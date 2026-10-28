# Facts – báo cáo NoSQL nhóm 38 (LedgerMind)

Nguồn sự thật của mọi nội dung báo cáo. Khi facts.md khác spec, **facts.md thắng**. Mỗi sự kiện mang nguồn
`(đường dẫn:dòng @SHA)`; điều chưa biết ghi rõ "CHƯA BIẾT", không đoán.

- CODE_SHA: `1cae4de3307bc15d5cadb21918c3d52fd74403ec` (HEAD nhánh `feature/nosql`, viết tắt `1cae4de`). Mã nguồn đổi lần
  cuối ở `0765832`; `1cae4de` chỉ thêm tài liệu. Mọi "@63328b7" trong plan báo cáo nghĩa là SHA này.
- Bao gồm plan 1 (Redis ZSET leaderboard, Mongo OCR analytics, ES search + PG fallback, ô tìm kiếm mobile, scripts Q-01..Q-40)
  và plan 1b (trang `/admin/ocr-feedbacks`, `/admin/nosql`, Mongo backup/restore trên `/admin/backup`, sự kiện realtime
  Redis Pub/Sub `ledgermind:admin-events` → SSE `/admin/events`, Q-41).
- Viết tắt đường dẫn: `J/` = `core-backend/src/main/java/vn/edu/huit/finance/core/`, `R/` = `core-backend/src/main/resources/`,
  `T/` = `core-backend/src/test/java/vn/edu/huit/finance/core/`, `S/` = `scripts/nosql/`. Mọi nguồn là `@1cae4de` trừ khi ghi khác.
- `core-backend/src/main/resources/application.yml` **không nằm trong git** (`.gitignore:27`), nên không được trích làm nguồn;
  cấu hình được trích từ `*.properties` có trong git và `docker-compose.yml`.

---

## §0. Câu trả lời của người dùng (27/10/2026, chép từ spec §11 và plan "Additions")

Nguồn: `docs/superpowers/specs/2026-10-26-nosql-report-and-elasticsearch-design.md:139-158 @1cae4de`,
`docs/superpowers/plans/2026-10-27-nosql-word-report.md:77-80,413-431 @1cae4de`.

| Câu | Nội dung câu hỏi | Trả lời |
|---|---|---|
| [Q1] | Thang điểm chính thức, tiêu chí 10 | Tiêu chí 10 = 4 ý × 0,5 điểm: (a) báo cáo đầy đủ, đúng chính tả, đúng định dạng, không sao chép; (b) thuyết trình tự tin, trả lời được câu hỏi; (c) nộp đúng hạn, đủ file **Word, PowerPoint, source code**; (d) phân chia công việc rõ ràng, có trách nhiệm. |
| [Q2] | Có realtime không | Có: plan 1b đã làm realtime cho web admin bằng Redis Pub/Sub + SSE. Push trên mobile (FCM) để hướng phát triển. |
| [Q3] | Phân công thật, ngày, "Phụ trách CSDL", % | Trung thực, đối chiếu được với git. Trí: nhóm trưởng; phân tích, kiến trúc, **toàn bộ code** (PG, Redis, ES, plan 1b), khoảng 60% (người dùng chỉnh lại). Tiến: việc còn lại, làm thật: MongoDB (truy vấn, minh chứng Compass), Kibana/Elasticvue (mục 2.5), chụp ảnh trên stack demo, chạy lại script và backup/restore, soát Ch.2 và Ch.5, slide, video demo, soát chính tả; khoảng 40%. Không ghi Tiến viết phần code đã có. Chi tiết việc của Tiến: `docs/nosql/HUONG_DAN_TIEN.md` (T1–T10). **Ngày bắt đầu/kết thúc từng việc: CHƯA BIẾT** (git không dùng được: mọi commit cùng một tài khoản, cùng ngày) → ô vàng. |
| [Q4] | Minh chứng CRUD MongoDB và backup NoSQL từ giao diện | Có: plan 1b làm trang `/admin/ocr-feedbacks` (đọc, lọc, đánh dấu đã xử lý, xóa, biểu đồ) và Mongo backup/restore trên `/admin/backup`. Minh chứng = Postman/Swagger + GUI tool thấy dữ liệu đổi + trang backup. |
| [Q5] | Link điền phiếu minh chứng | Nhánh `main` của repo (repo private). Ô Ghi chú nhắc: thêm GV làm collaborator hoặc nộp kèm zip source. Link video: CHƯA CÓ (ô vàng). |
| [Q6] | Tháng/năm trên bìa | "Thành phố Hồ Chí Minh tháng 11 năm 2026". |
| [Q7] | Tên đề tài cuối | Tên đã đăng ký (giống bìa SRS tuần 6): "ỨNG DỤNG CƠ SỞ DỮ LIỆU MONGODB VÀ BỘ NHỚ ĐỆM REDIS TRONG VIỆC XÂY DỰNG HỆ THỐNG QUẢN LÝ TÀI CHÍNH CÁ NHÂN". Elasticsearch trình bày trong nội dung là "CSDL tự tìm hiểu". Nếu GV cho đổi tên thì thêm "… kết hợp Elasticsearch". |
| [Q8] | Chụp Compass, RedisInsight, màn hình app trên stack nào | Stack demo riêng (Task 4 viết `scripts/nosql/demo-stack.sh`, project `nosql-demo`, cổng chỉ 127.0.0.1), không đụng stack `finance-*` đang chạy. |

Quy tắc ghi công (áp dụng cho 1.6 và 8.3): mỗi người chỉ được ghi công những ảnh/việc **thật sự do người đó làm**
(cột "Người chụp" ở §2.6 sửa theo thực tế); ảnh agent chụp tự động không ghi công cho ai; không ghi Tiến viết phần code đã có.

Thông tin nhóm (plan Global Constraints, `docs/superpowers/plans/2026-10-27-nosql-word-report.md:28-36`): nhóm 38;
Phan Thanh Trí (2001230977, nhóm trưởng), Phan Minh Tiến (2001230806); GVHD Ths. Ngô Minh Anh Thư; bìa: Bộ Công Thương /
Trường ĐH Công Thương TP.HCM / Khoa CNTT / "BÁO CÁO MÔN HỌC – DỮ LIỆU NOSQL".

---

## §1. Sự kiện mã nguồn đã kiểm chứng

### 1.0 Phiên bản và hạ tầng chung

| Thành phần | Giá trị | Nguồn |
|---|---|---|
| Spring Boot | 3.2.5 (`spring-boot-starter-parent`) | `core-backend/pom.xml:7-8` |
| Java | 21 | `core-backend/pom.xml:16`; image chạy `eclipse-temurin:21-jre-jammy` (`core-backend/Dockerfile:12`) |
| Starter NoSQL | `spring-boot-starter-data-redis`, `spring-boot-starter-data-mongodb`, `spring-boot-starter-data-elasticsearch` (ES thêm ở plan 1) | `core-backend/pom.xml:76,135,139` |
| Phiên bản thư viện đã phân giải | Spring Data Redis 3.2.5, Spring Data MongoDB 4.2.5, Spring Data Elasticsearch 5.2.5, Lettuce 6.3.2.RELEASE, MongoDB Java driver 4.11.2, elasticsearch-java 8.10.4 | thư mục `~/.m2/repository` của máy dev (bản duy nhất có mặt), không phải một dòng trong repo; theo BOM Spring Boot 3.2.5 |
| PostgreSQL | image `postgres:15-alpine` (PG_VERSION=15.19 trong image cục bộ) | `docker-compose.yml:41`; `docker image inspect` ngày 27/10/2026 |
| Redis | image `redis:8.10-alpine` (`redis-server --version` → v=8.10.2) | `docker-compose.yml:65` |
| MongoDB | image `mongo:6.0` (`mongod --version` → v6.0.28) | `docker-compose.yml:108` |
| Elasticsearch | image `elasticsearch:8.11.4`, profile `search` | `docker-compose.yml:150,152` |
| Kibana | image `kibana:8.11.4`, profile `tools` | `docker-compose.yml:191,193` |
| Mạng | một bridge `finance-network` cho mọi service | `docker-compose.yml:329-331` |
| Volume | `postgres_data`, `mongodb_data`, `elasticsearch_data`, `elasticsearch_snapshots`, `core_backups`, `caddy_data`, `caddy_config`; Redis **không** có volume | `docker-compose.yml:333-342` |
| Giới hạn bộ nhớ container | proxy 128M; Redis `${REDIS_MEMORY_LIMIT:-192M}`; MongoDB 512M; Elasticsearch 1G; Kibana 1G; core-api 512M; data-mining-api 3G | `docker-compose.yml:28,94,134,178,208,292,320` |
| Công cụ backup trong image core-api | `postgresql-client-15` (pg_dump/pg_restore) và `mongodb-database-tools` (repo apt MongoDB 7.0) | `core-backend/Dockerfile:14-28` |
| Executor nền cho mọi ghi NoSQL sau commit | bean `mongoAsyncExecutor`: core 5, max 20, hàng đợi 500, tên luồng `MongoAsync-`; hàng đợi đầy thì **bỏ** tác vụ và log cảnh báo | `J/Config/AsyncConfig.java:20-34` |
| Chế độ chạy trên server thật | **CHƯA BIẾT / CHƯA TRIỂN KHAI**: hosting chưa chốt (tài khoản Azure sinh viên bị tắt, Oracle Always Free đang cân nhắc – ghi chú dự án ngày 25/10/2026). Mặc định `SEARCH_ENGINE=postgres`. | `docker-compose.yml:265`; `R/search.properties:6` |

### 1.1 PostgreSQL (nguồn sự thật, RDBMS)

| Sự kiện | Nguồn |
|---|---|
| Bảng chính: `users`, `transactions`, `receipts`, `receipt_processing_attempts`, `categories`, `budgets`, `notifications`, `revoked_tokens`, `action_logs`, `saving_goals`, `payment_orders`, `app_reviews`, `subscription_plans` | `J/Entity/*.java` (`@Table`), ví dụ `J/Entity/Transaction.java:13`, `J/Entity/Receipt.java:23`, `J/Entity/ReceiptProcessingAttempt.java:35` |
| Chống trùng checkout theo `clientId`: ràng buộc `uk_transactions_user_client_id (user_id, client_id)`, tra `findByUserIdAndClientId` | `J/Entity/Transaction.java:13-15,85`; `J/Service/TransactionService.java:180` |
| Khóa ví bi quan: `lockWallet` = `detach` rồi `entityManager.find(User, id, PESSIMISTIC_WRITE)` | `J/Service/TransactionService.java:663-669` |
| Khóa lạc quan hóa đơn: `Receipt.version` `@Version`; `OptimisticLockingFailureException` → 409; `ReceiptConflictException` → 409 | `J/Entity/Receipt.java:72-78`; `J/Exception/GlobalExceptionHandler.java:154-162` |
| JSON thô của AI nằm trong PG (`receipt_processing_attempts.ai_raw_data` qua `getAiRawData()`), không chuyển sang Mongo | `J/Service/ReceiptProcessingService.java:167-168` |
| Vòng đời hóa đơn `ReceiptStatus`: PENDING, PROCESSING, COMPLETED_RAW, EDITED, FAILED, WAITING_FOR_REVIEW, APPROVED, CANCELED; **PROCESSING dành sẵn, không bước chuyển nào dẫn tới hay đi ra** (`MOVES.put(PROCESSING, noneOf)`) | `J/Entity/ReceiptStatus.java:16-42,60` |
| Bảng chuyển trạng thái `MOVES` | `J/Entity/ReceiptStatus.java:59-66` |
| Danh sách thu hồi JWT nằm trong **PostgreSQL** (`revoked_tokens`, `existsByTokenHash`) | `J/Service/TokenBlacklistService.java:22,76-77`; `J/Entity/RevokedToken.java:21` |
| Phiên mobile/API = **JWT** không trạng thái (`SessionCreationPolicy.STATELESS` cho `/api/**`); web admin = form login + phiên HTTP | `J/Config/SecurityConfig.java:75-86,141-157` |
| Phân quyền: `/admin/**` và `/api/admin/**` cần `ROLE_ADMIN` ở SecurityConfig, controller admin thêm `@PreAuthorize(Roles.HAS_ADMIN)` | `J/Config/SecurityConfig.java:82,156`; `J/Security/Roles.java:21` |
| Sao lưu PG: `BackupService` chạy `pg_dump`/`pg_restore`; nút trên `/admin/backup` gọi `POST /admin/backup/execute?type=…`, `POST /admin/backup/restore?type=FULL` | `J/Service/BackupService.java:26-32,70-90`; `J/Controller/AdminController.java:327-360`; `R/templates/admin/backup.html:136,171` |
| Khôi phục PG phát `StatisticsChangedEvent(DATABASE_RESTORED)` | `J/Service/BackupService.java:149` |
| Truy vấn bảng xếp hạng từ PG: `sumExpensesByUserBetween` (JPQL `SUM(t.amount) … GROUP BY t.user.id, t.user.username ORDER BY totalSpent DESC`, `[rangeStart, rangeEnd)`) và `sumExpensesBetween` cho một user | `J/Repository/TransactionRepository.java:127-139` |
| Tìm kiếm PG: `searchIdsByText` = `LOWER(col) LIKE :pattern ESCAPE '\'` trên `note`, `categoryName`, `location`, `paymentMethod`, `receipt.vendorName`, lọc `t.user.id = :userId`, `ORDER BY t.transactionDate DESC, t.id DESC`; `likePattern` hạ chữ thường và thoát `\ % _` (**không phải ILIKE**, không bỏ dấu) | `J/Repository/TransactionRepository.java:149-181` |
| Nạp lại kết quả tìm kiếm theo id **và chủ sở hữu**: `findAllByIdInAndUserIdWithReceipt` (JOIN FETCH category, receipt) | `J/Repository/TransactionRepository.java:183-189` |
| Đọc một giao dịch để index: `findForSearchIndex` (LEFT JOIN FETCH receipt); trang 500 dòng: `findPageForSearchIndex` | `J/Repository/TransactionRepository.java:29-35` |

### 1.2 Redis (Key-Value) – 3 vai trò + Pub/Sub

**Cấu hình chung**

