package vn.edu.huit.finance.core.Security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;

/**
 * Records every real request of the admin web as activity of its session (see {@link AdminSessionActivity}). Runs on the
 * admin filter chain after the authorization, so a refused request records nothing; it never creates a session. Not a
 * Spring bean on purpose: as a bean it would also be registered for every request of the servlet container.
 */
public class AdminActivityFilter extends OncePerRequestFilter {

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !AdminSessionActivity.isTracked(request.getRequestURI().substring(request.getContextPath().length()));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session != null) {
            AdminSessionActivity.record(session, Instant.now());
        }
        filterChain.doFilter(request, response);
    }
}
