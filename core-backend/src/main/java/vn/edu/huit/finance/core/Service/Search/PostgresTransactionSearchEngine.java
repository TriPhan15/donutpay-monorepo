package vn.edu.huit.finance.core.Service.Search;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Repository.TransactionRepository;

/** The search in PostgreSQL itself: a case-insensitive LIKE over the text fields, newest first. Always available. */
@Component
public class PostgresTransactionSearchEngine implements TransactionSearchEngine {

    private final TransactionRepository transactionRepo;

    public PostgresTransactionSearchEngine(TransactionRepository transactionRepo) {
        this.transactionRepo = transactionRepo;
    }

    @Override
    public SearchHits hits(Long userId, String q, Pageable page) {
        Page<Long> ids = transactionRepo.searchIdsByText(userId, TransactionRepository.likePattern(q), page);
        return new SearchHits(ids.getContent(), ids.getTotalElements());
    }
}
