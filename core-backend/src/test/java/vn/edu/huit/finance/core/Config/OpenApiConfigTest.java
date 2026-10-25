package vn.edu.huit.finance.core.Config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.PathItem;
import io.swagger.v3.oas.models.Paths;
import org.junit.jupiter.api.Test;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Swagger only exists with the dev profile (the switch is the springdoc.*.enabled properties seen by springdoc's own
 * auto-configuration), the two groups split /api/** from /api/admin/**, and only the public auth endpoints lose the
 * bearer requirement.
 */
class OpenApiConfigTest {

    private static final String API_DOCS_ENABLED = "springdoc.api-docs.enabled";
    private static final String SWAGGER_UI_ENABLED = "springdoc.swagger-ui.enabled";
    private static final String SWAGGER_UI_PATH = "springdoc.swagger-ui.path";

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(OpenApiConfig.class);

    @Test
    void withoutTheDevProfileSwaggerIsSwitchedOff() {
        runner.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context.getEnvironment().getProperty(API_DOCS_ENABLED)).isEqualTo("false");
            assertThat(context.getEnvironment().getProperty(SWAGGER_UI_ENABLED)).isEqualTo("false");
        });
    }

    @Test
    void theProdProfileSwitchesSwaggerOff() {
        runner.withPropertyValues("spring.profiles.active=prod").run(context ->
                assertThat(context.getEnvironment().getProperty(API_DOCS_ENABLED)).isEqualTo("false"));
    }

    @Test
    void theDevProfileLeavesSwaggerOn() {
        runner.withPropertyValues("spring.profiles.active=" + OpenApiConfig.DEV_PROFILE).run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context.getEnvironment().getProperty(API_DOCS_ENABLED)).isNull();
            assertThat(context.getEnvironment().getProperty(SWAGGER_UI_ENABLED)).isNull();
            assertThat(context.getEnvironment().getProperty(SWAGGER_UI_PATH)).isEqualTo("/swagger-ui.html");
        });
    }

    @Test
    void anEnvironmentVariableStillWinsOverTheDisabledDefault() {
        runner.withPropertyValues(API_DOCS_ENABLED + "=true").run(context ->
                assertThat(context.getEnvironment().getProperty(API_DOCS_ENABLED)).isEqualTo("true"));
    }

    @Test
    void theUserGroupLeavesTheAdminApiToTheAdminGroup() {
        runner.run(context -> {
            GroupedOpenApi user = context.getBean("userApi", GroupedOpenApi.class);
            GroupedOpenApi admin = context.getBean("adminApi", GroupedOpenApi.class);
            assertThat(user.getGroup()).isEqualTo(OpenApiConfig.USER_GROUP);
            assertThat(user.getPathsToMatch()).containsExactly(OpenApiConfig.API_PATHS);
            assertThat(user.getPathsToExclude()).containsExactly(OpenApiConfig.ADMIN_API_PATHS);
            assertThat(admin.getGroup()).isEqualTo(OpenApiConfig.ADMIN_GROUP);
            assertThat(admin.getPathsToMatch()).containsExactly(OpenApiConfig.ADMIN_API_PATHS);
        });
    }

    @Test
    void everyOperationNeedsTheBearerJwtByDefault() {
        runner.run(context -> {
            OpenAPI openApi = context.getBean(OpenAPI.class);
            assertThat(openApi.getComponents().getSecuritySchemes()).containsKey(OpenApiConfig.BEARER_SCHEME);
            assertThat(openApi.getSecurity()).singleElement()
                    .satisfies(requirement -> assertThat(requirement).containsKey(OpenApiConfig.BEARER_SCHEME));
        });
    }

    @Test
    void onlyThePublicAuthEndpointsDropTheBearerRequirement() {
        Operation login = new Operation();
        Operation logout = new Operation();
        Operation changePassword = new Operation();
        Operation transactions = new Operation();
        OpenAPI openApi = new OpenAPI().paths(new Paths()
                .addPathItem("/api/auth/login", new PathItem().post(login))
                .addPathItem("/api/auth/logout", new PathItem().post(logout))
                .addPathItem("/api/auth/change-password", new PathItem().put(changePassword))
                .addPathItem("/api/transactions/mine", new PathItem().get(transactions)));

        OpenApiConfig.markPublicAuthEndpoints(openApi);

        assertThat(login.getSecurity()).isEqualTo(List.of());
        assertThat(logout.getSecurity()).isNull();
        assertThat(changePassword.getSecurity()).isNull();
        assertThat(transactions.getSecurity()).isNull();
    }

    @Test
    void aDocumentWithoutPathsIsLeftAlone() {
        OpenAPI openApi = new OpenAPI();

        OpenApiConfig.markPublicAuthEndpoints(openApi);

        assertThat(openApi.getPaths()).isNull();
    }
}
