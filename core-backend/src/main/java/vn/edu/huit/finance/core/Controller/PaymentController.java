package vn.edu.huit.finance.core.Controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.CreatePaymentRequestDto;
import vn.edu.huit.finance.core.Dto.PaymentWebhookDto;
import vn.edu.huit.finance.core.Exception.InvalidTokenException;
import vn.edu.huit.finance.core.Exception.UserNotFoundException;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.PaymentService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/payment")
public class PaymentController {

    private static final String MSG_NOT_SIGNED_IN = "Bạn chưa đăng nhập";
    private static final String MSG_USER_NOT_FOUND = "Không tìm thấy người dùng";

    @Autowired private PaymentService paymentService;
    @Autowired private UserRepository userRepository;

    private Long currentUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) throw new InvalidTokenException(MSG_NOT_SIGNED_IN);
        return userRepository.findByEmail(auth.getName())
                .orElseThrow(() -> new UserNotFoundException(MSG_USER_NOT_FOUND))
                .getId();
    }

    @PostMapping("/create")
    public ResponseEntity<ApiResponse<Map<String, Object>>> create(
            @Valid @RequestBody CreatePaymentRequestDto req) {
        Map<String, Object> data = paymentService.createOrder(req, currentUserId());
        return ResponseEntity.ok(ApiResponse.<Map<String, Object>>builder()
                .code(200).message("Tao don thanh cong").data(data).build());
    }

    @PostMapping("/webhook")
    public ResponseEntity<ApiResponse<Void>> webhook(@Valid @RequestBody PaymentWebhookDto dto) {
        paymentService.handleWebhook(dto);
        return ResponseEntity.ok(ApiResponse.<Void>builder()
                .code(200).message("OK").build());
    }

    @GetMapping("/status/{orderCode}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> status(@PathVariable String orderCode) {
        Map<String, Object> data = paymentService.getStatus(orderCode, currentUserId());
        return ResponseEntity.ok(ApiResponse.<Map<String, Object>>builder()
                .code(200).message("OK").data(data).build());
    }

    @GetMapping("/mine")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> mine() {
        List<Map<String, Object>> data = paymentService.history(currentUserId());
        return ResponseEntity.ok(ApiResponse.<List<Map<String, Object>>>builder()
                .code(200).message("OK").data(data).build());
    }

    @PutMapping("/cancel/{orderCode}")
    public ResponseEntity<ApiResponse<Map<String, Object>>> cancel(@PathVariable String orderCode) {
        Map<String, Object> data = paymentService.cancel(orderCode, currentUserId());
        return ResponseEntity.ok(ApiResponse.<Map<String, Object>>builder()
                .code(200).message("Da huy don").data(data).build());
    }
}
