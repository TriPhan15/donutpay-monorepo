package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.InsufficientBalanceException;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;

/**
 * POST /api/savings/{id}/contributions end to end on H2: the real SavingGoalService and TransactionService run through
 * their @Transactional proxies (no test transaction around them), and every check reads the database again. The wallet,
 * the expense transaction and the goal commit together or not at all.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Import({SavingGoalService.class, TransactionService.class, CategoryService.class, ReceiptProcessingService.class, OcrService.class, OcrCorrectionDetector.class,
        UserStatisticsService.class})
class SavingGoalContributionRollbackTest {

    private static final BigDecimal WALLET = new BigDecimal("1000000.00");
    private static final String SAVINGS = DefaultCategory.SAVINGS.getDisplayName();

    @Autowired private SavingGoalService service;
    @Autowired private UserRepository userRepository;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private TransactionRepository transactionRepository;
    @SpyBean private SavingGoalRepository savingGoalRepository;
    @MockBean private CurrentUserProvider currentUserProvider;
    @MockBean private AuditLogService auditLogService;
    @MockBean private BudgetAlertService budgetAlertService;

    private Long aliceId;
    private Long alicesGoalId;

    @BeforeEach
    void setUp() {
        User alice = persistUser("alice", "0900000001");
        aliceId = alice.getId();
        alicesGoalId = persistGoal(alice, "Mua xe", "1000000").getId();
        // Every call answers with a fresh read, inside whatever transaction the service has opened by then.
        when(currentUserProvider.getCurrentUser()).thenAnswer(invocation -> userRepository.findById(aliceId).orElseThrow());
    }

    @AfterEach
    void cleanUp() {
        savingGoalRepository.deleteAll();
        transactionRepository.deleteAll();
        categoryRepository.deleteAll();
        userRepository.deleteAll();
    }

    private User persistUser(String name, String phone) {
        User user = new User();
        user.setUsername(name);
        user.setPassword("hash");
        user.setEmail(name + "@example.com");
        user.setPhone(phone);
        user.setWalletBalance(WALLET);
        return userRepository.saveAndFlush(user);
    }

    private SavingGoal persistGoal(User owner, String title, String current) {
        SavingGoal goal = new SavingGoal();
        goal.setTitle(title);
        goal.setTargetAmount(new BigDecimal("50000000"));
        goal.setCurrentAmount(new BigDecimal(current));
        goal.setUser(owner);
        return savingGoalRepository.saveAndFlush(goal);
    }

    private BigDecimal walletInDatabase() {
        return userRepository.findById(aliceId).orElseThrow().getWalletBalance();
    }

    private BigDecimal goalInDatabase(Long goalId) {
        return savingGoalRepository.findById(goalId).orElseThrow().getCurrentAmount();
    }

    private static void assertMoney(String expected, BigDecimal actual) {
        assertEquals(0, new BigDecimal(expected).compareTo(actual), "expected " + expected + " but was " + actual);
    }

    private void assertNothingMoved() {
        assertMoney("1000000", walletInDatabase());
        assertMoney("1000000", goalInDatabase(alicesGoalId));
        assertEquals(0, transactionRepository.count());
    }

    @Test
    void aContributionCommitsTheWalletTheExpenseAndTheGoalTogether() {
        SavingGoalDto answer = service.contributeToMySaving(alicesGoalId, new BigDecimal("300000"));

        assertMoney("1300000", answer.getCurrent());
        assertMoney("1300000", goalInDatabase(alicesGoalId));
        assertMoney("700000", walletInDatabase());
        List<Transaction> transactions = transactionRepository.findByUserIdOrderByTransactionDateDesc(aliceId);
        assertEquals(1, transactions.size());
        Transaction expense = transactions.get(0);
        assertTrue(expense.isExpense());
        assertMoney("300000", expense.getAmount());
        assertEquals(SAVINGS, expense.getCategory().getName());
        assertEquals(SAVINGS, expense.getCategoryName());
        assertEquals("Mua xe", expense.getNote());
        assertEquals(SavingGoalService.CONTRIBUTION_PAYMENT_METHOD, expense.getPaymentMethod());
        assertNull(expense.getReceipt());
    }

    @Test
    void deletingAGoalThatHoldsMoneyCreditsTheWalletWithARefundThatIsNoIncome() {
        // A6: the 1,000,000 the goal holds goes back to the wallet, marked GOAL_REFUND so no income total counts it.
        service.deleteSaving(alicesGoalId);

        assertMoney("2000000", walletInDatabase());
        assertFalse(savingGoalRepository.existsById(alicesGoalId));
        List<Transaction> transactions = transactionRepository.findByUserIdOrderByTransactionDateDesc(aliceId);
        assertEquals(1, transactions.size());
        Transaction refund = transactions.get(0);
        assertFalse(refund.isExpense());
        assertMoney("1000000", refund.getAmount());
        assertEquals(TransactionSource.GOAL_REFUND, refund.getSource());
        assertEquals("GOAL_REFUND", TransactionResponseDto.from(refund).getSource());
    }

    @Test
    void aContributionIsAnOrdinaryTransaction() {
        service.contributeToMySaving(alicesGoalId, new BigDecimal("300000"));

        Transaction expense = transactionRepository.findByUserIdOrderByTransactionDateDesc(aliceId).get(0);
        assertEquals(TransactionSource.NORMAL, expense.getSource());
        assertEquals("NORMAL", TransactionResponseDto.from(expense).getSource());
    }

    @Test
    void theSavingsCategoryIsCreatedOnceAsAnExpenseCategoryAndThenReused() {
        service.contributeToMySaving(alicesGoalId, new BigDecimal("100000"));
        service.contributeToMySaving(alicesGoalId, new BigDecimal("200000"));

        Category savings = categoryRepository.findFirstByNameIgnoreCaseOrderByIdAsc(SAVINGS).orElseThrow();
        assertEquals(DefaultCategory.TYPE_EXPENSE, savings.getType());
        assertEquals(1, categoryRepository.count());
        assertMoney("1300000", goalInDatabase(alicesGoalId));
        assertMoney("700000", walletInDatabase());
        assertEquals(2, transactionRepository.count());
    }

    @Test
    void theWholeWalletMayGoIntoAGoal() {
        service.contributeToMySaving(alicesGoalId, new BigDecimal("1000000"));

        assertMoney("0", walletInDatabase());
        assertMoney("2000000", goalInDatabase(alicesGoalId));
    }

    @Test
    void aContributionTheWalletCannotCarryChangesNothing() {
        InsufficientBalanceException refused = assertThrows(InsufficientBalanceException.class,
                () -> service.contributeToMySaving(alicesGoalId, new BigDecimal("1000000.01")));

        assertEquals("GIAO DỊCH THẤT BẠI: Số dư ví không đủ!", refused.getMessage());
        assertNothingMoved();
    }

    @Test
    void whenSavingTheGoalFailsTheExpenseAndTheChargeThatWereAlreadyWrittenAreRolledBack() {
        doThrow(new IllegalStateException("database went away")).when(savingGoalRepository).save(any(SavingGoal.class));

        assertThrows(IllegalStateException.class, () -> service.contributeToMySaving(alicesGoalId, new BigDecimal("300000")));

        assertNothingMoved();
    }

    @Test
    void aGoalOfBobIsRefusedWith403AndNeitherAlicesWalletNorBobsGoalMoves() {
        Long bobsGoalId = persistGoal(persistUser("bob", "0900000002"), "Du lịch", "0").getId();

        assertThrows(TransactionAccessDeniedException.class,
                () -> service.contributeToMySaving(bobsGoalId, new BigDecimal("300000")));

        assertMoney("0", goalInDatabase(bobsGoalId));
        assertNothingMoved();
    }

    @Test
    void contributeThenDelete_givesTheWalletBackItsMoney() {
        service.contributeToMySaving(alicesGoalId, new BigDecimal("300000"));
        assertMoney("700000", walletInDatabase());

        service.deleteSaving(alicesGoalId);

        // The goal held 1,000,000 + 300,000: all of it goes back as one income of "Thu khác".
        assertMoney("2000000", walletInDatabase());
        assertEquals(0, savingGoalRepository.count());
        Transaction refund = transactionRepository.findByUserIdOrderByTransactionDateDesc(aliceId).stream()
                .filter(transaction -> !transaction.isExpense()).findFirst().orElseThrow();
        assertMoney("1300000", refund.getAmount());
        assertEquals(DefaultCategory.OTHER_INCOME.getDisplayName(), refund.getCategoryName());
        assertTrue(refund.getNote().contains("Mua xe"));
    }

    @Test
    void whenTheGoalCannotBeDeletedTheRefundIsRolledBack() {
        doThrow(new IllegalStateException("database went away")).when(savingGoalRepository).delete(any(SavingGoal.class));

        assertThrows(IllegalStateException.class, () -> service.deleteSaving(alicesGoalId));

        assertNothingMoved();
    }
}
