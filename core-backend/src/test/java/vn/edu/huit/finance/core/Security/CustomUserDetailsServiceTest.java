package vn.edu.huit.finance.core.Security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

/**
 * An identifier is looked up as an email first, then as a username: a legacy username that equals somebody else's
 * email must not take over that person's tokens. The principal name is always the email (the JWT subject).
 */
@ExtendWith(MockitoExtension.class)
class CustomUserDetailsServiceTest {

    @Mock private UserRepository userRepository;

    private CustomUserDetailsService service;

    @BeforeEach
    void setUp() {
        service = new CustomUserDetailsService();
        ReflectionTestUtils.setField(service, "userRepository", userRepository);
    }

    private static User user(Long id, String username, String email) {
        User user = new User();
        user.setId(id);
        user.setUsername(username);
        user.setEmail(email);
        user.setPassword("hash");
        user.setRole(Roles.USER);
        user.setActive(true);
        return user;
    }

    @Test
    void legacyUsernameEqualToAnotherEmail_resolvesToTheEmailOwner() {
        User attacker = user(1L, "victim@x.com", "attacker@y.com");
        User victim = user(2L, "victim", "victim@x.com");
        when(userRepository.findByEmail("victim@x.com")).thenReturn(Optional.of(victim));
        lenient().when(userRepository.findByUsername("victim@x.com")).thenReturn(Optional.of(attacker));

        assertThat(service.loadApplicationUser("victim@x.com").getId()).isEqualTo(2L);
    }

    @Test
    void plainUsername_stillResolvesByUsername() {
        when(userRepository.findByEmail("an")).thenReturn(Optional.empty());
        when(userRepository.findByUsername("an")).thenReturn(Optional.of(user(3L, "an", "an@x.com")));

        assertThat(service.loadApplicationUser("an").getId()).isEqualTo(3L);
    }

    @Test
    void socialAccountWhoseUsernameIsItsEmail_stillResolves() {
        when(userRepository.findByEmail("s@g.com")).thenReturn(Optional.of(user(4L, "s@g.com", "s@g.com")));

        assertThat(service.loadApplicationUser("s@g.com").getId()).isEqualTo(4L);
    }

    @Test
    void principalNameIsTheEmail() {
        when(userRepository.findByEmail("an")).thenReturn(Optional.empty());
        when(userRepository.findByUsername("an")).thenReturn(Optional.of(user(3L, "an", "an@x.com")));

        assertThat(service.loadUserByUsername("an").getUsername()).isEqualTo("an@x.com");
    }
}
