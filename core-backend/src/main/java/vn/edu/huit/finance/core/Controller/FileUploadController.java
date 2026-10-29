package vn.edu.huit.finance.core.Controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import vn.edu.huit.finance.core.Service.Storage.ImageUploadService;

import java.util.Map;

@RestController
@RequestMapping("/api/upload")
public class FileUploadController {

    private static final String URL_KEY = "url";

    @Autowired
    private ImageUploadService imageUploadService;

    /**
     * Ảnh hóa đơn của app. Thân trả về giữ dạng {"url": ...} mà app đang đọc. File rỗng hoặc không phải ảnh là 400,
     * quá lớn là 413, kho ảnh lỗi là 503 (GlobalExceptionHandler).
     */
    @PostMapping
    public ResponseEntity<Map<String, String>> uploadFile(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(Map.of(URL_KEY, imageUploadService.upload(file)));
    }
}
