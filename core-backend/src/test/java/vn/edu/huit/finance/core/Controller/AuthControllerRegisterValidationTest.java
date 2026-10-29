package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.AuthPaths;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Service.AuthService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.SocialAuthService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** POST /api/auth/register refuses a username with "@" unless it is the account's own email. */
@WebMvcTest(AuthController.class)
@ContextConfiguration(classes = {
        AuthController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AuthControllerRegisterValidationTest {

    private static final String REGISTER_URL = AuthPaths.BASE + "/register";

    @Autowired private MockMvc mockMvc;

    @MockBean private AuthService authService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private SocialAuthService socialAuthService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private MockHttpServletRequestBuilder register(String username, String email) {
        String body = "{\"username\":\"" + username + "\",\"email\":\"" + email + "\",\"password\":\"NewPass456\","
                + "\"phone\":\"0901234567\"}";
        return post(REGISTER_URL).servletPath(REGISTER_URL).contentType(MediaType.APPLICATION_JSON).content(body);
    }

    @Test
    void usernameEqualToAnotherEmail_isRefusedWith400_andNothingIsSaved() throws Exception {
        mockMvc.perform(register("victim@x.com", "attacker@y.com"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("@")));

        verify(authService, never()).register(any());
    }

    @Test
    void usernameDifferingFromEmailOnlyByCase_isRefusedWith400() throws Exception {
        mockMvc.perform(register("Victim@x.com", "victim@x.com"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("@")));

        verify(authService, never()).register(any());
    }

    @Test
    void usernameEqualToOwnEmail_isAccepted() throws Exception {
        // What the mobile app sends: username == email.
        mockMvc.perform(register("newbie@x.com", "newbie@x.com"))
                .andExpect(status().isOk());

        verify(authService).register(any());
    }
}
