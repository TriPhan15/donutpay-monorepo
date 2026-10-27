package vn.edu.huit.finance.core.Service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Exception.OtpStoreUnavailableException;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;

/**
 * The pending OTPs in Redis, one hash per email ({@code code}, {@code expiresAt} in epoch milliseconds, and
 * {@code failedAttempts} once a guess was wrong). Every save and every check is one Lua script, which Redis runs alone:
 * that is what makes a check atomic, the way ConcurrentHashMap.computeIfPresent made it atomic in one JVM. The expiry is
 * decided by the instant the caller passes (its clock), and the key also gets a TTL of the validity so that Redis drops
 * the OTPs nobody comes back for. Redis being down fails the request with {@link OtpStoreUnavailableException}: an OTP
 * that cannot be stored must not be mailed, and one that cannot be checked must not be accepted.
 */
@Slf4j
@Component
public class RedisPasswordResetOtpStore implements PasswordResetOtpStore {

    static final String KEY_PREFIX = "ledgermind:password-reset-otp:";
    static final String LIMIT_KEY_PREFIX = "ledgermind:password-reset-limit:";
    private static final String MSG_UNAVAILABLE = "Dịch vụ mã OTP tạm thời gián đoạn. Vui lòng thử lại sau ít phút.";
    // What CHECK_SCRIPT answers besides a positive number, which is the count of failed attempts.
    private static final long NOT_PENDING = -1;
    private static final long ACCEPTED = 0;
    private static final long ISSUE_ALLOWED = 1;

    // KEYS[1] = key, ARGV = code, expiresAt (epoch ms), TTL (ms).
    private static final RedisScript<Long> SAVE_SCRIPT = RedisScript.of("""
            redis.call('DEL', KEYS[1])
            redis.call('HSET', KEYS[1], 'code', ARGV[1], 'expiresAt', ARGV[2])
            redis.call('PEXPIRE', KEYS[1], ARGV[3])
            return 1
            """, Long.class);

    // KEYS[1] = key, ARGV = submitted code, now (epoch ms), max failed attempts.
    private static final RedisScript<Long> CHECK_SCRIPT = RedisScript.of("""
            local code = redis.call('HGET', KEYS[1], 'code')
            if not code then
              return %1$d
            end
            if tonumber(ARGV[2]) > tonumber(redis.call('HGET', KEYS[1], 'expiresAt')) then
              redis.call('DEL', KEYS[1])
              return %1$d
            end
            if code == ARGV[1] then
              redis.call('DEL', KEYS[1])
              return %2$d
            end
            local failed = redis.call('HINCRBY', KEYS[1], 'failedAttempts', 1)
            if failed >= tonumber(ARGV[3]) then
              redis.call('DEL', KEYS[1])
            end
            return failed
            """.formatted(NOT_PENDING, ACCEPTED), Long.class);

    // KEYS[1] = limit key, ARGV = now (epoch ms), cooldown (ms), max issues, window (ms). Answers 1 when the issue was
    // recorded, 0 when refused. The window starts with the first issue: the key's TTL is set only then.
    private static final RedisScript<Long> LIMIT_SCRIPT = RedisScript.of("""
            local last = redis.call('HGET', KEYS[1], 'lastIssuedAt')
            if last and tonumber(ARGV[1]) - tonumber(last) < tonumber(ARGV[2]) then
              return 0
            end
            local count = tonumber(redis.call('HGET', KEYS[1], 'count') or '0')
            if count >= tonumber(ARGV[3]) then
              return 0
            end
            redis.call('HSET', KEYS[1], 'lastIssuedAt', ARGV[1])
            if redis.call('HINCRBY', KEYS[1], 'count', 1) == 1 then
              redis.call('PEXPIRE', KEYS[1], ARGV[4])
            end
            return 1
            """, Long.class);

    @Autowired
    private StringRedisTemplate redis;

    @Override
    public boolean tryRegisterIssue(String email, Instant now, Duration cooldown, int maxIssues, Duration window) {
        long answer = runOnKey(LIMIT_SCRIPT, LIMIT_KEY_PREFIX + email.trim().toLowerCase(Locale.ROOT),
                String.valueOf(now.toEpochMilli()), String.valueOf(cooldown.toMillis()), String.valueOf(maxIssues),
                String.valueOf(window.toMillis()));
        return answer == ISSUE_ALLOWED;
    }

    @Override
    public void save(String email, String code, Instant issuedAt, Duration validity) {
        String expiresAt = String.valueOf(issuedAt.plus(validity).toEpochMilli());
        run(SAVE_SCRIPT, email, code, expiresAt, String.valueOf(validity.toMillis()));
    }

    @Override
    public OtpCheck check(String email, String submittedCode, Instant now, int maxFailedAttempts) {
        long answer = run(CHECK_SCRIPT, email, submittedCode, String.valueOf(now.toEpochMilli()),
                String.valueOf(maxFailedAttempts));
        if (answer == NOT_PENDING) {
            return OtpCheck.notPending();
        }
        if (answer == ACCEPTED) {
            return OtpCheck.accepted();
        }
        return OtpCheck.failed(Math.toIntExact(answer), maxFailedAttempts);
    }

    private long run(RedisScript<Long> script, String email, String... args) {
        return runOnKey(script, KEY_PREFIX + email, args);
    }

    private long runOnKey(RedisScript<Long> script, String key, String... args) {
        try {
            return redis.execute(script, List.of(key), (Object[]) args);
        } catch (DataAccessException e) {
            // The OTP and the email are not logged: the cause names the Redis failure only.
            log.error("Password-reset OTP store unavailable: {}", e.getMessage());
            throw new OtpStoreUnavailableException(MSG_UNAVAILABLE, e);
        }
    }
}
