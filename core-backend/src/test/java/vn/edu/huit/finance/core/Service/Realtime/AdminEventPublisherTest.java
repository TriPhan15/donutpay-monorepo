package vn.edu.huit.finance.core.Service.Realtime;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.lang.reflect.Method;
import java.lang.reflect.RecordComponent;
import java.time.Instant;
import java.time.YearMonth;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/** The publishing half of the realtime admin events: JSON on one Redis channel, and a Redis failure is only logged. */
class AdminEventPublisherTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    // Like the ObjectMapper Spring Boot gives the application: Instant as ISO-8601 text.
    private final ObjectMapper mapper = Jackson2ObjectMapperBuilder.json()
            .featuresToDisable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS).build();
    private final AdminEventPublisher publisher = new AdminEventPublisher(redis, mapper);

    private JsonNode sentJson() throws Exception {
        ArgumentCaptor<String> json = ArgumentCaptor.forClass(String.class);
        verify(redis).convertAndSend(eq(AdminEventPublisher.CHANNEL), json.capture());
        return mapper.readTree(json.getValue());
    }

    @Test
    void theChannelIsTheLedgermindAdminEventsChannel() {
        assertEquals("ledgermind:admin-events", AdminEventPublisher.CHANNEL);
    }

    @Test
    void publishSendsTheEventAsJsonOnTheChannel() throws Exception {
        Instant at = Instant.parse("2026-10-27T08:15:30Z");
        publisher.publish(new AdminEvent(AdminEventType.RECEIPT_WAITING_REVIEW, 41L, "Hóa đơn #41 đang chờ duyệt", at));

        JsonNode json = sentJson();
        assertEquals("RECEIPT_WAITING_REVIEW", json.get("type").asText());
        assertEquals(41L, json.get("id").asLong());
        assertEquals("Hóa đơn #41 đang chờ duyệt", json.get("message").asText());
        assertEquals("2026-10-27T08:15:30Z", json.get("at").asText());
    }

    @Test
    void aRedisFailureIsOnlyLogged() {
        doThrow(new RedisConnectionFailureException("redis down")).when(redis).convertAndSend(anyString(), anyString());

        assertDoesNotThrow(() -> publisher.publish(AdminEvent.searchReindexed(5)));
    }

    @Test
    void aReceiptWaitingForReviewBecomesAnAdminEventWithItsId() throws Exception {
        publisher.onReceiptWaitingReview(new ReceiptWaitingReviewEvent(7L));

        JsonNode json = sentJson();
        assertEquals("RECEIPT_WAITING_REVIEW", json.get("type").asText());
        assertEquals(7L, json.get("id").asLong());
        assertEquals("Hóa đơn #7 đang chờ duyệt", json.get("message").asText());
    }

    @Test
    void theReceiptListenerRunsOnlyAfterTheCommitAndOffTheRequestThread() throws NoSuchMethodException {
        Method listener = AdminEventPublisher.class.getMethod("onReceiptWaitingReview", ReceiptWaitingReviewEvent.class);

        TransactionalEventListener after = listener.getAnnotation(TransactionalEventListener.class);
        assertNotNull(after);
        assertEquals(TransactionPhase.AFTER_COMMIT, after.phase());
        assertFalse(after.fallbackExecution(), "no event without a committed transaction");
        assertEquals("mongoAsyncExecutor", listener.getAnnotation(Async.class).value());
    }

    @Test
    void theMessagesHoldIdsAndCountsOnly() {
        assertEquals("Hóa đơn #9 có 2 chỗ sửa OCR mới", AdminEvent.ocrFeedbackReported(9L, 2).message());
        assertEquals("Đã dựng lại chỉ mục tìm kiếm: 321 giao dịch", AdminEvent.searchReindexed(321).message());
        assertEquals("Đã dựng lại bảng xếp hạng tháng 2026-09: 12 người dùng",
                AdminEvent.leaderboardRebuilt(YearMonth.of(2026, 9), 12).message());
        assertEquals(List.of("type", "id", "message", "at"),
                Arrays.stream(AdminEvent.class.getRecordComponents()).map(RecordComponent::getName).toList());
        assertNull(AdminEvent.searchReindexed(1).id());
        assertNotNull(AdminEvent.searchReindexed(1).at());
    }
}
