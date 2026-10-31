package vn.edu.huit.finance.core.Exception;

/** 413: file tải lên vượt giới hạn kích thước. */
public class UploadTooLargeException extends RuntimeException {

    public UploadTooLargeException(String message) {
        super(message);
    }
}