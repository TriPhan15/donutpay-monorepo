package vn.edu.huit.finance.core.Repository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.hibernate.metamodel.mapping.internal.BasicAttributeMapping;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.AuditResult;
import vn.edu.huit.finance.core.Entity.AuditTargetType;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.CustomerSegment;
import vn.edu.huit.finance.core.Entity.Notification;
import vn.edu.huit.finance.core.Entity.NotificationType;
import vn.edu.huit.finance.core.Entity.PaymentOrder;
import vn.edu.huit.finance.core.Entity.PaymentStatus;
import vn.edu.huit.finance.core.Entity.PaymentType;
import vn.edu.huit.finance.core.Entity.ReceiptAttemptStatus;
import vn.edu.huit.finance.core.Entity.ReceiptErrorCode;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Entity.User;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Schema mà Hibernate tự tạo trên một PostgreSQL 15 mới tinh (đúng như server deploy, không chạy migration tay) phải khớp
 * với code hiện tại:
 * <ul>
 *   <li>mỗi cột enum lưu dạng chuỗi có một CHECK chứa đúng và đủ các giá trị của enum Java, kể cả bảng *_aud của Envers;</li>
 *   <li>các cột lưu tên enum dưới dạng String đủ dài cho tên dài nhất;</li>
 *   <li>lưu được từng giá trị enum (insert thật, commit thật để Envers ghi cả bảng *_aud).</li>
 * </ul>
 * Cột enum được tìm từ metamodel của Hibernate, nên enum mới thêm sau này cũng được kiểm. Cách dựng container theo
 * {@link UserRfmQueryPostgresTest}. Bị bỏ qua khi không có Docker.
 */
