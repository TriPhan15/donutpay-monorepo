package vn.edu.huit.finance.core.Service.Search;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.elasticsearch.indices.analyze.AnalyzeToken;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.elasticsearch.client.elc.ElasticsearchTemplate;
import org.springframework.data.elasticsearch.client.elc.NativeQuery;
import org.springframework.data.elasticsearch.core.IndexOperations;
import org.springframework.data.elasticsearch.core.SearchHits;
import org.springframework.data.elasticsearch.core.query.Query;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument;
import vn.edu.huit.finance.core.Dto.TransactionChangedEvent;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChange;
import vn.edu.huit.finance.core.Service.Cache.StatisticsChangedEvent;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.LongStream;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * TransactionSearchIndexer on a real Elasticsearch 8.11 (Testcontainers): the index built from the settings and mapping
 * files, the Vietnamese folding analyzer, the after-commit sync of one transaction and the full rebuild. PostgreSQL is not
 * needed: the repository is a mock that hands out the rows. Skipped when Docker is not there.
 */
@Testcontainers(disabledWithoutDocker = true)
class TransactionSearchIndexerIntegrationTest {

    @Container
    private static final GenericContainer<?> ELASTICSEARCH = ElasticsearchTestContainers.newElasticsearch();

    private static ElasticsearchClient client;
    private static ElasticsearchTemplate template;

    private TransactionRepository transactionRepo;
    private TransactionSearchIndexer indexer;

    @BeforeAll
    static void connect() {
        client = ElasticsearchTestContainers.clientFor(ElasticsearchTestContainers.hostAndPort(ELASTICSEARCH));
        template = ElasticsearchTestContainers.templateFor(client);
    }

    @BeforeEach
    void freshIndex() {
        IndexOperations indexOps = template.indexOps(TransactionSearchDocument.class);
        if (indexOps.exists()) {
            indexOps.delete();
        }
        transactionRepo = mock(TransactionRepository.class);
        when(transactionRepo.findPageForSearchIndex(any(Pageable.class)))
                .thenAnswer(invocation -> Page.empty(invocation.getArgument(0)));
        // Runs the background rebuild on the calling thread, so the test sees it finished.
        indexer = new TransactionSearchIndexer(template, transactionRepo, Runnable::run);
    }

    @Test
    void ensureIndex_createsIndexWithViAnalyzer() throws IOException {
        indexer.ensureIndex();

        assertTrue(template.indexOps(TransactionSearchDocument.class).exists());
        List<String> tokens = client.indices().analyze(a -> a
                        .index(TransactionSearchDocument.INDEX)
                        .analyzer("vi_folded")
                        .text("PHỞ Đà Nẵng"))
                .tokens().stream().map(AnalyzeToken::token).toList();
        assertEquals(List.of("pho", "da", "nang"), tokens);

        Map<String, Object> properties = properties();
        assertAll(
                () -> assertEquals("vi_folded", field(properties, "vendorName").get("analyzer")),
                () -> assertEquals("vi_autocomplete", subField(properties, "vendorName", "autocomplete").get("analyzer")),
                () -> assertEquals("vi_folded", subField(properties, "note", "autocomplete").get("search_analyzer")),
                () -> assertEquals("keyword", subField(properties, "categoryName", "keyword").get("type")),
                () -> assertEquals("scaled_float", field(properties, "amount").get("type")),
                () -> assertEquals("keyword", field(properties, "receiptStatus").get("type")),
                () -> assertEquals("date", field(properties, "transactionDate").get("type")));

        // A second start finds the index and leaves it (and what it holds) alone.
        template.save(document("1"));
        indexer.ensureIndex();
        assertNotNull(template.get("1", TransactionSearchDocument.class));
    }

    @Test
    void saveBeforeEnsureIndex_createsIndexFromMapping_notDynamic() throws IOException {
        // Elasticsearch was still starting at ApplicationReadyEvent: the first write finds no index.
        when(transactionRepo.findForSearchIndex(46L)).thenReturn(Optional.of(transaction(46L, 7L, "Phở Hà Nội")));

        indexer.onTransactionChanged(TransactionChangedEvent.upserted(46L, 7L, Set.of()));

        assertTrue(template.indexOps(TransactionSearchDocument.class).exists());
        assertEquals("vi_folded", field(properties(), "vendorName").get("analyzer"));
        assertEquals("keyword", field(properties(), "receiptStatus").get("type"));
        List<String> tokens = client.indices().analyze(a -> a
                        .index(TransactionSearchDocument.INDEX).analyzer("vi_folded").text("Phở"))
                .tokens().stream().map(AnalyzeToken::token).toList();
        assertEquals(List.of("pho"), tokens);
        assertNotNull(template.get("46", TransactionSearchDocument.class), "the write is retried once the index exists");
    }

    @Test
    void deleteBeforeEnsureIndex_createsIndex_andDoesNotThrow() {
        assertDoesNotThrow(() -> indexer.onTransactionChanged(TransactionChangedEvent.deleted(47L, 7L, Set.of())));
        assertTrue(template.indexOps(TransactionSearchDocument.class).exists());
    }

