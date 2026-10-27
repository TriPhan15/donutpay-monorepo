package vn.edu.huit.finance.core.Exception;

/** Phản hồi OCR (ocr_feedbacks trong MongoDB) không tồn tại. */
public class OcrFeedbackNotFoundException extends RuntimeException {

    public OcrFeedbackNotFoundException(String message) {
        super(message);
    }
}
