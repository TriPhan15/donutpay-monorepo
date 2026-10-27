package vn.edu.huit.finance.core.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.SimpleMongoClientDatabaseFactory;
import org.springframework.data.mongodb.core.index.MongoPersistentEntityIndexResolver;
import org.springframework.data.mongodb.core.mapping.MongoMappingContext;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.repository.support.MongoRepositoryFactory;
import org.springframework.data.util.TypeInformation;
import org.springframework.test.util.ReflectionTestUtils;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto;
import vn.edu.huit.finance.core.Dto.OcrCorrectionEvent;
import vn.edu.huit.finance.core.Dto.OcrFeedbackFilterRequestDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Dto.OcrFieldCorrection;
import vn.edu.huit.finance.core.Dto.OcrProcessedEvent;
import vn.edu.huit.finance.core.Exception.OcrFeedbackNotFoundException;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * OcrMongoService on a real MongoDB 6 (Testcontainers): upsert on a unique key, the Criteria filter and the aggregation
 * pipelines only run on a real server. Skipped when Docker is not there.
 */
@Testcontainers(disabledWithoutDocker = true)
class OcrMongoServiceMongoIntegrationTest {

    @Container
    private static final GenericContainer<?> MONGO = new GenericContainer<>("mongo:6.0").withExposedPorts(27017);

    private static final String MODEL = "donut-test";
    private static final String FULL_SCAN = "{\"seller\": {\"seller_name\": \"Bách Hóa Xanh\", \"address\": \"12 Nguyễn Trãi\","
            + " \"timestamp\": \"27/05/2026 10:30\", \"total_cost\": \"245.000\", \"total_cost_number\": 245000}}";

    private static MongoTemplate template;
    private static OcrFeedbackRepository feedbackRepository;
    private static OcrRawLogRepository rawLogRepository;
    private static OcrMongoService service;

    @BeforeAll
    static void connect() {
        template = new MongoTemplate(new SimpleMongoClientDatabaseFactory(
                "mongodb://" + MONGO.getHost() + ":" + MONGO.getMappedPort(27017) + "/ocr_it"));
        MongoRepositoryFactory factory = new MongoRepositoryFactory(template);
        feedbackRepository = factory.getRepository(OcrFeedbackRepository.class);
        rawLogRepository = factory.getRepository(OcrRawLogRepository.class);
        service = new OcrMongoService(rawLogRepository, feedbackRepository, new ObjectMapper(), new OcrService(), template);
        ReflectionTestUtils.setField(service, "modelVersion", MODEL);
        // Spring Boot creates indexes only when asked to: the IT creates the ones the documents declare, unique key included.
        MongoMappingContext context = (MongoMappingContext) template.getConverter().getMappingContext();
        new MongoPersistentEntityIndexResolver(context).resolveIndexFor(TypeInformation.of(OcrFeedback.class))
                .forEach(holder -> template.indexOps(OcrFeedback.class).ensureIndex(holder.getIndexDefinition()));
    }

    @BeforeEach
    void emptyCollections() {
        template.remove(new Query(), OcrFeedback.class);
        template.remove(new Query(), OcrRawLog.class);
    }

    private static OcrCorrectionEvent total(long receiptId, String ai, String expected) {
        return new OcrCorrectionEvent(receiptId, receiptId * 10, 5L,
                List.of(new OcrFieldCorrection(OcrField.TOTAL_COST, ai, expected)));
    }

    private static OcrFeedback feedback(long receiptId, OcrField field, boolean resolved, String model, LocalDateTime reportedAt) {
        OcrFeedback feedback = new OcrFeedback();
        feedback.setReceiptId(receiptId);
        feedback.setTransactionId(10 + receiptId);
        feedback.setUserId(5L);
        feedback.setFieldError(field.key());
        feedback.setResolved(resolved);
        feedback.setModelVersion(model);
        feedback.setReportedAt(reportedAt);
        return feedback;
    }

    private static OcrRawLog rawLog(long transactionId, Double confidence, LocalDateTime createdAt) {
        OcrRawLog rawLog = new OcrRawLog();
        rawLog.setTransactionId(transactionId);
        rawLog.setAverageConfidenceScore(confidence);
        rawLog.setCreatedAt(createdAt);
        return rawLog;
    }

