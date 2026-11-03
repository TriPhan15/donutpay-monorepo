package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Dto.SubscriptionPlanRequestDto;
import vn.edu.huit.finance.core.Entity.SubscriptionPlan;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.AppReviewRepository;
import vn.edu.huit.finance.core.Repository.CampaignRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.SubscriptionPlanRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
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
import vn.edu.huit.finance.core.Service.TokenBlacklistService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserService;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrfHeader;

/**
 * B3: the plan form says "enter -1 for unlimited", so -1 must get through create and update, and the page must show
 * the same value as "Unlimited" and hand it back to the edit form.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = {
        AdminController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminSubscriptionPlanTest {

    private static final String PLANS = "/admin/subscriptions";
    private static final String AJAX_PLANS = "/admin/ajax/subscriptions";
    private static final String AJAX_PLAN_7 = AJAX_PLANS + "/7";
    private static final String UNLIMITED_BADGE = "<i class=\"bi bi-infinity\"></i> Unlimited";
    private static final String PLACEHOLDER = "placeholder=\"Nhập -1 nếu vô hạn\"";

    @Autowired private MockMvc mockMvc;

    @MockBean private TransactionService transactionService;
    @MockBean private ReceiptProcessingService receiptProcessingService;
    @MockBean private AdminStatisticsService adminStatisticsService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private UserRepository userRepo;
    @MockBean private CategoryRepository categoryRepo;
    @MockBean private CampaignRepository campaignRepo;
    @MockBean private ReceiptRepository receiptRepo;
    @MockBean private BackupService backupService;
    @MockBean private CustomerSegmentationService customerSegmentationService;
    @MockBean private UserService userService;
    @MockBean private EntityManager entityManager;
    @MockBean private SubscriptionPlanRepository subscriptionPlanRepository;
    @MockBean private SubscriptionPlanService subscriptionPlanService;
    @MockBean private CategoryService categoryService;
    @MockBean private AppReviewService appReviewService;
    @MockBean private AuditLogQueryService auditLogQueryService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private AppReviewRepository appReviewRepository;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpSession adminSession() {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY, new SecurityContextImpl(
                new UsernamePasswordAuthenticationToken("someone", null, AuthorityUtils.createAuthorityList(Roles.ADMIN))));
        return session;
    }

    private static String planJson(int maxAiScans) {
        return "{\"planName\":\"VIP\",\"price\":99000,\"durationDays\":30,\"maxAiScans\":" + maxAiScans
                + ",\"wcmSpadeEnabled\":true}";
    }

    @Test
    void creatingAPlanWithUnlimitedScansIsAccepted() throws Exception {
        mockMvc.perform(post(AJAX_PLANS).with(csrfHeader()).session(adminSession())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(planJson(SubscriptionPlanRequestDto.UNLIMITED_AI_SCANS)))
                .andExpect(status().isOk());

        ArgumentCaptor<SubscriptionPlanRequestDto> saved = ArgumentCaptor.forClass(SubscriptionPlanRequestDto.class);
        verify(subscriptionPlanService).createPlan(saved.capture());
        assertEquals(-1, saved.getValue().getMaxAiScans());
    }

    @Test
    void savingAnUnlimitedPlanAgainIsAccepted() throws Exception {
        mockMvc.perform(put(AJAX_PLAN_7).with(csrfHeader()).session(adminSession())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(planJson(SubscriptionPlanRequestDto.UNLIMITED_AI_SCANS)))
                .andExpect(status().isOk());

        ArgumentCaptor<SubscriptionPlanRequestDto> saved = ArgumentCaptor.forClass(SubscriptionPlanRequestDto.class);
        verify(subscriptionPlanService).updatePlan(eq(7L), saved.capture());
        assertEquals(-1, saved.getValue().getMaxAiScans());
    }

    @Test
    void scansBelowMinusOneAreRefusedOnCreateAndOnUpdate() throws Exception {
        mockMvc.perform(post(AJAX_PLANS).with(csrfHeader()).session(adminSession())
                        .contentType(MediaType.APPLICATION_JSON).content(planJson(-2)))
                .andExpect(status().isBadRequest());
        mockMvc.perform(put(AJAX_PLAN_7).with(csrfHeader()).session(adminSession())
                        .contentType(MediaType.APPLICATION_JSON).content(planJson(-2)))
                .andExpect(status().isBadRequest());

        verify(subscriptionPlanService, never()).createPlan(any());
        verify(subscriptionPlanService, never()).updatePlan(any(), any());
    }

    @Test
    void thePageShowsAnUnlimitedPlanAsUnlimitedAndTellsTheAdminWhatToTypeForIt() throws Exception {
        SubscriptionPlan plan = new SubscriptionPlan();
        plan.setId(7L);
        plan.setPlanName("VIP");
        plan.setPrice(99000.0);
        plan.setDurationDays(30);
        plan.setMaxAiScans(SubscriptionPlanRequestDto.UNLIMITED_AI_SCANS);
        when(subscriptionPlanRepository.findAll()).thenReturn(List.of(plan));

        String page = mockMvc.perform(get(PLANS).session(adminSession()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

        assertTrue(page.contains(UNLIMITED_BADGE), "an unlimited plan is badged Unlimited");
        assertTrue(page.contains("data-scans=\"-1\""), "the edit form gets -1 back");
        assertTrue(page.contains(PLACEHOLDER));
    }
}
