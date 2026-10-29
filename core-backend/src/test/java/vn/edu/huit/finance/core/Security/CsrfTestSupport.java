package vn.edu.huit.finance.core.Security;

import jakarta.servlet.http.HttpSession;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.security.web.csrf.DefaultCsrfToken;
import org.springframework.security.web.csrf.HttpSessionCsrfTokenRepository;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Stand-in for SecurityMockMvcRequestPostProcessors.csrf(): spring-security-test is not a dependency of the project.
 * It stores a token in the session of the request and sends it, masked the way the browser pages send it (the
 * XorCsrfTokenRequestAttributeHandler of Spring Security 6 only accepts a masked value).
 */
public final class CsrfTestSupport {

    private static final String PARAMETER = "_csrf";
    private static final String HEADER = "X-CSRF-TOKEN";
    private static final String SESSION_TOKEN = "test-session-token-0123456789-abcdefghij";
    private static final String SESSION_ATTRIBUTE = HttpSessionCsrfTokenRepository.class.getName() + ".CSRF_TOKEN";
    private static final SecureRandom RANDOM = new SecureRandom();

    private CsrfTestSupport() {
    }

    /** A valid token, sent in the _csrf form parameter. */
    public static RequestPostProcessor csrf() {
        return request -> {
            storeToken(request.getSession(true));
            request.setParameter(PARAMETER, mask(SESSION_TOKEN));
            return request;
        };
    }

    /** A valid token, sent in the X-CSRF-TOKEN header as admin-csrf.js does for fetch and jQuery calls. */
    public static RequestPostProcessor csrfHeader() {
        return request -> {
            storeToken(request.getSession(true));
            request.addHeader(HEADER, mask(SESSION_TOKEN));
            return request;
        };
    }

    private static void storeToken(HttpSession session) {
        CsrfToken token = new DefaultCsrfToken(HEADER, PARAMETER, SESSION_TOKEN);
        session.setAttribute(SESSION_ATTRIBUTE, token);
    }

    private static String mask(String token) {
        byte[] tokenBytes = token.getBytes(StandardCharsets.UTF_8);
        byte[] random = new byte[tokenBytes.length];
        RANDOM.nextBytes(random);
        byte[] combined = new byte[tokenBytes.length * 2];
        System.arraycopy(random, 0, combined, 0, random.length);
        for (int i = 0; i < tokenBytes.length; i++) {
            combined[random.length + i] = (byte) (random[i] ^ tokenBytes[i]);
        }
        return Base64.getUrlEncoder().encodeToString(combined);
    }
}
