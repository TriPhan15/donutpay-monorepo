package vn.edu.huit.finance.core.Exception;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.ModelAndView;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.DuplicateReceiptResponseDto;
import vn.edu.huit.finance.core.Security.AuditingAccessDeniedHandler;
import vn.edu.huit.finance.core.Service.Audit.SecurityAuditEvent;

import java.util.stream.Collectors;

@Slf4j
@ControllerAdvice
public class GlobalExceptionHandler {

    private static final String MSG_CONCURRENT_CHANGE =
            "Dữ liệu vừa được thay đổi bởi một yêu cầu khác, vui lòng tải lại rồi thử lại";
    private static final String MSG_SYSTEM_ERROR = "Hệ thống đang gặp sự cố, vui lòng thử lại sau";
    private static final String TYPE_MISMATCH = "typeMismatch";
    private static final String MSG_UNREADABLE_BODY = "Dữ liệu gửi lên không đúng định dạng";
    private static final String MSG_PARAMETER_INVALID = "Giá trị của tham số %s không hợp lệ";
    private static final String MSG_METHOD_NOT_ALLOWED = "Phương thức %s không được hỗ trợ cho địa chỉ này";
    private static final String MSG_UNSUPPORTED_MEDIA_TYPE = "Định dạng dữ liệu gửi lên không được hỗ trợ";
    private static final String MSG_URL_NOT_FOUND = "Không tìm thấy địa chỉ yêu cầu";
    private static final String MSG_MISSING_HEADER = "Thiếu header bắt buộc: %s";
    private static final String REASON_NOT_OWNER = "Dữ liệu thuộc về người dùng khác";
    private static final String REASON_ROLE = "Phân quyền theo vai trò";
    private static final String MSG_UPLOAD_TOO_LARGE = "Ảnh quá lớn (tối đa 15MB), vui lòng chụp lại với độ phân giải thấp hơn";

    // Every 403 is recorded (AUTH_ACCESS_DENIED), in a row written on its own: the request's transaction has rolled back.
    @Autowired
    private ApplicationEventPublisher eventPublisher;

    private boolean isJsonRequest(HttpServletRequest request) {
        String uri = request.getRequestURI();
        return uri.startsWith("/api/") || uri.contains("/ajax/");
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Object handleValidationExceptions(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String errorMessage = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getDefaultMessage())
                .collect(Collectors.joining(", "));

        if (isJsonRequest(request)) {
            return ResponseEntity.badRequest().body(ApiResponse.<String>builder()
                    .code(400)
                    .message("Dữ liệu không hợp lệ: " + errorMessage)
                    .build());
        }
        return new ModelAndView("error").addObject("errorMessage", errorMessage);
    }

    // 400: a form or query bound to a DTO with @Valid @ModelAttribute (admin pages) broke a rule. MethodArgumentNotValid
    // (a JSON body) is a subclass and keeps its own handler above.
    @ExceptionHandler(BindException.class)
    public Object handleBindException(BindException ex, HttpServletRequest request) {
        // A value that did not even convert ("abc" for a number) gets a short text of ours, not Spring's class names.
        String errorMessage = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> TYPE_MISMATCH.equals(error.getCode())
                        ? String.format(MSG_PARAMETER_INVALID, error.getField())
                        : error.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return buildErrorResponse(HttpStatus.BAD_REQUEST, "Dữ liệu không hợp lệ: " + errorMessage, request);
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public Object handleMissingRequestParameter(MissingServletRequestParameterException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, "Thiếu tham số bắt buộc: " + ex.getParameterName(), request);
    }

    // Tham số @Min/@Max của @RequestParam (controller có @Validated): 400 thay vì rơi xuống handler 500 chung.
    @ExceptionHandler(ConstraintViolationException.class)
    public Object handleConstraintViolation(ConstraintViolationException ex, HttpServletRequest request) {
        String errorMessage = ex.getConstraintViolations().stream()
                .map(ConstraintViolation::getMessage)
                .collect(Collectors.joining(", "));
        return buildErrorResponse(HttpStatus.BAD_REQUEST, "Dữ liệu không hợp lệ: " + errorMessage, request);
    }

