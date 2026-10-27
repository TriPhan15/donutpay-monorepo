package vn.edu.huit.finance.core.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * The pending OTPs in one JVM, for the tests of AuthService that do not start a Redis. Same rules as
 * RedisPasswordResetOtpStore (RedisPasswordResetOtpStoreIntegrationTest pins them there): each call holds the lock of
 * the store, as each Lua script holds Redis, so parallel guesses are weighed one after the other.
 */
public class InMemoryPasswordResetOtpStore implements PasswordResetOtpStore {

    private record Pending(String code, Instant expiresAt, int failedAttempts) {
    }

    // The request limit of one email: when its window began, how many codes it got, and when the last one was issued.
    private record Issues(Instant windowStart, int count, Instant lastIssuedAt) {
    }

    private final Map<String, Pending> pending = new HashMap<>();
    private final Map<String, Issues> issues = new HashMap<>();

    /** Forgets every pending OTP and every request count, for tests that share one store between test methods. */
    public synchronized void clear() {
        pending.clear();
        forgetIssues();
    }

    /** Forgets the request counts only, for tests of the OTP rules that request several codes at one frozen instant. */
    public synchronized void forgetIssues() {
        issues.clear();
    }

    @Override
    public synchronized boolean tryRegisterIssue(String email, Instant now, Duration cooldown, int maxIssues,
                                                 Duration window) {
        String key = email.trim().toLowerCase(Locale.ROOT);
        Issues previous = issues.get(key);
        if (previous != null && !now.isBefore(previous.windowStart().plus(window))) {
            previous = null;
        }
        if (previous != null && (now.isBefore(previous.lastIssuedAt().plus(cooldown))
                || previous.count() >= maxIssues)) {
            return false;
        }
        issues.put(key, previous == null ? new Issues(now, 1, now)
                : new Issues(previous.windowStart(), previous.count() + 1, now));
        return true;
    }

    @Override
    public synchronized void save(String email, String code, Instant issuedAt, Duration validity) {
        pending.put(email, new Pending(code, issuedAt.plus(validity), 0));
    }

    @Override
    public synchronized OtpCheck check(String email, String submittedCode, Instant now, int maxFailedAttempts) {
        Pending otp = pending.get(email);
        if (otp == null) {
            return OtpCheck.notPending();
        }
        if (now.isAfter(otp.expiresAt())) {
            pending.remove(email);
            return OtpCheck.notPending();
        }
        if (otp.code().equals(submittedCode)) {
            pending.remove(email);
            return OtpCheck.accepted();
        }
        int failedAttempts = otp.failedAttempts() + 1;
        if (failedAttempts >= maxFailedAttempts) {
            pending.remove(email);
        } else {
            pending.put(email, new Pending(otp.code(), otp.expiresAt(), failedAttempts));
        }
        return OtpCheck.failed(failedAttempts, maxFailedAttempts);
    }
}
