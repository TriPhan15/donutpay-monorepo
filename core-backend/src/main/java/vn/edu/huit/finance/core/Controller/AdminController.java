package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.envers.AuditReader;
import org.hibernate.envers.AuditReaderFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.validation.ObjectError;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import vn.edu.huit.finance.core.Dto.AdminDashboardSummaryDto;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.AuditLogFilterRequestDto;
import vn.edu.huit.finance.core.Dto.MonthlyTransactionCountDto;
import vn.edu.huit.finance.core.Dto.ReceiptStatusCountDto;
import vn.edu.huit.finance.core.Dto.CategoryRenameRequestDto;
import vn.edu.huit.finance.core.Dto.CategoryRequestDto;
import vn.edu.huit.finance.core.Dto.SubscriptionPlanRequestDto;
import vn.edu.huit.finance.core.Dto.UserCreateDto;
import vn.edu.huit.finance.core.Dto.UserUpdateDto;
import vn.edu.huit.finance.core.Entity.*;
import vn.edu.huit.finance.core.Repository.*;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.AdminStatisticsService;
import vn.edu.huit.finance.core.Service.AppReviewService;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.AuditLogQueryService;
import vn.edu.huit.finance.core.Service.BackupService;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.CategoryService;
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.ReceiptProcessingService;
import vn.edu.huit.finance.core.Service.SubscriptionPlanService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserDeletionOutcome;
import vn.edu.huit.finance.core.Service.UserService;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.YearMonth;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * The admin pages. Every change made through them is recorded in action_logs: the services below write the row in the
 * transaction of the change (users, categories, plans, reviews, receipts), and the operations outside the database
 * (lifting a lockout, the segmentation batch, backups) publish a SecurityAuditEvent once they have run.
 */
@Slf4j
@Controller
@RequestMapping("/admin")
public class AdminController {
    private static final int DEFAULT_PAGE_SIZE = 10;
    static final int MAX_PAGE_SIZE = 100;
    private static final int TOP_SPENDERS_LIMIT = 5;
    private static final int CHART_MONTHS = 6;
    private static final String CHART_LABEL_PREFIX = "Tháng ";
    private static final String MSG_USER_DELETED = "Đã xóa vĩnh viễn tài khoản";
    private static final String MSG_USER_LOCKED_INSTEAD =
            "Tài khoản đã có dữ liệu (giao dịch, ngân sách...) nên đã được khóa thay vì xóa vĩnh viễn";
    private static final String AUDIT_UNLOCK = "Gỡ khóa đăng nhập sớm cho email: %s / IP: %s";
    private static final String AUDIT_SEGMENTATION = "Chạy phân lớp khách hàng RFM (ngũ phân vị): %d người dùng được gán nhãn";
    private static final String MSG_FILTER_FIELD_INVALID = "Giá trị của %s không hợp lệ";
    private static final String TYPE_MISMATCH = "typeMismatch";
    private static final String MSG_BACKUP_TYPE_INVALID = "Loại sao lưu không hợp lệ (chỉ hỗ trợ FULL, SCHEMA_ONLY, DATA_ONLY).";
    private static final String MSG_BACKUP_SUCCESS = "Đã sao lưu %s thành công!";
    private static final String MSG_BACKUP_FAILED = "Lỗi sao lưu! Kiểm tra lại đường dẫn PostgreSQL.";
    private static final String MSG_RESTORE_SUCCESS = "Đã phục hồi từ bản sao lưu FULL mới nhất!";
    private static final String MSG_RESTORE_FAILED = "Lỗi phục hồi! Không tìm thấy bản sao lưu FULL hoặc pg_restore lỗi.";

