package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

/**
 * The query parameters of GET /api/transactions/search. There is deliberately no user field: the search always runs for
 * the caller. A page or size left out keeps its default.
 */
@Getter
@Setter
public class TransactionSearchRequestDto {

    public static final int FIRST_PAGE = 0;
    public static final int DEFAULT_SIZE = 20;
    public static final int MIN_QUERY_LENGTH = 2;
    public static final int MAX_QUERY_LENGTH = 100;
    public static final int MIN_SIZE = 1;
    public static final int MAX_SIZE = 50;
    /** Elasticsearch refuses to page past index.max_result_window. */
    public static final int MAX_RESULT_WINDOW = 10_000;
    /** The last page that stays inside the window at the largest size: (199 + 1) * 50 = 10 000. */
    public static final int MAX_PAGE = MAX_RESULT_WINDOW / MAX_SIZE - 1;

    @NotBlank(message = "Từ khóa tìm kiếm không được để trống")
    @Size(min = MIN_QUERY_LENGTH, max = MAX_QUERY_LENGTH, message = "Từ khóa tìm kiếm phải từ 2 đến 100 ký tự")
    private String q;

    @Min(value = FIRST_PAGE, message = "Số trang phải lớn hơn hoặc bằng 0")
    @Max(value = MAX_PAGE, message = "Số trang không được vượt quá 199")
    private int page = FIRST_PAGE;

    @Min(value = MIN_SIZE, message = "Số kết quả mỗi trang phải từ 1 đến 50")
    @Max(value = MAX_SIZE, message = "Số kết quả mỗi trang phải từ 1 đến 50")
    private int size = DEFAULT_SIZE;

    /** Surrounding blanks are not part of the text, so the length rule applies to the trimmed text. */
    public void setQ(String q) {
        this.q = q == null ? null : q.strip();
    }
}
