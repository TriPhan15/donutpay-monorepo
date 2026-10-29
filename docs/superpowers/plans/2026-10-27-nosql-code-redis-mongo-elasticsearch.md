# NoSQL code: Redis leaderboard, MongoDB OCR analytics, Elasticsearch search — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the code half of the NoSQL coursework as real LedgerMind features: a monthly spending leaderboard on a Redis Sorted Set, automatic OCR correction analytics in MongoDB, and full-text transaction search on Elasticsearch with a Postgres fallback, plus the per-database scripts to hand in.

**Architecture:** PostgreSQL stays the only source of truth. Every write that changes a transaction publishes one new in-transaction event (`TransactionChangedEvent`); after commit, async listeners update the Redis leaderboard and the Elasticsearch index, the same pattern `OcrMongoService` and `StatisticsCacheEvictor` already use. Search asks Elasticsearch only for ids, then loads the rows from Postgres scoped to the caller, so a stale or foreign index entry can never leak.

**Tech Stack:** Java 21, Spring Boot 3.2.5, Spring Data Redis/MongoDB/Elasticsearch (Boot-managed 5.2.x, client 8.11), Elasticsearch/Kibana 8.11.4, Testcontainers `GenericContainer`, Flutter (Dio, `RemoteApiHelper`, `AppRepository`).

**Spec:** `docs/superpowers/specs/2026-10-26-nosql-report-and-elasticsearch-design.md` (sections 4, 5, 10). This plan covers only the code (spec section 8, step 1). The NoSQL Word report and the thesis update get their own plans once this lands, because they cite its real behaviour and screenshots.

## Global Constraints

