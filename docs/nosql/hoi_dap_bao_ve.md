# Hỏi đáp bảo vệ – báo cáo NoSQL nhóm 38 (LedgerMind)

29 câu giảng viên có thể hỏi, kèm câu trả lời ngắn (nói được trong 20–40 giây). Mỗi câu ghi **mục báo cáo** và **file** để mở ra chứng minh. Nguồn sự thật là `docs/nosql/facts.md`; số đo ở `docs/nosql/bench_results.md`. Đường dẫn tắt: `J/` = `core-backend/src/main/java/vn/edu/huit/finance/core/`, `R/` = `core-backend/src/main/resources/`, `S/` = `scripts/nosql/`.

Nguyên tắc khi trả lời: chỉ nói điều hệ thống đang làm; điều chưa làm thì nói là hạn chế hoặc hướng phát triển; số đo nói rõ là dữ liệu tổng hợp 100k (sinh bằng `gen_data.py`) hoặc dữ liệu demo; một CSDL dừng thì nói "vẫn trả lời" kèm độ trễ, không nói "không ảnh hưởng". Câu về MongoDB và Kibana: Tiến trả lời trước; câu về thiết kế, code, Redis, Elasticsearch: Trí trả lời trước.

Mục lục theo chủ đề: lựa chọn CSDL (1–4, 18), CAP và sự cố (5–9), kỹ thuật (10–15), tìm kiếm tiếng Việt (16–17), realtime (19–20), sao lưu (21–22), bảo mật (23), số đo và triển khai (24–26), GUI tool (27), phân công (28), hạn chế (29).

---

## A. Lựa chọn và thiết kế

### 1. Vì sao chọn đúng ba CSDL MongoDB, Redis, Elasticsearch?
Mỗi CSDL gắn với một nhóm mẫu truy cập (AP) mà PostgreSQL làm kém hoặc làm tốn. Redis cho đọc rất nhiều và dữ liệu ngắn hạn (cache, OTP, xếp hạng, Pub/Sub): GET p50 0,054 ms so với 3 câu SQL 2,13 ms. MongoDB cho JSON của AI đổi theo phiên bản mô hình và thống kê bằng aggregation. Elasticsearch cho tìm kiếm tiếng Việt: người dùng nặng p50 3,70 ms so với LIKE 78,2 ms, bỏ sót 0 dòng. Còn PostgreSQL vẫn giữ tiền và hóa đơn.
- Báo cáo: mục 4.2 (bảng ma trận lựa chọn), 3.6 (AP).
- File: `docs/nosql/build/content_c4.py` (C4_2), `docs/nosql/bench_results.md`.

### 2. Vì sao JSON thô của AI vẫn nằm ở PostgreSQL, không chuyển sang MongoDB?
Vì vòng đời hóa đơn đổi trạng thái hóa đơn và lần đọc AI trong cùng một giao dịch ACID (khóa lạc quan `@Version`, trả 409 khi xung đột). Nếu để JSON ở MongoDB thì hai nơi phải đổi cùng lúc mà không có giao dịch chung (giao dịch nhiều document của MongoDB cần replica set, hệ thống chạy một node). MongoDB giữ bản sao phân tích để thống kê, không phải nguồn sự thật.
- Báo cáo: mục 4.2, 1.1 (PostgreSQL).
- File: `J/Service/ReceiptProcessingService.java:167-168`, `J/Entity/Receipt.java:72-78`.

### 3. MongoDB ở đây có phải CQRS không?
Không. CQRS tách hẳn mô hình ghi và mô hình đọc; ở đây mọi lệnh ghi và phần lớn lệnh đọc nghiệp vụ vẫn dùng mô hình PostgreSQL. MongoDB chỉ là bản sao phân tích dựng sau commit cho quản trị viên. Nhóm chỉ dùng CQRS để so sánh, giải thích vì sao các bản sao được phép chậm hơn nguồn một chút.
- Báo cáo: mục 4.2 (đoạn "So sánh với CQRS").
- File: `docs/nosql/build/content_c4.py` (C4_2).

