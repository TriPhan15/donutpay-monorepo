package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/** MongoDB backups and restores through mongodump / mongorestore, which are fake scripts that record their arguments. */
@ExtendWith(MockitoExtension.class)
@EnabledOnOs({OS.LINUX, OS.MAC})
class MongoBackupServiceTest {

    private static final String URI = "mongodb://admin:s3cret-pw@mongodb:27017/finance_nosql?authSource=admin";

    @TempDir private Path bin;
    @TempDir private Path backups;
    @Mock private ApplicationEventPublisher eventPublisher;
    @InjectMocks private MongoBackupService service;

    private Path argsFile;

    @BeforeEach
    void configure() {
        argsFile = bin.resolve("args.txt");
        ReflectionTestUtils.setField(service, "mongoBinPath", bin.toString());
        ReflectionTestUtils.setField(service, "mongoUri", URI);
        ReflectionTestUtils.setField(service, "backupDir", backups + "/");
    }

    private Path configCopy;

    /** A fake tool: records its arguments, keeps a copy of the --config file (and its permissions), then exits. */
    private void tool(String name, int exitCode, String output) throws IOException {
        toolScript(name, "echo '" + output + "'\nexit " + exitCode + "\n");
    }

    private void toolScript(String name, String tail) throws IOException {
        configCopy = bin.resolve("config-copy.yml");
        Path script = bin.resolve(name);
        Files.writeString(script, "#!/bin/sh\nfor a in \"$@\"; do echo \"$a\"; done > '" + argsFile + "'\n"
                + "for a in \"$@\"; do case \"$a\" in --config=*) f=\"${a#--config=}\"; cp \"$f\" '" + configCopy + "';"
                + " stat -c %a \"$f\" > '" + bin.resolve("config-mode.txt") + "';; esac; done\n" + tail);
        assertTrue(script.toFile().setExecutable(true));
    }

    private static final Path CONFIG = Path.of("/tmp/c.yml");

    /** The URI the tools get: a database in it would make mongorestore ignore --nsInclude (found in the container test). */
    private static final String TOOL_URI = "mongodb://admin:s3cret-pw@mongodb:27017/?authSource=admin";

    @Test
    void theToolUriLosesItsDatabaseAndKeepsEverythingElse() {
        assertEquals(TOOL_URI, MongoBackupService.withoutDatabase(URI));
        assertEquals("mongodb://h1,h2/?rs=x", MongoBackupService.withoutDatabase("mongodb://h1,h2/finance_nosql?rs=x"));
        assertEquals("mongodb://h1/", MongoBackupService.withoutDatabase("mongodb://h1/db"));
        assertEquals("mongodb://u:p@h:1", MongoBackupService.withoutDatabase("mongodb://u:p@h:1"));
        assertEquals("mongodb://u:p@h:1/?a=b", MongoBackupService.withoutDatabase("mongodb://u:p@h:1/?a=b"));
    }

    @Test
    void credentialsWithoutAuthSourceKeepAuthenticatingAgainstThePathDatabase() {
        assertEquals("mongodb://u:p@h:1/?a=b&c=d&authSource=db", MongoBackupService.withoutDatabase("mongodb://u:p@h:1/db?a=b&c=d"));
        assertEquals("mongodb://u:p@h:1/?authSource=db", MongoBackupService.withoutDatabase("mongodb://u:p@h:1/db"));
        assertEquals("mongodb://u:p@h:1/?AUTHSOURCE=x", MongoBackupService.withoutDatabase("mongodb://u:p@h:1/db?AUTHSOURCE=x"));
        assertEquals("mongodb://h:1/?a=b", MongoBackupService.withoutDatabase("mongodb://h:1/db?a=b"), "no credentials: nothing to add");
    }

    @Test
    void theConfigHoldsTheUriQuotedForYaml() {
        assertEquals("uri: \"" + TOOL_URI + "\"\n", MongoBackupService.configContent(URI));
        assertEquals("uri: \"mongodb://u:a\\\"b@h/?authSource=db\"\n", MongoBackupService.configContent("mongodb://u:a\"b@h/db"));
    }

