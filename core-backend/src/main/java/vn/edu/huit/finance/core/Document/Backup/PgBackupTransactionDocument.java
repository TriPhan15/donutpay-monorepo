package vn.edu.huit.finance.core.Document.Backup;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Dto.ReceiptResponseDto;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.ReceiptErrorCode;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.TransactionSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bản sao dự phòng nóng của {@link Transaction} nhúng kèm {@link Receipt} trên MongoDB.
 * Gộp 2 bảng quan hệ 1–1 ({@code transactions} và {@code receipts}) thành 1 Document JSON duy nhất.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pg_backup_transactions")
@CompoundIndex(name = "user_tx_date_idx", def = "{'userId': 1, 'transactionDate': -1}")
public class PgBackupTransactionDocument {

    @Id
    private Long id;

    @Indexed
    private Long userId;

    private Long categoryId;

    private String categoryName;

    private BigDecimal amount;

    private String note;

    private LocalDateTime transactionDate;

    private boolean isExpense;

    private String source;

    private String clientId;

    private String status;

    private String voucherCode;

    private String additionalImages;

    private String location;

    private String paymentMethod;

    private BigDecimal rating;

    private String reviewNote;

    private EmbeddedReceipt receipt;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    private LocalDateTime mirroredAt;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EmbeddedReceipt {
        @Indexed
        private Long id;
        private String vendorName;
        private BigDecimal extractedTotal;
        private LocalDate extractedDate;
        private String imageUrl;
        private String status;
        private String errorCode;
        private Long version;
        private Long ownerId;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;

        public static EmbeddedReceipt from(Receipt receipt, Long fallbackOwnerId) {
            if (receipt == null) {
                return null;
            }
            Long resolvedOwnerId = receipt.ownerId() != null ? receipt.ownerId() : fallbackOwnerId;
            return EmbeddedReceipt.builder()
                    .id(receipt.getId())
                    .vendorName(receipt.getVendorName())
                    .extractedTotal(receipt.getExtractedTotal())
                    .extractedDate(receipt.getExtractedDate())
                    .imageUrl(receipt.getImageUrl())
                    .status(receipt.getStatus())
                    .errorCode(receipt.getErrorCode())
                    .version(receipt.getVersion() != null ? receipt.getVersion() : 0L)
                    .ownerId(resolvedOwnerId)
                    .createdAt(receipt.getCreatedAt())
                    .updatedAt(receipt.getUpdatedAt())
                    .build();
        }

        public ReceiptResponseDto toReceiptResponseDto() {
            return toReceiptResponseDto(null);
        }

        public ReceiptResponseDto toReceiptResponseDto(Long transactionId) {
            return ReceiptResponseDto.builder()
                    .id(this.id)
                    .transactionId(transactionId)
                    .vendorName(this.vendorName)
                    .extractedTotal(this.extractedTotal)
                    .extractedDate(this.extractedDate)
                    .imageUrl(this.imageUrl)
                    .status(ReceiptStatus.fromStored(this.status).map(Enum::name).orElse(this.status))
                    .errorCode(this.errorCode)
                    .errorMessage(ReceiptErrorCode.fromStored(this.errorCode)
                            .map(ReceiptErrorCode::getMessage)
                            .orElse(null))
                    .version(this.version)
                    .createdAt(this.createdAt)
                    .updatedAt(this.updatedAt)
                    .build();
        }
    }

    public static PgBackupTransactionDocument from(Transaction tx) {
        Long uid = tx.getUser() != null ? tx.getUser().getId() : null;
        Long cid = tx.getCategory() != null ? tx.getCategory().getId() : null;
        return PgBackupTransactionDocument.builder()
                .id(tx.getId())
                .userId(uid)
                .categoryId(cid)
                .categoryName(tx.getCategoryName())
                .amount(tx.getAmount())
                .note(tx.getNote())
                .transactionDate(tx.getTransactionDate())
                .isExpense(tx.isExpense())
                .source(tx.getSource() != null ? tx.getSource().name() : TransactionSource.NORMAL.name())
                .clientId(tx.getClientId())
                .status(tx.getStatus())
                .voucherCode(tx.getVoucherCode())
                .additionalImages(tx.getAdditionalImages())
                .location(tx.getLocation())
                .paymentMethod(tx.getPaymentMethod())
                .rating(tx.getRating())
                .reviewNote(tx.getReviewNote())
                .receipt(EmbeddedReceipt.from(tx.getReceipt(), uid))
                .createdAt(tx.getCreatedAt())
                .updatedAt(tx.getUpdatedAt())
                .mirroredAt(LocalDateTime.now())
                .build();
    }

    public TransactionResponseDto toResponseDto() {
        String resolvedTitle = (this.note != null && !this.note.isBlank()) ? this.note : this.categoryName;
        String imageUrl = this.receipt != null ? this.receipt.getImageUrl() : null;
        String receiptStatus = this.receipt != null ? ReceiptStatus.legacyNameOf(this.receipt.getStatus()) : null;
        return TransactionResponseDto.builder()
                .id(this.id)
                .title(resolvedTitle)
                .amount(this.amount)
                .date(this.transactionDate)
                .category(this.categoryName)
                .isExpense(this.isExpense)
                .imageUrl(imageUrl)
                .receiptStatus(receiptStatus)
                .clientId(this.clientId)
                .source(this.source != null ? this.source : TransactionSource.NORMAL.name())
                .rating(this.rating)
                .reviewNote(this.reviewNote)
                .build();
    }
}
