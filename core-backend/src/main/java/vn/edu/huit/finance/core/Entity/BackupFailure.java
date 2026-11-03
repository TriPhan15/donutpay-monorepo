package vn.edu.huit.finance.core.Entity;

/** Bước nào của lần sao lưu tự động đã hỏng. Nhãn hiện trên trang Sao lưu, trong nhật ký kiểm toán và trong mail cho admin. */
public enum BackupFailure {
    DUMP_FAILED("pg_dump thất bại, không tạo được file sao lưu"),
    CHECKSUM_FAILED("Không đọc được file vừa tạo để tính SHA-256"),
    NOT_READABLE("pg_restore --list không đọc được file sao lưu (file hỏng, đã xóa)"),
    MONGO_COPY_FAILED("Không lưu được bản sao trong MongoDB (bản trên đĩa vẫn dùng được)");

    private final String label;

    BackupFailure(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}