    @Test
    void theDumpCommandHasExactlyTheDocumentedArgumentsAndNoUri() {
        List<String> command = service.mongoDumpCommand("/x/mongo_1.archive.gz", CONFIG);
        assertEquals(List.of(bin + "/mongodump", "--config=/tmp/c.yml", "--db=finance_nosql",
                "--archive=/x/mongo_1.archive.gz", "--gzip"), command);
        assertTrue(command.stream().noneMatch(a -> a.contains("--uri") || a.contains("s3cret-pw")));
    }

    @Test
    void theRestoreCommandDropsAndRestoresOnlyTheTwoCollectionsAndHasNoUri() {
        List<String> command = service.mongoRestoreCommand("/x/mongo_1.archive.gz", CONFIG);
        assertEquals(List.of(bin + "/mongorestore", "--config=/tmp/c.yml", "--archive=/x/mongo_1.archive.gz", "--gzip",
                "--drop", "--nsInclude=finance_nosql.ocr_logs", "--nsInclude=finance_nosql.ocr_feedbacks"), command);
        assertTrue(command.stream().noneMatch(a -> a.contains("--uri") || a.contains("s3cret-pw")));
    }

    @Test
    void theToolReadsTheUriFromAnOwnerOnlyConfigThatIsDeletedAfterwards() throws IOException {
        tool("mongodump", 0, "done");

        assertTrue(service.backup());

        List<String> args = Files.readAllLines(argsFile);
        assertTrue(args.stream().noneMatch(a -> a.contains("--uri") || a.contains("s3cret-pw")), args.toString());
        assertEquals("uri: \"" + TOOL_URI + "\"\n", Files.readString(configCopy));
        assertEquals("600", Files.readString(bin.resolve("config-mode.txt")).trim());
        String path = args.stream().filter(a -> a.startsWith("--config=")).findFirst().orElseThrow().substring(9);
        assertFalse(Files.exists(Path.of(path)), "the config is deleted after the run");
    }

    @Test
    void theConfigIsDeletedAlsoWhenTheToolFails() throws IOException {
        tool("mongodump", 1, "failed");

        assertFalse(service.backup());

        String path = Files.readAllLines(argsFile).stream().filter(a -> a.startsWith("--config=")).findFirst().orElseThrow().substring(9);
        assertFalse(Files.exists(Path.of(path)));
    }

    @Test
    void aSecondCallWhileOneRunsIsRefusedWithoutRunningAnyTool() throws Exception {
        java.util.concurrent.locks.ReentrantLock lock = (java.util.concurrent.locks.ReentrantLock) ReflectionTestUtils.getField(service, "running");
        java.util.concurrent.CountDownLatch held = new java.util.concurrent.CountDownLatch(1);
        java.util.concurrent.CountDownLatch release = new java.util.concurrent.CountDownLatch(1);
        Thread other = new Thread(() -> {
            lock.lock();
            held.countDown();
            try { release.await(); } catch (InterruptedException ignored) { } finally { lock.unlock(); }
        });
        other.start();
        assertTrue(held.await(5, java.util.concurrent.TimeUnit.SECONDS));
        try {
            tool("mongodump", 0, "done");
            Files.createFile(backups.resolve("mongo_20261026_100000.archive.gz"));
            assertThrows(MongoBackupService.BusyException.class, service::backup);
            assertThrows(MongoBackupService.BusyException.class, service::restoreLatest);
            assertFalse(Files.exists(argsFile), "no tool was started");
            verifyNoInteractions(eventPublisher);
        } finally {
            release.countDown();
            other.join();
        }
        assertTrue(service.backup(), "the lock is free again");
    }

