package vn.edu.huit.finance.core.Service.Realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import jakarta.servlet.http.HttpSession;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.lang.Nullable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter.SseEventBuilder;
import vn.edu.huit.finance.core.Security.AdminSessionActivity;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;

/**
 * The receiving half of the realtime admin events, one per instance of the API: it listens to the Redis channel
 * {@link AdminEventPublisher#CHANNEL} and forwards every event to the Server-Sent Events streams of the admin browsers
 * connected to this instance.
 * <p>
 * No emitter is ever leaked: completion, timeout and error remove it, so does a send that fails (the browser went away),
 * and so does a stream whose HTTP session has ended (sign-out or expiry) or has been idle past its timeout (see
 * {@link AdminSessionActivity}), which is closed at the next send or heartbeat at the latest. A message that is not an {@link AdminEvent} is dropped; what reaches the browser is always re-serialised
 * from the record, never the raw message.
 */
@Slf4j
@Component
public class AdminEventRelay implements MessageListener {

    public static final String EVENT_NAME = "admin";
    /** The browser opens a new stream after this; EventSource reconnects on its own. */
    static final Duration TIMEOUT = Duration.ofMinutes(30);
    /** How long the browser waits before it reconnects a dropped stream. */
    static final long RECONNECT_MILLIS = 5_000;
    private static final long HEARTBEAT_SECONDS = 25;
    private static final String COMMENT_CONNECTED = "connected";
    private static final String COMMENT_PING = "ping";

    private final ObjectMapper objectMapper;
    private final Map<SseEmitter, Subscriber> subscribers = new ConcurrentHashMap<>();

    public AdminEventRelay(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /** An open stream and the session it was opened in (null when there is none to watch). */
    private record Subscriber(SseEmitter emitter, @Nullable HttpSession session) {

        /** Signed out, expired, or idle past its timeout (the stream itself is no activity). */
        boolean sessionOver() {
            if (session == null) {
                return false;
            }
            try {
                return AdminSessionActivity.isIdle(session, Instant.now());
            } catch (IllegalStateException invalidated) {
                return true;
            }
        }
    }

    /** A new stream that lives at most {@link #TIMEOUT}. */
    public SseEmitter register() {
        return register((HttpSession) null);
    }

    /** A new stream that also ends with {@code session}. */
    public SseEmitter register(@Nullable HttpSession session) {
        return register(new SseEmitter(TIMEOUT.toMillis()), session);
    }

    SseEmitter register(SseEmitter emitter, @Nullable HttpSession session) {
        Subscriber subscriber = new Subscriber(emitter, session);
        emitter.onCompletion(() -> subscribers.remove(emitter));
        emitter.onTimeout(() -> {
            subscribers.remove(emitter);
            emitter.complete();
        });
        emitter.onError(error -> subscribers.remove(emitter));
        subscribers.put(emitter, subscriber);
        send(subscriber, () -> SseEmitter.event().reconnectTime(RECONNECT_MILLIS).comment(COMMENT_CONNECTED));
        return emitter;
    }

    public int subscriberCount() {
        return subscribers.size();
    }

    /** A message of the Redis channel: one admin event for every open stream of this instance. */
    @Override
    public void onMessage(Message message, @Nullable byte[] pattern) {
        String json;
        try {
            AdminEvent event = objectMapper.readValue(message.getBody(), AdminEvent.class);
            if (event == null || event.type() == null) {
                log.warn("Admin event dropped: no type");
                return;
            }
            json = objectMapper.writeValueAsString(event);
        } catch (IOException e) {
            log.warn("Admin event dropped: not an AdminEvent ({})", e.getClass().getSimpleName());
            return;
        }
        for (Subscriber subscriber : subscribers.values()) {
            send(subscriber, () -> SseEmitter.event().name(EVENT_NAME).data(json));
        }
    }

    /** A comment line keeps proxies from closing an idle stream and finds the streams whose browser has gone. */
    @Scheduled(fixedRate = HEARTBEAT_SECONDS, timeUnit = TimeUnit.SECONDS)
    public void heartbeat() {
        for (Subscriber subscriber : subscribers.values()) {
            send(subscriber, () -> SseEmitter.event().comment(COMMENT_PING));
        }
    }

    @PreDestroy
    public void shutdown() {
        for (SseEmitter emitter : subscribers.keySet()) {
            subscribers.remove(emitter);
            completeQuietly(emitter);
        }
    }

    /** A builder can be written once only, so every stream gets its own. */
    private void send(Subscriber subscriber, Supplier<SseEventBuilder> event) {
        SseEmitter emitter = subscriber.emitter();
        if (subscriber.sessionOver()) {
            subscribers.remove(emitter);
            completeQuietly(emitter);
            return;
        }
        try {
            emitter.send(event.get());
        } catch (IOException | IllegalStateException e) {
            // The browser went away (IOException) or the stream is already over: the container completes it, we forget it.
            subscribers.remove(emitter);
            log.debug("Admin event stream dropped: {}", e.toString());
        }
    }

    private static void completeQuietly(SseEmitter emitter) {
        try {
            emitter.complete();
        } catch (RuntimeException e) {
            log.debug("Admin event stream already closed: {}", e.toString());
        }
    }
}