### 4. CAP và PACELC của từng CSDL?
Hiện mỗi CSDL một node nên không có phân vùng mạng giữa các bản sao; bảng là thiết kế cụm (chưa triển khai). PostgreSQL: CP, PC/EC (giữ tiền nên ưu tiên nhất quán). Redis: AP, PA/EL (sao chép bất đồng bộ, chấp nhận mất vài lệnh ghi cuối). MongoDB: CP, PC/EC khi dùng write/read concern majority. Elasticsearch: bầu master theo đa số (nghiêng về C), đọc PA/EL vì bản sao có thể chậm một nhịp refresh. Lựa chọn khớp vai trò: chỉ PostgreSQL giữ tiền; ba hệ kia chấp nhận nhất quán cuối cùng.
- Báo cáo: mục 4.8 (bảng CAP/PACELC), 2.1 (lý thuyết CAP/PACELC).
- File: `docs/nosql/build/content_c4.py` (C4_8).

---

## B. Sự cố và nhất quán

### 5. Redis dừng hoặc treo thì chuyện gì xảy ra?
Dashboard và thống kê vẫn trả lời, đọc từ PostgreSQL: lỗi đọc cache coi như trượt cache, lỗi ghi/xóa cache bị bỏ qua. Mỗi request tốn thêm tối đa timeout (kết nối 1 s, lệnh 500 ms); kiểm thử xác nhận Redis đã dừng trả lời dưới 450 ms, Redis treo dưới 3 s. Độ trễ quan sát khi quay demo: `____ ms` (điền sau khi quay). Đó là cơ chế dự phòng (fallback), không phải Circuit Breaker. Riêng OTP cố ý báo lỗi vì mã không dựng lại được; realtime mất tin, app vẫn chạy và tự đăng ký lại sau mỗi 10 s.
- Báo cáo: mục 7.3 (bảng chịu lỗi), 4.7 ("Khi một CSDL lỗi").
- File: `J/Config/FallbackCacheErrorHandler.java:9-41`, `J/Config/CacheConfig.java:117-122`; test TC-10, TC-11 (`RedisOutageTest`).

### 6. Elasticsearch dừng, hoặc đang dựng lại chỉ mục, thì tìm kiếm ra sao?
Vẫn trả lời bằng PostgreSQL (`LOWER(col) LIKE … ESCAPE`), phản hồi có trường `engine` đổi từ `elasticsearch` sang `postgres`. Từ commit 59983b9, nếu chỉ mục chưa sẵn sàng hoặc đang dựng lại (reindex) thì chuyển sang PostgreSQL ngay, không chờ lỗi. Chờ thêm tối đa 1 s kết nối hoặc 2 s socket; độ trễ quan sát: `____ ms`. Cái giá: chế độ PostgreSQL không bỏ dấu ("pho" không ra "Phở"), được ghi là hạn chế.
- Báo cáo: mục 7.3, 7.4 (hạn chế), 4.5.
- File: `J/Service/Search/TransactionSearchService.java:22-91`; test TC-36, TC-40.

### 7. MongoDB dừng thì sao?
Ghi giao dịch và hóa đơn vẫn thành công vì ghi Mongo chạy sau commit trên luồng nền; luồng nền chờ tối đa 5 s chọn server (`serverSelectionTimeoutMS=5000`) rồi chỉ ghi log. Cái mất: log OCR và chỗ sửa OCR của khoảng thời gian đó không có cơ chế tự chữa (hạn chế L2). App khởi động không cần MongoDB.
- Báo cáo: mục 7.3, 4.7.
- File: `docker-compose.yml:116,232-236,285-288`, `J/Service/OcrMongoService.java:91-130`; test TC-30.

