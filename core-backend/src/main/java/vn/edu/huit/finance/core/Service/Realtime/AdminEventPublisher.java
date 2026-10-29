package vn.edu.huit.finance.core.Service.Realtime;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Sends the realtime events of the admin web to every instance of the API: one JSON message on the Redis channel
 * {@link #CHANNEL}, which the {@link AdminEventRelay} of each instance forwards to its open admin browsers. Redis only
 * carries a notification here: when it is down or slow the event is lost and the failure is only logged, never thrown at
 * the caller (whose database work is already committed).
 */
@Slf4j
@Service
public class AdminEventPublisher {

    public static final String CHANNEL = "ledgermind:admin-events";

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    public AdminEventPublisher(StringRedisTemplate redis, ObjectMapper objectMapper) {
        this.redis = redis;
        this.objectMapper = objectMapper;
    }

    public void publish(AdminEvent event) {
        try {
            redis.convertAndSend(CHANNEL, objectMapper.writeValueAsString(event));
        } catch (JsonProcessingException | RuntimeException e) {
            log.warn("Admin event not published, type={}, id={}: {}", event.type(), event.id(), e.toString());
        }
    }

    /** After the commit and off the request thread: a slow Redis never holds the user's request nor its connection. */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onReceiptWaitingReview(ReceiptWaitingReviewEvent event) {
        publish(AdminEvent.receiptWaitingReview(event.receiptId()));
    }
}
