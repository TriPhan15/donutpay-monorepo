package vn.edu.huit.finance.core.Controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import vn.edu.huit.finance.core.Dto.MirrorDiffItemDto;
import vn.edu.huit.finance.core.Dto.MirrorStatusResponseDto;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Backup.MongoMirrorDiffService;
import vn.edu.huit.finance.core.Service.Backup.MongoSelectiveMirrorService;
import vn.edu.huit.finance.core.Service.Backup.MongoSelectiveRestoreService;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Điều khiển Sao lưu Chọn lọc 5 Collection (Selective Collection Mirroring), Phục hồi Ngược về PostgreSQL,
 * Đối soát Chênh lệch Từng dòng (Diff Inspector - Human-in-the-Loop) và Công tắc Giả lập Đọc Dự phòng
 * (Force MongoDB Failover Mode) trên trang {@code /admin/backup}.
 */
@Slf4j
@Controller
@RequestMapping("/admin/backup/mirror")
@PreAuthorize(Roles.HAS_ADMIN)
@RequiredArgsConstructor
public class AdminMongoMirrorBackupController {

    private final MongoSelectiveMirrorService mirrorService;
    private final MongoMirrorDiffService diffService;
    private final MongoSelectiveRestoreService restoreService;
    private final MongoStandbyFailoverService failoverService;

    @GetMapping("/status")
    @ResponseBody
    public MirrorStatusResponseDto getStatus() {
        return mirrorService.getMirrorStatus();
    }

    @GetMapping("/diffs")
    @ResponseBody
    public List<MirrorDiffItemDto> getDiffs(
            @RequestParam(value = "collection", required = false, defaultValue = "ALL") String collection) {
        return diffService.getCollectionDiffs(collection);
    }

    @PostMapping("/resolve-diff")
    @ResponseBody
    public Map<String, Object> resolveDiff(@RequestParam("collection") String collection,
                                           @RequestParam("recordId") Long recordId,
                                           @RequestParam("action") String action) {
        Map<String, Object> response = new LinkedHashMap<>();
        try {
            String message;
            switch (action) {
                case "APPLY_MONGO_TO_PG" -> {
                    restoreService.restoreSingleRecordFromMongoToPostgres(collection, recordId);
                    message = String.format("Đã khôi phục/cập nhật bản ghi #%d từ [%s] về PostgreSQL!", recordId, collection);
                }
                case "APPLY_PG_TO_MONGO" -> {
                    mirrorService.syncSingleRecordFromPostgresToMongo(collection, recordId);
                    message = String.format("Đã sao lưu/cập nhật bản ghi #%d từ PostgreSQL sang [%s]!", recordId, collection);
                }
                case "DELETE_FROM_MONGO" -> {
                    mirrorService.deleteSingleRecordFromMongo(collection, recordId);
                    message = String.format("Đã xóa bản ghi #%d khỏi [%s] trên MongoDB!", recordId, collection);
                }
                case "DELETE_FROM_PG" -> {
                    restoreService.deleteSingleRecordFromPostgres(collection, recordId);
                    message = String.format("Đã xóa bản ghi #%d khỏi PostgreSQL và [%s]!", recordId, collection);
                }
                default -> throw new IllegalArgumentException("Hành động đối soát không hợp lệ: " + action);
            }
            response.put("success", true);
            response.put("message", message);
            response.put("status", mirrorService.getMirrorStatus());
            return response;
        } catch (RuntimeException e) {
            log.error("Failed to resolve diff item (collection={}, recordId={}, action={})", collection, recordId, action, e);
            response.put("success", false);
            response.put("message", "Lỗi xử lý đối soát: "
                    + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()));
            return response;
        }
    }

    @PostMapping("/sync")
    @ResponseBody
    public Map<String, Object> syncToMongo() {
        Map<String, Object> response = new LinkedHashMap<>();
        try {
            restoreService.reconcilePendingStandbyWritesIfNeeded();
            Map<String, Object> summary = mirrorService.syncAllFromPostgresToMongo();
            failoverService.markStandbyWritePending(false);
            long totalDocs = toLong(summary.get("users"))
                    + toLong(summary.get("categories"))
                    + toLong(summary.get("transactions"))
                    + toLong(summary.get("budgets"))
                    + toLong(summary.get("savingGoals"));
            response.put("success", true);
            response.put("message", String.format(
                    "Đã đồng bộ thành công %d Document từ PostgreSQL sang 5 Collection dự phòng trên MongoDB!",
                    totalDocs));
            response.put("counts", summary);
            response.put("status", mirrorService.getMirrorStatus());
            return response;
        } catch (RuntimeException e) {
            log.error("Manual sync from PostgreSQL to MongoDB standby collections failed", e);
            response.put("success", false);
            response.put("message", "Lỗi đồng bộ sang MongoDB: "
                    + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()));
            return response;
        }
    }

    @PostMapping("/restore")
    @ResponseBody
    public Map<String, Object> restoreToPostgres() {
        Map<String, Object> response = new LinkedHashMap<>();
        try {
            Map<String, Object> summary = restoreService.restoreAllFromMongoToPostgres();
            long totalRows = toLong(summary.get("users"))
                    + toLong(summary.get("categories"))
                    + toLong(summary.get("receipts"))
                    + toLong(summary.get("transactions"))
                    + toLong(summary.get("budgets"))
                    + toLong(summary.get("savingGoals"));
            response.put("success", true);
            response.put("message", String.format(
                    "Đã đồng bộ ngược thành công %d bản ghi từ 5 Collection MongoDB về 6 bảng PostgreSQL!",
                    totalRows));
            response.put("counts", summary);
            response.put("status", mirrorService.getMirrorStatus());
            return response;
        } catch (RuntimeException e) {
            log.error("Restore from MongoDB standby collections to PostgreSQL failed", e);
            response.put("success", false);
            response.put("message", "Lỗi phục hồi về PostgreSQL: "
                    + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()));
            return response;
        }
    }

    @PostMapping("/failover")
    @ResponseBody
    public Map<String, Object> toggleFailover(@RequestParam("enabled") boolean enabled) {
        failoverService.setForceFailoverEnabled(enabled);
        if (!enabled) {
            restoreService.reconcilePendingStandbyWritesIfNeeded();
        }
        MirrorStatusResponseDto status = mirrorService.getMirrorStatus();

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("success", true);
        response.put("forceFailoverEnabled", enabled);
        response.put("failoverActive", status != null && status.isFailoverActive());
        response.put("message", enabled
                ? "Đã bật chế độ giả lập đọc dự phòng trên MongoDB!"
                : "Đã tắt chế độ giả lập đọc dự phòng, hệ thống quay lại sử dụng PostgreSQL!");
        response.put("status", status);
        return response;
    }

    private static long toLong(Object val) {
        return (val instanceof Number n) ? n.longValue() : 0L;
    }
}
