package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

/**
 * Body of POST /api/payment/webhook. Every field is part of the signed text, so a missing one is a 400 before the
 * signature is checked (an empty body used to end in a NullPointerException and a 500). The lengths are the columns
 * of payment_orders.
 */
@Data
public class PaymentWebhookDto {

    private static final int ORDER_CODE_MAX_LENGTH = 64;
    private static final int GATEWAY_TXN_ID_MAX_LENGTH = 64;
    private static final int RESULT_CODE_MAX_LENGTH = 16;
    private static final int SIGNATURE_MAX_LENGTH = 128;
    private static final int AMOUNT_INTEGER_DIGITS = 17;
    private static final int AMOUNT_FRACTION_DIGITS = 2;

    @NotBlank(message = "Thiếu mã đơn (orderCode)")
    @Size(max = ORDER_CODE_MAX_LENGTH, message = "Mã đơn (orderCode) tối đa {max} ký tự")
    private String orderCode;

    @NotBlank(message = "Thiếu mã giao dịch của cổng (gatewayTxnId)")
    @Size(max = GATEWAY_TXN_ID_MAX_LENGTH, message = "Mã giao dịch của cổng (gatewayTxnId) tối đa {max} ký tự")
    private String gatewayTxnId;

    @NotBlank(message = "Thiếu mã kết quả (resultCode)")
    @Size(max = RESULT_CODE_MAX_LENGTH, message = "Mã kết quả (resultCode) tối đa {max} ký tự")
    private String resultCode;

    @NotNull(message = "Thiếu số tiền (amount)")
    @Digits(integer = AMOUNT_INTEGER_DIGITS, fraction = AMOUNT_FRACTION_DIGITS, message = "Số tiền (amount) không hợp lệ")
    private BigDecimal amount;

    @NotBlank(message = "Thiếu chữ ký (signature)")
    @Size(max = SIGNATURE_MAX_LENGTH, message = "Chữ ký (signature) tối đa {max} ký tự")
    private String signature;
}
