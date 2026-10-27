package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.PosixFilePermissions;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Backups and restores of the MongoDB data of the application (ocr_logs, ocr_feedbacks) through mongodump /
 * mongorestore, for administrators; the counterpart of {@link BackupService} for PostgreSQL. Each one that succeeded is
 * recorded right after it as a SecurityAuditEvent. The connection string holds the password: it is never put in the
 * arguments of the tools (those show in the process list) but in a temporary owner-only YAML config file ({@code --config})
 * that is deleted right after the run; it is never logged either, and any text of the tools that reaches the log goes
 * through {@link #maskUri(String)}.
 * <p>
 * mongodump (tools 100.x) cannot be given several collections to include (--collection takes one; it only has
 * --excludeCollection), so by design it dumps the whole {@value #DATABASE} database into one archive. The
 * restore is where the two collections are fixed: {@code --nsInclude} limits it, and {@code --drop} only drops the
 * collections it restores, so any other collection of the database is left alone.
 * <p>
 * One backup or restore runs at a time; a second call while one runs gets a {@link BusyException}. A tool that does not
 * end within {@value #TOOL_TIMEOUT_MINUTES} minutes is killed and counts as failed.
 */
@Slf4j
@Service
public class MongoBackupService {
    static final String DATABASE = "finance_nosql";
    static final List<String> COLLECTIONS = List.of("ocr_logs", "ocr_feedbacks");
    static final long TOOL_TIMEOUT_MINUTES = 10;

    private static final String ARCHIVE_PREFIX = "mongo_";
    private static final String ARCHIVE_SUFFIX = ".archive.gz";
    /** What mongodump writes to; renamed to the final name only after it succeeded, so a failed dump is never restorable. */
    private static final String PARTIAL_SUFFIX = ".partial";
    private static final DateTimeFormatter TIMESTAMP = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");
    private static final String AUDIT_BACKUP = "Sao lưu MongoDB (%s): %s";
    private static final String AUDIT_RESTORE = "Phục hồi MongoDB (%s) từ file: %s";
    /** user:password@ of a connection string; the password may hold anything but "@" (it is percent-encoded there). */
    private static final Pattern CREDENTIALS = Pattern.compile("(mongodb(?:\\+srv)?://[^/:@\\s]+):[^@\\s]*@");
    /** scheme://[credentials@]hosts, then /database, then an optional ?query. */
    private static final Pattern URI_WITH_DATABASE = Pattern.compile("^(mongodb(?:\\+srv)?://[^/?]+)/([^?]+)(?:\\?(.*))?$");
    private static final Pattern AUTH_SOURCE = Pattern.compile("(^|&)authSource=", Pattern.CASE_INSENSITIVE);
    private static final int LOGGED_OUTPUT_MAX = 2000;

    /** Thrown when a backup or restore is asked while another one still runs. */
    public static class BusyException extends RuntimeException {
        public BusyException() {
            super("Another MongoDB backup or restore is running");
        }
    }

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Value("${spring.data.mongodb.uri}")
    private String mongoUri;

    @Value("${mongo.bin.path:}")
    private String mongoBinPath;

    private String backupDir = System.getProperty("user.dir") + "/backups/";

    private final ReentrantLock running = new ReentrantLock();
    private long toolTimeoutMillis = TimeUnit.MINUTES.toMillis(TOOL_TIMEOUT_MINUTES);

    /** The connection string with the password replaced by ****; null stays null. */
    static String maskUri(String text) {
        return text == null ? null : CREDENTIALS.matcher(text).replaceAll("$1:****@");
    }

    /**
     * The connection string without the database of its path (host/db?options becomes host/?options). With a database in
     * the URI, mongorestore restores that whole database and ignores --nsInclude, which would let --drop replace
     * collections other than the two; the database is named by --db (dump) and --nsInclude (restore) instead. A URI with
     * credentials and no authSource authenticates against the database of its path, so that name moves to authSource and
     * stripping the path never changes where the user is looked up.
     */
    static String withoutDatabase(String uri) {
        if (uri == null) {
            return null;
        }
        Matcher m = URI_WITH_DATABASE.matcher(uri);
        if (!m.matches()) {
            return uri;
        }
        String query = m.group(3);
        if (m.group(1).contains("@") && (query == null || !AUTH_SOURCE.matcher(query).find())) {
            String authSource = "authSource=" + m.group(2);
            query = query == null || query.isEmpty() ? authSource : query + "&" + authSource;
        }
        return m.group(1) + "/" + (query == null || query.isEmpty() ? "" : "?" + query);
    }

    /** Dumps the database into a new archive of the backup directory; recorded only when mongodump succeeded. */
    public boolean backup() {
        if (!running.tryLock()) {
            throw new BusyException();
        }
        try {
            File dir = new File(backupDir);
            if (!dir.exists() && !dir.mkdirs()) {
                log.error("Không tạo được thư mục sao lưu {}", backupDir);
                return false;
            }
            String fileName = ARCHIVE_PREFIX + LocalDateTime.now().format(TIMESTAMP) + ARCHIVE_SUFFIX;
            Path target = Path.of(backupDir + fileName);
            Path partial = Path.of(backupDir + fileName + PARTIAL_SUFFIX);
            try {
                if (!run("mongodump", config -> mongoDumpCommand(partial.toString(), config))) {
                    return false;
                }
                publish(partial, target);
            } catch (IOException e) {
                log.error("Không đổi tên file sao lưu {}: {}", fileName, e.getMessage());
                return false;
            } finally {
                deleteQuietly(partial);
            }
            eventPublisher.publishEvent(SecurityAuditEvent.ofCurrentCaller(AuditAction.MONGO_BACKUP_CREATED,
                    String.format(AUDIT_BACKUP, String.join(", ", COLLECTIONS), fileName)));
            log.info("Sao lưu MongoDB thành công: {}", fileName);
            return true;
        } finally {
            running.unlock();
        }
    }

    private static void publish(Path partial, Path target) throws IOException {
        try {
            Files.move(partial, target, StandardCopyOption.ATOMIC_MOVE);
        } catch (AtomicMoveNotSupportedException e) {
            Files.move(partial, target, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    /** Restores the two collections from the newest archive; false when there is none or mongorestore failed. */
    public boolean restoreLatest() {
        if (!running.tryLock()) {
            throw new BusyException();
        }
        try {
            String fileName = latestBackup();
            if (fileName == null) {
                return false;
            }
            if (!run("mongorestore", config -> mongoRestoreCommand(backupDir + fileName, config))) {
                return false;
            }
            eventPublisher.publishEvent(SecurityAuditEvent.ofCurrentCaller(AuditAction.MONGO_RESTORED,
                    String.format(AUDIT_RESTORE, String.join(", ", COLLECTIONS), fileName)));
            log.info("Phục hồi MongoDB thành công từ {}", fileName);
            return true;
        } finally {
            running.unlock();
        }
    }

    /** The name of the newest mongo_*.archive.gz of the backup directory, or null when there is none. */
    public String latestBackup() {
        File[] files = new File(backupDir).listFiles((d, n) -> n.startsWith(ARCHIVE_PREFIX) && n.endsWith(ARCHIVE_SUFFIX));
        if (files == null || files.length == 0) {
            return null;
        }
        return Arrays.stream(files)
                .max(Comparator.comparingLong(File::lastModified).thenComparing(File::getName))
                .map(File::getName)
                .orElse(null);
    }

    /** The YAML config the tools read the connection string from: {@code uri: "<uri without database>"}. */
    static String configContent(String uri) {
        String quoted = withoutDatabase(uri).replace("\\", "\\\\").replace("\"", "\\\"");
        return "uri: \"" + quoted + "\"\n";
    }

    List<String> mongoDumpCommand(String archive, Path config) {
        return new ArrayList<>(List.of(tool("mongodump"), "--config=" + config, "--db=" + DATABASE,
                "--archive=" + archive, "--gzip"));
    }

    List<String> mongoRestoreCommand(String archive, Path config) {
        List<String> command = new ArrayList<>(List.of(tool("mongorestore"), "--config=" + config,
                "--archive=" + archive, "--gzip", "--drop"));
        COLLECTIONS.forEach(collection -> command.add("--nsInclude=" + DATABASE + "." + collection));
        return command;
    }

    private String tool(String name) {
        if (mongoBinPath == null || mongoBinPath.isBlank()) {
            return name;
        }
        return mongoBinPath.endsWith("/") ? mongoBinPath + name : mongoBinPath + File.separator + name;
    }

    /** A new file only its owner can read (0600 where the file system has POSIX permissions). */
    private static Path ownerOnlyTempFile(String prefix, String suffix) throws IOException {
        try {
            return Files.createTempFile(prefix, suffix,
                    PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));
        } catch (UnsupportedOperationException e) {
            Path file = Files.createTempFile(prefix, suffix);
            file.toFile().setReadable(false, false);
            file.toFile().setReadable(true, true);
            return file;
        }
    }

    /**
     * Runs the tool with a temporary config file holding the URI; the output goes to a second temporary file, read only
     * on failure and logged masked (so a tool that hangs while holding its pipe cannot block the wait). Both files are
     * deleted afterwards. A tool still running after the timeout is killed with its children.
     */
    private boolean run(String name, Function<Path, List<String>> commandOf) {
        Path config = null;
        Path output = null;
        try {
            config = ownerOnlyTempFile("mongo-tool-", ".yml");
            Files.writeString(config, configContent(mongoUri), StandardCharsets.UTF_8);
            output = ownerOnlyTempFile("mongo-tool-", ".log");
            Process process = new ProcessBuilder(commandOf.apply(config))
                    .redirectErrorStream(true).redirectOutput(output.toFile()).start();
            if (!process.waitFor(toolTimeoutMillis, TimeUnit.MILLISECONDS)) {
                process.descendants().forEach(ProcessHandle::destroyForcibly);
                process.destroyForcibly();
                log.error("{} chạy quá {} ms nên bị dừng", name, toolTimeoutMillis);
                return false;
            }
            int exitCode = process.exitValue();
            if (exitCode != 0) {
                String masked = maskUri(Files.readString(output, StandardCharsets.UTF_8));
                if (masked.length() > LOGGED_OUTPUT_MAX) {
                    masked = masked.substring(masked.length() - LOGGED_OUTPUT_MAX);
                }
                log.error("{} thất bại, exitCode={}, output: {}", name, exitCode, masked);
                return false;
            }
            return true;
        } catch (IOException e) {
            log.error("Không chạy được {}: {}", name, maskUri(e.getMessage()));
            return false;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.error("{} bị ngắt giữa chừng", name);
            return false;
        } finally {
            deleteQuietly(config);
            deleteQuietly(output);
        }
    }

    private static void deleteQuietly(Path file) {
        if (file == null) {
            return;
        }
        try {
            Files.deleteIfExists(file);
        } catch (IOException e) {
            log.warn("Không xóa được file tạm {}", file.getFileName());
        }
    }
}
