package vn.edu.huit.finance.core.Service.Cache;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.Cursor;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations.TypedTuple;
import org.springframework.data.redis.core.DefaultTypedTuple;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Supplier;
import java.util.stream.Collectors;

/**
 * The monthly spending leaderboard: one Redis sorted set per month (member = user id, score = what the user spent that
 * month). Everything in it can be rebuilt from PostgreSQL, so it has a TTL and no persistence: a missing set is rebuilt on
 * the next read, and a write only touches sets that already exist. Scores are absolute totals read back from PostgreSQL
 * (ZADD), never deltas (ZINCRBY), so a dropped or repeated event heals itself on the next change of that user. A failure
 * of Redis is logged and never reaches the PostgreSQL write that caused it, and a read then answers from PostgreSQL.
 */
@Slf4j
@Service
public class SpendingLeaderboardService {

    public static final String KEY_PREFIX = "ledgermind:leaderboard:spend:";

    private static final int MONEY_SCALE = 2;
    private static final long SCAN_BATCH_SIZE = 100;

    private final StringRedisTemplate redis;
    private final TransactionRepository transactionRepo;
    private final UserRepository userRepo;
    private final Duration ttl;

    public SpendingLeaderboardService(StringRedisTemplate redis, TransactionRepository transactionRepo,
                                      UserRepository userRepo, @Value("${app.leaderboard.ttl:62d}") Duration ttl) {
        this.redis = redis;
        this.transactionRepo = transactionRepo;
        this.userRepo = userRepo;
        this.ttl = ttl;
    }

    /** {@code ledgermind:leaderboard:spend:2026-10}. */
    public static String keyOf(YearMonth month) {
        return KEY_PREFIX + month;
    }

    /**
     * The users who spent the most in {@code month}, highest first, at most {@code limit} of them. Only a failure of
     * Redis falls back to PostgreSQL; a failure of PostgreSQL propagates, whichever step it hits.
     */
    public List<TopSpenderDto> topSpenders(YearMonth month, int limit) {
        String key = keyOf(month);
        List<Object[]> rebuildRows = null;
        try {
            if (!Boolean.TRUE.equals(onRedis(() -> redis.hasKey(key)))) {
                rebuildRows = readRows(month);
                writeRows(month, key, rebuildRows);
            }
            Set<TypedTuple<String>> top = onRedis(() -> redis.opsForZSet().reverseRangeWithScores(key, 0, limit - 1L));
            return top == null ? List.of() : withUsernames(new ArrayList<>(top));
        } catch (RedisAccessException e) {
            log.warn("Leaderboard read from Redis failed, answering from PostgreSQL, month={}", month, e.getCause());
            return fromRows(rebuildRows != null ? rebuildRows : readRows(month), limit);
        }
    }

    /** Deletes the set of {@code month} and builds it again from PostgreSQL; the number of users in it. */
    public int rebuildMonth(YearMonth month) {
        String key = keyOf(month);
        redis.delete(key);
        List<Object[]> rows = readRows(month);
        writeRows(month, key, rows);
        log.info("Leaderboard rebuilt on request, month={}, members={}", month, rows.size());
        return rows.size();
    }

    /**
     * Deletes the set of every month (SCAN, never KEYS): they are rebuilt on the next read. After a restore of the
     * database or the deletion of an account, which change totals without telling the leaderboard whose.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onStatisticsChanged(StatisticsChangedEvent event) {
        if (event.change() == StatisticsChange.DATABASE_RESTORED || event.change() == StatisticsChange.ACCOUNT_DELETED) {
            dropAllMonths();
        }
    }

    public void dropAllMonths() {
        try {
            List<String> keys = new ArrayList<>();
            ScanOptions options = ScanOptions.scanOptions().match(KEY_PREFIX + "*").count(SCAN_BATCH_SIZE).build();
            try (Cursor<String> cursor = redis.scan(options)) {
                cursor.forEachRemaining(keys::add);
            }
            if (!keys.isEmpty()) {
                redis.delete(keys);
            }
            log.info("Leaderboard months dropped, count={}", keys.size());
        } catch (DataAccessException e) {
            log.warn("Leaderboard months could not be dropped, they expire with their TTL", e);
        }
    }

    /** Recomputes the total of the owner for every month the write may have changed, in the sets that exist. */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onTransactionChanged(TransactionChangedEvent event) {
        for (YearMonth month : event.expenseMonths()) {
            try {
                refreshMember(month, event.userId());
            } catch (DataAccessException e) {
                log.warn("Leaderboard update failed, the month is rebuilt when its set expires, month={}, userId={}",
                        month, event.userId(), e);
            }
        }
    }

