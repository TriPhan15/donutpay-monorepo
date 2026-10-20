package vn.edu.huit.finance.core.Entity;

/**
 * Danh mục mặc định của hệ thống, theo thói quen chi tiêu ở Việt Nam. Bảng categories chỉ lưu tên tiếng Việt và loại
 * (không có cột key, để không đổi schema); {@link #getKey()} là mã ổn định, không bao giờ đổi, để app mobile ánh xạ tên
 * hiển thị sang ngôn ngữ khác (T4). Đổi tên tiếng Việt ở đây thì phải đổi cả bản dịch bên mobile.
 * Không tên nào chứa chữ "đi" đứng riêng: TransactionCategories.iconFor của mobile hiểu chữ đó là xăng xe.
 */
public enum DefaultCategory {

    // ------------------------------------------------------------------------------------------------------------ chi
    FOOD("food", "Ăn uống", true),
    GROCERIES("groceries", "Siêu thị & Chợ", true),
    TRANSPORT("transport", "Di chuyển", true),
    HOUSING("housing", "Nhà ở", true),
    UTILITIES("utilities", "Điện nước", true),
    TELECOM("telecom", "Internet & Điện thoại", true),
    SHOPPING("shopping", "Mua sắm", true),
    HEALTH("health", "Sức khỏe", true),
    EDUCATION("education", "Giáo dục", true),
    ENTERTAINMENT("entertainment", "Giải trí", true),
    TRAVEL("travel", "Du lịch", true),
    FAMILY("family", "Gia đình & Con cái", true),
    SOCIAL("social", "Hiếu hỉ", true),
    INSURANCE("insurance", "Bảo hiểm", true),
    OTHER_EXPENSE("other_expense", "Khác", true),

    // ------------------------------------------------------------------------------------------------------------ thu
    SALARY("salary", "Lương", false),
    BONUS("bonus", "Thưởng", false),
    BUSINESS("business", "Kinh doanh", false),
    INVESTMENT("investment", "Đầu tư", false),
    GIFT("gift", "Được tặng", false),
    OTHER_INCOME("other_income", "Thu khác", false);

    /** Giá trị cột categories.type của danh mục chi. */
    public static final String TYPE_EXPENSE = "EXPENSE";
    /** Giá trị cột categories.type của danh mục thu. */
    public static final String TYPE_INCOME = "INCOME";

    private final String key;
    private final String displayName;
    private final boolean expense;

    DefaultCategory(String key, String displayName, boolean expense) {
        this.key = key;
        this.displayName = displayName;
        this.expense = expense;
    }

    public String getKey() {
        return key;
    }

    /** Tên tiếng Việt, đúng như lưu trong categories.name. */
    public String getDisplayName() {
        return displayName;
    }

    public boolean isExpense() {
        return expense;
    }

    /** Giá trị cột categories.type: EXPENSE hoặc INCOME. */
    public String getType() {
        return expense ? TYPE_EXPENSE : TYPE_INCOME;
    }
}