| Sự kiện | Nguồn |
|---|---|
| Không persistence: `--save ''`, `--appendonly no`; `--maxmemory "$REDIS_MAXMEMORY"` (mặc định 128mb), `--maxmemory-policy allkeys-lru`; `KEYS`, `FLUSHALL`, `FLUSHDB` bị đổi tên thành rỗng; `--requirepass`; không publish cổng nào ra host | `docker-compose.yml:60-83` |
| Kết nối: `spring.data.redis.connect-timeout=${REDIS_CONNECT_TIMEOUT:1s}`, `spring.data.redis.timeout=${REDIS_COMMAND_TIMEOUT:500ms}`; health Redis tắt; không repository | `R/redis-cache.properties:5-13` |
| Lettuce `DisconnectedBehavior.REJECT_COMMANDS`: mất kết nối thì lệnh hỏng ngay, không chờ timeout | `J/Config/CacheConfig.java:117-122` |

**(a) Cache thống kê (Spring Cache, cache-aside)**

| Sự kiện | Nguồn |
|---|---|
| 4 cache: `user-dashboard`, `user-popular-vendors`, `admin-dashboard-summary`, `admin-statistics`; `SCHEMA_VERSION = "v1"` | `J/Service/Cache/CacheNames.java:13-18` |
| Khóa: `<prefix>:v1:<cache>:<key>`; prefix mặc định `ledgermind:<profile đang chạy>` (không profile → `ledgermind:default`), chỉ cho ký tự `[A-Za-z0-9._:-]` | `J/Config/CacheConfig.java:65-70,128-138`; `R/redis-cache.properties:15-16` |
| Giá trị: JSON thuần (Jackson, không type info), khóa String; không lưu null; `disableCreateOnMissingCache` | `J/Config/CacheConfig.java:82-98,148-156` |
| TTL tối đa: user-dashboard 45s, user-popular-vendors 60s, admin-dashboard-summary 45s, admin-statistics 60s; jitter 10% (`JitteredTtl`: TTL trừ ngẫu nhiên tối đa 10%) | `R/redis-cache.properties:18-22`; `J/Config/CacheConfig.java:162-169` |
| Xóa cache theo lô bằng SCAN (`BatchStrategies.scan(500)`), không KEYS | `J/Config/CacheConfig.java:64,93-94` |
| `@Cacheable` key `#userId`: `UserStatisticsService.popularVendorsOf`, `dashboardOf` | `J/Service/UserStatisticsService.java:36,47` |
| `@Cacheable` admin: `getDashboardSummary` key `<yyyy-MM>:<ngưỡng>`; `getMonthlyTransactionCounts` key `monthly-transactions:<yyyy-MM>:<n>` | `J/Service/AdminStatisticsService.java:43-46,81-84` |
| Lỗi cache không làm hỏng request: `FallbackCacheErrorHandler` (đọc lỗi = miss → đọc PG; ghi lỗi = không cache; xóa lỗi = để TTL hết hạn). **Đây là fallback, không phải Circuit Breaker.** | `J/Config/FallbackCacheErrorHandler.java:9-17,19-41` |
| Xóa cache **sau commit**: `StatisticsCacheEvictor.onStatisticsChanged` `@TransactionalEventListener(AFTER_COMMIT, fallbackExecution = true)`; rollback không xóa gì | `J/Service/Cache/StatisticsCacheEvictor.java:12-36` |
| Thay đổi nào xóa cache nào: enum `StatisticsChange` (TRANSACTION_TOTALS, TRANSACTION_DETAILS, RECEIPT_STATUS, RECEIPT_CONTENT, ACCOUNT_CREATED, ACCOUNT_PROFILE, ACCOUNT_DELETED, DATABASE_RESTORED) | `J/Service/Cache/StatisticsChange.java:12-32` |
| Cache `admin-top-spenders` đã bị bỏ (Sorted Set thay thế) | `J/Service/Cache/CacheNames.java:15-18` (không còn tên này); spec §10 |

**(b) OTP quên mật khẩu**

| Sự kiện | Nguồn |
|---|---|
| Khóa `ledgermind:password-reset-otp:<email>`, kiểu Hash (`code`, `expiresAt` epoch ms, `failedAttempts`) | `J/Service/RedisPasswordResetOtpStore.java:15-27` |
| Lưu = Lua `SAVE_SCRIPT` (DEL + HSET + PEXPIRE); kiểm tra = Lua `CHECK_SCRIPT` (HGET, so hạn, so mã, HINCRBY failedAttempts, DEL khi đúng/hết hạn/sai đủ lần); trả -1 không có, 0 đúng, >0 số lần sai | `J/Service/RedisPasswordResetOtpStore.java:33-60` |
| Hạn 5 phút (`OTP_VALIDITY`), tối đa 3 lần sai (`OTP_MAX_FAILED_ATTEMPTS`) | `J/Service/AuthService.java:104-105,207,246` |
| Redis sập → `OtpStoreUnavailableException` với câu cố định "Dịch vụ mã OTP tạm thời gián đoạn…" (cố ý fail, không fallback) | `J/Service/RedisPasswordResetOtpStore.java:20-28,84-92` |
| Đây là phần Redis **duy nhất** của quản trị người dùng (phiên là JWT, danh sách thu hồi ở PG) | §1.1 dòng JWT, revoked_tokens |

**(c) Bảng xếp hạng chi tiêu tháng (Sorted Set)**

| Sự kiện | Nguồn |
|---|---|
| Khóa `ledgermind:leaderboard:spend:<yyyy-MM>` (`KEY_PREFIX` + `YearMonth.toString()`), member = userId, score = tổng chi tháng | `J/Service/Cache/SpendingLeaderboardService.java:35-46,79-82` |
| Score là **tổng tuyệt đối đọc lại từ PG** rồi ghi bằng Lua `REFRESH_MEMBER_SCRIPT` (`EXISTS` → `ZADD` hoặc `ZREM` khi tổng ≤ 0); **không dùng ZINCRBY** | `J/Service/Cache/SpendingLeaderboardService.java:36-40,53-64,155-170` |
| Script chỉ ghi khi set đã tồn tại (không tạo set 1 member không TTL) | `J/Service/Cache/SpendingLeaderboardService.java:155-167` |
| Đọc: `hasKey` → thiếu thì dựng lại từ `sumExpensesByUserBetween` (ZADD mọi member rồi `EXPIRE` sau cùng) → `ZREVRANGE … WITHSCORES` (`reverseRangeWithScores(key, 0, limit-1)`), tên user lấy bằng **một** `findAllById` | `J/Service/Cache/SpendingLeaderboardService.java:88-102,176-208` |
| Redis lỗi khi đọc → trả lời từ PG (`RedisAccessException` phân biệt với lỗi PG) | `J/Service/Cache/SpendingLeaderboardService.java:98-101,221-234` |
| TTL `app.leaderboard.ttl=${LEADERBOARD_TTL:62d}` | `R/redis-cache.properties:24-25`; `J/Service/Cache/SpendingLeaderboardService.java:72` |
| Cập nhật sau commit: `onTransactionChanged` `@Async("mongoAsyncExecutor")` + `@TransactionalEventListener(AFTER_COMMIT)`, cho mỗi tháng trong `expenseMonths` | `J/Service/Cache/SpendingLeaderboardService.java:141-153` |
| Sau khôi phục DB hoặc xóa tài khoản: `dropAllMonths` (SCAN MATCH `ledgermind:leaderboard:spend:*` COUNT 100 + DEL) | `J/Service/Cache/SpendingLeaderboardService.java:114-139` |
| `rebuildMonth`: xóa set tháng, dựng lại từ PG | `J/Service/Cache/SpendingLeaderboardService.java:104-112` |
| Trang `/admin/dashboard` hiện top 5 của tháng (tham số `month`), đọc qua `topSpenders` | `J/Controller/AdminController.java:69,112-125` |

**(d) Pub/Sub sự kiện realtime admin (plan 1b)**

| Sự kiện | Nguồn |
|---|---|
| Kênh `ledgermind:admin-events`; `AdminEventPublisher.publish` = `convertAndSend` JSON; lỗi chỉ log | `J/Service/Realtime/AdminEventPublisher.java:12-38` |
| Bản ghi `AdminEvent(type, id, message, at)` không chứa dữ liệu cá nhân; 4 loại `RECEIPT_WAITING_REVIEW`, `OCR_FEEDBACK_REPORTED`, `SEARCH_REINDEXED`, `LEADERBOARD_REBUILT` | `J/Service/Realtime/AdminEvent.java:6-37`; `J/Service/Realtime/AdminEventType.java:4-13` |
| Phát: `ReceiptWaitingReviewEvent` sau commit (async); `OcrMongoService` khi có chỗ sửa mới; controller reindex/rebuild | `J/Service/Realtime/AdminEventPublisher.java:40-45`; `J/Service/OcrMongoService.java:165-167`; `J/Controller/AdminSearchController.java:51`; `J/Controller/AdminLeaderboardController.java:65`; `J/Controller/AdminNoSqlPageController.java:322,346` |
| Nhận: `RedisMessageListenerContainer` cho kênh trên, không tự khởi động; `AdminEventSubscription` thử đăng ký lại mỗi 10 s khi Redis chưa sẵn | `J/Config/RealtimeConfig.java:15-52`; `J/Service/Realtime/AdminEventSubscription.java:12-70` |
| `AdminEventRelay` chuyển mỗi tin tới mọi `SseEmitter` của instance; timeout luồng 30 phút, retry 5 s, heartbeat 25 s; luồng kết thúc cùng phiên đăng nhập | `J/Service/Realtime/AdminEventRelay.java:24-123` |
| SSE `GET /admin/events` (`text/event-stream`), ROLE_ADMIN; phiên nhàn rỗi quá hạn → 204 | `J/Controller/AdminEventsController.java:19-48` |
| Trình duyệt: `EventSource('/admin/events')` → toast Bootstrap + badge sidebar; nạp ở mọi trang admin | `R/static/admin/js/admin-events.js:2-13`; `R/templates/admin/layout/_layout.html:47,70` |
| Pub/Sub không lưu tin: không ai nghe thì tin mất (chấp nhận, chỉ là thông báo) | `S/redis_demo.txt:136` |

### 1.3 MongoDB (Document) – bản sao phân tích chất lượng AI

| Sự kiện | Nguồn |
|---|---|
| Database `finance_nosql`; kết nối `MONGO_URI=…@mongodb:27017/finance_nosql?authSource=admin&serverSelectionTimeoutMS=5000&connectTimeoutMS=5000`; health Mongo tắt; core-api khởi động không cần Mongo (`required: false`) | `docker-compose.yml:116,232-236,285-288` |
| Mongo chạy `--wiredTigerCacheSizeGB 0.25`, cổng `127.0.0.1:27017`, có user root | `docker-compose.yml:110-116` |
| Vai trò: "analysis copy" của câu trả lời AI và phản hồi OCR; **PG vẫn là nguồn sự thật** của hóa đơn | `docker-compose.yml:103-106`; `S/mongodb_init.js:4-7` |
| Collection `ocr_logs` (`OcrRawLog`): `transactionId` (unique), `rawJsonData` (org.bson.Document), `modelVersion`, `aiReading {sellerName, totalCost, receiptDate}` (document lồng), `averageConfidenceScore`, `createdAt` (`@CreatedDate`) | `J/Document/OcrRawLog.java:12-43` |
| Collection `ocr_feedbacks` (`OcrFeedback`): `receiptId`, `transactionId`, `userId`, `fieldError`, `expectedValue`, `aiValue`, `modelVersion`, `isResolved`, `reportedAt` (`@CreatedDate`), `updatedAt` | `J/Document/OcrFeedback.java:12-46` |
| Giá trị `fieldError` ∈ `seller_name`, `total_cost`, `receipt_date` (`OcrField.key()`) | `J/Document/OcrField.java:4-17` |
| Spring **không tự tạo index** (auto-index-creation tắt); `S/mongodb_init.js` tạo collection, `$jsonSchema` (validationLevel `moderate`, validationAction `error`) và mọi index; idempotent; được gắn vào `/docker-entrypoint-initdb.d/` (chỉ chạy khi volume rỗng) | `S/mongodb_init.js:9-17,40-110`; `docker-compose.yml:125-129` |
| Index `ocr_logs`: `transactionId` (unique), `averageConfidenceScore`, `createdAt`, `score_date_idx {averageConfidenceScore:1, createdAt:-1}` | `S/mongodb_init.js:117-123`; `J/Document/OcrRawLog.java:14,20,31,35` |
| Index `ocr_feedbacks`: `receipt_field_uq {receiptId:1, fieldError:1}` UNIQUE, `receiptId` (dư vì là tiền tố của receipt_field_uq – script tự ghi chú), `userId`, `transactionId` (cho `$lookup`), `isResolved`, `reportedAt`, `status_date_idx {isResolved:1, reportedAt:-1}` | `S/mongodb_init.js:125-139`; `J/Document/OcrFeedback.java:14-15` |
| **Không có TTL index** nào | `S/mongodb_init.js:115-139` (không có `expireAfterSeconds`) |
| Ghi `ocr_logs`: `onOcrProcessedEvent` `@Async("mongoAsyncExecutor")` + `AFTER_COMMIT`; JSON hỏng thì bọc `{unparsed_raw_string}`; lỗi chỉ log | `J/Service/OcrMongoService.java:91-130` |
| `ocr_logs` chỉ ghi cho **lần đọc đầu tiên** (event phát trong `recordAttachedReceipt` lúc checkout); một log mỗi giao dịch (unique `transactionId`) | `J/Service/ReceiptProcessingService.java:157-174` |
| Độ tin cậy: đọc `confidence_score` / `score` / `confidence` nếu có; **Donut V5 không trả → null** (không bịa) | `J/Service/OcrMongoService.java:336-350` |
| `modelVersion` = `app.ocr.model-version=${OCR_MODEL_VERSION:donut-v5}` | `R/ocr-analytics.properties:5`; `J/Service/OcrMongoService.java:88-89` |
| Sinh `ocr_feedbacks` tự động khi người dùng sửa giá trị AI đã đọc: (1) checkout có số tiền khác tổng AI; (2) `editMyReceipt` (PUT `/api/receipts/{id}`); (3) `submitFeedback` (POST `/api/receipts/feedback/{receiptId}`); so với lần đọc AI mới nhất | `J/Service/ReceiptProcessingService.java:163-207,235-285,358-376`; `J/Controller/ReceiptController.java:45,61` |
| So sánh: `OcrCorrectionDetector.diff` (tiền so `compareTo`, tên quán cắt khoảng trắng, phân biệt hoa thường) | `J/Service/OcrCorrectionDetector.java:15-52` |
| Upsert hai bước: (1) `updateFirst` khi (receiptId, fieldError) có giá trị **khác** → ghi đè, `isResolved=false`; (2) không có → `upsert` chỉ với `$setOnInsert`; trùng do 2 luồng → unique `receipt_field_uq` chặn, lỗi chỉ log; trường trả về đúng giá trị AI → `remove` chỗ sửa cũ | `J/Service/OcrMongoService.java:145-216` |
| Đọc/lọc feedback: `Criteria` field/resolved/khoảng `reportedAt` [from, to+1 ngày), `count` + `find(query.with(pageable))` | `J/Service/OcrMongoService.java:224-255` |
| Đánh dấu đã xử lý: `findById` + `save`; xóa: `existsById` + `deleteById`; không có → `OcrFeedbackNotFoundException` (404) | `J/Service/OcrMongoService.java:257-275` |
| Thống kê `analytics(from,to)`: errorsByField (`$match`/`$group fieldError`/`$sort`), errorsByModel (`$group modelVersion`, null → "unknown"), confidenceByMonth (`$dateToString %Y-%m` theo múi giờ hệ thống, `$avg`), receiptsWithErrorRate (`$match createdAt` → `$lookup ocr_feedbacks` theo transactionId → `$group`) | `J/Service/OcrMongoService.java:277-334` |
| Phương thức repository khai báo nhưng **không được gọi** ở mã chính: `findByTransactionIdOrderByCreatedAtDesc`, `findByAverageConfidenceScoreLessThan`, `findByIsResolvedFalse`, `countErrorsByField` (@Aggregation) | `J/Repository/Mongo/OcrRawLogRepository.java:9-10`; `J/Repository/Mongo/OcrFeedbackRepository.java:11-14`; `git grep` tại 1cae4de |
| Seeder demo Mongo (cờ `app.seed.demo`, mặc định tắt `SEED_DEMO=false`): log + feedback cho hóa đơn vừa seed ở PG | `J/Config/MongoDataSeeder.java:21-70`; `docker-compose.yml:256` |
| Sao lưu Mongo từ web (plan 1b): `MongoBackupService.backup` = `mongodump --config=<tạm> --db=finance_nosql --archive=… --gzip` (cả database), ghi file `.partial` rồi đổi tên; `restoreLatest` = `mongorestore --archive --gzip --drop --nsInclude=finance_nosql.ocr_logs --nsInclude=finance_nosql.ocr_feedbacks`; mật khẩu không vào tham số/log; một lần chạy một lúc (`BusyException`); timeout 10 phút; ghi audit `MONGO_BACKUP_CREATED`/`MONGO_RESTORED` | `J/Service/MongoBackupService.java:31-66,117-175,200-207` |
| Trang: nút MongoDB trên `/admin/backup` gọi `POST /admin/backup/mongo/execute`, `POST /admin/backup/mongo/restore`, trả `{success, message}` | `J/Controller/AdminMongoBackupController.java:14-54`; `R/templates/admin/backup.html:223,240` |

