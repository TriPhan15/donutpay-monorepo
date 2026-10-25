package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Data;
import vn.edu.huit.finance.core.Document.OcrRawLog;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Một bản ghi OCR thô trong MongoDB (collection ocr_logs) như quản trị viên thấy (GET /api/admin/ocr-logs). Chứa câu trả
 * lời của AI: chỉ trả về từ endpoint dành riêng cho quản trị viên.
 */
@Data
@Builder
public class OcrRawLogResponseDto {
    private String id;
    private Long transactionId;
    /** JSON AI trả về, dạng Map thường (không phải org.bson.Document của tầng lưu trữ). */
    private Map<String, Object> rawJsonData;
    private Double averageConfidenceScore;
    private LocalDateTime createdAt;

    /** Ánh xạ duy nhất từ document MongoDB sang DTO. */
    public static OcrRawLogResponseDto from(OcrRawLog log) {
        return OcrRawLogResponseDto.builder()
                .id(log.getId())
                .transactionId(log.getTransactionId())
                .rawJsonData(log.getRawJsonData() == null ? null : new LinkedHashMap<>(log.getRawJsonData()))
                .averageConfidenceScore(log.getAverageConfidenceScore())
                .createdAt(log.getCreatedAt())
                .build();
    }
}
