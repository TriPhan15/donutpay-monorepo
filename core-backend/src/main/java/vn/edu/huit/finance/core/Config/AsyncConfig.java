package vn.edu.huit.finance.core.Config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.data.mongodb.config.EnableMongoAuditing;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@Configuration
@EnableAsync
@EnableMongoAuditing
@Slf4j
public class AsyncConfig {

    @Bean(name = "mongoAsyncExecutor")
    public Executor threadPoolTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);   // Số lượng thread duy trì cố định
        executor.setMaxPoolSize(20);   // Tối đa khi tải nặng
        executor.setQueueCapacity(500); // Hàng đợi nạp task (quá 500 thì mới spawn thread mới)
        executor.setThreadNamePrefix("MongoAsync-");
        // Hàng đợi đầy (MongoDB chậm/chết lâu): bỏ bản log thô đó và ghi cảnh báo, không ném lỗi về luồng đã commit PostgreSQL.
        executor.setRejectedExecutionHandler((task, pool) ->
                log.warn("MongoAsyncExecutor queue is full, dropping one MongoDB raw-log write"));
        executor.initialize();
        log.info("Initialized MongoAsyncExecutor for background MongoDB tasks.");
        return executor;
    }
}
