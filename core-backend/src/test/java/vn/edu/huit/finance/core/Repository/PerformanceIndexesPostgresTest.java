package vn.edu.huit.finance.core.Repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.Container.ExecResult;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

import java.io.IOException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The two indexes of RB6 (transactions by user and date, receipts by status and creation time) on PostgreSQL 15: Hibernate
 * creates them on a new database (the deploy server), and {@code src/main/resources/db/indexes-migration.sql}, run the way
 * it is run on an old local database (the file itself, by psql, inside the container), creates the same ones and changes
 * nothing when run again. The old database is a schema-only copy of the one Hibernate made, without the two indexes. Cách
 * dựng container theo {@link SchemaEnumConstraintsPostgresTest}. Bị bỏ qua khi không có Docker.
 */
@DataJpaTest(properties = "spring.jpa.hibernate.ddl-auto=create")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class PerformanceIndexesPostgresTest {

    /** Keep in step with the db service of docker-compose.yml. */
    private static final String IMAGE = "postgres:15-alpine";
    private static final int PORT = 5432;
    private static final String DATABASE = "perf_indexes_it";
    private static final String USERNAME = "perf_indexes_it";
    private static final String PASSWORD = "integration-test-only";
    private static final String READY_LOG = ".*database system is ready to accept connections.*\\n";
    private static final int READY_LOG_TIMES = 2;

    private static final String MIGRATION = "db/indexes-migration.sql";
    private static final String MIGRATION_IN_CONTAINER = "/tmp/indexes-migration.sql";
    private static final String TRANSACTIONS_INDEX = "idx_transactions_user_date";
    private static final String RECEIPTS_INDEX = "idx_receipts_status_created";

    /** The definitions the two @Index entries must produce, and the migration must reproduce. */
    private static final List<String> EXPECTED_DEFINITIONS = List.of(
            "CREATE INDEX idx_receipts_status_created ON public.receipts USING btree (status, created_at)",
            "CREATE INDEX idx_transactions_user_date ON public.transactions USING btree (user_id, transaction_date)");

    /** Name, definition and the file behind each index: a rebuilt index gets a new file, so a re-run shows up here. */
    private static final String INDEXES = "select i.indexname || ' | ' || i.indexdef || ' | ' || c.relfilenode "
            + "from pg_indexes i join pg_class c on c.relname = i.indexname and c.relnamespace = 'public'::regnamespace "
            + "where i.schemaname = 'public' and i.indexname in ('" + TRANSACTIONS_INDEX + "', '" + RECEIPTS_INDEX + "') "
            + "order by i.indexname";
    private static final String DEFINITIONS = "select indexdef from pg_indexes where schemaname = 'public' "
            + "and indexname in ('" + TRANSACTIONS_INDEX + "', '" + RECEIPTS_INDEX + "') order by indexname";

    @Container
    private static final GenericContainer<?> POSTGRES = new GenericContainer<>(DockerImageName.parse(IMAGE))
            .withExposedPorts(PORT)
            .withEnv("POSTGRES_DB", DATABASE)
            .withEnv("POSTGRES_USER", USERNAME)
            .withEnv("POSTGRES_PASSWORD", PASSWORD)
            .waitingFor(Wait.forLogMessage(READY_LOG, READY_LOG_TIMES));

    @DynamicPropertySource
    static void postgres(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", () -> jdbcUrl(DATABASE));
        registry.add("spring.datasource.username", () -> USERNAME);
        registry.add("spring.datasource.password", () -> PASSWORD);
    }

    /** The database of the context, as Hibernate created it. */
    @Autowired private JdbcTemplate jdbc;

    private static String jdbcUrl(String database) {
        return "jdbc:postgresql://" + POSTGRES.getHost() + ":" + POSTGRES.getMappedPort(PORT) + "/" + database;
    }

    /** What an old local database looks like: the current schema, without the two indexes. */
    private JdbcTemplate databaseWithoutTheIndexes(String name) throws IOException, InterruptedException {
        jdbc.execute("drop database if exists " + name);
        jdbc.execute("create database " + name);
        ExecResult copy = POSTGRES.execInContainer("sh", "-c", String.format(
                "set -o pipefail; pg_dump -U %1$s -d %2$s --schema-only | psql -X -q -v ON_ERROR_STOP=1 -U %1$s -d %3$s",
                USERNAME, DATABASE, name));
        assertEquals(0, copy.getExitCode(), copy.getStderr());
        JdbcTemplate db = new JdbcTemplate(new DriverManagerDataSource(jdbcUrl(name), USERNAME, PASSWORD));
        db.execute("drop index " + TRANSACTIONS_INDEX);
        db.execute("drop index " + RECEIPTS_INDEX);
        return db;
    }

    /** Runs the file as the owner of the tables, requires it to succeed, and returns all psql printed (with the NOTICE). */
    private static String migrated(String database) throws IOException, InterruptedException {
        POSTGRES.copyFileToContainer(MountableFile.forClasspathResource(MIGRATION), MIGRATION_IN_CONTAINER);
        ExecResult result = POSTGRES.execInContainer("psql", "-X", "-v", "ON_ERROR_STOP=1", "-U", USERNAME, "-d", database,
                "-f", MIGRATION_IN_CONTAINER);
        assertEquals(0, result.getExitCode(), result.getStdout() + result.getStderr());
        assertFalse(result.getStderr().contains("ERROR"), result.getStderr());
        return result.getStdout() + result.getStderr();
    }

    @Test
    void hibernateCreatesBothIndexesOnANewDatabase() {
        assertEquals(EXPECTED_DEFINITIONS, jdbc.queryForList(DEFINITIONS, String.class));
    }

    @Test
    void theMigrationCreatesTheSameIndexesOnAnOldDatabase() throws Exception {
        JdbcTemplate db = databaseWithoutTheIndexes("perf_indexes_old");
        assertTrue(db.queryForList(DEFINITIONS, String.class).isEmpty());

        String output = migrated("perf_indexes_old");

        assertEquals(EXPECTED_DEFINITIONS, db.queryForList(DEFINITIONS, String.class));
        assertEquals(jdbc.queryForList(DEFINITIONS, String.class), db.queryForList(DEFINITIONS, String.class));
        assertTrue(output.contains("indexes-migration: ok indexes=2"), output);
    }

    @Test
    void aSecondRunChangesNothing() throws Exception {
        JdbcTemplate db = databaseWithoutTheIndexes("perf_indexes_twice");
        migrated("perf_indexes_twice");
        List<String> afterTheFirstRun = db.queryForList(INDEXES, String.class);
        assertEquals(2, afterTheFirstRun.size(), afterTheFirstRun.toString());

        migrated("perf_indexes_twice");

        assertEquals(afterTheFirstRun, db.queryForList(INDEXES, String.class));
    }

    @Test
    void theIndexesHibernateCreatedAreAcceptedAsTheyAre() throws Exception {
        List<String> before = jdbc.queryForList(INDEXES, String.class);
        assertEquals(2, before.size(), before.toString());

        migrated(DATABASE);

        assertEquals(before, jdbc.queryForList(INDEXES, String.class));
    }
}