### 8. Nhất quán giữa các CSDL ra sao? Có thể mất dữ liệu không?
PostgreSQL nhất quán mạnh. Redis, MongoDB, Elasticsearch cập nhật sau commit, bất đồng bộ, nhất quán cuối cùng. Có cửa sổ mất: JVM chết giữa lúc PostgreSQL commit và lúc tác vụ nền chạy xong thì thay đổi đó chỉ được chữa ở lần đổi kế tiếp của cùng dòng, khi dựng lại hoặc reindex; log và chỗ sửa OCR bị mất thì không tự chữa. Hàng đợi `mongoAsyncExecutor` đầy (500) thì bỏ tác vụ và ghi cảnh báo; cập nhật chỉ mục hỏng không được thử lại; một executor chung cho cả ba CSDL (L2, L3, L4, L20). Rollback thì NoSQL không đổi gì. Hướng đóng cửa sổ này: Outbox.
- Báo cáo: mục 4.7 ("Cửa sổ mất dữ liệu và cách chữa"), 7.4.
- File: `J/Config/AsyncConfig.java:20-34`, `J/Service/Search/TransactionSearchIndexer.java:117-134`; `docs/nosql/facts.md` §3 (L2–L4, L17–L20).

### 9. Vì sao dùng sự kiện sau commit mà không dùng Outbox, Change Streams hay Kafka?
Không thêm hạ tầng, rollback không rò rỉ, NoSQL lỗi không làm hỏng nghiệp vụ. Outbox giải quyết được cửa sổ mất dữ liệu nhưng cần bảng, tiến trình chuyển, đánh dấu đã gửi và xử lý gửi lặp: để làm sau (hướng phát triển đầu tiên). Change Streams đọc thay đổi của MongoDB trong khi nguồn thay đổi ở đây là PostgreSQL, và cần replica set. Kafka/RabbitMQ thêm một hệ thống nữa trên máy nhỏ, Elasticsearch 1 GB đã hết dư.
- Báo cáo: mục 4.7 (bảng so sánh cơ chế đồng bộ), 8.5.
- File: `docs/nosql/build/content_c4.py` (C4_7); `J/Service/Cache/StatisticsCacheEvictor.java:12-36`.

---

## C. Kỹ thuật

### 10. Vì sao dùng Lua trong Redis?
Để một chuỗi thao tác chạy nguyên tử trên một khóa, không có lệnh nào chen vào giữa. OTP: kiểm tra mã, so hạn, tăng số lần sai, xóa khi đúng hoặc sai đủ lần là một script, nên hai instance song song vẫn chỉ cân đúng 3 lần sai (TC-04). Bảng xếp hạng: `EXISTS` rồi `ZADD`/`ZREM` trong một script để không tạo lại set vừa hết hạn thành set một phần tử không có TTL (TC-15). Mỗi script chỉ dùng một khóa nên tương thích Redis Cluster nếu sau này cần.
- Báo cáo: mục 4.3 (Script Lua), 4.13 (xử lý tranh chấp).
- File: `J/Service/RedisPasswordResetOtpStore.java:33-60`, `J/Service/Cache/SpendingLeaderboardService.java:54-64,155-170`.

### 11. Vì sao bảng xếp hạng ghi tổng tuyệt đối bằng `ZADD`, không dùng `ZINCRBY`?
`ZINCRBY` cộng chênh lệch: nếu một sự kiện mất hoặc chạy hai lần, điểm sai mãi. Ghi tổng tuyệt đối đọc lại từ PostgreSQL thì lần cập nhật kế tiếp của người đó tự sửa điểm, sự kiện lặp hay đến muộn vô hại. Hạn chế còn lại: hai tác vụ chạy xen nhau có thể để tổng cũ tới lần đổi sau hoặc hết TTL 62 ngày (L18). Q-25 trong `redis_demo.txt` minh họa khác biệt.
- Báo cáo: mục 4.13 (đoạn "Bảng xếp hạng"), 7.4.
- File: `J/Service/Cache/SpendingLeaderboardService.java:36-40,141-153`, `S/redis_demo.txt` (Q-25); test TC-14.

