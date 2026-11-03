package vn.edu.huit.finance.core.Service.Backup;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Cò súng của sao lưu tự động. Giờ chạy và công tắc đọc từ property (app.backup.cron, app.backup.zone, app.backup.enabled),
 * mặc định 02:00 giờ Việt Nam mỗi ngày. Việc làm thật nằm ở {@link ScheduledBackupService}.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ScheduledBackupJob {

    static final String DEFAULT_CRON = "0 0 2 * * *";
    static final String DEFAULT_ZONE = "Asia/Ho_Chi_Minh";

    private final ScheduledBackupService backupService;
    private final BackupScheduleSettings settings;

    @Scheduled(cron = "${app.backup.cron:" + DEFAULT_CRON + "}", zone = "${app.backup.zone:" + DEFAULT_ZONE + "}")
    public void run() {
        if (!settings.enabled()) {
            log.info("Scheduled backup is switched off (app.backup.enabled=false)");
            return;
        }
        backupService.runScheduledBackup();
    }
}
