package vn.edu.huit.finance.core.Service.Backup;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Function;

/**
 * Lịch giữ bản sao lưu: {@value #DAILY_KEPT} bản hằng ngày + {@value #WEEKLY_KEPT} bản hằng tuần, còn lại xóa.
 * <ul>
 *   <li>Hằng ngày: bản mới nhất của mỗi ngày, cho {@value #DAILY_KEPT} ngày gần nhất CÓ bản sao lưu (ngày sao lưu hỏng
 *       không làm lịch sử ngắn đi).</li>
 *   <li>Hằng tuần: trong số bản cũ hơn cửa sổ hằng ngày, bản mới nhất của mỗi tuần (tuần bắt đầu thứ Hai), cho
 *       {@value #WEEKLY_KEPT} tuần gần nhất. Khi một bản rời cửa sổ hằng ngày, nó thành bản của tuần của nó nếu là bản
 *       mới nhất của tuần đó.</li>
 * </ul>
 * Hàm thuần, không đụng đĩa hay MongoDB: dùng chung cho thư mục backups/ và cho GridFS.
 */
public final class BackupRetention {

    public static final int DAILY_KEPT = 7;
    public static final int WEEKLY_KEPT = 4;

    private BackupRetention() {
    }

    /** Những bản phải xóa, cũ nhất trước. */
    public static <T> List<T> toDelete(Collection<T> backups, Function<T, LocalDateTime> createdAt) {
        List<T> newestFirst = new ArrayList<>(backups);
        newestFirst.sort(Comparator.comparing(createdAt).reversed());

        Set<T> kept = new HashSet<>();
        Set<LocalDate> days = new HashSet<>();
        for (T backup : newestFirst) {
            if (days.size() < DAILY_KEPT && days.add(createdAt.apply(backup).toLocalDate())) {
                kept.add(backup);
            }
        }
        // Only what is older than the daily window can stand for a week: a second backup of a day inside it is just extra.
        LocalDate windowStart = days.stream().min(Comparator.naturalOrder()).orElse(LocalDate.MIN);
        Set<LocalDate> weeks = new HashSet<>();
        for (T backup : newestFirst) {
            LocalDateTime time = createdAt.apply(backup);
            if (time.toLocalDate().isBefore(windowStart) && weeks.size() < WEEKLY_KEPT && weeks.add(weekStart(time))) {
                kept.add(backup);
            }
        }

        List<T> doomed = new ArrayList<>();
        for (int i = newestFirst.size() - 1; i >= 0; i--) {
            if (!kept.contains(newestFirst.get(i))) {
                doomed.add(newestFirst.get(i));
            }
        }
        return doomed;
    }

    private static LocalDate weekStart(LocalDateTime time) {
        return time.toLocalDate().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
    }
}
