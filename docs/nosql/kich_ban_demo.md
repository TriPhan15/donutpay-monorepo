# Kịch bản demo 5–7 phút – báo cáo NoSQL nhóm 38 (LedgerMind)

Dùng cho buổi báo cáo trực tiếp hoặc quay video (việc T9 của Tiến trong `docs/nosql/HUONG_DAN_TIEN.md`). Bảng rút gọn của
kịch bản này nằm trong báo cáo Word, Phụ lục D (mục 9.5). Bốn phần và thời lượng theo yêu cầu của môn học; mỗi thao tác demo mở
GUI tool song song để thấy dữ liệu thay đổi thật. Cột cuối ghi mã truy vấn (Q-xx, `scripts/nosql`) hoặc ảnh minh chứng (S-xx,
`docs/nosql/screenshots.md`) của cùng thao tác.

## 0. Chuẩn bị (trước khi bấm quay)

Phần 2–3 cần **ứng dụng chạy** (app di động hoặc trình giả lập, web quản trị, Postman), nên dùng hệ thống đầy đủ của Trí, không
dùng stack demo (stack demo không có ứng dụng).

| Bước | Việc | Lệnh / màn hình |
|---|---|---|
| 0.1 | Bật hệ thống có Elasticsearch | `.env`: `SEARCH_ENGINE=elasticsearch`, có `ELASTIC_PASSWORD`, `REDIS_PASSWORD`; `docker compose --profile search up -d` (thêm `--profile tools` nếu cần Kibana) |
| 0.2 | Có dữ liệu để demo | đăng nhập tài khoản demo trên app; có vài giao dịch tên "Phở …" và ít nhất một hóa đơn đã quét |
| 0.3 | Mở sẵn các cửa sổ | MongoDB Compass (`finance_nosql`), RedisInsight (Redis của hệ thống), Kibana Dev Tools, Postman (`scripts/nosql/NoSQL_Postman_Collection.json`), hai tab web quản trị, một terminal ở thư mục gốc repo |
| 0.4 | Mở sẵn slide | slide bìa, sơ đồ kiến trúc (Hình mục 4.1), biểu đồ E1–E4 (`docs/nosql/diagrams/bench_E*.png`) |
| 0.5 | Đồng hồ | ghi lại độ trễ Postman hiển thị ở phần 3 (dừng dịch vụ) để điền vào bảng mục 7.3 |

## 1. Giới thiệu (0:00–1:00)

| Thời lượng | Màn hình / lệnh | Nói gì | Q-id, ảnh |
|---|---|---|---|
| 0:00–0:20 | Slide bìa | Tên đề tài, nhóm 38: Phan Thanh Trí (nhóm trưởng), Phan Minh Tiến; GVHD ThS. Ngô Minh Anh Thư | – |
| 0:20–1:00 | Slide sơ đồ kiến trúc (mục 4.1) | PostgreSQL là nguồn sự thật; Redis (key-value): cache thống kê, OTP, bảng xếp hạng, Pub/Sub; MongoDB (document): bản sao phân tích câu trả lời AI và chỗ người dùng sửa; Elasticsearch (CSDL tự tìm hiểu): tìm kiếm tiếng Việt. Công cụ: Compass, RedisInsight, Kibana | – |

## 2. Giao diện và tính năng theo phân quyền (1:00–3:00)

Theo bốn nhóm chức năng của tiêu chí 9.

| Thời lượng | Nhóm | Màn hình / lệnh | Dữ liệu thấy đổi ở | Q-id, ảnh |
|---|---|---|---|---|
| 1:00–1:30 | 1. Quản trị người dùng | App: đăng nhập. Web: trang đăng nhập quản trị → trang người dùng (cột vai trò). App: Quên mật khẩu → nhập email → màn hình OTP | RedisInsight: Hash `ledgermind:password-reset-otp:<email>`, TTL đếm ngược từ 300 s | S-67, S-68, S-69, S-70; Q-17 |
| 1:30–2:10 | 2. Thao tác trên CSDL | `/admin/ocr-feedbacks`: lọc theo trường, đánh dấu đã xử lý một dòng, xóa một dòng. `/admin/backup`, thẻ MongoDB: Sao lưu → xóa thêm một phản hồi → Khôi phục | Compass `finance_nosql.ocr_feedbacks`: bấm Refresh, `isResolved` đổi, document mất; sau khôi phục đếm lại bằng số trước khi xóa | S-72, S-73, S-65, S-66; Q-03, Q-07, Q-08 |
| 2:10–2:40 | 3. Nghiệp vụ | App: quét một hóa đơn, sửa tổng tiền → lưu. Sổ cái: gõ "pho" | Compass: document `ocr_feedbacks` mới (`fieldError` = `total_cost`); app hiện các dòng "Phở"; Kibana Dev Tools `GET transactions/_doc/<id>` của giao dịch vừa tạo | S-76, S-74, S-75; Q-09, Q-31 |
| 2:40–3:00 | 4. Chức năng hỗ trợ | `/admin/dashboard`: top 5 chi tiêu tháng. App: trang chủ | RedisInsight: Sorted Set `ledgermind:leaderboard:spend:<yyyy-MM>`; khóa `…:user-dashboard:<userId>` có TTL | S-77, S-79, S-81; Q-19, Q-23 |

