package vn.edu.huit.finance.core.Dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/** A review of the app by the caller; the author always comes from the JWT, so the body carries no user id. */
@Data
public class ReviewRequestDto {
    @Min(value = 1, message = "Đánh giá thấp nhất là 1 sao")
    @Max(value = 5, message = "Đánh giá cao nhất là 5 sao")
    private int rating;

    private static final int COMMENT_MAX_LENGTH = 1000;

    @NotBlank(message = "Vui lòng nhập nội dung đánh giá")
    @Size(max = COMMENT_MAX_LENGTH, message = "Nội dung đánh giá tối đa {max} ký tự")
    private String comment;
}