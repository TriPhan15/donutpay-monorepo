package vn.edu.huit.finance.core.Exception;

/** 403: đơn thanh toán thuộc về người dùng khác. */
public class PaymentOrderAccessDeniedException extends RuntimeException {

    public PaymentOrderAccessDeniedException(String message) {
        super(message);
    }
}
