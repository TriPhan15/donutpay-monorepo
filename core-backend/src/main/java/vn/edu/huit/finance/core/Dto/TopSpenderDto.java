package vn.edu.huit.finance.core.Dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/** A user and the sum of their expenses in one month, for the admin leaderboard (Redis sorted set of that month). */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TopSpenderDto {
    private Long userId;
    private String username;
    private BigDecimal totalSpent;
}
