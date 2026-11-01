package vn.edu.huit.finance.core.Service.Backup;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Lịch giữ bản sao lưu: 7 bản hằng ngày + 4 bản hằng tuần; ngày nào giữ, ngày nào xóa. */
class BackupRetentionTest {

    /** Một bản lúc 02:00 của mỗi ngày từ {@code first} đến {@code last} (cùng tháng 10/2026). */
    private static List<LocalDateTime> dailyBackups(int first, int last) {
        List<LocalDateTime> backups = new ArrayList<>();
        for (int day = first; day <= last; day++) {
            backups.add(LocalDateTime.of(2026, 10, day, 2, 0));
        }
        return backups;
    }

    private static List<LocalDateTime> kept(List<LocalDateTime> all) {
        List<LocalDateTime> deleted = BackupRetention.toDelete(all, backup -> backup);
        List<LocalDateTime> kept = new ArrayList<>(all);
        kept.removeAll(deleted);
        Collections.sort(kept);
        return kept;
    }

    private static LocalDateTime oct(int day) {
        return LocalDateTime.of(2026, 10, day, 2, 0);
    }

    @Test
    void theLimitsAreSevenDailyAndFourWeekly() {
        assertEquals(7, BackupRetention.DAILY_KEPT);
        assertEquals(4, BackupRetention.WEEKLY_KEPT);
    }

    @Test
    void aMonthOfDailyBackupsKeepsTheLastSevenDaysAndOneBackupOfEachOfTheFourWeeksBefore() {
        // 1-31/10/2026 (31/10 is a Saturday). Daily: 25-31. Weekly: the newest of each week before that window.
        List<LocalDateTime> kept = kept(dailyBackups(1, 31));

        assertEquals(List.of(oct(4), oct(11), oct(18), oct(24), oct(25), oct(26), oct(27), oct(28), oct(29), oct(30), oct(31)),
                kept);
    }

    @Test
    void backupsOlderThanTheDailyWindowAndNotTheNewestOfTheirWeekAreDeleted() {
        List<LocalDateTime> all = dailyBackups(1, 31);

        List<LocalDateTime> deleted = BackupRetention.toDelete(all, backup -> backup);

        assertTrue(deleted.contains(oct(23)), "23/10 is in the week of 24/10, which is kept");
        assertTrue(deleted.contains(oct(19)));
        assertTrue(deleted.contains(oct(1)), "older than the fourth weekly backup");
        assertEquals(31 - 11, deleted.size());
    }

    @Test
    void whenTheDailyWindowEndsInsideAWeekTheNewestBackupBeforeItStandsForThatWeek() {
        // Today is Wednesday 28/10: daily window 22-28/10. The week of 19/10 has 19-21 left over: only 21/10 stays.
        List<LocalDateTime> kept = kept(dailyBackups(19, 28));

        assertEquals(List.of(oct(21), oct(22), oct(23), oct(24), oct(25), oct(26), oct(27), oct(28)), kept);
    }

    @Test
    void twoBackupsOfTheSameDayKeepOnlyTheNewestOne() {
        LocalDateTime morning = LocalDateTime.of(2026, 10, 31, 2, 0);
        LocalDateTime evening = LocalDateTime.of(2026, 10, 31, 20, 0);

        List<LocalDateTime> deleted = BackupRetention.toDelete(List.of(morning, evening), backup -> backup);

        assertEquals(List.of(morning), deleted);
    }

    @Test
    void daysWithoutABackupDoNotShortenTheHistory() {
        // Backups failed for two weeks: the last seven days that HAVE a backup are kept, not the last seven calendar days.
        List<LocalDateTime> all = new ArrayList<>(dailyBackups(1, 7));
        all.add(oct(30));

        assertEquals(all.stream().sorted().toList(), kept(all));
    }

    @Test
    void fewerBackupsThanTheLimitsAreAllKept() {
        List<LocalDateTime> all = dailyBackups(29, 31);

        assertTrue(BackupRetention.toDelete(all, backup -> backup).isEmpty());
        assertTrue(BackupRetention.toDelete(List.<LocalDateTime>of(), backup -> backup).isEmpty());
    }

    @Test
    void theOrderOfTheInputDoesNotChangeTheResult() {
        List<LocalDateTime> all = dailyBackups(1, 31);
        List<LocalDateTime> shuffled = new ArrayList<>(all);
        Collections.reverse(shuffled);

        assertEquals(kept(all), kept(shuffled));
    }

    @Test
    void weeksStartOnMondayAndFollowTheCalendarAcrossTheMonthEnd() {
        // 2026-11-01 is a Sunday: the same week as 26-31/10. Daily window: 26/10-1/11 (7 days).
        List<LocalDateTime> all = new ArrayList<>(dailyBackups(1, 31));
        all.add(LocalDate.of(2026, 11, 1).atTime(2, 0));

        List<LocalDateTime> kept = kept(all);

        assertTrue(kept.contains(oct(25)), "Sunday 25/10 is the newest of its week and leaves the daily window");
        assertTrue(kept.contains(LocalDate.of(2026, 11, 1).atTime(2, 0)));
        assertEquals(11, kept.size());
    }
}
