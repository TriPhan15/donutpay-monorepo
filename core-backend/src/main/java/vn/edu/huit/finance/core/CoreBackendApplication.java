package vn.edu.huit.finance.core;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.TimeZone;
@Slf4j
@EnableScheduling
@EnableJpaAuditing
@SpringBootApplication
public class CoreBackendApplication {
	@PostConstruct
	public void init() {
		TimeZone.setDefault(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
		log.info("Đã cấu hình múi giờ hệ thống: {}", TimeZone.getDefault().getID());
	}
	public static void main(String[] args) {
		SpringApplication.run(CoreBackendApplication.class, args);
	}

}
