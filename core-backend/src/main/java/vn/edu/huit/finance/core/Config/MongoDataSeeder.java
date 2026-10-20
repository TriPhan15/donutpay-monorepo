package vn.edu.huit.finance.core.Config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.bson.Document;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;
import vn.edu.huit.finance.core.Service.DemoData.ReceiptScenario;
import vn.edu.huit.finance.core.Service.DemoData.SeededReceipt;

import java.util.List;
import java.util.Optional;

/**
 * Log OCR demo trên MongoDB, cùng cờ {@code app.seed.demo} với DataSeeder, gọi sau khi PostgreSQL đã commit: mỗi hóa đơn
 * vừa seed có một log thô (đúng câu trả lời AI đã lưu ở lần đọc đầu tiên), hóa đơn được sửa hoặc chờ duyệt có thêm một
 * phản hồi. Collection đã có dữ liệu thì bỏ qua.
 */
@Component
@ConditionalOnProperty(name = DemoSeedProperties.ENABLED_PROPERTY, havingValue = "true")
@RequiredArgsConstructor
@Slf4j
public class MongoDataSeeder {

    private static final double CONFIDENCE_TOTAL_READ = 0.94;
    private static final double CONFIDENCE_TOTAL_MISSING = 0.41;
    private static final String FIELD_SELLER_NAME = "seller_name";
    private static final String FIELD_TOTAL_COST = "total_cost";
    private static final String NOT_READ = "";
    private static final long FEEDBACK_DELAY_MINUTES = 5;

    private final OcrRawLogRepository ocrRawLogRepository;
    private final OcrFeedbackRepository ocrFeedbackRepository;

    public void seed(List<SeededReceipt> receipts) {
        if (receipts.isEmpty()) {
            log.info("MongoDataSeeder: no receipt was seeded in PostgreSQL, nothing to log");
            return;
        }
        try {
            seedOcrRawLogs(receipts);
            seedOcrFeedbacks(receipts);
        } catch (DataAccessException e) {
            // MongoDB chỉ là kho log phụ: không seed được thì vẫn khởi động app (PostgreSQL là nguồn dữ liệu chính).
            log.error("MongoDataSeeder skipped, MongoDB is unreachable: {}", e.getMessage());
        }
    }

    private void seedOcrRawLogs(List<SeededReceipt> receipts) {
        if (ocrRawLogRepository.count() > 0) {
            log.info("MongoDataSeeder: ocr_logs already has documents, skipped");
            return;
        }
        List<OcrRawLog> logs = receipts.stream().map(MongoDataSeeder::rawLogOf).toList();
        ocrRawLogRepository.saveAll(logs);
        log.info("MongoDataSeeder: seeded {} OcrRawLog documents", logs.size());
    }

    private void seedOcrFeedbacks(List<SeededReceipt> receipts) {
        if (ocrFeedbackRepository.count() > 0) {
            log.info("MongoDataSeeder: ocr_feedbacks already has documents, skipped");
            return;
        }
        List<OcrFeedback> feedbacks = receipts.stream().map(MongoDataSeeder::feedbackOf).flatMap(Optional::stream).toList();
        ocrFeedbackRepository.saveAll(feedbacks);
        log.info("MongoDataSeeder: seeded {} OcrFeedback documents", feedbacks.size());
    }

    private static OcrRawLog rawLogOf(SeededReceipt receipt) {
        OcrRawLog rawLog = new OcrRawLog();
        rawLog.setTransactionId(receipt.transactionId());
        rawLog.setRawJsonData(Document.parse(receipt.aiRawData()));
        rawLog.setAverageConfidenceScore(receipt.scenario().totalRead() ? CONFIDENCE_TOTAL_READ : CONFIDENCE_TOTAL_MISSING);
        rawLog.setCreatedAt(receipt.scannedAt());
        return rawLog;
    }

    /** Người dùng sửa tên cửa hàng (đã xử lý) hoặc tự nhập tổng tiền AI không đọc được (chờ duyệt). */
    private static Optional<OcrFeedback> feedbackOf(SeededReceipt receipt) {
        ReceiptScenario scenario = receipt.scenario();
        if (scenario != ReceiptScenario.CORRECTED && scenario != ReceiptScenario.AWAITING_REVIEW) {
            return Optional.empty();
        }
        boolean corrected = scenario == ReceiptScenario.CORRECTED;
        OcrFeedback feedback = new OcrFeedback();
        feedback.setReceiptId(receipt.receiptId());
        feedback.setUserId(receipt.userId());
        feedback.setFieldError(corrected ? FIELD_SELLER_NAME : FIELD_TOTAL_COST);
        feedback.setAiValue(corrected ? receipt.readSeller() : NOT_READ);
        feedback.setExpectedValue(corrected ? receipt.seller() : receipt.amount().toPlainString());
        feedback.setResolved(corrected);
        feedback.setReportedAt(receipt.scannedAt().plusMinutes(FEEDBACK_DELAY_MINUTES));
        return Optional.of(feedback);
    }
}
