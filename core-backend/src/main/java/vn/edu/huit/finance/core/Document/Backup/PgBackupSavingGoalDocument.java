package vn.edu.huit.finance.core.Document.Backup;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Entity.SavingGoal;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Bản sao dự phòng nóng của thực thể {@link SavingGoal} (bảng {@code saving_goals}) trên MongoDB.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pg_backup_saving_goals")
public class PgBackupSavingGoalDocument {

    @Id
    private Long id;

    @Indexed
    private Long userId;

    private String title;

    private BigDecimal targetAmount;

    private BigDecimal currentAmount;

    private String deadline;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    private LocalDateTime mirroredAt;

    public static PgBackupSavingGoalDocument from(SavingGoal goal) {
        return PgBackupSavingGoalDocument.builder()
                .id(goal.getId())
                .userId(goal.getUser() != null ? goal.getUser().getId() : null)
                .title(goal.getTitle())
                .targetAmount(goal.getTargetAmount())
                .currentAmount(goal.getCurrentAmount() != null ? goal.getCurrentAmount() : BigDecimal.ZERO)
                .deadline(goal.getDeadline())
                .createdAt(goal.getCreatedAt())
                .updatedAt(goal.getUpdatedAt())
                .mirroredAt(LocalDateTime.now())
                .build();
    }

    public SavingGoalDto toResponseDto() {
        return SavingGoalDto.builder()
                .id(this.id)
                .title(this.title)
                .target(this.targetAmount)
                .current(this.currentAmount != null ? this.currentAmount : BigDecimal.ZERO)
                .deadline(this.deadline)
                .build();
    }
}
