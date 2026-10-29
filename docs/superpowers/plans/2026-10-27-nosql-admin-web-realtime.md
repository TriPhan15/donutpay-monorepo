# NoSQL admin web pages + realtime admin events — Implementation Plan (plan 1b)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the NoSQL features a real admin web UI, so grading criterion 9 ("thao tác trên CSDL: thêm, xoá, sửa, tìm kiếm, backup từ giao diện") is demonstrable. The UI covers:
- OCR feedback review with analytics charts (MongoDB);
- rebuild buttons for the search index and the monthly leaderboard (Elasticsearch / Redis);
- MongoDB backup/restore on the existing backup page;
- realtime admin notifications over Redis Pub/Sub + Server-Sent Events.

**Architecture:** Thymeleaf pages under `/admin`, in the style of the existing `receipts.html`/`backup.html`, calling the services that already exist (`OcrMongoService`, `TransactionSearchIndexer`, `SpendingLeaderboardService`). MongoDB backup copies `BackupService`'s pg_dump pattern with `mongodump`/`mongorestore` installed in the image. Realtime: after commit, a domain change publishes a small JSON event to the Redis channel `ledgermind:admin-events`. Every core-api instance subscribes and forwards the event to its connected admin browsers through an `SseEmitter`. Redis Pub/Sub carries the event between instances, so this stays correct with more than one core-api. Mobile push stays future work (FCM).

**Tech Stack:** Spring MVC + Thymeleaf + Bootstrap (existing admin), Spring Data Redis `RedisMessageListenerContainer`, `SseEmitter`, Chart.js (already used by `dashboard.html`), MongoDB Database Tools 100.x in the Dockerfile.

