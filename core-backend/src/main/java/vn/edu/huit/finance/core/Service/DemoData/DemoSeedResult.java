package vn.edu.huit.finance.core.Service.DemoData;

import java.util.List;

/**
 * Kết quả một lần seed: {@code seeded} = false khi database đã có người dùng và không ghi gì cả.
 */
public record DemoSeedResult(boolean seeded, int userCount, int transactionCount, List<SeededReceipt> receipts) {

    public DemoSeedResult {
        receipts = List.copyOf(receipts);
    }

    public static DemoSeedResult skipped() {
        return new DemoSeedResult(false, 0, 0, List.of());
    }
}
