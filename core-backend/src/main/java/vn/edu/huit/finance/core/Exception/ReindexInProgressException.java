package vn.edu.huit.finance.core.Exception;

/** Một lần dựng lại chỉ mục tìm kiếm đang chạy; lần thứ hai bị từ chối thay vì chạy song song. */
public class ReindexInProgressException extends RuntimeException {

    public static final String MESSAGE = "Đang dựng lại chỉ mục, vui lòng đợi";

    public ReindexInProgressException() {
        super(MESSAGE);
    }
}