### 12. Vì sao dùng `$setOnInsert` và unique index khi ghi chỗ sửa OCR?
Mỗi cặp (hóa đơn, trường) chỉ được có một document. Bước 1 `updateFirst` ghi đè khi giá trị sửa khác và mở lại `isResolved=false`; bước 2 `upsert` chỉ với `$setOnInsert`, nên không đụng document đã có cùng giá trị (gửi lại y nguyên giữ trạng thái đã xử lý, TC-21). Hai luồng cùng tạo thì unique `receipt_field_uq {receiptId, fieldError}` chặn luồng thua, chỉ ghi log. Từ 59983b9, đánh dấu "đã xử lý" là một `findAndModify` nguyên tử chỉ `$set isResolved`, không đọc rồi `save` cả document.
- Báo cáo: mục 4.13 ("Chỗ sửa OCR"), 4.4.
- File: `J/Service/OcrMongoService.java:145-216,260-293`, `S/mongodb_init.js:125-139`; test TC-20..22, TC-48.

### 13. Thứ tự trường trong index theo quy tắc ESR là gì? Áp dụng ra sao?
ESR = Equality, Sort, Range: trường so bằng đứng trước, rồi trường sắp xếp, rồi trường khoảng. Truy vấn Q-03 "chưa xử lý, mới nhất trước" là `isResolved` (bằng) rồi `reportedAt` (sắp xếp), nên index `status_date_idx {isResolved:1, reportedAt:-1}`: IXSCAN, 5 key = 5 document = 5 trả về, p50 0,33 ms so với COLLSCAN 21,8 ms (65×).
- Báo cáo: mục 4.4 (bảng index), 4.13 (tối ưu CSDL).
- File: `S/mongodb_init.js:125-139`, `J/Document/OcrFeedback.java:14`; Q-16 trong `S/mongodb_demo.js:267-286`; `docs/nosql/diagrams/bench_E1.png`.

### 14. Có truy vấn nào không đạt mục tiêu NFR-05 không?
Có, nhóm ghi thẳng: Q-02 ("độ tin cậy dưới 0,75, mới nhất trước") dùng index `createdAt` và phải kiểm tra 61 document để trả 5, nên vế "totalDocsExamined = nReturned" không đạt; p95 vẫn 0,51 ms. Nguyên nhân: điều kiện là khoảng (R) còn sắp xếp là `createdAt` (S); `score_date_idx` đặt R trước S nên bị bỏ qua. Index đúng theo ESR sẽ là `{createdAt:-1, averageConfidenceScore:1}`; chưa tạo vì dữ liệu thật của DONUT V5 không có độ tin cậy.
- Báo cáo: mục 4.4, 7.2, 7.4.
- File: `docs/nosql/bench_results.md` (E1 và "Tổng hợp NFR").

### 15. Vì sao `ocr_feedbacks` tham chiếu `ocr_logs` bằng `transactionId`, không nhúng?
Hai document ghi ở hai thời điểm khác nhau, một log có 0 đến 3 chỗ sửa và chỗ sửa còn được cập nhật, xóa riêng. Đo E5 trên dữ liệu tổng hợp 100k: theo người dùng, bản nhúng chỉ nhanh hơn 2,5× (0,64 ms so với 1,63 ms) mà tốn thêm 12,2 MB dữ liệu lặp. Con số 871,6 ms của Q-13 nguyên bản là giá của `$lookup` đặt muộn; đặt `$sort`/`$limit` trước `$lookup` còn 0,75 ms. Nhóm giữ tham chiếu.
- Báo cáo: mục 4.4 (bảng embed/reference), 7.2 (E5).
- File: `docs/nosql/bench_results.md` (E5), `docs/nosql/diagrams/bench_E5.png`.

---

## D. Tìm kiếm tiếng Việt

