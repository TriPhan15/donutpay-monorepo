package vn.edu.huit.finance.core.Service.DemoData;

import java.math.BigDecimal;
import java.util.List;

/**
 * Một người dùng demo đã sinh cùng toàn bộ giao dịch của họ (cũ nhất trước). Số dư ví bằng tổng thu trừ tổng chi, đúng
 * như cột users.wallet_balance phải giữ.
 */
public record DemoAccount(String username, String email, String phone, DemoPersona persona,
                          List<DemoTransaction> transactions) {

    public DemoAccount {
        transactions = List.copyOf(transactions);
    }

    public BigDecimal walletBalance() {
        return transactions.stream().map(DemoTransaction::signedAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
