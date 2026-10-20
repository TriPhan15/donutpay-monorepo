package vn.edu.huit.finance.core.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * The pending OTPs in one JVM, for the tests of AuthService that do not start a Redis. Same rules as
 * RedisPasswordResetOtpStore (RedisPasswordResetOtpStoreIntegrationTest pins them there): each call holds the lock of
 * the store, as each Lua script holds Redis, so parallel guesses are weighed one after the other.
 */
public class InMemoryPasswordResetOtpStore implements PasswordResetOtpStore {

    private record Pending(String code, Instant expiresAt, int failedAttempts) {
    }

    private final Map<String, Pending> pending = new HashMap<>();

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
