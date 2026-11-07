package vn.edu.huit.finance.core.Service.Backup;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Document.Backup.PgBackupCategoryDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupTransactionDocument;
import vn.edu.huit.finance.core.Document.Backup.PgBackupUserDocument;
import vn.edu.huit.finance.core.Dto.TransactionRequestDto;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.TransactionSource;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.InsufficientBalanceException;
import vn.edu.huit.finance.core.Exception.InvalidCategoryException;
import vn.edu.huit.finance.core.Exception.SavingsLedgerException;
import vn.edu.huit.finance.core.Exception.UserNotFoundException;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupCategoryRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupTransactionRepository;
import vn.edu.huit.finance.core.Repository.Mongo.PgBackupUserRepository;
import vn.edu.huit.finance.core.Util.CategoryNames;
import vn.edu.huit.finance.core.Util.SavingsContributions;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Dịch vụ ghi giao dịch dự phòng (Write-Fallback) trực tiếp vào {@code pg_backup_transactions}
 * và cập nhật số dư ví {@code walletBalance} trong {@code pg_backup_users} khi PostgreSQL đang sập
 * hoặc bật chế độ Failover. Đồng bộ hóa theo từng {@code userId} để chống race condition số dư ví.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MongoStandbyWriteService {

    private static final BigDecimal LOW_BALANCE_THRESHOLD = new BigDecimal("50000");
    private static final String MSG_LOW_BALANCE = "CẢNH BÁO: Số dư ví của bạn sắp cạn kiệt (Dưới 50,000 VNĐ)!";
    private static final String MSG_INSUFFICIENT_BALANCE = "GIAO DỊCH THẤT BẠI: Số dư ví không đủ!";
    private static final String MSG_SAVINGS_MANAGED_BY_GOAL =
            "Khoản góp tiết kiệm được quản lý trong mục Mục tiêu tiết kiệm. Hãy góp thêm hoặc xóa mục tiêu ở đó.";
    private static final String MSG_CATEGORY_NOT_FOUND = "Không tìm thấy danh mục";
    private static final String MSG_CATEGORY_REQUIRED = "Thiếu danh mục (categoryId hoặc categoryName)";
    private static final String MSG_USER_NOT_FOUND = "Không tìm thấy người dùng";

    private final PgBackupUserRepository backupUserRepo;
    private final PgBackupCategoryRepository backupCategoryRepo;
    private final PgBackupTransactionRepository backupTransactionRepo;

    private final ConcurrentHashMap<Long, Object> userWalletLocks = new ConcurrentHashMap<>();
    private final AtomicLong txIdSequence = new AtomicLong(0L);
    private final AtomicLong categoryIdSequence = new AtomicLong(0L);
    private final AtomicLong receiptIdSequence = new AtomicLong(0L);

    public Map<String, Object> createStandbyTransaction(User caller, TransactionRequestDto request) {
        if (caller == null || caller.getId() == null) {
            throw new UserNotFoundException(MSG_USER_NOT_FOUND);
        }
        Long userId = caller.getId();
        Object walletLock = userWalletLocks.computeIfAbsent(userId, ignored -> new Object());

        synchronized (walletLock) {
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

    private synchronized long nextTransactionId() {
        long maxInDb = backupTransactionRepo.findTopByOrderByIdDesc()
                .map(PgBackupTransactionDocument::getId)
                .orElseGet(() -> backupTransactionRepo.findAll().stream()
                        .map(PgBackupTransactionDocument::getId)
                        .filter(Objects::nonNull)
                        .mapToLong(Long::longValue)
                        .max()
                        .orElse(0L));
        long next = Math.max(txIdSequence.get(), maxInDb) + 1L;
        txIdSequence.set(next);
        return next;
    }

    private synchronized long nextCategoryId() {
        long maxInDb = backupCategoryRepo.findTopByOrderByIdDesc()
                .map(PgBackupCategoryDocument::getId)
                .orElseGet(() -> backupCategoryRepo.findAll().stream()
                        .map(PgBackupCategoryDocument::getId)
                        .filter(Objects::nonNull)
                        .mapToLong(Long::longValue)
                        .max()
                        .orElse(0L));
        long next = Math.max(categoryIdSequence.get(), maxInDb) + 1L;
        categoryIdSequence.set(next);
        return next;
    }

    private synchronized long nextReceiptId() {
        long maxInDb = backupTransactionRepo.findTopByReceipt_IdIsNotNullOrderByReceipt_IdDesc()
                .map(PgBackupTransactionDocument::getReceipt)
                .filter(Objects::nonNull)
                .map(PgBackupTransactionDocument.EmbeddedReceipt::getId)
                .orElseGet(() -> backupTransactionRepo.findAll().stream()
                        .map(PgBackupTransactionDocument::getReceipt)
                        .filter(Objects::nonNull)
                        .map(PgBackupTransactionDocument.EmbeddedReceipt::getId)
                        .filter(Objects::nonNull)
                        .mapToLong(Long::longValue)
                        .max()
                        .orElse(0L));
        long next = Math.max(receiptIdSequence.get(), maxInDb) + 1L;
        receiptIdSequence.set(next);
        return next;
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
}
