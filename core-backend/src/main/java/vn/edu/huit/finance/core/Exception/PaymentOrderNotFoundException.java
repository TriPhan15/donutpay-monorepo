package vn.edu.huit.finance.core.Exception;

/** 404: không có đơn thanh toán với mã này. */
public class PaymentOrderNotFoundException extends RuntimeException {

    public PaymentOrderNotFoundException(String message) {
        super(message);
    }
}