## 3. Tính năng nâng cao, tối ưu hệ thống (3:00–5:30)

| Thời lượng | Nội dung | Màn hình / lệnh | Kết quả cần thấy | Q-id, ảnh |
|---|---|---|---|---|
| 3:00–3:30 | Realtime (Redis Pub/Sub → SSE) | Hai tab web quản trị; tab 1 mở `/admin/nosql`, bấm "Dựng lại bảng xếp hạng" | Toast hiện ở tab 2, badge sidebar tăng | S-78, S-80; Q-41 |
| 3:30–4:00 | Cache Redis | Postman: `GET /api/transactions/app-dashboard` hai lần | Lần 1 (trượt) chậm hơn lần 2 (trúng); RedisInsight thấy khóa và TTL; nói số đo E4 (GET 0,054 ms so với 3 câu SQL 2,13 ms ở p50) | Q-19; biểu đồ E4 |
| 4:00–4:30 | Index MongoDB, explain() | Compass → `ocr_feedbacks` → Explain Plan của truy vấn Q-03 | FETCH → IXSCAN trên `status_date_idx`, số khóa = số document đọc = số trả về; biểu đồ E1 (có/không index 65× ở p50) | S-35; Q-16; E1 |
| 4:30–4:55 | Dừng Redis | Terminal: `docker compose stop redis` → Postman gọi lại `app-dashboard` → `docker compose start redis` | **Vẫn trả lời** (đọc PostgreSQL); độ trễ quan sát: `____ ms` (ghi lại, điền vào mục 7.3) | S-83 |
| 4:55–5:15 | Dừng Elasticsearch | Terminal: `docker compose stop elasticsearch` → Postman `GET /api/transactions/search?q=pho` → `docker compose start elasticsearch` | **Vẫn trả lời**, trường `engine` đổi từ `elasticsearch` sang `postgres`; độ trễ quan sát: `____ ms` | S-82 |
| 5:15–5:30 | Benchmark | Slide biểu đồ E2 (tìm kiếm) và E3 (bảng xếp hạng) | Elasticsearch 3,70 ms so với LIKE 78,2 ms ở người dùng nặng, không bỏ sót "Phở"; top 10 Redis nhanh hơn SQL 66× | E2, E3 |

Lưu ý khi nói: mỗi CSDL chạy một node, nên đây không phải failover; hệ thống chỉ **giảm chức năng nhưng vẫn trả lời**. Nếu có
thời gian, dừng thêm MongoDB (`docker compose stop mongodb`), quét hóa đơn vẫn lưu được, log ghi cảnh báo (S-84), rồi bật lại.

## 4. Hạn chế và hướng phát triển (5:30–7:00)

| Thời lượng | Nội dung | Màn hình | Mục báo cáo |
|---|---|---|---|
| 5:30–6:15 | Hạn chế: chế độ tìm kiếm PostgreSQL không bỏ dấu; ghi NoSQL sau commit, nhất quán cuối cùng (JVM dừng giữa chừng thì chờ lần đổi sau hoặc reindex); một node mỗi CSDL; realtime chỉ trên web; Elasticsearch 1 GB bị OOM khi bật Kibana; Q-02 chưa đạt "đọc bằng số trả về" | Slide hạn chế | 7.4 |
| 6:15–7:00 | Hướng phát triển: push di động (FCM), MongoDB replica set, Redis Sentinel, Elasticsearch nhiều node, Prometheus + Grafana, tìm kiếm bỏ dấu ở PostgreSQL (unaccent, trigram), outbox | Slide hướng phát triển | 8.5 |

## Sau khi quay

- Điền hai số `____ ms` vào ô "Quan sát" của bảng mục 7.3 (`docs/nosql/build/content_c7_c9.py`, hằng `LAT`), chụp S-82, S-83,
  S-84 nếu chưa có.
- Gửi link video cho Trí để điền vào phiếu minh chứng.
