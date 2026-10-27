package vn.edu.huit.finance.core.Service.Search;

import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import vn.edu.huit.finance.core.Config.SearchEngineType;
import vn.edu.huit.finance.core.Dto.TransactionResponseDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchRequestDto;
import vn.edu.huit.finance.core.Dto.TransactionSearchResponseDto;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * The search of the caller's own transactions. The engine (Elasticsearch when configured, PostgreSQL otherwise or when
 * Elasticsearch fails) only decides which ids match and in what order; the transactions themselves are always read back
 * from PostgreSQL by id <em>and owner</em>, so a stale or foreign entry of the index can neither show a row that is gone
 * nor another user's row.
 */
@Slf4j
@Service
public class TransactionSearchService {

    private final CurrentUserProvider currentUserProvider;
    private final TransactionRepository transactionRepo;
    private final SearchEngineType configuredEngine;
    private final PostgresTransactionSearchEngine postgresEngine;
    private final Optional<ElasticsearchTransactionSearchEngine> elasticsearchEngine;

    public TransactionSearchService(CurrentUserProvider currentUserProvider,
                                    TransactionRepository transactionRepo,
                                    SearchEngineType configuredEngine,
                                    PostgresTransactionSearchEngine postgresEngine,
                                    Optional<ElasticsearchTransactionSearchEngine> elasticsearchEngine) {
        this.currentUserProvider = currentUserProvider;
        this.transactionRepo = transactionRepo;
        this.configuredEngine = configuredEngine;
        this.postgresEngine = postgresEngine;
        this.elasticsearchEngine = elasticsearchEngine;
    }

    public TransactionSearchResponseDto search(TransactionSearchRequestDto request) {
        Long userId = currentUserProvider.getCurrentUser().getId();
        String q = request.getQ().trim();
        Pageable page = PageRequest.of(request.getPage(), request.getSize());

        SearchEngineType answeredBy = SearchEngineType.POSTGRES;
        TransactionSearchEngine.SearchHits hits = null;
        if (configuredEngine == SearchEngineType.ELASTICSEARCH && elasticsearchEngine.isPresent()) {
            try {
                hits = elasticsearchEngine.get().hits(userId, q, page);
                answeredBy = SearchEngineType.ELASTICSEARCH;
            } catch (RuntimeException e) {
                // Elasticsearch is down, slow or answered something unusable: PostgreSQL answers instead.
                // One line per search while it is down; the stack trace only at debug, so an outage does not flood the log.
                log.warn("Elasticsearch search failed, falling back to PostgreSQL, userId={}: {}", userId, e.toString());
                log.debug("Elasticsearch search failure", e);
            }
        }
        if (hits == null) {
            hits = postgresEngine.hits(userId, q, page);
        }

        return TransactionSearchResponseDto.builder()
                .items(load(hits.ids(), userId))
                .total(hits.total())
                .engine(answeredBy.name().toLowerCase(Locale.ROOT))
                .build();
    }

    /** The caller's rows for {@code ids} in the order of {@code ids}; an id without a row of the caller is dropped. */
    private List<TransactionResponseDto> load(List<Long> ids, Long userId) {
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, Transaction> byId = transactionRepo.findAllByIdInAndUserIdWithReceipt(ids, userId).stream()
                .collect(Collectors.toMap(Transaction::getId, Function.identity()));
        return ids.stream()
                .map(byId::get)
                .filter(java.util.Objects::nonNull)
                .map(TransactionResponseDto::from)
                .toList();
    }
}
