package vn.edu.huit.finance.core.Config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.context.annotation.PropertySource;
import vn.edu.huit.finance.core.Security.AuthPaths;

import java.util.List;

/**
 * The OpenAPI description of the REST API (springdoc): Swagger UI at /swagger-ui.html, one document per group, "user"
 * (/api/** without the admin part) and "admin" (/api/admin/**). Every operation needs the bearer JWT of POST
 * /api/auth/login, except the public auth endpoints ({@link AuthPaths#isPublic}). Both endpoints exist only with the
 * "dev" profile: anywhere else {@link DisabledOutsideDev} switches springdoc off, so prod never publishes them. When they
 * exist they match no security filter chain and are open, which is what a local dev machine wants.
 */
@Configuration
@PropertySource("classpath:openapi.properties")
public class OpenApiConfig {

    public static final String DEV_PROFILE = "dev";
    static final String BEARER_SCHEME = "bearerAuth";
    static final String USER_GROUP = "user";
    static final String ADMIN_GROUP = "admin";
    static final String API_PATHS = "/api/**";
    static final String ADMIN_API_PATHS = "/api/admin/**";

    private static final String TITLE = "LedgerMind / DonutPay Core API";
    private static final String VERSION = "1.0.0";
    private static final String DESCRIPTION = "API lõi của ứng dụng quản lý tài chính cá nhân: xác thực JWT, giao dịch, "
            + "ngân sách, hóa đơn (kết quả OCR của DONUT), thông báo và các API quản trị. Mọi phản hồi dùng khung "
            + "ApiResponse {code, message, data}.";
    private static final String USER_GROUP_NAME = "API người dùng (mobile)";
    private static final String ADMIN_GROUP_NAME = "API quản trị (ROLE_ADMIN)";
    private static final String BEARER_TYPE = "bearer";
    private static final String BEARER_FORMAT = "JWT";
    private static final String BEARER_DESCRIPTION = "Access token lấy từ data.token của POST /api/auth/login "
            + "(không gõ tiền tố \"Bearer \").";

    @Bean
    public OpenAPI ledgerMindOpenApi() {
        return new OpenAPI()
                .info(new Info().title(TITLE).version(VERSION).description(DESCRIPTION))
                .components(new Components().addSecuritySchemes(BEARER_SCHEME, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme(BEARER_TYPE)
                        .bearerFormat(BEARER_FORMAT)
                        .description(BEARER_DESCRIPTION)))
                .addSecurityItem(new SecurityRequirement().addList(BEARER_SCHEME));
    }

    @Bean
    public GroupedOpenApi userApi() {
        return GroupedOpenApi.builder()
                .group(USER_GROUP)
                .displayName(USER_GROUP_NAME)
                .pathsToMatch(API_PATHS)
                .pathsToExclude(ADMIN_API_PATHS)
                .addOpenApiCustomizer(OpenApiConfig::markPublicAuthEndpoints)
                .build();
    }

    @Bean
    public GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
                .group(ADMIN_GROUP)
                .displayName(ADMIN_GROUP_NAME)
                .pathsToMatch(ADMIN_API_PATHS)
                .build();
    }

    /** An empty security list on an operation overrides the global bearer requirement: Swagger UI sends no token there. */
    static void markPublicAuthEndpoints(OpenAPI openApi) {
        if (openApi.getPaths() == null) {
            return;
        }
        openApi.getPaths().forEach((path, item) -> {
            if (AuthPaths.isPublic(path)) {
                item.readOperations().forEach(operation -> operation.setSecurity(List.of()));
            }
        });
    }

    /** Skipped with the dev profile; otherwise its properties turn off /v3/api-docs and Swagger UI before springdoc starts. */
    @Configuration(proxyBeanMethods = false)
    @Profile("!" + DEV_PROFILE)
    @PropertySource("classpath:openapi-disabled.properties")
    static class DisabledOutsideDev {
    }
}