**Spec:** `docs/superpowers/specs/2026-10-26-nosql-report-and-elasticsearch-design.md` (spec §5 extended by the user decisions of 2026-10-27: admin pages + realtime admin events; recorded in the spec's §10).

## Global Constraints

- Same rules as plan 1:
  - PascalCase packages; thin controllers; Vietnamese UI text and messages; constants, not magic strings; no N+1.
  - Admin pages under `/admin/**` are guarded like the existing ones. Check the security config and any `@PreAuthorize` on `AdminController`, then do the same.
  - A NoSQL failure is logged and shown as a friendly message, never a 500 page.
  - Keep each file's line endings (CRLF in many Java files).
  - Mobile is untouched.
- Process:
  - Implementers never commit.
  - After the review, the user runs the given test commands and says "ok", then the controller commits (no Claude trailers, no push).
  - Never start the app or touch the local stack. Testcontainers only.
- Every new page links from `templates/admin/layout/_layout.html`'s sidebar.
- Dockerfile: only add MongoDB Database Tools from MongoDB's apt repo, in the same style as the PostgreSQL client lines. Pin the tools series (100.x for jammy).
- Realtime events carry no personal data beyond ids and counts. They are admin-only, and the SSE endpoint is behind the admin guard.

## Review Focus

1. **A non-admin (or no session) opens `/admin/ocr-feedbacks` or `/admin/events`.** Expected: refused like other admin pages.
2. **MongoDB/Redis/ES down while an admin uses the new pages.** Expected: the page renders with a Vietnamese error banner; actions report failure; no 500.
3. **The SSE connection drops, or the browser tab sleeps.** Expected: `EventSource` reconnects. The server never leaks emitters: completion, timeout and error all remove them.
4. **`mongorestore` on a running app.** Expected: the restore uses `--drop` only on the two app collections, is confirmed by a dialog, and is recorded in the audit log like the PG restore.
5. **Rebuild clicked twice quickly.** Expected: the second click is refused or waits (button disabled while running; the server never runs two reindexes at once — reuse the indexer's lock).

---

### Task 1: OCR feedback admin page (MongoDB) + rebuild buttons (ES, Redis)

**Files:**
- Create:
  - `core-backend/src/main/java/vn/edu/huit/finance/core/Controller/AdminNoSqlPageController.java`, so `AdminController` does not grow;
  - `templates/admin/ocr_feedbacks.html`, `templates/admin/nosql_ops.html`.
- Modify:
  - `templates/admin/layout/_layout.html`: 2 sidebar links, "Phản hồi OCR (MongoDB)" and "Vận hành NoSQL";
  - `Service/OcrMongoService.java`, only if a method the page needs is missing.
- Test: `Controller/AdminNoSqlPageControllerTest.java`, a WebMvc security slice like `AdminDashboardPageTest`.

**Interfaces:**
- Consumes: `OcrMongoService.findFeedbacks(OcrFeedbackFilterRequestDto, Pageable)`, `resolveFeedback(String)`, `deleteFeedback(String)`, `analytics(LocalDate, LocalDate)`; `TransactionSearchIndexer.reindexAll()` (an optional bean, through `ObjectProvider` as `AdminSearchController` does); `SpendingLeaderboardService.rebuildMonth(YearMonth)`.
- Produces:
  - `GET /admin/ocr-feedbacks?field&resolved&from&to&page`: a table showing receipt, field, AI value, user value, model, reported date and status, with a filter form, pagination and per-row "Đã xử lý"/"Xóa" buttons. Above it, the analytics:
    - Chart.js bar charts: errors by field and errors by model;
    - a line chart: monthly confidence (nulls shown as gaps);
    - a KPI: receipts-with-error rate.
  - `POST /admin/ocr-feedbacks/{id}/resolve`, `POST /admin/ocr-feedbacks/{id}/delete`: redirect back with a flash message, using the PRG pattern like `/admin/receipts/approve`.
  - `GET /admin/nosql`, the operations page:
    - Elasticsearch: the current engine (`app.search.engine`), the index document count, and a "Dựng lại chỉ mục" button (disabled with a note when the engine is postgres);
    - Redis: a month picker and a "Dựng lại bảng xếp hạng tháng" button, then the top 10 of that month;
    - links to Kibana/RedisInsight/Compass instructions (text only).
  - `POST /admin/nosql/search/reindex`, `POST /admin/nosql/leaderboard/rebuild?month=`.

- [ ] **Step 1: Write the failing WebMvc tests**:
  - `ocrFeedbacks_admin_200_showsRowsAndCharts`;
  - `ocrFeedbacks_user_redirectedOrForbidden` (assert the same outcome the existing admin pages give);
  - `resolve_redirectsWithFlash`;
  - `delete_unknownId_flashError`;
  - `nosqlPage_engineFromProperty`;
  - `reindex_whenPostgresEngine_flashDisabled`;
  - `rebuildMonth_redirectsWithCount`;
  - `mongoDown_pageShowsBanner` (the service throws `DataAccessResourceFailureException`).
- [ ] **Step 2: Run, expect FAIL:** `mvn -B -o -Dmaven.repo.local=<m2> test -Dtest=AdminNoSqlPageControllerTest`.
- [ ] **Step 3: Implement** the controller, the templates and the sidebar links. Thymeleaf JS inlining escapes non-ASCII, so tests assert the escaped forms.
- [ ] **Step 4: Run, expect PASS**, plus `Admin*Test`.
- [ ] **Step 5: Checkpoint**: the user runs the command, says "ok", and the controller commits.

### Task 2: MongoDB backup/restore on the backup page

**Files:**
- Modify:
  - `core-backend/Dockerfile`: MongoDB Database Tools from `https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0` with the server key, `mongodb-database-tools` only;
  - `Service/BackupService.java`, or create `Service/MongoBackupService.java` if `BackupService` would grow past one responsibility (preferred);
  - `Controller/AdminController.java` (backup endpoints);
  - `templates/admin/backup.html`: a second card "MongoDB (ocr_logs, ocr_feedbacks)".
- Test: `Service/MongoBackupServiceTest.java` (command building, like `BackupServiceTest`) and `Service/MongoBackupServiceIntegrationTest.java`. The integration test runs `mongodump`/`mongorestore` inside the `mongo:6.0` container via `execInContainer`, because the host has no tools: it proves the exact argument list works.

**Interfaces:**
- `MongoBackupService.backup() -> boolean`:
  - `mongodump --uri=<spring.data.mongodb.uri> --db=finance_nosql --collection=…` for both collections, `--archive=<backups>/mongo_<yyyyMMdd_HHmmss>.archive.gz --gzip`;
  - files land in the existing `core_backups` volume.
- `restoreLatest() -> boolean`: `mongorestore --uri … --archive=… --gzip --drop --nsInclude=finance_nosql.ocr_logs --nsInclude=finance_nosql.ocr_feedbacks`.
- `latestBackup() -> String`.
- The URI comes from `spring.data.mongodb.uri` and is never logged; the password is masked in errors.
- Both actions write the audit log with new `AuditAction` values `MONGO_BACKUP_CREATED`/`MONGO_RESTORED`. If `AuditAction` is backed by a PostgreSQL CHECK constraint, say so: the user must run the manual SQL, as the memory notes for earlier enum additions. Put that SQL in `core-backend/src/main/resources/db/` and flag the `*.sql` ignore rule.
- Endpoints: `POST /admin/backup/mongo/execute`, `POST /admin/backup/mongo/restore` (JSON `ApiResponse`, matching the existing PG endpoints).
- [ ] Steps as in Task 1:
  - RED: the 2 test classes;
  - implement;
  - GREEN;
  - `docker build` of the image is user-run (it downloads apt packages), so give the command in the checkpoint;
  - checkpoint.

### Task 3: Realtime admin events (Redis Pub/Sub + SSE)

**Files:**
- Create:
  - `Service/Realtime/AdminEvent.java` (record);
  - `Service/Realtime/AdminEventPublisher.java`;
  - `Service/Realtime/AdminEventRelay.java` (Redis subscriber → emitters);
  - `Controller/AdminEventsController.java`;
  - `Config/RealtimeConfig.java` (`RedisMessageListenerContainer`);
  - `static/admin/js/admin-events.js`.
- Modify: `templates/admin/layout/_layout.html` (a toast area + script include, plus a badge on "Quản lý Hóa đơn AI" and "Phản hồi OCR").
- Test:
  - `Service/Realtime/AdminEventRelayIntegrationTest.java` (real Redis container: publish → a registered fake emitter receives it; two relays, i.e. two "instances", both receive);
  - `Controller/AdminEventsControllerTest.java` (admin-only, content type `text/event-stream`);
  - publisher unit tests in the existing service test classes.

**Interfaces:**
- `record AdminEvent(AdminEventType type, Long id, String message, Instant at)`, with `enum AdminEventType { RECEIPT_WAITING_REVIEW, OCR_FEEDBACK_REPORTED, SEARCH_REINDEXED, LEADERBOARD_REBUILT }`.
- Channel constant `AdminEventPublisher.CHANNEL = "ledgermind:admin-events"`. JSON via the app `ObjectMapper`.
- `AdminEventPublisher.publish(AdminEvent)`: `StringRedisTemplate.convertAndSend`, and any Redis failure is only logged.
- Called **after commit** in these places:
  - `ReceiptProcessingService.submitFeedback`, when the receipt becomes WAITING_FOR_REVIEW: a `@TransactionalEventListener` on a small new Spring event, or reuse an existing event if one already fires there;
  - `OcrMongoService` after a correction upsert: already async after commit, so publish at the end;
  - the reindex and rebuild actions of Task 1.
- `AdminEventRelay`:
  - a `MessageListener` on the channel;
  - holds a thread-safe set of `SseEmitter`s;
  - `register()` returns a new emitter (timeout 30 min, heartbeat comment every 25 s through a `@Scheduled` method) and removes it on completion/timeout/error;
  - sends `event: admin` with the JSON;
  - sends never block the listener thread for long: catch `IOException`, then remove the emitter.
- `GET /admin/events` (produces `text/event-stream`, admin-only) → `relay.register()`.
- `admin-events.js`: an `EventSource('/admin/events')` that shows a Bootstrap toast with the message, bumps the sidebar badge, and on the receipts/OCR pages shows a "Có dữ liệu mới – tải lại" bar. `EventSource` reconnects on its own.
- Caddy: confirm `/admin/events` is proxied without buffering (`flush_interval -1` for that path if needed, in `deploy/caddy/Caddyfile`) and document it.
- [ ] Steps as in Task 1: RED (3 test classes) → implement → GREEN (+ `TransactionService*Test`, `*Receipt*Test`, `OcrMongoService*`, slice classes with `@Import` lists if a new bean is injected into an imported service) → checkpoint.

### Task 4: Scripts and docs follow-up

- [ ] Update:
  - `scripts/nosql/redis_demo.txt` (a Pub/Sub section: `SUBSCRIBE ledgermind:admin-events` / `PUBLISH`, tagged [NÂNG CAO], as Q-41);
  - `scripts/nosql/backup_restore.md` (the Mongo backup from the admin page);
  - `scripts/nosql/NoSQL_Postman_Collection.json` (the new admin endpoints).
- [ ] Verify the Redis demo file in a throwaway `redis:8.10-alpine` (0 `ERR`). Checkpoint.

After plan 1b: update `docs/nosql/facts.md` inputs for plan 2 (realtime is now in 4.13/6.4, criterion 9 has UI evidence for every group, Q-41).
