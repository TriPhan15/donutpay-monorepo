package vn.edu.huit.finance.core.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import vn.edu.huit.finance.core.Dto.OcrProcessedEvent;
import vn.edu.huit.finance.core.Dto.OcrRawLogResponseDto;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class OcrMongoService {
    
    private final OcrRawLogRepository ocrRawLogRepository;
    private final OcrFeedbackRepository ocrFeedbackRepository;
    private final ObjectMapper objectMapper;

    /**
     * Executes asynchronously in the background using the dedicated MongoAsyncExecutor pool.
     * Prevents the core business transaction (PostgreSQL) from blocking on MongoDB IO or JSON parsing.
     */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOcrProcessedEvent(OcrProcessedEvent event) {
        Long transactionId = event.transactionId();
        String rawReceiptData = event.rawReceiptData();
        if (rawReceiptData == null || rawReceiptData.isBlank()) {
            return;
        }
        
        try {
            OcrRawLog logDoc = new OcrRawLog();
            logDoc.setTransactionId(transactionId);
            
            try {
                logDoc.setRawJsonData(org.bson.Document.parse(rawReceiptData));
            } catch (Exception parseException) {
                // Nếu chuỗi không phải JSON chuẩn, bọc nó vào một field tạm để không mất dữ liệu
                logDoc.setRawJsonData(new org.bson.Document("unparsed_raw_string", rawReceiptData));
            }

            
            // Dynamically parse confidence score from raw AI JSON payload without blocking the main thread
            Double confidenceScore = extractConfidenceScore(rawReceiptData);
            logDoc.setAverageConfidenceScore(confidenceScore);
            
            // createdAt is automatically handled by @CreatedDate
            ocrRawLogRepository.save(logDoc);
            log.info("Successfully persisted AI raw data to MongoDB Data Lake for Transaction: {}", transactionId);
            
        } catch (Exception e) {
            // Log the error but NEVER throw it back to the caller thread, ensuring Polyglot fallback safety
            log.error("CRITICAL: Failed to save OCR log to MongoDB for Transaction: {}. Error: {}", transactionId, e.getMessage(), e);
        }
    }


    /** Một trang nhật ký OCR thô cho quản trị viên, đã ánh xạ sang DTO (không trả document MongoDB ra API). */
    public Page<OcrRawLogResponseDto> getOcrLogs(Pageable pageable) {
        return ocrRawLogRepository.findAll(pageable).map(OcrRawLogResponseDto::from);
    }

    public boolean resolveFeedback(String feedbackId) {
        Optional<OcrFeedback> optionalFeedback = ocrFeedbackRepository.findById(feedbackId);
        if (optionalFeedback.isPresent()) {
            OcrFeedback feedback = optionalFeedback.get();
            feedback.setResolved(true);
            ocrFeedbackRepository.save(feedback);
            log.info("Resolved OCR feedback: {}", feedbackId);
            return true;
        }
        return false;
    }

    private Double extractConfidenceScore(String json) {
        try {
            JsonNode root = objectMapper.readTree(json);
            // Attempt to find common confidence score fields in DONUT's output. 
            // Adjust the json path depending on the exact DONUT output format.
            if (root.has("confidence_score")) return root.get("confidence_score").asDouble();
            if (root.has("score")) return root.get("score").asDouble();
            if (root.has("confidence")) return root.get("confidence").asDouble();
            return 1.0; // Default if not found
        } catch (Exception e) {
            log.warn("Failed to parse JSON for confidence score, defaulting to 1.0", e);
            return 1.0;
        }
    }
}
