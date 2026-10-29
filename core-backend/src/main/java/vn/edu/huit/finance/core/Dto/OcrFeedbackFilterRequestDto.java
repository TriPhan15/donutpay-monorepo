package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Value;
import vn.edu.huit.finance.core.Document.OcrField;

import java.time.LocalDate;

/** Bộ lọc danh sách phản hồi OCR của quản trị viên; trường null là không lọc. {@code from}/{@code to} gồm cả hai ngày. */
@Value
@Builder
public class OcrFeedbackFilterRequestDto {
    OcrField field;
    Boolean resolved;
    LocalDate from;
    LocalDate to;
}
