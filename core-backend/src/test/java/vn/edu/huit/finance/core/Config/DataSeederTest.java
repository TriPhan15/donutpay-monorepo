package vn.edu.huit.finance.core.Config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.validation.BindValidationException;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import vn.edu.huit.finance.core.Service.DemoData.DemoDataWriter;
import vn.edu.huit.finance.core.Service.DemoData.DemoSeedResult;
import vn.edu.huit.finance.core.Service.DemoData.ReceiptScenario;
import vn.edu.huit.finance.core.Service.DemoData.SeededReceipt;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * The switch: without app.seed.demo=true no seeding bean exists at all, and with it the passwords have to pass
 * @StrongPassword before anything runs. The writer and the Mongo seeder are mocks here (DemoDataWriterTest covers the
 * writing); a CommandLineRunner is not run by an ApplicationContextRunner, so the tests call it themselves.
 */
class DataSeederTest {

    private static final String ADMIN_PASSWORD = "Admin2026x";
    private static final String DEMO_PASSWORD = "Demo2026a";

    private final DemoDataWriter writer = mock(DemoDataWriter.class);
    private final MongoDataSeeder mongoDataSeeder = mock(MongoDataSeeder.class);

    /** The seeding classes as the component scan would find them. */
    private final ApplicationContextRunner scanned = new ApplicationContextRunner()
            .withUserConfiguration(DataSeeder.class, MongoDataSeeder.class, DemoDataWriter.class);

    /** DataSeeder with its two collaborators replaced by mocks. */
    private final ApplicationContextRunner mocked = new ApplicationContextRunner()
            .withUserConfiguration(DataSeeder.class)
            .withBean(DemoDataWriter.class, () -> writer)
            .withBean(MongoDataSeeder.class, () -> mongoDataSeeder);

    @Test
    void withoutTheFlagNothingIsSeeded() {
        scanned.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context).doesNotHaveBean(DataSeeder.class);
            assertThat(context).doesNotHaveBean(DemoDataWriter.class);
            assertThat(context).doesNotHaveBean(MongoDataSeeder.class);
            assertThat(context).doesNotHaveBean(DemoSeedProperties.class);
        });
    }

    @Test
    void theFlagSetToFalseSeedsNothing_evenWithoutPasswords() {
        scanned.withPropertyValues(DemoSeedProperties.ENABLED_PROPERTY + "=false").run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context).doesNotHaveBean(DataSeeder.class);
        });
    }

    @Test
    void withTheFlag_aMissingPasswordStopsTheStartup() {
        mocked.withPropertyValues(DemoSeedProperties.ENABLED_PROPERTY + "=true", "app.seed.admin-password=" + ADMIN_PASSWORD)
                .run(context -> {
                    assertThat(context).hasFailed();
                    assertThat(context.getStartupFailure()).hasRootCauseInstanceOf(BindValidationException.class)
                            .rootCause().hasMessageContaining("demoPassword");
                });
    }

    @Test
    void withTheFlag_aWeakPasswordStopsTheStartup() {
        mocked.withPropertyValues(DemoSeedProperties.ENABLED_PROPERTY + "=true",
                        "app.seed.admin-password=12345678", "app.seed.demo-password=" + DEMO_PASSWORD)
                .run(context -> {
                    assertThat(context).hasFailed();
                    assertThat(context.getStartupFailure()).hasRootCauseInstanceOf(BindValidationException.class)
                            .rootCause().hasMessageContaining("adminPassword");
                });
    }

    @Test
    void withTheFlagAndStrongPasswords_postgresIsSeededFirst_thenMongoWithTheSameReceipts() {
        SeededReceipt receipt = new SeededReceipt(10L, 20L, 30L, ReceiptScenario.READ, "{}", "Phúc Long", "Phúc Long",
                BigDecimal.valueOf(55_000), LocalDateTime.of(2026, 10, 20, 15, 0));
        DemoSeedResult result = new DemoSeedResult(true, 39, 7000, List.of(receipt));
        when(writer.seedIfEmpty(ADMIN_PASSWORD, DEMO_PASSWORD)).thenReturn(result);

        mocked.withPropertyValues(DemoSeedProperties.ENABLED_PROPERTY + "=true",
                        "app.seed.admin-password=" + ADMIN_PASSWORD, "app.seed.demo-password=" + DEMO_PASSWORD)
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    context.getBean(DataSeeder.class).run();
                });

        var order = inOrder(writer, mongoDataSeeder);
        order.verify(writer).seedIfEmpty(ADMIN_PASSWORD, DEMO_PASSWORD);
        order.verify(mongoDataSeeder).seed(List.of(receipt));
    }
}