- Follow `CLAUDE.md`: PascalCase packages under `vn.edu.huit.finance.core`, `ApiResponse<T>` envelope, DTOs `<Feature>RequestDto/ResponseDto` with Lombok `@Builder`, caller from `CurrentUserProvider` (never from request), Vietnamese `message` strings and comments, English identifiers, no magic strings or numbers (constants/enums), no N+1 (`JOIN FETCH` / one batched `findAllById`).
- `TransactionResponseDto.from` stays the only entity-to-DTO mapping for transactions.
- Admin JSON endpoints live under `/api/admin/**` (already admin-only in security config; verify, don't re-guard).
- Allowed dependency/infra edits, and only these: add `spring-boot-starter-data-elasticsearch` to `core-backend/pom.xml`; add `elasticsearch` (profile `search`) and `kibana` (profile `tools`) services to `docker-compose.yml`; new env keys in `.env.example`.
- `application.yml` is git-ignored: new defaults go in tracked `.properties` files loaded with `@PropertySource`, like `redis-cache.properties`.
- Redis keeps no persistence and no `KEYS`; everything in Redis must be rebuildable from Postgres.
- A failure of Redis, MongoDB or Elasticsearch is logged (`log.warn`/`log.error`) and never fails or rolls back the Postgres write.
- `SEARCH_ENGINE` = `elasticsearch` | `postgres`, property `app.search.engine`, default `postgres`. With `postgres` the app starts and searches without any Elasticsearch running.
- Elasticsearch: single node, `ES_JAVA_OPTS=-Xms512m -Xmx512m`, container memory limit 1G, security on (`ELASTIC_PASSWORD` from `.env`), port bound to `127.0.0.1` only.
- No `git add/commit/push` by the agent: each task ends with a checkpoint where the user commits. No commit trailers.
- Tests: run only the test classes a step names (backend: system `mvn -o -B test -Dtest=...` per the backend runbook; mobile: `flutter test test/<file> 2>&1 | tail -50`). Never the full suite, never start the app.

## Review Focus

1. **Search text with special characters** (`50%`, `a_b`, `(`, `"`, `\`, `*`): expected a normal result list, never 500. Elasticsearch uses `multi_match` (never `query_string`), Postgres `LIKE` escapes `%`, `_`, `\`. Tests in Task 4 and Task 5.
2. **Another user's or a deleted transaction still in the index**: never returned. Ids from Elasticsearch are reloaded from Postgres with `userId = caller`, and missing ids are dropped. Test in Task 5.
3. **Vietnamese case and diacritics** (`PHỞ`, `Đà Nẵng`, `pho`, `da nang`): all match each other. Test in Task 4.
4. **An expense whose date moves to another month, or that flips to income**: both months' leaderboard scores are recomputed. Test in Task 1.
5. **Editing a receipt field back to the AI's own value, or editing the same field twice**: no doc for the first, a single upserted doc for the second. Test in Task 2.

---

### Task 1: `TransactionChangedEvent` + monthly spending leaderboard (Redis Sorted Set)

**Files:**
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Dto/TransactionChangedEvent.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Service/Cache/SpendingLeaderboardService.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Controller/AdminLeaderboardController.java`
- Modify: `core-backend/src/main/java/vn/edu/huit/finance/core/Service/TransactionService.java` (`create` ~l.222, `updateTransaction` ~l.290, `deleteTransaction` ~l.310, `approveReceipt` ~l.391: publish next to each existing `StatisticsChangedEvent`)
- Modify: `core-backend/src/main/java/vn/edu/huit/finance/core/Repository/TransactionRepository.java` (replace `findTopSpenders`)
- Modify: `core-backend/src/main/java/vn/edu/huit/finance/core/Controller/AdminController.java:110-121` + its dashboard template under `src/main/resources/templates/` (month picker)
- Modify: `core-backend/src/main/java/vn/edu/huit/finance/core/Dto/TopSpenderDto.java` (javadoc "of one month", add `Long userId`)
- Remove the `admin-top-spenders` cache group: `Service/AdminStatisticsService.java:79-90`, `Service/Cache/CacheNames.java`, `Service/Cache/StatisticsChange.java`, `Config/CacheConfig.java:90`, `Config/StatisticsCacheProperties.java`, `src/main/resources/redis-cache.properties` (`app.cache.ttl.admin-top-spenders`), and every test that names it.
- Modify: `src/main/resources/redis-cache.properties`: add `app.leaderboard.ttl=${LEADERBOARD_TTL:62d}`
- Test: `core-backend/src/test/java/vn/edu/huit/finance/core/Service/SpendingLeaderboardServiceIntegrationTest.java` (uses `Config/RedisTestContainers`), `.../Service/SpendingLeaderboardServiceTest.java` (Mockito, Redis down), `.../Service/TransactionServiceTest.java` (event published)

**Interfaces:**
- Produces:
  - `public record TransactionChangedEvent(Long transactionId, Long userId, Kind kind, Set<YearMonth> expenseMonths)` with `enum Kind { UPSERTED, DELETED }` and factories `upserted(Long transactionId, Long userId, Set<YearMonth> expenseMonths)`, `deleted(Long transactionId, Long userId, Set<YearMonth> expenseMonths)`. `expenseMonths` holds every month whose expense total this write may have changed (empty set = only searchable text changed).
  - `SpendingLeaderboardService.KEY_PREFIX = "ledgermind:leaderboard:spend:"`, `static String keyOf(YearMonth month)` → e.g. `ledgermind:leaderboard:spend:2026-10`.
  - `List<TopSpenderDto> topSpenders(YearMonth month, int limit)`
  - `@Async("mongoAsyncExecutor") @TransactionalEventListener(phase = AFTER_COMMIT) void onTransactionChanged(TransactionChangedEvent event)`. Reuse that existing bean from `Config/AsyncConfig.java` for every NoSQL after-commit write in this plan; do not add a pool. It drops a task when its queue is full, which is acceptable because scores are absolute and the index has `reindexAll`.
  - Repository: `List<Object[]> sumExpensesByUserBetween(LocalDateTime start, LocalDateTime end)` → rows `[Long userId, String username, BigDecimal total]`, highest first; existing `sumExpensesBetween(userId, start, end)` is reused per user.
  - `GET /api/admin/leaderboard?month=yyyy-MM&limit=10` → `ApiResponse<List<TopSpenderDto>>`, `limit` 1..50 (`@Min/@Max`), month defaults to `YearMonth.now()`.

- [ ] **Step 1: Write failing integration tests** (`SpendingLeaderboardServiceIntegrationTest`, real Redis container, repositories mocked):
  - `topSpenders_missingKey_rebuildsFromPostgresAndSetsTtl`: repo returns `[1,"an",300000]`, `[2,"binh",500000]` → result order `binh, an`; `ZCARD key == 2`; `0 < TTL <= 62 days`.
  - `topSpenders_existingKey_doesNotQueryPostgres`: second call → `verify(repo, times(1)).sumExpensesByUserBetween(...)`.
  - `onTransactionChanged_setsAbsoluteMonthlyTotal`: key exists; `sumExpensesBetween(1, Oct)` returns 450000 → `ZSCORE key "1" == 450000`.
  - `onTransactionChanged_totalZero_removesMember`: sum returns null → member `1` gone.
  - `onTransactionChanged_dateMovedAcrossMonths_recomputesBothMonths` (Review Focus 4): event months `{2026-09, 2026-10}`, both keys exist → both scores updated from the repo.
  - `onTransactionChanged_missingKey_leavesItMissing`: no key → nothing written (rebuilt lazily on the next read).
  - `topSpenders_usernamesLoadedInOneQuery`: `verify(userRepo, times(1)).findAllById(anyCollection())`.
- [ ] **Step 2: Run, expect compile failure / FAIL:** `mvn -o -B test -Dtest=SpendingLeaderboardServiceIntegrationTest`
- [ ] **Step 3: Implement the event and `SpendingLeaderboardService`.** Scores are absolute (`ZADD` with the Postgres sum), never `ZINCRBY` deltas, so a missed or repeated event self-heals on the next change. `topSpenders` uses `ZREVRANGE 0 limit-1 WITHSCORES`. Rebuild writes all members, then `EXPIRE`. A `DataAccessException` from Redis in `topSpenders` logs a warning and answers straight from `sumExpensesByUserBetween` (limited); in the listener it only logs.
- [ ] **Step 4: Run, expect PASS** (same command).
- [ ] **Step 5: Write failing unit tests:** `SpendingLeaderboardServiceTest.topSpenders_redisDown_answersFromPostgres` (template throws `RedisConnectionFailureException`), and in `TransactionServiceTest`: `create_expense_publishesUpsertedWithItsMonth`, `update_dateToNextMonth_publishesBothMonths`, `update_noteOnly_publishesEmptyMonths`, `delete_publishesDeletedWithItsMonth`, `approveReceipt_amountChanged_publishesUpserted`. Use `ArgumentCaptor` on `eventPublisher`. Months are those where the transaction was an expense before or after the write.
- [ ] **Step 6: Publish the event in the four `TransactionService` methods**, next to the existing `StatisticsChangedEvent` calls.
- [ ] **Step 7: Switch the admin dashboard and REST endpoint to `topSpenders(month, limit)`** and remove the `admin-top-spenders` cache group everywhere listed above. Dashboard: `@RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM") YearMonth month`, model attribute `topSpendersMonth`, an `<input type="month">` in the existing top-spenders card. Heading text: `"Top chi tiêu tháng"`.
- [ ] **Step 8: Run:** `mvn -o -B test -Dtest='SpendingLeaderboardService*,TransactionServiceTest,RedisStatisticsCacheIntegrationTest,RedisOutageTest,AdminStatisticsService*,AdminController*'`. Expected: all PASS, and `grep -rn ADMIN_TOP_SPENDERS core-backend/src` prints nothing.
- [ ] **Step 9: Checkpoint.** Report the changed files; the user commits (`feat(backend): monthly spending leaderboard on a Redis sorted set`).

### Task 2: MongoDB OCR correction analytics (`ocr_feedbacks` automatic + admin CRUD/stats)

**Files:**
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Document/OcrField.java` (enum)
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Dto/OcrCorrectionEvent.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Service/OcrCorrectionDetector.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Controller/AdminOcrFeedbackController.java`
- Create DTOs: `Dto/OcrFeedbackFilterRequestDto.java`, `Dto/OcrFeedbackResponseDto.java`, `Dto/OcrAnalyticsResponseDto.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Exception/OcrFeedbackNotFoundException.java` + mapping in `GlobalExceptionHandler` (404, same shape as `ReceiptNotFoundException`; read the handler first)
- Modify: `Document/OcrRawLog.java` (add `modelVersion`, nested `aiReading`), `Document/OcrFeedback.java` (add `transactionId`, `modelVersion`, `updatedAt`; `@CompoundIndex(name = "receipt_field_uq", def = "{'receiptId': 1, 'fieldError': 1}", unique = true)`)
- Modify: `Service/OcrMongoService.java` (listener for the new event, filter/resolve/delete/stats), `Repository/Mongo/OcrFeedbackRepository.java`
- Modify: `Service/ReceiptProcessingService.java`: `recordAttachedReceipt` ~l.154, `editMyReceipt` ~l.198, `submitFeedback` ~l.311
- Modify: `Config/MongoDataSeeder.java` (use `OcrField` values instead of its private string constants)
- Test: `.../Service/OcrCorrectionDetectorTest.java`, `.../Service/OcrMongoServiceMongoIntegrationTest.java` (`GenericContainer` `mongo:6.0`), `.../Service/ReceiptProcessingServiceTest.java`, `.../Controller/AdminOcrFeedbackControllerTest.java` (WebMvc security slice)

**Interfaces:**
- Consumes: `OcrService.extract(String raw) -> ExtractedReceiptDto` (existing), latest `ReceiptProcessingAttempt.getAiRawData()`.
- Produces:
  - `enum OcrField { SELLER_NAME("seller_name"), TOTAL_COST("total_cost"), RECEIPT_DATE("receipt_date") }` with `String key()`. The stored `fieldError` is `key()`, matching the seeded data.
  - `record OcrFieldCorrection(OcrField field, String aiValue, String expectedValue)`. Values as strings: money `toPlainString()` scale-stripped, dates ISO `yyyy-MM-dd`, `aiValue` null when the AI read nothing.
  - `record OcrCorrectionEvent(Long receiptId, Long transactionId, Long userId, List<OcrFieldCorrection> corrections)`.
  - `List<OcrFieldCorrection> OcrCorrectionDetector.diff(ExtractedReceiptDto ai, String seller, BigDecimal total, LocalDate date)`: a null user value means "not sent" and yields nothing; money compared with `compareTo`; seller compared trimmed and case-sensitive.
  - `OcrMongoService`: `Page<OcrFeedbackResponseDto> findFeedbacks(OcrFeedbackFilterRequestDto filter, Pageable pageable)`, `OcrFeedbackResponseDto resolveFeedback(String id)` (replaces the boolean version), `void deleteFeedback(String id)`, `OcrAnalyticsResponseDto analytics(LocalDate from, LocalDate to)`.
  - `OcrAnalyticsResponseDto { List<FieldCount> errorsByField; List<ModelCount> errorsByModel; List<MonthlyConfidence> confidenceByMonth; double receiptsWithErrorRate; }`. The rate is distinct feedback `receiptId` count / `ocr_logs` count in the range.
  - Endpoints under `/api/admin/ocr-feedbacks`: `GET` (query: `field`, `resolved`, `from`, `to`, `page`, `size`, `sort=reportedAt,desc` default), `PATCH /{id}/resolve`, `DELETE /{id}`, `GET /analytics?from&to`. All `ApiResponse`.
  - Property `app.ocr.model-version=${OCR_MODEL_VERSION:donut-v5}` in new tracked `src/main/resources/ocr-analytics.properties`, loaded with `@PropertySource` on the Mongo config class (or `AsyncConfig` if none exists).

- [ ] **Step 1: Write `OcrCorrectionDetectorTest`:** `sameValues_noCorrection` (Review Focus 5), `totalDiffers_oneTotalCorrection("120000","150000")`, `scaleOnly_120000_vs_120000.00_noCorrection`, `aiReadNothing_aiValueNull`, `nullUserValues_ignored`, `sellerTrimmedEqual_noCorrection`.
- [ ] **Step 2: Run, expect FAIL**, implement `OcrField`, the records and `OcrCorrectionDetector`, run again, expect PASS: `mvn -o -B test -Dtest=OcrCorrectionDetectorTest`.
- [ ] **Step 3: Write `ReceiptProcessingServiceTest` cases:** `checkout_amountDiffersFromAi_publishesTotalCorrection`, `checkout_amountEqualsAi_publishesNothing`, `editMyReceipt_vendorChanged_publishesAgainstLatestAttempt` (two attempts; the diff uses the second's raw data), `submitFeedback_publishesTotalWithNullAiValue`. `recordAttachedReceipt` gets the user's amount from `receipt.getTransaction().getAmount()`.
- [ ] **Step 4: Publish `OcrCorrectionEvent` from the three methods** only when `diff` is non-empty. Run the test class, expect PASS.
- [ ] **Step 5: Write `OcrMongoServiceMongoIntegrationTest`** (real `mongo:6.0`; skipped without Docker like the Redis ITs): `correction_upsertsOneDocPerReceiptField` (same event twice with different expected values → 1 doc, latest value, `isResolved=false`, `reportedAt` unchanged); `rawLog_storesModelVersionAndAiReading`; `findFeedbacks_filtersByFieldAndResolved_sortedNewestFirst`; `analytics_groupsByFieldAndModel_andMonthlyConfidence`; `resolve_unknownId_throwsNotFound`; `delete_removesDoc`.
- [ ] **Step 6: Implement** the listener (`@Async("mongoAsyncExecutor")` + `@TransactionalEventListener(AFTER_COMMIT)`, `MongoTemplate.upsert` keyed on `receiptId + fieldError`, `$setOnInsert reportedAt`, `$set` the rest), the filter with `Criteria` (no hand-built JSON), and the analytics with `Aggregation.newAggregation` (`match → group → sort`). Run the IT, expect PASS.
- [ ] **Step 7: Write `AdminOcrFeedbackControllerTest`:** `user_role_gets403`, `admin_list_200_withPage`, `admin_resolve_unknown_404`, `admin_size_over_100_400`. Implement the controller. Run, expect PASS.
- [ ] **Step 8: Run the touched classes together:** `mvn -o -B test -Dtest='OcrCorrectionDetectorTest,OcrMongoService*,ReceiptProcessingServiceTest,AdminOcrFeedbackControllerTest,MongoDataSeederTest'`. Expected PASS.
- [ ] **Step 9: Checkpoint**: user commits (`feat(backend): OCR correction analytics in MongoDB`).

### Task 3: Elasticsearch infrastructure, index and after-commit sync

**Files:**
- Modify: `core-backend/pom.xml` (add `spring-boot-starter-data-elasticsearch`, Boot-managed version)
- Modify: `docker-compose.yml` (services `elasticsearch` profile `search`, `kibana` profile `tools`; core-api env `SEARCH_ENGINE`, `ELASTICSEARCH_URIS`, `ELASTIC_PASSWORD`), `.env.example`
- Create: `core-backend/src/main/resources/search.properties`, `core-backend/src/main/resources/elasticsearch/transactions-settings.json`, `.../elasticsearch/transactions-mapping.json`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Config/SearchConfig.java` (`@PropertySource("classpath:search.properties")`)
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Document/Search/TransactionSearchDocument.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Service/Search/TransactionSearchIndexer.java`
- Create: `core-backend/src/main/java/vn/edu/huit/finance/core/Controller/AdminSearchController.java`
- Modify: `Repository/TransactionRepository.java` (two fetch queries), `Service/ReceiptProcessingService.java` (`editMyReceipt`: publish `TransactionChangedEvent.upserted(txId, userId, Set.of())` when the vendor changed)
- Test: `.../Service/Search/ElasticsearchTestContainers.java`, `.../Service/Search/TransactionSearchIndexerIntegrationTest.java`

**Interfaces:**
- Consumes: `TransactionChangedEvent` (Task 1).
- Produces:
  - `search.properties`: `app.search.engine=${SEARCH_ENGINE:postgres}`, `spring.elasticsearch.uris=${ELASTICSEARCH_URIS:http://localhost:9200}`, `spring.elasticsearch.username=${ELASTIC_USERNAME:elastic}`, `spring.elasticsearch.password=${ELASTIC_PASSWORD:}`, `spring.elasticsearch.connection-timeout=1s`, `spring.elasticsearch.socket-timeout=2s`, `spring.data.elasticsearch.repositories.enabled=false`, `management.health.elasticsearch.enabled=false`.
  - `SearchEngineType { ELASTICSEARCH, POSTGRES }` enum, bound from `app.search.engine`.
  - `TransactionSearchDocument` (`@Document(indexName = "transactions", createIndex = false)`, `@Setting(settingPath = "elasticsearch/transactions-settings.json")`, `@Mapping(mappingPath = "elasticsearch/transactions-mapping.json")`): `String id`, `Long userId`, `String note`, `String categoryName`, `String location`, `String paymentMethod`, `String vendorName`, `BigDecimal amount`, `boolean expense`, `LocalDateTime transactionDate`, `String receiptStatus`; `static TransactionSearchDocument from(Transaction t)`.
  - `TransactionSearchIndexer` (bean only when engine = elasticsearch, `@ConditionalOnProperty(name = "app.search.engine", havingValue = "elasticsearch")`): `onTransactionChanged(TransactionChangedEvent)` (async after commit; UPSERTED → load + save, DELETED → delete by id), `int reindexAll()` (drops and recreates the index from settings/mapping, then bulk-saves pages of 500), `void ensureIndex()` on `ApplicationReadyEvent` (creates it if missing; failure only logs).
  - Repository: `Optional<Transaction> findForSearchIndex(Long id)` and `Page<Transaction> findPageForSearchIndex(Pageable p)`, both `LEFT JOIN FETCH t.receipt`, with `countQuery` on the page one.
  - `POST /api/admin/search/reindex` → `ApiResponse<Integer>` (documents indexed); 503-style `ApiResponse` when engine = postgres (message `"Tìm kiếm Elasticsearch đang tắt"`).
- Exact analysis settings (`transactions-settings.json`):

```json
{
  "number_of_shards": 1,
  "number_of_replicas": 0,
  "analysis": {
    "filter": { "vi_edge": { "type": "edge_ngram", "min_gram": 2, "max_gram": 15 } },
    "analyzer": {
      "vi_folded": { "type": "custom", "tokenizer": "standard", "filter": ["lowercase", "asciifolding"] },
      "vi_autocomplete": { "type": "custom", "tokenizer": "standard", "filter": ["lowercase", "asciifolding", "vi_edge"] }
    }
  }
}
```

  Mapping: `note`, `vendorName`, `location`, `categoryName`, `paymentMethod` are `text` with `analyzer: vi_folded`. `note` and `vendorName` also get a subfield `autocomplete` (`analyzer: vi_autocomplete`, `search_analyzer: vi_folded`). `categoryName` also gets a `keyword` subfield (for aggregations); `userId` is `long`, `receiptStatus` is `keyword`, `amount` is `scaled_float` with `scaling_factor` 100, `expense` is `boolean`, `transactionDate` is `date`.
- Compose `elasticsearch`: image `elasticsearch:8.11.4`, `discovery.type=single-node`, `xpack.security.enabled=true`, `xpack.security.http.ssl.enabled=false` (internal network only), `ELASTIC_PASSWORD=${ELASTIC_PASSWORD:?...}`, `ES_JAVA_OPTS=-Xms512m -Xmx512m`, `path.repo=/usr/share/elasticsearch/snapshots` (volume, for the backup script), healthcheck `curl -fsu elastic:$$ELASTIC_PASSWORD http://localhost:9200/_cluster/health`, memory limit `1G`, ports `127.0.0.1:9200:9200`, comment block in the file's existing numbered style. `kibana`: image `kibana:8.11.4`, profile `tools`, `127.0.0.1:5601:5601`, connects with a `kibana_system` password (`KIBANA_PASSWORD`; document the one-time `elasticsearch-reset-password -u kibana_system` in `.env.example`).

- [ ] **Step 1: Write `TransactionSearchIndexerIntegrationTest`** (`elasticsearch:8.11.4` via `GenericContainer`, security off in the test container, `wait` on `/_cluster/health`; skipped without Docker): `ensureIndex_createsIndexWithViAnalyzer` (`_analyze` with `vi_folded` on `"PHỞ Đà Nẵng"` → tokens `pho, da, nang`; Review Focus 3); `upsertedEvent_indexesTransactionWithVendor`; `deletedEvent_removesDocument`; `reindexAll_indexesEveryRow_inPagesOf500` (repo mocked with 2 pages); `esDown_listenerLogsAndDoesNotThrow`.
- [ ] **Step 2: Run, expect FAIL:** `mvn -o -B test -Dtest=TransactionSearchIndexerIntegrationTest` (offline resolution needs the new starter in the scratchpad `~/.m2` copy: run one online `mvn -B dependency:resolve` first, the only online call in this plan).
- [ ] **Step 3: Implement** the pom line, properties, JSON files, document, indexer, repository queries, `editMyReceipt` publish and admin controller. Run the IT again, expect PASS.
- [ ] **Step 4: Check that Postgres mode starts without Elasticsearch:** a `@SpringBootTest`-free check is enough. Add `SearchConfigTest.postgresEngine_noIndexerBean` using `ApplicationContextRunner` with `app.search.engine=postgres` → `assertThat(ctx).doesNotHaveBean(TransactionSearchIndexer.class)`. Run, expect PASS.
- [ ] **Step 5: Validate compose:** `docker compose --profile search --profile tools config -q` prints nothing, exit 0. Do not `up` anything (the local `finance-*` stack must not be touched).
- [ ] **Step 6: Checkpoint**: user commits (`feat(backend): Elasticsearch transaction index synced after commit`).

### Task 4: Search API with Postgres fallback

**Files:**
- Create: `Dto/TransactionSearchRequestDto.java`, `Dto/TransactionSearchResponseDto.java`
- Create: `Service/Search/TransactionSearchEngine.java` (interface), `Service/Search/ElasticsearchTransactionSearchEngine.java`, `Service/Search/PostgresTransactionSearchEngine.java`, `Service/Search/TransactionSearchService.java`
- Modify: `Controller/TransactionController.java` (new `GET /search`), `Repository/TransactionRepository.java` (two queries)
- Test: `.../Service/Search/TransactionSearchServiceTest.java`, `.../Service/Search/ElasticsearchTransactionSearchEngineIntegrationTest.java` (reuses `ElasticsearchTestContainers`), `.../Repository/TransactionSearchRepositoryTest.java` (H2 slice), `.../Controller/TransactionSearchControllerTest.java` (WebMvc)

**Interfaces:**
- Consumes: Task 3's index/document; `CurrentUserProvider.getCurrentUser()`.
- Produces:
  - `TransactionSearchRequestDto { @NotBlank @Size(min = 2, max = 100) String q; @Min(0) int page = 0; @Min(1) @Max(50) int size = 20; }`, bound with `@Valid @ModelAttribute`, like `/filter`.
  - `TransactionSearchResponseDto { List<TransactionResponseDto> items; long total; String engine; }`. `engine` is `"elasticsearch"` or `"postgres"`, whichever actually answered.
  - `interface TransactionSearchEngine { SearchHits hits(Long userId, String q, Pageable page); }` with `record SearchHits(List<Long> ids, long total)`.
  - `TransactionSearchService.search(TransactionSearchRequestDto req) -> TransactionSearchResponseDto`: hits → `transactionRepo.findAllByIdInAndUserIdWithReceipt(ids, userId)` (JOIN FETCH category + receipt) → reorder by hit order, drop missing ids → `TransactionResponseDto.from`. Elasticsearch throws → `log.warn`, answer with the Postgres engine.
  - Elasticsearch query: `bool.filter term userId` + `multi_match` on `vendorName^3, vendorName.autocomplete^2, note^2, note.autocomplete, categoryName, location, paymentMethod`, `fuzziness AUTO`, `operator AND`, sorted by `_score` then `transactionDate desc`. Never `query_string`.
  - Postgres: `Page<Long> searchIdsByText(Long userId, String pattern, Pageable p)`: `LOWER(field) LIKE :pattern ESCAPE '\'` over note, categoryName, location, paymentMethod, receipt.vendorName (LEFT JOIN), ordered by `transactionDate desc`. Pattern built by `static String likePattern(String q)` (lowercase, escape `\ % _`, wrap in `%`).
  - `GET /api/transactions/search?q=&page=&size=` → `ApiResponse<TransactionSearchResponseDto>`, message `"Tìm kiếm giao dịch thành công"`.

- [ ] **Step 1: Write failing tests:**
  - `ElasticsearchTransactionSearchEngineIntegrationTest`: `pho_matchesPhoHung`, `daNang_matchesDaNangUppercase` (Review Focus 3), `typo_phoHug_matchesPhoHung`, `prefix_phu_matchesPhucLong`, `otherUsersDocs_neverReturned` (Review Focus 2), `specialChars_50percent_paren_quote_backslash_noException` (Review Focus 1).
  - `TransactionSearchRepositoryTest`: `likePattern_escapesPercentUnderscoreBackslash`, `searchIdsByText_matchesVendorThroughReceipt`, `searchIdsByText_onlyCallerRows`.
  - `TransactionSearchServiceTest`: `esHitsReloadedFromPostgres_inHitOrder`, `idMissingInPostgres_dropped` (Review Focus 2), `esThrows_fallsBackToPostgres_engineIsPostgres`, `engineConfiguredPostgres_neverCallsEs`, `userIdComesFromCurrentUserProvider`.
  - `TransactionSearchControllerTest`: `q_oneChar_400`, `size_51_400`, `noToken_403`, `ok_200_envelope`.
- [ ] **Step 2: Run, expect FAIL:** `mvn -o -B test -Dtest='ElasticsearchTransactionSearchEngineIntegrationTest,TransactionSearchRepositoryTest,TransactionSearchServiceTest,TransactionSearchControllerTest'`
- [ ] **Step 3: Implement** the two engines (Postgres one always a bean, Elasticsearch one conditional like the indexer), the service and the controller method.
- [ ] **Step 4: Run, expect PASS** (same command).
- [ ] **Step 5: Checkpoint**: user commits (`feat(backend): transaction search on Elasticsearch with a PostgreSQL fallback`).

### Task 5: Mobile Ledger search through the API

**Files:**
- Modify: `mobile-app/lib/services/remote_api_helper.dart` (next to `fetchTransactions` ~l.410)
- Modify: `mobile-app/lib/repositories/app_repository.dart`
- Modify: `mobile-app/lib/screens/ledger/ledger_page.dart` (search state ~l.73, filter ~l.253, `onChanged` ~l.339, `dispose`)
- Test: `mobile-app/test/ledger_search_test.dart` (fake-backend widget test, same setup as the existing Ledger/Dashboard widget tests; see the mobile runbook traps: l10n delegates, Dio zero-timer pump)

**Interfaces:**
- Consumes: `GET /api/transactions/search` (Task 4), response `data.items[].id`.
- Produces:
  - `RemoteApiHelper.searchTransactionIds(String query, {int size = 50}) -> Future<List<int>>` (ids in relevance order).
  - `AppRepository.searchTransactionIds(String query) -> Future<List<int>?>`: null on any network/server error (logged with `debugPrint`, no dialog: typing is not a user-initiated save).
  - Ledger: constants `_searchDebounce = Duration(milliseconds: 350)`, `_minServerQueryLength = 2`; state `Set<int>? _serverMatchIds`, `Timer? _searchTimer` (cancelled in `dispose`). Match rule: `_serverMatchIds == null` → the current local match; otherwise `tx.id == null ? localMatch : _serverMatchIds!.contains(tx.id)`. Period/type/amount filters and sorting stay as they are. A response for an outdated query is ignored (compare with the current `_searchQuery`), and `if (!mounted) return;` comes after the await.

- [ ] **Step 1: Write `ledger_search_test.dart`:** `serverIdsShown_evenWhenTitleHasDiacritics` (row "Phở Hùng", query "pho", server returns its id), `serverError_fallsBackToLocalFilter`, `unsyncedRow_matchedLocally_alongsideServerResults` (id null row "pho bo"), `oneCharQuery_doesNotCallServer`, `staleResponse_ignored` (first slow response for "ph" arrives after "pho").
- [ ] **Step 2: Run, expect FAIL:** `cd mobile-app && flutter test --no-pub test/ledger_search_test.dart 2>&1 | tail -50`
- [ ] **Step 3: Implement** the helper, repository and Ledger changes.
- [ ] **Step 4: Run, expect PASS** (same command), then `dart analyze lib/screens/ledger lib/services lib/repositories 2>&1 | tail -20` with no new issues (baseline 0).
- [ ] **Step 5: Checkpoint**: user commits (`feat(mobile): ledger search through the server search API`).

### Task 6: Per-database scripts to hand in (`scripts/nosql/`)

**Files:**
- Modify: `scripts/nosql/mongodb_init.js` (collections with `$jsonSchema` validators for `ocr_logs` and `ocr_feedbacks`, every index from the `@Indexed/@CompoundIndex` annotations incl. `receipt_field_uq`, ≥30 sample docs per collection with the Task 2 shape, then the queries)
- Modify: `scripts/nosql/redis_demo.txt` → keep name; sections: OTP hash + `PEXPIRE`, cache keys + `TTL`, leaderboard `ZADD/ZINCRBY/ZREVRANGE WITHSCORES/ZREVRANK/EXPIRE`, `MULTI/EXEC`, `SCAN MATCH`, `BGSAVE` demo note (production runs without persistence, and why)
- Create: `scripts/nosql/elasticsearch/README.md`, `scripts/nosql/elasticsearch/transactions-bulk.ndjson` (≥40 Vietnamese transactions, 3 users), `scripts/nosql/elasticsearch/kibana-devtools.txt` (index creation that references the settings/mapping files from Task 3 by path, no copy; `_analyze`; queries)
- Create: `scripts/nosql/backup_restore.md` (per DB: export/import + backup/restore, each as "đếm → xóa → khôi phục → đếm lại")
- Modify: `scripts/nosql/NoSQL_Postman_Collection.json` (add the Task 1, 2, 3, 4 endpoints)

**Interfaces:**
- Consumes: shapes from Tasks 1–4. Queries are numbered `Q-01…`, with ≥10 basic and ≥10 advanced in total across the three DBs, each tagged `// [CƠ BẢN]` or `// [NÂNG CAO]` and with its access pattern as a comment. The NoSQL report plan will cite them by number.
  - Mongo advanced must include `$match/$group/$sort`, `$facet`, `$lookup` (feedbacks → logs by `transactionId`), `$unwind`, `$dateToString` monthly confidence, `explain("executionStats")` showing `IXSCAN`.
  - Elasticsearch advanced must include fuzzy `multi_match`, autocomplete, `bool` filter by user plus date `range`, a `terms` aggregation on `categoryName.keyword`, and `date_histogram` sum of `amount`.

- [ ] **Step 1: Run `mongodb_init.js` in a throwaway container:** `docker run --rm -v "$PWD/scripts/nosql:/s:ro" mongo:6.0 bash -c 'mongod --fork --logpath /tmp/m.log && mongosh --quiet /s/mongodb_init.js'`. Expected: no error, printed counts ≥30, the explain line contains `IXSCAN`.
- [ ] **Step 2: Run the Redis script** against a throwaway `redis:8.10-alpine` (`redis-server --daemonize yes && redis-cli < /s/redis_demo.txt`). Expected: no `ERR`.
- [ ] **Step 3: Run the Elasticsearch script** against a throwaway `elasticsearch:8.11.4` (`xpack.security.enabled=false`, waiting on health, then `curl` for the bulk and every query). Expected: `"errors":false` on the bulk, and the `pho` query returns the Phở rows.
- [ ] **Step 4: Run the backup/restore walk-through for each DB** in those same throwaway containers. The counts before and after must be equal.
- [ ] **Step 5: Checkpoint**: user commits (`docs(nosql): per-database scripts, sample data and backup walk-throughs`).

---

## After this plan

1. **Plan 2: NoSQL Word report** + `BaoCaoMinhChung` (spec section 6). This starts after the user runs the stack with `--profile search --profile tools` and captures the screenshot list the plan will define.
2. **Plan 3: thesis update** (spec section 7).
