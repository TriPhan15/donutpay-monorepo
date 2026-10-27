package vn.edu.huit.finance.core.Config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class ProductionSecretsGuardTest {

    private static final String[] ALL_SECRETS = {
            "spring.datasource.password=x1",
            "spring.mail.password=x2",
            "cloudinary.api-key=x3",
            "cloudinary.api-secret=x4",
            "payment.secret=x5",
            "app.jwt.secret=x6"
    };

    private ApplicationContextRunner runner(String profile) {
        return new ApplicationContextRunner()
                .withInitializer(context -> context.getEnvironment().setActiveProfiles(profile))
                .withUserConfiguration(ProductionSecretsGuard.class);
    }

    @Test
    void prodWithMissingSecrets_failsAndNamesThem_withoutValues() {
        runner("prod").withPropertyValues(ALL_SECRETS).withPropertyValues("payment.secret=").run(context -> {
            assertThat(context).hasFailed();
            Throwable failure = context.getStartupFailure();
            StringBuilder messages = new StringBuilder();
            for (Throwable t = failure; t != null; t = t.getCause()) {
                messages.append(t.getMessage()).append(' ');
            }
            assertThat(messages.toString()).contains("payment.secret").doesNotContain("x1", "x2", "x3", "x4", "x6");
        });
    }

    @Test
    void prodWithAllSecrets_starts() {
        runner("prod").withPropertyValues(ALL_SECRETS).run(context -> assertThat(context).hasNotFailed());
    }

    @Test
    void prodWithJwtSecretOnlyInEnvFallback_starts() {
        String[] withoutJwt = Arrays.copyOf(ALL_SECRETS, ALL_SECRETS.length - 1);
        runner("prod").withPropertyValues(withoutJwt).withPropertyValues("JWT_SECRET=x7")
                .run(context -> assertThat(context).hasNotFailed());
    }

    @Test
    void devWithMissingSecrets_starts() {
        runner("dev").run(context -> assertThat(context).hasNotFailed());
    }
}
