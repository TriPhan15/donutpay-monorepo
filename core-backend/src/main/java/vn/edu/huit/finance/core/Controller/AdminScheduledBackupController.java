package vn.edu.huit.finance.core.Controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import vn.edu.huit.finance.core.Dto.ScheduledBackupStatusDto;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Backup.MongoRestoreOutcome;
import vn.edu.huit.finance.core.Service.Backup.ScheduledBackupService;

import java.util.HashMap;
import java.util.Map;

/**
 * The automatic-backup half of the admin backup page (/admin/backup): the status of the last run, and the destructive
 * button that restores PostgreSQL from the copy in MongoDB. Closed to everybody without ROLE_ADMIN twice, by the /admin/**
 * rule of SecurityConfig and by @PreAuthorize. Same JSON answer as the other backup buttons ({success, message}).
 */
@Controller
@RequestMapping("/admin/backup/scheduled")
@PreAuthorize(Roles.HAS_ADMIN)
public class AdminScheduledBackupController {

    private static final String MSG_RESTORED = "Đã phục hồi PostgreSQL từ bản sao lưu mới nhất trong MongoDB!";
    private static final String MSG_BUSY = "Đang sao lưu hoặc phục hồi, vui lòng đợi";
    private static final String MSG_NO_COPY = "MongoDB chưa có bản sao lưu nào.";
    private static final String MSG_STORE_UNAVAILABLE = "Không tải được bản sao lưu từ MongoDB. Kiểm tra kết nối MongoDB.";
    private static final String MSG_INVALID_COPY = "Bản sao lưu trong MongoDB có tên không hợp lệ, không phục hồi.";
    private static final String MSG_CHECKSUM_MISMATCH =
            "Bản sao lưu trong MongoDB không khớp mã kiểm tra SHA-256 đã lưu, không phục hồi.";
    private static final String MSG_RESTORE_FAILED = "Lỗi phục hồi! pg_restore thất bại.";

    @Autowired private ScheduledBackupService scheduledBackupService;

    @GetMapping("/status")
    @ResponseBody
    public ScheduledBackupStatusDto status() {
        return scheduledBackupService.latestStatus();
    }

    @PostMapping("/run-now")
    @ResponseBody
    public Map<String, Object> runNow() {
        scheduledBackupService.runScheduledBackup();
        ScheduledBackupStatusDto status = scheduledBackupService.latestStatus();
        Map<String, Object> response = new HashMap<>();
        boolean ok = status != null && status.hasRun() && Boolean.TRUE.equals(status.success());
        response.put("success", ok);
        response.put("message", ok
                ? "Đã chạy sao lưu toàn bộ thành công lên ổ đĩa và MongoDB!"
                : "Sao lưu tự động không hoàn tất: "
                        + (status != null && status.failureReason() != null
                                ? status.failureReason()
                                : "Vui lòng kiểm tra kết nối PostgreSQL/MongoDB."));
        response.put("status", status);
        return response;
    }

    @PostMapping("/restore-from-mongo")
    @ResponseBody
    public Map<String, Object> restoreFromMongo() {
        MongoRestoreOutcome outcome = scheduledBackupService.restoreFromMongo();
        Map<String, Object> response = new HashMap<>();
        response.put("success", outcome == MongoRestoreOutcome.RESTORED);
        response.put("message", messageOf(outcome));
        return response;
    }

    private static String messageOf(MongoRestoreOutcome outcome) {
        return switch (outcome) {
            case RESTORED -> MSG_RESTORED;
            case BUSY -> MSG_BUSY;
            case NO_COPY -> MSG_NO_COPY;
            case STORE_UNAVAILABLE -> MSG_STORE_UNAVAILABLE;
            case INVALID_COPY -> MSG_INVALID_COPY;
            case CHECKSUM_MISMATCH -> MSG_CHECKSUM_MISMATCH;
            case RESTORE_FAILED -> MSG_RESTORE_FAILED;
        };
    }
}
