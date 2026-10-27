package vn.edu.huit.finance.core.Dto;

import vn.edu.huit.finance.core.Document.OcrField;

/** Một trường người dùng đã sửa khác với AI; {@code aiValue} là null khi AI không đọc được gì. */
public record OcrFieldCorrection(OcrField field, String aiValue, String expectedValue) {}
