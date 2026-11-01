package vn.edu.huit.finance.core.Util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** SHA-256 của file sao lưu: dùng vector chuẩn của NIST. */
class FileChecksumTest {

    @TempDir private Path dir;

    @Test
    void theHashOfAbcIsTheNistVector() throws IOException {
        Path file = Files.writeString(dir.resolve("abc.sql"), "abc", StandardCharsets.UTF_8);

        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", FileChecksum.sha256(file));
    }

    @Test
    void theHashOfAnEmptyFileIsTheHashOfNoBytes() throws IOException {
        Path file = Files.createFile(dir.resolve("empty.sql"));

        assertEquals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", FileChecksum.sha256(file));
    }

    @Test
    void aFileLargerThanTheReadBufferIsHashedWhole() throws IOException {
        byte[] content = new byte[300_000];
        for (int i = 0; i < content.length; i++) content[i] = (byte) (i % 251);
        Path file = Files.write(dir.resolve("big.sql"), content);
        byte[] changedLast = content.clone();
        changedLast[changedLast.length - 1] ^= 1;
        Path other = Files.write(dir.resolve("big2.sql"), changedLast);

        assertEquals(64, FileChecksum.sha256(file).length());
        assertNotEquals(FileChecksum.sha256(file), FileChecksum.sha256(other), "one flipped bit in the last byte changes the hash");
    }

    @Test
    void aMissingFileIsAnIoError() {
        assertThrows(NoSuchFileException.class, () -> FileChecksum.sha256(dir.resolve("none.sql")));
    }
}
