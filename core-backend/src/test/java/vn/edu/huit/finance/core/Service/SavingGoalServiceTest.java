package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.InsufficientBalanceException;
import vn.edu.huit.finance.core.Exception.SavingsLedgerException;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * The caller's saving goals: the owner always comes from the SecurityContext, a goal of somebody else is refused with a
 * 403 and records no change, and each change of the caller's own goal is recorded with the caller and the goal.
 */
@ExtendWith(MockitoExtension.class)
class SavingGoalServiceTest {

    @Mock private SavingGoalRepository repository;
    @Mock private CurrentUserProvider currentUserProvider;
    @Mock private AuditLogService auditLogService;
    @Mock private TransactionService transactionService;
    @InjectMocks private SavingGoalService service;

    private final User alice = user(1L);
    private final User bob = user(2L);

    private static User user(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        return user;
    }

    @BeforeEach
    void aliceIsTheCaller() {
        when(currentUserProvider.getCurrentUser()).thenReturn(alice);
    }

    private AuditEntry recorded() {
        ArgumentCaptor<AuditEntry> entry = ArgumentCaptor.forClass(AuditEntry.class);
        verify(auditLogService).record(entry.capture());
        return entry.getValue();
    }

    private static void assertNoFigureOrTitleIn(AuditEntry entry) {
        assertFalse(entry.description().contains("Mua xe"));
        assertFalse(entry.description().contains("50000000"));
    }

    @Test
    void aNewGoalBelongsToTheCaller_andIsRecorded() {
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> {
            SavingGoal saved = invocation.getArgument(0);
            saved.setId(6L);
            return saved;
        });

        service.createSaving(SavingGoalDto.builder().title("Mua xe").target(new BigDecimal("50000000"))
                .current(BigDecimal.ZERO).build());

