package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
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
import vn.edu.huit.finance.core.Dto.PaymentStatusResponseDto;
import vn.edu.huit.finance.core.Dto.PaymentWebhookDto;
import vn.edu.huit.finance.core.Entity.PaymentOrder;
import vn.edu.huit.finance.core.Entity.PaymentStatus;
import vn.edu.huit.finance.core.Entity.PaymentType;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.PaymentOrderRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Payment.PaymentGatewayRegistry;
import vn.edu.huit.finance.core.Util.HmacUtil;

import java.math.BigDecimal;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Cùng một webhook thanh toán được gửi lại hai lần cùng lúc, và webhook gặp lệnh hủy đơn cùng lúc, trên PostgreSQL 15
 * thật: dịch vụ thật qua proxy @Transactional thật, mỗi lần gọi một thread và một giao dịch riêng. Chỉ một lần được
 * cộng ví; đơn đã được webhook chốt SUCCESS thì lệnh hủy không ghi đè được. Cách dựng container theo
 * {@link ReceiptConcurrencyPostgresTest}: container riêng, cổng ngẫu nhiên, "create" chứ không "create-drop". Bị bỏ qua
 * khi không có Docker.
 */
@DataJpaTest(properties = {"spring.jpa.hibernate.ddl-auto=create", "payment.secret=" + PaymentWebhookConcurrencyPostgresTest.SECRET})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Import({PaymentService.class, TransactionService.class, CategoryService.class, ReceiptProcessingService.class,
        OcrService.class, OcrCorrectionDetector.class, UserStatisticsService.class})
class PaymentWebhookConcurrencyPostgresTest {

    static final String SECRET = "concurrency_it_secret";

    /** Keep in step with the db service of docker-compose.yml. */
    private static final String IMAGE = "postgres:15-alpine";
    private static final int PORT = 5432;
    private static final String DATABASE = "payment_webhook_it";
    private static final String USERNAME = "payment_webhook_it";
    private static final String PASSWORD = "integration-test-only";
    private static final String READY_LOG = ".*database system is ready to accept connections.*\\n";
    private static final int READY_LOG_TIMES = 2;

    private static final String ORDER_CODE = "PAYCONC1";
    private static final String GATEWAY_TXN = "TXN1";
    private static final String SUCCESS_CODE = "00";
    private static final BigDecimal AMOUNT = new BigDecimal("100000");
    private static final String DEPOSIT_CATEGORY = "Nạp ví điện tử";
    private static final int CALLERS = 2;
    private static final long TIMEOUT_SECONDS = 20;
    private static final long POLL_MILLIS = 50;
    private static final String LOCK_WAITERS_SQL = "select count(*) from pg_stat_activity "
            + "where datname = current_database() and wait_event_type = 'Lock'";

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

    @Autowired private PaymentService paymentService;
    @Autowired private UserRepository userRepository;
    @Autowired private PaymentOrderRepository orderRepository;
    @Autowired private TransactionRepository transactionRepository;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private JdbcTemplate jdbc;
    @Autowired private PlatformTransactionManager transactionManager;
    @MockBean private PaymentGatewayRegistry gateways;
    @MockBean private CurrentUserProvider currentUserProvider;
    @MockBean private AuditLogService auditLogService;
    @MockBean private BudgetAlertService budgetAlertService;
    // The notification of a review has its own Mockito tests; here it would only add statements.
    @MockBean private NotificationService notificationService;

    private Long userId;

    @BeforeEach
    void setUp() {
        User alice = new User();
        alice.setUsername("alice");
        alice.setPassword("hash");
        alice.setEmail("alice@example.com");
        alice.setPhone("0900000001");
        alice.setWalletBalance(BigDecimal.ZERO);
        userId = userRepository.saveAndFlush(alice).getId();

        orderRepository.saveAndFlush(PaymentOrder.builder()
                .orderCode(ORDER_CODE).userId(userId).amount(AMOUNT).type(PaymentType.DEPOSIT)
                .status(PaymentStatus.PENDING).provider("MOCK").build());
    }

