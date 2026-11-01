package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Entity.Category;
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

import java.util.List;

import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

/**
 * Trang danh mục của admin, render bằng Thymeleaf thật: thêm cột "Người tạo" (B8). Danh mục mặc định và do admin thêm
 * (không có chủ) ghi "Hệ thống"; danh mục người dùng tự gõ ghi email người tạo. Bỏ qua security (addFilters = false).
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminCategoriesPageTest {

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

    private static Category category(long id, String name, User owner) {
        Category category = new Category();
        category.setId(id);
        category.setName(name);
        category.setType("EXPENSE");
        category.setOwner(owner);
        return category;
    }

    @Test
    void theCategoriesPageShowsWhoCreatedEachOne_theSystemForTheOnesWithoutAnOwner() throws Exception {
        User alice = new User();
        alice.setId(5L);
        alice.setEmail("alice@example.com");
        when(categoryRepo.findAllWithOwner()).thenReturn(List.of(
                category(1L, "Ăn uống", null),
                category(2L, "Cafe sáng", alice)));

        mockMvc.perform(get("/admin/categories"))
                .andExpect(status().isOk())
                .andExpect(view().name("admin/categories"))
                .andExpect(content().string(allOf(
                        containsString("<th>Người tạo</th>"),
                        containsString("Hệ thống"),
                        containsString("alice@example.com"),
                        containsString("Cafe sáng"))));

        verify(categoryRepo, never()).findAll();
    }
}