    @Autowired private UserRepository userRepo;
    @Autowired private CustomerSegmentationService customerSegmentationService;
    @Autowired private AdminStatisticsService adminStatisticsService;
    @Autowired private ReceiptProcessingService receiptProcessingService;
    @Autowired private CategoryRepository categoryRepo;
    @Autowired private CampaignRepository campaignRepo;
    @Autowired private ReceiptRepository receiptRepo;
    @Autowired private BackupService backupService;
    @Autowired private UserService userService;
    @Autowired private TransactionService transactionService;
    @Autowired private EntityManager entityManager;
    @Autowired private SubscriptionPlanRepository subscriptionPlanRepository;
    @Autowired private SubscriptionPlanService subscriptionPlanService;
    @Autowired private CategoryService categoryService;
    @Autowired private AppReviewService appReviewService;
    @Autowired private AuditLogQueryService auditLogQueryService;
    @Autowired private LoginAttemptService loginAttemptService;
    @Autowired private AppReviewRepository appReviewRepository;
    @Autowired private ApplicationEventPublisher eventPublisher;
    @Autowired private SpendingLeaderboardService leaderboardService;
    /**
     * The aggregates come from AdminStatisticsService, cached in Redis as DTOs (never this Model, never an entity) and
     * keyed by the month, threshold, page and limit asked for here; the customer segments below are read live.
     */
    @GetMapping("/dashboard")
    public String showDashboard(Model model,
                                @RequestParam(name = "month", required = false) @DateTimeFormat(pattern = "yyyy-MM") YearMonth requestedMonth) {
        YearMonth currentMonth = YearMonth.now();
        YearMonth topSpendersMonth = requestedMonth != null ? requestedMonth : currentMonth;
        AdminDashboardSummaryDto summary = adminStatisticsService.getDashboardSummary(
                currentMonth, TransactionService.LOW_BALANCE_THRESHOLD);

        model.addAttribute("totalVolume", formatCurrencyWithoutDecimal(summary.getTotalVolume()));
        model.addAttribute("totalUsers", summary.getTotalUsers());
        model.addAttribute("lowBalanceUsers", summary.getLowBalanceUsers());
        model.addAttribute("totalTransactionsThisMonth", summary.getTransactionsInPeriod());

        model.addAttribute("topSpenders", leaderboardService.topSpenders(topSpendersMonth, TOP_SPENDERS_LIMIT));
        model.addAttribute("topSpendersMonth", topSpendersMonth.toString());

        List<MonthlyTransactionCountDto> chart = adminStatisticsService.getMonthlyTransactionCounts(currentMonth, CHART_MONTHS);
        model.addAttribute("chartLabels", chart.stream()
                .map(month -> CHART_LABEL_PREFIX + month.getMonth().getMonthValue())
                .toList());
        model.addAttribute("chartData", chart.stream().map(MonthlyTransactionCountDto::getTransactionCount).toList());

        List<String> aiLabels = new java.util.ArrayList<>();
        List<Long> aiData = new java.util.ArrayList<>();

        for (ReceiptStatusCountDto receiptStatus : summary.getReceiptStatuses()) {
            String status = receiptStatus.getStatus();

            if ("SUCCESS".equals(status)) status = "Thành công";
            else if ("FAILED".equals(status)) status = "Lỗi AI";
            else status = "Đang xử lý";

            aiLabels.add(status);
            aiData.add(receiptStatus.getCount());
        }

        model.addAttribute("aiLabels", aiLabels);
        model.addAttribute("aiData", aiData);
        Map<CustomerSegment, Long> segmentCounts = customerSegmentationService.countBySegment();
        model.addAttribute("segmentNames", segmentCounts.keySet().stream().map(CustomerSegment::getDisplayName).toList());
        model.addAttribute("segmentData", List.copyOf(segmentCounts.values()));
        model.addAttribute("segmentDisplayNames", Arrays.stream(CustomerSegment.values())
                .collect(Collectors.toMap(CustomerSegment::name, CustomerSegment::getDisplayName)));
        Page<User> segmentedUsers = userRepo.findAll(PageRequest.of(0, 10, Sort.by(Sort.Direction.DESC, "id")));
        model.addAttribute("segmentedUsers", segmentedUsers.getContent());
        return "admin/dashboard";
    }


    @GetMapping("/login")
    public String showLoginPage() {
        return "admin/login";
    }


    @GetMapping("/categories")
    public String showCategories(Model model) {
        List<Category> categories = categoryRepo.findAll();
        model.addAttribute("categories", categories);
        return "admin/categories";
    }

