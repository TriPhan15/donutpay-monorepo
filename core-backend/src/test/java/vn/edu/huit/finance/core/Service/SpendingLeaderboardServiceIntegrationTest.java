package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.RedisPassword;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Config.RedisTestContainers;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * The leaderboard on a real Redis (Testcontainers), started like the redis service of docker-compose.yml, with the
 * repositories mocked: what is checked is what ends up in the sorted set. Each test uses a month of its own so the sets
 * of two tests never meet.
 */
@Testcontainers(disabledWithoutDocker = true)
class SpendingLeaderboardServiceIntegrationTest {

    @Container
    private static final GenericContainer<?> REDIS = RedisTestContainers.newRedis();

    private static final Duration TTL = Duration.ofDays(62);
    private static final long FIRST_YEAR = 2100;

    private static LettuceConnectionFactory connectionFactory;
    private static StringRedisTemplate redis;
    private static long monthCounter;

    private final TransactionRepository transactionRepo = mock(TransactionRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private SpendingLeaderboardService service;
    private YearMonth month;
    private String key;

    @BeforeAll
    static void connect() {
        RedisStandaloneConfiguration configuration = new RedisStandaloneConfiguration(
                REDIS.getHost(), REDIS.getMappedPort(RedisTestContainers.PORT));
        configuration.setPassword(RedisPassword.of(RedisTestContainers.PASSWORD));
        connectionFactory = new LettuceConnectionFactory(configuration);
        connectionFactory.afterPropertiesSet();
        redis = new StringRedisTemplate(connectionFactory);
    }

    @AfterAll
    static void disconnect() {
        connectionFactory.destroy();
    }

    @BeforeEach
    void aMonthOfItsOwn() {
        month = YearMonth.of((int) FIRST_YEAR, 1).plusMonths(monthCounter++);
        key = SpendingLeaderboardService.keyOf(month);
        service = new SpendingLeaderboardService(redis, transactionRepo, userRepo, TTL);
    }

    private static User user(long id, String username) {
        User user = new User();
        user.setId(id);
        user.setUsername(username);
        return user;
    }

    private static Object[] row(long userId, String username, String total) {
        return new Object[]{userId, username, new BigDecimal(total)};
    }

    private void postgresHoldsAnAndBinh() {
        when(transactionRepo.sumExpensesByUserBetween(any(), any())).thenReturn(List.<Object[]>of(
                row(2, "binh", "500000"), row(1, "an", "300000")));
        when(userRepo.findAllById(anyCollection())).thenReturn(List.of(user(1, "an"), user(2, "binh")));
    }

    private static LocalDateTime startOf(YearMonth month) {
        return month.atDay(1).atStartOfDay();
    }

    @Test
    void keyOf_isTheMonthUnderTheLeaderboardPrefix() {
        assertEquals("ledgermind:leaderboard:spend:2026-10", SpendingLeaderboardService.keyOf(YearMonth.of(2026, 10)));
    }

    @Test
    void topSpenders_missingKey_rebuildsFromPostgresAndSetsTtl() {
        postgresHoldsAnAndBinh();

        List<TopSpenderDto> top = service.topSpenders(month, 10);

        assertEquals(List.of("binh", "an"), top.stream().map(TopSpenderDto::getUsername).toList());
        assertEquals(List.of(2L, 1L), top.stream().map(TopSpenderDto::getUserId).toList());
        assertEquals(0, new BigDecimal("500000").compareTo(top.get(0).getTotalSpent()));
        assertEquals(2L, redis.opsForZSet().zCard(key));
        Long secondsLeft = redis.getExpire(key, TimeUnit.SECONDS);
        assertNotNull(secondsLeft);
        assertTrue(secondsLeft > 0 && secondsLeft <= TTL.toSeconds(), "ttl was " + secondsLeft);
        verify(transactionRepo).sumExpensesByUserBetween(startOf(month), startOf(month.plusMonths(1)));
    }

    @Test
    void topSpenders_limitCutsTheList() {
        postgresHoldsAnAndBinh();

        List<TopSpenderDto> top = service.topSpenders(month, 1);

        assertEquals(List.of("binh"), top.stream().map(TopSpenderDto::getUsername).toList());
    }

    @Test
    void topSpenders_existingKey_doesNotQueryPostgres() {
        postgresHoldsAnAndBinh();

        service.topSpenders(month, 10);
        service.topSpenders(month, 10);

        verify(transactionRepo, times(1)).sumExpensesByUserBetween(any(), any());
    }

    @Test
    void topSpenders_monthWithoutExpenses_isEmptyAndWritesNothing() {
        when(transactionRepo.sumExpensesByUserBetween(any(), any())).thenReturn(List.of());

        assertEquals(List.of(), service.topSpenders(month, 10));

        assertEquals(Boolean.FALSE, redis.hasKey(key));
    }

    @Test
    void topSpenders_usernamesLoadedInOneQuery() {
        postgresHoldsAnAndBinh();

        service.topSpenders(month, 10);

        verify(userRepo, times(1)).findAllById(anyCollection());
    }

    @Test
    void onTransactionChanged_setsAbsoluteMonthlyTotal() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);
        when(transactionRepo.sumSpendingBetween(eq(1L), eq(startOf(month)), eq(startOf(month.plusMonths(1)))))
                .thenReturn(new BigDecimal("450000"));

