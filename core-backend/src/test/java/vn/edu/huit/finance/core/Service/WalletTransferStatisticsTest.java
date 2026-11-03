package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.Notification;
import vn.edu.huit.finance.core.Entity.NotificationType;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.BudgetRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.NotificationRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * B9 end to end on H2, with the real TransactionService and queries: money that a linked e-wallet takes from or adds to
 * the main wallet moves the balance as before, but is neither spending nor income for the budget alerts, the monthly
 * leaderboard (which is fed by sumExpensesByUserBetween and sumSpendingBetween) and the admin volume.
 * Nothing is wrapped in a test transaction, so every check reads the committed rows.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Import({TransactionService.class, CategoryService.class, ReceiptProcessingService.class, OcrService.class, OcrCorrectionDetector.class,
        BudgetAlertService.class, NotificationService.class, UserStatisticsService.class})
class WalletTransferStatisticsTest {

    private static final BigDecimal WALLET = new BigDecimal("10000000.00");
    private static final LocalDate MONTH_START = LocalDate.of(2026, 9, 1);
    private static final LocalDateTime SEPTEMBER_15 = LocalDateTime.of(2026, 9, 15, 12, 0);
    private static final LocalDateTime SEPTEMBER_START = MONTH_START.atStartOfDay();
    private static final LocalDateTime OCTOBER_START = MONTH_START.plusMonths(1).atStartOfDay();
    private static final String WITHDRAW_CATEGORY = "Rút ví điện tử";
    private static final String DEPOSIT_CATEGORY = "Nạp ví điện tử";
    private static final int WHOLE_LIST = 100;

    @Autowired private TransactionService service;
    @Autowired private UserRepository userRepository;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private BudgetRepository budgetRepository;
    @Autowired private TransactionRepository transactionRepository;
    @Autowired private ReceiptRepository receiptRepository;
    @Autowired private NotificationRepository notificationRepository;
    @MockBean private CurrentUserProvider currentUserProvider;
    @MockBean private AuditLogService auditLogService;

    private Long aliceId;

    @BeforeEach
    void setUp() {
        User alice = new User();
        alice.setUsername("alice");
        alice.setPassword("hash");
        alice.setEmail("alice@example.com");
        alice.setPhone("0900000001");
        alice.setWalletBalance(WALLET);
        aliceId = userRepository.saveAndFlush(alice).getId();

        // A budget of 3,000,000 for every category: a 5,000,000 expense would cross both of its levels.
        Budget budget = new Budget();
        budget.setUser(userRepository.findById(aliceId).orElseThrow());
        budget.setAmount(new BigDecimal("3000000"));
        budget.setPeriodType(BudgetPeriodType.MONTH);
        budget.setStartDate(MONTH_START);
        budget.setEndDate(LocalDate.of(2026, 9, 30));
        budgetRepository.saveAndFlush(budget);
    }

    @AfterEach
    void cleanUp() {
        notificationRepository.deleteAll();
        transactionRepository.deleteAll();
        receiptRepository.deleteAll();
        budgetRepository.deleteAll();
        categoryRepository.deleteAll();
        userRepository.deleteAll();
    }

    private static TransactionRequestDto transfer(String amount, boolean expense) {
        TransactionRequestDto request = new TransactionRequestDto();
        request.setAmount(new BigDecimal(amount));
        request.setExpense(expense);
        request.setCategoryName(expense ? WITHDRAW_CATEGORY : DEPOSIT_CATEGORY);
        request.setLocation("Ví MOMO");
        request.setPaymentMethod("MOMO");
        request.setTransactionDate(SEPTEMBER_15);
        return request;
    }

    private List<Notification> notificationsOf(Long userId) {
        return notificationRepository.findNewestByUserId(userId, PageRequest.of(0, WHOLE_LIST)).getContent();
    }

    private BigDecimal walletInDatabase() {
        return userRepository.findById(aliceId).orElseThrow().getWalletBalance();
    }

    private static void assertMoney(String expected, BigDecimal actual) {
        assertEquals(0, new BigDecimal(expected).compareTo(actual), "expected " + expected + " but was " + actual);
    }

    private Transaction onlyTransaction() {
        List<Transaction> all = transactionRepository.findAll();
        assertEquals(1, all.size());
        return transactionRepository.findDetailedById(all.get(0).getId()).orElseThrow();
    }

    @Test
    void withdrawingFiveMillion_takesItFromTheWallet_butIsNotThisMonthsSpending() {
        service.recordWalletTransfer(transfer("5000000", true), aliceId);

        assertMoney("5000000", walletInDatabase());
        Transaction saved = onlyTransaction();
        assertEquals(TransactionSource.WALLET_TRANSFER, saved.getSource());
        assertTrue(saved.isExpense(), "the row is still a debit of the wallet");
        assertNull(transactionRepository.sumSpendingBetween(aliceId, SEPTEMBER_START, OCTOBER_START));
    }

    @Test
    void withdrawingFiveMillion_raisesNoBudgetAlert() {
        service.recordWalletTransfer(transfer("5000000", true), aliceId);

        assertEquals(List.of(), notificationsOf(aliceId));
    }

    @Test
    void withdrawingFiveMillion_doesNotPutTheUserOnTheLeaderboard() {
        service.recordWalletTransfer(transfer("5000000", true), aliceId);

        assertEquals(0, transactionRepository.sumExpensesByUserBetween(SEPTEMBER_START, OCTOBER_START).size());
    }

    @Test
    void depositingFiveMillion_addsToTheWallet_butIsNoIncomeAndNoVolume() {
        service.recordWalletTransfer(transfer("5000000", false), aliceId);

        assertMoney("15000000", walletInDatabase());
        assertEquals(TransactionSource.WALLET_TRANSFER, onlyTransaction().getSource());
        assertNull(transactionRepository.sumTotalVolume());
    }

    @Test
    void theResponseNamesTheSource_soTheAppCanLeaveTheRowOutOfItsTotals() {
        service.recordWalletTransfer(transfer("5000000", true), aliceId);

        assertEquals("WALLET_TRANSFER", TransactionResponseDto.from(onlyTransaction()).getSource());
    }

    @Test
    void anOrdinaryExpenseStillCountsAndStillRaisesTheAlert_nextToAWithdrawal() {
        service.recordWalletTransfer(transfer("5000000", true), aliceId);
        TransactionRequestDto lunch = transfer("2500000", true);
        lunch.setCategoryName("Ăn uống");
        lunch.setLocation("Quán A");
        lunch.setPaymentMethod("Ví chính");

        service.createTransaction(lunch, aliceId);

        assertMoney("2500000", walletInDatabase());
        assertMoney("2500000", transactionRepository.sumSpendingBetween(aliceId, SEPTEMBER_START, OCTOBER_START));
        assertEquals(1, transactionRepository.sumExpensesByUserBetween(SEPTEMBER_START, OCTOBER_START).size());
        List<Notification> raised = notificationsOf(aliceId);
        assertEquals(1, raised.size());
        assertEquals(NotificationType.BUDGET_WARNING, raised.get(0).getType());
        assertMoney("2500000", transactionRepository.sumTotalVolume());
    }
}
