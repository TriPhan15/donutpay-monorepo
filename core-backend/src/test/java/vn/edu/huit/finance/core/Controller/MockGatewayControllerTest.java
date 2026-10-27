package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpEntity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.HtmlUtils;
import vn.edu.huit.finance.core.Service.Payment.PaymentGateway;
import vn.edu.huit.finance.core.Service.Payment.PaymentGatewayRegistry;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * /mock-gateway/** nằm ngoài cả hai filter chain trong SecurityConfig nên slice này tắt filter bảo mật.
 * RestTemplate được mock qua RestTemplateBuilder để kiểm tra webhook có được gọi hay không.
 */
@WebMvcTest(controllers = MockGatewayController.class,
        properties = {"payment.secret=test-secret", "payment.webhook-url=http://localhost/api/payment/webhook"})
@AutoConfigureMockMvc(addFilters = false)
@ContextConfiguration(classes = {MockGatewayController.class, MockGatewayControllerTest.HttpClientConfig.class})
class MockGatewayControllerTest {

    private static final String FIXED_ERROR = "Yêu cầu thanh toán không hợp lệ";
    private static final String SIGN = "sig+/=";
    private static final String PROVIDER = "MOCK";
    private static final String AMOUNT = "50000";
    private static final String ORDER = "ORD123";
    private static final Pattern HREF = Pattern.compile("href='([^']+)'");

    @TestConfiguration
    static class HttpClientConfig {
        @Bean
        RestTemplate restTemplate() {
            return mock(RestTemplate.class);
        }

        @Bean
        RestTemplateBuilder restTemplateBuilder(RestTemplate restTemplate) {
            RestTemplateBuilder builder = mock(RestTemplateBuilder.class);
            when(builder.build()).thenReturn(restTemplate);
            return builder;
        }
    }

    @Autowired private MockMvc mockMvc;
    @Autowired private RestTemplate restTemplate;
    @MockBean private PaymentGatewayRegistry gateways;

    private PaymentGateway gateway;

    @BeforeEach
    void setUp() {
        reset(restTemplate);
        gateway = mock(PaymentGateway.class);
    }

    private void acceptSignatureFor(String orderCode) {
        when(gateway.verifyRequestSignature(orderCode, AMOUNT, SIGN)).thenReturn(true);
        when(gateways.get(PROVIDER)).thenReturn(gateway);
    }

    private static String body(ResultActions r) throws Exception {
        return r.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    @Test
    void unknownProvider_errorPageDoesNotEchoInput() throws Exception {
        String evil = "<script>alert(1)</script>";
        when(gateways.get(evil)).thenThrow(new IllegalArgumentException("Unknown provider " + evil));

        ResultActions res = mockMvc.perform(get("/mock-gateway/pay")
                        .param("orderCode", ORDER).param("amount", AMOUNT).param("provider", evil).param("sign", SIGN))
                .andExpect(status().isBadRequest());

        String html = body(res);
        assertFalse(html.contains("<script>"), html);
        assertTrue(html.contains(FIXED_ERROR), html);
    }

    @Test
    void payPage_escapesOrderCodeAndProvider() throws Exception {
        String evilOrder = "<b>x</b>";
        acceptSignatureFor(evilOrder);

        ResultActions res = mockMvc.perform(get("/mock-gateway/pay")
                        .param("orderCode", evilOrder).param("amount", AMOUNT).param("provider", PROVIDER).param("sign", SIGN))
                .andExpect(status().isOk());

        String html = body(res);
        assertTrue(html.contains("&lt;b&gt;"), html);
        assertFalse(html.contains("<b>x</b>"), html);
    }

    @Test
    void confirmWithoutValidSign_doesNotCallWebhook() throws Exception {
        when(gateways.get(PROVIDER)).thenReturn(gateway);

        mockMvc.perform(get("/mock-gateway/confirm")
                        .param("orderCode", ORDER).param("amount", AMOUNT).param("provider", PROVIDER)
                        .param("sign", "forged").param("result", "success"))
                .andExpect(status().isBadRequest());

        verify(restTemplate, never()).postForEntity(anyString(), any(HttpEntity.class), eq(String.class));
    }

    @Test
    void payPageLinks_carryAValidSignature_confirmCallsWebhook() throws Exception {
        acceptSignatureFor(ORDER);

        String html = body(mockMvc.perform(get("/mock-gateway/pay")
                        .param("orderCode", ORDER).param("amount", AMOUNT).param("provider", PROVIDER).param("sign", SIGN))
                .andExpect(status().isOk()));
        Matcher m = HREF.matcher(html);
        assertTrue(m.find(), html);
        String successHref = HtmlUtils.htmlUnescape(m.group(1));

        mockMvc.perform(get(URI.create(successHref))).andExpect(status().isOk());

        verify(restTemplate, times(1)).postForEntity(anyString(), any(HttpEntity.class), eq(String.class));
    }

    @Test
    void webhookFailure_pageShowsFixedText() throws Exception {
        acceptSignatureFor(ORDER);
        when(restTemplate.postForEntity(anyString(), any(HttpEntity.class), eq(String.class)))
                .thenThrow(new RestClientException("secret-host:8080"));

        ResultActions res = mockMvc.perform(get("/mock-gateway/confirm")
                .param("orderCode", ORDER).param("amount", AMOUNT).param("provider", PROVIDER)
                .param("sign", SIGN).param("result", "success"));

        res.andExpect(status().isBadGateway());
        assertFalse(body(res).contains("secret-host"));
        assertTrue(body(res).contains("Không gọi được webhook, vui lòng thử lại sau"));
    }
}
