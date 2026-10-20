package vn.edu.huit.finance.core.Config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.bson.Document;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;

import java.time.LocalDateTime;
import java.util.List;

@Component
@ConditionalOnProperty(name = "app.seeder.enabled", havingValue = "true")
@RequiredArgsConstructor
@Slf4j
public class MongoDataSeeder implements CommandLineRunner {

    private final OcrRawLogRepository ocrRawLogRepository;
    private final OcrFeedbackRepository ocrFeedbackRepository;

    @Override
    public void run(String... args) {
        log.info("MongoDataSeeder is enabled. Checking if database is empty...");

        try {
            seedOcrRawLogs();
            seedOcrFeedbacks();
        } catch (DataAccessException e) {
            // MongoDB chỉ là kho log phụ: không seed được thì vẫn khởi động app (PostgreSQL là nguồn dữ liệu chính).
            log.error("MongoDataSeeder skipped, MongoDB is unreachable: {}", e.getMessage());
        }
    }

    private void seedOcrRawLogs() {
        if (ocrRawLogRepository.count() == 0) {
            log.info("Seeding OcrRawLog collections...");

            String sampleJson1 = """
                {
                    "vendor_name": "Highlands Coffee",
                    "total_amount": 85000,
                    "date": "2026-10-08",
                    "confidence_score": 0.95,
                    "line_items": [
                        {"name": "Phin Sua Da", "price": 35000},
                        {"name": "Tra Sen Vang", "price": 50000}
                    ]
                }
                """;

            String sampleJson2 = """
                {
                    "vendor_name": "Phuc Long",
                    "total_amount": 110000,
                    "date": "2026-10-07",
                    "confidence_score": 0.45,
                    "line_items": [
                        {"name": "Tra Dao Cam Sa", "price": 55000},
                        {"name": "Tra Vai", "price": 55000}
                    ]
                }
                """;

            OcrRawLog log1 = new OcrRawLog();
            log1.setTransactionId(101L);
            log1.setAverageConfidenceScore(0.95);
            log1.setRawJsonData(Document.parse(sampleJson1));

            OcrRawLog log2 = new OcrRawLog();
            log2.setTransactionId(102L);
            log2.setAverageConfidenceScore(0.45);
            log2.setRawJsonData(Document.parse(sampleJson2));

            ocrRawLogRepository.saveAll(List.of(log1, log2));
            log.info("Successfully seeded 2 OcrRawLog documents.");
        }
    }

    private void seedOcrFeedbacks() {
        if (ocrFeedbackRepository.count() == 0) {
            log.info("Seeding OcrFeedback collections...");

            OcrFeedback feedback1 = new OcrFeedback();
            feedback1.setReceiptId(201L);
            feedback1.setUserId(1L);
            feedback1.setFieldError("total_amount");
            feedback1.setExpectedValue("120000");
            feedback1.setAiValue("12000");
            feedback1.setResolved(false);
            feedback1.setReportedAt(LocalDateTime.now().minusDays(1));

            OcrFeedback feedback2 = new OcrFeedback();
            feedback2.setReceiptId(202L);
            feedback2.setUserId(2L);
            feedback2.setFieldError("total_amount");
            feedback2.setExpectedValue("50000");
            feedback2.setAiValue("5000");
            feedback2.setResolved(true);
            feedback2.setReportedAt(LocalDateTime.now().minusDays(2));
            
            OcrFeedback feedback3 = new OcrFeedback();
            feedback3.setReceiptId(203L);
            feedback3.setUserId(1L);
            feedback3.setFieldError("vendor_name");
            feedback3.setExpectedValue("KFC");
            feedback3.setAiValue("KEC");
            feedback3.setResolved(false);
            feedback3.setReportedAt(LocalDateTime.now());

            ocrFeedbackRepository.saveAll(List.of(feedback1, feedback2, feedback3));
            log.info("Successfully seeded 3 OcrFeedback documents.");
        }
    }
}
