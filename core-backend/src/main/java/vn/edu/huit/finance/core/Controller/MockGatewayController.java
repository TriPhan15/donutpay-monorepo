package vn.edu.huit.finance.core.Controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.HtmlUtils;
import org.springframework.web.util.UriComponentsBuilder;
import vn.edu.huit.finance.core.Dto.PaymentWebhookDto;
import vn.edu.huit.finance.core.Service.Payment.PaymentGatewayRegistry;
import vn.edu.huit.finance.core.Util.HmacUtil;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * Cổng thanh toán giả lập (trang demo). Mọi giá trị đưa vào HTML đều được escape, lỗi chỉ trả câu cố định,
 * và /confirm chỉ ký webhook khi chữ ký của trang pay còn hợp lệ. Tắt bằng payment.mock-gateway.enabled=false.
 */
@Slf4j
@RestController
@RequestMapping("/mock-gateway")
@ConditionalOnProperty(name = "payment.mock-gateway.enabled", havingValue = "true", matchIfMissing = true)
public class MockGatewayController {

    private static final String HTML_UTF8 = "text/html;charset=UTF-8";
    private static final String CONFIRM_PATH = "/mock-gateway/confirm";
    private static final String RESULT_SUCCESS = "success";
    private static final String RESULT_FAIL = "fail";
    private static final String CODE_SUCCESS = "00";
    private static final String CODE_FAIL = "99";
    private static final String TXN_ID_PREFIX = "MOCK";
    private static final int TXN_ID_SUFFIX_LENGTH = 10;
    private static final String MSG_INVALID_REQUEST = "Yêu cầu thanh toán không hợp lệ";
    private static final String MSG_WEBHOOK_FAILED = "Không gọi được webhook, vui lòng thử lại sau";

    @Value("${payment.secret}")
    private String secret;

    @Value("${payment.webhook-url}")
    private String webhookUrl;

    private final PaymentGatewayRegistry gateways;
    private final RestTemplate http;

    public MockGatewayController(PaymentGatewayRegistry gateways, RestTemplateBuilder restTemplateBuilder) {
        this.gateways = gateways;
        this.http = restTemplateBuilder.build();
    }

    @GetMapping(value = "/pay", produces = HTML_UTF8)
    public ResponseEntity<String> payPage(@RequestParam String orderCode,
                                          @RequestParam String amount,
                                          @RequestParam(defaultValue = "MOCK") String provider,
                                          @RequestParam String sign) {
        if (!isSignatureValid(orderCode, amount, provider, sign)) {
            return errorPage(HttpStatus.BAD_REQUEST, MSG_INVALID_REQUEST);
        }
        String successLink = confirmLink(orderCode, amount, provider, sign, RESULT_SUCCESS);
        String failLink = confirmLink(orderCode, amount, provider, sign, RESULT_FAIL);
        String html = "<html><head><meta charset='utf-8'><title>Mock Gateway</title></head>"
                + "<body style='font-family:sans-serif;text-align:center;padding-top:60px'>"
                + "<h2>Cổng thanh toán GIẢ LẬP - " + esc(provider) + "</h2>"
                + "<p>Mã đơn: <b>" + esc(orderCode) + "</b></p>"
                + "<p>Số tiền: <b>" + esc(amount) + " đ</b></p>"
                + "<a href='" + esc(successLink) + "'"
                + " style='display:inline-block;margin:10px;padding:14px 28px;background:#2e7d32;color:#fff;text-decoration:none;border-radius:8px'>Thanh toán THÀNH CÔNG</a>"
                + "<a href='" + esc(failLink) + "'"
                + " style='display:inline-block;margin:10px;padding:14px 28px;background:#c62828;color:#fff;text-decoration:none;border-radius:8px'>Thanh toán THẤT BẠI</a>"
                + "</body></html>";
        return ResponseEntity.ok(html);
    }

