package vn.edu.huit.finance.core.Security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

/**
 * An identifier is looked up as an email first, then as a username: a legacy username that equals somebody else's
 * email must not take over that person's tokens. The principal name is always the email (the JWT subject). The authority
 * granted is the stored role in the one spelling Spring Security compares with ("ROLE_&lt;NAME&gt;", see {@link Roles}).
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

    private List<String> authoritiesOfAUserWithRole(String role) {
        User user = user(5L, "an", "an@x.com");
        user.setRole(role);
        when(userRepository.findByEmail("an@x.com")).thenReturn(Optional.of(user));
        UserDetails details = service.loadUserByUsername("an@x.com");
        return details.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList();
    }

    @ParameterizedTest
    @ValueSource(strings = {Roles.USER, Roles.ADMIN})
    void everyRoleASignedInAccountHas_isGrantedAsItIsStored(String storedRole) {
        assertThat(authoritiesOfAUserWithRole(storedRole)).containsExactly(storedRole);
    }

    @Test
    void roleSpelledROLE_ADMIN_isGrantedROLE_ADMIN() {
        assertThat(authoritiesOfAUserWithRole("ROLE_ADMIN")).containsExactly("ROLE_ADMIN");
    }

    @Test
    void roleSpelledAdmin_isGrantedTheSameAuthorityAsROLE_ADMIN() {
        assertThat(authoritiesOfAUserWithRole("admin")).containsExactly("ROLE_ADMIN");
    }

    @Test
    void aLockedAccount_isStillRefusedWhateverItsAuthority() {
        User locked = user(6L, "lk", "lk@x.com");
        locked.setRole(Roles.LOCKED);
        when(userRepository.findByEmail("lk@x.com")).thenReturn(Optional.of(locked));

        assertThatThrownBy(() -> service.loadUserByUsername("lk@x.com")).isInstanceOf(DisabledException.class);
    }

    @Test
    void toUserDetails_ofAUserWithoutPassword_hasAnEmptyPassword() {
        User noPassword = user(7L, "np", "np@x.com");
        noPassword.setPassword(null);

        UserDetails details = CustomUserDetailsService.toUserDetails(noPassword);

        assertThat(details.getPassword()).isEmpty();
        assertThat(details.getUsername()).isEqualTo("np@x.com");
    }
}
