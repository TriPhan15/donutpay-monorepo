package vn.edu.huit.finance.core.Controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import vn.edu.huit.finance.core.Service.MongoBackupService;

import java.util.HashMap;
import java.util.Map;

/**
 * The MongoDB half of the admin backup page (/admin/backup), next to the PostgreSQL buttons of AdminController. Same JSON
 * answer as theirs ({success, message}); like every /admin/** URL it is reachable by administrators only (SecurityConfig).
 */
@Controller
@RequestMapping("/admin/backup/mongo")
public class AdminMongoBackupController {
    private static final String MSG_BACKUP_SUCCESS = "Đã sao lưu MongoDB (ocr_logs, ocr_feedbacks) thành công!";
    private static final String MSG_BACKUP_FAILED = "Lỗi sao lưu MongoDB! Kiểm tra mongodump và kết nối MongoDB.";
    private static final String MSG_RESTORE_SUCCESS = "Đã phục hồi ocr_logs và ocr_feedbacks từ bản sao lưu MongoDB mới nhất!";
    private static final String MSG_RESTORE_FAILED = "Lỗi phục hồi MongoDB! Không tìm thấy bản sao lưu hoặc mongorestore lỗi.";

    private static final String MSG_BUSY = "Đang sao lưu/khôi phục MongoDB, vui lòng đợi";

    @Autowired private MongoBackupService mongoBackupService;

    @PostMapping("/execute")
    @ResponseBody
    public Map<String, Object> executeBackup() {
        try {
            return answer(mongoBackupService.backup(), MSG_BACKUP_SUCCESS, MSG_BACKUP_FAILED);
        } catch (MongoBackupService.BusyException e) {
            return answer(false, "", MSG_BUSY);
        }
    }

    @PostMapping("/restore")
    @ResponseBody
    public Map<String, Object> executeRestore() {
        try {
            return answer(mongoBackupService.restoreLatest(), MSG_RESTORE_SUCCESS, MSG_RESTORE_FAILED);
        } catch (MongoBackupService.BusyException e) {
            return answer(false, "", MSG_BUSY);
        }
    }

    private static Map<String, Object> answer(boolean success, String ok, String failed) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", success);
        response.put("message", success ? ok : failed);
        return response;
    }
}
