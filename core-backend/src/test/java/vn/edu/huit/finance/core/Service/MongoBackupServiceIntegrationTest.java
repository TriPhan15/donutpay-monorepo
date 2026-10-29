package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.testcontainers.containers.Container.ExecResult;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.images.builder.Transferable;
import org.testcontainers.utility.DockerImageName;

import java.io.IOException;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * The exact argument lists MongoBackupService builds, run by the mongodump / mongorestore of a mongo:6.0 container (the
 * host has no database tools). The container, its user and data exist nowhere else. Skipped where Docker is missing.
 */
@Testcontainers(disabledWithoutDocker = true)
class MongoBackupServiceIntegrationTest {

    private static final String USER = "root";
    private static final String PASSWORD = "integration-test-only";
    private static final String ARCHIVE = "/tmp/mongo_20261027_120000.archive.gz";

    @Container
    private static final GenericContainer<?> MONGO = new GenericContainer<>(DockerImageName.parse("mongo:6.0"))
            .withEnv("MONGO_INITDB_ROOT_USERNAME", USER)
            .withEnv("MONGO_INITDB_ROOT_PASSWORD", PASSWORD)
            .withExposedPorts(27017)
            .waitingFor(Wait.forLogMessage(".*Waiting for connections.*\\n", 2));

    private static final String CONFIG_IN_CONTAINER = "/tmp/mongo-tools.yml";
    private static final String URI = "mongodb://" + USER + ":" + PASSWORD
            + "@localhost:27017/finance_nosql?authSource=admin&serverSelectionTimeoutMS=5000&connectTimeoutMS=5000";

    private static MongoBackupService service;

    @BeforeAll
    static void service() {
        service = new MongoBackupService();
        // The same shape as the MONGO_URI of docker-compose.yml, reaching the server from inside its own container.
        ReflectionTestUtils.setField(service, "mongoUri", URI);
        // The config file the service writes on the host, here copied into the container the tools run in.
        MONGO.copyFileToContainer(Transferable.of(MongoBackupService.configContent(URI)), CONFIG_IN_CONTAINER);
        ReflectionTestUtils.setField(service, "mongoBinPath", "");
    }

    private static ExecResult run(List<String> command) throws IOException, InterruptedException {
        return MONGO.execInContainer(command.toArray(new String[0]));
    }

    private static String shell(String js) throws IOException, InterruptedException {
        ExecResult result = run(List.of("mongosh", "--quiet", "-u", USER, "-p", PASSWORD, "--authenticationDatabase", "admin",
                "--eval", js));
        assertEquals(0, result.getExitCode(), result.getStderr());
        return result.getStdout().trim();
    }

    private static String count(String collection) throws IOException, InterruptedException {
        return shell("db.getSiblingDB('finance_nosql')." + collection + ".countDocuments()");
    }

    @Test
    void dumpDropAndRestoreBringBackTheTwoCollectionsAndTouchNothingElse() throws Exception {
        shell("const d = db.getSiblingDB('finance_nosql');"
                + "d.ocr_logs.drop(); d.ocr_feedbacks.drop(); d.other_data.drop();"
                + "d.ocr_logs.insertMany([{a:1},{a:2},{a:3}]); d.ocr_feedbacks.insertMany([{b:1},{b:2}]);"
                + "d.other_data.insertOne({keep:'before'});");

        ExecResult dump = run(service.mongoDumpCommand(ARCHIVE, Path.of(CONFIG_IN_CONTAINER)));
        assertEquals(0, dump.getExitCode(), dump.getStderr());

        // Changed after the dump: rows lost or added in the two collections, and a collection the restore must not touch.
        shell("const d = db.getSiblingDB('finance_nosql');"
                + "d.ocr_logs.deleteMany({}); d.ocr_feedbacks.insertOne({b:99}); d.other_data.insertOne({keep:'after'});");

        ExecResult restore = run(service.mongoRestoreCommand(ARCHIVE, Path.of(CONFIG_IN_CONTAINER)));
        assertEquals(0, restore.getExitCode(), restore.getStderr());

        assertEquals("3", count("ocr_logs"));
        assertEquals("2", count("ocr_feedbacks"), "--drop replaced the collection with the archive's");
        assertEquals("2", count("other_data"), "a third collection survives the restore");
    }
}