    @Test
    void correction_upsertsOneDocPerReceiptField() throws InterruptedException {
        service.onOcrCorrectionEvent(total(1, "120000", "150000"));
        OcrFeedback first = feedbackRepository.findAll().get(0);
        service.resolveFeedback(first.getId());
        Thread.sleep(20);

        service.onOcrCorrectionEvent(total(1, "120000", "160000"));

        List<OcrFeedback> all = feedbackRepository.findAll();
        assertEquals(1, all.size());
        OcrFeedback doc = all.get(0);
        assertEquals("160000", doc.getExpectedValue());
        assertEquals("120000", doc.getAiValue());
        assertEquals("total_cost", doc.getFieldError());
        assertEquals(MODEL, doc.getModelVersion());
        assertEquals(10L, doc.getTransactionId());
        assertFalse(doc.isResolved(), "a new correction needs a new look");
        assertEquals(first.getReportedAt(), doc.getReportedAt(), "reportedAt stays the day of the first report");
        assertTrue(doc.getUpdatedAt().isAfter(doc.getReportedAt()));
    }

    @Test
    void correction_differentFieldsOfOneReceipt_giveOneDocEach() {
        service.onOcrCorrectionEvent(new OcrCorrectionEvent(1L, 10L, 5L, List.of(
                new OcrFieldCorrection(OcrField.SELLER_NAME, null, "A"),
                new OcrFieldCorrection(OcrField.TOTAL_COST, "1", "2"))));

        assertEquals(2, feedbackRepository.count());
    }

    @Test
    void rawLog_storesModelVersionAndAiReading() {
        service.onOcrProcessedEvent(new OcrProcessedEvent(77L, FULL_SCAN));

        OcrRawLog saved = rawLogRepository.findAll().get(0);
        assertEquals(MODEL, saved.getModelVersion());
        assertEquals("Bách Hóa Xanh", saved.getAiReading().getSellerName());
        assertEquals("245000", saved.getAiReading().getTotalCost());
        assertEquals("2026-05-27", saved.getAiReading().getReceiptDate());
    }

    @Test
    void findFeedbacks_filtersByFieldAndResolved_sortedNewestFirst() {
        LocalDateTime base = LocalDateTime.of(2026, 5, 1, 9, 0);
        feedbackRepository.saveAll(List.of(
                feedback(1, OcrField.TOTAL_COST, false, MODEL, base),
                feedback(2, OcrField.TOTAL_COST, false, MODEL, base.plusDays(2)),
                feedback(3, OcrField.TOTAL_COST, true, MODEL, base.plusDays(3)),
                feedback(4, OcrField.SELLER_NAME, false, MODEL, base.plusDays(4))));
        OcrFeedbackFilterRequestDto filter = OcrFeedbackFilterRequestDto.builder()
                .field(OcrField.TOTAL_COST).resolved(false).build();

        Page<OcrFeedbackResponseDto> page = service.findFeedbacks(filter, PageRequest.of(0, 10, Sort.by(Sort.Direction.DESC, "reportedAt")));

        assertEquals(2, page.getTotalElements());
        assertEquals(List.of(2L, 1L), page.getContent().stream().map(OcrFeedbackResponseDto::getReceiptId).toList());
    }

    @Test
    void findFeedbacks_dateRangeIsInclusiveOfTheLastDay() {
        LocalDateTime base = LocalDateTime.of(2026, 5, 10, 23, 30);
        feedbackRepository.saveAll(List.of(
                feedback(1, OcrField.TOTAL_COST, false, MODEL, base.minusDays(5)),
                feedback(2, OcrField.TOTAL_COST, false, MODEL, base)));
        OcrFeedbackFilterRequestDto filter = OcrFeedbackFilterRequestDto.builder()
                .from(LocalDate.of(2026, 5, 10)).to(LocalDate.of(2026, 5, 10)).build();

        Page<OcrFeedbackResponseDto> page = service.findFeedbacks(filter, PageRequest.of(0, 10));

        assertEquals(List.of(2L), page.getContent().stream().map(OcrFeedbackResponseDto::getReceiptId).toList());
    }