    @GetMapping("/receipts")
    public String showReceipts(
            @RequestParam(defaultValue = "0") int receiptPage,
            @RequestParam(defaultValue = "10") int size,
            Model model) {
        // Trang hóa đơn chỉ còn danh sách hóa đơn (Duyệt / Từ chối); quản lý tài khoản nằm ở /admin/users.
        Page<Receipt> receiptsPage = receiptRepo.findAllByOrderByCreatedAtDesc(
                PageRequest.of(Math.max(receiptPage, 0), normalizePageSize(size)));
        model.addAttribute("receipts", receiptsPage.getContent());
        model.addAttribute("receiptsPage", receiptsPage);
        model.addAttribute("pageSize", normalizePageSize(size));
        return "admin/receipts";
    }

    @GetMapping("/users")
    public String showUsers(
            @RequestParam(defaultValue = "0") int userPage,
            @RequestParam(defaultValue = "10") int size,
            Model model) {
        Page<User> usersPage = userRepo.findAll(PageRequest.of(Math.max(userPage, 0), normalizePageSize(size), Sort.by(Sort.Direction.DESC, "id")));
        model.addAttribute("users", usersPage.getContent());
        model.addAttribute("usersPage", usersPage);
        model.addAttribute("pageSize", normalizePageSize(size));
        return "admin/users";
    }

    // Closed to everybody without ROLE_ADMIN twice, by the /admin/** rule of SecurityConfig and by @PreAuthorize: the two
    // services behind these handlers take no user and trust their caller to be an administrator.
    @PostMapping("/receipts/approve/{id}")
    @PreAuthorize(Roles.HAS_ADMIN)
    public String approveReceipt(@PathVariable Long id) {
        transactionService.approveReceipt(id);
        return "redirect:/admin/receipts";
    }

    @PostMapping("/receipts/reject/{id}")
    @PreAuthorize(Roles.HAS_ADMIN)
    public String rejectReceipt(@PathVariable Long id) {
        receiptProcessingService.rejectReceipt(id);
        return "redirect:/admin/receipts";
    }




    @GetMapping("/subscriptions")
    public String viewSubscriptions(Model model) {
        List<SubscriptionPlan> plans = subscriptionPlanRepository.findAll();
        model.addAttribute("plans", plans);
        return "admin/subscriptions";
    }
    @PostMapping("/subscriptions/add")
    public String addSubscription(
            @Valid @ModelAttribute SubscriptionPlanRequestDto values,
            @RequestParam(defaultValue = "false") boolean isWcmSpadeEnabled) {
        // The form field is named isWcmSpadeEnabled, which does not bind to the DTO's wcmSpadeEnabled by itself.
        values.setWcmSpadeEnabled(values.isWcmSpadeEnabled() || isWcmSpadeEnabled);
        subscriptionPlanService.createPlan(values);

        return "redirect:/admin/subscriptions";
    }

    @PostMapping("/ajax/users")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> createUserAjax(@Valid @RequestBody UserCreateDto dto) {
        // Recorded by UserService (USER_CREATED, by the caller) in the transaction of the creation. A refusal (bad role,
        // duplicate email...) is answered by GlobalExceptionHandler, never with the raw exception message.
        User user = userService.createUser(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.<Map<String, Object>>builder()
                .code(201)
                .message("Tạo tài khoản thành công")
                .data(toUserResponse(user))
                .build());
    }

    @PutMapping("/ajax/users/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateUserAjax(
            @PathVariable Long id,
            @Valid @RequestBody UserUpdateDto dto) {
        // Recorded by UserService (USER_UPDATED, and USER_ROLE_CHANGED for a new role) in the transaction of the update.
        User user = userService.updateUser(id, dto);
        return ResponseEntity.ok(ApiResponse.<Map<String, Object>>builder()
                .code(200)
                .message("Cập nhật thông tin thành công")
                .data(toUserResponse(user))
                .build());
    }

