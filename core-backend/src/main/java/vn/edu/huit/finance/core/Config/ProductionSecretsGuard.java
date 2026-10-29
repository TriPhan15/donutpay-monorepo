package vn.edu.huit.finance.core.Config;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Chặn khởi động profile prod khi thiếu secret. application.yml đặt mọi secret mặc định rỗng, nên một file .env thiếu
 * biến sẽ làm ứng dụng chạy với cấu hình hỏng một cách âm thầm; guard này biến nó thành lỗi khởi động rõ ràng.
 * Chỉ liệt kê TÊN khóa thiếu, không bao giờ in giá trị.
 */
@Slf4j
@Component
@Profile("prod")
@RequiredArgsConstructor
public class ProductionSecretsGuard {

    /** Khóa JWT cũng đọc được từ biến môi trường này (cùng cách JwtUtil đọc). */
    static final String JWT_SECRET_PROPERTY = "app.jwt.secret";
    static final String JWT_SECRET_ENV_FALLBACK = "JWT_SECRET";

    static final List<String> REQUIRED_PROPERTIES = List.of(
            "spring.datasource.password",
            "spring.mail.password",
            "cloudinary.api-key",
            "cloudinary.api-secret",
            "payment.secret",
            JWT_SECRET_PROPERTY);

    /** Khi cổng thanh toán giả lập bật (mặc định bật) thì hai khóa ký này cũng bắt buộc. */
    static final String MOCK_GATEWAY_ENABLED_PROPERTY = "payment.mock-gateway.enabled";
    static final List<String> MOCK_GATEWAY_PROPERTIES = List.of("payment.vnpay.secret", "payment.zalopay.secret");

    private final Environment environment;

    @PostConstruct
    void verify() {
        List<String> missing = new ArrayList<>(REQUIRED_PROPERTIES.stream().filter(this::isBlank).toList());
        if (environment.getProperty(MOCK_GATEWAY_ENABLED_PROPERTY, Boolean.class, true)) {
            // Cổng giả lập ký bằng HMAC: khóa rỗng làm HmacUtil ném "Empty key" nên đơn VNPay/ZaloPay trả 500.
            missing.addAll(MOCK_GATEWAY_PROPERTIES.stream().filter(this::isBlank).toList());
        }
        if (!missing.isEmpty()) {
            log.error("Profile prod thiếu cấu hình bắt buộc: {}", missing);
            throw new IllegalStateException("Profile prod thiếu secret bắt buộc (điền trong .env): " + missing);
        }
    }

    private boolean isBlank(String property) {
        String value = environment.getProperty(property);
        if ((value == null || value.isBlank()) && JWT_SECRET_PROPERTY.equals(property)) {
            value = environment.getProperty(JWT_SECRET_ENV_FALLBACK);
        }
        return value == null || value.isBlank();
    }
}
