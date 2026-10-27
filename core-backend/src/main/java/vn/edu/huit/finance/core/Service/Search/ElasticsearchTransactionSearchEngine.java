package vn.edu.huit.finance.core.Service.Search;

import co.elastic.clients.elasticsearch._types.FieldValue;
import co.elastic.clients.elasticsearch._types.SortOrder;
import co.elastic.clients.elasticsearch._types.query_dsl.Operator;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.domain.Pageable;
import org.springframework.data.elasticsearch.client.elc.NativeQuery;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import org.springframework.stereotype.Component;
import vn.edu.huit.finance.core.Config.SearchConfig;
import vn.edu.huit.finance.core.Config.SearchEngineType;
import vn.edu.huit.finance.core.Document.Search.TransactionSearchDocument;

import java.util.List;

/**
 * The search in the Elasticsearch index: a fuzzy multi_match over the text fields (accent-insensitive, with prefix matching
 * through the autocomplete sub-fields), always inside a filter on the caller's user id. The text is the value of a
 * multi_match, never a query_string, so no character of it has a meaning for Elasticsearch. Only exists with
 * {@code app.search.engine=elasticsearch}; failures propagate, TransactionSearchService falls back to PostgreSQL.
 */
@Component
@ConditionalOnProperty(name = SearchConfig.ENGINE_PROPERTY, havingValue = SearchEngineType.ELASTICSEARCH_VALUE)
public class ElasticsearchTransactionSearchEngine implements TransactionSearchEngine {

    /** Whole words and prefixes: the main fields plus the edge-ngram sub-fields. Matched without fuzziness. */
    static final List<String> EXACT_FIELDS = List.of(
            "vendorName^3", "vendorName.autocomplete^2", "note^2", "note.autocomplete",
            "categoryName", "location", "paymentMethod");
    /** Whole-word fields only: fuzziness on the edge-ngram sub-fields would match every word that shares two letters. */
    static final List<String> FUZZY_FIELDS = List.of(
            "vendorName^3", "note^2", "categoryName", "location", "paymentMethod");
    static final float EXACT_BOOST = 2f;
    static final String MIN_SHOULD_MATCH = "1";
    static final String USER_ID_FIELD = "userId";
    static final String DATE_FIELD = "transactionDate";
    static final String FUZZINESS = "AUTO";

    private final ElasticsearchOperations operations;

    public ElasticsearchTransactionSearchEngine(ElasticsearchOperations operations) {
        this.operations = operations;
    }

    @Override
    public SearchHits hits(Long userId, String q, Pageable page) {
        NativeQuery query = NativeQuery.builder()
                .withQuery(root -> root.bool(bool -> bool
                        .filter(filter -> filter.term(term -> term.field(USER_ID_FIELD).value(FieldValue.of(userId))))
                        // Exact words and prefixes (the edge-ngram sub-fields), never fuzzy: a typo of one edit would
                        // otherwise turn "pho" into every word that starts with "ph".
                        .should(should -> should.multiMatch(match -> match
                                .query(q)
                                .fields(EXACT_FIELDS)
                                .operator(Operator.And)
                                .boost(EXACT_BOOST)))
                        // Typos, on the whole-word fields only.
                        .should(should -> should.multiMatch(match -> match
                                .query(q)
                                .fields(FUZZY_FIELDS)
                                .fuzziness(FUZZINESS)
                                .operator(Operator.And)))
                        .minimumShouldMatch(MIN_SHOULD_MATCH)))
                .withSort(sort -> sort.score(score -> score.order(SortOrder.Desc)))
                .withSort(sort -> sort.field(field -> field.field(DATE_FIELD).order(SortOrder.Desc)))
                .withPageable(page)
                .withTrackTotalHits(true)
                .build();

        org.springframework.data.elasticsearch.core.SearchHits<TransactionSearchDocument> found =
                operations.search(query, TransactionSearchDocument.class);
        List<Long> ids = found.getSearchHits().stream()
                .map(hit -> Long.valueOf(hit.getId()))
                .toList();
        return new SearchHits(ids, found.getTotalHits());
    }
}
