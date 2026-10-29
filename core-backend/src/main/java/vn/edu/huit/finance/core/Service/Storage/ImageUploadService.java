package vn.edu.huit.finance.core.Service.Storage;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import vn.edu.huit.finance.core.Exception.FileStorageUnavailableException;
import vn.edu.huit.finance.core.Exception.InvalidUploadException;
import vn.edu.huit.finance.core.Exception.UploadTooLargeException;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Optional;
import java.util.Set;

/**
 * POST /api/upload: ảnh hóa đơn từ app được đưa lên kho ảnh (Cloudinary). Chỉ nhận JPEG, PNG, WEBP và tối đa
 * {@link #MAX_UPLOAD_BYTES}. Định dạng được nhận theo các byte đầu file, vì app gửi Content-Type
 * application/octet-stream; một Content-Type khác ảnh thì bị từ chối luôn.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ImageUploadService {

    /** Cùng giới hạn với ai-service (MAX_UPLOAD_BYTES của /donut/scan). */
    public static final long MAX_UPLOAD_BYTES = 15L * 1024 * 1024;

    static final String MSG_EMPTY = "File ảnh rỗng";
    static final String MSG_TOO_LARGE = "Ảnh quá lớn (tối đa 15MB), vui lòng chụp lại với độ phân giải thấp hơn";
    static final String MSG_UNSUPPORTED = "Chỉ nhận ảnh JPEG, PNG hoặc WEBP";
    static final String MSG_STORAGE_FAILED = "Không tải được ảnh lên, vui lòng thử lại sau";

    private static final Set<String> ACCEPTED_CONTENT_TYPES =
            Set.of("image/jpeg", "image/jpg", "image/png", "image/webp", "application/octet-stream");
    private static final int HEADER_BYTES = 12;
    private static final byte[] JPEG_MAGIC = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] PNG_MAGIC = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'};
    private static final byte[] RIFF = "RIFF".getBytes(StandardCharsets.US_ASCII);
    private static final byte[] WEBP = "WEBP".getBytes(StandardCharsets.US_ASCII);
    private static final int WEBP_TAG_OFFSET = 8;

    private final FileStorageService fileStorageService;

    /** Kiểm tra rồi đưa ảnh lên kho; trả về link của ảnh. */
    public String upload(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new InvalidUploadException(MSG_EMPTY);
        }
        if (file.getSize() > MAX_UPLOAD_BYTES) {
            log.warn("Upload refused: too large, size={}", file.getSize());
            throw new UploadTooLargeException(MSG_TOO_LARGE);
        }
        String contentType = file.getContentType();
        if (contentType != null && !ACCEPTED_CONTENT_TYPES.contains(contentType.toLowerCase())) {
            log.warn("Upload refused: content type {}", contentType);
            throw new InvalidUploadException(MSG_UNSUPPORTED);
        }
        String format = detectFormat(header(file)).orElseThrow(() -> {
            log.warn("Upload refused: not a JPEG, PNG or WEBP image, size={}", file.getSize());
            return new InvalidUploadException(MSG_UNSUPPORTED);
        });

        String url;
        try {
            url = fileStorageService.uploadFile(file);
        } catch (IOException | RuntimeException e) {
            log.error("Image upload to storage failed, format={}, size={}", format, file.getSize(), e);
            throw new FileStorageUnavailableException(MSG_STORAGE_FAILED, e);
        }
        if (url == null || url.isBlank()) {
            log.error("Image storage returned no link, format={}, size={}", format, file.getSize());
            throw new FileStorageUnavailableException(MSG_STORAGE_FAILED);
        }
        log.info("Image uploaded, format={}, size={}", format, file.getSize());
        return url;
    }

    private static byte[] header(MultipartFile file) {
        try (InputStream in = file.getInputStream()) {
            return in.readNBytes(HEADER_BYTES);
        } catch (IOException e) {
            log.warn("Upload refused: file could not be read", e);
            throw new InvalidUploadException(MSG_UNSUPPORTED);
        }
    }

    /** "jpeg", "png" hoặc "webp" theo các byte đầu file; rỗng khi không phải ba định dạng đó. */
    static Optional<String> detectFormat(byte[] head) {
        if (startsWith(head, JPEG_MAGIC, 0)) {
            return Optional.of("jpeg");
        }
        if (startsWith(head, PNG_MAGIC, 0)) {
            return Optional.of("png");
        }
        if (startsWith(head, RIFF, 0) && startsWith(head, WEBP, WEBP_TAG_OFFSET)) {
            return Optional.of("webp");
        }
        return Optional.empty();
    }

    private static boolean startsWith(byte[] data, byte[] prefix, int offset) {
        return data.length >= offset + prefix.length
                && Arrays.equals(data, offset, offset + prefix.length, prefix, 0, prefix.length);
    }
}
