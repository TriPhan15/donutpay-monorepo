package vn.edu.huit.finance.core.Security;

import jakarta.servlet.http.HttpSession;

import java.time.Instant;
import java.util.List;

/**
 * When the administrator last really used the admin web, kept in the HTTP session.
 * <p>
 * The servlet container's own idle timeout cannot tell: an open admin tab keeps touching the session through its
 * Server-Sent Events stream (every completion and every EventSource reconnect is a request), so the session would never
 * expire. {@link AdminActivityFilter} therefore records the instant of every real admin request, never of the stream or
 * of a static file, and a session is idle once that instant is older than the session's own timeout
 * ({@link HttpSession#getMaxInactiveInterval()}, server.servlet.session.timeout). The event stream of an idle session is
 * closed, and its reconnect is refused and ends the session.
 */
public final class AdminSessionActivity {

    public static final String LAST_ACTIVITY_ATTRIBUTE = AdminSessionActivity.class.getName() + ".LAST_ACTIVITY";

    /** Requests that are not the administrator's activity: the event stream and the admin web's own static files. */
    static final List<String> UNTRACKED_PATH_PREFIXES = List.of("/admin/events", "/admin/js/");

    private static final String TRACKED_PATH_PREFIX = "/admin/";
    /** A timeout of zero or less: the session never expires (Servlet specification). */
    private static final int NEVER_EXPIRES = 0;
    private static final long MILLIS_PER_SECOND = 1000L;

    private AdminSessionActivity() {
    }

    public static void record(HttpSession session, Instant now) {
        session.setAttribute(LAST_ACTIVITY_ATTRIBUTE, now.toEpochMilli());
    }

    /**
     * Whether the last real activity in {@code session} is older than the session's idle timeout. Without any recorded
     * activity the session's creation counts. Throws {@link IllegalStateException} for an invalidated session.
     */
    public static boolean isIdle(HttpSession session, Instant now) {
        // First, because getMaxInactiveInterval() does not check: throws IllegalStateException once invalidated.
        long createdAt = session.getCreationTime();
        int timeoutSeconds = session.getMaxInactiveInterval();
        if (timeoutSeconds <= NEVER_EXPIRES) {
            return false;
        }
        long lastActivity = session.getAttribute(LAST_ACTIVITY_ATTRIBUTE) instanceof Long recorded
                ? recorded
                : createdAt;
        return now.toEpochMilli() - lastActivity > timeoutSeconds * MILLIS_PER_SECOND;
    }

    /** Whether a request to {@code path} (without the context path) is activity of the administrator. */
    static boolean isTracked(String path) {
        return path.startsWith(TRACKED_PATH_PREFIX) && UNTRACKED_PATH_PREFIXES.stream().noneMatch(path::startsWith);
    }
}
