package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Exception.AiServiceUnavailableException;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.UserRepository;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * The customer segmentation calls the AI service at the configured URL (AI_SERVICE_URL), and an unreachable service is
 * a fixed 503 text: no label is written, nothing is recorded, and the connection error never reaches the client.
 */
@ExtendWith(MockitoExtension.class)
class AdminSegmentationTest {

    /** Nothing listens on port 1, so the connection is refused at once. */
    private static final String UNREACHABLE_AI_SERVICE = "http://127.0.0.1:1";
    private static final String FIXED_TEXT = "Dịch vụ AI tạm thời không phản hồi, vui lòng thử lại sau.";

    @Mock private UserRepository userRepo;
    @Mock private ApplicationEventPublisher eventPublisher;
    @InjectMocks private AdminController controller;

    @Test
    void anUnreachableAiServiceIsAFixedText_andNoLabelIsWritten() {
        ReflectionTestUtils.setField(controller, "aiServiceUrl", UNREACHABLE_AI_SERVICE);
        when(userRepo.calculateAllUsersRFM()).thenReturn(List.<Object[]>of(new Object[]{7L, 3, 12, 1500000.0}));

        AiServiceUnavailableException error =
                assertThrows(AiServiceUnavailableException.class, controller::runAiSegmentation);

        assertEquals(FIXED_TEXT, error.getMessage());
        assertFalse(error.getMessage().contains("127.0.0.1"));
        verify(userRepo, never()).updateUserAiLabel(anyLong(), any());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void theHandlerAnswersTheAjaxCallWith503AndTheFixedText() {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/admin/ajax/segmentation/run");

        Object answer = new GlobalExceptionHandler()
                .handleAiServiceUnavailable(new AiServiceUnavailableException(FIXED_TEXT), request);

        ResponseEntity<?> response = assertInstanceOf(ResponseEntity.class, answer);
        assertEquals(503, response.getStatusCode().value());
        ApiResponse<?> body = assertInstanceOf(ApiResponse.class, response.getBody());
        assertEquals(503, body.getCode());
        assertEquals(FIXED_TEXT, body.getMessage());
    }
}
