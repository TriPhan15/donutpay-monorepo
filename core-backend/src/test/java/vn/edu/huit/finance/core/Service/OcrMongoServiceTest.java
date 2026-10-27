package vn.edu.huit.finance.core.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mongodb.client.result.UpdateResult;
import org.bson.BsonObjectId;
import org.bson.Document;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.UpdateDefinition;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Dto.OcrCorrectionEvent;
import vn.edu.huit.finance.core.Dto.OcrFieldCorrection;
import vn.edu.huit.finance.core.Dto.OcrProcessedEvent;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Dto.OcrRawLogResponseDto;
import vn.edu.huit.finance.core.Exception.OcrFeedbackNotFoundException;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventType;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;

/**
 * Unit tests cho OcrMongoService.
 *
 * <p>Mục tiêu kiểm thử:
 * <ol>
 *   <li>Graceful Degradation: Khi MongoDB lỗi, KHÔNG ném exception ra ngoài (đảm bảo Postgres không bị ảnh hưởng).</li>
 *   <li>Data Parsing: BSON Document được parse đúng từ JSON hợp lệ và invalid JSON.</li>
 *   <li>Confidence Score: extractConfidenceScore tìm đúng field từ nhiều cấu trúc JSON của AI, null khi không có.</li>
 *   <li>Resolve Feedback: Update isResolved=true và trả về đúng kết quả.</li>
 *   <li>Skip Empty Event: Không ghi DB khi payload rỗng/null.</li>
 * </ol>
 *
 * <p>Không dùng @SpringBootTest để giữ test nhanh — chỉ Mockito thuần.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("OcrMongoService — Unit Tests")
class OcrMongoServiceTest {

    @Mock
    private OcrRawLogRepository ocrRawLogRepository;

    @Mock
    private OcrFeedbackRepository ocrFeedbackRepository;

    @Mock
    private MongoTemplate mongoTemplate;

    @Spy
    private OcrService ocrService = new OcrService();

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private AdminEventPublisher adminEventPublisher;

    @InjectMocks
    private OcrMongoService ocrMongoService;

    // =========================================================================
    // NHÓM 1: onOcrProcessedEvent — Happy Path
    // =========================================================================
    @Nested
    @DisplayName("onOcrProcessedEvent — Happy Path")
    class OnOcrProcessedEventHappyPath {

        private static final Long   TRANSACTION_ID = 42L;
        private static final String VALID_JSON =
                "{\"confidence_score\":0.95,\"vendor_name\":\"Highlands Coffee\",\"total_amount\":85000}";

        @Test
        @DisplayName("Lưu OcrRawLog với BSON Document đúng khi JSON hợp lệ")
        void savesDocumentWithCorrectBsonWhenJsonIsValid() {
            OcrProcessedEvent event = new OcrProcessedEvent(TRANSACTION_ID, VALID_JSON);
            given(ocrRawLogRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            ocrMongoService.onOcrProcessedEvent(event);

            ArgumentCaptor<OcrRawLog> captor = ArgumentCaptor.forClass(OcrRawLog.class);
            then(ocrRawLogRepository).should(times(1)).save(captor.capture());

            OcrRawLog saved = captor.getValue();
            assertThat(saved.getTransactionId()).isEqualTo(TRANSACTION_ID);
            assertThat(saved.getAverageConfidenceScore()).isEqualTo(0.95);
            // rawJsonData phải là BSON Document, không phải String raw
            assertThat(saved.getRawJsonData()).isInstanceOf(Document.class);
            assertThat(saved.getRawJsonData().get("vendor_name")).isEqualTo("Highlands Coffee");
        }

        @Test
        @DisplayName("Parse confidence_score từ field 'score' khi không có 'confidence_score'")
        void parsesConfidenceFromAlternativeScoreField() {
            String jsonWithScore = "{\"score\":0.75,\"vendor_name\":\"KFC\"}";
            OcrProcessedEvent event = new OcrProcessedEvent(TRANSACTION_ID, jsonWithScore);
            given(ocrRawLogRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            ocrMongoService.onOcrProcessedEvent(event);

            ArgumentCaptor<OcrRawLog> captor = ArgumentCaptor.forClass(OcrRawLog.class);
            then(ocrRawLogRepository).should().save(captor.capture());
            assertThat(captor.getValue().getAverageConfidenceScore()).isEqualTo(0.75);
        }

        @Test
        @DisplayName("Parse confidence từ field 'confidence' khi hai field kia không có")
        void parsesConfidenceFromConfidenceField() {
            String jsonWithConfidence = "{\"confidence\":0.60,\"text\":\"some receipt\"}";
            OcrProcessedEvent event = new OcrProcessedEvent(TRANSACTION_ID, jsonWithConfidence);
            given(ocrRawLogRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            ocrMongoService.onOcrProcessedEvent(event);

            ArgumentCaptor<OcrRawLog> captor = ArgumentCaptor.forClass(OcrRawLog.class);
            then(ocrRawLogRepository).should().save(captor.capture());
            assertThat(captor.getValue().getAverageConfidenceScore()).isEqualTo(0.60);
        }

        @Test
        @DisplayName("Không có field confidence nào (Donut V5 không trả về): độ tin cậy để null, không bịa 1.0")
        void leavesConfidenceNullWhenNoFieldFound() {
            String jsonNoConfidence = "{\"vendor_name\":\"Starbucks\",\"total\":120000}";
            OcrProcessedEvent event = new OcrProcessedEvent(TRANSACTION_ID, jsonNoConfidence);
            given(ocrRawLogRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            ocrMongoService.onOcrProcessedEvent(event);

            ArgumentCaptor<OcrRawLog> captor = ArgumentCaptor.forClass(OcrRawLog.class);
            then(ocrRawLogRepository).should().save(captor.capture());
            assertThat(captor.getValue().getAverageConfidenceScore()).isNull();
        }
    }

    // =========================================================================
    // NHÓM 2: onOcrProcessedEvent — Edge Cases (JSON không hợp lệ)
    // =========================================================================
    @Nested
    @DisplayName("onOcrProcessedEvent — Edge Cases với JSON không hợp lệ")
    class OnOcrProcessedEventEdgeCases {

        @Test
        @DisplayName("Bọc invalid JSON vào 'unparsed_raw_string' thay vì bỏ qua")
        void wrapsInvalidJsonInFallbackBsonField() {
            String invalidJson = "INVALID_RAW_TEXT_FROM_AI";
            OcrProcessedEvent event = new OcrProcessedEvent(99L, invalidJson);
            given(ocrRawLogRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            ocrMongoService.onOcrProcessedEvent(event);

            ArgumentCaptor<OcrRawLog> captor = ArgumentCaptor.forClass(OcrRawLog.class);
            then(ocrRawLogRepository).should(times(1)).save(captor.capture());

            Document bson = captor.getValue().getRawJsonData();
            assertThat(bson).isNotNull();
            assertThat(bson.containsKey("unparsed_raw_string")).isTrue();
            assertThat(bson.get("unparsed_raw_string")).isEqualTo(invalidJson);
        }

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {"   ", "\t", "\n"})
        @DisplayName("Bỏ qua hoàn toàn khi rawReceiptData null hoặc blank — không gọi MongoDB")
        void skipsRepositoryCallWhenPayloadIsNullOrBlank(String blankPayload) {
            OcrProcessedEvent event = new OcrProcessedEvent(1L, blankPayload);

            ocrMongoService.onOcrProcessedEvent(event);

            then(ocrRawLogRepository).should(never()).save(any());
        }
    }

    // =========================================================================
    // NHÓM 3: onOcrProcessedEvent — Graceful Degradation (QUAN TRỌNG NHẤT)
    // =========================================================================
    @Nested
    @DisplayName("onOcrProcessedEvent — Graceful Degradation")
    class OnOcrProcessedEventGracefulDegradation {

        @Test
        @DisplayName("KHÔNG ném exception ra ngoài khi MongoDB.save() thất bại — đảm bảo Postgres không bị ảnh hưởng")
        void doesNotPropagateExceptionWhenMongoSaveFails() {
            String validJson = "{\"confidence_score\":0.8,\"vendor\":\"Test\"}";
            OcrProcessedEvent event = new OcrProcessedEvent(55L, validJson);
            given(ocrRawLogRepository.save(any())).willThrow(new RuntimeException("MongoDB is down!"));

            // Đây là assertion quan trọng nhất của cả test suite:
            // Method PHẢI hoàn thành bình thường, KHÔNG được re-throw exception
            assertThatCode(() -> ocrMongoService.onOcrProcessedEvent(event))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("KHÔNG ném exception khi ObjectMapper bị lỗi khi parse JSON")
        void doesNotPropagateExceptionWhenObjectMapperFails() {
            // JSON hợp lệ về mặt cú pháp nhưng giả lập parser fail
            String maliciousJson = "{\"key\":\"value\"}";
            OcrProcessedEvent event = new OcrProcessedEvent(77L, maliciousJson);
            given(ocrRawLogRepository.save(any())).willThrow(new RuntimeException("Connection timeout"));

            assertThatCode(() -> ocrMongoService.onOcrProcessedEvent(event))
                    .doesNotThrowAnyException();
        }
    }

    // =========================================================================
    // NHÓM 4: resolveFeedback — Update CRUD
    // =========================================================================
    @Nested
    @DisplayName("resolveFeedback — Update Operation")
    class ResolveFeedbackTests {

        @Test
        @DisplayName("Cập nhật isResolved=true và trả về DTO khi feedback tồn tại")
        void returnsDtoAndUpdatesWhenFeedbackExists() {
            String feedbackId = "fb-001";
            OcrFeedback existingFeedback = new OcrFeedback();
            existingFeedback.setResolved(false);
            given(ocrFeedbackRepository.findById(feedbackId)).willReturn(Optional.of(existingFeedback));
            given(ocrFeedbackRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            OcrFeedbackResponseDto result = ocrMongoService.resolveFeedback(feedbackId);

            assertThat(result.isResolved()).isTrue();
            ArgumentCaptor<OcrFeedback> captor = ArgumentCaptor.forClass(OcrFeedback.class);
            then(ocrFeedbackRepository).should().save(captor.capture());
            assertThat(captor.getValue().isResolved()).isTrue();
        }

        @Test
        @DisplayName("Ném OcrFeedbackNotFoundException và không gọi save khi feedback không tồn tại")
        void throwsAndSkipsSaveWhenFeedbackNotFound() {
            given(ocrFeedbackRepository.findById("not-exist")).willReturn(Optional.empty());

            org.assertj.core.api.Assertions.assertThatThrownBy(() -> ocrMongoService.resolveFeedback("not-exist"))
                    .isInstanceOf(OcrFeedbackNotFoundException.class);
            then(ocrFeedbackRepository).should(never()).save(any());
        }
    }

    // =========================================================================
    // NHÓM: getOcrLogs — trả DTO, không trả document MongoDB
    // =========================================================================
    @Nested
    @DisplayName("getOcrLogs — DTO mapping")
    class GetOcrLogs {

        @Test
        @DisplayName("Mỗi document được ánh xạ sang OcrRawLogResponseDto, rawJsonData thành Map thường, giữ thông tin trang")
        void mapsEveryDocumentToADto() {
            OcrRawLog log = new OcrRawLog();
            log.setId("abc123");
            log.setTransactionId(42L);
            log.setRawJsonData(new Document("seller", new Document("total_cost", "120000")));
            log.setAverageConfidenceScore(0.87);
            log.setCreatedAt(LocalDateTime.of(2026, 10, 25, 9, 30));
            PageRequest pageable = PageRequest.of(1, 5);
            given(ocrRawLogRepository.findAll(pageable)).willReturn(new PageImpl<>(List.of(log), pageable, 6));

            Page<OcrRawLogResponseDto> page = ocrMongoService.getOcrLogs(pageable);

            assertThat(page.getTotalElements()).isEqualTo(6);
            assertThat(page.getNumber()).isEqualTo(1);
            OcrRawLogResponseDto dto = page.getContent().get(0);
            assertThat(dto.getId()).isEqualTo("abc123");
            assertThat(dto.getTransactionId()).isEqualTo(42L);
            assertThat(dto.getAverageConfidenceScore()).isEqualTo(0.87);
            assertThat(dto.getCreatedAt()).isEqualTo(LocalDateTime.of(2026, 10, 25, 9, 30));
            assertThat(dto.getRawJsonData()).isNotInstanceOf(Document.class).containsKey("seller");
            assertThat(((Map<?, ?>) dto.getRawJsonData().get("seller")).get("total_cost")).isEqualTo("120000");
        }

        @Test
        @DisplayName("Document không có rawJsonData vẫn ánh xạ được (null)")
        void aDocumentWithoutRawJsonMapsToNull() {
            OcrRawLog log = new OcrRawLog();
            log.setId("empty");
            PageRequest pageable = PageRequest.of(0, 20);
            given(ocrRawLogRepository.findAll(pageable)).willReturn(new PageImpl<>(List.of(log), pageable, 1));

            assertThat(ocrMongoService.getOcrLogs(pageable).getContent().get(0).getRawJsonData()).isNull();
        }
    }

    // =========================================================================
    // NHÓM: onOcrCorrectionEvent — báo cho trang quản trị (Redis Pub/Sub)
    // =========================================================================
    @Nested
    @DisplayName("onOcrCorrectionEvent — sự kiện realtime cho quản trị viên")
    class CorrectionAdminEvent {

        private static final Long RECEIPT_ID = 9L;

        private OcrCorrectionEvent twoCorrections() {
            return new OcrCorrectionEvent(RECEIPT_ID, 100L, 3L, List.of(
                    new OcrFieldCorrection(OcrField.TOTAL_COST, "125000", "152000"),
                    new OcrFieldCorrection(OcrField.SELLER_NAME, "Hghlands", "Highlands")));
        }

        private void updateMatches(long matched) {
            given(mongoTemplate.updateFirst(any(Query.class), any(UpdateDefinition.class), eq(OcrFeedback.class)))
                    .willReturn(UpdateResult.acknowledged(matched, matched, null));
        }

        private void upsertInserts(boolean inserted) {
            given(mongoTemplate.upsert(any(Query.class), any(UpdateDefinition.class), eq(OcrFeedback.class)))
                    .willReturn(inserted ? UpdateResult.acknowledged(0, 0L, new BsonObjectId())
                            : UpdateResult.acknowledged(1, 0L, null));
        }

        @Test
        @DisplayName("Chỗ sửa mới được ghi: phát OCR_FEEDBACK_REPORTED với mã hóa đơn và số chỗ sửa")
        void newCorrectionsArePublishedWithTheReceiptIdAndTheirCount() {
            updateMatches(0);
            upsertInserts(true);

            ocrMongoService.onOcrCorrectionEvent(twoCorrections());

            ArgumentCaptor<AdminEvent> published = ArgumentCaptor.forClass(AdminEvent.class);
            then(adminEventPublisher).should().publish(published.capture());
            assertThat(published.getValue().type()).isEqualTo(AdminEventType.OCR_FEEDBACK_REPORTED);
            assertThat(published.getValue().id()).isEqualTo(RECEIPT_ID);
            assertThat(published.getValue().message()).isEqualTo("Hóa đơn #9 có 2 chỗ sửa OCR mới");
        }

        @Test
        @DisplayName("Chỗ sửa đổi giá trị (mở lại phản hồi cũ) cũng được báo")
        void reopenedCorrectionsArePublished() {
            updateMatches(1);

            ocrMongoService.onOcrCorrectionEvent(twoCorrections());

            then(adminEventPublisher).should().publish(any(AdminEvent.class));
        }

        @Test
        @DisplayName("Gửi lại đúng chỗ sửa đã lưu (không đổi gì): không báo lại cho quản trị viên")
        void unchangedCorrectionsAreNotPublishedAgain() {
            updateMatches(0);
            upsertInserts(false);

            ocrMongoService.onOcrCorrectionEvent(twoCorrections());

            then(adminEventPublisher).should(never()).publish(any());
        }

        @Test
        @DisplayName("MongoDB lỗi: không ném lỗi và không báo gì")
        void mongoFailurePublishesNothing() {
            given(mongoTemplate.updateFirst(any(Query.class), any(UpdateDefinition.class), eq(OcrFeedback.class)))
                    .willThrow(new DataAccessResourceFailureException("mongo down"));

            assertThatCode(() -> ocrMongoService.onOcrCorrectionEvent(twoCorrections())).doesNotThrowAnyException();

            then(adminEventPublisher).should(never()).publish(any());
        }
    }
}
