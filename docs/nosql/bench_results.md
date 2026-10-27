# Kết quả đo hiệu năng E1–E5 (Task 3)

> **Dữ liệu tổng hợp**: toàn bộ dữ liệu trong bảng này do `scripts/nosql/bench/gen_data.py` sinh ra (seed 42), không có dữ liệu thật của người dùng. Số đo là **độ trễ tầng dữ liệu** (client Python trong cùng mạng docker, không qua Spring/JPA/mạng ngoài), 1 luồng, tuần tự. Dấu phẩy là dấu thập phân. Mục tiêu NFR lấy nguyên từ `facts.md` §2.3 (đóng băng trước khi đo); cột "Đạt NFR" chỉ so sánh, không sửa mục tiêu.

## 0. Môi trường, phiên bản, lệnh

| Mục | Giá trị |
|---|---|
| Ngày đo (UTC), lệnh | `scripts/nosql/bench/run_all.sh E1 E2 E3 E4 E5` lúc 2026-10-27T19:12:40Z; `scripts/nosql/bench/run_all.sh E2 E3 E5` lúc 2026-10-27T20:04:21Z; `scripts/nosql/bench/run_all.sh E2` lúc 2026-10-27T20:35:47Z |
| CPU | Intel(R) Core(TM) i7-8750H CPU @ 2.20GHz (12 luồng) |
| RAM | MemTotal: 15682476 kB |
| Nhân Linux | 7.0.0-38-generic |
| Docker Engine | 29.1.3 |
| MongoDB (server / pymongo) | 6.0.28 / 4.10.1 |
| Redis (server / redis-py) | 8.10.2 / 5.2.1 |
| Elasticsearch | 8.11.4 (bảo mật tắt trong mạng riêng, 1 node, heap 512 MB, 1 shard, 0 replica) |
| PostgreSQL | PostgreSQL 15.19 on x86_64-pc-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit |
| Driver PostgreSQL / HTTP | psycopg 3.2.3 (chuẩn bị câu lệnh sau 5 lần, như pgjdbc) / requests 2.32.3 (keep-alive) |
| Python client | 3.12.16 (image `python:3.12-slim`) |
| Giới hạn tài nguyên container | như `docker-compose.yml`: Redis 192 MB (`maxmemory 128mb`), MongoDB 512 MB (WiredTiger cache 0,25 GB), Elasticsearch 1 GB (heap 512 MB); PostgreSQL không giới hạn (compose cũng không) |
| Cách đo | khởi động 200 lần (không tính), rồi 1200 lần đo; mỗi lần gọi đo riêng bằng `perf_counter_ns`; phân vị nearest-rank; ops/s = n / tổng thời gian (1 luồng); GC của Python tạm dừng khi đo |
| Ghi chú lệnh | cần Docker; mỗi lần chạy tạo một mạng riêng và xóa sạch khi xong; sau đó `python3 docs/nosql/build/report_bench.py` và `python3 docs/nosql/build/plot_bench.py`. Lần chạy thứ hai (E2, E3, E5) làm lại ba thí nghiệm sau khi ứng dụng đổi `FUZZINESS` thành `AUTO:4,7` (commit 7f07caa) và sau khi thêm các hàng bổ sung; lần thứ ba (chỉ E2) làm lại E2 sau khi thêm `prefix_length: 1` (commit b35cd6e). E1 và E4 giữ số đo của lần đầu, E3 và E5 của lần hai, cùng máy, cùng dữ liệu. |
| Image (ID) | `mongo:6.0` 8b6d8f5bbedb; `redis:8.10-alpine` 3811787313eb; `elasticsearch:8.11.4` 0092c4086c3e; `postgres:15-alpine` f7d23353e1b1 |

Dữ liệu (sha256 từng tệp, sinh hai lần cho ra cùng kết quả):

```
6db063a28058d6e967cce7d5e4c330fbce61d674194e32f08bf778bb53219f74  users.csv
ae1b44c577a14ccf055b06f1eaab581e040730864a1c6809e436f58c5c0919cb  categories.csv
5fea2fb78c0fa6b81df10ddcbf9e6abdd309e709207268f15b6e404ae777ab47  receipts.csv
894bf70c3e6b771333544501705107bb2bbb23b847e831680c6a4be787ac7841  transactions.csv
e75f9911b5f061e7dab7873426d05ac596cede7ff22eac61c35b96af09cacace  es_bulk.ndjson
9dab40cdccac6127b1cd9987ac61c7289269593cfd44266efdaba5feeba0ae5a  ocr_logs.ndjson
a28cfb08ba7b99faf04a66373cebfd1f6aeb96d74a46f17bdc1110441c83928a  ocr_feedbacks.ndjson
48e4bbbeb5d3678b3029e1dfdfdbc81fc34471c015f7b36a9d44ad186e183189  ALL (sha256 of the lines above)
```

Quy mô: 100.000 giao dịch (34.943 hóa đơn, 1000 người dùng; người dùng 1 là tài khoản "nặng" giữ 19.788 giao dịch, mỗi người dùng còn lại khoảng 80), 100.000 `ocr_logs` và 45.471 `ocr_feedbacks`; 10 % văn bản viết không dấu.

Sơ đồ PostgreSQL là DDL do Hibernate 6.4 sinh ra (bốn bảng `users`, `categories`, `receipts`, `transactions`; không có index nào ngoài khóa chính và khóa duy nhất `uk_transactions_user_client_id (user_id, client_id)`), lấy từ log show-sql của một bài test tạm chạy trên container PostgreSQL 15 (`scripts/nosql/bench/BenchSqlCaptureTest.java.txt`, `schema_hibernate_pg.ddl`). Các câu SQL của E2/E3/E4 cũng lấy từ log đó (`captured_queries.txt`), không viết tay.

## E1. MongoDB: có index và không có index (AP-19, AP-38; NFR-05)

