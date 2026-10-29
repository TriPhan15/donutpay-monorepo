package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.YearMonth;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** The leaderboard when Redis is down: reads answer from PostgreSQL, writes only log. */
class SpendingLeaderboardServiceTest {

    private static final YearMonth OCTOBER = YearMonth.of(2026, 10);

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final TransactionRepository transactionRepo = mock(TransactionRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final SpendingLeaderboardService service =
            new SpendingLeaderboardService(redis, transactionRepo, userRepo, Duration.ofDays(62));

    private void redisIsDown() {
        when(redis.hasKey(any(String.class))).thenThrow(new RedisConnectionFailureException("Unable to connect to Redis"));
    }

    @Test
    void topSpenders_redisDown_answersFromPostgres() {
        redisIsDown();
        when(transactionRepo.sumExpensesByUserBetween(any(), any())).thenReturn(List.<Object[]>of(
                new Object[]{2L, "binh", new BigDecimal("500000")},
                new Object[]{1L, "an", new BigDecimal("300000")},
                new Object[]{3L, "chi", new BigDecimal("100000")}));

        List<TopSpenderDto> top = service.topSpenders(OCTOBER, 2);

        assertEquals(List.of("binh", "an"), top.stream().map(TopSpenderDto::getUsername).toList());
        assertEquals(List.of(2L, 1L), top.stream().map(TopSpenderDto::getUserId).toList());
        assertEquals(new BigDecimal("500000"), top.get(0).getTotalSpent());
        verifyNoInteractions(userRepo);
    }

    @Test
    void onTransactionChanged_redisDown_isOnlyLogged() {
        redisIsDown();

        assertDoesNotThrow(() -> service.onTransactionChanged(TransactionChangedEvent.upserted(10L, 1L, Set.of(OCTOBER))));

        verifyNoInteractions(transactionRepo);
    }

    @Test
    void topSpenders_postgresFailsDuringRebuild_propagatesInsteadOfBeingTakenForRedis() {
        when(redis.hasKey(any(String.class))).thenReturn(false);
        when(transactionRepo.sumExpensesByUserBetween(any(), any())).thenThrow(new DataAccessResourceFailureException("pg down"));

        assertThrows(DataAccessResourceFailureException.class, () -> service.topSpenders(OCTOBER, 5));

        verify(transactionRepo, times(1)).sumExpensesByUserBetween(any(), any());
    }

    @Test
    void dropAllMonths_redisDown_isOnlyLogged() {
        when(redis.scan(any())).thenThrow(new RedisConnectionFailureException("Unable to connect to Redis"));

        assertDoesNotThrow(service::dropAllMonths);
    }
}
