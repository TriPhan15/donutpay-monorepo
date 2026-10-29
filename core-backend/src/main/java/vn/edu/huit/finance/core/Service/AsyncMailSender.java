package vn.edu.huit.finance.core.Service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Config.AsyncConfig;

/**
 * Gửi mail ngoài luồng của request (mailAsyncExecutor). Request quên mật khẩu vì thế trả lời ngay, cùng một thời gian
 * dù email có tài khoản hay không, và lỗi SMTP không thành lỗi 500 của request: lỗi chỉ được ghi log.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AsyncMailSender {

    private final JavaMailSender mailSender;

    @Async(AsyncConfig.MAIL_EXECUTOR)
    public void send(SimpleMailMessage message) {
        try {
            mailSender.send(message);
            log.info("Mail sent, subject={}", message.getSubject());
        } catch (MailException e) {
            log.error("Mail could not be sent, subject={}", message.getSubject(), e);
        }
    }
}