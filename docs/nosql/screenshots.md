# Danh sách ảnh chụp màn hình S-01..S-89 (báo cáo NoSQL nhóm 38)

Mã S-xx, mục báo cáo, nội dung và người chụp lấy **nguyên** từ `docs/nosql/facts.md` §2.6 (đóng băng 27/10/2026); không thêm
mã mới. File ảnh: `docs/nosql/screenshots/S-xx.png`. Ảnh chưa chụp là ảnh giữ chỗ màu xám "S-xx – chưa chụp" (sinh bằng
`python3 docs/nosql/build/make_placeholder_png.py --all`, mang khóa PNG `ledgermind-placeholder`, `check_report.py` dùng khóa
này để liệt kê ảnh còn thiếu). Ai chụp thì lưu đè đúng tên file; script giữ chỗ không bao giờ ghi đè ảnh thật.

**Người chụp:** `agent` = Task 4 chụp tự động ngày 28/10/2026 bằng `docs/nosql/build/capture_tools.py` (Playwright Chromium
headless + ảnh terminal dựng từ đúng lệnh và đúng kết quả in ra) trên stack demo `scripts/nosql/demo-stack.sh`; ảnh agent
không ghi công cho ai ([Q3]). `Tiến` / `Trí` = người dùng chụp tay (cột theo facts §2.6; ai chụp thật thì sửa lại cột này
trước khi viết 1.6/8.3).

