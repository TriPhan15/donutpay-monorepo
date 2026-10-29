package vn.edu.huit.finance.core.Service.Realtime;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.RedisPassword;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Config.RealtimeConfig;
import vn.edu.huit.finance.core.Config.RedisTestContainers;

import java.io.IOException;
import java.net.ServerSocket;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Redis Pub/Sub between instances of the API, on a real Redis started like the redis service of docker-compose.yml: an
 * event published once reaches the emitters of every instance (each instance is one relay with its own listener
 * container), and an instance that starts while Redis is down neither fails nor stays deaf once Redis is back.
 */
@Testcontainers(disabledWithoutDocker = true)
class AdminEventRelayIntegrationTest {

    @Container
    private static final GenericContainer<?> REDIS = RedisTestContainers.newRedis();

    private static final Duration WAIT = Duration.ofSeconds(10);
    private static final Duration RETRY = Duration.ofMillis(300);
    /** How long a message of another channel is given to (wrongly) show up after the admin one arrived. */
    private static final Duration OFF_CHANNEL_GRACE = Duration.ofMillis(300);

    private static LettuceConnectionFactory connectionFactory;
    private static StringRedisTemplate redis;

    // Like the ObjectMapper Spring Boot gives the application: Instant as ISO-8601 text.
    private final ObjectMapper mapper = Jackson2ObjectMapperBuilder.json()
            .featuresToDisable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS).build();
    private final List<AutoCloseable> toClose = new ArrayList<>();

    /** An emitter without an HTTP response: it keeps what would have been written to the browser. */
    static final class RecordingEmitter extends SseEmitter {
        final List<String> frames = new CopyOnWriteArrayList<>();

        @Override
        public void send(SseEventBuilder builder) {
            frames.add(builder.build().stream().map(part -> String.valueOf(part.getData())).collect(Collectors.joining()));
        }

        List<String> adminFrames() {
            return frames.stream().filter(frame -> frame.startsWith("event:admin\n")).toList();
        }
    }

    @BeforeAll
    static void connect() {
        connectionFactory = factoryFor(REDIS.getHost(), REDIS.getMappedPort(RedisTestContainers.PORT));
        redis = new StringRedisTemplate(connectionFactory);
    }

    @AfterAll
    static void disconnect() {
        connectionFactory.destroy();
    }

    @AfterEach
    void closeEverything() throws Exception {
        // Last opened, first closed: the subscription stops before its connection factory goes away.
        for (int i = toClose.size() - 1; i >= 0; i--) {
            toClose.get(i).close();
        }
    }

    private static LettuceConnectionFactory factoryFor(String host, int port) {
        RedisStandaloneConfiguration configuration = new RedisStandaloneConfiguration(host, port);
        configuration.setPassword(RedisPassword.of(RedisTestContainers.PASSWORD));
        LettuceConnectionFactory factory = new LettuceConnectionFactory(configuration);
        factory.afterPropertiesSet();
        return factory;
    }

    /** One "instance" of the API: a relay subscribed to the channel through a listener container of its own. */
    private AdminEventRelay instance(LettuceConnectionFactory factory) throws Exception {
        AdminEventRelay relay = new AdminEventRelay(mapper);
        var container = RealtimeConfig.listenerContainer(factory, relay, RETRY);
        container.afterPropertiesSet();
        AdminEventSubscription subscription = new AdminEventSubscription(container, RETRY);
        subscription.start();
        toClose.add(() -> {
            subscription.stop();
            container.destroy();
            relay.shutdown();
        });
        return relay;
    }

    private static void awaitListening(AdminEventSubscription subscription) throws InterruptedException {
        long deadline = System.nanoTime() + WAIT.toNanos();
        while (!subscription.isListening() && System.nanoTime() < deadline) {
            Thread.sleep(50);
        }
        assertTrue(subscription.isListening(), "the subscription never came up");
    }

    /** Publishes until every emitter got at least one event (a subscription may still be registering). */
    private void publishUntilReceived(AdminEventPublisher publisher, AdminEvent event, RecordingEmitter... emitters)
            throws InterruptedException {
        long deadline = System.nanoTime() + WAIT.toNanos();
        while (System.nanoTime() < deadline) {
            boolean all = true;
            for (RecordingEmitter emitter : emitters) {
                all &= !emitter.adminFrames().isEmpty();
            }
            if (all) {
                return;
            }
            publisher.publish(event);
            Thread.sleep(100);
        }
        fail("not every emitter received the event");
    }

    private JsonNode dataOf(String frame) throws IOException {
        String data = frame.substring(frame.indexOf("data:") + "data:".length()).trim();
        return mapper.readTree(data);
    }

    @Test
    void anEventPublishedOnceReachesTheEmittersOfBothInstances() throws Exception {
        AdminEventRelay first = instance(connectionFactory);
        AdminEventRelay second = instance(connectionFactory);
        RecordingEmitter onFirst = new RecordingEmitter();
        RecordingEmitter onSecond = new RecordingEmitter();
        first.register(onFirst, null);
        second.register(onSecond, null);
        AdminEventPublisher publisher = new AdminEventPublisher(redis, mapper);

        publishUntilReceived(publisher, AdminEvent.of(AdminEventType.RECEIPT_WAITING_REVIEW, 41L, "Hóa đơn #41 đang chờ duyệt"),
                onFirst, onSecond);

        for (RecordingEmitter emitter : List.of(onFirst, onSecond)) {
            JsonNode data = dataOf(emitter.adminFrames().get(0));
            assertEquals("RECEIPT_WAITING_REVIEW", data.get("type").asText());
            assertEquals(41L, data.get("id").asLong());
            assertEquals("Hóa đơn #41 đang chờ duyệt", data.get("message").asText());
        }
    }

    @Test
    void theRelayForwardsOnlyMessagesOfTheAdminChannel() throws Exception {
        AdminEventRelay relay = instance(connectionFactory);
        RecordingEmitter emitter = new RecordingEmitter();
        relay.register(emitter, null);
        AdminEventPublisher publisher = new AdminEventPublisher(redis, mapper);
        publishUntilReceived(publisher, AdminEvent.searchReindexed(3), emitter);

        redis.convertAndSend("ledgermind:something-else",
                mapper.writeValueAsString(AdminEvent.searchReindexed(99)));
        publisher.publish(AdminEvent.leaderboardRebuilt(java.time.YearMonth.of(2026, 9), 4));

        // Messages are dispatched on threads of their own, so frames may arrive in any order: wait for the one wanted.
        long deadline = System.nanoTime() + WAIT.toNanos();
        while (emitter.adminFrames().stream().noneMatch(frame -> frame.contains("LEADERBOARD_REBUILT"))
                && System.nanoTime() < deadline) {
            Thread.sleep(50);
        }
        Thread.sleep(OFF_CHANNEL_GRACE.toMillis());
        List<String> frames = emitter.adminFrames();
        assertTrue(frames.stream().anyMatch(frame -> frame.contains("LEADERBOARD_REBUILT")), frames.toString());
        assertTrue(frames.stream().noneMatch(frame -> frame.contains("99 giao")), frames.toString());
    }

    @Test
    void anInstanceStartedWhileRedisIsDownStartsAnywayAndSubscribesOnceRedisIsUp() throws Exception {
        int port;
        try (ServerSocket socket = new ServerSocket(0)) {
            port = socket.getLocalPort();
        }
        LettuceConnectionFactory lateFactory = factoryFor("localhost", port);
        toClose.add(lateFactory::destroy);
        AdminEventRelay relay = new AdminEventRelay(mapper);
        var container = RealtimeConfig.listenerContainer(lateFactory, relay, RETRY);
        container.afterPropertiesSet();
        AdminEventSubscription subscription = new AdminEventSubscription(container, RETRY);
        toClose.add(() -> {
            subscription.stop();
            container.destroy();
        });

        assertDoesNotThrow(subscription::start, "Redis down must not stop the application from starting");
        Thread.sleep(RETRY.toMillis() * 3);
        assertFalse(subscription.isListening());
        assertTrue(subscription.isRunning());

        GenericContainer<?> lateRedis = RedisTestContainers.newRedis();
        lateRedis.setPortBindings(List.of(port + ":" + RedisTestContainers.PORT));
        lateRedis.start();
        toClose.add(lateRedis::stop);

        awaitListening(subscription);
        RecordingEmitter emitter = new RecordingEmitter();
        relay.register(emitter, null);
        publishUntilReceived(new AdminEventPublisher(new StringRedisTemplate(lateFactory), mapper),
                AdminEvent.searchReindexed(1), emitter);
    }
}
