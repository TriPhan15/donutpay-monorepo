package vn.edu.huit.finance.core.Service.Backup;

import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * Chạy công cụ ngoài (pg_dump, pg_restore) và trả về mã thoát. Tách khỏi BackupService để test không phải gọi pg_dump
 * thật: test thay bằng bản giả. Mật khẩu chỉ đi qua {@code environment}, không bao giờ nằm trong tham số dòng lệnh.
 */
public interface ExternalCommandRunner {

    /** Đầu ra của công cụ đi thẳng ra đầu ra của ứng dụng (pg_dump -v báo tiến độ). */
    int run(List<String> command, Map<String, String> environment) throws IOException, InterruptedException;

    /** Bỏ đầu ra chuẩn (pg_restore --list in cả mục lục của file); lỗi vẫn hiện ở đầu ra lỗi. */
    int runQuietly(List<String> command, Map<String, String> environment) throws IOException, InterruptedException;
}
