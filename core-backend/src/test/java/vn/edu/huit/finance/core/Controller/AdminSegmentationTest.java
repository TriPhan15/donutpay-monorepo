package vn.edu.huit.finance.core.Controller;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Exception.AiServiceUnavailableException;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Service.AiSegmentClient;
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * The customer segmentation calls the AI service at the configured URL (AI_SERVICE_URL), and an unreachable service is
 * a fixed 503 text: no label is written, nothing is recorded, and the connection error never reaches the client.
 */
@ExtendWith(MockitoExtension.class)
class AdminSegmentationTest {

    @Mock private ApplicationEventPublisher eventPublisher;

    /** Nothing listens on port 1, so the connection is refused at once. */
    private static final String UNREACHABLE_AI_SERVICE = "http://127.0.0.1:1";
    private static final String FIXED_TEXT = "Dịch vụ AI tạm thời không phản hồi, vui lòng thử lại sau.";

    @Test
    void anUnreachableAiServiceIsAFixedText() {
        AiSegmentClient client = new AiSegmentClient();
        ReflectionTestUtils.setField(client, "aiServiceUrl", UNREACHABLE_AI_SERVICE);

        AiServiceUnavailableException error =
                assertThrows(AiServiceUnavailableException.class, () -> client.requestSegments(List.of()));

        assertEquals(FIXED_TEXT, error.getMessage());
        assertFalse(error.getMessage().contains("127.0.0.1"));
    }

    @Test
    void anUnreachableAiServiceWritesNoLabel_andRecordsNothing() {
        AdminController controller = new AdminController();
        CustomerSegmentationService service = mock(CustomerSegmentationService.class);
        when(service.runSegmentation()).thenThrow(new AiServiceUnavailableException(FIXED_TEXT));
        ReflectionTestUtils.setField(controller, "customerSegmentationService", service);
        ReflectionTestUtils.setField(controller, "eventPublisher", eventPublisher);

        assertThrows(AiServiceUnavailableException.class, controller::runAiSegmentation);

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
