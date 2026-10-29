package vn.edu.huit.finance.core.Util;

import vn.edu.huit.finance.core.Entity.Receipt;

import java.util.regex.Pattern;

/**
 * Luật cho link ảnh hóa đơn do client gửi lên. Link được admin bấm mở trên trang /admin/receipts, nên chỉ nhận
 * {@code https://}: một link {@code javascript:} hay {@code data:} sẽ chạy script với phiên của admin (XSS lưu trữ).
 */
public final class ImageUrls {

    /** Bằng độ dài cột receipts.image_url. */
    public static final int MAX_LENGTH = Receipt.IMAGE_URL_MAX_LENGTH;

    /** Rỗng (bỏ qua ảnh) hoặc một link https không có khoảng trắng; khoảng trắng hai đầu được trim khi lưu. */
    public static final String HTTPS_OR_BLANK_REGEX = "(?i)^\\s*(https://\\S+)?\\s*$";

    public static final String MSG_INVALID = "Link ảnh hóa đơn phải là một địa chỉ https://";

    private static final Pattern HTTPS_URL = Pattern.compile("(?i)^https://\\S+$");

    private ImageUrls() {
    }

    /** True khi {@code url} (đã trim) là một link https đủ ngắn để lưu. */
    public static boolean isSafe(String url) {
        return url != null && url.length() <= MAX_LENGTH && HTTPS_URL.matcher(url).matches();
    }
}
