# Thiết kế: Đồ án NoSQL "một công đôi việc" (MongoDB + Redis + Elasticsearch) và cập nhật khóa luận

Ngày: 2026-10-26 · Trạng thái: chờ người dùng duyệt

## 1. Ý định và lý do

Người dùng (nhóm Phan Thanh Trí, Phan Minh Tiến; GVHD Ths. Ngô Minh Anh Thư) phải nộp đồ án môn **Dữ liệu NoSQL** và muốn dùng chính LedgerMind (monorepo này) làm sản phẩm, để mọi phần code thêm vào vừa đáp ứng barem NoSQL vừa là tính năng thật của khóa luận. Đã chốt:

- Hướng đồ án 1: "mở rộng ứng dụng có sẵn dùng RDBMS, tích hợp NoSQL đã học và **ít nhất 1 CSDL tự tìm hiểu**". Giảng viên yêu cầu CSDL tự tìm hiểu **phải nằm ngoài** MongoDB, Redis, Cassandra, Neo4j.
- NoSQL đã học dùng: **MongoDB** (Document) và **Redis** (Key-Value), cả hai đã có trong code. Không dùng Cassandra, Neo4j.
- CSDL tự tìm hiểu: **Elasticsearch** (search engine / document store), phục vụ tính năng người dùng thật: tìm lại giao dịch/hóa đơn theo từ khóa tiếng Việt (gõ không dấu, gõ sai chính tả vẫn ra, xếp theo độ liên quan). Hiện app chưa có: ô tìm kiếm ở `mobile-app/lib/screens/ledger/ledger_page.dart` chỉ lọc danh sách đã tải về, và `TransactionFilterRequestDto` không có tham số từ khóa.
- Nỗi sợ chính của người dùng: **over-engineer**. Mỗi CSDL phải có đúng một vai trò rõ ràng, có lý do thật, đúng kiểu doanh nghiệp làm.

Nguồn yêu cầu: `Nosql/YC_NoSql/nosql_doan.txt`, `Nosql/YC_NoSql/REFS_NoSQL_SRS&SDS_Template.docx` (khung 9 chương + barem tiêu chí 1–10), `Nosql/YC_NoSql/BaoCaoMinhChung_DoAn_DuLieuNoSQL.docx`. Bản nháp đã có: `Nosql/Nosql_38/` (SRS docx tuần 6, Report_NoSQL.md, nosql_audit.md, nosql_diagrams.md...).

## 2. Mục tiêu, ngoài phạm vi, điều cấm

**Mục tiêu**
1. Code: thêm Elasticsearch search, biến "leaderboard" thành Redis Sorted Set thật, lấp chỗ trống CRUD/thống kê của MongoDB. Mỗi phần là tính năng dùng được trong app.
2. Word NoSQL cuối kỳ: 1 file báo cáo hoàn chỉnh theo 9 chương của template, phủ mọi tiêu chí barem, nội dung đúng với code trong repo, tài liệu tham khảo chuẩn IEEE.
3. Điền `BaoCaoMinhChung_DoAn_DuLieuNoSQL.docx` (ngắn: thông tin đồ án, danh mục hồ sơ, phân công, tóm tắt kiến trúc).
4. Sau khi xong Word NoSQL: cập nhật Word khóa luận với những gì mới/khác.

**Ngoài phạm vi**
- Cassandra, Neo4j, Kafka/RabbitMQ, cluster nhiều node, sharding thật, Prometheus/Grafana.
- Viết lại luồng hóa đơn (receipt lifecycle) hay chuyển JSON thô của AI ra khỏi Postgres.
- 3 file theo mốc tuần 6/7/11: chỉ cần **file cuối** + file minh chứng.
- Video demo: người dùng tự quay. Báo cáo chỉ kèm kịch bản demo theo template.

**Điều cấm (làm vậy là hỏng dù chạy được)**
- Nhồi CSDL/kỹ thuật không có nhu cầu thật; claim trong báo cáo điều mà code không làm. Ví dụ bản nháp gọi `FallbackCacheErrorHandler` là "Circuit Breaker" là sai, nó chỉ là fallback. Bản nháp gọi Jitter TTL/@Async là "CSDL tự tìm hiểu" cũng sai.
- Số liệu hiệu năng bịa. Mọi con số phải đo thật hoặc ghi rõ là mục tiêu.
- Elasticsearch trở thành nguồn sự thật hoặc làm app chết khi nó sập.
- Lộ dữ liệu người khác qua search (phải lọc theo user từ JWT).

