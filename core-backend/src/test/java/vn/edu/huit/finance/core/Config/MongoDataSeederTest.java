package vn.edu.huit.finance.core.Config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessResourceFailureException;
import vn.edu.huit.finance.core.Document.OcrFeedback;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Repository.Mongo.OcrFeedbackRepository;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;
import vn.edu.huit.finance.core.Service.DemoData.ReceiptScenario;
import vn.edu.huit.finance.core.Service.DemoData.SeededReceipt;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MongoDataSeederTest {

    private static final LocalDateTime SCANNED_AT = LocalDateTime.of(2026, 10, 20, 12, 30);
    private static final String AI_ANSWER = "{\"seller\":{\"seller_name\":\"PHUC LONG\",\"total_cost_number\":55000}}";

    @Mock private OcrRawLogRepository ocrRawLogRepository;
    @Mock private OcrFeedbackRepository ocrFeedbackRepository;
    @InjectMocks private MongoDataSeeder seeder;

    @Test
    void eachSeededReceiptGetsItsRawLog_andTheCorrectedAndAwaitingOnesAFeedback() {
        List<SeededReceipt> receipts = List.of(
                receipt(1L, ReceiptScenario.READ),
                receipt(2L, ReceiptScenario.CORRECTED),
                receipt(3L, ReceiptScenario.UNREADABLE_TOTAL),
                receipt(4L, ReceiptScenario.AWAITING_REVIEW));

        seeder.seed(receipts);

        ArgumentCaptor<List<OcrRawLog>> logs = listCaptor();
        verify(ocrRawLogRepository).saveAll(logs.capture());
        assertThat(logs.getValue()).extracting(OcrRawLog::getTransactionId).containsExactly(1L, 2L, 3L, 4L);
        assertThat(logs.getValue().get(1).getRawJsonData().get("seller", org.bson.Document.class).getString("seller_name"))
                .isEqualTo("PHUC LONG");
        assertThat(logs.getValue().get(0).getAverageConfidenceScore())
                .isGreaterThan(logs.getValue().get(2).getAverageConfidenceScore());

        ArgumentCaptor<List<OcrFeedback>> feedbacks = listCaptor();
        verify(ocrFeedbackRepository).saveAll(feedbacks.capture());
        assertThat(feedbacks.getValue()).extracting(OcrFeedback::getReceiptId).containsExactly(102L, 104L);
        OcrFeedback corrected = feedbacks.getValue().get(0);
        assertThat(corrected.getAiValue()).isEqualTo("PHUC LONG");
        assertThat(corrected.getExpectedValue()).isEqualTo("Phúc Long");
        assertThat(corrected.isResolved()).isTrue();
        OcrFeedback awaiting = feedbacks.getValue().get(1);
        assertThat(awaiting.getExpectedValue()).isEqualTo("55000");
        assertThat(awaiting.isResolved()).isFalse();
    }

    @Test
    void nothingWasSeededInPostgres_soMongoIsNotTouched() {
        seeder.seed(List.of());

        verifyNoInteractions(ocrRawLogRepository, ocrFeedbackRepository);
    }

    @Test
    void collectionsThatAlreadyHaveDocumentsAreLeftAlone() {
        when(ocrRawLogRepository.count()).thenReturn(3L);
        when(ocrFeedbackRepository.count()).thenReturn(1L);

        seeder.seed(List.of(receipt(1L, ReceiptScenario.CORRECTED)));

        verify(ocrRawLogRepository, never()).saveAll(anyList());
        verify(ocrFeedbackRepository, never()).saveAll(anyList());
    }

    @Test
    void anUnreachableMongoDbDoesNotStopTheStartup() {
        when(ocrRawLogRepository.count()).thenThrow(new DataAccessResourceFailureException("connection refused"));

        assertThatCode(() -> seeder.seed(List.of(receipt(1L, ReceiptScenario.READ)))).doesNotThrowAnyException();
    }

    private static SeededReceipt receipt(long transactionId, ReceiptScenario scenario) {
        return new SeededReceipt(transactionId, 100L + transactionId, 7L, scenario, AI_ANSWER, "PHUC LONG", "Phúc Long",
                BigDecimal.valueOf(55_000), SCANNED_AT);
    }

    @SuppressWarnings("unchecked")
    private static <T> ArgumentCaptor<List<T>> listCaptor() {
        return ArgumentCaptor.forClass(List.class);
    }
}
