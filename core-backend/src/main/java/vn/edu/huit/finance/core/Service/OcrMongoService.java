package vn.edu.huit.finance.core.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.aggregation.DateOperators;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.data.support.PageableExecutionUtils;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Dto.ExtractedReceiptDto;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.FieldCount;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.ModelCount;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.MonthlyConfidence;
import vn.edu.huit.finance.core.Dto.OcrCorrectionEvent;
import vn.edu.huit.finance.core.Dto.OcrFeedbackFilterRequestDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Dto.OcrFieldCorrection;
import vn.edu.huit.finance.core.Dto.OcrProcessedEvent;
import vn.edu.huit.finance.core.Dto.OcrRawLogResponseDto;
import vn.edu.huit.finance.core.Exception.OcrFeedbackNotFoundException;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class OcrMongoService {

    private static final String MSG_FEEDBACK_NOT_FOUND = "Không tìm thấy phản hồi OCR";
    private static final String FIELD_RECEIPT_ID = "receiptId";
    private static final String FIELD_ERROR = "fieldError";
    private static final String FIELD_RESOLVED = "isResolved";
    private static final String FIELD_REPORTED_AT = "reportedAt";
    private static final String FIELD_MODEL_VERSION = "modelVersion";
    private static final String FIELD_CREATED_AT = "createdAt";
    private static final String FIELD_CONFIDENCE = "averageConfidenceScore";
    private static final String UNKNOWN_MODEL = "unknown";
    private static final String MONTH_FORMAT = "%Y-%m";
    private static final String ALIAS_COUNT = "count";
    private static final String ALIAS_MONTH = "month";
    private static final String ALIAS_SCORE = "score";
    private static final String ALIAS_AVERAGE = "average";
    private static final String ALIAS_LOGS = "logs";
    private static final String GROUP_KEY = "_id";

    private final OcrRawLogRepository ocrRawLogRepository;
    private final OcrFeedbackRepository ocrFeedbackRepository;
    private final ObjectMapper objectMapper;
    private final OcrService ocrService;
    private final MongoTemplate mongoTemplate;

    @Value("${app.ocr.model-version}")
    private String modelVersion;

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
            logDoc.setModelVersion(modelVersion);
            logDoc.setAiReading(aiReadingOf(rawReceiptData));

            // createdAt is automatically handled by @CreatedDate
            ocrRawLogRepository.save(logDoc);
            log.info("Successfully persisted AI raw data to MongoDB Data Lake for Transaction: {}", transactionId);

        } catch (Exception e) {
            // Log the error but NEVER throw it back to the caller thread, ensuring Polyglot fallback safety
            log.error("CRITICAL: Failed to save OCR log to MongoDB for Transaction: {}. Error: {}", transactionId, e.getMessage(), e);
        }
    }

    /** Chuẩn hóa những gì AI đọc được từ câu trả lời thô, để so với phản hồi của người dùng mà không phải đọc lại JSON. */
    private OcrRawLog.AiReading aiReadingOf(String rawReceiptData) {
        ExtractedReceiptDto extracted = ocrService.extract(rawReceiptData);
        if (extracted == null) {
            return null;
        }
        OcrRawLog.AiReading reading = new OcrRawLog.AiReading();
        reading.setSellerName(extracted.getSeller());
        reading.setTotalCost(extracted.getTotalCost() == null ? null : extracted.getTotalCost().stripTrailingZeros().toPlainString());
        reading.setReceiptDate(extracted.getTimestamp() == null ? null : extracted.getTimestamp().toLocalDate().toString());
        return reading;
    }

    /**
     * Ghi các chỗ người dùng sửa AI sau khi PostgreSQL commit: mỗi (hóa đơn, trường) đúng một document, sửa lại lần nữa thì
     * cập nhật document đó (đặt lại chưa xử lý) và giữ nguyên reportedAt của lần báo đầu. Lỗi MongoDB chỉ được ghi log.
     */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOcrCorrectionEvent(OcrCorrectionEvent event) {
        try {
            for (OcrFieldCorrection correction : event.corrections()) {
                upsertCorrection(event, correction);
            }
            log.info("Persisted {} OCR correction(s) to MongoDB for Receipt: {}", event.corrections().size(), event.receiptId());
        } catch (Exception e) {
            // MongoDB là kho phân tích phụ: không ghi được thì chỉ log, không ảnh hưởng dữ liệu PostgreSQL đã commit.
            log.error("Failed to save OCR correction to MongoDB for Receipt: {}. Error: {}", event.receiptId(), e.getMessage(), e);
        }
    }

    private void upsertCorrection(OcrCorrectionEvent event, OcrFieldCorrection correction) {
        LocalDateTime now = LocalDateTime.now();
        Query key = new Query(Criteria.where(FIELD_RECEIPT_ID).is(event.receiptId())
                .and(FIELD_ERROR).is(correction.field().key()));
        Update update = new Update()
                .setOnInsert(FIELD_REPORTED_AT, now)
                .set("transactionId", event.transactionId())
                .set("userId", event.userId())
                .set("aiValue", correction.aiValue())
                .set("expectedValue", correction.expectedValue())
                .set(FIELD_MODEL_VERSION, modelVersion)
                .set(FIELD_RESOLVED, false)
                .set("updatedAt", now);
        mongoTemplate.upsert(key, update, OcrFeedback.class);
    }


    /** Một trang nhật ký OCR thô cho quản trị viên, đã ánh xạ sang DTO (không trả document MongoDB ra API). */
    public Page<OcrRawLogResponseDto> getOcrLogs(Pageable pageable) {
        return ocrRawLogRepository.findAll(pageable).map(OcrRawLogResponseDto::from);
    }

    /** Một trang phản hồi OCR theo bộ lọc; thứ tự do {@code pageable} quyết định. */
    public Page<OcrFeedbackResponseDto> findFeedbacks(OcrFeedbackFilterRequestDto filter, Pageable pageable) {
        Query query = new Query(feedbackCriteria(filter));
        long total = mongoTemplate.count(query, OcrFeedback.class);
        List<OcrFeedback> content = mongoTemplate.find(query.with(pageable), OcrFeedback.class);
        return PageableExecutionUtils.getPage(content.stream().map(OcrFeedbackResponseDto::from).toList(), pageable, () -> total);
    }

    private Criteria feedbackCriteria(OcrFeedbackFilterRequestDto filter) {
        Criteria criteria = new Criteria();
        if (filter.getField() != null) {
            criteria.and(FIELD_ERROR).is(filter.getField().key());
        }
        if (filter.getResolved() != null) {
            criteria.and(FIELD_RESOLVED).is(filter.getResolved());
        }
        return withinRange(criteria, FIELD_REPORTED_AT, filter.getFrom(), filter.getTo());
    }

    /** Giới hạn {@code field} trong [from, to], gồm cả ngày {@code to}; mốc null là không giới hạn phía đó. */
    private static Criteria withinRange(Criteria criteria, String field, LocalDate from, LocalDate to) {
        if (from != null && to != null) {
            return criteria.and(field).gte(from.atStartOfDay()).lt(to.plusDays(1).atStartOfDay());
        }
        if (from != null) {
            return criteria.and(field).gte(from.atStartOfDay());
        }
        if (to != null) {
            return criteria.and(field).lt(to.plusDays(1).atStartOfDay());
        }
        return criteria;
    }

    public OcrFeedbackResponseDto resolveFeedback(String feedbackId) {
        OcrFeedback feedback = ocrFeedbackRepository.findById(feedbackId).orElseThrow(() -> {
            log.warn("OCR feedback not found for resolve: {}", feedbackId);
            return new OcrFeedbackNotFoundException(MSG_FEEDBACK_NOT_FOUND);
        });
        feedback.setResolved(true);
        OcrFeedback saved = ocrFeedbackRepository.save(feedback);
        log.info("Resolved OCR feedback: {}", feedbackId);
        return OcrFeedbackResponseDto.from(saved);
    }

    public void deleteFeedback(String feedbackId) {
        if (!ocrFeedbackRepository.existsById(feedbackId)) {
            log.warn("OCR feedback not found for delete: {}", feedbackId);
            throw new OcrFeedbackNotFoundException(MSG_FEEDBACK_NOT_FOUND);
        }
        ocrFeedbackRepository.deleteById(feedbackId);
        log.info("Deleted OCR feedback: {}", feedbackId);
    }

    /** Thống kê OCR trong [from, to] (gồm cả hai ngày; null là không giới hạn): lỗi theo trường, theo mô hình, độ tin cậy theo tháng. */
    public OcrAnalyticsResponseDto analytics(LocalDate from, LocalDate to) {
        Criteria feedbackRange = withinRange(new Criteria(), FIELD_REPORTED_AT, from, to);
        Criteria logRange = withinRange(new Criteria(), FIELD_CREATED_AT, from, to);
        return OcrAnalyticsResponseDto.builder()
                .errorsByField(countFeedbacksBy(feedbackRange, FIELD_ERROR).stream()
                        .map(group -> new FieldCount(group.getString(GROUP_KEY), group.getInteger(ALIAS_COUNT))).toList())
                .errorsByModel(countFeedbacksBy(feedbackRange, FIELD_MODEL_VERSION).stream()
                        .map(group -> new ModelCount(group.getString(GROUP_KEY) == null ? UNKNOWN_MODEL : group.getString(GROUP_KEY),
                                group.getInteger(ALIAS_COUNT))).toList())
                .confidenceByMonth(confidenceByMonth(logRange))
                .receiptsWithErrorRate(receiptsWithErrorRate(feedbackRange, logRange))
                .build();
    }

    private List<org.bson.Document> countFeedbacksBy(Criteria range, String groupField) {
        Aggregation aggregation = Aggregation.newAggregation(
                Aggregation.match(range),
                Aggregation.group(groupField).count().as(ALIAS_COUNT),
                Aggregation.sort(Sort.by(Sort.Order.desc(ALIAS_COUNT), Sort.Order.asc(GROUP_KEY))));
        return mongoTemplate.aggregate(aggregation, OcrFeedback.class, org.bson.Document.class).getMappedResults();
    }

    private List<MonthlyConfidence> confidenceByMonth(Criteria logRange) {
        DateOperators.Timezone zone = DateOperators.Timezone.valueOf(ZoneId.systemDefault().getId());
        Aggregation aggregation = Aggregation.newAggregation(
                Aggregation.match(logRange),
                Aggregation.project().and(DateOperators.dateOf(FIELD_CREATED_AT).withTimezone(zone).toString(MONTH_FORMAT))
                        .as(ALIAS_MONTH).and(FIELD_CONFIDENCE).as(ALIAS_SCORE),
                Aggregation.group(ALIAS_MONTH).avg(ALIAS_SCORE).as(ALIAS_AVERAGE).count().as(ALIAS_LOGS),
                Aggregation.sort(Sort.by(Sort.Order.asc(GROUP_KEY))));
        return mongoTemplate.aggregate(aggregation, OcrRawLog.class, org.bson.Document.class).getMappedResults().stream()
                .map(group -> new MonthlyConfidence(group.getString(GROUP_KEY), group.getDouble(ALIAS_AVERAGE), group.getInteger(ALIAS_LOGS)))
                .toList();
    }

    /** Số hóa đơn có ít nhất một chỗ bị sửa chia cho số lần đọc (ocr_logs), cùng khoảng thời gian. */
    private double receiptsWithErrorRate(Criteria feedbackRange, Criteria logRange) {
        long readings = mongoTemplate.count(new Query(logRange), OcrRawLog.class);
        if (readings == 0) {
            return 0.0;
        }
        long receiptsWithError = mongoTemplate.findDistinct(new Query(feedbackRange), FIELD_RECEIPT_ID, OcrFeedback.class, Long.class).size();
        return (double) receiptsWithError / readings;
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
