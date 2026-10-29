package vn.edu.huit.finance.core.Service.Realtime;

import java.time.Instant;
import java.time.YearMonth;

/**
 * One realtime event of the admin web, sent as JSON over Redis Pub/Sub and then over Server-Sent Events. It carries no
 * personal data: only a type, the id of the receipt it is about (null for a whole-store action), a Vietnamese message made
 * of ids and counts, and when it happened.
 */
public record AdminEvent(AdminEventType type, Long id, String message, Instant at) {

    private static final String MSG_RECEIPT_WAITING_REVIEW = "Hóa đơn #%d đang chờ duyệt";
    private static final String MSG_OCR_FEEDBACK_REPORTED = "Hóa đơn #%d có %d chỗ sửa OCR mới";
    private static final String MSG_SEARCH_REINDEXED = "Đã dựng lại chỉ mục tìm kiếm: %d giao dịch";
    private static final String MSG_LEADERBOARD_REBUILT = "Đã dựng lại bảng xếp hạng tháng %s: %d người dùng";

    public static AdminEvent of(AdminEventType type, Long id, String message) {
        return new AdminEvent(type, id, message, Instant.now());
    }

    public static AdminEvent receiptWaitingReview(long receiptId) {
        return of(AdminEventType.RECEIPT_WAITING_REVIEW, receiptId, String.format(MSG_RECEIPT_WAITING_REVIEW, receiptId));
    }

    public static AdminEvent ocrFeedbackReported(long receiptId, int corrections) {
        return of(AdminEventType.OCR_FEEDBACK_REPORTED, receiptId,
                String.format(MSG_OCR_FEEDBACK_REPORTED, receiptId, corrections));
    }

    public static AdminEvent searchReindexed(int documents) {
        return of(AdminEventType.SEARCH_REINDEXED, null, String.format(MSG_SEARCH_REINDEXED, documents));
    }

    public static AdminEvent leaderboardRebuilt(YearMonth month, int members) {
        return of(AdminEventType.LEADERBOARD_REBUILT, null, String.format(MSG_LEADERBOARD_REBUILT, month, members));
    }
}
