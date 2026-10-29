package vn.edu.huit.finance.core.Service.Search;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.elasticsearch.client.elc.ElasticsearchTemplate;
import org.springframework.data.elasticsearch.core.IndexOperations;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** The query of ElasticsearchTransactionSearchEngine on a real Elasticsearch 8.11 with the real index settings and mapping. */
@Testcontainers(disabledWithoutDocker = true)
class ElasticsearchTransactionSearchEngineIntegrationTest {

    private static final long ALICE = 1L;
    private static final long BOB = 2L;
    private static final LocalDateTime DATE = LocalDateTime.of(2026, 10, 1, 12, 0);

    @Container
    private static final GenericContainer<?> ELASTICSEARCH = ElasticsearchTestContainers.newElasticsearch();

    private static ElasticsearchTemplate template;
    private ElasticsearchTransactionSearchEngine engine;

    @BeforeAll
    static void connect() {
        template = ElasticsearchTestContainers.templateFor(
                ElasticsearchTestContainers.clientFor(ElasticsearchTestContainers.hostAndPort(ELASTICSEARCH)));
    }

    @BeforeEach
    void freshIndex() {
        IndexOperations indexOps = template.indexOps(TransactionSearchDocument.class);
        if (indexOps.exists()) {
            indexOps.delete();
        }
        indexOps.createWithMapping();
        engine = new ElasticsearchTransactionSearchEngine(template);
    }

    private void index(long id, long userId, String vendor, String note, String location, LocalDateTime date) {
        TransactionSearchDocument document = new TransactionSearchDocument();
        document.setId(String.valueOf(id));
        document.setUserId(userId);
        document.setVendorName(vendor);
        document.setNote(note);
        document.setLocation(location);
        document.setCategoryName("Ăn uống");
        document.setPaymentMethod("CASH");
        document.setAmount(new BigDecimal("1000"));
        document.setExpense(true);
        document.setTransactionDate(date);
        template.save(document);
        template.indexOps(TransactionSearchDocument.class).refresh();
    }

    private List<Long> ids(long userId, String q) {
        return engine.hits(userId, q, PageRequest.of(0, 20)).ids();
    }

    @Test
    void pho_matchesPhoHung() {
        index(10, ALICE, "Phở Hưng", "bữa trưa", null, DATE);
        index(11, ALICE, "Highlands", "trà đá", null, DATE);

        assertEquals(List.of(10L), ids(ALICE, "pho"));
    }

    @Test
    void pho_doesNotReturnPhucLong() {
        index(12, ALICE, "Phở Hưng", null, null, DATE);
        index(13, ALICE, "Phúc Long", "trà đá", null, DATE);
        index(14, ALICE, "Ship hàng", "tiền trọ", null, DATE);

        assertEquals(List.of(12L), ids(ALICE, "pho"));
    }

    @Test
    void pho_fuzzyCaFe_ifReturnedRanksBelowPhoHung() {
        // "phê" is one edit from "pho" for the typo clause; the newer date must not lift it above the real match.
        index(15, ALICE, "Phở Hưng", "bữa trưa", null, LocalDateTime.of(2026, 10, 1, 12, 0));
        index(16, ALICE, "Highlands", "cà phê", null, LocalDateTime.of(2026, 10, 5, 12, 0));

        List<Long> ids = ids(ALICE, "pho");

        assertEquals(15L, ids.get(0));
        assertTrue(ids.indexOf(16L) == -1 || ids.indexOf(16L) > ids.indexOf(15L));
    }

    @Test
    void daNang_matchesDaNangUppercase() {
        index(20, ALICE, null, "Đi chơi", "ĐÀ NẴNG", DATE);

        assertEquals(List.of(20L), ids(ALICE, "da nang"));
        assertEquals(List.of(20L), ids(ALICE, "Đà Nẵng"));
    }

    @Test
    void typo_phoHug_matchesPhoHung() {
        index(30, ALICE, "Phở Hưng", null, null, DATE);

        // "hunh" is 4 letters: one edit from "hung" is still forgiven by AUTO:4,7.
        assertEquals(List.of(30L), ids(ALICE, "pho hunh"));
    }

    @Test
    void tienDien_doesNotMatchTienNuoc() {
        index(37, ALICE, "Tiền điện", null, null, DATE);
        index(38, ALICE, "Tiền nước", null, null, DATE);

        assertEquals(List.of(37L), ids(ALICE, "tiền điện"));
        assertEquals(List.of(37L), ids(ALICE, "tien dien"));
    }

    @Test
    void typo_firstLetterRight_stillForgiven() {
        index(39, ALICE, "Highlands Coffee", null, null, DATE);

        assertEquals(List.of(39L), ids(ALICE, "highlans cofee"));
    }

    @Test
    void pho_doesNotMatchCho() {
        index(31, ALICE, "Phở Hưng", null, null, DATE);
        index(32, ALICE, "Chợ Bến Thành", null, null, DATE);

        assertEquals(List.of(31L), ids(ALICE, "pho"));
    }

    @Test
    void pho_doesNotMatchPhi() {
        index(33, ALICE, "Phở Hưng", null, null, DATE);
        index(34, ALICE, "Phí chuyển khoản", null, null, DATE);

        assertEquals(List.of(33L), ids(ALICE, "pho"));
    }

    @Test
    void pho_stillMatchesPhoAndPhoCo() {
        index(35, ALICE, "Phở Hưng", null, null, DATE);
        index(36, ALICE, "Phố Cổ", null, null, DATE);

        assertEquals(java.util.Set.of(35L, 36L), new java.util.HashSet<>(ids(ALICE, "pho")));
    }

    @Test
    void prefix_phu_matchesPhucLong() {
        index(40, ALICE, "Phúc Long", null, null, DATE);

        assertEquals(List.of(40L), ids(ALICE, "phu"));
    }

    @Test
    void otherUsersDocs_neverReturned() {
        index(50, BOB, "Phở Hưng", "phở của bob", null, DATE);
        index(51, ALICE, "Phở Hưng", "phở của alice", null, DATE);

        TransactionSearchEngine.SearchHits hits = engine.hits(ALICE, "pho", PageRequest.of(0, 20));

        assertEquals(List.of(51L), hits.ids());
        assertEquals(1, hits.total());
        assertTrue(ids(999L, "pho").isEmpty());
    }

    @Test
    void newestFirstAmongEqualScores_andPaging() {
        index(60, ALICE, "Phở Hưng", null, null, LocalDateTime.of(2026, 10, 1, 12, 0));
        index(61, ALICE, "Phở Hưng", null, null, LocalDateTime.of(2026, 10, 3, 12, 0));

        TransactionSearchEngine.SearchHits first = engine.hits(ALICE, "pho", PageRequest.of(0, 1));

        assertEquals(List.of(61L), first.ids());
        assertEquals(2, first.total());
        assertEquals(List.of(60L), engine.hits(ALICE, "pho", PageRequest.of(1, 1)).ids());
    }

    @Test
    void specialChars_50percent_paren_quote_backslash_noException() {
        index(70, ALICE, "Phở Hưng", "giảm 50% (khuyến mãi)", null, DATE);

        for (String q : List.of("50%", "(", "\"", "\\", "a AND (b", "foo:bar", "*", "~2", "'; DROP", "[x TO y}")) {
            assertDoesNotThrow(() -> ids(ALICE, q), q);
        }
        assertEquals(List.of(70L), ids(ALICE, "50%"));
    }
}
