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
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Entity.PaymentOrder;
import vn.edu.huit.finance.core.Entity.PaymentStatus;
import vn.edu.huit.finance.core.Entity.PaymentType;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.PaymentOrderRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.AuditLogService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.Payment.PaymentGateway;
import vn.edu.huit.finance.core.Service.Payment.PaymentGatewayRegistry;
import vn.edu.huit.finance.core.Service.PaymentService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;
import vn.edu.huit.finance.core.Service.TransactionService;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Characterization of /api/payment/{create,status,mine,cancel} through the real security filter chain, the real
 * controller and the real PaymentService (only its repositories and collaborators are mocks): the JSON keys, the HTTP
 * codes and the owner id the service works with. The same test must stay green when the controller or the shape of the
 * service result changes.
 */
@WebMvcTest(PaymentController.class)
@ContextConfiguration(classes = {PaymentController.class, PaymentService.class, CurrentUserProvider.class,
        GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
@TestPropertySource(properties = "payment.secret=controller_test_secret")
class PaymentControllerTest {

    private static final String BASE = "/api/payment";
    private static final String TOKEN = "valid.jwt.token";
    private static final String BAD_TOKEN = "invalid.jwt.token";
    private static final String EMAIL = "alice@example.com";
    private static final long USER_ID = 42L;
    private static final long OTHER_USER_ID = 43L;
    private static final String ORDER_CODE = "PAY1700000000000ABC123";
    private static final String PAY_URL = "http://pay.example/checkout";
    private static final String CREATE_BODY = "{\"type\":\"DEPOSIT\",\"amount\":50000,\"provider\":\"MOCK\",\"description\":\"Nap\"}";
    private static final LocalDateTime CREATED_AT = LocalDateTime.of(2026, 10, 31, 9, 30, 15);

    @Autowired private MockMvc mockMvc;

    @MockBean private PaymentOrderRepository orderRepo;
    @MockBean private PaymentGatewayRegistry gateways;
    @MockBean private TransactionService transactionService;
    @MockBean private AuditLogService auditLogService;
    @MockBean private UserRepository userRepository;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private User alice;

    @BeforeEach
    void signInAlice() {
        when(jwtUtil.parse(TOKEN, TokenType.ACCESS)).thenReturn(new TokenClaims(EMAIL, 0));
        when(jwtUtil.parse(BAD_TOKEN, TokenType.ACCESS)).thenThrow(new MalformedJwtException("not a valid token"));

        alice = new User();
        alice.setId(USER_ID);
        alice.setEmail(EMAIL);
        alice.setUsername("alice");
        alice.setActive(true);
        alice.setRole("ROLE_USER");
        alice.setWalletBalance(new BigDecimal("1000000"));
        alice.setLastActionTime(LocalDateTime.now());
        // Both ways of finding the caller: the controller used to read the repository, CurrentUserProvider reads this.
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(alice));
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(alice));
        when(userDetailsService.loadApplicationUser(EMAIL)).thenReturn(alice);
        when(userDetailsService.loadUserByUsername(EMAIL)).thenReturn(
                new org.springframework.security.core.userdetails.User(
                        EMAIL, "hash", AuthorityUtils.createAuthorityList("ROLE_USER")));
    }

    private static MockHttpServletRequestBuilder signedIn(MockHttpServletRequestBuilder builder) {
        return builder.header(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN);
    }

    private static MockHttpServletRequestBuilder json(HttpMethod method, String path, String body) {
        return request(method, path).contentType(MediaType.APPLICATION_JSON).content(body);
    }

    private static PaymentOrder order(long ownerId, PaymentStatus status) {
        PaymentOrder order = PaymentOrder.builder()
                .orderCode(ORDER_CODE).userId(ownerId).amount(new BigDecimal("50000.00"))
                .type(PaymentType.DEPOSIT).status(status).provider("MOCK").description("Nap")
                .gatewayTxnId("TXN9").signature("sig").build();
        order.setCreatedAt(CREATED_AT);
        return order;
    }

    // ---- authentication ----

    static Stream<Arguments> everySignedInEndpoint() {
        return Stream.of(
                Arguments.of(HttpMethod.POST, BASE + "/create"),
                Arguments.of(HttpMethod.GET, BASE + "/status/" + ORDER_CODE),
                Arguments.of(HttpMethod.GET, BASE + "/mine"),
                Arguments.of(HttpMethod.PUT, BASE + "/cancel/" + ORDER_CODE));
    }

    @ParameterizedTest
    @MethodSource("everySignedInEndpoint")
    void withoutATokenIsA401_andNothingIsRead(HttpMethod method, String path) throws Exception {
        mockMvc.perform(json(method, path, CREATE_BODY))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(orderRepo);
    }

    @ParameterizedTest
    @MethodSource("everySignedInEndpoint")
    void anInvalidTokenIsA401_andNothingIsRead(HttpMethod method, String path) throws Exception {
        mockMvc.perform(json(method, path, CREATE_BODY).header(HttpHeaders.AUTHORIZATION, "Bearer " + BAD_TOKEN))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(orderRepo);
    }

    // ---- create ----

    @Test
    void create_answers200WithTheOrderKeys_andSavesTheOrderForTheCaller() throws Exception {
        PaymentGateway gateway = org.mockito.Mockito.mock(PaymentGateway.class);
        when(gateways.get("MOCK")).thenReturn(gateway);
        when(gateway.buildPaymentUrl(any())).thenReturn(PAY_URL);

        mockMvc.perform(signedIn(json(HttpMethod.POST, BASE + "/create", CREATE_BODY)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Tao don thanh cong"))
                .andExpect(jsonPath("$.data.orderCode").isString())
                .andExpect(jsonPath("$.data.amount").value(50000))
                .andExpect(jsonPath("$.data.type").value("DEPOSIT"))
                .andExpect(jsonPath("$.data.status").value("PENDING"))
                .andExpect(jsonPath("$.data.provider").value("MOCK"))
                .andExpect(jsonPath("$.data.payUrl").value(PAY_URL))
                .andExpect(jsonPath("$.data.length()").value(6));

        org.mockito.ArgumentCaptor<PaymentOrder> saved = org.mockito.ArgumentCaptor.forClass(PaymentOrder.class);
        verify(orderRepo).save(saved.capture());
        org.junit.jupiter.api.Assertions.assertEquals(USER_ID, saved.getValue().getUserId());
    }

    @Test
    void create_withAnUnknownTypeIsA400() throws Exception {
        mockMvc.perform(signedIn(json(HttpMethod.POST, BASE + "/create",
                        "{\"type\":\"GIFT\",\"amount\":50000}")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));

        verifyNoInteractions(orderRepo);
    }

    @Test
    void create_withAnAmountBelowTheMinimumIsA400() throws Exception {
        mockMvc.perform(signedIn(json(HttpMethod.POST, BASE + "/create",
                        "{\"type\":\"DEPOSIT\",\"amount\":10}")))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(orderRepo);
    }

    @Test
    void create_aWithdrawalAboveTheBalanceIsA400() throws Exception {
        alice.setWalletBalance(new BigDecimal("1000"));
        when(gateways.get("MOCK")).thenReturn(org.mockito.Mockito.mock(PaymentGateway.class));

        mockMvc.perform(signedIn(json(HttpMethod.POST, BASE + "/create",
                        "{\"type\":\"WITHDRAW\",\"amount\":50000}")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Số dư ví không đủ để rút"));

        verifyNoInteractions(orderRepo);
    }

    // ---- status ----

    @Test
    void status_answers200WithEveryOrderKey_forTheOwner() throws Exception {
        when(orderRepo.findByOrderCode(ORDER_CODE)).thenReturn(Optional.of(order(USER_ID, PaymentStatus.SUCCESS)));

        mockMvc.perform(signedIn(request(HttpMethod.GET, BASE + "/status/" + ORDER_CODE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("OK"))
                .andExpect(jsonPath("$.data.orderCode").value(ORDER_CODE))
                .andExpect(jsonPath("$.data.amount").value(50000.00))
                .andExpect(jsonPath("$.data.type").value("DEPOSIT"))
                .andExpect(jsonPath("$.data.status").value("SUCCESS"))
                .andExpect(jsonPath("$.data.provider").value("MOCK"))
                .andExpect(jsonPath("$.data.description").value("Nap"))
                .andExpect(jsonPath("$.data.gatewayTxnId").value("TXN9"))
                .andExpect(jsonPath("$.data.createdAt").value("2026-10-31T09:30:15"))
                .andExpect(jsonPath("$.data.length()").value(8));
    }

    @Test
    void status_keepsTheNullKeys_whenTheOrderHasNoDescriptionOrGatewayTxn() throws Exception {
        PaymentOrder pending = order(USER_ID, PaymentStatus.PENDING);
        pending.setDescription(null);
        pending.setGatewayTxnId(null);
        pending.setCreatedAt(null);
        when(orderRepo.findByOrderCode(ORDER_CODE)).thenReturn(Optional.of(pending));

        mockMvc.perform(signedIn(request(HttpMethod.GET, BASE + "/status/" + ORDER_CODE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.description").value(nullValue()))
                .andExpect(jsonPath("$.data.gatewayTxnId").value(nullValue()))
                .andExpect(jsonPath("$.data.createdAt").value(nullValue()))
                .andExpect(jsonPath("$.data.length()").value(8));
    }

    @Test
    void status_ofSomebodyElsesOrderIsA403() throws Exception {
        when(orderRepo.findByOrderCode(ORDER_CODE)).thenReturn(Optional.of(order(OTHER_USER_ID, PaymentStatus.PENDING)));

        mockMvc.perform(signedIn(request(HttpMethod.GET, BASE + "/status/" + ORDER_CODE)))
                .andExpect(status().isForbidden());
    }

    @Test
    void status_ofAnUnknownOrderIsA404() throws Exception {
        when(orderRepo.findByOrderCode(ORDER_CODE)).thenReturn(Optional.empty());

        mockMvc.perform(signedIn(request(HttpMethod.GET, BASE + "/status/" + ORDER_CODE)))
                .andExpect(status().isNotFound());
    }

    // ---- mine ----

    @Test
    void mine_listsTheOrdersOfTheCaller() throws Exception {
        when(orderRepo.findByUserIdOrderByCreatedAtDesc(USER_ID))
                .thenReturn(List.of(order(USER_ID, PaymentStatus.SUCCESS), order(USER_ID, PaymentStatus.PENDING)));

        mockMvc.perform(signedIn(request(HttpMethod.GET, BASE + "/mine")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("OK"))
                .andExpect(jsonPath("$.data", hasSize(2)))
                .andExpect(jsonPath("$.data[0].orderCode").value(ORDER_CODE))
                .andExpect(jsonPath("$.data[0].status").value("SUCCESS"))
                .andExpect(jsonPath("$.data[1].status").value("PENDING"))
                .andExpect(jsonPath("$.data[0].length()").value(8));

        verify(orderRepo).findByUserIdOrderByCreatedAtDesc(USER_ID);
    }

    // ---- cancel ----

    @Test
    void cancel_closesAPendingOrderOfTheCaller() throws Exception {
        when(orderRepo.findLockedByOrderCode(ORDER_CODE)).thenReturn(Optional.of(order(USER_ID, PaymentStatus.PENDING)));

        mockMvc.perform(signedIn(request(HttpMethod.PUT, BASE + "/cancel/" + ORDER_CODE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Da huy don"))
                .andExpect(jsonPath("$.data.orderCode").value(ORDER_CODE))
                .andExpect(jsonPath("$.data.status").value("CANCELLED"))
                .andExpect(jsonPath("$.data.length()").value(8));
    }

    @Test
    void cancel_returnsAnOrderThatIsNotPendingAsItIs() throws Exception {
        when(orderRepo.findLockedByOrderCode(ORDER_CODE)).thenReturn(Optional.of(order(USER_ID, PaymentStatus.SUCCESS)));

        mockMvc.perform(signedIn(request(HttpMethod.PUT, BASE + "/cancel/" + ORDER_CODE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUCCESS"));
    }

    @Test
    void cancel_ofSomebodyElsesOrderIsA403() throws Exception {
        when(orderRepo.findLockedByOrderCode(ORDER_CODE)).thenReturn(Optional.of(order(OTHER_USER_ID, PaymentStatus.PENDING)));

        mockMvc.perform(signedIn(request(HttpMethod.PUT, BASE + "/cancel/" + ORDER_CODE)))
                .andExpect(status().isForbidden());
    }
}