    @AfterEach
    void cleanUp() {
        transactionRepository.deleteAll();
        orderRepository.deleteAll();
        categoryRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void sameWebhookTwiceInParallel_creditsTheWalletOnce() throws Exception {
        PaymentWebhookDto webhook = signedWebhook();
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(CALLERS);
        try {
            Callable<Void> call = () -> {
                start.await();
                paymentService.handleWebhook(webhook);
                return null;
            };
            Future<Void> first = pool.submit(call);
            Future<Void> second = pool.submit(call);
            start.countDown();
            first.get(TIMEOUT_SECONDS, TimeUnit.SECONDS);
            second.get(TIMEOUT_SECONDS, TimeUnit.SECONDS);
        } finally {
            pool.shutdownNow();
        }

        BigDecimal wallet = userRepository.findById(userId).orElseThrow().getWalletBalance();
        assertEquals(0, AMOUNT.compareTo(wallet), "the wallet is credited once, but was " + wallet);
        Integer deposits = jdbc.queryForObject("select count(*) from transactions where category_name = ?",
                Integer.class, DEPOSIT_CATEGORY);
        assertEquals(1, deposits, "exactly one deposit transaction");
        assertEquals(PaymentStatus.SUCCESS, orderRepository.findByOrderCode(ORDER_CODE).orElseThrow().getStatus());
    }

    @Test
    void cancelWhileTheWebhookHoldsTheOrder_waitsForIt_andCannotOverwriteSuccess() throws Exception {
        ExecutorService pool = Executors.newSingleThreadExecutor();
        Future<PaymentStatusResponseDto> cancel;
        try {
            // The webhook is processed in a transaction that is still open: the order is locked, the wallet credited.
            cancel = new TransactionTemplate(transactionManager).execute(status -> {
                paymentService.handleWebhook(signedWebhook());
                Future<PaymentStatusResponseDto> late = pool.submit(() -> paymentService.cancel(ORDER_CODE, userId));
                awaitDoneOrWaitingOnALock(late);
                assertFalse(late.isDone(), "the cancel must wait for the lock held by the webhook");
                return late;
            });
            PaymentStatusResponseDto answer = cancel.get(TIMEOUT_SECONDS, TimeUnit.SECONDS);
            assertEquals(PaymentStatus.SUCCESS.name(), answer.getStatus(), "the cancel answers with the closed order");
        } finally {
            pool.shutdownNow();
        }

        assertEquals(PaymentStatus.SUCCESS, orderRepository.findByOrderCode(ORDER_CODE).orElseThrow().getStatus());
        BigDecimal wallet = userRepository.findById(userId).orElseThrow().getWalletBalance();
        assertEquals(0, AMOUNT.compareTo(wallet), "the wallet keeps the deposit, but was " + wallet);
    }

    @Test
    void webhookAndCancelInParallel_leaveTheOrderAndTheWalletConsistent() throws Exception {
        PaymentWebhookDto webhook = signedWebhook();
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(CALLERS);
        try {
            Future<Void> hook = pool.submit(() -> {
                start.await();
                paymentService.handleWebhook(webhook);
                return null;
            });
            Future<PaymentStatusResponseDto> cancel = pool.submit(() -> {
                start.await();
                return paymentService.cancel(ORDER_CODE, userId);
            });
            start.countDown();
            hook.get(TIMEOUT_SECONDS, TimeUnit.SECONDS);
            cancel.get(TIMEOUT_SECONDS, TimeUnit.SECONDS);
        } finally {
            pool.shutdownNow();
        }

        PaymentStatus status = orderRepository.findByOrderCode(ORDER_CODE).orElseThrow().getStatus();
        BigDecimal wallet = userRepository.findById(userId).orElseThrow().getWalletBalance();
        BigDecimal expected = status == PaymentStatus.SUCCESS ? AMOUNT : BigDecimal.ZERO;
        assertTrue(status == PaymentStatus.SUCCESS || status == PaymentStatus.CANCELLED, "the order is closed: " + status);
        assertEquals(0, expected.compareTo(wallet), "status " + status + " but the wallet is " + wallet);
    }

    @Test
    void withdrawWithoutFunds_commitsTheOrderAsFailed_andLeavesTheWalletAlone() {
        BigDecimal balance = new BigDecimal("100000");
        BigDecimal withdrawal = new BigDecimal("500000");
        User owner = userRepository.findById(userId).orElseThrow();
        owner.setWalletBalance(balance);
        userRepository.saveAndFlush(owner);
        orderRepository.deleteAll();
        orderRepository.saveAndFlush(PaymentOrder.builder()
                .orderCode(ORDER_CODE).userId(userId).amount(withdrawal).type(PaymentType.WITHDRAW)
                .status(PaymentStatus.PENDING).provider("MOCK").build());

        assertDoesNotThrow(() -> paymentService.handleWebhook(signedWebhook(withdrawal)));

        assertEquals(PaymentStatus.FAILED, orderRepository.findByOrderCode(ORDER_CODE).orElseThrow().getStatus());
        BigDecimal wallet = userRepository.findById(userId).orElseThrow().getWalletBalance();
        assertEquals(0, balance.compareTo(wallet), "the wallet is untouched, but was " + wallet);
        assertEquals(0, transactionRepository.count());
    }

    /** Waits until the call has finished or a session waits on a lock, i.e. is queued behind the open transaction. */
    private void awaitDoneOrWaitingOnALock(Future<?> call) {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(TIMEOUT_SECONDS);
        try {
            while (!call.isDone() && System.nanoTime() < deadline) {
                Integer waiting = jdbc.queryForObject(LOCK_WAITERS_SQL, Integer.class);
                if (waiting != null && waiting > 0) {
                    return;
                }
                Thread.sleep(POLL_MILLIS);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private static PaymentWebhookDto signedWebhook() {
        return signedWebhook(AMOUNT);
    }

    private static PaymentWebhookDto signedWebhook(BigDecimal amount) {
        PaymentWebhookDto dto = new PaymentWebhookDto();
        dto.setOrderCode(ORDER_CODE);
        dto.setGatewayTxnId(GATEWAY_TXN);
        dto.setResultCode(SUCCESS_CODE);
        dto.setAmount(amount);
        String raw = ORDER_CODE + "|" + GATEWAY_TXN + "|" + SUCCESS_CODE + "|" + amount.toPlainString();
        dto.setSignature(HmacUtil.hmacSha256(raw, SECRET));
        return dto;
    }
}
