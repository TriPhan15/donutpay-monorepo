package vn.edu.huit.finance.core.Service.Backup;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.test.util.ReflectionTestUtils;
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
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.AsyncMailSender;
import vn.edu.huit.finance.core.Service.BackupService;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * The daily backup and the restore from the MongoDB copy, with every collaborator mocked: no pg_dump, no pg_restore and
 * no MongoDB run here (the process calls are behind BackupService, the GridFS calls behind BackupCopyStore).
 */
@ExtendWith(MockitoExtension.class)
class ScheduledBackupServiceTest {

    private static final String FILE = "FULL_backup_auto_20261101_020000.sql";
    private static final String CONTENT = "abc";
    private static final String CONTENT_SHA256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 1, 2, 0, 30);

    @TempDir private Path folder;
    @Mock private BackupService backupService;
    @Mock private BackupCopyStore copyStore;
    @Mock private BackupRunRepository runs;
    @Mock private UserRepository users;
    @Mock private AsyncMailSender mailSender;
    @Mock private ApplicationEventPublisher events;

    private ScheduledBackupService service;

    @BeforeEach
    void create() {
        service = new ScheduledBackupService(backupService, copyStore, runs, users, mailSender, events,
                new BackupScheduleSettings(true, "0 0 2 * * *", "Asia/Ho_Chi_Minh"));
        ZoneId zone = ZoneId.of("Asia/Ho_Chi_Minh");
        ReflectionTestUtils.setField(service, "clock", Clock.fixed(NOW.atZone(zone).toInstant(), zone));
        lenient().when(backupService.resolveBackupFile(anyString())).thenAnswer(call -> folder.resolve(call.<String>getArgument(0)));
    }

    // --------------------------------------------------------------------------------------------------- helpers

    private void dumpCreatesTheFile() throws IOException {
        Files.writeString(folder.resolve(FILE), CONTENT, StandardCharsets.UTF_8);
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.of(FILE));
    }

    private void adminsAre(String... emails) {
        List<User> admins = java.util.Arrays.stream(emails).map(email -> {
            User user = new User();
            user.setEmail(email);
            return user;
        }).toList();
        when(users.findByRoleAndActiveTrue(Roles.ADMIN)).thenReturn(admins);
    }

    private BackupRun savedRun() {
        ArgumentCaptor<BackupRun> run = ArgumentCaptor.forClass(BackupRun.class);
        verify(runs).save(run.capture());
        return run.getValue();
    }

    private AuditEntry publishedEntry() {
        ArgumentCaptor<SecurityAuditEvent> event = ArgumentCaptor.forClass(SecurityAuditEvent.class);
        verify(events).publishEvent(event.capture());
        return event.getValue().entry();
    }

    private static BackupCopy copy(String id, int day) {
        String name = String.format("FULL_backup_auto_202610%02d_020000.sql", day);
        return new BackupCopy(id, name, LocalDateTime.of(2026, 10, day, 2, 0), 3, CONTENT_SHA256);
    }

    // ------------------------------------------------------------------------------------------- the good night

    @Test
    void aGoodBackupIsChecksummedVerifiedCopiedToMongoAndRecordedAsSuccess() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(true);

        service.runScheduledBackup();

        verify(copyStore).save(folder.resolve(FILE), FILE, LocalDateTime.of(2026, 11, 1, 2, 0), CONTENT_SHA256);
        BackupRun run = savedRun();
        assertTrue(run.isSuccess());
        assertEquals(FILE, run.getFileName());
        assertEquals(3L, run.getSizeBytes());
        assertEquals(CONTENT_SHA256, run.getSha256());
        assertTrue(run.isOnDisk());
        assertTrue(run.isInMongo());
        assertNull(run.getFailure());
        assertEquals(NOW, run.getFinishedAt());
        verifyNoInteractions(mailSender);
    }

    @Test
    void theResultIsWrittenToTheAuditLogAsTheSystemWithTheChecksumAndPlaces() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(true);

        service.runScheduledBackup();

        AuditEntry entry = publishedEntry();
        assertEquals(AuditAction.SYSTEM_BACKUP_VERIFIED, entry.action());
        assertEquals(AuditActor.system(), entry.actor());
        assertTrue(entry.description().contains(FILE));
        assertTrue(entry.description().contains(CONTENT_SHA256));
        assertTrue(entry.description().contains("MongoDB"));
        assertTrue(entry.description().contains("đĩa"));
    }

    // ----------------------------------------------------------------------------------------------- the bad nights

    @Test
    void aFailedDumpIsRecordedAsFailureAndTheAdministratorsAreMailed() {
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.empty());
        adminsAre("admin1@example.com", "admin2@example.com");

        service.runScheduledBackup();

        BackupRun run = savedRun();
        assertFalse(run.isSuccess());
        assertEquals(BackupFailure.DUMP_FAILED, run.getFailure());
        assertFalse(run.isOnDisk());
        AuditEntry entry = publishedEntry();
        assertEquals(AuditAction.SYSTEM_BACKUP_SCHEDULED_FAILED, entry.action());
        assertEquals(AuditActor.system(), entry.actor());
        assertTrue(entry.description().contains(BackupFailure.DUMP_FAILED.getLabel()));

        ArgumentCaptor<SimpleMailMessage> mail = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender, times(2)).send(mail.capture());
        assertEquals("admin1@example.com", mail.getAllValues().get(0).getTo()[0]);
        assertEquals("admin2@example.com", mail.getAllValues().get(1).getTo()[0]);
        assertTrue(mail.getAllValues().get(0).getSubject().contains("Sao lưu tự động thất bại"));
        assertTrue(mail.getAllValues().get(0).getText().contains(BackupFailure.DUMP_FAILED.getLabel()));
        verifyNoInteractions(copyStore);
    }

    @Test
    void aFailedBackupNeverDeletesTheOlderOnes() {
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.empty());
        adminsAre("admin@example.com");

        service.runScheduledBackup();

        verify(backupService, never()).deleteBackup(anyString());
        verify(backupService, never()).listBackups(any(), any());
        verifyNoInteractions(copyStore);
    }

    @Test
    void aDumpThatPgRestoreCannotListIsDeletedReportedAndNeverCopiedToMongo() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(false);
        adminsAre("admin@example.com");

        service.runScheduledBackup();

        verify(backupService).deleteBackup(FILE);
        verifyNoInteractions(copyStore);
        BackupRun run = savedRun();
        assertFalse(run.isSuccess());
        assertEquals(BackupFailure.NOT_READABLE, run.getFailure());
        assertFalse(run.isOnDisk(), "the unreadable file was deleted");
        verify(mailSender).send(any(SimpleMailMessage.class));
    }

    @Test
    void aFileThatCannotBeReadBackToChecksumItIsAFailure() {
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.of(FILE));
        adminsAre("admin@example.com");

        service.runScheduledBackup();

        assertEquals(BackupFailure.CHECKSUM_FAILED, savedRun().getFailure());
        verify(mailSender).send(any(SimpleMailMessage.class));
        verify(backupService, never()).isReadable(anyString());
    }

    @Test
    void ifTheMongoCopyFailsTheGoodDiskBackupStaysAndTheFailureIsReported() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(true);
        doThrow(new IllegalStateException("mongo down")).when(copyStore).save(any(), anyString(), any(), anyString());
        adminsAre("admin@example.com");

        service.runScheduledBackup();

        verify(backupService, never()).deleteBackup(FILE);
        BackupRun run = savedRun();
        assertFalse(run.isSuccess());
        assertEquals(BackupFailure.MONGO_COPY_FAILED, run.getFailure());
        assertTrue(run.isOnDisk());
        assertFalse(run.isInMongo());
        assertEquals(AuditAction.SYSTEM_BACKUP_SCHEDULED_FAILED, publishedEntry().action());
        verify(mailSender).send(any(SimpleMailMessage.class));
        verify(copyStore, never()).delete(anyString());
    }

    @Test
    void aFailureToMailOrToRecordTheRunNeverEscapesTheJob() {
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.empty());
        when(users.findByRoleAndActiveTrue(Roles.ADMIN)).thenThrow(new IllegalStateException("db down"));
        when(runs.save(any(BackupRun.class))).thenThrow(new IllegalStateException("mongo down"));

        service.runScheduledBackup();

        verify(events).publishEvent(any(SecurityAuditEvent.class));
    }

    @Test
    void aMailAddressIsNeverPutInAnyMessageOtherThanTheRecipient() {
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.empty());
        adminsAre("admin@example.com");

        service.runScheduledBackup();

        ArgumentCaptor<SimpleMailMessage> mail = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender).send(mail.capture());
        assertFalse(mail.getValue().getText().contains("admin@example.com"));
        assertFalse(publishedEntry().description().contains("admin@example.com"));
    }

    // ------------------------------------------------------------------------------------------------- retention

    @Test
    void afterAGoodBackupTheDiskAndMongoKeepSevenDaysAndWeeklyAndDeleteTheRest() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(true);
        // 20-31/10 on disk and in MongoDB. Daily: 25-31/10, weekly: 24/10 (newest of the week of 19/10); 20-23/10 go.
        List<BackupFile> files = new java.util.ArrayList<>();
        List<BackupCopy> copies = new java.util.ArrayList<>();
        for (int day = 20; day <= 31; day++) {
            BackupCopy copy = copy("id" + day, day);
            copies.add(copy);
            files.add(new BackupFile(copy.fileName(), copy.createdAt()));
        }
        when(backupService.listBackups(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(files);
        when(copyStore.list()).thenReturn(copies);

        service.runScheduledBackup();

        for (int day : new int[]{20, 21, 22, 23}) {
            verify(backupService).deleteBackup(String.format("FULL_backup_auto_202610%02d_020000.sql", day));
            verify(copyStore).delete("id" + day);
        }
        verify(backupService, times(4)).deleteBackup(anyString());
        verify(copyStore, times(4)).delete(anyString());
    }

    @Test
    void aFileThatCannotBeDeletedDoesNotStopTheRestOfTheCleanUpOrFailTheBackup() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(true);
        List<BackupFile> files = new java.util.ArrayList<>();
        for (int day = 20; day <= 31; day++) {
            files.add(new BackupFile(copy("x", day).fileName(), copy("x", day).createdAt()));
        }
        when(backupService.listBackups(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(files);
        doThrow(new IllegalStateException("locked")).when(backupService).deleteBackup("FULL_backup_auto_20261020_020000.sql");

        service.runScheduledBackup();

        verify(backupService).deleteBackup("FULL_backup_auto_20261021_020000.sql");
        assertTrue(savedRun().isSuccess());
    }

    // -------------------------------------------------------------------------------------- restore from MongoDB

    private void downloadWrites(String content) throws IOException {
        doAnswer(call -> {
            Files.writeString(call.<Path>getArgument(1), content, StandardCharsets.UTF_8);
            return null;
        }).when(copyStore).downloadTo(any(BackupCopy.class), any(Path.class));
    }

    @Test
    void theNewestMongoCopyIsDownloadedItsChecksumCheckedAndThenTheExistingRestoreRuns() throws IOException {
        BackupCopy newest = copy("id31", 31);
        when(copyStore.list()).thenReturn(List.of(newest, copy("id30", 30)));
        downloadWrites(CONTENT);
        when(backupService.restoreDatabase(newest.fileName())).thenReturn(true);

        assertEquals(MongoRestoreOutcome.RESTORED, service.restoreFromMongo());

        verify(backupService).restoreDatabase(newest.fileName());
        assertEquals(CONTENT, Files.readString(folder.resolve(newest.fileName())));
        assertFalse(Files.exists(folder.resolve(newest.fileName() + BackupService.PARTIAL_SUFFIX)), "staged file renamed");
    }

    @Test
    void aCopyWhoseChecksumDoesNotMatchIsDeletedAndNeverRestored() throws IOException {
        BackupCopy newest = copy("id31", 31);
        when(copyStore.list()).thenReturn(List.of(newest));
        downloadWrites("abd");

        assertEquals(MongoRestoreOutcome.CHECKSUM_MISMATCH, service.restoreFromMongo());

        verify(backupService, never()).restoreDatabase(anyString());
        assertFalse(Files.exists(folder.resolve(newest.fileName())));
        assertFalse(Files.exists(folder.resolve(newest.fileName() + BackupService.PARTIAL_SUFFIX)));
    }

    @Test
    void aCopyWithoutAStoredChecksumIsNeverTrusted() throws IOException {
        BackupCopy noSum = new BackupCopy("id31", copy("id31", 31).fileName(), LocalDateTime.of(2026, 10, 31, 2, 0), 3, null);
        when(copyStore.list()).thenReturn(List.of(noSum));
        downloadWrites(CONTENT);

        assertEquals(MongoRestoreOutcome.CHECKSUM_MISMATCH, service.restoreFromMongo());

        verify(backupService, never()).restoreDatabase(anyString());
    }

    @Test
    void withoutAnyCopyNothingIsDownloadedOrRestored() throws IOException {
        when(copyStore.list()).thenReturn(List.of());

        assertEquals(MongoRestoreOutcome.NO_COPY, service.restoreFromMongo());

        verify(copyStore, never()).downloadTo(any(), any());
        verify(backupService, never()).restoreDatabase(anyString());
    }

    @Test
    void aMongoThatCannotBeReachedIsReportedNotThrown() {
        when(copyStore.list()).thenThrow(new IllegalStateException("mongo down"));

        assertEquals(MongoRestoreOutcome.STORE_UNAVAILABLE, service.restoreFromMongo());
    }

    @Test
    void aFailedDownloadLeavesNoPartialFileAndRestoresNothing() throws IOException {
        BackupCopy newest = copy("id31", 31);
        when(copyStore.list()).thenReturn(List.of(newest));
        doAnswer(call -> {
            Files.writeString(call.<Path>getArgument(1), "ab", StandardCharsets.UTF_8);
            throw new IOException("connection reset");
        }).when(copyStore).downloadTo(any(BackupCopy.class), any(Path.class));

        assertEquals(MongoRestoreOutcome.STORE_UNAVAILABLE, service.restoreFromMongo());

        assertFalse(Files.exists(folder.resolve(newest.fileName() + BackupService.PARTIAL_SUFFIX)));
        verify(backupService, never()).restoreDatabase(anyString());
    }

    @Test
    void aCopyWhoseNameIsNotAScheduledFullBackupNameIsRefusedBeforeAnythingIsWritten() throws IOException {
        BackupCopy odd = new BackupCopy("id", "../../etc/cron.d/x", LocalDateTime.of(2026, 10, 31, 2, 0), 3, CONTENT_SHA256);
        when(copyStore.list()).thenReturn(List.of(odd));

        assertEquals(MongoRestoreOutcome.INVALID_COPY, service.restoreFromMongo());

        verify(copyStore, never()).downloadTo(any(), any());
        verify(backupService, never()).restoreDatabase(anyString());
    }

    @Test
    void whenPgRestoreFailsTheOutcomeSaysSo() throws IOException {
        BackupCopy newest = copy("id31", 31);
        when(copyStore.list()).thenReturn(List.of(newest));
        downloadWrites(CONTENT);
        when(backupService.restoreDatabase(newest.fileName())).thenReturn(false);

        assertEquals(MongoRestoreOutcome.RESTORE_FAILED, service.restoreFromMongo());
    }

    @Test
    void theRestoreAsksForTheCopiesNewestFirstAndTakesTheFirst() throws IOException {
        BackupCopy older = copy("id30", 30);
        BackupCopy newer = copy("id31", 31);
        when(copyStore.list()).thenReturn(List.of(newer, older));
        downloadWrites(CONTENT);
        when(backupService.restoreDatabase(eq(newer.fileName()))).thenReturn(true);

        service.restoreFromMongo();

        verify(copyStore).downloadTo(eq(newer), any(Path.class));
        verify(copyStore, never()).downloadTo(eq(older), any(Path.class));
    }

    // ---------------------------------------------------------------------------------------------------- status

    @Test
    void theStatusShowsTheLastRunWithItsSizePlacesAndOutcome() {
        BackupRun last = BackupRun.builder().finishedAt(NOW).success(true).fileName(FILE).sizeBytes(2048L)
                .sha256(CONTENT_SHA256).onDisk(true).inMongo(true).build();
        when(runs.findFirstByOrderByFinishedAtDesc()).thenReturn(Optional.of(last));

        ScheduledBackupStatusDto status = service.latestStatus();

        assertTrue(status.enabled());
        assertEquals("0 0 2 * * *", status.cron());
        assertTrue(status.hasRun());
        assertTrue(status.success());
        assertEquals(NOW, status.lastRunAt());
        assertEquals(2048L, status.sizeBytes());
        assertTrue(status.onDisk());
        assertTrue(status.inMongo());
        assertNull(status.failureReason());
    }

    @Test
    void aFailedRunShowsItsReasonInWords() {
        BackupRun last = BackupRun.builder().finishedAt(NOW).success(false).failure(BackupFailure.NOT_READABLE).build();
        when(runs.findFirstByOrderByFinishedAtDesc()).thenReturn(Optional.of(last));

        ScheduledBackupStatusDto status = service.latestStatus();

        assertFalse(status.success());
        assertEquals(BackupFailure.NOT_READABLE.getLabel(), status.failureReason());
    }

    @Test
    void withoutAnyRunTheStatusSaysNoRunYet() {
        when(runs.findFirstByOrderByFinishedAtDesc()).thenReturn(Optional.empty());

        ScheduledBackupStatusDto status = service.latestStatus();

        assertFalse(status.hasRun());
        assertNull(status.lastRunAt());
    }

    @Test
    void ifTheRunsCannotBeReadTheStatusFallsBackToTheLastRunKnownInMemory() throws IOException {
        dumpCreatesTheFile();
        when(backupService.isReadable(FILE)).thenReturn(true);
        service.runScheduledBackup();
        when(runs.findFirstByOrderByFinishedAtDesc()).thenThrow(new IllegalStateException("mongo down"));

        ScheduledBackupStatusDto status = service.latestStatus();

        assertTrue(status.hasRun());
        assertTrue(status.success());
    }

    // ---------------------------------------------------------------------------- manual runs share the lock

    /** Holds the lock the way a running scheduled backup does, until the returned latch is released. */
    private CountDownLatch holdTheLockInAScheduledRun() throws InterruptedException {
        CountDownLatch inside = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenAnswer(invocation -> {
            inside.countDown();
            release.await(10, TimeUnit.SECONDS);
            return Optional.empty();
        });
        Thread holder = new Thread(service::runScheduledBackup);
        holder.setDaemon(true);
        holder.start();
        assertTrue(inside.await(10, TimeUnit.SECONDS));
        return release;
    }

    @Test
    void aManualBackupWhileTheScheduledOneRunsIsRefusedAndNothingIsDumped() throws InterruptedException {
        CountDownLatch release = holdTheLockInAScheduledRun();
        try {
            assertThrows(BackupInProgressException.class, () -> service.backupNow(BackupType.FULL));
            verify(backupService, never()).backupDatabase(any());
        } finally {
            release.countDown();
        }
    }

    @Test
    void aManualRestoreWhileTheScheduledOneRunsIsRefusedAndNothingIsRestored() throws InterruptedException {
        CountDownLatch release = holdTheLockInAScheduledRun();
        try {
            assertThrows(BackupInProgressException.class, () -> service.restoreLatestFullNow());
            verify(backupService, never()).restoreLatestFull();
        } finally {
            release.countDown();
        }
    }

    @Test
    void aManualBackupOnAFreeLockRunsOnceAndReturnsItsResult() {
        when(backupService.backupDatabase(BackupType.SCHEMA_ONLY)).thenReturn(true);

        assertTrue(service.backupNow(BackupType.SCHEMA_ONLY));

        verify(backupService, times(1)).backupDatabase(BackupType.SCHEMA_ONLY);
    }

    @Test
    void aManualRestoreOnAFreeLockRunsOnceAndReturnsItsResult() {
        when(backupService.restoreLatestFull()).thenReturn(false);

        assertFalse(service.restoreLatestFullNow());

        verify(backupService, times(1)).restoreLatestFull();
    }

    @Test
    void theLockIsReleasedWhenTheManualBackupThrows() {
        when(backupService.backupDatabase(BackupType.FULL)).thenThrow(new IllegalStateException("pg_dump"));
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.empty());

        assertThrows(IllegalStateException.class, () -> service.backupNow(BackupType.FULL));
        service.runScheduledBackup();

        verify(backupService).createBackup(BackupType.FULL, BackupOrigin.SCHEDULED);
    }

    @Test
    void theLockIsReleasedWhenTheManualRestoreThrows() {
        when(backupService.restoreLatestFull()).thenThrow(new IllegalStateException("pg_restore"));
        when(backupService.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED)).thenReturn(Optional.empty());

        assertThrows(IllegalStateException.class, () -> service.restoreLatestFullNow());
        service.runScheduledBackup();

        verify(backupService).createBackup(BackupType.FULL, BackupOrigin.SCHEDULED);
    }
}
