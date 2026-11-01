package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Dto.AdminDashboardSummaryDto;
import vn.edu.huit.finance.core.Entity.CustomerSegment;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Dto.LowBalanceUserDto;
import vn.edu.huit.finance.core.Dto.MonthlyTransactionCountDto;
import vn.edu.huit.finance.core.Dto.ReceiptStatusCountDto;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Repository.AppReviewRepository;
import vn.edu.huit.finance.core.Repository.CampaignRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.SubscriptionPlanRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.AdminStatisticsService;
import vn.edu.huit.finance.core.Service.AppReviewService;
import vn.edu.huit.finance.core.Service.AuditLogQueryService;
import vn.edu.huit.finance.core.Service.BackupService;
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.CategoryService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.ReceiptProcessingService;
import vn.edu.huit.finance.core.Service.SubscriptionPlanService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserService;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The admin dashboard page, rendered by Thymeleaf from the cached DTOs of AdminStatisticsService instead of rows and
 * entities. Security is left out (addFilters = false): the /admin/** rule of SecurityConfig is not what is under test.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminDashboardPageTest {

    @Autowired private MockMvc mockMvc;

    @MockBean private AdminStatisticsService adminStatisticsService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private ReceiptProcessingService receiptProcessingService;
    @MockBean private UserRepository userRepo;
    @MockBean private CategoryRepository categoryRepo;
    @MockBean private CampaignRepository campaignRepo;
    @MockBean private ReceiptRepository receiptRepo;
    @MockBean private BackupService backupService;
    @MockBean private CustomerSegmentationService customerSegmentationService;
    @MockBean private UserService userService;
    @MockBean private TransactionService transactionService;
    @MockBean private EntityManager entityManager;
    @MockBean private SubscriptionPlanRepository subscriptionPlanRepository;
    @MockBean private SubscriptionPlanService subscriptionPlanService;
    @MockBean private CategoryService categoryService;
    @MockBean private AppReviewService appReviewService;
    @MockBean private AuditLogQueryService auditLogQueryService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private AppReviewRepository appReviewRepository;

    @Test
    void theDashboardShowsTheCachedFiguresOfTheCurrentMonth() throws Exception {
        YearMonth now = YearMonth.now();
        when(adminStatisticsService.getDashboardSummary(now, TransactionService.LOW_BALANCE_THRESHOLD))
                .thenReturn(new AdminDashboardSummaryDto(new BigDecimal("1250000.50"), 42, 17,
                        List.of(new LowBalanceUserDto(7L, "an_low", "0900000007", new BigDecimal("12000.00"))),
                        List.of(new ReceiptStatusCountDto("SUCCESS", 5), new ReceiptStatusCountDto("FAILED", 2),
                                new ReceiptStatusCountDto("WAITING_FOR_REVIEW", 1))));
        when(leaderboardService.topSpenders(now, 5))
                .thenReturn(List.of(new TopSpenderDto(9L, "binh_top", new BigDecimal("900000.00"))));
        when(adminStatisticsService.getMonthlyTransactionCounts(now, 6))
                .thenReturn(List.of(new MonthlyTransactionCountDto(now.minusMonths(1), 3),
                        new MonthlyTransactionCountDto(now, 17)));
        when(userRepo.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
        when(customerSegmentationService.countBySegment()).thenReturn(sevenCounts());

        // The charts are inlined into JavaScript, where Thymeleaf writes every non-ASCII character as a \\u escape.
        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("1.250.000 VNĐ"),
                        containsString("binh_top"),
                        containsString("Top chi tiêu tháng"),
                        containsString("value=\"" + now + "\""),
                        containsString("900.000 VNĐ"),
                        containsString("an_low"),
                        containsString("0900000007"),
                        containsString("12.000 VNĐ"),
                        containsString("const labelsReal = [\"Th\\u00E1ng " + now.minusMonths(1).getMonthValue()
                                + "\",\"Th\\u00E1ng " + now.getMonthValue() + "\"];"),
                        containsString("const dataReal = [3,17];"),
                        containsString("const aiLabelsReal = [\"Th\\u00E0nh c\\u00F4ng\",\"L\\u1ED7i AI\",\"\\u0110ang x\\u1EED l\\u00FD\"];"),
                        containsString("const aiDataReal = [5,2,1];"))));

        verify(adminStatisticsService).getDashboardSummary(now, TransactionService.LOW_BALANCE_THRESHOLD);
        verify(leaderboardService).topSpenders(now, 5);
        verify(adminStatisticsService).getMonthlyTransactionCounts(now, 6);
    }

    @Test
    void receiptStatusesThatShareALabelAreMergedIntoOneSliceAndTheBarChartCountsTransactions() throws Exception {
        YearMonth now = YearMonth.now();
        when(adminStatisticsService.getDashboardSummary(now, TransactionService.LOW_BALANCE_THRESHOLD))
                .thenReturn(new AdminDashboardSummaryDto(BigDecimal.ZERO, 0, 0, List.of(),
                        List.of(new ReceiptStatusCountDto("WAITING_FOR_REVIEW", 4),
                                new ReceiptStatusCountDto("SUCCESS", 5),
                                new ReceiptStatusCountDto("PROCESSING", 2),
                                new ReceiptStatusCountDto("FAILED", 1),
                                new ReceiptStatusCountDto("PENDING", 3))));
        when(leaderboardService.topSpenders(now, 5)).thenReturn(List.of());
        when(adminStatisticsService.getMonthlyTransactionCounts(now, 6)).thenReturn(List.of());
        when(userRepo.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
        when(customerSegmentationService.countBySegment()).thenReturn(sevenCounts());

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(model().attribute("aiLabels", List.of("Đang xử lý", "Thành công", "Lỗi AI")))
                .andExpect(model().attribute("aiData", List.of(9L, 5L, 1L)))
                .andExpect(content().string(allOf(
                        containsString("Số giao dịch 6 tháng qua"),
                        containsString("label: \"Số giao dịch\""),
                        not(containsString("Số lượng Hóa đơn")))));
    }

    private void stubEmptyDashboard() {
        YearMonth now = YearMonth.now();
        when(adminStatisticsService.getDashboardSummary(now, TransactionService.LOW_BALANCE_THRESHOLD))
                .thenReturn(new AdminDashboardSummaryDto(BigDecimal.ZERO, 0, 0, List.of(), List.of()));
        when(leaderboardService.topSpenders(now, 5)).thenReturn(List.of());
        when(adminStatisticsService.getMonthlyTransactionCounts(now, 6)).thenReturn(List.of());
        when(userRepo.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
        when(customerSegmentationService.countBySegment()).thenReturn(sevenCounts());
    }

    private static Map<CustomerSegment, Long> sevenCounts() {
        Map<CustomerSegment, Long> counts = new EnumMap<>(CustomerSegment.class);
        long[] values = {3, 0, 1, 0, 2, 0, 5};
        for (CustomerSegment segment : CustomerSegment.values()) {
            counts.put(segment, values[segment.ordinal()]);
        }
        return counts;
    }

    @Test
    void theDashboardSaysRfm_andNeverTheOldClusteringName() throws Exception {
        stubEmptyDashboard();

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(containsString("RFM"), not(containsString("K-" + "Means")),
                        not(containsString("K-" + "means")), not(containsString("Python")))));
    }

    @Test
    void theSegmentChartGetsEverySegmentInOrder() throws Exception {
        stubEmptyDashboard();

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(model().attribute("segmentData", List.of(3L, 0L, 1L, 0L, 2L, 0L, 5L)))
                .andExpect(model().attribute("segmentNames", List.of("Khách hàng tốt nhất", "Trung thành", "Khách mới",
                        "Cần chú ý", "Có nguy cơ rời bỏ", "Ngủ đông", "Đã rời bỏ")))
                .andExpect(model().attribute("segmentDisplayNames", Map.of("CHAMPIONS", "Khách hàng tốt nhất",
                        "LOYAL", "Trung thành", "NEW", "Khách mới", "NEED_ATTENTION", "Cần chú ý",
                        "AT_RISK", "Có nguy cơ rời bỏ", "HIBERNATING", "Ngủ đông", "LOST", "Đã rời bỏ")))
                .andExpect(model().attributeDoesNotExist("vipCount", "activeCount", "atRiskCount", "churnCount"))
                .andExpect(content().string(containsString("const segmentData = [3,0,1,0,2,0,5];")));
    }

    @Test
    void aUserRowShowsTheSegmentName_theRawOldLabel_orNotSegmented() throws Exception {
        stubEmptyDashboard();
        User champion = new User();
        champion.setId(1L);
        champion.setUsername("u_champion");
        champion.setAiLabel("CHAMPIONS");
        User old = new User();
        old.setId(2L);
        old.setUsername("u_old");
        old.setAiLabel("VIP");
        User none = new User();
        none.setId(3L);
        none.setUsername("u_none");
        when(userRepo.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of(champion, old, none)));

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(content().string(allOf(
                        containsString("Khách hàng tốt nhất</span>"),
                        containsString(">VIP</span>"),
                        containsString("Chưa phân lớp</span>"))));
    }

    @Test
    void rejectingAReceiptGoesThroughTheServiceSoTheCachesAreEvictedAfterItsCommit() throws Exception {
        mockMvc.perform(post("/admin/receipts/reject/{id}", 7L))
                .andExpect(redirectedUrl("/admin/receipts"));

        verify(receiptProcessingService).rejectReceipt(7L);
    }

    @Test
    void theBackupPageHasAMongoDbCardNextToThePostgresOneWithItsConfirmDialogs() throws Exception {
        mockMvc.perform(get("/admin/backup"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("MongoDB (ocr_logs, ocr_feedbacks)"),
                        containsString("ConfirmMongoBackup()"),
                        containsString("ConfirmMongoRestore()"),
                        containsString("/admin/backup/mongo/execute"),
                        containsString("/admin/backup/mongo/restore"),
                        containsString("/admin/backup/execute?type="),
                        containsString("/admin/backup/restore?type=FULL"))));
    }
}
