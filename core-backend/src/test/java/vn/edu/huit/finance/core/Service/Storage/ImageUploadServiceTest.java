package vn.edu.huit.finance.core.Service.Storage;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import vn.edu.huit.finance.core.Exception.FileStorageUnavailableException;
import vn.edu.huit.finance.core.Exception.InvalidUploadException;
import vn.edu.huit.finance.core.Exception.UploadTooLargeException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** POST /api/upload (A15): only JPEG, PNG and WEBP up to the limit reach the storage; its failures stay in the log. */
@ExtendWith(MockitoExtension.class)
class ImageUploadServiceTest {

    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0x10, 'J', 'F', 'I', 'F', 0, 1};
    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n', 0, 0, 0, 0x0D};
    private static final byte[] WEBP = "RIFF$\u0000\u0000\u0000WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1);
    private static final String LINK = "https://res.cloudinary.com/demo/image/upload/v1/r.jpg";

    @Mock private FileStorageService fileStorageService;
    @InjectMocks private ImageUploadService service;

    private static MockMultipartFile file(byte[] content, String contentType) {
        return new MockMultipartFile("file", "receipt.jpg", contentType, content);
    }

    @ParameterizedTest
    @ValueSource(strings = {"application/octet-stream", "image/jpeg"})
    void aJpegIsUploaded_evenSentAsOctetStreamLikeTheApp(String contentType) throws IOException {
        when(fileStorageService.uploadFile(any())).thenReturn(LINK);

        assertEquals(LINK, service.upload(file(JPEG, contentType)));
    }

    @Test
    void pngAndWebpAreUploadedToo() throws IOException {
        when(fileStorageService.uploadFile(any())).thenReturn(LINK);

        assertEquals(LINK, service.upload(file(PNG, "image/png")));
        assertEquals(LINK, service.upload(file(WEBP, null)));
    }

    @Test
    void aFileThatIsNotAnImageIsRefused_whateverItsContentTypeSays() {
        byte[] script = "<script>alert(1)</script>".getBytes(StandardCharsets.UTF_8);

        assertThrows(InvalidUploadException.class, () -> service.upload(file(script, "image/jpeg")));
        verifyNoInteractions(fileStorageService);
    }

    @ParameterizedTest
    @ValueSource(strings = {"text/html", "application/pdf", "image/gif"})
    void aContentTypeThatIsNotAnAcceptedImageIsRefused(String contentType) {
        assertThrows(InvalidUploadException.class, () -> service.upload(file(JPEG, contentType)));
        verifyNoInteractions(fileStorageService);
    }

    @Test
    void anEmptyFileIsRefused() {
        assertThrows(InvalidUploadException.class, () -> service.upload(file(new byte[0], "image/jpeg")));
        verifyNoInteractions(fileStorageService);
    }

    @Test
    void aFileOverTheLimitIsRefusedBeforeItIsRead() {
        MockMultipartFile big = mock(MockMultipartFile.class);
        when(big.isEmpty()).thenReturn(false);
        when(big.getSize()).thenReturn(ImageUploadService.MAX_UPLOAD_BYTES + 1);

        assertThrows(UploadTooLargeException.class, () -> service.upload(big));
        verifyNoInteractions(fileStorageService);
    }

    @Test
    void aStorageFailureIsAFixedText_neverItsCause() throws IOException {
        when(fileStorageService.uploadFile(any())).thenThrow(new IOException("Invalid api_key 1234567890"));

        FileStorageUnavailableException ex =
                assertThrows(FileStorageUnavailableException.class, () -> service.upload(file(JPEG, "image/jpeg")));

        assertEquals(ImageUploadService.MSG_STORAGE_FAILED, ex.getMessage());
        assertFalse(ex.getMessage().contains("api_key"));
    }

    @Test
    void aStorageThatReturnsNoLinkIsAFailureToo() throws IOException {
        when(fileStorageService.uploadFile(any())).thenReturn(" ");

        assertThrows(FileStorageUnavailableException.class, () -> service.upload(file(JPEG, "image/jpeg")));
    }
}
