package vn.edu.huit.finance.core.Service.Backup;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.SimpleMongoClientDatabaseFactory;
import org.springframework.data.mongodb.repository.support.MongoRepositoryFactory;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Document.BackupRun;
import vn.edu.huit.finance.core.Entity.BackupFailure;
import vn.edu.huit.finance.core.Repository.Mongo.BackupRunRepository;
import vn.edu.huit.finance.core.Util.FileChecksum;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The MongoDB copy of the backups (GridFS) and the record of the runs on a real MongoDB 6 (Testcontainers). Skipped when
 * Docker is not there.
 */
@Testcontainers(disabledWithoutDocker = true)
class BackupMongoIntegrationTest {

    @Container
    private static final GenericContainer<?> MONGO = new GenericContainer<>("mongo:6.0").withExposedPorts(27017);

    private static MongoClient client;
    private static MongoTemplate template;
    private static GridFsBackupCopyStore store;
    private static BackupRunRepository runs;

    @TempDir private Path folder;

    @BeforeAll
    static void connect() {
        String uri = "mongodb://" + MONGO.getHost() + ":" + MONGO.getMappedPort(27017);
        client = MongoClients.create(uri);
        template = new MongoTemplate(new SimpleMongoClientDatabaseFactory(client, "backup_it_nosql"));
        store = new GridFsBackupCopyStore(client, template.getConverter());
        runs = new MongoRepositoryFactory(template).getRepository(BackupRunRepository.class);
    }

    @AfterAll
    static void disconnect() {
        client.close();
    }

    @BeforeEach
    void emptyEverything() {
        store.list().forEach(copy -> store.delete(copy.id()));
        runs.deleteAll();
    }

    private Path dump(String name, byte[] content) throws IOException {
        return Files.write(folder.resolve(name), content);
    }

    @Test
    void aFileIsStoredWithItsChecksumAndComesBackByteForByte() throws IOException {
        byte[] content = new byte[700_000];
        new Random(42).nextBytes(content);
        Path file = dump("FULL_backup_auto_20261101_020000.sql", content);
        String sha = FileChecksum.sha256(file);

        BackupCopy saved = store.save(file, file.getFileName().toString(), LocalDateTime.of(2026, 11, 1, 2, 0), sha);

        assertEquals(sha, saved.sha256());
        assertEquals(content.length, saved.sizeBytes());
        BackupCopy listed = store.list().get(0);
        assertEquals(saved.id(), listed.id());
        assertEquals("FULL_backup_auto_20261101_020000.sql", listed.fileName());
        assertEquals(LocalDateTime.of(2026, 11, 1, 2, 0), listed.createdAt());
        assertEquals(sha, listed.sha256());
        assertEquals(content.length, listed.sizeBytes());

        Path restored = folder.resolve("downloaded.sql");
        store.downloadTo(listed, restored);
        assertArrayEquals(content, Files.readAllBytes(restored));
        assertEquals(sha, FileChecksum.sha256(restored), "the downloaded file passes the stored checksum");
    }

    @Test
    void theListIsNewestFirstByTheTimeOfTheBackup() throws IOException {
        for (int day : new int[]{29, 31, 30}) {
            Path file = dump("FULL_backup_auto_202610" + day + "_020000.sql", ("dump " + day).getBytes(StandardCharsets.UTF_8));
            store.save(file, file.getFileName().toString(), LocalDateTime.of(2026, 10, day, 2, 0), FileChecksum.sha256(file));
        }

        List<BackupCopy> copies = store.list();

        assertEquals(List.of(31, 30, 29), copies.stream().map(copy -> copy.createdAt().getDayOfMonth()).toList());
    }

    @Test
    void deletingACopyRemovesItsFileAndItsChunksAndLeavesTheOthers() throws IOException {
        Path first = dump("FULL_backup_auto_20261030_020000.sql", "one".getBytes(StandardCharsets.UTF_8));
        Path second = dump("FULL_backup_auto_20261031_020000.sql", "two".getBytes(StandardCharsets.UTF_8));
        BackupCopy gone = store.save(first, first.getFileName().toString(), LocalDateTime.of(2026, 10, 30, 2, 0), FileChecksum.sha256(first));
        BackupCopy kept = store.save(second, second.getFileName().toString(), LocalDateTime.of(2026, 10, 31, 2, 0), FileChecksum.sha256(second));

        store.delete(gone.id());

        assertEquals(List.of(kept.id()), store.list().stream().map(BackupCopy::id).toList());
        long chunks = client.getDatabase(GridFsBackupCopyStore.DATABASE).getCollection(GridFsBackupCopyStore.BUCKET + ".chunks")
                .countDocuments();
        assertEquals(1, chunks, "the chunks of the deleted copy are gone too");
    }

    @Test
    void theCopiesLiveInTheirOwnDatabaseSoThatMongodumpOfTheOcrDataDoesNotCarryThem() throws IOException {
        Path file = dump("FULL_backup_auto_20261101_020000.sql", "x".getBytes(StandardCharsets.UTF_8));
        store.save(file, file.getFileName().toString(), LocalDateTime.of(2026, 11, 1, 2, 0), FileChecksum.sha256(file));

        List<String> collectionsOfTheOcrDatabase = template.getCollectionNames().stream().toList();

        assertFalse(collectionsOfTheOcrDatabase.stream().anyMatch(name -> name.startsWith(GridFsBackupCopyStore.BUCKET)));
        assertTrue(client.getDatabase(GridFsBackupCopyStore.DATABASE).listCollectionNames().into(new java.util.ArrayList<>())
                .contains(GridFsBackupCopyStore.BUCKET + ".files"));
    }

    @Test
    void theLastRunIsTheOneThatFinishedLast() {
        runs.save(BackupRun.builder().finishedAt(LocalDateTime.of(2026, 10, 30, 2, 1)).success(true).build());
        runs.save(BackupRun.builder().finishedAt(LocalDateTime.of(2026, 10, 31, 2, 1)).success(false)
                .failure(BackupFailure.NOT_READABLE).build());
        runs.save(BackupRun.builder().finishedAt(LocalDateTime.of(2026, 10, 29, 2, 1)).success(true).build());

        BackupRun last = runs.findFirstByOrderByFinishedAtDesc().orElseThrow();

        assertEquals(LocalDateTime.of(2026, 10, 31, 2, 1), last.getFinishedAt());
        assertFalse(last.isSuccess());
        assertEquals(BackupFailure.NOT_READABLE, last.getFailure());
    }
}
