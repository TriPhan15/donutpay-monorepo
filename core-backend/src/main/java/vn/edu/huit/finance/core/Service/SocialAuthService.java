package vn.edu.huit.finance.core.Service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.SocialLoginRejectedException;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.util.Map;

@Service
public class SocialAuthService {

    private static final Logger log = LoggerFactory.getLogger(SocialAuthService.class);

    private static final String GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo?id_token={t}";
    private static final String FACEBOOK_APP_URL = "https://graph.facebook.com/app?access_token={t}";
    private static final String FACEBOOK_ME_URL = "https://graph.facebook.com/me?fields=id,name,email&access_token={t}";

    private final UserRepository userRepository;
    private final AuthService authService;
    private final RestClient http;

    // Empty = provider not configured: its logins are refused (fail closed).
    @Value("${app.google.web-client-id:}")
    private String googleWebClientId;

    @Value("${app.facebook.app-id:}")
    private String facebookAppId;

    public SocialAuthService(UserRepository userRepository, AuthService authService,
                             RestClient.Builder restClientBuilder) {
        this.userRepository = userRepository;
        this.authService = authService;
        this.http = restClientBuilder.build();
    }

    public User authenticate(String provider, String token) {
        final Map<?, ?> info;
        if ("google".equalsIgnoreCase(provider)) {
            info = verifyGoogle(token);
        } else if ("facebook".equalsIgnoreCase(provider)) {
            info = verifyFacebook(token);
        } else {
            throw reject("provider not supported");
        }

        String email = str(info.get("email"));
        if (email == null || email.isBlank()) {
            throw reject("provider returned no email");
        }
        return findOrCreate(email, provider);
    }

    private Map<?, ?> verifyGoogle(String idToken) {
        if (isBlank(googleWebClientId)) {
            throw reject("Google web-client-id is not configured");
        }
        Map<?, ?> info = fetch(GOOGLE_TOKENINFO_URL, idToken, "Google");
        if (!googleWebClientId.equals(str(info.get("aud")))) {
            throw reject("Google token was issued for another client");
        }
        if (!"true".equals(str(info.get("email_verified")))) {
            throw reject("Google email is not verified");
        }
        return info;
    }

    private Map<?, ?> verifyFacebook(String accessToken) {
        if (isBlank(facebookAppId)) {
            throw reject("Facebook app-id is not configured");
        }
        // /app tells which app issued the token: a token of another app must not sign anybody in here.
        Map<?, ?> app = fetch(FACEBOOK_APP_URL, accessToken, "Facebook /app");
        if (!facebookAppId.equals(str(app.get("id")))) {
            throw reject("Facebook token was issued for another app");
        }
        Map<?, ?> info = fetch(FACEBOOK_ME_URL, accessToken, "Facebook /me");
        if (info.get("id") == null) {
            throw reject("Facebook returned no user id");
        }
        return info;
    }

    /** GET a JSON object from the provider; a failed call or an empty body is a rejection. The token is never logged. */
    private Map<?, ?> fetch(String url, String token, String what) {
        final Map<?, ?> body;
        try {
            body = http.get().uri(url, token).retrieve().body(Map.class);
        } catch (RestClientException e) {
            throw reject(what + " refused the token (" + e.getClass().getSimpleName() + ")");
        }
        if (body == null) {
            throw reject(what + " answered with an empty body");
        }
        return body;
    }

    private static SocialLoginRejectedException reject(String reason) {
        log.warn("Social login rejected: {}", reason);
        return new SocialLoginRejectedException();
    }

    /** The account of a verified email; the first sign-in creates it (with its audit row, in its own transaction). */
    private User findOrCreate(String email, String provider) {
        return userRepository.findByEmail(email).orElseGet(() -> authService.registerSocialAccount(email, provider));
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private static String str(Object o) {
        return o == null ? null : o.toString();
    }
}