        service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of(month)));
        service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of(month)));

        assertEquals(450000.0, redis.opsForZSet().score(key, "1"));
    }

    @Test
    void onTransactionChanged_totalZero_removesMember() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);
        when(transactionRepo.sumSpendingBetween(eq(1L), any(), any())).thenReturn(null);

        service.onTransactionChanged(TransactionChangedEvent.deleted(10L, 1L, Set.of(month)));

        assertNull(redis.opsForZSet().score(key, "1"));
        assertEquals(1L, redis.opsForZSet().zCard(key));
    }

    @Test
    void onTransactionChanged_dateMovedAcrossMonths_recomputesBothMonths() {
        YearMonth next = month.plusMonths(1);
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);
        service.topSpenders(next, 10);
        when(transactionRepo.sumSpendingBetween(eq(1L), eq(startOf(month)), any())).thenReturn(new BigDecimal("100000"));
        when(transactionRepo.sumSpendingBetween(eq(1L), eq(startOf(next)), any())).thenReturn(new BigDecimal("200000"));

        service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of(month, next)));

        assertEquals(100000.0, redis.opsForZSet().score(key, "1"));
        assertEquals(200000.0, redis.opsForZSet().score(SpendingLeaderboardService.keyOf(next), "1"));
    }

    @Test
    void onTransactionChanged_missingKey_leavesItMissing() {
        service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of(month)));

        assertEquals(Boolean.FALSE, redis.hasKey(key));
        verifyNoInteractions(transactionRepo);
    }

    @Test
    void onTransactionChanged_keyExpiresWhileTheTotalIsRead_isNotCreatedAgain() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);
        // The set expires (or is dropped by a restore) after the check and before the write.
        when(transactionRepo.sumSpendingBetween(eq(1L), any(), any())).thenAnswer(invocation -> {
            redis.delete(key);
            return new BigDecimal("450000");
        });

        service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of(month)));

        // A one-member set without a TTL would hide everybody else until it is dropped by hand.
        assertEquals(Boolean.FALSE, redis.hasKey(key));
    }

    @Test
    void onTransactionChanged_noExpenseMonths_doesNothing() {
        service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of()));

        verifyNoInteractions(transactionRepo);
    }

    @Test
    void databaseRestored_dropsEveryMonthWithScanAndTheNextReadRebuilds() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);
        service.topSpenders(month.plusMonths(1), 10);
        redis.opsForValue().set("ledgermind:other:key", "stays");

        service.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.DATABASE_RESTORED));

        assertEquals(Boolean.FALSE, redis.hasKey(key));
        assertEquals(Boolean.FALSE, redis.hasKey(SpendingLeaderboardService.keyOf(month.plusMonths(1))));
        assertEquals("stays", redis.opsForValue().get("ledgermind:other:key"));
        service.topSpenders(month, 10);
        verify(transactionRepo, times(3)).sumExpensesByUserBetween(any(), any());
        assertEquals(2L, redis.opsForZSet().zCard(key));
    }

    @Test
    void accountDeleted_dropsEveryMonth() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);

        service.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.ACCOUNT_DELETED, 1L));

        assertEquals(Boolean.FALSE, redis.hasKey(key));
    }

    @Test
    void otherStatisticsChanges_leaveTheLeaderboardAlone() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);

        service.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.TRANSACTION_TOTALS, 1L));
        service.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.ACCOUNT_PROFILE, 1L));

        assertEquals(Boolean.TRUE, redis.hasKey(key));
    }

    @Test
    void rebuildMonth_replacesAStaleSetFromPostgres() {
        postgresHoldsAnAndBinh();
        service.topSpenders(month, 10);
        redis.opsForZSet().add(key, "1", 1.0);
        redis.opsForZSet().add(key, "99", 5.0);

        int members = service.rebuildMonth(month);

        assertEquals(2, members);
        assertEquals(300000.0, redis.opsForZSet().score(key, "1"));
        assertNull(redis.opsForZSet().score(key, "99"));
        Long secondsLeft = redis.getExpire(key, TimeUnit.SECONDS);
        assertTrue(secondsLeft != null && secondsLeft > 0 && secondsLeft <= TTL.toSeconds());
    }
}
