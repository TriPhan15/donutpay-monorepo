package vn.edu.huit.finance.core.Controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.connection.DefaultMessage;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.AdminSessionActivity;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.Realtime.AdminEvent;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventPublisher;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventRelay;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventType;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrlPattern;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /admin/events, the Server-Sent Events stream of the admin web: behind the filter chain of the admin pages like every
 * page under /admin, and an open stream that ends (timeout, shutdown, a session that ended meanwhile) closes cleanly
 * instead of being sent to the login page in the middle of a response that is already streaming.
 */
@WebMvcTest(AdminEventsController.class)
@ContextConfiguration(classes = {
        AdminEventsController.class, AdminEventRelay.class, GlobalExceptionHandler.class, SecurityConfig.class,
        JwtAuthFilter.class})
class AdminEventsControllerTest {

    private static final String EVENTS = "/admin/events";
    /** The servlet container's default idle timeout (server.servlet.session.timeout = 30m). */
    private static final int SESSION_TIMEOUT_SECONDS = 1800;

    @Autowired private MockMvc mockMvc;
    @Autowired private AdminEventRelay relay;
    @Autowired private ObjectMapper mapper;

    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private UserRepository userRepo;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @AfterEach
    void cleanUp() {
        relay.shutdown();
        SecurityContextHolder.clearContext();
    }

    private static MockHttpSession sessionOf(String role) {
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
                new SecurityContextImpl(new UsernamePasswordAuthenticationToken(
                        "someone", null, AuthorityUtils.createAuthorityList(role))));
        return session;
    }

    private MvcResult openStream(MockHttpSession session) throws Exception {
        return mockMvc.perform(get(EVENTS).session(session).accept(MediaType.TEXT_EVENT_STREAM))
                .andExpect(request().asyncStarted())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_EVENT_STREAM))
                .andReturn();
    }

    private void relayReceives(AdminEvent event) throws Exception {
        relay.onMessage(new DefaultMessage(AdminEventPublisher.CHANNEL.getBytes(StandardCharsets.UTF_8),
                mapper.writeValueAsBytes(event)), null);
    }

    @Test
    void withoutASessionTheStreamIsSentToTheLoginPage() throws Exception {
        mockMvc.perform(get(EVENTS).accept(MediaType.TEXT_EVENT_STREAM))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrlPattern("**/admin/login"));

        assertEquals(0, relay.subscriberCount());
    }

    @Test
    void anOrdinaryUserIsRefused() throws Exception {
        mockMvc.perform(get(EVENTS).session(sessionOf(Roles.USER)).accept(MediaType.TEXT_EVENT_STREAM))
                .andExpect(status().isForbidden());

        assertEquals(0, relay.subscriberCount());
    }

    @Test
    void anAdministratorGetsAnEventStreamThatCarriesTheAdminEvents() throws Exception {
        MvcResult stream = openStream(sessionOf(Roles.ADMIN));
        assertEquals(1, relay.subscriberCount());

        relayReceives(AdminEvent.of(AdminEventType.RECEIPT_WAITING_REVIEW, 41L, "Hóa đơn #41 đang chờ duyệt"));

        String body = stream.getResponse().getContentAsString(StandardCharsets.UTF_8);
        assertTrue(body.contains("retry:"), body);
        assertTrue(body.contains("event:admin\ndata:{\"type\":\"RECEIPT_WAITING_REVIEW\",\"id\":41,"), body);
        assertTrue(body.contains("Hóa đơn #41 đang chờ duyệt"), body);
    }

    @Test
    void aStreamThatEndsIsForgottenAndItsClosingDispatchIsNotReauthorised() throws Exception {
        MockHttpSession session = sessionOf(Roles.ADMIN);
        MvcResult stream = openStream(session);

        // The session ends while the stream is open (sign-out or expiry); then the stream is closed by the server.
        session.invalidate();
        relay.heartbeat();
        assertEquals(0, relay.subscriberCount());

        // The ASYNC dispatch that finishes the response must not be refused (a redirect to the login page in the middle of
        // a streaming response): it only ever follows a request the admin rule already let through.
        mockMvc.perform(asyncDispatch(stream)).andExpect(status().isOk());
    }

    // ------------------------------------------------------------------------- idle sessions (the stream is no activity)

    /** An admin session with the container's default idle timeout whose last real page request was {@code idleFor} ago. */
    private static MockHttpSession adminIdleFor(Duration idleFor) {
        MockHttpSession session = sessionOf(Roles.ADMIN);
        session.setMaxInactiveInterval(SESSION_TIMEOUT_SECONDS);
        AdminSessionActivity.record(session, Instant.now().minus(idleFor));
        return session;
    }

    private static long lastActivityOf(MockHttpSession session) {
        return (Long) session.getAttribute(AdminSessionActivity.LAST_ACTIVITY_ATTRIBUTE);
    }

    @Test
    void aReconnectAfterTheAdministratorWasIdlePastTheTimeoutIsRefusedAndTheSessionEnds() throws Exception {
        MockHttpSession session = adminIdleFor(Duration.ofSeconds(SESSION_TIMEOUT_SECONDS + 1));

        // 204: EventSource treats it as a fatal error and stops reconnecting.
        mockMvc.perform(get(EVENTS).session(session).accept(MediaType.TEXT_EVENT_STREAM))
                .andExpect(request().asyncNotStarted())
                .andExpect(status().isNoContent());

        assertTrue(session.isInvalid());
        assertEquals(0, relay.subscriberCount());
    }

    @Test
    void aRealPageRequestResetsTheIdleClock() throws Exception {
        MockHttpSession session = adminIdleFor(Duration.ofSeconds(SESSION_TIMEOUT_SECONDS + 1));
        long before = Instant.now().toEpochMilli();

        mockMvc.perform(get("/admin/dashboard").session(session));

        assertTrue(lastActivityOf(session) >= before, "a page request is activity");
        openStream(session);
        assertEquals(1, relay.subscriberCount());
    }

    @Test
    void theEventStreamAndTheScriptAreNoActivity() throws Exception {
        MockHttpSession session = adminIdleFor(Duration.ofMinutes(10));
        long recorded = lastActivityOf(session);

        openStream(session);
        mockMvc.perform(get("/admin/js/admin-events.js").session(session));

        assertEquals(recorded, lastActivityOf(session));
    }

    @Test
    void aStreamClosedAtShutdownEndsWithA200() throws Exception {
        MvcResult stream = openStream(sessionOf(Roles.ADMIN));

        relay.shutdown();

        mockMvc.perform(asyncDispatch(stream)).andExpect(status().isOk());
        assertEquals(0, relay.subscriberCount());
    }
}