| Kịch bản | NFR | Số bản ghi | Tải | p50 (ms) | p95 (ms) | p99 (ms) | ops/s | Đạt NFR |
|---|---|---|---|---|---|---|---|---|
| Q-01 có index (`transactionId`) | NFR-05 | 100.000 | 1 luồng | 0,34 | 0,40 | 0,45 | 2.927 | IXSCAN ✓, p95 ✓, docs = nReturned ✓ (1/1) → Đạt |
| Q-01 không index (COLLSCAN) | – | 100.000 | 1 luồng | 20,7 | 39,0 | 42,5 | 48 | – (chậm hơn 60× ở p50) |
| Q-02 có index (`createdAt`) | NFR-05 | 100.000 | 1 luồng | 0,43 | 0,51 | 0,56 | 2.317 | IXSCAN ✓, p95 ✓, docs = nReturned ✗ (61/5) → KHÔNG đạt |
| Q-02 không index (COLLSCAN) | – | 100.000 | 1 luồng | 45,8 | 50,3 | 65,6 | 21 | – (chậm hơn 106× ở p50) |
| Q-03 có index (`status_date_idx`) | NFR-05 | 45.471 | 1 luồng | 0,33 | 0,40 | 0,46 | 3.007 | IXSCAN ✓, p95 ✓, docs = nReturned ✓ (5/5) → Đạt |
| Q-03 không index (COLLSCAN) | – | 45.471 | 1 luồng | 21,8 | 24,1 | 28,3 | 45 | – (chậm hơn 65× ở p50) |

Máy chủ (`explain("executionStats")` của đúng lệnh đó):

| Truy vấn | Kế hoạch thắng | Index | keys examined | docs examined | nReturned | executionTimeMillis |
|---|---|---|---|---|---|---|
| Q-01 có index | LIMIT -> PROJECTION_DEFAULT -> FETCH -> IXSCAN | transactionId | 1 | 1 | 1 | 0 |
| Q-01 không index | LIMIT -> PROJECTION_DEFAULT -> COLLSCAN | – | 0 | 81645 | 1 | 35 |
| Q-02 có index | LIMIT -> PROJECTION_SIMPLE -> FETCH -> IXSCAN | createdAt | 61 | 61 | 5 | 5 |
| Q-02 không index | PROJECTION_SIMPLE -> SORT -> COLLSCAN | – | 0 | 100000 | 5 | 53 |
| Q-03 có index | LIMIT -> PROJECTION_SIMPLE -> FETCH -> IXSCAN | status_date_idx | 5 | 5 | 5 | 0 |
| Q-03 không index | PROJECTION_SIMPLE -> SORT -> COLLSCAN | – | 0 | 45471 | 5 | 23 |

| Kịch bản | max (ms) | trung bình (ms) | n (đo) | khởi động (không tính) |
|---|---|---|---|---|
| Q-01 có index | 0,65 | 0,34 | 1200 | 200 |
| Q-01 không index | 62,2 | 20,7 | 1200 | 200 |
| Q-02 có index | 0,71 | 0,43 | 1200 | 200 |
| Q-02 không index | 88,1 | 46,7 | 1200 | 200 |
| Q-03 có index | 1,31 | 0,33 | 1200 | 200 |
| Q-03 không index | 48,4 | 22,2 | 1200 | 200 |

Kích thước: `ocr_logs` 100.000 document, dữ liệu 41,9 MB, index 5,5 MB; `ocr_feedbacks` 45.471 document, dữ liệu 11,0 MB, index 4,1 MB.

Ghi chú trung thực: với Q-02 bộ lập kế hoạch chọn index `createdAt` (quét `createdAt` giảm dần cho tới khi đủ 5 dòng có `averageConfidenceScore < 0,75`) nên phải kiểm tra 61 document để trả 5: điều kiện "totalDocsExamined = nReturned" của NFR-05 chỉ đúng khi truy vấn khớp trọn một index theo cả bộ lọc lẫn thứ tự sắp xếp (Q-03 với `status_date_idx`, Q-01 với `transactionId`). Với Q-02 không index nào làm được điều đó: bộ lọc là một **khoảng** trên `averageConfidenceScore` (`$lt 0,75`) còn thứ tự sắp xếp là `createdAt`. Theo quy tắc ESR (Equality, Sort, Range) của MongoDB, index `{averageConfidenceScore, createdAt}` có trường khoảng đứng trước trường sắp xếp nên các khóa trả về theo thứ tự điểm chứ không theo thời gian, buộc phải có bước SORT trong bộ nhớ (`score_date_idx` nằm trong bộ index nhưng bị bỏ qua); index `{createdAt}` cho đúng thứ tự nhưng không lọc được theo điểm nên phải đọc các document để loại những dòng điểm ≥ 0,75. Chỉ khi điều kiện trên điểm là bằng nhau (không phải khoảng) thì `{điểm, createdAt}` mới thỏa cả hai.

## E2. Elasticsearch và PostgreSQL `LOWER(..) LIKE .. ESCAPE` (AP-29, AP-31; NFR-03, NFR-04)

PostgreSQL: câu `searchIdsByText` (trang 20 dòng, thêm câu `count` khi trang đầy, như `Page` của Spring Data). Elasticsearch: thân yêu cầu của `ElasticsearchTransactionSearchEngine.hits` (hai `multi_match`, nhánh mờ `fuzziness: AUTO:4,7` với `prefix_length: 1` như `FUZZINESS` và `FUZZY_PREFIX_LENGTH` hiện tại của mã nguồn (commits 7f07caa, b35cd6e), lọc `userId`, sắp xếp điểm rồi ngày, `track_total_hits`, trang 0 cỡ 20), trên index tạo từ `transactions-settings.json` và `transactions-mapping.json` của ứng dụng. Chỉ đo bước truy vấn của engine (việc nạp lại các dòng theo id từ PostgreSQL là chung cho cả hai). 20 chuỗi tìm kiếm = 10 từ × (có dấu, không dấu), quay vòng đều; 'điển hình' = 20 người dùng ~80 giao dịch (quay vòng), 'nặng' = người dùng 1 (19.788 giao dịch).

