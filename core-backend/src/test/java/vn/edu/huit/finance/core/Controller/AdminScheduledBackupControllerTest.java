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
import vn.edu.huit.finance.core.Dto.ScheduledBackupStatusDto;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Backup.MongoRestoreOutcome;
import vn.edu.huit.finance.core.Service.Backup.ScheduledBackupService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.time.LocalDateTime;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrlPattern;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrfHeader;

/** The status of the daily backup and the destructive "restore from the MongoDB copy" button: administrators only. */
@WebMvcTest(AdminScheduledBackupController.class)
@ContextConfiguration(classes = {
        AdminScheduledBackupController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminScheduledBackupControllerTest {

    private static final String STATUS = "/admin/backup/scheduled/status";
    private static final String RESTORE = "/admin/backup/scheduled/restore-from-mongo";

    @Autowired private MockMvc mockMvc;

    @MockBean private ScheduledBackupService scheduledBackupService;
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
    void anAdministratorSeesTheLastRunItsSizeAndWhereItIsKept() throws Exception {
        when(scheduledBackupService.latestStatus()).thenReturn(new ScheduledBackupStatusDto(true, "0 0 2 * * *",
                "Asia/Ho_Chi_Minh", true, LocalDateTime.of(2026, 11, 1, 2, 0), true, null,
                "FULL_backup_auto_20261101_020000.sql", 2048L, "abc123", true, true));

        mockMvc.perform(get(STATUS).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(true))
                .andExpect(jsonPath("$.hasRun").value(true))
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.sizeBytes").value(2048))
                .andExpect(jsonPath("$.onDisk").value(true))
                .andExpect(jsonPath("$.inMongo").value(true))
                .andExpect(jsonPath("$.lastRunAt").exists());
    }

    @Test
    void anOrdinaryUserCannotSeeTheStatusOrRestore() throws Exception {
        mockMvc.perform(get(STATUS).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());
        mockMvc.perform(post(RESTORE).with(csrfHeader()).session(sessionOf(Roles.USER))).andExpect(status().isForbidden());

        verifyNoInteractions(scheduledBackupService);
    }

    @Test
    void withoutASessionTheCallerIsSentToTheLoginPage() throws Exception {
        mockMvc.perform(post(RESTORE).with(csrfHeader()))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrlPattern("**/admin/login"));

        verifyNoInteractions(scheduledBackupService);
    }

    @Test
    void theRestoreNeedsTheCsrfTokenLikeEveryOtherAdminPost() throws Exception {
        mockMvc.perform(post(RESTORE).session(sessionOf(Roles.ADMIN))).andExpect(status().isForbidden());

        verifyNoInteractions(scheduledBackupService);
    }

    @Test
    void aRestoreThatSucceededAnswersSuccessTrue() throws Exception {
        when(scheduledBackupService.restoreFromMongo()).thenReturn(MongoRestoreOutcome.RESTORED);

        mockMvc.perform(post(RESTORE).with(csrfHeader()).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").isNotEmpty());

        verify(scheduledBackupService).restoreFromMongo();
    }

    @Test
    void everyOtherOutcomeAnswersSuccessFalseWithItsOwnMessage() throws Exception {
        for (MongoRestoreOutcome outcome : MongoRestoreOutcome.values()) {
            if (outcome == MongoRestoreOutcome.RESTORED) continue;
            when(scheduledBackupService.restoreFromMongo()).thenReturn(outcome);

            mockMvc.perform(post(RESTORE).with(csrfHeader()).session(sessionOf(Roles.ADMIN)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.success").value(false))
                    .andExpect(jsonPath("$.message").isNotEmpty());
        }
    }
}
