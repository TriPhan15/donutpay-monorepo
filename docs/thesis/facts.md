# Bảng dữ kiện hệ thống (System Facts) – LedgerMind / DonutPay

> Nguồn số liệu DUY NHẤT cho các chương khóa luận. Mỗi dòng có bằng chứng: đường dẫn file (kèm dòng) hoặc lệnh shell đã chạy và kết quả.
> Ngày lập: **2026-10-21**. Mọi lệnh chạy tại thư mục gốc `/home/triphan/Workspace/Deploy_Project` (viết tắt `$ROOT`), chỉ đọc.

## 0. Trạng thái mã nguồn khi lập bảng

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Git HEAD | `a7ff9b3` | `git rev-parse --short HEAD` |
| Working tree có thay đổi chưa commit | **34** dòng trạng thái (sửa + chưa theo dõi) | `git status --short \| wc -l` → 34 |
| Lưu ý | Một số số liệu dưới đây đo trên working tree (gồm phần MongoDB chưa commit: `Document/`, `Repository/Mongo/`, `OcrMongoController`, `OcrMongoService`, `AsyncConfig`, `MongoDataSeeder`; và `ai-service/Version5/`, `data1/`, notebook). Số liệu nào chỉ đúng với working tree được ghi rõ. | `git status --short` |

---

## 1. Công nghệ và phiên bản

### 1.1 Core Backend (`core-backend/pom.xml`)

| Thành phần | Phiên bản | Bằng chứng |
|---|---|---|
| Java | 21 | `core-backend/pom.xml:16` `<java.version>21` |
| Spring Boot (parent `spring-boot-starter-parent`) | 3.2.5 | `core-backend/pom.xml:6-8` |
| groupId / artifactId / version | `vn.edu.huit.finance` / `core-backend` / `0.0.1-SNAPSHOT` | `core-backend/pom.xml:11-13` |
| JJWT (`jjwt-api`, `jjwt-impl`, `jjwt-jackson`) | 0.11.5 | `core-backend/pom.xml:48-61` |
| springdoc-openapi-starter-webmvc-ui | 2.5.0 | `core-backend/pom.xml:31-33` |
| Cloudinary (`cloudinary-http44`) | 1.36.0 | `core-backend/pom.xml:37-39` |
| Testcontainers (`junit-jupiter`, test) | 1.21.4 (ghi đè property) | `core-backend/pom.xml:18` `<testcontainers.version>1.21.4` |
| PostgreSQL JDBC driver (runtime) | do Boot 3.2.5 quản lý (không ghi version) | `core-backend/pom.xml:103-106` |
| Hibernate Envers | do Boot quản lý | `core-backend/pom.xml:23-24` |
| Starter khác (version do Boot quản lý) | thymeleaf, security, data-jpa, cache, data-redis, validation, mail, web, webflux, devtools, actuator, data-mongodb; lombok; test: spring-boot-starter-test, h2 | `grep -nE '<artifactId>' core-backend/pom.xml` |
| `spring-boot-starter-data-mongodb` | **chỉ có trong working tree** (thay một dòng actuator trùng lặp ở HEAD) | `git diff HEAD --ignore-cr-at-eol -- core-backend/pom.xml` |
| Tên file JAR | `finance-api.jar` | `core-backend/Dockerfile` (`COPY ... /app/target/finance-api.jar`) |

### 1.2 Mobile App (`mobile-app/pubspec.yaml`)

| Thành phần | Phiên bản | Bằng chứng |
|---|---|---|
| Phiên bản app | 1.0.0+1 | `mobile-app/pubspec.yaml:4` |
| Dart SDK | `^3.10.8` | `pubspec.yaml` mục `environment` |
| State/DI | provider ^6.1.2, flutter_bloc ^8.1.5, get_it ^7.7.0, equatable ^2.0.5 | `pubspec.yaml` mục `dependencies` |
| HTTP | dio ^5.7.0 | như trên |
| Lưu trữ cục bộ | sqflite ^2.3.3+1, sqflite_common_ffi ^2.3.3, shared_preferences ^2.2.3, path_provider ^2.1.3 | như trên |
| Biểu đồ / UI | fl_chart ^0.68.0, google_fonts ^6.2.1, shimmer ^3.0.0, qr_flutter ^4.1.0 | như trên |
| Hóa đơn / camera | google_mlkit_document_scanner 0.4.1, mobile_scanner ^5.2.3, image_picker ^1.2.1, permission_handler ^11.3.1 | như trên |
| Đăng nhập MXH | google_sign_in ^6.2.1, flutter_facebook_auth ^7.1.1 | như trên |
| Khác | intl ^0.20.2, excel ^4.0.6, url_launcher ^6.3.0, share_plus ^13.1.0, uuid ^4.5.3, path ^1.9.0, flutter_localizations (sdk) | như trên |
| Dev | flutter_lints ^6.0.0, flutter_launcher_icons ^0.13.1 | như trên |

### 1.3 AI Service (`ai-service/requirements.txt`, `ai-service/Dockerfile`)

| Thành phần | Phiên bản | Bằng chứng |
|---|---|---|
| Python (image) | 3.10 (`python:3.10-slim`) | `ai-service/Dockerfile:1` |
| Python trên CI | 3.10 | `.github/workflows/ci.yml` job `ai-ci`, `python-version: '3.10'` |
| Thư viện | torch, torchvision (CPU wheel qua `--extra-index-url https://download.pytorch.org/whl/cpu`), fastapi, uvicorn[standard], python-multipart, pillow, transformers, sentencepiece, scikit-learn; test: pytest, pytest-mock, httpx | `ai-service/requirements.txt` |
| Ghim phiên bản | **Không** (mọi gói không ghi version) | `ai-service/requirements.txt` |
| scikit-learn | khai báo nhưng **không được import** trong file .py nào của service | `grep -rln sklearn --include=*.py ai-service` (bỏ venv) → rỗng |

### 1.4 Image Docker

| Image | Dùng cho | Bằng chứng |
|---|---|---|
| `postgres:15-alpine` | service `db` | `docker-compose.yml` |
| `redis:8.10-alpine` | service `redis` | `docker-compose.yml` |
| `mongo:6.0` | service `mongodb` (**chỉ working tree**) | `docker-compose.yml` (working tree) |
| `maven:3.9.6-eclipse-temurin-21` (build) → `eclipse-temurin:21-jre-jammy` (run), có `tini`, `curl`, user `spring`, TZ `Asia/Ho_Chi_Minh` | core-api (multi-stage) | `core-backend/Dockerfile` |
| `python:3.10-slim` + libgl1, libglib2.0-0; CMD `uvicorn ai_service:app --host 0.0.0.0 --port 8000` | data-mining-api | `ai-service/Dockerfile` |

---

## 2. Kiến trúc container, CI/CD

