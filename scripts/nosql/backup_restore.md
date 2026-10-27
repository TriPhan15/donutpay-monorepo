# Sao lưu và khôi phục MongoDB, Redis, Elasticsearch (đồ án NoSQL)

Mỗi phần đi theo một nhịp: **đếm → xóa → khôi phục → đếm lại**, và hai số đếm trước/sau phải bằng nhau. Các lệnh dưới đây
chạy trong **container dùng một lần** (`docker run --rm`, không mở cổng), không đụng tới stack `finance-*` đang chạy.
Thư mục `scripts/nosql` được gắn vào container ở `/s` (chỉ đọc), mã nguồn app ở `/w`. Kết quả ghi bên dưới là kết quả chạy
thật ngày 2026-10-27.

> Vai trò của từng DB quyết định việc sao lưu: **PostgreSQL là nguồn dữ liệu chính**. MongoDB (phân tích OCR) quan trọng
> vừa phải; Redis và Elasticsearch **chỉ là bản sao dựng lại được** từ PostgreSQL, nên với chúng "khôi phục" thường rẻ hơn
> "sao lưu" (xem ghi chú cuối mỗi phần).

---

## 1. MongoDB

Đếm bằng: số document mỗi collection, số index, số collection có `$jsonSchema` validator.

### 1a. `mongodump` / `mongorestore` (nhị phân, giữ cả index và validator) - cách nên dùng

```bash
docker run --rm --network none -v "$PWD/scripts/nosql:/s:ro" mongo:6.0 bash -c '
  mongod --fork --logpath /tmp/m.log >/dev/null && cd /s && mongosh --quiet mongodb_demo.js >/dev/null   # tạo 36 + 36 document
  mongodump --quiet --db finance_nosql_demo --archive=/tmp/demo.archive.gz --gzip                         # SAO LƯU
  mongosh --quiet --eval "db.getSiblingDB(\"finance_nosql_demo\").dropDatabase()"                         # XÓA
  mongorestore --quiet --archive=/tmp/demo.archive.gz --gzip                                              # KHÔI PHỤC
'
```

| Bước | ocr_logs | ocr_feedbacks | index | validator |
|---|---|---|---|---|
| 1. đếm trước | 36 | 36 | 12 | 2 |
| 2. sau khi xóa database | 0 | 0 | 0 | 0 |
| 3. đếm sau khi khôi phục | **36** | **36** | **12** | **2** |

(12 index = 5 của `ocr_logs` + 7 của `ocr_feedbacks`, tính cả `_id_`.)

### 1b. `mongoexport` / `mongoimport` (JSON, từng collection)

Dùng `--jsonFormat=canonical` để giữ kiểu `Long` và `Date`: nếu xuất dạng thường thì `transactionId` trở thành số nguyên
32-bit và bị `$jsonSchema` validator từ chối khi nhập lại. Vì `mongoexport` không mang theo index/validator, phải tạo lại
schema bằng chính `mongodb_init.js` rồi mới nhập:

```bash
mongoexport --db finance_nosql_demo --collection ocr_logs      --jsonFormat=canonical --out=/tmp/ocr_logs.jsonl
mongoexport --db finance_nosql_demo --collection ocr_feedbacks --jsonFormat=canonical --out=/tmp/ocr_feedbacks.jsonl
mongosh --quiet --eval 'db.getSiblingDB("finance_nosql_demo").dropDatabase()'                                    # XÓA
mongosh --quiet --eval 'var TARGET_DB="finance_nosql_demo"; load("mongodb_init.js")'                            # schema + index
mongoimport --db finance_nosql_demo --collection ocr_logs      --file /tmp/ocr_logs.jsonl                       # KHÔI PHỤC
mongoimport --db finance_nosql_demo --collection ocr_feedbacks --file /tmp/ocr_feedbacks.jsonl
```

| Bước | ocr_logs | ocr_feedbacks | index | validator |
|---|---|---|---|---|
| 1. đếm trước (file xuất: 36 + 36 dòng) | 36 | 36 | 12 | 2 |
| 2. sau khi xóa database | 0 | 0 | 0 | 0 |
| 3. đếm sau khi nhập lại | **36** | **36** | **12** | **2** |

Sau khi nhập, `findOne({transactionId: NumberLong("1025")})` vẫn trả `transactionId: Long('1025')` và `createdAt` kiểu `ISODate`.

### Trên stack thật

```bash
docker compose exec mongodb sh -c 'mongodump -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" \
    --authenticationDatabase admin --db finance_nosql --archive --gzip' > finance_nosql-$(date +%F).archive.gz
docker compose exec -T mongodb sh -c 'mongorestore -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" \
    --authenticationDatabase admin --archive --gzip --drop' < finance_nosql-2026-10-27.archive.gz
```

`--drop` thay thế collection hiện có. Ghi trước khi khôi phục: dữ liệu `ocr_logs` / `ocr_feedbacks` ghi sau thời điểm sao
lưu sẽ mất; các sửa lỗi OCR đó vẫn còn ở PostgreSQL nên không phải dữ liệu duy nhất.

---

## 2. Redis

Đếm bằng: `DBSIZE`, `ZCARD` của bảng xếp hạng, phần tử đứng đầu bảng.

