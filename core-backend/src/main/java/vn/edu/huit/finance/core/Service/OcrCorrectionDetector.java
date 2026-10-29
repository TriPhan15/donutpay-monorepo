package vn.edu.huit.finance.core.Service;

import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Dto.ExtractedReceiptDto;
import vn.edu.huit.finance.core.Dto.OcrCorrectionDiff;
import vn.edu.huit.finance.core.Dto.OcrFieldCorrection;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/** So sánh những gì người dùng nhập với những gì AI đã đọc, để biết AI sai ở trường nào. */
@Component
public class OcrCorrectionDetector {

    /**
     * Các trường khác với AI, và các trường đã so sánh mà bằng AI (chỗ sửa cũ của chúng, nếu có, đã lỗi thời). Giá trị
     * null của người dùng nghĩa là "không gửi" nên không được so sánh; tiền so bằng {@code compareTo} (120000 và
     * 120000.00 là một), tên cửa hàng so sau khi cắt khoảng trắng và phân biệt hoa thường.
     */
    public OcrCorrectionDiff diff(ExtractedReceiptDto ai, String seller, BigDecimal total, LocalDate date) {
        List<OcrFieldCorrection> corrections = new ArrayList<>();
        List<OcrField> cleared = new ArrayList<>();
        if (seller != null) {
            String aiSeller = ai.getSeller() == null ? null : ai.getSeller().trim();
            if (Objects.equals(seller.trim(), aiSeller)) {
                cleared.add(OcrField.SELLER_NAME);
            } else {
                corrections.add(new OcrFieldCorrection(OcrField.SELLER_NAME, ai.getSeller(), seller.trim()));
            }
        }
        if (total != null) {
            if (ai.getTotalCost() != null && ai.getTotalCost().compareTo(total) == 0) {
                cleared.add(OcrField.TOTAL_COST);
            } else {
                corrections.add(new OcrFieldCorrection(OcrField.TOTAL_COST, money(ai.getTotalCost()), money(total)));
            }
        }
        if (date != null) {
            LocalDate aiDate = ai.getTimestamp() == null ? null : ai.getTimestamp().toLocalDate();
            if (date.equals(aiDate)) {
                cleared.add(OcrField.RECEIPT_DATE);
            } else {
                corrections.add(new OcrFieldCorrection(OcrField.RECEIPT_DATE, aiDate == null ? null : aiDate.toString(),
                        date.toString()));
            }
        }
        return new OcrCorrectionDiff(corrections, cleared);
    }

    private static String money(BigDecimal amount) {
        return amount == null ? null : amount.stripTrailingZeros().toPlainString();
    }
}
