package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

/**
 * Body of POST /api/savings/{id}/contributions: how much the caller moves from the wallet into one of their saving goals.
 * There is deliberately no user or goal field: the goal is the path variable and the owner is always the caller.
 */
@Getter
@Setter
public class SavingContributionRequestDto {

    /** What the amount columns hold (Hibernate's default numeric(38,2) for transactions.amount and the goal): 36 + 2 digits. */
    public static final int AMOUNT_INTEGER_DIGITS = 36;
    public static final int AMOUNT_FRACTION_DIGITS = 2;

    @NotNull(message = "Số tiền góp không được để trống")
    @Positive(message = "Số tiền góp phải lớn hơn 0")
    @Digits(integer = AMOUNT_INTEGER_DIGITS, fraction = AMOUNT_FRACTION_DIGITS,
            message = "Số tiền góp chỉ được có tối đa {integer} chữ số nguyên và {fraction} chữ số thập phân")
    private BigDecimal amount;
}
