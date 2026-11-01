package vn.edu.huit.finance.core.Service.Backup;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.BackupOrigin;
import vn.edu.huit.finance.core.Entity.BackupType;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.BackupService;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * BackupService with the external tools behind {@link ExternalCommandRunner}: no real pg_dump or pg_restore runs here, so
 * the test runs on every operating system (the script-based BackupServiceBackupTest only on Linux and macOS).
 */
@ExtendWith(MockitoExtension.class)
class BackupServiceCommandTest {

    @TempDir private Path backups;
    @Mock private ApplicationEventPublisher eventPublisher;
    @Mock private ExternalCommandRunner runner;
    @InjectMocks private BackupService service;

    @BeforeEach
    void configure() {
        ReflectionTestUtils.setField(service, "pgBinPath", "");
        ReflectionTestUtils.setField(service, "dbUser", "finance");
        ReflectionTestUtils.setField(service, "dbPassword", "test-only");
        ReflectionTestUtils.setField(service, "backupDir", backups + "/");
    }

    @SuppressWarnings("unchecked")
    private List<String> lastCommand(boolean quiet) throws Exception {
        ArgumentCaptor<List<String>> command = ArgumentCaptor.forClass(List.class);
        if (quiet) verify(runner).runQuietly(command.capture(), anyMap());
        else verify(runner).run(command.capture(), anyMap());
        return command.getValue();
    }

    // ------------------------------------------------------------------------------------------------ createBackup

    @Test
    void aScheduledFullBackupIsDumpedToAFileNamedAutoAndItsNameIsReturned() throws Exception {
        when(runner.run(anyList(), anyMap())).thenReturn(0);

        Optional<String> name = service.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED);

