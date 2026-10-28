package vn.edu.huit.finance.core.Service.Search;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.IndexOperations;
import org.springframework.data.elasticsearch.core.query.CriteriaQuery;
import org.springframework.data.elasticsearch.core.query.Query;
import org.springframework.transaction.support.TransactionOperations;
import vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.LongStream;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;

/** The paging loop of a full index fill and the removal of a deleted account's documents, with nothing but mocks. */
class TransactionSearchIndexerPagingTest {

    private ElasticsearchOperations operations;
    private TransactionRepository repo;
    private final List<Long> rowsInPostgres = new ArrayList<>();
    private final AtomicInteger transactionsRun = new AtomicInteger();
    private final AtomicInteger cleared = new AtomicInteger();
    private TransactionSearchIndexer indexer;

    @BeforeEach
    void setUp() {
        operations = mock(ElasticsearchOperations.class);
        when(operations.indexOps(TransactionSearchDocument.class)).thenReturn(mock(IndexOperations.class));
        repo = mock(TransactionRepository.class);
        // A repository over the list: the rows after lastId in the order of the ids, at most one page.
        when(repo.findNextForSearchIndex(anyLong(), any(Pageable.class))).thenAnswer(call -> {
            long lastId = call.getArgument(0);
            int size = ((Pageable) call.getArgument(1)).getPageSize();
            return rowsInPostgres.stream().sorted().filter(id -> id > lastId).limit(size).map(this::transaction).toList();
        });
        TransactionOperations counting = new TransactionOperations() {
            @Override
            public <T> T execute(org.springframework.transaction.support.TransactionCallback<T> action) {
                transactionsRun.incrementAndGet();
                return action.doInTransaction(null);
            }
        };
        indexer = new TransactionSearchIndexer(operations, repo, Runnable::run, counting, cleared::incrementAndGet);
    }

    private Transaction transaction(long id) {
        User owner = new User();
        owner.setId(7L);
        Transaction transaction = new Transaction();
        transaction.setId(id);
        transaction.setUser(owner);
        return transaction;
    }

    @SuppressWarnings("unchecked")
    private List<String> indexedIds() {
        ArgumentCaptor<Iterable<TransactionSearchDocument>> saved = ArgumentCaptor.forClass(Iterable.class);
        verify(operations, org.mockito.Mockito.atLeast(0)).save(saved.capture());
        List<String> ids = new ArrayList<>();
        saved.getAllValues().forEach(batch -> batch.forEach(document -> ids.add(document.getId())));
        return ids;
    }

    @Test
    void aRowDeletedBetweenTwoPages_doesNotMakeTheNextPageSkipAnother() {
        LongStream.rangeClosed(1, 5).forEach(rowsInPostgres::add);
        // The user deletes id 1 once the first page has been read: with OFFSET paging the second page would start at id 4.
        when(operations.save(any(Iterable.class))).thenAnswer(call -> {
            rowsInPostgres.remove(Long.valueOf(1));
            return call.getArgument(0);
        });

        int indexed = indexer.indexAllRows(2);

        assertEquals(5, indexed);
        assertEquals(List.of("1", "2", "3", "4", "5"), indexedIds());
    }

    @Test
    void everyPageRunsInItsOwnTransaction_andTheContextIsClearedAfterEachOne() {
        LongStream.rangeClosed(1, 5).forEach(rowsInPostgres::add);

        indexer.indexAllRows(2);

        // [1,2] [3,4] [5]: the short page ends the loop.
        assertEquals(3, transactionsRun.get());
        assertEquals(3, cleared.get());
    }

    @Test
    void anExactMultipleOfThePageSize_endsWithOneEmptyPage() {
        LongStream.rangeClosed(1, 4).forEach(rowsInPostgres::add);

        assertEquals(4, indexer.indexAllRows(2));
        assertEquals(3, transactionsRun.get());
    }

    @Test
    void accountDeleted_deletesTheUsersDocumentsByQuery() {
        indexer.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.ACCOUNT_DELETED, 7L));

        ArgumentCaptor<Query> query = ArgumentCaptor.forClass(Query.class);
        verify(operations).delete(query.capture(), eq(TransactionSearchDocument.class));
        assertTrue(query.getValue() instanceof CriteriaQuery);
        CriteriaQuery criteriaQuery = (CriteriaQuery) query.getValue();
        assertEquals("userId", criteriaQuery.getCriteria().getField().getName());
        assertTrue(criteriaQuery.getCriteria().getQueryCriteriaEntries().toString().contains("7"));
    }

    @Test
    void accountDeleted_withoutAUserId_orWhenElasticsearchFails_doesNothingOrNeverThrows() {
        indexer.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.ACCOUNT_DELETED));
        verify(operations, never()).delete(any(Query.class), eq(TransactionSearchDocument.class));

        doThrow(new IllegalStateException("es down")).when(operations).delete(any(Query.class), eq(TransactionSearchDocument.class));
        assertDoesNotThrow(() -> indexer.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.ACCOUNT_DELETED, 7L)));
    }
}
