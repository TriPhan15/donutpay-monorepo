package vn.edu.huit.finance.core.Exception;

/** 400: chữ ký của webhook thanh toán không khớp; không có gì được ghi vào đơn. */
public class PaymentWebhookRejectedException extends RuntimeException {

    public PaymentWebhookRejectedException(String message) {
        super(message);
    }
}
