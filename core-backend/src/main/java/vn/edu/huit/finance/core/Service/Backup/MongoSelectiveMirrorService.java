package vn.edu.huit.finance.core.Service.Backup;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.bson.Document;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import vn.edu.huit.finance.core.Document.Backup.PgBackupBudgetDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupSavingGoalDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;
import vn.edu.huit.finance.core.Dto.MirrorStatusResponseDto;
import vn.edu.huit.finance.core.Dto.StandbyEntityChangedEvent;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.Transaction;
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

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.LongSupplier;
import java.util.stream.Collectors;

/**
 * Dịch vụ Sao lưu Chọn lọc (Selective Collection Mirroring) từ PostgreSQL sang 5 Collection
 * {@code pg_backup_*} trên MongoDB theo cả 2 cơ chế:
 * <ul>
 *   <li>Đồng bộ Thời gian thực Bất đồng bộ ({@code AFTER_COMMIT} + {@code @Async("mongoAsyncExecutor")}).</li>
 *   <li>Đồng bộ Toàn phần Chủ động ({@link #syncAllFromPostgresToMongo()}).</li>
 * </ul>
 * Phần đối soát chênh lệch từng dòng (Diff Inspector) được tách riêng sang {@link MongoMirrorDiffService}.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MongoSelectiveMirrorService {

    private final UserRepository userRepo;
    private final CategoryRepository categoryRepo;
    private final TransactionRepository transactionRepo;
    private final ReceiptRepository receiptRepo;
    private final BudgetRepository budgetRepo;
    private final SavingGoalRepository savingGoalRepo;

    private final PgBackupUserRepository backupUserRepo;
    private final PgBackupCategoryRepository backupCategoryRepo;
    private final PgBackupTransactionRepository backupTransactionRepo;
    private final PgBackupBudgetRepository backupBudgetRepo;
    private final PgBackupSavingGoalRepository backupSavingGoalRepo;

    private final MongoStandbyFailoverService failoverService;
    private final JdbcTemplate jdbcTemplate;
    private final MongoTemplate mongoTemplate;

    private final AtomicReference<LocalDateTime> lastSyncTime = new AtomicReference<>();
    private final AtomicReference<LocalDateTime> lastRestoreTime = new AtomicReference<>();

    public void markRestoredNow() {
        lastRestoreTime.set(LocalDateTime.now());
    }

    /**
     * Khi khởi động ứng dụng, nếu MongoDB chưa có bản sao nào trong {@code pg_backup_users}
     * trong khi PostgreSQL đã có dữ liệu, tự động đồng bộ lần đầu ở chế độ nền.
     */
    @Async("mongoAsyncExecutor")
    @EventListener(ApplicationReadyEvent.class)
    public void initialSyncIfEmpty() {
        try {
            if (backupUserRepo.count() == 0 && userRepo.count() > 0) {
                log.info("Initializing MongoDB Selective Standby Mirror for 5 core collections...");
                syncAllFromPostgresToMongo();
            }
        } catch (Exception e) {
            log.warn("Initial MongoDB Standby Mirror check skipped: {}", e.getMessage());
        }
    }

    /**
     * Đồng bộ tức thì khi một giao dịch (hoặc hóa đơn gắn kèm) được thêm, sửa, duyệt, hủy hoặc xóa.
     * Luôn đồng bộ kèm số dư ví {@code walletBalance} của {@code User} và {@code Category} liên quan.
     */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onTransactionChanged(TransactionChangedEvent event) {
        if (event == null) {
            return;
        }
        try {
            if (event.kind() == TransactionChangedEvent.Kind.DELETED) {
                if (event.transactionId() != null) {
                    backupTransactionRepo.deleteById(event.transactionId());
                }
            } else if (event.transactionId() != null) {
                transactionRepo.findByIdWithDetailsForBackup(event.transactionId()).ifPresent(tx -> {
                    backupTransactionRepo.save(PgBackupTransactionDocument.from(tx));
                    if (tx.getCategory() != null && tx.getCategory().getId() != null) {
                        syncSingleCategory(tx.getCategory().getId());
                    }
                });
            }
            if (event.userId() != null) {
                syncSingleUser(event.userId());
            }
            lastSyncTime.set(LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Async MongoDB mirror failed for TransactionChangedEvent(txId={}, userId={}): {}",
                    event.transactionId(), event.userId(), e.getMessage());
        }
    }

    /**
     * Đồng bộ tức thì khi {@code User}, {@code Category}, {@code Budget} hoặc {@code SavingGoal} thay đổi.
     */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onStandbyEntityChanged(StandbyEntityChangedEvent event) {
        if (event == null || event.entityId() == null) {
            return;
        }
        try {
            switch (event.entityType()) {
                case USER -> {
                    if (event.deleted()) {
                        backupUserRepo.deleteById(event.entityId());
                    } else {
                        syncSingleUser(event.entityId());
                    }
                }
                case ALL_USERS -> {
                    List<PgBackupUserDocument> users = userRepo.findAll().stream()
                            .map(PgBackupUserDocument::from)
                            .toList();
                    if (!users.isEmpty()) {
                        backupUserRepo.saveAll(users);
                    }
                }
                case CATEGORY -> {
                    if (event.deleted()) {
                        backupCategoryRepo.deleteById(event.entityId());
                    } else {
                        syncSingleCategory(event.entityId());
                    }
                }
                case RECEIPT -> syncSingleReceiptCarrier(event.entityId());
                case BUDGET -> {
                    if (event.deleted()) {
                        backupBudgetRepo.deleteById(event.entityId());
                    } else {
                        syncSingleBudget(event.entityId());
                    }
                }
                case SAVING_GOAL -> {
                    if (event.deleted()) {
                        backupSavingGoalRepo.deleteById(event.entityId());
                    } else {
                        syncSingleSavingGoal(event.entityId());
                    }
                }
            }
            lastSyncTime.set(LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Async MongoDB mirror failed for StandbyEntityChangedEvent({}, id={}): {}",
                    event.entityType(), event.entityId(), e.getMessage());
        }
    }

    public void syncSingleUser(Long userId) {
        userRepo.findById(userId)
                .ifPresentOrElse(
                        u -> backupUserRepo.save(PgBackupUserDocument.from(u)),
                        () -> backupUserRepo.deleteById(userId)
                );
    }

    public void syncSingleCategory(Long categoryId) {
        categoryRepo.findByIdWithOwner(categoryId)
                .ifPresentOrElse(
                        c -> backupCategoryRepo.save(PgBackupCategoryDocument.from(c)),
                        () -> backupCategoryRepo.deleteById(categoryId)
                );
    }

    public void syncSingleBudget(Long budgetId) {
        budgetRepo.findByIdWithUserAndCategory(budgetId)
                .ifPresentOrElse(
                        b -> backupBudgetRepo.save(PgBackupBudgetDocument.from(b)),
                        () -> backupBudgetRepo.deleteById(budgetId)
                );
    }

    public void syncSingleSavingGoal(Long goalId) {
        savingGoalRepo.findByIdWithUser(goalId)
                .ifPresentOrElse(
                        g -> backupSavingGoalRepo.save(PgBackupSavingGoalDocument.from(g)),
                        () -> backupSavingGoalRepo.deleteById(goalId)
                );
    }

    public void syncSingleReceiptCarrier(Long receiptId) {
        receiptRepo.findDetailedById(receiptId).ifPresent(r -> {
            if (r.getTransaction() != null && r.getTransaction().getId() != null) {
                transactionRepo.findByIdWithDetailsForBackup(r.getTransaction().getId())
                        .ifPresent(tx -> backupTransactionRepo.save(PgBackupTransactionDocument.from(tx)));
            }
        });
    }

    /**
     * Quét toàn bộ 5 nhóm dữ liệu cốt lõi trên PostgreSQL và đồng bộ hàng loạt sang 5 Collection
     * {@code pg_backup_*} trên MongoDB, đồng thời dọn sạch các bản ghi đã bị xóa trên PostgreSQL.
     * Nếu trước đó có giao dịch ghi tạm trên MongoDB khi Failover, tự động đối soát/khôi phục ngược về PostgreSQL trước.
     */
    public Map<String, Object> syncAllFromPostgresToMongo() {
        long startMs = System.currentTimeMillis();
        failoverService.reconcilePendingWritesIfNeeded();

        List<PgBackupUserDocument> users = userRepo.findAll().stream()
                .map(PgBackupUserDocument::from)
                .toList();
        if (users.isEmpty()) {
            backupUserRepo.deleteAll();
        } else {
            backupUserRepo.saveAll(users);
            Set<Long> userIds = users.stream().map(PgBackupUserDocument::getId).collect(Collectors.toSet());
            backupUserRepo.deleteByIdNotIn(userIds);
        }

        List<PgBackupCategoryDocument> categories = categoryRepo.findAllWithOwner().stream()
                .map(PgBackupCategoryDocument::from)
                .toList();
        if (categories.isEmpty()) {
            backupCategoryRepo.deleteAll();
        } else {
            backupCategoryRepo.saveAll(categories);
            Set<Long> categoryIds = categories.stream().map(PgBackupCategoryDocument::getId).collect(Collectors.toSet());
            backupCategoryRepo.deleteByIdNotIn(categoryIds);
        }

        List<Transaction> rawTransactions = transactionRepo.findAllWithDetailsForBackup();
        List<PgBackupTransactionDocument> transactions = rawTransactions.stream()
                .map(PgBackupTransactionDocument::from)
                .toList();
        long embeddedReceiptsCount = transactions.stream().filter(t -> t.getReceipt() != null).count();
        if (transactions.isEmpty()) {
            backupTransactionRepo.deleteAll();
        } else {
            backupTransactionRepo.saveAll(transactions);
            Set<Long> txIds = transactions.stream().map(PgBackupTransactionDocument::getId).collect(Collectors.toSet());
            backupTransactionRepo.deleteByIdNotIn(txIds);
        }

        List<PgBackupBudgetDocument> budgets = budgetRepo.findAllWithUserAndCategory().stream()
                .map(PgBackupBudgetDocument::from)
                .toList();
        if (budgets.isEmpty()) {
            backupBudgetRepo.deleteAll();
        } else {
            backupBudgetRepo.saveAll(budgets);
            Set<Long> budgetIds = budgets.stream().map(PgBackupBudgetDocument::getId).collect(Collectors.toSet());
            backupBudgetRepo.deleteByIdNotIn(budgetIds);
        }

        List<PgBackupSavingGoalDocument> savingGoals = savingGoalRepo.findAllWithUser().stream()
                .map(PgBackupSavingGoalDocument::from)
                .toList();
        if (savingGoals.isEmpty()) {
            backupSavingGoalRepo.deleteAll();
        } else {
            backupSavingGoalRepo.saveAll(savingGoals);
            Set<Long> goalIds = savingGoals.stream().map(PgBackupSavingGoalDocument::getId).collect(Collectors.toSet());
            backupSavingGoalRepo.deleteByIdNotIn(goalIds);
        }

        long elapsedMs = System.currentTimeMillis() - startMs;
        LocalDateTime syncedAt = LocalDateTime.now();
        lastSyncTime.set(syncedAt);
        failoverService.clearAutoFailover();

        log.info("MongoDB Selective Mirror Full Sync completed in {}ms: users={}, categories={}, transactions={} (receipts={}), budgets={}, savingGoals={}",
                elapsedMs, users.size(), categories.size(), transactions.size(), embeddedReceiptsCount, budgets.size(), savingGoals.size());

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("users", users.size());
        summary.put("categories", categories.size());
        summary.put("transactions", transactions.size());
        summary.put("embeddedReceipts", embeddedReceiptsCount);
        summary.put("budgets", budgets.size());
        summary.put("savingGoals", savingGoals.size());
        summary.put("durationMs", elapsedMs);
        summary.put("syncedAt", syncedAt);
        return summary;
    }

    /**
     * Lấy trạng thái đối chiếu trực tiếp giữa PostgreSQL và 5 Collection {@code pg_backup_*} trên MongoDB.
     */
    public MirrorStatusResponseDto getMirrorStatus() {
        boolean pgUp = checkPostgresUp();
        boolean mongoUp = checkMongoUp();

        long pgUsers = -1;
        long pgCategories = -1;
        long pgTransactions = -1;
        long pgBudgets = -1;
        long pgSavingGoals = -1;

        if (pgUp) {
            try {
                if (!failoverService.isForceFailoverEnabled()) {
                    failoverService.clearAutoFailover();
                    failoverService.reconcilePendingWritesIfNeeded();
                }
                pgUsers = userRepo.count();
                pgCategories = categoryRepo.count();
                pgTransactions = transactionRepo.count();
                pgBudgets = budgetRepo.count();
                pgSavingGoals = savingGoalRepo.count();
            } catch (Exception e) {
                pgUp = false;
                failoverService.recordPostgresFailure(e);
            }
        } else {
            failoverService.recordPostgresFailure(new IllegalStateException("PostgreSQL health check failed"));
        }

        long mongoUsers = mongoUp ? safeMongoCount(backupUserRepo::count) : -1;
        long mongoCategories = mongoUp ? safeMongoCount(backupCategoryRepo::count) : -1;
        long mongoTransactions = mongoUp ? safeMongoCount(backupTransactionRepo::count) : -1;
        long mongoBudgets = mongoUp ? safeMongoCount(backupBudgetRepo::count) : -1;
        long mongoSavingGoals = mongoUp ? safeMongoCount(backupSavingGoalRepo::count) : -1;

        List<MirrorStatusResponseDto.CollectionMirrorStat> stats = new ArrayList<>();
        stats.add(buildStat("pg_backup_users", "users", "Tài khoản, mật khẩu BCrypt, số dư ví, phân khúc AI", pgUsers, mongoUsers));
        stats.add(buildStat("pg_backup_categories", "categories", "Danh mục thu/chi mặc định và danh mục riêng của người dùng", pgCategories, mongoCategories));
        stats.add(buildStat("pg_backup_transactions", "transactions + receipts", "Giao dịch thu/chi, đánh giá sao và hóa đơn OCR", pgTransactions, mongoTransactions));
        stats.add(buildStat("pg_backup_budgets", "budgets", "Hạn mức ngân sách theo danh mục và chu kỳ", pgBudgets, mongoBudgets));
        stats.add(buildStat("pg_backup_saving_goals", "saving_goals", "Mục tiêu tiết kiệm và số tiền tích lũy", pgSavingGoals, mongoSavingGoals));

        return MirrorStatusResponseDto.builder()
                .postgresUp(pgUp)
                .mongoUp(mongoUp)
                .forceFailoverEnabled(failoverService.isForceFailoverEnabled())
                .autoFailoverActive(failoverService.isAutoFailoverActive())
                .failoverActive(failoverService.isFailoverActive())
                .effectiveReadSource(failoverService.getEffectiveReadSource())
                .lastSyncTime(lastSyncTime.get())
                .lastRestoreTime(lastRestoreTime.get())
                .collections(stats)
                .build();
    }

    public void syncSingleRecordFromPostgresToMongo(String mongoCollection, Long recordId) {
        switch (mongoCollection) {
            case "pg_backup_users" -> syncSingleUser(recordId);
            case "pg_backup_categories" -> syncSingleCategory(recordId);
            case "pg_backup_transactions" -> transactionRepo.findByIdWithDetailsForBackup(recordId)
                    .ifPresentOrElse(
                            tx -> {
                                backupTransactionRepo.save(PgBackupTransactionDocument.from(tx));
                                if (tx.getUser() != null && tx.getUser().getId() != null) {
                                    syncSingleUser(tx.getUser().getId());
                                }
                            },
                            () -> backupTransactionRepo.deleteById(recordId)
                    );
            case "pg_backup_budgets" -> syncSingleBudget(recordId);
            case "pg_backup_saving_goals" -> syncSingleSavingGoal(recordId);
            default -> throw new IllegalArgumentException("Collection không hợp lệ: " + mongoCollection);
        }
        lastSyncTime.set(LocalDateTime.now());
    }

    public void deleteSingleRecordFromMongo(String mongoCollection, Long recordId) {
        switch (mongoCollection) {
            case "pg_backup_users" -> backupUserRepo.deleteById(recordId);
            case "pg_backup_categories" -> backupCategoryRepo.deleteById(recordId);
            case "pg_backup_transactions" -> backupTransactionRepo.deleteById(recordId);
            case "pg_backup_budgets" -> backupBudgetRepo.deleteById(recordId);
            case "pg_backup_saving_goals" -> backupSavingGoalRepo.deleteById(recordId);
            default -> throw new IllegalArgumentException("Collection không hợp lệ: " + mongoCollection);
        }
    }

    private static MirrorStatusResponseDto.CollectionMirrorStat buildStat(String mongoCollection,
                                                                          String postgresTable,
                                                                          String description,
                                                                          long pgCount,
                                                                          long mongoCount) {
        int diffCount = (pgCount >= 0 && mongoCount >= 0) ? (int) Math.abs(pgCount - mongoCount) : 0;
        boolean synced = pgCount >= 0 && mongoCount >= 0 && pgCount == mongoCount && diffCount == 0;
        return MirrorStatusResponseDto.CollectionMirrorStat.builder()
                .mongoCollection(mongoCollection)
                .postgresTable(postgresTable)
                .description(description)
                .postgresCount(pgCount)
                .mongoCount(mongoCount)
                .diffCount(diffCount)
                .synced(synced)
                .build();
    }

    private boolean checkPostgresUp() {
        try {
            Integer one = jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            return one != null && one == 1;
        } catch (Exception e) {
            return false;
        }
    }

    private boolean checkMongoUp() {
        try {
            Document res = mongoTemplate.executeCommand(new Document("ping", 1));
            return res != null;
        } catch (Exception e) {
            return false;
        }
    }

    private static long safeMongoCount(LongSupplier supplier) {
        try {
            return supplier.getAsLong();
        } catch (Exception e) {
            return -1L;
        }
    }
}
