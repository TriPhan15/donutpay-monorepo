package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import vn.edu.huit.finance.core.Config.AsyncConfig;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;

/** A8: the OTP mail leaves the request (its own pool), and an SMTP failure never reaches the caller. */
@ExtendWith(MockitoExtension.class)
class AsyncMailSenderTest {

    @Mock private JavaMailSender javaMailSender;
    @InjectMocks private AsyncMailSender sender;

    private static SimpleMailMessage message() {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo("alice@example.com");
        message.setSubject("Mã OTP");
        message.setText("123456");
        return message;
    }

    @Test
    void theMailIsSent() {
        SimpleMailMessage message = message();

        sender.send(message);

        verify(javaMailSender).send(message);
    }

    @Test
    void anSmtpFailureIsOnlyLogged() {
        doThrow(new MailSendException("Connection refused: smtp.gmail.com:587")).when(javaMailSender).send(message());

        assertDoesNotThrow(() -> sender.send(message()));
    }

    @Test
    void sendRunsOnTheMailPool() throws NoSuchMethodException {
        Async async = AsyncMailSender.class.getMethod("send", SimpleMailMessage.class).getAnnotation(Async.class);

        assertEquals(AsyncConfig.MAIL_EXECUTOR, async.value());
    }
}