    @DeleteMapping("/ajax/users/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteUserAjax(@PathVariable Long id) {
        // Recorded by UserService (USER_DELETED, or USER_STATUS_CHANGED when it only locks) in its transaction.
        // An ADMIN account or an unknown id is answered by GlobalExceptionHandler (403 / 404).
        UserDeletionOutcome outcome = userService.deleteUser(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200)
                .message(outcome == UserDeletionOutcome.DELETED ? MSG_USER_DELETED : MSG_USER_LOCKED_INSTEAD)
                .build());
    }

    @PutMapping("/ajax/users/{id}/toggle-status")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> toggleUserStatusAjax(@PathVariable Long id) {
        // Recorded by UserService (USER_STATUS_CHANGED) in the transaction of the change. An ADMIN account or an unknown
        // id is answered by GlobalExceptionHandler (403 / 404).
        userService.toggleUserStatus(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200)
                .message("Cập nhật trạng thái thành công")
                .build());
    }

    @GetMapping("/backup")
    public String showBackupPage() {
        return "admin/backup";
    }


    @PostMapping("/backup/execute")
    @ResponseBody
    public Map<String, Object> executeBackup(@RequestParam("type") String type) {
        Map<String, Object> response = new HashMap<>();
        Optional<BackupType> backupType = BackupType.fromParam(type);
        if (backupType.isEmpty()) {
            response.put("success", false);
            response.put("message", MSG_BACKUP_TYPE_INVALID);
            return response;
        }

        boolean isSuccess = backupService.backupDatabase(backupType.get());

        response.put("success", isSuccess);
        response.put("message", isSuccess
                ? String.format(MSG_BACKUP_SUCCESS, backupType.get().getLabel())
                : MSG_BACKUP_FAILED);
        return response;
    }

    // Chỉ phục hồi từ bản FULL mới nhất (bản schema-only / data-only không đủ để dựng lại cơ sở dữ liệu).
    @PostMapping("/backup/restore")
    @ResponseBody
    public Map<String, Object> executeRestore() {
        Map<String, Object> response = new HashMap<>();

        boolean isSuccess = backupService.restoreLatestFull();

        response.put("success", isSuccess);
        response.put("message", isSuccess ? MSG_RESTORE_SUCCESS : MSG_RESTORE_FAILED);
        return response;
    }

    @PostMapping("/ajax/subscriptions")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> createSubscriptionAjax(@Valid @RequestBody SubscriptionPlanRequestDto plan) {
        subscriptionPlanService.createPlan(plan);
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(201).message("Thành công").build());
    }

    @PutMapping("/ajax/subscriptions/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> updateSubscriptionAjax(@PathVariable Long id,
                                                                @Valid @RequestBody SubscriptionPlanRequestDto dto) {
        subscriptionPlanService.updatePlan(id, dto);
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(200).message("Thành công").build());
    }

    @PutMapping("/ajax/subscriptions/{id}/toggle")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> toggleSubscriptionAjax(@PathVariable Long id) {
        subscriptionPlanService.togglePlan(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(200).build());
    }

    @DeleteMapping("/ajax/subscriptions/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteSubscriptionAjax(@PathVariable Long id) {
        subscriptionPlanService.deletePlan(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(200).build());
    }

    /**
     * The activity log: the newest {@value AuditLogQueryService#LATEST_LIMIT} rows of the data tab and of the security
     * tab, as before, the summary of the last days, and a filtered, paged search (also served as JSON by
     * GET /api/admin/audit-logs). Nothing here loads the whole table.
     */
    @GetMapping("/auditlog")
    @PreAuthorize(Roles.HAS_ADMIN)
    public String showAuditLog(@Valid @ModelAttribute("filter") AuditLogFilterRequestDto filter, BindingResult filterErrors,
                               Model model) {
        model.addAttribute("systemLogs", auditLogQueryService.latestOtherEvents());
        model.addAttribute("loginAttempts", auditLogQueryService.latestSecurityEvents());
        model.addAttribute("auditSummary", auditLogQueryService.summary());
        model.addAttribute("summaryWindowDays", AuditLogQueryService.SUMMARY_WINDOW_DAYS);
        model.addAttribute("auditActions", AuditAction.values());
        model.addAttribute("auditTargetTypes", AuditTargetType.values());
        model.addAttribute("searchRequested", filterErrors.hasErrors() || filter.hasCriteria());
        if (filterErrors.hasErrors()) {
            model.addAttribute("filterError", filterErrors.getAllErrors().stream()
                    .map(AdminController::filterErrorMessage)
                    .collect(Collectors.joining(", ")));
        } else {
            model.addAttribute("searchPage", auditLogQueryService.search(filter));
        }
        return "admin/auditlog";
    }

    /** The validation message of a filter, or a short one of ours for a value that did not even convert (no class names). */
    private static String filterErrorMessage(ObjectError error) {
        if (error instanceof FieldError fieldError && TYPE_MISMATCH.equals(fieldError.getCode())) {
            return String.format(MSG_FILTER_FIELD_INVALID, fieldError.getField());
        }
        return error.getDefaultMessage();
    }

    /** Cỡ trang của các trang admin: mặc định khi không hợp lệ, tối đa MAX_PAGE_SIZE để ?size=1000000 không tải cả bảng. */
    static int normalizePageSize(int size) {
        return size > 0 ? Math.min(size, MAX_PAGE_SIZE) : DEFAULT_PAGE_SIZE;
    }

    private String formatCurrencyWithoutDecimal(BigDecimal amount) {
        BigDecimal safeAmount = amount != null ? amount : BigDecimal.ZERO;
        return safeAmount.setScale(0, RoundingMode.DOWN).toPlainString();
    }

    private Map<String, Object> toUserResponse(User user) {
        Map<String, Object> response = new HashMap<>();
        response.put("id", user.getId());
        response.put("username", user.getUsername());
        response.put("email", user.getEmail());
        response.put("role", user.getRole());
        response.put("isActive", user.isActive());
        return response;
    }

    @PostMapping("/ajax/categories")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> addCategoryAjax(@Valid @ModelAttribute CategoryRequestDto dto) {
        categoryService.createCategory(dto.getName(), dto.getType());
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(201).message("Thêm thành công").build());
    }

    @PutMapping("/ajax/categories/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> updateCategoryAjax(@PathVariable Long id,
                                                             @Valid @ModelAttribute CategoryRenameRequestDto dto) {
        categoryService.renameCategory(id, dto.getName());
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(200).message("Cập nhật thành công").build());
    }

    @DeleteMapping("/ajax/categories/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteCategoryAjax(@PathVariable Long id) {
        categoryService.deleteCategory(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder().code(200).message("Xóa thành công").build());
    }
    @PostMapping("/ajax/security/unlock")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> unlockUserOrIp(
            @RequestParam(required = false) String email,
            @RequestParam(required = false) String ipAddress) {
        loginAttemptService.resetAttempts(email, ipAddress);
        // The lockout lives in memory, outside any transaction: recorded once lifted, in a row of its own.
        eventPublisher.publishEvent(SecurityAuditEvent.ofCurrentCaller(AuditAction.AUTH_LOGIN_UNLOCKED,
                String.format(AUDIT_UNLOCK, email, ipAddress)));
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200)
                .message("Đã gỡ khóa giải ban thành công!")
                .build());

    }

    @GetMapping("/reviews")
    public String showReviews(Model model) {
        List<AppReview> reviews = appReviewRepository.findAllByOrderByCreatedAtDesc();
        model.addAttribute("reviews", reviews);
        return "admin/reviews";
    }

    @PostMapping("/ajax/reviews/{id}/approve")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> approveReviewAjax(@PathVariable Long id) {
        // An unknown id is a 404 from GlobalExceptionHandler.
        appReviewService.approveReview(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200)
                .message("Đã duyệt đánh giá thành công!")
                .build());
    }

    @DeleteMapping("/ajax/reviews/{id}")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteReviewAjax(@PathVariable Long id) {
        appReviewService.deleteReview(id);
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200)
                .message("Đã xóa đánh giá thành công!")
                .build());
    }
    @PostMapping("/ajax/segmentation/run")
    @ResponseBody
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> runAiSegmentation() {
        int assigned = customerSegmentationService.runSegmentation();

        // Mọi nhãn đã ghi trong một giao dịch: chỉ ghi nhật ký sau khi nó đã commit, ở một dòng riêng.
        eventPublisher.publishEvent(SecurityAuditEvent.ofCurrentCaller(AuditAction.SYSTEM_SEGMENTATION_RUN,
                String.format(AUDIT_SEGMENTATION, assigned)));

        return ResponseEntity.ok(ApiResponse.<Void>builder().code(200).message("Phân lớp hoàn tất").build());
    }
}