    @GetMapping(value = "/confirm", produces = HTML_UTF8)
    public ResponseEntity<String> confirm(@RequestParam String orderCode,
                                          @RequestParam String amount,
                                          @RequestParam(defaultValue = "MOCK") String provider,
                                          @RequestParam String sign,
                                          @RequestParam String result) {
        if (!isSignatureValid(orderCode, amount, provider, sign)) {
            return errorPage(HttpStatus.BAD_REQUEST, MSG_INVALID_REQUEST);
        }
        BigDecimal parsedAmount;
        try {
            parsedAmount = new BigDecimal(amount);
        } catch (NumberFormatException e) {
            log.warn("Mock gateway confirm: số tiền không hợp lệ cho đơn {}", orderCode, e);
            return errorPage(HttpStatus.BAD_REQUEST, MSG_INVALID_REQUEST);
        }

        String resultCode = RESULT_SUCCESS.equalsIgnoreCase(result) ? CODE_SUCCESS : CODE_FAIL;
        String gatewayTxnId = TXN_ID_PREFIX
                + UUID.randomUUID().toString().substring(0, TXN_ID_SUFFIX_LENGTH).toUpperCase();

        PaymentWebhookDto dto = new PaymentWebhookDto();
        dto.setOrderCode(orderCode);
        dto.setGatewayTxnId(gatewayTxnId);
        dto.setResultCode(resultCode);
        dto.setAmount(parsedAmount);

        String raw = orderCode + "|" + gatewayTxnId + "|" + resultCode + "|" + dto.getAmount().toPlainString();
        dto.setSignature(HmacUtil.hmacSha256(raw, secret));

        try {
            HttpHeaders h = new HttpHeaders();
            h.setContentType(MediaType.APPLICATION_JSON);
            http.postForEntity(webhookUrl, new HttpEntity<>(dto, h), String.class);
        } catch (Exception e) {
            log.error("Mock gateway: gọi webhook lỗi cho đơn {}", orderCode, e);
            return errorPage(HttpStatus.BAD_GATEWAY, MSG_WEBHOOK_FAILED);
        }

        boolean success = CODE_SUCCESS.equals(resultCode);
        String color = success ? "#2e7d32" : "#c62828";
        String text = success ? "THÀNH CÔNG" : "THẤT BẠI";
        String html = "<html><head><meta charset='utf-8'></head>"
                + "<body style='font-family:sans-serif;text-align:center;padding-top:80px'>"
                + "<h1 style='color:" + color + "'>Thanh toán " + text + "</h1>"
                + "<p>Mã giao dịch: " + esc(gatewayTxnId) + "</p>"
                + "<p>Quay lại ứng dụng để xem kết quả.</p>"
                + "</body></html>";
        return ResponseEntity.ok(html);
    }

    /** Provider lạ hoặc chữ ký sai đều coi là không hợp lệ; chi tiết chỉ ghi log, không trả về client. */
    private boolean isSignatureValid(String orderCode, String amount, String provider, String sign) {
        try {
            return gateways.get(provider).verifyRequestSignature(orderCode, amount, sign);
        } catch (Exception e) {
            log.warn("Mock gateway: không kiểm được chữ ký cho đơn {}", orderCode, e);
            return false;
        }
    }

    private String confirmLink(String orderCode, String amount, String provider, String sign, String result) {
        return UriComponentsBuilder.fromPath(CONFIRM_PATH)
                .queryParam("orderCode", "{orderCode}")
                .queryParam("amount", "{amount}")
                .queryParam("provider", "{provider}")
                .queryParam("sign", "{sign}")
                .queryParam("result", "{result}")
                .encode()
                .buildAndExpand(orderCode, amount, provider, sign, result)
                .toUriString();
    }

    private ResponseEntity<String> errorPage(HttpStatus status, String message) {
        return ResponseEntity.status(status)
                .body("<h2 style='color:red'>" + esc(message) + "</h2>");
    }

    private static String esc(String value) {
        // Pages are served as UTF-8: escape only the HTML specials and keep Vietnamese letters readable.
        return HtmlUtils.htmlEscape(value, StandardCharsets.UTF_8.name());
    }
}
