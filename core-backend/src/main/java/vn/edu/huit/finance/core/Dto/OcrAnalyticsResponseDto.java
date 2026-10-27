package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Value;

import java.util.List;

/** Thống kê chất lượng OCR từ MongoDB: AI sai ở trường nào, ở phiên bản mô hình nào, độ tin cậy theo tháng. */
@Value
@Builder
public class OcrAnalyticsResponseDto {
    List<FieldCount> errorsByField;
    List<ModelCount> errorsByModel;
    List<MonthlyConfidence> confidenceByMonth;
    /** Số hóa đơn có ít nhất một chỗ bị sửa chia cho số lần đọc (ocr_logs) trong khoảng thời gian; 0 khi chưa có lần đọc nào. */
    double receiptsWithErrorRate;

    @Value
    public static class FieldCount {
        String field;
        long count;
    }

    @Value
    public static class ModelCount {
        String modelVersion;
        long count;
    }

    @Value
    public static class MonthlyConfidence {
        /** Tháng dạng yyyy-MM. */
        String month;
        double averageConfidence;
        long logs;
    }
}
