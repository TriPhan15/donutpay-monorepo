package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.SocialLoginRejectedException;
import vn.edu.huit.finance.core.Exception.UserNotFoundException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.AuthPaths;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;
import vn.edu.huit.finance.core.Service.AuthService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.SocialAuthService;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * What sign-up and the two API sign-ins answer, as the client sees it: status, JSON keys and texts, the audit row and the
 * order in which the credentials version is read. The controller and the real AuthService run together (only the
 * database, the password check, the token signer and the social providers are doubles), so the answers stay the same
 * wherever the logic lives: these tests were written before the sign-up check and the sign-in bookkeeping moved from
 * AuthController into AuthService, and must stay green after it.
 */
class AuthControllerBehaviourTest {

    private static final String REGISTER_URL = AuthPaths.BASE + "/register";
    private static final String LOGIN_URL = AuthPaths.BASE + "/login";
    private static final String SOCIAL_LOGIN_URL = AuthPaths.BASE + "/social-login";
    private static final String EMAIL = "alice@example.com";
    private static final String USERNAME = "alice";
    private static final String PASSWORD = "OldPass123";
    private static final String PROVIDER_TOKEN = "google.id.token";
    private static final int CHECKED_VERSION = 3;
    private static final int LATER_VERSION = 4;
    private static final long ALICE_ID = 1L;

    private UserRepository userRepository;
    private AuthenticationManager authenticationManager;
    private LoginAttemptService loginAttemptService;
    private SocialAuthService socialAuthService;
    private JwtUtil jwtUtil;
    private ApplicationEventPublisher controllerEvents;
    private MockMvc mockMvc;
    private User alice;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        authenticationManager = mock(AuthenticationManager.class);
        loginAttemptService = mock(LoginAttemptService.class);
        socialAuthService = mock(SocialAuthService.class);
        jwtUtil = mock(JwtUtil.class);
        controllerEvents = mock(ApplicationEventPublisher.class);

        AuthService authService = new AuthService();
        ReflectionTestUtils.setField(authService, "userRepository", userRepository);
        ReflectionTestUtils.setField(authService, "passwordEncoder", new BCryptPasswordEncoder(4));
        ReflectionTestUtils.setField(authService, "auditLogService", mock(vn.edu.huit.finance.core.Service.AuditLogService.class));
        ReflectionTestUtils.setField(authService, "eventPublisher", mock(ApplicationEventPublisher.class));

        AuthController controller = new AuthController();
        ReflectionTestUtils.setField(controller, "authenticationManager", authenticationManager);
        ReflectionTestUtils.setField(controller, "userRepository", userRepository);
        ReflectionTestUtils.setField(controller, "jwtUtil", jwtUtil);
        ReflectionTestUtils.setField(controller, "loginAttemptService", loginAttemptService);
        ReflectionTestUtils.setField(controller, "authService", authService);
        ReflectionTestUtils.setField(controller, "socialAuthService", socialAuthService);
        ReflectionTestUtils.setField(controller, "eventPublisher", controllerEvents);
        mockMvc = MockMvcBuilders.standaloneSetup(controller).build();