### 2.1 Docker Compose – bản đã commit (HEAD `a7ff9b3`)

Đo bằng: `git show HEAD:docker-compose.yml` rồi parse bằng `python3 -c "import yaml ..."`.

| Service | Image / build | container_name | Ports | depends_on | Volume | Network |
|---|---|---|---|---|---|---|
| `db` | `postgres:15-alpine` | finance-postgres | `127.0.0.1:5432:5432` (chỉ loopback) | – | `postgres_data:/var/lib/postgresql/data` | finance-network |
| `redis` | `redis:8.10-alpine` (requirepass, `allkeys-lru`, không persistence, tắt KEYS/FLUSHALL/FLUSHDB) | finance-redis | không publish | – | – | finance-network |
| `core-api` | build `./core-backend` | finance-core-api | `8080:8080` | db, redis, data-mining-api (đều `service_healthy`) | – | finance-network |
| `data-mining-api` | build `./ai-service` | finance-data-mining | `8000:8000` | – | – | finance-network |

- Network: `finance-network` (driver `bridge`). Volume: `postgres_data`.
- Giới hạn bộ nhớ: core-api 512M, data-mining-api 1G, redis `${REDIS_MEMORY_LIMIT:-192M}` (maxmemory mặc định 128mb).
- Healthcheck: db `pg_isready`, redis `redis-cli ping`, core-api `curl /actuator/health`, data-mining-api `GET /health`.

### 2.2 Docker Compose – working tree (chưa commit)

> **Cập nhật 21/10/2026 (phiên T7.1):** commit `68c407b` đã đưa MongoDB vào HEAD; `docker-compose.yml` hiện parse được, có 5 service `db`, `redis`, `mongodb` (`mongo:6.0`), `core-api`, `data-mining-api`; `core-api` chờ db/redis/data-mining-api `service_healthy`, chờ mongodb `service_started` với `required: false` (`python3 -c "import yaml; ..."`). Bảng dưới là trạng thái cũ, giữ để đối chiếu; các mục "chỉ working tree" về MongoDB ở §1.1, §1.4, §3 cần rà lại ở T7.3a.

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Thêm service `mongodb` | `mongo:6.0`, container `finance-mongodb`, port `27017:27017`, volume `mongodb_data:/data/db`, DB `finance_nosql` | `docker-compose.yml` (working tree) |
| core-api thêm env | `MONGO_URI=mongodb://...@mongodb:27017/finance_nosql?authSource=admin` | như trên |
| **File hiện KHÔNG parse được** | `yaml.scanner.ScannerError: mapping values are not allowed here, line 181, column 31` (khối `mongodb_data:` lọt vào service `db`, service `data-mining-api` bị tách đôi, dòng volumes `postgres_data:  mongodb_data:`) | `python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))"` |
| Quy mô thay đổi so với HEAD | 26 dòng thêm, 3 dòng xóa (bỏ qua CRLF) | `git diff HEAD --ignore-cr-at-eol --stat -- docker-compose.yml` |

### 2.3 Dockerfile

| File | Bằng chứng |
|---|---|
| `core-backend/Dockerfile`, `ai-service/Dockerfile` (2 file; mobile không có) | `find . -name 'Dockerfile*' -not -path '*/.git/*'` |

### 2.4 CI/CD (`.github/workflows/ci.yml`, 1 workflow "Microservices CI")

| Job | Nội dung | Bằng chứng |
|---|---|---|
| `backend-ci` | ubuntu-latest, Temurin Java 21, cache maven; `mvn -B clean test -Dtest=!CoreBackendApplicationTests` | `ci.yml:14-30` |
| `mobile-ci` | cài clang/cmake/ninja/gtk; `subosito/flutter-action@v2` channel stable; `flutter pub get && flutter analyze && flutter test` | `ci.yml:32-49` |
| `ai-ci` | Python 3.10, timeout 15 phút; `pip install -r requirements.txt && pytest test_main.py -v` | `ci.yml:51-66` |
| `deploy` "Deploy to AWS VPS" | `needs: [backend-ci, mobile-ci, ai-ci]`, chỉ khi push lên `main`; `appleboy/ssh-action@v1.0.3` vào EC2 (secrets `AWS_HOST`, `AWS_USERNAME`, `AWS_SSH_KEY`), `git reset --hard origin/main`, `docker compose build`, `docker compose up -d --wait --remove-orphans` | `ci.yml:67-100` |
| Trigger | `push`, `pull_request`; có `concurrency` | `ci.yml:3-12` |

---

## 3. Core Backend – số liệu

Thư mục gốc: `core-backend/src/main/java/vn/edu/huit/finance/core` (viết tắt `$M`).

### 3.1 Quy mô mã nguồn

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| File .java trong `src/main/java` | 196 | `find core-backend/src/main/java -name '*.java' \| wc -l` |
| Số dòng mã (main, thô) | 11.861 | `find core-backend/src/main/java -name '*.java' \| xargs cat \| wc -l` |
| File theo package | Config 9, Controller 19, Document 2, Dto 47, Entity 27 (gồm enum), Exception 18, Repository 16 (14 JPA + 2 trong `Repository/Mongo`), Security 15, Service 41 (gồm subpackage Audit, Cache, Payment, Storage), Util 1 | `for d in */; do find $d -name '*.java' \| wc -l; done` trong `$M` |
| Lớp `@Service` | 26 | `grep -rl '^@Service' $M \| wc -l` |
| Lớp `@Service`/`@Component` trong package Service | 31 | `grep -rlE '^@(Component\|Service)' $M/Service \| wc -l` |
| Repository interface | 16 = 14 `JpaRepository` + 2 `MongoRepository` (Mongo: chỉ working tree) | `grep -rlE 'extends (JpaRepository\|MongoRepository)' $M` |
| Ghi chú repository | `CampaignRepository` và `SubscriptionPlanRepository` cùng quản lý entity `SubscriptionPlan` | `Repository/CampaignRepository.java:5` |
| DTO | 47 file trong `Dto/` | `find $M/Dto -name '*.java' \| wc -l` |

### 3.2 Controller

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| `@RestController` | **16** lớp | `grep -rlE '^@RestController' $M \| wc -l` |
| `@Controller` (Thymeleaf/MVC) | **2** lớp: `AdminController` (`/admin`), `ViewController` | `grep -rlE '^@Controller\b' $M` |
| File phụ không phải controller | `Controller/ApiResponses.java` | `ls $M/Controller` |
| Annotation mapping cấp phương thức | **81** = Get 32, Post 27, Put 13, Delete 7, Patch 2 | `grep -hE '^\s+@(Get\|Post\|Put\|Patch\|Delete\|Request)Mapping\b' $M/Controller/*.java \| wc -l` |
| Endpoint REST API | **51** (trên 16 lớp `@RestController`) | bảng 3.3 |
| Endpoint trang/AJAX Web Admin (MVC) | **30** (AdminController 29 + ViewController 1); trong AdminController có 17 `@ResponseBody` (AJAX JSON) | bảng 3.4; `grep -c '@ResponseBody' AdminController.java` → 17 |

