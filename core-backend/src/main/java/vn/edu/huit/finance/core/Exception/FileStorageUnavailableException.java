package vn.edu.huit.finance.core.Exception;

/** 503 với câu cố định: kho ảnh (Cloudinary) lỗi hoặc không trả link. Nguyên nhân chỉ nằm trong log. */
public class FileStorageUnavailableException extends RuntimeException {

    public FileStorageUnavailableException(String message) {
        super(message);
    }

    public FileStorageUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}