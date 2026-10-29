package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
public class SavingGoalDto {

    public static final int TITLE_MAX_LENGTH = 255;
    /** Hạn mục tiêu mobile gửi lên: dd/MM/yyyy. */
    public static final String DEADLINE_PATTERN = "^\\d{2}/\\d{2}/\\d{4}$";

    private Long id;

    @NotBlank(message = "Tên mục tiêu không được để trống")
    @Size(max = TITLE_MAX_LENGTH, message = "Tên mục tiêu tối đa {max} ký tự")
    private String title;

    @NotNull(message = "Số tiền mục tiêu không được để trống")
    @Positive(message = "Số tiền mục tiêu phải lớn hơn 0")
    @Digits(integer = SavingContributionRequestDto.AMOUNT_INTEGER_DIGITS,
            fraction = SavingContributionRequestDto.AMOUNT_FRACTION_DIGITS,
            message = "Số tiền mục tiêu chỉ được có tối đa {integer} chữ số nguyên và {fraction} chữ số thập phân")
    private BigDecimal target;

    /** Chỉ đọc: số đã tiết kiệm đổi qua Góp tiền; client gửi lên thì chỉ được trùng giá trị đang lưu. */
    @PositiveOrZero(message = "Số tiền đã tiết kiệm không được âm")
    private BigDecimal current;

    @Pattern(regexp = DEADLINE_PATTERN, message = "Hạn mục tiêu phải có dạng dd/MM/yyyy")
    private String deadline;
}