Cách dựng bảng: script đọc `@RequestMapping` cấp lớp + annotation cấp phương thức (tự giải hằng `AuthPaths.BASE = "/api/auth"`, `CHANGE_PASSWORD`, `LOGOUT` từ `Security/AuthPaths.java:8-10`).

### 3.3 Bảng endpoint REST API (51)

| # | Method | Path | Controller (file:dòng) |
|---|---|---|---|
| 1 | POST | `/api/auth/register` | AuthController:68 |
| 2 | POST | `/api/auth/login` | AuthController:94 |
| 3 | POST | `/api/auth/social-login` | AuthController:171 |
| 4 | POST | `/api/auth/forgot-password` | AuthController:215 |
| 5 | POST | `/api/auth/reset-password` | AuthController:227 |
| 6 | PUT | `/api/auth/change-password` | AuthController:239 |
| 7 | POST | `/api/auth/logout` | AuthController:248 |
| 8 | POST | `/api/auth/refresh` | AuthController:265 |
| 9 | GET | `/api/users/me` | UserController:56 |
| 10 | PUT | `/api/users/{id}` | UserController:67 |
| 11 | GET | `/api/transactions/mine` | TransactionController:41 |
| 12 | POST | `/api/transactions/checkout` | TransactionController:46 |
| 13 | PUT | `/api/transactions/{id}` | TransactionController:52 |
| 14 | DELETE | `/api/transactions/{id}` | TransactionController:58 |
| 15 | GET | `/api/transactions/filter` | TransactionController:64 |
| 16 | PUT | `/api/transactions/cancel/{receiptId}` | TransactionController:83 |
| 17 | GET | `/api/transactions/popular-vendors` | TransactionController:89 |
| 18 | GET | `/api/transactions/app-dashboard` | TransactionController:94 |
| 19 | GET | `/api/receipts/{id}` | ReceiptController:33 |
| 20 | GET | `/api/receipts/transaction/{transactionId}` | ReceiptController:39 |
| 21 | PUT | `/api/receipts/{id}` | ReceiptController:45 |
| 22 | POST | `/api/receipts/{id}/retry` | ReceiptController:55 |
| 23 | POST | `/api/receipts/feedback/{receiptId}` | ReceiptController:61 |
| 24 | GET | `/api/budgets` | BudgetController:29 |
| 25 | GET | `/api/budgets/{id}` | BudgetController:34 |
| 26 | POST | `/api/budgets` | BudgetController:39 |
| 27 | PUT | `/api/budgets/{id}` | BudgetController:44 |
| 28 | DELETE | `/api/budgets/{id}` | BudgetController:50 |
| 29 | GET | `/api/savings` | SavingGoalController:26 |
| 30 | POST | `/api/savings` | SavingGoalController:32 |
| 31 | PUT | `/api/savings/{id}` | SavingGoalController:38 |
| 32 | DELETE | `/api/savings/{id}` | SavingGoalController:44 |
| 33 | GET | `/api/notifications` | NotificationController:33 |
| 34 | GET | `/api/notifications/unread-count` | NotificationController:40 |
| 35 | PATCH | `/api/notifications/read-all` | NotificationController:46 |
| 36 | PATCH | `/api/notifications/{id}/read` | NotificationController:51 |
| 37 | POST | `/api/payment/create` | PaymentController:33 |
| 38 | POST | `/api/payment/webhook` | PaymentController:41 |
| 39 | GET | `/api/payment/status/{orderCode}` | PaymentController:48 |
| 40 | GET | `/api/payment/mine` | PaymentController:55 |
| 41 | PUT | `/api/payment/cancel/{orderCode}` | PaymentController:62 |
| 42 | GET | `/api/categories` | CategoryApiController:22 |
| 43 | POST | `/api/upload` | FileUploadController:19 |
| 44 | POST | `/api/reviews` | AppReviewMobileController:25 |
| 45 | GET | `/api/admin/audit-logs` | AdminAuditLogController:33 |
| 46 | GET | `/api/admin/receipts/{id}/attempts` | AdminReceiptController:33 |
| 47 | GET | `/api/admin/transactions/popular-vendors` | AdminTransactionController:35 |
| 48 | GET | `/api/admin/transactions/app-dashboard` | AdminTransactionController:40 |
| 49 | GET | `/api/admin/ocr-logs` | OcrMongoController:21 (**chỉ working tree**) |
| 50 | GET | `/mock-gateway/pay` | MockGatewayController:33 (cổng thanh toán giả lập) |
| 51 | GET | `/mock-gateway/confirm` | MockGatewayController:60 (cổng thanh toán giả lập) |

=> Ở HEAD (không tính OcrMongoController): 15 `@RestController`, 50 endpoint REST.

### 3.4 Bảng endpoint Web Admin (Thymeleaf/MVC, 30)

| # | Method | Path | Loại | Controller:dòng |
|---|---|---|---|---|
| 1 | GET | `/login` | redirect `/admin/login` | ViewController:9 |
| 2 | GET | `/admin/dashboard` | trang `admin/dashboard` | AdminController:92 |
| 3 | GET | `/admin/login` | trang `admin/login` | AdminController:137 |
| 4 | GET | `/admin/categories` | trang | AdminController:143 |
| 5 | GET | `/admin/receipts` | trang | AdminController:150 |
| 6 | GET | `/admin/users` | trang | AdminController:163 |
| 7 | POST | `/admin/receipts/approve/{id}` | form → redirect | AdminController:177 |
| 8 | POST | `/admin/receipts/reject/{id}` | form → redirect | AdminController:184 |
| 9 | GET | `/admin/subscriptions` | trang | AdminController:194 |
| 10 | POST | `/admin/subscriptions/add` | form → redirect | AdminController:200 |
| 11 | POST | `/admin/ajax/users` | AJAX | AdminController:219 |
| 12 | PUT | `/admin/ajax/users/{id}` | AJAX | AdminController:240 |
| 13 | DELETE | `/admin/ajax/users/{id}` | AJAX | AdminController:263 |
| 14 | PUT | `/admin/ajax/users/{id}/toggle-status` | AJAX | AdminController:283 |
| 15 | GET | `/admin/backup` | trang | AdminController:303 |
| 16 | POST | `/admin/backup/execute` | hành động | AdminController:309 |
| 17 | POST | `/admin/backup/restore` | hành động | AdminController:327 |
| 18 | POST | `/admin/ajax/subscriptions` | AJAX | AdminController:344 |
| 19 | PUT | `/admin/ajax/subscriptions/{id}` | AJAX | AdminController:352 |
| 20 | PUT | `/admin/ajax/subscriptions/{id}/toggle` | AJAX | AdminController:360 |
| 21 | DELETE | `/admin/ajax/subscriptions/{id}` | AJAX | AdminController:368 |
| 22 | GET | `/admin/auditlog` | trang | AdminController:381 |
| 23 | POST | `/admin/ajax/categories` | AJAX | AdminController:440 |
| 24 | PUT | `/admin/ajax/categories/{id}` | AJAX | AdminController:448 |
| 25 | DELETE | `/admin/ajax/categories/{id}` | AJAX | AdminController:456 |
| 26 | POST | `/admin/ajax/security/unlock` | AJAX | AdminController:463 |
| 27 | GET | `/admin/reviews` | trang | AdminController:488 |
| 28 | POST | `/admin/ajax/reviews/{id}/approve` | AJAX | AdminController:495 |
| 29 | DELETE | `/admin/ajax/reviews/{id}` | AJAX | AdminController:511 |
| 30 | POST | `/admin/ajax/segmentation/run` | AJAX (gọi AI `/admin/segment`) | AdminController:526 |

