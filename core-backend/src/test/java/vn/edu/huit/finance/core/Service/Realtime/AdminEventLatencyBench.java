package vn.edu.huit.finance.core.Service.Realtime;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.data.redis.connection.RedisPassword;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.testcontainers.containers.GenericContainer;
import vn.edu.huit.finance.core.Config.RealtimeConfig;
import vn.edu.huit.finance.core.Config.RedisTestContainers;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * E6 of the NoSQL report (NFR-15): how long an admin event takes from {@link AdminEventPublisher#publish} to the
 * {@code send} of an SSE emitter, through the real {@link AdminEventPublisher}, the real {@link AdminEventRelay} with the
 * listener container of {@link RealtimeConfig}, and a real Redis started like the compose service. Server path only: the
 * write to the HTTP response and the hop to the browser are NOT measured.
 * <p>
 * A benchmark, not a test: skipped unless run with {@code -Dbench=true}
 * ({@code mvn test -Dtest=AdminEventLatencyBench -Dbench=true}). It prints a table and writes
 * {@code target/bench/E6.json}.
 */
@EnabledIfSystemProperty(named = "bench", matches = "true")
class AdminEventLatencyBench {

    private static final int WARM_UP = 20;
    private static final int MEASURED = 300;
    /** Events are spaced out so that each one is measured alone, not queued behind the previous one. */
    private static final long GAP_MILLIS = 10;
    private static final Duration WAIT = Duration.ofSeconds(10);

    /** An emitter without an HTTP response: it notes when the relay handed it each event (by the event's id). */
    static final class TimingEmitter extends SseEmitter {
        final Map<Long, Long> receivedAt = new ConcurrentHashMap<>();

        @Override
        public void send(SseEventBuilder builder) {
            long now = System.nanoTime();
            String frame = builder.build().stream().map(part -> String.valueOf(part.getData())).collect(Collectors.joining());
            if (!frame.startsWith("event:" + AdminEventRelay.EVENT_NAME + "\n")) {
                return; // the "connected" comment
            }
            int at = frame.indexOf("\"id\":");
            if (at < 0) {
                return;
            }
            int end = at + 5;
            while (end < frame.length() && (Character.isDigit(frame.charAt(end)) || frame.charAt(end) == '-')) {
                end++;
            }
            receivedAt.putIfAbsent(Long.parseLong(frame.substring(at + 5, end)), now);
        }
    }

    @Test
    void publishToEmitterLatency() throws Exception {
        try (GenericContainer<?> redisContainer = RedisTestContainers.newRedis()) {
            redisContainer.start();
            String redisVersion = redisContainer.execInContainer("redis-server", "--version").getStdout().trim();

            RedisStandaloneConfiguration configuration = new RedisStandaloneConfiguration(
                    redisContainer.getHost(), redisContainer.getMappedPort(RedisTestContainers.PORT));
            configuration.setPassword(RedisPassword.of(RedisTestContainers.PASSWORD));
            LettuceConnectionFactory factory = new LettuceConnectionFactory(configuration);
            factory.afterPropertiesSet();

            ObjectMapper mapper = Jackson2ObjectMapperBuilder.json()
                    .featuresToDisable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS).build();
            AdminEventRelay relay = new AdminEventRelay(mapper);
            var container = RealtimeConfig.listenerContainer(factory, relay, Duration.ofMillis(300));
            container.afterPropertiesSet();
            AdminEventSubscription subscription = new AdminEventSubscription(container, Duration.ofMillis(300));
            subscription.start();
            TimingEmitter emitter = new TimingEmitter();
            relay.register(emitter, null);
            AdminEventPublisher publisher = new AdminEventPublisher(new StringRedisTemplate(factory), mapper);

            try {
                // The subscription registers asynchronously: publish a probe until it arrives.
                long deadline = System.nanoTime() + WAIT.toNanos();
                while (!emitter.receivedAt.containsKey(0L) && System.nanoTime() < deadline) {
                    publisher.publish(AdminEvent.receiptWaitingReview(0L));
                    Thread.sleep(100);
                }
                assertTrue(emitter.receivedAt.containsKey(0L), "the subscription never came up");

                int total = WARM_UP + MEASURED;
                long[] publishedAt = new long[total + 1];
                long[] publishCallNanos = new long[total + 1];
                for (int i = 1; i <= total; i++) {
                    AdminEvent event = AdminEvent.receiptWaitingReview(i);
                    long t0 = System.nanoTime();
                    publisher.publish(event);
                    publishCallNanos[i] = System.nanoTime() - t0;
                    publishedAt[i] = t0;
                    Thread.sleep(GAP_MILLIS);
                }
                deadline = System.nanoTime() + WAIT.toNanos();
                while (emitter.receivedAt.size() < total + 1 && System.nanoTime() < deadline) {
                    Thread.sleep(50);
                }

                List<Double> latencies = new ArrayList<>();
                List<Double> calls = new ArrayList<>();
                int lost = 0;
                for (int i = WARM_UP + 1; i <= total; i++) {
                    Long received = emitter.receivedAt.get((long) i);
                    calls.add(publishCallNanos[i] / 1e6);
                    if (received == null) {
                        lost++;
                    } else {
                        latencies.add((received - publishedAt[i]) / 1e6);
                    }
                }
                double[] sorted = latencies.stream().mapToDouble(Double::doubleValue).sorted().toArray();
                double[] callsSorted = calls.stream().mapToDouble(Double::doubleValue).sorted().toArray();
                double mean = Arrays.stream(sorted).average().orElse(Double.NaN);

                String table = String.join("\n",
                        "E6 realtime latency: AdminEventPublisher.publish -> Redis PUBLISH -> AdminEventRelay -> SseEmitter.send",
                        "Redis: " + redisVersion,
                        "Java: " + System.getProperty("java.version") + ", " + Instant.now(),
                        String.format(Locale.ROOT, "events: %d measured (+%d warm-up, +probe), gap %d ms, 1 publisher thread, 1 emitter",
                                MEASURED, WARM_UP, GAP_MILLIS),
                        "+----------------------------+--------+--------+--------+--------+--------+------+",
                        "| path (ms)                  |    p50 |    p95 |    p99 |    max |   mean | lost |",
                        "+----------------------------+--------+--------+--------+--------+--------+------+",
                        String.format(Locale.ROOT, "| publish -> emitter.send    | %6.3f | %6.3f | %6.3f | %6.3f | %6.3f | %4d |",
                                rank(sorted, 50), rank(sorted, 95), rank(sorted, 99), sorted[sorted.length - 1], mean, lost),
                        String.format(Locale.ROOT, "| publish() call (sender)    | %6.3f | %6.3f | %6.3f | %6.3f | %6.3f |    - |",
                                rank(callsSorted, 50), rank(callsSorted, 95), rank(callsSorted, 99),
                                callsSorted[callsSorted.length - 1], Arrays.stream(callsSorted).average().orElse(Double.NaN)),
                        "+----------------------------+--------+--------+--------+--------+--------+------+",
                        String.format(Locale.ROOT, "NFR-15 target < 1000 ms (server path only, browser hop not measured): %s",
                                lost == 0 && rank(sorted, 95) < 1000 ? "MET" : "NOT MET"));
                System.out.println("\n" + table + "\n");

                Path out = Path.of("target", "bench");
                Files.createDirectories(out);
                String json = String.format(Locale.ROOT,
                        "{\"experiment\":\"E6\",\"redis\":\"%s\",\"java\":\"%s\",\"at\":\"%s\",\"measured\":%d,\"warmUp\":%d,"
                                + "\"gapMillis\":%d,\"received\":%d,\"lost\":%d,\"p50\":%.4f,\"p95\":%.4f,\"p99\":%.4f,"
                                + "\"max\":%.4f,\"min\":%.4f,\"mean\":%.4f,\"publishCallP50\":%.4f,\"publishCallP95\":%.4f,"
                                + "\"latenciesMs\":%s}",
                        redisVersion.replace("\"", "'"), System.getProperty("java.version"), Instant.now(), MEASURED, WARM_UP,
                        GAP_MILLIS, sorted.length, lost, rank(sorted, 50), rank(sorted, 95), rank(sorted, 99),
                        sorted[sorted.length - 1], sorted[0], mean, rank(callsSorted, 50), rank(callsSorted, 95),
                        latencies.stream().map(v -> String.format(Locale.ROOT, "%.4f", v)).collect(Collectors.joining(",", "[", "]")));
                Files.writeString(out.resolve("E6.json"), json, StandardCharsets.UTF_8);
                Files.writeString(out.resolve("E6.txt"), table + "\n", StandardCharsets.UTF_8);
            } finally {
                subscription.stop();
                container.destroy();
                relay.shutdown();
                factory.destroy();
            }
        }
    }

    /** Nearest-rank percentile of an ascending array. */
    private static double rank(double[] sorted, int percentile) {
        int index = (int) Math.ceil(percentile / 100.0 * sorted.length) - 1;
        return sorted[Math.max(0, Math.min(sorted.length - 1, index))];
    }
}
