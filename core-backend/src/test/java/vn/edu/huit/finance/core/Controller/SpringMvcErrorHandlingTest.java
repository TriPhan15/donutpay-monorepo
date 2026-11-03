package vn.edu.huit.finance.core.Controller;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import io.jsonwebtoken.MalformedJwtException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.BudgetService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.time.LocalDateTime;
import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * A request Spring MVC itself refuses (wrong method, wrong Content-Type, unknown URL, missing header) is the caller's
 * mistake: it gets its own 4xx with the {@code ApiResponse} body, and is not logged as a system error.
 */
@WebMvcTest(BudgetController.class)
@ContextConfiguration(classes = {BudgetController.class, SpringMvcErrorHandlingTest.HeaderProbeController.class,
        GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class SpringMvcErrorHandlingTest {

    private static final String TOKEN = "valid.jwt.token";
    private static final String BAD_TOKEN = "invalid.jwt.token";
    private static final String USERNAME = "alice";
    private static final String BUDGETS = "/api/budgets";
    private static final String BUDGET_BY_ID = "/api/budgets/7";
    private static final String UNKNOWN_URL = "/api/no-such-endpoint";
    private static final String PROBE_URL = "/api/probe/header";
    private static final String PROBE_HEADER = "X-Probe";
    private static final String MOBILE_ORIGIN = "https://app.example.com";
    private static final String PATCH = "PATCH";

    @RestController
    static class HeaderProbeController {
        @GetMapping(PROBE_URL)
        String probe(@RequestHeader(PROBE_HEADER) String value) {
            return value;
        }
    }

    @Autowired private MockMvc mockMvc;

    @MockBean private BudgetService budgetService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private final ListAppender<ILoggingEvent> handlerLog = new ListAppender<>();
    private Logger handlerLogger;

    @BeforeEach
    void stubJwtForAliceAndWatchTheHandlerLog() {
        when(jwtUtil.parse(TOKEN, TokenType.ACCESS)).thenReturn(new TokenClaims(USERNAME, 0));
        when(jwtUtil.parse(BAD_TOKEN, TokenType.ACCESS)).thenThrow(new MalformedJwtException("not a valid token"));

        User alice = new User();
        alice.setUsername(USERNAME);
        alice.setActive(true);
        alice.setRole("ROLE_USER");
        alice.setLastActionTime(LocalDateTime.now());
        when(userDetailsService.loadApplicationUser(USERNAME)).thenReturn(alice);
        when(userDetailsService.loadUserByUsername(USERNAME)).thenReturn(
                new org.springframework.security.core.userdetails.User(
                        USERNAME, "hash", AuthorityUtils.createAuthorityList("ROLE_USER")));

        handlerLogger = (Logger) LoggerFactory.getLogger(GlobalExceptionHandler.class);
        handlerLog.start();
        handlerLogger.addAppender(handlerLog);
    }

    @AfterEach
    void stopWatchingTheHandlerLog() {
        handlerLogger.detachAppender(handlerLog);
        handlerLog.stop();
    }

    private static MockHttpServletRequestBuilder signedIn(MockHttpServletRequestBuilder builder) {
        return builder.header(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN);
    }

    private void assertNothingLoggedAsError() {
        List<ILoggingEvent> errors = handlerLog.list.stream().filter(event -> event.getLevel().isGreaterOrEqual(Level.ERROR)).toList();
        assertTrue(errors.isEmpty(), "a caller's mistake must not be logged as an error: " + errors);
    }

    @Test
    void aMethodTheUrlDoesNotSupportIsAnswered405_withTheAllowedMethods() throws Exception {
        mockMvc.perform(signedIn(request(HttpMethod.PATCH, BUDGET_BY_ID)).contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(header().string(HttpHeaders.ALLOW, containsString("GET")))
                .andExpect(jsonPath("$.code").value(405))
                .andExpect(jsonPath("$.message").value("Phương thức PATCH không được hỗ trợ cho địa chỉ này"))
                .andExpect(content().string(not(containsString("HttpRequestMethodNotSupportedException"))));

        verifyNoInteractions(budgetService);
        assertNothingLoggedAsError();
    }

    @Test
    void aFormBodySentToAJsonEndpointIsAnswered415() throws Exception {
        mockMvc.perform(signedIn(post(BUDGETS)).contentType(MediaType.APPLICATION_FORM_URLENCODED).content("amount=1"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.code").value(415))
                .andExpect(jsonPath("$.message").value("Định dạng dữ liệu gửi lên không được hỗ trợ"));

        verifyNoInteractions(budgetService);
        assertNothingLoggedAsError();
    }

    @Test
    void anUnknownUrlIsAnswered404() throws Exception {
        mockMvc.perform(signedIn(get(UNKNOWN_URL)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404))
                .andExpect(jsonPath("$.message").value("Không tìm thấy địa chỉ yêu cầu"));

        assertNothingLoggedAsError();
    }

    @Test
    void aMissingRequiredHeaderIsAnswered400_namingTheHeader() throws Exception {
        mockMvc.perform(signedIn(get(PROBE_URL)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value("Thiếu header bắt buộc: " + PROBE_HEADER));

        assertNothingLoggedAsError();
    }

    @Test
    void theRequiredHeaderPresent_theProbeStillWorks() throws Exception {
        mockMvc.perform(signedIn(get(PROBE_URL)).header(PROBE_HEADER, "ok"))
                .andExpect(status().isOk());
    }

    @Test
    void anUnknownUrlOutsideTheApiIsAnswered404_withAnErrorPageNotJson() throws Exception {
        // Not under /api/: the page of the error view, but still with the right code.
        mockMvc.perform(signedIn(get("/no-such-page")))
                .andExpect(status().isNotFound());
    }

    @Test
    void aCorsPreflightForPatchIsAllowed() throws Exception {
        mockMvc.perform(options(BUDGET_BY_ID)
                        .header(HttpHeaders.ORIGIN, MOBILE_ORIGIN)
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, PATCH))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, containsString(PATCH)));
    }
}