### 3.5 Thực thể dữ liệu

**JPA `@Entity`: 14 lớp** (`grep -l '^@Entity$' $M/Entity/*.java \| wc -l` → 14; `BaseEntity` là `@MappedSuperclass` + `@Audited`, không tính).

| Entity | Bảng (`@Table`) | `@Audited` (Envers) |
|---|---|---|
| User | `users` | có |
| Transaction | `transactions` | có |
| Receipt | `receipts` | có |
| ReceiptProcessingAttempt | `receipt_processing_attempts` | không |
| Budget | `budgets` | có |
| Category | `categories` | có |
| SavingGoal | `saving_goals` | có |
| Notification | `notifications` | có |
| PaymentOrder | `payment_orders` | có |
| SubscriptionPlan | `subscription_plans` | có |
| AppReview | `app_reviews` | không |
| ActionLog | `action_logs` | không |
| RevokedToken | `revoked_tokens` | không |
| CustomRevisionEntity | (không `@Table`; `@RevisionEntity`, kế thừa `DefaultRevisionEntity`) | – |

Bằng chứng: `grep -oE '@Table\(name *= *"[^"]+"' <file>`; `grep -c '@Audited' <file>` (9 entity có `@Audited`).

**MongoDB `@Document`: 2 lớp (chỉ working tree)**

| Document | Collection | Index | Bằng chứng |
|---|---|---|---|
| OcrRawLog | `ocr_logs` | compound `score_date_idx {averageConfidenceScore:1, createdAt:-1}`, 1 `@Indexed(unique=true)`, 2 `@Indexed` | `Document/OcrRawLog.java:13-29` |
| OcrFeedback | `ocr_feedbacks` | compound `status_date_idx {isResolved:1, reportedAt:-1}`, 4 `@Indexed` | `Document/OcrFeedback.java:13-34` |

### 3.6 Enum nghiệp vụ (`$M/Entity/`)

Đếm: 12 enum trong `Entity/` + `TokenType`, `TokenRejection` (Security) + `StatisticsChange` (Service/Cache) = 15 (`grep -rln '^public enum' $M`).

| Enum | Giá trị |
|---|---|
| ReceiptStatus | PENDING, PROCESSING, COMPLETED_RAW, EDITED, FAILED, WAITING_FOR_REVIEW, APPROVED, CANCELED (8) |
| ReceiptAttemptStatus | COMPLETED, FAILED, LEGACY |
| ReceiptErrorCode | AI_UNREADABLE, AI_NO_TOTAL, REJECTED_BY_ADMIN |
| PaymentStatus | PENDING, SUCCESS, FAILED, CANCELLED |
| PaymentType | DEPOSIT, WITHDRAW |
| BudgetPeriodType | WEEK, MONTH |
| NotificationType | BUDGET_WARNING, BUDGET_EXCEEDED, TRANSACTION_ALERT, RECEIPT_PROCESSED |
| TransactionSortField | TRANSACTION_DATE, AMOUNT |
| AuditCategory | SECURITY, DATA, SYSTEM |
| AuditResult | SUCCESS, FAILURE |
| AuditTargetType | USER, TRANSACTION, RECEIPT, BUDGET, CATEGORY, PAYMENT_ORDER, SAVING_GOAL, SUBSCRIPTION_PLAN, APP_REVIEW (9) |
| AuditAction | **54** hằng (AUTH_* 13, USER_* 5, TRANSACTION_* 3, RECEIPT_* 9, BUDGET_* 3, CATEGORY_* 3, PAYMENT_* 5, SAVING_* 3, PLAN_* 4, REVIEW_* 2, SYSTEM_* 4) |
| TokenType (Security) | ACCESS, REFRESH |

- Loại giao dịch **không** là enum: chiều giao dịch là boolean `isExpense` (CLAUDE.md, Local Conventions).
- Vai trò **không** là enum: `User.role` là `String`, mặc định `"ROLE_USER"` (`Entity/User.java:41`); hằng trong `Security/Roles.java:14-18`: `ROLE_USER`, `ROLE_ADMIN`, `ROLE_LOCKED`.

### 3.7 Ràng buộc dữ liệu