| Kịch bản | NFR | Số bản ghi | Tải | p50 (ms) | p95 (ms) | p99 (ms) | ops/s | Đạt NFR |
|---|---|---|---|---|---|---|---|---|
| ES, người dùng điển hình (~80 dòng) | NFR-03 | 100.000 | 1 luồng | 3,70 | 5,65 | 12,6 | 202 | p95 < 100 ms → Đạt |
| PostgreSQL LIKE, người dùng điển hình (~80 dòng) | – | 100.000 | 1 luồng | 0,66 | 0,98 | 1,15 | 1.432 | – (PostgreSQL = 0,18× thời gian của ES ở p50) |
| ES, người dùng nặng (19.788 dòng) | NFR-03 | 100.000 | 1 luồng | 3,70 | 4,95 | 6,20 | 257 | p95 < 100 ms → Đạt |
| PostgreSQL LIKE, người dùng nặng (19.788 dòng) | – | 100.000 | 1 luồng | 78,2 | 85,1 | 96,8 | 13 | – (PostgreSQL = 21,13× thời gian của ES ở p50) |

| Kịch bản | max (ms) | trung bình (ms) | n (đo) | khởi động (không tính) |
|---|---|---|---|---|
| ES typical | 473,1 | 4,95 | 1200 | 200 |
| PostgreSQL typical | 1,30 | 0,70 | 1200 | 200 |
| ES heavy | 18,1 | 3,89 | 1200 | 200 |
| PostgreSQL heavy | 156,1 | 77,6 | 1200 | 200 |

Máy chủ Elasticsearch (`took` trong mỗi phản hồi, ms): typical: p50 1, p95 3, p99 4, max 471; heavy: p50 2, p95 3, p99 3, max 16.

Sàn của lời gọi (làm gì cũng phải trả): PostgreSQL `SELECT 1` p50 0,045 ms; Elasticsearch `GET /` qua HTTP p50 0,97 ms (Python `requests`, một phần của phần chênh giữa `took` và độ trễ client).

Máy chủ PostgreSQL (`EXPLAIN (ANALYZE, BUFFERS)` của câu trang, từ "phở"): người dùng nặng 41,512 ms, người dùng điển hình 0,286 ms. Kế hoạch là Bitmap Index Scan trên `uk_transactions_user_client_id` (chỉ khóa duy nhất này có `user_id` đứng đầu) rồi lọc `LIKE` từng dòng của người dùng đó: không có index nào giúp `LIKE '%…%'`, nên thời gian tăng theo số giao dịch của một người dùng, không theo cả bảng. Cơ sở dữ liệu dùng collation `en_US.utf8` (mặc định của image compose), nên `LOWER()` hạ được chữ hoa có dấu.

Elasticsearch: 100.000 document, 10,9 MB, 5 segment (không force-merge).

Chất lượng kết quả. **Sự thật nền** = các giao dịch của người dùng có một trường văn bản chứa **mọi** từ của chuỗi như một từ nguyên vẹn sau khi hạ chữ thường và bỏ dấu (cùng cách `vi_folded` làm: lowercase + asciifolding, `đ` thành `d`). Hai engine được lấy **toàn bộ** tập kết quả (không chỉ trang đầu) rồi so với sự thật nền theo id: *dương tính giả* = có trong kết quả nhưng không thuộc sự thật nền; *bỏ sót* = thuộc sự thật nền nhưng không có trong kết quả. Người dùng nặng (người dùng 1):

| Chuỗi | Sự thật nền | PG: số hit | PG: dương tính giả | PG: bỏ sót | ES: số hit | ES: dương tính giả | ES: bỏ sót |
|---|---|---|---|---|---|---|---|
| phở | 1.517 | 1.233 | 0 | 284 | 1.852 | 335 | 0 |
| pho | 1.517 | 176 | 35 | 1.376 | 1.852 | 335 | 0 |
| cà phê | 2.665 | 2.561 | 0 | 104 | 2.665 | 0 | 0 |
| ca phe | 2.665 | 112 | 0 | 2.553 | 2.665 | 0 | 0 |
| bún | 823 | 732 | 0 | 91 | 823 | 0 | 0 |
| bun | 823 | 95 | 0 | 728 | 823 | 0 | 0 |
| cơm tấm | 690 | 624 | 0 | 66 | 690 | 0 | 0 |
| com tam | 690 | 67 | 0 | 623 | 690 | 0 | 0 |
| bánh mì | 757 | 690 | 0 | 67 | 757 | 0 | 0 |
| banh mi | 757 | 69 | 0 | 688 | 757 | 0 | 0 |
| phúc long | 182 | 164 | 0 | 18 | 182 | 0 | 0 |
| phuc long | 182 | 18 | 0 | 164 | 182 | 0 | 0 |
| trà sữa | 716 | 631 | 0 | 85 | 716 | 0 | 0 |
| tra sua | 716 | 86 | 0 | 630 | 716 | 0 | 0 |
| tiền điện | 391 | 352 | 0 | 39 | 391 | 0 | 0 |
| tien dien | 391 | 39 | 0 | 352 | 391 | 0 | 0 |
| đổ xăng | 404 | 355 | 0 | 49 | 404 | 0 | 0 |
| do xang | 404 | 49 | 0 | 355 | 404 | 0 | 0 |
| siêu thị | 806 | 718 | 0 | 88 | 806 | 0 | 0 |
| sieu thi | 806 | 88 | 0 | 718 | 806 | 0 | 0 |

Tổng gộp trên 20 người dùng điển hình (cộng các số đếm): "phở": sự thật nền 101, PG 79 (giả 0, sót 22), ES 144 (giả 43, sót 0); "pho": sự thật nền 101, PG 17 (giả 6, sót 90), ES 144 (giả 43, sót 0).

Độ chính xác của 20 kết quả đầu (P@20 = tỉ lệ trong 20 dòng đầu có chứa từ khóa như một từ nguyên vẹn sau khi bỏ dấu), người dùng nặng, và tổng gộp của 20 người dùng điển hình (số dòng đúng / số dòng trả về):

| Chuỗi | PG, nặng | ES, nặng | PG, điển hình | ES, điển hình |
|---|---|---|---|---|
| phở | 20/20 (100 %) | 20/20 (100 %) | 79/79 (100 %) | 101/144 (70 %) |
| pho | 16/20 (80 %) | 20/20 (100 %) | 11/17 (65 %) | 101/144 (70 %) |

