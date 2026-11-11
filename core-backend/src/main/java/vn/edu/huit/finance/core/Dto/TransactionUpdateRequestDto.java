package vn.edu.huit.finance.core.Dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Body of PUT /api/transactions/{id}. A field that is left out keeps its current value. There is deliberately no user,
 * status or voucher field: the owner is always the caller, and those values cannot be changed through this request.
 */
@Getter
@Setter
public class TransactionUpdateRequestDto {

    private static final int AMOUNT_INTEGER_DIGITS = 17;
    private static final int AMOUNT_FRACTION_DIGITS = 2;
    private static final int TEXT_MAX_LENGTH = 255;
    private static final String NOT_BLANK_REGEX = ".*\\S.*";

    @Positive(message = "Số tiền giao dịch phải lớn hơn 0")
    @Digits(integer = AMOUNT_INTEGER_DIGITS, fraction = AMOUNT_FRACTION_DIGITS,
            message = "Số tiền giao dịch chỉ được có tối đa {integer} chữ số nguyên và {fraction} chữ số thập phân")
    private BigDecimal amount;

    /** With {@link #categoryName}, the id wins; a name that does not exist yet creates the category, as at checkout. */
    @Positive(message = "Mã danh mục không hợp lệ")
    private Long categoryId;

    @Size(max = TEXT_MAX_LENGTH, message = "Tên danh mục tối đa {max} ký tự")
    private String categoryName;

    /** A blank note clears the note. */
    @Size(max = TEXT_MAX_LENGTH, message = "Ghi chú tối đa {max} ký tự")
    private String note;

    private LocalDateTime transactionDate;

    @Size(max = TEXT_MAX_LENGTH, message = "Nguồn tiền tối đa {max} ký tự")
    @Pattern(regexp = NOT_BLANK_REGEX, message = "Nguồn tiền không được để trống")
    private String paymentMethod;

    /** True for an expense, false for an income. Changing it undoes the effect of the old type on the wallet and applies the new one. */
    @JsonProperty("isExpense")
    private Boolean expense;

    /** Optional new experience rating (0.5 to 5.0 stars in 0.5 increments). Null leaves the current rating unchanged unless {@link #clearRating} is true. */
    @DecimalMin(value = "0.5", message = "Điểm đánh giá trải nghiệm phải từ 0.5 đến 5.0 sao")
    @DecimalMax(value = "5.0", message = "Điểm đánh giá trải nghiệm phải từ 0.5 đến 5.0 sao")
    private BigDecimal rating;

    /** True clears any existing rating back to null. */
    private Boolean clearRating;

    /** Optional personal review note about the experience. A blank string clears the existing review note. */
    @Size(max = TEXT_MAX_LENGTH, message = "Ghi chú đánh giá tối đa {max} ký tự")
    private String reviewNote;

    /** Optional new address. Null leaves it unchanged; a blank string resets it to the default "Trong ứng dụng" (create requires a non-blank location). */
    @Size(max = TEXT_MAX_LENGTH, message = "Địa chỉ giao dịch tối đa {max} ký tự")
    private String location;

    @JsonIgnore
    @AssertTrue(message = "Điểm đánh giá trải nghiệm phải cách nhau 0.5 sao")
    public boolean isRatingStepValid() {
        return rating == null || rating.multiply(BigDecimal.valueOf(2)).stripTrailingZeros().scale() <= 0;
    }
}
