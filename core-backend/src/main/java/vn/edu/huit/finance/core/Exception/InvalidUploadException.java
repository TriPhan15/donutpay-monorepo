package vn.edu.huit.finance.core.Exception;

/** 400: file tải lên rỗng hoặc không phải ảnh JPEG, PNG, WEBP. */
public class InvalidUploadException extends RuntimeException {

    public InvalidUploadException(String message) {
        super(message);
    }
}