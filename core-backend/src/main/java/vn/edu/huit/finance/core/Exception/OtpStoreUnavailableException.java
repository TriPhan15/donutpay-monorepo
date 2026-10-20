package vn.edu.huit.finance.core.Exception;

/**
 * The store of the pending OTPs (Redis) could not be reached, so no OTP was issued or checked. The message is a fixed
 * text that may be shown to a client; the cause stays on the server, in the log line RedisPasswordResetOtpStore writes.
 */
public class OtpStoreUnavailableException extends RuntimeException {

    public OtpStoreUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
