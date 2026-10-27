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
import org.springframework.data.mongodb.core.aggregation.ArrayOperators;
import org.springframework.data.mongodb.core.aggregation.ComparisonOperators;
import org.springframework.data.mongodb.core.aggregation.ConditionalOperators;
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
import vn.edu.huit.finance.core.Document.OcrField;
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
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;

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
    private static final String FIELD_TRANSACTION_ID = "transactionId";
    private static final String FIELD_USER_ID = "userId";
    private static final String FIELD_AI_VALUE = "aiValue";
    private static final String FIELD_EXPECTED_VALUE = "expectedValue";
    private static final String FIELD_UPDATED_AT = "updatedAt";
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
    private static final String ALIAS_FEEDBACKS = "feedbacks";
    private static final String ALIAS_HAS_FEEDBACK = "hasFeedback";
    private static final String ALIAS_READINGS = "readings";
    private static final String ALIAS_WITH_ERROR = "withError";

    private final OcrRawLogRepository ocrRawLogRepository;
    private final OcrFeedbackRepository ocrFeedbackRepository;
    private final ObjectMapper objectMapper;
    private final OcrService ocrService;
    private final MongoTemplate mongoTemplate;
    private final AdminEventPublisher adminEventPublisher;

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
     * Ghi các chỗ người dùng sửa AI sau khi PostgreSQL commit: mỗi (hóa đơn, trường) đúng một document. Sửa lại thành một
     * giá trị khác thì cập nhật document đó (đặt lại chưa xử lý) và giữ nguyên reportedAt của lần báo đầu; gửi lại đúng
     * chỗ sửa đã lưu (một lần sửa hóa đơn ở trường khác) thì không đổi gì, phản hồi đã xử lý vẫn là đã xử lý. Trường nào
     * người dùng đã trả về đúng giá trị AI thì chỗ sửa cũ của nó bị xóa. Lỗi MongoDB chỉ được ghi log. Khi có chỗ sửa mới
     * hoặc đổi giá trị, trang quản trị được báo (OCR_FEEDBACK_REPORTED qua Redis Pub/Sub); gửi lại y nguyên thì không.
     */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOcrCorrectionEvent(OcrCorrectionEvent event) {
        try {
            int written = 0;
            for (OcrFieldCorrection correction : event.corrections()) {
                if (upsertCorrection(event, correction)) {
                    written++;
                }
            }
            long removed = removeCleared(event);
            log.info("Persisted {} OCR correction(s) and removed {} stale one(s) in MongoDB for Receipt: {}",
                    event.corrections().size(), removed, event.receiptId());
            if (written > 0) {
                adminEventPublisher.publish(AdminEvent.ocrFeedbackReported(event.receiptId(), written));
            }
        } catch (Exception e) {
            // MongoDB là kho phân tích phụ: không ghi được thì chỉ log, không ảnh hưởng dữ liệu PostgreSQL đã commit.
            log.error("Failed to save OCR correction to MongoDB for Receipt: {}. Error: {}", event.receiptId(), e.getMessage(), e);
        }
    }

    /**
     * Hai bước: (1) document của (hóa đơn, trường) có giá trị khác thì được ghi đè và mở lại; (2) không có document nào
     * thì tạo mới ({@code $setOnInsert}: không đụng tới document đã có cùng giá trị). Hai luồng cùng tạo một document thì
     * khóa duy nhất receipt_field_uq chặn luồng sau (lỗi đó chỉ được ghi log). True khi đã ghi đè hoặc tạo mới một document.
     */
    private boolean upsertCorrection(OcrCorrectionEvent event, OcrFieldCorrection correction) {
        LocalDateTime now = LocalDateTime.now();
        Criteria key = Criteria.where(FIELD_RECEIPT_ID).is(event.receiptId()).and(FIELD_ERROR).is(correction.field().key());
        Criteria changed = new Criteria().andOperator(key, new Criteria().orOperator(
                Criteria.where(FIELD_EXPECTED_VALUE).ne(correction.expectedValue()),
                Criteria.where(FIELD_AI_VALUE).ne(correction.aiValue())));
        Update reopen = new Update()
                .set(FIELD_TRANSACTION_ID, event.transactionId())
                .set(FIELD_USER_ID, event.userId())
                .set(FIELD_AI_VALUE, correction.aiValue())
                .set(FIELD_EXPECTED_VALUE, correction.expectedValue())
                .set(FIELD_MODEL_VERSION, modelVersion)
                .set(FIELD_RESOLVED, false)
                .set(FIELD_UPDATED_AT, now);
        if (mongoTemplate.updateFirst(new Query(changed), reopen, OcrFeedback.class).getMatchedCount() > 0) {
            return true;
        }
        Update insertIfAbsent = new Update()
                .setOnInsert(FIELD_REPORTED_AT, now)
                .setOnInsert(FIELD_TRANSACTION_ID, event.transactionId())
                .setOnInsert(FIELD_USER_ID, event.userId())
                .setOnInsert(FIELD_AI_VALUE, correction.aiValue())
                .setOnInsert(FIELD_EXPECTED_VALUE, correction.expectedValue())
                .setOnInsert(FIELD_MODEL_VERSION, modelVersion)
                .setOnInsert(FIELD_RESOLVED, false)
                .setOnInsert(FIELD_UPDATED_AT, now);
        return mongoTemplate.upsert(new Query(key), insertIfAbsent, OcrFeedback.class).getUpsertedId() != null;
    }

    /** Xóa chỗ sửa của các trường người dùng đã trả về đúng giá trị AI; số document đã xóa. */
    private long removeCleared(OcrCorrectionEvent event) {
        if (event.clearedFields().isEmpty()) {
            return 0;
        }
        List<String> fields = event.clearedFields().stream().map(OcrField::key).toList();
        Query stale = new Query(Criteria.where(FIELD_RECEIPT_ID).is(event.receiptId()).and(FIELD_ERROR).in(fields));
        return mongoTemplate.remove(stale, OcrFeedback.class).getDeletedCount();
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
                .receiptsWithErrorRate(receiptsWithErrorRate(logRange))
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

    /**
     * Trong các lần đọc (ocr_logs) tạo trong khoảng thời gian, tỉ lệ lần đọc có giao dịch bị sửa ít nhất một chỗ
     * (ocr_feedbacks cùng transactionId, báo lúc nào cũng được). Tử số là một phần của mẫu số nên tỉ lệ không vượt 1.
     * Một aggregation: $match theo createdAt, $lookup sang ocr_feedbacks theo transactionId (có index), rồi đếm.
     */
    private double receiptsWithErrorRate(Criteria logRange) {
        Aggregation aggregation = Aggregation.newAggregation(
                Aggregation.match(logRange),
                Aggregation.lookup(mongoTemplate.getCollectionName(OcrFeedback.class), FIELD_TRANSACTION_ID,
                        FIELD_TRANSACTION_ID, ALIAS_FEEDBACKS),
                Aggregation.project().and(ComparisonOperators.Gt.valueOf(ArrayOperators.Size.lengthOfArray(ALIAS_FEEDBACKS))
                        .greaterThanValue(0)).as(ALIAS_HAS_FEEDBACK),
                Aggregation.group().count().as(ALIAS_READINGS)
                        .sum(ConditionalOperators.when(Criteria.where(ALIAS_HAS_FEEDBACK).is(true)).then(1).otherwise(0))
                        .as(ALIAS_WITH_ERROR));
        org.bson.Document totals = mongoTemplate.aggregate(aggregation, OcrRawLog.class, org.bson.Document.class)
                .getUniqueMappedResult();
        if (totals == null || totals.getInteger(ALIAS_READINGS, 0) == 0) {
            return 0.0;
        }
        return (double) totals.getInteger(ALIAS_WITH_ERROR, 0) / totals.getInteger(ALIAS_READINGS);
    }

    private Double extractConfidenceScore(String json) {
        try {
            JsonNode root = objectMapper.readTree(json);
            // Attempt to find common confidence score fields in DONUT's output.
            // Adjust the json path depending on the exact DONUT output format.
            if (root.has("confidence_score")) return root.get("confidence_score").asDouble();
            if (root.has("score")) return root.get("score").asDouble();
            if (root.has("confidence")) return root.get("confidence").asDouble();
            // Không có (Donut V5 không trả về độ tin cậy): null, không bịa một con số; $avg của thống kê bỏ qua null.
            return null;
        } catch (Exception e) {
            log.warn("Failed to parse JSON for confidence score, leaving it empty", e);
            return null;
        }
    }
}