    @Test
    void analytics_groupsByFieldAndModel_andMonthlyConfidence() {
        LocalDateTime may = LocalDateTime.of(2026, 5, 10, 12, 0);
        LocalDateTime june = LocalDateTime.of(2026, 6, 10, 12, 0);
        feedbackRepository.saveAll(List.of(
                feedback(1, OcrField.TOTAL_COST, false, "donut-v5", may),
                feedback(1, OcrField.SELLER_NAME, false, "donut-v5", may),
                feedback(2, OcrField.TOTAL_COST, false, "donut-v4", june),
                feedback(3, OcrField.TOTAL_COST, false, "donut-v5", LocalDateTime.of(2025, 1, 1, 0, 0))));
        rawLogRepository.saveAll(List.of(
                rawLog(11, 0.5, may), rawLog(12, 0.7, may), rawLog(13, 0.9, june), rawLog(14, 0.1, may), rawLog(15, 1.0, june),
                rawLog(16, 1.0, LocalDateTime.of(2025, 1, 1, 0, 0))));

        OcrAnalyticsResponseDto result = service.analytics(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 6, 30));

        assertEquals(2, result.getErrorsByField().size());
        assertEquals("total_cost", result.getErrorsByField().get(0).getField());
        assertEquals(2, result.getErrorsByField().get(0).getCount());
        assertEquals(1, result.getErrorsByField().get(1).getCount());
        assertEquals(2, result.getErrorsByModel().size());
        assertEquals("donut-v5", result.getErrorsByModel().get(0).getModelVersion());
        assertEquals(2, result.getErrorsByModel().get(0).getCount());
        assertEquals(2, result.getConfidenceByMonth().size());
        assertEquals("2026-05", result.getConfidenceByMonth().get(0).getMonth());
        assertEquals(0.4333, result.getConfidenceByMonth().get(0).getAverageConfidence(), 0.001);
        assertEquals(3, result.getConfidenceByMonth().get(0).getLogs());
        assertEquals("2026-06", result.getConfidenceByMonth().get(1).getMonth());
        // Five readings in the range; three of their transactions (11, 12, 13) have a correction, whenever it was reported.
        assertEquals(3.0 / 5.0, result.getReceiptsWithErrorRate(), 1e-9);
    }

    @Test
    void analytics_feedbackReportedAfterTheRange_rateStaysAtMostOne() {
        // One reading in May, corrected in June: the May rate counts it, and never more readings than there are.
        LocalDateTime may = LocalDateTime.of(2026, 5, 31, 22, 0);
        rawLogRepository.save(rawLog(11, 0.8, may));
        feedbackRepository.saveAll(List.of(
                feedback(1, OcrField.TOTAL_COST, false, MODEL, LocalDateTime.of(2026, 6, 2, 8, 0)),
                feedback(1, OcrField.SELLER_NAME, false, MODEL, LocalDateTime.of(2026, 6, 2, 8, 0)),
                // Corrections of receipts whose reading is in another month do not count in May.
                feedback(2, OcrField.TOTAL_COST, false, MODEL, LocalDateTime.of(2026, 5, 3, 8, 0)),
                feedback(3, OcrField.TOTAL_COST, false, MODEL, LocalDateTime.of(2026, 5, 4, 8, 0))));

        double may2026 = service.analytics(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31)).getReceiptsWithErrorRate();
        double june2026 = service.analytics(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30)).getReceiptsWithErrorRate();

        assertEquals(1.0, may2026, 1e-9);
        assertEquals(0.0, june2026, "no reading in June");
    }

    @Test
    void analytics_readingsWithoutConfidence_doNotCountInTheAverage() {
        LocalDateTime may = LocalDateTime.of(2026, 5, 10, 12, 0);
        LocalDateTime june = LocalDateTime.of(2026, 6, 10, 12, 0);
        rawLogRepository.saveAll(List.of(rawLog(11, 0.6, may), rawLog(12, null, may), rawLog(13, null, june)));

        List<OcrAnalyticsResponseDto.MonthlyConfidence> months =
                service.analytics(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 6, 30)).getConfidenceByMonth();

        assertEquals(0.6, months.get(0).getAverageConfidence(), 1e-9);
        assertEquals(2, months.get(0).getLogs());
        assertNull(months.get(1).getAverageConfidence(), "no reading of June has a confidence");
        assertEquals(1, months.get(1).getLogs());
    }

    @Test
    void rawLog_withoutConfidenceField_storesNull() {
        service.onOcrProcessedEvent(new OcrProcessedEvent(78L, FULL_SCAN));

        assertNull(rawLogRepository.findAll().get(0).getAverageConfidenceScore());
    }

    @Test
    void correction_editedBackToTheAiValue_removesTheStaleDoc() {
        service.onOcrCorrectionEvent(new OcrCorrectionEvent(1L, 10L, 5L, List.of(
                new OcrFieldCorrection(OcrField.TOTAL_COST, "120000", "150000"),
                new OcrFieldCorrection(OcrField.SELLER_NAME, "A", "B"))));
        assertEquals(2, feedbackRepository.count());

        // The user typed the AI's total again; the seller stays corrected.
        service.onOcrCorrectionEvent(new OcrCorrectionEvent(1L, 10L, 5L, List.of(), List.of(OcrField.TOTAL_COST)));

        List<OcrFeedback> left = feedbackRepository.findAll();
        assertEquals(1, left.size());
        assertEquals("seller_name", left.get(0).getFieldError());
        // Clearing a field that has no correction is no error.
        assertDoesNotThrow(() -> service.onOcrCorrectionEvent(
                new OcrCorrectionEvent(2L, 20L, 5L, List.of(), List.of(OcrField.RECEIPT_DATE))));
    }

    @Test
    void correction_sameExpectedValueAgain_keepsItResolved_differentValueReopens() {
        service.onOcrCorrectionEvent(total(1, "120000", "150000"));
        OcrFeedback first = feedbackRepository.findAll().get(0);
        service.resolveFeedback(first.getId());

        // An unrelated edit of the receipt compares the total again and finds the same correction.
        service.onOcrCorrectionEvent(total(1, "120000", "150000"));

        OcrFeedback unchanged = feedbackRepository.findAll().get(0);
        assertTrue(unchanged.isResolved(), "nothing new to look at");
        assertEquals(first.getUpdatedAt(), unchanged.getUpdatedAt());

        service.onOcrCorrectionEvent(total(1, "120000", "160000"));

        OcrFeedback reopened = feedbackRepository.findAll().get(0);
        assertFalse(reopened.isResolved());
        assertEquals("160000", reopened.getExpectedValue());
        assertEquals(1, feedbackRepository.count());
    }

    @Test
    void analytics_noLogs_rateIsZero() {
        assertEquals(0.0, service.analytics(null, null).getReceiptsWithErrorRate());
    }

    @Test
    void resolve_unknownId_throwsNotFound() {
        assertThrows(OcrFeedbackNotFoundException.class, () -> service.resolveFeedback("64b7f0f0f0f0f0f0f0f0f0f0"));
    }

    @Test
    void resolve_marksTheDocResolved() {
        OcrFeedback saved = feedbackRepository.save(feedback(1, OcrField.TOTAL_COST, false, MODEL, LocalDateTime.of(2026, 5, 1, 9, 0)));

        OcrFeedbackResponseDto resolved = service.resolveFeedback(saved.getId());

        assertTrue(resolved.isResolved());
        assertTrue(feedbackRepository.findById(saved.getId()).orElseThrow().isResolved());
    }

    @Test
    void delete_removesDoc() {
        OcrFeedback saved = feedbackRepository.save(feedback(1, OcrField.TOTAL_COST, false, MODEL, LocalDateTime.of(2026, 5, 1, 9, 0)));

        service.deleteFeedback(saved.getId());

        assertEquals(0, template.count(new Query(Criteria.where("receiptId").is(1L)), OcrFeedback.class));
        assertThrows(OcrFeedbackNotFoundException.class, () -> service.deleteFeedback(saved.getId()));
    }
}