Cách gõ có dấu và không dấu: **tập kết quả** của Elasticsearch giống hệt nhau (so theo id) ở 10/10 cặp ("pho" và "phở" cùng 1.852 giao dịch), vì `asciifolding` đưa cả hai về token `pho`. PostgreSQL chỉ giống nhau ở 0/10 cặp: "phở" ra 1.233 nhưng "pho" chỉ 176, vì `LIKE` so từng ký tự ("pho" chỉ khớp những giao dịch được gõ không dấu), nên PostgreSQL **bỏ sót** phần lớn sự thật nền ở mọi chuỗi có dấu/không dấu không khớp với cách ghi trong dữ liệu (cột "PG: bỏ sót"); đó là giới hạn đã ghi nhận của chế độ PostgreSQL.

Dương tính giả của Elasticsearch: chỉ còn **tiền tố**. Nhánh chính xác dùng thêm trường `.autocomplete` (edge-ngram) nên "pho" khớp mọi từ bắt đầu bằng `pho`, ví dụ "phòng" trong "Ăn trưa văn phòng" (PostgreSQL cũng có dương tính giả cùng loại vì `LIKE '%pho%'` khớp "phong" khi viết không dấu). Chuỗi có dương tính giả: phở, pho (335 giao dịch ở "pho"). Nhánh mờ hiện chạy với `AUTO:4,7` và `prefix_length: 1` (commit 7f07caa, b35cd6e): từ dưới 4 ký tự không được sai, từ 4-7 ký tự sai tối đa 1 ký tự **nhưng chữ cái đầu phải đúng**. Vì vậy "tiền điện"/"tien dien" (trước khi có `prefix_length` là 6.224 hit so với sự thật nền 391, 5.833 dương tính giả vì "tien" và "dien" cách nhau đúng một ký tự) nay trả 391 hit, đúng bằng sự thật nền 391. "phố" ("Xúc Xích Phố Cổ") **không** phải dương tính giả: nó khớp "pho" vì `asciifolding` (token chính xác), không phải do mờ, nên nó nằm trong sự thật nền. Elasticsearch không bỏ sót dòng nào của sự thật nền ở cả 20 chuỗi.

Kiểm tra đúng/sai còn lại của NFR-04 (sai một ký tự vẫn ra, tiền tố "phu" ra "Phúc Long", không ra giao dịch người khác) nằm ở TC-32..TC-35 (test tích hợp), không lặp lại ở đây.

## E3. Bảng xếp hạng top 10: Redis ZSET và SQL `sumExpensesByUserBetween` (AP-11, AP-12; NFR-06)

Tháng 2026-10: 27.067 dòng chi tiêu của 1.000 người dùng; ZSET dựng bằng `ZADD` từ kết quả SQL như `writeRows`. Kết quả top 10 của hai đường khớp nhau (cùng id, cùng điểm). Đường ghi: script Lua `REFRESH_MEMBER_SCRIPT` của dịch vụ (EXISTS rồi ZADD điểm tuyệt đối) gọi bằng EVALSHA. Đường Redis của ứng dụng không chỉ là đọc ZSET: `topSpenders` còn gọi `userRepo.findAllById(ids)` để lấy tên 10 người dùng (đường SQL đã có tên nhờ phép nối), nên hàng so sánh công bằng với SQL là **ZREVRANGE + tra tên** (câu `select … from users where id in (10 id)` do Hibernate phát ra cho `findAllById`, lấy từ log show-sql).

| Kịch bản | NFR | Số bản ghi | Tải | p50 (ms) | p95 (ms) | p99 (ms) | ops/s | Đạt NFR |
|---|---|---|---|---|---|---|---|---|
| Redis `ZREVRANGE 0 9 WITHSCORES` (chỉ đọc ZSET) | NFR-06 | 27.067 dòng → 1.000 member | 1 luồng | 0,080 | 0,15 | 0,19 | 10.330 | p95 < 5 ms → Đạt |
| Redis `ZREVRANGE` + tra tên (`findAllById`, 10 id): đường Redis đầy đủ của ứng dụng | NFR-06 | 27.067 dòng → 1.000 member | 1 luồng | 0,36 | 0,39 | 0,42 | 2.902 | p95 < 5 ms → Đạt; nhanh hơn SQL 66× ở p50 |
| PostgreSQL `sumExpensesByUserBetween` (toàn bộ nhóm, đã gồm tên) | – | 27.067 dòng | 1 luồng | 23,6 | 27,1 | 40,2 | 41 | – (gấp 295× ZREVRANGE trần, gấp 66× đường Redis đầy đủ ở p50) |
| Redis Lua refresh một member (EVALSHA, ZADD tuyệt đối) | – | 27.067 dòng → 1.000 member | 1 luồng | 0,067 | 0,11 | 0,14 | 12.150 | – (đường ghi) |
| Redis dựng lại (DEL + ZADD mọi member) | – | 27.067 dòng → 1.000 member | 1 luồng | 2,67 | 2,89 | 3,37 | 368 | – (chỉ phần Redis của một lần miss) |

| Kịch bản | max (ms) | trung bình (ms) | n (đo) | khởi động (không tính) |
|---|---|---|---|---|
| Redis ZREVRANGE | 0,27 | 0,097 | 1200 | 200 |
| Redis ZREVRANGE + tra tên | 0,47 | 0,34 | 1200 | 200 |
| PostgreSQL SQL | 52,7 | 24,3 | 1200 | 200 |
| Redis Lua refresh | 0,22 | 0,082 | 1200 | 200 |
| Redis rebuild | 4,93 | 2,72 | 200 | 20 |

Máy chủ: Redis `usec_per_call` của ZREVRANGE = 1,92 µs, của EVALSHA = 7,12 µs (`INFO commandstats`); PostgreSQL `EXPLAIN (ANALYZE)` = 21,327 ms (Seq Scan `transactions` + HashAggregate). Sàn: Redis `PING` p50 0,073 ms, PostgreSQL `SELECT 1` p50 0,045 ms.

## E4. Cache và không cache ở tầng dữ liệu (AP-07, AP-08; NFR-01, NFR-02)

