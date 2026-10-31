package vn.edu.huit.finance.core.Repository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import vn.edu.huit.finance.core.Entity.User;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

/** The one UPDATE of a sign-in on H2: last_login_time and last_action_time of one user, no other column, no other row. */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
class UserRepositoryLoginTimeTest {

    private static final LocalDateTime SIGNED_IN_AT = LocalDateTime.of(2026, 10, 31, 8, 30, 15);
    private static final BigDecimal WALLET = new BigDecimal("75.50");

    @Autowired private UserRepository userRepository;
    @Autowired private TestEntityManager entityManager;

    private Long aliceId;
    private Long bobId;

    @BeforeEach
    void setUp() {
        aliceId = persist("alice", "0900000001").getId();
        bobId = persist("bob", "0900000002").getId();
        entityManager.flush();
        entityManager.clear();
    }

    private User persist(String name, String phone) {
        User user = new User();
        user.setUsername(name);
        user.setEmail(name + "@example.com");
        user.setPhone(phone);
        user.setPassword("$2a$04$oldoldoldoldoldoldoldoldoldoldoldoldoldoldoldoldoldol");
        user.setWalletBalance(WALLET);
        user.setAiLabel("REGULAR");
        return entityManager.persist(user);
    }

    private User reread(Long id) {
        entityManager.clear();
        return userRepository.findById(id).orElseThrow();
    }

    @Test
    void writesBothTimesOfTheUser_andNothingElseOfIt() {
        int updated = userRepository.updateLoginTimes(aliceId, SIGNED_IN_AT);

        assertEquals(1, updated);
        User alice = reread(aliceId);
        assertEquals(SIGNED_IN_AT, alice.getLastLoginTime());
        assertEquals(SIGNED_IN_AT, alice.getLastActionTime());
        assertEquals(0, WALLET.compareTo(alice.getWalletBalance()));
        assertTrue(alice.isActive());
        assertEquals("REGULAR", alice.getAiLabel());
        assertEquals("alice@example.com", alice.getEmail());
    }

    @Test
    void leavesTheOtherUsersAlone() {
        userRepository.updateLoginTimes(aliceId, SIGNED_IN_AT);

        User bob = reread(bobId);
        assertNull(bob.getLastLoginTime());
        assertNull(bob.getLastActionTime());
    }

    @Test
    void changesNothing_andSaysSo_whenTheUserIsGone() {
        assertEquals(0, userRepository.updateLoginTimes(Long.MAX_VALUE, SIGNED_IN_AT));
    }
}
