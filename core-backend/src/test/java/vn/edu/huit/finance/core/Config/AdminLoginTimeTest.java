package vn.edu.huit.finance.core.Config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrf;

/**
 * The sign-in form of the admin pages records the time of the sign-in with one UPDATE of two columns, not with a save of
 * the row it read before the password check (which would write back its wallet, lock and label).
 */
@WebMvcTest
@ContextConfiguration(classes = {GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminLoginTimeTest {

    private static final String LOGIN = "/admin/login";
    private static final String ROOT = "root";
    private static final String PASSWORD = "RootPass123";
    private static final long ROOT_ID = 1L;

    @Autowired private MockMvc mockMvc;
    @Autowired private PasswordEncoder passwordEncoder;

    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @BeforeEach
    void setUp() {
        User root = new User();
        root.setId(ROOT_ID);
        root.setUsername(ROOT);
        root.setEmail("root@example.com");
        root.setRole(Roles.ADMIN);
        when(userDetailsService.loadUserByUsername(ROOT)).thenReturn(new org.springframework.security.core.userdetails.User(
                ROOT, passwordEncoder.encode(PASSWORD), AuthorityUtils.createAuthorityList(Roles.ADMIN)));
        when(userRepository.findByUsername(ROOT)).thenReturn(Optional.of(root));
    }

    private static MockHttpServletRequestBuilder signIn(String password) {
        return post(LOGIN).with(csrf()).servletPath(LOGIN).param("username", ROOT).param("password", password);
    }

    @Test
    void aSuccessfulSignInWritesTheTwoTimesOnly() throws Exception {
        mockMvc.perform(signIn(PASSWORD)).andExpect(redirectedUrl("/admin/dashboard"));

        verify(userRepository).updateLoginTimes(eq(ROOT_ID), any(LocalDateTime.class));
        verify(userRepository, never()).save(any());
    }

    @Test
    void aWrongPasswordWritesNothing() throws Exception {
        mockMvc.perform(signIn("Guess1234")).andExpect(redirectedUrl("/admin/login?error=true"));

        verify(userRepository, never()).updateLoginTimes(any(), any());
        verify(userRepository, never()).save(any());
    }
}
