package vn.edu.huit.finance.core.Service.Backup;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Document.BackupRun;
import vn.edu.huit.finance.core.Dto.ScheduledBackupStatusDto;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.BackupFailure;
import vn.edu.huit.finance.core.Entity.BackupOrigin;
import vn.edu.huit.finance.core.Entity.BackupType;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.BackupInProgressException;
import vn.edu.huit.finance.core.Repository.Mongo.BackupRunRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.AsyncMailSender;
import vn.edu.huit.finance.core.Service.BackupService;
import vn.edu.huit.finance.core.Util.FileChecksum;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.locks.ReentrantLock;

/**
 * The daily backup of PostgreSQL and the restore from its copy in MongoDB.
 * <p>
 * A run: pg_dump (BackupService, FULL), SHA-256 of the file, {@code pg_restore --list} on it to prove it can be read, a
 * second copy in MongoDB GridFS with the same SHA-256, then the retention ({@link BackupRetention}) of both places. Every
 * run is written to action_logs (as the system) and to {@code backup_runs} for the backup page; a run that fails at any
 * step mails the administrators, and a failed run never deletes an older backup. Nothing here logs a connection string,
 * a password or an email address.
 * <p>
 * The copy in MongoDB sits on the same server as PostgreSQL: it guards against file and disk faults of PostgreSQL, not
 * against losing the server. Copying off the server is a deployment task.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ScheduledBackupService {

    private static final String MAIL_SUBJECT = "[DonutPay] Sao lưu tự động thất bại";
    private static final String MAIL_TEXT = "Lần sao lưu tự động lúc %s thất bại: %s.%n%n"
            + "Các bản sao lưu cũ vẫn được giữ nguyên. Xem trang Sao lưu và Nhật ký kiểm toán của Web Admin để biết thêm.";
    private static final String AUDIT_VERIFIED = "Sao lưu tự động %s (%d byte, SHA-256 %s), đã kiểm tra bằng pg_restore --list; nơi lưu: %s";
    private static final String AUDIT_FAILED = "Sao lưu tự động thất bại: %s";
    private static final String PLACE_DISK = "đĩa";
    private static final String PLACE_MONGO = "MongoDB";
    private static final String PLACE_SEPARATOR = ", ";

    private final BackupService backupService;
    private final BackupCopyStore copyStore;
    private final BackupRunRepository runs;
    private final UserRepository users;
    private final AsyncMailSender mailSender;
    private final ApplicationEventPublisher eventPublisher;
    private final BackupScheduleSettings settings;

    private Clock clock = Clock.systemDefaultZone();
    /** One backup or restore at a time. */
    private final ReentrantLock running = new ReentrantLock();
    /** The last run, kept in memory too: if MongoDB is down the page can still say how the last night went. */
    private volatile BackupRun lastRun;

    // ----------------------------------------------------------------------------------------------- the daily run

    public void runScheduledBackup() {
        if (!running.tryLock()) {
            log.warn("A backup or restore is already running, the scheduled backup is skipped");
            return;
        }
        try {
            BackupRun run = BackupRun.builder().startedAt(now()).build();
            Optional<String> fileName = backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED);
            if (fileName.isEmpty()) {
                finish(failed(run, null, BackupFailure.DUMP_FAILED, false));
                return;
            }
            BackupRun result = verifyAndCopy(run, fileName.get());
            finish(result);
            // A run without a good dump on disk deletes nothing: the older backups are all there is.
            if (result.isOnDisk()) {
                pruneDisk();
            }
        } finally {
            running.unlock();
        }
    }

    /** Checksum, readability and the MongoDB copy of a dump that exists. Never deletes anything but a dump that is corrupt. */
    private BackupRun verifyAndCopy(BackupRun run, String fileName) {
        Path file = backupService.resolveBackupFile(fileName);
        String sha256;
        long size;
        try {
            size = Files.size(file);
            sha256 = FileChecksum.sha256(file);
        } catch (IOException e) {
            log.error("Could not read the new backup {} to checksum it", fileName, e);
            return failed(run, fileName, BackupFailure.CHECKSUM_FAILED, false);
        }
        run.setFileName(fileName);
        run.setSizeBytes(size);
        run.setSha256(sha256);

        if (!backupService.isReadable(fileName)) {
            backupService.deleteBackup(fileName);
            return failed(run, fileName, BackupFailure.NOT_READABLE, false);
        }
        run.setOnDisk(true);

        LocalDateTime createdAt = BackupFile.parse(fileName, BackupType.FULL, BackupOrigin.SCHEDULED).orElseThrow().createdAt();
        try {
            copyStore.save(file, fileName, createdAt, sha256);
        } catch (RuntimeException e) {
            log.error("Could not copy the backup {} to MongoDB", fileName, e);
            return failed(run, fileName, BackupFailure.MONGO_COPY_FAILED, true);
        }
        run.setInMongo(true);
        run.setSuccess(true);
        pruneMongo();
        return run;
    }

    private BackupRun failed(BackupRun run, String fileName, BackupFailure failure, boolean onDisk) {
        run.setFileName(fileName);
        run.setOnDisk(onDisk);
        run.setSuccess(false);
        run.setFailure(failure);
        return run;
    }

    /** Writes the result everywhere it is shown; none of these steps can make the job fail or hide the others. */
    private void finish(BackupRun run) {
        run.setFinishedAt(now());
        lastRun = run;
        audit(run);
        try {
            runs.save(run);
        } catch (RuntimeException e) {
            log.error("Could not record the backup run in MongoDB", e);
        }
        if (!run.isSuccess()) {
            notifyAdministrators(run);
        }
    }

    private void audit(BackupRun run) {
        AuditAction action = run.isSuccess() ? AuditAction.SYSTEM_BACKUP_VERIFIED : AuditAction.SYSTEM_BACKUP_SCHEDULED_FAILED;
        String description = run.isSuccess()
                ? String.format(AUDIT_VERIFIED, run.getFileName(), run.getSizeBytes(), run.getSha256(), places(run))
                : String.format(AUDIT_FAILED, run.getFailure().getLabel());
        eventPublisher.publishEvent(SecurityAuditEvent.of(action, AuditActor.system(), null, description));
    }

    private static String places(BackupRun run) {
        List<String> places = new ArrayList<>();
        if (run.isOnDisk()) places.add(PLACE_DISK);
        if (run.isInMongo()) places.add(PLACE_MONGO);
        return String.join(PLACE_SEPARATOR, places);
    }

    private void notifyAdministrators(BackupRun run) {
        try {
            for (User admin : users.findByRoleAndActiveTrue(Roles.ADMIN)) {
                if (admin.getEmail() == null || admin.getEmail().isBlank()) continue;
                SimpleMailMessage message = new SimpleMailMessage();
                message.setTo(admin.getEmail());
                message.setSubject(MAIL_SUBJECT);
                message.setText(String.format(MAIL_TEXT, run.getFinishedAt(), run.getFailure().getLabel()));
                mailSender.send(message);
            }
        } catch (RuntimeException e) {
            // The failure is already in action_logs and on the backup page; a mail problem must not hide it.
            log.error("Could not mail the administrators about the failed backup", e);
        }
    }

    // ------------------------------------------------------------------------------------------------- retention

    private void pruneDisk() {
        try {
            for (BackupFile old : BackupRetention.toDelete(
                    backupService.listBackups(BackupType.FULL, BackupOrigin.SCHEDULED), BackupFile::createdAt)) {
                deleteQuietly(() -> backupService.deleteBackup(old.name()), old.name());
            }
        } catch (RuntimeException e) {
            log.error("Could not clean up the old backups on disk", e);
        }
    }

    private void pruneMongo() {
        try {
            for (BackupCopy old : BackupRetention.toDelete(copyStore.list(), BackupCopy::createdAt)) {
                deleteQuietly(() -> copyStore.delete(old.id()), old.fileName());
            }
        } catch (RuntimeException e) {
            log.error("Could not clean up the old backups in MongoDB", e);
        }
    }

    private static void deleteQuietly(Runnable deletion, String name) {
        try {
            deletion.run();
        } catch (RuntimeException e) {
            log.error("Could not delete the old backup {}", name, e);
        }
    }

    // ------------------------------------------------------------------------------- manual runs (admin buttons)

    /** The admin's "back up now" button: same lock as the daily run, so two pg_dump / pg_restore never overlap. */
    public boolean backupNow(BackupType type) {
        if (!running.tryLock()) {
            log.warn("A backup or restore is already running, the manual {} backup is refused", type);
            throw new BackupInProgressException();
        }
        try {
            return backupService.backupDatabase(type);
        } finally {
            running.unlock();
        }
    }

    /** The admin's "restore the newest FULL" button, under the same lock. */
    public boolean restoreLatestFullNow() {
        if (!running.tryLock()) {
            log.warn("A backup or restore is already running, the manual restore is refused");
            throw new BackupInProgressException();
        }
        try {
            return backupService.restoreLatestFull();
        } finally {
            running.unlock();
        }
    }

    // ------------------------------------------------------------------------------------- restore from MongoDB

    /**
     * Downloads the newest copy from MongoDB into the backup folder, checks it against the SHA-256 stored with it and only
     * then hands it to {@link BackupService#restoreDatabase}, which stays the one place that runs pg_restore. A copy that
     * does not match is deleted and never restored.
     */
    public MongoRestoreOutcome restoreFromMongo() {
        if (!running.tryLock()) {
            return MongoRestoreOutcome.BUSY;
        }
        try {
            return restoreNewestCopy();
        } finally {
            running.unlock();
        }
    }

    private MongoRestoreOutcome restoreNewestCopy() {
        List<BackupCopy> copies;
        try {
            copies = copyStore.list();
        } catch (RuntimeException e) {
            log.error("Could not list the backup copies in MongoDB", e);
            return MongoRestoreOutcome.STORE_UNAVAILABLE;
        }
        if (copies.isEmpty()) {
            return MongoRestoreOutcome.NO_COPY;
        }
        BackupCopy copy = copies.get(0);
        if (BackupFile.parse(copy.fileName(), BackupType.FULL, BackupOrigin.SCHEDULED).isEmpty()) {
            log.error("The newest copy in MongoDB has a name that is no scheduled FULL backup name");
            return MongoRestoreOutcome.INVALID_COPY;
        }

        Path staged = backupService.resolveBackupFile(copy.fileName() + BackupService.PARTIAL_SUFFIX);
        try {
            copyStore.downloadTo(copy, staged);
            if (!matchesStoredChecksum(staged, copy)) {
                Files.deleteIfExists(staged);
                log.error("The copy {} does not match its stored SHA-256, it is not restored", copy.fileName());
                return MongoRestoreOutcome.CHECKSUM_MISMATCH;
            }
            Files.move(staged, backupService.resolveBackupFile(copy.fileName()), StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException | RuntimeException e) {
            log.error("Could not download the copy {} from MongoDB", copy.fileName(), e);
            discard(staged);
            return MongoRestoreOutcome.STORE_UNAVAILABLE;
        }
        return backupService.restoreDatabase(copy.fileName()) ? MongoRestoreOutcome.RESTORED : MongoRestoreOutcome.RESTORE_FAILED;
    }

    private static boolean matchesStoredChecksum(Path file, BackupCopy copy) throws IOException {
        return copy.sha256() != null && copy.sha256().equalsIgnoreCase(FileChecksum.sha256(file));
    }

    private static void discard(Path file) {
        try {
            Files.deleteIfExists(file);
        } catch (IOException e) {
            log.error("Could not delete the partial file {}", file.getFileName(), e);
        }
    }

    // ----------------------------------------------------------------------------------------------------- status

    public ScheduledBackupStatusDto latestStatus() {
        BackupRun run = readLastRun();
        if (run == null) {
            return new ScheduledBackupStatusDto(settings.enabled(), settings.cron(), settings.zone(),
                    false, null, false, null, null, null, null, false, false);
        }
        return new ScheduledBackupStatusDto(settings.enabled(), settings.cron(), settings.zone(), true,
                run.getFinishedAt(), run.isSuccess(), run.getFailure() == null ? null : run.getFailure().getLabel(),
                run.getFileName(), run.getSizeBytes(), run.getSha256(), run.isOnDisk(), run.isInMongo());
    }

    private BackupRun readLastRun() {
        try {
            Optional<BackupRun> stored = runs.findFirstByOrderByFinishedAtDesc();
            if (stored.isPresent()) {
                return stored.get();
            }
        } catch (RuntimeException e) {
            log.error("Could not read the last backup run from MongoDB", e);
        }
        return lastRun;
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }
}