## 3. Ràng buộc

- Tuân thủ `CLAUDE.md`: package PascalCase, `ApiResponse<T>`, `CurrentUserProvider`, DTO `<Feature>RequestDto/ResponseDto`, message tiếng Việt, không N+1, không tự chạy full test suite/build, không git commit/push, không chạy server.
- `pom.xml` và `docker-compose.yml` chỉ được sửa ở mức thiết kế này nêu: thêm `spring-boot-starter-data-elasticsearch`, thêm service `elasticsearch` (và `kibana` sau profile demo). Duyệt thiết kế này = người dùng cho phép sửa đúng các chỗ đó.
- Deploy dự kiến: Oracle Always Free (xem memory deploy). Elasticsearch phải chạy 1 node với heap nhỏ (~512 MB, giới hạn container ~1 GB). Kibana chỉ bật khi demo/chụp màn hình, không chạy trên production.
- **Server production chưa chốt** (Oracle Always Free hoặc cloud free tier khác, chưa biết RAM). Vì vậy Elasticsearch phải là thành phần **bật/tắt được**: một cờ cấu hình (ví dụ `SEARCH_ENGINE=elasticsearch|postgres`) và service ES nằm sau compose profile. Tắt thì toàn bộ app vẫn chạy và tìm kiếm dùng đường Postgres (ILIKE). Báo cáo và khóa luận mô tả cả hai chế độ, ghi rõ chế độ nào đang chạy trên server thật khi deploy xong. Máy dev/demo luôn chạy ES.
- Không gấp hạn nộp: làm đủ phạm vi, không cần thứ tự cắt giảm.
- Redis hiện **không persistence** (`--save ''`, `--appendonly no`) và tắt `KEYS`/`FLUSHALL`/`FLUSHDB`. Giữ nguyên. Dữ liệu Redis luôn dựng lại được từ Postgres.
- Postgres là nguồn sự thật của mọi dữ liệu nghiệp vụ.

## 4. Vai trò từng CSDL (đã quyết)

| CSDL | Loại | Vai trò duy nhất | Nguồn sự thật? |
|---|---|---|---|
| PostgreSQL | RDBMS | Người dùng, ví, giao dịch, ngân sách, vòng đời hóa đơn kể cả `receipt_processing_attempts` (JSON thô AI phục vụ retry/duyệt) | Có |
| MongoDB | Document | **Kho phân tích chất lượng AI / dữ liệu huấn luyện lại DONUT**: `ocr_logs` (bản làm giàu: độ tin cậy, các trường AI đọc, phiên bản model) + `ocr_feedbacks` (mỗi trường người dùng sửa so với AI). Truy vấn aggregation theo trường lỗi, model, thời gian | Không (bản sao phân tích) |
| Redis | Key-Value | Cache thống kê (5 nhóm hiện có), OTP quên mật khẩu (Hash + TTL + Lua), **bảng xếp hạng chi tiêu theo tháng (Sorted Set)** | Không |
| Elasticsearch | Search/Document (tự tìm hiểu) | Index chỉ-đọc để **tìm kiếm full-text giao dịch/hóa đơn** của chính người dùng | Không |

**Quyết định về MongoDB (do người nhờ chọn, đây là lựa chọn của Claude):** giữ code luồng hóa đơn, định vị lại Mongo là kho phân tích/ML (mô hình CQRS read model / data lake). Lý do: retry và duyệt hóa đơn cần JSON thô nằm cùng transaction với trạng thái hóa đơn trong Postgres. Mongo có lý do tồn tại riêng là truy vấn phân tích mà Postgres không phục vụ tự nhiên. `docker-compose.yml` đã mô tả Mongo đúng như vậy ("analysis copy"). Báo cáo phải bỏ lập luận cũ "tách JSON ra Mongo để Postgres khỏi phình".

## 5. Phần code

### 5.1 Elasticsearch: tìm kiếm giao dịch

