package vn.edu.huit.finance.core.Document.Backup;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Entity.RevokedToken;

import java.time.LocalDateTime;

/**
 * Bản sao dự phòng nóng của thực thể {@link RevokedToken} (bảng {@code revoked_tokens}) trên MongoDB.
 * Đảm bảo các JWT đã bị thu hồi (logout, refresh, đổi mật khẩu) vẫn bị từ chối khi PostgreSQL sập
 * hoặc khi ứng dụng khởi động lại trong chế độ Failover.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pg_backup_revoked_tokens")
public class PgBackupRevokedTokenDocument {

    @Id
    private String tokenHash;

    @Indexed
    private LocalDateTime expiresAt;

    private LocalDateTime revokedAt;

    private LocalDateTime mirroredAt;

    public static PgBackupRevokedTokenDocument from(RevokedToken token) {
        return PgBackupRevokedTokenDocument.builder()
                .tokenHash(token.getTokenHash())
                .expiresAt(token.getExpiresAt())
                .revokedAt(token.getRevokedAt())
                .mirroredAt(LocalDateTime.now())
                .build();
    }
}
