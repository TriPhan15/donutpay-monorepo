package vn.edu.huit.finance.core.Service.DemoData;

import vn.edu.huit.finance.core.Entity.DefaultCategory;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Một giao dịch demo đã sinh, chưa lưu. Chiều thu/chi lấy theo danh mục.
 *
 * @param note     tên cửa hàng hoặc nội dung chuyển khoản
 * @param location quận/thành phố của cửa hàng; null với giao dịch không có nơi chốn (lương, tiền nhà, cước)
 */
public record DemoTransaction(DefaultCategory category, BigDecimal amount, LocalDateTime at, String note,
                              String location) {

    public boolean isExpense() {
        return category.isExpense();
    }

    /** Số tiền có dấu: dương với khoản thu, âm với khoản chi. */
    public BigDecimal signedAmount() {
        return isExpense() ? amount.negate() : amount;
    }
}
