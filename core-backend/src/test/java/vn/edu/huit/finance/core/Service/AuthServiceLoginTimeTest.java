package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtUtil;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

/**
 * A sign-in writes the time of the sign-in and of the latest action, and nothing else. The user it is given was read
 * before the password check (and BCrypt takes its time): while it waited, another request may have changed the wallet,
 * locked the account or labelled the customer, and the sign-in must not put the old values back. Nothing runs inside a
 * test transaction, so every call commits on H2 like a request does.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
@Transactional(propagation = Propagation.NOT_SUPPORTED)
@Import({AuthService.class, AuthServiceLoginTimeTest.Config.class})
class AuthServiceLoginTimeTest {

    private static final BigDecimal WALLET_AT_SIGN_IN_START = new BigDecimal("100.00");
    private static final BigDecimal WALLET_AFTER_ANOTHER_REQUEST = new BigDecimal("250.00");
    private static final String LABEL_SET_MEANWHILE = "VIP";
    private static final Duration CLOCK_TOLERANCE = Duration.ofSeconds(30);

    @TestConfiguration
    static class Config {
        @Bean
        PasswordEncoder passwordEncoder() {
            return new BCryptPasswordEncoder(4);
        }
    }

    @Autowired private AuthService authService;
    @Autowired private UserRepository userRepository;

    // Not used by markLoggedIn; AuthService needs them to be built.
    @MockBean private AsyncMailSender mailSender;
    @MockBean private CurrentUserProvider currentUserProvider;
    @MockBean private AuditLogService auditLogService;
    @MockBean private TokenBlacklistService tokenBlacklistService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private PasswordResetOtpStore otpStore;

    private Long aliceId;

    @BeforeEach
    void setUp() {
        User alice = new User();
        alice.setUsername("alice");
        alice.setEmail("alice@example.com");
        alice.setPhone("0900000001");
        alice.setPassword("$2a$04$oldoldoldoldoldoldoldoldoldoldoldoldoldoldoldoldoldol");
        alice.setWalletBalance(WALLET_AT_SIGN_IN_START);
        aliceId = userRepository.saveAndFlush(alice).getId();
    }

    @AfterEach
    void cleanUp() {
        userRepository.deleteAll();
    }

    private User reread() {
        return userRepository.findById(aliceId).orElseThrow();
    }

    private static void assertJustNow(LocalDateTime time, String what) {
        assertNotNull(time, what);
        assertTrue(Duration.between(time, LocalDateTime.now()).abs().compareTo(CLOCK_TOLERANCE) < 0, what + ": " + time);
    }

    @Test
    void theTimeOfTheSignInAndOfTheLatestActionAreWritten() {
        authService.markLoggedIn(reread());

        User alice = reread();
        assertJustNow(alice.getLastLoginTime(), "last login");
        assertJustNow(alice.getLastActionTime(), "last action");
        assertEquals(alice.getLastLoginTime(), alice.getLastActionTime(), "one moment for both");
    }

    @Test
    void aCopyReadBeforeAnotherRequestChangedTheWalletTheAccountAndTheLabel_doesNotPutTheOldValuesBack() {
        User readBeforeThePasswordCheck = reread();

        // Another request commits meanwhile: a top-up, an admin locking the account, the nightly customer labelling.
        User changedMeanwhile = reread();
        changedMeanwhile.setWalletBalance(WALLET_AFTER_ANOTHER_REQUEST);
        changedMeanwhile.setActive(false);
        changedMeanwhile.setAiLabel(LABEL_SET_MEANWHILE);
        userRepository.saveAndFlush(changedMeanwhile);

        authService.markLoggedIn(readBeforeThePasswordCheck);

        User alice = reread();
        assertEquals(0, WALLET_AFTER_ANOTHER_REQUEST.compareTo(alice.getWalletBalance()), "wallet keeps the newer value");
        assertFalse(alice.isActive(), "the lock keeps");
        assertEquals(LABEL_SET_MEANWHILE, alice.getAiLabel(), "the label keeps");
        assertJustNow(alice.getLastLoginTime(), "last login");
    }

    @Test
    void anAccountDeletedMeanwhileIsNotBroughtBack() {
        User readBeforeThePasswordCheck = reread();
        userRepository.deleteAll();

        authService.markLoggedIn(readBeforeThePasswordCheck);

        assertTrue(userRepository.findById(aliceId).isEmpty());
    }
}
