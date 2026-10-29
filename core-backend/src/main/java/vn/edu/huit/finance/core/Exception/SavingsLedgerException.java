package vn.edu.huit.finance.core.Exception;

/**
 * A savings transaction can only be made, changed or removed through its savings goal, so nothing was written.
 * Mapped to 409 by {@link GlobalExceptionHandler}.
 */
public class SavingsLedgerException extends RuntimeException {

    public SavingsLedgerException(String message) {
        super(message);
    }
}
