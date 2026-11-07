package vn.edu.huit.finance.core.Service.Backup;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Document.Backup.PgBackupBudgetDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupSavingGoalDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;
import vn.edu.huit.finance.core.Dto.MirrorDiffItemDto;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.BudgetRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupBudgetRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupCategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupSavingGoalRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupTransactionRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupUserRepository;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Đối soát chi tiết từng bản ghi (Record-level Diff Inspector) giữa PostgreSQL và 5 Collection
 * {@code pg_backup_*} trên MongoDB để Quản trị viên phát hiện chênh lệch (bản ghi chỉ có một bên,
 * lệch số dư ví, trạng thái khóa tài khoản, phiên bản mật khẩu hoặc số tiền giao dịch).
 */
@Service
@RequiredArgsConstructor
public class MongoMirrorDiffService {

    private final UserRepository userRepo;
    private final CategoryRepository categoryRepo;
    private final TransactionRepository transactionRepo;
    private final BudgetRepository budgetRepo;
    private final SavingGoalRepository savingGoalRepo;

    private final PgBackupUserRepository backupUserRepo;
    private final PgBackupCategoryRepository backupCategoryRepo;
    private final PgBackupTransactionRepository backupTransactionRepo;
    private final PgBackupBudgetRepository backupBudgetRepo;
    private final PgBackupSavingGoalRepository backupSavingGoalRepo;

    public List<MirrorDiffItemDto> getCollectionDiffs(String filterCollection) {
        List<MirrorDiffItemDto> diffs = new ArrayList<>();
        boolean all = filterCollection == null || filterCollection.isBlank() || "ALL".equalsIgnoreCase(filterCollection);

        if (all || "pg_backup_users".equals(filterCollection)) {
            collectUserDiffs(diffs);
        }
        if (all || "pg_backup_categories".equals(filterCollection)) {
            collectCategoryDiffs(diffs);
        }
        if (all || "pg_backup_transactions".equals(filterCollection)) {
            collectTransactionDiffs(diffs);
        }
        if (all || "pg_backup_budgets".equals(filterCollection)) {
            collectBudgetDiffs(diffs);
        }
        if (all || "pg_backup_saving_goals".equals(filterCollection)) {
            collectSavingGoalDiffs(diffs);
        }
        return diffs;
    }