### 1.4 Elasticsearch (Search/Document – CSDL tự tìm hiểu)

| Sự kiện | Nguồn |
|---|---|
| Single node `discovery.type=single-node`, security bật (user `elastic`, `ELASTIC_PASSWORD`), HTTP TLS tắt, heap `-Xms512m -Xmx512m`, `path.repo=/usr/share/elasticsearch/snapshots`, `action.auto_create_index=false`, cổng `127.0.0.1:9200`, profile `search` (mặc định không chạy) | `docker-compose.yml:143-185` |
| Kibana chỉ với profile `tools`, `127.0.0.1:5601`, đăng nhập bằng `kibana_system` (`KIBANA_PASSWORD`) | `docker-compose.yml:187-215`; `.env.example:39-40` |
| Bật/tắt: `app.search.engine=${SEARCH_ENGINE:postgres}`; `SearchEngineType` ELASTICSEARCH / POSTGRES (mặc định) | `R/search.properties:5-6`; `J/Config/SearchEngineType.java:6-28`; `J/Config/SearchConfig.java:20-27` |
| Client: `spring.elasticsearch.uris=${ELASTICSEARCH_URIS:http://localhost:9200}`, user `elastic`, connection-timeout 1s, socket-timeout 2s; không repository; health ES tắt | `R/search.properties:10-18` |
| Index `transactions`, `createIndex = false`, settings/mapping từ file; 1 shard, 0 replica | `J/Document/Search/TransactionSearchDocument.java:28-33`; `R/elasticsearch/transactions-settings.json:2-3` |
| Analyzer `vi_folded` = tokenizer `standard` + `lowercase` + `asciifolding`; `vi_autocomplete` = thêm filter `vi_edge` (`edge_ngram` 2..15) | `R/elasticsearch/transactions-settings.json:4-9` |
| Mapping: `userId` long; `note`, `vendorName` text `vi_folded` + sub-field `.autocomplete` (index `vi_autocomplete`, search `vi_folded`); `location`, `paymentMethod` text `vi_folded`; `categoryName` text phân tích bằng `vi_folded` + sub-field `.keyword` (kiểu keyword; Q-33 dựa vào `vi_folded`, Q-39 dựa vào `.keyword`); `amount` `scaled_float` ×100; `expense` boolean; `transactionDate` date; `receiptStatus` keyword | `R/elasticsearch/transactions-mapping.json:1-32` |
| Document = một giao dịch (id = `transactions.id`) + `vendorName` của hóa đơn; không index các dòng món hàng | `J/Document/Search/TransactionSearchDocument.java:19-88` |
| Truy vấn thật: `bool { filter term userId; should [multi_match EXACT_FIELDS operator AND boost 2; multi_match FUZZY_FIELDS fuzziness AUTO:4,7 prefix_length 1 operator AND]; minimum_should_match 1 }`, sort `_score` desc rồi `transactionDate` desc, phân trang, `track_total_hits`. Hai giá trị mờ là hằng `FUZZINESS` (`"AUTO:4,7"`, commit 7f07caa) và `FUZZY_PREFIX_LENGTH` (`1`, truyền bằng `.prefixLength(...)`, commit b35cd6e), sau CODE_SHA nên dòng ghi theo HEAD | `J/Service/Search/ElasticsearchTransactionSearchEngine.java:17-81`; `:38-41,62-67 @b35cd6e` |
| EXACT_FIELDS = `vendorName^3, vendorName.autocomplete^2, note^2, note.autocomplete, categoryName, location, paymentMethod`; FUZZY_FIELDS = `vendorName^3, note^2, categoryName, location, paymentMethod` | `J/Service/Search/ElasticsearchTransactionSearchEngine.java:27-41` |
| Văn bản người dùng là giá trị của `multi_match`, **không** `query_string` → không có cú pháp truy vấn bị tiêm | `J/Service/Search/ElasticsearchTransactionSearchEngine.java:18-21` |
| `TransactionSearchService`: ES lỗi (mọi RuntimeException) → log 1 dòng, trả lời bằng PG; kết quả luôn nạp lại từ PG theo id + owner; phản hồi có trường `engine` (`elasticsearch`/`postgres`) | `J/Service/Search/TransactionSearchService.java:22-91` |
| API `GET /api/transactions/search?q=&page=&size=`: `q` 2..100 ký tự (sau strip), `page` 0..199, `size` 1..50 (mặc định 20) – giới hạn cửa sổ 10 000 | `J/Controller/TransactionController.java:92-95`; `J/Dto/TransactionSearchRequestDto.java:10-44` |
| Đồng bộ: `TransactionSearchIndexer.onTransactionChanged` `@Async` + `AFTER_COMMIT`: đọc lại hàng từ PG rồi `save` cả document (hoặc `delete`), không vá từ event; lỗi chỉ log, document giữ cũ tới lần đổi sau hoặc reindex | `J/Service/Search/TransactionSearchIndexer.java:117-134,206-216` |
| Tạo index chỉ từ file: lúc `ApplicationReadyEvent`, `@Scheduled` mỗi 15 s **cho tới khi tạo/thấy được một lần** (`INDEX_CHECK_DELAY_MS`), và khi một lần ghi gặp `index_not_found` (tạo rồi ghi lại 1 lần); index vừa tạo được nạp nền từ PG. **@Scheduled này thử lại việc tạo index, không thử lại các lần cập nhật hỏng.** | `J/Service/Search/TransactionSearchIndexer.java:36-52,84-110,218-267` |
| Reindex toàn bộ `reindexAll`: khóa `ReentrantLock` (lần thứ hai → `ReindexInProgressException` 409), xóa index, tạo từ file, bulk 500 dòng/lần theo id, `refresh` | `J/Service/Search/TransactionSearchIndexer.java:169-199,269-289` |
| Khôi phục DB PG → dựng lại index nền (chờ tối đa 10 phút nếu đang reindex) | `J/Service/Search/TransactionSearchIndexer.java:136-167` |
| Sự kiện `TransactionChangedEvent(transactionId, userId, kind UPSERTED/DELETED, expenseMonths)` phát trong transaction của mọi ghi giao dịch và mọi đổi hóa đơn mà document hiện ra; xử lý AFTER_COMMIT bởi leaderboard và search index | `J/Dto/TransactionChangedEvent.java:7-36`; `J/Service/TransactionService.java:228-229,299-306,325-326,357-359,410-414`; `J/Service/ReceiptProcessingService.java:277-281,345-347,371-375,413-416` |
| Admin: `POST /api/admin/search/reindex` (200 số document; 503 khi tắt hoặc ES lỗi; 409 khi đang chạy); trang `/admin/nosql` có nút `POST /admin/nosql/search/reindex` và số document (`count`) | `J/Controller/AdminSearchController.java:28-58`; `J/Controller/AdminNoSqlPageController.java:282-326` |
| Mobile: ô tìm kiếm Sổ cái debounce 350 ms, gọi `RemoteApiHelper.searchTransactionIds` (`size` 50), hiện dòng khớp server **hoặc** khớp cục bộ (dòng outbox chưa đồng bộ vẫn lọc cục bộ); lỗi mạng → lọc cục bộ | `mobile-app/lib/screens/ledger/ledger_page.dart:47,87,264-322`; `mobile-app/lib/services/remote_api_helper.dart:420-433`; `mobile-app/lib/repositories/app_repository.dart:126-128` |

### 1.5 Danh sách endpoint liên quan NoSQL

| Phương thức | Đường dẫn | Tham số | Vai trò | CSDL | Nguồn |
|---|---|---|---|---|---|
| POST | `/api/auth/forgot-password` | `email` | công khai | Redis (OTP) + PG | `J/Controller/AuthController.java:215-216`; `J/Security/AuthPaths.java:8` |
| POST | `/api/auth/reset-password` | body `ResetPasswordRequestDto` | công khai | Redis (OTP) + PG | `J/Controller/AuthController.java:227-228` |
| POST | `/api/transactions/checkout` | body `TransactionRequestDto` | USER | PG → (sau commit) Redis cache/leaderboard, Mongo, ES | `J/Controller/TransactionController.java:54-56` |
| PUT / DELETE | `/api/transactions/{id}` | body / – | USER (chủ) | PG → sau commit Redis, ES | `J/Controller/TransactionController.java:60-67` |
| GET | `/api/transactions/search` | `q`, `page`, `size` | USER | ES (hoặc PG) + PG | `J/Controller/TransactionController.java:92-95` |
| GET | `/api/transactions/popular-vendors` | – | USER | Redis cache / PG | `J/Controller/TransactionController.java:104-105` |
| GET | `/api/transactions/app-dashboard` | – | USER | Redis cache / PG | `J/Controller/TransactionController.java:109-110` |
| PUT | `/api/receipts/{id}` | body `ReceiptUpdateRequestDto` | USER (chủ) | PG → Mongo feedback, ES | `J/Controller/ReceiptController.java:45` |
| POST | `/api/receipts/{id}/retry` | body | USER (chủ) | PG → ES | `J/Controller/ReceiptController.java:55` |
| POST | `/api/receipts/feedback/{receiptId}` | số tiền | USER (chủ) | PG → Mongo feedback, Redis Pub/Sub | `J/Controller/ReceiptController.java:61` |
| GET | `/api/admin/transactions/popular-vendors`, `/api/admin/transactions/app-dashboard` | `userId` | ADMIN | Redis cache / PG | `J/Controller/AdminTransactionController.java:25,35,40` |
| GET | `/api/admin/ocr-logs` | `Pageable` | ADMIN | Mongo | `J/Controller/OcrMongoController.java:19-29` |
| GET | `/api/admin/ocr-feedbacks` | `field`, `resolved`, `from`, `to`, `page` (≥0), `size` 1..100 (mặc định 20), `sort` `reportedAt|updatedAt[,asc|desc]` (mặc định `reportedAt,desc`) | ADMIN | Mongo | `J/Controller/AdminOcrFeedbackController.java:36-75` |
| PATCH | `/api/admin/ocr-feedbacks/{id}/resolve` | – | ADMIN | Mongo | `J/Controller/AdminOcrFeedbackController.java:77-80` |
| DELETE | `/api/admin/ocr-feedbacks/{id}` | – | ADMIN | Mongo | `J/Controller/AdminOcrFeedbackController.java:82-86` |
| GET | `/api/admin/ocr-feedbacks/analytics` | `from`, `to` | ADMIN | Mongo | `J/Controller/AdminOcrFeedbackController.java:88-91` |
| GET | `/api/admin/leaderboard` | `month` (yyyy-MM, mặc định tháng này), `limit` 1..50 (mặc định 10) | ADMIN | Redis ZSET (PG khi thiếu/lỗi) | `J/Controller/AdminLeaderboardController.java:30-57` |
| POST | `/api/admin/leaderboard/rebuild` | `month` | ADMIN | Redis + PG; Pub/Sub | `J/Controller/AdminLeaderboardController.java:59-66` |
| POST | `/api/admin/search/reindex` | – | ADMIN | ES + PG; Pub/Sub | `J/Controller/AdminSearchController.java:26,43-58` |
| GET | `/api/admin/receipts/{id}/attempts` | – | ADMIN | PG (JSON thô AI) | `J/Controller/AdminReceiptController.java:24,33` |
| GET | `/admin/dashboard` | `month` | ADMIN (web) | Redis cache + ZSET | `J/Controller/AdminController.java:112-125` |
| GET | `/admin/ocr-feedbacks` | `field`, `resolved`, `from`, `to`, `page` (20/trang) | ADMIN (web) | Mongo (danh sách + 3 biểu đồ) | `J/Controller/AdminNoSqlPageController.java:109-115`; `R/templates/admin/ocr_feedbacks.html:33-45` |
| POST | `/admin/ocr-feedbacks/{id}/resolve`, `/admin/ocr-feedbacks/{id}/delete` | – | ADMIN (web) | Mongo | `J/Controller/AdminNoSqlPageController.java:190-197` |
| GET | `/admin/nosql` | `month` | ADMIN (web) | ES (đếm) + Redis (top 10) | `J/Controller/AdminNoSqlPageController.java:282-311` |
| POST | `/admin/nosql/search/reindex`, `/admin/nosql/leaderboard/rebuild` | `month` | ADMIN (web) | ES / Redis + PG; Pub/Sub | `J/Controller/AdminNoSqlPageController.java:313-352` |
| POST | `/admin/backup/execute`, `/admin/backup/restore` | `type` | ADMIN (web) | PG | `J/Controller/AdminController.java:333,354` |
| POST | `/admin/backup/mongo/execute`, `/admin/backup/mongo/restore` | – | ADMIN (web) | Mongo | `J/Controller/AdminMongoBackupController.java:18-47` |
| GET | `/admin/events` | – (SSE) | ADMIN (web) | Redis Pub/Sub | `J/Controller/AdminEventsController.java:39-48` |

