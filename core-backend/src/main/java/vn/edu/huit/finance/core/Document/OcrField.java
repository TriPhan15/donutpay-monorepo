package vn.edu.huit.finance.core.Document;

/** Trường của hóa đơn mà AI đọc và người dùng có thể sửa; {@link #key()} là giá trị lưu ở {@code fieldError} của ocr_feedbacks. */
public enum OcrField {
    SELLER_NAME("seller_name"),
    TOTAL_COST("total_cost"),
    RECEIPT_DATE("receipt_date");

    private final String key;

    OcrField(String key) {
        this.key = key;
    }

    public String key() {
        return key;
    }
}
