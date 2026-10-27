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
    /**
     * Trong các lần đọc (ocr_logs) tạo trong khoảng thời gian, tỉ lệ lần đọc có giao dịch bị sửa ít nhất một chỗ (dù chỗ
     * sửa được báo lúc nào); luôn trong [0, 1], 0 khi chưa có lần đọc nào.
     */
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
        /** Trung bình của các lần đọc có độ tin cậy; null khi không lần đọc nào của tháng có (mô hình không trả về). */
        Double averageConfidence;
        long logs;
    }
}
