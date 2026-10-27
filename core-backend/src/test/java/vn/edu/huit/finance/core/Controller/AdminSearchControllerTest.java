package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.support.StaticListableBeanFactory;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.ReindexInProgressException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.Search.TransactionSearchIndexer;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The reindex endpoint through the whole filter chain, and its answer when Elasticsearch is off or down. */
@WebMvcTest(AdminSearchController.class)
@ContextConfiguration(classes = {
        AdminSearchController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminSearchControllerTest {

    private static final String REINDEX = "/api/admin/search/reindex";
    private static final String USER_TOKEN = "user.jwt.token";
    private static final String ADMIN_TOKEN = "admin.jwt.token";

    @Autowired private MockMvc mockMvc;

    @MockBean private TransactionSearchIndexer indexer;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

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
    void anAdministratorRebuildsTheIndex() throws Exception {
        when(indexer.reindexAll()).thenReturn(501);

        mockMvc.perform(asAdmin(post(REINDEX)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Đã dựng lại chỉ mục tìm kiếm từ cơ sở dữ liệu"))
                .andExpect(jsonPath("$.data").value(501));
    }

    @Test
    void elasticsearchDownIsA503() throws Exception {
        when(indexer.reindexAll()).thenThrow(new DataAccessResourceFailureException("connection refused"));

        mockMvc.perform(asAdmin(post(REINDEX)))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value(503))
                .andExpect(jsonPath("$.message").value(AdminSearchController.MSG_REINDEX_FAILED));
    }

    @Test
    void aReindexWhileAnotherRunsIsA409() throws Exception {
        when(indexer.reindexAll()).thenThrow(new ReindexInProgressException());

        mockMvc.perform(asAdmin(post(REINDEX)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value(409))
                .andExpect(jsonPath("$.message").value("Đang dựng lại chỉ mục, vui lòng đợi"));
    }

    @Test
    void anOrdinaryUserIsForbidden() throws Exception {
        mockMvc.perform(post(REINDEX).header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());

        verifyNoInteractions(indexer);
    }

    @Test
    void withThePostgresEngineThereIsNoIndexerAndTheAnswerIsA503() {
        AdminSearchController controller = new AdminSearchController(
                new StaticListableBeanFactory().getBeanProvider(TransactionSearchIndexer.class));

        ResponseEntity<ApiResponse<Integer>> response = controller.reindex();

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, response.getStatusCode());
        assertEquals(503, response.getBody().getCode());
        assertEquals("Tìm kiếm Elasticsearch đang tắt", response.getBody().getMessage());
        assertNull(response.getBody().getData());
    }
}