"Trúng cache" = Redis `GET` của JSON đã cache (và một dòng `GET` + `json.loads`). "Trượt cache" = các câu SQL mà Hibernate phát ra khi `UserStatisticsService.dashboardOf` / `popularVendorsOf` và `AdminStatisticsService.getDashboardSummary` chạy (3, 1 và 5 câu, lấy từ log show-sql) cộng việc dựng kết quả; "trượt đầy đủ" thêm `json.dumps` và `SET`. Dashboard/popular vendors quay vòng qua 500 người dùng; PostgreSQL ấm (toàn bộ dữ liệu nằm trong bộ nhớ đệm của PG). Đường trượt của ứng dụng thật còn thêm một câu tra khóa chính (`select … from receipts where id = ?`) cho hóa đơn của giao dịch lớn nhất (quan hệ `receipt` là lazy và `TransactionResponseDto.from` đọc nó) mỗi khi giao dịch đó có hóa đơn mà không nằm trong 5 giao dịch gần nhất hoặc danh sách có mã giảm giá; câu đó không có trong log vì giao dịch lớn nhất của dữ liệu bắt log cũng là giao dịch mới nhất, nên hóa đơn của nó đã được nạp bởi câu liền trước. Với dữ liệu thật câu này xuất hiện ở đa số người dùng, nên thời gian trượt ở đây là cận dưới và hệ số tăng tốc là thận trọng.

| Kịch bản | NFR | Số bản ghi | Tải | p50 (ms) | p95 (ms) | p99 (ms) | ops/s | Đạt NFR |
|---|---|---|---|---|---|---|---|---|
| Dashboard người dùng: Redis GET | NFR-01 | JSON ~1,9 KB | 1 luồng | 0,054 | 0,063 | 0,11 | 17.887 | p95 < 5 ms → Đạt |
| Dashboard người dùng: Redis GET + json.loads | NFR-01 | JSON ~1,9 KB | 1 luồng | 0,092 | 0,12 | 0,16 | 10.581 | p95 < 5 ms → Đạt |
| Dashboard người dùng: SQL (3 câu) | NFR-02 | 100.000 giao dịch | 1 luồng | 2,13 | 2,49 | 3,76 | 455 | GET nhanh hơn 39× ở p50 (≥ 5×) → Đạt |
| Dashboard người dùng: trượt đầy đủ (SQL + dumps + SET) | – | 100.000 giao dịch | 1 luồng | 2,39 | 2,68 | 3,49 | 412 | – (GET + loads nhanh hơn 26× ở p50) |
| Quán phổ biến: Redis GET | NFR-01 | JSON ~1,1 KB | 1 luồng | 0,053 | 0,065 | 0,100 | 18.083 | p95 < 5 ms → Đạt |
| Quán phổ biến: Redis GET + json.loads | NFR-01 | JSON ~1,1 KB | 1 luồng | 0,076 | 0,099 | 0,13 | 12.741 | p95 < 5 ms → Đạt |
| Quán phổ biến: SQL (1 câu) | NFR-02 | 100.000 giao dịch | 1 luồng | 0,57 | 0,61 | 0,65 | 1.750 | GET nhanh hơn 11× ở p50 (≥ 5×) → Đạt |
| Quán phổ biến: trượt đầy đủ (SQL + dumps + SET) | – | 100.000 giao dịch | 1 luồng | 0,81 | 0,97 | 1,12 | 1.215 | – (GET + loads nhanh hơn 11× ở p50) |
| Tổng quan quản trị: Redis GET | NFR-01 | JSON ~0,8 KB | 1 luồng | 0,051 | 0,060 | 0,099 | 18.866 | p95 < 5 ms → Đạt |
| Tổng quan quản trị: Redis GET + json.loads | NFR-01 | JSON ~0,8 KB | 1 luồng | 0,067 | 0,11 | 0,13 | 13.576 | p95 < 5 ms → Đạt |
| Tổng quan quản trị: SQL (5 câu) | NFR-02 | 100.000 giao dịch | 1 luồng | 27,2 | 30,3 | 32,9 | 36 | GET nhanh hơn 529× ở p50 (≥ 5×) → Đạt |
| Tổng quan quản trị: trượt đầy đủ (SQL + dumps + SET) | – | 100.000 giao dịch | 1 luồng | 27,7 | 30,6 | 32,2 | 36 | – (GET + loads nhanh hơn 410× ở p50) |

| Kịch bản | max (ms) | trung bình (ms) | n (đo) | khởi động (không tính) |
|---|---|---|---|---|
| Dashboard người dùng: Redis GET | 0,20 | 0,056 | 1200 | 200 |
| Dashboard người dùng: GET + loads | 0,27 | 0,095 | 1200 | 200 |
| Dashboard người dùng: SQL | 4,75 | 2,20 | 1200 | 200 |
| Dashboard người dùng: trượt đầy đủ | 3,96 | 2,43 | 1200 | 200 |
| Quán phổ biến: Redis GET | 0,21 | 0,055 | 1200 | 200 |
| Quán phổ biến: GET + loads | 0,23 | 0,078 | 1200 | 200 |
| Quán phổ biến: SQL | 0,87 | 0,57 | 1200 | 200 |
| Quán phổ biến: trượt đầy đủ | 1,37 | 0,82 | 1200 | 200 |
| Tổng quan quản trị: Redis GET | 0,19 | 0,053 | 1200 | 200 |
| Tổng quan quản trị: GET + loads | 0,22 | 0,074 | 1200 | 200 |
| Tổng quan quản trị: SQL | 58,7 | 27,6 | 1200 | 200 |
| Tổng quan quản trị: trượt đầy đủ | 38,4 | 28,0 | 1200 | 200 |

Máy chủ: `EXPLAIN (ANALYZE)` của từng câu SQL (người dùng đầu của danh sách, ms): dashboard/biggest 0,195; dashboard/recent 0,370; dashboard/sale 0,177; popular_vendors 0,222; admin/sum_volume 15,813; admin/count_users 0,139; admin/count_period 10,895; admin/low_balance 0,124; admin/receipt_status 8,615. Redis `usec_per_call` của GET = 1,02 µs.

Sàn: Redis `PING` p50 0,046 ms; PostgreSQL `SELECT 1` p50 0,045 ms. Câu SQL của dashboard người dùng chạy trong khoảng nửa mili-giây ở máy chủ vì mỗi người dùng chỉ ~80 dòng và đi qua `uk_transactions_user_client_id`; các câu tổng quan quản trị quét toàn bảng (Seq Scan) nên đắt hơn nhiều và là nơi cache có lợi nhất.

