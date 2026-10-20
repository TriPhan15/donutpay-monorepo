package vn.edu.huit.finance.core.Controller;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.edu.huit.finance.core.Document.OcrRawLog;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Repository.Mongo.OcrRawLogRepository;

@RestController
@RequestMapping("/api/admin/ocr-logs")
@RequiredArgsConstructor
public class OcrMongoController {

    private final OcrRawLogRepository ocrRawLogRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<Page<OcrRawLog>>> getOcrLogs(Pageable pageable) {
        Page<OcrRawLog> page = ocrRawLogRepository.findAll(pageable);
        return ResponseEntity.ok(ApiResponse.<Page<OcrRawLog>>builder()
                .code(200)
                .message("Success")
                .data(page)
                .build());
    }
}
