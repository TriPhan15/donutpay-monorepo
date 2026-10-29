package vn.edu.huit.finance.core.Service;

/** Kết quả của {@link UserService#deleteUser}: xóa hẳn, hoặc chỉ khóa vì tài khoản đã có dữ liệu. */
public enum UserDeletionOutcome {
    /** Tài khoản không có dữ liệu liên quan và đã bị xóa vĩnh viễn. */
    DELETED,
    /** Tài khoản đã có giao dịch hoặc dữ liệu khác, nên chỉ bị khóa (active = false) để giữ dữ liệu. */
    LOCKED
}
