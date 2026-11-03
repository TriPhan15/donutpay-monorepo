package vn.edu.huit.finance.core.Util;

import vn.edu.huit.finance.core.Entity.Receipt;

/**
 * Nội dung thông báo RECEIPT_PROCESSED gửi cho chủ hóa đơn khi quản trị viên duyệt hoặc từ chối hóa đơn. Một chỗ duy nhất
 * giữ câu chữ, để hai nơi gửi (duyệt trong TransactionService, từ chối trong ReceiptProcessingService) không lệch nhau.
 */
public final class ReceiptReviewMessages {

    private static final String MSG_APPROVED = "Hóa đơn %s đã được quản trị viên duyệt.";
    private static final String MSG_REJECTED =
            "Hóa đơn %s đã bị quản trị viên từ chối. Bạn có thể quét lại hoặc nhập số tiền để gửi duyệt.";
    /** Thay cho tên cửa hàng khi hóa đơn không có tên. */
    private static final String UNNAMED_RECEIPT = "của bạn";

    private ReceiptReviewMessages() {
    }

    public static String approved(Receipt receipt) {
        return String.format(MSG_APPROVED, labelOf(receipt));
    }

    public static String rejected(Receipt receipt) {
        return String.format(MSG_REJECTED, labelOf(receipt));
    }

    private static String labelOf(Receipt receipt) {
        String vendor = receipt.getVendorName();
        return vendor == null || vendor.isBlank() ? UNNAMED_RECEIPT : vendor.strip();
    }
}
