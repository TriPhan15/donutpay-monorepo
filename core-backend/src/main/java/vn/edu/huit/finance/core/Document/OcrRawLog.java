package vn.edu.huit.finance.core.Document;

import lombok.Data;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;

@Data
@Document(collection = "ocr_logs")
@CompoundIndex(name = "score_date_idx", def = "{'averageConfidenceScore': 1, 'createdAt': -1}")
public class OcrRawLog {
    
    @Id
    private String id;
    
    @Indexed(unique = true)
    private Long transactionId;
    
    private org.bson.Document rawJsonData;

    /** Phiên bản mô hình OCR đã đọc hóa đơn này (app.ocr.model-version lúc ghi). */
    private String modelVersion;

    /** Những gì AI đọc được, đã chuẩn hóa (cùng định dạng chuỗi với ocr_feedbacks); null khi không đọc được JSON. */
    private AiReading aiReading;
    
    @Indexed
    private Double averageConfidenceScore;
    
    @CreatedDate
    @Indexed
    private LocalDateTime createdAt;

    @Data
    public static class AiReading {
        private String sellerName;
        private String totalCost;
        private String receiptDate;
    }
}