        assertTrue(name.isPresent());
        assertTrue(name.get().matches("FULL_backup_auto_\\d{8}_\\d{6}\\.sql"), name.get());
        List<String> command = lastCommand(false);
        assertEquals("pg_dump", command.get(0));
        assertEquals(backups + "/" + name.get(), command.get(command.indexOf("-f") + 1));
        assertTrue(command.contains("-b"));
        assertFalse(command.contains("--schema-only"));
    }

    @Test
    void aManualBackupKeepsItsOldFileNameWithoutTheAutoMark() throws Exception {
        when(runner.run(anyList(), anyMap())).thenReturn(0);

        Optional<String> name = service.createBackup(BackupType.SCHEMA_ONLY, BackupOrigin.MANUAL);

        assertTrue(name.orElseThrow().matches("SCHEMA_ONLY_backup_\\d{8}_\\d{6}\\.sql"), name.get());
    }

    @Test
    @SuppressWarnings("unchecked")
    void thePasswordGoesToTheToolInTheEnvironmentOnlyNeverInTheArguments() throws Exception {
        when(runner.run(anyList(), anyMap())).thenReturn(0);

        service.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED);

        ArgumentCaptor<Map<String, String>> environment = ArgumentCaptor.forClass(Map.class);
        ArgumentCaptor<List<String>> command = ArgumentCaptor.forClass(List.class);
        verify(runner).run(command.capture(), environment.capture());
        assertEquals("test-only", environment.getValue().get("PGPASSWORD"));
        assertFalse(String.join(" ", command.getValue()).contains("test-only"));
    }

    @Test
    void aScheduledBackupIsRecordedAsDoneByTheSystemAndAManualOneByTheAdministratorWhoCalled() throws Exception {
        when(runner.run(anyList(), anyMap())).thenReturn(0);

        service.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED);
        service.createBackup(BackupType.FULL, BackupOrigin.MANUAL);

        ArgumentCaptor<SecurityAuditEvent> event = ArgumentCaptor.forClass(SecurityAuditEvent.class);
        verify(eventPublisher, times(2)).publishEvent(event.capture());
        AuditEntry scheduled = event.getAllValues().get(0).entry();
        AuditEntry manual = event.getAllValues().get(1).entry();
        assertEquals(AuditAction.SYSTEM_BACKUP_CREATED, scheduled.action());
        assertEquals(AuditActor.system(), scheduled.actor());
        assertEquals(AuditActor.currentCaller(), manual.actor());
        assertFalse(scheduled.description().contains("test-only"));
    }

    @Test
    void aDumpThatExitedWithAnErrorGivesNoFileNameAndNoAuditRow() throws Exception {
        when(runner.run(anyList(), anyMap())).thenReturn(1);

        assertTrue(service.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED).isEmpty());

        verifyNoInteractions(eventPublisher);
    }

    @Test
    void aToolThatCannotBeStartedIsAFailedBackupNotAnException() throws Exception {
        when(runner.run(anyList(), anyMap())).thenThrow(new IOException("pg_dump: not found"));

        assertTrue(service.createBackup(BackupType.FULL, BackupOrigin.SCHEDULED).isEmpty());

        verifyNoInteractions(eventPublisher);
    }

    @Test
    void theManualEntryPointStillAnswersWithABoolean() throws Exception {
        when(runner.run(anyList(), anyMap())).thenReturn(0, 1);

        assertTrue(service.backupDatabase(BackupType.FULL));
        assertFalse(service.backupDatabase(BackupType.FULL));
    }

    // -------------------------------------------------------------------------------------------------- isReadable

    @Test
    void aBackupIsReadableWhenPgRestoreCanListIt() throws Exception {
        when(runner.runQuietly(anyList(), anyMap())).thenReturn(0);

        assertTrue(service.isReadable("FULL_backup_auto_20261101_020000.sql"));

        List<String> command = lastCommand(true);
        assertEquals("pg_restore", command.get(0));
        assertTrue(command.contains("--list"));
        assertEquals(backups + "/FULL_backup_auto_20261101_020000.sql", command.get(command.size() - 1));
    }

    @Test
    void aBackupPgRestoreCannotListIsNotReadable() throws Exception {
        when(runner.runQuietly(anyList(), anyMap())).thenReturn(1);

        assertFalse(service.isReadable("FULL_backup_auto_20261101_020000.sql"));
    }

    @Test
    void ifPgRestoreCannotBeStartedTheBackupCountsAsNotReadable() throws Exception {
        when(runner.runQuietly(anyList(), anyMap())).thenThrow(new IOException("not found"));

        assertFalse(service.isReadable("FULL_backup_auto_20261101_020000.sql"));
    }

    // -------------------------------------------------------------------------------------------- files of the folder

    @Test
    void theListOfBackupsHoldsOnlyTheRequestedTypeAndOriginWithTheTimeInTheirName() throws IOException {
        Files.createFile(backups.resolve("FULL_backup_auto_20261030_020000.sql"));
        Files.createFile(backups.resolve("FULL_backup_auto_20261031_020000.sql"));
        Files.createFile(backups.resolve("FULL_backup_20261031_110000.sql"));
        Files.createFile(backups.resolve("SCHEMA_ONLY_backup_auto_20261031_020000.sql"));
        Files.createFile(backups.resolve("FULL_backup_auto_20261031_020000.sql.partial"));
        Files.createFile(backups.resolve("notes.txt"));

        List<BackupFile> scheduled = service.listBackups(BackupType.FULL, BackupOrigin.SCHEDULED);
        List<BackupFile> manual = service.listBackups(BackupType.FULL, BackupOrigin.MANUAL);

        assertEquals(List.of("FULL_backup_auto_20261030_020000.sql", "FULL_backup_auto_20261031_020000.sql"),
                scheduled.stream().map(BackupFile::name).sorted().toList());
        assertEquals(LocalDateTime.of(2026, 10, 30, 2, 0),
                scheduled.stream().filter(f -> f.name().contains("1030")).findFirst().orElseThrow().createdAt());
        assertEquals(List.of("FULL_backup_20261031_110000.sql"), manual.stream().map(BackupFile::name).toList());
    }

    @Test
    void anAutoBackupIsStillTheLatestFullOneForTheRestoreOfTheNewestBackup() throws IOException {
        Path older = Files.createFile(backups.resolve("FULL_backup_20261030_110000.sql"));
        Path newer = Files.createFile(backups.resolve("FULL_backup_auto_20261031_020000.sql"));
        assertTrue(older.toFile().setLastModified(1_000_000L));
        assertTrue(newer.toFile().setLastModified(2_000_000L));

        assertEquals("FULL_backup_auto_20261031_020000.sql", service.latestBackup(BackupType.FULL));
    }

    @Test
    void deletingABackupRemovesItsFileOnly() throws IOException {
        Path keep = Files.createFile(backups.resolve("FULL_backup_auto_20261031_020000.sql"));
        Path drop = Files.createFile(backups.resolve("FULL_backup_auto_20261030_020000.sql"));

        assertTrue(service.deleteBackup("FULL_backup_auto_20261030_020000.sql"));

        assertFalse(Files.exists(drop));
        assertTrue(Files.exists(keep));
        assertFalse(service.deleteBackup("FULL_backup_auto_20261030_020000.sql"), "already gone");
    }

    @Test
    void aNameThatLeavesTheBackupFolderIsRefused() {
        assertThrows(IllegalArgumentException.class, () -> service.resolveBackupFile("../secret.sql"));
        assertThrows(IllegalArgumentException.class, () -> service.resolveBackupFile("sub/FULL_backup_20261031_020000.sql"));
        assertThrows(IllegalArgumentException.class, () -> service.deleteBackup("..\\secret.sql"));
        assertEquals(backups.resolve("FULL_backup_auto_20261031_020000.sql").toAbsolutePath().normalize(),
                service.resolveBackupFile("FULL_backup_auto_20261031_020000.sql").toAbsolutePath().normalize());
    }
}
