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
import vn.edu.huit.finance.core.Entity.Receipt;
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
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.ReceiptProcessingService;
import vn.edu.huit.finance.core.Service.SubscriptionPlanService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserService;

import java.math.BigDecimal;
import java.util.List;

import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

/**
 * Trang quản lý người dùng và trang hóa đơn AI, render bằng Thymeleaf thật: quản lý tài khoản (thêm/sửa/khóa/xóa) nằm
 * ở /admin/users và gọi đúng các endpoint /admin/ajax/users/**; trang hóa đơn có nút Duyệt / Từ chối theo trạng thái.
 * Bỏ qua security (addFilters = false), giống AdminDashboardPageTest.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminUserAndReceiptPagesTest {

    @Autowired private MockMvc mockMvc;

    @MockBean private AdminStatisticsService adminStatisticsService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private ReceiptProcessingService receiptProcessingService;
    @MockBean private UserRepository userRepo;
    @MockBean private CategoryRepository categoryRepo;
    @MockBean private CampaignRepository campaignRepo;
    @MockBean private ReceiptRepository receiptRepo;
    @MockBean private BackupService backupService;
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

    private static Receipt receipt(long id, String status) {
        Receipt receipt = new Receipt();
        receipt.setId(id);
        receipt.setStatus(status);
        receipt.setVendorName("Cửa hàng " + id);
        receipt.setExtractedTotal(new BigDecimal("120000"));
        return receipt;
    }

    @Test
    void theUsersPageHoldsTheAccountManagement_andLocksThroughTheRealAjaxEndpoint() throws Exception {
        User user = new User();
        user.setId(5L);
        user.setUsername("binh_user");
        user.setEmail("binh@example.com");
        user.setRole("ROLE_USER");
        user.setActive(true);
        when(userRepo.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of(user)));

        mockMvc.perform(get("/admin/users"))
                .andExpect(status().isOk())
                .andExpect(view().name("admin/users"))
                .andExpect(content().string(allOf(
                        containsString("binh_user"),
                        containsString("id=\"addUserModal\""),
                        containsString("id=\"editUserModal\""),
                        containsString("fetch(`/admin/ajax/users/${userId}/toggle-status`, { method: 'PUT' })"),
                        containsString("fetch(`/admin/ajax/users/${userId}`, { method: 'DELETE' })"),
                        not(containsString("/api/admin/users/")))));

        verify(receiptRepo, never()).findAllByOrderByCreatedAtDesc(any());
    }

    @Test
    void theReceiptsPageOffersApproveAndRejectOnlyWhereTheLifecycleAllowsThem() throws Exception {
        when(receiptRepo.findAllByOrderByCreatedAtDesc(any(Pageable.class))).thenReturn(new PageImpl<>(List.of(
                receipt(7L, "COMPLETED_RAW"),
                receipt(8L, "CANCELED"),
                receipt(9L, "FAILED"),
                receipt(10L, "APPROVED"))));

        mockMvc.perform(get("/admin/receipts"))
                .andExpect(status().isOk())
                .andExpect(view().name("admin/receipts"))
                .andExpect(content().string(allOf(
                        // Đọc xong: duyệt hoặc từ chối được.
                        containsString("action=\"/admin/receipts/approve/7\""),
                        containsString("action=\"/admin/receipts/reject/7\""),
                        // Đã hủy: không còn thao tác nào.
                        not(containsString("/admin/receipts/approve/8\"")),
                        not(containsString("/admin/receipts/reject/8\"")),
                        // Lỗi: duyệt được (số tiền của chủ hóa đơn), từ chối lần nữa thì không.
                        containsString("action=\"/admin/receipts/approve/9\""),
                        not(containsString("/admin/receipts/reject/9\"")),
                        // Đã duyệt: chỉ còn từ chối.
                        not(containsString("/admin/receipts/approve/10\"")),
                        containsString("action=\"/admin/receipts/reject/10\""),
                        // Quản lý tài khoản không còn nằm ở trang hóa đơn.
                        not(containsString("addUserModal")),
                        not(containsString("toggleUserStatus")))));

        verify(userRepo, never()).findAll(any(Pageable.class));
    }
}
