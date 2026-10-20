package vn.edu.huit.finance.core.Service.DemoData;

import java.util.List;

/**
 * Câu chuyện của một hóa đơn demo, mỗi câu chuyện dừng ở một trạng thái của vòng đời hóa đơn để demo đủ các nhánh.
 * Trạng thái chỉ được chuyển qua Receipt.moveTo / failWith, đúng những bước mà app thật đi qua.
 */
public enum ReceiptScenario {
    /** AI đọc được tổng tiền, người dùng chưa sửa: COMPLETED_RAW. */
    READ,
    /** AI đọc tên cửa hàng không dấu, người dùng sửa lại: EDITED. */
    CORRECTED,
    /** AI không đọc được tổng tiền: FAILED (AI_NO_TOTAL). */
    UNREADABLE_TOTAL,
    /** AI không đọc được tổng tiền, người dùng gửi số tiền chờ admin duyệt: WAITING_FOR_REVIEW. */
    AWAITING_REVIEW,
    /** AI đọc được, admin đã duyệt: APPROVED. */
    APPROVED;

    private static final List<ReceiptScenario> OFFICE_WORKER_RECEIPTS = List.of(values());
    private static final List<ReceiptScenario> STUDENT_RECEIPTS = List.of(READ, UNREADABLE_TOTAL);

    /** Các hóa đơn của một kiểu người dùng: chỉ hai tài khoản demo có hóa đơn. */
    public static List<ReceiptScenario> forPersona(DemoPersona persona) {
        return switch (persona) {
            case OFFICE_WORKER -> OFFICE_WORKER_RECEIPTS;
            case STUDENT -> STUDENT_RECEIPTS;
            default -> List.of();
        };
    }

    /** True khi AI đọc được tổng tiền ở lần đọc đầu tiên. */
    public boolean totalRead() {
        return this != UNREADABLE_TOTAL && this != AWAITING_REVIEW;
    }
}