## E5. `$lookup` (tham chiếu) và bản sao nhúng (AP-37; Q-13)

Q-13 giữ nguyên (`$match` → `$lookup` `ocr_logs` theo `transactionId` (index unique) → `$unwind` → `$project` → `$sort` → `$limit 4`). Bản nhúng: mỗi feedback mang sẵn `rawJsonData`, `modelVersion`, `averageConfidenceScore` của log, cùng các index của `ocr_feedbacks`, nên chỗ khác duy nhất là phép nối; mọi biến thể trả cùng kết quả (kiểm trước khi đo, 50 lần mỗi biến thể). A = đúng như Q-13 (`fieldError = seller_name`, 15.211 feedback khớp, không index nào phục vụ điều kiện này); B = thêm `userId` (index `userId`), cách quản trị viên xem chi tiết một người dùng. Vì Q-13 chỉ sắp xếp và cắt 4 dòng **sau** phép nối, hai hàng "sắp lại" được thêm: `$match → $sort → $limit → $lookup → $unwind → $project` (cùng kết quả, vì `transactionId` là duy nhất trong `ocr_logs` và mọi feedback đều có log: đã kiểm bằng so sánh kết quả) và cùng thứ tự đó trên bản nhúng (`$project` sau `$limit`).

| Kịch bản | NFR | Số bản ghi | Tải | p50 (ms) | p95 (ms) | p99 (ms) | ops/s | Đạt NFR |
|---|---|---|---|---|---|---|---|---|
| A: toàn bộ `seller_name`: `$lookup` (Q-13 nguyên bản) | – | 45.471 feedback / 100.000 log | 1 luồng | 871,6 | 988,2 | 1069,9 | 1 | – |
| A: toàn bộ `seller_name`: Q-13 sắp lại (`$sort`/`$limit` trước `$lookup`) | – | 45.471 feedback / 100.000 log | 1 luồng | 0,75 | 0,80 | 0,83 | 1.330 | – (nhanh hơn Q-13 nguyên bản 1154,8× ở p50) |
| A: toàn bộ `seller_name`: bản sao nhúng (cùng thứ tự với Q-13) | – | 45.471 feedback / 100.000 log | 1 luồng | 49,5 | 55,1 | 63,0 | 20 | – (nhanh hơn Q-13 nguyên bản 17,6× ở p50) |
| A: toàn bộ `seller_name`: bản sao nhúng, `$sort`/`$limit` trước `$project` | – | 45.471 feedback / 100.000 log | 1 luồng | 0,48 | 0,57 | 0,62 | 2.046 | – (1,57× so với Q-13 sắp lại, p50) |
| B: theo người dùng: `$lookup` (Q-13 nguyên bản) | – | 45.471 feedback / 100.000 log | 1 luồng | 1,63 | 2,15 | 2,40 | 604 | – |
| B: theo người dùng: Q-13 sắp lại (`$sort`/`$limit` trước `$lookup`) | – | 45.471 feedback / 100.000 log | 1 luồng | 0,91 | 1,17 | 1,28 | 1.056 | – (nhanh hơn Q-13 nguyên bản 1,8× ở p50) |
| B: theo người dùng: bản sao nhúng (cùng thứ tự với Q-13) | – | 45.471 feedback / 100.000 log | 1 luồng | 0,64 | 0,73 | 0,81 | 1.542 | – (nhanh hơn Q-13 nguyên bản 2,5× ở p50) |
| B: theo người dùng: bản sao nhúng, `$sort`/`$limit` trước `$project` | – | 45.471 feedback / 100.000 log | 1 luồng | 0,63 | 0,73 | 0,83 | 1.574 | – (1,46× so với Q-13 sắp lại, p50) |

Cách đọc: **biến thể A đo cái giá của một `$lookup` đặt muộn** (một phép tra cho mỗi feedback khớp, 15.211 lần, rồi mới sắp xếp và lấy 4 dòng), không phải cái giá của việc tham chiếu so với nhúng: khi `$sort`/`$limit` chạy trước thì `$lookup` chỉ còn 4 lần và cả hai đường cùng xuống dưới 1 ms (bản nhúng sắp lại chỉ còn nhanh hơn 1,57× ở p50). **Biến thể B (theo người dùng, khoảng 15 feedback) là số so sánh công bằng giữa tham chiếu và nhúng**: nhúng nhanh hơn 2,5× ở p50.

| Kịch bản | max (ms) | trung bình (ms) | n (đo) | khởi động (không tính) |
|---|---|---|---|---|
| A: `$lookup` nguyên bản | 1199,8 | 888,2 | 1200 | 200 |
| A: Q-13 sắp lại | 0,98 | 0,75 | 1200 | 200 |
| A: nhúng (cùng thứ tự Q-13) | 79,2 | 50,0 | 1200 | 200 |
| A: nhúng sắp lại | 0,75 | 0,49 | 1200 | 200 |
| B: `$lookup` nguyên bản | 3,12 | 1,65 | 1200 | 200 |
| B: Q-13 sắp lại | 1,48 | 0,95 | 1200 | 200 |
| B: nhúng (cùng thứ tự Q-13) | 0,92 | 0,65 | 1200 | 200 |
| B: nhúng sắp lại | 1,02 | 0,64 | 1200 | 200 |

Máy chủ (`explain("executionStats")` của pipeline):

| Biến thể | docs examined (từng giai đoạn) | keys examined | index dùng | executionTimeMillis |
|---|---|---|---|---|
| A `$lookup` nguyên bản | [45471, 15210] | [0, 15210] | [['transactionId']] | [904] |
| A Q-13 sắp lại | [6, 3] | [6, 3] | [['transactionId']] | [0] |
| A nhúng | [45471] | [0] | – | [47] |
| A nhúng sắp lại | [6] | [6] | – | [0] |
| B `$lookup` nguyên bản | [39, 16] | [39, 16] | [['transactionId']] | [1] |
| B Q-13 sắp lại | [39, 3] | [39, 3] | [['transactionId']] | [0] |
| B nhúng | [39] | [39] | – | [0] |
| B nhúng sắp lại | [39] | [39] | – | [0] |

