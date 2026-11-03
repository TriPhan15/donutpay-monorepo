package vn.edu.huit.finance.core.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Entity.BackupFailure;

import java.time.LocalDateTime;

/**
 * Kết quả một lần sao lưu tự động, cho trang Sao lưu. Nằm trong MongoDB chứ không trong PostgreSQL: khôi phục PostgreSQL
 * thay cả bảng này bằng nội dung bản sao lưu, và lần chạy vừa xong sẽ biến mất. Không giữ chuỗi kết nối, mật khẩu hay
 * thông điệp lỗi thô; lỗi chỉ là một {@link BackupFailure}.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "backup_runs")
public class BackupRun {

    @Id
    private String id;

    private LocalDateTime startedAt;

    @Indexed
    private LocalDateTime finishedAt;

    private boolean success;

    /** Tên file trên đĩa; null khi pg_dump không tạo được file. */
    private String fileName;

    private Long sizeBytes;

    private String sha256;

    /** Bản sao còn nằm trong thư mục backups/ sau lần chạy này. */
    private boolean onDisk;

    /** Bản sao đã lưu vào MongoDB GridFS. */
    private boolean inMongo;

    /** Bước đã hỏng; null khi thành công. */
    private BackupFailure failure;
}
