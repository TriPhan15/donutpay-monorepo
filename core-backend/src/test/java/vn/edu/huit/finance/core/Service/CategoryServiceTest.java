package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Exception.CategoryInUseException;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Exception.InvalidCategoryException;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;
import org.springframework.context.ApplicationEventPublisher;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;

import java.lang.reflect.Method;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** The shared categories as administrators change them: each change with its row, by the administrator who called. */
@ExtendWith(MockitoExtension.class)
class CategoryServiceTest {

    @Mock private CategoryRepository categoryRepository;
    @Mock private AuditLogService auditLogService;
    @Mock private TransactionRepository transactionRepository;
    @Mock private ApplicationEventPublisher eventPublisher;
    @InjectMocks private CategoryService service;

    private static Category category(Long id, String name) {
        Category category = new Category();
        category.setId(id);
        category.setName(name);
        category.setType("EXPENSE");
        return category;
    }

    private AuditEntry recorded() {
        ArgumentCaptor<AuditEntry> entry = ArgumentCaptor.forClass(AuditEntry.class);
        verify(auditLogService).record(entry.capture());
        return entry.getValue();
    }

    @Test
    void aNewCategoryIsRecordedWithItsNameAndType() {
        when(categoryRepository.save(any(Category.class))).thenAnswer(invocation -> {
            Category saved = invocation.getArgument(0);
            saved.setId(12L);
            return saved;
        });

        service.createCategory("Cà phê", "EXPENSE");

        AuditEntry entry = recorded();
        assertEquals(AuditAction.CATEGORY_CREATED, entry.action());
        assertEquals(AuditActor.currentCaller(), entry.actor());
        assertEquals(12L, entry.targetId());
        assertEquals("Thêm danh mục \"Cà phê\" (EXPENSE)", entry.description());
    }