Giá của bản nhúng: `ocr_feedbacks` 11,0 MB (240 B/document) → `ocr_feedbacks_embedded` 23,1 MB (508 B/document), tức thêm 12,2 MB dữ liệu trùng lặp (mỗi log chép vào mọi feedback của nó, và phải cập nhật ở nhiều nơi nếu log đổi; ứng dụng không sửa log sau khi ghi nên rủi ro này thấp).

## Tổng hợp NFR (mục tiêu giữ nguyên như đã đóng băng)

| NFR | Mục tiêu | Số đo | Kết luận |
|---|---|---|---|
| NFR-01 | Redis GET (AP-07/08) p95 < 5 ms | Dashboard người dùng p95 0,063 ms; Quán phổ biến p95 0,065 ms; Tổng quan quản trị p95 0,060 ms | Đạt |
| NFR-02 | GET nhanh hơn trượt ≥ 5× ở p50 | Dashboard người dùng 39×; Quán phổ biến 11×; Tổng quan quản trị 529× | Đạt |
| NFR-03 | ES p95 < 100 ms trên 100.000 giao dịch | typical: p95 5,65 ms (took p95 3 ms); heavy: p95 4,95 ms (took p95 3 ms) | Đạt |
| NFR-04 | "pho" tìm ra "Phở"; PG không bỏ dấu (giới hạn) | ES: tập kết quả của "pho" = "phở" (1.852 giao dịch, bỏ sót 0, P@20 20/20 (100 %)); PG: "phở" 1.233, "pho" 176 (bỏ sót 1.376) | Đạt phần đo ở đây (các phần còn lại ở TC-32..35) |
| NFR-05 | IXSCAN, totalDocsExamined = nReturned, p95 < 20 ms (Q-01..03, có index) | Q-01: p95 0,40 ms, docs/nReturned 1/1; Q-02: p95 0,51 ms, docs/nReturned 61/5; Q-03: p95 0,40 ms, docs/nReturned 5/5 | Một phần: Q-01, Q-03 đạt; Q-02 không đạt vế docs = nReturned |
| NFR-06 | Top 10 p95 < 5 ms, so với SQL | Redis ZREVRANGE p95 0,15 ms; Redis + tra tên p95 0,39 ms (p50 0,36); SQL p50 23,6 ms (66× chậm hơn đường Redis đầy đủ) | Đạt |

E6 độ trễ realtime (NFR-15), sao lưu/khôi phục (NFR-13) và `docker stats` (NFR-14) do Task 4 đo, xem các mục ngay sau (chép nguyên từ `bench_raw/task4.md`). JMeter ở mức ứng dụng không được chạy (tùy chọn, do người dùng chạy).

## E6. Độ trễ sự kiện realtime: Redis Pub/Sub → SSE (AP-15, AP-16; NFR-15)

Đo bằng bài đo JUnit `core-backend/src/test/java/vn/edu/huit/finance/core/Service/Realtime/AdminEventLatencyBench.java`
(không chạy trong `mvn test` thường: cần `-Dbench=true`), lúc 2026-10-27T20:44:01Z, cùng máy ở mục 0. Bài đo dùng
**đúng mã của app**: `AdminEventPublisher.publish` (gửi `PUBLISH ledgermind:admin-events`), `AdminEventRelay` đăng ký qua
`RealtimeConfig.listenerContainer` + `AdminEventSubscription`, và một Redis thật (Testcontainers, `redis:8.10-alpine`,
v=8.10.2, khởi động giống dịch vụ `redis` của `docker-compose.yml`). Emitter là lớp con của `SseEmitter` ghi
`System.nanoTime()` khi relay gọi `send`. Độ trễ của mỗi sự kiện = lúc emitter nhận − lúc gọi `publish`, trên cùng một đồng
hồ. 20 sự kiện khởi động (không tính) rồi 300 sự kiện đo, cách nhau 10 ms, 1 luồng phát, 1 emitter; phân vị nearest-rank.
Lệnh: `cd core-backend && TESTCONTAINERS_RYUK_DISABLED=true mvn -B -o test -Dtest=AdminEventLatencyBench -Dbench=true`.
Số thô: `bench_raw/E6.json` (cả 300 giá trị), `bench_raw/E6.txt`; ảnh S-88.

| Đường đi (ms) | p50 | p95 | p99 | max | trung bình | mất |
|---|---|---|---|---|---|---|
| `publish()` → `SseEmitter.send` (phía server) | 1,177 | 1,573 | 1,920 | 3,131 | 1,202 | 0 / 300 |
| riêng lời gọi `publish()` (bên phát) | 0,701 | 0,978 | 1,104 | 3,027 | 0,716 | – |

Kết luận NFR-15 (mục tiêu < 1 s sau PUBLISH): **Đạt cho phần phía server** (p95 1,6 ms, không mất sự kiện nào). **Không đo**
chặng từ `SseEmitter` qua HTTP tới trình duyệt (ghi dữ liệu ra response, proxy, mạng, `EventSource` của trình duyệt), vì
agent không chạy app; số này vì vậy là cận dưới của độ trễ người dùng thấy.

## Sao lưu – NFR-13 (MongoDB)

Trên stack demo `scripts/nosql/demo-stack.sh` (MongoDB 6.0.28, giới hạn 512M, WiredTiger cache 0,25 GB như
`docker-compose.yml`), dữ liệu demo `finance_nosql_demo` (36 `ocr_logs` + 36 `ocr_feedbacks`, 13 index, 2 validator), lúc
2026-10-28 04:52 (+07). Theo `scripts/nosql/backup_restore.md` mục 1a: `mongodump --archive --gzip` (file 4.612 byte) →
`dropDatabase()` → `time mongorestore --archive --gzip` → đếm lại. Ảnh S-61; số thô `bench_raw/task4_backup.json`.

| Lần | 1 (ảnh S-61) | 2 | 3 | 4 | 5 | 6 | trung vị (2–6) |
|---|---|---|---|---|---|---|---|
| `real` của `mongorestore` (giây) | 0,604 | 0,554 | 0,543 | 0,500 | 0,502 | 0,897 | 0,543 |

