package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

/** Answer of POST /api/payment/create: the new order and the address to pay it at. The JSON keys are read by the mobile app. */
@Data
@Builder
public class PaymentOrderResponseDto {
    private String orderCode;
    private BigDecimal amount;
    /** PaymentType name: DEPOSIT or WITHDRAW. */
    private String type;
    /** PaymentStatus name. */
    private String status;
    private String provider;
    private String payUrl;
}
