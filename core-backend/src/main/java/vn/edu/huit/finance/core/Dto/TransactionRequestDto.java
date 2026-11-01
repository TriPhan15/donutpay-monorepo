package vn.edu.huit.finance.core.Dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import lombok.Data;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Util.ImageUrls;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class TransactionRequestDto {

    // Cùng giới hạn với TransactionUpdateRequestDto: số tiền khớp cột (2 chữ số thập phân, nên ví không bị trừ theo số
    // chưa làm tròn), chữ khớp cột varchar(255), nên quá dài là 400 thay vì lỗi DB (409 sai nghĩa).
    private static final int AMOUNT_INTEGER_DIGITS = 17;
    private static final int AMOUNT_FRACTION_DIGITS = 2;
    private static final int TEXT_MAX_LENGTH = 255;

    @NotNull(message = "Số tiền không được để trống")
    @Positive(message = "Số tiền giao dịch phải lớn hơn 0")
    @Digits(integer = AMOUNT_INTEGER_DIGITS, fraction = AMOUNT_FRACTION_DIGITS,
            message = "Số tiền giao dịch chỉ được có tối đa {integer} chữ số nguyên và {fraction} chữ số thập phân")
    private BigDecimal amount;

    @Size(max = TEXT_MAX_LENGTH, message = "Ghi chú tối đa {max} ký tự")
    private String note;

    @NotBlank(message = "Địa chỉ giao dịch không được để trống")
    @Size(max = TEXT_MAX_LENGTH, message = "Địa chỉ giao dịch tối đa {max} ký tự")
    private String location;

    @NotBlank(message = "Vui lòng chọn nguồn tiền")
    @Size(max = TEXT_MAX_LENGTH, message = "Nguồn tiền tối đa {max} ký tự")
    private String paymentMethod;

    @NotNull(message = "Ngày giao dịch không được để trống")
    private LocalDateTime transactionDate;

    private Long categoryId;

    @Size(max = TEXT_MAX_LENGTH, message = "Tên danh mục tối đa {max} ký tự")
    private String categoryName;

    private Long receiptId;
    @JsonProperty("isExpense")
    private boolean isExpense;
    private Long campaignId;
    /** What the AI answered for the scanned receipt, as one JSON text; it is kept as the receipt's first attempt, never on the transaction. */
    @Size(max = Receipt.AI_RAW_DATA_MAX_LENGTH, message = "Dữ liệu AI của hóa đơn (rawReceiptData) tối đa {max} ký tự")
    private String rawReceiptData;
    /** Link ảnh hóa đơn (từ POST /api/upload). Chỉ nhận https://, vì trang admin hiện nó thành một link bấm được. */
    @Size(max = ImageUrls.MAX_LENGTH, message = "Link ảnh hóa đơn tối đa {max} ký tự")
    @Pattern(regexp = ImageUrls.HTTPS_OR_BLANK_REGEX, message = ImageUrls.MSG_INVALID)
    private String imageUrl;
    /** Ảnh phụ: tối đa {@link ImageUrls#MAX_ADDITIONAL_IMAGES} link, mỗi link theo cùng luật với {@code imageUrl}. */
    @Size(max = ImageUrls.MAX_ADDITIONAL_IMAGES, message = "Tối đa {max} ảnh phụ cho một giao dịch")
    private List<@NotBlank(message = ImageUrls.MSG_INVALID)
                 @Size(max = ImageUrls.MAX_LENGTH, message = "Link ảnh hóa đơn tối đa {max} ký tự")
                 @Pattern(regexp = ImageUrls.HTTPS_OR_BLANK_REGEX, message = ImageUrls.MSG_INVALID) String> additionalImages;

    /**
     * Optional idempotency key, made up by the client for one attempt to save (a UUID will do) and sent again unchanged
     * when that attempt is retried. A second request with a key the user has already used is answered with the first
     * transaction instead of creating another one. Blank counts as absent.
     */
    @Size(max = Transaction.CLIENT_ID_MAX_LENGTH,
            message = "Mã định danh yêu cầu (clientId) tối đa " + Transaction.CLIENT_ID_MAX_LENGTH + " ký tự")
    private String clientId;

    /**
     * Only read for a scanned receipt (rawReceiptData present). Null or false: the checkout is refused with a 409
     * (DuplicateReceiptException) when the caller already has a transaction of the same direction and amount, in the
     * same minute, at the same seller; true: saved anyway (the user confirmed it is another purchase). A manual
     * checkout is never checked.
     */
    private Boolean allowDuplicate;
}
