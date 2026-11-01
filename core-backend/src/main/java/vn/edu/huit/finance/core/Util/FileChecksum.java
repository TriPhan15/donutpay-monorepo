package vn.edu.huit.finance.core.Util;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/** SHA-256 của một file, đọc từng khối nên file sao lưu lớn không bị nạp hết vào bộ nhớ. */
public final class FileChecksum {

    private static final String ALGORITHM = "SHA-256";
    private static final int READ_BUFFER_BYTES = 64 * 1024;

    private FileChecksum() {
    }

    /** Chuỗi hex thường (64 ký tự) của SHA-256; ném IOException khi không đọc được file. */
    public static String sha256(Path file) throws IOException {
        MessageDigest digest = newDigest();
        byte[] buffer = new byte[READ_BUFFER_BYTES];
        try (InputStream in = Files.newInputStream(file)) {
            int read;
            while ((read = in.read(buffer)) != -1) {
                digest.update(buffer, 0, read);
            }
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static MessageDigest newDigest() {
        try {
            return MessageDigest.getInstance(ALGORITHM);
        } catch (NoSuchAlgorithmException e) {
            // Every Java runtime has SHA-256 (the platform specification requires it).
            throw new IllegalStateException(ALGORITHM + " is not available", e);
        }
    }
}
