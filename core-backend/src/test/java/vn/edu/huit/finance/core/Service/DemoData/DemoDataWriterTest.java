package vn.edu.huit.finance.core.Service.DemoData;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.AopTestUtils;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.NotificationType;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.AuditLogService;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The demo seed on H2, through the real @Transactional proxy (nothing here runs in a test transaction, so every check
 * reads what was committed): what it writes, that the wallets add up, and that it never writes into a database that
 * already has users.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "app.seed.demo=true"})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Import({DemoDataWriter.class, AuditLogService.class, DemoDataWriterTest.Passwords.class})
class DemoDataWriterTest {

    private static final String ADMIN_PASSWORD = "Admin2026x";
    private static final String DEMO_PASSWORD = "Demo2026a";
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 21, 20, 0);
    private static final ZoneId ZONE = ZoneId.systemDefault();
    private static final int OFFICE_WORKER_BUDGETS = 3;
    private static final int STUDENT_BUDGETS = 2;
    private static final int GOALS = 5;

    @TestConfiguration
    static class Passwords {
        @Bean
        PasswordEncoder passwordEncoder() {
            return new BCryptPasswordEncoder();
        }
    }

    @Autowired private DemoDataWriter writer;
    @Autowired private JdbcTemplate jdbc;
    @Autowired private PasswordEncoder passwordEncoder;
    @MockBean private CurrentUserProvider currentUserProvider;

    @BeforeEach
    void fixToday() {
        DemoDataWriter target = AopTestUtils.getTargetObject(writer);
        ReflectionTestUtils.setField(target, "clock", Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE));
    }

    @AfterEach
    void emptyEveryTable() {
        List<String> tables = jdbc.queryForList(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC'", String.class);
        jdbc.execute("SET REFERENTIAL_INTEGRITY FALSE");
        tables.forEach(table -> jdbc.execute("TRUNCATE TABLE " + table));
        jdbc.execute("SET REFERENTIAL_INTEGRITY TRUE");
    }

    @Test
    void anEmptyDatabaseIsSeeded_andTheResultTellsWhatWasWritten() {
        DemoSeedResult result = seed();

        assertThat(result.seeded()).isTrue();
        assertThat(result.userCount()).isEqualTo(count("users"));
        assertThat(result.transactionCount()).isEqualTo(count("transactions")).isBetween(2_000, 10_000);
        assertThat(result.receipts()).hasSize(count("receipts"));
    }

    @Test
    void everyWalletEqualsIncomeMinusExpensesOfItsTransactions() {
        seed();

        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT u.username, u.wallet_balance,
                       COALESCE(SUM(CASE WHEN t.is_expense THEN -t.amount ELSE t.amount END), 0) AS total
                FROM users u LEFT JOIN transactions t ON t.user_id = u.id
                GROUP BY u.id, u.username, u.wallet_balance""");
        assertThat(rows).hasSize(count("users")).allSatisfy(row -> {
            BigDecimal wallet = (BigDecimal) row.get("WALLET_BALANCE");
            assertThat(wallet).as("wallet of %s", row.get("USERNAME")).isNotNegative()
                    .isEqualByComparingTo((BigDecimal) row.get("TOTAL"));
        });
    }

    @Test
    void theDefaultCategoriesExistWithTheirType() {
        seed();

        Map<String, String> types = jdbc.query("SELECT name, type FROM categories", rs -> {
            Map<String, String> byName = new HashMap<>();
            while (rs.next()) {
                byName.put(rs.getString("name"), rs.getString("type"));
            }
            return byName;
        });
        assertThat(types).hasSize(DefaultCategory.values().length);
        assertThat(DefaultCategory.values()).allSatisfy(category ->
                assertThat(types).containsEntry(category.getDisplayName(), category.getType()));
    }

    @Test
    void onlyTheAdminAndTheTwoDemoAccountsCanSignIn() {
        seed();

        List<Map<String, Object>> users = jdbc.queryForList("SELECT username, password, role FROM users");
        assertThat(users).allSatisfy(user -> {
            String username = (String) user.get("USERNAME");
            String hash = (String) user.get("PASSWORD");
            boolean admin = DemoDataWriter.ADMIN_USERNAME.equals(username);
            boolean demo = DemoDataGenerator.OFFICE_WORKER_USERNAME.equals(username)
                    || DemoDataGenerator.STUDENT_USERNAME.equals(username);
            assertThat(user.get("ROLE")).isEqualTo(admin ? Roles.ADMIN : Roles.USER);
            assertThat(passwordEncoder.matches(ADMIN_PASSWORD, hash)).as(username).isEqualTo(admin);
            assertThat(passwordEncoder.matches(DEMO_PASSWORD, hash)).as(username).isEqualTo(demo);
        });
    }

    @Test
    void theDemoAccountsHaveReceiptsInEveryStatusOfTheLifecycle_eachWithItsFirstReading() {
        seed();

        List<String> statuses = jdbc.queryForList("""
                SELECT r.status FROM receipts r
                JOIN transactions t ON t.receipt_id = r.id JOIN users u ON u.id = t.user_id
                WHERE u.username = ?""", String.class, DemoDataGenerator.OFFICE_WORKER_USERNAME);
        assertThat(statuses).containsExactlyInAnyOrder(ReceiptStatus.COMPLETED_RAW.name(), ReceiptStatus.EDITED.name(),
                ReceiptStatus.FAILED.name(), ReceiptStatus.WAITING_FOR_REVIEW.name(), ReceiptStatus.APPROVED.name());
        assertThat(count("receipt_processing_attempts")).isEqualTo(count("receipts"));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM transactions WHERE receipt_id IS NOT NULL", Integer.class))
                .isEqualTo(count("receipts"));
    }

    @Test
    void theOfficeWorkersFoodBudgetHasPassedTheWarningLevel_andTheyWereNotified() {
        seed();

        assertThat(budgetsOf(DemoDataGenerator.OFFICE_WORKER_USERNAME)).isEqualTo(OFFICE_WORKER_BUDGETS);
        assertThat(budgetsOf(DemoDataGenerator.STUDENT_USERNAME)).isEqualTo(STUDENT_BUDGETS);
        assertThat(count("budgets")).isEqualTo(OFFICE_WORKER_BUDGETS + STUDENT_BUDGETS);

        Map<String, Object> food = jdbc.queryForMap("""
                SELECT b.id, b.amount,
                       (SELECT SUM(t.amount) FROM transactions t WHERE t.user_id = b.user_id AND t.is_expense
                          AND t.category_id = b.category_id
                          AND CAST(t.transaction_date AS DATE) BETWEEN b.start_date AND b.end_date) AS spent
                FROM budgets b JOIN users u ON u.id = b.user_id JOIN categories c ON c.id = b.category_id
                WHERE u.username = ? AND c.name = ? AND b.period_type = 'MONTH'""",
                DemoDataGenerator.OFFICE_WORKER_USERNAME, DefaultCategory.FOOD.getDisplayName());
        BigDecimal spent = (BigDecimal) food.get("SPENT");
        BigDecimal limit = (BigDecimal) food.get("AMOUNT");
        assertThat(spent.multiply(BigDecimal.valueOf(100))).isGreaterThanOrEqualTo(limit.multiply(BigDecimal.valueOf(80)));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE budget_id = ? AND type IN (?, ?)",
                Integer.class, food.get("ID"), NotificationType.BUDGET_WARNING.name(),
                NotificationType.BUDGET_EXCEEDED.name())).isEqualTo(1);
    }

    @Test
    void theDemoAccountsHaveGoalsNotificationsAndAuditRows() {
        seed();

        assertThat(count("saving_goals")).isEqualTo(GOALS);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE type = ?", Integer.class,
                NotificationType.RECEIPT_PROCESSED.name())).isEqualTo(count("receipts"));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE is_read = FALSE", Integer.class))
                .isPositive();
        List<String> actions = jdbc.queryForList("SELECT action FROM action_logs", String.class);
        assertThat(actions).contains(AuditAction.USER_CREATED.name(), AuditAction.RECEIPT_CREATED.name(),
                AuditAction.RECEIPT_UPDATED.name(), AuditAction.RECEIPT_FEEDBACK_SUBMITTED.name(),
                AuditAction.RECEIPT_APPROVED.name());
    }

    @Test
    void aSecondRunWritesNothing() {
        seed();
        Map<String, Integer> before = countEveryTable();

        DemoSeedResult second = seed();

        assertThat(second.seeded()).isFalse();
        assertThat(second.receipts()).isEmpty();
        assertThat(countEveryTable()).isEqualTo(before);
    }

    @Test
    void aDatabaseThatAlreadyHasAUserIsLeftAlone() {
        jdbc.update("INSERT INTO users (username, password, email, phone, role, active, wallet_balance, "
                        + "credentials_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                "real.user", "hash", "real.user@example.com", "0911111111", Roles.USER, true, BigDecimal.TEN, 0);
        Map<String, Integer> before = countEveryTable();

        DemoSeedResult result = seed();

        assertThat(result).isEqualTo(DemoSeedResult.skipped());
        assertThat(countEveryTable()).isEqualTo(before);
        assertThat(jdbc.queryForObject("SELECT wallet_balance FROM users", BigDecimal.class))
                .isEqualByComparingTo(BigDecimal.TEN);
    }

    @Test
    void existingCategoriesAreReused_notDuplicated() {
        jdbc.update("INSERT INTO categories (name, type) VALUES (?, ?)", DefaultCategory.FOOD.getDisplayName(),
                DefaultCategory.TYPE_EXPENSE);

        seed();

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM categories WHERE name = ?", Integer.class,
                DefaultCategory.FOOD.getDisplayName())).isEqualTo(1);
        assertThat(count("categories")).isEqualTo(DefaultCategory.values().length);
    }

    // ------------------------------------------------------------------------------------------------------- helpers

    private DemoSeedResult seed() {
        return writer.seedIfEmpty(ADMIN_PASSWORD, DEMO_PASSWORD);
    }

    private int count(String table) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Integer.class);
    }

    private int budgetsOf(String username) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM budgets b JOIN users u ON u.id = b.user_id WHERE u.username = ?",
                Integer.class, username);
    }

    private Map<String, Integer> countEveryTable() {
        List<String> tables = jdbc.queryForList(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC'", String.class);
        Map<String, Integer> counts = new TreeMap<>();
        tables.forEach(table -> counts.put(table, count(table)));
        return counts;
    }
}
