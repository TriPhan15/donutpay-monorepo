package vn.edu.huit.finance.core.Service.DemoData;

/**
 * Kiểu người dùng của dữ liệu demo. Mỗi kiểu quyết định thói quen chi tiêu và khoảng thời gian có giao dịch, nên cũng
 * ảnh hưởng tới nhóm RFM mà ai-service (/admin/segment, rfm_segmentation.py) gán khi admin chạy phân khúc. Recency,
 * Frequency, Monetary được chấm 1..5 theo ngũ phân vị TƯƠNG ĐỐI giữa các người dùng có chi tiêu trong 12 tháng, rồi
 * ánh xạ (luật đầu tiên khớp thắng): CHAMPIONS (R, F, M ≥ 4), NEW (R ≥ 4, F ≤ 2), LOYAL (R, F ≥ 3), AT_RISK (R ≤ 2,
 * F ≥ 3), HIBERNATING (R ≤ 2), còn lại NEED_ATTENTION; không có khoản chi nào trong 12 tháng là LOST. Vì điểm là thứ
 * hạng tương đối, "nhóm dự kiến" dưới đây chỉ là xu hướng trên bộ dữ liệu demo, không phải ngưỡng cố định.
 */
public enum DemoPersona {
    /** Tài khoản demo đăng nhập được: nhân viên văn phòng, lương đầu tháng, thuê nhà. Nhóm dự kiến: CHAMPIONS hoặc LOYAL. */
    OFFICE_WORKER(true),
    /** Tài khoản demo đăng nhập được: sinh viên, bố mẹ gửi tiền và lương làm thêm. Nhóm dự kiến: LOYAL hoặc CHAMPIONS. */
    STUDENT(true),
    /** Người đi làm, có giao dịch tới hôm nay. Nhóm dự kiến: CHAMPIONS hoặc LOYAL. */
    SALARIED(false),
    /** Mới dùng app vài tuần, ít giao dịch, chi tiêu gần đây. Nhóm dự kiến: NEW. */
    NEWCOMER(false),
    /** Ngừng ghi chép từ 35 đến 95 ngày trước. Nhóm dự kiến: AT_RISK hoặc HIBERNATING. */
    FADING(false),
    /** Ngừng ghi chép từ 125 đến 160 ngày trước. Nhóm dự kiến: HIBERNATING (LOST nếu không còn khoản chi nào trong 12 tháng). */
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
