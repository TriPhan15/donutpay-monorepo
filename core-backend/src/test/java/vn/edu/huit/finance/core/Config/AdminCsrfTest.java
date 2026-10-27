package vn.edu.huit.finance.core.Config;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.util.Optional;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrf;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrfHeader;

/**
 * The admin pages sign in with a session, so a form on another site could make an administrator's browser post to
 * /admin/** (backup restore, user delete...). The admin filter chain therefore requires a CSRF token on every state
 * changing request, while the stateless JWT chain of /api/** stays free of it.
 */
@WebMvcTest
@ContextConfiguration(classes = {
        AdminCsrfTest.CsrfProbeController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminCsrfTest {

    private static final String PROBE = "/admin/test-csrf";
    private static final String LOGIN = "/admin/login";
    private static final String ADMIN_NAME = "admin";
    private static final String ADMIN_PASSWORD = "AdminPass123";

    /** Stub that only exists so that a POST under /admin/** has a handler to reach. */
    @RestController
    static class CsrfProbeController {
        @PostMapping(PROBE)
        String probe() {
            return "ok";
        }
    }

    @Autowired private MockMvc mockMvc;
    @Autowired private PasswordEncoder passwordEncoder;

    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @BeforeEach
    void setUp() {
        User admin = new User();
        admin.setId(1L);
        admin.setUsername(ADMIN_NAME);
        admin.setEmail("admin@example.com");
        admin.setRole(Roles.ADMIN);
        when(userDetailsService.loadUserByUsername(ADMIN_NAME)).thenReturn(new org.springframework.security.core.userdetails.User(
                ADMIN_NAME, passwordEncoder.encode(ADMIN_PASSWORD), AuthorityUtils.createAuthorityList(Roles.ADMIN)));
        when(userRepository.findByUsername(ADMIN_NAME)).thenReturn(Optional.of(admin));
    }

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    /** The session the form login leaves behind for an administrator. */
    private static MockHttpSession adminSession() {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY, new SecurityContextImpl(
                new UsernamePasswordAuthenticationToken(ADMIN_NAME, null, AuthorityUtils.createAuthorityList(Roles.ADMIN))));
        return session;
    }

    @Test
    void adminPostWithoutCsrf_is403() throws Exception {
        mockMvc.perform(post(PROBE).servletPath(PROBE).session(adminSession()))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminPostWithCsrf_isOk() throws Exception {
        mockMvc.perform(post(PROBE).servletPath(PROBE).session(adminSession()).with(csrf()))
                .andExpect(status().isOk());
    }

    @Test
    void adminPostWithCsrfInTheHeader_isOk() throws Exception {
        mockMvc.perform(post(PROBE).servletPath(PROBE).session(adminSession()).with(csrfHeader()))
                .andExpect(status().isOk());
    }

    @Test
    void apiPostWithoutCsrf_isNotBlockedByCsrf() throws Exception {
        mockMvc.perform(post("/api/anything").servletPath("/api/anything"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminFormLoginWithoutCsrf_is403() throws Exception {
        mockMvc.perform(post(LOGIN).servletPath(LOGIN).param("username", ADMIN_NAME).param("password", ADMIN_PASSWORD))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminFormLogin_withUsernameAndCsrfToken_redirectsToDashboard() throws Exception {
        mockMvc.perform(post(LOGIN).servletPath(LOGIN).with(csrf())
                        .param("username", ADMIN_NAME).param("password", ADMIN_PASSWORD))
                .andExpect(redirectedUrl("/admin/dashboard"));
    }
}
