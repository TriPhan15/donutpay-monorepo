package vn.edu.huit.finance.core.Repository;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Security.Roles;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Câu RFM chuẩn chạy trên PostgreSQL 15 thật: chỉ khoản chi, không tính khoản góp tiết kiệm, chỉ 12 tháng gần nhất, ngày
 * ở tương lai tính là hôm nay. Cách dựng container theo {@code PaymentWebhookConcurrencyPostgresTest}. Bị bỏ qua khi
 * không có Docker.
 */
@DataJpaTest(properties = "spring.jpa.hibernate.ddl-auto=create")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class UserRfmQueryPostgresTest {

    private static final String IMAGE = "postgres:15-alpine";
    private static final int PORT = 5432;
    private static final String DATABASE = "user_rfm_it";
    private static final String USERNAME = "user_rfm_it";
    private static final String PASSWORD = "integration-test-only";
    private static final String READY_LOG = ".*database system is ready to accept connections.*\\n";
    private static final int READY_LOG_TIMES = 2;

    private static final LocalDateTime NOW = LocalDateTime.parse("2026-10-28T10:00:00");
    private static final LocalDateTime WINDOW_START = NOW.minusMonths(12);
    private static final String SAVINGS = "Tiết kiệm";
    private static final int NO_ACTIVITY_DAYS = 366;

    @Container
    private static final GenericContainer<?> POSTGRES = new GenericContainer<>(DockerImageName.parse(IMAGE))
            .withExposedPorts(PORT)
            .withEnv("POSTGRES_DB", DATABASE)
            .withEnv("POSTGRES_USER", USERNAME)
            .withEnv("POSTGRES_PASSWORD", PASSWORD)
            .waitingFor(Wait.forLogMessage(READY_LOG, READY_LOG_TIMES));

    @DynamicPropertySource
    static void postgres(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url",
                () -> "jdbc:postgresql://" + POSTGRES.getHost() + ":" + POSTGRES.getMappedPort(PORT) + "/" + DATABASE);
        registry.add("spring.datasource.username", () -> USERNAME);
        registry.add("spring.datasource.password", () -> PASSWORD);
    }

    @Autowired private UserRepository userRepository;
    @Autowired private JdbcTemplate jdbc;

    private long alice;
    private long bob;
    private long carol;
    private long foodCategory;
    private long savingsCategory;

    @BeforeEach
    void setUp() {
        alice = insertUser("alice", "0900000001");
        bob = insertUser("bob", "0900000002");
        carol = insertUser("carol", "0900000003");
        foodCategory = insertCategory("Ăn uống");
        savingsCategory = insertCategory(SAVINGS);
    }

    @AfterEach
    void cleanUp() {
        jdbc.update("delete from transactions");
        jdbc.update("delete from categories");
        jdbc.update("delete from users");
    }

    private long insertUser(String name, String phone) {
        return insertUser(name, phone, Roles.USER);
    }

    private long insertUser(String name, String phone, String role) {
        User user = new User();
        user.setRole(role);
        user.setUsername(name);
        user.setEmail(name + "@example.com");
        user.setPhone(phone);
        user.setPassword("hash");
        return userRepository.saveAndFlush(user).getId();
    }

    private long insertCategory(String name) {
        return jdbc.queryForObject("insert into categories (name, type, created_at, updated_at) "
                + "values (?, 'EXPENSE', now(), now()) returning id", Long.class, name);
    }

    private void insertTransaction(long userId, long categoryId, boolean expense, String amount, LocalDateTime date) {
        jdbc.update("insert into transactions (user_id, category_id, is_expense, amount, transaction_date, created_at, "
                        + "updated_at) values (?, ?, ?, ?, ?, now(), now())",
                userId, categoryId, expense, new BigDecimal(amount), date);
    }

    private void insertTransaction(long userId, long categoryId, boolean expense, String amount, LocalDateTime date,
                                   String source) {
        jdbc.update("insert into transactions (user_id, category_id, is_expense, amount, transaction_date, source, "
                        + "created_at, updated_at) values (?, ?, ?, ?, ?, ?, now(), now())",
                userId, categoryId, expense, new BigDecimal(amount), date, source);
    }

    private UserRfmRow row(long userId) {
        List<UserRfmRow> rows = userRepository.calculateAllUsersRfm(WINDOW_START, NOW, SAVINGS, NO_ACTIVITY_DAYS);
        return rows.stream().filter(r -> r.getUserId() == userId).findFirst().orElseThrow();
    }

    @Test
    void incomeIsNotSpending_andDoesNotCount() {
        insertTransaction(alice, foodCategory, false, "5000000", NOW.minusDays(1));

        UserRfmRow r = row(alice);

        assertEquals(0L, r.getFrequency());
        assertEquals(NO_ACTIVITY_DAYS, r.getRecency());
    }

    @Test
    void anExpenseCountsWithItsAgeAndAmount() {
        insertTransaction(alice, foodCategory, true, "100000", NOW.minusDays(10));
        insertTransaction(alice, foodCategory, true, "50000", NOW.minusDays(3));

        UserRfmRow r = row(alice);

        assertEquals(2L, r.getFrequency());
        assertEquals(3, r.getRecency());
        assertEquals(0, new BigDecimal("150000").compareTo(r.getMonetary()));
    }

    @Test
    void savingsContributionsAreLeftOut() {
        insertTransaction(alice, savingsCategory, true, "900000", NOW.minusDays(1));
        insertTransaction(alice, foodCategory, true, "10000", NOW.minusDays(5));

        UserRfmRow r = row(alice);

        assertEquals(1L, r.getFrequency());
        assertEquals(5, r.getRecency());
        assertEquals(0, new BigDecimal("10000").compareTo(r.getMonetary()));
    }

    @Test
    void aWithdrawalToALinkedWalletIsNotSpending_soItDoesNotCountForRecencyFrequencyOrMonetary() {
        // B9: 5,000,000 moved to another wallet of the same person, five days ago.
        insertTransaction(alice, foodCategory, true, "5000000", NOW.minusDays(5), "WALLET_TRANSFER");
        insertTransaction(alice, foodCategory, true, "10000", NOW.minusDays(8));

        UserRfmRow r = row(alice);

        assertEquals(1L, r.getFrequency());
        assertEquals(8, r.getRecency());
        assertEquals(0, new BigDecimal("10000").compareTo(r.getMonetary()));
    }

    @Test
    void aUserWhoOnlyMovedMoneyBetweenWalletsGetsTheNoActivityRow() {
        insertTransaction(bob, foodCategory, true, "5000000", NOW.minusDays(1), "WALLET_TRANSFER");

        UserRfmRow r = row(bob);

        assertEquals(0L, r.getFrequency());
        assertEquals(NO_ACTIVITY_DAYS, r.getRecency());
        assertEquals(0, BigDecimal.ZERO.compareTo(r.getMonetary()));
    }

    @Test
    void expensesOlderThanTwelveMonthsAreLeftOut() {
        insertTransaction(alice, foodCategory, true, "10000", WINDOW_START.minusDays(1));
        insertTransaction(alice, foodCategory, true, "20000", WINDOW_START.plusDays(1));

        UserRfmRow r = row(alice);

        assertEquals(1L, r.getFrequency());
        assertEquals(0, new BigDecimal("20000").compareTo(r.getMonetary()));
    }

    @Test
    void aFutureDatedExpenseCountsAsToday_withRecencyZero() {
        insertTransaction(bob, foodCategory, true, "30000", NOW.plusDays(20));

        UserRfmRow r = row(bob);

        assertEquals(0, r.getRecency());
        assertEquals(1L, r.getFrequency());
    }

    @Test
    void aUserWithoutExpensesGetsNoActivityDays_andZeros() {
        UserRfmRow r = row(carol);

        assertEquals(366, r.getRecency());
        assertEquals(0L, r.getFrequency());
        assertEquals(0, BigDecimal.ZERO.compareTo(r.getMonetary()));
    }

    @Test
    void anAdminAccountIsLeftOutOfTheRows() {
        long admin = insertUser("root", "0900000009", Roles.ADMIN);

        List<UserRfmRow> rows = userRepository.calculateAllUsersRfm(WINDOW_START, NOW, SAVINGS, NO_ACTIVITY_DAYS);

        assertTrue(rows.stream().noneMatch(r -> r.getUserId() == admin));
    }

    @Test
    void aNormalUserStaysInTheRowsNextToAnAdmin() {
        insertUser("root", "0900000009", Roles.ADMIN);

        List<UserRfmRow> rows = userRepository.calculateAllUsersRfm(WINDOW_START, NOW, SAVINGS, NO_ACTIVITY_DAYS);

        assertEquals(3, rows.size());
        assertTrue(rows.stream().anyMatch(r -> r.getUserId() == alice));
    }

    @Test
    void everyUserGetsExactlyOneRow() {
        insertTransaction(alice, foodCategory, true, "1000", NOW.minusDays(2));
        insertTransaction(alice, foodCategory, true, "1000", NOW.minusDays(4));

        assertEquals(3, userRepository.calculateAllUsersRfm(WINDOW_START, NOW, SAVINGS, NO_ACTIVITY_DAYS).size());
    }
}
