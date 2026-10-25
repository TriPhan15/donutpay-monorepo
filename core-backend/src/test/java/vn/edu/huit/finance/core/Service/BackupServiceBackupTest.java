package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.BackupType;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/** Mỗi loại sao lưu chạy pg_dump với tham số riêng của nó. pg_dump là một script giả ghi lại tham số nhận được. */
@ExtendWith(MockitoExtension.class)
@EnabledOnOs({OS.LINUX, OS.MAC})
class BackupServiceBackupTest {

    @TempDir private Path pgBin;
    @TempDir private Path backups;
    @Mock private ApplicationEventPublisher eventPublisher;
    @InjectMocks private BackupService service;

    private Path argsFile;

    @BeforeEach
    void configure() {
        argsFile = pgBin.resolve("args.txt");
        ReflectionTestUtils.setField(service, "pgBinPath", pgBin.toString());
        ReflectionTestUtils.setField(service, "dbUser", "finance");
        ReflectionTestUtils.setField(service, "dbPassword", "test-only");
        ReflectionTestUtils.setField(service, "backupDir", backups + "/");
    }

    private void pgDumpExitsWith(int exitCode) throws IOException {
        Path script = pgBin.resolve("pg_dump");
        Files.writeString(script, "#!/bin/sh\nfor a in \"$@\"; do echo \"$a\"; done > '" + argsFile + "'\nexit " + exitCode + "\n");
        assertTrue(script.toFile().setExecutable(true));
    }

    private List<String> pgDumpArgs() throws IOException {
        return Files.readAllLines(argsFile);
    }

    @Test
    void aFullBackupDumpsSchemaAndData() throws IOException {
        pgDumpExitsWith(0);

        assertTrue(service.backupDatabase(BackupType.FULL));

        List<String> args = pgDumpArgs();
        assertFalse(args.contains("--schema-only"));
        assertFalse(args.contains("--data-only"));
        assertTrue(args.contains("-b"));
        assertEquals("finance_db", args.get(args.size() - 1));
    }

    @Test
    void aSchemaOnlyBackupDumpsNoRows() throws IOException {
        pgDumpExitsWith(0);

        assertTrue(service.backupDatabase(BackupType.SCHEMA_ONLY));

        assertTrue(pgDumpArgs().contains("--schema-only"));
        assertFalse(pgDumpArgs().contains("--data-only"));
    }

    @Test
    void aDataOnlyBackupDumpsNoTableDefinitions() throws IOException {
        pgDumpExitsWith(0);

        assertTrue(service.backupDatabase(BackupType.DATA_ONLY));

        assertTrue(pgDumpArgs().contains("--data-only"));
        assertFalse(pgDumpArgs().contains("--schema-only"));
    }

    @ParameterizedTest
    @EnumSource(BackupType.class)
    void theFileIsNamedAfterItsTypeSoOnlyAFullOneIsEverRestored(BackupType type) throws IOException {
        pgDumpExitsWith(0);

        service.backupDatabase(type);

        List<String> args = pgDumpArgs();
        String file = args.get(args.indexOf("-f") + 1);
        assertTrue(Path.of(file).getFileName().toString().startsWith(type.name() + "_backup_"), file);
        assertTrue(file.startsWith(backups.toString()), "inside the backup directory");
    }

    @Test
    void aBackupThatSucceededIsRecordedWithItsType() throws IOException {
        pgDumpExitsWith(0);

        service.backupDatabase(BackupType.SCHEMA_ONLY);

        ArgumentCaptor<SecurityAuditEvent> event = ArgumentCaptor.forClass(SecurityAuditEvent.class);
        verify(eventPublisher).publishEvent(event.capture());
        AuditEntry entry = event.getValue().entry();
        assertEquals(AuditAction.SYSTEM_BACKUP_CREATED, entry.action());
        assertEquals("Sao lưu cơ sở dữ liệu (loại: SCHEMA_ONLY - chỉ cấu trúc (schema))", entry.description());
        assertFalse(entry.description().contains("test-only"), "never the database password");
    }

    @Test
    void aBackupThatFailedIsNotRecorded() throws IOException {
        pgDumpExitsWith(1);

        assertFalse(service.backupDatabase(BackupType.FULL));

        verifyNoInteractions(eventPublisher);
    }

    @Test
    void theLatestBackupOfAnotherTypeIsNeverTakenForAFullOne() throws IOException {
        Files.createFile(backups.resolve("SCHEMA_ONLY_backup_20261025_120000.sql"));
        Files.createFile(backups.resolve("DATA_ONLY_backup_20261025_120000.sql"));

        assertNull(service.latestBackup(BackupType.FULL));
        assertFalse(service.restoreLatestFull());

        Files.createFile(backups.resolve("FULL_backup_20261025_110000.sql"));
        assertEquals("FULL_backup_20261025_110000.sql", service.latestBackup(BackupType.FULL));
    }

    // ---------------------------------------------------------------------------------- the type parameter of the page

    @Test
    void theTypeParameterIsReadIgnoringCaseAndSpaces() {
        assertEquals(Optional.of(BackupType.SCHEMA_ONLY), BackupType.fromParam(" schema_only "));
        assertEquals(Optional.of(BackupType.FULL), BackupType.fromParam("FULL"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"DIFF", "LOG", "", "../../etc/passwd", "FULL;rm"})
    void anUnknownTypeIsRefused_includingTheOldDifferentialAndLogButtons(String value) {
        assertTrue(BackupType.fromParam(value).isEmpty());
        assertTrue(BackupType.fromParam(null).isEmpty());
    }
}