        ArgumentCaptor<SavingGoal> saved = ArgumentCaptor.forClass(SavingGoal.class);
        verify(repository).save(saved.capture());
        assertSame(alice, saved.getValue().getUser());
        AuditEntry entry = recorded();
        assertEquals(AuditAction.SAVING_CREATED, entry.action());
        assertEquals(AuditActor.of(alice), entry.actor());
        assertEquals(6L, entry.targetId());
        assertNoFigureOrTitleIn(entry);
    }

    private static SavingGoalDto dto(String title, String target, String current, String deadline) {
        return SavingGoalDto.builder().title(title).target(new BigDecimal(target))
                .current(current == null ? null : new BigDecimal(current)).deadline(deadline).build();
    }

    @Test
    void anUpdateAndADeletionOfTheCallersGoalAreRecorded() {
        SavingGoal goal = lockedGoalOf(alice);
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));
        goal.setCurrentAmount(BigDecimal.ZERO);

        service.updateMySaving(6L, dto("Mua xe mới", "60000000", null, null));
        service.deleteSaving(6L);

        verify(repository).delete(goal);
        ArgumentCaptor<AuditEntry> entries = ArgumentCaptor.forClass(AuditEntry.class);
        verify(auditLogService, times(2)).record(entries.capture());
        assertEquals(List.of(AuditAction.SAVING_UPDATED, AuditAction.SAVING_DELETED),
                entries.getAllValues().stream().map(AuditEntry::action).toList());
        entries.getAllValues().forEach(entry -> {
            assertEquals(AuditActor.of(alice), entry.actor());
            assertEquals(6L, entry.targetId());
        });
    }

    @Test
    void updateChangesTitleTargetAndDeadline_butNotTheSavedAmount() {
        SavingGoal goal = lockedGoalOf(alice);
        goal.setCurrentAmount(new BigDecimal("3000000"));
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));

        SavingGoalDto out = service.updateMySaving(6L, dto("Laptop", "20000000", null, "31/12/2026"));

        assertEquals("Laptop", out.getTitle());
        assertEquals(0, new BigDecimal("20000000").compareTo(out.getTarget()));
        assertEquals("31/12/2026", out.getDeadline());
        assertEquals(0, new BigDecimal("3000000").compareTo(out.getCurrent()));
        assertEquals(0, new BigDecimal("3000000").compareTo(goal.getCurrentAmount()));
    }

    @Test
    void updateWithTheStoredCurrentIsAccepted_whateverItsScale() {
        SavingGoal goal = lockedGoalOf(alice);
        goal.setCurrentAmount(new BigDecimal("3000000.00"));
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.updateMySaving(6L, dto("Laptop", "20000000", "3000000", null));

        verify(repository).save(goal);
    }

    @Test
    void updateWithADifferentCurrent_isRefused409_andNothingChanges() {
        SavingGoal goal = lockedGoalOf(alice);
        goal.setCurrentAmount(new BigDecimal("3000000"));

        SavingsLedgerException refused = assertThrows(SavingsLedgerException.class,
                () -> service.updateMySaving(6L, dto("Laptop", "20000000", "9000000", null)));

        assertEquals("Số tiền đã tiết kiệm chỉ thay đổi qua Góp tiền", refused.getMessage());
        assertEquals("Mua xe", goal.getTitle());
        verify(repository, never()).save(any());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void createWithAStartingAmount_isRefused409_andSavesNothing() {
        SavingsLedgerException refused = assertThrows(SavingsLedgerException.class,
                () -> service.createSaving(dto("Mua xe", "50000000", "1", null)));

        assertEquals(SavingGoalService.MSG_NEW_GOAL_STARTS_EMPTY, refused.getMessage());
        verify(repository, never()).save(any());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void deletingAGoalWithMoney_refundsTheWalletAsOtherIncomeNamingTheGoal() {
        SavingGoal goal = lockedGoalOf(alice);
        goal.setCurrentAmount(new BigDecimal("3000000"));
        theCheckoutRecordsTransaction(901L);

        service.deleteSaving(6L);

        TransactionRequestDto refund = checkoutSent();
        assertFalse(refund.isExpense());
        assertEquals("Thu khác", refund.getCategoryName());
        assertEquals(0, new BigDecimal("3000000").compareTo(refund.getAmount()));
        assertTrue(refund.getNote().contains("Mua xe"));
        assertEquals("WALLET", refund.getPaymentMethod());
        assertNotNull(refund.getTransactionDate());
        verify(repository).delete(goal);
        AuditEntry entry = recorded();
        assertEquals(AuditAction.SAVING_DELETED, entry.action());
        assertTrue(entry.description().contains("#901"));
        assertTrue(entry.description().contains("3000000"));
    }

    @Test
    void deletingAGoalWithNothingSaved_movesNoMoney() {
        SavingGoal goal = lockedGoalOf(alice);
        goal.setCurrentAmount(BigDecimal.ZERO);

        service.deleteSaving(6L);

        verify(transactionService, never()).recordSavingsMovement(any());
        verify(repository).delete(goal);
        assertEquals("Xóa mục tiêu tiết kiệm", recorded().description());
    }

    @Test
    void deleteLocksTheGoalBeforeTheWalletIsCreditedAndDeletesAfterIt() {
        SavingGoal goal = lockedGoalOf(alice);
        theCheckoutRecordsTransaction(901L);

        service.deleteSaving(6L);

        InOrder order = inOrder(repository, transactionService);
        order.verify(repository).findLockedById(6L);
        order.verify(transactionService).recordSavingsMovement(any());
        order.verify(repository).delete(goal);
        verify(repository, never()).findById(any());
    }

    @Test
    void whenTheRefundFailsTheGoalIsNotDeleted() {
        lockedGoalOf(alice);
        when(transactionService.recordSavingsMovement(any())).thenThrow(new IllegalStateException("boom"));

        assertThrows(IllegalStateException.class, () -> service.deleteSaving(6L));

        verify(repository, never()).delete(any());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void aGoalOfSomebodyElseIsRefusedWith403_unchanged_andNoChangeIsRecorded() {
        SavingGoal bobsGoal = lockedGoalOf(bob);

        assertThrows(TransactionAccessDeniedException.class,
                () -> service.updateMySaving(6L, dto("Laptop", "20000000", null, null)));
        assertThrows(TransactionAccessDeniedException.class, () -> service.deleteSaving(6L));

        assertEquals(0, new BigDecimal("1000000").compareTo(bobsGoal.getCurrentAmount()));
        verify(repository, never()).save(any());
        verify(repository, never()).delete(any());
        verifyNoInteractions(auditLogService, transactionService);
    }

    @Test
    void aGoalThatDoesNotExistIsRefused_andNothingIsRecorded() {
        when(repository.findLockedById(99L)).thenReturn(Optional.empty());

        NoSuchElementException refused = assertThrows(NoSuchElementException.class, () -> service.deleteSaving(99L));

        assertEquals("Không tìm thấy mục tiêu tiết kiệm", refused.getMessage());
        verifyNoInteractions(auditLogService);
    }

    // ------------------------------------------------------------------------------------------ contributions (T10c)

    private static final BigDecimal CONTRIBUTION = new BigDecimal("500000");

    /** Bob's or Alice's goal "Mua xe" (6), 1,000,000 of 50,000,000 saved, found under its row lock. */
    private SavingGoal lockedGoalOf(User owner) {
        SavingGoal goal = new SavingGoal();
        goal.setId(6L);
        goal.setTitle("Mua xe");
        goal.setTargetAmount(new BigDecimal("50000000"));
        goal.setCurrentAmount(new BigDecimal("1000000"));
        goal.setUser(owner);
        when(repository.findLockedById(6L)).thenReturn(Optional.of(goal));
        return goal;
    }

    private void theCheckoutRecordsTransaction(long transactionId) {
        when(transactionService.recordSavingsMovement(any(TransactionRequestDto.class)))
                .thenReturn(Map.of("transactionId", transactionId));
    }

    private TransactionRequestDto checkoutSent() {
        ArgumentCaptor<TransactionRequestDto> sent = ArgumentCaptor.forClass(TransactionRequestDto.class);
        verify(transactionService).recordSavingsMovement(sent.capture());
        return sent.getValue();
    }

    @Test
    void aContributionIsAnExpenseOfTheWalletInTheSavingsCategoryNotedWithTheGoalsTitle() {
        lockedGoalOf(alice);
        theCheckoutRecordsTransaction(900L);
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.contributeToMySaving(6L, CONTRIBUTION);

        TransactionRequestDto sent = checkoutSent();
        assertEquals(0, CONTRIBUTION.compareTo(sent.getAmount()));
        assertTrue(sent.isExpense());
        assertEquals("Tiết kiệm", sent.getCategoryName());
        assertNull(sent.getCategoryId());
        assertEquals("Mua xe", sent.getNote());
        assertEquals("WALLET", sent.getPaymentMethod());
        assertNotNull(sent.getTransactionDate());
        assertNull(sent.getRawReceiptData(), "a contribution is no scanned receipt");
    }

    @Test
    void aContributionAddsItsAmountToTheGoal_answersTheGoal_andIsRecordedWithTheTransaction() {
        SavingGoal goal = lockedGoalOf(alice);
        theCheckoutRecordsTransaction(900L);
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));

        SavingGoalDto answer = service.contributeToMySaving(6L, CONTRIBUTION);

        assertEquals(0, new BigDecimal("1500000").compareTo(goal.getCurrentAmount()));
        assertEquals(6L, answer.getId());
        assertEquals("Mua xe", answer.getTitle());
        assertEquals(0, new BigDecimal("1500000").compareTo(answer.getCurrent()));
        assertEquals(0, new BigDecimal("50000000").compareTo(answer.getTarget()));
        verify(repository).save(goal);
        AuditEntry entry = recorded();
        assertEquals(AuditAction.SAVING_UPDATED, entry.action());
        assertEquals(AuditActor.of(alice), entry.actor());
        assertEquals(6L, entry.targetId());
        assertTrue(entry.description().contains("#900"));
        assertNoFigureOrTitleIn(entry);
        assertFalse(entry.description().contains("500000"));
    }

    @Test
    void theGoalIsLockedBeforeTheWalletIsChargedAndSavedAfterIt() {
        SavingGoal goal = lockedGoalOf(alice);
        theCheckoutRecordsTransaction(900L);
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.contributeToMySaving(6L, CONTRIBUTION);

        InOrder inOrder = inOrder(repository, transactionService);
        inOrder.verify(repository).findLockedById(6L);
        inOrder.verify(transactionService).recordSavingsMovement(any());
        inOrder.verify(repository).save(goal);
        verify(repository, never()).findById(any());
    }

    @Test
    void aGoalThatStillHasNoAmountStartsFromZero() {
        SavingGoal goal = lockedGoalOf(alice);
        goal.setCurrentAmount(null);
        theCheckoutRecordsTransaction(900L);
        when(repository.save(any(SavingGoal.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.contributeToMySaving(6L, CONTRIBUTION);

        assertEquals(0, CONTRIBUTION.compareTo(goal.getCurrentAmount()));
    }

    @Test
    void aContributionToAGoalOfSomebodyElseIsRefusedWith403BeforeTheWalletIsTouched() {
        SavingGoal bobsGoal = lockedGoalOf(bob);

        assertThrows(TransactionAccessDeniedException.class, () -> service.contributeToMySaving(6L, CONTRIBUTION));

        assertEquals(0, new BigDecimal("1000000").compareTo(bobsGoal.getCurrentAmount()));
        verifyNoInteractions(transactionService, auditLogService);
        verify(repository, never()).save(any());
    }

    @Test
    void aContributionToAGoalThatDoesNotExistIsRefusedBeforeTheWalletIsTouched() {
        when(repository.findLockedById(99L)).thenReturn(Optional.empty());

        NoSuchElementException refused = assertThrows(NoSuchElementException.class,
                () -> service.contributeToMySaving(99L, CONTRIBUTION));

        assertEquals("Không tìm thấy mục tiêu tiết kiệm", refused.getMessage());
        verifyNoInteractions(transactionService, auditLogService);
    }

    @Test
    void aWalletThatCannotCarryTheContributionLeavesTheGoalAsItWas() {
        SavingGoal goal = lockedGoalOf(alice);
        when(transactionService.recordSavingsMovement(any()))
                .thenThrow(new InsufficientBalanceException("GIAO DỊCH THẤT BẠI: Số dư ví không đủ!"));

        assertThrows(InsufficientBalanceException.class, () -> service.contributeToMySaving(6L, CONTRIBUTION));

        assertEquals(0, new BigDecimal("1000000").compareTo(goal.getCurrentAmount()));
        verify(repository, never()).save(any());
        verifyNoInteractions(auditLogService);
    }
}
