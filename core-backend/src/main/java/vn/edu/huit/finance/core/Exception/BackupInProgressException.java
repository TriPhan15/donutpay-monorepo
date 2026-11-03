package vn.edu.huit.finance.core.Exception;

/** Một lần sao lưu hoặc khôi phục khác đang chạy; lần bấm tay bị từ chối thay vì chạy song song. */
public class BackupInProgressException extends RuntimeException {

    public static final String MESSAGE = "Đang có một lần sao lưu hoặc khôi phục khác chạy, vui lòng thử lại sau.";

    public BackupInProgressException() {
        super(MESSAGE);
    }
}
