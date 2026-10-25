package vn.edu.huit.finance.core.Entity;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Các loại sao lưu mà pg_dump thật sự làm được. PostgreSQL không có bản sao lưu vi sai (differential) hay sao lưu nhật ký
 * (log) qua pg_dump (việc đó cần WAL archiving / pg_basebackup), nên trang quản trị chỉ đưa ra ba loại dưới đây.
 * Chỉ bản {@link #FULL} mới dùng để phục hồi: bản chỉ cấu trúc không có dữ liệu, bản chỉ dữ liệu không tạo lại được bảng.
 */
public enum BackupType {
    /** Toàn bộ cơ sở dữ liệu: cấu trúc + dữ liệu + large objects. */
    FULL("toàn bộ cơ sở dữ liệu", List.of("-b")),
    /** Chỉ cấu trúc (bảng, chỉ mục, ràng buộc), không có dòng dữ liệu nào. */
    SCHEMA_ONLY("chỉ cấu trúc (schema)", List.of("--schema-only")),
    /** Chỉ dữ liệu, không có lệnh tạo bảng. */
    DATA_ONLY("chỉ dữ liệu", List.of("--data-only", "-b"));

    private final String label;
    private final List<String> pgDumpOptions;

    BackupType(String label, List<String> pgDumpOptions) {
        this.label = label;
        this.pgDumpOptions = pgDumpOptions;
    }

    public String getLabel() {
        return label;
    }

    /** Tham số riêng của loại này cho pg_dump (thêm vào sau các tham số chung). */
    public List<String> getPgDumpOptions() {
        return pgDumpOptions;
    }

    /** Tiền tố tên file sao lưu của loại này, ví dụ FULL_backup_20260930_120000.sql. */
    public String filePrefix() {
        return name() + "_backup_";
    }

    /** Đọc tham số "type" của trang quản trị; giá trị lạ (kể cả DIFF, LOG cũ) thì rỗng. */
    public static Optional<BackupType> fromParam(String value) {
        if (value == null) {
            return Optional.empty();
        }
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        return Arrays.stream(values()).filter(type -> type.name().equals(normalized)).findFirst();
    }
}
