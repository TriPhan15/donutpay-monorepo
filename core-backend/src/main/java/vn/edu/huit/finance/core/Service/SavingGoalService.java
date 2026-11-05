package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.SavingGoalNotFoundException;
import vn.edu.huit.finance.core.Exception.SavingsLedgerException;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyReadService;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

/**
 * The saving goals of the signed-in caller. No method takes a user id: the owner is the caller, from the SecurityContext,
 * and a goal of somebody else is refused with a 403 (recorded as AUTH_ACCESS_DENIED). Each change and its audit row commit
 * together. Creating and updating a goal only change figures the owner keeps for themselves (the saved amount starts at 0 and
 * never comes from a request); a contribution and the refund of a deleted goal do move money: a contribution is an expense of the wallet in the "Tiết kiệm" category, recorded through
 * TransactionService like any other checkout. Neither the amounts nor the title are part of the audit rows here.
 */
@Slf4j
@Service
public class SavingGoalService {

    private static final String MSG_GOAL_NOT_FOUND = "Không tìm thấy mục tiêu tiết kiệm";
    private static final String MSG_GOAL_FORBIDDEN = "Bạn không có quyền thao tác trên mục tiêu tiết kiệm này";
    private static final String AUDIT_CREATED = "Tạo mục tiêu tiết kiệm";
    private static final String AUDIT_UPDATED = "Cập nhật mục tiêu tiết kiệm";
    private static final String AUDIT_DELETED = "Xóa mục tiêu tiết kiệm";
    private static final String AUDIT_DELETED_WITH_REFUND = "Xóa mục tiêu tiết kiệm, hoàn %s VNĐ vào ví (giao dịch #%s)";
    static final String MSG_CURRENT_ONLY_BY_CONTRIBUTION = "Số tiền đã tiết kiệm chỉ thay đổi qua Góp tiền";
    static final String MSG_NEW_GOAL_STARTS_EMPTY =
            "Mục tiêu mới bắt đầu từ 0đ. Hãy dùng Góp tiền để chuyển tiền từ ví vào mục tiêu";
    static final String REFUND_NOTE = "Hoàn tiền từ mục tiêu tiết kiệm đã xóa: %s";
    private static final String AUDIT_CONTRIBUTED = "Góp tiền vào mục tiêu tiết kiệm (giao dịch #%s)";
    /** Where a contribution comes from: the wallet, under the name the mobile app gives that source. */
    static final String CONTRIBUTION_PAYMENT_METHOD = "WALLET";
    /** A refund goes back to the wallet the same way. */
    static final String REFUND_PAYMENT_METHOD = CONTRIBUTION_PAYMENT_METHOD;
    private static final String KEY_TRANSACTION_ID = "transactionId";

    @Autowired
    private SavingGoalRepository savingGoalRepository;

    @Autowired
    private CurrentUserProvider currentUserProvider;

    @Autowired
    private AuditLogService auditLogService;

    @Autowired
    private TransactionService transactionService;

    @Autowired(required = false)
    private MongoStandbyFailoverService failoverService;

    @Autowired(required = false)
    private MongoStandbyReadService standbyReadService;

    @Transactional(readOnly = true, propagation = Propagation.SUPPORTS)
    public List<SavingGoalDto> getMySavings() {
        Long userId = currentUserProvider.getCurrentUser().getId();
        if (failoverService != null && standbyReadService != null) {
            return failoverService.executeReadWithFallback(
                    () -> savingGoalRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                            .map(SavingGoalService::toDto)
                            .toList(),
                    () -> standbyReadService.getSavingsByUser(userId),
                    "SavingGoalService.getMySavings"
            );
        }
        return savingGoalRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(SavingGoalService::toDto)
                .toList();
    }

