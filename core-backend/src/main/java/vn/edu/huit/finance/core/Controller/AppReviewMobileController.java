package vn.edu.huit.finance.core.Controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.ReviewRequestDto;
import vn.edu.huit.finance.core.Service.AppReviewService;

/** Reviews of the app sent from the mobile app; the author is the caller of the request (JWT). */
@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class AppReviewMobileController {

    private static final String MSG_REVIEW_SUBMITTED = "Gửi đánh giá góp ý thành công!";

    private final AppReviewService appReviewService;

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> submitReview(@Valid @RequestBody ReviewRequestDto request) {
        appReviewService.submitMyReview(request);
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200)
                .message(MSG_REVIEW_SUBMITTED)
                .build());
    }
}
