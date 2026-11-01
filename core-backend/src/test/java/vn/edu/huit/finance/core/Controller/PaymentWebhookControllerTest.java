package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.PaymentWebhookRejectedException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.PaymentService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import static org.hamcrest.Matchers.startsWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** POST /api/payment/webhook (no sign-in) through the real filter chain: a malformed body is a 400, never a 500 (A14). */
@WebMvcTest(PaymentController.class)
@ContextConfiguration(classes = {PaymentController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class PaymentWebhookControllerTest {

    private static final String URL = "/api/payment/webhook";
    private static final String VALID = "{\"orderCode\":\"PAY1\",\"gatewayTxnId\":\"TXN1\",\"resultCode\":\"00\","
            + "\"amount\":50000,\"signature\":\"abc\"}";

    @Autowired private MockMvc mockMvc;

    @MockBean private PaymentService paymentService;
    @MockBean private UserRepository userRepository;
    @MockBean private CurrentUserProvider currentUserProvider;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @ParameterizedTest
    @ValueSource(strings = {"{}", "{\"orderCode\":\"PAY1\",\"gatewayTxnId\":\"TXN1\",\"resultCode\":\"00\",\"signature\":\"abc\"}",
            "{\"orderCode\":\"PAY1\",\"gatewayTxnId\":\"TXN1\",\"resultCode\":\"00\",\"amount\":50000}"})
    void anIncompleteWebhookIsA400AndNeverReachesTheService(String body) throws Exception {
        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.message").value(startsWith("Dữ liệu không hợp lệ")));

        verifyNoInteractions(paymentService);
    }

    @Test
    void anOrderCodeLongerThanItsColumnIsA400() throws Exception {
        String body = VALID.replace("\"PAY1\"", "\"" + "P".repeat(65) + "\"");

        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(paymentService);
    }

    @Test
    void aCompleteWebhookReachesTheService() throws Exception {
        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isOk());

        verify(paymentService).handleWebhook(any());
    }

    @Test
    void aBadSignatureIsA400() throws Exception {
        doThrow(new PaymentWebhookRejectedException("Sai chữ ký webhook (HMAC không khớp)"))
                .when(paymentService).handleWebhook(any());

        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Sai chữ ký webhook (HMAC không khớp)"));
    }
}
