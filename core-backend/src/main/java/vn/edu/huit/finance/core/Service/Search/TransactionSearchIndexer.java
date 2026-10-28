package vn.edu.huit.finance.core.Service.Search;

import jakarta.persistence.EntityManager;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.elasticsearch.NoSuchIndexException;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.IndexOperations;
import org.springframework.data.elasticsearch.core.query.Criteria;
import org.springframework.data.elasticsearch.core.query.CriteriaQuery;
import org.springframework.data.elasticsearch.core.query.Query;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.support.TransactionOperations;
import org.springframework.transaction.support.TransactionTemplate;
import vn.edu.huit.finance.core.Config.SearchConfig;
import vn.edu.huit.finance.core.Config.SearchEngineType;
import vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Exception.ReindexInProgressException;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Keeps the Elasticsearch index of the transactions in step with PostgreSQL, which stays the source of truth. Only exists
 * with {@code app.search.engine=elasticsearch}.
 * <ul>
 *   <li>after every committed write of a transaction, the row is read back from PostgreSQL and indexed whole (or its
 *       document deleted), never patched from the event, so a lost or repeated event heals on the next change;</li>
 *   <li>the index is only ever created from its settings and mapping files (docker-compose.yml forbids Elasticsearch to
 *       create one on its own with a dynamic mapping): at start-up, again every {@value #INDEX_CHECK_DELAY_MS} ms until
 *       that has worked once (Elasticsearch may still be starting), and by a write that finds it missing, which is then
 *       retried once;</li>
 *   <li>an index this class has just created is filled from PostgreSQL in the background, and a restore of the database
 *       rebuilds it from scratch, so neither leaves it empty or stale;</li>
 *   <li>{@link #reindexAll} rebuilds it from scratch, for an administrator;</li>
 *   <li>the deletion of an account removes that user's documents, which no per-transaction event announces.</li>
 * </ul>
 * A failure of Elasticsearch in all but the last is logged and goes no further: it never reaches the PostgreSQL write that
 * caused it, nor stops the application from starting.
 */
@Slf4j
@Service
@ConditionalOnProperty(name = SearchConfig.ENGINE_PROPERTY, havingValue = SearchEngineType.ELASTICSEARCH_VALUE)
public class TransactionSearchIndexer {

    /** Rows read from PostgreSQL and sent to Elasticsearch in one bulk request by {@link #reindexAll}. */
    static final int PAGE_SIZE = 500;

    /** Pause between two checks of the index while it has been neither found nor created yet. */
    static final long INDEX_CHECK_DELAY_MS = 15_000;

    /** How long the rebuild after a restore waits for a rebuild already running before giving up. */
    static final long RESTORE_REBUILD_WAIT_MINUTES = 10;

    private final ElasticsearchOperations operations;
    private final TransactionRepository transactionRepo;
    private final Executor backgroundExecutor;
    /** Runs the read of one page of rows (a read-only transaction in the application). */
    private final TransactionOperations pageTransaction;
    /** Detaches every entity read so far; run at the end of each page. */
    private final Runnable clearPersistenceContext;
    /** Serialises the creation (and the drop and re-creation) of the index, never the bulk writes that follow. */
    private final Object indexLock = new Object();
    /** Held for the whole of a full rebuild (drop, create, bulk fill): a second one is refused, never queued. */
    private final ReentrantLock reindexLock = new ReentrantLock();
    /** Set once the index has been seen or created; the periodic check does nothing from then on. */
    private volatile boolean indexReady;

    @Autowired
    public TransactionSearchIndexer(ElasticsearchOperations operations, TransactionRepository transactionRepo,
                                    @Qualifier("mongoAsyncExecutor") Executor backgroundExecutor,
                                    PlatformTransactionManager transactionManager,
                                    EntityManager entityManager) {
        this(operations, transactionRepo, backgroundExecutor, readOnly(transactionManager), entityManager::clear);
    }

    TransactionSearchIndexer(ElasticsearchOperations operations, TransactionRepository transactionRepo,
                             Executor backgroundExecutor, TransactionOperations pageTransaction,
                             Runnable clearPersistenceContext) {
        this.operations = operations;
        this.transactionRepo = transactionRepo;
        this.backgroundExecutor = backgroundExecutor;
        this.pageTransaction = pageTransaction;
        this.clearPersistenceContext = clearPersistenceContext;
    }

    /** For tests that read from a mocked repository: no transaction, nothing to clear. */
    TransactionSearchIndexer(ElasticsearchOperations operations, TransactionRepository transactionRepo,
                             Executor backgroundExecutor) {
        this(operations, transactionRepo, backgroundExecutor, TransactionOperations.withoutTransaction(), () -> { });
    }

    private static TransactionTemplate readOnly(PlatformTransactionManager transactionManager) {
        TransactionTemplate template = new TransactionTemplate(transactionManager);
        template.setReadOnly(true);
        return template;
    }

    /**
     * Creates the index from the settings and mapping files when it does not exist yet, and then fills it from PostgreSQL
     * in the background; leaves an existing one alone. A failure is logged and the periodic check tries again.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void ensureIndex() {
        try {
            createIndexIfMissing();
        } catch (RuntimeException e) {
            log.warn("Search index could not be checked or created, tried again in {} ms, index={}: {}",
                    INDEX_CHECK_DELAY_MS, TransactionSearchDocument.INDEX, e.toString());
            log.debug("Search index check failure", e);
        }
    }

    /** Tries {@link #ensureIndex} again while no attempt has worked yet; does nothing afterwards. */
    @Scheduled(initialDelay = INDEX_CHECK_DELAY_MS, fixedDelay = INDEX_CHECK_DELAY_MS)
    public void retryEnsureIndex() {
        if (!indexReady) {
            ensureIndex();
        }
    }

    /** Whether the index has been found or created since the start. */
    public boolean isIndexReady() {
        return indexReady;
    }

    /** Number of documents in the index now (for the admin page); failures of Elasticsearch propagate to the caller. */
    public long countDocuments() {
        return operations.count(Query.findAll(), TransactionSearchDocument.class);
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
            withIndex(() -> sync(event));
            log.debug("Search index updated, transactionId={}, kind={}", transactionId, event.kind());
        } catch (RuntimeException e) {
            // Elasticsearch down or slow (or the row unreadable): the document stays stale until the next change of this
            // transaction or the next reindex. PostgreSQL has committed already and is not affected.
            log.warn("Search index update failed, transactionId={}, userId={}, kind={}",
                    transactionId, event.userId(), event.kind(), e);
        }
    }

    /**
     * Rebuilds the index after a restore of the database, which changes the transactions without saying which. Runs after
     * the commit of the restore (or at once outside a transaction), in the background.
     */
    @Async("mongoAsyncExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onStatisticsChanged(StatisticsChangedEvent event) {
        if (event.change() == StatisticsChange.ACCOUNT_DELETED) {
            deleteDocumentsOf(event.userId());
            return;
        }
        if (event.change() != StatisticsChange.DATABASE_RESTORED) {
            return;
        }
        // Waits for a rebuild that is running: it may have read rows from before the restore, so it is not enough.
        boolean locked = false;
        try {
            locked = reindexLock.tryLock(RESTORE_REBUILD_WAIT_MINUTES, TimeUnit.MINUTES);
            if (!locked) {
                log.warn("Search index rebuild after a restore gave up waiting for the running rebuild, run POST /api/admin/search/reindex, index={}",
                        TransactionSearchDocument.INDEX);
                return;
            }
            rebuildLocked();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("Search index rebuild after a restore interrupted, index={}", TransactionSearchDocument.INDEX);
        } catch (RuntimeException e) {
            log.warn("Search index rebuild after a restore failed, run POST /api/admin/search/reindex, index={}",
                    TransactionSearchDocument.INDEX, e);
        } finally {
            if (locked) {
                reindexLock.unlock();
            }
        }
    }

    /**
     * Removes every document of a deleted account (its transactions went with it through a cascade, which publishes no
     * per-transaction event). A failure is logged: the documents stay until the next reindex, and are never served, because
     * a search filters on the caller's id and reads the rows back from PostgreSQL.
     */
    private void deleteDocumentsOf(Long userId) {
        if (userId == null) {
            return;
        }
        try {
            operations.delete(new CriteriaQuery(new Criteria("userId").is(userId)), TransactionSearchDocument.class);
            log.info("Search documents of a deleted account removed, userId={}, index={}", userId, TransactionSearchDocument.INDEX);
        } catch (RuntimeException e) {
            log.warn("Search documents of a deleted account could not be removed, run POST /api/admin/search/reindex, userId={}, index={}",
                    userId, TransactionSearchDocument.INDEX, e);
        }
    }

    /**
     * Drops the index, creates it again from the settings and mapping files and indexes every transaction of PostgreSQL,
     * {@value #PAGE_SIZE} per bulk request in the order of their ids; the number of documents indexed. Searches find
     * nothing (or part) while it runs, and a change committed during the run may be missing until its next change.
     * Failures propagate to the caller.
     */
    public int reindexAll() {
        if (!reindexLock.tryLock()) {
            throw new ReindexInProgressException();
        }
        try {
            return rebuildLocked();
        } finally {
            reindexLock.unlock();
        }
    }

    /** The rebuild itself; the caller holds {@link #reindexLock}. */
    private int rebuildLocked() {
        synchronized (indexLock) {
            IndexOperations indexOps = indexOps();
            if (indexOps.exists()) {
                indexOps.delete();
            }
            indexOps.createWithMapping();
            indexReady = true;
        }
        int indexed = indexAllRows();
        log.info("Search index rebuilt from PostgreSQL, index={}, documents={}", TransactionSearchDocument.INDEX, indexed);
        return indexed;
    }

    /** Whether a full rebuild is running now, whoever started it. */
    public boolean isReindexing() {
        return reindexLock.isLocked();
    }

    private void sync(TransactionChangedEvent event) {
        Long transactionId = event.transactionId();
        if (event.kind() == TransactionChangedEvent.Kind.DELETED) {
            delete(transactionId);
            return;
        }
        transactionRepo.findForSearchIndex(transactionId).ifPresentOrElse(
                transaction -> operations.save(TransactionSearchDocument.from(transaction)),
                // Deleted again between the commit and now: what the index must hold is nothing.
                () -> delete(transactionId));
    }

    /** Runs {@code write}; when it finds no index, creates the index from its files and runs it once more. */
    private void withIndex(Runnable write) {
        try {
            write.run();
        } catch (RuntimeException e) {
            if (!isIndexNotFound(e)) {
                throw e;
            }
            log.info("Search index missing at a write, creating it from its mapping, index={}",
                    TransactionSearchDocument.INDEX);
            createIndexIfMissing();
            write.run();
        }
    }

    /**
     * Creates the index when it is missing and starts filling it from PostgreSQL in the background. Marks the index ready
     * whether it found or created it.
     */
    private void createIndexIfMissing() {
        synchronized (indexLock) {
            IndexOperations indexOps = indexOps();
            if (indexOps.exists()) {
                indexReady = true;
                return;
            }
            indexOps.createWithMapping();
            indexReady = true;
            log.info("Search index created, filling it from PostgreSQL in the background, index={}",
                    TransactionSearchDocument.INDEX);
        }
        backgroundExecutor.execute(this::fillNewIndex);
    }

    private void fillNewIndex() {
        if (!reindexLock.tryLock()) {
            log.info("New search index not filled, a full rebuild is running, index={}", TransactionSearchDocument.INDEX);
            return;
        }
        try {
            int indexed = indexAllRows();
            log.info("New search index filled from PostgreSQL, index={}, documents={}",
                    TransactionSearchDocument.INDEX, indexed);
        } catch (RuntimeException e) {
            log.warn("New search index could not be filled, run POST /api/admin/search/reindex, index={}",
                    TransactionSearchDocument.INDEX, e);
        } finally {
            reindexLock.unlock();
        }
    }

    /** Indexes every transaction of PostgreSQL into the existing index, {@value #PAGE_SIZE} per bulk request. */
    private int indexAllRows() {
        return indexAllRows(PAGE_SIZE);
    }

    /**
     * Keyset paging ({@code id > lastId}, in the order of the ids), not OFFSET: a row deleted between two pages cannot make
     * the next one skip a row. Each page is read in its own read-only transaction and the persistence context is cleared at
     * its end, so a rebuild on a request thread (open-session-in-view) does not keep the whole table managed.
     */
    int indexAllRows(int pageSize) {
        int indexed = 0;
        long lastId = 0;
        while (true) {
            long after = lastId;
            RowPage page = pageTransaction.execute(status -> {
                List<Transaction> rows = transactionRepo.findNextForSearchIndex(after, PageRequest.of(0, pageSize));
                RowPage read = new RowPage(rows.stream().map(TransactionSearchDocument::from).toList(),
                        rows.isEmpty() ? after : rows.get(rows.size() - 1).getId(), rows.size());
                clearPersistenceContext.run();
                return read;
            });
            if (!page.documents().isEmpty()) {
                operations.save(page.documents());
                indexed += page.documents().size();
            }
            if (page.rowCount() < pageSize) {
                break;
            }
            lastId = page.lastId();
        }
        indexOps().refresh();
        return indexed;
    }

    private record RowPage(List<TransactionSearchDocument> documents, long lastId, int rowCount) {
    }

    /** Elasticsearch answered index_not_found_exception, whether Spring Data translated it or not. */
    static boolean isIndexNotFound(Throwable error) {
        for (Throwable cause = error; cause != null; cause = cause.getCause() == cause ? null : cause.getCause()) {
            if (cause instanceof NoSuchIndexException
                    || (cause.getMessage() != null && cause.getMessage().contains("index_not_found_exception"))) {
                return true;
            }
        }
        return false;
    }

    private void delete(Long transactionId) {
        operations.delete(String.valueOf(transactionId), TransactionSearchDocument.class);
    }

    private IndexOperations indexOps() {
        return operations.indexOps(TransactionSearchDocument.class);
    }
}
