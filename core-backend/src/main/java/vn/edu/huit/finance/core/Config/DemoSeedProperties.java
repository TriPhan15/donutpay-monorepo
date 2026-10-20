package vn.edu.huit.finance.core.Config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;
import vn.edu.huit.finance.core.Security.StrongPassword;

/**
 * Cấu hình seed dữ liệu demo (tiền tố {@code app.seed}), chỉ được nạp khi {@code app.seed.demo=true}. Biến môi trường:
 * APP_SEED_DEMO, APP_SEED_ADMIN_PASSWORD, APP_SEED_DEMO_PASSWORD (docker-compose lấy từ SEED_DEMO, SEED_ADMIN_PASSWORD,
 * SEED_DEMO_PASSWORD trong .env). Mật khẩu không bao giờ nằm trong code; thiếu hoặc yếu thì app dừng ngay lúc khởi động
 * với thông báo của @StrongPassword, thay vì tạo tài khoản không đăng nhập được.
 *
 * @param demo          bật seed; production thật để false
 * @param adminPassword mật khẩu tài khoản admin
 * @param demoPassword  mật khẩu chung của hai tài khoản demo
 */
@Validated
@ConfigurationProperties(prefix = "app.seed")
public record DemoSeedProperties(boolean demo, @StrongPassword String adminPassword, @StrongPassword String demoPassword) {

    public static final String ENABLED_PROPERTY = "app.seed.demo";
}
