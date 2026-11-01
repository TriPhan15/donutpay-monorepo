package vn.edu.huit.finance.core.Service.Backup;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Cấu hình lịch sao lưu tự động (app.backup.* trong ocr-analytics.properties; biến môi trường ghi đè). */
@Component
public class BackupScheduleSettings {

    private final boolean enabled;
    private final String cron;
    private final String zone;

    public BackupScheduleSettings(
            @Value("${app.backup.enabled:true}") boolean enabled,
            @Value("${app.backup.cron:" + ScheduledBackupJob.DEFAULT_CRON + "}") String cron,
            @Value("${app.backup.zone:" + ScheduledBackupJob.DEFAULT_ZONE + "}") String zone) {
        this.enabled = enabled;
        this.cron = cron;
        this.zone = zone;
    }

    public boolean enabled() {
        return enabled;
    }

    public String cron() {
        return cron;
    }

    public String zone() {
        return zone;
    }
}
