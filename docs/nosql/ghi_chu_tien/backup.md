# Ghi chú Kiểm chứng Sao lưu / Khôi phục 3 CSDL NoSQL & Truy vấn Redis/ES (T4 & T5 — Phan Minh Tiến)

## 1. Quy trình 5 Bước Kiểm chứng Sao lưu & Khôi phục (`scripts/nosql/backup_restore.md`)
Nguyên tắc chung áp dụng cho cả 3 CSDL: **Đếm trước sao lưu -> Sao lưu -> Xóa / Thay đổi dữ liệu -> Khôi phục -> Đếm lại đối chiếu**.

### 1.1. MongoDB (`mongodump` / `mongorestore` và `mongoexport` / `mongoimport`)
- **Số đếm trước khi sao lưu (trên `finance_nosql_demo`):**
  - `ocr_logs`: `36` documents (`5` indexes, `1` `$jsonSchema` validator).
  - `ocr_feedbacks`: `36` documents (`8` indexes, `1` `$jsonSchema` validator).
  - Tổng cộng: `36 + 36` documents, `13` indexes, `2` validators.
- **Thao tác:** Chạy `mongodump --archive --gzip`, sau đó `dropDatabase()` và khôi phục bằng `mongorestore --archive --gzip --drop` (Minh chứng terminal: `S-61.png`, `S-62.png`, `S-86.png`, `S-87.png`).
- **Số đếm sau khi khôi phục:** Khớp tuyệt đối `36` `ocr_logs`, `36` `ocr_feedbacks`, `13` indexes và `2` validators; thời gian khôi phục trung vị trên stack demo đạt ~`0,543 s` (đạt yêu cầu `NFR-13`).

### 1.2. Redis (`dump.rdb` & Cơ chế Dựng lại từ PostgreSQL)
- **Trên Stack Demo:** Kiểm tra số lượng khóa bằng `DBSIZE`, xuất snapshot RDB bằng `redis-cli --rdb`, xóa thử và nạp lại trên container thử nghiệm khớp hoàn toàn số khóa ban đầu (`S-63.png`).
- **Trong kiến trúc LedgerMind:** Redis production cấu hình `--save '' --appendonly no` vì toàn bộ Cache thống kê và Bảng xếp hạng chi tiêu tháng (`ZSET`) đều có thể dựng lại chính xác 100% từ nguồn sự thật PostgreSQL thông qua trang `/admin/nosql`.

### 1.3. Elasticsearch (Snapshot Repository & Reindex từ PostgreSQL)
- **Số đếm trước khi sao lưu:** `GET transactions/_count` = `47` documents.
- **Thao tác:** Tạo kho lưu trữ `demo_repo` (`/usr/share/elasticsearch/snapshots`), chụp snapshot `snap-2026-10-28`, xóa chỉ mục `DELETE transactions` và gọi `_restore` (`S-07.png`, `S-64.png`).
- **Kiểm tra sau khôi phục:**
  - `GET transactions/_count` trả về đúng `47` documents.
  - Kiểm tra lại custom analyzer `POST transactions/_analyze` với analyzer `vi_folded` và chuỗi `"Phở Bò"` trả về đúng 2 token `["pho", "bo"]`.

## 2. Xác nhận Chạy Kiểm chứng Truy vấn Redis (`Q-17..Q-29`, `Q-41`) và Elasticsearch (`Q-30..Q-40`) (T5)
- **Redis (`scripts/nosql/redis_demo.txt`):** Đã kiểm tra các thao tác trên khóa OTP Hash (`HSET`, `HGETALL`, `HINCRBY`, `PTTL`), Cache-aside String (`SET ... EX`, `GET`, `DEL`), Bảng xếp hạng Sorted Set (`ZADD`, `ZREVRANGE ... WITHSCORES`, `ZRANK`, `ZSCORE`) và kênh Pub/Sub `ledgermind:admin-events` (`Q-41`) — Khớp với bộ ảnh `S-36..S-48`, `S-60`.
- **Elasticsearch (`scripts/nosql/elasticsearch/kibana-devtools.txt`):** Đã kiểm tra `_analyze` (`vi_folded`, `vi_autocomplete`), tìm kiếm khớp không dấu `"pho"`, gợi ý tiền tố, tìm kiếm mờ chịu lỗi chính tả (`fuzziness: "AUTO:4,7"`), lọc kết hợp khoảng tiền/ngày và thống kê `aggs` theo danh mục/tháng — Khớp với bộ ảnh `S-49..S-59`.
