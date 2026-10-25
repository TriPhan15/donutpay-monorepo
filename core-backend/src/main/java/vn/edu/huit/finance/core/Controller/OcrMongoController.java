package vn.edu.huit.finance.core.Controller;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.OcrRawLogResponseDto;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.OcrMongoService;

/** Nhật ký OCR thô trong MongoDB, chỉ cho quản trị viên (luật /api/admin/** của SecurityConfig và @PreAuthorize). */
@RestController
@RequestMapping("/api/admin/ocr-logs")
@PreAuthorize(Roles.HAS_ADMIN)
@RequiredArgsConstructor
public class OcrMongoController {

    private static final String MSG_OCR_LOGS_OK = "Lấy nhật ký OCR thành công";

    private final OcrMongoService ocrMongoService;

    @GetMapping
    public ResponseEntity<ApiResponse<Page<OcrRawLogResponseDto>>> getOcrLogs(Pageable pageable) {
        return ApiResponses.respond(HttpStatus.OK, MSG_OCR_LOGS_OK, ocrMongoService.getOcrLogs(pageable));
    }
}
