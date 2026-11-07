package vn.edu.huit.finance.core.Service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Dto.BudgetRequestDto;
import vn.edu.huit.finance.core.Dto.BudgetResponseDto;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.BudgetNotFoundException;
import vn.edu.huit.finance.core.Exception.DuplicateBudgetException;
import vn.edu.huit.finance.core.Repository.BudgetRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyReadService;

import java.util.List;

/**
 * Budgets of the authenticated caller. No method takes a user id: the owner is always resolved from the SecurityContext,
 * and every lookup is scoped to that owner, so a budget of another user behaves exactly like a missing one. Every change
 * is recorded in action_logs with its owner, in its transaction; the amount of a budget is the owner's plan, not money
 * that moved, so it is not part of the row.
 */
@Slf4j
@Service
@RequiredArgsConstructor(onConstructor_ = @Autowired)
public class BudgetService {

    private static final String MSG_BUDGET_NOT_FOUND = "Không tìm thấy ngân sách";
    private static final String MSG_DUPLICATE_BUDGET = "Ngân sách cho danh mục và kỳ hạn này đã tồn tại";
    private static final String AUDIT_BUDGET = "%s ngân sách kỳ %s từ %s, %s";
    private static final String AUDIT_CREATED = "Tạo";
    private static final String AUDIT_UPDATED = "Sửa";
    private static final String AUDIT_DELETED = "Xóa";
    private static final String AUDIT_CATEGORY = "danh mục #%d";
    private static final String AUDIT_ALL_CATEGORIES = "mọi danh mục";

    private final BudgetRepository budgetRepository;
    private final CategoryService categoryService;
    private final CurrentUserProvider currentUserProvider;
    private final AuditLogService auditLogService;
    private final ObjectProvider<MongoStandbyFailoverService> failoverServiceProvider;
    private final ObjectProvider<MongoStandbyReadService> standbyReadServiceProvider;

    public BudgetService() {
        this(null, null, null, null, null, null);
    }

    @Transactional(readOnly = true, propagation = Propagation.SUPPORTS)
    public List<BudgetResponseDto> getMyBudgets() {
        Long userId = currentUserProvider.getCurrentUser().getId();
        MongoStandbyFailoverService failover = failoverService();
        MongoStandbyReadService standby = standbyReadService();
        if (failover != null && standby != null) {
            return failover.executeReadWithFallback(
                    () -> budgetRepository.findAllWithCategoryByUserId(userId).stream()
                            .map(BudgetResponseDto::from)
                            .toList(),
                    () -> standby.getBudgetsByUser(userId),
                    "BudgetService.getMyBudgets"
            );
        }
        return budgetRepository.findAllWithCategoryByUserId(userId).stream()
                .map(BudgetResponseDto::from)
                .toList();
    }

    @Transactional(readOnly = true, propagation = Propagation.SUPPORTS)
    public BudgetResponseDto getMyBudget(Long budgetId) {
        Long userId = currentUserProvider.getCurrentUser().getId();
        MongoStandbyFailoverService failover = failoverService();
        MongoStandbyReadService standby = standbyReadService();
        if (failover != null && standby != null) {
            return failover.executeReadWithFallback(
                    () -> BudgetResponseDto.from(findOwnedBudget(budgetId, userId)),
                    () -> standby.getBudgetByIdAndUser(budgetId, userId),
                    "BudgetService.getMyBudget"
            );
        }
        return BudgetResponseDto.from(findOwnedBudget(budgetId, userId));
    }

    @Transactional
    public BudgetResponseDto createBudget(BudgetRequestDto request) {
        User user = currentUserProvider.getCurrentUser();
        Category category = resolveCategory(request, user);
        if (budgetRepository.existsDuplicate(
                user.getId(), Budget.categoryKeyOf(idOf(category)),
                request.getPeriodType(), request.getStartDate())) {
            throw duplicateBudget(user.getId(), category, request);
        }

        Budget budget = new Budget();
        budget.setUser(user);
        applyRequest(budget, request, category);
        Budget saved = budgetRepository.saveAndFlush(budget);
        record(AuditAction.BUDGET_CREATED, user, saved, AUDIT_CREATED);

        log.info("Budget created, userId={}, budgetId={}", user.getId(), saved.getId());
        return BudgetResponseDto.from(saved);
    }

