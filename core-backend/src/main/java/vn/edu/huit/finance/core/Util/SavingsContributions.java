package vn.edu.huit.finance.core.Util;

import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.Transaction;

/**
 * Góp tiết kiệm trừ ví nhưng không phải chi tiêu (D1): một khoản chi thuộc danh mục "Tiết kiệm" không tính vào ngân sách,
 * cảnh báo ngân sách hay top người chi tiêu.
 */
public final class SavingsContributions {

    /** Tên danh mục dùng để nhận ra khoản góp tiết kiệm; các truy vấn loại trừ theo tên này. */
    public static final String CATEGORY_NAME = DefaultCategory.SAVINGS.getDisplayName();

    private SavingsContributions() {
    }

    /** True khi danh mục là danh mục chi "Tiết kiệm"; null thì không phải. */
    public static boolean isSavingsCategory(Category category) {
        return category != null
                && CATEGORY_NAME.equals(CategoryNames.clean(category.getName()))
                && DefaultCategory.TYPE_EXPENSE.equals(category.getType());
    }

    /** True khi giao dịch là khoản chi nằm trong danh mục tiết kiệm. */
    public static boolean isContribution(Transaction transaction) {
        return transaction.isExpense() && isSavingsCategory(transaction.getCategory());
    }
}
