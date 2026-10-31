package vn.edu.huit.finance.core.Entity;

/**
 * Nguồn của một giao dịch, lưu trong transactions.source. Phân biệt giao dịch bằng cột này, không bằng tên danh mục
 * hay ghi chú.
 */
public enum TransactionSource {
    /** Giao dịch người dùng nhập, quét hóa đơn, nạp/rút ví, góp tiết kiệm. */
    NORMAL,
    /**
     * Tiền một mục tiêu tiết kiệm đang giữ, trả về ví khi mục tiêu bị xóa. Ví vẫn được cộng như một khoản thu, nhưng đây
     * là tiền của chính người dùng quay về, nên không được tính là thu nhập (thống kê, AI).
     */
    GOAL_REFUND
}