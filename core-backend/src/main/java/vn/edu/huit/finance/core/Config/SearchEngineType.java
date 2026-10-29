package vn.edu.huit.finance.core.Config;

import java.util.Locale;

/** Where the transactions are searched, from {@code app.search.engine} (search.properties, env SEARCH_ENGINE). */
public enum SearchEngineType {

    /** The Elasticsearch index, kept in step with PostgreSQL after every commit (TransactionSearchIndexer). */
    ELASTICSEARCH,

    /** PostgreSQL only: no Elasticsearch bean does anything, none is ever contacted. The default. */
    POSTGRES;

    /** The value of {@code app.search.engine} that turns Elasticsearch on, usable in annotations (ConditionalOnProperty). */
    public static final String ELASTICSEARCH_VALUE = "elasticsearch";

    /** The engine named by {@code value}, case and surrounding blanks ignored; blank means POSTGRES. */
    public static SearchEngineType from(String value) {
        if (value == null || value.isBlank()) {
            return POSTGRES;
        }
        try {
            return valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException(
                    "app.search.engine must be elasticsearch or postgres, not '" + value + "'", e);
        }
    }
}