### 1.6 Script và dữ liệu mẫu nộp kèm (`scripts/nosql/`)

| File | Nội dung | Nguồn |
|---|---|---|
| `mongodb_init.js` | 2 collection + `$jsonSchema` + 11 index (chưa kể `_id`), không ghi dữ liệu | `S/mongodb_init.js:1-146` |
| `mongodb_demo.js` | database riêng `finance_nosql_demo`: **36 ocr_logs + 36 ocr_feedbacks** (3 tháng 2026-08..10, donut-v4/donut-v5, sinh bằng công thức cố định), truy vấn Q-01..Q-16 | `S/mongodb_demo.js:20-107,109-294` |
| `redis_demo.txt` | Q-17..Q-29 + Q-41, chạy bằng `redis-cli < redis_demo.txt` trong container dùng một lần | `S/redis_demo.txt:1-149` |
| `elasticsearch/kibana-devtools.txt` | Q-30..Q-40 cho Kibana Dev Tools | `S/elasticsearch/kibana-devtools.txt:1-193` |
| `elasticsearch/transactions-bulk.ndjson` | **47 giao dịch** tiếng Việt, 3 người dùng, tháng 8–10/2026 (94 dòng NDJSON) | `S/elasticsearch/README.md:9`; `S/elasticsearch/kibana-devtools.txt:12` |
| `elasticsearch/README.md` | tạo index từ 2 file thật của app, nạp bulk, chạy truy vấn | `S/elasticsearch/README.md:1-65` |
| `backup_restore.md` | MongoDB (mongodump/mongorestore, mongoexport/mongoimport, trang admin), Redis (RDB SAVE, `--rdb`), Elasticsearch (snapshot/restore, `_search`/`_bulk`, reindex từ PG) | `S/backup_restore.md:1-188` |
| `NoSQL_Postman_Collection.json` | bộ Postman gọi các endpoint NoSQL (kể cả admin) | `S/NoSQL_Postman_Collection.json` |
| Hướng dẫn cho Tiến | việc T1–T10 của Tiến, lệnh dựng CSDL demo | `docs/nosql/HUONG_DAN_TIEN.md:1-96` |

Ghi chú nguồn số đếm: mọi con số dữ liệu trong báo cáo ghi rõ "dữ liệu demo" (các file trên) hoặc "dữ liệu tổng hợp 100k
(sinh bằng gen_data.py)" (Task 3, chưa có).

---

## §2. Danh sách ID đóng băng

Đóng băng ngày 27/10/2026, **trước mọi phép đo**. Độ trễ mục tiêu là **mục tiêu**, đo ở tầng dữ liệu (client nằm cùng mạng
docker với CSDL, 1 luồng, p95) theo phương pháp Task 3 trừ khi cột ghi khác; số chưa đo thì báo cáo ghi "mục tiêu".
"Strong" = đọc thấy ngay giá trị đã commit; "Eventual" = cập nhật sau commit, bất đồng bộ; "At-most-once" = có thể mất.

### 2.1 FR – Yêu cầu chức năng

| ID | Tên | Tác nhân | Mô tả | Ưu tiên | Truy vết AP |
|---|---|---|---|---|---|
| FR-01 | Đăng nhập và phân quyền | Người dùng, Quản trị viên | Mobile/API dùng JWT; web admin dùng form login + phiên; `/admin/**`, `/api/admin/**` chỉ ROLE_ADMIN | Cao | AP-01 |
| FR-02 | Quên mật khẩu bằng OTP | Người dùng | Gửi OTP 6 số qua email, hạn 5 phút, sai tối đa 3 lần, dùng một lần | Cao | AP-05, AP-06 |
| FR-03 | Ghi giao dịch thu/chi | Người dùng | Checkout chống trùng theo clientId, khóa ví; sau commit cập nhật cache, bảng xếp hạng, chỉ mục tìm kiếm | Cao | AP-02, AP-10, AP-13, AP-32 |
| FR-04 | Sửa, xóa giao dịch | Người dùng | Sửa/xóa giao dịch của mình; sau commit đồng bộ như FR-03 | Cao | AP-03, AP-10, AP-13, AP-32 |
| FR-05 | Quét hóa đơn bằng AI | Người dùng | Lưu hóa đơn + lần đọc thô của AI ở PG; sau commit ghi bản sao phân tích `ocr_logs` | Cao | AP-04, AP-17 |
| FR-06 | Sửa kết quả AI của hóa đơn | Người dùng | Sửa tên quán/tổng tiền/ngày, hoặc gửi số tiền khi AI không đọc được; sinh `ocr_feedbacks` (một document mỗi hóa đơn + trường) và báo realtime cho admin | Cao | AP-04, AP-18, AP-15 |
| FR-07 | Xem trang chủ thống kê | Người dùng | Dashboard và cửa hàng hay mua, đọc qua cache Redis | Cao | AP-07, AP-09 |
| FR-08 | Tìm kiếm giao dịch | Người dùng | Tìm theo từ khóa tiếng Việt, gõ không dấu, sai chính tả, tiền tố; chỉ giao dịch của mình; ES sập vẫn tìm được (PG) | Cao | AP-29, AP-30, AP-31 |
| FR-09 | Dashboard quản trị | Quản trị viên | Tổng quan + thống kê giao dịch theo tháng (cache) + top 5 chi tiêu tháng | Trung bình | AP-08, AP-09, AP-11 |
| FR-10 | Bảng xếp hạng chi tiêu tháng | Quản trị viên | Xem top N theo tháng, dựng lại từ PG khi cần | Trung bình | AP-11, AP-12, AP-13, AP-14 |
| FR-11 | Duyệt phản hồi OCR | Quản trị viên | Danh sách lọc theo trường/trạng thái/khoảng ngày, sắp xếp, phân trang; đánh dấu đã xử lý; xóa | Cao | AP-19, AP-20, AP-21 |
| FR-12 | Thống kê chất lượng OCR | Quản trị viên | Lỗi theo trường, theo mô hình, độ tin cậy theo tháng, tỉ lệ lần đọc bị sửa; biểu đồ | Trung bình | AP-22, AP-23, AP-24, AP-25 |
| FR-13 | API xem log OCR thô | Quản trị viên | API REST `GET /api/admin/ocr-logs` trả một trang log câu trả lời thô của AI (phân trang; không có trang web, không tra theo giao dịch) | Thấp | AP-26 |
| FR-14 | Vận hành chỉ mục tìm kiếm | Quản trị viên | Dựng lại chỉ mục ES từ PG; xem số document | Trung bình | AP-33, AP-34, AP-35 |
| FR-15 | Sao lưu, khôi phục | Quản trị viên | PG (pg_dump) và MongoDB (mongodump/mongorestore) từ trang `/admin/backup` | Cao | AP-27, AP-28 |
| FR-16 | Thông báo realtime cho quản trị | Quản trị viên | Toast + badge khi có hóa đơn chờ duyệt, chỗ sửa OCR mới, reindex, dựng lại bảng xếp hạng | Trung bình | AP-15, AP-16 |

### 2.2 AP – Mẫu truy cập dữ liệu

| ID | Mẫu truy cập | CSDL | Loại | Tham số | Tần suất | Độ trễ mục tiêu (p95) | Nhất quán | Cấu trúc / lệnh | Nguồn |
|---|---|---|---|---|---|---|---|---|---|
| AP-01 | Xác thực: đọc người dùng, kiểm tra JWT bị thu hồi | PostgreSQL | Đọc | username/email; hash token | Rất cao | < 20 ms | Strong | `users`, `revoked_tokens.existsByTokenHash` | §1.1 |
| AP-02 | Checkout: khóa ví, chống trùng clientId, ghi giao dịch | PostgreSQL | Ghi | userId, clientId, giao dịch | Cao | < 50 ms | Strong | `PESSIMISTIC_WRITE` users; `uk_transactions_user_client_id` | §1.1 |
| AP-03 | Sửa/xóa giao dịch | PostgreSQL | Ghi | transactionId | Trung bình | < 50 ms | Strong | `transactions`, khóa ví | §1.1 |
| AP-04 | Ghi hóa đơn + lần đọc AI; sửa hóa đơn có khóa lạc quan | PostgreSQL | Ghi | receiptId, version | Cao | < 50 ms | Strong | `receipts.version`, `receipt_processing_attempts` | §1.1 |
| AP-05 | Lưu OTP | Redis | Ghi | email, code | Thấp | < 5 ms | Strong (một node, Lua nguyên tử) | Hash `ledgermind:password-reset-otp:<email>`; Lua DEL+HSET+PEXPIRE | §1.2b |
| AP-06 | Kiểm tra OTP | Redis | Đọc/Ghi | email, code | Thấp | < 5 ms | Strong | Lua HGET/HINCRBY/DEL | §1.2b |
| AP-07 | Đọc cache thống kê của người dùng | Redis | Đọc | userId | Rất cao | < 5 ms | Eventual (cũ tối đa TTL 45–60 s nếu xóa cache lỗi) | String JSON `<prefix>:v1:user-dashboard:<userId>`, `…:user-popular-vendors:<userId>`; GET | §1.2a |
| AP-08 | Đọc cache thống kê quản trị | Redis | Đọc | tháng, ngưỡng, số tháng | Trung bình | < 5 ms | Eventual | `…:admin-dashboard-summary:<yyyy-MM>:<ngưỡng>`, `…:admin-statistics:monthly-transactions:<yyyy-MM>:<n>` | §1.2a |
| AP-09 | Cache miss: tính từ PG rồi ghi cache (TTL có jitter) | PostgreSQL + Redis | Đọc + Ghi | như AP-07/08 | Theo miss | < 200 ms | Strong (đọc PG) | SQL JPA của `UserStatisticsService`/`AdminStatisticsService`; SET PX | §1.2a |
| AP-10 | Xóa cache sau commit | Redis | Ghi | userId / cả cache | Cao | < 10 ms | Eventual | DEL; SCAN MATCH + DEL (lô 500) | §1.2a |
| AP-11 | Top N chi tiêu của tháng | Redis (+ PG lấy tên) | Đọc | tháng, limit | Trung bình | < 5 ms (phần Redis) | Eventual | ZSET `ledgermind:leaderboard:spend:<yyyy-MM>`; ZREVRANGE 0 N-1 WITHSCORES; `findAllById` | §1.2c |
| AP-12 | Dựng lại bảng xếp hạng tháng từ PG | PostgreSQL + Redis | Đọc + Ghi | tháng | Thấp (thiếu key, admin bấm) | < 500 ms | Eventual | `sumExpensesByUserBetween` → ZADD nhiều member → EXPIRE 62 ngày | §1.2c |
| AP-13 | Cập nhật tổng chi một người dùng sau commit | PostgreSQL + Redis | Ghi | userId, tháng | Cao | < 20 ms | Eventual | `sumExpensesBetween` → Lua EXISTS/ZADD/ZREM | §1.2c |
| AP-14 | Xóa mọi tháng bảng xếp hạng | Redis | Ghi | – | Rất thấp | < 100 ms | Eventual | SCAN MATCH `ledgermind:leaderboard:spend:*` + DEL | §1.2c |
| AP-15 | Phát sự kiện quản trị | Redis | Ghi | type, id | Trung bình | < 5 ms | At-most-once | PUBLISH `ledgermind:admin-events` | §1.2d |
| AP-16 | Nhận sự kiện và đẩy tới trình duyệt | Redis → SSE | Đọc | – | Trung bình | < 1 s từ PUBLISH tới trình duyệt (đầu-cuối; cách đo §2.7) | At-most-once | SUBSCRIBE; `GET /admin/events` | §1.2d |
| AP-17 | Ghi log OCR thô sau commit | MongoDB | Ghi | transactionId, JSON | Cao | < 20 ms | Eventual | `insert` `ocr_logs` (unique transactionId) | §1.3 |
| AP-18 | Upsert chỗ sửa OCR, xóa chỗ sửa lỗi thời | MongoDB | Ghi | receiptId, fieldError | Trung bình | < 20 ms | Eventual (nguyên tử trên một document) | `updateFirst` có điều kiện; `upsert` `$setOnInsert`; unique `receipt_field_uq`; `remove` | §1.3 |
| AP-19 | Danh sách phản hồi OCR lọc/sắp xếp/phân trang | MongoDB | Đọc | field, resolved, from, to, page, size, sort | Trung bình | < 20 ms | Eventual | `find` + `count`; `status_date_idx`, `reportedAt`, `isResolved` | §1.3 |
| AP-20 | Đánh dấu phản hồi đã xử lý | MongoDB | Ghi | id | Thấp | < 20 ms | Strong (một document) | `findById` + `save` | §1.3 |
| AP-21 | Xóa phản hồi | MongoDB | Ghi | id | Thấp | < 20 ms | Strong (một document) | `deleteById` | §1.3 |
| AP-22 | Số lỗi theo trường | MongoDB | Đọc | from, to | Thấp | < 50 ms | Eventual | `$match reportedAt` → `$group fieldError` → `$sort` | §1.3 |
| AP-23 | Số lỗi theo mô hình | MongoDB | Đọc | from, to | Thấp | < 50 ms | Eventual | `$group modelVersion` | §1.3 |
| AP-24 | Độ tin cậy trung bình theo tháng | MongoDB | Đọc | from, to | Thấp | < 50 ms | Eventual | `ocr_logs`: `$dateToString %Y-%m` → `$group $avg` | §1.3 |
| AP-25 | Tỉ lệ lần đọc bị sửa | MongoDB | Đọc | from, to | Thấp | < 100 ms | Eventual | `$match createdAt` → `$lookup ocr_feedbacks` (index transactionId) → `$group` | §1.3 |
| AP-26 | Xem log OCR thô theo trang (REST) | MongoDB | Đọc | page, size, sort (`Pageable`) | Thấp | < 20 ms | Eventual | `findAll(pageable)` (`J/Controller/OcrMongoController.java:29`, `J/Service/OcrMongoService.java:220-222`) | §1.3 |
| AP-27 | Sao lưu MongoDB | MongoDB | Đọc toàn bộ | – | Rất thấp | < 60 s (dữ liệu demo) | Bản chụp tại thời điểm dump | `mongodump --db=finance_nosql --archive --gzip` | §1.3 |
| AP-28 | Khôi phục MongoDB | MongoDB | Ghi toàn bộ | – | Rất thấp | < 60 s (dữ liệu demo) | – | `mongorestore --drop --nsInclude` 2 collection | §1.3 |
| AP-29 | Tìm giao dịch của mình theo từ khóa | Elasticsearch | Đọc | userId (JWT), q, page, size | Cao | < 100 ms (trên 100k tổng hợp) | Eventual (index sau commit) | `bool` filter userId + 2 `multi_match`; sort `_score`, `transactionDate` | §1.4 |
| AP-30 | Nạp lại kết quả theo id và chủ sở hữu | PostgreSQL | Đọc | ids, userId | Cao | < 20 ms | Strong | `findAllByIdInAndUserIdWithReceipt` | §1.1 |
| AP-31 | Tìm kiếm dự phòng trên PG | PostgreSQL | Đọc | userId, q, page, size | Khi ES tắt/sập | < 500 ms (trên 100k tổng hợp) | Strong | `searchIdsByText`: `LOWER(col) LIKE … ESCAPE` | §1.1 |
| AP-32 | Index/xóa document một giao dịch sau commit | PostgreSQL + Elasticsearch | Ghi | transactionId | Cao | < 50 ms | Eventual | `findForSearchIndex` → `save` / `delete` | §1.4 |
| AP-33 | Dựng lại toàn bộ chỉ mục | PostgreSQL + Elasticsearch | Ghi | – | Rất thấp | < 60 s cho 100k (mục tiêu) | Eventual | drop → create từ file → bulk 500/lần → refresh | §1.4 |
| AP-34 | Tạo chỉ mục khi thiếu | Elasticsearch | Ghi | – | Lúc khởi động / 15 s | < 5 s | – | `indexOps.exists` / `createWithMapping` | §1.4 |
| AP-35 | Đếm document của chỉ mục | Elasticsearch | Đọc | – | Thấp | < 50 ms | Eventual | `count` (`_count`) | §1.4 |
| AP-36 | Thống kê chi tiêu theo danh mục / tháng trên ES (**chỉ trong script, chưa có API**) | Elasticsearch | Đọc | userId, khoảng ngày | – | < 100 ms | Eventual | `terms categoryName.keyword` + `sum`; `date_histogram` | `S/elasticsearch/kibana-devtools.txt:147-193` |
| AP-37 | Đối chiếu chỗ sửa với câu trả lời thô; thống kê gộp `$facet` (**chỉ trong script**) | MongoDB | Đọc | fieldError | – | < 50 ms | Eventual | `$lookup` ocr_logs; `$facet` | `S/mongodb_demo.js:230-253` |
| AP-38 | Tra log OCR của một giao dịch; tìm lần đọc có độ tin cậy thấp (**chỉ trong script, chưa có API**; `findByTransactionIdOrderByCreatedAtDesc`, `findByAverageConfidenceScoreLessThan` khai báo nhưng không dùng) | MongoDB | Đọc | transactionId; ngưỡng | – | < 20 ms | Eventual | `findOne {transactionId}` (index unique `transactionId`); `find {averageConfidenceScore:{$lt}}` + sort `createdAt` (`score_date_idx`) | `S/mongodb_demo.js:112-121` |