        alice = new User();
        alice.setId(ALICE_ID);
        alice.setUsername(EMAIL);
        alice.setEmail(EMAIL);
        alice.setRole("ROLE_USER");
        alice.setCredentialsVersion(CHECKED_VERSION);
        when(jwtUtil.generateToken(anyString(), any())).thenAnswer(call -> "access-v" + call.getArgument(1));
        when(jwtUtil.generateRefreshToken(anyString(), any())).thenAnswer(call -> "refresh-v" + call.getArgument(1));
    }

    private static MockHttpServletRequestBuilder json(String url, String body) {
        return post(url).servletPath(url).contentType(MediaType.APPLICATION_JSON).content(body);
    }

    private static MockHttpServletRequestBuilder register() {
        return json(REGISTER_URL, "{\"username\":\"" + USERNAME + "\",\"email\":\"" + EMAIL + "\","
                + "\"password\":\"NewPass456\",\"phone\":\"0901234567\"}");
    }

    private static MockHttpServletRequestBuilder login(String password) {
        return json(LOGIN_URL, "{\"email\":\"" + EMAIL + "\",\"password\":\"" + password + "\"}");
    }

    private static MockHttpServletRequestBuilder socialLogin() {
        return json(SOCIAL_LOGIN_URL, "{\"provider\":\"Google\",\"token\":\"" + PROVIDER_TOKEN + "\"}");
    }

    private SecurityAuditEvent theAuditRowOfTheController() {
        org.mockito.ArgumentCaptor<Object> published = org.mockito.ArgumentCaptor.forClass(Object.class);
        verify(controllerEvents).publishEvent(published.capture());
        return (SecurityAuditEvent) published.getValue();
    }

    // --------------------------------------------------------------------------------------------------- sign-up

    @Test
    void register_newAccount_answers200WithCodeAndMessage_andStoresIt() throws Exception {
        when(userRepository.save(any(User.class))).thenAnswer(call -> call.getArgument(0));

        mockMvc.perform(register())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Đăng ký thành công!"));

        verify(userRepository).save(any(User.class));
    }

    @Test
    void register_emailAlreadyTaken_answers400WithItsMessage_andStoresNothing() throws Exception {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));

        mockMvc.perform(register())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value("Email đã được đăng ký. Vui lòng dùng email khác."));

        verify(userRepository, never()).save(any());
    }

    @Test
    void register_usernameAlreadyTaken_answers400WithItsMessage_andStoresNothing() throws Exception {
        when(userRepository.findByUsername(USERNAME)).thenReturn(Optional.of(alice));

        mockMvc.perform(register())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value("Tên đăng nhập đã tồn tại."));

        verify(userRepository, never()).save(any());
    }

    @Test
    void register_emailAndUsernameBothTaken_theEmailIsReported() throws Exception {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));
        when(userRepository.findByUsername(USERNAME)).thenReturn(Optional.of(alice));

        mockMvc.perform(register())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Email đã được đăng ký. Vui lòng dùng email khác."));
    }

    @Test
    void register_aRaceLostToTheUniqueKeys_answers400WithTheKeyMessage() throws Exception {
        when(userRepository.save(any(User.class))).thenThrow(new DataIntegrityViolationException("uk_users_phone"));

        mockMvc.perform(register())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value("Email hoặc số điện thoại đã tồn tại."));
    }

    // ------------------------------------------------------------------------------------------------- password

    @Test
    void login_rightPassword_answers200WithTheTokenPairAndTheUser_andRecordsTheSuccess() throws Exception {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));

        mockMvc.perform(login(PASSWORD))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Đăng nhập thành công"))
                .andExpect(jsonPath("$.data.token").value("access-v" + CHECKED_VERSION))
                .andExpect(jsonPath("$.data.refreshToken").value("refresh-v" + CHECKED_VERSION))
                .andExpect(jsonPath("$.data.user.id").value(ALICE_ID))
                .andExpect(jsonPath("$.data.user.email").value(EMAIL))
                .andExpect(jsonPath("$.data.user.role").value("ROLE_USER"));

        verify(loginAttemptService).recordSuccess(eq(EMAIL), any());
        SecurityAuditEvent row = theAuditRowOfTheController();
        assertEquals(AuditAction.AUTH_LOGIN_SUCCESS, row.entry().action());
        assertEquals(AuditActor.of(alice), row.entry().actor());
        assertEquals(ALICE_ID, row.entry().targetId());
        assertEquals("Đăng nhập App Mobile bằng mật khẩu", row.entry().description());
    }

    @Test
    void login_theCredentialsVersionIsReadBeforeThePasswordIsChecked_andThatVersionIsInTheTokens() throws Exception {
        // The password is changed while the check runs: the account read afterwards already has the next version.
        User afterTheChange = new User();
        afterTheChange.setId(ALICE_ID);
        afterTheChange.setUsername(EMAIL);
        afterTheChange.setEmail(EMAIL);
        afterTheChange.setCredentialsVersion(LATER_VERSION);
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice), Optional.of(afterTheChange));

        mockMvc.perform(login(PASSWORD))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").value("access-v" + CHECKED_VERSION))
                .andExpect(jsonPath("$.data.refreshToken").value("refresh-v" + CHECKED_VERSION));

        InOrder order = inOrder(userRepository, authenticationManager);
        order.verify(userRepository).findByEmail(EMAIL);
        order.verify(authenticationManager).authenticate(any());
    }

    @Test
    void login_wrongPassword_answers401_recordsTheFailure_andWritesNothingToTheAccount() throws Exception {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("bad"));

        mockMvc.perform(login("Guess1234"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Sai email hoặc mật khẩu!"));

        verify(loginAttemptService).recordFailure(eq(EMAIL), any());
        verify(userRepository, never()).save(any());
        verify(jwtUtil, never()).generateToken(anyString(), any());
        assertEquals(AuditAction.AUTH_LOGIN_FAILED, theAuditRowOfTheController().entry().action());
    }

    @Test
    void login_lockedAccount_answers401LikeAWrongPassword_andIssuesNoToken() throws Exception {
        // The account is deactivated (active = false): the authentication manager refuses it with DisabledException.
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));
        when(authenticationManager.authenticate(any())).thenThrow(new DisabledException("disabled"));

        mockMvc.perform(login(PASSWORD))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Sai email hoặc mật khẩu!"));

        verify(userRepository, never()).save(any());
        verify(jwtUtil, never()).generateToken(anyString(), any());
    }

    @Test
    void login_tooManyAttempts_answers429_andDoesNotCheckThePassword() throws Exception {
        doThrow(new LockedException("locked")).when(loginAttemptService).assertLoginAllowed(any(), any());

        mockMvc.perform(login(PASSWORD))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.message")
                        .value("Tài khoản hoặc IP của bạn đang bị tạm khóa 15 phút do nhập sai quá 5 lần!"));

        verifyNoInteractions(authenticationManager);
        verify(userRepository, never()).save(any());
        assertEquals(AuditAction.AUTH_LOGIN_LOCKED, theAuditRowOfTheController().entry().action());
    }

    @Test
    void login_theAccountVanishedBetweenTheReads_isRefusedAsUserNotFound_andNoTokenIsIssued() {
        // No account: the version read finds nothing, the password check passes (a double), the second read finds nothing.
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.empty());

        jakarta.servlet.ServletException thrown = org.junit.jupiter.api.Assertions.assertThrows(
                jakarta.servlet.ServletException.class, () -> mockMvc.perform(login(PASSWORD)));
        org.junit.jupiter.api.Assertions.assertInstanceOf(UserNotFoundException.class, thrown.getCause());
        verify(jwtUtil, never()).generateToken(anyString(), any());
    }

    @Test
    void login_writesTheTwoSignInTimesOnly_neverTheWholeRowOfTheUserItRead() throws Exception {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));

        mockMvc.perform(login(PASSWORD)).andExpect(status().isOk());

        verify(userRepository).updateLoginTimes(eq(ALICE_ID), any(LocalDateTime.class));
        verify(userRepository, never()).save(any());
    }

    // ------------------------------------------------------------------------------------------------- social

    @Test
    void socialLogin_verifiedAccount_answers200WithTheTokenPairAndTheUser_andRecordsTheProvider() throws Exception {
        when(socialAuthService.authenticate("Google", PROVIDER_TOKEN)).thenReturn(alice);

        mockMvc.perform(socialLogin())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Đăng nhập thành công"))
                .andExpect(jsonPath("$.data.token").value("access-v" + CHECKED_VERSION))
                .andExpect(jsonPath("$.data.refreshToken").value("refresh-v" + CHECKED_VERSION))
                .andExpect(jsonPath("$.data.user.id").value(ALICE_ID))
                .andExpect(jsonPath("$.data.user.email").value(EMAIL))
                .andExpect(jsonPath("$.data.user.role").value("ROLE_USER"));

        SecurityAuditEvent row = theAuditRowOfTheController();
        assertEquals(AuditAction.AUTH_LOGIN_SUCCESS, row.entry().action());
        assertEquals(AuditActor.of(alice), row.entry().actor());
        assertEquals("Đăng nhập App Mobile qua google", row.entry().description());
    }

    @Test
    void socialLogin_writesTheTwoSignInTimesOnly_neverTheWholeRowOfTheUser() throws Exception {
        when(socialAuthService.authenticate("Google", PROVIDER_TOKEN)).thenReturn(alice);

        mockMvc.perform(socialLogin()).andExpect(status().isOk());

        verify(userRepository).updateLoginTimes(eq(ALICE_ID), any(LocalDateTime.class));
        verify(userRepository, never()).save(any());
    }

    @Test
    void socialLogin_withoutTokenOrProvider_answers400() throws Exception {
        mockMvc.perform(json(SOCIAL_LOGIN_URL, "{\"provider\":\"Google\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Thiếu provider hoặc token"));

        verifyNoInteractions(socialAuthService);
    }

    @Test
    void socialLogin_refusedByTheProviderCheck_answers401WithTheFixedText_andIssuesNoToken() throws Exception {
        when(socialAuthService.authenticate(any(), any())).thenThrow(new SocialLoginRejectedException());

        mockMvc.perform(socialLogin())
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value(SocialLoginRejectedException.MESSAGE));

        verify(jwtUtil, never()).generateToken(anyString(), any());
        verify(userRepository, never()).save(any());
        assertEquals(AuditAction.AUTH_LOGIN_FAILED, theAuditRowOfTheController().entry().action());
    }
}
