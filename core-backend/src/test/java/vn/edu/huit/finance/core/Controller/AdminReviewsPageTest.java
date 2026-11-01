package vn.edu.huit.finance.core.Controller;

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
import vn.edu.huit.finance.core.Entity.AppReview;
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
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The reviews page is paged on the server like the users and receipts pages: the page and the size come from the request,
 * the size is bounded by AdminController.normalizePageSize, and the page shows the shared pagination bar.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminReviewsPageTest {

    private static final int PAGE_SIZE = 10;
    private static final long TOTAL_ROWS = 25;

    @Autowired private MockMvc mockMvc;

    @MockBean private AdminStatisticsService adminStatisticsService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private ReceiptProcessingService receiptProcessingService;
    @MockBean private BackupService backupService;
    @MockBean private CustomerSegmentationService customerSegmentationService;
    @MockBean private UserService userService;
    @MockBean private TransactionService transactionService;
    @MockBean private SubscriptionPlanService subscriptionPlanService;
    @MockBean private CategoryService categoryService;
    @MockBean private AppReviewService appReviewService;
    @MockBean private AuditLogQueryService auditLogQueryService;
    @MockBean private LoginAttemptService loginAttemptService;

    private static Page<AppReview> reviewsPage(int pageIndex, int size, long total) {
        AppReview review = new AppReview();
        review.setId(11L);
        review.setUserEmail("an@example.com");
        review.setRating(5);
        review.setComment("Nhận xét trang " + pageIndex);
        review.setStatus("PENDING");
        return new PageImpl<>(List.of(review), PageRequest.of(pageIndex, size), total);
    }

    private Pageable askedPageable() {
        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(appReviewService).listNewestFirst(pageable.capture());
        return pageable.getValue();
    }

    @Test
    void withoutParametersTheFirstPageOfTenIsAsked() throws Exception {
        when(appReviewService.listNewestFirst(any(Pageable.class))).thenReturn(reviewsPage(0, PAGE_SIZE, 3));

        mockMvc.perform(get("/admin/reviews"))
                .andExpect(status().isOk())
                .andExpect(model().attribute("pageSize", PAGE_SIZE))
                .andExpect(content().string(allOf(
                        containsString("Nhận xét trang 0"),
                        not(containsString("data-pagination-bar")))));

        Pageable asked = askedPageable();
        assertEquals(0, asked.getPageNumber());
        assertEquals(PAGE_SIZE, asked.getPageSize());
    }

    @Test
    void aHugeSizeIsClampedToTheMaximum() throws Exception {
        when(appReviewService.listNewestFirst(any(Pageable.class))).thenReturn(reviewsPage(0, 100, 3));

        mockMvc.perform(get("/admin/reviews").param("size", "1000000"))
                .andExpect(status().isOk())
                .andExpect(model().attribute("pageSize", AdminController.MAX_PAGE_SIZE));

        assertEquals(AdminController.MAX_PAGE_SIZE, askedPageable().getPageSize());
    }

    @Test
    void aZeroSizeFallsBackToTheDefault_andANegativePageToTheFirst() throws Exception {
        when(appReviewService.listNewestFirst(any(Pageable.class))).thenReturn(reviewsPage(0, PAGE_SIZE, 3));

        mockMvc.perform(get("/admin/reviews").param("size", "0").param("reviewPage", "-4"))
                .andExpect(status().isOk());

        Pageable asked = askedPageable();
        assertEquals(PAGE_SIZE, asked.getPageSize());
        assertEquals(0, asked.getPageNumber());
    }

    @Test
    void pageOneAsksForTheSecondPage_andLinksToTheOtherPagesKeepingTheSize() throws Exception {
        when(appReviewService.listNewestFirst(any(Pageable.class))).thenReturn(reviewsPage(1, 5, TOTAL_ROWS));

        mockMvc.perform(get("/admin/reviews").param("reviewPage", "1").param("size", "5"))
                .andExpect(status().isOk())
                .andExpect(model().attributeExists("reviews", "reviewsPage"))
                .andExpect(content().string(allOf(
                        containsString("Nhận xét trang 1"),
                        containsString("Trang 2 / 5"),
                        containsString("25 bản ghi"),
                        containsString("href=\"/admin/reviews?reviewPage=0&amp;size=5\""),
                        containsString("href=\"/admin/reviews?reviewPage=2&amp;size=5\""),
                        containsString("href=\"/admin/reviews?reviewPage=4&amp;size=5\""))));

        Pageable asked = askedPageable();
        assertEquals(1, asked.getPageNumber());
        assertEquals(5, asked.getPageSize());
    }
}
