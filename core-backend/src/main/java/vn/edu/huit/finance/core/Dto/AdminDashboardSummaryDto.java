package vn.edu.huit.finance.core.Dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/** The cross-user figures of the admin dashboard for one month. Cached in Redis as JSON: plain values, never entities. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminDashboardSummaryDto {
    /** Sum of the amounts of every transaction ever recorded, incomes and expenses alike; zero when there is none. */
    private BigDecimal totalVolume;
    private long totalUsers;
    /** Transactions dated inside the month the summary was asked for. */
    private long transactionsInPeriod;
    /** The users whose wallet is below the threshold the summary was asked for. */
    private List<LowBalanceUserDto> lowBalanceUsers;
    private List<ReceiptStatusCountDto> receiptStatuses;

    /** The total volume cut to whole dong (never rounded up) as plain digits; "0" when there is none. */
    public String wholeTotalVolume() {
        BigDecimal safeAmount = totalVolume != null ? totalVolume : BigDecimal.ZERO;
        return safeAmount.setScale(0, RoundingMode.DOWN).toPlainString();
    }
}
