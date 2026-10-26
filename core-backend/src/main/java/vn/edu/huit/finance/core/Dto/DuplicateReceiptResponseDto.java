package vn.edu.huit.finance.core.Dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/** The data of the 409 answered to a scanned receipt that looks already saved: which transaction, and when it happened. */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DuplicateReceiptResponseDto {
    private Long existingTransactionId;
    private LocalDateTime existingTransactionDate;
}