    @ExceptionHandler(InvalidPasswordException.class)
    public Object handleInvalidPassword(InvalidPasswordException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, ex.getMessage(), request);
    }

    @ExceptionHandler(InvalidOtpException.class)
    public Object handleInvalidOtp(InvalidOtpException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, ex.getMessage(), request);
    }

    // 429 with a fixed text: too many reset codes were requested for the email.
    @ExceptionHandler(OtpRequestLimitedException.class)
    public Object handleOtpRequestLimited(OtpRequestLimitedException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage(), request);
    }

    // 503 with a fixed text: the OTP store (Redis) is down, so no OTP was issued or checked. The cause stays in the log.
    @ExceptionHandler(OtpStoreUnavailableException.class)
    public Object handleOtpStoreUnavailable(OtpStoreUnavailableException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), request);
    }

    // 503 with a fixed text: the AI service is down or answered nothing usable. The cause stays in the log.
    @ExceptionHandler(AiServiceUnavailableException.class)
    public Object handleAiServiceUnavailable(AiServiceUnavailableException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), request);
    }

    // 401: no usable token where one is required. A revoked token never gets this far, JwtAuthFilter answers it first.
    @ExceptionHandler(InvalidTokenException.class)
    public Object handleInvalidToken(InvalidTokenException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.UNAUTHORIZED, ex.getMessage(), request);
    }

    // 401 with a fixed text: the reason (wrong app, unverified email...) stays in the service log.
    @ExceptionHandler(SocialLoginRejectedException.class)
    public Object handleSocialLoginRejected(SocialLoginRejectedException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.UNAUTHORIZED, ex.getMessage(), request);
    }

    // 409: another request changed the password first; nothing was written, so trying again is safe.
    @ExceptionHandler(CredentialsChangeConflictException.class)
    public Object handleCredentialsChangeConflict(CredentialsChangeConflictException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.CONFLICT, ex.getMessage(), request);
    }

    @ExceptionHandler(BudgetNotFoundException.class)
    public Object handleBudgetNotFound(BudgetNotFoundException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.NOT_FOUND, ex.getMessage(), request);
    }

    @ExceptionHandler(DuplicateBudgetException.class)
    public Object handleDuplicateBudget(DuplicateBudgetException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.CONFLICT, ex.getMessage(), request);
    }

    // 400 rather than 404: the category is referenced from the request body, so it is the request that is invalid.
    @ExceptionHandler(InvalidCategoryException.class)
    public Object handleInvalidCategory(InvalidCategoryException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, ex.getMessage(), request);
    }

    @ExceptionHandler(UserNotFoundException.class)
    public Object handleUserNotFound(UserNotFoundException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.NOT_FOUND, ex.getMessage(), request);
    }

    @ExceptionHandler({TransactionNotFoundException.class, ReceiptNotFoundException.class, OcrFeedbackNotFoundException.class,
            AppReviewNotFoundException.class, SubscriptionPlanNotFoundException.class, PaymentOrderNotFoundException.class,
            SavingGoalNotFoundException.class})
    public Object handleTransactionOrReceiptNotFound(RuntimeException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.NOT_FOUND, ex.getMessage(), request);
    }

    // 404 also for a notification of another user, so the answer never reveals that the id exists.
    @ExceptionHandler(NotificationNotFoundException.class)
    public Object handleNotificationNotFound(NotificationNotFoundException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.NOT_FOUND, ex.getMessage(), request);
    }

    // 403 and not 404: the caller is signed in and the record exists, but it belongs to somebody else.
    @ExceptionHandler({TransactionAccessDeniedException.class, PaymentOrderAccessDeniedException.class})
    public Object handleTransactionAccessDenied(RuntimeException ex, HttpServletRequest request) {
        eventPublisher.publishEvent(SecurityAuditEvent.accessDenied(REASON_NOT_OWNER, request.getMethod(), request.getRequestURI()));
        return buildErrorResponse(HttpStatus.FORBIDDEN, ex.getMessage(), request);
    }

    // 500 with a fixed text: the change was rolled back because its audit row could not be written. The cause (SQL, the
    // database's own message) was logged by AuditLogService and is never sent to the client.
    @ExceptionHandler(AuditLogWriteException.class)
    public Object handleAuditLogWrite(AuditLogWriteException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, ex.getMessage(), request);
    }

    @ExceptionHandler(InvalidUploadException.class)
    public Object handleInvalidUpload(InvalidUploadException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, ex.getMessage(), request);
    }

    // 413: the file is over the limit of ImageUploadService, or over spring.servlet.multipart.max-file-size.
    @ExceptionHandler({UploadTooLargeException.class, MaxUploadSizeExceededException.class})
    public Object handleUploadTooLarge(Exception ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.PAYLOAD_TOO_LARGE, MSG_UPLOAD_TOO_LARGE, request);
    }

    // 503 with a fixed text: the image storage failed; the cause was logged by ImageUploadService.
    @ExceptionHandler(FileStorageUnavailableException.class)
    public Object handleFileStorageUnavailable(FileStorageUnavailableException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), request);
    }

    // 403: PUT /api/users/{id} with another user's id. Recorded like any other 403 about somebody else's data.
    @ExceptionHandler(ProfileAccessDeniedException.class)
    public Object handleProfileAccessDenied(ProfileAccessDeniedException ex, HttpServletRequest request) {
        eventPublisher.publishEvent(SecurityAuditEvent.accessDenied(REASON_NOT_OWNER, request.getMethod(), request.getRequestURI()));
        return buildErrorResponse(HttpStatus.FORBIDDEN, ex.getMessage(), request);
    }

    // 403: an ADMIN account cannot be locked, unlocked or deleted from the admin pages; nothing was written.
    @ExceptionHandler(AdminAccountProtectedException.class)
    public Object handleAdminAccountProtected(AdminAccountProtectedException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.FORBIDDEN, ex.getMessage(), request);
    }

    // 409: the receipt is not in a state that allows the request, or another request changed it first; nothing was written.
    @ExceptionHandler(ReceiptConflictException.class)
    public Object handleReceiptConflict(ReceiptConflictException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.CONFLICT, ex.getMessage(), request);
    }

    // 409: the category is still used by a transaction or a budget, another request just created the same category name, or a
    // search reindex is already running; nothing was written.
    @ExceptionHandler({CategoryInUseException.class, CategoryNameTakenException.class, ReindexInProgressException.class})
    public Object handleConflictingState(RuntimeException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.CONFLICT, ex.getMessage(), request);
    }

    // 409: a savings transaction can only change through its savings goal; nothing was written.
    @ExceptionHandler(SavingsLedgerException.class)
    public Object handleSavingsLedger(SavingsLedgerException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.CONFLICT, ex.getMessage(), request);
    }

    // 409: a versioned row (a receipt) was changed by another request between the read and the write of this one, and the
    // whole transaction of this one was rolled back. The exception names the entity and its id, so the answer is a fixed text.
    @ExceptionHandler(OptimisticLockingFailureException.class)
    public Object handleOptimisticLockingFailure(OptimisticLockingFailureException ex, HttpServletRequest request) {
        log.warn("Optimistic locking conflict, nothing was written, uri={}", request.getRequestURI());
        return buildErrorResponse(HttpStatus.CONFLICT, MSG_CONCURRENT_CHANGE, request);
    }

    // 409 with the transaction already saved in data, so the app can open it or send the checkout again with
    // allowDuplicate=true. Nothing was written: the checkout's transaction rolled back.
    @ExceptionHandler(DuplicateReceiptException.class)
    public Object handleDuplicateReceipt(DuplicateReceiptException ex, HttpServletRequest request) {
        if (!isJsonRequest(request)) {
            return buildErrorResponse(HttpStatus.CONFLICT, ex.getMessage(), request);
        }
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiResponse.<DuplicateReceiptResponseDto>builder()
                .code(HttpStatus.CONFLICT.value())
                .message(ex.getMessage())
                .data(DuplicateReceiptResponseDto.builder()
                        .existingTransactionId(ex.getExistingTransactionId())
                        .existingTransactionDate(ex.getExistingTransactionDate())
                        .build())
                .build());
    }

    @ExceptionHandler({InsufficientBalanceException.class, InvalidRoleException.class, InvalidSortFieldException.class,
            ProfileUpdateRefusedException.class, InvalidImageUrlException.class, PaymentWebhookRejectedException.class,
            InvalidRequestException.class})
    public Object handleRejectedInput(RuntimeException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, ex.getMessage(), request);
    }

    private Object buildErrorResponse(HttpStatus status, String message, HttpServletRequest request) {
        if (isJsonRequest(request)) {
            return ResponseEntity.status(status).body(ApiResponse.<String>builder()
                    .code(status.value())
                    .message(message)
                    .build());
        }
        return new ModelAndView("error").addObject("errorMessage", message);
    }

    // The same, with the headers Spring set for the refusal (Allow, Accept) and the real code also on the error page.
    private Object buildErrorResponse(HttpStatus status, String message, HttpHeaders headers, HttpServletRequest request) {
        if (isJsonRequest(request)) {
            return ResponseEntity.status(status).headers(headers).body(ApiResponse.<String>builder()
                    .code(status.value())
                    .message(message)
                    .build());
        }
        return new ModelAndView("error", status).addObject("errorMessage", message);
    }

    // 400 with a fixed text: a body that is not JSON, or does not fit the DTO (Jackson's message names classes and fields).
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public Object handleUnreadableBody(HttpMessageNotReadableException ex, HttpServletRequest request) {
        log.warn("Unreadable request body, uri={}", request.getRequestURI());
        return buildErrorResponse(HttpStatus.BAD_REQUEST, MSG_UNREADABLE_BODY, request);
    }

    // 400: a path or query parameter of the wrong type (/api/transactions/abc).
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public Object handleArgumentTypeMismatch(MethodArgumentTypeMismatchException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, String.format(MSG_PARAMETER_INVALID, ex.getName()), request);
    }

    // 400: a multipart request without its file part (POST /api/upload without "file").
    @ExceptionHandler(MissingServletRequestPartException.class)
    public Object handleMissingRequestPart(MissingServletRequestPartException ex, HttpServletRequest request) {
        return buildErrorResponse(HttpStatus.BAD_REQUEST, "Thiếu tham số bắt buộc: " + ex.getRequestPartName(), request);
    }

    // 405: the URL exists but not for this method. The Allow header (from Spring) tells the client which ones it has.
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public Object handleMethodNotSupported(HttpRequestMethodNotSupportedException ex, HttpServletRequest request) {
        logRefusedRequest(HttpStatus.METHOD_NOT_ALLOWED, request);
        return buildErrorResponse(HttpStatus.METHOD_NOT_ALLOWED, String.format(MSG_METHOD_NOT_ALLOWED, ex.getMethod()),
                ex.getHeaders(), request);
    }

    // 415: the body is in a Content-Type the endpoint does not read (a form sent to a JSON endpoint).
    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public Object handleMediaTypeNotSupported(HttpMediaTypeNotSupportedException ex, HttpServletRequest request) {
        logRefusedRequest(HttpStatus.UNSUPPORTED_MEDIA_TYPE, request);
        return buildErrorResponse(HttpStatus.UNSUPPORTED_MEDIA_TYPE, MSG_UNSUPPORTED_MEDIA_TYPE, ex.getHeaders(), request);
    }

    // 404: no controller and no static file for this URL.
    @ExceptionHandler(NoResourceFoundException.class)
    public Object handleNoResourceFound(NoResourceFoundException ex, HttpServletRequest request) {
        logRefusedRequest(HttpStatus.NOT_FOUND, request);
        return buildErrorResponse(HttpStatus.NOT_FOUND, MSG_URL_NOT_FOUND, HttpHeaders.EMPTY, request);
    }

    // 400: a header the endpoint requires (@RequestHeader) is missing.
    @ExceptionHandler(MissingRequestHeaderException.class)
    public Object handleMissingRequestHeader(MissingRequestHeaderException ex, HttpServletRequest request) {
        logRefusedRequest(HttpStatus.BAD_REQUEST, request);
        return buildErrorResponse(HttpStatus.BAD_REQUEST, String.format(MSG_MISSING_HEADER, ex.getHeaderName()),
                HttpHeaders.EMPTY, request);
    }

    // A caller's mistake, not a fault of ours: warn level, without the stack trace.
    private void logRefusedRequest(HttpStatus status, HttpServletRequest request) {
        log.warn("Request refused with {}, method={}, uri={}", status.value(), request.getMethod(), request.getRequestURI());
    }

    // 500 with a fixed text: every exception meant for the user has its own handler above, so what reaches this one is
    // unexpected (SMTP, NullPointerException, a library), and its message stays in the log with the stack trace.
    @ExceptionHandler(RuntimeException.class)
    public Object handleRuntimeExceptions(RuntimeException ex, HttpServletRequest request) {
        log.error("Unexpected error, uri={}", request.getRequestURI(), ex);
        return buildErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, MSG_SYSTEM_ERROR, request);
    }

    @ExceptionHandler(org.springframework.security.access.AccessDeniedException.class)
    public Object handleAccessDeniedException(org.springframework.security.access.AccessDeniedException ex, HttpServletRequest request) {
        eventPublisher.publishEvent(SecurityAuditEvent.accessDenied(REASON_ROLE, request.getMethod(), request.getRequestURI()));
        if (isJsonRequest(request)) {
            return ResponseEntity.status(403).body(ApiResponse.<String>builder()
                    .code(403)
                    .message(AuditingAccessDeniedHandler.MSG_ACCESS_DENIED)
                    .build());
        }
        return new ModelAndView("error").addObject("errorMessage", "Bạn không có quyền truy cập tính năng này.");
    }

    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public Object handleDataIntegrity(Exception ex, HttpServletRequest request) {
        if (isJsonRequest(request)) {
            return ResponseEntity.status(409).body(ApiResponse.<String>builder()
                    .code(409)
                    .message("Lỗi dữ liệu: Dữ liệu đã tồn tại hoặc đang vướng khóa ngoại (Đã có giao dịch).")
                    .build());
        }
        return new ModelAndView("error").addObject("errorMessage", "Lỗi ràng buộc dữ liệu cơ sở dữ liệu.");
    }

    // 500 with a fixed text: a JDBC/Hibernate message carries the SQL and table/column names, so it stays in the log.
    // The more specific subclasses (DataIntegrityViolation, OptimisticLockingFailure) still reach their own handlers.
    @ExceptionHandler(DataAccessException.class)
    public Object handleDataAccess(DataAccessException ex, HttpServletRequest request) {
        log.error("Database error, uri={}", request.getRequestURI(), ex);
        return buildErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, MSG_SYSTEM_ERROR, request);
    }

    // 500 with a fixed text: an unexpected error's message may expose internals, so it stays in the log.
    @ExceptionHandler(Exception.class)
    public Object handleAllExceptions(Exception ex, HttpServletRequest request) {
        log.error("Unhandled error, uri={}", request.getRequestURI(), ex);
        return buildErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, MSG_SYSTEM_ERROR, request);
    }
}