| Loại | Chi tiết | Bằng chứng |
|---|---|---|
| Bean Validation trên `Entity/` + `Dto/` | @NotBlank 17, @Size 12, @NotNull 11, @Positive 7, @Min 5, @Max 4, @StrongPassword 3, @Email 3, @Pattern 2, @Digits 2, @DecimalMin 2 | `grep -rnoE '@(NotNull\|NotBlank\|...\|StrongPassword)\b' Entity Dto \| awk -F: '{print $3}' \| sort \| uniq -c` |
| Số tiền giao dịch > 0 | `@Positive` | `Dto/TransactionRequestDto.java:20`, `Dto/TransactionUpdateRequestDto.java:27` |
| Ngân sách > 0 | `@DecimalMin(value="0", inclusive=false)` + `@Digits` | `Dto/BudgetRequestDto.java:27-28` |
| Nạp tiền tối thiểu | `@DecimalMin("1000")` | `Dto/CreatePaymentRequestDto.java:18` |
| Đánh giá app | 1–5 sao (`@Min(1)`, `@Max(5)`) | `Dto/ReviewRequestDto.java:14-15` |
| Phân trang thông báo | size 1–50 | `Dto/NotificationPageRequestDto.java:21-25` |
| Phân trang audit log | page 0–10000, size 1–100 | `Dto/AuditLogFilterRequestDto.java:60-65` |
| Mật khẩu mạnh `@StrongPassword` | 8–72 ký tự, có ít nhất 1 chữ và 1 số | `Security/StrongPassword.java:25-37` |
| UNIQUE cột | `users.username`, `users.email`, `users.phone`; `payment_orders.order_code` (len 64); `revoked_tokens.token_hash` | `Entity/User.java:23,34,37`; `Entity/PaymentOrder.java:23`; `Entity/RevokedToken.java:35` |
| UNIQUE tổ hợp | `uk_transactions_user_client_id (user_id, client_id)` (idempotent checkout) | `Entity/Transaction.java:13-15` |
| | `uk_budgets_user_category_period (user_id, category_key, period_type, start_date)` | `Entity/Budget.java:15-17` |
| | `uk_receipt_attempts_receipt_number (receipt_id, attempt_number)`, `uk_receipt_attempts_receipt_client_id (receipt_id, client_id)` | `Entity/ReceiptProcessingAttempt.java:36-37` |
| File migration SQL | 2 file, đều đã được git theo dõi: `db/receipt-workflow-migration.sql` (482 dòng), `db/action-log-audit-migration.sql` (154 dòng) | `ls core-backend/src/main/resources/db`; `wc -l`; `git ls-files core-backend/src/main/resources/db` |
| CHECK constraint trong SQL | **0** (không có `CHECK (`); script tạo UNIQUE/FK có điều kiện và tự kiểm tra (PART D/PART C) | `grep -ci 'check *(' db/*.sql` → 0, 0 |
| Quản lý schema | `ddl-auto: update`, không có Flyway/Liquibase | `core-backend/src/main/resources/application.yml` (file bị git-ignore) |

### 3.8 Bảo mật

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Thuật toán ký JWT | HS256 (`Keys.hmacShaKeyFor`) | `Security/JwtUtil.java:28,55` |
| Access token TTL | 900.000 ms = **15 phút** | `Security/JwtUtil.java:21` |
| Refresh token TTL | 2.592.000.000 ms = **30 ngày** | `Security/JwtUtil.java:22` |
| Claim bổ sung | `credentialsVersion` (thu hồi token khi đổi mật khẩu); loại token ACCESS/REFRESH ở JOSE header `typ` | `Security/JwtUtil.java:25,46`; `Security/TokenType.java` |
| Secret JWT | **hardcode trong mã nguồn** (không đọc từ env) | `Security/JwtUtil.java:20` |
| Mã hóa mật khẩu | BCrypt | `Config/SecurityConfig.java:63-66` |
| Thu hồi token | bảng `revoked_tokens` (lưu `token_hash`), `TokenBlacklistService` | `Entity/RevokedToken.java`, `Service/TokenBlacklistService.java` |
| Filter chain 1 (`@Order(1)`) | `/admin/**`, `/login`, `/error`, tài nguyên tĩnh; `/admin/**` cần `ROLE_ADMIN` | `Config/SecurityConfig.java:69-76` |
| Filter chain 2 (`@Order(2)`) | `/api/**`, STATELESS, CSRF tắt, CORS `*`; `JwtAuthFilter` trước `UsernamePasswordAuthenticationFilter` | `Config/SecurityConfig.java:127-160` |
| Đường dẫn công khai API | `/api/auth/**` (trừ `/api/auth/change-password`, `/api/auth/logout`), `/api/payment/webhook`, `/api/categories` | `Config/SecurityConfig.java:143-146`; `Security/AuthPaths.java:8-24` |
| API admin | `/api/admin/**` cần `ROLE_ADMIN` | `Config/SecurityConfig.java:147` |
| Lỗi xác thực | `JsonAuthenticationEntryPoint` (401/403 JSON), `AuditingAccessDeniedHandler` (ghi `AUTH_ACCESS_DENIED`) | `Config/SecurityConfig.java:151-154` |

### 3.9 Redis cache (thống kê)

| Cache name | TTL mặc định | Bằng chứng |
|---|---|---|
| `user-dashboard` | 45s | `Service/Cache/CacheNames.java:15`; `resources/redis-cache.properties` `CACHE_TTL_USER_DASHBOARD:45s` |
| `user-popular-vendors` | 60s | `CacheNames.java:16`; `CACHE_TTL_USER_POPULAR_VENDORS:60s` |
| `admin-dashboard-summary` | 45s | `CacheNames.java:17`; `CACHE_TTL_ADMIN_DASHBOARD_SUMMARY:45s` |
| `admin-top-spenders` | 60s | `CacheNames.java:18`; `CACHE_TTL_ADMIN_TOP_SPENDERS:60s` |
| `admin-statistics` | 60s | `CacheNames.java:19`; `CACHE_TTL_ADMIN_STATISTICS:60s` |

- TTL jitter: giảm ngẫu nhiên tối đa 10% (`CACHE_TTL_JITTER_PERCENT:10`; `Config/CacheConfig.java:181-186`).
- Key: tiền tố ứng dụng `ledgermind`, schema `v1` (`CacheConfig.java:72`, `CacheNames.java:13`).
- Timeout: connect 1s, command 500ms; Redis health tắt; repositories tắt (`redis-cache.properties`).
- Xóa hàng loạt bằng SCAN batch 500 (`CacheConfig.java:71`); lỗi Redis được bỏ qua để đọc thẳng PostgreSQL (`Config/FallbackCacheErrorHandler.java`).

### 3.10 Kiểm thử Backend (`core-backend/src/test/java`, chưa chạy lại khi lập bảng)

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| File .java trong test | 91 | `find core-backend/src/test/java -name '*.java' \| wc -l` |
| Lớp có ít nhất 1 `@Test`/`@ParameterizedTest` | 85 | `grep -rlE '@(Test\|ParameterizedTest)\b' ... \| wc -l` |
| Phương thức `@Test` | **927** | `grep -rhE '^\s*@Test\b' core-backend/src/test/java \| wc -l` |
| Phương thức `@ParameterizedTest` | **157** | `grep -rhE '^\s*@ParameterizedTest\b' ... \| wc -l` |
| `@Nested` | 4 | `grep -rh '@Nested' ... \| wc -l` |
| Lớp dùng Testcontainers | 8 | `grep -rl '@Testcontainers\|GenericContainer\|PostgreSQLContainer' ... \| wc -l` |
| Dòng mã test | 23.881 | `find ... -name '*.java' \| xargs cat \| wc -l` |
| Ghi chú | 157 test tham số hóa sinh nhiều lần chạy; số "test case" khi chạy Maven lớn hơn 927+157 và phải lấy từ báo cáo Surefire | – |

---

## 4. Mobile App (`mobile-app/lib`)

### 4.1 Quy mô

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| File .dart trong `lib/` | 82 (gồm 3 file l10n sinh tự động) | `find lib -name '*.dart' \| wc -l`; `find lib -name 'app_localizations*.dart' \| wc -l` → 3 |
| Số dòng (lib, thô) | 18.267 | `find lib -name '*.dart' \| xargs cat \| wc -l` |
| File trong `lib/screens` | 26 | `find lib/screens -name '*.dart' \| wc -l` |

