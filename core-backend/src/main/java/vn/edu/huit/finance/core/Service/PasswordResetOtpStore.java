package vn.edu.huit.finance.core.Service;

import java.time.Duration;
import java.time.Instant;

/**
 * Where the pending password-reset OTPs live: at most one per email, shared by every instance of the API. Each call is
 * one atomic step for its email, so guesses that arrive in parallel are weighed one after the other and cannot slip past
 * the limit of failed attempts.
 */
public interface PasswordResetOtpStore {

    /**
     * Makes {@code code} the pending OTP of {@code email}, valid until {@code issuedAt + validity} included. Replaces the
     * pending one, so the old code stops working and the failed attempts start over.
     */
    void save(String email, String code, Instant issuedAt, Duration validity);

    /**
     * Weighs {@code submittedCode} against the pending OTP of {@code email} at {@code now}. A matching code consumes the
     * OTP; an expired OTP, and one whose {@code maxFailedAttempts}-th wrong guess this is, are dropped. In every case but
     * a plain wrong guess, a new OTP has to be requested.
     */
    OtpCheck check(String email, String submittedCode, Instant now, int maxFailedAttempts);

    enum Outcome {
        /** The code matched and the OTP is consumed. */
        ACCEPTED,
        /** The code did not match; the OTP stays pending. */
        WRONG,
        /** The code did not match and the OTP has used up its failed attempts: it is dropped. */
        ATTEMPTS_EXHAUSTED,
        /** No OTP is pending: never requested, already used, dropped, or expired (and dropped now). */
        NOT_PENDING
    }

    /** What a check found; {@code failedAttempts} counts the wrong guesses so far, this one included (0 otherwise). */
    record OtpCheck(Outcome outcome, int failedAttempts) {

        public static OtpCheck accepted() {
            return new OtpCheck(Outcome.ACCEPTED, 0);
        }

        public static OtpCheck notPending() {
            return new OtpCheck(Outcome.NOT_PENDING, 0);
        }

        public static OtpCheck failed(int failedAttempts, int maxFailedAttempts) {
            return new OtpCheck(failedAttempts >= maxFailedAttempts ? Outcome.ATTEMPTS_EXHAUSTED : Outcome.WRONG,
                    failedAttempts);
        }
    }
}
