package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.BackupOrigin;
import vn.edu.huit.finance.core.Entity.BackupType;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.Backup.BackupFile;
import vn.edu.huit.finance.core.Service.Backup.ExternalCommandRunner;
import vn.edu.huit.finance.core.Service.Backup.ProcessCommandRunner;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
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
    /** What a file being downloaded from the MongoDB copy is called until its SHA-256 has been checked. */
    public static final String PARTIAL_SUFFIX = ".partial";
    private static final String PG_PASSWORD_VARIABLE = "PGPASSWORD";
    private static final String MSG_BAD_FILE_NAME = "Tên file sao lưu không hợp lệ";
    private static final String AUDIT_RESTORE = "Phục hồi cơ sở dữ liệu từ file: %s";

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Value("${spring.datasource.username}")
    private String dbUser;

    @Value("${spring.datasource.password}")
    private String dbPassword;

    /** The tools run through this, so that a test needs no real pg_dump; the default is the real thing. */
    @Autowired
    private ExternalCommandRunner commandRunner = new ProcessCommandRunner();

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

    /** Bản admin bấm tay: chạy pg_dump theo loại được chọn; true khi pg_dump thành công. */
    public boolean backupDatabase(BackupType type) {
        return createBackup(type, BackupOrigin.MANUAL).isPresent();
    }

    /**
     * Chạy pg_dump; chỉ bản chạy thành công mới được ghi vào nhật ký kiểm toán (người gọi nếu là admin bấm tay, HỆ THỐNG
     * nếu là bản tự động). Trả về tên file đã tạo trong thư mục backups/, rỗng khi pg_dump thất bại.
     */
    public Optional<String> createBackup(BackupType type, BackupOrigin origin) {
        String name = type.filePrefix() + origin.fileInfix() + LocalDateTime.now().format(BackupFile.TIMESTAMP) + BackupFile.EXTENSION;
        File dir = new File(backupDir);
        if (!dir.exists()) dir.mkdirs();

        try {
            int exitCode = commandRunner.run(pgDumpCommand(type, backupDir + name), pgEnvironment());
            if (exitCode != 0) {
                log.error("pg_dump thất bại, type={}, exitCode={}", type, exitCode);
                return Optional.empty();
            }
            AuditActor actor = origin == BackupOrigin.SCHEDULED ? AuditActor.system() : AuditActor.currentCaller();
            eventPublisher.publishEvent(SecurityAuditEvent.of(AuditAction.SYSTEM_BACKUP_CREATED, actor, null,
                    String.format(AUDIT_BACKUP, type.name(), type.getLabel())));
            log.info("Sao lưu cơ sở dữ liệu thành công, type={}, origin={}", type, origin);
            return Optional.of(name);
        } catch (IOException e) {
            log.error("Không chạy được pg_dump, type={}", type, e);
            return Optional.empty();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("pg_dump bị ngắt giữa chừng, type={}", type, e);
            return Optional.empty();
        }
    }

    /** pg_restore --list đọc được mục lục của file: bản dump hỏng hoặc cụt không qua được bước này. */
    public boolean isReadable(String fileName) {
        resolveBackupFile(fileName);
        List<String> command = new ArrayList<>(List.of(getCommand("pg_restore"), "--list", backupDir + fileName));
        try {
            return commandRunner.runQuietly(command, Map.of()) == 0;
        } catch (IOException e) {
            log.error("Không chạy được pg_restore --list", e);
            return false;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("pg_restore --list bị ngắt giữa chừng", e);
            return false;
        }
    }

    private Map<String, String> pgEnvironment() {
        return Map.of(PG_PASSWORD_VARIABLE, dbPassword);
    }

    /** Đường dẫn của một file trong thư mục backups/; ném IllegalArgumentException khi tên có dấu phân cách thư mục. */
    public Path resolveBackupFile(String fileName) {
        boolean plainName = fileName != null && !fileName.isBlank() && !fileName.equals(".") && !fileName.equals("..")
                && !fileName.contains("/") && !fileName.contains("\\");
        if (!plainName) {
            throw new IllegalArgumentException(MSG_BAD_FILE_NAME);
        }
        Path dir = Path.of(backupDir).toAbsolutePath().normalize();
        Path resolved = dir.resolve(fileName).normalize();
        if (!dir.equals(resolved.getParent())) {
            throw new IllegalArgumentException(MSG_BAD_FILE_NAME);
        }
        return resolved;
    }

    /** Các file sao lưu của một loại và một nguồn, kèm thời điểm tạo đọc từ tên file; thứ tự không đảm bảo. */
    public List<BackupFile> listBackups(BackupType type, BackupOrigin origin) {
        String[] names = new File(backupDir).list();
        if (names == null) return List.of();
        return Arrays.stream(names)
                .map(name -> BackupFile.parse(name, type, origin))
                .flatMap(Optional::stream)
                .toList();
    }

    /** Xóa một file sao lưu; false khi file không còn hoặc không xóa được. */
    public boolean deleteBackup(String fileName) {
        Path file = resolveBackupFile(fileName);
        try {
            return Files.deleteIfExists(file);
        } catch (IOException e) {
            log.error("Không xóa được file sao lưu {}", fileName, e);
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
        File[] files = dir.listFiles((d, n) -> n.startsWith(type.filePrefix()) && n.endsWith(BackupFile.EXTENSION));
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