### 2.3 NFR – Yêu cầu phi chức năng

| ID | Nhóm | Yêu cầu (đo được) | Cách kiểm chứng |
|---|---|---|---|
| NFR-01 | Hiệu năng | Đọc cache Redis (AP-07/AP-08) p95 < 5 ms ở tầng dữ liệu, 1 luồng | Task 3 E4 (Redis GET của JSON cache) |
| NFR-02 | Hiệu năng | Cache hit nhanh hơn cache miss (SQL JPA của dashboard) ít nhất 5 lần ở p50 | Task 3 E4 |
| NFR-03 | Hiệu năng | Tìm kiếm ES (AP-29) p95 < 100 ms trên 100k giao dịch tổng hợp; báo cả `took` của ES | Task 3 E2 |
| NFR-04 | Chất lượng tìm kiếm | ES: "pho" tìm ra "Phở", sai 1 ký tự vẫn ra, tiền tố "phu" ra "Phúc Long", không ra giao dịch người khác; chế độ PG **không** bỏ dấu (ghi là giới hạn) | TC-32..TC-35; Task 3 E2 (số hit "pho" vs "phở" trên cả hai engine) |
| NFR-05 | Hiệu năng | Truy vấn MongoDB có index (AP-19, AP-38) dùng IXSCAN, totalDocsExamined = nReturned, p95 < 20 ms trên dữ liệu tổng hợp | Q-16; Task 3 E1 (có/không index, explain executionStats) |
| NFR-06 | Hiệu năng | Top 10 bảng xếp hạng (AP-11) p95 < 5 ms, so với SQL `sumExpensesByUserBetween` | Task 3 E3 |
| NFR-07 | Sẵn sàng | Redis sập: dashboard/thống kê **vẫn trả lời** (đọc PG), mỗi request tốn thêm không quá timeout kết nối 1 s / lệnh 500 ms; OTP cố ý báo lỗi rõ ràng | TC-10, TC-11; demo `docker compose stop redis` ghi độ trễ quan sát |
| NFR-08 | Sẵn sàng | Elasticsearch sập: tìm kiếm **vẫn trả lời** bằng PG (`engine=postgres`), thêm không quá 1 s kết nối / 2 s socket; ghi giao dịch không bị ảnh hưởng | TC-36, TC-40; demo `docker compose stop elasticsearch` ghi độ trễ quan sát |
| NFR-09 | Sẵn sàng | MongoDB sập: ghi giao dịch/hóa đơn vẫn thành công; ghi Mongo chỉ log, chờ tối đa 5 s trên luồng nền | TC-30; cấu hình `serverSelectionTimeoutMS=5000` |
| NFR-10 | Nhất quán | PG strong (khóa ví, khóa lạc quan 409, clientId duy nhất); Redis/MongoDB/ES eventual sau commit; cache cũ tối đa bằng TTL (45–60 s) khi xóa cache lỗi; rollback không làm đổi NoSQL | TC-08, TC-09, TC-52, TC-53, TC-54 |
| NFR-11 | Bảo mật dữ liệu | Không bao giờ trả giao dịch người khác qua tìm kiếm (lọc userId ở ES + nạp lại theo owner ở PG); cache theo userId không lẫn | TC-07, TC-35, TC-37, TC-44 |
| NFR-12 | Bảo mật | `/api/admin/**`, `/admin/**` chỉ ROLE_ADMIN (2 lớp); Redis có mật khẩu, không mở cổng; Mongo/ES có mật khẩu, cổng chỉ 127.0.0.1; ES chặn tự tạo index | TC-19, TC-31, TC-45; kiểm tra `docker-compose.yml` |
| NFR-13 | Sao lưu | MongoDB: dump → xóa → khôi phục → đếm lại khớp 100%; thời gian khôi phục < 5 phút với dữ liệu demo; Redis không cần sao lưu (dựng lại từ PG); ES: snapshot hoặc reindex từ PG | TC-29, TC-49, TC-50; **đo thời gian** ở Task 4 trên stack demo (§2.7): `time mongorestore …` (S-61) và thời gian từ bấm "Khôi phục" tới thông báo trên `/admin/backup` (S-66) |
| NFR-14 | Tài nguyên | Chạy trên một máy: Redis ≤ 192M, MongoDB ≤ 512M (WiredTiger cache 0,25 GB), ES ≤ 1G (heap 512 MB), Kibana chỉ bật khi demo | Kiểm tra `docker-compose.yml`; Task 4: `docker stats --no-stream` trên stack demo (§2.7, S-89). Giới hạn bộ nhớ của stack demo phải đặt giống `docker-compose.yml` thì số đo mới đối chiếu được |
| NFR-15 | Realtime | Sự kiện quản trị tới trình duyệt < 1 s sau PUBLISH (mục tiêu); Redis chưa sẵn khi khởi động thì app vẫn chạy và tự đăng ký lại | TC-17, TC-18; đo ở Task 4 (§2.7, S-88, `bench_results.md` mục E6) |
| NFR-16 | Mở rộng | Nhiều instance API dùng chung Redis: cache và sự kiện Pub/Sub thấy nhau. Không đặt mục tiêu mở rộng ngang CSDL (mỗi CSDL 1 node; replica/shard chỉ ở mức thiết kế) | TC-55, TC-17 |

### 2.4 Q – Truy vấn trên GUI tool (Q-01..Q-41)

CB = cơ bản, NC = nâng cao. Tổng: 19 CB (Mongo 8, Redis 6, ES 5), 22 NC (Mongo 8, Redis 8, ES 6).

