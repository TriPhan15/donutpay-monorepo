package vn.edu.huit.finance.core.Service.Backup;

import vn.edu.huit.finance.core.Entity.BackupOrigin;
import vn.edu.huit.finance.core.Entity.BackupType;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Optional;
import java.util.regex.Pattern;

/** Một file sao lưu trong thư mục backups/ và thời điểm tạo, đọc từ chính tên file. */
public record BackupFile(String name, LocalDateTime createdAt) {

    public static final String EXTENSION = ".sql";
    public static final DateTimeFormatter TIMESTAMP = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");
    private static final Pattern TIMESTAMP_TEXT = Pattern.compile("\\d{8}_\\d{6}");

    /**
     * Đọc tên dạng {@code <LOẠI>_backup_[auto_]yyyyMMdd_HHmmss.sql}; rỗng khi tên thuộc loại hoặc nguồn khác, có thêm đuôi
     * (.partial) hoặc mốc thời gian không hợp lệ. Đây cũng là kiểm tra tên trước khi ghi một file tải về từ MongoDB.
     */
    public static Optional<BackupFile> parse(String name, BackupType type, BackupOrigin origin) {
        String prefix = type.filePrefix() + origin.fileInfix();
        if (name == null || !name.startsWith(prefix) || !name.endsWith(EXTENSION)) {
            return Optional.empty();
        }
        String stamp = name.substring(prefix.length(), name.length() - EXTENSION.length());
        if (!TIMESTAMP_TEXT.matcher(stamp).matches()) {
            return Optional.empty();
        }
        try {
            return Optional.of(new BackupFile(name, LocalDateTime.parse(stamp, TIMESTAMP)));
        } catch (DateTimeParseException e) {
            return Optional.empty();
        }
    }
}
