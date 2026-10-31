package vn.edu.huit.finance.core.Config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.data.mongodb.config.EnableMongoAuditing;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@Configuration
@PropertySource("classpath:ocr-analytics.properties")
@EnableAsync
@EnableMongoAuditing
@Slf4j
public class AsyncConfig {

    /** Pool của AsyncMailSender: mail OTP gửi ngoài request. */
    public static final String MAIL_EXECUTOR = "mailAsyncExecutor";
    private static final int MAIL_POOL_SIZE = 2;
    private static final int MAIL_QUEUE_CAPACITY = 100;

    @Bean(name = MAIL_EXECUTOR)
    public Executor mailAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(MAIL_POOL_SIZE);
        executor.setMaxPoolSize(MAIL_POOL_SIZE);
        executor.setQueueCapacity(MAIL_QUEUE_CAPACITY);
        executor.setThreadNamePrefix("MailAsync-");
        // Hàng đợi đầy: bỏ mail đó và ghi lỗi; request đã trả lời, người dùng có thể xin mã lại.
        executor.setRejectedExecutionHandler((task, pool) -> log.error("MailAsyncExecutor queue is full, dropping one mail"));
        executor.initialize();
        return executor;
    }

    @Bean(name = "mongoAsyncExecutor")
    public Executor threadPoolTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);   // Số lượng thread duy trì cố định
        executor.setMaxPoolSize(20);   // Tối đa khi tải nặng
        executor.setQueueCapacity(500); // Hàng đợi nạp task (quá 500 thì mới spawn thread mới)
        executor.setThreadNamePrefix("MongoAsync-");
        // Hàng đợi đầy (MongoDB/Redis/Elasticsearch chậm hoặc chết lâu): bỏ tác vụ ghi đó và ghi cảnh báo, không ném lỗi về
        // luồng đã commit PostgreSQL. Pool này chạy mọi tác vụ NoSQL sau commit (log OCR, bảng xếp hạng, chỉ mục tìm kiếm).
        executor.setRejectedExecutionHandler((task, pool) ->
                log.warn("MongoAsyncExecutor queue is full, dropping one NoSQL after-commit write"));
        executor.initialize();
        log.info("Initialized MongoAsyncExecutor for background MongoDB tasks.");
        return executor;
    }
}
