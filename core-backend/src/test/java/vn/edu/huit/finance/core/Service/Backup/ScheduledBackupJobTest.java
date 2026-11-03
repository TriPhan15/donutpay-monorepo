package vn.edu.huit.finance.core.Service.Backup;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.ClassPathResource;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.support.CronExpression;
import org.springframework.core.env.StandardEnvironment;

import java.io.IOException;
import java.io.InputStream;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Properties;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/** The trigger of the daily backup: the cron and the switch come from properties, 02:00 Vietnam time by default. */
@ExtendWith(MockitoExtension.class)
class ScheduledBackupJobTest {

    private static final ZoneId VIETNAM = ZoneId.of("Asia/Ho_Chi_Minh");

    @Mock private ScheduledBackupService service;

    @Test
    void whenSwitchedOffNothingRuns() {
        new ScheduledBackupJob(service, new BackupScheduleSettings(false, "0 0 2 * * *", "Asia/Ho_Chi_Minh")).run();

        verifyNoInteractions(service);
    }

    @Test
    void whenSwitchedOnTheBackupRuns() {
        new ScheduledBackupJob(service, new BackupScheduleSettings(true, "0 0 2 * * *", "Asia/Ho_Chi_Minh")).run();

        verify(service).runScheduledBackup();
    }

    @Test
    void theCronAndTheZoneOfTheJobAreReadFromPropertiesWithTheDefaultOfTwoInTheMorningInVietnam() throws NoSuchMethodException {
        Scheduled scheduled = ScheduledBackupJob.class.getMethod("run").getAnnotation(Scheduled.class);

        assertNotNull(scheduled);
        assertEquals("${app.backup.cron:0 0 2 * * *}", scheduled.cron());
        assertEquals("${app.backup.zone:Asia/Ho_Chi_Minh}", scheduled.zone());
    }

    @Test
    void theDefaultCronFiresAtTwoEveryDayOfVietnamTime() {
        CronExpression cron = CronExpression.parse(ScheduledBackupJob.DEFAULT_CRON);

        ZonedDateTime next = cron.next(ZonedDateTime.of(2026, 11, 1, 1, 0, 0, 0, VIETNAM));
        ZonedDateTime afterThat = cron.next(next);

        assertEquals(ZonedDateTime.of(2026, 11, 1, 2, 0, 0, 0, VIETNAM), next);
        assertEquals(ZonedDateTime.of(2026, 11, 2, 2, 0, 0, 0, VIETNAM), afterThat);
        assertEquals("Asia/Ho_Chi_Minh", ScheduledBackupJob.DEFAULT_ZONE);
    }

    @Test
    void theModulePropertiesFileHoldsTheThreeKeysWithTheirDefaults() throws IOException {
        Properties properties = new Properties();
        try (InputStream in = new ClassPathResource("ocr-analytics.properties").getInputStream()) {
            properties.load(new java.io.InputStreamReader(in, java.nio.charset.StandardCharsets.UTF_8));
        }
        StandardEnvironment environment = new StandardEnvironment();

        assertEquals("true", environment.resolvePlaceholders(properties.getProperty("app.backup.enabled")));
        assertEquals("0 0 2 * * *", environment.resolvePlaceholders(properties.getProperty("app.backup.cron")));
        assertEquals("Asia/Ho_Chi_Minh", environment.resolvePlaceholders(properties.getProperty("app.backup.zone")));
        assertTrue(properties.stringPropertyNames().stream().noneMatch(key -> key.toLowerCase().contains("password")),
                "no secret in the file");
    }
}