- **Hạ tầng:** service `elasticsearch` 8.x single-node trong `docker-compose.yml` cùng `finance-network`. Bật security (mật khẩu qua `.env`, theo kiểu `REDIS_PASSWORD`), heap ~512 MB, có volume, healthcheck, chỉ bind `127.0.0.1` nếu cần publish. `kibana` đặt sau compose profile (ví dụ `tools`) để chỉ bật khi demo.
- **Thư viện:** Spring Data Elasticsearch, đúng bảng ánh xạ thư viện của template.
- **Index `transactions`** (một document = một giao dịch): id giao dịch, userId, mô tả/ghi chú, tên cửa hàng, địa chỉ, danh mục, số tiền, isExpense, ngày giao dịch, trạng thái hóa đơn nếu có. Analyzer tiếng Việt tự định nghĩa: `lowercase` + `asciifolding` (để "pho" khớp "Phở", "đ" về "d"), thêm subfield cho prefix/autocomplete (edge n-gram), truy vấn `multi_match` có `fuzziness: AUTO`. Mapping và analyzer phải nằm trong script để nộp.
- **Đồng bộ:** sau khi Postgres commit (tái sử dụng mẫu `@TransactionalEventListener(AFTER_COMMIT)` + `@Async` đang dùng cho Mongo và xóa cache Redis), index/cập nhật/xóa document. Lỗi Elasticsearch chỉ log, không làm hỏng giao dịch. Có **endpoint admin reindex toàn bộ từ Postgres** (bulk) để khôi phục sau sự cố. Đây là câu chuyện nhất quán cuối cùng (eventual consistency) trong báo cáo.
- **API:** `GET /api/transactions/search?q=...&page=&size=` chỉ trả giao dịch của user lấy từ JWT (filter `userId` bắt buộc ở server), validate `q` (độ dài tối thiểu/tối đa), trả `ApiResponse` với DTO, có highlight nếu builder thấy hợp lý.
- **Khi Elasticsearch sập:** fallback xuống truy vấn Postgres đơn giản (ILIKE trên mô tả/tên cửa hàng của chính user) để app vẫn tìm được, ghi log cảnh báo. (Lựa chọn của Claude, thống nhất với cách Redis/Mongo đang suy giảm an toàn.)
- **Mobile:** ô tìm kiếm Sổ cái gọi API qua `RemoteApiHelper` (có debounce), hiển thị kết quả, có lỗi mạng thì báo theo `AppDialog`/thông báo hiện có. Chuỗi UI qua ARB vi/en (dự án đã có l10n).

### 5.2 Redis: bảng xếp hạng Sorted Set thật

- Key dạng `leaderboard:spend:{yyyyMM}` (đặt hằng số, không magic string): member = userId, score = tổng chi tiêu tháng.
- Sau commit: tạo giao dịch chi → `ZINCRBY +amount`. Xóa/sửa giao dịch → điều chỉnh delta tương ứng. TTL khoảng 2 tháng.
- Đọc top N bằng `ZREVRANGE ... WITHSCORES`, thứ hạng của một user bằng `ZREVRANK`.
- Vì Redis không persistence: khi key tháng không tồn tại thì dựng lại từ Postgres (một truy vấn GROUP BY), rồi mới đọc. Đây là điểm đáng viết trong báo cáo (Redis là dữ liệu dẫn xuất, dựng lại được).
- Endpoint top spenders của admin chuyển sang đọc Sorted Set, giữ nguyên hợp đồng API hiện có nếu có thể. Builder kiểm tra `AdminStatisticsService.getTopSpenders` / `TransactionRepository.findTopSpenders` để xác định phạm vi thời gian hiện tại.

### 5.3 MongoDB: lấp chỗ trống barem

Hiện có: `ocr_logs`, `ocr_feedbacks`, `GET /api/admin/ocr-logs`, aggregation group-by `fieldError`, `resolveFeedback` trong service. `ocr_feedbacks` hiện chỉ có dữ liệu từ seeder.

