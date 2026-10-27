package vn.edu.huit.finance.core.Dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

/** One page of search results: the matching transactions, how many there are in all, and the engine that answered. */
@Getter
@Builder
public class TransactionSearchResponseDto {

    private final List<TransactionResponseDto> items;
    private final long total;
    /** {@code "elasticsearch"} or {@code "postgres"}: the engine that actually answered, which is PostgreSQL after a fallback. */
    private final String engine;
}
