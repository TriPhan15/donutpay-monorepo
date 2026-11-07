package vn.edu.huit.finance.core.Dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Phản hồi trạng thái đồng bộ của 5 Collection sao lưu chọn lọc trên MongoDB
 * và chế độ Đọc Dự phòng (Read-Fallback) cho trang quản trị {@code /admin/backup}.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MirrorStatusResponseDto {

    private boolean postgresUp;
    private boolean mongoUp;
    private boolean forceFailoverEnabled;
    private boolean autoFailoverActive;
    private boolean failoverActive;
    private String effectiveReadSource;
    private LocalDateTime lastSyncTime;
    private LocalDateTime lastRestoreTime;
    private List<CollectionMirrorStat> collections;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CollectionMirrorStat {
        private String mongoCollection;
        private String postgresTable;
        private String description;
        private long postgresCount;
        private long mongoCount;
        private int diffCount;
        private boolean synced;
    }
}
