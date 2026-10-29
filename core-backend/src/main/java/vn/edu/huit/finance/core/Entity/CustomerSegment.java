package vn.edu.huit.finance.core.Entity;

import java.util.Arrays;
import java.util.Optional;

/** Nhóm khách hàng do dịch vụ AI gán theo RFM; mã (tên enum) là giá trị lưu ở users.ai_label. */
public enum CustomerSegment {
    CHAMPIONS("Khách hàng tốt nhất"),
    LOYAL("Trung thành"),
    NEW("Khách mới"),
    NEED_ATTENTION("Cần chú ý"),
    AT_RISK("Có nguy cơ rời bỏ"),
    HIBERNATING("Ngủ đông"),
    LOST("Đã rời bỏ");

    private final String displayName;

    CustomerSegment(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }

    /** Nhóm có mã đúng như đã cho; rỗng nếu mã null hoặc không thuộc enum (kể cả nhãn cũ như VIP). */
    public static Optional<CustomerSegment> fromCode(String code) {
        return Arrays.stream(values()).filter(segment -> segment.name().equals(code)).findFirst();
    }
}