@DataJpaTest(properties = "spring.jpa.hibernate.ddl-auto=create")
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class SchemaEnumConstraintsPostgresTest {

    /** Keep in step with the db service of docker-compose.yml. */
    private static final String IMAGE = "postgres:15-alpine";
    private static final int PORT = 5432;
    private static final String DATABASE = "schema_enum_it";
    private static final String USERNAME = "schema_enum_it";
    private static final String PASSWORD = "integration-test-only";
    private static final String READY_LOG = ".*database system is ready to accept connections.*\\n";
    private static final int READY_LOG_TIMES = 2;

    private static final Pattern QUOTED = Pattern.compile("'([^']*)'");
    private static final String AUDIT_SUFFIX = "_aud";
    private static final String APP_PACKAGE = "vn.edu.huit.finance.core.";
    private static final String PROVIDER = "VNPAY";
    private static final BigDecimal AMOUNT = new BigDecimal("100000");

    /** Cột enum phải có, để test không "xanh" nhờ metamodel không tìm thấy gì. */
    private static final Set<String> EXPECTED_ENUM_COLUMNS = Set.of(
            "budgets.period_type", "budgets_aud.period_type",
            "notifications.type", "notifications_aud.type",
            "payment_orders.type", "payment_orders_aud.type",
            "payment_orders.status", "payment_orders_aud.status",
            "transactions.source", "transactions_aud.source");

    private static final String CHECKS_OF_COLUMN = "select pg_get_constraintdef(c.oid) from pg_constraint c "
            + "join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey) "
            + "where c.contype = 'c' and c.conrelid = to_regclass(?) and a.attname = ?";
    private static final String COLUMN_INFO = "select data_type, character_maximum_length from information_schema.columns "
            + "where table_schema = current_schema() and table_name = ? and column_name = ?";

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

    @Autowired private EntityManagerFactory entityManagerFactory;
    @Autowired private EntityManager entityManager;
    @Autowired private PlatformTransactionManager transactionManager;
    @Autowired private JdbcTemplate jdbc;

    private record EnumColumn(String table, String column, Class<?> enumType) {
        String key() {
            return table + "." + column;
        }
    }

    /**
     * Mọi thuộc tính enum của ứng dụng trên mọi entity (gồm entity *_aud của Envers), theo bảng và cột thật. Bỏ qua enum
     * của chính Hibernate (cột revtype của Envers lưu theo số thứ tự).
     */
    private List<EnumColumn> enumColumns() {
        Map<String, EnumColumn> found = new TreeMap<>();
        entityManagerFactory.unwrap(SessionFactoryImplementor.class).getMappingMetamodel()
                .forEachEntityDescriptor(persister -> persister.forEachAttributeMapping(attribute -> {
                    if (attribute instanceof BasicAttributeMapping basic
                            && basic.getJavaType().getJavaTypeClass().isEnum()
                            && basic.getJavaType().getJavaTypeClass().getName().startsWith(APP_PACKAGE)) {
                        EnumColumn column = new EnumColumn(basic.getContainingTableExpression(),
                                basic.getSelectionExpression(), basic.getJavaType().getJavaTypeClass());
                        found.putIfAbsent(column.key(), column);
                    }
                }));
        return new ArrayList<>(found.values());
    }

    private static Set<String> namesOf(Class<?> enumType) {
        return Arrays.stream(enumType.getEnumConstants()).map(constant -> ((Enum<?>) constant).name())
                .collect(Collectors.toCollection(TreeSet::new));
    }

    private Set<String> checkValues(String table, String column) {
        List<String> checks = jdbc.queryForList(CHECKS_OF_COLUMN, String.class, table, column);
        assertEquals(1, checks.size(), "Cột " + table + "." + column + " phải có đúng một CHECK, thấy: " + checks);
        Set<String> values = new TreeSet<>();
        Matcher matcher = QUOTED.matcher(checks.get(0));
        while (matcher.find()) {
            values.add(matcher.group(1));
        }
        return values;
    }

    @Test
    void everyEnumColumnIsFound_includingTheEnversTables() {
        Set<String> found = enumColumns().stream().map(EnumColumn::key).collect(Collectors.toSet());

        assertTrue(found.containsAll(EXPECTED_ENUM_COLUMNS), "Metamodel chỉ thấy: " + found);
    }

    @Test
    void everyEnumColumnIsTextWithACheckHoldingExactlyTheJavaValues() {
        assertAll(enumColumns().stream().map(column -> () -> {
            Map<String, Object> info = jdbc.queryForMap(COLUMN_INFO, column.table(), column.column());
            assertEquals("character varying", info.get("data_type"), column.key() + " phải lưu tên enum (STRING)");
            int width = ((Number) info.get("character_maximum_length")).intValue();
            int longest = namesOf(column.enumType()).stream().mapToInt(String::length).max().orElse(0);
            assertTrue(width >= longest, column.key() + " dài " + width + ", tên enum dài nhất " + longest);
            assertEquals(namesOf(column.enumType()), checkValues(column.table(), column.column()), column.key());
        }));
    }

    private record StringEnumColumn(String table, String column, Set<String> values) {
    }

    /** Các cột giữ tên enum dưới dạng String (không có CHECK): chỉ cần đủ dài. */
    private static List<StringEnumColumn> stringEnumColumns() {
        Set<String> auditCodes = Arrays.stream(AuditAction.values()).flatMap(action -> action.getStoredCodes().stream())
                .collect(Collectors.toSet());
        return List.of(
                new StringEnumColumn("receipts", "status", namesOf(ReceiptStatus.class)),
                new StringEnumColumn("receipts", "error_code", namesOf(ReceiptErrorCode.class)),
                new StringEnumColumn("receipt_processing_attempts", "status", namesOf(ReceiptAttemptStatus.class)),
                new StringEnumColumn("receipt_processing_attempts", "error_code", namesOf(ReceiptErrorCode.class)),
                new StringEnumColumn("action_logs", "action", auditCodes),
                new StringEnumColumn("action_logs", "target_type", namesOf(AuditTargetType.class)),
                new StringEnumColumn("action_logs", "result", namesOf(AuditResult.class)),
                new StringEnumColumn("users", "ai_label", namesOf(CustomerSegment.class)));
    }

    @Test
    void columnsHoldingEnumNamesAsTextAreWideEnough_alsoInTheEnversTables() {
        List<StringEnumColumn> columns = new ArrayList<>(stringEnumColumns());
        for (StringEnumColumn column : stringEnumColumns()) {
            String audit = column.table() + AUDIT_SUFFIX;
            if (jdbc.queryForObject("select to_regclass(?) is not null", Boolean.class, audit)
                    && !jdbc.queryForList(COLUMN_INFO, audit, column.column()).isEmpty()) {
                columns.add(new StringEnumColumn(audit, column.column(), column.values()));
            }
        }

        assertAll(columns.stream().map(column -> () -> {
            Map<String, Object> info = jdbc.queryForMap(COLUMN_INFO, column.table(), column.column());
            int width = ((Number) info.get("character_maximum_length")).intValue();
            int longest = column.values().stream().mapToInt(String::length).max().orElse(0);
            assertTrue(width >= longest, column.table() + "." + column.column() + " dài " + width
                    + ", giá trị dài nhất " + longest);
        }));
    }

    @Test
    void everyEnumValueCanBeSaved_andEnversRecordsIt() {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        tx.executeWithoutResult(status -> {
            User user = new User();
            user.setUsername("schema_it");
            user.setEmail("schema_it@example.com");
            user.setPhone("0900000099");
            user.setPassword("hash");
            entityManager.persist(user);

            LocalDate start = LocalDate.parse("2026-10-01");
            for (BudgetPeriodType period : BudgetPeriodType.values()) {
                Budget budget = new Budget();
                budget.setUser(user);
                budget.setAmount(AMOUNT);
                budget.setPeriodType(period);
                budget.setStartDate(start);
                budget.setEndDate(start.plusDays(1));
                entityManager.persist(budget);
            }
            for (NotificationType type : NotificationType.values()) {
                Notification notification = new Notification();
                notification.setUser(user);
                notification.setType(type);
                notification.setMessage(type.name());
                entityManager.persist(notification);
            }
            int order = 0;
            for (PaymentType type : PaymentType.values()) {
                for (PaymentStatus paymentStatus : PaymentStatus.values()) {
                    entityManager.persist(PaymentOrder.builder().orderCode("SCHEMA" + order++).userId(user.getId())
                            .amount(AMOUNT).type(type).status(paymentStatus).provider(PROVIDER).build());
                }
            }
            Category category = new Category();
            category.setName("Schema");
            category.setType("EXPENSE");
            entityManager.persist(category);
            for (TransactionSource source : TransactionSource.values()) {
                Transaction transaction = new Transaction();
                transaction.setUser(user);
                transaction.setCategory(category);
                transaction.setCategoryName(category.getName());
                transaction.setAmount(AMOUNT);
                transaction.setExpense(true);
                transaction.setTransactionDate(start.atStartOfDay());
                transaction.setSource(source);
                entityManager.persist(transaction);
            }
        });

        assertAll(
                () -> assertEquals(namesOf(BudgetPeriodType.class), distinct("budgets", "period_type")),
                () -> assertEquals(namesOf(BudgetPeriodType.class), distinct("budgets_aud", "period_type")),
                () -> assertEquals(namesOf(NotificationType.class), distinct("notifications", "type")),
                () -> assertEquals(namesOf(NotificationType.class), distinct("notifications_aud", "type")),
                () -> assertEquals(namesOf(PaymentType.class), distinct("payment_orders", "type")),
                () -> assertEquals(namesOf(PaymentStatus.class), distinct("payment_orders_aud", "status")),
                () -> assertEquals(namesOf(TransactionSource.class), distinct("transactions", "source")),
                () -> assertEquals(namesOf(TransactionSource.class), distinct("transactions_aud", "source")));
    }

    /** Tên bảng và cột là hằng trong test, không đến từ input. */
    private Set<String> distinct(String table, String column) {
        return new TreeSet<>(jdbc.queryForList("select distinct " + column + " from " + table, String.class));
    }
}