    @Test
    void ensureIndex_creatingTheIndex_fillsItFromPostgres() {
        when(transactionRepo.findPageForSearchIndex(any(Pageable.class))).thenAnswer(invocation ->
                new PageImpl<>(List.of(transaction(48L, 7L, "Circle K")), invocation.getArgument(0), 1));

        indexer.ensureIndex();

        assertTrue(indexer.isIndexReady());
        assertEquals("Circle K", template.get("48", TransactionSearchDocument.class).getVendorName());
    }

    @Test
    void ensureIndex_onExistingIndex_doesNotReindex() {
        template.indexOps(TransactionSearchDocument.class).createWithMapping();

        indexer.ensureIndex();

        assertTrue(indexer.isIndexReady());
        verify(transactionRepo, never()).findPageForSearchIndex(any(Pageable.class));
    }

    @Test
    void databaseRestored_rebuildsTheIndex_otherChangesDoNot() {
        indexer.ensureIndex();
        clearInvocations(transactionRepo); // the fill of the new index
        template.save(document("999998")); // gone from the restored PostgreSQL
        when(transactionRepo.findPageForSearchIndex(any(Pageable.class))).thenAnswer(invocation ->
                new PageImpl<>(List.of(transaction(49L, 7L, "Bách Hóa Xanh")), invocation.getArgument(0), 1));

        indexer.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.TRANSACTION_TOTALS, 7L));
        assertNotNull(template.get("999998", TransactionSearchDocument.class));
        verify(transactionRepo, never()).findPageForSearchIndex(any(Pageable.class));

        indexer.onStatisticsChanged(StatisticsChangedEvent.of(StatisticsChange.DATABASE_RESTORED));

        assertNull(template.get("999998", TransactionSearchDocument.class));
        assertEquals("Bách Hóa Xanh", template.get("49", TransactionSearchDocument.class).getVendorName());
    }

    @Test
    void indexCheck_retriesUntilTheIndexExists_thenStops() {
        // Elasticsearch was unreachable at start-up: ensureIndex failed and left the flag down.
        TransactionSearchIndexer offline = new TransactionSearchIndexer(
                ElasticsearchTestContainers.templateFor(ElasticsearchTestContainers.clientFor("localhost:1")),
                transactionRepo, Runnable::run);
        offline.ensureIndex();
        assertFalse(offline.isIndexReady());

        // The periodic check on a reachable cluster creates it, once.
        indexer.retryEnsureIndex();
        assertTrue(indexer.isIndexReady());
        assertTrue(template.indexOps(TransactionSearchDocument.class).exists());
        template.indexOps(TransactionSearchDocument.class).delete();
        indexer.retryEnsureIndex();
        assertFalse(template.indexOps(TransactionSearchDocument.class).exists(), "no check once the index was there");
    }

    @Test
    void upsertedEvent_indexesTransactionWithVendor() {
        indexer.ensureIndex();
        Transaction transaction = transaction(42L, 7L, "Phở Hà Nội");
        when(transactionRepo.findForSearchIndex(42L)).thenReturn(Optional.of(transaction));

        indexer.onTransactionChanged(TransactionChangedEvent.upserted(42L, 7L, Set.of()));

        TransactionSearchDocument stored = template.get("42", TransactionSearchDocument.class);
        assertNotNull(stored);
        assertAll(
                () -> assertEquals(7L, stored.getUserId()),
                () -> assertEquals("Phở Hà Nội", stored.getVendorName()),
                () -> assertEquals("Ăn sáng với đồng nghiệp", stored.getNote()),
                () -> assertEquals("Ăn uống", stored.getCategoryName()),
                () -> assertEquals("Quận 1", stored.getLocation()),
                () -> assertEquals("CASH", stored.getPaymentMethod()),
                () -> assertEquals(0, new BigDecimal("55000.50").compareTo(stored.getAmount())),
                () -> assertTrue(stored.isExpense()),
                () -> assertEquals(LocalDateTime.of(2026, 10, 20, 7, 30, 15), stored.getTransactionDate()),
                () -> assertEquals(ReceiptStatus.LEGACY_SUCCESS, stored.getReceiptStatus()));

        // The text went through vi_folded: an unaccented query finds the accented seller.
        template.indexOps(TransactionSearchDocument.class).refresh();
        SearchHits<TransactionSearchDocument> hits = template.search(NativeQuery.builder()
                .withQuery(q -> q.match(m -> m.field("vendorName").query("pho ha noi")))
                .build(), TransactionSearchDocument.class);
        assertEquals(1, hits.getTotalHits());

        // An edit is indexed over the earlier copy.
        transaction.getReceipt().setVendorName("Bún bò Huế");
        indexer.onTransactionChanged(TransactionChangedEvent.upserted(42L, 7L, Set.of()));
        assertEquals("Bún bò Huế", template.get("42", TransactionSearchDocument.class).getVendorName());
    }

    @Test
    void upsertedEvent_ofRowGoneSinceTheCommit_removesDocument() {
        indexer.ensureIndex();
        template.save(document("43"));
        when(transactionRepo.findForSearchIndex(43L)).thenReturn(Optional.empty());

        indexer.onTransactionChanged(TransactionChangedEvent.upserted(43L, 7L, Set.of()));

        assertNull(template.get("43", TransactionSearchDocument.class));
    }

    @Test
    void deletedEvent_removesDocument() {
        indexer.ensureIndex();
        when(transactionRepo.findForSearchIndex(44L)).thenReturn(Optional.of(transaction(44L, 7L, "Circle K")));
        indexer.onTransactionChanged(TransactionChangedEvent.upserted(44L, 7L, Set.of()));
        assertNotNull(template.get("44", TransactionSearchDocument.class));

        indexer.onTransactionChanged(TransactionChangedEvent.deleted(44L, 7L, Set.of()));

        assertNull(template.get("44", TransactionSearchDocument.class));
        // Deleting what is not in the index is no error.
        assertDoesNotThrow(() -> indexer.onTransactionChanged(TransactionChangedEvent.deleted(44L, 7L, Set.of())));
    }

    @Test
    void reindexAll_indexesEveryRow_inPagesOf500() {
        indexer.ensureIndex();
        template.save(document("999999")); // not in PostgreSQL any more: the rebuild must drop it
        List<Transaction> firstPage = LongStream.rangeClosed(1, 500)
                .mapToObj(id -> transaction(id, 7L, "Cửa hàng " + id)).toList();
        List<Transaction> secondPage = List.of(transaction(501L, 8L, "Cửa hàng 501"));
        List<Pageable> requested = new ArrayList<>();
        when(transactionRepo.findPageForSearchIndex(any(Pageable.class))).thenAnswer(invocation -> {
            Pageable pageable = invocation.getArgument(0);
            requested.add(pageable);
            List<Transaction> rows = pageable.getPageNumber() == 0 ? firstPage : secondPage;
            Page<Transaction> page = new PageImpl<>(rows, pageable, 501);
            return page;
        });

        int indexed = indexer.reindexAll();

        assertEquals(501, indexed);
        assertEquals(2, requested.size());
        assertAll(
                () -> assertEquals(0, requested.get(0).getPageNumber()),
                () -> assertEquals(1, requested.get(1).getPageNumber()),
                () -> assertEquals(TransactionSearchIndexer.PAGE_SIZE, requested.get(0).getPageSize()),
                () -> assertEquals(500, TransactionSearchIndexer.PAGE_SIZE),
                () -> assertTrue(requested.get(0).getSort().isSorted(), "pages must have a stable order"));
        assertEquals(501, template.count(Query.findAll(), TransactionSearchDocument.class));
        assertNull(template.get("999999", TransactionSearchDocument.class));
        assertEquals("Cửa hàng 501", template.get("501", TransactionSearchDocument.class).getVendorName());
    }

    @Test
    void esDown_listenerLogsAndDoesNotThrow() {
        // Nothing listens on port 1: every call is refused at once.
        ElasticsearchTemplate down = ElasticsearchTestContainers.templateFor(ElasticsearchTestContainers.clientFor("localhost:1"));
        TransactionRepository repo = mock(TransactionRepository.class);
        when(repo.findForSearchIndex(45L)).thenReturn(Optional.of(transaction(45L, 7L, "Highlands")));
        TransactionSearchIndexer offline = new TransactionSearchIndexer(down, repo, Runnable::run);

        assertDoesNotThrow(() -> offline.onTransactionChanged(TransactionChangedEvent.upserted(45L, 7L, Set.of())));
        assertDoesNotThrow(() -> offline.onTransactionChanged(TransactionChangedEvent.deleted(45L, 7L, Set.of())));
        assertDoesNotThrow(offline::ensureIndex);
    }

    private static Transaction transaction(Long id, Long userId, String vendorName) {
        User owner = new User();
        owner.setId(userId);
        Receipt receipt = new Receipt();
        receipt.setVendorName(vendorName);
        receipt.setStatus(ReceiptStatus.COMPLETED_RAW.name());
        Transaction transaction = new Transaction();
        transaction.setId(id);
        transaction.setUser(owner);
        transaction.setAmount(new BigDecimal("55000.50"));
        transaction.setNote("Ăn sáng với đồng nghiệp");
        transaction.setCategoryName("Ăn uống");
        transaction.setLocation("Quận 1");
        transaction.setPaymentMethod("CASH");
        transaction.setExpense(true);
        transaction.setTransactionDate(LocalDateTime.of(2026, 10, 20, 7, 30, 15));
        transaction.setReceipt(receipt);
        return transaction;
    }

    private static TransactionSearchDocument document(String id) {
        TransactionSearchDocument document = new TransactionSearchDocument();
        document.setId(id);
        document.setUserId(1L);
        document.setVendorName("stale");
        return document;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> properties() {
        return (Map<String, Object>) template.indexOps(TransactionSearchDocument.class).getMapping().get("properties");
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> field(Map<String, Object> properties, String name) {
        return (Map<String, Object>) properties.get(name);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> subField(Map<String, Object> properties, String name, String sub) {
        return (Map<String, Object>) ((Map<String, Object>) field(properties, name).get("fields")).get(sub);
    }
}