### 16. Analyzer tiếng Việt của Elasticsearch làm gì? Gõ không dấu vì sao vẫn ra?
Analyzer `vi_folded` = tokenizer `standard` + `lowercase` + `asciifolding`: "Phở" thành token `pho`, nên "pho" và "phở" cho cùng tập kết quả (10/10 cặp thử). `vi_autocomplete` thêm `edge_ngram` 2..15 cho gợi ý khi đang gõ. Sai chính tả được bắt bằng nhánh `fuzziness AUTO:4,7`, `prefix_length 1`. Giới hạn cần nói: đây là bỏ dấu, không phải tách từ tiếng Việt (không có bộ tách từ ghép), và còn dương tính giả theo tiền tố (ví dụ "pho" khớp "phòng").
- Báo cáo: mục 4.5 (settings, analyzer, mapping), 7.2 (chất lượng kết quả).
- File: `R/elasticsearch/transactions-settings.json:4-9`, `R/elasticsearch/transactions-mapping.json`, `J/Service/Search/ElasticsearchTransactionSearchEngine.java:17-81`; Q-34, Q-35, Q-36 (`S/elasticsearch/kibana-devtools.txt`); test TC-32..TC-34.

### 17. Elasticsearch nhanh hơn PostgreSQL bao nhiêu? Có luôn nhanh hơn không?
Không luôn. Người dùng nặng (19.788 giao dịch): Elasticsearch p50 3,70 ms, LIKE 78,2 ms (21×). Người dùng điển hình (~80 dòng): LIKE nhanh hơn (0,66 ms so với 3,70 ms). Elasticsearch thắng ở chất lượng: "pho" bỏ sót 0 so với 1.376/1.517 dòng của LIKE; LIKE `%…%` quét hết giao dịch của người dùng và không có index nào giúp. Số đo là dữ liệu tổng hợp 100k, tầng dữ liệu, một luồng.
- Báo cáo: mục 7.2 (E2), 4.13 (bảng trước/sau).
- File: `docs/nosql/bench_results.md` (E2), `docs/nosql/diagrams/bench_E2.png`.

### 18. Vì sao không dùng Cassandra và Neo4j?
Cassandra mạnh ở ghi lớn liên tục theo thời gian, nhiều trung tâm dữ liệu; luồng ghi lớn nhất ở đây là vài giao dịch mỗi người mỗi ngày và một log AI mỗi hóa đơn, không có AP nào cần partition theo thời gian ở quy mô đó, và cụm cần ≥ 3 node trong khi Elasticsearch 1 GB đã chạm giới hạn máy. Neo4j mạnh ở duyệt quan hệ nhiều tầng; quan hệ ở đây nông, một chiều (người dùng → giao dịch → hóa đơn → lần đọc AI), không AP nào duyệt từ hai bước; JOIN của PostgreSQL và `$lookup` một bước là đủ.
- Báo cáo: mục 4.6 (bảng), 4.2.
- File: `docs/nosql/build/content_c4.py` (C4_6).

---

## E. Realtime

### 19. Vì sao dùng SSE mà không dùng WebSocket?
Nhu cầu chỉ một chiều: server báo cho trình duyệt quản trị (toast, badge). SSE chạy trên HTTP thường, `EventSource` của trình duyệt tự nối lại, đi qua Caddy và phiên đăng nhập sẵn có (luồng chỉ ROLE_ADMIN, kết thúc cùng phiên; heartbeat 25 s giữ luồng khỏi bị proxy đóng). WebSocket cần khi hai chiều hoặc dữ liệu nhị phân, ở đây thêm giao thức riêng mà không có lợi. Lưu ý trung thực: báo cáo không có phép đo so sánh SSE với WebSocket; đây là lý do thiết kế.
- Báo cáo: mục 4.13 (Realtime: Redis Pub/Sub và SSE), 6.4.
- File: `J/Controller/AdminEventsController.java:19-48`, `J/Service/Realtime/AdminEventRelay.java:24-123`, `R/static/admin/js/admin-events.js:2-13`.

