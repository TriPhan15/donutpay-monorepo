package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Dto.TopSpenderDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventType;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The leaderboard endpoints through the whole filter chain: who may call them and which parameters they accept. */
@WebMvcTest(AdminLeaderboardController.class)
@ContextConfiguration(classes = {
        AdminLeaderboardController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminLeaderboardControllerTest {

    private static final String PATH = "/api/admin/leaderboard";
    private static final String REBUILD = PATH + "/rebuild";
    private static final String USER_TOKEN = "user.jwt.token";
    private static final String ADMIN_TOKEN = "admin.jwt.token";
    private static final YearMonth OCTOBER = YearMonth.of(2026, 10);

    @Autowired private MockMvc mockMvc;

    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;
    @MockBean private AdminEventPublisher adminEventPublisher;

    @BeforeEach
    void stubTokens() {
        stubToken(USER_TOKEN, "alice", "ROLE_USER");
        stubToken(ADMIN_TOKEN, "root", "ROLE_ADMIN");
    }

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private void stubToken(String token, String username, String role) {
        when(jwtUtil.parse(token, TokenType.ACCESS)).thenReturn(new TokenClaims(username, 0));
        User user = new User();
        user.setUsername(username);
        user.setActive(true);
        user.setRole(role);
        user.setLastActionTime(LocalDateTime.now());
        when(userDetailsService.loadApplicationUser(username)).thenReturn(user);
        when(userDetailsService.loadUserByUsername(username)).thenReturn(
                new org.springframework.security.core.userdetails.User(username, "hash", AuthorityUtils.createAuthorityList(role)));
    }

    private static MockHttpServletRequestBuilder asAdmin(MockHttpServletRequestBuilder request) {
        return request.header(HttpHeaders.AUTHORIZATION, "Bearer " + ADMIN_TOKEN);
    }

    @Test
    void anAdministratorReadsTheLeaderboardOfTheMonthAsked() throws Exception {
        when(leaderboardService.topSpenders(OCTOBER, 5)).thenReturn(
                List.of(new TopSpenderDto(2L, "binh", new BigDecimal("500000.00"))));

        mockMvc.perform(asAdmin(get(PATH).param("month", "2026-10").param("limit", "5")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data[0].userId").value(2))
                .andExpect(jsonPath("$.data[0].username").value("binh"));
    }

    @Test
    void withoutParametersTheCurrentMonthTopTenIsAsked() throws Exception {
        mockMvc.perform(asAdmin(get(PATH))).andExpect(status().isOk());

        verify(leaderboardService).topSpenders(YearMonth.now(), 10);
    }

    @Test
    void aLimitOfZeroIsA400() throws Exception {
        mockMvc.perform(asAdmin(get(PATH).param("limit", "0"))).andExpect(status().isBadRequest());

        verifyNoInteractions(leaderboardService);
    }

    @Test
    void aLimitAboveFiftyIsA400() throws Exception {
        mockMvc.perform(asAdmin(get(PATH).param("limit", "51"))).andExpect(status().isBadRequest());

        verifyNoInteractions(leaderboardService);
    }

    @Test
    void anOrdinaryUserIsForbidden() throws Exception {
        mockMvc.perform(get(PATH).header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());

        verifyNoInteractions(leaderboardService);
    }

    @Test
    void anAdministratorRebuildsAMonth() throws Exception {
        when(leaderboardService.rebuildMonth(OCTOBER)).thenReturn(7);

        mockMvc.perform(asAdmin(post(REBUILD).param("month", "2026-10")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Đã dựng lại bảng xếp hạng chi tiêu từ cơ sở dữ liệu"))
                .andExpect(jsonPath("$.data").value(7));
    }

    @Test
    void aRebuildTellsEveryAdministratorWhichMonthWasRebuilt() throws Exception {
        when(leaderboardService.rebuildMonth(OCTOBER)).thenReturn(7);

        mockMvc.perform(asAdmin(post(REBUILD).param("month", "2026-10"))).andExpect(status().isOk());

        org.mockito.ArgumentCaptor<AdminEvent> published = org.mockito.ArgumentCaptor.forClass(AdminEvent.class);
        verify(adminEventPublisher).publish(published.capture());
        org.junit.jupiter.api.Assertions.assertEquals(AdminEventType.LEADERBOARD_REBUILT, published.getValue().type());
        org.junit.jupiter.api.Assertions.assertEquals("Đã dựng lại bảng xếp hạng tháng 2026-10: 7 người dùng",
                published.getValue().message());
    }

    @Test
    void aFailedRebuildPublishesNothing() throws Exception {
        when(leaderboardService.rebuildMonth(OCTOBER))
                .thenThrow(new org.springframework.dao.DataAccessResourceFailureException("redis down"));

        mockMvc.perform(asAdmin(post(REBUILD).param("month", "2026-10")));

        verifyNoInteractions(adminEventPublisher);
    }

    @Test
    void rebuildWithoutAMonthMeansTheCurrentOne() throws Exception {
        mockMvc.perform(asAdmin(post(REBUILD))).andExpect(status().isOk());

        verify(leaderboardService).rebuildMonth(YearMonth.now());
    }

    @Test
    void anOrdinaryUserCannotRebuild() throws Exception {
        mockMvc.perform(post(REBUILD).header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());

        verifyNoInteractions(leaderboardService);
    }
}
