package vn.edu.huit.finance.core.Document;

import lombok.Data;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;

@Data
@Document(collection = "ocr_feedbacks")
@CompoundIndex(name = "status_date_idx", def = "{'isResolved': 1, 'reportedAt': -1}")
@CompoundIndex(name = "receipt_field_uq", def = "{'receiptId': 1, 'fieldError': 1}", unique = true)
public class OcrFeedback {
    
    @Id
    private String id;
    
    @Indexed
    private Long receiptId;
    
    /** Có index: thống kê receiptsWithErrorRate nối ocr_logs sang đây theo transactionId ($lookup). */
    @Indexed
    private Long transactionId;

    @Indexed
    private Long userId;
    
    private String fieldError;
    private String expectedValue;
    private String aiValue;

    /** Phiên bản mô hình OCR đã đọc hóa đơn này (app.ocr.model-version lúc ghi). */
    private String modelVersion;
    
    @Indexed
    private boolean isResolved;
    
    @CreatedDate
    @Indexed
    private LocalDateTime reportedAt;

    /** Lần cuối người dùng sửa lại trường này (reportedAt giữ nguyên lần báo đầu tiên). */
    private LocalDateTime updatedAt;
}
