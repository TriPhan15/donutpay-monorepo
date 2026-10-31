package vn.edu.huit.finance.core.Exception;

/** 400: link ảnh hóa đơn không phải https:// (hoặc quá dài), nên không được lưu. */
public class InvalidImageUrlException extends RuntimeException {

    public InvalidImageUrlException(String message) {
        super(message);
    }
}
