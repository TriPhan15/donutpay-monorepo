package vn.edu.huit.finance.core.Exception;

/** 403: người dùng gọi PUT /api/users/{id} với id của người khác. */
public class ProfileAccessDeniedException extends RuntimeException {

    public ProfileAccessDeniedException(String message) {
        super(message);
    }
}
