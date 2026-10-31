package vn.edu.huit.finance.core.Exception;

/** 400: một giá trị trong request không hợp lệ (ngoài những gì @Valid kiểm được); thông báo là câu cố định cho người dùng đọc. */
public class InvalidRequestException extends RuntimeException {

    public InvalidRequestException(String message) {
        super(message);
    }
}
