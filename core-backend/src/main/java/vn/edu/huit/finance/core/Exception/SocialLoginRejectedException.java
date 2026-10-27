package vn.edu.huit.finance.core.Exception;

/** A social-login token failed verification (wrong app, unverified email, not configured). Mapped to 401. */
public class SocialLoginRejectedException extends RuntimeException {

    public static final String MESSAGE = "Đăng nhập mạng xã hội không hợp lệ.";

    public SocialLoginRejectedException() {
        super(MESSAGE);
    }
}