Số đếm sau khôi phục = trước khi xóa (36 / 36 / 13 index / 2 validator, ảnh S-61). Kết luận NFR-13 (khôi phục < 5 phút với
dữ liệu demo): **Đạt** cho `mongorestore` (dưới 1 giây). Phần "đồng hồ cho thao tác khôi phục trên `/admin/backup`" (S-66)
**chưa đo**: cần app chạy, người dùng chụp.

## Tài nguyên – NFR-14 (`docker stats --no-stream`, ảnh S-89)

Stack demo với giới hạn bộ nhớ **bằng `docker-compose.yml`** (Redis 192M với `maxmemory 128mb`, MongoDB 512M, Elasticsearch 1G
heap 512 MB bảo mật bật, Kibana 1G; `NOSQL_DEMO_ES_MEMORY=1G`), sau khi nạp lại dữ liệu demo và chạy Q-01..Q-41
(`mongodb_demo.js`, `redis_demo.txt`, Q-30..Q-40 bằng `curl`), lúc 2026-10-28 04:18–04:21 (+07).

| Container | Giới hạn | (1) Kibana tắt | (2) Kibana bật, 60 s sau khi đăng nhập |
|---|---|---|---|
| Redis | 192 MiB | 6,1 MiB (3,2 %) | 5,4 MiB (2,8 %) |
| MongoDB | 512 MiB | 84,2 MiB (16,5 %) | 83,8 MiB (16,4 %) |
| Elasticsearch | 1 GiB | 997,2 MiB (97,4 %), khởi động lại 0 lần | 1022 MiB (99,8 %), **khởi động lại 1 lần** |
| Kibana | 1 GiB | – (tắt) | 561,9 MiB (54,9 %) |
| Elasticvue / RedisInsight (công cụ demo, không có trong compose) | không giới hạn | 9,8 MiB / 142,8 MiB | 9,8 MiB / 138,3 MiB |

22 giây sau khi bật Kibana (04:19:04 → 04:19:26), kernel ghi "Memory cgroup out of memory: Killed process … (java)
anon-rss:1026016kB" trong cgroup của container Elasticsearch; Docker khởi động lại container (`restarts=1`;
`OOMKilled=false` vì tiến trình bị giết là `java`, không phải PID 1), và lần đăng nhập Kibana trong lúc đó thất bại. Cùng hiện
tượng xảy ra ở ít nhất 3 lần khác trong ngày, mỗi lần Kibana chạy cùng Elasticsearch 1G (một lần container khởi động lại
9 lần liên tiếp; nhật ký kernel 04:01:28, 04:15:18, 04:26:35). Kết luận NFR-14: Redis và MongoDB **Đạt** (dùng
dưới 20 % giới hạn); Elasticsearch 1G **KHÔNG đạt** khi Kibana bật (bị OOM-kill), và chỉ còn 3 % dư khi Kibana tắt. Các ảnh
Kibana/Elasticvue của Task 4 vì vậy chụp với `NOSQL_DEMO_ES_MEMORY=1536M` (mặc định của stack demo); ở mức đó Elasticsearch
dùng 1,15 GiB và không khởi động lại lần nào trong suốt các lần chụp.

## Kibana và Elasticvue – RAM và thời gian tải trang đầu (mục 2.5, ảnh S-14)

Đo lúc 2026-10-28 04:53 (+07) trên stack demo (Elasticsearch giới hạn 1,5 GiB): Playwright Chromium headless, hồ sơ trình
duyệt mới mỗi lần (cache trống), 5 lần; "tải xong" = phần tử chính hiện ra. Số thô `bench_raw/task4_tools.json`.

| Công cụ | RAM container (`docker stats`) | Image | Trang đầu, trung vị 5 lần |
|---|---|---|---|
| Kibana 8.11.4 | 631,4 MiB / 1 GiB | 1,67 GB | `/login` 1,38 s; sau khi bấm Log in tới Home 1,74 s |
| Elasticvue 1.16.0 (`cars10/elasticvue`, nginx + trang tĩnh) | 10,5 MiB | 105 MB | trang Home (Cluster Health) 0,25 s |

Elasticvue chạy hoàn toàn trong trình duyệt và gọi thẳng Elasticsearch (cần CORS), nên RAM của nó trên server gần như chỉ
là nginx; Kibana là một tiến trình Node.js riêng, có tài khoản `kibana_system` và chỉ mục hệ thống riêng trong Elasticsearch.

## Giới hạn của phép đo (đọc trước khi trích số)

- Đây là độ trễ **tầng dữ liệu** từ một client Python trong cùng mạng docker: không gồm Spring, JPA, Jackson, JWT hay mạng thật; phần Python (driver, `requests`, `json`) cộng vài chục đến vài trăm micro-giây vào mọi dòng, giống nhau cho các bên so sánh.
- Một máy, 12 luồng, mọi container cùng chia CPU; các thí nghiệm chạy tuần tự, mỗi thí nghiệm chỉ bật các container nó cần. Không có tải song song: cột Tải luôn là "1 luồng", nên ops/s là tốc độ một luồng đạt được chứ không phải sức chứa của hệ thống.
- Dữ liệu tổng hợp, phân bố do `gen_data.py` đặt ra (người dùng nặng 20 %, văn bản mẫu ngắn, 10 % không dấu): số tuyệt đối sẽ khác với dữ liệu thật; tỉ lệ giữa các bên và hình dạng kế hoạch truy vấn mới là điều đáng tin.
- Bộ nhớ đệm đã ấm (200 lần khởi động, dữ liệu nằm gọn trong RAM của PostgreSQL, WiredTiger cache 0,25 GB và Elasticsearch heap 512 MB). Số đo "nguội" (đĩa) không được đo.
- Elasticsearch chạy với bảo mật tắt (mạng riêng) và index không force-merge; PostgreSQL dùng cấu hình mặc định của image (compose cũng vậy).
- Thân yêu cầu Elasticsearch dựng lại từng trường của `ElasticsearchTransactionSearchEngine.hits`; không bắt được byte-by-byte yêu cầu mà Spring Data gửi.
- psycopg gửi số nguyên nhỏ dưới dạng smallint (JDBC gửi BIGINT); kế hoạch (`EXPLAIN`) vẫn dùng đúng index như nhau.