| ID | Loại | CSDL | Yêu cầu (ngôn ngữ người dùng) | Lệnh chính | AP | Nguồn |
|---|---|---|---|---|---|---|
| Q-01 | CB | MongoDB | Xem log AI thô của một giao dịch | `findOne({transactionId})` + projection | AP-38 | `S/mongodb_demo.js:112-115` |
| Q-02 | CB | MongoDB | Lần đọc AI kém (độ tin cậy < 0.75), mới nhất trước | `find({averageConfidenceScore:{$lt:0.75}}).sort({createdAt:-1}).limit(5)` | AP-38 | `S/mongodb_demo.js:117-121` |
| Q-03 | CB | MongoDB | Phản hồi chưa xử lý, mới nhất trước | `find({isResolved:false}).sort({reportedAt:-1})` (status_date_idx) | AP-19 | `S/mongodb_demo.js:123-127` |
| Q-04 | CB | MongoDB | Đếm lỗi total_cost trong tháng 9/2026; các giá trị fieldError | `countDocuments`, `distinct` | AP-19 | `S/mongodb_demo.js:129-136` |
| Q-05 | CB | MongoDB | Validator chặn document sai schema | `insertOne` sai kiểu → lỗi 121 | AP-18 | `S/mongodb_demo.js:138-146` |
| Q-06 | CB | MongoDB | Unique index chặn trùng (receiptId, fieldError) | `insertOne` trùng → lỗi 11000 | AP-18 | `S/mongodb_demo.js:148-156` |
| Q-07 | CB | MongoDB | Admin đánh dấu đã xử lý | `updateOne({_id},{$set:{isResolved:true}})` | AP-20 | `S/mongodb_demo.js:158-164` |
| Q-08 | CB | MongoDB | Xóa phản hồi | `deleteOne({_id})` | AP-21 | `S/mongodb_demo.js:166-171` |
| Q-09 | NC | MongoDB | Ghi chỗ sửa không bao giờ trùng, sửa lại thì mở lại | `updateOne` có điều kiện `$ne` + `updateOne(..., {$setOnInsert}, {upsert:true})` | AP-18 | `S/mongodb_demo.js:173-201` |
| Q-10 | NC | MongoDB | Trường nào AI đọc sai nhiều nhất | `aggregate $match/$group/$sort` | AP-22 | `S/mongodb_demo.js:203-210` |
| Q-11 | NC | MongoDB | Lỗi theo mô hình (donut-v4 vs v5) | `$group {$ifNull:["$modelVersion","unknown"]}` | AP-23 | `S/mongodb_demo.js:212-218` |
| Q-12 | NC | MongoDB | Độ tin cậy trung bình theo tháng | `$project $dateToString` + `$group $avg` | AP-24 | `S/mongodb_demo.js:220-228` |
| Q-13 | NC | MongoDB | Mỗi chỗ sửa tên quán kèm câu trả lời thô của AI | `$lookup` ocr_logs + `$unwind` + `$project` | AP-37 | `S/mongodb_demo.js:230-241` |
| Q-14 | NC | MongoDB | Ba thống kê trong một lần truy vấn | `$facet` | AP-37 | `S/mongodb_demo.js:243-253` |
| Q-15 | NC | MongoDB | Tỉ lệ lần đọc bị sửa | `$lookup` ocr_feedbacks + `$group` + `$divide` | AP-25 | `S/mongodb_demo.js:255-265` |
| Q-16 | NC | MongoDB | Chứng minh truy vấn dùng index | `explain("executionStats")` → IXSCAN | AP-19, AP-38 | `S/mongodb_demo.js:267-286` |
| Q-17 | CB | Redis | Lưu OTP 5 phút | `HSET` + `PEXPIRE 300000` + `PTTL` | AP-05 | `S/redis_demo.txt:18-24` |
| Q-18 | CB | Redis | Đếm lần nhập sai, OTP hết hạn | `HINCRBY`, `HGET`, `PEXPIREAT`, `EXISTS` | AP-06 | `S/redis_demo.txt:26-33` |
| Q-19 | CB | Redis | Cache dashboard của user 1 | `SET … EX`, `GET`, `TTL`, `TYPE` | AP-07 | `S/redis_demo.txt:38-43` |
| Q-20 | CB | Redis | TTL lệch nhau (jitter), xóa = evict | `SET … EX` khác nhau, `DEL`, `EXISTS` | AP-07, AP-10 | `S/redis_demo.txt:45-53` |
| Q-21 | CB | Redis | Liệt kê key của một cache không chặn Redis | `SCAN 0 MATCH … COUNT 100 [TYPE string]` | AP-10 | `S/redis_demo.txt:55-58` |
| Q-22 | NC | Redis | Dựng bảng xếp hạng tháng | `ZADD` nhiều member + `EXPIRE 5356800` | AP-12 | `S/redis_demo.txt:64-71` |
| Q-23 | NC | Redis | Top 3 chi nhiều nhất | `ZREVRANGE 0 2 WITHSCORES` | AP-11 | `S/redis_demo.txt:73-75` |
| Q-24 | NC | Redis | Thứ hạng, điểm, số người trong khoảng tiền | `ZREVRANK`, `ZSCORE`, `ZCOUNT` | AP-11 | `S/redis_demo.txt:77-81` |
| Q-25 | NC | Redis | ZINCRBY khác ZADD tuyệt đối; gỡ member | `ZINCRBY`, `ZADD`, `ZREM` | AP-13 | `S/redis_demo.txt:83-90` |
| Q-26 | NC | Redis | Nhiều lệnh thành một giao dịch | `MULTI` … `EXEC` | AP-12 | `S/redis_demo.txt:92-99` |
| Q-27 | NC | Redis | Kiểm tra OTP nguyên tử | `EVAL` Lua (SAVE, CHECK) → 1, 2, 0, -1 | AP-05, AP-06 | `S/redis_demo.txt:104-114` |
| Q-28 | NC | Redis | Dọn các tháng bảng xếp hạng | `SCAN MATCH` + `DEL` | AP-14 | `S/redis_demo.txt:119-124` |
| Q-29 | CB | Redis | Kiểm tra persistence, BGSAVE (demo) | `CONFIG GET save/appendonly`, `BGSAVE`, `LASTSAVE`, `INFO persistence` | – (vận hành; NFR-13) | `S/redis_demo.txt:126-134` |
| Q-30 | CB | Elasticsearch | Index có mặt, bao nhiêu document | `GET _cat/indices/transactions?v`, `GET transactions/_count` | AP-35 | `S/elasticsearch/kibana-devtools.txt:15-21` |
| Q-31 | CB | Elasticsearch | Lấy document theo id | `GET transactions/_doc/1` | AP-32 | `S/elasticsearch/kibana-devtools.txt:23-27` |
| Q-32 | CB | Elasticsearch | Giao dịch của một người, mới nhất trước | `bool filter term userId` + `sort transactionDate` | AP-29 | `S/elasticsearch/kibana-devtools.txt:29-39` |
| Q-33 | CB | Elasticsearch | Gõ "ca phe" ra "Cà phê" | `match categoryName` | AP-29 | `S/elasticsearch/kibana-devtools.txt:41-53` |
| Q-34 | CB | Elasticsearch | Xem analyzer tách token | `GET transactions/_analyze` (vi_folded, vi_autocomplete) | AP-29 | `S/elasticsearch/kibana-devtools.txt:55-69` |
| Q-35 | NC | Elasticsearch | Truy vấn thật của app cho "pho" | `bool` + 2 `multi_match` (exact boost 2, fuzzy AUTO:4,7) | AP-29 | `S/elasticsearch/kibana-devtools.txt:71-107` |
| Q-36 | NC | Elasticsearch | Gõ sai "highlans cofee" vẫn ra | `multi_match fuzziness AUTO:4,7 prefix_length 1` | AP-29 | `S/elasticsearch/kibana-devtools.txt:109-126` |
| Q-37 | NC | Elasticsearch | Gợi ý khi đang gõ "hig" | `multi_match` trên `.autocomplete` | AP-29 | `S/elasticsearch/kibana-devtools.txt:128-144` |
| Q-38 | NC | Elasticsearch | Chi tiêu tháng 9/2026 của tôi, theo số tiền | `bool filter term + range` + `sort amount` | AP-36 | `S/elasticsearch/kibana-devtools.txt:146-160` |
| Q-39 | NC | Elasticsearch | Chi tiêu theo danh mục | `aggs terms categoryName.keyword` + `sum` | AP-36 | `S/elasticsearch/kibana-devtools.txt:162-177` |
| Q-40 | NC | Elasticsearch | Chi tiêu theo tháng | `aggs date_histogram month` + `sum` | AP-36 | `S/elasticsearch/kibana-devtools.txt:179-193` |
| Q-41 | NC | Redis | Kênh sự kiện realtime cho trang quản trị | `PUBSUB CHANNELS/NUMSUB`, `PUBLISH`, `SUBSCRIBE` (2 cửa sổ) | AP-15, AP-16 | `S/redis_demo.txt:135-146` |

### 2.5 TC – Ca kiểm thử (Ch.7 dùng)

Kết quả chạy thật ở §4. "Tự động" = phương thức JUnit; "Script" = kiểm tra bằng script trong container dùng một lần.

| ID | Yêu cầu / AP | Loại | Ca kiểm thử (lớp.phương thức hoặc script) | Kết quả mong đợi |
|---|---|---|---|---|
| TC-01 | FR-02 / AP-06 | Tự động | `RedisPasswordResetOtpStoreIntegrationTest.theRightCodeIsAcceptedOnce_andCannotBeReplayed` | Mã đúng được nhận một lần, lần sau -1 |
| TC-02 | FR-02 / AP-06 | Tự động | `RedisPasswordResetOtpStoreIntegrationTest.wrongGuessesCountUp_andTheThirdDropsTheOtp_soEvenTheRightCodeIsRefusedAfterwards` | Sai lần 3 thì OTP bị xóa |
| TC-03 | FR-02 / AP-05 | Tự động | `RedisPasswordResetOtpStoreIntegrationTest.theKeyExpiresInRedisAfterTheValidity_soForgottenOtpsDoNotPileUp` | Key có TTL bằng hạn OTP |
| TC-04 | FR-02 / AP-06 | Tự động | `RedisPasswordResetOtpStoreIntegrationTest.onlyThreeWrongGuessesAreEverWeighed_evenWhenTheyArriveInParallelOnTwoInstances` | Lua nguyên tử: song song 2 instance vẫn chỉ 3 lần sai |
| TC-05 | FR-07 / AP-07, AP-09 | Tự động | `RedisStatisticsCacheIntegrationTest.aMissReadsTheDatabaseOnceAndTheHitsAfterItComeFromRedisThroughTheProxy` | Miss đọc DB một lần, các lần sau từ Redis |
| TC-06 | FR-07 / AP-07 | Tự động | `RedisStatisticsCacheIntegrationTest.theEntryIsPlainJsonUnderAKeyThatNamesTheEnvironmentTheSchemaTheCacheAndTheUserAndItExpires` | Khóa `<prefix>:v1:<cache>:<user>`, JSON thuần, có TTL |
| TC-07 | NFR-11 / AP-07 | Tự động | `RedisStatisticsCacheIntegrationTest.aliceNeverReadsBobsEntryNorBobAlices` | Không đọc lẫn cache người khác |
| TC-08 | FR-03 / AP-10 | Tự động | `StatisticsCacheTransactionTest.aCheckoutEvictsItsOwnersEntriesOnlyOnceItHasCommittedAndTheNextReadSeesIt` | Xóa cache sau commit, lần đọc sau thấy số mới |
| TC-09 | NFR-10 / AP-10 | Tự động | `StatisticsCacheTransactionTest.aWriteWhoseTransactionRollsBackEvictsNothingAndTheEntryStillMatchesTheDatabase` | Rollback không xóa cache |
| TC-10 | NFR-07 | Tự động | `RedisOutageTest.aRedisThatCannotBeReachedLeavesEveryReadToTheDatabaseAndEveryEvictionHarmless` | Redis không với tới: đọc từ DB, không lỗi |
| TC-11 | NFR-07 | Tự động | `RedisOutageTest.aRedisThatStopsAnsweringCostsARequestNoMoreThanTheCommandTimeouts` | Redis treo: request chậm thêm tối đa bằng timeout |
| TC-12 | FR-10 / AP-12 | Tự động | `SpendingLeaderboardServiceIntegrationTest.topSpenders_missingKey_rebuildsFromPostgresAndSetsTtl` | Thiếu key: dựng từ PG, có TTL |
| TC-13 | FR-10 / AP-11 | Tự động | `SpendingLeaderboardServiceIntegrationTest.topSpenders_existingKey_doesNotQueryPostgres` | Có key: không truy vấn PG |
| TC-14 | FR-03 / AP-13 | Tự động | `SpendingLeaderboardServiceIntegrationTest.onTransactionChanged_setsAbsoluteMonthlyTotal` | Score = tổng tuyệt đối đọc từ PG |
| TC-15 | FR-03 / AP-13 | Tự động | `SpendingLeaderboardServiceIntegrationTest.onTransactionChanged_keyExpiresWhileTheTotalIsRead_isNotCreatedAgain` | Lua không tạo lại set đã hết hạn |
| TC-16 | FR-15 / AP-14 | Tự động | `SpendingLeaderboardServiceIntegrationTest.databaseRestored_dropsEveryMonthWithScanAndTheNextReadRebuilds` | Khôi phục DB: SCAN xóa mọi tháng, lần đọc sau dựng lại |
| TC-17 | FR-16 / AP-15, AP-16 | Tự động | `AdminEventRelayIntegrationTest.anEventPublishedOnceReachesTheEmittersOfBothInstances` | Một PUBLISH tới SSE của cả 2 instance |
| TC-18 | NFR-15 | Tự động | `AdminEventRelayIntegrationTest.anInstanceStartedWhileRedisIsDownStartsAnywayAndSubscribesOnceRedisIsUp` | Redis chưa chạy: app vẫn khởi động, sau đó tự đăng ký |
| TC-19 | NFR-12 / FR-16 | Tự động | `AdminEventsControllerTest.anOrdinaryUserIsRefused` | Người dùng thường bị từ chối luồng SSE |
| TC-20 | FR-06 / AP-18 | Tự động | `OcrMongoServiceMongoIntegrationTest.correction_upsertsOneDocPerReceiptField` | Mỗi (hóa đơn, trường) đúng một document |
| TC-21 | FR-06 / AP-18 | Tự động | `OcrMongoServiceMongoIntegrationTest.correction_sameExpectedValueAgain_keepsItResolved_differentValueReopens` | Gửi lại y nguyên: giữ đã xử lý; giá trị khác: mở lại |
| TC-22 | FR-06 / AP-18 | Tự động | `OcrMongoServiceMongoIntegrationTest.correction_editedBackToTheAiValue_removesTheStaleDoc` | Trả về giá trị AI: xóa chỗ sửa cũ |
| TC-23 | FR-05 / AP-17 | Tự động | `OcrMongoServiceMongoIntegrationTest.rawLog_storesModelVersionAndAiReading` | Log có modelVersion và aiReading |
| TC-24 | FR-11 / AP-19 | Tự động | `OcrMongoServiceMongoIntegrationTest.findFeedbacks_filtersByFieldAndResolved_sortedNewestFirst` | Lọc đúng, mới nhất trước |
| TC-25 | FR-12 / AP-22, AP-23, AP-24 | Tự động | `OcrMongoServiceMongoIntegrationTest.analytics_groupsByFieldAndModel_andMonthlyConfidence` | Số liệu nhóm đúng |
| TC-26 | FR-12 / AP-25 | Tự động | `OcrMongoServiceMongoIntegrationTest.analytics_feedbackReportedAfterTheRange_rateStaysAtMostOne` | Tỉ lệ ≤ 1 |
| TC-27 | FR-11 / AP-20 | Tự động | `OcrMongoServiceMongoIntegrationTest.resolve_marksTheDocResolved` | isResolved = true |
| TC-28 | FR-11 / AP-21 | Tự động | `OcrMongoServiceMongoIntegrationTest.delete_removesDoc` | Document bị xóa |
| TC-29 | FR-15 / AP-27, AP-28 | Tự động | `MongoBackupServiceIntegrationTest.dumpDropAndRestoreBringBackTheTwoCollectionsAndTouchNothingElse` | Dump → xóa → restore: 2 collection trở lại, collection khác không bị đụng |
| TC-30 | NFR-09 / AP-17 | Tự động | `OcrMongoServiceTest$OnOcrProcessedEventGracefulDegradation.doesNotPropagateExceptionWhenMongoSaveFails` | Mongo lỗi: không ném lỗi về luồng gọi |
| TC-31 | NFR-12 / FR-15 | Tự động | `AdminMongoBackupControllerTest.anOrdinaryUserIsRefusedAndNothingRuns` | Người dùng thường bị từ chối, không chạy gì |
| TC-32 | FR-08 / AP-29 | Tự động | `ElasticsearchTransactionSearchEngineIntegrationTest.pho_matchesPhoHung` | "pho" ra "Phở Hùng" |
| TC-33 | NFR-04 / AP-29 | Tự động | `ElasticsearchTransactionSearchEngineIntegrationTest.typo_phoHug_matchesPhoHung` | Sai chính tả vẫn ra |
| TC-34 | NFR-04 / AP-29 | Tự động | `ElasticsearchTransactionSearchEngineIntegrationTest.prefix_phu_matchesPhucLong` | Tiền tố "phu" ra "Phúc Long" |
| TC-35 | NFR-11 / AP-29 | Tự động | `ElasticsearchTransactionSearchEngineIntegrationTest.otherUsersDocs_neverReturned` | Không trả document người khác |
| TC-36 | NFR-08 / AP-31 | Tự động | `TransactionSearchServiceTest.esThrows_fallsBackToPostgres_engineIsPostgres` | ES lỗi: PG trả lời, engine=postgres |
| TC-37 | NFR-11 / AP-30 | Tự động | `TransactionSearchServiceTest.idMissingInPostgres_dropped` | Id không còn ở PG bị bỏ |
| TC-38 | FR-03 / AP-32 | Tự động | `TransactionSearchIndexerIntegrationTest.upsertedEvent_indexesTransactionWithVendor` | Document có vendorName của hóa đơn |
| TC-39 | FR-04 / AP-32 | Tự động | `TransactionSearchIndexerIntegrationTest.deletedEvent_removesDocument` | Xóa giao dịch: xóa document |
| TC-40 | NFR-08 / AP-32 | Tự động | `TransactionSearchIndexerIntegrationTest.esDown_listenerLogsAndDoesNotThrow` | ES sập: chỉ log |
| TC-41 | FR-14 / AP-34 | Tự động | `TransactionSearchIndexerIntegrationTest.saveBeforeEnsureIndex_createsIndexFromMapping_notDynamic` | Index tạo từ mapping, không dynamic |
| TC-42 | FR-14 / AP-33 | Tự động | `TransactionSearchIndexerIntegrationTest.databaseRestored_rebuildsTheIndex_otherChangesDoNot` | Khôi phục DB: dựng lại index |
| TC-43 | FR-08 / AP-31 | Tự động | `TransactionSearchRepositoryTest.searchIdsByText_percentIsLiteral_andNewestFirst` | `%` là ký tự thường; mới nhất trước |
| TC-44 | NFR-11 / AP-31 | Tự động | `TransactionSearchRepositoryTest.searchIdsByText_onlyCallerRows` | Chỉ dòng của người gọi |
| TC-45 | NFR-12 / FR-08 | Tự động | `TransactionSearchControllerTest.noToken_rejected` | Không token: bị từ chối |
| TC-46 | NFR-05 / AP-19 | Script | `S/mongodb_demo.js` Q-16: `explain("executionStats")` | winningPlan có IXSCAN (status_date_idx, transactionId, receipt_field_uq) |
| TC-47 | AP-18 | Script | `S/mongodb_demo.js` Q-05 | Insert sai schema bị từ chối |
| TC-48 | AP-18 | Script | `S/mongodb_demo.js` Q-06 | Insert trùng (receiptId, fieldError) bị từ chối |
| TC-49 | NFR-13 / AP-27, AP-28 | Script | `S/backup_restore.md` mục 1a: đếm → mongodump → xóa → mongorestore → đếm | Số document trước = sau |
| TC-50 | NFR-13 | Script | `S/backup_restore.md` mục 3a: snapshot → xóa index → restore → `_count` | Số document trước = sau |
| TC-51 | FR-02 / AP-06 | Script | `S/redis_demo.txt` Q-27: EVAL Lua | Trả về lần lượt 1, 2, 0, -1 |
| TC-52 | NFR-10 / AP-02 | Tự động | `TransactionServiceTest.aRepeatOfTheSameClientIdIsAnsweredWithTheOriginalAndIsNoDuplicate` | Gửi lại cùng clientId: trả giao dịch gốc, không tạo bản trùng |
| TC-53 | NFR-10 / AP-02 | Tự động | `TransactionServiceTest.theBalanceUsedIsTheOneReadUnderTheLockNotTheOneReadEarlier` | Số dư dùng là số đọc dưới khóa ví |
| TC-54 | NFR-10 / AP-04 | Tự động | `ReceiptConcurrencyPostgresTest` (hợp đồng `ReceiptConcurrencyContract.ofTwoEditsMadeFromTheSameVersionThatArriveTogetherOneIsWrittenAndTheOtherChangesNothing`) | Hai lần sửa cùng phiên bản: một ghi, một không đổi gì (409) |
| TC-55 | NFR-16 / AP-07 | Tự động | `RedisStatisticsCacheIntegrationTest.twoInstancesShareOneRedisSoWhatOneComputedTheOtherReads` | Instance B đọc được cache instance A tính |

