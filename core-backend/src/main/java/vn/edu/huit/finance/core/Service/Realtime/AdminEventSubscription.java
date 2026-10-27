package vn.edu.huit.finance.core.Service.Realtime;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.SmartLifecycle;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;

import java.time.Duration;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Starts the Redis subscription of the admin events without ever making Redis a requirement of the application.
 * <p>
 * {@link RedisMessageListenerContainer#start()} throws when Redis cannot be reached at that moment, which would fail the
 * start of the whole application, and it never tries again on its own after such a first failure. So the container is
 * not started by Spring (auto-startup off) but here, on a thread of its own: a failed attempt is logged and repeated
 * after {@code retryDelay} until it succeeds or the application stops. Once subscribed, the container recovers by itself
 * from a later Redis outage (its recovery back-off, set in RealtimeConfig). Meanwhile admin pages work without toasts.
 */
@Slf4j
public class AdminEventSubscription implements SmartLifecycle {

    private static final String THREAD_NAME = "admin-events-subscriber";

    private final RedisMessageListenerContainer container;
    private final Duration retryDelay;
    private volatile ScheduledExecutorService scheduler;
    private volatile boolean running;

    public AdminEventSubscription(RedisMessageListenerContainer container, Duration retryDelay) {
        this.container = container;
        this.retryDelay = retryDelay;
    }

    @Override
    public synchronized void start() {
        if (running) {
            return;
        }
        running = true;
        scheduler = Executors.newSingleThreadScheduledExecutor(task -> {
            Thread thread = new Thread(task, THREAD_NAME);
            thread.setDaemon(true);
            return thread;
        });
        scheduler.execute(this::subscribe);
    }

    private void subscribe() {
        if (!running) {
            return;
        }
        try {
            container.start();
            log.info("Admin events: subscribed to Redis channel {}", AdminEventPublisher.CHANNEL);
        } catch (RuntimeException e) {
            log.warn("Admin events: Redis subscription failed, retrying in {} ms: {}", retryDelay.toMillis(), e.toString());
            // A failed start leaves the container marked as started: stop it so that the next start() really subscribes.
            try {
                container.stop();
            } catch (RuntimeException stopFailure) {
                log.debug("Admin events: stopping the failed subscription: {}", stopFailure.toString());
            }
            ScheduledExecutorService current = scheduler;
            if (running && current != null && !current.isShutdown()) {
                current.schedule(this::subscribe, retryDelay.toMillis(), TimeUnit.MILLISECONDS);
            }
        }
    }

    @Override
    public synchronized void stop() {
        running = false;
        ScheduledExecutorService current = scheduler;
        if (current != null) {
            current.shutdownNow();
        }
        container.stop();
    }

    @Override
    public boolean isRunning() {
        return running;
    }

    /** Whether the Redis subscription is up right now. */
    public boolean isListening() {
        return container.isListening();
    }
}