    @Transactional
    public SavingGoalDto createSaving(SavingGoalDto request) {
        User caller = currentUserProvider.getCurrentUser();
        if (request.getCurrent() != null && request.getCurrent().signum() > 0) {
            log.warn("Saving goal with a starting amount refused, userId={}", caller.getId());
            throw new SavingsLedgerException(MSG_NEW_GOAL_STARTS_EMPTY);
        }
        SavingGoal goal = new SavingGoal();
        goal.setTitle(request.getTitle());
        goal.setTargetAmount(request.getTarget());
        goal.setCurrentAmount(BigDecimal.ZERO);
        goal.setDeadline(request.getDeadline());
        goal.setUser(caller);
        SavingGoal created = savingGoalRepository.save(goal);

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_CREATED, AuditActor.of(caller), created.getId(), AUDIT_CREATED));
        log.info("Saving goal created, userId={}, goalId={}", caller.getId(), created.getId());
        return toDto(created);
    }

    /**
     * Changes the title, target and deadline. The saved amount is never taken from the request: it only moves through
     * contributions and the refund of a deletion, so a [current] that differs from the stored one is refused (409).
     * The goal row is locked so a concurrent contribution is not overwritten.
     */
    @Transactional
    public SavingGoalDto updateMySaving(Long goalId, SavingGoalDto request) {
        User caller = currentUserProvider.getCurrentUser();
        SavingGoal goal = requireOwned(savingGoalRepository.findLockedById(goalId), goalId, caller);
        if (request.getCurrent() != null && request.getCurrent().compareTo(savedAmount(goal)) != 0) {
            log.warn("Saving goal amount change refused, userId={}, goalId={}", caller.getId(), goalId);
            throw new SavingsLedgerException(MSG_CURRENT_ONLY_BY_CONTRIBUTION);
        }
        goal.setTitle(request.getTitle());
        goal.setTargetAmount(request.getTarget());
        goal.setDeadline(request.getDeadline());
        SavingGoal saved = savingGoalRepository.save(goal);

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_UPDATED, AuditActor.of(caller), goalId, AUDIT_UPDATED));
        log.info("Saving goal updated, userId={}, goalId={}", caller.getId(), goalId);
        return toDto(saved);
    }

    private static BigDecimal savedAmount(SavingGoal goal) {
        return Objects.requireNonNullElse(goal.getCurrentAmount(), BigDecimal.ZERO);
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

        goal.setCurrentAmount(savedAmount(goal).add(amount));
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

    /**
     * Deletes a goal; the money it holds goes back to the wallet in the same transaction, as an income of "Thu khác"
     * naming the goal. The goal row is locked first so a concurrent contribution cannot slip in between.
     */
    @Transactional
    public void deleteSaving(Long goalId) {
        User caller = currentUserProvider.getCurrentUser();
        SavingGoal goal = requireOwned(savingGoalRepository.findLockedById(goalId), goalId, caller);
        BigDecimal refund = savedAmount(goal);

        String audit = AUDIT_DELETED;
        if (refund.signum() > 0) {
            // GOAL_REFUND: the wallet gets the money back, but it is no income for the statistics or the AI.
            Object transactionId = transactionService.recordSavingsMovement(refundTransaction(goal, refund),
                    TransactionSource.GOAL_REFUND).get(KEY_TRANSACTION_ID);
            audit = String.format(AUDIT_DELETED_WITH_REFUND, refund.toPlainString(), transactionId);
            log.info("Saving goal refunded to the wallet, userId={}, goalId={}, amount={}", caller.getId(), goalId, refund);
        }
        savingGoalRepository.delete(goal);

        auditLogService.record(AuditEntry.of(AuditAction.SAVING_DELETED, AuditActor.of(caller), goalId, audit));
        log.info("Saving goal deleted, userId={}, goalId={}", caller.getId(), goalId);
    }

    /** The income a deletion records: back into the wallet, now, as "Thu khác", noted with the goal's title. */
    private static TransactionRequestDto refundTransaction(SavingGoal goal, BigDecimal amount) {
        TransactionRequestDto request = new TransactionRequestDto();
        request.setAmount(amount);
        request.setExpense(false);
        request.setCategoryName(DefaultCategory.OTHER_INCOME.getDisplayName());
        request.setNote(String.format(REFUND_NOTE, goal.getTitle()));
        request.setPaymentMethod(REFUND_PAYMENT_METHOD);
        request.setTransactionDate(LocalDateTime.now());
        return request;
    }

    private static SavingGoal requireOwned(Optional<SavingGoal> found, Long goalId, User caller) {
        SavingGoal goal = found.orElseThrow(() -> {
            log.warn("Saving goal not found, userId={}, goalId={}", caller.getId(), goalId);
            return new SavingGoalNotFoundException(MSG_GOAL_NOT_FOUND);
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