### 4.2 Màn hình

Heuristic: một file là "màn hình" nếu định nghĩa lớp public tên kết thúc bằng `Screen` hoặc `Page` và `extends StatefulWidget|StatelessWidget`.
Lệnh: `grep -rlE 'class \w+(Screen|Page)\s+extends\s+(StatefulWidget|StatelessWidget)' lib` → 23 file, trừ `lib/main.dart` (`_StartupLoadingScreen`, private, màn hình chờ khởi động) → **22 màn hình**. Ngoài ra `lib/screens/main_scaffold.dart` (`MainScaffold`, khung điều hướng tab) không tính.

| # | Lớp | File |
|---|---|---|
| 1 | LoginScreen | `lib/screens/auth/login_page.dart` |
| 2 | RegisterScreen | `lib/screens/auth/register_page.dart` |
| 3 | ForgotPasswordScreen | `lib/screens/auth/forgot_password_page.dart` |
| 4 | ResetPasswordScreen | `lib/screens/auth/reset_password_page.dart` |
| 5 | DashboardPage | `lib/screens/dashboard/dashboard_page.dart` |
| 6 | LedgerPage | `lib/screens/ledger/ledger_page.dart` |
| 7 | AddTransactionPage | `lib/screens/ledger/add_transaction_page.dart` |
| 8 | EditTransactionPage | `lib/screens/ledger/edit_transaction_page.dart` |
| 9 | BudgetScreen | `lib/screens/budget/budget_screen.dart` |
| 10 | AITabPage | `lib/screens/ai/ai_tab_page.dart` |
| 11 | NotificationScreen | `lib/screens/notifications/notification_screen.dart` |
| 12 | PaymentHistoryScreen | `lib/screens/payment/payment_history_screen.dart` |
| 13 | LinkedServicesPage | `lib/screens/linked/linked_services_page.dart` |
| 14 | ReviewFormPage | `lib/screens/receipt_scanner/review_form_page.dart` |
| 15 | ProfilePage | `lib/screens/profile/profile_page.dart` |
| 16 | SettingsScreen | `lib/screens/profile/settings_screen.dart` |
| 17 | SavingsPage | `lib/screens/profile/savings_page.dart` |
| 18 | AccountInfoScreen | `lib/screens/profile/account_info_screen.dart` |
| 19 | AccountCredentialsScreen | `lib/screens/profile/account_credentials_screen.dart` |
| 20 | UserInfoScreen | `lib/screens/profile/user_info_screen.dart` |
| 21 | SetUserInfoScreen | `lib/screens/profile/set_user_info.dart` |
| 22 | UserInfoScreen (bản thứ hai, khác nội dung từ dòng 62) | `lib/screens/receipt_scanner/user_info_screen.dart` — không được file nào trong `lib/` import, chỉ `test/screens/receipt_scanner/receipt_theme_test.dart` dùng |

=> Nếu chỉ tính màn hình thực sự dùng trong app: **21**. File screens không phải màn hình: `password_recovery_errors.dart`, `budget_form_sheet.dart` (bottom sheet), `main_scaffold.dart`, `notification_destination.dart`.

### 4.3 Đa ngôn ngữ, state management, truy cập dữ liệu

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| File ARB | `lib/l10n/app_en.arb` (template), `lib/l10n/app_vi.arb`; locale ưu tiên `vi` | `ls lib/l10n`; `mobile-app/l10n.yaml` |
| Số key | **70** key mỗi file (en có thêm 70 mục `@metadata`) | `python3 -c "json.load(...)"` đếm key không bắt đầu bằng `@` |
| Cubit (flutter_bloc) | 2: `ThemeCubit`, `LanguageCubit` | `grep -rlE 'extends Cubit<\|extends Bloc<' lib` → `lib/cubits/theme_cubit.dart`, `lib/cubits/language_cubit.dart` |
| Dòng dùng BlocProvider/BlocBuilder/MultiBlocProvider | 3 | `grep -rn 'BlocProvider\|BlocBuilder\|MultiBlocProvider' lib \| wc -l` |
| GetIt | 5 dòng tham chiếu (`lib/di/injection_container.dart`) | `grep -rn 'GetIt\|sl<\|sl(' lib \| wc -l` |
| package `provider` / ChangeNotifier | 0 / 0 (khai báo nhưng không dùng; `lib/providers/` rỗng) | `grep -rln 'package:provider' lib \| wc -l`; `ls lib/providers` |
| Mô hình chính | `StatefulWidget` + `setState`; Cubit chỉ cho theme/ngôn ngữ | như trên |
| `RemoteApiHelper` | 775 dòng; **39** phương thức public trả `Future` (+5 private) | `grep -cE '^\s+Future<[^(]*>\s+[a-z]\w*\(' lib/services/remote_api_helper.dart` |
| Base URL mặc định | backend `https://api.ledgermind.dev`, AI `https://api.ledgermind.dev/ai` | `lib/config/app_config.dart:8,13` |
| Chế độ | `AppMode { demo, full }`, mặc định `full` | `lib/config/app_config.dart:1-4` |
| SQLite cục bộ | phiên bản DB = 6 (outbox đồng bộ offline) | `lib/services/sqflite_helper.dart:18` |
| Endpoint AI mobile gọi | `POST /donut/scan`, `/spade/analyze`, `/spade/recommend` | `lib/services/remote_api_helper.dart:518` và `grep -nE "'/(api\|spade)..."` |

### 4.4 Kiểm thử Mobile (`mobile-app/test`, chưa chạy lại)

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| File .dart trong `test/` | 66 (60 file `*_test.dart`, còn lại là helper/fake) | `find test -name '*.dart' \| wc -l`; `find test -name '*_test.dart' \| wc -l` |
| Lời gọi `test(` | 240 | `grep -rhoE '(^\|[^A-Za-z_])test\(' test --include=*_test.dart \| wc -l` |
| Lời gọi `testWidgets(` | 348 | `grep -rhoE '\btestWidgets\(' test \| wc -l` |
| Tổng ca kiểm thử (ước lượng tĩnh) | 588 | 240 + 348 |
| `group(` | 114 | `grep -rhoE '\bgroup\(' test \| wc -l` |
| `integration_test/` | 0 file | `find integration_test -name '*.dart'` |

---

