package vn.edu.huit.finance.core.Service.Backup;

import java.io.IOException;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Nơi giữ bản sao thứ hai của các bản sao lưu PostgreSQL. Hiện là MongoDB GridFS ({@link GridFsBackupCopyStore}).
 * Mongo nằm cùng máy chủ với PostgreSQL, nên bản sao này chỉ chống lỗi file hoặc ổ đĩa của PostgreSQL, không chống mất cả
 * máy chủ.
 */
public interface BackupCopyStore {

    /** Lưu nội dung {@code file} cùng SHA-256 đã tính; ném RuntimeException khi MongoDB không ghi được. */
    BackupCopy save(Path file, String fileName, LocalDateTime createdAt, String sha256);

    /** Mọi bản đang lưu, mới nhất trước. */
    List<BackupCopy> list();

    /** Xóa bản có id này (file và các khối của nó). */
    void delete(String id);

    /** Ghi nội dung của bản vào {@code target} (ghi đè nếu đã có). */
    void downloadTo(BackupCopy copy, Path target) throws IOException;
}
