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
public class OcrFeedback {
    
    @Id
    private String id;
    
    @Indexed
    private Long receiptId;
    
    @Indexed
    private Long userId;
    
    private String fieldError;
    private String expectedValue;
    private String aiValue;
    
    @Indexed
    private boolean isResolved;
    
    @CreatedDate
    @Indexed
    private LocalDateTime reportedAt;
}