### 20. Realtime có mất tin không? Chạy nhiều instance thì sao? Độ trễ bao nhiêu?
Pub/Sub của Redis không lưu tin: không ai nghe thì mất (at-most-once); chấp nhận vì chỉ là thông báo, dữ liệu thật vẫn đọc ở trang quản trị. Nhiều instance dùng chung Redis: một `PUBLISH` tới SSE của cả hai instance (TC-17); instance khởi động lúc Redis chưa chạy vẫn chạy rồi tự đăng ký lại (TC-18). Đo phía server (JUnit, 300 sự kiện): p50 1,18 ms, p95 1,57 ms, mất 0/300. Chặng server tới trình duyệt chưa đo, nên con số là cận dưới. Realtime chỉ có trên web quản trị; push mobile (FCM) là hướng phát triển.
- Báo cáo: mục 4.13, 7.2 (E6), 6.4.
- File: `core-backend/src/test/java/vn/edu/huit/finance/core/Service/Realtime/AdminEventLatencyBench.java`, `docs/nosql/bench_raw/E6.json`; ảnh `docs/nosql/screenshots/S-88.png`.

---

## F. Sao lưu và khôi phục

### 21. Sao lưu và khôi phục MongoDB được chứng minh thế nào?
Quy trình đếm, sao lưu, xóa, khôi phục, đếm lại. Từ trang `/admin/backup` thẻ MongoDB: `mongodump --archive --gzip` rồi `mongorestore --drop` hai collection `ocr_logs`, `ocr_feedbacks`; mật khẩu không vào tham số hay log, mỗi lần chạy một lúc. Test tích hợp `MongoBackupServiceIntegrationTest` (TC-29) dump, xóa, restore trên MongoDB thật và kiểm hai collection trở lại, collection khác không bị đụng. Trên stack demo (dữ liệu demo 36 + 36 document, 13 index): đếm khớp 100%, `mongorestore` trung vị 0,543 s (NFR-13 đạt). Thời gian bấm "Khôi phục" trên web (S-66) chưa đo.
- Báo cáo: mục 5.6, 7.1, 7.2.
- File: `J/Service/MongoBackupService.java:31-175`, `S/backup_restore.md` (mục 1a), `docs/nosql/bench_raw/task4_backup.json`; ảnh S-61, S-65, S-66.

### 22. Redis và Elasticsearch có sao lưu không?
Redis không cần sao lưu: dữ liệu dựng lại được từ PostgreSQL (cache, bảng xếp hạng), chỉ OTP đang chờ mất và người dùng xin mã mới (L7); RDB chỉ minh họa (Q-29, S-63). Elasticsearch: snapshot vào `path.repo` qua Kibana hoặc script (S-64, đếm trước và sau khớp), hoặc reindex từ PostgreSQL (`POST /api/admin/search/reindex`; từ 59983b9 phân trang theo khóa). Trang web chỉ có nút cho PostgreSQL và MongoDB (L11).
- Báo cáo: mục 5.6, 4.9 (bảng sao lưu).
- File: `S/backup_restore.md:110-188`, `J/Service/Search/TransactionSearchIndexer.java:169-199`.

---

## G. Bảo mật

### 23. Hệ thống chống injection và lộ dữ liệu người khác thế nào? Có lỗ hổng nào còn mở không?
Mongo: không ghép chuỗi truy vấn, không dùng `$where`; dùng `Criteria` của Spring Data với tham số có kiểu, sort chỉ nhận `reportedAt` hoặc `updatedAt`, nên giá trị người dùng luôn là giá trị BSON, không thành toán tử (TC-24). Elasticsearch: văn bản người dùng là giá trị của `multi_match`, không `query_string`. SQL: tham số JPQL, mẫu LIKE thoát `\ % _`. Dữ liệu người khác: tìm kiếm lọc `userId` ở Elasticsearch rồi nạp lại theo chủ sở hữu ở PostgreSQL; khóa cache có `userId` (TC-07, TC-35, TC-37, TC-44). Phân quyền hai lớp cho `/admin/**` và `/api/admin/**`. Còn mở, nhóm đã ghi trong báo cáo: web quản trị đang tắt CSRF (`SecurityConfig.java:76`), phải bật lại trước khi triển khai; kết nối tới CSDL trong mạng nội bộ Docker không mã hóa.
- Báo cáo: mục 4.9 (bảng bảo mật).
- File: `J/Service/Search/ElasticsearchTransactionSearchEngine.java:18-21`, `J/Repository/TransactionRepository.java:149-189`, `J/Config/SecurityConfig.java:75-86,141-157`.