- **Feedback sinh tự động, có thật:** khi người dùng lưu một hóa đơn đã quét, so sánh các trường AI đọc (từ câu trả lời thô) với giá trị người dùng lưu. Mỗi trường khác nhau tạo một document `ocr_feedbacks` (aiValue, expectedValue, fieldError, modelVersion, userId, receiptId). Ghi sau commit, lỗi chỉ log.
- `ocr_logs` thêm `modelVersion` (ví dụ `donut-v5`) và các trường AI đọc dạng document lồng nhau.
- **API admin đủ CRUD + lọc/sắp xếp/thống kê:** liệt kê feedback có lọc (trường, đã xử lý chưa, khoảng thời gian), sắp xếp, phân trang; đánh dấu đã xử lý; xóa; thống kê aggregation: lỗi theo trường, theo model, độ tin cậy trung bình theo tháng, tỷ lệ hóa đơn có ít nhất một lỗi. Nếu admin web (Thymeleaf) đã có trang tương ứng thì nối vào, không thì API + Compass/Postman là đủ.
- `scripts/nosql/mongodb_init.js`: collection kèm `$jsonSchema` validation, index (compound theo quy tắc ESR cho truy vấn chính, TTL index nếu hợp lý), dữ liệu mẫu JSON đủ để mọi truy vấn demo có kết quả.

### 5.4 Scripts nộp kèm (`scripts/nosql/`)

Mỗi CSDL một script: tạo cấu trúc, dữ liệu mẫu, khoảng 10 truy vấn cơ bản + 10 nâng cao cho toàn đồ án (chia đều 3 hệ), lệnh import/export, backup/restore:
- MongoDB: `mongoimport/mongoexport`, `mongodump/mongorestore`.
- Redis: script `redis-cli`. Backup bằng `BGSAVE` chỉ để demo, ghi rõ production không persistence và vì sao.
- Elasticsearch: mapping, bulk NDJSON, truy vấn dạng Kibana Dev Tools. Snapshot/restore qua `path.repo`.

Mỗi lệnh "xóa → restore → đếm lại" theo yêu cầu tiêu chí backup.

### 5.5 Kiểm thử

Theo runbook trong memory: unit (Mockito) + integration bằng Testcontainers (Redis, MongoDB, Elasticsearch container) + widget test mobile cho ô tìm kiếm. Viết test, nhưng **không tự chạy full suite** (CLAUDE.md rule 1). Chạy test lẻ theo cách người dùng cho phép. Bảng TC trong báo cáo lấy từ test thật.

## 6. Word NoSQL cuối kỳ

- **Hình thức:** trang bìa và style lấy từ `Nosql/Nosql_38/38_SRS_...docx` (Bộ Công Thương, HUIT, Khoa CNTT, GVHD, nhóm, "Thành phố Hồ Chí Minh tháng ... năm 2026"). Đổi tên đề tài cho có Elasticsearch, ví dụ "Ứng dụng MongoDB, Redis và Elasticsearch trong hệ thống quản lý tài chính cá nhân LedgerMind" (lựa chọn của Claude, người dùng sửa được).
- **Bố cục:** đúng 9 chương của template: (1) giới thiệu + kế hoạch + phân công; (2) tổng quan NoSQL (CAP, BASE, phân tán, 4 loại) + các hệ dùng + **mục 2.5 tìm hiểu GUI Tool: Kibana, so sánh với Elasticvue** (4 tiêu chí × 0,5 điểm); (3) SRS theo IEEE 830/29148 có BPMN, use case, activity, sequence, state machine (vòng đời hóa đơn), DFD, NFR đo được, 3V, **bảng Access Pattern**, ma trận truy vết; (4) SDS theo IEEE 1016: kiến trúc, ma trận chọn CSDL, thiết kế từng CSDL (key pattern Redis, collection/index/validation Mongo, mapping/analyzer Elasticsearch), đồng bộ polyglot, CAP/PACELC, bảo mật/backup, API, ánh xạ AP → thiết kế, class diagram, kỹ thuật nâng cao; (5) xây dựng CSDL và truy vấn trên GUI tool (Compass, RedisInsight, Kibana) kèm `explain()` IXSCAN; (6) kết nối ứng dụng + demo 4 nhóm chức năng; (7) kiểm thử chức năng + hiệu năng có/không cache, có/không index (JMeter đã có trong `docs/testing`); (8) kết quả + tổng kết nhóm; (9) tài liệu tham khảo, phụ lục.
- **Bảng đối chiếu barem:** một bảng (cuối chương 8 hoặc phụ lục) nối từng tiêu chí 1–10 và yêu cầu tối thiểu MongoDB/Redis với mục trong báo cáo + file minh chứng.
- **Sơ đồ:** vẽ lại theo kiến trúc mới (có Elasticsearch), dùng cách render đang dùng cho khóa luận (`docs/thesis/diagrams`, `docs/thesis/build/`).
- **Ảnh chụp GUI tool:** agent không tự mở được Compass/RedisInsight. Báo cáo chừa khung ảnh có chú thích và đánh số. Kèm danh sách ảnh cần chụp (ảnh nào, lệnh nào, màn hình nào) để người dùng chụp rồi agent chèn. Kibana thì agent có thể chụp bằng trình duyệt tự động nếu stack đang chạy và người dùng cho phép.
- **Tài liệu tham khảo:** IEEE, ưu tiên tài liệu chính thức (MongoDB Manual, Redis docs, Elasticsearch Reference 8.x, Spring Data MongoDB/Redis/Elasticsearch), sách/bài báo gốc (Sadalage & Fowler *NoSQL Distilled*; Brewer CAP; Gilbert & Lynch 2002; Abadi PACELC 2012; Kleppmann *Designing Data-Intensive Applications*; IEEE 830, ISO/IEC/IEEE 29148, IEEE 1016; Kim et al. 2022 Donut). Tái sử dụng `docs/thesis/references.md` khi trùng nguồn. Mỗi tài liệu phải được trích dẫn trong thân bài, không liệt kê suông.
- **Phân công nhóm:** bảng 2 thành viên (Trí: trưởng nhóm/backend; Tiến: phần còn lại). Tỷ lệ % do người dùng điền hoặc xác nhận.
- **Đầu ra:** file `.docx` cuối trong `Nosql/Nosql_38/` + `BaoCaoMinhChung` đã điền. Sinh bằng generator Python (python-docx) giống cách làm khóa luận, kiểm tra hiển thị bằng LibreOffice render như memory đã ghi.

