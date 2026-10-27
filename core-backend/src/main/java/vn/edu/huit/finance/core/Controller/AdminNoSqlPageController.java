package vn.edu.huit.finance.core.Controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import vn.edu.huit.finance.core.Config.SearchConfig;
import vn.edu.huit.finance.core.Config.SearchEngineType;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.FieldCount;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.ModelCount;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.MonthlyConfidence;
import vn.edu.huit.finance.core.Dto.OcrFeedbackFilterRequestDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Exception.OcrFeedbackNotFoundException;
import vn.edu.huit.finance.core.Exception.ReindexInProgressException;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.OcrMongoService;
import vn.edu.huit.finance.core.Service.Search.TransactionSearchIndexer;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.time.format.DateTimeParseException;

/**
 * The NoSQL pages of the admin web: the OCR feedbacks and analytics of MongoDB, and the operations page that rebuilds the
 * Elasticsearch index and the Redis leaderboard. Closed to everybody without ROLE_ADMIN twice, by the /admin/** rule of
 * SecurityConfig and by @PreAuthorize. A failure of a NoSQL store is logged and shown as a Vietnamese banner or flash
 * message, never as an error page.
 */
@Slf4j
@Controller
@RequestMapping("/admin")
@PreAuthorize(Roles.HAS_ADMIN)
public class AdminNoSqlPageController {

    static final String MSG_SEARCH_DISABLED = "Tìm kiếm Elasticsearch đang tắt (công cụ tìm kiếm hiện là PostgreSQL), không có chỉ mục để dựng lại";
    static final String MSG_REINDEX_FAILED = "Không dựng lại được chỉ mục tìm kiếm, vui lòng thử lại sau";
    static final String MSG_FILTER_INVALID = "Bộ lọc có giá trị không hợp lệ (trường, trạng thái hoặc ngày), đã bỏ qua giá trị đó";
    static final String MSG_MONTH_INVALID = "Tháng không hợp lệ, hãy chọn lại theo dạng yyyy-MM";

    private static final String FEEDBACKS_URL = "/admin/ocr-feedbacks";
    private static final String NOSQL_URL = "/admin/nosql";
    private static final String REDIRECT = "redirect:";

    private static final String FLASH_MESSAGE = "message";
    private static final String FLASH_ERROR = "error";

    private static final int FEEDBACK_PAGE_SIZE = 20;
    private static final int LEADERBOARD_SIZE = 10;
    private static final double PERCENT = 100.0;

    private static final String MSG_RESOLVE_OK = "Đã đánh dấu phản hồi OCR là đã xử lý";
    private static final String MSG_DELETE_OK = "Đã xóa phản hồi OCR";
    private static final String MSG_MONGO_DOWN = "Không kết nối được MongoDB, vui lòng thử lại sau";
    private static final String MSG_MONGO_READ_FAILED = "Không đọc được dữ liệu MongoDB, vui lòng thử lại sau";
    private static final String MSG_REINDEX_OK = "Đã dựng lại chỉ mục tìm kiếm: %d giao dịch";
    private static final String MSG_REBUILD_OK = "Đã dựng lại bảng xếp hạng tháng %s: %d người dùng";
    private static final String MSG_REBUILD_FAILED = "Không dựng lại được bảng xếp hạng, vui lòng thử lại sau";
    private static final String MSG_LEADERBOARD_READ_FAILED = "Không đọc được bảng xếp hạng từ Redis, vui lòng thử lại sau";
    private static final String MSG_SEARCH_READ_FAILED = "Không đọc được chỉ mục Elasticsearch, vui lòng thử lại sau";

    /** Vietnamese names of the fields of a receipt, by the key stored in ocr_feedbacks. */
    private static final Map<String, String> FIELD_LABELS = Map.of(
            OcrField.SELLER_NAME.key(), "Tên cửa hàng",
            OcrField.TOTAL_COST.key(), "Tổng tiền",
            OcrField.RECEIPT_DATE.key(), "Ngày hóa đơn");

    private final OcrMongoService ocrMongoService;
    private final SpendingLeaderboardService leaderboardService;
    private final ObjectProvider<TransactionSearchIndexer> indexer;
    private final String searchEngine;

    public AdminNoSqlPageController(OcrMongoService ocrMongoService, SpendingLeaderboardService leaderboardService,
                                    ObjectProvider<TransactionSearchIndexer> indexer,
                                    @Value("${" + SearchConfig.ENGINE_PROPERTY + ":postgres}") String searchEngine) {
        this.ocrMongoService = ocrMongoService;
        this.leaderboardService = leaderboardService;
        this.indexer = indexer;
        this.searchEngine = searchEngine;
    }

    // ------------------------------------------------------------------------------------------- OCR feedbacks (MongoDB)

