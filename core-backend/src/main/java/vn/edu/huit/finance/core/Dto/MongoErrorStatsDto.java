package vn.edu.huit.finance.core.Dto;

import lombok.Data;

@Data
public class MongoErrorStatsDto {
    private String _id; // Tương ứng với fieldError
    private long count;
}