## 5. Web Admin (Thymeleaf)

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Template | 10 file: `admin/layout/_layout.html` + 9 trang: `login`, `dashboard`, `users`, `categories`, `receipts`, `subscriptions`, `reviews`, `auditlog`, `backup` | `find core-backend/src/main/resources/templates -type f` |
| Tài nguyên tĩnh | 1 file `static/css/admin.css` | `find core-backend/src/main/resources/static -type f` |
| Controller | `AdminController` (`@RequestMapping("/admin")`, `AdminController.java:58`), `ViewController` | §3.4 |
| Trang trả view | 9 view `admin/*` (dashboard, login, categories, receipts, users, subscriptions, backup, auditlog, reviews) | `grep -n 'return "admin/' AdminController.java` |
| Chức năng | CRUD người dùng/danh mục/gói dịch vụ qua AJAX, duyệt/từ chối hóa đơn, duyệt/xóa đánh giá, mở khóa tài khoản, backup/restore DB, chạy phân khúc khách hàng RFM, xem audit log | §3.4 |

---

## 6. AI Service (`ai-service/`)

### 6.1 Endpoint FastAPI (`ai-service/ai_service.py`, 298 dòng)

| Method | Path | Chức năng | Dòng |
|---|---|---|---|
| GET | `/health` | healthcheck | 70 |
| POST | `/donut/scan` | OCR hóa đơn bằng Donut (multipart `image`) | 75 |
| POST | `/spade/analyze` | khai phá chuỗi chi tiêu WCM-SPADE (`max_pattern_length=4`, cần ≥ 3 giao dịch chi) | 187, 207 |
| POST | `/spade/recommend` | gợi ý ngân sách (`budget_advisor.advise`, WCM-SPADE `max_pattern_length=3`) | 231; `budget_advisor.py:85` |
| POST | `/admin/segment` | phân khúc RFM **theo luật** (không phải ML): recency > 120 → CHURN; > 30 → AT-RISK; monetary > 10.000.000 và frequency ≥ 2 → VIP; còn lại ACTIVE | 272-296 |

Module: `wcm_spade.py` (260 dòng), `budget_advisor.py` (190 dòng).

### 6.2 Mô hình đang phục vụ (production = Version3)

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Đường dẫn weights | `ai-service/Version3/donut_result` | `ai_service.py:20` |
| Processor gốc | `naver-clova-ix/donut-base` (tokenizer thay bằng tokenizer trong MODEL_PATH) | `ai_service.py:30-34` |
| Kiến trúc | `VisionEncoderDecoderModel`: encoder `donut-swin`, decoder `mbart` 4 lớp, vocab 57.670, `max_position_embeddings` 768 | `Version3/donut_result/config.json` |
| Kích thước ảnh vào | 1280 × 960 (H × W) | `ai_service.py:23-24`; config `image_size [1280, 960]` |
| Task prompt token | `<s_seller>` (decoder_input_ids) | `ai_service.py:103` |
| Sinh chuỗi | `max_length=768`, greedy (`num_beams=1`, `do_sample=false`) | `ai_service.py:106`; `generation_config.json` |
| Token thêm | 207 added tokens (gồm `<s_seller>`, `<s_seller_name>`, `<s_address>`, `<s_timestamp>`, `<s_total_cost>` và ký tự tiếng Việt có dấu) | `tokenizer.json` `added_tokens` |
| Dung lượng weights | 806.518.936 byte (~769 MiB), **không** nằm trong git (`*.safetensors` bị ignore) | `ls -la Version3/donut_result/model.safetensors`; `.gitignore:111,121` |
| Thiết bị | CUDA nếu có, ngược lại CPU | `ai_service.py:21` |
| Hậu xử lý | `clean_vietnamese_text` (dòng 49), `processor.token2json`, `extract_final_cost` (bỏ `.`/`,`, lấy số lớn nhất → `total_cost_number`); lỗi parse → `{"raw_text": ...}` | `ai_service.py:40-46, 49, 114-125` |
| Hậu xử lý V5 (chưa dùng ở production) | `Version5/postprocess.py` | `ls ai-service/Version5` |

### 6.3 Kiểm thử AI

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Test service | 5 hàm trong `ai-service/test_main.py` (health, scan thành công, thiếu file, spade analyze, recommend) | `grep -cE '^(async )?def test_' ai-service/test_main.py` |
| Test bundle V5 | 58 hàm `test_` trong 11 file `Version5/tests/test_*.py` | `find Version5/tests -name 'test_*.py' \| wc -l`; `grep -rhcE '^\s*def test_' Version5/tests/*.py \| paste -sd+ \| bc` |

### 6.4 Tập dữ liệu hóa đơn

| Split | Ảnh (`*.jpg`) | Dòng `metadata.jsonl` | Bằng chứng |
|---|---|---|---|
| train | 5.080 | 5.080 | `find ai-service/data1/train -iname '*.jpg' \| wc -l`; `wc -l ai-service/data1/train/metadata.jsonl` |
| validation | 635 | 635 | tương tự |
| test | 636 | 636 | tương tự |
| **Tổng** | **6.351** | **6.351** | – |

- Tỉ lệ ≈ 80/10/10. Thư mục `ai-service/data1/` chưa được git theo dõi.
- Nhãn: `{"gt_parse": {"SELLER", "ADDRESS", "TIMESTAMP", "TOTAL_COST"}}` (4 trường, phẳng).
- Số nhãn rỗng (đọc từ `data1/<split>/metadata.jsonl` bằng script python đếm giá trị trống):

| Split | SELLER rỗng | ADDRESS rỗng | TIMESTAMP rỗng | TOTAL_COST rỗng |
|---|---|---|---|---|
| train (5.080) | 2.757 | 3.822 | 2.702 | 1.530 |
| validation (635) | 344 | 480 | 345 | 197 |
| test (636) | 348 | 479 | 320 | 189 |

- Số ảnh có **đủ cả 4 trường** khác rỗng: train 450/5.080, validation 49/635, test 59/636; không ảnh nào rỗng cả 4 trường (đo ngày 21/10/2026 bằng script python đọc `data1/<split>/metadata.jsonl`, đếm `all(gt_parse.get(k) for k in 4 khóa)`).
- Ví dụ định dạng trong nhãn train: TIMESTAMP `14/02/2023`, `15/08/2020-17:29`, `31/03/2023 20:02:49`; TOTAL_COST `100,000`, `20.000`, `205.500`; SELLER `HIGHLANDS COFFEE`, `VinCommerce`, `MINIMART ANAN` (mẫu ngẫu nhiên seed 3 trong 450 ảnh đủ nhãn).
- `ai-service/Version5/data1/<split>/metadata.jsonl`: 5.080 / 635 / 636 dòng, không chứa ảnh; **hiện giống hệt từng byte** bản trong `ai-service/data1` (`cmp -s` cả 3 split) → nhãn sửa lại (relabel Gemini/Qwen) chưa được ghi vào bundle.
- `Version5/v3_seen_test.txt`: 14 dòng (ảnh test mà V3 đã "thấy").

