package vn.edu.huit.finance.core.Dto;

import java.time.LocalDateTime;

/**
 * Phần "Sao lưu tự động" của trang Sao lưu: lịch, lần chạy gần nhất (thành công hay không, dung lượng) và nơi lưu
 * (đĩa, MongoDB). {@code hasRun} false khi chưa có lần nào; khi đó các trường còn lại của lần chạy là rỗng.
 */
public record ScheduledBackupStatusDto(
        boolean enabled,
        String cron,
        String zone,
        boolean hasRun,
        LocalDateTime lastRunAt,
        boolean success,
        String failureReason,
        String fileName,
        Long sizeBytes,
        String sha256,
        boolean onDisk,
        boolean inMongo) {
}
