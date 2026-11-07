package vn.edu.huit.finance.core.Document.Backup;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Dto.CategoryResponseDto;
import vn.edu.huit.finance.core.Entity.Category;

import java.time.LocalDateTime;

/**
 * Bản sao dự phòng nóng của thực thể {@link Category} (bảng {@code categories}) trên MongoDB.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pg_backup_categories")
public class PgBackupCategoryDocument {

    @Id
    private Long id;

    private String name;

    private String type;

    @Indexed
    private Long ownerId;

    private long ownerKey;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    private LocalDateTime mirroredAt;

    public static PgBackupCategoryDocument from(Category category) {
        Long ownerId = category.getOwner() != null ? category.getOwner().getId() : null;
        return PgBackupCategoryDocument.builder()
                .id(category.getId())
                .name(category.getName())
                .type(category.getType())
                .ownerId(ownerId)
                .ownerKey(category.getOwnerKey())
                .createdAt(category.getCreatedAt())
                .updatedAt(category.getUpdatedAt())
                .mirroredAt(LocalDateTime.now())
                .build();
    }

    public CategoryResponseDto toResponseDto() {
        return CategoryResponseDto.builder()
                .id(this.id)
                .name(this.name)
                .type(this.type)
                .build();
    }
}
