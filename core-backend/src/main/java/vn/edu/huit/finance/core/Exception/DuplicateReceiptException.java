package vn.edu.huit.finance.core.Exception;

import java.time.LocalDateTime;

/**
 * A scanned receipt looks like one the caller has saved already (same direction, amount, minute and seller). Answered
 * with a 409 that names the transaction already saved, so the app can show it or send the checkout again with
 * allowDuplicate=true.
 */
public class DuplicateReceiptException extends RuntimeException {

    private final Long existingTransactionId;
    private final LocalDateTime existingTransactionDate;

    public DuplicateReceiptException(String message, Long existingTransactionId, LocalDateTime existingTransactionDate) {
        super(message);
        this.existingTransactionId = existingTransactionId;
        this.existingTransactionDate = existingTransactionDate;
    }

    public Long getExistingTransactionId() {
        return existingTransactionId;
    }

    public LocalDateTime getExistingTransactionDate() {
        return existingTransactionDate;
    }
}
