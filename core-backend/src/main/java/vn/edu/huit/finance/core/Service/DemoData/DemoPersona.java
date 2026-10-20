package vn.edu.huit.finance.core.Service.DemoData;

/**
 * Kiểu người dùng của dữ liệu demo. Mỗi kiểu quyết định thói quen chi tiêu và khoảng thời gian có giao dịch, nên cũng
 * quyết định nhóm RFM mà ai-service (/admin/segment) sẽ gán khi admin chạy phân khúc: CHURN khi giao dịch cuối cách
 * đây hơn 120 ngày, AT-RISK khi hơn 30 ngày, VIP khi tổng tiền trên 10 triệu, còn lại ACTIVE.
 */
public enum DemoPersona {
    /** Tài khoản demo đăng nhập được: nhân viên văn phòng, lương đầu tháng, thuê nhà. Nhóm dự kiến: VIP. */
    OFFICE_WORKER(true),
    /** Tài khoản demo đăng nhập được: sinh viên, bố mẹ gửi tiền và lương làm thêm. Nhóm dự kiến: VIP. */
    STUDENT(true),
    /** Người đi làm, có giao dịch tới hôm nay. Nhóm dự kiến: VIP. */
    SALARIED(false),
    /** Mới dùng app vài tuần, ít giao dịch, tổng tiền dưới 10 triệu. Nhóm dự kiến: ACTIVE. */
    NEWCOMER(false),
    /** Ngừng ghi chép từ 35 đến 95 ngày trước. Nhóm dự kiến: AT-RISK. */
    FADING(false),
    /** Ngừng ghi chép từ 125 đến 160 ngày trước. Nhóm dự kiến: CHURN. */
    CHURNED(false);

    private final boolean demoLogin;

    DemoPersona(boolean demoLogin) {
        this.demoLogin = demoLogin;
    }

    /** True cho hai tài khoản demo có mật khẩu đăng nhập được; tài khoản nền không ai đăng nhập được. */
    public boolean isDemoLogin() {
        return demoLogin;
    }
}
