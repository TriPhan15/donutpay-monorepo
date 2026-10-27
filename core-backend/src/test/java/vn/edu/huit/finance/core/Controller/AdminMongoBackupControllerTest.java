package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.MongoBackupService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrlPattern;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The MongoDB buttons of the admin backup page, through the filter chain of the admin pages. */
@WebMvcTest(AdminMongoBackupController.class)
@ContextConfiguration(classes = {
        AdminMongoBackupController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminMongoBackupControllerTest {

    private static final String EXECUTE = "/admin/backup/mongo/execute";
    private static final String RESTORE = "/admin/backup/mongo/restore";

    @Autowired private MockMvc mockMvc;

    @MockBean private MongoBackupService mongoBackupService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private UserRepository userRepo;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpSession sessionOf(String role) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
                new SecurityContextImpl(new UsernamePasswordAuthenticationToken(
                        "someone", null, AuthorityUtils.createAuthorityList(role))));
        return session;
    }

    @Test
    void backupAnswersWithTheSameJsonShapeAsThePostgresOne() throws Exception {
        when(mongoBackupService.backup()).thenReturn(true);

        mockMvc.perform(post(EXECUTE).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @Test
    void aFailedBackupIsSuccessFalseWithAMessageThatHoldsNoRawError() throws Exception {
        when(mongoBackupService.backup()).thenReturn(false);

        mockMvc.perform(post(EXECUTE).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @Test
    void restoreAnswersSuccessAndFailure() throws Exception {
        when(mongoBackupService.restoreLatest()).thenReturn(true, false);

        mockMvc.perform(post(RESTORE).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.success").value(true));
        mockMvc.perform(post(RESTORE).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.success").value(false));

        verify(mongoBackupService, org.mockito.Mockito.times(2)).restoreLatest();
    }

    @Test
    void whileAnotherRunIsBusyBothAnswerSuccessFalseWithTheWaitMessage() throws Exception {
        when(mongoBackupService.backup()).thenThrow(new MongoBackupService.BusyException());
        when(mongoBackupService.restoreLatest()).thenThrow(new MongoBackupService.BusyException());

        for (String url : new String[]{EXECUTE, RESTORE}) {
            mockMvc.perform(post(url).session(sessionOf(Roles.ADMIN)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.success").value(false))
                    .andExpect(jsonPath("$.message").value("Đang sao lưu/khôi phục MongoDB, vui lòng đợi"));
        }
    }

    @Test
    void anOrdinaryUserIsRefusedAndNothingRuns() throws Exception {
        mockMvc.perform(post(EXECUTE).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());
        mockMvc.perform(post(RESTORE).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());

        verifyNoInteractions(mongoBackupService);
    }

    @Test
    void withoutASessionTheCallerIsSentToTheLoginPage() throws Exception {
        mockMvc.perform(post(EXECUTE))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrlPattern("**/admin/login"));

        verifyNoInteractions(mongoBackupService);
    }
}
