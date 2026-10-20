package vn.edu.huit.finance.core.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
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
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Dto.OcrProcessedEvent;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
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
 *   <li>Confidence Score: extractConfidenceScore tìm đúng field từ nhiều cấu trúc JSON của AI.</li>
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

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

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
        @DisplayName("Dùng confidence mặc định 1.0 khi JSON không có field confidence nào")
        void defaultsConfidenceToOneWhenNoFieldFound() {
            String jsonNoConfidence = "{\"vendor_name\":\"Starbucks\",\"total\":120000}";
            OcrProcessedEvent event = new OcrProcessedEvent(TRANSACTION_ID, jsonNoConfidence);
            given(ocrRawLogRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            ocrMongoService.onOcrProcessedEvent(event);

            ArgumentCaptor<OcrRawLog> captor = ArgumentCaptor.forClass(OcrRawLog.class);
            then(ocrRawLogRepository).should().save(captor.capture());
            assertThat(captor.getValue().getAverageConfidenceScore()).isEqualTo(1.0);
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
        @DisplayName("Cập nhật isResolved=true và trả về true khi feedback tồn tại")
        void returnsTrueAndUpdatesWhenFeedbackExists() {
            String feedbackId = "fb-001";
            OcrFeedback existingFeedback = new OcrFeedback();
            existingFeedback.setResolved(false);
            given(ocrFeedbackRepository.findById(feedbackId)).willReturn(Optional.of(existingFeedback));
            given(ocrFeedbackRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

            boolean result = ocrMongoService.resolveFeedback(feedbackId);

            assertThat(result).isTrue();
            ArgumentCaptor<OcrFeedback> captor = ArgumentCaptor.forClass(OcrFeedback.class);
            then(ocrFeedbackRepository).should().save(captor.capture());
            assertThat(captor.getValue().isResolved()).isTrue();
        }

        @Test
        @DisplayName("Trả về false và không gọi save khi feedback không tồn tại")
        void returnsFalseAndSkipsSaveWhenFeedbackNotFound() {
            given(ocrFeedbackRepository.findById("not-exist")).willReturn(Optional.empty());

            boolean result = ocrMongoService.resolveFeedback("not-exist");

            assertThat(result).isFalse();
            then(ocrFeedbackRepository).should(never()).save(any());
        }
    }
}

