package vn.edu.huit.finance.core.Service.Backup;

/** Kết quả của nút "Khôi phục từ bản trong MongoDB". Chỉ {@link #RESTORED} là PostgreSQL đã được thay bằng bản sao lưu. */
public enum MongoRestoreOutcome {
    RESTORED,
    /** Một lần sao lưu hoặc khôi phục khác đang chạy. */
    BUSY,
    /** MongoDB chưa có bản sao nào. */
    NO_COPY,
    /** Không liên lạc được MongoDB hoặc tải về dở chừng. */
    STORE_UNAVAILABLE,
    /** Tên bản sao không phải tên của một bản FULL tự động (không bao giờ ghi file có tên lạ vào thư mục backups). */
    INVALID_COPY,
    /** SHA-256 của file tải về khác SHA-256 đã lưu, hoặc bản sao không có SHA-256: file bị xóa, không khôi phục. */
    CHECKSUM_MISMATCH,
    /** File đã qua kiểm tra nhưng restoreDatabase (pg_restore) thất bại. */
    RESTORE_FAILED
}