### 2.6 S – Khung ảnh chụp màn hình

Cột "Người chụp": **agent** = Task 4 chụp tự động (Playwright/terminal trên stack demo), không ghi công cho ai;
**Tiến** = mặc định cho mọi ảnh phía người dùng (Compass, app, trang admin, Postman, RedisInsight) theo phân công [Q3],
chụp trên stack demo riêng [Q8] (`scripts/nosql/demo-stack.sh`, Task 4); **Trí** = chỉ những ảnh cần máy/stack đầy đủ của
Trí (dừng dịch vụ trên stack đầy đủ, JMeter). Ảnh do người khác thực tế chụp thì sửa cột này trước khi viết 1.6/8.3.
Quy ước: ảnh kết quả của Q-n là **S-(n+19)**. **Mục 3.7 (giao diện người dùng) dùng lại các ảnh S-67, S-68, S-69, S-72,
S-74, S-76, S-77, S-78, S-80, S-81** (không chụp riêng; 3.7 tham chiếu hình ở 6.3 hoặc chèn lại).
Bằng chứng nhập/xuất + sao lưu/khôi phục cho mỗi CSDL (5.6): MongoDB S-61, S-62, S-65, S-66; Redis S-63, S-86;
Elasticsearch S-19, S-64, S-87.

| ID | Mục báo cáo | Nội dung ảnh | Công cụ | Người chụp |
|---|---|---|---|---|
| S-01 | 2.5 (tiêu chí 1) | Elasticsearch container healthy + đặt mật khẩu `kibana_system` (terminal) | Terminal | agent |
| S-02 | 2.5 (tiêu chí 1) | Kibana sau khi cài: trang đăng nhập / Home | Kibana | agent |
| S-03 | 2.5 (tiêu chí 2) | Index Management: index `transactions`, settings/mapping | Kibana | agent |
| S-04 | 2.5 (tiêu chí 2) | Dev Tools chạy truy vấn | Kibana | agent |
| S-05 | 2.5 (tiêu chí 2) | Import: Upload file / Data Visualizer | Kibana | agent |
| S-06 | 2.5 (tiêu chí 2) | Export dữ liệu (Discover → Share → CSV, nếu bản Basic có; nếu không thì ghi rõ) | Kibana | agent |
| S-07 | 2.5 (tiêu chí 2) | Snapshot and Restore: repository + snapshot | Kibana | agent |
| S-08 | 2.5 (tiêu chí 2) | Security: Users/Roles (role chỉ đọc index transactions) | Kibana | agent |
| S-09 | 2.5 (tiêu chí 2) | Giám sát: Index Management stats / `_cat` (không có Stack Monitoring vì chưa cài Metricbeat) | Kibana | agent |
| S-10 | 2.5 (tiêu chí 1) | Elasticvue: kết nối cluster (cài bằng docker) | Elasticvue | agent |
| S-11 | 2.5 (tiêu chí 3) | Elasticvue: danh sách index, document, tìm kiếm | Elasticvue | agent |
| S-12 | 2.5 (tiêu chí 3) | Elasticvue: REST query | Elasticvue | agent |
| S-13 | 2.5 (tiêu chí 3) | Elasticvue: snapshot / repositories | Elasticvue | agent |
| S-14 | 2.5 (tiêu chí 3) | `docker stats` RAM/CPU Kibana vs Elasticvue + thời gian tải trang đầu (đo) | Terminal | agent |
| S-15 | 5.2 | Compass: database `finance_nosql`, tab Validation `$jsonSchema` | Compass | Tiến |
| S-16 | 5.2 | Compass: tab Indexes của `ocr_feedbacks` | Compass | Tiến |
| S-17 | 5.3 | Compass: `finance_nosql_demo` 36 + 36 document | Compass | Tiến |
| S-18 | 5.2–5.3 | RedisInsight: danh sách key `ledgermind:*` kèm kiểu và TTL | RedisInsight | agent |
| S-19 | 5.2–5.3 | Tạo index `transactions` + bulk 47 document (`_count`) | Kibana Dev Tools | agent |
| S-20 | 5.4 | Kết quả Q-01 | Compass | Tiến |
| S-21 | 5.4 | Kết quả Q-02 | Compass | Tiến |
| S-22 | 5.4 | Kết quả Q-03 | Compass | Tiến |
| S-23 | 5.4 | Kết quả Q-04 | Compass (mongosh) | Tiến |
| S-24 | 5.4 | Kết quả Q-05 | Compass (mongosh) | Tiến |
| S-25 | 5.4 | Kết quả Q-06 | Compass (mongosh) | Tiến |
| S-26 | 5.4 | Kết quả Q-07 | Compass | Tiến |
| S-27 | 5.4 | Kết quả Q-08 | Compass | Tiến |
| S-28 | 5.5 | Kết quả Q-09 | Compass (mongosh) | Tiến |
| S-29 | 5.5 | Kết quả Q-10 | Compass Aggregations | Tiến |
| S-30 | 5.5 | Kết quả Q-11 | Compass Aggregations | Tiến |
| S-31 | 5.5 | Kết quả Q-12 | Compass Aggregations | Tiến |
| S-32 | 5.5 | Kết quả Q-13 | Compass Aggregations | Tiến |
| S-33 | 5.5 | Kết quả Q-14 | Compass Aggregations | Tiến |
| S-34 | 5.5 | Kết quả Q-15 | Compass Aggregations | Tiến |
| S-35 | 5.5 | Kết quả Q-16 (Explain Plan IXSCAN) | Compass Explain | Tiến |
| S-36 | 5.4 | Kết quả Q-17 | RedisInsight | agent |
| S-37 | 5.4 | Kết quả Q-18 | RedisInsight | agent |
| S-38 | 5.4 | Kết quả Q-19 | RedisInsight | agent |
| S-39 | 5.4 | Kết quả Q-20 | RedisInsight | agent |
| S-40 | 5.4 | Kết quả Q-21 | RedisInsight | agent |
| S-41 | 5.5 | Kết quả Q-22 | RedisInsight | agent |
| S-42 | 5.5 | Kết quả Q-23 | RedisInsight | agent |
| S-43 | 5.5 | Kết quả Q-24 | RedisInsight | agent |
| S-44 | 5.5 | Kết quả Q-25 | RedisInsight | agent |
| S-45 | 5.5 | Kết quả Q-26 | RedisInsight | agent |
| S-46 | 5.5 | Kết quả Q-27 | RedisInsight | agent |
| S-47 | 5.5 | Kết quả Q-28 | RedisInsight | agent |
| S-48 | 5.4 | Kết quả Q-29 | RedisInsight | agent |
| S-49 | 5.4 | Kết quả Q-30 | Kibana Dev Tools | agent |
| S-50 | 5.4 | Kết quả Q-31 | Kibana Dev Tools | agent |
| S-51 | 5.4 | Kết quả Q-32 | Kibana Dev Tools | agent |
| S-52 | 5.4 | Kết quả Q-33 | Kibana Dev Tools | agent |
| S-53 | 5.4 | Kết quả Q-34 | Kibana Dev Tools | agent |
| S-54 | 5.5 | Kết quả Q-35 | Kibana Dev Tools | agent |
| S-55 | 5.5 | Kết quả Q-36 | Kibana Dev Tools | agent |
| S-56 | 5.5 | Kết quả Q-37 | Kibana Dev Tools | agent |
| S-57 | 5.5 | Kết quả Q-38 | Kibana Dev Tools | agent |
| S-58 | 5.5 | Kết quả Q-39 | Kibana Dev Tools | agent |
| S-59 | 5.5 | Kết quả Q-40 | Kibana Dev Tools | agent |
| S-60 | 5.5 | Kết quả Q-41 (PUBLISH/SUBSCRIBE hai cửa sổ) | RedisInsight Pub/Sub | agent |
| S-61 | 5.6 | MongoDB: đếm → mongodump → xóa → `time mongorestore` → đếm (NFR-13) | Terminal | agent |
| S-62 | 5.6 | MongoDB: mongoexport / mongoimport | Terminal | agent |
| S-63 | 5.6 | Redis: RDB SAVE → khởi động lại với dump.rdb → đếm | Terminal | agent |
| S-64 | 5.6 | Elasticsearch: snapshot → xóa → restore → `_count` | Kibana / Terminal | agent |
| S-65 | 5.6, 6.3 | Trang `/admin/backup`, thẻ MongoDB: sao lưu thành công | Web admin | Tiến |
| S-66 | 5.6, 6.3 | `/admin/backup` khôi phục MongoDB + Compass đếm lại | Web admin + Compass | Tiến |
| S-67 | 6.3 (nhóm 1), 3.7 | Mobile: đăng nhập | App mobile | Tiến |
| S-68 | 6.3 (nhóm 1), 3.7 | Web admin: đăng nhập, trang người dùng (phân quyền) | Web admin | Tiến |
| S-69 | 6.3 (nhóm 1), 3.7 | Mobile: quên mật khẩu, nhập OTP | App mobile | Tiến |
| S-70 | 6.3 (nhóm 1) | RedisInsight: key `ledgermind:password-reset-otp:<email>` (Hash, TTL) | RedisInsight | Tiến |
| S-71 | 6.3 (nhóm 2) | Postman/Swagger: `GET /api/admin/ocr-feedbacks` | Postman | Tiến |
| S-72 | 6.3 (nhóm 2), 3.7 | Trang `/admin/ocr-feedbacks`: danh sách + 3 biểu đồ | Web admin | Tiến |
| S-73 | 6.3 (nhóm 2) | Đánh dấu đã xử lý / xóa phản hồi + Compass thấy dữ liệu đổi | Web admin + Compass | Tiến |
| S-74 | 6.3 (nhóm 3), 3.7 | Mobile: Sổ cái tìm "pho" ra các dòng "Phở" | App mobile | Tiến |
| S-75 | 6.3 (nhóm 3) | Document của giao dịch vừa tạo xuất hiện trong index (đồng bộ sau commit) | Kibana / Elasticvue | Tiến |
| S-76 | 6.3 (nhóm 3), 3.7 | Mobile: quét hóa đơn rồi sửa → document `ocr_feedbacks` mới trong Compass | App + Compass | Tiến |
| S-77 | 6.3 (nhóm 4), 3.7 | `/admin/dashboard`: top 5 chi tiêu tháng | Web admin | Tiến |
| S-78 | 6.3 (nhóm 4), 3.7 | `/admin/nosql`: dựng lại chỉ mục + bảng xếp hạng (flash) | Web admin | Tiến |
| S-79 | 6.3 (nhóm 4) | RedisInsight: ZSET `ledgermind:leaderboard:spend:<yyyy-MM>` | RedisInsight | Tiến |
| S-80 | 6.3, 6.4, 3.7 | Toast realtime trên trang admin (Pub/Sub → SSE) | Web admin | Tiến |
| S-81 | 6.3 (nhóm 4), 3.7 | Mobile trang chủ + RedisInsight key `…:user-dashboard:<userId>` | App + RedisInsight | Tiến |
| S-82 | 6.4, 7.3 | Postman: `/api/transactions/search` trả `engine=elasticsearch`, rồi `engine=postgres` sau khi dừng ES | Postman | Tiến |
| S-83 | 7.3 | Dừng Redis: dashboard vẫn trả lời (Postman, độ trễ quan sát; cần stack đầy đủ) | Postman + Terminal | Trí |
| S-84 | 7.3 | Dừng MongoDB: quét hóa đơn vẫn lưu (log cảnh báo; cần stack đầy đủ) | App + Terminal | Trí |
| S-85 | 7.2 | JMeter Summary Report (tùy chọn, chỉ khi chạy) | JMeter | Trí |
| S-86 | 5.6 | Redis: nhập bằng `redis-cli < redis_demo.txt` (DBSIZE trước/sau; `S/backup_restore.md:124`) và xuất bằng `redis-cli --rdb` (`S/backup_restore.md` mục 2b, `:144-151`) | Terminal / RedisInsight | agent |
| S-87 | 5.6 | Elasticsearch: xuất bằng `GET transactions/_search?size=1000` → xóa index → tạo lại từ hai file mapping/settings của app → nhập lại bằng `_bulk` (`"errors":false`) → `_count` = 47 (`S/backup_restore.md` mục 3b, `:179-183`) | Kibana Dev Tools / Terminal | agent |
| S-88 | 7.2, 6.4 | Đo độ trễ sự kiện realtime (§2.7): terminal `curl -N` trên `/admin/events` + bảng p50/p95 | Terminal | agent |
| S-89 | 7.2 | `docker stats --no-stream` của stack demo (NFR-14) | Terminal | agent |