    @Transactional
    public BudgetResponseDto updateBudget(Long budgetId, BudgetRequestDto request) {
        User caller = currentUserProvider.getCurrentUser();
        Long userId = caller.getId();
        Budget budget = findOwnedBudget(budgetId, userId);
        Category category = resolveCategory(request, caller);
        if (budgetRepository.existsDuplicateExcluding(
                userId, Budget.categoryKeyOf(idOf(category)),
                request.getPeriodType(), request.getStartDate(), budgetId)) {
            throw duplicateBudget(userId, category, request);
        }

        applyRequest(budget, request, category);
        Budget saved = budgetRepository.saveAndFlush(budget);
        record(AuditAction.BUDGET_UPDATED, caller, saved, AUDIT_UPDATED);

        log.info("Budget updated, userId={}, budgetId={}", userId, budgetId);
        return BudgetResponseDto.from(saved);
    }

    @Transactional
    public void deleteBudget(Long budgetId) {
        User caller = currentUserProvider.getCurrentUser();
        Long userId = caller.getId();
        Budget budget = findOwnedBudget(budgetId, userId);
        budgetRepository.delete(budget);
        record(AuditAction.BUDGET_DELETED, caller, budget, AUDIT_DELETED);

        log.info("Budget deleted, userId={}, budgetId={}", userId, budgetId);
    }

    /** One row for a change of one of the caller's budgets: what was done, the period and the category it covers. */
    private void record(AuditAction action, User owner, Budget budget, String verb) {
        String category = budget.getCategory() != null
                ? String.format(AUDIT_CATEGORY, budget.getCategory().getId())
                : AUDIT_ALL_CATEGORIES;
        auditLogService.record(AuditEntry.of(action, AuditActor.of(owner), budget.getId(),
                String.format(AUDIT_BUDGET, verb, budget.getPeriodType(), budget.getStartDate(), category)));
    }

    private Budget findOwnedBudget(Long budgetId, Long userId) {
        return budgetRepository.findWithCategoryByIdAndUserId(budgetId, userId).orElseThrow(() -> {
            log.warn("Budget not found or not owned, userId={}, budgetId={}", userId, budgetId);
            return new BudgetNotFoundException(MSG_BUDGET_NOT_FOUND);
        });
    }

    /**
     * Null when the budget applies to every category. Otherwise by id, or by name (the id wins), through the resolver
     * transactions use: among the default categories and the caller's own, and a new name creates an expense category
     * of the caller's, in this transaction, recorded with the caller.
     */
    private Category resolveCategory(BudgetRequestDto request, User caller) {
        if (!request.hasCategory()) {
            return null;
        }
        return categoryService.resolveOrCreate(request.getCategoryId(), request.getCategoryName(),
                CategoryService.TYPE_EXPENSE, caller, AuditActor.of(caller));
    }

    private static Long idOf(Category category) {
        return category == null ? null : category.getId();
    }

    private void applyRequest(Budget budget, BudgetRequestDto request, Category category) {
        budget.setCategory(category);
        budget.setAmount(request.getAmount());
        budget.setPeriodType(request.getPeriodType());
        budget.setStartDate(request.getStartDate());
        budget.setEndDate(request.getEndDate());
    }

    private DuplicateBudgetException duplicateBudget(Long userId, Category category, BudgetRequestDto request) {
        log.warn("Budget rejected: duplicate, userId={}, categoryId={}, periodType={}, startDate={}",
                userId, idOf(category), request.getPeriodType(), request.getStartDate());
        return new DuplicateBudgetException(MSG_DUPLICATE_BUDGET);
    }

    private MongoStandbyFailoverService failoverService() {
        return failoverServiceProvider != null ? failoverServiceProvider.getIfAvailable() : null;
    }

    private MongoStandbyReadService standbyReadService() {
        return standbyReadServiceProvider != null ? standbyReadServiceProvider.getIfAvailable() : null;
    }
}