## 7. Cập nhật Word khóa luận (sau khi Word NoSQL xong)

Dùng generator hiện có (`docs/thesis/build/builder.py` + các `content_*.py`, phiên bản mới nhất v9), tạo bản kế tiếp. Cập nhật: kiến trúc và triển khai (thêm Elasticsearch, vai trò Mongo mới), tính năng tìm kiếm giao dịch, bảng xếp hạng Sorted Set, ocr_feedbacks tự động, sơ đồ liên quan, kiểm thử mới, tài liệu tham khảo mới. Kiểm tra `docs/thesis/facts.md` / `outline.md` để không mâu thuẫn số liệu cũ. Chỉ sửa phần bị ảnh hưởng, không viết lại khóa luận.

## 8. Thứ tự làm

1. Code: Redis Sorted Set → MongoDB feedback/API/scripts → Elasticsearch (backend → mobile) → scripts nộp kèm → test.
2. Word NoSQL + BaoCaoMinhChung (cần ảnh người dùng chụp).
3. Cập nhật khóa luận.

Dừng sau mỗi bước lớn để người dùng xem (người dùng quen kiểu làm từng batch).

## 9. Để builder tự quyết

Tên class/endpoint chi tiết, cấu trúc DTO, cách debounce trên mobile, có highlight hay không, số shard/replica (1/0 cho single node), cách tổ chức generator docx, cách đo benchmark cụ thể, bố cục trang admin nếu có.

## 10. Lựa chọn do Claude quyết (người dùng kiểm tra lại)

