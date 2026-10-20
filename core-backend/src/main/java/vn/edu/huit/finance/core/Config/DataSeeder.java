package vn.edu.huit.finance.core.Config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Service.DemoData.DemoDataWriter;
import vn.edu.huit.finance.core.Service.DemoData.DemoSeedResult;

/**
 * Seed dữ liệu demo lúc khởi động, chỉ khi {@code app.seed.demo=true} (env SEED_DEMO trong docker-compose). PostgreSQL
 * trước, trong một transaction (DemoDataWriter: database đã có người dùng thì bỏ qua, không bao giờ xóa), sau khi commit
 * mới tới log OCR trên MongoDB, khớp với các hóa đơn vừa seed.
 */
@Slf4j
@Component
@ConditionalOnProperty(name = DemoSeedProperties.ENABLED_PROPERTY, havingValue = "true")
@EnableConfigurationProperties(DemoSeedProperties.class)
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {

    private final DemoSeedProperties properties;
    private final DemoDataWriter demoDataWriter;
    private final MongoDataSeeder mongoDataSeeder;

    @Override
    public void run(String... args) {
        log.info("Demo seed enabled ({}=true)", DemoSeedProperties.ENABLED_PROPERTY);
        DemoSeedResult result = demoDataWriter.seedIfEmpty(properties.adminPassword(), properties.demoPassword());
        mongoDataSeeder.seed(result.receipts());
    }
}
