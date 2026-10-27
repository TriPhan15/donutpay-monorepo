package vn.edu.huit.finance.core.Controller;

import io.jsonwebtoken.MalformedJwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.InsufficientBalanceException;
import vn.edu.huit.finance.core.Exception.SavingsLedgerException;
import vn.edu.huit.finance.core.Exception.TransactionAccessDeniedException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.SavingGoalService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.NoSuchElementException;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Stream;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.startsWith;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * POST /api/savings/{id}/contributions through the real security filter chain, JwtAuthFilter and GlobalExceptionHandler.
 * Explicit context classes keep the app class (@EnableJpaAuditing) out of the slice.
 */
@WebMvcTest(SavingGoalController.class)
@ContextConfiguration(classes = {
        SavingGoalController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class SavingGoalControllerTest {

    private static final String URL = "/api/savings/6/contributions";
    private static final String TOKEN = "valid.jwt.token";
    private static final String BAD_TOKEN = "invalid.jwt.token";
    private static final String USERNAME = "alice";
    private static final String VALID_BODY = "{\"amount\":500000}";

    @Autowired private MockMvc mockMvc;

    @MockBean private SavingGoalService savingGoalService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @BeforeEach
    void stubJwtForAlice() {
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
    }

    private static MockHttpServletRequestBuilder contribution(String body) {
        return post(URL).contentType(MediaType.APPLICATION_JSON).content(body);
    }

    private static MockHttpServletRequestBuilder signedIn(MockHttpServletRequestBuilder builder) {
        return builder.header(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN);
    }

    private static SavingGoalDto goalAfterTheContribution() {
        return SavingGoalDto.builder().id(6L).title("Mua xe").target(new BigDecimal("50000000"))
                .current(new BigDecimal("1500000")).deadline("2027-06-30").build();
    }

    @Test
    void aContributionAnswers200WithTheGoalAsItIsNow_andRunsForTheJwtUserWhateverTheBodySays() throws Exception {
        AtomicReference<String> callerSeenByService = new AtomicReference<>();
        when(savingGoalService.contributeToMySaving(eq(6L), any())).thenAnswer(invocation -> {
            callerSeenByService.set(SecurityContextHolder.getContext().getAuthentication().getName());
            return goalAfterTheContribution();
        });

        mockMvc.perform(signedIn(contribution("{\"amount\":500000,\"userId\":999}")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Góp tiền vào mục tiêu thành công"))
                .andExpect(jsonPath("$.data.id").value(6))
                .andExpect(jsonPath("$.data.title").value("Mua xe"))
                .andExpect(jsonPath("$.data.target").value(50000000))
                .andExpect(jsonPath("$.data.current").value(1500000))
                .andExpect(jsonPath("$.data.deadline").value("2027-06-30"));

        assertEquals(USERNAME, callerSeenByService.get());
        verify(savingGoalService).contributeToMySaving(6L, new BigDecimal("500000"));
    }

    @Test
    void aContributionWithoutAUsableTokenNeverReachesTheService() throws Exception {
        mockMvc.perform(contribution(VALID_BODY)).andExpect(status().is4xxClientError());
        mockMvc.perform(contribution(VALID_BODY).header(HttpHeaders.AUTHORIZATION, "Bearer " + BAD_TOKEN))
                .andExpect(status().is4xxClientError());

        verifyNoInteractions(savingGoalService);
    }

    static Stream<Arguments> invalidBodies() {
        return Stream.of(
                Arguments.of("no amount", "{}", "Số tiền góp không được để trống"),
                Arguments.of("a null amount", "{\"amount\":null}", "Số tiền góp không được để trống"),
                Arguments.of("a zero amount", "{\"amount\":0}", "Số tiền góp phải lớn hơn 0"),
                Arguments.of("a negative amount", "{\"amount\":-5000}", "Số tiền góp phải lớn hơn 0"),
                Arguments.of("three decimals", "{\"amount\":100.125}", "chữ số thập phân"));
    }

    @ParameterizedTest(name = "rejects {0}")
    @MethodSource("invalidBodies")
    void anInvalidAmountIsA400WithTheReason_andSkipsTheService(String description, String body, String message)
            throws Exception {
        mockMvc.perform(signedIn(contribution(body)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value(startsWith("Dữ liệu không hợp lệ")))
                .andExpect(jsonPath("$.message").value(containsString(message)));

        verifyNoInteractions(savingGoalService);
    }

    @Test
    void aWalletThatCannotCarryTheContributionIsA400WithTheCheckoutsMessage() throws Exception {
        when(savingGoalService.contributeToMySaving(anyLong(), any()))
                .thenThrow(new InsufficientBalanceException("GIAO DỊCH THẤT BẠI: Số dư ví không đủ!"));

        mockMvc.perform(signedIn(contribution(VALID_BODY)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value("GIAO DỊCH THẤT BẠI: Số dư ví không đủ!"));
    }

    @Test
    void aGoalOfSomebodyElseIsA403() throws Exception {
        when(savingGoalService.contributeToMySaving(anyLong(), any()))
                .thenThrow(new TransactionAccessDeniedException("Bạn không có quyền thao tác trên mục tiêu tiết kiệm này"));

        mockMvc.perform(signedIn(contribution(VALID_BODY)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value(403))
                .andExpect(jsonPath("$.message").value("Bạn không có quyền thao tác trên mục tiêu tiết kiệm này"));
    }

    @Test
    void aGoalThatDoesNotExistIsA400LikeTheOtherSavingsEndpoints() throws Exception {
        when(savingGoalService.contributeToMySaving(anyLong(), any()))
                .thenThrow(new NoSuchElementException("Không tìm thấy mục tiêu tiết kiệm"));

        mockMvc.perform(signedIn(contribution(VALID_BODY)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value("Không tìm thấy mục tiêu tiết kiệm"));
    }

    // ------------------------------------------------------------------------------------ create and update a goal

    private static final String GOALS_URL = "/api/savings";
    private static final String GOAL_URL = "/api/savings/7";

    @Test
    void oldAppPutWithOnlyCurrent_isRefused400_andNothingChanges() throws Exception {
        mockMvc.perform(signedIn(put(GOAL_URL).contentType(MediaType.APPLICATION_JSON).content("{\"current\":5000000}")))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(savingGoalService);
    }

    @Test
    void createWithBlankTitleOrNonPositiveTarget_is400() throws Exception {
        mockMvc.perform(signedIn(post(GOALS_URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\" \",\"target\":0}")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Tên mục tiêu không được để trống")))
                .andExpect(jsonPath("$.message").value(containsString("Số tiền mục tiêu phải lớn hơn 0")));

        verifyNoInteractions(savingGoalService);
    }

    @Test
    void aMalformedDeadlineOrNegativeCurrentIs400() throws Exception {
        mockMvc.perform(signedIn(post(GOALS_URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Xe\",\"target\":100,\"deadline\":\"2027-06-30\",\"current\":-1}")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("dd/MM/yyyy")))
                .andExpect(jsonPath("$.message").value(containsString("không được âm")));

        verifyNoInteractions(savingGoalService);
    }

    @Test
    void aValidUpdateAnswers200WithTheGoal() throws Exception {
        when(savingGoalService.updateMySaving(eq(7L), any())).thenReturn(goalAfterTheContribution());

        mockMvc.perform(signedIn(put(GOAL_URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Mua xe\",\"target\":50000000,\"deadline\":\"30/06/2027\"}")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Cập nhật thành công"))
                .andExpect(jsonPath("$.data.current").value(1500000));
    }

    @Test
    void anUpdateThatChangesTheSavedAmountIsA409() throws Exception {
        when(savingGoalService.updateMySaving(anyLong(), any()))
                .thenThrow(new SavingsLedgerException("Số tiền đã tiết kiệm chỉ thay đổi qua Góp tiền"));

        mockMvc.perform(signedIn(put(GOAL_URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Mua xe\",\"target\":100,\"current\":9}")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("Số tiền đã tiết kiệm chỉ thay đổi qua Góp tiền"));
    }
}
