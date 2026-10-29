package vn.edu.huit.finance.core.Service.Payment;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Giới hạn số dòng audit PAYMENT_WEBHOOK_REJECTED. Webhook không cần đăng nhập, nên ai cũng gửi được webhook sai chữ ký;
 * nếu mỗi lần ghi một dòng thì action_logs phình mãi. Trong mỗi {@link #WINDOW}: mỗi mã đơn chỉ được ghi một lần, và
 * tổng cộng không quá {@link #MAX_ROWS_PER_WINDOW} dòng (để đổi mã đơn liên tục cũng không làm phình bảng). Lần bị bỏ
 * qua vẫn được ghi vào log của ứng dụng bởi người gọi. Chỉ giữ trong bộ nhớ của một instance.
 */
public class RejectedWebhookAuditThrottle {

    static final Duration WINDOW = Duration.ofMinutes(10);
    static final int MAX_ROWS_PER_WINDOW = 100;
    static final int MAX_TRACKED_ORDER_CODES = 10_000;
    private static final String NO_ORDER_CODE = "";

    private final Clock clock;
    private final Map<String, Instant> lastRecorded = new HashMap<>();
    private Instant windowStart;
    private int rowsInWindow;

    public RejectedWebhookAuditThrottle(Clock clock) {
        this.clock = clock;
    }

    /** True khi webhook bị từ chối với mã đơn này được ghi một dòng audit; false khi đã ghi đủ trong cửa sổ hiện tại. */
    public synchronized boolean shouldRecord(String orderCode) {
        Instant now = clock.instant();
        if (windowStart == null || !now.isBefore(windowStart.plus(WINDOW))) {
            windowStart = now;
            rowsInWindow = 0;
            lastRecorded.values().removeIf(at -> !now.isBefore(at.plus(WINDOW)));
        }
        String key = orderCode == null ? NO_ORDER_CODE : orderCode;
        Instant last = lastRecorded.get(key);
        if (last != null && now.isBefore(last.plus(WINDOW))) {
            return false;
        }
        if (rowsInWindow >= MAX_ROWS_PER_WINDOW) {
            return false;
        }
        if (lastRecorded.size() >= MAX_TRACKED_ORDER_CODES) {
            lastRecorded.clear();
        }
        lastRecorded.put(key, now);
        rowsInWindow++;
        return true;
    }
}
