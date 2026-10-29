package vn.edu.huit.finance.core.Dto;

import vn.edu.huit.finance.core.Document.OcrField;

import java.util.List;

/**
 * Kết quả so sánh những gì người dùng nhập với những gì AI đọc: các trường khác AI ({@code corrections}) và các trường
 * đã được so sánh mà nay bằng AI ({@code clearedFields}), tức chỗ sửa lưu trước đó cho trường ấy (nếu có) đã lỗi thời.
 */
public record OcrCorrectionDiff(List<OcrFieldCorrection> corrections, List<OcrField> clearedFields) {

    public OcrCorrectionDiff {
        corrections = List.copyOf(corrections);
        clearedFields = List.copyOf(clearedFields);
    }

    /** Không trường nào được so sánh (người dùng không gửi trường nào). */
    public boolean isEmpty() {
        return corrections.isEmpty() && clearedFields.isEmpty();
    }
}