### 6.5 Cấu hình huấn luyện

**Bản cũ (gốc `ai-service/`, chưa git theo dõi; có thể là cấu hình đã sinh V3 – chưa xác nhận):**

| Tham số | Giá trị | Bằng chứng |
|---|---|---|
| Base model | `naver-clova-ix/donut-base-finetuned-cord-v2` | `ai-service/model_config.py:129-130` |
| Ảnh | 1280 × 960 | `model_config.py:31-32` |
| max_length | 768 | `train_model.py:31,35,58`; `model_config.py:163` |
| Nhân bản dữ liệu train | `duplication_factor=3` | `model_config.py:35` |
| Batch / grad accum | 2 / 4 (batch hiệu dụng 8) | `train_model.py:40-41` |
| Epoch | 50 | `train_model.py:42` |
| Learning rate / scheduler / warmup | 5e-5 / cosine / 100 bước | `train_model.py:43-45` |
| fp16, gradient checkpointing, optimizer | True (GPU T4), True, `adamw_torch_fused` | `train_model.py:51,54` |
| Chọn checkpoint | eval mỗi 200 bước, `metric_for_best_model="eval_loss"` | `train_model.py:47-60` |
| Decoder start token | `<s_seller>` | `model_config.py` (khối thêm token, dòng ~161-165) |

**Bundle Version5 (`ai-service/Version5/`, chưa commit):**

| Tham số | Giá trị | Bằng chứng |
|---|---|---|
| Base model | `naver-clova-ix/donut-base-finetuned-cord-v2` | `Version5/model_config.py:14` |
| Task token | `<s_seller>` … `</s_seller>` | `Version5/model_config.py:15-16` |
| Trường → tag | SELLER→`seller_name`, ADDRESS→`address`, TIMESTAMP→`timestamp`, TOTAL_COST→`total_cost` | `Version5/model_config.py:17-22` |
| max_length | 768 | `Version5/model_config.py:23` |
| Ảnh mặc định | 1920 × 1440 (H × W) | `Version5/model_config.py:25` |
| Batch / grad accum | 1 / 8 | `Version5/train_model.py:56-57, 22` |
| Learning rate / scheduler / warmup | 3e-5 / cosine / 300 | `Version5/train_model.py:58-60` |
| Epoch | 8; early stopping patience 4 | `Version5/train_model.py:61, 23` |
| Seed | 42 | `Version5/train_model.py:19` |
| Validation con khi train | 150 ảnh | `Version5/train_model.py:18` |
| Chọn checkpoint | eval/save mỗi 400 bước, `metric_for_best_model="eval_field_exact"` | `Version5/train_model.py:75-81` |
| Đánh giá | greedy `num_beams=1`; ngưỡng "relaxed" 0,80 | `Version5/evaluate.py:17,46` |

**Notebook:** `donut-tranformer.ipynb` (8 cell, 4 cell có output), `donut-v5.ipynb` (11 cell, chưa có output), `relabel-v5.ipynb` (11 cell, chưa có output) – đếm bằng `json.load` số cell và cell có `outputs`.

**Kết quả đánh giá duy nhất có trong repo** (output cell 4 của `ai-service/donut-tranformer.ipynb`, mô hình tải từ `/kaggle/input/.../donut-tranformer/donut_result`, "Tập Validation 172 ảnh"):

| Trường | Exact Match | Match @ 80% | Similarity |
|---|---|---|---|
| SELLER | 77,33% | 84,88% | 90,92% |
| ADDRESS | 30,23% | 80,81% | 86,53% |
| TIMESTAMP | 62,79% | 88,95% | 92,66% |
| TOTAL_COST | 85,47% | 91,86% | 92,29% |
| Trung bình | 63,95% | 86,63% | 90,60% |

Cảnh báo: tập 172 ảnh này **không** trùng kích thước với `data1/validation` (635 ảnh); chưa xác nhận đây là mô hình Version3 đang phục vụ.

---

## 7. Git

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Số commit | 31 | `git rev-list --count HEAD` |
| Người đóng góp | 1: `TriPhan15` (31 commit) | `git shortlog -sn --all \| head` |
| Commit đầu tiên | 2026-07-23 17:35:20 +0700 (`1ae93a0`) | `git log --reverse --format='%ad %h' --date=iso \| head -1` |
| Commit cuối | 2026-10-02 19:20:10 +0700 (`a7ff9b3`) | `git log -1 --format='%ad %h' --date=iso` |

---

## 8. Chưa xác định / cần người dùng cung cấp

1. **Kết quả huấn luyện/đánh giá Donut V5** (field exact, relaxed, so sánh V3 vs V5): chưa có trong repo (notebook `donut-v5.ipynb` không có output; `Version5/donut_result` không tồn tại).
2. **Kết quả đánh giá chính thức của V3 trên `data1/test` (636 ảnh)**: chỉ có bảng 172 ảnh ở §6.5 với nguồn chưa rõ.
3. **Cấu hình thực tế đã sinh Version3** (số epoch thực chạy, phần cứng, thời gian huấn luyện, loss cuối): `ai-service/model_config.py`/`train_model.py` chưa git theo dõi và không có log.
4. **Nguồn gốc/giấy phép tập dữ liệu 6.351 ảnh** và cách gán nhãn ban đầu.
5. **Số ca kiểm thử thực tế khi chạy** (Surefire/`flutter test`/pytest) tại HEAD hiện tại: bảng này chỉ đếm tĩnh; không chạy test theo quy định.
6. **Số liệu hiệu năng** (thời gian suy luận `/donut/scan` CPU/GPU, JMeter, độ trễ API, hit-rate cache): chưa đo.
7. **Hạ tầng triển khai thật** (loại EC2, RAM/CPU, domain/TLS cho `api.ledgermind.dev`, reverse proxy): repo chỉ có workflow SSH, không có cấu hình máy.
8. **docker-compose.yml ở working tree đang lỗi cú pháp** (§2.2): cần người dùng sửa trước khi mô tả kiến trúc có MongoDB là "đã triển khai".
9. **Phần MongoDB** (2 collection, `OcrMongoController`, `spring-boot-starter-data-mongodb`) chưa commit: cần xác nhận có đưa vào khóa luận không.
10. **Endpoint mobile gọi nhưng backend không có**: `RemoteApiHelper` gọi `/api/wallets/transfer`, `/api/wallets/user/{userId}`, `GET /api/transactions?userId=...` – không có mapping nào trong §3.3 (`grep -nE "'/(api\|spade)" lib/services/remote_api_helper.dart`). Cần xác nhận đây là code chết hay tính năng thiếu.
11. **CHECK constraint do Hibernate sinh cho cột enum** (Hibernate 6 + `ddl-auto: update`): không có trong file SQL; cần đọc schema DB thật nếu muốn liệt kê.
