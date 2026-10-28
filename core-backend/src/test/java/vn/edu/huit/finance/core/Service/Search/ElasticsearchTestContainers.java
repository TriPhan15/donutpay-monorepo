package vn.edu.huit.finance.core.Service.Search;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import org.springframework.data.elasticsearch.client.ClientConfiguration;
import org.springframework.data.elasticsearch.client.elc.ElasticsearchClients;
import org.springframework.data.elasticsearch.client.elc.ElasticsearchTemplate;
import org.springframework.data.elasticsearch.core.convert.ElasticsearchCustomConversions;
import org.springframework.data.elasticsearch.core.convert.MappingElasticsearchConverter;
import org.springframework.data.elasticsearch.core.mapping.SimpleElasticsearchMappingContext;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;

import java.time.Duration;
import java.util.List;

/**
 * A real Elasticsearch for the integration tests, the image of the elasticsearch service of docker-compose.yml. Security
 * is switched off inside this throwaway container only (the compose service keeps it on), with a small heap. The test
 * classes that use it are skipped where Docker is not available.
 */
public final class ElasticsearchTestContainers {

    /** Keep in step with the elasticsearch service of docker-compose.yml. */
    public static final String IMAGE = "elasticsearch:8.11.4";
    public static final int PORT = 9200;

    private ElasticsearchTestContainers() {
    }

    public static GenericContainer<?> newElasticsearch() {
        return new GenericContainer<>(DockerImageName.parse(IMAGE))
                .withExposedPorts(PORT)
                .withEnv("discovery.type", "single-node")
                .withEnv("xpack.security.enabled", "false")
                // As in docker-compose.yml: a write into a missing index fails instead of creating it with a dynamic mapping.
                .withEnv("action.auto_create_index", "false")
                // A host disk over 90% full would keep the shards unassigned (high watermark): irrelevant for a throwaway test cluster.
                .withEnv("cluster.routing.allocation.disk.threshold_enabled", "false")
                .withEnv("ES_JAVA_OPTS", "-Xms256m -Xmx256m")
                .waitingFor(Wait.forHttp("/_cluster/health").forPort(PORT).forStatusCode(200)
                        .withStartupTimeout(Duration.ofMinutes(2)));
    }

    /** {@code host:port} of {@code elasticsearch} as seen from the tests. */
    public static String hostAndPort(GenericContainer<?> elasticsearch) {
        return elasticsearch.getHost() + ":" + elasticsearch.getMappedPort(PORT);
    }

    /** A client for {@code hostAndPort}, with short timeouts, the way search.properties configures the application. */
    public static ElasticsearchClient clientFor(String hostAndPort) {
        return ElasticsearchClients.createImperative(ClientConfiguration.builder()
                .connectedTo(hostAndPort)
                .withConnectTimeout(Duration.ofSeconds(1))
                .withSocketTimeout(Duration.ofSeconds(5))
                .build());
    }

    /**
     * A template wired the way Spring Boot's ElasticsearchDataAutoConfiguration wires the application's: the mapping
     * context knows the simple types of the default conversions (BigDecimal among them, written as a double).
     */
    public static ElasticsearchTemplate templateFor(ElasticsearchClient client) {
        ElasticsearchCustomConversions conversions = new ElasticsearchCustomConversions(List.of());
        SimpleElasticsearchMappingContext mappingContext = new SimpleElasticsearchMappingContext();
        mappingContext.setSimpleTypeHolder(conversions.getSimpleTypeHolder());
        MappingElasticsearchConverter converter = new MappingElasticsearchConverter(mappingContext);
        converter.setConversions(conversions);
        converter.afterPropertiesSet();
        return new ElasticsearchTemplate(client, converter);
    }
}
