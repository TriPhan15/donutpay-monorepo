package vn.edu.huit.finance.core.Service.Backup;

import org.bson.Document;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import vn.edu.huit.finance.core.Document.Backup.PgBackupBudgetDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupSavingGoalDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;
import vn.edu.huit.finance.core.Dto.AppDashboardResponseDto;
import vn.edu.huit.finance.core.Dto.BudgetResponseDto;
import vn.edu.huit.finance.core.Dto.CategoryResponseDto;
import vn.edu.huit.finance.core.Dto.MirrorStatusResponseDto;
import vn.edu.huit.finance.core.Dto.PopularVendorResponseDto;
import vn.edu.huit.finance.core.Dto.ReceiptResponseDto;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Dto.StandbyEntityChangedEvent;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Dto.TransactionFilterRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchResponseDto;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.BudgetRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupBudgetRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupCategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupSavingGoalRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupTransactionRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupUserRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MongoSelectiveBackupAndFailoverTest {

    @Mock private UserRepository userRepo;
    @Mock private CategoryRepository categoryRepo;
    @Mock private TransactionRepository transactionRepo;
    @Mock private ReceiptRepository receiptRepo;
    @Mock private BudgetRepository budgetRepo;
    @Mock private SavingGoalRepository savingGoalRepo;

    @Mock private PgBackupUserRepository backupUserRepo;
    @Mock private PgBackupCategoryRepository backupCategoryRepo;
    @Mock private PgBackupTransactionRepository backupTransactionRepo;
    @Mock private PgBackupBudgetRepository backupBudgetRepo;
    @Mock private PgBackupSavingGoalRepository backupSavingGoalRepo;

    @Mock private JdbcTemplate jdbcTemplate;
    @Mock private MongoTemplate mongoTemplate;

    private MongoStandbyFailoverService failoverService;
    private MongoStandbyReadService standbyReadService;
    private MongoSelectiveMirrorService mirrorService;
    private MongoSelectiveRestoreService restoreService;

    @BeforeEach
    void setUp() {
        failoverService = new MongoStandbyFailoverService();
        standbyReadService = new MongoStandbyReadService(
                backupUserRepo, backupCategoryRepo, backupTransactionRepo, backupBudgetRepo, backupSavingGoalRepo
        );
        mirrorService = new MongoSelectiveMirrorService(
                userRepo, categoryRepo, transactionRepo, receiptRepo, budgetRepo, savingGoalRepo,
                backupUserRepo, backupCategoryRepo, backupTransactionRepo, backupBudgetRepo, backupSavingGoalRepo,
                failoverService, jdbcTemplate, mongoTemplate
        );
        restoreService = new MongoSelectiveRestoreService(
                backupUserRepo, backupCategoryRepo, backupTransactionRepo, backupBudgetRepo, backupSavingGoalRepo,
                jdbcTemplate, failoverService, mirrorService
        );
    }

    @Test
    @SuppressWarnings("unchecked")
    void syncAllFromPostgresToMongo_mirrorsAll5CollectionsIncludingEmbeddedReceiptAndReview() {
        User user = new User();
        user.setId(10L);
        user.setUsername("tien");
        user.setEmail("tien@huit.edu.vn");
        user.setPassword("$2a$10$hash");
        user.setRole("ROLE_USER");
        user.setActive(true);
        user.setWalletBalance(new BigDecimal("1500000.00"));
        user.setCredentialsVersion(2);

        Category category = new Category();
        category.setId(3L);
        category.setName("Ăn uống");
        category.setType("EXPENSE");
        category.setOwner(user);

        Receipt receipt = new Receipt();
        receipt.setId(55L);
        receipt.setVendorName("Highlands Coffee");
        receipt.setExtractedTotal(new BigDecimal("65000.00"));
        receipt.setExtractedDate(LocalDate.of(2026, 5, 10));
        receipt.setImageUrl("https://res.cloudinary.com/demo/receipt.jpg");
        receipt.setStatus(ReceiptStatus.COMPLETED_RAW.name());
        receipt.setVersion(1L);
        receipt.setOwner(user);

        Transaction tx = new Transaction();
        tx.setId(100L);
        tx.setUser(user);
        tx.setCategory(category);
        tx.setCategoryName("Ăn uống");
        tx.setAmount(new BigDecimal("65000.00"));
        tx.setNote("Cà phê sáng");
        tx.setTransactionDate(LocalDateTime.of(2026, 5, 10, 8, 30));
        tx.setExpense(true);
        tx.setSource(TransactionSource.NORMAL);
        tx.setRating(new BigDecimal("4.5"));
        tx.setReviewNote("Đồ uống ngon");
        tx.setReceipt(receipt);

        Budget budget = new Budget();
        budget.setId(20L);
        budget.setUser(user);
        budget.setCategory(category);
        budget.setAmount(new BigDecimal("3000000.00"));
        budget.setPeriodType(BudgetPeriodType.MONTH);
        budget.setStartDate(LocalDate.of(2026, 5, 1));
        budget.setEndDate(LocalDate.of(2026, 5, 31));

        SavingGoal goal = new SavingGoal();
        goal.setId(30L);
        goal.setUser(user);
        goal.setTitle("Mua laptop");
        goal.setTargetAmount(new BigDecimal("25000000.00"));
        goal.setCurrentAmount(new BigDecimal("5000000.00"));
        goal.setDeadline("2026-12-31");

        when(userRepo.findAll()).thenReturn(List.of(user));
        when(categoryRepo.findAllWithOwner()).thenReturn(List.of(category));
        when(transactionRepo.findAllWithDetailsForBackup()).thenReturn(List.of(tx));
        when(budgetRepo.findAllWithUserAndCategory()).thenReturn(List.of(budget));
        when(savingGoalRepo.findAllWithUser()).thenReturn(List.of(goal));

        Map<String, Object> summary = mirrorService.syncAllFromPostgresToMongo();

        assertThat(summary.get("users")).isEqualTo(1);
        assertThat(summary.get("categories")).isEqualTo(1);
        assertThat(summary.get("transactions")).isEqualTo(1);
        assertThat(summary.get("embeddedReceipts")).isEqualTo(1L);
        assertThat(summary.get("budgets")).isEqualTo(1);
        assertThat(summary.get("savingGoals")).isEqualTo(1);

        ArgumentCaptor<List<PgBackupTransactionDocument>> txCaptor = ArgumentCaptor.forClass(List.class);
        verify(backupTransactionRepo).saveAll(txCaptor.capture());
        PgBackupTransactionDocument savedTx = txCaptor.getValue().get(0);
        assertThat(savedTx.getId()).isEqualTo(100L);
        assertThat(savedTx.getRating()).isEqualByComparingTo("4.5");
        assertThat(savedTx.getReviewNote()).isEqualTo("Đồ uống ngon");
        assertThat(savedTx.getReceipt()).isNotNull();
        assertThat(savedTx.getReceipt().getId()).isEqualTo(55L);
        assertThat(savedTx.getReceipt().getVendorName()).isEqualTo("Highlands Coffee");
    }

    @Test
    void restoreAllFromMongoToPostgres_restores6TablesInForeignKeyOrderAndResetsSequences() {
        PgBackupUserDocument userDoc = PgBackupUserDocument.builder()
                .id(10L)
                .username("tien")
                .email("tien@huit.edu.vn")
                .password("$2a$10$hash")
                .role("ROLE_USER")
                .active(true)
                .walletBalance(new BigDecimal("1500000.00"))
                .credentialsVersion(2)
                .build();

        PgBackupCategoryDocument catDoc = PgBackupCategoryDocument.builder()
                .id(3L)
                .name("Ăn uống")
                .type("EXPENSE")
                .ownerId(10L)
                .ownerKey(10L)
                .build();

        PgBackupTransactionDocument txDoc = PgBackupTransactionDocument.builder()
                .id(100L)
                .userId(10L)
                .categoryId(3L)
                .categoryName("Ăn uống")
                .amount(new BigDecimal("65000.00"))
                .note("Cà phê sáng")
                .transactionDate(LocalDateTime.of(2026, 5, 10, 8, 30))
                .isExpense(true)
                .source("NORMAL")
                .rating(new BigDecimal("4.5"))
                .reviewNote("Đồ uống ngon")
                .receipt(PgBackupTransactionDocument.EmbeddedReceipt.builder()
                        .id(55L)
                        .vendorName("Highlands Coffee")
                        .extractedTotal(new BigDecimal("65000.00"))
                        .extractedDate(LocalDate.of(2026, 5, 10))
                        .status("COMPLETED_RAW")
                        .version(1L)
                        .ownerId(10L)
                        .build())
                .build();

        PgBackupBudgetDocument budgetDoc = PgBackupBudgetDocument.builder()
                .id(20L)
                .userId(10L)
                .categoryId(3L)
                .categoryKey(3L)
                .amount(new BigDecimal("3000000.00"))
                .periodType("MONTH")
                .startDate(LocalDate.of(2026, 5, 1))
                .endDate(LocalDate.of(2026, 5, 31))
                .build();

        PgBackupSavingGoalDocument goalDoc = PgBackupSavingGoalDocument.builder()
                .id(30L)
                .userId(10L)
                .title("Mua laptop")
                .targetAmount(new BigDecimal("25000000.00"))
                .currentAmount(new BigDecimal("5000000.00"))
                .deadline("2026-12-31")
                .build();

        when(backupUserRepo.findAll()).thenReturn(List.of(userDoc));
        when(backupCategoryRepo.findAll()).thenReturn(List.of(catDoc));
        when(backupTransactionRepo.findAll()).thenReturn(List.of(txDoc));
        when(backupBudgetRepo.findAll()).thenReturn(List.of(budgetDoc));
        when(backupSavingGoalRepo.findAll()).thenReturn(List.of(goalDoc));
        when(jdbcTemplate.queryForObject(anyString(), eq(Long.class))).thenReturn(1L);

        failoverService.setForceFailoverEnabled(true);
        Map<String, Object> result = restoreService.restoreAllFromMongoToPostgres();

        assertThat(result.get("users")).isEqualTo(1);
        assertThat(result.get("categories")).isEqualTo(1);
        assertThat(result.get("receipts")).isEqualTo(1);
        assertThat(result.get("transactions")).isEqualTo(1);
        assertThat(result.get("budgets")).isEqualTo(1);
        assertThat(result.get("savingGoals")).isEqualTo(1);
        assertThat(failoverService.isForceFailoverEnabled()).isFalse();

        // 6 bảng được reset sequence
        verify(jdbcTemplate, times(6)).queryForObject(contains("pg_get_serial_sequence"), eq(Long.class));
        verify(jdbcTemplate, atLeastOnce()).update(contains("INSERT INTO users"), any(Object[].class));
        verify(jdbcTemplate, atLeastOnce()).update(contains("INSERT INTO categories"), any(Object[].class));
        verify(jdbcTemplate, atLeastOnce()).update(contains("INSERT INTO receipts"), any(Object[].class));
        verify(jdbcTemplate, atLeastOnce()).update(contains("INSERT INTO transactions"), any(Object[].class));
        verify(jdbcTemplate, atLeastOnce()).update(contains("INSERT INTO budgets"), any(Object[].class));
        verify(jdbcTemplate, atLeastOnce()).update(contains("INSERT INTO saving_goals"), any(Object[].class));
    }

    @Test
    void executeReadWithFallback_switchesToMongoWhenPostgresThrowsConnectionExceptionOrForceFailoverEnabled() {
        String pgResult = failoverService.executeReadWithFallback(
                () -> "FROM_PG",
                () -> "FROM_MONGO",
                "testOp"
        );
        assertThat(pgResult).isEqualTo("FROM_PG");

        // Khi PostgreSQL ném lỗi mất kết nối, tự động fallback sang MongoDB và bật mạch ngắt 30s
        String fallbackResult = failoverService.executeReadWithFallback(
                () -> {
                    throw new DataAccessResourceFailureException("Connection refused: finance-postgres:5432");
                },
                () -> "FROM_MONGO_ON_ERROR",
                "testOp"
        );
        assertThat(fallbackResult).isEqualTo("FROM_MONGO_ON_ERROR");
        assertThat(failoverService.isAutoFailoverActive()).isTrue();
        assertThat(failoverService.getEffectiveReadSource()).isEqualTo(MongoStandbyFailoverService.SOURCE_MONGO_STANDBY);

        // Khi xóa auto-failover nhưng bật Force Failover Mode
        failoverService.clearAutoFailover();
        failoverService.setForceFailoverEnabled(true);
        String forcedResult = failoverService.executeReadWithFallback(
                () -> "FROM_PG",
                () -> "FROM_MONGO_FORCED",
                "testOp"
        );
        assertThat(forcedResult).isEqualTo("FROM_MONGO_FORCED");
    }

    @Test
    void standbyReadService_servesAllMobileEndpointsFromMongoCollections() {
        PgBackupCategoryDocument cat1 = PgBackupCategoryDocument.builder()
                .id(1L).name("Ăn uống").type("EXPENSE").ownerId(null).ownerKey(0L).build();
        when(backupCategoryRepo.findVisibleToUser(10L)).thenReturn(List.of(cat1));

        List<CategoryResponseDto> categories = standbyReadService.listCategoriesFor(10L);
        assertThat(categories).hasSize(1);
        assertThat(categories.get(0).getName()).isEqualTo("Ăn uống");

        PgBackupTransactionDocument txDoc = PgBackupTransactionDocument.builder()
                .id(100L)
                .userId(10L)
                .categoryId(1L)
                .categoryName("Ăn uống")
                .amount(new BigDecimal("120000.00"))
                .note("Ăn trưa Phở Hà Nội")
                .transactionDate(LocalDateTime.of(2026, 5, 10, 12, 0))
                .isExpense(true)
                .source("NORMAL")
                .voucherCode("SALE10")
                .rating(new BigDecimal("5.0"))
                .reviewNote("Nước dùng đậm đà")
                .receipt(PgBackupTransactionDocument.EmbeddedReceipt.builder()
                        .id(55L)
                        .vendorName("Phở Hà Nội")
                        .extractedTotal(new BigDecimal("120000.00"))
                        .status("COMPLETED_RAW")
                        .version(1L)
                        .ownerId(10L)
                        .build())
                .build();
        when(backupTransactionRepo.findByUserIdOrderByTransactionDateDescIdDesc(10L)).thenReturn(List.of(txDoc));
        when(backupTransactionRepo.findByReceipt_Id(55L)).thenReturn(Optional.of(txDoc));
        when(backupTransactionRepo.findById(100L)).thenReturn(Optional.of(txDoc));

        // Transactions mine, filter, search, popular-vendors, app-dashboard, receipts
        List<TransactionResponseDto> mine = standbyReadService.getTransactionsByUser(10L);
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).getRating()).isEqualByComparingTo("5.0");

        TransactionFilterRequestDto filter = TransactionFilterRequestDto.builder()
                .categoryId(1L)
                .vendorName("phở")
                .sortBy("transactionDate")
                .sortDirection("DESC")
                .build();
        assertThat(standbyReadService.filterTransactions(10L, filter)).hasSize(1);

        TransactionSearchRequestDto searchReq = new TransactionSearchRequestDto();
        searchReq.setQ("pho ha noi");
        searchReq.setPage(0);
        searchReq.setSize(10);
        TransactionSearchResponseDto searchRes = standbyReadService.searchTransactions(10L, searchReq);
        assertThat(searchRes.getTotal()).isEqualTo(1L);

        List<PopularVendorResponseDto> vendors = standbyReadService.popularVendorsOf(10L);
        assertThat(vendors).hasSize(1);
        assertThat(vendors.get(0).getVendorName()).isEqualTo("Phở Hà Nội");

        AppDashboardResponseDto dashboard = standbyReadService.dashboardOf(10L);
        assertThat(dashboard.getRecentTransactions()).hasSize(1);
        assertThat(dashboard.getBiggestTransaction().getId()).isEqualTo(100L);
        assertThat(dashboard.getSaleTransactions()).hasSize(1);

        ReceiptResponseDto r1 = standbyReadService.getReceiptForUser(55L, 10L);
        assertThat(r1.getVendorName()).isEqualTo("Phở Hà Nội");
        assertThat(r1.getTransactionId()).isEqualTo(100L);

        ReceiptResponseDto r2 = standbyReadService.getReceiptOfTransactionForUser(100L, 10L);
        assertThat(r2.getId()).isEqualTo(55L);

        // Budgets & Saving goals
        PgBackupBudgetDocument bDoc = PgBackupBudgetDocument.builder()
                .id(20L).userId(10L).categoryId(1L).categoryName("Ăn uống")
                .amount(new BigDecimal("2000000.00")).periodType("MONTH")
                .startDate(LocalDate.of(2026, 5, 1)).endDate(LocalDate.of(2026, 5, 31)).build();
        when(backupBudgetRepo.findByUserIdOrderByStartDateDescIdDesc(10L)).thenReturn(List.of(bDoc));
        when(backupBudgetRepo.findByIdAndUserId(20L, 10L)).thenReturn(Optional.of(bDoc));

        List<BudgetResponseDto> budgets = standbyReadService.getBudgetsByUser(10L);
        assertThat(budgets).hasSize(1);
        assertThat(standbyReadService.getBudgetByIdAndUser(20L, 10L).getCategoryName()).isEqualTo("Ăn uống");

        PgBackupSavingGoalDocument gDoc = PgBackupSavingGoalDocument.builder()
                .id(30L).userId(10L).title("Quỹ dự phòng")
                .targetAmount(new BigDecimal("10000000.00")).currentAmount(new BigDecimal("2000000.00")).build();
        when(backupSavingGoalRepo.findByUserIdOrderByCreatedAtDesc(10L)).thenReturn(List.of(gDoc));

        List<SavingGoalDto> goals = standbyReadService.getSavingsByUser(10L);
        assertThat(goals).hasSize(1);
        assertThat(goals.get(0).getTitle()).isEqualTo("Quỹ dự phòng");
    }

    @Test
    void mirrorEvents_deleteAndUpsertEntitiesOnStandbyCollections() {
        mirrorService.onTransactionChanged(TransactionChangedEvent.deleted(99L, 10L, Set.of()));
        verify(backupTransactionRepo).deleteById(99L);

        mirrorService.onStandbyEntityChanged(StandbyEntityChangedEvent.budgetDeleted(20L));
        verify(backupBudgetRepo).deleteById(20L);

        mirrorService.onStandbyEntityChanged(StandbyEntityChangedEvent.savingGoalDeleted(30L));
        verify(backupSavingGoalRepo).deleteById(30L);

        when(jdbcTemplate.queryForObject("SELECT 1", Integer.class)).thenThrow(new RuntimeException("PG Down"));
        when(mongoTemplate.executeCommand(any(Document.class))).thenReturn(new Document("ok", 1));
        when(backupUserRepo.count()).thenReturn(5L);

        MirrorStatusResponseDto status = mirrorService.getMirrorStatus();
        assertThat(status.isPostgresUp()).isFalse();
        assertThat(status.isMongoUp()).isTrue();
        assertThat(status.isFailoverActive()).isTrue();
        assertThat(status.getCollections()).hasSize(5);
        verify(userRepo, never()).count();
    }

    @Test
    void createStandbyTransaction_writesToMongoAndUpdatesWalletBalance() {
        User caller = new User();
        caller.setId(10L);
        caller.setUsername("tien");
        caller.setWalletBalance(new BigDecimal("1000000.00"));

        PgBackupUserDocument userDoc = PgBackupUserDocument.builder()
                .id(10L).username("tien").walletBalance(new BigDecimal("1000000.00")).active(true).build();
        when(backupUserRepo.findById(10L)).thenReturn(Optional.of(userDoc));

        PgBackupCategoryDocument catDoc = PgBackupCategoryDocument.builder()
                .id(1L).name("Ăn uống").type("EXPENSE").build();
        when(backupCategoryRepo.findVisibleToUser(10L)).thenReturn(List.of(catDoc));
        when(backupTransactionRepo.findAll()).thenReturn(List.of(
                PgBackupTransactionDocument.builder().id(500L).build()
        ));

        TransactionRequestDto req = new TransactionRequestDto();
        req.setAmount(new BigDecimal("65000.00"));
        req.setCategoryId(1L);
        req.setExpense(true);
        req.setLocation("Quán Cơm Tấm");
        req.setPaymentMethod("Tiền mặt");
        req.setTransactionDate(LocalDateTime.of(2026, 5, 11, 12, 0));
        req.setNote("Cơm sườn bì chả");
        req.setRating(new BigDecimal("4.5"));
        req.setReviewNote("Ngon");

        Map<String, Object> res = standbyReadService.createStandbyTransaction(caller, req);
        assertThat(res.get("transactionId")).isEqualTo(501L);
        assertThat((BigDecimal) res.get("finalAmount")).isEqualByComparingTo("65000.00");
        assertThat((BigDecimal) res.get("remainingBalance")).isEqualByComparingTo("935000.00");

        ArgumentCaptor<PgBackupUserDocument> userCaptor = ArgumentCaptor.forClass(PgBackupUserDocument.class);
        verify(backupUserRepo).save(userCaptor.capture());
        assertThat(userCaptor.getValue().getWalletBalance()).isEqualByComparingTo("935000.00");

        ArgumentCaptor<PgBackupTransactionDocument> txCaptor = ArgumentCaptor.forClass(PgBackupTransactionDocument.class);
        verify(backupTransactionRepo).save(txCaptor.capture());
        assertThat(txCaptor.getValue().getId()).isEqualTo(501L);
        assertThat(txCaptor.getValue().getCategoryName()).isEqualTo("Ăn uống");
        assertThat(txCaptor.getValue().getRating()).isEqualByComparingTo("4.5");
        assertThat(txCaptor.getValue().getReviewNote()).isEqualTo("Ngon");
    }
}
