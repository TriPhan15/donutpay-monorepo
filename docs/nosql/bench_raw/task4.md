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