    private void collectUserDiffs(List<MirrorDiffItemDto> out) {
        Map<Long, User> pgMap = userRepo.findAll().stream()
                .filter(u -> u.getId() != null)
                .collect(Collectors.toMap(User::getId, Function.identity(), (a, b) -> a));
        Map<Long, PgBackupUserDocument> mongoMap = backupUserRepo.findAll().stream()
                .filter(u -> u.getId() != null)
                .collect(Collectors.toMap(PgBackupUserDocument::getId, Function.identity(), (a, b) -> a));

        Set<Long> allIds = new TreeSet<>(pgMap.keySet());
        allIds.addAll(mongoMap.keySet());

        for (Long id : allIds) {
            User pg = pgMap.get(id);
            PgBackupUserDocument mg = mongoMap.get(id);
            if (pg == null && mg != null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_users")
                        .postgresTable("users")
                        .recordId(id)
                        .diffType("ONLY_IN_MONGO")
                        .title("User #" + id + " - " + mg.getUsername())
                        .postgresSummary("Không tồn tại trên PostgreSQL")
                        .mongoSummary("Email: " + mg.getEmail() + " | Ví: " + formatMoney(mg.getWalletBalance()))
                        .build());
            } else if (pg != null && mg == null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_users")
                        .postgresTable("users")
                        .recordId(id)
                        .diffType("ONLY_IN_POSTGRES")
                        .title("User #" + id + " - " + pg.getUsername())
                        .postgresSummary("Email: " + pg.getEmail() + " | Ví: " + formatMoney(pg.getWalletBalance()))
                        .mongoSummary("Không tồn tại trên MongoDB")
                        .build());
            } else if (pg != null && mg != null && isUserMismatched(pg, mg)) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_users")
                        .postgresTable("users")
                        .recordId(id)
                        .diffType("VALUE_MISMATCH")
                        .title("User #" + id + " - " + pg.getUsername() + " — Lệch dữ liệu tài khoản/ví")
                        .postgresSummary(formatUserSummary("PG", pg.getWalletBalance(), pg.isActive(), pg.getRole(), pg.getCredentialsVersion()))
                        .mongoSummary(formatUserSummary("Mongo", mg.getWalletBalance(), mg.isActive(), mg.getRole(), mg.getCredentialsVersion()))
                        .build());
            }
        }
    }

    private static boolean isUserMismatched(User pg, PgBackupUserDocument mg) {
        if (!sameAmount(pg.getWalletBalance(), mg.getWalletBalance())) {
            return true;
        }
        if (pg.isActive() != mg.isActive()) {
            return true;
        }
        String pgRole = Objects.requireNonNullElse(pg.getRole(), "ROLE_USER");
        String mgRole = Objects.requireNonNullElse(mg.getRole(), "ROLE_USER");
        if (!Objects.equals(pgRole, mgRole)) {
            return true;
        }
        int pgVer = Objects.requireNonNullElse(pg.getCredentialsVersion(), 0);
        int mgVer = Objects.requireNonNullElse(mg.getCredentialsVersion(), 0);
        return pgVer != mgVer;
    }

    private static String formatUserSummary(String source, BigDecimal balance, boolean active, String role, Integer version) {
        return String.format("%s: Ví=%s | active=%s | role=%s | ver=%d",
                source, formatMoney(balance), active,
                Objects.requireNonNullElse(role, "ROLE_USER"),
                Objects.requireNonNullElse(version, 0));
    }

    private void collectCategoryDiffs(List<MirrorDiffItemDto> out) {
        Map<Long, Category> pgMap = categoryRepo.findAllWithOwner().stream()
                .filter(c -> c.getId() != null)
                .collect(Collectors.toMap(Category::getId, Function.identity(), (a, b) -> a));
        Map<Long, PgBackupCategoryDocument> mongoMap = backupCategoryRepo.findAll().stream()
                .filter(c -> c.getId() != null)
                .collect(Collectors.toMap(PgBackupCategoryDocument::getId, Function.identity(), (a, b) -> a));

        Set<Long> allIds = new TreeSet<>(pgMap.keySet());
        allIds.addAll(mongoMap.keySet());

        for (Long id : allIds) {
            Category pg = pgMap.get(id);
            PgBackupCategoryDocument mg = mongoMap.get(id);
            if (pg == null && mg != null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_categories")
                        .postgresTable("categories")
                        .recordId(id)
                        .diffType("ONLY_IN_MONGO")
                        .title("Danh mục #" + id + " - " + mg.getName())
                        .postgresSummary("Không tồn tại trên PostgreSQL")
                        .mongoSummary("Tên: " + mg.getName() + " | Loại: " + mg.getType())
                        .build());
            } else if (pg != null && mg == null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_categories")
                        .postgresTable("categories")
                        .recordId(id)
                        .diffType("ONLY_IN_POSTGRES")
                        .title("Danh mục #" + id + " - " + pg.getName())
                        .postgresSummary("Tên: " + pg.getName() + " | Loại: " + pg.getType())
                        .mongoSummary("Không tồn tại trên MongoDB")
                        .build());
            } else if (pg != null && mg != null && !Objects.equals(pg.getName(), mg.getName())) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_categories")
                        .postgresTable("categories")
                        .recordId(id)
                        .diffType("VALUE_MISMATCH")
                        .title("Danh mục #" + id + " — Lệch tên danh mục")
                        .postgresSummary("Tên PG: " + pg.getName())
                        .mongoSummary("Tên Mongo: " + mg.getName())
                        .build());
            }
        }
    }

    private void collectTransactionDiffs(List<MirrorDiffItemDto> out) {
        Map<Long, Transaction> pgMap = transactionRepo.findAllWithDetailsForBackup().stream()
                .filter(t -> t.getId() != null)
                .collect(Collectors.toMap(Transaction::getId, Function.identity(), (a, b) -> a));
        Map<Long, PgBackupTransactionDocument> mongoMap = backupTransactionRepo.findAll().stream()
                .filter(t -> t.getId() != null)
                .collect(Collectors.toMap(PgBackupTransactionDocument::getId, Function.identity(), (a, b) -> a));

        Set<Long> allIds = new TreeSet<>(pgMap.keySet());
        allIds.addAll(mongoMap.keySet());

        for (Long id : allIds) {
            Transaction pg = pgMap.get(id);
            PgBackupTransactionDocument mg = mongoMap.get(id);
            if (pg == null && mg != null) {
                String dir = mg.isExpense() ? "Chi" : "Thu";
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_transactions")
                        .postgresTable("transactions")
                        .recordId(id)
                        .diffType("ONLY_IN_MONGO")
                        .title("Giao dịch #" + id + " - User #" + mg.getUserId() + " - " + mg.getCategoryName())
                        .postgresSummary("Không tồn tại trên PostgreSQL")
                        .mongoSummary(dir + " " + formatMoney(mg.getAmount()) + " | Ghi chú: " + Objects.requireNonNullElse(mg.getNote(), "-"))
                        .build());
            } else if (pg != null && mg == null) {
                String dir = pg.isExpense() ? "Chi" : "Thu";
                Long uid = pg.getUser() != null ? pg.getUser().getId() : null;
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_transactions")
                        .postgresTable("transactions")
                        .recordId(id)
                        .diffType("ONLY_IN_POSTGRES")
                        .title("Giao dịch #" + id + " - User #" + uid + " - " + pg.getCategoryName())
                        .postgresSummary(dir + " " + formatMoney(pg.getAmount()) + " | Ghi chú: " + Objects.requireNonNullElse(pg.getNote(), "-"))
                        .mongoSummary("Không tồn tại trên MongoDB")
                        .build());
            } else if (pg != null && mg != null && !sameAmount(pg.getAmount(), mg.getAmount())) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_transactions")
                        .postgresTable("transactions")
                        .recordId(id)
                        .diffType("VALUE_MISMATCH")
                        .title("Giao dịch #" + id + " — Lệch số tiền")
                        .postgresSummary("Số tiền PG: " + formatMoney(pg.getAmount()))
                        .mongoSummary("Số tiền Mongo: " + formatMoney(mg.getAmount()))
                        .build());
            }
        }
    }

    private void collectBudgetDiffs(List<MirrorDiffItemDto> out) {
        Map<Long, Budget> pgMap = budgetRepo.findAllWithUserAndCategory().stream()
                .filter(b -> b.getId() != null)
                .collect(Collectors.toMap(Budget::getId, Function.identity(), (a, b) -> a));
        Map<Long, PgBackupBudgetDocument> mongoMap = backupBudgetRepo.findAll().stream()
                .filter(b -> b.getId() != null)
                .collect(Collectors.toMap(PgBackupBudgetDocument::getId, Function.identity(), (a, b) -> a));

        Set<Long> allIds = new TreeSet<>(pgMap.keySet());
        allIds.addAll(mongoMap.keySet());

        for (Long id : allIds) {
            Budget pg = pgMap.get(id);
            PgBackupBudgetDocument mg = mongoMap.get(id);
            if (pg == null && mg != null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_budgets")
                        .postgresTable("budgets")
                        .recordId(id)
                        .diffType("ONLY_IN_MONGO")
                        .title("Ngân sách #" + id + " - " + mg.getCategoryName())
                        .postgresSummary("Không tồn tại trên PostgreSQL")
                        .mongoSummary("Hạn mức: " + formatMoney(mg.getAmount()) + " | Chu kỳ: " + mg.getPeriodType())
                        .build());
            } else if (pg != null && mg == null) {
                String catName = pg.getCategory() != null ? pg.getCategory().getName() : "Tổng";
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_budgets")
                        .postgresTable("budgets")
                        .recordId(id)
                        .diffType("ONLY_IN_POSTGRES")
                        .title("Ngân sách #" + id + " - " + catName)
                        .postgresSummary("Hạn mức: " + formatMoney(pg.getAmount()) + " | Chu kỳ: " + pg.getPeriodType())
                        .mongoSummary("Không tồn tại trên MongoDB")
                        .build());
            } else if (pg != null && mg != null && !sameAmount(pg.getAmount(), mg.getAmount())) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_budgets")
                        .postgresTable("budgets")
                        .recordId(id)
                        .diffType("VALUE_MISMATCH")
                        .title("Ngân sách #" + id + " — Lệch hạn mức")
                        .postgresSummary("Hạn mức PG: " + formatMoney(pg.getAmount()))
                        .mongoSummary("Hạn mức Mongo: " + formatMoney(mg.getAmount()))
                        .build());
            }
        }
    }

    private void collectSavingGoalDiffs(List<MirrorDiffItemDto> out) {
        Map<Long, SavingGoal> pgMap = savingGoalRepo.findAllWithUser().stream()
                .filter(g -> g.getId() != null)
                .collect(Collectors.toMap(SavingGoal::getId, Function.identity(), (a, b) -> a));
        Map<Long, PgBackupSavingGoalDocument> mongoMap = backupSavingGoalRepo.findAll().stream()
                .filter(g -> g.getId() != null)
                .collect(Collectors.toMap(PgBackupSavingGoalDocument::getId, Function.identity(), (a, b) -> a));

        Set<Long> allIds = new TreeSet<>(pgMap.keySet());
        allIds.addAll(mongoMap.keySet());

        for (Long id : allIds) {
            SavingGoal pg = pgMap.get(id);
            PgBackupSavingGoalDocument mg = mongoMap.get(id);
            if (pg == null && mg != null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_saving_goals")
                        .postgresTable("saving_goals")
                        .recordId(id)
                        .diffType("ONLY_IN_MONGO")
                        .title("Mục tiêu #" + id + " - " + mg.getTitle())
                        .postgresSummary("Không tồn tại trên PostgreSQL")
                        .mongoSummary("Đã góp: " + formatMoney(mg.getCurrentAmount()) + " / " + formatMoney(mg.getTargetAmount()))
                        .build());
            } else if (pg != null && mg == null) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_saving_goals")
                        .postgresTable("saving_goals")
                        .recordId(id)
                        .diffType("ONLY_IN_POSTGRES")
                        .title("Mục tiêu #" + id + " - " + pg.getTitle())
                        .postgresSummary("Đã góp: " + formatMoney(pg.getCurrentAmount()) + " / " + formatMoney(pg.getTargetAmount()))
                        .mongoSummary("Không tồn tại trên MongoDB")
                        .build());
            } else if (pg != null && mg != null && !sameAmount(pg.getCurrentAmount(), mg.getCurrentAmount())) {
                out.add(MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_saving_goals")
                        .postgresTable("saving_goals")
                        .recordId(id)
                        .diffType("VALUE_MISMATCH")
                        .title("Mục tiêu #" + id + " - " + pg.getTitle() + " — Lệch tiền tích lũy")
                        .postgresSummary("Đã góp PG: " + formatMoney(pg.getCurrentAmount()))
                        .mongoSummary("Đã góp Mongo: " + formatMoney(mg.getCurrentAmount()))
                        .build());
            }
        }
    }

    private static boolean sameAmount(BigDecimal a, BigDecimal b) {
        BigDecimal na = a != null ? a : BigDecimal.ZERO;
        BigDecimal nb = b != null ? b : BigDecimal.ZERO;
        return na.compareTo(nb) == 0;
    }

    private static String formatMoney(BigDecimal val) {
        if (val == null) {
            return "0 VNĐ";
        }
        return val.stripTrailingZeros().toPlainString() + " VNĐ";
    }
}