---

## H. Số đo, triển khai, công cụ

### 24. Các số đo trong báo cáo có đáng tin không? Đo ở đâu?
Đo độ trễ tầng dữ liệu từ client Python cùng mạng docker, một luồng, 200 lần khởi động rồi 1.200 lần đo, phân vị nearest-rank, cache đã ấm, giới hạn container như `docker-compose.yml`. Dữ liệu tổng hợp 100k (seed 42, sinh bằng `gen_data.py`, có checksum), không phải dữ liệu người dùng thật. Không qua Spring, JPA, JWT hay mạng ngoài, nên số tuyệt đối sẽ khác; tỉ lệ giữa các bên và kế hoạch truy vấn mới là điều đáng tin. JMeter ở mức ứng dụng chưa chạy, nên độ trễ API đầu cuối chưa có số. Số nào chưa đo thì ghi "mục tiêu".
- Báo cáo: mục 7.2 ("Giới hạn của phép đo"), 1.2.
- File: `docs/nosql/bench_results.md` (mục 0 và "Giới hạn của phép đo"), `scripts/nosql/bench/`.

### 25. Server thật đang chạy Elasticsearch không?
Chưa nói được: hosting chưa chốt, chưa triển khai. Mặc định `SEARCH_ENGINE=postgres`; Elasticsearch bật bằng profile `search` của Docker Compose cùng `SEARCH_ENGINE=elasticsearch`. Mọi số liệu và demo chạy trên máy phát triển và stack demo (`scripts/nosql/demo-stack.sh`).
- Báo cáo: mục 1.5 (công nghệ), 7.4 (L15).
- File: `docker-compose.yml:265`, `R/search.properties:6`.

### 26. Máy chạy được cả bốn CSDL cùng lúc không? Tài nguyên ra sao?
Chạy được nhưng sát. Đo `docker stats` trên stack demo với giới hạn như compose: Redis 6,1 MiB / 192 MiB; MongoDB 84,2 MiB / 512 MiB; Elasticsearch 997 MiB / 1 GiB (97,4%). Bật thêm Kibana thì Elasticsearch ở mức 1 GiB bị kernel giết tiến trình java (khởi động lại, NFR-14 không đạt); nên chụp Kibana với Elasticsearch 1,5 GB, hoặc chỉ bật Kibana khi cần quản trị. Elasticsearch và Kibana nằm ngoài profile mặc định.
- Báo cáo: mục 7.2 (bảng bộ nhớ), 2.5.1.
- File: `docs/nosql/bench_results.md` (mục "Tài nguyên – NFR-14"), `docker-compose.yml:143-215`; ảnh S-89.

### 27. Kibana khác Elasticvue ở đâu? Vì sao chọn Kibana?
Kibana 8.11.4 đủ sáu nhóm chức năng của tiêu chí (quản lý index, Dev Tools, import/export, snapshot/restore, user/role, thống kê) và có Discover, Dashboards; nặng: RAM 631 MiB, image 1,67 GB, trang đầu 1,38 s, giấy phép ELv2 (mã nguồn SSPL/ELv2). Elasticvue 1.16.0 nhẹ: RAM 10,5 MiB, image 105 MB, trang đầu 0,25 s, MIT, chạy trong trình duyệt nên cần bật CORS, không có dashboard hay nhập file. Việc quản trị có tổ chức (snapshot, phân quyền, xuất dữ liệu, minh chứng truy vấn) làm trên Kibana; xem nhanh dùng Elasticvue. Số đo ngày 28/10/2026, trung vị 5 lần. Kibana hợp ứng dụng phân tích log/số liệu trên Elasticsearch; trong LedgerMind nó chỉ là công cụ quản trị.
- Báo cáo: mục 2.5 (2.5.3 bảng so sánh, 2.5.4).
- File: `docs/nosql/build/content_c1_c2.py:460-499`, `docs/nosql/bench_results.md` (mục Kibana và Elasticvue); ảnh S-14.

