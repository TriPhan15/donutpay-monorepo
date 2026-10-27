package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Data;
import vn.edu.huit.finance.core.Document.OcrFeedback;

import java.time.LocalDateTime;

/** Một phản hồi OCR (ocr_feedbacks) như quản trị viên thấy; không trả document MongoDB ra API. */
@Data
@Builder
public class OcrFeedbackResponseDto {
    private String id;
    private Long receiptId;
    private Long transactionId;
    private Long userId;
    /** Khóa của {@code OcrField}: seller_name, total_cost hoặc receipt_date. */
    private String field;
    private String aiValue;
    private String expectedValue;
    private String modelVersion;
    private boolean resolved;
    private LocalDateTime reportedAt;
    private LocalDateTime updatedAt;

    /** Ánh xạ duy nhất từ document MongoDB sang DTO. */
    public static OcrFeedbackResponseDto from(OcrFeedback feedback) {
        return OcrFeedbackResponseDto.builder()
                .id(feedback.getId())
                .receiptId(feedback.getReceiptId())
                .transactionId(feedback.getTransactionId())
                .userId(feedback.getUserId())
                .field(feedback.getFieldError())
                .aiValue(feedback.getAiValue())
                .expectedValue(feedback.getExpectedValue())
                .modelVersion(feedback.getModelVersion())
                .resolved(feedback.isResolved())
                .reportedAt(feedback.getReportedAt())
                .updatedAt(feedback.getUpdatedAt())
                .build();
    }
}