**Stack demo cho ảnh của người dùng** ([Q8]): `scripts/nosql/demo-stack.sh up` (hướng dẫn `scripts/nosql/demo-stack.README.md`;
Compass `mongodb://root:demo-mongo-pass@127.0.0.1:27018/?authSource=admin`, RedisInsight http://localhost:5541, Kibana
http://localhost:5602 `elastic`/`demo-elastic-pass`, Elasticvue http://localhost:8081). Stack demo **không có app**: ảnh app
mobile, trang admin, Postman/Swagger cần app LedgerMind chạy (stack của Trí, hoặc app trỏ vào CSDL của stack demo); ảnh
"dừng dịch vụ" (S-83, S-84) cần stack đầy đủ của Trí.

Lưu ý chung cho ảnh agent: (a) ảnh Kibana/Elasticvue chụp khi Elasticsearch của stack demo giới hạn **1536M**, không phải 1G
như compose, vì ở 1G Elasticsearch bị OOM-kill khi Kibana bật (đo ở S-89, `bench_results.md` mục NFR-14); (b) tài khoản,
role, repository và snapshot thấy trong ảnh là đối tượng thật, tạo bằng API ngay trước khi chụp (lệnh trong
`capture_tools.py`, hàm `kibana`); (c) ảnh terminal giữ nguyên kết quả lệnh, chỉ thay mật khẩu bằng `***` hoặc dùng biến môi
trường trong container; (d) ảnh ghép hai cửa sổ (S-06, S-11, S-13, S-60) là hai ảnh thật xếp chồng, vạch xám ở giữa.

Chụp lại toàn bộ ảnh agent: `scripts/nosql/demo-stack.sh up`, rồi lần lượt `python3 docs/nosql/build/capture_tools.py`
`terminal-setup`, `kibana`, `kibana-extra`, `kibana-csv`, `elasticvue`, `redisinsight`, `redisinsight-pubsub`,
`terminal-backup`, `measure-tools`, `terminal-e6`; `docker-stats` (S-89) chạy với `NOSQL_DEMO_ES_MEMORY=1G`.

| ID | Mục | Nội dung (facts §2.6) | Công cụ | Cách chụp (bước / lệnh) | Người chụp | Trạng thái |
|---|---|---|---|---|---|---|
| S-01 | 2.5 (tc 1) | Elasticsearch container healthy + đặt mật khẩu `kibana_system` (terminal) | Terminal | `docker ps` (healthy), `_cluster/health`, curl không đăng nhập → 401, `POST _security/user/kibana_system/_password` → `{}`, `_authenticate` bằng `kibana_system`, Kibana `overall: available` | agent | đã chụp |
| S-02 | 2.5 (tc 1) | Kibana sau khi cài: trang đăng nhập / Home | Kibana | đăng nhập `elastic` → "Explore on my own" → Home ("Welcome home") | agent | đã chụp |
| S-03 | 2.5 (tc 2) | Index Management: index `transactions`, settings/mapping | Kibana | Stack Management → Index Management → `transactions` → tab Mappings (analyzer `vi_folded`, trường con `.autocomplete`) | agent | đã chụp |
| S-04 | 2.5 (tc 2) | Dev Tools chạy truy vấn | Kibana | Dev Tools → Console: `GET transactions/_search` match `vendorName: "pho"` của user 1 → 4 hit "Phở …" | agent | đã chụp |
| S-05 | 2.5 (tc 2) | Import: Upload file / Data Visualizer | Kibana | Integrations → Upload file → `giao_dich_mau.csv` (47 giao dịch demo xuất ra CSV) → Import vào index `giao_dich_csv` → "Import complete" (5 bước xanh) | agent | đã chụp |
| S-06 | 2.5 (tc 2) | Export dữ liệu (Discover → Share → CSV, nếu bản Basic có; nếu không thì ghi rõ) | Kibana | Discover (data view `transactions`, 08–10/2026, 47 hits) → Share → CSV Reports → Generate csv; dưới: Stack Management → Reporting "Done, warnings detected". Bản Basic **có** CSV; cảnh báo là `csv_contains_formulas` (job hoàn tất, 47 dòng, 9.764 byte) | agent | đã chụp (ảnh ghép 2 cửa sổ) |
| S-07 | 2.5 (tc 2) | Snapshot and Restore: repository + snapshot | Kibana | repository `demo_repo` (fs) + snapshot `snap-2026-10-28` tạo bằng API → Stack Management → Snapshot and Restore (1 index, 0 failed shard) | agent | đã chụp |
| S-08 | 2.5 (tc 2) | Security: Users/Roles (role chỉ đọc index transactions) | Kibana | role `transactions_read` (index `transactions`: `read`, `view_index_metadata`) + user `tien_viewer` tạo bằng API → Roles → Edit role | agent | đã chụp |
| S-09 | 2.5 (tc 2) | Giám sát: Index Management stats / `_cat` (không có Stack Monitoring vì chưa cài Metricbeat) | Kibana | Index Management → `transactions` → tab Statistics (docs, store, indexing). Stack Monitoring không dùng (cần Metricbeat, không cài) | agent | đã chụp |
| S-10 | 2.5 (tc 1) | Elasticvue: kết nối cluster (cài bằng docker) | Elasticvue | image `cars10/elasticvue`, cluster đặt sẵn qua `ELASTICVUE_CLUSTERS` (Basic auth `elastic`, CORS) → Home: green, 8.11.4 | agent | đã chụp |
| S-11 | 2.5 (tc 3) | Elasticvue: danh sách index, document, tìm kiếm | Elasticvue | trên: Indices lọc `transactions` (47 docs); dưới: Search, index `transactions`, từ khóa `phở` → 10 hit | agent | đã chụp (ảnh ghép) |
| S-12 | 2.5 (tc 3) | Elasticvue: REST query | Elasticvue | REST → POST `transactions/_search?filter_path=hits.total,aggregations`, aggs terms `categoryName.keyword` của user 1 → 200 OK | agent | đã chụp |
| S-13 | 2.5 (tc 3) | Elasticvue: snapshot / repositories | Elasticvue | trên: Snapshot Repositories (`demo_repo`); dưới: snapshot `snap-2026-10-28` SUCCESS | agent | đã chụp (ảnh ghép) |
| S-14 | 2.5 (tc 3) | `docker stats` RAM/CPU Kibana vs Elasticvue + thời gian tải trang đầu (đo) | Terminal | `docker stats` (Kibana 631 MiB, Elasticvue 10,5 MiB), kích thước image, `capture_tools.py measure-tools` (5 lần, cache trống): Kibana /login 1,38 s, Home sau đăng nhập 1,74 s; Elasticvue 0,25 s | agent | đã chụp |
| S-15 | 5.2 | Compass: database `finance_nosql`, tab Validation `$jsonSchema` | Compass | Compass nối stack demo → `finance_nosql` → `ocr_logs` (và `ocr_feedbacks`) → tab Validation | Tiến | giữ chỗ |
| S-16 | 5.2 | Compass: tab Indexes của `ocr_feedbacks` | Compass | `finance_nosql.ocr_feedbacks` → tab Indexes (thấy `receipt_field_uq`, `status_date_idx`, …) | Tiến | giữ chỗ |
| S-17 | 5.3 | Compass: `finance_nosql_demo` 36 + 36 document | Compass | danh sách collection của `finance_nosql_demo` (Documents 36 / 36); chụp ngay sau `demo-stack.sh up` hoặc `load` | Tiến | giữ chỗ |
| S-18 | 5.2–5.3 | RedisInsight: danh sách key `ledgermind:*` kèm kiểu và TTL | RedisInsight | Browse, List view, lọc `ledgermind:*` (5 key: STRING, SORTED SET, HASH; cột TTL, size), mở hash OTP (TTL 290 s) | agent | đã chụp |
| S-19 | 5.2–5.3 | Tạo index `transactions` + bulk 47 document (`_count`) | Kibana Dev Tools | Console: `DELETE transactions` → `PUT transactions` (settings + mapping thật của app) → `POST _bulk` (`"errors": false`) → `GET transactions/_count` = 47 | agent | đã chụp |
| S-20 | 5.4 | Kết quả Q-01 | Compass | Compass, `finance_nosql_demo.ocr_logs`, Filter/Project của Q-01 (`scripts/nosql/mongodb_demo.js:112-115`) | Tiến | giữ chỗ |
| S-21 | 5.4 | Kết quả Q-02 | Compass | Filter `{averageConfidenceScore:{$lt:0.75}}`, Sort `{createdAt:-1}`, Limit 5 (`mongodb_demo.js:117-121`) | Tiến | giữ chỗ |
| S-22 | 5.4 | Kết quả Q-03 | Compass | `ocr_feedbacks` Filter `{isResolved:false}` Sort `{reportedAt:-1}` (`mongodb_demo.js:123-127`) | Tiến | giữ chỗ |
| S-23 | 5.4 | Kết quả Q-04 | Compass (mongosh) | mongosh trong Compass: `countDocuments` + `distinct` (`mongodb_demo.js:129-136`) | Tiến | giữ chỗ |
| S-24 | 5.4 | Kết quả Q-05 | Compass (mongosh) | `insertOne` sai kiểu → lỗi 121 (`mongodb_demo.js:138-146`) | Tiến | giữ chỗ |
| S-25 | 5.4 | Kết quả Q-06 | Compass (mongosh) | `insertOne` trùng → lỗi 11000 (`mongodb_demo.js:148-156`) | Tiến | giữ chỗ |
| S-26 | 5.4 | Kết quả Q-07 | Compass | sửa `isResolved` thành `true` trên một document (`mongodb_demo.js:158-164`) | Tiến | giữ chỗ |
| S-27 | 5.4 | Kết quả Q-08 | Compass | xóa một document (`mongodb_demo.js:166-171`); chạy `demo-stack.sh load` sau đó để có lại 36 + 36 | Tiến | giữ chỗ |
| S-28 | 5.5 | Kết quả Q-09 | Compass (mongosh) | hai `updateOne` có `$ne` / `$setOnInsert` upsert (`mongodb_demo.js:173-201`) | Tiến | giữ chỗ |
| S-29 | 5.5 | Kết quả Q-10 | Compass Aggregations | pipeline `$match/$group/$sort` (`mongodb_demo.js:203-210`) | Tiến | giữ chỗ |
| S-30 | 5.5 | Kết quả Q-11 | Compass Aggregations | `$group` theo `modelVersion` (`mongodb_demo.js:212-218`) | Tiến | giữ chỗ |
| S-31 | 5.5 | Kết quả Q-12 | Compass Aggregations | `$dateToString` + `$avg` (`mongodb_demo.js:220-228`) | Tiến | giữ chỗ |
| S-32 | 5.5 | Kết quả Q-13 | Compass Aggregations | `$lookup` `ocr_logs` + `$unwind` (`mongodb_demo.js:230-241`) | Tiến | giữ chỗ |
| S-33 | 5.5 | Kết quả Q-14 | Compass Aggregations | `$facet` (`mongodb_demo.js:243-253`) | Tiến | giữ chỗ |
| S-34 | 5.5 | Kết quả Q-15 | Compass Aggregations | `$lookup` + `$group` + `$divide` (`mongodb_demo.js:255-265`) | Tiến | giữ chỗ |
| S-35 | 5.5 | Kết quả Q-16 (Explain Plan IXSCAN) | Compass Explain | Explain Plan của truy vấn Q-03 → IXSCAN `status_date_idx` (`mongodb_demo.js:267-286`) | Tiến | giữ chỗ |
| S-36 | 5.4 | Kết quả Q-17 | RedisInsight | Workbench, Group results, các lệnh Q-17 của `redis_demo.txt` (ECHO bỏ đi) → thẻ kết quả mở toàn màn hình | agent | đã chụp |
| S-37 | 5.4 | Kết quả Q-18 | RedisInsight | như S-36, lệnh Q-18 (HINCRBY…EXISTS → 0) | agent | đã chụp |
| S-38 | 5.4 | Kết quả Q-19 | RedisInsight | như S-36, lệnh Q-19 | agent | đã chụp |
| S-39 | 5.4 | Kết quả Q-20 | RedisInsight | như S-36, lệnh Q-20 | agent | đã chụp |
| S-40 | 5.4 | Kết quả Q-21 | RedisInsight | như S-36, lệnh Q-21 (SCAN … TYPE string) | agent | đã chụp |
| S-41 | 5.5 | Kết quả Q-22 | RedisInsight | như S-36, lệnh Q-22 | agent | đã chụp |
| S-42 | 5.5 | Kết quả Q-23 | RedisInsight | như S-36, lệnh Q-23 (top 3: user 4, 2, 1) | agent | đã chụp |
| S-43 | 5.5 | Kết quả Q-24 | RedisInsight | như S-36, lệnh Q-24 | agent | đã chụp |
| S-44 | 5.5 | Kết quả Q-25 | RedisInsight | như S-36, lệnh Q-25 | agent | đã chụp |
| S-45 | 5.5 | Kết quả Q-26 | RedisInsight | như S-36, lệnh Q-26 (MULTI … EXEC) | agent | đã chụp |
| S-46 | 5.5 | Kết quả Q-27 | RedisInsight | như S-36, lệnh Q-27 (EVAL → 1, 1, 2, 0, -1; EXISTS 0) | agent | đã chụp |
| S-47 | 5.5 | Kết quả Q-28 | RedisInsight | như S-36, lệnh Q-28 | agent | đã chụp |
| S-48 | 5.4 | Kết quả Q-29 | RedisInsight | như S-36, lệnh Q-29 (`save ""`, `appendonly no`, BGSAVE, INFO persistence) | agent | đã chụp |
| S-49 | 5.4 | Kết quả Q-30 | Kibana Dev Tools | Console: dán nguyên khối Q-30 của `scripts/nosql/elasticsearch/kibana-devtools.txt` (cả chú thích), chọn hết, Send | agent | đã chụp |
| S-50 | 5.4 | Kết quả Q-31 | Kibana Dev Tools | như S-49, khối Q-31 | agent | đã chụp |
| S-51 | 5.4 | Kết quả Q-32 | Kibana Dev Tools | như S-49, khối Q-32 | agent | đã chụp |
| S-52 | 5.4 | Kết quả Q-33 | Kibana Dev Tools | như S-49, khối Q-33 | agent | đã chụp |
| S-53 | 5.4 | Kết quả Q-34 | Kibana Dev Tools | như S-49, khối Q-34 (hai `_analyze`) | agent | đã chụp |
| S-54 | 5.5 | Kết quả Q-35 | Kibana Dev Tools | như S-49, khối Q-35 (4 hit "Phở …" của user 1) | agent | đã chụp |
| S-55 | 5.5 | Kết quả Q-36 | Kibana Dev Tools | như S-49, khối Q-36 | agent | đã chụp |
| S-56 | 5.5 | Kết quả Q-37 | Kibana Dev Tools | như S-49, khối Q-37 | agent | đã chụp |
| S-57 | 5.5 | Kết quả Q-38 | Kibana Dev Tools | như S-49, khối Q-38 | agent | đã chụp |
| S-58 | 5.5 | Kết quả Q-39 | Kibana Dev Tools | như S-49, khối Q-39 | agent | đã chụp |
| S-59 | 5.5 | Kết quả Q-40 | Kibana Dev Tools | như S-49, khối Q-40 | agent | đã chụp |
| S-60 | 5.5 | Kết quả Q-41 (PUBLISH/SUBSCRIBE hai cửa sổ) | RedisInsight Pub/Sub | cửa sổ 1 (trên): RedisInsight Pub/Sub, Subscribe `ledgermind:admin-events`, nhận 2 tin; cửa sổ 2 (dưới): `redis-cli PUBSUB NUMSUB/NUMPAT`, `PUBLISH` → 1. RedisInsight đăng ký theo mẫu (PSUBSCRIBE) nên NUMSUB = 0, NUMPAT = 1 | agent | đã chụp (ảnh ghép) |
| S-61 | 5.6 | MongoDB: đếm → mongodump → xóa → `time mongorestore` → đếm (NFR-13) | Terminal | trên stack demo, `finance_nosql_demo`: 36/36/13 index/2 validator → `mongodump --archive --gzip` (4.612 byte) → `dropDatabase` → `time mongorestore` (real 0,604 s) → 36/36/13/2; dòng cuối: 5 lần đo thêm, trung vị 0,543 s | agent | đã chụp |
| S-62 | 5.6 | MongoDB: mongoexport / mongoimport | Terminal | `mongoexport --jsonFormat=canonical` (36 + 36 dòng) → xóa → `mongodb_init.js` với `TARGET_DB` → `mongoimport` (36 + 36) → đếm 36/36/13/2, `transactionId: Long('1006')`, `createdAt: ISODate` | agent | đã chụp |
| S-63 | 5.6 | Redis: RDB SAVE → khởi động lại với dump.rdb → đếm | Terminal | container `redis:8.10-alpine` dùng một lần, mạng `none` (theo `backup_restore.md` mục 2a; Redis của stack thật/demo chạy `--save ''` và đổi tên `FLUSHALL`): DBSIZE 4, ZCARD 3, top user 4 → SAVE → FLUSHALL → 0 → khởi động lại với file → 4, 3, user 4, TTL còn 281 | agent | đã chụp |
| S-64 | 5.6 | Elasticsearch: snapshot → xóa → restore → `_count` | Kibana / Terminal | curl trong container: `_count` 47 → snapshot `snap-s64` SUCCESS → `DELETE transactions` → `index_not_found_exception` → `_restore` (1/1 shard) → 47 → `_analyze` vi_folded "Phở Bò" → `pho`, `bo` | agent | đã chụp |
| S-65 | 5.6, 6.3 | Trang `/admin/backup`, thẻ MongoDB: sao lưu thành công | Web admin | app chạy, đăng nhập `/admin/login` → `/admin/backup` → thẻ MongoDB → Sao lưu → thông báo "Đã sao lưu MongoDB (ocr_logs, ocr_feedbacks) thành công!" (`backup_restore.md` mục 1c) | Tiến | giữ chỗ |
| S-66 | 5.6, 6.3 | `/admin/backup` khôi phục MongoDB + Compass đếm lại | Web admin + Compass | xóa vài phản hồi → Khôi phục → thông báo; Compass đếm lại = trước khi xóa. **Bấm giờ** từ lúc bấm "Khôi phục" tới lúc thông báo hiện (NFR-13, phần chưa đo) và ghi số vào `bench_results.md` | Tiến | giữ chỗ |
| S-67 | 6.3 (nhóm 1), 3.7 | Mobile: đăng nhập | App mobile | màn hình đăng nhập của app | Tiến | giữ chỗ |
| S-68 | 6.3 (nhóm 1), 3.7 | Web admin: đăng nhập, trang người dùng (phân quyền) | Web admin | `/admin/login` → trang người dùng (cột vai trò) | Tiến | giữ chỗ |
| S-69 | 6.3 (nhóm 1), 3.7 | Mobile: quên mật khẩu, nhập OTP | App mobile | Đăng nhập → Quên mật khẩu → màn hình nhập OTP 6 số | Tiến | giữ chỗ |
| S-70 | 6.3 (nhóm 1) | RedisInsight: key `ledgermind:password-reset-otp:<email>` (Hash, TTL) | RedisInsight | ngay sau S-69 (trong 5 phút), RedisInsight nối **Redis mà app đang dùng**, mở hash OTP (trường `code`, `expiresAt`, TTL) | Tiến | giữ chỗ |
| S-71 | 6.3 (nhóm 2) | Postman/Swagger: `GET /api/admin/ocr-feedbacks` | Postman | `scripts/nosql/NoSQL_Postman_Collection.json`, request tương ứng, kết quả 200 | Tiến | giữ chỗ |
| S-72 | 6.3 (nhóm 2), 3.7 | Trang `/admin/ocr-feedbacks`: danh sách + 3 biểu đồ | Web admin | mở trang khi có dữ liệu phản hồi | Tiến | giữ chỗ |
| S-73 | 6.3 (nhóm 2) | Đánh dấu đã xử lý / xóa phản hồi + Compass thấy dữ liệu đổi | Web admin + Compass | bấm đánh dấu/xóa → Compass `finance_nosql.ocr_feedbacks` thấy `isResolved` đổi / document mất | Tiến | giữ chỗ |
| S-74 | 6.3 (nhóm 3), 3.7 | Mobile: Sổ cái tìm "pho" ra các dòng "Phở" | App mobile | Sổ cái → ô tìm "pho" | Tiến | giữ chỗ |
| S-75 | 6.3 (nhóm 3) | Document của giao dịch vừa tạo xuất hiện trong index (đồng bộ sau commit) | Kibana / Elasticvue | tạo giao dịch trên app (`SEARCH_ENGINE=elasticsearch`) → Kibana Dev Tools / Elasticvue `GET transactions/_doc/<id>` | Tiến | giữ chỗ |
| S-76 | 6.3 (nhóm 3), 3.7 | Mobile: quét hóa đơn rồi sửa → document `ocr_feedbacks` mới trong Compass | App + Compass | quét, sửa trường → Compass thấy document mới | Tiến | giữ chỗ |
| S-77 | 6.3 (nhóm 4), 3.7 | `/admin/dashboard`: top 5 chi tiêu tháng | Web admin | mở `/admin/dashboard` | Tiến | giữ chỗ |
| S-78 | 6.3 (nhóm 4), 3.7 | `/admin/nosql`: dựng lại chỉ mục + bảng xếp hạng (flash) | Web admin | bấm hai nút dựng lại, chụp thông báo flash | Tiến | giữ chỗ |
| S-79 | 6.3 (nhóm 4) | RedisInsight: ZSET `ledgermind:leaderboard:spend:<yyyy-MM>` | RedisInsight | Redis của app, mở ZSET tháng hiện tại | Tiến | giữ chỗ |
| S-80 | 6.3, 6.4, 3.7 | Toast realtime trên trang admin (Pub/Sub → SSE) | Web admin | mở trang admin, ở tab khác bấm "Dựng lại bảng xếp hạng" (hoặc `PUBLISH ledgermind:admin-events …` như Q-41) → toast | Tiến | giữ chỗ |
| S-81 | 6.3 (nhóm 4), 3.7 | Mobile trang chủ + RedisInsight key `…:user-dashboard:<userId>` | App + RedisInsight | mở trang chủ app → RedisInsight thấy key cache của user | Tiến | giữ chỗ |
| S-82 | 6.4, 7.3 | Postman: `/api/transactions/search` trả `engine=elasticsearch`, rồi `engine=postgres` sau khi dừng ES | Postman | gọi search khi ES chạy, dừng ES, gọi lại | Tiến | giữ chỗ |
| S-83 | 7.3 | Dừng Redis: dashboard vẫn trả lời (Postman, độ trễ quan sát; cần stack đầy đủ) | Postman + Terminal | trên stack đầy đủ: `docker stop finance-redis` → gọi dashboard → vẫn 200 | Trí | giữ chỗ |
| S-84 | 7.3 | Dừng MongoDB: quét hóa đơn vẫn lưu (log cảnh báo; cần stack đầy đủ) | App + Terminal | trên stack đầy đủ: `docker stop finance-mongodb` → quét hóa đơn → lưu được, log cảnh báo | Trí | giữ chỗ |
| S-85 | 7.2 | JMeter Summary Report (tùy chọn, chỉ khi chạy) | JMeter | `docs/testing` (JMeter), chỉ chụp nếu thật sự chạy; không chạy thì bỏ hình khỏi 7.2 | Trí | giữ chỗ |
| S-86 | 5.6 | Redis: nhập bằng `redis-cli < redis_demo.txt` (DBSIZE trước/sau; `S/backup_restore.md:124`) và xuất bằng `redis-cli --rdb` (`S/backup_restore.md` mục 2b, `:144-151`) | Terminal / RedisInsight | stack demo, database logic 3: DBSIZE 0 → `redis-cli -n 3 < /s/redis_demo.txt` → DBSIZE 3 (3 key cache còn lại sau Q-28) → `redis-cli --rdb /tmp/remote.rdb` "Transfer finished with success after 575 bytes" | agent | đã chụp |
| S-87 | 5.6 | Elasticsearch: xuất bằng `GET transactions/_search?size=1000` → xóa index → tạo lại từ hai file mapping/settings của app → nhập lại bằng `_bulk` (`"errors":false`) → `_count` = 47 (`S/backup_restore.md` mục 3b, `:179-183`) | Kibana Dev Tools / Terminal | curl trong container: xuất 47 `_id` → DELETE → PUT từ `/app-es/*.json` → `_bulk` `"errors":false`, 47 × 201 → `_count` 47 | agent | đã chụp |
| S-88 | 7.2, 6.4 | Đo độ trễ sự kiện realtime (§2.7): terminal `curl -N` trên `/admin/events` + bảng p50/p95 | Terminal | **Khác facts theo phán quyết của controller** (agent không chạy app nên không có `/admin/events` để `curl -N`): ảnh là bảng kết quả của bài đo `AdminEventLatencyBench` (`mvn … -Dtest=AdminEventLatencyBench -Dbench=true`, mã thật của `AdminEventPublisher` + `AdminEventRelay` + Redis thật) dựng lại từ file kết quả `bench_raw/E6.txt` của lần chạy đó: p50 1,177 ms, p95 1,573 ms, mất 0/300. Chặng tới trình duyệt không đo. Nếu muốn đúng mô tả facts thì Trí/Tiến chạy `curl -N` trên app thật và thay ảnh | agent | đã chụp |
| S-89 | 7.2 | `docker stats --no-stream` của stack demo (NFR-14) | Terminal | stack demo với giới hạn **bằng compose** (`NOSQL_DEMO_ES_MEMORY=1G`), sau khi chạy lại dữ liệu demo + Q-xx: (1) Kibana tắt; (2) bật Kibana, đăng nhập, đợi 60 s; `docker inspect` restarts; nhật ký kernel OOM của container Elasticsearch | agent | đã chụp |

Tổng: 49 ảnh agent đã chụp; 40 ảnh giữ chỗ (Tiến 37, Trí 3).
