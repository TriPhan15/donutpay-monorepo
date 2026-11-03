package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.AppReviewRepository;
import vn.edu.huit.finance.core.Repository.CampaignRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.SubscriptionPlanRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.AdminStatisticsService;
import vn.edu.huit.finance.core.Service.AppReviewService;
import vn.edu.huit.finance.core.Service.AuditLogQueryService;
import vn.edu.huit.finance.core.Service.BackupService;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.CategoryService;
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.ReceiptProcessingService;
import vn.edu.huit.finance.core.Service.SubscriptionPlanService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserService;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static vn.edu.huit.finance.core.Security.CsrfTestSupport.csrfHeader;

/**
 * The @PreAuthorize handlers of AdminController other than receipt approve/reject (AdminReceiptReviewTest covers
 * those two): an ordinary user gets 403 through the filter chain, and @PreAuthorize alone refuses a caller that is not
 * an administrator before the handler touches any service.
 */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = {
        AdminController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminControllerPreAuthorizeTest {

    private static final String EMPTY_JSON = "{}";
    private static final Set<String> RECEIPT_REVIEW_HANDLERS = Set.of("approveReceipt", "rejectReceipt");

    @Autowired private MockMvc mockMvc;
    @Autowired private AdminController controller;

    @MockBean private TransactionService transactionService;
    @MockBean private ReceiptProcessingService receiptProcessingService;
    @MockBean private AdminStatisticsService adminStatisticsService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private UserRepository userRepo;
    @MockBean private CategoryRepository categoryRepo;
    @MockBean private CampaignRepository campaignRepo;
    @MockBean private ReceiptRepository receiptRepo;
    @MockBean private BackupService backupService;
    @MockBean private CustomerSegmentationService customerSegmentationService;
    @MockBean private UserService userService;
    @MockBean private EntityManager entityManager;
    @MockBean private SubscriptionPlanRepository subscriptionPlanRepository;
    @MockBean private SubscriptionPlanService subscriptionPlanService;
    @MockBean private CategoryService categoryService;
    @MockBean private AppReviewService appReviewService;
    @MockBean private AuditLogQueryService auditLogQueryService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private AppReviewRepository appReviewRepository;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    /** Handler name, HTTP method and URL of every guarded admin endpoint covered here. */
    static Stream<Arguments> guardedEndpoints() {
        return Stream.of(
                Arguments.of("createUserAjax", HttpMethod.POST, "/admin/ajax/users"),
                Arguments.of("updateUserAjax", HttpMethod.PUT, "/admin/ajax/users/7"),
                Arguments.of("deleteUserAjax", HttpMethod.DELETE, "/admin/ajax/users/7"),
                Arguments.of("toggleUserStatusAjax", HttpMethod.PUT, "/admin/ajax/users/7/toggle-status"),
                Arguments.of("createSubscriptionAjax", HttpMethod.POST, "/admin/ajax/subscriptions"),
                Arguments.of("updateSubscriptionAjax", HttpMethod.PUT, "/admin/ajax/subscriptions/7"),
                Arguments.of("toggleSubscriptionAjax", HttpMethod.PUT, "/admin/ajax/subscriptions/7/toggle"),
                Arguments.of("deleteSubscriptionAjax", HttpMethod.DELETE, "/admin/ajax/subscriptions/7"),
                Arguments.of("showAuditLog", HttpMethod.GET, "/admin/auditlog"),
                Arguments.of("addCategoryAjax", HttpMethod.POST, "/admin/ajax/categories"),
                Arguments.of("updateCategoryAjax", HttpMethod.PUT, "/admin/ajax/categories/7"),
                Arguments.of("deleteCategoryAjax", HttpMethod.DELETE, "/admin/ajax/categories/7"),
                Arguments.of("unlockUserOrIp", HttpMethod.POST, "/admin/ajax/security/unlock"),
                Arguments.of("approveReviewAjax", HttpMethod.POST, "/admin/ajax/reviews/7/approve"),
                Arguments.of("deleteReviewAjax", HttpMethod.DELETE, "/admin/ajax/reviews/7"),
                Arguments.of("runAiSegmentation", HttpMethod.POST, "/admin/ajax/segmentation/run"));
    }

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private static Authentication someoneWithRole(String role) {
        return new UsernamePasswordAuthenticationToken("someone", null, AuthorityUtils.createAuthorityList(role));
    }

    private static MockHttpSession sessionOf(String role) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
                new SecurityContextImpl(someoneWithRole(role)));
        return session;
    }

    private static Method handler(String name) {
        return Arrays.stream(AdminController.class.getMethods())
                .filter(method -> method.getName().equals(name))
                .findFirst()
                .orElseThrow(() -> new AssertionError("AdminController has no handler " + name));
    }

    private void verifyNoServiceWasTouched() {
        verifyNoInteractions(userService, subscriptionPlanService, categoryService, appReviewService,
                auditLogQueryService, loginAttemptService, customerSegmentationService, transactionService,
                receiptProcessingService);
    }

    @ParameterizedTest(name = "{1} {2}")
    @MethodSource("guardedEndpoints")
    void anOrdinaryUserIsForbiddenAndNoServiceIsTouched(String name, HttpMethod method, String url) throws Exception {
        mockMvc.perform(request(method, url).with(csrfHeader()).session(sessionOf(Roles.USER))
                        .contentType(MediaType.APPLICATION_JSON).content(EMPTY_JSON))
                .andExpect(status().isForbidden());

        verifyNoServiceWasTouched();
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("guardedEndpoints")
    void preAuthorizeAloneRefusesAnOrdinaryUserBeforeTheHandlerRuns(String name, HttpMethod method, String url) {
        // Calling the bean directly skips the /admin/** rule of SecurityConfig, so only the annotation can say no here.
        SecurityContextHolder.getContext().setAuthentication(someoneWithRole(Roles.USER));
        Method target = handler(name);
        Object[] noArguments = new Object[target.getParameterCount()];

        InvocationTargetException thrown =
                assertThrows(InvocationTargetException.class, () -> target.invoke(controller, noArguments));

        assertInstanceOf(AccessDeniedException.class, thrown.getCause());
        verifyNoServiceWasTouched();
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("guardedEndpoints")
    void everyCoveredHandlerCarriesTheAdministratorRule(String name, HttpMethod method, String url) {
        PreAuthorize rule = handler(name).getAnnotation(PreAuthorize.class);

        assertNotNull(rule, name + " must be closed by @PreAuthorize as well as by the URL rule");
        assertEquals(Roles.HAS_ADMIN, rule.value());
    }

    @Test
    void everyPreAuthorizeHandlerOfTheControllerIsCoveredByATest() {
        Set<String> guarded = Arrays.stream(AdminController.class.getDeclaredMethods())
                .filter(method -> method.isAnnotationPresent(PreAuthorize.class))
                .map(Method::getName)
                .filter(name -> !RECEIPT_REVIEW_HANDLERS.contains(name))
                .collect(Collectors.toSet());
        Set<String> covered = guardedEndpoints()
                .map(arguments -> (String) arguments.get()[0])
                .collect(Collectors.toSet());

        assertEquals(guarded, covered);
    }
}
