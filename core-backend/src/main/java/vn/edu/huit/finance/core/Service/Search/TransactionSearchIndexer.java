package vn.edu.huit.finance.core.Service.Search;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.IndexOperations;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import vn.edu.huit.finance.core.Config.SearchConfig;
import vn.edu.huit.finance.core.Config.SearchEngineType;
import vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Repository.TransactionRepository;

import java.util.List;

/**
 * Keeps the Elasticsearch index of the transactions in step with PostgreSQL, which stays the source of truth. Only exists
 * with {@code app.search.engine=elasticsearch}.
 * <ul>
 *   <li>after every committed write of a transaction, the row is read back from PostgreSQL and indexed whole (or its
 *       document deleted), never patched from the event, so a lost or repeated event heals on the next change;</li>
 *   <li>at start-up the index is created from its settings and mapping when it is missing;</li>
 *   <li>{@link #reindexAll} rebuilds it from scratch, for an administrator.</li>
 * </ul>
 * A failure of Elasticsearch in the first two is logged and goes no further: it never reaches the PostgreSQL write that
 * caused it, nor stops the application from starting.
 */
@Slf4j
@Service
@ConditionalOnProperty(name = SearchConfig.ENGINE_PROPERTY, havingValue = SearchEngineType.ELASTICSEARCH_VALUE)
public class TransactionSearchIndexer {

    /** Rows read from PostgreSQL and sent to Elasticsearch in one bulk request by {@link #reindexAll}. */
    static final int PAGE_SIZE = 500;

    private final ElasticsearchOperations operations;
    private final TransactionRepository transactionRepo;

    public TransactionSearchIndexer(ElasticsearchOperations operations, TransactionRepository transactionRepo) {
        this.operations = operations;
        this.transactionRepo = transactionRepo;
    }

    /** Creates the index from the settings and mapping files when it does not exist yet; leaves an existing one alone. */
    @EventListener(ApplicationReadyEvent.class)
    public void ensureIndex() {
        try {
            IndexOperations indexOps = indexOps();
            if (!indexOps.exists()) {
                indexOps.createWithMapping();
                log.info("Search index created, index={}", TransactionSearchDocument.INDEX);
            }
        } catch (RuntimeException e) {
            log.warn("Search index could not be checked or created, it is created by the next reindex, index={}",
                    TransactionSearchDocument.INDEX, e);
        }
    }

    /** Indexes the transaction as it is now in PostgreSQL, or removes its document when it is gone. */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onTransactionChanged(TransactionChangedEvent event) {
        Long transactionId = event.transactionId();
        if (transactionId == null) {
            return;
        }
        try {
            if (event.kind() == TransactionChangedEvent.Kind.DELETED) {
                delete(transactionId);
                return;
            }
            transactionRepo.findForSearchIndex(transactionId).ifPresentOrElse(
                    transaction -> operations.save(TransactionSearchDocument.from(transaction)),
                    // Deleted again between the commit and now: what the index must hold is nothing.
                    () -> delete(transactionId));
            log.debug("Search index updated, transactionId={}, kind={}", transactionId, event.kind());
        } catch (RuntimeException e) {
            // Elasticsearch down or slow (or the row unreadable): the document stays stale until the next change of this
            // transaction or the next reindex. PostgreSQL has committed already and is not affected.
            log.warn("Search index update failed, transactionId={}, userId={}, kind={}",
                    transactionId, event.userId(), event.kind(), e);
        }
    }

    /**
     * Drops the index, creates it again from the settings and mapping files and indexes every transaction of PostgreSQL,
     * {@value #PAGE_SIZE} per bulk request in the order of their ids; the number of documents indexed. Searches find
     * nothing (or part) while it runs, and a change committed during the run may be missing until its next change.
     * Failures propagate to the caller.
     */
    public int reindexAll() {
        IndexOperations indexOps = indexOps();
        if (indexOps.exists()) {
            indexOps.delete();
        }
        indexOps.createWithMapping();

        int indexed = 0;
        Pageable pageable = PageRequest.of(0, PAGE_SIZE, Sort.by(Sort.Direction.ASC, "id"));
        while (true) {
            Page<Transaction> page = transactionRepo.findPageForSearchIndex(pageable);
            List<TransactionSearchDocument> documents = page.getContent().stream()
                    .map(TransactionSearchDocument::from)
                    .toList();
            if (!documents.isEmpty()) {
                operations.save(documents);
                indexed += documents.size();
            }
            if (!page.hasNext()) {
                break;
            }
            pageable = page.nextPageable();
        }
        indexOps.refresh();
        log.info("Search index rebuilt from PostgreSQL, index={}, documents={}", TransactionSearchDocument.INDEX, indexed);
        return indexed;
    }

    private void delete(Long transactionId) {
        operations.delete(String.valueOf(transactionId), TransactionSearchDocument.class);
    }

    private IndexOperations indexOps() {
        return operations.indexOps(TransactionSearchDocument.class);
    }
}