---

## I. Phân công và hạn chế

### 28. Ai làm phần nào?
Theo bảng phân công thật của báo cáo (`facts.md` §0 [Q3]). Phan Thanh Trí (nhóm trưởng, khoảng 60%): phân tích, kiến trúc, toàn bộ code (PostgreSQL, Redis, Elasticsearch, trang quản trị, realtime, sao lưu) và dựng báo cáo. Phan Minh Tiến (khoảng 40%): MongoDB (truy vấn Q-01..Q-16, minh chứng trên Compass), tìm hiểu Kibana và Elasticvue (mục 2.5), chụp ảnh trên stack demo, chạy lại script và sao lưu/khôi phục, soát Chương 2 và 5, slide, video demo, soát chính tả. Tiến không viết phần code đã có. Một số ảnh GUI tool được công cụ tự chụp trên stack demo và không ghi công cho ai. Ngày bắt đầu/kết thúc từng việc nhóm điền theo thực tế, vì lịch sử git của Trí cùng một tài khoản.
- Báo cáo: mục 1.6 (bảng phân công), 8.3.
- File: `docs/nosql/HUONG_DAN_TIEN.md` (T1–T10), `docs/nosql/screenshots.md` (cột "Người chụp"), `docs/nosql/facts.md` §0.

### 29. Hạn chế lớn nhất của hệ thống là gì? Làm tiếp thì làm gì?
Hạn chế: (1) chế độ tìm kiếm PostgreSQL không bỏ dấu; (2) ghi NoSQL sau commit, bất đồng bộ, JVM chết giữa chừng thì chờ lần đổi sau hoặc reindex, log/chỗ sửa OCR mất không tự chữa; (3) một node mỗi CSDL, không replication hay sharding (replica set, Sentinel, cluster mới ở mức thiết kế); (4) realtime chỉ trên web, Pub/Sub at-most-once; (5) DONUT V5 không trả độ tin cậy (null); (6) Redis không lưu đĩa nên OTP đang chờ mất khi khởi động lại; (7) Elasticsearch 1 GB không đủ khi bật Kibana; (8) Q-02 chưa đạt "docs = nReturned"; (9) chưa có API cho thống kê Elasticsearch theo danh mục/tháng; (10) CSRF web quản trị còn tắt; (11) chưa triển khai server thật. Hướng phát triển: Outbox (đóng cửa sổ mất dữ liệu), push mobile FCM, MongoDB replica set, Redis Sentinel, Elasticsearch nhiều node, Prometheus + Grafana, tìm kiếm bỏ dấu ở PostgreSQL (`unaccent`, trigram).
- Báo cáo: mục 7.4 (bảng hạn chế), 8.5 (hướng phát triển).
- File: `docs/nosql/facts.md` §3 (L1–L20), `docs/nosql/build/content_c7_c9.py` (LIMITS, C7_4).

---

## Ghi chú cập nhật

- Các sửa lỗi ngày 28/10/2026 (commit 59983b9) đã phản ánh trong câu 6, 12, 22: tìm kiếm chuyển ngay sang PostgreSQL khi chỉ mục đang dựng lại; reindex phân trang theo khóa; xóa tài khoản dọn Elasticsearch và `ocr_feedbacks` của người đó (`ocr_logs` không có `userId` nên giữ); đánh dấu đã xử lý là thao tác nguyên tử.
- Hai ô `____ ms` ở câu 5 và 6 chỉ điền được sau khi quay demo dừng dịch vụ (bảng mục 7.3, hằng `LAT` trong `docs/nosql/build/content_c7_c9.py`). Chưa có thì nói rõ là chưa đo.
