package vn.edu.huit.finance.core.Exception;

/** Too many password-reset codes were requested for one email: the request is refused (429) and no code is issued. */
public class OtpRequestLimitedException extends RuntimeException {

    public OtpRequestLimitedException(String message) {
        super(message);
    }
}
