package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import vn.edu.huit.finance.core.Config.SecurityConfig;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackFilterRequestDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.OcrFeedbackNotFoundException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.CustomUserDetailsService;
import vn.edu.huit.finance.core.Security.JwtAuthFilter;
import vn.edu.huit.finance.core.Security.JwtUtil;
import vn.edu.huit.finance.core.Security.TokenClaims;
import vn.edu.huit.finance.core.Security.TokenType;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.OcrMongoService;
import vn.edu.huit.finance.core.Service.TokenBlacklistService;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The OCR feedback endpoints through the whole filter chain: who may call them and which parameters they accept. */
@WebMvcTest(AdminOcrFeedbackController.class)
@ContextConfiguration(classes = {
        AdminOcrFeedbackController.class, GlobalExceptionHandler.class, SecurityConfig.class, JwtAuthFilter.class})
class AdminOcrFeedbackControllerTest {

    private static final String PATH = "/api/admin/ocr-feedbacks";
    private static final String USER_TOKEN = "user.jwt.token";
    private static final String ADMIN_TOKEN = "admin.jwt.token";
    private static final String ID = "64b7f0f0f0f0f0f0f0f0f0f0";

    @Autowired private MockMvc mockMvc;

    @MockBean private OcrMongoService ocrMongoService;
    @MockBean private JwtUtil jwtUtil;
    @MockBean private CustomUserDetailsService userDetailsService;
    @MockBean private UserRepository userRepository;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    @BeforeEach
    void stubTokens() {
        stubToken(USER_TOKEN, "alice", "ROLE_USER");
        stubToken(ADMIN_TOKEN, "root", "ROLE_ADMIN");
    }

    @AfterEach
    void clearTheSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private void stubToken(String token, String username, String role) {
        when(jwtUtil.parse(token, TokenType.ACCESS)).thenReturn(new TokenClaims(username, 0));
        User user = new User();
        user.setUsername(username);
        user.setEmail(username);
        user.setActive(true);
        user.setRole(role);
        user.setLastActionTime(LocalDateTime.now());
        when(userDetailsService.loadApplicationUser(username)).thenReturn(user);
    }

    private static MockHttpServletRequestBuilder asAdmin(MockHttpServletRequestBuilder request) {
        return request.header(HttpHeaders.AUTHORIZATION, "Bearer " + ADMIN_TOKEN);
    }

    @Test
    void user_role_gets403() throws Exception {
        mockMvc.perform(get(PATH).header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN)).andExpect(status().isForbidden());
        mockMvc.perform(patch(PATH + "/" + ID + "/resolve").header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());
        mockMvc.perform(delete(PATH + "/" + ID).header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());
        mockMvc.perform(get(PATH + "/analytics").header(HttpHeaders.AUTHORIZATION, "Bearer " + USER_TOKEN))
                .andExpect(status().isForbidden());

        verifyNoInteractions(ocrMongoService);
    }

    @Test
    void admin_list_200_withPage() throws Exception {
        OcrFeedbackResponseDto dto = OcrFeedbackResponseDto.builder().id(ID).receiptId(7L).field("total_cost").build();
        when(ocrMongoService.findFeedbacks(any(), any(Pageable.class))).thenReturn(new PageImpl<>(List.of(dto)));

        mockMvc.perform(asAdmin(get(PATH).param("field", "TOTAL_COST").param("resolved", "false")
                        .param("from", "2026-05-01").param("to", "2026-05-31").param("page", "1").param("size", "5")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.content[0].id").value(ID))
                .andExpect(jsonPath("$.data.content[0].field").value("total_cost"));

        ArgumentCaptor<OcrFeedbackFilterRequestDto> filter = ArgumentCaptor.forClass(OcrFeedbackFilterRequestDto.class);
        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(ocrMongoService).findFeedbacks(filter.capture(), pageable.capture());
        assertEquals(OcrField.TOTAL_COST, filter.getValue().getField());
        assertEquals(Boolean.FALSE, filter.getValue().getResolved());
        assertEquals(LocalDate.of(2026, 5, 1), filter.getValue().getFrom());
        assertEquals(LocalDate.of(2026, 5, 31), filter.getValue().getTo());
        assertEquals(1, pageable.getValue().getPageNumber());
        assertEquals(5, pageable.getValue().getPageSize());
    }

    @Test
    void admin_list_defaultsToNewestFirst() throws Exception {
        when(ocrMongoService.findFeedbacks(any(), any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));

        mockMvc.perform(asAdmin(get(PATH))).andExpect(status().isOk());

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(ocrMongoService).findFeedbacks(any(), pageable.capture());
        assertEquals(Sort.by(Sort.Direction.DESC, "reportedAt"), pageable.getValue().getSort());
        assertEquals(20, pageable.getValue().getPageSize());
    }

    @Test
    void admin_size_over_100_400() throws Exception {
        mockMvc.perform(asAdmin(get(PATH).param("size", "101"))).andExpect(status().isBadRequest());

        verifyNoInteractions(ocrMongoService);
    }

    @Test
    void admin_unknownSortProperty_400() throws Exception {
        mockMvc.perform(asAdmin(get(PATH).param("sort", "aiValue,desc"))).andExpect(status().isBadRequest());

        verifyNoInteractions(ocrMongoService);
    }

    @Test
    void admin_resolve_unknown_404() throws Exception {
        when(ocrMongoService.resolveFeedback(ID)).thenThrow(new OcrFeedbackNotFoundException("Không tìm thấy phản hồi OCR"));

        mockMvc.perform(asAdmin(patch(PATH + "/" + ID + "/resolve")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404));
    }

    @Test
    void admin_resolve_200() throws Exception {
        when(ocrMongoService.resolveFeedback(ID)).thenReturn(OcrFeedbackResponseDto.builder().id(ID).resolved(true).build());

        mockMvc.perform(asAdmin(patch(PATH + "/" + ID + "/resolve")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.resolved").value(true));
    }

    @Test
    void admin_delete_200_and_unknown_404() throws Exception {
        mockMvc.perform(asAdmin(delete(PATH + "/" + ID))).andExpect(status().isOk());
        verify(ocrMongoService).deleteFeedback(ID);

        doThrow(new OcrFeedbackNotFoundException("Không tìm thấy phản hồi OCR")).when(ocrMongoService).deleteFeedback("missing");
        mockMvc.perform(asAdmin(delete(PATH + "/missing"))).andExpect(status().isNotFound());
    }

    @Test
    void admin_analytics_200() throws Exception {
        when(ocrMongoService.analytics(eq(LocalDate.of(2026, 5, 1)), eq(LocalDate.of(2026, 5, 31)))).thenReturn(
                OcrAnalyticsResponseDto.builder().errorsByField(List.of()).errorsByModel(List.of())
                        .confidenceByMonth(List.of()).receiptsWithErrorRate(0.25).build());

        mockMvc.perform(asAdmin(get(PATH + "/analytics").param("from", "2026-05-01").param("to", "2026-05-31")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.receiptsWithErrorRate").value(0.25));
    }
}
