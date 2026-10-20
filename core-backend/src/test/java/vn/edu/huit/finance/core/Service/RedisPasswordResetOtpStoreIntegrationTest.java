package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration;
import org.springframework.boot.test.context.assertj.AssertableApplicationContext;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Config.RedisTestContainers;
import vn.edu.huit.finance.core.Exception.OtpStoreUnavailableException;
import vn.edu.huit.finance.core.Service.PasswordResetOtpStore.OtpCheck;
import vn.edu.huit.finance.core.Service.PasswordResetOtpStore.Outcome;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

/**
 * The OTP store on a real Redis (Testcontainers), started like the redis service of docker-compose.yml: the Lua scripts
 * are what make a check atomic, and only a real Redis runs them. Each test uses an email of its own.
 */
@Testcontainers(disabledWithoutDocker = true)
class RedisPasswordResetOtpStoreIntegrationTest {

    @Container
    private static final GenericContainer<?> REDIS = RedisTestContainers.newRedis();

    private static final String CODE = "123456";
    private static final String WRONG_CODE = "000000";
    private static final Instant ISSUED_AT = Instant.parse("2026-01-01T10:00:00Z");
    private static final Duration VALIDITY = Duration.ofMinutes(5);
    private static final int MAX_FAILED_ATTEMPTS = 3;
    private static final int PARALLEL_GUESSES = 40;
    private static final int PARALLEL_ROUNDS = 10;

    private String email;

    @BeforeEach
    void anEmailOfItsOwn() {
        email = "it-" + UUID.randomUUID() + "@example.com";
    }

    private static ApplicationContextRunner api(String... properties) {
        return new ApplicationContextRunner()
                .withConfiguration(AutoConfigurations.of(RedisAutoConfiguration.class))
                .withUserConfiguration(RedisPasswordResetOtpStore.class)
                .withPropertyValues(properties);
    }

    private static ApplicationContextRunner api() {
        return api(RedisTestContainers.connectionProperties(REDIS));
    }

    private static PasswordResetOtpStore store(AssertableApplicationContext context) {
        return context.getBean(PasswordResetOtpStore.class);
    }

    private OtpCheck guess(PasswordResetOtpStore store, String code, Instant now) {
        return store.check(email, code, now, MAX_FAILED_ATTEMPTS);
    }

    @Test
    void theRightCodeIsAcceptedOnce_andCannotBeReplayed() {
        api().run(context -> {
            PasswordResetOtpStore store = store(context);
            store.save(email, CODE, ISSUED_AT, VALIDITY);

            assertEquals(OtpCheck.accepted(), guess(store, CODE, ISSUED_AT));
            assertEquals(OtpCheck.notPending(), guess(store, CODE, ISSUED_AT));
        });
    }

    @Test
    void wrongGuessesCountUp_andTheThirdDropsTheOtp_soEvenTheRightCodeIsRefusedAfterwards() {
        api().run(context -> {
            PasswordResetOtpStore store = store(context);
            store.save(email, CODE, ISSUED_AT, VALIDITY);

            assertEquals(new OtpCheck(Outcome.WRONG, 1), guess(store, WRONG_CODE, ISSUED_AT));
            assertEquals(new OtpCheck(Outcome.WRONG, 2), guess(store, WRONG_CODE, ISSUED_AT));
            assertEquals(new OtpCheck(Outcome.ATTEMPTS_EXHAUSTED, 3), guess(store, WRONG_CODE, ISSUED_AT));
            assertEquals(OtpCheck.notPending(), guess(store, CODE, ISSUED_AT));
        });
    }

    @Test
    void theOtpIsValidUntilItsExpiryInstantIncluded() {
        api().run(context -> {
            PasswordResetOtpStore store = store(context);
            store.save(email, CODE, ISSUED_AT, VALIDITY);

            assertEquals(OtpCheck.accepted(), guess(store, CODE, ISSUED_AT.plus(VALIDITY)));
        });
    }

    @Test
    void anExpiredOtpIsRefusedEvenWithTheRightCode_andDropped() {
        api().run(context -> {
            PasswordResetOtpStore store = store(context);
            store.save(email, CODE, ISSUED_AT, VALIDITY);

            assertEquals(OtpCheck.notPending(), guess(store, CODE, ISSUED_AT.plus(VALIDITY).plusMillis(1)));
            // Dropped, not just refused: a check from inside the validity window does not revive it.
            assertEquals(OtpCheck.notPending(), guess(store, CODE, ISSUED_AT));
            assertFalse(context.getBean(StringRedisTemplate.class).hasKey(RedisPasswordResetOtpStore.KEY_PREFIX + email));
        });
    }

