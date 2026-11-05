package vn.edu.huit.finance.core.Document.Backup;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Entity.User;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Bản sao dự phòng nóng của thực thể {@link User} (bảng {@code users}) trên MongoDB.
 * Phục vụ xác thực JWT dự phòng ({@code JwtAuthFilter}, {@code CurrentUserProvider}),
 * đọc hồ sơ {@code GET /api/users/me} khi PostgreSQL sập và khôi phục ngược về PostgreSQL.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pg_backup_users")
public class PgBackupUserDocument {

    @Id
    private Long id;

    @Indexed(unique = true)
    private String username;

    private String password;

    @Indexed(unique = true)
    private String email;

    private String phone;

    private String role;

    private boolean active;

    private BigDecimal walletBalance;

    private String aiLabel;

    private Integer credentialsVersion;

    private LocalDateTime lastLoginTime;

    private LocalDateTime lastActionTime;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    private LocalDateTime mirroredAt;

    public static PgBackupUserDocument from(User user) {
        return PgBackupUserDocument.builder()
                .id(user.getId())
                .username(user.getUsername())
                .password(user.getPassword())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .active(user.isActive())
                .walletBalance(user.getWalletBalance() != null ? user.getWalletBalance() : BigDecimal.ZERO)
                .aiLabel(user.getAiLabel())
                .credentialsVersion(user.getCredentialsVersion() != null ? user.getCredentialsVersion() : 0)
                .lastLoginTime(user.getLastLoginTime())
                .lastActionTime(user.getLastActionTime())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .mirroredAt(LocalDateTime.now())
                .build();
    }

    public User toEntity() {
        User user = new User();
        user.setId(this.id);
        user.setUsername(this.username);
        user.setPassword(this.password);
        user.setEmail(this.email);
        user.setPhone(this.phone);
        user.setRole(this.role != null ? this.role : "ROLE_USER");
        user.setActive(this.active);
        user.setWalletBalance(this.walletBalance != null ? this.walletBalance : BigDecimal.ZERO);
        user.setAiLabel(this.aiLabel);
        user.setCredentialsVersion(this.credentialsVersion != null ? this.credentialsVersion : 0);
        user.setLastLoginTime(this.lastLoginTime);
        user.setLastActionTime(this.lastActionTime);
        user.setCreatedAt(this.createdAt);
        user.setUpdatedAt(this.updatedAt);
        return user;
    }
}
