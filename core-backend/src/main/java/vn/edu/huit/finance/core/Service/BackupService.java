package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.BackupType;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.io.File;
import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Backups and restores of the database through pg_dump / pg_restore, for administrators. Their effect lies outside the
 * application's transactions, so each one that succeeded is recorded right after it as a SecurityAuditEvent (a row of its
 * own, naming the administrator who called); a row that cannot be written is logged and does not undo the backup.
 */
@Slf4j
@Service
public class BackupService {
    private static final String AUDIT_BACKUP = "Sao lưu cơ sở dữ liệu (loại: %s - %s)";
    private static final String BACKUP_FILE_EXTENSION = ".sql";
    private static final DateTimeFormatter BACKUP_TIMESTAMP = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");
    private static final String AUDIT_RESTORE = "Phục hồi cơ sở dữ liệu từ file: %s";

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Value("${spring.datasource.username}")
    private String dbUser;

    @Value("${spring.datasource.password}")
    private String dbPassword;

    /** host[:port]/database of a jdbc:postgresql URL; query parameters after "?" are ignored. */
    private static final Pattern JDBC_POSTGRES_URL = Pattern.compile("^jdbc:postgresql://([^:/?]+)(?::(\\d+))?/([^?]+).*$");
    private static final String DEFAULT_DB_NAME = "finance_db";

    // Same URL the application connects with: in Docker the database is the "db" service, not localhost.
    @Value("${spring.datasource.url:}")
    private String dbUrl;

    private String backupDir = System.getProperty("user.dir") + "/backups/";

    @Value("${postgres.bin.path:}")
    private String pgBinPath;

    private String getCommand(String cmd) {
        if (pgBinPath == null || pgBinPath.trim().isEmpty()) {
            return cmd;
        }
        if (!pgBinPath.endsWith("/") && !pgBinPath.endsWith("\\")) {
            return pgBinPath + File.separator + cmd;
        }
        return pgBinPath + cmd;
    }

    /** Chạy pg_dump theo đúng loại được chọn; chỉ bản chạy thành công mới được ghi vào nhật ký kiểm toán. */
    public boolean backupDatabase(BackupType type) {
        String fileName = backupDir + type.filePrefix() + LocalDateTime.now().format(BACKUP_TIMESTAMP) + BACKUP_FILE_EXTENSION;
        File dir = new File(backupDir);
        if (!dir.exists()) dir.mkdirs();

        ProcessBuilder processBuilder = new ProcessBuilder(pgDumpCommand(type, fileName));
        processBuilder.environment().put("PGPASSWORD", dbPassword);
        processBuilder.inheritIO();
        try {
            int exitCode = processBuilder.start().waitFor();
            if (exitCode != 0) {
                log.error("pg_dump thất bại, type={}, exitCode={}", type, exitCode);
                return false;
            }
            eventPublisher.publishEvent(SecurityAuditEvent.ofCurrentCaller(AuditAction.SYSTEM_BACKUP_CREATED,
                    String.format(AUDIT_BACKUP, type.name(), type.getLabel())));
            log.info("Sao lưu cơ sở dữ liệu thành công, type={}", type);
            return true;
        } catch (IOException e) {
            log.error("Không chạy được pg_dump, type={}", type, e);
            return false;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("pg_dump bị ngắt giữa chừng, type={}", type, e);
            return false;
        }
    }

    /** Lệnh pg_dump: các tham số chung (định dạng custom, file đích, tên DB) + tham số riêng của loại sao lưu. */
    List<String> pgDumpCommand(BackupType type, String fileName) {
        List<String> command = new ArrayList<>(List.of(getCommand("pg_dump")));
        command.addAll(connectionOptions());
        command.addAll(List.of("-F", "c", "-v"));
        command.addAll(type.getPgDumpOptions());
        command.addAll(List.of("-f", fileName, databaseName()));
        return command;
    }

    /** -h/-p from the datasource URL (left out when the URL is missing or not a PostgreSQL one), then -U. */
    List<String> connectionOptions() {
        List<String> options = new ArrayList<>();
        Matcher url = parsedUrl();
        if (url != null) {
            options.addAll(List.of("-h", url.group(1)));
            if (url.group(2) != null) options.addAll(List.of("-p", url.group(2)));
        }
        options.addAll(List.of("-U", dbUser));
        return options;
    }

    String databaseName() {
        Matcher url = parsedUrl();
        return url != null ? url.group(3) : DEFAULT_DB_NAME;
    }

    private Matcher parsedUrl() {
        if (dbUrl == null || dbUrl.isBlank()) return null;
        Matcher matcher = JDBC_POSTGRES_URL.matcher(dbUrl.trim());
        return matcher.matches() ? matcher : null;
    }

    public boolean restoreDatabase(String fileName) {
        try {
            List<String> command = new ArrayList<>(List.of(getCommand("pg_restore")));
            command.addAll(connectionOptions());
            command.addAll(List.of("-d", databaseName(), "-1", "--clean", "--if-exists", backupDir + fileName));
            ProcessBuilder processBuilder = new ProcessBuilder(command);
            processBuilder.environment().put("PGPASSWORD", dbPassword);
            processBuilder.inheritIO();

            Process process = processBuilder.start();
            int exitCode = process.waitFor();

            if (exitCode == 0) {
                // Written into the restored database, after pg_restore has replaced action_logs with the backup's.
                eventPublisher.publishEvent(SecurityAuditEvent.ofCurrentCaller(AuditAction.SYSTEM_DATABASE_RESTORED,
                        String.format(AUDIT_RESTORE, fileName)));
                // Every cached statistic now describes data that is gone.
                eventPublisher.publishEvent(StatisticsChangedEvent.of(StatisticsChange.DATABASE_RESTORED));
            }

            return exitCode == 0;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public String latestBackup(BackupType type) {
        File dir = new File(backupDir);
        File[] files = dir.listFiles((d, n) -> n.startsWith(type.filePrefix()) && n.endsWith(BACKUP_FILE_EXTENSION));
        if (files == null || files.length == 0) return null;
        return Arrays.stream(files)
                .max(Comparator.comparingLong(File::lastModified))
                .map(File::getName)
                .orElse(null);
    }

    /** Phục hồi từ bản FULL mới nhất: chỉ bản đó có cả cấu trúc lẫn dữ liệu (xem {@link BackupType}). */
    public boolean restoreLatestFull() {
        String fileName = latestBackup(BackupType.FULL);
        if (fileName == null) return false;
        return restoreDatabase(fileName);
    }
}