    @Test
    void anOtpThatWasNeverSavedIsNotPending() {
        api().run(context -> assertEquals(OtpCheck.notPending(), guess(store(context), CODE, ISSUED_AT)));
    }

    @Test
    void aNewOtpReplacesThePendingOne_andStartsTheFailedAttemptsOver() {
        api().run(context -> {
            PasswordResetOtpStore store = store(context);
            store.save(email, WRONG_CODE, ISSUED_AT, VALIDITY);
            guess(store, CODE, ISSUED_AT);
            guess(store, CODE, ISSUED_AT);

            store.save(email, CODE, ISSUED_AT, VALIDITY);

            assertEquals(new OtpCheck(Outcome.WRONG, 1), guess(store, WRONG_CODE + "1", ISSUED_AT));
            assertEquals(OtpCheck.accepted(), guess(store, CODE, ISSUED_AT));
        });
    }

    @Test
    void theKeyExpiresInRedisAfterTheValidity_soForgottenOtpsDoNotPileUp() {
        api().run(context -> {
            store(context).save(email, CODE, ISSUED_AT, VALIDITY);

            Long ttl = context.getBean(StringRedisTemplate.class)
                    .getExpire(RedisPasswordResetOtpStore.KEY_PREFIX + email, TimeUnit.SECONDS);
            assertNotNull(ttl);
            assertTrue(ttl > 0 && ttl <= VALIDITY.toSeconds(), "TTL was " + ttl);
        });
    }

    @Test
    void onlyThreeWrongGuessesAreEverWeighed_evenWhenTheyArriveInParallelOnTwoInstances() {
        api().run(first -> api().run(second -> {
            List<PasswordResetOtpStore> instances = List.of(store(first), store(second));
            ExecutorService pool = Executors.newFixedThreadPool(PARALLEL_GUESSES);
            try {
                // Repeated: whether a race shows up is a matter of timing, so one round proves little.
                for (int round = 0; round < PARALLEL_ROUNDS; round++) {
                    instances.get(0).save(email, CODE, ISSUED_AT, VALIDITY);
                    CountDownLatch startGate = new CountDownLatch(1);
                    List<Future<OtpCheck>> futures = new ArrayList<>();
                    for (int i = 0; i < PARALLEL_GUESSES; i++) {
                        PasswordResetOtpStore instance = instances.get(i % instances.size());
                        String wrongCode = WRONG_CODE + "-" + i;
                        futures.add(pool.submit(() -> {
                            startGate.await();
                            return guess(instance, wrongCode, ISSUED_AT);
                        }));
                    }
                    startGate.countDown();
                    List<OtpCheck> checks = new ArrayList<>();
                    for (Future<OtpCheck> future : futures) {
                        checks.add(future.get(10, TimeUnit.SECONDS));
                    }

                    assertEquals(1, Collections.frequency(checks, new OtpCheck(Outcome.WRONG, 1)), "round " + round);
                    assertEquals(1, Collections.frequency(checks, new OtpCheck(Outcome.WRONG, 2)), "round " + round);
                    assertEquals(1, Collections.frequency(checks, new OtpCheck(Outcome.ATTEMPTS_EXHAUSTED, 3)),
                            "round " + round);
                    assertEquals(PARALLEL_GUESSES - MAX_FAILED_ATTEMPTS,
                            Collections.frequency(checks, OtpCheck.notPending()), "round " + round);
                    assertEquals(OtpCheck.notPending(), guess(instances.get(1), CODE, ISSUED_AT), "round " + round);
                }
            } finally {
                pool.shutdownNow();
            }
        }));
    }

    @Test
    void anUnreachableRedisFailsWithAFixedMessage_andNeitherTheOtpNorTheEmailInIt() {
        // Nothing listens on port 1: the connection is refused at once.
        api("spring.data.redis.host=127.0.0.1", "spring.data.redis.port=1",
                "spring.data.redis.connect-timeout=500ms", "spring.data.redis.timeout=500ms").run(context -> {
            PasswordResetOtpStore store = store(context);

            OtpStoreUnavailableException onSave = assertThrows(OtpStoreUnavailableException.class,
                    () -> store.save(email, CODE, ISSUED_AT, VALIDITY));
            OtpStoreUnavailableException onCheck = assertThrows(OtpStoreUnavailableException.class,
                    () -> guess(store, CODE, ISSUED_AT));

            for (OtpStoreUnavailableException e : List.of(onSave, onCheck)) {
                assertEquals("Dịch vụ mã OTP tạm thời gián đoạn. Vui lòng thử lại sau ít phút.", e.getMessage());
                assertFalse(e.getMessage().contains(CODE));
                assertFalse(e.getMessage().contains(email));
            }
        });
    }
}
