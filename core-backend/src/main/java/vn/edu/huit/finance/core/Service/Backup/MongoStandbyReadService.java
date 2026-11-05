package vn.edu.huit.finance.core.Service.Backup;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.TransactionSortField;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.BudgetNotFoundException;
import vn.edu.huit.finance.core.Exception.InsufficientBalanceException;
import vn.edu.huit.finance.core.Exception.InvalidCategoryException;
import vn.edu.huit.finance.core.Exception.ReceiptNotFoundException;
import vn.edu.huit.finance.core.Exception.SavingsLedgerException;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Exception.TransactionNotFoundException;
import vn.edu.huit.finance.core.Exception.UserNotFoundException;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupBudgetRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupCategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupSavingGoalRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupTransactionRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupUserRepository;
import vn.edu.huit.finance.core.Util.CategoryNames;
import vn.edu.huit.finance.core.Util.SavingsContributions;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
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
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MongoStandbyReadService {

    private static final int DASHBOARD_RECENT_COUNT = 5;
    private static final BigDecimal LOW_BALANCE_THRESHOLD = new BigDecimal("50000");
    private static final String MSG_LOW_BALANCE = "CẢNH BÁO: Số dư ví của bạn sắp cạn kiệt (Dưới 50,000 VNĐ)!";
    private static final String MSG_INSUFFICIENT_BALANCE = "GIAO DỊCH THẤT BẠI: Số dư ví không đủ!";
    private static final String MSG_SAVINGS_MANAGED_BY_GOAL =
            "Khoản góp tiết kiệm được quản lý trong mục Mục tiêu tiết kiệm. Hãy góp thêm hoặc xóa mục tiêu ở đó.";
    private static final String MSG_CATEGORY_NOT_FOUND = "Không tìm thấy danh mục";
    private static final String MSG_CATEGORY_REQUIRED = "Thiếu danh mục (categoryId hoặc categoryName)";
    private static final String MSG_USER_NOT_FOUND = "Không tìm thấy người dùng";
    private static final String MSG_BUDGET_NOT_FOUND = "Không tìm thấy ngân sách";
    private static final String MSG_RECEIPT_NOT_FOUND = "Không tìm thấy hóa đơn";
    private static final String MSG_RECEIPT_FORBIDDEN = "Bạn không có quyền thao tác trên hóa đơn này";
    private static final String MSG_TRANSACTION_NOT_FOUND = "Không tìm thấy giao dịch";
    private static final String MSG_TRANSACTION_FORBIDDEN = "Bạn không có quyền thao tác trên giao dịch này";
    private static final Pattern COMBINING_MARKS = Pattern.compile("\\p{M}+");

    private final PgBackupUserRepository backupUserRepo;
    private final PgBackupCategoryRepository backupCategoryRepo;
    private final PgBackupTransactionRepository backupTransactionRepo;
    private final PgBackupBudgetRepository backupBudgetRepo;
    private final PgBackupSavingGoalRepository backupSavingGoalRepo;

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

    /**
     * Ghi giao dịch dự phòng (Write-Fallback) trực tiếp vào {@code pg_backup_transactions} và cập nhật số dư ví
     * {@code walletBalance} trong {@code pg_backup_users} khi PostgreSQL đang sập hoặc bật chế độ Failover.
     */
    public synchronized Map<String, Object> createStandbyTransaction(User caller, TransactionRequestDto request) {
        if (caller == null || caller.getId() == null) {
            throw new UserNotFoundException(MSG_USER_NOT_FOUND);
        }
        Long userId = caller.getId();
        PgBackupUserDocument userDoc = backupUserRepo.findById(userId)
                .orElseGet(() -> PgBackupUserDocument.from(caller));

        String clientId = (request.getClientId() != null && !request.getClientId().isBlank())
                ? request.getClientId().trim()
                : null;
        if (clientId != null) {
            Optional<PgBackupTransactionDocument> existing = backupTransactionRepo
                    .findByUserIdOrderByTransactionDateDescIdDesc(userId).stream()
                    .filter(doc -> clientId.equals(doc.getClientId()))
                    .findFirst();
            if (existing.isPresent()) {
                BigDecimal currentBalance = Objects.requireNonNullElse(userDoc.getWalletBalance(), BigDecimal.ZERO);
                return buildCheckoutResponse(existing.get().getId(), existing.get().getAmount(), currentBalance);
            }
        }

        PgBackupCategoryDocument categoryDoc = resolveOrCreateStandbyCategory(
                request.getCategoryId(), request.getCategoryName(), request.isExpense(), userId);

        if (SavingsContributions.CATEGORY_NAME.equals(CategoryNames.clean(categoryDoc.getName()))
                && DefaultCategory.TYPE_EXPENSE.equals(categoryDoc.getType())) {
            throw new SavingsLedgerException(MSG_SAVINGS_MANAGED_BY_GOAL);
        }

        BigDecimal finalAmount = request.getAmount();
        BigDecimal currentBalance = Objects.requireNonNullElse(userDoc.getWalletBalance(), BigDecimal.ZERO);
        BigDecimal signedChange = request.isExpense() ? finalAmount.negate() : finalAmount;
        BigDecimal newBalance = currentBalance.add(signedChange);
        if (signedChange.signum() < 0 && newBalance.signum() < 0) {
            throw new InsufficientBalanceException(MSG_INSUFFICIENT_BALANCE);
        }

        LocalDateTime now = LocalDateTime.now();
        userDoc.setWalletBalance(newBalance);
        userDoc.setUpdatedAt(now);
        userDoc.setMirroredAt(now);
        backupUserRepo.save(userDoc);

        String additionalImagesJson = null;
        if (request.getAdditionalImages() != null && !request.getAdditionalImages().isEmpty()) {
            try {
                additionalImagesJson = new ObjectMapper().writeValueAsString(request.getAdditionalImages());
            } catch (JsonProcessingException e) {
                throw new IllegalStateException("Additional images could not be written as JSON", e);
            }
        }

        PgBackupTransactionDocument.EmbeddedReceipt embeddedReceipt = null;
        if ((request.getRawReceiptData() != null && !request.getRawReceiptData().isBlank())
                || (request.getImageUrl() != null && !request.getImageUrl().isBlank())) {
            embeddedReceipt = PgBackupTransactionDocument.EmbeddedReceipt.builder()
                    .id(nextReceiptId())
                    .vendorName(request.getLocation())
                    .extractedTotal(finalAmount)
                    .extractedDate(request.getTransactionDate() != null ? request.getTransactionDate().toLocalDate() : now.toLocalDate())
                    .imageUrl(request.getImageUrl())
                    .status(ReceiptStatus.COMPLETED_RAW.name())
                    .version(0L)
                    .ownerId(userId)
                    .createdAt(now)
                    .updatedAt(now)
                    .build();
        }

        long nextTxId = nextTransactionId();
        String reviewNote = (request.isExpense() && request.getReviewNote() != null && !request.getReviewNote().isBlank())
                ? request.getReviewNote().trim()
                : null;

        PgBackupTransactionDocument txDoc = PgBackupTransactionDocument.builder()
                .id(nextTxId)
                .userId(userId)
                .categoryId(categoryDoc.getId())
                .categoryName(categoryDoc.getName())
                .amount(finalAmount)
                .note(request.getNote())
                .transactionDate(request.getTransactionDate())
                .isExpense(request.isExpense())
                .source(TransactionSource.NORMAL.name())
                .clientId(clientId)
                .additionalImages(additionalImagesJson)
                .location(request.getLocation())
                .paymentMethod(request.getPaymentMethod())
                .rating(request.isExpense() ? request.getRating() : null)
                .reviewNote(reviewNote)
                .receipt(embeddedReceipt)
                .createdAt(now)
                .updatedAt(now)
                .mirroredAt(now)
                .build();
        backupTransactionRepo.save(txDoc);

        log.info("Standby transaction saved to MongoDB (txId={}, userId={}, amount={}, isExpense={}, newBalance={})",
                nextTxId, userId, finalAmount, request.isExpense(), newBalance);

        return buildCheckoutResponse(nextTxId, finalAmount, newBalance);
    }

    private PgBackupCategoryDocument resolveOrCreateStandbyCategory(Long categoryId,
                                                                    String categoryName,
                                                                    boolean isExpense,
                                                                    Long userId) {
        List<PgBackupCategoryDocument> visible = backupCategoryRepo.findVisibleToUser(userId);
        if (categoryId != null) {
            return visible.stream()
                    .filter(c -> Objects.equals(c.getId(), categoryId))
                    .findFirst()
                    .orElseThrow(() -> new InvalidCategoryException(MSG_CATEGORY_NOT_FOUND));
        }
        if (categoryName == null || categoryName.isBlank()) {
            throw new InvalidCategoryException(MSG_CATEGORY_REQUIRED);
        }
        String typed = CategoryNames.clean(categoryName);
        Optional<DefaultCategory> shared = Arrays.stream(DefaultCategory.values())
                .filter(d -> d.getDisplayName().equalsIgnoreCase(typed))
                .findFirst();
        String resolvedName = shared.map(DefaultCategory::getDisplayName).orElse(typed);

        Optional<PgBackupCategoryDocument> found = visible.stream()
                .filter(c -> c.getName() != null && c.getName().equalsIgnoreCase(resolvedName))
                .findFirst();
        if (found.isPresent()) {
            return found.get();
        }

        LocalDateTime now = LocalDateTime.now();
        Long ownerId = shared.isPresent() ? null : userId;
        long ownerKey = ownerId != null ? ownerId : 0L;
        PgBackupCategoryDocument created = PgBackupCategoryDocument.builder()
                .id(nextCategoryId())
                .name(resolvedName)
                .type(isExpense ? DefaultCategory.TYPE_EXPENSE : DefaultCategory.TYPE_INCOME)
                .ownerId(ownerId)
                .ownerKey(ownerKey)
                .createdAt(now)
                .updatedAt(now)
                .mirroredAt(now)
                .build();
        return backupCategoryRepo.save(created);
    }

    private long nextTransactionId() {
        return backupTransactionRepo.findAll().stream()
                .map(PgBackupTransactionDocument::getId)
                .filter(Objects::nonNull)
                .mapToLong(Long::longValue)
                .max()
                .orElse(0L) + 1L;
    }

    private long nextCategoryId() {
        return backupCategoryRepo.findAll().stream()
                .map(PgBackupCategoryDocument::getId)
                .filter(Objects::nonNull)
                .mapToLong(Long::longValue)
                .max()
                .orElse(0L) + 1L;
    }

    private long nextReceiptId() {
        return backupTransactionRepo.findAll().stream()
                .map(PgBackupTransactionDocument::getReceipt)
                .filter(Objects::nonNull)
                .map(PgBackupTransactionDocument.EmbeddedReceipt::getId)
                .filter(Objects::nonNull)
                .mapToLong(Long::longValue)
                .max()
                .orElse(0L) + 1L;
    }

    private static Map<String, Object> buildCheckoutResponse(Long txId, BigDecimal finalAmount, BigDecimal remainingBalance) {
        boolean lowBalance = remainingBalance.compareTo(LOW_BALANCE_THRESHOLD) < 0;
        Map<String, Object> responseData = new HashMap<>();
        responseData.put("transactionId", txId);
        responseData.put("finalAmount", finalAmount);
        responseData.put("remainingBalance", remainingBalance);
        responseData.put("warning", lowBalance ? MSG_LOW_BALANCE : "");
        return responseData;
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
