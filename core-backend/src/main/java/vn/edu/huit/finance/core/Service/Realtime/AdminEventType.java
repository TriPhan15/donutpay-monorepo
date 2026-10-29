package vn.edu.huit.finance.core.Service.Realtime;

/** What happened, for the toast and the sidebar badge of the admin web. */
public enum AdminEventType {
    /** A receipt the user corrected waits for an administrator (badge on "Quản lý Hóa đơn AI"). */
    RECEIPT_WAITING_REVIEW,
    /** A user corrected what the OCR read (badge on "Phản hồi OCR"). */
    OCR_FEEDBACK_REPORTED,
    /** An administrator rebuilt the Elasticsearch index. */
    SEARCH_REINDEXED,
    /** An administrator rebuilt the Redis leaderboard of a month. */
    LEADERBOARD_REBUILT
}
