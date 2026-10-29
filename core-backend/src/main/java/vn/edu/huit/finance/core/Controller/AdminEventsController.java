package vn.edu.huit.finance.core.Controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.edu.huit.finance.core.Security.AdminSessionActivity;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Realtime.AdminEventRelay;

import java.time.Instant;

/**
 * The Server-Sent Events stream of the admin web (static/admin/js/admin-events.js opens it on every admin page). Closed to
 * everybody without ROLE_ADMIN twice, by the /admin/** rule of SecurityConfig and by @PreAuthorize; the stream also ends
 * with the session it was opened in.
 * <p>
 * The stream is no activity of the administrator ({@link AdminSessionActivity}): when the tab has been left alone past the
 * session timeout, the reconnect ends the session and is answered 204 No Content, on which EventSource stops for good
 * (it reconnects only after a 200 text/event-stream stream that ended).
 */
@Controller
@RequestMapping("/admin")
@PreAuthorize(Roles.HAS_ADMIN)
public class AdminEventsController {

    private final AdminEventRelay relay;

    public AdminEventsController(AdminEventRelay relay) {
        this.relay = relay;
    }

    @GetMapping(value = "/events", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @ResponseBody
    public ResponseEntity<SseEmitter> events(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session != null && AdminSessionActivity.isIdle(session, Instant.now())) {
            session.invalidate();
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(relay.register(session));
    }
}
