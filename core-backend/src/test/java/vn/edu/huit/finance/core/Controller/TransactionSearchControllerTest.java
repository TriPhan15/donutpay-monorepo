package vn.edu.huit.finance.core.Controller;

import io.jsonwebtoken.MalformedJwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchResponseDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.Search.TransactionSearchService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;
import vn.edu.huit.finance.core.Service.TransactionService;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET /api/transactions/search through the real security chain and validation handler; the service is a mock. */
@WebMvcTest(TransactionController.class)
@ContextConfiguration(classes = {
        TransactionController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class TransactionSearchControllerTest {

    private static final String URL = "/api/transactions/search";
    private static final String TOKEN = "valid.jwt.token";
    private static final String USERNAME = "alice";

    @Autowired private MockMvc mockMvc;

    @MockBean private TransactionSearchService searchService;
    @MockBean private TransactionService transactionService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @BeforeEach
    void stubJwtForAlice() {
        when(jwtUtil.parse(TOKEN, TokenType.ACCESS)).thenReturn(new TokenClaims(USERNAME, 0));
        when(jwtUtil.parse("bad", TokenType.ACCESS)).thenThrow(new MalformedJwtException("bad"));
        User alice = new User();
        alice.setUsername(USERNAME);
        alice.setEmail(USERNAME);
        alice.setActive(true);
        alice.setRole("ROLE_USER");
        alice.setLastActionTime(LocalDateTime.now());
        when(userDetailsService.loadApplicationUser(USERNAME)).thenReturn(alice);
    }

    private static MockHttpServletRequestBuilder signedIn(String query) {
        return get(URL + query).header(HttpHeaders.AUTHORIZATION, "Bearer " + TOKEN);
    }

    @Test
    void q_oneChar_400() throws Exception {
        mockMvc.perform(signedIn("?q=a")).andExpect(status().isBadRequest());
        verifyNoInteractions(searchService);
    }

    @Test
    void q_spaceAndOneChar_400() throws Exception {
        mockMvc.perform(signedIn("").param("q", " a")).andExpect(status().isBadRequest());
        mockMvc.perform(signedIn("").param("q", "a  ")).andExpect(status().isBadRequest());
        verifyNoInteractions(searchService);
    }

    @Test
    void page_beyondResultWindow_400() throws Exception {
        mockMvc.perform(signedIn("?q=pho&page=200")).andExpect(status().isBadRequest());
        verifyNoInteractions(searchService);
    }

    @Test
    void q_missing_400() throws Exception {
        mockMvc.perform(signedIn("")).andExpect(status().isBadRequest());
        verifyNoInteractions(searchService);
    }

    @Test
    void size_51_400() throws Exception {
        mockMvc.perform(signedIn("?q=pho&size=51")).andExpect(status().isBadRequest());
        verifyNoInteractions(searchService);
    }

    @Test
    void noToken_rejected() throws Exception {
        // 401 since the token-revocation work (the brief said 403); either way the service is never reached.
        mockMvc.perform(get(URL + "?q=pho")).andExpect(status().isUnauthorized());
        verifyNoInteractions(searchService);
    }

    @Test
    void ok_200_envelope() throws Exception {
        TransactionResponseDto item = TransactionResponseDto.builder().id(100L).title("Phở")
                .amount(new BigDecimal("50000")).date(LocalDateTime.of(2026, 10, 1, 12, 0))
                .category("Ăn uống").isExpense(true).build();
        when(searchService.search(any())).thenReturn(TransactionSearchResponseDto.builder()
                .items(List.of(item)).total(1).engine("postgres").build());

        mockMvc.perform(signedIn("?q=pho&page=2&size=10&userId=999"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Tìm kiếm giao dịch thành công"))
                .andExpect(jsonPath("$.data.items[0].id").value(100))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.engine").value("postgres"));

        ArgumentCaptor<TransactionSearchRequestDto> sent = ArgumentCaptor.forClass(TransactionSearchRequestDto.class);
        verify(searchService).search(sent.capture());
        assertEquals("pho", sent.getValue().getQ());
        assertEquals(2, sent.getValue().getPage());
        assertEquals(10, sent.getValue().getSize());
    }
}
