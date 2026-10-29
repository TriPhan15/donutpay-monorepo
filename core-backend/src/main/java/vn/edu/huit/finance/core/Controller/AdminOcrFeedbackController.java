package vn.edu.huit.finance.core.Controller;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Document.OcrField;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.OcrAnalyticsResponseDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackFilterRequestDto;
import vn.edu.huit.finance.core.Dto.OcrFeedbackResponseDto;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.OcrMongoService;

import java.time.LocalDate;

/**
 * Những chỗ người dùng sửa kết quả OCR của AI (ocr_feedbacks trong MongoDB) và thống kê chất lượng OCR. Chỉ cho quản trị
 * viên: luật /api/admin/** của SecurityConfig và @PreAuthorize.
 */
@RestController
@RequestMapping("/api/admin/ocr-feedbacks")
@PreAuthorize(Roles.HAS_ADMIN)
@Validated
public class AdminOcrFeedbackController {

    static final int DEFAULT_PAGE_SIZE = 20;
    static final int MIN_PAGE_SIZE = 1;
    static final int MAX_PAGE_SIZE = 100;

    private static final String DEFAULT_SORT = "reportedAt,desc";
    private static final String SORT_PATTERN = "^(reportedAt|updatedAt)(,(asc|desc))?$";
    private static final String SORT_SEPARATOR = ",";
    private static final int SORT_DIRECTION_INDEX = 1;
    private static final String MSG_SORT_INVALID = "sort phải là reportedAt hoặc updatedAt, kèm ,asc hoặc ,desc";

    private static final String MSG_LIST_OK = "Lấy danh sách phản hồi OCR thành công";
    private static final String MSG_RESOLVE_OK = "Đã đánh dấu phản hồi OCR là đã xử lý";
    private static final String MSG_DELETE_OK = "Đã xóa phản hồi OCR";
    private static final String MSG_ANALYTICS_OK = "Lấy thống kê chất lượng OCR thành công";

    private final OcrMongoService ocrMongoService;

    public AdminOcrFeedbackController(OcrMongoService ocrMongoService) {
        this.ocrMongoService = ocrMongoService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<OcrFeedbackResponseDto>>> list(
            @RequestParam(required = false) OcrField field,
            @RequestParam(required = false) Boolean resolved,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "" + DEFAULT_PAGE_SIZE) @Min(MIN_PAGE_SIZE) @Max(MAX_PAGE_SIZE) int size,
            @RequestParam(defaultValue = DEFAULT_SORT) @Pattern(regexp = SORT_PATTERN, message = MSG_SORT_INVALID) String sort) {
        OcrFeedbackFilterRequestDto filter = OcrFeedbackFilterRequestDto.builder()
                .field(field).resolved(resolved).from(from).to(to).build();
        return ApiResponses.respond(HttpStatus.OK, MSG_LIST_OK,
                ocrMongoService.findFeedbacks(filter, PageRequest.of(page, size, parseSort(sort))));
    }

    @PatchMapping("/{id}/resolve")
    public ResponseEntity<ApiResponse<OcrFeedbackResponseDto>> resolve(@PathVariable String id) {
        return ApiResponses.respond(HttpStatus.OK, MSG_RESOLVE_OK, ocrMongoService.resolveFeedback(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable String id) {
        ocrMongoService.deleteFeedback(id);
        return ApiResponses.respond(HttpStatus.OK, MSG_DELETE_OK, null);
    }

    @GetMapping("/analytics")
    public ResponseEntity<ApiResponse<OcrAnalyticsResponseDto>> analytics(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponses.respond(HttpStatus.OK, MSG_ANALYTICS_OK, ocrMongoService.analytics(from, to));
    }

    /** "reportedAt,desc" (đã qua @Pattern) thành Sort; thiếu hướng thì giảm dần như mặc định. */
    private static Sort parseSort(String sort) {
        String[] parts = sort.split(SORT_SEPARATOR);
        Sort.Direction direction = parts.length > SORT_DIRECTION_INDEX
                ? Sort.Direction.fromString(parts[SORT_DIRECTION_INDEX]) : Sort.Direction.DESC;
        return Sort.by(direction, parts[0]);
    }
}
