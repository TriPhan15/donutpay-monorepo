package vn.edu.huit.finance.core.Service.Realtime;

/**
 * Published inside the transaction that moved a receipt to WAITING_FOR_REVIEW; {@link AdminEventPublisher} turns it into an
 * admin event only once that transaction has committed, so a rollback tells nobody anything.
 */
public record ReceiptWaitingReviewEvent(Long receiptId) {
}
