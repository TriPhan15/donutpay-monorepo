package vn.edu.huit.finance.core.Dto;

import java.util.List;

/** Phát sau khi giao dịch PostgreSQL commit để ghi các chỗ người dùng sửa AI vào MongoDB (ocr_feedbacks). */
public record OcrCorrectionEvent(Long receiptId, Long transactionId, Long userId, List<OcrFieldCorrection> corrections) {}
