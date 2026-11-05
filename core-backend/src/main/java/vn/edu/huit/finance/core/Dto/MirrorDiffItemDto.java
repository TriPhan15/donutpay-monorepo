package vn.edu.huit.finance.core.Dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Thông tin đối soát chênh lệch của từng bản ghi (Record-level Diff) giữa PostgreSQL và MongoDB Standby
 * để Quản trị viên kiểm tra và quyết định hướng xử lý (Human-in-the-Loop).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MirrorDiffItemDto {

    /** Tên Collection trên MongoDB (ví dụ: pg_backup_transactions). */
    private String mongoCollection;

    /** Tên bảng tương ứng trên PostgreSQL (ví dụ: transactions). */
    private String postgresTable;

    /** Khóa chính (ID) của bản ghi đang bị lệch. */
    private Long recordId;

    /**
     * Loại chênh lệch:
     * - ONLY_IN_MONGO: Chỉ tồn tại trên MongoDB (thiếu trên PostgreSQL).
     * - ONLY_IN_POSTGRES: Chỉ tồn tại trên PostgreSQL (thiếu trên MongoDB).
     * - VALUE_MISMATCH: Tồn tại ở cả 2 bên nhưng lệch số tiền / số dư ví.
     */
    private String diffType;

    /** Tiêu đề tóm tắt bản ghi (ví dụ: Giao dịch #4782 - User #10). */
    private String title;

    /** Trạng thái / Giá trị của bản ghi phía PostgreSQL. */
    private String postgresSummary;

    /** Trạng thái / Giá trị của bản ghi phía MongoDB. */
    private String mongoSummary;
}