    private void refreshMember(YearMonth month, Long userId) {
        String key = keyOf(month);
        if (!Boolean.TRUE.equals(redis.hasKey(key))) {
            return;
        }
        BigDecimal total = transactionRepo.sumExpensesBetween(userId, startOf(month), startOf(month.plusMonths(1)));
        String member = String.valueOf(userId);
        if (total == null || total.signum() <= 0) {
            redis.opsForZSet().remove(key, member);
        } else {
            redis.opsForZSet().add(key, member, total.doubleValue());
        }
        log.debug("Leaderboard member refreshed, month={}, userId={}, total={}", month, userId, total);
    }

    private List<Object[]> readRows(YearMonth month) {
        return transactionRepo.sumExpensesByUserBetween(startOf(month), startOf(month.plusMonths(1)));
    }

    /** Writes every member first and sets the TTL last. Redis failures surface as RedisAccessException. */
    private void writeRows(YearMonth month, String key, List<Object[]> rows) {
        if (rows.isEmpty()) {
            return;
        }
        Set<TypedTuple<String>> members = new LinkedHashSet<>();
        for (Object[] row : rows) {
            members.add(new DefaultTypedTuple<>(String.valueOf(row[0]), ((BigDecimal) row[2]).doubleValue()));
        }
        onRedis(() -> redis.opsForZSet().add(key, members));
        onRedis(() -> redis.expire(key, ttl));
        log.info("Leaderboard rebuilt from PostgreSQL, month={}, members={}", month, members.size());
    }

    /** One query for all the names of the page, never one per row. */
    private List<TopSpenderDto> withUsernames(List<TypedTuple<String>> top) {
        List<Long> ids = top.stream().map(tuple -> Long.valueOf(tuple.getValue())).toList();
        Map<Long, String> names = userRepo.findAllById(ids).stream()
                .collect(Collectors.toMap(User::getId, User::getUsername, (first, second) -> first));
        List<TopSpenderDto> result = new ArrayList<>();
        for (TypedTuple<String> tuple : top) {
            Long userId = Long.valueOf(tuple.getValue());
            String username = names.get(userId);
            if (username != null) {
                result.add(TopSpenderDto.builder()
                        .userId(userId)
                        .username(username)
                        .totalSpent(BigDecimal.valueOf(tuple.getScore()).setScale(MONEY_SCALE, RoundingMode.HALF_UP))
                        .build());
            }
        }
        return result;
    }

    private List<TopSpenderDto> fromRows(List<Object[]> rows, int limit) {
        return rows.stream()
                .limit(limit)
                .map(row -> TopSpenderDto.builder()
                        .userId((Long) row[0])
                        .username((String) row[1])
                        .totalSpent((BigDecimal) row[2])
                        .build())
                .toList();
    }

    private static <T> T onRedis(Supplier<T> call) {
        try {
            return call.get();
        } catch (DataAccessException e) {
            throw new RedisAccessException(e);
        }
    }

    /** Marks a failure of Redis, to tell it from one of PostgreSQL (both are DataAccessExceptions). */
    private static final class RedisAccessException extends RuntimeException {
        RedisAccessException(DataAccessException cause) {
            super(cause);
        }
    }

    private static LocalDateTime startOf(YearMonth month) {
        return month.atDay(1).atStartOfDay();
    }
}