    @GetMapping("/ocr-feedbacks")
    public String ocrFeedbacks(
            @RequestParam(name = "field", required = false) String fieldParam,
            @RequestParam(name = "resolved", required = false) String resolvedParam,
            @RequestParam(name = "from", required = false) String fromParam,
            @RequestParam(name = "to", required = false) String toParam,
            @RequestParam(name = "page", defaultValue = "0") String pageParam,
            Model model) {
        // A bad value is ignored and said so in a banner, never a raw 400 page.
        boolean badFilter = false;
        OcrField field = null;
        if (isPresent(fieldParam)) {
            field = parseField(fieldParam.trim());
            badFilter |= field == null;
        }
        Boolean resolved = null;
        if (isPresent(resolvedParam)) {
            resolved = parseBoolean(resolvedParam.trim());
            badFilter |= resolved == null;
        }
        LocalDate from = null;
        if (isPresent(fromParam)) {
            from = parseDate(fromParam.trim());
            badFilter |= from == null;
        }
        LocalDate to = null;
        if (isPresent(toParam)) {
            to = parseDate(toParam.trim());
            badFilter |= to == null;
        }
        if (badFilter) {
            model.addAttribute("filterError", MSG_FILTER_INVALID);
        }
        int page = parsePage(pageParam);
        OcrFeedbackFilterRequestDto filter = OcrFeedbackFilterRequestDto.builder()
                .field(field).resolved(resolved).from(from).to(to).build();
        model.addAttribute("field", field == null ? "" : field.name());
        model.addAttribute("resolved", resolved == null ? "" : resolved.toString());
        model.addAttribute("from", from);
        model.addAttribute("to", to);
        model.addAttribute("fields", OcrField.values());
        model.addAttribute("fieldLabels", FIELD_LABELS);

        Page<OcrFeedbackResponseDto> feedbacks = Page.empty();
        OcrAnalyticsResponseDto analytics = OcrAnalyticsResponseDto.builder()
                .errorsByField(List.of()).errorsByModel(List.of()).confidenceByMonth(List.of()).build();
        try {
            feedbacks = ocrMongoService.findFeedbacks(filter,
                    PageRequest.of(Math.max(page, 0), FEEDBACK_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "reportedAt")));
            analytics = ocrMongoService.analytics(from, to);
        } catch (DataAccessException e) {
            log.warn("OCR feedback page: MongoDB read failed", e);
            model.addAttribute("mongoError", MSG_MONGO_READ_FAILED);
            feedbacks = new PageImpl<>(List.of());
        }
        model.addAttribute("feedbacks", feedbacks);
        model.addAttribute("errorRate", String.format(java.util.Locale.forLanguageTag("vi"), "%.1f%%",
                analytics.getReceiptsWithErrorRate() * PERCENT));
        model.addAttribute("fieldChartLabels", analytics.getErrorsByField().stream()
                .map(FieldCount::getField).map(AdminNoSqlPageController::labelOf).toList());
        model.addAttribute("fieldChartData", analytics.getErrorsByField().stream().map(FieldCount::getCount).toList());
        model.addAttribute("modelChartLabels", analytics.getErrorsByModel().stream().map(ModelCount::getModelVersion).toList());
        model.addAttribute("modelChartData", analytics.getErrorsByModel().stream().map(ModelCount::getCount).toList());
        model.addAttribute("monthChartLabels", analytics.getConfidenceByMonth().stream().map(MonthlyConfidence::getMonth).toList());
        // A month without any confidence stays null: Chart.js draws a gap, not a drop to zero.
        model.addAttribute("monthChartData", analytics.getConfidenceByMonth().stream()
                .map(MonthlyConfidence::getAverageConfidence).toList());
        return "admin/ocr_feedbacks";
    }

    @PostMapping("/ocr-feedbacks/{id}/resolve")
    public String resolveFeedback(@PathVariable String id, FeedbackReturn back, RedirectAttributes redirect) {
        runOnFeedback(() -> ocrMongoService.resolveFeedback(id), MSG_RESOLVE_OK, redirect);
        return back.redirect(redirect);
    }

    @PostMapping("/ocr-feedbacks/{id}/delete")
    public String deleteFeedback(@PathVariable String id, FeedbackReturn back, RedirectAttributes redirect) {
        runOnFeedback(() -> ocrMongoService.deleteFeedback(id), MSG_DELETE_OK, redirect);
        return back.redirect(redirect);
    }

    private void runOnFeedback(Runnable action, String successMessage, RedirectAttributes redirect) {
        try {
            action.run();
            redirect.addFlashAttribute(FLASH_MESSAGE, successMessage);
        } catch (OcrFeedbackNotFoundException e) {
            redirect.addFlashAttribute(FLASH_ERROR, e.getMessage());
        } catch (DataAccessException e) {
            log.warn("OCR feedback action failed", e);
            redirect.addFlashAttribute(FLASH_ERROR, MSG_MONGO_DOWN);
        }
    }

    /** The filter and page of the list the click came from, so the admin lands on the same page again. */
    public record FeedbackReturn(String field, String resolved, String from, String to, String page) {
        String redirect(RedirectAttributes redirect) {
            addIfPresent(redirect, "field", field);
            addIfPresent(redirect, "resolved", resolved);
            addIfPresent(redirect, "from", from);
            addIfPresent(redirect, "to", to);
            addIfPresent(redirect, "page", page);
            return REDIRECT + FEEDBACKS_URL;
        }

        private static void addIfPresent(RedirectAttributes redirect, String name, String value) {
            if (value != null && !value.isBlank()) {
                redirect.addAttribute(name, value);
            }
        }
    }

    private static boolean isPresent(String value) {
        return value != null && !value.isBlank();
    }

    private static OcrField parseField(String name) {
        try {
            return OcrField.valueOf(name);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static Boolean parseBoolean(String value) {
        return switch (value) {
            case "true" -> Boolean.TRUE;
            case "false" -> Boolean.FALSE;
            default -> null;
        };
    }

    private static LocalDate parseDate(String value) {
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    private static YearMonth parseMonth(String value) {
        try {
            return YearMonth.parse(value.trim());
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    private static int parsePage(String value) {
        try {
            return Math.max(Integer.parseInt(value.trim()), 0);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static String labelOf(String key) {
        return FIELD_LABELS.getOrDefault(key, key);
    }

    // ------------------------------------------------------------------------------- operations (Elasticsearch, Redis)

    @GetMapping("/nosql")
    public String nosql(@RequestParam(name = "month", required = false) String monthParam, Model model) {
        YearMonth month = isPresent(monthParam) ? parseMonth(monthParam) : null;
        if (isPresent(monthParam) && month == null) {
            model.addAttribute("monthError", MSG_MONTH_INVALID);
        }
        YearMonth shown = month != null ? month : YearMonth.now();
        TransactionSearchIndexer available = indexer.getIfAvailable();
        model.addAttribute("searchEngine", SearchEngineType.from(searchEngine).name().toLowerCase(java.util.Locale.ROOT));
        model.addAttribute("searchEnabled", available != null);
        model.addAttribute("reindexRunning", available != null && available.isReindexing());
        if (available != null) {
            try {
                model.addAttribute("indexedDocuments", available.countDocuments());
            } catch (RuntimeException e) {
                log.warn("Admin NoSQL page: Elasticsearch count failed", e);
                model.addAttribute("searchError", MSG_SEARCH_READ_FAILED);
            }
        }
        model.addAttribute("month", shown.toString());
        List<TopSpenderDto> top = List.of();
        try {
            top = leaderboardService.topSpenders(shown, LEADERBOARD_SIZE);
        } catch (RuntimeException e) {
            log.warn("Admin NoSQL page: leaderboard read failed, month={}", shown, e);
            model.addAttribute("redisError", MSG_LEADERBOARD_READ_FAILED);
        }
        model.addAttribute("topSpenders", top);
        return "admin/nosql_ops";
    }

    @PostMapping("/nosql/search/reindex")
    public String reindex(RedirectAttributes redirect) {
        TransactionSearchIndexer available = indexer.getIfAvailable();
        if (available == null) {
            redirect.addFlashAttribute(FLASH_ERROR, MSG_SEARCH_DISABLED);
        } else {
            try {
                redirect.addFlashAttribute(FLASH_MESSAGE, String.format(MSG_REINDEX_OK, available.reindexAll()));
            } catch (ReindexInProgressException e) {
                redirect.addFlashAttribute(FLASH_ERROR, e.getMessage());
            } catch (RuntimeException e) {
                log.warn("Admin reindex failed", e);
                redirect.addFlashAttribute(FLASH_ERROR, MSG_REINDEX_FAILED);
            }
        }
        return REDIRECT + NOSQL_URL;
    }

    @PostMapping("/nosql/leaderboard/rebuild")
    public String rebuildLeaderboard(@RequestParam(name = "month", required = false) String monthParam,
                                     RedirectAttributes redirect) {
        YearMonth month = isPresent(monthParam) ? parseMonth(monthParam) : null;
        if (isPresent(monthParam) && month == null) {
            redirect.addFlashAttribute(FLASH_ERROR, MSG_MONTH_INVALID);
            return REDIRECT + NOSQL_URL;
        }
        YearMonth target = month != null ? month : YearMonth.now();
        redirect.addAttribute("month", target.toString());
        try {
            redirect.addFlashAttribute(FLASH_MESSAGE,
                    String.format(MSG_REBUILD_OK, target, leaderboardService.rebuildMonth(target)));
        } catch (RuntimeException e) {
            log.warn("Admin leaderboard rebuild failed, month={}", target, e);
            redirect.addFlashAttribute(FLASH_ERROR, MSG_REBUILD_FAILED);
        }
        return REDIRECT + NOSQL_URL;
    }
}
