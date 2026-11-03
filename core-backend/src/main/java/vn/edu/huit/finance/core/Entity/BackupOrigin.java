package vn.edu.huit.finance.core.Entity;

/**
 * Ai khởi chạy một lần sao lưu. Tên file của bản tự động có thêm dấu {@code auto_} sau tiền tố của loại
 * (FULL_backup_auto_20261101_020000.sql): lịch giữ bản chỉ xóa bản tự động, không bao giờ xóa bản admin tự bấm.
 */
public enum BackupOrigin {
    /** Admin bấm nút trên trang Sao lưu. */
    MANUAL(""),
    /** Việc chạy hằng ngày theo lịch (ScheduledBackupJob). */
    SCHEDULED("auto_");

    private final String fileInfix;

    BackupOrigin(String fileInfix) {
        this.fileInfix = fileInfix;
    }

    /** Đoạn chèn vào tên file, sau {@link BackupType#filePrefix()} và trước mốc thời gian. */
    public String fileInfix() {
        return fileInfix;
    }
}
