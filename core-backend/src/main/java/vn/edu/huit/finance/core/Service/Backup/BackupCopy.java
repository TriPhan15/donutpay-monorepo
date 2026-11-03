package vn.edu.huit.finance.core.Service.Backup;

import java.time.LocalDateTime;

/** Một bản sao lưu đã lưu trong MongoDB (GridFS): tên file gốc, thời điểm sao lưu, dung lượng và SHA-256 lúc lưu. */
public record BackupCopy(String id, String fileName, LocalDateTime createdAt, long sizeBytes, String sha256) {
}
