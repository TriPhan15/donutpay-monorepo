package vn.edu.huit.finance.core.Config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

/**
 * Search of the transactions. Loads search.properties (lowest precedence) and says which engine is on. With the default
 * {@code app.search.engine=postgres} the Elasticsearch client that Spring Boot creates is never used: the beans that talk
 * to Elasticsearch ({@code TransactionSearchIndexer}) exist only with {@code app.search.engine=elasticsearch}, Spring
 * Data Elasticsearch repositories are off and Elasticsearch takes no part in the health of the API.
 */
@Slf4j
@Configuration
@PropertySource("classpath:search.properties")
public class SearchConfig {

    public static final String ENGINE_PROPERTY = "app.search.engine";

    @Bean
    public SearchEngineType searchEngineType(@Value("${" + ENGINE_PROPERTY + ":postgres}") String engine) {
        SearchEngineType type = SearchEngineType.from(engine);
        log.info("Transaction search engine: {}", type);
        return type;
    }
}
