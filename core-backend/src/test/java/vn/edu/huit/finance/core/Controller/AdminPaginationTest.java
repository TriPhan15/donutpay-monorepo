package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
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
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;
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
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * B2: thanh phân trang của trang admin Người dùng và Hóa đơn. Server chỉ trả một trang (mặc định 10 dòng), nên thanh này
 * là cách duy nhất để admin xem và duyệt hóa đơn từ dòng 11 trở đi. Render bằng Thymeleaf thật, bỏ qua security
 * (addFilters = false), giống AdminUserAndReceiptPagesTest.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminPaginationTest {

    private static final int PAGE_SIZE = 10;
    private static final long TOTAL_ROWS = 25;

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

    private static Page<User> usersPage(int pageIndex, int size, long total) {
        User user = new User();
        user.setId(11L);
        user.setUsername("nguoi_dung_trang_" + pageIndex);
        user.setRole("ROLE_USER");
        user.setActive(true);
        return new PageImpl<>(List.of(user), PageRequest.of(pageIndex, size), total);
    }

    private static Page<Receipt> receiptsPage(int pageIndex, int size, long total) {
        Receipt receipt = new Receipt();
        receipt.setId(11L);
        receipt.setStatus("COMPLETED_RAW");
        receipt.setVendorName("Cua hang trang " + pageIndex);
        receipt.setExtractedTotal(new BigDecimal("120000"));
        return new PageImpl<>(List.of(receipt), PageRequest.of(pageIndex, size), total);
    }

    @Test
    void usersPageOne_asksTheRepositoryForTheSecondPage_andLinksToTheOtherPages() throws Exception {
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(usersPage(1, PAGE_SIZE, TOTAL_ROWS));

        mockMvc.perform(get("/admin/users").param("userPage", "1"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("nguoi_dung_trang_1"),
                        containsString("Trang 2 / 3"),
                        containsString("25 bản ghi"),
                        containsString("href=\"/admin/users?userPage=0&amp;size=10\""),
                        containsString("href=\"/admin/users?userPage=2&amp;size=10\""))));

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(userService).listNewestFirst(pageable.capture());
        assertEquals(1, pageable.getValue().getPageNumber());
        assertEquals(PAGE_SIZE, pageable.getValue().getPageSize());
    }

    @Test
    void receiptsPageOne_keepsTheSizeInTheLinks() throws Exception {
        when(receiptProcessingService.listNewestFirst(any(Pageable.class))).thenReturn(receiptsPage(1, 5, TOTAL_ROWS));

        mockMvc.perform(get("/admin/receipts").param("receiptPage", "1").param("size", "5"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Cua hang trang 1"),
                        containsString("Trang 2 / 5"),
                        containsString("href=\"/admin/receipts?receiptPage=0&amp;size=5\""),
                        containsString("href=\"/admin/receipts?receiptPage=2&amp;size=5\""),
                        containsString("href=\"/admin/receipts?receiptPage=4&amp;size=5\""))));

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(receiptProcessingService).listNewestFirst(pageable.capture());
        assertEquals(1, pageable.getValue().getPageNumber());
        assertEquals(5, pageable.getValue().getPageSize());
    }

    @Test
    void theFirstPageHasNoPreviousLink() throws Exception {
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(usersPage(0, PAGE_SIZE, TOTAL_ROWS));

        mockMvc.perform(get("/admin/users"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Trang 1 / 3"),
                        containsString("page-item disabled\" data-page-nav=\"previous\""),
                        not(containsString("page-item disabled\" data-page-nav=\"next\"")),
                        containsString("href=\"/admin/users?userPage=1&amp;size=10\""))));
    }

    @Test
    void theLastPageHasNoNextLink() throws Exception {
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(usersPage(2, PAGE_SIZE, TOTAL_ROWS));

        mockMvc.perform(get("/admin/users").param("userPage", "2"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Trang 3 / 3"),
                        containsString("page-item disabled\" data-page-nav=\"next\""),
                        not(containsString("page-item disabled\" data-page-nav=\"previous\"")),
                        not(containsString("userPage=3")))));
    }

    @Test
    void withManyPages_onlyAWindowAroundTheCurrentPageIsListed_plusTheFirstAndLast() throws Exception {
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(usersPage(10, PAGE_SIZE, 200));

        mockMvc.perform(get("/admin/users").param("userPage", "10"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Trang 11 / 20"),
                        containsString("href=\"/admin/users?userPage=0&amp;size=10\""),
                        containsString("href=\"/admin/users?userPage=8&amp;size=10\""),
                        containsString("href=\"/admin/users?userPage=12&amp;size=10\""),
                        containsString("href=\"/admin/users?userPage=19&amp;size=10\""),
                        not(containsString("userPage=5&")),
                        not(containsString("userPage=15&")))));
    }

    @Test
    void aSinglePageShowsNoPaginationBar() throws Exception {
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(usersPage(0, PAGE_SIZE, 3));
        when(receiptProcessingService.listNewestFirst(any(Pageable.class))).thenReturn(receiptsPage(0, PAGE_SIZE, 3));

        mockMvc.perform(get("/admin/users"))
                .andExpect(status().isOk())
                .andExpect(content().string(not(containsString("data-pagination-bar"))));
        mockMvc.perform(get("/admin/receipts"))
                .andExpect(status().isOk())
                .andExpect(content().string(not(containsString("data-pagination-bar"))));
    }

    @Test
    void aNegativePageNumberIsTreatedAsTheFirstPage() throws Exception {
        when(userService.listNewestFirst(any(Pageable.class))).thenReturn(usersPage(0, PAGE_SIZE, TOTAL_ROWS));

        mockMvc.perform(get("/admin/users").param("userPage", "-4")).andExpect(status().isOk());

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(userService).listNewestFirst(pageable.capture());
        assertEquals(0, pageable.getValue().getPageNumber());
    }
}
