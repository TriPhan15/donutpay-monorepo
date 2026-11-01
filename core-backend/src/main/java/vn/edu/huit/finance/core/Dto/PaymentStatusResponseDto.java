package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Data;
import vn.edu.huit.finance.core.Entity.PaymentOrder;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** One payment order as the status, history and cancel endpoints show it. The JSON keys are read by the mobile app. */
@Data
@Builder
public class PaymentStatusResponseDto {
    private String orderCode;
    private BigDecimal amount;
    /** PaymentType name: DEPOSIT or WITHDRAW. */
    private String type;
    /** PaymentStatus name. */
    private String status;
    private String provider;
    private String description;
    /** Null until the gateway has reported on the order. */
    private String gatewayTxnId;
    /** ISO local date-time text, null when the row has no creation time. */
    private String createdAt;

    public static PaymentStatusResponseDto from(PaymentOrder order) {
        LocalDateTime created = order.getCreatedAt();
        return PaymentStatusResponseDto.builder()
                .orderCode(order.getOrderCode())
                .amount(order.getAmount())
                .type(order.getType().name())
                .status(order.getStatus().name())
                .provider(order.getProvider())
                .description(order.getDescription())
                .gatewayTxnId(order.getGatewayTxnId())
                .createdAt(created != null ? created.toString() : null)
                .build();
    }
}
