# Stack demo NoSQL (`demo-stack.sh`)

Một lệnh dựng đủ các CSDL và công cụ GUI để chụp ảnh cho báo cáo NoSQL (danh sách ảnh: `docs/nosql/screenshots.md`):
MongoDB, Redis, Elasticsearch (bật bảo mật như bản thật), Kibana, Elasticvue, RedisInsight, kèm dữ liệu demo của
`scripts/nosql`. Stack này **tách hẳn** khỏi stack `finance-*` của `docker-compose.yml`: project `nosql-demo`, mạng
`nosql-demo`, volume riêng, mọi cổng chỉ mở trên `127.0.0.1` và khác cổng của stack thật. Không có app LedgerMind trong stack
này (ảnh app/trang admin chụp trên app chạy riêng).

## Chạy

Từ thư mục gốc của repo (cần Docker và Docker Compose v2):

```bash
scripts/nosql/demo-stack.sh up       # 2-3 phút lần đầu; in ra địa chỉ và tài khoản ở cuối
scripts/nosql/demo-stack.sh info     # in lại địa chỉ và tài khoản
scripts/nosql/demo-stack.sh status   # container + docker stats
scripts/nosql/demo-stack.sh load     # nạp lại dữ liệu demo (sau khi đã xóa/sửa thử)
scripts/nosql/demo-stack.sh down     # xóa container, mạng VÀ volume của stack demo
```

`up` làm theo thứ tự: bật MongoDB, Redis, Elasticsearch, Elasticvue, RedisInsight → đợi healthy → cấp quyền ghi thư mục
snapshot cho Elasticsearch → đặt mật khẩu `kibana_system` bằng API bảo mật (tài khoản `elastic`) → bật Kibana → nạp dữ liệu:

| CSDL | Dữ liệu sau `up` |
|---|---|
| MongoDB | `finance_nosql` (schema + index từ `mongodb_init.js`, không có document) và `finance_nosql_demo` (36 `ocr_logs` + 36 `ocr_feedbacks` từ `mongodb_demo.js`) |
| Redis | đã chạy `redis_demo.txt`, thêm lại bảng xếp hạng `ledgermind:leaderboard:spend:2026-10` và một OTP `ledgermind:password-reset-otp:sv01@huit.edu.vn` (TTL 5 phút) để xem đủ 3 kiểu key trong RedisInsight |
| Elasticsearch | index `transactions` tạo từ hai file settings/mapping thật của app + 47 document của `elasticsearch/transactions-bulk.ndjson` |

## Địa chỉ và tài khoản mặc định

| Công cụ | Địa chỉ | Đăng nhập |
|---|---|---|
| MongoDB Compass | `mongodb://root:demo-mongo-pass@127.0.0.1:27018/?authSource=admin` | có trong chuỗi kết nối |
| RedisInsight | http://localhost:5541 | database `nosql-demo-redis` đã được thêm sẵn |
| Redis (redis-cli ngoài máy) | `127.0.0.1:6380` | mật khẩu `demo-redis-pass` |
| Elasticsearch | http://localhost:9201 | `elastic` / `demo-elastic-pass` |
| Kibana | http://localhost:5602 | `elastic` / `demo-elastic-pass` |
| Elasticvue | http://localhost:8081 | cluster `nosql-demo` đã được thêm sẵn |

Mật khẩu là mật khẩu demo (stack chỉ mở trên 127.0.0.1 và xóa đi sau khi chụp), không phải mật khẩu thật. Đổi cổng hoặc mật
khẩu bằng biến môi trường, ví dụ `NOSQL_DEMO_KIBANA_PORT=5610 scripts/nosql/demo-stack.sh up`; danh sách biến
`NOSQL_DEMO_*` nằm ở đầu `demo-stack.sh` và trong `demo-stack.compose.yml`. Dùng cùng các biến đó cho mọi lệnh sau (`info`,
`load`, `down`).

## Khác với `docker-compose.yml` (và vì sao)

| Điểm | `docker-compose.yml` | Stack demo |
|---|---|---|
| Giới hạn bộ nhớ Elasticsearch | 1G | **1536M** mặc định. Đo ngày 28/10/2026: với 1G và bảo mật bật, Elasticsearch dùng ~990 MiB và bị kernel OOM-kill trong vòng nửa phút sau khi Kibana kết nối (ảnh S-89). Muốn đo đúng như compose (NFR-14): `NOSQL_DEMO_ES_MEMORY=1G` |
| Ngưỡng ổ đĩa của Elasticsearch | mặc định (90 %) | tắt (`cluster.routing.allocation.disk.threshold_enabled=false`): ổ đĩa máy dev trên 90 % làm cluster đỏ ngay khi khởi động. `NOSQL_DEMO_ES_DISK_THRESHOLD=true` để bật lại |
| CORS của Elasticsearch | không bật | bật, chỉ cho `localhost`/`127.0.0.1`, header `Authorization,Content-Type` (Elasticvue gọi Elasticsearch thẳng từ trình duyệt) |
| Mật khẩu `kibana_system` | đặt tay một lần | đặt bằng API `POST _security/user/kibana_system/_password`; không dùng `bin/elasticsearch-reset-password` vì công cụ này chạy thêm một JVM trong container Elasticsearch và làm nó vượt giới hạn 1G (bị OOM-kill, đã gặp hai lần) |
| Thư mục snapshot | volume `elasticsearch_snapshots` | volume riêng, `up` đổi chủ thư mục cho uid 1000; nếu không, mọi snapshot báo `access_denied_exception` (volume mới thuộc root) |
| Elasticvue, RedisInsight | không có | có, không giới hạn bộ nhớ (chỉ dùng để chụp ảnh) |

Các giá trị còn lại (image, lệnh chạy Redis có mật khẩu, `maxmemory 128mb`, không lưu đĩa, `KEYS`/`FLUSHALL`/`FLUSHDB` bị đổi
tên; MongoDB 512M với WiredTiger cache 0,25 GB; Elasticsearch heap 512 MB, `action.auto_create_index=false`, `path.repo`;
Kibana 1G) giống `docker-compose.yml`.

## Gỡ lỗi nhanh

- Kibana báo "Kibana server is not ready yet" hoặc đăng nhập báo lỗi: xem `docker inspect -f '{{.RestartCount}}'
  nosql-demo-es`; nếu số này tăng thì Elasticsearch đang bị OOM-kill (đang chạy với 1G?).
- Một CSDL trên máy đã dùng cổng mặc định: đặt `NOSQL_DEMO_*_PORT` khác rồi chạy lại `up`.
- Dọn sạch: `scripts/nosql/demo-stack.sh down` (xóa cả volume, dữ liệu demo nạp lại được bằng `up`).
