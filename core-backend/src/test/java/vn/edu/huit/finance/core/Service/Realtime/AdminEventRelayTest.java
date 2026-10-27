package vn.edu.huit.finance.core.Service.Realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.connection.DefaultMessage;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.edu.huit.finance.core.Security.AdminSessionActivity;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.function.Consumer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * The relay without Redis: which emitters it holds and when it lets them go. Completion, timeout and error each remove the
 * emitter; so does a failed send, a heartbeat that fails, and a session that has ended (sign-out or expiry).
 */
class AdminEventRelayTest {

    // Like the ObjectMapper Spring Boot gives the application: Instant as ISO-8601 text.
    /** The servlet container's default idle timeout (server.servlet.session.timeout = 30m). */
    private static final int SESSION_TIMEOUT_SECONDS = 1800;

    private final ObjectMapper mapper = Jackson2ObjectMapperBuilder.json()
            .featuresToDisable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS).build();
    private final AdminEventRelay relay = new AdminEventRelay(mapper);

    private static DefaultMessage messageOf(String json) {
        return new DefaultMessage(AdminEventPublisher.CHANNEL.getBytes(StandardCharsets.UTF_8),
                json.getBytes(StandardCharsets.UTF_8));
    }

    private String eventJson() throws Exception {
        return mapper.writeValueAsString(new AdminEvent(AdminEventType.OCR_FEEDBACK_REPORTED, 3L, "Hóa đơn #3 có 1 chỗ sửa OCR mới",
                Instant.parse("2026-10-27T08:00:00Z")));
    }

    @Test
    void registerReturnsAnEmitterThatTimesOutAfterThirtyMinutes() {
        SseEmitter emitter = relay.register();

        assertEquals(30 * 60 * 1000L, emitter.getTimeout());
        assertEquals(1, relay.subscriberCount());
    }

    @Test
    void completionRemovesTheEmitter() {
        SseEmitter emitter = mock(SseEmitter.class);
        ArgumentCaptor<Runnable> onCompletion = ArgumentCaptor.forClass(Runnable.class);
        relay.register(emitter, null);
        verify(emitter).onCompletion(onCompletion.capture());

        onCompletion.getValue().run();

        assertEquals(0, relay.subscriberCount());
    }

    @Test
    void timeoutRemovesTheEmitter() {
        SseEmitter emitter = mock(SseEmitter.class);
        ArgumentCaptor<Runnable> onTimeout = ArgumentCaptor.forClass(Runnable.class);
        relay.register(emitter, null);
        verify(emitter).onTimeout(onTimeout.capture());

        onTimeout.getValue().run();

        assertEquals(0, relay.subscriberCount());
    }

    @Test
    @SuppressWarnings("unchecked")
    void errorRemovesTheEmitter() {
        SseEmitter emitter = mock(SseEmitter.class);
        ArgumentCaptor<Consumer<Throwable>> onError = ArgumentCaptor.forClass(Consumer.class);
        relay.register(emitter, null);
        verify(emitter).onError(onError.capture());

        onError.getValue().accept(new IOException("broken pipe"));

        assertEquals(0, relay.subscriberCount());
    }

    @Test
    void aMessageIsSentToEveryEmitterAsAnAdminEvent() throws Exception {
        SseEmitter first = mock(SseEmitter.class);
        SseEmitter second = mock(SseEmitter.class);
        relay.register(first, null);
        relay.register(second, null);

        relay.onMessage(messageOf(eventJson()), null);

        // One send at registration (the reconnect delay), one for the event.
        verify(first, times(2)).send(any(SseEmitter.SseEventBuilder.class));
        verify(second, times(2)).send(any(SseEmitter.SseEventBuilder.class));
    }

    @Test
    void anEmitterWhoseSendFailsIsRemovedAndTheOthersStillGetTheEvent() throws Exception {
        SseEmitter broken = mock(SseEmitter.class);
        SseEmitter healthy = mock(SseEmitter.class);
        relay.register(broken, null);
        relay.register(healthy, null);
        doThrow(new IOException("client gone")).when(broken).send(any(SseEmitter.SseEventBuilder.class));

        relay.onMessage(messageOf(eventJson()), null);

        assertEquals(1, relay.subscriberCount());
        verify(healthy, times(2)).send(any(SseEmitter.SseEventBuilder.class));
    }

    @Test
    void anEmitterThatIsAlreadyCompleteIsRemovedOnTheNextSend() throws Exception {
        SseEmitter done = mock(SseEmitter.class);
        relay.register(done, null);
        doThrow(new IllegalStateException("ResponseBodyEmitter has already completed"))
                .when(done).send(any(SseEmitter.SseEventBuilder.class));

        relay.heartbeat();

        assertEquals(0, relay.subscriberCount());
    }

    @Test
    void aMessageThatIsNoAdminEventIsDropped() throws Exception {
        SseEmitter emitter = mock(SseEmitter.class);
        relay.register(emitter, null);
        clearInvocations(emitter);

        relay.onMessage(messageOf("<script>alert(1)</script>"), null);
        relay.onMessage(messageOf("{\"type\":\"NOT_A_TYPE\",\"id\":1}"), null);

        verify(emitter, never()).send(any(SseEmitter.SseEventBuilder.class));
        assertEquals(1, relay.subscriberCount());
    }

    @Test
    void theHeartbeatPingsEveryEmitterEvery25Seconds() throws Exception {
        SseEmitter emitter = mock(SseEmitter.class);
        relay.register(emitter, null);
        clearInvocations(emitter);

        relay.heartbeat();

        verify(emitter).send(any(SseEmitter.SseEventBuilder.class));
        Scheduled scheduled = AdminEventRelay.class.getMethod("heartbeat").getAnnotation(Scheduled.class);
        assertEquals(25_000L, scheduled.timeUnit().toMillis(scheduled.fixedRate()));
    }

    @Test
    void aStreamWhoseSessionEndedIsClosedAtTheNextHeartbeat() throws Exception {
        MockHttpSession session = new MockHttpSession();
        SseEmitter emitter = mock(SseEmitter.class);
        relay.register(emitter, session);
        clearInvocations(emitter);

        session.invalidate();
        relay.heartbeat();

        assertEquals(0, relay.subscriberCount());
        verify(emitter).complete();
        verify(emitter, never()).send(any(SseEmitter.SseEventBuilder.class));
    }

    @Test
    void aStreamWhoseSessionEndedGetsNoEvent() throws Exception {
        MockHttpSession session = new MockHttpSession();
        SseEmitter emitter = mock(SseEmitter.class);
        relay.register(emitter, session);
        clearInvocations(emitter);

        session.invalidate();
        relay.onMessage(messageOf(eventJson()), null);

        verify(emitter, never()).send(any(SseEmitter.SseEventBuilder.class));
        assertEquals(0, relay.subscriberCount());
    }

    /** A session with the given idle timeout whose last real page request was {@code idleFor} ago. */
    private static MockHttpSession sessionIdleFor(Duration idleFor, int timeoutSeconds) {
        MockHttpSession session = new MockHttpSession();
        session.setMaxInactiveInterval(timeoutSeconds);
        AdminSessionActivity.record(session, Instant.now().minus(idleFor));
        return session;
    }

    @Test
    void theStreamOfAnAdministratorIdlePastTheSessionTimeoutIsClosedAtTheNextHeartbeat() throws Exception {
        SseEmitter emitter = mock(SseEmitter.class);
        MockHttpSession session = sessionIdleFor(Duration.ofMinutes(1), SESSION_TIMEOUT_SECONDS);
        relay.register(emitter, session);
        clearInvocations(emitter);
        // The tab stays open, the administrator does nothing more: the last activity becomes older than the timeout.
        AdminSessionActivity.record(session, Instant.now().minusSeconds(SESSION_TIMEOUT_SECONDS + 1));

        relay.heartbeat();

        assertEquals(0, relay.subscriberCount());
        verify(emitter).complete();
        verify(emitter, never()).send(any(SseEmitter.SseEventBuilder.class));
    }

    @Test
    void theStreamOfAnAdministratorActiveWithinTheTimeoutStaysOpen() throws Exception {
        SseEmitter emitter = mock(SseEmitter.class);
        relay.register(emitter, sessionIdleFor(Duration.ofMinutes(1), SESSION_TIMEOUT_SECONDS));
        clearInvocations(emitter);

        relay.heartbeat();

        assertEquals(1, relay.subscriberCount());
        verify(emitter).send(any(SseEmitter.SseEventBuilder.class));
    }

    @Test
    void theIdleLimitIsTheTimeoutOfTheSessionItself() throws Exception {
        SseEmitter shortSession = mock(SseEmitter.class);
        SseEmitter neverExpires = mock(SseEmitter.class);
        relay.register(shortSession, sessionIdleFor(Duration.ofSeconds(61), 60));
        relay.register(neverExpires, sessionIdleFor(Duration.ofDays(2), 0));

        relay.heartbeat();

        assertEquals(1, relay.subscriberCount());
        verify(shortSession).complete();
        verify(neverExpires, never()).complete();
    }

    @Test
    void shutdownCompletesAndForgetsEveryEmitter() {
        SseEmitter emitter = mock(SseEmitter.class);
        relay.register(emitter, null);

        relay.shutdown();

        verify(emitter).complete();
        assertEquals(0, relay.subscriberCount());
    }
}
