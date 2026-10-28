package vn.edu.huit.finance.core.Config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import jakarta.persistence.EntityManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.data.elasticsearch.core.ElasticsearchOperations;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Service.Search.TransactionSearchIndexer;

import java.util.concurrent.Executor;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

/**
 * Which search engine is on, and that PostgreSQL mode never builds the indexer (so nothing ever talks to Elasticsearch).
 * No Spring Boot application and no Elasticsearch: SearchConfig and the indexer alone, with mocks for what the indexer
 * would need.
 */
class SearchConfigTest {

    private final ElasticsearchOperations operations = mock(ElasticsearchOperations.class);

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(SearchConfig.class, TransactionSearchIndexer.class)
            .withBean(ElasticsearchOperations.class, () -> operations)
            .withBean(TransactionRepository.class, () -> mock(TransactionRepository.class))
            .withBean(PlatformTransactionManager.class, () -> mock(PlatformTransactionManager.class))
            .withBean(EntityManager.class, () -> mock(EntityManager.class))
            .withBean("mongoAsyncExecutor", Executor.class, () -> Runnable::run);

    @Test
    void postgresEngine_noIndexerBean() {
        runner.withPropertyValues("app.search.engine=postgres").run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).doesNotHaveBean(TransactionSearchIndexer.class);
            assertThat(ctx.getBean(SearchEngineType.class)).isEqualTo(SearchEngineType.POSTGRES);
        });
        verifyNoInteractions(operations);
    }

    @Test
    void engineUnset_meansPostgres_fromSearchProperties() {
        runner.run(ctx -> {
            assertThat(ctx).doesNotHaveBean(TransactionSearchIndexer.class);
            assertThat(ctx.getBean(SearchEngineType.class)).isEqualTo(SearchEngineType.POSTGRES);
            assertThat(ctx.getEnvironment().getProperty("spring.data.elasticsearch.repositories.enabled")).isEqualTo("false");
            assertThat(ctx.getEnvironment().getProperty("management.health.elasticsearch.enabled")).isEqualTo("false");
        });
    }

    @Test
    void elasticsearchEngine_hasIndexerBean() {
        runner.withPropertyValues("app.search.engine=elasticsearch").run(ctx -> {
            assertThat(ctx).hasSingleBean(TransactionSearchIndexer.class);
            assertThat(ctx.getBean(SearchEngineType.class)).isEqualTo(SearchEngineType.ELASTICSEARCH);
        });
    }

    @Test
    void engineNames_areReadWithoutRegardToCase() {
        assertEquals(SearchEngineType.ELASTICSEARCH, SearchEngineType.from(" Elasticsearch "));
        assertEquals(SearchEngineType.POSTGRES, SearchEngineType.from("POSTGRES"));
        assertEquals(SearchEngineType.POSTGRES, SearchEngineType.from(""));
        assertThrows(IllegalArgumentException.class, () -> SearchEngineType.from("solr"));
    }
}
