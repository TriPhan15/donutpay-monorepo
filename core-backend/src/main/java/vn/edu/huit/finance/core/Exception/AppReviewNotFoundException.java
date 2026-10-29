package vn.edu.huit.finance.core.Exception;

/** 404: không có đánh giá với id này. */
public class AppReviewNotFoundException extends RuntimeException {

    public AppReviewNotFoundException(String message) {
        super(message);
    }
}
