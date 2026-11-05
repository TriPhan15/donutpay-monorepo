package vn.edu.huit.finance.core.Document.Backup;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;
import vn.edu.huit.finance.core.Dto.BudgetResponseDto;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.Category;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Bản sao dự phòng nóng của thực thể {@link Budget} (bảng {@code budgets}) trên MongoDB.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "pg_backup_budgets")
public class PgBackupBudgetDocument {

    @Id
    private Long id;

    @Indexed
    private Long userId;

    private Long categoryId;

    private String categoryName;

    private long categoryKey;

    private BigDecimal amount;

    private String periodType;

    private LocalDate startDate;

    private LocalDate endDate;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    private LocalDateTime mirroredAt;

    public static PgBackupBudgetDocument from(Budget budget) {
        Category category = budget.getCategory();
        Long cid = category != null ? category.getId() : null;
        return PgBackupBudgetDocument.builder()
                .id(budget.getId())
                .userId(budget.getUser() != null ? budget.getUser().getId() : null)
                .categoryId(cid)
                .categoryName(category != null ? category.getName() : null)
                .categoryKey(Budget.categoryKeyOf(cid))
                .amount(budget.getAmount())
                .periodType(budget.getPeriodType() != null ? budget.getPeriodType().name() : BudgetPeriodType.MONTH.name())
                .startDate(budget.getStartDate())
                .endDate(budget.getEndDate())
                .createdAt(budget.getCreatedAt())
                .updatedAt(budget.getUpdatedAt())
                .mirroredAt(LocalDateTime.now())
                .build();
    }

    public BudgetResponseDto toResponseDto() {
        BudgetPeriodType resolvedPeriod = BudgetPeriodType.MONTH;
        if (this.periodType != null) {
            try {
                resolvedPeriod = BudgetPeriodType.valueOf(this.periodType);
            } catch (IllegalArgumentException ignored) {
                resolvedPeriod = BudgetPeriodType.MONTH;
            }
        }
        return BudgetResponseDto.builder()
                .id(this.id)
                .categoryId(this.categoryId)
                .categoryName(this.categoryName)
                .amount(this.amount)
                .periodType(resolvedPeriod)
                .startDate(this.startDate)
                .endDate(this.endDate)
                .build();
    }
}
