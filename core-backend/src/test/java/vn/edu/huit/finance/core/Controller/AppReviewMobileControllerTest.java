package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import vn.edu.huit.finance.core.Dto.ReviewRequestDto;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Exception.UserNotFoundException;
import vn.edu.huit.finance.core.Service.AppReviewService;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * POST /api/reviews: the author is never taken from the body (the old IDOR), a user id sent by an old client is
 * ignored, and errors are the fixed texts of GlobalExceptionHandler instead of a raw exception message.
 */
@ExtendWith(MockitoExtension.class)
class AppReviewMobileControllerTest {

    private static final String URL = "/api/reviews";

    @Mock private AppReviewService appReviewService;
    @InjectMocks private AppReviewMobileController controller;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void aReviewIsSubmittedForTheCaller_evenWhenAnOldClientStillSendsAUserId() throws Exception {
        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":999,\"rating\":4,\"comment\":\"Rất tốt\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.message").value("Gửi đánh giá góp ý thành công!"));

        ArgumentCaptor<ReviewRequestDto> request = ArgumentCaptor.forClass(ReviewRequestDto.class);
        verify(appReviewService).submitMyReview(request.capture());
        assertEquals(4, request.getValue().getRating());
        assertEquals("Rất tốt", request.getValue().getComment());
    }

    @Test
    void anInvalidRatingIsRefusedBeforeTheService() throws Exception {
        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":9,\"comment\":\"Rất tốt\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Dữ liệu không hợp lệ: Đánh giá cao nhất là 5 sao"));

        verifyNoInteractions(appReviewService);
    }

    @Test
    void anUnknownCallerIsA404WithTheFixedText() throws Exception {
        doThrow(new UserNotFoundException("Không tìm thấy người dùng đang đăng nhập"))
                .when(appReviewService).submitMyReview(any());

        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":3,\"comment\":\"Tạm được\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value("Không tìm thấy người dùng đang đăng nhập"));
    }
}
