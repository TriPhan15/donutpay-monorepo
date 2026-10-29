package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.FieldCount;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.ModelCount;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto.MonthlyConfidence;
import vn.edu.huit.finance.core.Dto.OcrFeedbackFilterRequestDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.OcrFeedbackNotFoundException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.OcrMongoService;
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventType;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;

import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.flash;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrlPattern;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrf;

/**
 * The NoSQL pages of the admin web: the OCR feedbacks of MongoDB with their charts, and the operations page that rebuilds
 * the Redis leaderboard (and the Elasticsearch index, see AdminNoSqlSearchReindexTest). Behind the filter chain of the
 * admin pages, like every page under /admin; with the PostgreSQL engine no indexer bean exists.
 */
@WebMvcTest(value = AdminNoSqlPageController.class, properties = "app.search.engine=postgres")
@ContextConfiguration(classes = {
        AdminNoSqlPageController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminNoSqlPageControllerTest {

    private static final String FEEDBACKS = "/admin/ocr-feedbacks";
    private static final String NOSQL = "/admin/nosql";

    @Autowired private MockMvc mockMvc;

    @MockBean private OcrMongoService ocrMongoService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private UserRepository userRepo;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;
    @MockBean private AdminEventPublisher adminEventPublisher;

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpSession admin() {
        return sessionOf(Roles.ADMIN);
    }

    private static MockHttpSession sessionOf(String role) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
                new SecurityContextImpl(new UsernamePasswordAuthenticationToken(
                        "someone", null, AuthorityUtils.createAuthorityList(role))));
        return session;
    }

    private static OcrFeedbackResponseDto feedback(String id, boolean resolved) {
        return OcrFeedbackResponseDto.builder().id(id).receiptId(41L).transactionId(9L).userId(3L)
                .field(OcrField.TOTAL_COST.key()).aiValue("125000").expectedValue("152000").modelVersion("donut-v5")
                .resolved(resolved).reportedAt(LocalDateTime.of(2026, 10, 20, 14, 5)).build();
    }

    private static OcrAnalyticsResponseDto analytics() {
        return OcrAnalyticsResponseDto.builder()
                .errorsByField(List.of(new FieldCount("total_cost", 7), new FieldCount("seller_name", 2)))
                .errorsByModel(List.of(new ModelCount("donut-v5", 8), new ModelCount("unknown", 1)))
                .confidenceByMonth(List.of(new MonthlyConfidence("2026-09", 0.91, 10),
                        new MonthlyConfidence("2026-10", null, 4)))
                .receiptsWithErrorRate(0.125)
                .build();
    }

    // ------------------------------------------------------------------------------------------------- who may open

    @ParameterizedTest
    @ValueSource(strings = {FEEDBACKS, NOSQL})
    void withoutAnAdminSessionThePageIsSentToTheLoginPage(String url) throws Exception {
        mockMvc.perform(get(url))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrlPattern("**/admin/login"));

        verifyNoInteractions(ocrMongoService, leaderboardService);
    }

    @ParameterizedTest
    @ValueSource(strings = {FEEDBACKS, NOSQL})
    void ocrFeedbacks_user_forbidden(String url) throws Exception {
        mockMvc.perform(get(url).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());

        verifyNoInteractions(ocrMongoService, leaderboardService);
    }

    @Test
    void anOrdinaryUserCannotResolveNorDelete() throws Exception {
        mockMvc.perform(post(FEEDBACKS + "/abc/resolve").with(csrf()).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());
        mockMvc.perform(post(FEEDBACKS + "/abc/delete").with(csrf()).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());

        verifyNoInteractions(ocrMongoService);
    }

    // ------------------------------------------------------------------------------------------- the feedback page

    @Test
    void ocrFeedbacks_admin_200_showsRowsAndCharts() throws Exception {
        when(ocrMongoService.findFeedbacks(any(OcrFeedbackFilterRequestDto.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(feedback("f1", false), feedback("f2", true)),
                        PageRequest.of(0, 20), 2));
        when(ocrMongoService.analytics(null, null)).thenReturn(analytics());

        String page = mockMvc.perform(get(FEEDBACKS).session(admin()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

        assertTrue(page.contains("donut-v5") && page.contains("125000") && page.contains("152000"), "row values");
        assertTrue(page.contains("20/10/2026 14:05"), "reported date");
        assertTrue(page.contains("/admin/ocr-feedbacks/f1/resolve") && page.contains("/admin/ocr-feedbacks/f1/delete"));
        // The resolved one has no "Đã xử lý" button any more, only the delete one.
        assertTrue(!page.contains("/admin/ocr-feedbacks/f2/resolve") && page.contains("/admin/ocr-feedbacks/f2/delete"));
        assertTrue(page.contains("12,5%"), "error rate KPI");
        // Inlined into JavaScript, where Thymeleaf writes every non-ASCII character as a \\u escape; null is a gap.
        assertTrue(page.contains("const fieldLabels = [\"T\\u1ED5ng ti\\u1EC1n\",\"T\\u00EAn c\\u1EEDa h\\u00E0ng\"];"), page);
        assertTrue(page.contains("const fieldData = [7,2];"));
        assertTrue(page.contains("const modelLabels = [\"donut-v5\",\"unknown\"];"));
        assertTrue(page.contains("const modelData = [8,1];"));
        assertTrue(page.contains("const monthLabels = [\"2026-09\",\"2026-10\"];"));
        assertTrue(page.contains("const monthData = [0.91,null];"));
        assertTrue(page.contains("spanGaps: false"));
    }

    @Test
    void ocrFeedbacks_filterIsPassedToTheServiceByEnumName() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any())).thenReturn(new PageImpl<>(List.of()));
        when(ocrMongoService.analytics(any(), any())).thenReturn(analytics());

        mockMvc.perform(get(FEEDBACKS).session(admin())
                        .param("field", "SELLER_NAME").param("resolved", "false")
                        .param("from", "2026-10-01").param("to", "2026-10-27").param("page", "2"))
                .andExpect(status().isOk());

        verify(ocrMongoService).findFeedbacks(
                OcrFeedbackFilterRequestDto.builder().field(OcrField.SELLER_NAME).resolved(false)
                        .from(LocalDate.of(2026, 10, 1)).to(LocalDate.of(2026, 10, 27)).build(),
                PageRequest.of(2, 20, Sort.by(Sort.Direction.DESC, "reportedAt")));
        verify(ocrMongoService).analytics(LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 27));
    }

    @Test
    void mongoDown_pageShowsBanner() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any())).thenThrow(new DataAccessResourceFailureException("mongo down"));
        when(ocrMongoService.analytics(any(), any())).thenThrow(new DataAccessResourceFailureException("mongo down"));

        mockMvc.perform(get(FEEDBACKS).session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Không đọc được dữ liệu MongoDB"),
                        containsString("const fieldData = [];"))));
    }

    @Test
    void analyticsDown_keepsTheRowsAndShowsAnAnalyticsBanner() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any())).thenReturn(
                new PageImpl<>(List.of(feedback("f1", false)), PageRequest.of(0, 20), 1));
        when(ocrMongoService.analytics(any(), any())).thenThrow(new DataAccessResourceFailureException("agg failed"));

        mockMvc.perform(get(FEEDBACKS).session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("/admin/ocr-feedbacks/f1/delete"),
                        containsString("Không đọc được thống kê OCR"),
                        not(containsString("Không đọc được dữ liệu MongoDB")))));
    }

    @Test
    void feedbacksDown_keepsTheChartsAndShowsTheBanner() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any())).thenThrow(new DataAccessResourceFailureException("find failed"));
        when(ocrMongoService.analytics(any(), any())).thenReturn(analytics());

        mockMvc.perform(get(FEEDBACKS).session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("Không đọc được dữ liệu MongoDB"),
                        containsString("const fieldData = [7,2];"),
                        not(containsString("Không đọc được thống kê OCR")))));
    }

    @Test
    void aPageThatCameBackEmptyAfterADeleteShowsTheLastNonEmptyPage() throws Exception {
        Sort sort = Sort.by(Sort.Direction.DESC, "reportedAt");
        when(ocrMongoService.findFeedbacks(any(), eq(PageRequest.of(3, 20, sort))))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(3, 20, sort), 41));
        when(ocrMongoService.findFeedbacks(any(), eq(PageRequest.of(2, 20, sort))))
                .thenReturn(new PageImpl<>(List.of(feedback("f41", false)), PageRequest.of(2, 20, sort), 41));
        when(ocrMongoService.analytics(any(), any())).thenReturn(analytics());

        mockMvc.perform(get(FEEDBACKS).param("page", "3").session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("/admin/ocr-feedbacks/f41/delete"),
                        containsString("trang 3/3"))));
    }

    @Test
    void resolve_redirectsWithFlash() throws Exception {
        mockMvc.perform(post(FEEDBACKS + "/abc123/resolve").with(csrf()).session(admin()))
                .andExpect(redirectedUrl(FEEDBACKS))
                .andExpect(flash().attribute("message", "Đã đánh dấu phản hồi OCR là đã xử lý"));

        verify(ocrMongoService).resolveFeedback("abc123");
    }

    @Test
    void resolve_keepsTheFilterOfThePageItCameFrom() throws Exception {
        mockMvc.perform(post(FEEDBACKS + "/abc123/resolve").with(csrf()).session(admin())
                        .param("field", "TOTAL_COST").param("page", "3"))
                .andExpect(redirectedUrl(FEEDBACKS + "?field=TOTAL_COST&page=3"));
    }

    @Test
    void delete_redirectsWithFlash() throws Exception {
        mockMvc.perform(post(FEEDBACKS + "/abc123/delete").with(csrf()).session(admin()))
                .andExpect(redirectedUrl(FEEDBACKS))
                .andExpect(flash().attribute("message", "Đã xóa phản hồi OCR"));

        verify(ocrMongoService).deleteFeedback("abc123");
    }

    @Test
    void delete_unknownId_flashError() throws Exception {
        doThrow(new OcrFeedbackNotFoundException("Không tìm thấy phản hồi OCR")).when(ocrMongoService).deleteFeedback("nope");

        mockMvc.perform(post(FEEDBACKS + "/nope/delete").with(csrf()).session(admin()))
                .andExpect(redirectedUrl(FEEDBACKS))
                .andExpect(flash().attribute("error", "Không tìm thấy phản hồi OCR"));
    }

    @Test
    void resolve_mongoDown_flashErrorNot500() throws Exception {
        when(ocrMongoService.resolveFeedback("abc")).thenThrow(new DataAccessResourceFailureException("mongo down"));

        mockMvc.perform(post(FEEDBACKS + "/abc/resolve").with(csrf()).session(admin()))
                .andExpect(redirectedUrl(FEEDBACKS))
                .andExpect(flash().attribute("error", "Không kết nối được MongoDB, vui lòng thử lại sau"));
    }

    // ------------------------------------------------------------------------------------------ the operations page

    @Test
    void nosqlPage_engineFromProperty() throws Exception {
        YearMonth month = YearMonth.of(2026, 9);
        when(leaderboardService.topSpenders(month, 10)).thenReturn(
                List.of(new TopSpenderDto(9L, "binh_top", new BigDecimal("900000.00"))));

        mockMvc.perform(get(NOSQL).param("month", "2026-09").session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString("postgres"),
                        containsString("value=\"2026-09\""),
                        containsString("binh_top"),
                        containsString("900.000 VNĐ"),
                        containsString("Dựng lại bảng xếp hạng tháng"),
                        containsString("Dựng lại chỉ mục"),
                        containsString("disabled"))));
    }

    @Test
    void nosqlPage_redisDown_showsBannerNot500() throws Exception {
        when(leaderboardService.topSpenders(any(), eq(10))).thenThrow(new DataAccessResourceFailureException("redis down"));

        mockMvc.perform(get(NOSQL).session(admin()))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Không đọc được bảng xếp hạng từ Redis")));
    }

    @Test
    void reindex_whenPostgresEngine_flashDisabled() throws Exception {
        mockMvc.perform(post(NOSQL + "/search/reindex").with(csrf()).session(admin()))
                .andExpect(redirectedUrl(NOSQL))
                .andExpect(flash().attribute("error", AdminNoSqlPageController.MSG_SEARCH_DISABLED));
    }

    @Test
    void rebuildMonth_redirectsWithCount() throws Exception {
        when(leaderboardService.rebuildMonth(YearMonth.of(2026, 9))).thenReturn(12);

        mockMvc.perform(post(NOSQL + "/leaderboard/rebuild").with(csrf()).param("month", "2026-09").session(admin()))
                .andExpect(redirectedUrl(NOSQL + "?month=2026-09"))
                .andExpect(flash().attribute("message", "Đã dựng lại bảng xếp hạng tháng 2026-09: 12 người dùng"));
    }

    @Test
    void rebuildMonth_redisDown_flashError() throws Exception {
        when(leaderboardService.rebuildMonth(any())).thenThrow(new DataAccessResourceFailureException("redis down"));

        mockMvc.perform(post(NOSQL + "/leaderboard/rebuild").with(csrf()).param("month", "2026-09").session(admin()))
                .andExpect(redirectedUrl(NOSQL + "?month=2026-09"))
                .andExpect(flash().attribute("error", "Không dựng lại được bảng xếp hạng, vui lòng thử lại sau"));
    }

    @Test
    void rebuildMonth_tellsEveryAdministratorWhichMonthWasRebuilt() throws Exception {
        when(leaderboardService.rebuildMonth(YearMonth.of(2026, 9))).thenReturn(12);

        mockMvc.perform(post(NOSQL + "/leaderboard/rebuild").with(csrf()).param("month", "2026-09").session(admin()));

        ArgumentCaptor<AdminEvent> published = ArgumentCaptor.forClass(AdminEvent.class);
        verify(adminEventPublisher).publish(published.capture());
        assertEquals(AdminEventType.LEADERBOARD_REBUILT, published.getValue().type());
        assertEquals("Đã dựng lại bảng xếp hạng tháng 2026-09: 12 người dùng", published.getValue().message());
    }

    @Test
    void rebuildMonth_failed_publishesNothing() throws Exception {
        when(leaderboardService.rebuildMonth(any())).thenThrow(new DataAccessResourceFailureException("redis down"));

        mockMvc.perform(post(NOSQL + "/leaderboard/rebuild").with(csrf()).param("month", "2026-09").session(admin()));

        verify(adminEventPublisher, never()).publish(any());
    }

    @Test
    void badFilterValuesRenderThePageWithABannerNotA400() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any())).thenReturn(new PageImpl<>(List.of()));
        when(ocrMongoService.analytics(any(), any())).thenReturn(analytics());

        for (String[] bad : new String[][]{{"field", "NOPE"}, {"from", "31/12/2026"}, {"to", "not-a-date"}, {"resolved", "maybe"}}) {
            mockMvc.perform(get(FEEDBACKS).session(admin()).param(bad[0], bad[1]))
                    .andExpect(status().isOk())
                    .andExpect(content().string(containsString(AdminNoSqlPageController.MSG_FILTER_INVALID)));
        }
        // The bad values are ignored: the service gets no filter at all.
        verify(ocrMongoService, org.mockito.Mockito.times(4)).findFeedbacks(
                OcrFeedbackFilterRequestDto.builder().build(),
                PageRequest.of(0, 20, Sort.by(Sort.Direction.DESC, "reportedAt")));
    }

    @Test
    void aBadPageNumberIsPageZero() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any())).thenReturn(new PageImpl<>(List.of()));
        when(ocrMongoService.analytics(any(), any())).thenReturn(analytics());

        mockMvc.perform(get(FEEDBACKS).session(admin()).param("page", "abc")).andExpect(status().isOk());

        verify(ocrMongoService).findFeedbacks(any(), eq(PageRequest.of(0, 20, Sort.by(Sort.Direction.DESC, "reportedAt"))));
    }

    @Test
    void aBadMonthRendersTheOperationsPageWithABannerAndTheCurrentMonth() throws Exception {
        when(leaderboardService.topSpenders(any(), eq(10))).thenReturn(List.of());

        mockMvc.perform(get(NOSQL).session(admin()).param("month", "2026-13"))
                .andExpect(status().isOk())
                .andExpect(content().string(allOf(
                        containsString(AdminNoSqlPageController.MSG_MONTH_INVALID),
                        containsString("value=\"" + YearMonth.now() + "\""))));
    }

    @Test
    void aBadMonthOnRebuildIsAFlashErrorAndNothingIsRebuilt() throws Exception {
        mockMvc.perform(post(NOSQL + "/leaderboard/rebuild").with(csrf()).param("month", "abc").session(admin()))
                .andExpect(redirectedUrl(NOSQL))
                .andExpect(flash().attribute("error", AdminNoSqlPageController.MSG_MONTH_INVALID));

        verifyNoInteractions(leaderboardService);
    }

    @Test
    void sidebarLinksToBothPages() throws Exception {
        when(leaderboardService.topSpenders(any(), eq(10))).thenReturn(List.of());

        mockMvc.perform(get(NOSQL).session(admin()))
                .andExpect(content().string(allOf(
                        containsString("href=\"/admin/ocr-feedbacks\""),
                        containsString("Phản hồi OCR (MongoDB)"),
                        containsString("href=\"/admin/nosql\""),
                        containsString("Vận hành NoSQL"))));
    }

    @Test
    void theLayoutOpensTheRealtimeStreamWithAToastAreaAndTwoBadges() throws Exception {
        when(leaderboardService.topSpenders(any(), eq(10))).thenReturn(List.of());

        mockMvc.perform(get(NOSQL).session(admin()))
                .andExpect(content().string(allOf(
                        containsString("<script src=\"/admin/js/admin-events.js\"></script>"),
                        containsString("id=\"adminToastArea\""),
                        containsString("data-admin-badge=\"/admin/receipts\""),
                        containsString("data-admin-badge=\"/admin/ocr-feedbacks\""))));
    }
}
