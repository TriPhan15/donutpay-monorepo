package vn.edu.huit.finance.core.Service.Search;

import org.springframework.data.domain.Pageable;

import java.util.List;

/**
 * Finds which of a user's transactions match a text. An engine only returns ids, in the order of its ranking: the rows are
 * always read back from PostgreSQL, the source of truth, by TransactionSearchService.
 */
public interface TransactionSearchEngine {

    /** The ids of one page of hits (best first) and the number of hits in all. */
    record SearchHits(List<Long> ids, long total) {
    }

    /** Hits of {@code q} among the transactions of {@code userId} and nobody else. */
    SearchHits hits(Long userId, String q, Pageable page);
}
