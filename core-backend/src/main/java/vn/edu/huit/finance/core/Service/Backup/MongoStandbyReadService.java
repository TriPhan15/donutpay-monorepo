package vn.edu.huit.finance.core.Service.Backup;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Document.Backup.PgBackupBudgetDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupSavingGoalDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;
import vn.edu.huit.finance.core.Dto.AppDashboardResponseDto;
import vn.edu.huit.finance.core.Dto.BudgetResponseDto;
import vn.edu.huit.finance.core.Dto.CategoryResponseDto;
import vn.edu.huit.finance.core.Dto.PopularVendorResponseDto;
import vn.edu.huit.finance.core.Dto.ReceiptResponseDto;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Dto.TransactionFilterRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchResponseDto;
import vn.edu.huit.finance.core.Entity.TransactionSortField;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.BudgetNotFoundException;
import vn.edu.huit.finance.core.Exception.ReceiptNotFoundException;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupBudgetRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupCategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupSavingGoalRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupTransactionRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupUserRepository;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.function.Function;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Thực thi các truy vấn đọc dự phòng (Read-Fallback) trực tiếp trên 5 Collection {@code pg_backup_*}
 * của MongoDB khi PostgreSQL bị sập hoặc khi bật chế độ Force MongoDB Failover.
 * Phần ghi giao dịch dự phòng được tách sang {@link MongoStandbyWriteService}.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MongoStandbyReadService {

    private static final int DASHBOARD_RECENT_COUNT = 5;
    private static final String MSG_BUDGET_NOT_FOUND = "Không tìm thấy ngân sách";
    private static final String MSG_RECEIPT_NOT_FOUND = "Không tìm thấy hóa đơn";
    private static final String MSG_RECEIPT_FORBIDDEN = "Bạn không có quyền thao tác trên hóa đơn này";
    private static final Pattern COMBINING_MARKS = Pattern.compile("\\p{M}+");

    private final PgBackupUserRepository backupUserRepo;
    private final PgBackupCategoryRepository backupCategoryRepo;
    private final PgBackupTransactionRepository backupTransactionRepo;
    private final PgBackupBudgetRepository backupBudgetRepo;
    private final PgBackupSavingGoalRepository backupSavingGoalRepo;

    private volatile MongoStandbyWriteService delegateWriteService;

    public Optional<User> findUserByUsernameOrEmail(String usernameOrEmail) {
        if (usernameOrEmail == null || usernameOrEmail.isBlank()) {
            return Optional.empty();
        }
        return backupUserRepo.findByEmailIgnoreCase(usernameOrEmail)
                .or(() -> backupUserRepo.findByUsernameIgnoreCase(usernameOrEmail))
                .map(PgBackupUserDocument::toEntity);
    }

    public Optional<User> findUserById(Long userId) {
        if (userId == null) {
            return Optional.empty();
        }
        return backupUserRepo.findById(userId).map(PgBackupUserDocument::toEntity);
    }

    public boolean existsUserById(Long userId) {
        return userId != null && backupUserRepo.existsById(userId);
    }

    /** Phục vụ {@code GET /api/categories}. */
    public List<CategoryResponseDto> listCategoriesFor(Long userId) {
        return backupCategoryRepo.findVisibleToUser(userId).stream()
                .sorted(Comparator.comparing(PgBackupCategoryDocument::getId, Comparator.nullsLast(Long::compareTo)))
                .map(PgBackupCategoryDocument::toResponseDto)
                .toList();
    }

    /** Phục vụ {@code GET /api/transactions/mine}. */
    public List<TransactionResponseDto> getTransactionsByUser(Long userId) {
        return backupTransactionRepo.findByUserIdOrderByTransactionDateDescIdDesc(userId).stream()
                .map(PgBackupTransactionDocument::toResponseDto)
                .toList();
    }

    /** Phục vụ {@code GET /api/transactions/filter}. */
    public List<TransactionResponseDto> filterTransactions(Long userId, TransactionFilterRequestDto filter) {
        Sort.Direction direction = Sort.Direction.fromOptionalString(filter.getSortDirection()).orElse(Sort.Direction.DESC);
        TransactionSortField sortField = (filter.getSortBy() != null && !filter.getSortBy().isBlank())
                ? TransactionSortField.fromProperty(filter.getSortBy())
                : TransactionSortField.TRANSACTION_DATE;

        Comparator<PgBackupTransactionDocument> comparator = (sortField == TransactionSortField.AMOUNT)
                ? Comparator.comparing(doc -> Objects.requireNonNullElse(doc.getAmount(), BigDecimal.ZERO))
                : Comparator.comparing(PgBackupTransactionDocument::getTransactionDate, Comparator.nullsLast(Comparator.naturalOrder()));
        if (direction == Sort.Direction.DESC) {
            comparator = comparator.reversed();
        }

        String normalizedVendor = (filter.getVendorName() != null && !filter.getVendorName().isBlank())
                ? filter.getVendorName().trim().toLowerCase(Locale.ROOT)
                : null;

        return backupTransactionRepo.findByUserIdOrderByTransactionDateDescIdDesc(userId).stream()
                .filter(doc -> filter.getCategoryId() == null || Objects.equals(doc.getCategoryId(), filter.getCategoryId()))
                .filter(doc -> filter.getMinPrice() == null
                        || (doc.getAmount() != null && doc.getAmount().compareTo(filter.getMinPrice()) >= 0))
                .filter(doc -> filter.getMaxPrice() == null
                        || (doc.getAmount() != null && doc.getAmount().compareTo(filter.getMaxPrice()) <= 0))
                .filter(doc -> {
                    if (normalizedVendor == null) {
                        return true;
                    }
                    String rVendor = (doc.getReceipt() != null && doc.getReceipt().getVendorName() != null)
                            ? doc.getReceipt().getVendorName().toLowerCase(Locale.ROOT)
                            : "";
                    String note = doc.getNote() != null ? doc.getNote().toLowerCase(Locale.ROOT) : "";
                    return rVendor.contains(normalizedVendor) || note.contains(normalizedVendor);
                })
                .sorted(comparator)
                .map(PgBackupTransactionDocument::toResponseDto)
                .toList();
    }

    /** Phục vụ {@code GET /api/transactions/search}. */
    public TransactionSearchResponseDto searchTransactions(Long userId, TransactionSearchRequestDto request) {
        String rawQuery = request.getQ() != null ? request.getQ().trim() : "";
        String foldedQuery = foldText(rawQuery);
        int page = Math.max(0, request.getPage());
        int size = Math.max(1, request.getSize());

        List<PgBackupTransactionDocument> matched = backupTransactionRepo
                .findByUserIdOrderByTransactionDateDescIdDesc(userId).stream()
                .filter(doc -> matchesSearchQuery(doc, rawQuery.toLowerCase(Locale.ROOT), foldedQuery))
                .toList();

        long total = matched.size();
        int fromIndex = Math.min(page * size, matched.size());
        int toIndex = Math.min(fromIndex + size, matched.size());
        List<TransactionResponseDto> pageItems = matched.subList(fromIndex, toIndex).stream()
                .map(PgBackupTransactionDocument::toResponseDto)
                .toList();

        return TransactionSearchResponseDto.builder()
                .items(pageItems)
                .total(total)
                .engine("postgres")
                .build();
    }

    /** Phục vụ nạp danh sách giao dịch từ IDs của Elasticsearch khi PostgreSQL đang ở chế độ Failover. */
    public List<TransactionResponseDto> loadTransactionsByIds(List<Long> ids, Long userId) {
        if (ids == null || ids.isEmpty()) {
            return List.of();
        }
        Map<Long, PgBackupTransactionDocument> byId = backupTransactionRepo.findByIdInAndUserId(ids, userId).stream()
                .collect(Collectors.toMap(PgBackupTransactionDocument::getId, Function.identity(), (a, b) -> a));
        return ids.stream()
                .map(byId::get)
                .filter(Objects::nonNull)
                .map(PgBackupTransactionDocument::toResponseDto)
                .toList();
    }

    /** Phục vụ {@code GET /api/transactions/popular-vendors}. */
    public List<PopularVendorResponseDto> popularVendorsOf(Long userId) {
        Map<String, Long> counts = backupTransactionRepo.findByUserIdOrderByTransactionDateDescIdDesc(userId).stream()
                .map(PgBackupTransactionDocument::getReceipt)
                .filter(Objects::nonNull)
                .map(PgBackupTransactionDocument.EmbeddedReceipt::getVendorName)
                .filter(v -> v != null && !v.isBlank())
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));

        return counts.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .map(entry -> PopularVendorResponseDto.builder()
                        .vendorName(entry.getKey())
                        .transactionCount(entry.getValue())
                        .build())
                .toList();
    }

    /** Phục vụ {@code GET /api/transactions/app-dashboard}. */
    public AppDashboardResponseDto dashboardOf(Long userId) {
        List<PgBackupTransactionDocument> all = backupTransactionRepo.findByUserIdOrderByTransactionDateDescIdDesc(userId);

        List<TransactionResponseDto> recent = all.stream()
                .limit(DASHBOARD_RECENT_COUNT)
                .map(PgBackupTransactionDocument::toResponseDto)
                .toList();

        TransactionResponseDto biggest = all.stream()
                .filter(d -> d.getAmount() != null)
                .max(Comparator.comparing(PgBackupTransactionDocument::getAmount))
                .map(PgBackupTransactionDocument::toResponseDto)
                .orElse(null);

        List<TransactionResponseDto> sales = all.stream()
                .filter(d -> d.getVoucherCode() != null && !d.getVoucherCode().isBlank())
                .map(PgBackupTransactionDocument::toResponseDto)
                .toList();

        return AppDashboardResponseDto.builder()
                .recentTransactions(recent)
                .biggestTransaction(biggest)
                .saleTransactions(sales)
                .build();
    }

    /** Phục vụ {@code GET /api/budgets}. */
    public List<BudgetResponseDto> getBudgetsByUser(Long userId) {
        return backupBudgetRepo.findByUserIdOrderByStartDateDescIdDesc(userId).stream()
                .map(PgBackupBudgetDocument::toResponseDto)
                .toList();
    }

    /** Phục vụ {@code GET /api/budgets/{id}}. */
    public BudgetResponseDto getBudgetByIdAndUser(Long budgetId, Long userId) {
        return backupBudgetRepo.findByIdAndUserId(budgetId, userId)
                .map(PgBackupBudgetDocument::toResponseDto)
                .orElseThrow(() -> new BudgetNotFoundException(MSG_BUDGET_NOT_FOUND));
    }

    /** Phục vụ {@code GET /api/savings}. */
    public List<SavingGoalDto> getSavingsByUser(Long userId) {
        return backupSavingGoalRepo.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(PgBackupSavingGoalDocument::toResponseDto)
                .toList();
    }

    /** Phục vụ {@code GET /api/receipts/{id}}. */
    public ReceiptResponseDto getReceiptForUser(Long receiptId, Long userId) {
        PgBackupTransactionDocument txDoc = backupTransactionRepo.findByReceipt_Id(receiptId)
                .orElseThrow(() -> new ReceiptNotFoundException(MSG_RECEIPT_NOT_FOUND));
        Long ownerId = txDoc.getReceipt().getOwnerId() != null ? txDoc.getReceipt().getOwnerId() : txDoc.getUserId();
        if (!Objects.equals(ownerId, userId) || userId == null) {
            throw new TransactionAccessDeniedException(MSG_RECEIPT_FORBIDDEN);
        }
        return txDoc.getReceipt().toReceiptResponseDto(txDoc.getId());
    }

    /** Phục vụ {@code GET /api/receipts/transaction/{transactionId}}. */
    public ReceiptResponseDto getReceiptOfTransactionForUser(Long transactionId, Long userId) {
        PgBackupTransactionDocument txDoc = backupTransactionRepo.findById(transactionId)
                .orElseThrow(() -> new ReceiptNotFoundException(MSG_RECEIPT_NOT_FOUND));
        if (txDoc.getReceipt() == null) {
            throw new ReceiptNotFoundException(MSG_RECEIPT_NOT_FOUND);
        }
        Long ownerId = txDoc.getReceipt().getOwnerId() != null ? txDoc.getReceipt().getOwnerId() : txDoc.getUserId();
        if (!Objects.equals(ownerId, userId) || userId == null) {
            throw new TransactionAccessDeniedException(MSG_RECEIPT_FORBIDDEN);
        }
        return txDoc.getReceipt().toReceiptResponseDto(txDoc.getId());
    }

    /** Ủy quyền sang {@link MongoStandbyWriteService} để tương thích ngược. */
    public Map<String, Object> createStandbyTransaction(User caller, TransactionRequestDto request) {
        MongoStandbyWriteService writeService = this.delegateWriteService;
        if (writeService == null) {
            synchronized (this) {
                writeService = this.delegateWriteService;
                if (writeService == null) {
                    writeService = new MongoStandbyWriteService(backupUserRepo, backupCategoryRepo, backupTransactionRepo);
                    this.delegateWriteService = writeService;
                }
            }
        }
        return writeService.createStandbyTransaction(caller, request);
    }

    private static boolean matchesSearchQuery(PgBackupTransactionDocument doc, String lowerQuery, String foldedQuery) {
        if (lowerQuery.isEmpty()) {
            return true;
        }
        String vendorName = doc.getReceipt() != null ? doc.getReceipt().getVendorName() : null;
        return containsText(doc.getNote(), lowerQuery, foldedQuery)
                || containsText(doc.getReviewNote(), lowerQuery, foldedQuery)
                || containsText(doc.getCategoryName(), lowerQuery, foldedQuery)
                || containsText(vendorName, lowerQuery, foldedQuery)
                || containsText(doc.getLocation(), lowerQuery, foldedQuery)
                || containsText(doc.getPaymentMethod(), lowerQuery, foldedQuery);
    }

    private static boolean containsText(String candidate, String lowerQuery, String foldedQuery) {
        if (candidate == null || candidate.isBlank()) {
            return false;
        }
        String lowerCandidate = candidate.toLowerCase(Locale.ROOT);
        if (lowerCandidate.contains(lowerQuery)) {
            return true;
        }
        return !foldedQuery.isEmpty() && foldText(lowerCandidate).contains(foldedQuery);
    }

    private static String foldText(String input) {
        if (input == null || input.isBlank()) {
            return "";
        }
        String decomposed = Normalizer.normalize(input.toLowerCase(Locale.ROOT), Normalizer.Form.NFD);
        return COMBINING_MARKS.matcher(decomposed).replaceAll("").replace('đ', 'd');
    }
}
