package vn.edu.huit.finance.core.Controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.CreatePaymentRequestDto;
import vn.edu.huit.finance.core.Dto.PaymentOrderResponseDto;
import vn.edu.huit.finance.core.Dto.PaymentStatusResponseDto;
import vn.edu.huit.finance.core.Dto.PaymentWebhookDto;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.PaymentService;

import java.util.List;

@RestController
@RequestMapping("/api/payment")
@RequiredArgsConstructor
public class PaymentController {

    private static final int HTTP_OK = 200;
    private static final String MSG_OK = "OK";
    private static final String MSG_ORDER_CREATED = "Tạo đơn thành công";
    private static final String MSG_ORDER_CANCELED = "Đã hủy đơn";

    private final PaymentService paymentService;
    private final CurrentUserProvider currentUserProvider;

    @PostMapping("/create")
    public ResponseEntity<ApiResponse<PaymentOrderResponseDto>> create(
            @Valid @RequestBody CreatePaymentRequestDto req) {
        PaymentOrderResponseDto data = paymentService.createOrder(req, currentUserId());
        return respond(MSG_ORDER_CREATED, data);
    }

    @PostMapping("/webhook")
    public ResponseEntity<ApiResponse<Void>> webhook(@Valid @RequestBody PaymentWebhookDto dto) {
        paymentService.handleWebhook(dto);
        return respond(MSG_OK, null);
    }

    @GetMapping("/status/{orderCode}")
    public ResponseEntity<ApiResponse<PaymentStatusResponseDto>> status(@PathVariable String orderCode) {
        return respond(MSG_OK, paymentService.getStatus(orderCode, currentUserId()));
    }

    @GetMapping("/mine")
    public ResponseEntity<ApiResponse<List<PaymentStatusResponseDto>>> mine() {
        return respond(MSG_OK, paymentService.history(currentUserId()));
    }

    @PutMapping("/cancel/{orderCode}")
    public ResponseEntity<ApiResponse<PaymentStatusResponseDto>> cancel(@PathVariable String orderCode) {
        return respond(MSG_ORDER_CANCELED, paymentService.cancel(orderCode, currentUserId()));
    }

    private Long currentUserId() {
        return currentUserProvider.getCurrentUser().getId();
    }

    private static <T> ResponseEntity<ApiResponse<T>> respond(String message, T data) {
        return ResponseEntity.ok(ApiResponse.<T>builder().code(HTTP_OK).message(message).data(data).build());
    }
}
