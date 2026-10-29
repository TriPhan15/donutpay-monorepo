package vn.edu.huit.finance.core.Exception;

/** Một thay đổi hồ sơ mà người dùng không được tự làm (đổi email, tên đăng nhập chứa @ không phải email của mình). */
public class ProfileUpdateRefusedException extends RuntimeException {

    public ProfileUpdateRefusedException(String message) {
        super(message);
    }
}