- Vai trò MongoDB = kho phân tích/ML. Không chuyển JSON thô khỏi Postgres.
- GUI Tool tìm hiểu: Kibana, so với Elasticvue.
- Elasticsearch sập → fallback ILIKE Postgres.
- Feedback OCR sinh tự động từ chênh lệch AI và người dùng khi lưu hóa đơn.
- Tên đề tài mới có Elasticsearch.
- Kibana chỉ chạy theo profile demo, không lên production.
- **Trường đưa vào index tìm kiếm:** `note`, `categoryName`, `location`, `paymentMethod` của `Transaction` + `Receipt.vendorName` khi giao dịch có hóa đơn. Tải bằng JOIN FETCH, không gây N+1. **Không** index các dòng món hàng trong JSON thô, để index gọn và không phải parse JSON. Sửa hóa đơn (vendorName) cũng kích hoạt reindex giao dịch đó. Fallback ILIKE dùng đúng các trường này. (Mục 5.1 nói "tên cửa hàng, địa chỉ" tức là `vendorName` và `location`.)
- **Thời điểm sinh `ocr_feedbacks`** (đã chỉnh theo code thật: lúc checkout, backend lấy ngày/địa chỉ từ AI, nên người dùng chỉ sửa được số tiền ở bước đó): mỗi lần người dùng sửa một trường AI đã đọc thì sinh feedback. Có 3 điểm: (1) checkout hóa đơn quét có số tiền khác tổng AI đọc; (2) `editMyReceipt` đổi tên quán / tổng tiền / ngày; (3) `submitFeedback` gửi số tiền khi AI không đọc được (aiValue rỗng). Luôn so với lần đọc AI mới nhất (attempt mới nhất). Mỗi cặp (receiptId, trường) chỉ có **một** document, được upsert, nên sửa nhiều lần không nhân bản thống kê. Giá trị trùng với AI thì không sinh. Admin duyệt và lưu hàng loạt T11 không có chênh lệch thì không sinh.
- **Ô tìm kiếm mobile:** khi có mạng thì thay bộ lọc cục bộ bằng kết quả server. Các dòng outbox chưa đồng bộ (`id` null) vẫn được lọc cục bộ và hiển thị phía trên kết quả server. Mất mạng thì quay về lọc cục bộ.
- **Bảng xếp hạng admin:** đổi từ "toàn thời gian" sang **theo tháng** (mặc định tháng hiện tại, có tham số chọn tháng) trên trang admin Thymeleaf (`AdminController`). Nhóm cache `admin-top-spenders` được bỏ vì Sorted Set thay thế, Redis còn 4 nhóm cache + 1 leaderboard + OTP.

## 11. Bổ sung ngày 27/10/2026 (sau khi xong plan code 1)

- **Thang điểm** (người dùng cung cấp): tiêu chí 10 gồm 4 ý, mỗi ý 0,5 điểm:
  1. Báo cáo đầy đủ, đúng chính tả, đúng định dạng, không sao chép.
  2. Thuyết trình tự tin, trả lời được câu hỏi.
  3. Nộp đúng hạn, đủ file **Word, PowerPoint, source code**.
  4. Phân chia công việc rõ ràng, có trách nhiệm.
- Từ đó plan báo cáo thêm: slide PowerPoint, tài liệu chuẩn bị câu hỏi bảo vệ, bước soát chính tả.
- **Plan 1b (code), làm trước báo cáo.** Người dùng nhờ chọn; đây là lựa chọn của Claude:
  - trang admin web cho NoSQL: duyệt feedback OCR kèm biểu đồ, trang vận hành NoSQL có nút dựng lại chỉ mục ES và bảng xếp hạng, backup/restore MongoDB trên trang backup có sẵn;
  - **realtime cho web admin** bằng Redis Pub/Sub + SSE. Người dùng chọn "làm luôn". Push thông báo trên mobile (FCM) vẫn để hướng phát triển.
- **Ảnh GUI tool:** chụp trên một stack demo riêng do Claude viết lệnh dựng, không đụng stack đang chạy.
- **Báo cáo hoạt động nhóm và tài liệu kiểm thử:** nằm trong báo cáo chính (Chương 8 và Chương 7). Mã nhóm 38.
- **Tên đề tài** (theo tên đã đăng ký và bìa SRS tuần 6): "Ứng dụng cơ sở dữ liệu MongoDB và bộ nhớ đệm Redis trong việc xây dựng hệ thống quản lý tài chính cá nhân". Elasticsearch là "CSDL tự tìm hiểu" trình bày trong nội dung. Nếu GV cho đổi tên thì thêm "… kết hợp Elasticsearch".
- **Bìa:** tháng 11 năm 2026.
- **Link:** nhánh `main` của repo (repo private). Ô Ghi chú nhắc: thêm GV làm collaborator hoặc nộp kèm zip source.
- **Phân công** (trung thực, đối chiếu được với git):
  - Trí: nhóm trưởng; phân tích, kiến trúc, toàn bộ code (PG, Redis, ES, plan 1b). Khoảng 60%, người dùng chỉnh lại.
  - Tiến: những việc còn lại, làm thật: MongoDB (truy vấn, minh chứng Compass), Kibana/Elasticvue (mục 2.5), chụp ảnh trên stack demo, chạy lại script và backup/restore, soát Ch.2 và Ch.5, slide, video demo, soát chính tả. Khoảng 40%.
  - Không ghi Tiến viết phần code đã có.
