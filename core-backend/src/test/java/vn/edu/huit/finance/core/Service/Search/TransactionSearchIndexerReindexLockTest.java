package vn.edu.huit.finance.core.Service.Search;

import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.data.elasticsearch.core.IndexOperations;
import vn.edu.huit.finance.core.Exception.ReindexInProgressException;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Every caller of reindexAll() is serialised: a second one is refused while the first holds the lock, then it works again. */
class TransactionSearchIndexerReindexLockTest {

    @Test
    void aSecondReindexWhileTheFirstRunsIsRefused_andTheLockIsFreeAfterwards() throws Exception {
        ElasticsearchOperations operations = mock(ElasticsearchOperations.class);
        IndexOperations indexOps = mock(IndexOperations.class);
        TransactionRepository repo = mock(TransactionRepository.class);
        when(operations.indexOps(TransactionSearchDocument_CLASS())).thenReturn(indexOps);
        when(repo.findPageForSearchIndex(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
        CountDownLatch inside = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        when(indexOps.exists()).thenAnswer(call -> {
            inside.countDown();
            assertTrue(release.await(10, TimeUnit.SECONDS));
            return false;
        });
        TransactionSearchIndexer indexer = new TransactionSearchIndexer(operations, repo, Runnable::run);
        ExecutorService pool = Executors.newSingleThreadExecutor();
        try {
            Future<Integer> first = pool.submit(indexer::reindexAll);
            assertTrue(inside.await(10, TimeUnit.SECONDS));
            assertTrue(indexer.isReindexing());

            assertThrows(ReindexInProgressException.class, indexer::reindexAll);

            release.countDown();
            assertEquals(0, first.get(10, TimeUnit.SECONDS));
            assertFalse(indexer.isReindexing());
            assertEquals(0, indexer.reindexAll());
            verify(indexOps, times(2)).createWithMapping();
        } finally {
            release.countDown();
            pool.shutdownNow();
        }
    }

    @Test
    void aRestoreEventWhileARebuildRunsWaitsForItAndThenRebuildsAgain() throws Exception {
        ElasticsearchOperations operations = mock(ElasticsearchOperations.class);
        IndexOperations indexOps = mock(IndexOperations.class);
        TransactionRepository repo = mock(TransactionRepository.class);
        when(operations.indexOps(TransactionSearchDocument_CLASS())).thenReturn(indexOps);
        when(repo.findPageForSearchIndex(any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
        CountDownLatch inside = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        when(indexOps.exists()).thenAnswer(call -> {
            inside.countDown();
            assertTrue(release.await(10, TimeUnit.SECONDS));
            return false;
        });
        TransactionSearchIndexer indexer = new TransactionSearchIndexer(operations, repo, Runnable::run);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<Integer> running = pool.submit(indexer::reindexAll);
            assertTrue(inside.await(10, TimeUnit.SECONDS));

            Future<?> restore = pool.submit(() -> indexer.onStatisticsChanged(
                    StatisticsChangedEvent.of(StatisticsChange.DATABASE_RESTORED)));
            Thread.sleep(300);
            assertFalse(restore.isDone(), "the restore rebuild must wait, not skip");
            verify(indexOps, never()).createWithMapping();

            release.countDown();
            running.get(10, TimeUnit.SECONDS);
            restore.get(10, TimeUnit.SECONDS);
            verify(indexOps, times(2)).createWithMapping();
            assertFalse(indexer.isReindexing());
        } finally {
            release.countDown();
            pool.shutdownNow();
        }
    }

    private static Class<vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument> TransactionSearchDocument_CLASS() {
        return vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument.class;
    }
}