**Trung thực về production:** Redis của dự án chạy `--save '' --appendonly no` (không ghi đĩa) và đã đổi tên `FLUSHALL` /
`FLUSHDB` / `KEYS` thành rỗng. Lý do: cache thống kê, bảng xếp hạng và OTP đều dựng lại được (cache tự nạp lại, bảng xếp
hạng dựng lại từ PostgreSQL, chỉ OTP đang chờ là mất, người dùng bấm gửi lại), nên không đáng chi phí ghi đĩa. Phần dưới là
bài tập sao lưu cho môn học, chạy trên container demo có RDB bật; **không** áp lên stack thật.

### 2a. RDB: `SAVE` + sao chép `dump.rdb` + khởi động lại với file đó

```bash
docker run --rm --network none -v "$PWD/scripts/nosql:/s:ro" redis:8.10-alpine sh -c '
  redis-server --daemonize yes --dir /tmp/bk --dbfilename dump.rdb >/dev/null; sleep 1
  redis-cli < /s/redis_demo.txt >/dev/null                         # nạp dữ liệu demo
  redis-cli ZADD ledgermind:leaderboard:spend:2026-10 4200000 1 6850000 2 9100000 4
  redis-cli SAVE && cp /tmp/bk/dump.rdb /tmp/bk/backup.rdb         # SAO LƯU
  redis-cli FLUSHALL                                               # XÓA (chỉ được vì là container demo)
  redis-cli SHUTDOWN NOSAVE; cp /tmp/bk/backup.rdb /tmp/bk/dump.rdb
  redis-server --daemonize yes --dir /tmp/bk --dbfilename dump.rdb # KHÔI PHỤC = khởi động lại với file RDB
'
```

| Bước | DBSIZE | ZCARD leaderboard | đứng đầu |
|---|---|---|---|
| 1. đếm trước | 5 | 3 | user 4, 9100000 |
| 2. sau `FLUSHALL` | 0 | - | - |
| 3. đếm sau khi khôi phục | **5** | **3** | **user 4, 9100000** |

TTL được giữ: `ledgermind:default:v1:user-dashboard:1` đặt `EX 285`, sau khôi phục còn `TTL = 281`.

Lưu ý khi chạy lệnh trong `redis_demo.txt` ngay trước `SAVE`: file đó kết thúc bằng `BGSAVE`, lệnh `SAVE` ngay sau sẽ báo
"Background save already in progress"; đợi vài giây hoặc kiểm tra `INFO persistence`.

### 2b. Xuất RDB qua mạng không cần vào máy chủ: `redis-cli --rdb`

```bash
redis-cli --rdb /tmp/bk/remote.rdb      # "Transfer finished with success after 585 bytes"
```

Dùng khi Redis ở máy khác (thêm `-h host -a "$REDIS_PASSWORD"`); file thu được dùng được giống 2a. Sao chép một key sang key
khác: `COPY ledgermind:leaderboard:spend:2026-10 ledgermind:leaderboard:spend:2026-10-copy` trả `1`, `ZCARD` của bản sao = 3.

---

## 3. Elasticsearch

Đếm bằng: `GET transactions/_count`. Container demo bật `path.repo=/tmp/snap` (stack thật dùng
`/usr/share/elasticsearch/snapshots`, volume `elasticsearch_snapshots`, xem `docker-compose.yml`).

### 3a. Snapshot / restore (cách chính thức)

```bash
curl -X PUT  localhost:9200/_snapshot/demo_repo -H 'Content-Type: application/json' -d '{"type":"fs","settings":{"location":"/tmp/snap"}}'
curl -X PUT  'localhost:9200/_snapshot/demo_repo/snap-2026-10-27?wait_for_completion=true' -H 'Content-Type: application/json' \
     -d '{"indices":"transactions","include_global_state":false}'                                  # SAO LƯU
curl -X DELETE localhost:9200/transactions                                                         # XÓA
curl -X POST 'localhost:9200/_snapshot/demo_repo/snap-2026-10-27/_restore?wait_for_completion=true' -H 'Content-Type: application/json' \
     -d '{"indices":"transactions","include_global_state":false}'                                  # KHÔI PHỤC
```

| Bước | `_count` |
|---|---|
| 1. đếm trước (snapshot `"state":"SUCCESS"`) | 47 |
| 2. sau khi xóa index | lỗi `index_not_found_exception` |
| 3. đếm sau khi khôi phục | **47** |

Analyzer cũng được khôi phục: `_analyze` với `vi_folded` trên "Phở Bò" vẫn trả hai token `pho`, `bo`.

### 3b. Xuất / nhập bằng `_search` và `_bulk`

Xuất: `GET transactions/_search?size=1000` (47 document, đếm được bằng số `_id`). Nhập lại: tạo index từ hai file thật của app
rồi nạp `transactions-bulk.ndjson` (lệnh trong `elasticsearch/README.md`); sau khi xóa index và nhập lại, `_bulk` trả
`"errors":false` và `_count` = **47**.

### Cách rẻ nhất: dựng lại từ PostgreSQL

Index chỉ là bản sao, nên sau mất mát hoặc sau khi khôi phục PostgreSQL, chỉ cần `POST /api/admin/search/reindex` (xóa
index và nạp lại toàn bộ từ PostgreSQL). Snapshot chỉ đáng giá khi dữ liệu rất lớn và reindex quá lâu.
