package vn.edu.huit.finance.core.Exception;

/** 403: tài khoản ADMIN không được khóa, mở khóa hay xóa từ trang quản trị. */
public class AdminAccountProtectedException extends RuntimeException {

    public AdminAccountProtectedException(String message) {
        super(message);
    }
}
