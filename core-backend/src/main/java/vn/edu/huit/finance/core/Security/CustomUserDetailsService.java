package vn.edu.huit.finance.core.Security;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyFailoverService;
import vn.edu.huit.finance.core.Service.Backup.MongoStandbyReadService;

import java.util.Collections;
import java.util.Objects;

@Service
@RequiredArgsConstructor(onConstructor_ = @Autowired)
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;
    private final ObjectProvider<MongoStandbyFailoverService> failoverServiceProvider;
    private final ObjectProvider<MongoStandbyReadService> standbyReadServiceProvider;

    public CustomUserDetailsService() {
        this(null, null, null);
    }

    @Override
    public UserDetails loadUserByUsername(String usernameOrEmail) throws UsernameNotFoundException {
        User user = loadApplicationUser(usernameOrEmail);

        if (isLocked(user)) {
            throw new DisabledException("Account is locked");
        }

        return toUserDetails(user);
    }

    /**
     * The principal of an account that is already loaded. Static on purpose, like {@link #isLocked}: the JWT filter builds
     * it from the user it has loaded, without a second lookup, also where this service is mocked.
     */
    public static UserDetails toUserDetails(User user) {
        return new org.springframework.security.core.userdetails.User(
                // Email, not username: it is unique and the JWT subject, so Authentication.getName() is always the email.
                user.getEmail(),
                Objects.requireNonNullElse(user.getPassword(), ""),
                user.isActive(),
                true,
                true,
                !Roles.LOCKED.equals(user.getRole()),
                Collections.singletonList(new SimpleGrantedAuthority(Roles.normalize(user.getRole())))
        );
    }

    /**
     * True for an account that must not use the API any more: deactivated, or given the locked role. Static on purpose:
     * the sign-in, the JWT filter and the token refresh all apply this one rule, also where this service is mocked.
     */
    public static boolean isLocked(User user) {
        return !user.isActive() || Roles.LOCKED.equals(user.getRole());
    }

    public User loadApplicationUser(String usernameOrEmail) throws UsernameNotFoundException {
        MongoStandbyFailoverService failover = failoverService();
        MongoStandbyReadService standby = standbyReadService();
        if (failover != null && standby != null) {
            return failover.executeReadWithFallback(
                    () -> loadFromPostgres(usernameOrEmail),
                    () -> standby.findUserByUsernameOrEmail(usernameOrEmail)
                            .orElseThrow(() -> new UsernameNotFoundException("User not found in standby: " + usernameOrEmail)),
                    "CustomUserDetailsService.loadApplicationUser"
            );
        }
        return loadFromPostgres(usernameOrEmail);
    }

    private User loadFromPostgres(String usernameOrEmail) {
        // Email first: a legacy username equal to someone else's email must never win over that email's owner.
        return userRepository.findByEmail(usernameOrEmail)
                .or(() -> userRepository.findByUsername(usernameOrEmail))
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + usernameOrEmail));
    }

    private MongoStandbyFailoverService failoverService() {
        return failoverServiceProvider != null ? failoverServiceProvider.getIfAvailable() : null;
    }

    private MongoStandbyReadService standbyReadService() {
        return standbyReadServiceProvider != null ? standbyReadServiceProvider.getIfAvailable() : null;
    }
}
