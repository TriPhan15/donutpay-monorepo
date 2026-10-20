package vn.edu.huit.finance.core.Service.DemoData;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Một hóa đơn demo đã lưu vào PostgreSQL, đủ để MongoDataSeeder ghi log thô và phản hồi OCR khớp với nó.
 *
 * @param aiRawData  câu trả lời của AI, đúng như lần đọc đầu tiên đã lưu
 * @param readSeller tên cửa hàng AI đọc được
 * @param seller     tên cửa hàng đúng
 * @param amount     số tiền của giao dịch
 */
public record SeededReceipt(Long transactionId, Long receiptId, Long userId, ReceiptScenario scenario,
                            String aiRawData, String readSeller, String seller, BigDecimal amount,
                            LocalDateTime scannedAt) {
}
