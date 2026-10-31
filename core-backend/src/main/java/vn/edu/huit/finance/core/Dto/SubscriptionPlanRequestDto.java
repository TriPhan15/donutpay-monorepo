package vn.edu.huit.finance.core.Dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Body of POST /admin/ajax/subscriptions and PUT /admin/ajax/subscriptions/{id}. The entity used to be bound directly,
 * without validation, and its {@code boolean isWcmSpadeEnabled} is read by Jackson as {@code wcmSpadeEnabled}, so the
 * "isWcmSpadeEnabled" key the page sent was dropped and every save turned the flag off. The page now sends
 * {@code wcmSpadeEnabled}; the old key is still accepted.
 */
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubscriptionPlanRequestDto {

    private static final int PLAN_NAME_MAX_LENGTH = 100;
    private static final String MAX_PRICE = "1000000000";
    private static final int MAX_DURATION_DAYS = 3650;
    private static final int MAX_AI_SCANS = 1_000_000;

    @NotBlank(message = "Tên gói không được để trống")
    @Size(max = PLAN_NAME_MAX_LENGTH, message = "Tên gói tối đa {max} ký tự")
    private String planName;

    @NotNull(message = "Giá gói không được để trống")
    @PositiveOrZero(message = "Giá gói không được âm")
    @DecimalMax(value = MAX_PRICE, message = "Giá gói tối đa 1.000.000.000 VNĐ")
    private Double price;

    @NotNull(message = "Thời hạn gói không được để trống")
    @Positive(message = "Thời hạn gói phải lớn hơn 0 ngày")
    @Max(value = MAX_DURATION_DAYS, message = "Thời hạn gói tối đa {value} ngày")
    private Integer durationDays;

    @NotNull(message = "Số lượt quét AI không được để trống")
    @PositiveOrZero(message = "Số lượt quét AI không được âm")
    @Max(value = MAX_AI_SCANS, message = "Số lượt quét AI tối đa {value}")
    private Integer maxAiScans;

    @JsonAlias("isWcmSpadeEnabled")
    private boolean wcmSpadeEnabled;
}
