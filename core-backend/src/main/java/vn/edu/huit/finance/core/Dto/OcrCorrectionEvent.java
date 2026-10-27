package vn.edu.huit.finance.core.Dto;

import vn.edu.huit.finance.core.Document.OcrField;

import java.util.List;

/**
 * Phát sau khi giao dịch PostgreSQL commit để ghi các chỗ người dùng sửa AI vào MongoDB (ocr_feedbacks): {@code corrections}
 * được ghi (upsert), còn {@code clearedFields} là các trường nay lại bằng giá trị AI, chỗ sửa cũ của chúng bị xóa.
 */
public record OcrCorrectionEvent(Long receiptId, Long transactionId, Long userId, List<OcrFieldCorrection> corrections,
                                 List<OcrField> clearedFields) {

    public OcrCorrectionEvent {
        corrections = corrections == null ? List.of() : List.copyOf(corrections);
        clearedFields = clearedFields == null ? List.of() : List.copyOf(clearedFields);
    }

    /** Chỉ có các chỗ sửa, không trường nào trở lại giá trị AI. */
    public OcrCorrectionEvent(Long receiptId, Long transactionId, Long userId, List<OcrFieldCorrection> corrections) {
        this(receiptId, transactionId, userId, corrections, List.of());
    }
}
