# Elasticsearch trong LedgerMind: tạo index, nạp dữ liệu mẫu, chạy truy vấn

Elasticsearch giữ **một bản sao chỉ để tìm kiếm** của bảng `transactions` (index `transactions`). PostgreSQL vẫn là nguồn
dữ liệu chính: mất index thì dựng lại bằng `POST /api/admin/search/reindex`. App cập nhật index bất đồng bộ sau khi
PostgreSQL commit; lỗi Elasticsearch chỉ được ghi log và API tìm kiếm tự rơi về PostgreSQL.

| File | Nội dung |
|---|---|
| `transactions-bulk.ndjson` | 47 giao dịch tiếng Việt của 3 người dùng (userId 1, 2, 3), tháng 8-10/2026, dạng `_bulk` |
| `kibana-devtools.txt` | Truy vấn Q-30 ... Q-40 (5 cơ bản + 6 nâng cao) dán vào Kibana Dev Tools |
| `../../../core-backend/src/main/resources/elasticsearch/transactions-settings.json` | settings + analyzer thật của app (không sao chép lại ở đây) |
| `../../../core-backend/src/main/resources/elasticsearch/transactions-mapping.json` | mapping thật của app |

Hai analyzer tự định nghĩa trong settings: `vi_folded` (lowercase + asciifolding: "Phở" và "pho" cùng token `pho`) và
`vi_autocomplete` (thêm `edge_ngram` 2..15: "Highlands" thành `hi`, `hig`, `high`, ...). Mapping dùng `vi_folded` cho
các trường văn bản, thêm trường con `.autocomplete` cho `vendorName`, `note` và `.keyword` cho `categoryName`.

## Cách chạy (từ thư mục gốc của repo)

Dùng container dùng một lần, tách khỏi stack đang chạy (không mở cổng, không bảo mật để demo gọn):

```bash
docker network create --internal es-demo
docker run -d --name es-demo --network es-demo \
  -e discovery.type=single-node -e xpack.security.enabled=false -e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
  -v "$PWD:/w:ro" elasticsearch:8.11.4
# đợi khỏe (khoảng 20-40 giây)
until docker exec es-demo curl -s localhost:9200/_cluster/health | grep -q '"status":"\(green\|yellow\)"'; do sleep 3; done
```

**1. Tạo index từ hai file thật của app** (`settings` + `mappings` ghép lại bằng shell, không cần công cụ ngoài `curl`):

```bash
docker exec -w /w es-demo sh -c '
  printf "{\"settings\":%s,\"mappings\":%s}" \
    "$(cat core-backend/src/main/resources/elasticsearch/transactions-settings.json)" \
    "$(cat core-backend/src/main/resources/elasticsearch/transactions-mapping.json)" |
  curl -s -X PUT localhost:9200/transactions -H "Content-Type: application/json" --data-binary @-'
```

**2. Nạp dữ liệu mẫu** (kết quả phải có `"errors":false`):

```bash
docker exec -w /w es-demo curl -s "localhost:9200/_bulk?refresh=true" \
  -H "Content-Type: application/x-ndjson" --data-binary @scripts/nosql/elasticsearch/transactions-bulk.ndjson
docker exec es-demo curl -s localhost:9200/transactions/_count      # {"count":47,...}
```

**3. Chạy truy vấn**: dán từng khối trong `kibana-devtools.txt` vào Kibana Dev Tools. Không có Kibana thì dùng `curl`, ví dụ
truy vấn thật của app cho từ khóa `pho` (Q-35) là khối `GET transactions/_search` thứ ba mang nhãn Q-35. Truy vấn phải trả
các dòng "Phở ..." của user 1 lên đầu và không có dòng của user 2 hoặc 3.

**4. Dọn dẹp**: `docker rm -f es-demo && docker network rm es-demo`.

Trên stack thật (`docker compose --profile search up -d`, bảo mật bật): thêm `-u elastic:$ELASTIC_PASSWORD` vào `curl` và
gọi `localhost:9200`. Nếu app đã chạy với `SEARCH_ENGINE=elasticsearch` thì app tự tạo index từ hai file trên khi khởi
động / reindex, nên không cần bước 1 và 2: dữ liệu thật đến từ PostgreSQL, chỉ dùng `transactions-bulk.ndjson` để demo.

## Quan hệ với API

| Việc | API của app | Truy vấn tương ứng |
|---|---|---|
| Người dùng tìm giao dịch | `GET /api/transactions/search?q=pho&page=0&size=20` | Q-35 (truy vấn thật), Q-36, Q-37 |
| Admin dựng lại index từ PostgreSQL | `POST /api/admin/search/reindex` | Q-30 (kiểm tra số document) |
| Thống kê theo danh mục / tháng | (chưa có API, minh họa khả năng aggregation) | Q-39, Q-40 |
