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
import vn.edu.huit.finance.core.Dto.MirrorDiffItemDto;
import vn.edu.huit.finance.core.Dto.MirrorStatusResponseDto;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Backup.MongoMirrorDiffService;
import vn.edu.huit.finance.core.Service.Backup.MongoSelectiveMirrorService;
import vn.edu.huit.finance.core.Service.Backup.MongoSelectiveRestoreService;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.util.List;
import java.util.Map;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrfHeader;

@WebMvcTest(AdminMongoMirrorBackupController.class)
@ContextConfiguration(classes = {
        AdminMongoMirrorBackupController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminMongoMirrorBackupControllerTest {

    @Autowired private MockMvc mockMvc;

    @MockBean private MongoSelectiveMirrorService mirrorService;
    @MockBean private MongoMirrorDiffService diffService;
    @MockBean private MongoSelectiveRestoreService restoreService;
    @MockBean private MongoStandbyFailoverService failoverService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private UserRepository userRepo;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpSession sessionOf(String role) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
                new SecurityContextImpl(new UsernamePasswordAuthenticationToken(
                        "admin@huit.edu.vn", null, AuthorityUtils.createAuthorityList(role))));
        return session;
    }

    @Test
    void statusSyncRestoreAndFailoverEndpointsWorkForAdmin() throws Exception {
        MirrorStatusResponseDto statusDto = MirrorStatusResponseDto.builder()
                .postgresUp(true)
                .mongoUp(true)
                .forceFailoverEnabled(false)
                .failoverActive(false)
                .effectiveReadSource("POSTGRESQL")
                .collections(List.of())
                .build();
        when(mirrorService.getMirrorStatus()).thenReturn(statusDto);
        when(mirrorService.syncAllFromPostgresToMongo()).thenReturn(Map.of(
                "users", 2, "categories", 22, "transactions", 15, "budgets", 3, "savingGoals", 2
        ));
        when(restoreService.restoreAllFromMongoToPostgres()).thenReturn(Map.of(
                "users", 2, "categories", 22, "receipts", 5, "transactions", 15, "budgets", 3, "savingGoals", 2
        ));

        mockMvc.perform(get("/admin/backup/mirror/status").session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.postgresUp").value(true))
                .andExpect(jsonPath("$.effectiveReadSource").value("POSTGRESQL"));

        mockMvc.perform(post("/admin/backup/mirror/sync").with(csrfHeader()).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.counts.users").value(2));

        mockMvc.perform(post("/admin/backup/mirror/restore").with(csrfHeader()).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.counts.receipts").value(5));

        mockMvc.perform(post("/admin/backup/mirror/failover").param("enabled", "true")
                        .with(csrfHeader()).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.forceFailoverEnabled").value(true));

        verify(failoverService).setForceFailoverEnabled(true);

        when(diffService.getCollectionDiffs("pg_backup_transactions")).thenReturn(List.of(
                MirrorDiffItemDto.builder()
                        .mongoCollection("pg_backup_transactions")
                        .postgresTable("transactions")
                        .recordId(4782L)
                        .diffType("ONLY_IN_MONGO")
                        .title("Giao dịch #4782")
                        .postgresSummary("Không tồn tại trên PostgreSQL")
                        .mongoSummary("Chi 65000 VNĐ")
                        .build()
        ));

        mockMvc.perform(get("/admin/backup/mirror/diffs").param("collection", "pg_backup_transactions")
                        .session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].recordId").value(4782))
                .andExpect(jsonPath("$[0].diffType").value("ONLY_IN_MONGO"));

        mockMvc.perform(post("/admin/backup/mirror/resolve-diff")
                        .param("collection", "pg_backup_transactions")
                        .param("recordId", "4782")
                        .param("action", "APPLY_MONGO_TO_PG")
                        .with(csrfHeader()).session(sessionOf(Roles.ADMIN)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        verify(restoreService).restoreSingleRecordFromMongoToPostgres("pg_backup_transactions", 4782L);
    }

    @Test
    void ordinaryUserIsRefused() throws Exception {
        mockMvc.perform(post("/admin/backup/mirror/sync").with(csrfHeader()).session(sessionOf(Roles.USER)))
                .andExpect(status().isForbidden());
        verifyNoInteractions(mirrorService);
    }
}