### 2.7 Cách đo các mục tiêu chưa có số (giao cho plan Task 3/Task 4; mục tiêu giữ nguyên như đã đóng băng)

| Mục tiêu | Ai đo | Cách đo | Bằng chứng |
|---|---|---|---|
| NFR-15 / AP-16: sự kiện tới trình duyệt < 1 s sau PUBLISH | plan Task 4, trên stack demo (core-api chạy với Redis của stack demo) | Đăng nhập admin lấy cookie phiên; mở `curl -N -b <cookie> http://127.0.0.1:<port>/admin/events`, gắn giờ nhận cho mỗi dòng (ví dụ `while read l; do echo "$(date +%s.%N) $l"; done`). Phát **≥ 20 sự kiện** (bấm "Dựng lại bảng xếp hạng" trên `/admin/nosql`, hoặc `PUBLISH ledgermind:admin-events` với JSON đúng dạng `AdminEvent`). Giờ phát = trường `at` trong payload (hoặc giờ gọi PUBLISH khi phát bằng redis-cli); độ trễ = giờ nhận − giờ phát, trên cùng một máy (một đồng hồ). Báo p50/p95/max và số sự kiện mất. | `bench_results.md` mục **E6 realtime**; S-88 |
| NFR-13: khôi phục MongoDB < 5 phút (dữ liệu demo) | plan Task 4 | `time mongorestore …` theo `S/backup_restore.md` mục 1a; đồng hồ cho thao tác khôi phục trên `/admin/backup` | `bench_results.md` mục "Sao lưu"; S-61, S-66 |
| NFR-14: bộ nhớ container | plan Task 4 | `docker stats --no-stream` sau khi nạp dữ liệu demo và chạy hết Q-xx | `bench_results.md` mục "Tài nguyên"; S-89 |
| NFR-01..NFR-06 | plan Task 3 | E1–E5 theo phương pháp của plan | `bench_results.md` |

---

## §3. Danh sách hạn chế (Ch.7.4 + Ch.8)

| # | Hạn chế | Nguồn |
|---|---|---|
| L1 | Chế độ tìm kiếm PostgreSQL **không bỏ dấu** (`LOWER … LIKE`): "pho" không ra "Phở"; không xếp theo độ liên quan; quét theo LIKE `%…%` | `J/Repository/TransactionRepository.java:149-181` |
| L2 | Ghi NoSQL là **sau commit, bất đồng bộ, nhất quán cuối cùng**. JVM chết giữa commit PG và lần ghi nền → thay đổi đó chỉ được chữa ở lần đổi kế tiếp của cùng dòng, lần dựng lại (leaderboard hết TTL/admin rebuild) hoặc reindex; log OCR/feedback bị mất thì không có cơ chế tự chữa | `J/Service/Search/TransactionSearchIndexer.java:117-134`; `J/Service/Cache/SpendingLeaderboardService.java:141-153`; `J/Service/OcrMongoService.java:91-172` |
| L3 | Hàng đợi `mongoAsyncExecutor` đầy (500) → **bỏ** tác vụ ghi NoSQL đó (chỉ log) | `J/Config/AsyncConfig.java:25-30` |
| L4 | Cập nhật index ES hỏng **không được thử lại**; `@Scheduled` chỉ thử lại việc tạo index | `J/Service/Search/TransactionSearchIndexer.java:99-105,128-133` |
| L5 | DONUT V5 không trả độ tin cậy → `averageConfidenceScore` null; thống kê độ tin cậy chỉ có số khi dữ liệu có trường này (dữ liệu demo có) | `J/Service/OcrMongoService.java:336-350`; `S/mongodb_demo.js:69` |
| L6 | Mỗi CSDL **một node**, không replication, không sharding (thiết kế replica set / Sentinel / cluster chỉ ở mức thiết kế) | `docker-compose.yml:64-185` |
| L7 | Redis không persistence: OTP đang chờ mất khi Redis khởi động lại (người dùng gửi lại mã); cache/leaderboard dựng lại từ PG | `docker-compose.yml:76-77`; `S/redis_demo.txt:126-128` |
| L8 | Realtime chỉ cho **web admin**; mobile không có push (FCM là hướng phát triển); Pub/Sub at-most-once | [Q2]; `S/redis_demo.txt:136` |
| L9 | `ocr_logs` chỉ lưu lần đọc đầu tiên của mỗi giao dịch (unique `transactionId`); các lần đọc lại (retry) chỉ ở PG | `J/Service/ReceiptProcessingService.java:157-174`; `S/mongodb_init.js:119` |
| L10 | Không có trang web cho thao tác tạo/sửa tay document Mongo (ocr_feedbacks sinh tự động từ chỗ sửa của người dùng; admin chỉ đọc, lọc, đánh dấu đã xử lý, xóa) | `J/Controller/AdminNoSqlPageController.java:109-197` |
| L11 | Sao lưu từ web chỉ có PostgreSQL và MongoDB; Redis (cố ý, không cần) và Elasticsearch (snapshot qua script/Kibana hoặc reindex) không có nút trên web | `R/templates/admin/backup.html:136-240`; `S/backup_restore.md:110-188` |
| L12 | Thống kê ES theo danh mục/tháng (Q-38..Q-40) và `$facet`/`$lookup` đối chiếu (Q-13, Q-14) chỉ có trong script, chưa có API | AP-36, AP-37 |
| L13 | Không có API/trang tra log OCR theo giao dịch (AP-38 chỉ trong script). 4 phương thức repository Mongo khai báo nhưng không dùng (`findByTransactionIdOrderByCreatedAtDesc`, `findByAverageConfidenceScoreLessThan`, `findByIsResolvedFalse`, `countErrorsByField`) | §1.3 |
| L14 | Index đơn `receiptId` của `ocr_feedbacks` là dư (tiền tố của `receipt_field_uq`) | `S/mongodb_init.js:129-131` |
| L15 | Chế độ chạy trên server thật chưa biết (chưa triển khai); hiệu năng mức ứng dụng chỉ có nếu người dùng chạy JMeter | §1.0 |
| L16 | `FallbackCacheErrorHandler` chỉ là fallback (không ngắt mạch): trong lúc Redis treo mỗi request vẫn trả tối đa timeout lệnh; khi mất kết nối thì `REJECT_COMMANDS` cho lỗi ngay | `J/Config/FallbackCacheErrorHandler.java:9-17`; `J/Config/CacheConfig.java:117-122` |

---

## §4. Các lớp kiểm thử được trích (chạy thật)

Chạy ngày **27/10/2026** tại `1cae4de` (cây làm việc sạch), theo runbook backend: `mvn` hệ thống 3.9.12, Java 21.0.12,
offline với bản sao `~/.m2` ở scratchpad, `TESTCONTAINERS_RYUK_DISABLED=true`:
`cd core-backend && mvn -B -o -Dmaven.repo.local=<m2> clean test -Dtest='<38 lớp>' -Dsurefire.failIfNoSpecifiedTests=false`
(23:01:46 → 23:04:15, BUILD SUCCESS), rồi lượt 2 cho `ReceiptConcurrencyH2Test,ReceiptConcurrencyPostgresTest`
(23:07:03 → 23:07:28, BUILD SUCCESS). Số đếm đọc từ `core-backend/target/surefire-reports/TEST-*.xml` (cộng các lớp lồng
`$…` vào lớp ngoài), **không** đếm `@Test`. Các test dùng Docker (Testcontainers: Redis, MongoDB, Elasticsearch, PostgreSQL)
đều **chạy được** trong môi trường này. Người dùng cũng đã tự chạy xanh ngày 27/10/2026 (không có số đếm từ lần đó).

| Lớp | Tests | Lỗi | CSDL thật trong test |
|---|---|---|---|
| AdminDashboardPageTest | 3 | 0 | – (MockMvc) |
| AdminEventPublisherTest | 6 | 0 | – |
| AdminEventRelayIntegrationTest | 3 | 0 | Redis (Testcontainers) |
| AdminEventRelayTest | 15 | 0 | – |
| AdminEventsControllerTest | 8 | 0 | – |
| AdminLeaderboardControllerTest | 10 | 0 | – |
| AdminMongoBackupControllerTest | 6 | 0 | – |
| AdminNoSqlPageControllerTest | 29 | 0 | – |
| AdminNoSqlSearchReindexTest | 8 | 0 | – |
| AdminOcrFeedbackControllerTest | 9 | 0 | – |
| AdminSearchControllerTest | 7 | 0 | – |
| AdminStatisticsServiceTest | 6 | 0 | – |
| CacheConfigTest | 32 | 0 | – |
| ElasticsearchTransactionSearchEngineIntegrationTest | 9 | 0 | Elasticsearch (Testcontainers) |
| MongoBackupServiceIntegrationTest | 1 | 0 | MongoDB (Testcontainers) |
| MongoBackupServiceTest | 22 | 0 | – |
| MongoDataSeederTest | 4 | 0 | – |
| OcrCorrectionDetectorTest | 7 | 0 | – |
| OcrMongoServiceMongoIntegrationTest | 15 | 0 | MongoDB (Testcontainers) |
| OcrMongoServiceTest | 20 | 0 | – |
| ReceiptProcessingServiceTest | 125 | 0 | – |
| RedisOutageTest | 3 | 0 | Redis (Testcontainers, dừng/treo) |
| RedisPasswordResetOtpStoreIntegrationTest | 9 | 0 | Redis (Testcontainers) |
| RedisStatisticsCacheIntegrationTest | 15 | 0 | Redis (Testcontainers) |
| SearchConfigTest | 4 | 0 | – |
| SpendingLeaderboardServiceIntegrationTest | 16 | 0 | Redis (Testcontainers) + H2 |
| SpendingLeaderboardServiceTest | 4 | 0 | – |
| StatisticsCacheEvictorTest | 8 | 0 | – |
| StatisticsCacheTransactionTest | 9 | 0 | Redis (Testcontainers) + H2 |
| StatisticsChangeTest | 30 | 0 | – |
| TransactionRepositoryTest | 19 | 0 | H2 |
| TransactionSearchControllerTest | 7 | 0 | – |
| TransactionSearchIndexerIntegrationTest | 12 | 0 | Elasticsearch (Testcontainers) + H2 |
| TransactionSearchIndexerReindexLockTest | 2 | 0 | – |
| TransactionSearchRepositoryTest | 5 | 0 | H2 |
| TransactionSearchServiceTest | 6 | 0 | – |
| TransactionServiceTest | 192 | 0 | – |
| UserStatisticsServiceTest | 2 | 0 | – |
| **Lượt 1: 38 lớp** | **688** | **0** | |
| ReceiptConcurrencyH2Test | 7 | 0 | H2 |
| ReceiptConcurrencyPostgresTest | 7 | 0 | PostgreSQL 15 (Testcontainers) |
| **Lượt 2: 2 lớp** | **14** | **0** | |

Cột "CSDL thật trong test" suy từ tên lớp và các lớp hỗ trợ `RedisTestContainers`, `ElasticsearchTestContainers`
(`T/Config/RedisTestContainers.java`, `T/Service/Search/ElasticsearchTestContainers.java`); Task 9 kiểm lại từng lớp
trước khi đưa vào bảng 7.1 nếu cần chính xác hơn.

Không chạy trong lượt này: widget test mobile `mobile-app/test/screens/ledger/ledger_search_test.dart` (Flutter).

---

## §5. Bảng thuật ngữ (Task 9b bổ sung)

| Dùng | Không dùng |
|---|---|
| CSDL | "cơ sở dữ liệu" viết tắt lẫn lộn, "database" trong câu tiếng Việt |
| chỉ mục (index) – lần đầu ghi kèm tiếng Anh | trộn "index"/"chỉ mục" trong cùng đoạn |
| bản sao phân tích (MongoDB) | "CQRS read model" (chỉ dùng như phép so sánh) |
| cơ chế dự phòng (fallback) | "Circuit Breaker" |
| sau commit, bất đồng bộ, nhất quán cuối cùng | "đồng bộ thời gian thực" cho ghi NoSQL |
| chỉ mục: nói chung và chỉ mục tìm kiếm của Elasticsearch (lần đầu ghi "chỉ mục (index)") | "index" làm danh từ chung trong lời văn |
| index, database, collection, shard, mapping: giữ tiếng Anh khi gọi tên một đối tượng của sản phẩm (index transactions, database finance_nosql, 13 index của MongoDB) hoặc theo nhãn của GUI tool | dịch các tên đối tượng này |
| ThS. (học vị của GVHD) | "Ths." |
