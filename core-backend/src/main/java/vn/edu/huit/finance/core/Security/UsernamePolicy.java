package vn.edu.huit.finance.core.Security;

/**
 * Quy tắc tên đăng nhập. Tên đăng nhập chứa @ chỉ hợp lệ khi trùng với email của chính tài khoản đó, để nó
 * không bao giờ trùng với email của người khác (tên đăng nhập "victim@x.com" từng chiếm được token/đăng nhập
 * của chủ email đó).
 */
public final class UsernamePolicy {

    public static final String MESSAGE = "Tên đăng nhập chứa @ phải trùng với email của bạn";

    private static final String AT_SIGN = "@";

    private UsernamePolicy() {
    }

    /** True khi tên đăng nhập không chứa @, hoặc trùng với email của chính tài khoản (không phân biệt hoa thường). */
    public static boolean isAllowed(String username, String email) {
        if (username == null || !username.contains(AT_SIGN)) {
            return true;
        }
        return email != null && username.equalsIgnoreCase(email);
    }
}
