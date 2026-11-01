package vn.edu.huit.finance.core.Repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.dao.DataIntegrityViolationException;
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
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * The migration of the category owner (B8, {@code src/main/resources/db/category-owner-migration.sql}) on PostgreSQL 15,
 * the database of the deployment, run the way it will be run there: the file itself, by psql, inside the database
 * container. Each test makes a database of its own, shaped like an old one: the tables Hibernate creates for the current
 * mapping (taken from the database of the application context, {@link #DATABASE}) minus what B8 added, filled with
 * categories, and reads everything back with plain SQL:
 * <ul>
 *   <li>every old category stays, as a default (no owner) one, and a second run changes nothing;</li>
 *   <li>the migrated tables are what the current mapping defines, column by column and constraint by constraint;</li>
 *   <li>a name is unique per owner, not overall: two users can each have it, one user cannot have it twice, and the
 *       default categories cannot repeat it although SQL treats NULLs as distinct;</li>
 *   <li>an old database that already holds the same name twice (nothing prevented it) is still migrated, only without
 *       the uniqueness, and the script says so;</li>
 *   <li>a database where the build had already added the columns first (ddl-auto=update) is migrated all the same.</li>
 * </ul>
 * Skipped where Docker is not available. The container, its user and its databases exist nowhere else (see
 * ReceiptWorkflowMigrationPostgresTest, the model of this class).
 */
@DataJpaTest(properties = "spring.jpa.hibernate.ddl-auto=create")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class CategoryOwnerMigrationPostgresTest {

    /** Keep in step with the db service of docker-compose.yml. */
    private static final String IMAGE = "postgres:15-alpine";
    private static final int PORT = 5432;
    /** The database of the application context, where Hibernate creates the schema of the current mapping. */
    private static final String DATABASE = "category_migration_it";
    private static final String USERNAME = "category_migration_it";
    private static final String PASSWORD = "integration-test-only";
    /** The server logs this once while it initialises the data directory and once more when it really accepts clients. */
    private static final String READY_LOG = ".*database system is ready to accept connections.*\\n";
    private static final int READY_LOG_TIMES = 2;

    private static final String MIGRATION = "db/category-owner-migration.sql";
    private static final String MIGRATION_IN_CONTAINER = "/tmp/category-owner-migration.sql";
    private static final String NOTICE_PREFIX = "category-owner-migration:";

    private static final String CATEGORIES = "categories";
    private static final String CATEGORIES_AUDIT = "categories_aud";
    private static final String USERS = "users";
    private static final String EXPENSE = "EXPENSE";
    private static final String UNIQUE_PER_OWNER = "uk_categories_owner_name";

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

    /** The database of the context: the schema of the current mapping, as Hibernate created it. */
    @Autowired private JdbcTemplate jdbc;

    // ------------------------------------------------------------------------------------------------------------------
    // Building the databases
    // ------------------------------------------------------------------------------------------------------------------

    private static String jdbcUrl(String database) {
        return "jdbc:postgresql://" + POSTGRES.getHost() + ":" + POSTGRES.getMappedPort(PORT) + "/" + database;
    }

    /** An empty database of the container; every statement on it opens and closes a connection of its own. */
    private JdbcTemplate freshDatabase(String name) {
        jdbc.execute("drop database if exists " + name);
        jdbc.execute("create database " + name);
        return new JdbcTemplate(new DriverManagerDataSource(jdbcUrl(name), USERNAME, PASSWORD));
    }

    /**
     * The tables of an old database: those Hibernate creates for the current mapping (copied from the context's
     * database, with the tables their foreign keys point to), without the columns B8 added, and the categories a user
     * might have typed in before it: the default ones, and a few of their own that nobody can tell the author of.
     */
    private JdbcTemplate oldDatabase(String name) throws IOException, InterruptedException {
        JdbcTemplate db = freshDatabase(name);
        List<String> tables = new ArrayList<>(List.of(USERS, CATEGORIES, CATEGORIES_AUDIT));
        List<String> revisionTables = jdbc.queryForList("select distinct confrelid::regclass::text from pg_constraint "
                + "where contype = 'f' and conrelid = to_regclass('categories_aud')", String.class);
        tables.addAll(revisionTables);
        StringBuilder tableOptions = new StringBuilder();
        tables.stream().distinct().forEach(table -> tableOptions.append(" --table=").append(table));
        ExecResult copy = POSTGRES.execInContainer("sh", "-c", String.format(
                "set -o pipefail; pg_dump -U %1$s -d %2$s --schema-only%3$s | psql -X -q -v ON_ERROR_STOP=1 -U %1$s -d %4$s",
                USERNAME, DATABASE, tableOptions, name));
        assertEquals(0, copy.getExitCode(), copy.getStderr());
        db.execute("alter table categories drop column owner_id, drop column owner_key");
        db.execute("alter table categories_aud drop column owner_id");

        db.update("insert into categories (name, type) values ('Ăn uống', 'EXPENSE'), ('Tiết kiệm', 'EXPENSE'), "
                + "('Lương', 'INCOME'), ('Cafe sáng', 'EXPENSE'), ('Phở tối', 'EXPENSE')");
        // Every audit row belongs to a revision (Envers' revision table, whatever the mapping names it).
        String revisionTable = revisionTables.get(0);
        List<String> revisionColumns = jdbc.queryForList("select column_name from information_schema.columns where table_schema = 'public' "
                + "and table_name = ? and is_nullable = 'NO' and column_default is null", String.class, revisionTable);
        db.update("insert into " + revisionTable + " (" + String.join(", ", revisionColumns) + ") values ("
                + "1, ".repeat(revisionColumns.size() - 1) + "1)");
        db.update("insert into categories_aud (id, rev, revtype, name, type) select id, 1, 0, name, type from categories");
        return db;
    }

    private static long insertUser(JdbcTemplate db, String username) {
        return db.queryForObject("insert into users (username, password, email, phone, role, active, wallet_balance) "
                + "values (?, 'hash', ? || '@example.com', ?, 'ROLE_USER', true, 0) returning id", Long.class,
                username, username, "09" + Math.abs(username.hashCode() % 100_000_000));
    }

    // ------------------------------------------------------------------------------------------------------------------
    // Running the script
    // ------------------------------------------------------------------------------------------------------------------

    /** Runs the script as the owner of the tables, requires it to succeed, and returns all psql printed (with the NOTICEs). */
    private static String migrated(String database) throws IOException, InterruptedException {
        POSTGRES.copyFileToContainer(MountableFile.forClasspathResource(MIGRATION), MIGRATION_IN_CONTAINER);
        ExecResult result = POSTGRES.execInContainer("psql", "-X", "-v", "ON_ERROR_STOP=1", "-U", USERNAME, "-d", database,
                "-f", MIGRATION_IN_CONTAINER);
        assertEquals(0, result.getExitCode(), result.getStderr());
        assertFalse(result.getStderr().contains("ERROR"), result.getStderr());
        return result.getStdout() + result.getStderr();
    }

    private static String noticeOf(String output) {
        return output.lines().filter(line -> line.contains(NOTICE_PREFIX)).findFirst().orElse("");
    }

    // ------------------------------------------------------------------------------------------------------------------
    // Reading the databases back
    // ------------------------------------------------------------------------------------------------------------------

    /** One line per column: name, type, length, precision, scale, nullability, default. */
    private static List<String> columnsOf(JdbcTemplate db, String table) {
        return db.queryForList("""
                select format('%s %s length=%s precision=%s scale=%s datetime=%s nullable=%s default=%s', column_name,
                              data_type, coalesce(character_maximum_length::text, '-'), coalesce(numeric_precision::text, '-'),
                              coalesce(numeric_scale::text, '-'), coalesce(datetime_precision::text, '-'), is_nullable,
                              coalesce(column_default, '-'))
                  from information_schema.columns
                 where table_schema = 'public' and table_name = ?
                 order by column_name""", String.class, table);
    }

    private static List<String> constraintsOf(JdbcTemplate db, String table) {
        return db.queryForList("select conname || ': ' || pg_get_constraintdef(oid) from pg_constraint "
                + "where conrelid = to_regclass(?) order by conname", String.class, table);
    }

    private static List<String> indexesOf(JdbcTemplate db, String table) {
        return db.queryForList("select indexdef from pg_indexes where schemaname = 'public' and tablename = ? order by indexname",
                String.class, table);
    }

    /** Every row of the table, as JSON, in a stable order. */
    private static List<String> rowsOf(JdbcTemplate db, String table) {
        return db.queryForList("select row_to_json(t)::text from (select * from " + table + ") t order by 1", String.class);
    }

    /** Schema and rows of the two tables the script works on, for comparing a database before and after a run. */
    private static List<String> snapshotOf(JdbcTemplate db) {
        List<String> snapshot = new ArrayList<>();
        for (String table : List.of(CATEGORIES, CATEGORIES_AUDIT)) {
            snapshot.add(table + ":");
            snapshot.addAll(columnsOf(db, table));
            snapshot.addAll(constraintsOf(db, table));
            snapshot.addAll(indexesOf(db, table));
            snapshot.addAll(rowsOf(db, table));
        }
        return snapshot;
    }

    private static void insertCategory(JdbcTemplate db, String name, Long ownerId) {
        db.update("insert into categories (name, type, owner_id" + (ownerId == null ? "" : ", owner_key") + ") values (?, ?, ?"
                + (ownerId == null ? "" : ", ?") + ")", ownerId == null
                ? new Object[] {name, EXPENSE, null}
                : new Object[] {name, EXPENSE, ownerId, ownerId});
    }

    // ------------------------------------------------------------------------------------------------------------------
    // The tests
    // ------------------------------------------------------------------------------------------------------------------

    @Test
    void everyOldCategoryStaysAsADefaultOne_andASecondRunChangesNothing() throws Exception {
        JdbcTemplate db = oldDatabase("old_categories");
        List<String> namesBefore = db.queryForList("select name || '/' || type from categories order by id", String.class);

        String first = migrated("old_categories");

        assertEquals(namesBefore, db.queryForList("select name || '/' || type from categories order by id", String.class));
        assertEquals(5, db.queryForObject("select count(*) from categories where owner_id is null and owner_key = 0", Integer.class),
                "no old category has an owner, and every one is a default one");
        assertEquals(5, db.queryForObject("select count(*) from categories_aud", Integer.class), "no audit row is lost");
        assertTrue(first.contains(NOTICE_PREFIX + " categories=5 with_owner=0 duplicate_names=0"), first);
        List<String> afterTheFirstRun = snapshotOf(db);

        String second = migrated("old_categories");

        assertEquals(afterTheFirstRun, snapshotOf(db));
        assertEquals(noticeOf(first), noticeOf(second));
    }

    @Test
    void theMigratedTablesAreWhatTheCurrentMappingDefinesColumnByColumnAndConstraintByConstraint() throws Exception {
        JdbcTemplate db = oldDatabase("old_schema");

        migrated("old_schema");

        // Against the schema Hibernate creates for the entities today.
        assertEquals(columnsOf(jdbc, CATEGORIES), columnsOf(db, CATEGORIES));
        assertEquals(constraintsOf(jdbc, CATEGORIES), constraintsOf(db, CATEGORIES));
        assertEquals(indexesOf(jdbc, CATEGORIES), indexesOf(db, CATEGORIES));
        assertEquals(columnsOf(jdbc, CATEGORIES_AUDIT), columnsOf(db, CATEGORIES_AUDIT));

        // And spelled out, so that a change on both sides cannot pass unnoticed.
        assertEquals("owner_id bigint length=- precision=64 scale=0 datetime=- nullable=YES default=-",
                columnsOf(db, CATEGORIES).stream().filter(line -> line.startsWith("owner_id ")).findFirst().orElseThrow());
        assertEquals("owner_key bigint length=- precision=64 scale=0 datetime=- nullable=NO default=0",
                columnsOf(db, CATEGORIES).stream().filter(line -> line.startsWith("owner_key ")).findFirst().orElseThrow());
        assertTrue(constraintsOf(db, CATEGORIES).contains(
                "fk_categories_owner: FOREIGN KEY (owner_id) REFERENCES users(id)"), constraintsOf(db, CATEGORIES).toString());
        assertTrue(constraintsOf(db, CATEGORIES).contains(UNIQUE_PER_OWNER + ": UNIQUE (owner_key, name)"),
                constraintsOf(db, CATEGORIES).toString());
        assertTrue(indexesOf(db, CATEGORIES).stream().anyMatch(index -> index.contains("idx_categories_owner_id")),
                indexesOf(db, CATEGORIES).toString());
    }

    @Test
    void aNameIsUniquePerOwner_notOverall() throws Exception {
        JdbcTemplate db = oldDatabase("old_unique");
        migrated("old_unique");
        long alice = insertUser(db, "alice");
        long bob = insertUser(db, "bob");

        insertCategory(db, "Matcha", alice);
        insertCategory(db, "Matcha", bob);
        insertCategory(db, "Ăn uống", alice);

        assertThrows(DataIntegrityViolationException.class, () -> insertCategory(db, "Matcha", alice),
                "one user cannot have the same name twice");
        assertThrows(DataIntegrityViolationException.class, () -> insertCategory(db, "Ăn uống", null),
                "the default categories cannot repeat a name, although NULL owners are distinct in SQL");
        assertEquals(1, db.queryForObject("select count(*) from categories where name = 'Matcha' and owner_id = ?",
                Integer.class, alice));
    }

    @Test
    void aCategoryOfAUserCannotPointAtAUserWhoDoesNotExist() throws Exception {
        JdbcTemplate db = oldDatabase("old_foreign_key");
        migrated("old_foreign_key");

        assertThrows(DataIntegrityViolationException.class, () -> insertCategory(db, "Matcha", 987_654L));
    }

    @Test
    void anOldDatabaseWithTheSameNameTwice_isMigratedAllTheSame_withoutTheUniquenessAndTheScriptSaysSo() throws Exception {
        JdbcTemplate db = oldDatabase("old_duplicates");
        db.update("insert into categories (name, type) values ('Cafe sáng', 'EXPENSE')");

        String output = migrated("old_duplicates");

        assertTrue(output.contains(NOTICE_PREFIX + " categories=6 with_owner=0 duplicate_names=1"), output);
        assertEquals(0, db.queryForObject("select count(*) from pg_constraint where conname = ?", Integer.class, UNIQUE_PER_OWNER));
        assertEquals(6, db.queryForObject("select count(*) from categories", Integer.class), "no old category is merged or lost");
        assertEquals(1, db.queryForObject("select count(*) from information_schema.columns "
                + "where table_name = 'categories' and column_name = 'owner_id'", Integer.class));
        List<String> afterTheFirstRun = snapshotOf(db);

        assertEquals(noticeOf(output), noticeOf(migrated("old_duplicates")));
        assertEquals(afterTheFirstRun, snapshotOf(db));

        // The duplicate is removed by hand, as the script tells; the next run then adds the uniqueness.
        db.update("delete from categories where id = (select max(id) from categories where name = 'Cafe sáng')");
        migrated("old_duplicates");
        assertEquals(1, db.queryForObject("select count(*) from pg_constraint where conname = ?", Integer.class, UNIQUE_PER_OWNER));
    }

    @Test
    void aDatabaseTheNewBuildAlreadyAddedTheColumnsTo_isMigratedAllTheSame() throws Exception {
        JdbcTemplate db = oldDatabase("old_build_first");
        // What ddl-auto=update does when the new build starts before the script is run: the columns, nothing filled.
        db.execute("alter table categories add column owner_id bigint");
        db.execute("alter table categories add column owner_key bigint not null default 0");
        db.execute("alter table categories_aud add column owner_id bigint");

        migrated("old_build_first");

        assertEquals(columnsOf(jdbc, CATEGORIES), columnsOf(db, CATEGORIES));
        assertEquals(constraintsOf(jdbc, CATEGORIES), constraintsOf(db, CATEGORIES));
        assertEquals(indexesOf(jdbc, CATEGORIES), indexesOf(db, CATEGORIES));
    }

    @Test
    void aDatabaseWithoutAnAuditTableIsMigratedAndNoAuditTableIsCreated() throws Exception {
        JdbcTemplate db = oldDatabase("old_without_audit");
        db.execute("drop table categories_aud");

        migrated("old_without_audit");

        assertNull(db.queryForObject("select to_regclass('categories_aud')::text", String.class));
        assertEquals(columnsOf(jdbc, CATEGORIES), columnsOf(db, CATEGORIES));
    }
}
