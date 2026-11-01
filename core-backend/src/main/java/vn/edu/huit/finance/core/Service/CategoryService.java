package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Exception.CategoryInUseException;
import vn.edu.huit.finance.core.Exception.InvalidCategoryException;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * The shared categories. createCategory, renameCategory and deleteCategory are for administrators only (the caller
 * checks that); each change and its audit row, naming the administrator, commit together. {@link #resolveOrCreate} is
 * the one place where a category a user names (in a transaction or a budget) is looked up or created.
 */
@Slf4j
@Service
public class CategoryService {

    public static final String TYPE_EXPENSE = "EXPENSE";
    public static final String TYPE_INCOME = "INCOME";

    private static final String MSG_CATEGORY_NOT_FOUND = "Không tìm thấy danh mục";
    private static final String MSG_CATEGORY_REQUIRED = "Thiếu danh mục (categoryId hoặc categoryName)";
    private static final String MSG_CATEGORY_IN_USE = "Không thể xóa danh mục [%s] vì đang có giao dịch sử dụng nó!";
    private static final String MSG_DEFAULT_LOCKED = "Không thể đổi tên hoặc xóa danh mục mặc định [%s]";
    private static final String MSG_DEFAULT_NAME_TAKEN = "Tên [%s] là tên của một danh mục mặc định";
    private static final String AUDIT_CREATED_BY_NAME = "Tạo danh mục \"%s\" (%s) theo tên người dùng nhập";
    private static final String AUDIT_CREATED = "Thêm danh mục \"%s\" (%s)";
    private static final String AUDIT_RENAMED = "Đổi tên danh mục \"%s\" → \"%s\"";
    private static final String AUDIT_DELETED = "Xóa danh mục \"%s\" (%s)";

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private AuditLogService auditLogService;

    @Autowired
    private TransactionRepository transactionRepository;

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    /** Mọi danh mục, cho trang quản trị. */
    @Transactional(readOnly = true)
    public List<Category> listAll() {
        return categoryRepository.findAll();
    }

    /** Thêm một danh mục; tên trùng tên danh mục mặc định (Tiết kiệm, Ăn uống...) bị từ chối. */
    @Transactional
    public Category createCategory(String name, String type) {
        name = name.trim();
        refuseDefaultName(name);
        Category category = new Category();
        category.setName(name);
        category.setType(type);
        Category created = categoryRepository.save(category);

        record(AuditAction.CATEGORY_CREATED, created.getId(), String.format(AUDIT_CREATED, created.getName(), created.getType()));
        log.info("Category created, categoryId={}", created.getId());
        return created;
    }

    /**
     * Đổi tên một danh mục do admin thêm. Danh mục mặc định không đổi tên được (quy tắc tiết kiệm và phần loại trừ khỏi
     * ngân sách/thống kê dựa vào tên "Tiết kiệm"), và không đổi sang tên của một danh mục mặc định. Tên lưu trùng ở
     * transactions.category_name được cập nhật theo, và mỗi giao dịch được phát lại để chỉ mục tìm kiếm đọc tên mới.
     */
    @Transactional
    public Category renameCategory(Long categoryId, String name) {
        name = name.trim();
        Category category = findCategory(categoryId);
        refuseDefaultCategory(category);
        refuseDefaultName(name);
        String previousName = category.getName();
        category.setName(name);
        Category renamed = categoryRepository.save(category);

        List<Transaction> transactions = transactionRepository.findAllByCategory_Id(categoryId);
        Set<Long> owners = new HashSet<>();
        for (Transaction transaction : transactions) {
            transaction.setCategoryName(renamed.getName());
            owners.add(transaction.getUser().getId());
            eventPublisher.publishEvent(TransactionChangedEvent.upserted(transaction.getId(), transaction.getUser().getId(), Set.of()));
        }
        owners.forEach(userId -> eventPublisher.publishEvent(StatisticsChangedEvent.of(StatisticsChange.TRANSACTION_DETAILS, userId)));

        record(AuditAction.CATEGORY_UPDATED, categoryId, String.format(AUDIT_RENAMED, previousName, renamed.getName()));
        log.info("Category renamed, categoryId={}, transactions={}", categoryId, transactions.size());
        return renamed;
    }

    /** Refused while a transaction or a budget still uses the category: nothing is deleted then, and nothing recorded. */
    @Transactional
    public void deleteCategory(Long categoryId) {
        Category category = findCategory(categoryId);
        refuseDefaultCategory(category);
        try {
            categoryRepository.delete(category);
            categoryRepository.flush();
        } catch (DataIntegrityViolationException e) {
            log.warn("Category deletion refused, it is still in use, categoryId={}", categoryId);
            throw new CategoryInUseException(String.format(MSG_CATEGORY_IN_USE, category.getName()));
        }

        record(AuditAction.CATEGORY_DELETED, categoryId, String.format(AUDIT_DELETED, category.getName(), category.getType()));
        log.info("Category deleted, categoryId={}", categoryId);
    }

    /**
     * By id, or by name; the id wins when both are given. The name is trimmed and compared ignoring case, so "cà phê"
     * reuses "Cà phê". A name that does not exist yet creates the category with the given type; a category is shared by
     * every user, so its creation is recorded (CATEGORY_CREATED) with the actor who caused it, in the caller's transaction.
     *
     * @throws InvalidCategoryException for an unknown id, or when neither an id nor a non-blank name is given
     */
    @Transactional
    public Category resolveOrCreate(Long categoryId, String categoryName, String typeIfCreated, AuditActor actor) {
        if (categoryId != null) {
            return findCategory(categoryId);
        }
        if (categoryName == null || categoryName.isBlank()) {
            throw new InvalidCategoryException(MSG_CATEGORY_REQUIRED);
        }
        String name = categoryName.trim();
        return categoryRepository.findFirstByNameIgnoreCaseOrderByIdAsc(name)
                .orElseGet(() -> createByName(name, typeIfCreated, actor));
    }

    /** The type a category created by name gets from the direction of the money it is named for. */
    public static String typeOf(boolean isExpense) {
        return isExpense ? TYPE_EXPENSE : TYPE_INCOME;
    }

    private Category createByName(String name, String type, AuditActor actor) {
        Category category = new Category();
        category.setName(name);
        category.setType(type);
        Category saved = categoryRepository.save(category);
        auditLogService.record(AuditEntry.of(AuditAction.CATEGORY_CREATED, actor, saved.getId(),
                String.format(AUDIT_CREATED_BY_NAME, saved.getName(), saved.getType())));
        log.info("Category created by name, categoryId={}", saved.getId());
        return saved;
    }

    private Category findCategory(Long categoryId) {
        return categoryRepository.findById(categoryId).orElseThrow(() -> {
            log.warn("Category not found, categoryId={}", categoryId);
            return new InvalidCategoryException(MSG_CATEGORY_NOT_FOUND);
        });
    }

    /** Danh mục mặc định (cùng tên và loại với một DefaultCategory) không được đổi tên hay xóa. */
    private static void refuseDefaultCategory(Category category) {
        boolean isDefault = Arrays.stream(DefaultCategory.values()).anyMatch(d ->
                d.getDisplayName().equals(category.getName()) && d.getType().equals(category.getType()));
        if (isDefault) {
            log.warn("Change of a default category refused, categoryId={}", category.getId());
            throw new InvalidCategoryException(String.format(MSG_DEFAULT_LOCKED, category.getName()));
        }
    }

    /** Tên của một danh mục mặc định (không phân biệt hoa thường) không được dùng cho danh mục khác. */
    private static void refuseDefaultName(String name) {
        boolean taken = Arrays.stream(DefaultCategory.values()).anyMatch(d -> d.getDisplayName().equalsIgnoreCase(name));
        if (taken) {
            log.warn("Category name of a default category refused");
            throw new InvalidCategoryException(String.format(MSG_DEFAULT_NAME_TAKEN, name));
        }
    }

    /** By the administrator who called, looked up when the row is written. */
    private void record(AuditAction action, Long categoryId, String description) {
        auditLogService.record(AuditEntry.of(action, AuditActor.currentCaller(), categoryId, description));
    }
}