    @Test
    void aToolThatOutlastsTheTimeoutIsKilledAndCountsAsFailed() throws IOException {
        ReflectionTestUtils.setField(service, "toolTimeoutMillis", 300L);
        toolScript("mongodump", "sleep 30\nexit 0\n");

        long start = System.nanoTime();
        assertFalse(service.backup());

        assertTrue(java.util.concurrent.TimeUnit.NANOSECONDS.toSeconds(System.nanoTime() - start) < 10, "did not wait for sleep 30");
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void withoutABinPathTheToolsAreFoundOnThePath() {
        ReflectionTestUtils.setField(service, "mongoBinPath", "");
        assertEquals("mongodump", service.mongoDumpCommand("f", CONFIG).get(0));
        assertEquals("mongorestore", service.mongoRestoreCommand("f", CONFIG).get(0));
    }

    @Test
    void theUriPasswordIsMasked() {
        assertEquals("mongodb://admin:****@mongodb:27017/finance_nosql?authSource=admin", MongoBackupService.maskUri(URI));
        assertEquals("mongodb+srv://u:****@h/db", MongoBackupService.maskUri("mongodb+srv://u:p%40ss@h/db"));
        assertEquals("mongodb://localhost:27017/x", MongoBackupService.maskUri("mongodb://localhost:27017/x"));
        assertEquals("a mongodb://admin:****@h b", MongoBackupService.maskUri("a mongodb://admin:pw@h b"));
        assertNull(MongoBackupService.maskUri(null));
    }

    @Test
    void aBackupThatSucceededWritesAnArchiveNameAndIsRecordedOnce() throws IOException {
        tool("mongodump", 0, "done");

        assertTrue(service.backup());

        List<String> args = Files.readAllLines(argsFile);
        String archive = args.stream().filter(a -> a.startsWith("--archive=")).findFirst().orElseThrow();
        assertTrue(archive.startsWith("--archive=" + backups + "/mongo_") && archive.endsWith(".archive.gz"), archive);
        ArgumentCaptor<SecurityAuditEvent> event = ArgumentCaptor.forClass(SecurityAuditEvent.class);
        verify(eventPublisher).publishEvent(event.capture());
        AuditEntry entry = event.getValue().entry();
        assertEquals(AuditAction.MONGO_BACKUP_CREATED, entry.action());
        assertFalse(entry.description().contains("s3cret-pw"));
    }

    @Test
    void aBackupThatFailedIsNotRecorded() throws IOException {
        tool("mongodump", 1, "error connecting to " + URI);

        assertFalse(service.backup());

        verifyNoInteractions(eventPublisher);
    }

    @Test
    void aMissingToolIsAFailureNotAnException() {
        assertFalse(service.backup());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void theLatestBackupIsTheNewestMongoArchive() throws IOException {
        assertNull(service.latestBackup());
        Files.createFile(backups.resolve("FULL_backup_20261026_120000.sql"));
        Files.createFile(backups.resolve("mongo_20261025_090000.archive.gz"));
        Files.createFile(backups.resolve("mongo_20261026_100000.archive.gz"));
        Files.createFile(backups.resolve("mongo_20261024_100000.archive.gz"));
        Files.createFile(backups.resolve("mongo_20261026_100000.archive.gz.tmp"));

        assertEquals("mongo_20261026_100000.archive.gz", service.latestBackup());
    }

    @Test
    void restoreWithoutAnyArchiveFailsWithoutRunningAnything() {
        assertFalse(service.restoreLatest());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void aRestoreThatSucceededIsRecordedWithTheFileName() throws IOException {
        Files.createFile(backups.resolve("mongo_20261026_100000.archive.gz"));
        tool("mongorestore", 0, "ok");

        assertTrue(service.restoreLatest());

        List<String> args = Files.readAllLines(argsFile);
        assertTrue(args.contains("--archive=" + backups + "/mongo_20261026_100000.archive.gz"));
        ArgumentCaptor<SecurityAuditEvent> event = ArgumentCaptor.forClass(SecurityAuditEvent.class);
        verify(eventPublisher).publishEvent(event.capture());
        assertEquals(AuditAction.MONGO_RESTORED, event.getValue().entry().action());
        assertTrue(event.getValue().entry().description().contains("mongo_20261026_100000.archive.gz"));
    }

    @Test
    void aRestoreThatFailedIsNotRecorded() throws IOException {
        Files.createFile(backups.resolve("mongo_20261026_100000.archive.gz"));
        tool("mongorestore", 1, "failed");

        assertFalse(service.restoreLatest());

        verifyNoInteractions(eventPublisher);
    }
}
