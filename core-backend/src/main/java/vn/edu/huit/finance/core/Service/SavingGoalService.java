package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Objects;
import java.util.Optional;

/**
 * The saving goals of the signed-in caller. No method takes a user id: the owner is the caller, from the SecurityContext,
 * and a goal of somebody else is refused with a 403 (recorded as AUTH_ACCESS_DENIED). Each change and its audit row commit
 * together. Creating, updating and deleting a goal only change figures the owner keeps for themselves (no money moves);
 * a contribution does move money: it is an expense of the wallet in the "Tiết kiệm" category, recorded through
 * TransactionService like any other checkout. Neither the amounts nor the title are part of the audit rows here.
 */
@Slf4j
@Service
public class SavingGoalService {

    private static final String MSG_GOAL_NOT_FOUND = "Không tìm thấy mục tiêu tiết kiệm";
    private static final String MSG_GOAL_FORBIDDEN = "Bạn không có quyền thao tác trên mục tiêu tiết kiệm này";
    private static final String AUDIT_CREATED = "Tạo mục tiêu tiết kiệm";
    private static final String AUDIT_UPDATED = "Cập nhật số tiền đã tiết kiệm";
    private static final String AUDIT_DELETED = "Xóa mục tiêu tiết kiệm";
    private static final String AUDIT_CONTRIBUTED = "Góp tiền vào mục tiêu tiết kiệm (giao dịch #%s)";
    /** Where a contribution comes from: the wallet, under the name the mobile app gives that source. */
    static final String CONTRIBUTION_PAYMENT_METHOD = "WALLET";
    private static final String KEY_TRANSACTION_ID = "transactionId";

    @Autowired
    private SavingGoalRepository savingGoalRepository;

    @Autowired
    private CurrentUserProvider currentUserProvider;

    @Autowired
    private AuditLogService auditLogService;

    @Autowired
    private TransactionService transactionService;

    @Transactional(readOnly = true)
    public List<SavingGoalDto> getMySavings() {
        return savingGoalRepository.findByUserIdOrderByCreatedAtDesc(currentUserProvider.getCurrentUser().getId()).stream()
                .map(SavingGoalService::toDto)
                .toList();
    }

    @Transactional
    public SavingGoalDto createSaving(SavingGoalDto request) {
        User caller = currentUserProvider.getCurrentUser();
        SavingGoal goal = new SavingGoal();
        goal.setTitle(request.getTitle());
        goal.setTargetAmount(request.getTarget());
        goal.setCurrentAmount(request.getCurrent());
        goal.setDeadline(request.getDeadline());
        goal.setUser(caller);
        SavingGoal created = savingGoalRepository.save(goal);

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_CREATED, AuditActor.of(caller), created.getId(), AUDIT_CREATED));
        log.info("Saving goal created, userId={}, goalId={}", caller.getId(), created.getId());
        return toDto(created);
    }

    @Transactional
    public void updateCurrentAmount(Long goalId, BigDecimal currentAmount) {
        User caller = currentUserProvider.getCurrentUser();
        SavingGoal goal = findOwnedGoal(goalId, caller);
        goal.setCurrentAmount(currentAmount);
        savingGoalRepository.save(goal);

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_UPDATED, AuditActor.of(caller), goalId, AUDIT_UPDATED));
        log.info("Saving goal updated, userId={}, goalId={}", caller.getId(), goalId);
    }

    /**
     * Moves [amount] from the caller's wallet into one of their goals, all or nothing: an expense transaction in the
     * "Tiết kiệm" category (note = the goal's title, dated now) is recorded through TransactionService, which locks the
     * wallet, refuses a wallet that cannot carry it (InsufficientBalanceException, 400), raises the budget alerts and
     * reports the changed statistics; then the goal's currentAmount grows by the same amount. The goal row is locked
     * first, so two contributions to one goal add up. A goal that does not exist is refused like everywhere here (400),
     * one of somebody else with a 403, both before the wallet is touched.
     */
    @Transactional
    public SavingGoalDto contributeToMySaving(Long goalId, BigDecimal amount) {
        User caller = currentUserProvider.getCurrentUser();
        SavingGoal goal = requireOwned(savingGoalRepository.findLockedById(goalId), goalId, caller);

        Map<String, Object> checkout = transactionService.recordSavingsMovement(contributionTransaction(goal, amount));
        Object transactionId = checkout.get(KEY_TRANSACTION_ID);

        BigDecimal current = Objects.requireNonNullElse(goal.getCurrentAmount(), BigDecimal.ZERO);
        goal.setCurrentAmount(current.add(amount));
        SavingGoal saved = savingGoalRepository.save(goal);

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_UPDATED, AuditActor.of(caller), goalId,
                String.format(AUDIT_CONTRIBUTED, transactionId)));
        log.info("Saving goal contribution, userId={}, goalId={}, transactionId={}", caller.getId(), goalId, transactionId);
        return toDto(saved);
    }

    /** The expense a contribution records: from the wallet, now, in the savings category, noted with the goal's title. */
    private static TransactionRequestDto contributionTransaction(SavingGoal goal, BigDecimal amount) {
        TransactionRequestDto request = new TransactionRequestDto();
        request.setAmount(amount);
        request.setExpense(true);
        request.setCategoryName(DefaultCategory.SAVINGS.getDisplayName());
        request.setNote(goal.getTitle());
        request.setPaymentMethod(CONTRIBUTION_PAYMENT_METHOD);
        request.setTransactionDate(LocalDateTime.now());
        return request;
    }

    @Transactional
    public void deleteSaving(Long goalId) {
        User caller = currentUserProvider.getCurrentUser();
        savingGoalRepository.delete(findOwnedGoal(goalId, caller));

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_DELETED, AuditActor.of(caller), goalId, AUDIT_DELETED));
        log.info("Saving goal deleted, userId={}, goalId={}", caller.getId(), goalId);
    }

    /** A goal that does not exist is refused like before (400), one that exists but is somebody else's with a 403. */
    private SavingGoal findOwnedGoal(Long goalId, User caller) {
        return requireOwned(savingGoalRepository.findById(goalId), goalId, caller);
    }

    private static SavingGoal requireOwned(Optional<SavingGoal> found, Long goalId, User caller) {
        SavingGoal goal = found.orElseThrow(() -> {
            log.warn("Saving goal not found, userId={}, goalId={}", caller.getId(), goalId);
            return new NoSuchElementException(MSG_GOAL_NOT_FOUND);
        });
        if (!goal.getUser().getId().equals(caller.getId())) {
            log.warn("Saving goal access denied, userId={}, goalId={}", caller.getId(), goalId);
            throw new TransactionAccessDeniedException(MSG_GOAL_FORBIDDEN);
        }
        return goal;
    }

    private static SavingGoalDto toDto(SavingGoal goal) {
        return SavingGoalDto.builder()
                .id(goal.getId())
                .title(goal.getTitle())
                .target(goal.getTargetAmount())
                .current(goal.getCurrentAmount())
                .deadline(goal.getDeadline())
                .build();
    }
}
