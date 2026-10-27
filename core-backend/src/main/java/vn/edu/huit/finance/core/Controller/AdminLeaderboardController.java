package vn.edu.huit.finance.core.Controller;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;

import java.time.YearMonth;
import java.util.List;

/**
 * The users who spent the most in a month, from the Redis leaderboard. Closed to everybody without ROLE_ADMIN by the
 * /api/admin/** rule of SecurityConfig and again by @PreAuthorize.
 */
@RestController
@RequestMapping("/api/admin/leaderboard")
@PreAuthorize(Roles.HAS_ADMIN)
@Validated
public class AdminLeaderboardController {

    static final int DEFAULT_LIMIT = 10;
    static final int MIN_LIMIT = 1;
    static final int MAX_LIMIT = 50;

    private static final String MSG_LEADERBOARD_OK = "Lấy bảng xếp hạng chi tiêu thành công";

    private static final String MSG_REBUILD_OK = "Đã dựng lại bảng xếp hạng chi tiêu từ cơ sở dữ liệu";

    private final SpendingLeaderboardService leaderboardService;
    private final AdminEventPublisher adminEvents;

    public AdminLeaderboardController(SpendingLeaderboardService leaderboardService, AdminEventPublisher adminEvents) {
        this.leaderboardService = leaderboardService;
        this.adminEvents = adminEvents;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<TopSpenderDto>>> getLeaderboard(
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM") YearMonth month,
            @RequestParam(defaultValue = "" + DEFAULT_LIMIT) @Min(MIN_LIMIT) @Max(MAX_LIMIT) int limit) {
        YearMonth requested = month != null ? month : YearMonth.now();
        return ApiResponses.respond(HttpStatus.OK, MSG_LEADERBOARD_OK, leaderboardService.topSpenders(requested, limit));
    }

    /** Recovery path for a month left stale by a lost event: drops its set and rebuilds it from PostgreSQL. */
    @PostMapping("/rebuild")
    public ResponseEntity<ApiResponse<Integer>> rebuild(
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM") YearMonth month) {
        YearMonth requested = month != null ? month : YearMonth.now();
        int members = leaderboardService.rebuildMonth(requested);
        adminEvents.publish(AdminEvent.leaderboardRebuilt(requested, members));
        return ApiResponses.respond(HttpStatus.OK, MSG_REBUILD_OK, members);
    }
}
