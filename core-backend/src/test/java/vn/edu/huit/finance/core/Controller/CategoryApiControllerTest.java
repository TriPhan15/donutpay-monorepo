package vn.edu.huit.finance.core.Controller;

import io.jsonwebtoken.MalformedJwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Dto.CategoryResponseDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.CategoryService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /api/categories behind the real filter chain: it is no longer public (the categories a user named are theirs, B8),
 * so a request without a usable token is a 401 and never reaches the service; a signed-in caller gets a plain JSON array
 * (the shape the app parses) of what the service lists for the user the JWT names.
 */
@WebMvcTest(CategoryApiController.class)
@ContextConfiguration(classes = {
        CategoryApiController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class CategoryApiControllerTest {

    private static final String URL = "/api/categories";
    private static final String TOKEN = "valid.jwt.token";
    private static final String BAD_TOKEN = "invalid.jwt.token";
    private static final String USERNAME = "alice";

    @Autowired private MockMvc mockMvc;

    @MockBean private CategoryService categoryService;
    @MockBean private CurrentUserProvider currentUserProvider;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private User alice;

    @BeforeEach
    void stubJwtForAlice() {
        when(jwtUtil.parse(TOKEN, TokenType.ACCESS)).thenReturn(new TokenClaims(USERNAME, 0));
        when(jwtUtil.parse(BAD_TOKEN, TokenType.ACCESS)).thenThrow(new MalformedJwtException("not a valid token"));

        alice = new User();
        alice.setId(7L);
        alice.setUsername(USERNAME);
        alice.setEmail(USERNAME);
        alice.setActive(true);
        alice.setRole("ROLE_USER");
        alice.setLastActionTime(LocalDateTime.now());
        when(userDetailsService.loadApplicationUser(USERNAME)).thenReturn(alice);
        when(currentUserProvider.getCurrentUser()).thenReturn(alice);
    }

    @Test
    void withoutAToken_is401_andNeverReachesTheService() throws Exception {
        mockMvc.perform(get(URL))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));

        verifyNoInteractions(categoryService);
    }

    @Test
    void withAnInvalidToken_is401_andNeverReachesTheService() throws Exception {
        mockMvc.perform(get(URL).header(HttpHeaders.AUTHORIZATION, "Bearer " + BAD_TOKEN))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(categoryService);
    }

    @Test
    void aSignedInCaller_getsTheServicesListForThemselves_asAPlainJsonArray() throws Exception {
        when(categoryService.listFor(any(User.class))).thenReturn(List.of(
                CategoryResponseDto.builder().id(1L).name("Ăn uống").type("EXPENSE").build(),
                CategoryResponseDto.builder().id(9L).name("Cafe sáng").type("EXPENSE").build()));

        mockMvc.perform(get(URL + "?userId=999").header(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].name").value("Ăn uống"))
                .andExpect(jsonPath("$[0].type").value("EXPENSE"))
                .andExpect(jsonPath("$[1].name").value("Cafe sáng"));

        ArgumentCaptor<User> caller = ArgumentCaptor.forClass(User.class);
        verify(categoryService).listFor(caller.capture());
        assertSame(alice, caller.getValue(), "the caller comes from the session, not from the query string");
    }
}
