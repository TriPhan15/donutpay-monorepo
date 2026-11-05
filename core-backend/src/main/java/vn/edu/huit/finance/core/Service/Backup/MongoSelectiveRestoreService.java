package vn.edu.huit.finance.core.Service.Backup;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Document.Backup.PgBackupBudgetDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupSavingGoalDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupBudgetRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupCategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupSavingGoalRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupTransactionRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupUserRepository;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Phục hồi ngược dữ liệu (Reverse Restore) từ 5 Collection {@code pg_backup_*} trên MongoDB
 * về lại 6 bảng nghiệp vụ cốt lõi trên PostgreSQL ({@code users}, {@code categories}, {@code receipts},
 * {@code transactions}, {@code budgets}, {@code saving_goals}), bảo toàn 100% khóa chính {@code id}
 * và tự động đồng bộ lại bộ đếm tự tăng ({@code setval} sequences).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MongoSelectiveRestoreService {

    private static final String UPSERT_USER_SQL = """
            INSERT INTO users (
                id, username, password, email, phone, role, active,
                wallet_balance, ai_label, credentials_version,
                last_login_time, last_action_time, created_at, updated_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                username = EXCLUDED.username,
                password = EXCLUDED.password,
                email = EXCLUDED.email,
                phone = EXCLUDED.phone,
                role = EXCLUDED.role,
                active = EXCLUDED.active,
                wallet_balance = EXCLUDED.wallet_balance,
                ai_label = EXCLUDED.ai_label,
                credentials_version = EXCLUDED.credentials_version,
                last_login_time = EXCLUDED.last_login_time,
                last_action_time = EXCLUDED.last_action_time,
                updated_at = EXCLUDED.updated_at
            """;

    private static final String UPSERT_CATEGORY_SQL = """
            INSERT INTO categories (
                id, name, type, owner_id, owner_key, created_at, updated_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                type = EXCLUDED.type,
                owner_id = EXCLUDED.owner_id,
                owner_key = EXCLUDED.owner_key,
                updated_at = EXCLUDED.updated_at
            """;

    private static final String UPSERT_RECEIPT_SQL = """
            INSERT INTO receipts (
                id, vendor_name, extracted_total, extracted_date, image_url,
                status, error_code, version, owner_id, created_at, updated_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                vendor_name = EXCLUDED.vendor_name,
                extracted_total = EXCLUDED.extracted_total,
                extracted_date = EXCLUDED.extracted_date,
                image_url = EXCLUDED.image_url,
                status = EXCLUDED.status,
                error_code = EXCLUDED.error_code,
                version = EXCLUDED.version,
                owner_id = EXCLUDED.owner_id,
                updated_at = EXCLUDED.updated_at
            """;

    private static final String UPSERT_TRANSACTION_SQL = """
            INSERT INTO transactions (
                id, user_id, category_id, receipt_id, category_name,
                amount, note, transaction_date, is_expense, source, client_id,
                status, voucher_code, additional_images, location, payment_method,
                rating, review_note, created_at, updated_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                user_id = EXCLUDED.user_id,
                category_id = EXCLUDED.category_id,
                receipt_id = EXCLUDED.receipt_id,
                category_name = EXCLUDED.category_name,
                amount = EXCLUDED.amount,
                note = EXCLUDED.note,
                transaction_date = EXCLUDED.transaction_date,
                is_expense = EXCLUDED.is_expense,
                source = EXCLUDED.source,
                client_id = EXCLUDED.client_id,
                status = EXCLUDED.status,
                voucher_code = EXCLUDED.voucher_code,
                additional_images = EXCLUDED.additional_images,
                location = EXCLUDED.location,
                payment_method = EXCLUDED.payment_method,
                rating = EXCLUDED.rating,
                review_note = EXCLUDED.review_note,
                updated_at = EXCLUDED.updated_at
            """;

    private static final String UPSERT_BUDGET_SQL = """
            INSERT INTO budgets (
                id, user_id, category_id, category_key, amount,
                period_type, start_date, end_date, created_at, updated_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                user_id = EXCLUDED.user_id,
                category_id = EXCLUDED.category_id,
                category_key = EXCLUDED.category_key,
                amount = EXCLUDED.amount,
                period_type = EXCLUDED.period_type,
                start_date = EXCLUDED.start_date,
                end_date = EXCLUDED.end_date,
                updated_at = EXCLUDED.updated_at
            """;

    private static final String UPSERT_SAVING_GOAL_SQL = """
            INSERT INTO saving_goals (
                id, user_id, title, target_amount, current_amount,
                deadline, created_at, updated_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                user_id = EXCLUDED.user_id,
                title = EXCLUDED.title,
                target_amount = EXCLUDED.target_amount,
                current_amount = EXCLUDED.current_amount,
                deadline = EXCLUDED.deadline,
                updated_at = EXCLUDED.updated_at
            """;

    private static final List<String> RESTORED_TABLES = List.of(
            "users", "categories", "receipts", "transactions", "budgets", "saving_goals"
    );

    private final PgBackupUserRepository backupUserRepo;
    private final PgBackupCategoryRepository backupCategoryRepo;
    private final PgBackupTransactionRepository backupTransactionRepo;
    private final PgBackupBudgetRepository backupBudgetRepo;
    private final PgBackupSavingGoalRepository backupSavingGoalRepo;

    private final JdbcTemplate jdbcTemplate;
    private final MongoStandbyFailoverService failoverService;
    private final MongoSelectiveMirrorService mirrorService;

    @Transactional
    public Map<String, Object> restoreAllFromMongoToPostgres() {
        long startMs = System.currentTimeMillis();
        Timestamp nowTs = Timestamp.valueOf(LocalDateTime.now());

        // 1. Khôi phục bảng users
        List<PgBackupUserDocument> users = backupUserRepo.findAll().stream()
                .filter(u -> u.getId() != null)
                .sorted(Comparator.comparing(PgBackupUserDocument::getId))
                .toList();
        for (PgBackupUserDocument u : users) {
            jdbcTemplate.update(UPSERT_USER_SQL,
                    u.getId(),
                    u.getUsername(),
                    Objects.requireNonNullElse(u.getPassword(), ""),
                    u.getEmail(),
                    u.getPhone(),
                    Objects.requireNonNullElse(u.getRole(), "ROLE_USER"),
                    u.isActive(),
                    Objects.requireNonNullElse(u.getWalletBalance(), BigDecimal.ZERO),
                    u.getAiLabel(),
                    Objects.requireNonNullElse(u.getCredentialsVersion(), 0),
                    toTimestamp(u.getLastLoginTime()),
                    toTimestamp(u.getLastActionTime()),
                    toTimestampOrDefault(u.getCreatedAt(), nowTs),
                    toTimestampOrDefault(u.getUpdatedAt(), nowTs)
            );
        }

        // 2. Khôi phục bảng categories
        List<PgBackupCategoryDocument> categories = backupCategoryRepo.findAll().stream()
                .filter(c -> c.getId() != null)
                .sorted(Comparator.comparing(PgBackupCategoryDocument::getId))
                .toList();
        for (PgBackupCategoryDocument c : categories) {
            long ownerKey = c.getOwnerId() != null ? c.getOwnerId() : 0L;
            jdbcTemplate.update(UPSERT_CATEGORY_SQL,
                    c.getId(),
                    c.getName(),
                    Objects.requireNonNullElse(c.getType(), "EXPENSE"),
                    c.getOwnerId(),
                    ownerKey,
                    toTimestampOrDefault(c.getCreatedAt(), nowTs),
                    toTimestampOrDefault(c.getUpdatedAt(), nowTs)
            );
        }

        // 3. Khôi phục bảng receipts (tách từ sub-document nhúng trong pg_backup_transactions)
        List<PgBackupTransactionDocument> transactions = backupTransactionRepo.findAll().stream()
                .filter(t -> t.getId() != null)
                .sorted(Comparator.comparing(PgBackupTransactionDocument::getId))
                .toList();
        int restoredReceipts = 0;
        for (PgBackupTransactionDocument tx : transactions) {
            PgBackupTransactionDocument.EmbeddedReceipt r = tx.getReceipt();
            if (r != null && r.getId() != null) {
                Long ownerId = r.getOwnerId() != null ? r.getOwnerId() : tx.getUserId();
                jdbcTemplate.update(UPSERT_RECEIPT_SQL,
                        r.getId(),
                        r.getVendorName(),
                        r.getExtractedTotal(),
                        toSqlDate(r.getExtractedDate()),
                        r.getImageUrl(),
                        Objects.requireNonNullElse(r.getStatus(), ReceiptStatus.COMPLETED_RAW.name()),
                        r.getErrorCode(),
                        Objects.requireNonNullElse(r.getVersion(), 0L),
                        ownerId,
                        toTimestampOrDefault(r.getCreatedAt(), nowTs),
                        toTimestampOrDefault(r.getUpdatedAt(), nowTs)
                );
                restoredReceipts++;
            }
        }

        // 4. Khôi phục bảng transactions
        for (PgBackupTransactionDocument tx : transactions) {
            Long receiptId = (tx.getReceipt() != null) ? tx.getReceipt().getId() : null;
            jdbcTemplate.update(UPSERT_TRANSACTION_SQL,
                    tx.getId(),
                    tx.getUserId(),
                    tx.getCategoryId(),
                    receiptId,
                    tx.getCategoryName(),
                    Objects.requireNonNullElse(tx.getAmount(), BigDecimal.ZERO),
                    tx.getNote(),
                    toTimestampOrDefault(tx.getTransactionDate(), nowTs),
                    tx.isExpense(),
                    Objects.requireNonNullElse(tx.getSource(), TransactionSource.NORMAL.name()),
                    tx.getClientId(),
                    tx.getStatus(),
                    tx.getVoucherCode(),
                    tx.getAdditionalImages(),
                    tx.getLocation(),
                    tx.getPaymentMethod(),
                    tx.getRating(),
                    tx.getReviewNote(),
                    toTimestampOrDefault(tx.getCreatedAt(), nowTs),
                    toTimestampOrDefault(tx.getUpdatedAt(), nowTs)
            );
        }

        // 5. Khôi phục bảng budgets
        List<PgBackupBudgetDocument> budgets = backupBudgetRepo.findAll().stream()
                .filter(b -> b.getId() != null)
                .sorted(Comparator.comparing(PgBackupBudgetDocument::getId))
                .toList();
        for (PgBackupBudgetDocument b : budgets) {
            long categoryKey = b.getCategoryId() != null ? b.getCategoryId() : 0L;
            jdbcTemplate.update(UPSERT_BUDGET_SQL,
                    b.getId(),
                    b.getUserId(),
                    b.getCategoryId(),
                    categoryKey,
                    Objects.requireNonNullElse(b.getAmount(), BigDecimal.ZERO),
                    Objects.requireNonNullElse(b.getPeriodType(), BudgetPeriodType.MONTH.name()),
                    toSqlDate(b.getStartDate()),
                    toSqlDate(b.getEndDate()),
                    toTimestampOrDefault(b.getCreatedAt(), nowTs),
                    toTimestampOrDefault(b.getUpdatedAt(), nowTs)
            );
        }

        // 6. Khôi phục bảng saving_goals
        List<PgBackupSavingGoalDocument> savingGoals = backupSavingGoalRepo.findAll().stream()
                .filter(g -> g.getId() != null)
                .sorted(Comparator.comparing(PgBackupSavingGoalDocument::getId))
                .toList();
        for (PgBackupSavingGoalDocument g : savingGoals) {
            jdbcTemplate.update(UPSERT_SAVING_GOAL_SQL,
                    g.getId(),
                    g.getUserId(),
                    g.getTitle(),
                    Objects.requireNonNullElse(g.getTargetAmount(), BigDecimal.ZERO),
                    Objects.requireNonNullElse(g.getCurrentAmount(), BigDecimal.ZERO),
                    g.getDeadline(),
                    toTimestampOrDefault(g.getCreatedAt(), nowTs),
                    toTimestampOrDefault(g.getUpdatedAt(), nowTs)
            );
        }

        // 7. Cập nhật lại toàn bộ PostgreSQL Sequences (setval) cho 6 bảng
        resetPostgresSequences();

        long elapsedMs = System.currentTimeMillis() - startMs;
        failoverService.setForceFailoverEnabled(false);
        failoverService.markStandbyWritePending(false);
        mirrorService.markRestoredNow();

        log.info("PostgreSQL selective restore from MongoDB completed in {}ms: users={}, categories={}, receipts={}, transactions={}, budgets={}, savingGoals={}",
                elapsedMs, users.size(), categories.size(), restoredReceipts, transactions.size(), budgets.size(), savingGoals.size());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("users", users.size());
        result.put("categories", categories.size());
        result.put("receipts", restoredReceipts);
        result.put("transactions", transactions.size());
        result.put("budgets", budgets.size());
        result.put("savingGoals", savingGoals.size());
        result.put("durationMs", elapsedMs);
        result.put("restoredAt", LocalDateTime.now());
        return result;
    }

    /**
     * Khôi phục / cập nhật chọn lọc 1 bản ghi duy nhất từ MongoDB về PostgreSQL theo quyết định của Admin trên bảng Đối soát (Diff Inspector).
     */
    @Transactional
    public void restoreSingleRecordFromMongoToPostgres(String mongoCollection, Long recordId) {
        Timestamp nowTs = Timestamp.valueOf(LocalDateTime.now());
        switch (mongoCollection) {
            case "pg_backup_users" -> {
                PgBackupUserDocument u = backupUserRepo.findById(recordId)
                        .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy User #" + recordId + " trên MongoDB"));
                upsertSingleUser(u, nowTs);
            }
            case "pg_backup_categories" -> {
                PgBackupCategoryDocument c = backupCategoryRepo.findById(recordId)
                        .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Category #" + recordId + " trên MongoDB"));
                upsertSingleCategory(c, nowTs);
            }
            case "pg_backup_transactions" -> {
                PgBackupTransactionDocument tx = backupTransactionRepo.findById(recordId)
                        .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Giao dịch #" + recordId + " trên MongoDB"));
                if (tx.getUserId() != null) {
                    backupUserRepo.findById(tx.getUserId()).ifPresent(u -> upsertSingleUser(u, nowTs));
                }
                if (tx.getCategoryId() != null) {
                    backupCategoryRepo.findById(tx.getCategoryId()).ifPresent(c -> upsertSingleCategory(c, nowTs));
                }
                upsertSingleTransactionAndReceipt(tx, nowTs);
            }
            case "pg_backup_budgets" -> {
                PgBackupBudgetDocument b = backupBudgetRepo.findById(recordId)
                        .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Ngân sách #" + recordId + " trên MongoDB"));
                upsertSingleBudget(b, nowTs);
            }
            case "pg_backup_saving_goals" -> {
                PgBackupSavingGoalDocument g = backupSavingGoalRepo.findById(recordId)
                        .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy Mục tiêu tiết kiệm #" + recordId + " trên MongoDB"));
                upsertSingleSavingGoal(g, nowTs);
            }
            default -> throw new IllegalArgumentException("Collection không hợp lệ: " + mongoCollection);
        }
        resetPostgresSequences();
        mirrorService.markRestoredNow();
    }

    /**
     * Xóa chọn lọc 1 bản ghi khỏi PostgreSQL (và dọn trên MongoDB nếu có) theo quyết định của Admin trên bảng Đối soát.
     */
    @Transactional
    public void deleteSingleRecordFromPostgres(String mongoCollection, Long recordId) {
        switch (mongoCollection) {
            case "pg_backup_users" -> {
                jdbcTemplate.update("DELETE FROM users WHERE id = ?", recordId);
                backupUserRepo.deleteById(recordId);
            }
            case "pg_backup_categories" -> {
                jdbcTemplate.update("DELETE FROM categories WHERE id = ?", recordId);
                backupCategoryRepo.deleteById(recordId);
            }
            case "pg_backup_transactions" -> {
                jdbcTemplate.update("DELETE FROM transactions WHERE id = ?", recordId);
                backupTransactionRepo.deleteById(recordId);
            }
            case "pg_backup_budgets" -> {
                jdbcTemplate.update("DELETE FROM budgets WHERE id = ?", recordId);
                backupBudgetRepo.deleteById(recordId);
            }
            case "pg_backup_saving_goals" -> {
                jdbcTemplate.update("DELETE FROM saving_goals WHERE id = ?", recordId);
                backupSavingGoalRepo.deleteById(recordId);
            }
            default -> throw new IllegalArgumentException("Collection không hợp lệ: " + mongoCollection);
        }
    }

    private void upsertSingleUser(PgBackupUserDocument u, Timestamp nowTs) {
        jdbcTemplate.update(UPSERT_USER_SQL,
                u.getId(),
                u.getUsername(),
                Objects.requireNonNullElse(u.getPassword(), ""),
                u.getEmail(),
                u.getPhone(),
                Objects.requireNonNullElse(u.getRole(), "ROLE_USER"),
                u.isActive(),
                Objects.requireNonNullElse(u.getWalletBalance(), BigDecimal.ZERO),
                u.getAiLabel(),
                Objects.requireNonNullElse(u.getCredentialsVersion(), 0),
                toTimestamp(u.getLastLoginTime()),
                toTimestamp(u.getLastActionTime()),
                toTimestampOrDefault(u.getCreatedAt(), nowTs),
                toTimestampOrDefault(u.getUpdatedAt(), nowTs)
        );
    }

    private void upsertSingleCategory(PgBackupCategoryDocument c, Timestamp nowTs) {
        long ownerKey = c.getOwnerId() != null ? c.getOwnerId() : 0L;
        jdbcTemplate.update(UPSERT_CATEGORY_SQL,
                c.getId(),
                c.getName(),
                Objects.requireNonNullElse(c.getType(), "EXPENSE"),
                c.getOwnerId(),
                ownerKey,
                toTimestampOrDefault(c.getCreatedAt(), nowTs),
                toTimestampOrDefault(c.getUpdatedAt(), nowTs)
        );
    }

    private void upsertSingleTransactionAndReceipt(PgBackupTransactionDocument tx, Timestamp nowTs) {
        PgBackupTransactionDocument.EmbeddedReceipt r = tx.getReceipt();
        if (r != null && r.getId() != null) {
            Long ownerId = r.getOwnerId() != null ? r.getOwnerId() : tx.getUserId();
            jdbcTemplate.update(UPSERT_RECEIPT_SQL,
                    r.getId(),
                    r.getVendorName(),
                    r.getExtractedTotal(),
                    toSqlDate(r.getExtractedDate()),
                    r.getImageUrl(),
                    Objects.requireNonNullElse(r.getStatus(), ReceiptStatus.COMPLETED_RAW.name()),
                    r.getErrorCode(),
                    Objects.requireNonNullElse(r.getVersion(), 0L),
                    ownerId,
                    toTimestampOrDefault(r.getCreatedAt(), nowTs),
                    toTimestampOrDefault(r.getUpdatedAt(), nowTs)
            );
        }
        Long receiptId = (r != null) ? r.getId() : null;
        jdbcTemplate.update(UPSERT_TRANSACTION_SQL,
                tx.getId(),
                tx.getUserId(),
                tx.getCategoryId(),
                receiptId,
                tx.getCategoryName(),
                Objects.requireNonNullElse(tx.getAmount(), BigDecimal.ZERO),
                tx.getNote(),
                toTimestampOrDefault(tx.getTransactionDate(), nowTs),
                tx.isExpense(),
                Objects.requireNonNullElse(tx.getSource(), TransactionSource.NORMAL.name()),
                tx.getClientId(),
                tx.getStatus(),
                tx.getVoucherCode(),
                tx.getAdditionalImages(),
                tx.getLocation(),
                tx.getPaymentMethod(),
                tx.getRating(),
                tx.getReviewNote(),
                toTimestampOrDefault(tx.getCreatedAt(), nowTs),
                toTimestampOrDefault(tx.getUpdatedAt(), nowTs)
        );
    }

    private void upsertSingleBudget(PgBackupBudgetDocument b, Timestamp nowTs) {
        long categoryKey = b.getCategoryId() != null ? b.getCategoryId() : 0L;
        jdbcTemplate.update(UPSERT_BUDGET_SQL,
                b.getId(),
                b.getUserId(),
                b.getCategoryId(),
                categoryKey,
                Objects.requireNonNullElse(b.getAmount(), BigDecimal.ZERO),
                Objects.requireNonNullElse(b.getPeriodType(), BudgetPeriodType.MONTH.name()),
                toSqlDate(b.getStartDate()),
                toSqlDate(b.getEndDate()),
                toTimestampOrDefault(b.getCreatedAt(), nowTs),
                toTimestampOrDefault(b.getUpdatedAt(), nowTs)
        );
    }

    private void upsertSingleSavingGoal(PgBackupSavingGoalDocument g, Timestamp nowTs) {
        jdbcTemplate.update(UPSERT_SAVING_GOAL_SQL,
                g.getId(),
                g.getUserId(),
                g.getTitle(),
                Objects.requireNonNullElse(g.getTargetAmount(), BigDecimal.ZERO),
                Objects.requireNonNullElse(g.getCurrentAmount(), BigDecimal.ZERO),
                g.getDeadline(),
                toTimestampOrDefault(g.getCreatedAt(), nowTs),
                toTimestampOrDefault(g.getUpdatedAt(), nowTs)
        );
    }

    private void resetPostgresSequences() {
        for (String table : RESTORED_TABLES) {
            String sql = String.format(
                    "SELECT setval(pg_get_serial_sequence('%s', 'id'), COALESCE((SELECT MAX(id) FROM %s), 1), (SELECT COUNT(*) > 0 FROM %s))",
                    table, table, table
            );
            jdbcTemplate.queryForObject(sql, Long.class);
        }
    }

    private static Timestamp toTimestamp(LocalDateTime ldt) {
        return ldt != null ? Timestamp.valueOf(ldt) : null;
    }

    private static Timestamp toTimestampOrDefault(LocalDateTime ldt, Timestamp fallback) {
        return ldt != null ? Timestamp.valueOf(ldt) : fallback;
    }

    private static Date toSqlDate(LocalDate ld) {
        return ld != null ? Date.valueOf(ld) : null;
    }
}