    @Test
    void aRenameIsRecordedWithTheOldAndTheNewName() {
        when(categoryRepository.findById(12L)).thenReturn(Optional.of(category(12L, "Cà phê")));
        when(categoryRepository.save(any(Category.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.renameCategory(12L, "Ăn ngoài");

        AuditEntry entry = recorded();
        assertEquals(AuditAction.CATEGORY_UPDATED, entry.action());
        assertEquals(12L, entry.targetId());
        assertEquals("Đổi tên danh mục \"Cà phê\" → \"Ăn ngoài\"", entry.description());
    }

    @Test
    void aDeletionIsRecorded_onceTheDatabaseHasAcceptedIt() {
        Category food = category(12L, "Cà phê");
        when(categoryRepository.findById(12L)).thenReturn(Optional.of(food));

        service.deleteCategory(12L);

        verify(categoryRepository).delete(food);
        verify(categoryRepository).flush();
        AuditEntry entry = recorded();
        assertEquals(AuditAction.CATEGORY_DELETED, entry.action());
        assertEquals("Xóa danh mục \"Cà phê\" (EXPENSE)", entry.description());
    }

    @Test
    void aCategoryStillInUseIsNotDeleted_withTheUsualMessage_andNothingIsRecorded() {
        when(categoryRepository.findById(12L)).thenReturn(Optional.of(category(12L, "Cà phê")));
        doThrow(new DataIntegrityViolationException("fk_transactions_category")).when(categoryRepository).flush();

        CategoryInUseException refused = assertThrows(CategoryInUseException.class, () -> service.deleteCategory(12L));

        assertEquals("Không thể xóa danh mục [Cà phê] vì đang có giao dịch sử dụng nó!", refused.getMessage());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void aCategoryThatDoesNotExistIsRefused_andNothingIsRecorded() {
        when(categoryRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(InvalidCategoryException.class, () -> service.renameCategory(99L, "x"));
        assertThrows(InvalidCategoryException.class, () -> service.deleteCategory(99L));

        verifyNoInteractions(auditLogService);
    }

    // ------------------------------------------------------------------------------------------------ A13: default categories

    @Test
    void aDefaultCategoryCannotBeRenamedOrDeleted() {
        when(categoryRepository.findById(5L)).thenReturn(Optional.of(category(5L, "Tiết kiệm")));

        assertThrows(InvalidCategoryException.class, () -> service.renameCategory(5L, "Quỹ"));
        assertThrows(InvalidCategoryException.class, () -> service.deleteCategory(5L));

        verify(categoryRepository, never()).save(any());
        verify(categoryRepository, never()).delete(any());
        verifyNoInteractions(auditLogService, transactionRepository);
    }

    @Test
    void noCategoryMayTakeTheNameOfADefaultOne() {
        when(categoryRepository.findById(12L)).thenReturn(Optional.of(category(12L, "Cà phê")));

        assertThrows(InvalidCategoryException.class, () -> service.renameCategory(12L, " tiết KIỆM "));
        assertThrows(InvalidCategoryException.class, () -> service.createCategory("Tiết kiệm", "EXPENSE"));

        verify(categoryRepository, never()).save(any());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void aRenameCarriesTheNewNameIntoItsTransactions_andAsksTheIndexToReadThemAgain() {
        Category coffee = category(12L, "Cà phê");
        when(categoryRepository.findById(12L)).thenReturn(Optional.of(coffee));
        when(categoryRepository.save(any(Category.class))).thenAnswer(invocation -> invocation.getArgument(0));
        User alice = new User();
        alice.setId(1L);
        Transaction first = new Transaction();
        first.setId(100L);
        first.setUser(alice);
        first.setCategory(coffee);
        first.setCategoryName("Cà phê");
        Transaction second = new Transaction();
        second.setId(101L);
        second.setUser(alice);
        second.setCategory(coffee);
        second.setCategoryName("Cà phê");
        when(transactionRepository.findAllByCategory_Id(12L)).thenReturn(List.of(first, second));

        service.renameCategory(12L, "  Trà sữa ");

        assertEquals("Trà sữa", coffee.getName());
        assertEquals("Trà sữa", first.getCategoryName());
        assertEquals("Trà sữa", second.getCategoryName());
        verify(eventPublisher).publishEvent(TransactionChangedEvent.upserted(100L, 1L, Set.of()));
        verify(eventPublisher).publishEvent(TransactionChangedEvent.upserted(101L, 1L, Set.of()));
        verify(eventPublisher).publishEvent(StatisticsChangedEvent.of(StatisticsChange.TRANSACTION_DETAILS, 1L));
    }

    // ------------------------------------------------------------------------- resolveOrCreate (transactions, budgets)

    @Test
    void resolveOrCreate_reusesAnExistingNameIgnoringCaseAndSurroundingSpaces_andRecordsNothing() {
        Category coffee = category(12L, "Cà phê");
        when(categoryRepository.findFirstByNameIgnoreCaseOrderByIdAsc("cà PHÊ")).thenReturn(Optional.of(coffee));

        Category resolved = service.resolveOrCreate(null, "  cà PHÊ ", CategoryService.TYPE_EXPENSE, AuditActor.system());

        assertSame(coffee, resolved);
        verify(categoryRepository, never()).save(any());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void resolveOrCreate_createsAnUnknownNameTrimmedWithTheGivenType_andRecordsItWithTheActor() {
        when(categoryRepository.findFirstByNameIgnoreCaseOrderByIdAsc("Thú cưng")).thenReturn(Optional.empty());
        when(categoryRepository.save(any(Category.class))).thenAnswer(invocation -> {
            Category saved = invocation.getArgument(0);
            saved.setId(30L);
            return saved;
        });

        Category created = service.resolveOrCreate(null, " Thú cưng ", CategoryService.TYPE_EXPENSE, AuditActor.system());

        assertEquals("Thú cưng", created.getName());
        assertEquals("EXPENSE", created.getType());
        AuditEntry entry = recorded();
        assertEquals(AuditAction.CATEGORY_CREATED, entry.action());
        assertEquals(AuditActor.system(), entry.actor());
        assertEquals(30L, entry.targetId());
    }

    @Test
    void resolveOrCreate_prefersTheIdOverTheName() {
        Category food = category(12L, "Ăn uống");
        when(categoryRepository.findById(12L)).thenReturn(Optional.of(food));

        assertSame(food, service.resolveOrCreate(12L, "Khác hẳn", CategoryService.TYPE_EXPENSE, AuditActor.system()));

        verify(categoryRepository, never()).findFirstByNameIgnoreCaseOrderByIdAsc(any());
        verify(categoryRepository, never()).save(any());
    }

    @Test
    void resolveOrCreate_refusesAnUnknownId_andABlankNameWithoutId() {
        when(categoryRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(InvalidCategoryException.class,
                () -> service.resolveOrCreate(99L, null, CategoryService.TYPE_EXPENSE, AuditActor.system()));
        InvalidCategoryException blank = assertThrows(InvalidCategoryException.class,
                () -> service.resolveOrCreate(null, "   ", CategoryService.TYPE_EXPENSE, AuditActor.system()));

        assertEquals("Thiếu danh mục (categoryId hoặc categoryName)", blank.getMessage());
        verify(categoryRepository, never()).save(any());
        verifyNoInteractions(auditLogService);
    }

    @Test
    void everyChangeRunsInATransaction_soTheChangeAndItsRowCommitTogether() throws NoSuchMethodException {
        for (Method method : new Method[] {
                CategoryService.class.getMethod("createCategory", String.class, String.class),
                CategoryService.class.getMethod("renameCategory", Long.class, String.class),
                CategoryService.class.getMethod("deleteCategory", Long.class),
                CategoryService.class.getMethod("resolveOrCreate", Long.class, String.class, String.class,
                        AuditActor.class)}) {
            assertTrue(AnnotatedElementUtils.hasAnnotation(method, Transactional.class), method.getName());
        }
    }
}
