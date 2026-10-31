package vn.edu.huit.finance.core.Entity;

/**
 * Nguồn của một giao dịch, lưu trong transactions.source. Phân biệt giao dịch bằng cột này, không bằng tên danh mục
 * hay ghi chú.
 */
public enum TransactionSource {
    /** Giao dịch người dùng nhập, quét hóa đơn, góp tiết kiệm: chỉ loại này được cộng vào tổng thu nhập và tổng chi tiêu. */
    NORMAL,
    /**
     * Tiền một mục tiêu tiết kiệm đang giữ, trả về ví khi mục tiêu bị xóa. Ví vẫn được cộng như một khoản thu, nhưng đây
     * là tiền của chính người dùng quay về, nên không được tính là thu nhập (thống kê, AI).
     */
    GOAL_REFUND,
    /**
     * Nạp tiền từ, hoặc rút tiền về, ví điện tử liên kết (PaymentService). Ví chính vẫn được cộng hoặc trừ, nhưng đây là
     * tiền chuyển giữa hai ví của cùng một người, không phải thu nhập cũng không phải chi tiêu: ngân sách, cảnh báo ngân
     * sách, bảng xếp hạng, RFM và thống kê không tính khoản này.
     */
    WALLET_TRANSFER
}