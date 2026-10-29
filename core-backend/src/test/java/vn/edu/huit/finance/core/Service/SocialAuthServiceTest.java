package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.SocialLoginRejectedException;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class SocialAuthServiceTest {

    private static final String APP_ID = "111";
    private static final String CLIENT_ID = "web-client";
    private static final String FB_APP_URL = "https://graph.facebook.com/app?access_token=tok";
    private static final String FB_ME_URL = "https://graph.facebook.com/me?fields=id,name,email&access_token=tok";
    private static final String GOOGLE_URL = "https://oauth2.googleapis.com/tokeninfo?id_token=tok";

    private UserRepository userRepository;
    private MockRestServiceServer server;
    private SocialAuthService service;
    private final User user = new User();

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        RestClient.Builder builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        service = new SocialAuthService(userRepository, mock(AuthService.class), builder);
        ReflectionTestUtils.setField(service, "facebookAppId", APP_ID);
        ReflectionTestUtils.setField(service, "googleWebClientId", CLIENT_ID);
        when(userRepository.findByEmail("a@b.vn")).thenReturn(Optional.of(user));
    }

    private void expectJson(String url, String json) {
        server.expect(requestTo(url)).andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(json, MediaType.APPLICATION_JSON));
    }

    @Test
    void facebookTokenOfAnotherApp_isRejected() {
        expectJson(FB_APP_URL, "{\"id\":\"999\"}");
        assertThrows(SocialLoginRejectedException.class, () -> service.authenticate("facebook", "tok"));
        server.verify(); // /me was never expected, so a call to it would have failed the test
    }

    @Test
    void facebookInvalidToken_isRejected() {
        server.expect(requestTo(FB_APP_URL)).andRespond(withStatus(HttpStatus.BAD_REQUEST));
        assertThrows(SocialLoginRejectedException.class, () -> service.authenticate("facebook", "tok"));
        server.verify();
    }

    @Test
    void facebookNotConfigured_isRejected_withoutCallingFacebook() {
        ReflectionTestUtils.setField(service, "facebookAppId", "");
        assertThrows(SocialLoginRejectedException.class, () -> service.authenticate("facebook", "tok"));
        server.verify(); // no expectation set: any call would have failed
        verifyNoInteractions(userRepository);
    }

    @Test
    void facebookValidToken_returnsTheAccountOfItsEmail() {
        expectJson(FB_APP_URL, "{\"id\":\"" + APP_ID + "\"}");
        expectJson(FB_ME_URL, "{\"id\":\"42\",\"name\":\"A\",\"email\":\"a@b.vn\"}");
        assertSame(user, service.authenticate("facebook", "tok"));
        server.verify();
    }

    @Test
    void googleUnverifiedEmail_isRejected() {
        expectJson(GOOGLE_URL, "{\"aud\":\"" + CLIENT_ID + "\",\"email\":\"a@b.vn\",\"email_verified\":\"false\"}");
        assertThrows(SocialLoginRejectedException.class, () -> service.authenticate("google", "tok"));
    }

    @Test
    void googleWrongAudience_isRejected() {
        expectJson(GOOGLE_URL, "{\"aud\":\"other\",\"email\":\"a@b.vn\",\"email_verified\":\"true\"}");
        assertThrows(SocialLoginRejectedException.class, () -> service.authenticate("google", "tok"));
    }

    @Test
    void googleNotConfigured_isRejected() {
        ReflectionTestUtils.setField(service, "googleWebClientId", "");
        assertThrows(SocialLoginRejectedException.class, () -> service.authenticate("google", "tok"));
        server.verify();
        verifyNoInteractions(userRepository);
    }

    @Test
    void googleValid_returnsAccount() {
        expectJson(GOOGLE_URL, "{\"aud\":\"" + CLIENT_ID + "\",\"email\":\"a@b.vn\",\"email_verified\":\"true\"}");
        assertSame(user, service.authenticate("google", "tok"));
        server.verify();
    }
}
