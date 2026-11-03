package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Dto.AdminDashboardSummaryDto;
import vn.edu.huit.finance.core.Dto.LowBalanceUserDto;
import vn.edu.huit.finance.core.Dto.ReceiptStatusCountDto;
import vn.edu.huit.finance.core.Entity.AppReview;
import vn.edu.huit.finance.core.Entity.CustomerSegment;
import vn.edu.huit.finance.core.Entity.User;
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
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.CategoryService;
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.ReceiptProcessingService;
import vn.edu.huit.finance.core.Service.SubscriptionPlanService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserService;

import java.math.BigDecimal;
import java.time.YearMonth;
import java.util.EnumMap;
import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

/**
 * Characterization of AdminController before and after the refactor that moves its reads, its status labels and its user
 * JSON out of it: what the dashboard puts in the model, the JSON of the ajax user endpoints and the reviews page stay as
 * they are. Security is left out (addFilters = false), as in the other admin page tests.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminControllerCharacterizationTest {

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

    private void stubDashboard(AdminDashboardSummaryDto summary) {
        YearMonth now = YearMonth.now();
        when(adminStatisticsService.getDashboardSummary(now, TransactionService.LOW_BALANCE_THRESHOLD)).thenReturn(summary);
        when(leaderboardService.topSpenders(now, 5)).thenReturn(List.of());
        when(adminStatisticsService.getMonthlyTransactionCounts(now, 6)).thenReturn(List.of());
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
        when(customerSegmentationService.countBySegment()).thenReturn(new EnumMap<>(CustomerSegment.class));
    }

    @Test
    void theDashboardModelHoldsTheFiguresAndTheReceiptSlicesOfThreeStatuses() throws Exception {
        stubDashboard(new AdminDashboardSummaryDto(new BigDecimal("1250000.99"), 42, 17,
                List.of(new LowBalanceUserDto(7L, "an_low", "0900000007", new BigDecimal("12000.00"))),
                List.of(new ReceiptStatusCountDto("SUCCESS", 5), new ReceiptStatusCountDto("FAILED", 2),
                        new ReceiptStatusCountDto("PENDING", 1))));

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(status().isOk())
                .andExpect(view().name("admin/dashboard"))
                // Cut to whole dong, never rounded up.
                .andExpect(model().attribute("totalVolume", "1250000"))
                .andExpect(model().attribute("totalUsers", 42L))
                .andExpect(model().attribute("totalTransactionsThisMonth", 17L))
                .andExpect(model().attribute("aiLabels", List.of("Thành công", "Lỗi AI", "Đang xử lý")))
                .andExpect(model().attribute("aiData", List.of(5L, 2L, 1L)));
    }

    @Test
    void anyOtherStatusIsShownAsProcessing_andNoReceiptsGiveNoSlices() throws Exception {
        stubDashboard(new AdminDashboardSummaryDto(null, 0, 0, List.of(),
                List.of(new ReceiptStatusCountDto("WAITING_FOR_REVIEW", 4))));

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(model().attribute("totalVolume", "0"))
                .andExpect(model().attribute("aiLabels", List.of("Đang xử lý")))
                .andExpect(model().attribute("aiData", List.of(4L)));

        stubDashboard(new AdminDashboardSummaryDto(BigDecimal.ZERO, 0, 0, List.of(), List.of()));

        mockMvc.perform(get("/admin/dashboard"))
                .andExpect(model().attribute("totalVolume", "0"))
                .andExpect(model().attribute("aiLabels", List.of()))
                .andExpect(model().attribute("aiData", List.of()));
    }

    private static User user(long id, String role, boolean active) {
        User user = new User();
        user.setId(id);
        user.setUsername("binh_user");
        user.setEmail("binh@example.com");
        user.setRole(role);
        user.setActive(active);
        return user;
    }

    @Test
    void creatingAUserAnswers201WithTheFiveKeysOfTheAccount() throws Exception {
        when(userService.createUser(any())).thenReturn(user(5L, "ROLE_USER", true));

        mockMvc.perform(post("/admin/ajax/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"binh_user","email":"binh@example.com","phone":"0900000005",
                                 "password":"Passw0rdOk1","role":"ROLE_USER"}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.code").value(201))
                .andExpect(jsonPath("$.message").value("Tạo tài khoản thành công"))
                .andExpect(jsonPath("$.data.id").value(5))
                .andExpect(jsonPath("$.data.username").value("binh_user"))
                .andExpect(jsonPath("$.data.email").value("binh@example.com"))
                .andExpect(jsonPath("$.data.role").value("ROLE_USER"))
                .andExpect(jsonPath("$.data.isActive").value(true))
                .andExpect(jsonPath("$.data.active").doesNotExist())
                .andExpect(jsonPath("$.data.*", hasSize(5)));
    }

    @Test
    void updatingAUserAnswers200WithTheSameFiveKeys_andALockedAccountSaysIsActiveFalse() throws Exception {
        when(userService.updateUser(eq(6L), any())).thenReturn(user(6L, "ROLE_ADMIN", false));

        mockMvc.perform(put("/admin/ajax/users/{id}", 6L)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"binh_user\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Cập nhật thông tin thành công"))
                .andExpect(jsonPath("$.data.id").value(6))
                .andExpect(jsonPath("$.data.role").value("ROLE_ADMIN"))
                .andExpect(jsonPath("$.data.isActive").value(false))
                .andExpect(jsonPath("$.data.active").doesNotExist())
                .andExpect(jsonPath("$.data.*", hasSize(5)));
    }

    private static AppReview review(long id, String comment) {
        AppReview review = new AppReview();
        review.setId(id);
        review.setUserEmail("an" + id + "@example.com");
        review.setRating(4);
        review.setComment(comment);
        review.setStatus("PENDING");
        return review;
    }

    @Test
    void theReviewsPageListsTheReviewsNewestFirstAsGiven() throws Exception {
        when(appReviewService.listNewestFirst(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(review(2L, "Rất tiện"), review(1L, "Dùng ổn"))));

        mockMvc.perform(get("/admin/reviews"))
                .andExpect(status().isOk())
                .andExpect(view().name("admin/reviews"))
                .andExpect(model().attribute("reviews", hasSize(2)))
                .andExpect(content().string(containsString("an2@example.com")))
                .andExpect(content().string(containsString("Dùng ổn")));
    }
}
