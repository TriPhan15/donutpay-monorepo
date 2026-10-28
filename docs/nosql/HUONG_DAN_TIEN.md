# Hướng dẫn cho Tiến: phần việc đồ án NoSQL (nhóm 38)

Đề tài: **Ứng dụng cơ sở dữ liệu MongoDB và bộ nhớ đệm Redis trong việc xây dựng hệ thống quản lý tài chính cá nhân** (Elasticsearch là CSDL tự tìm hiểu). Ứng dụng là LedgerMind: backend Spring Boot, app Flutter, web admin, PostgreSQL + MongoDB + Redis + Elasticsearch.

Trí đã viết xong phần code. Phần của Tiến là **minh chứng, tìm hiểu tool, kiểm tra, slide, video**. Đây là các phần được chấm điểm trực tiếp (tiêu chí 1–7, 10). Tiến làm và **commit bằng tài khoản GitHub của chính mình**, để bảng phân công trong báo cáo đối chiếu được với lịch sử commit.

---

## 1. Cài đặt (làm 1 lần)

1. Nhận lời mời collaborator của repo (Trí mời; repo đang private).
2. Cài: Git, Docker Desktop (hoặc Docker Engine), **MongoDB Compass**, **RedisInsight** (bản desktop), trình duyệt Chrome/Edge.
3. Lấy code và chuyển sang nhánh làm chung:
   ```bash
   git clone <link repo>
   cd donutpay-monorepo
   git checkout feature/nosql
   git config user.name  "Phan Minh Tien"
   git config user.email "<email GitHub của Tiến>"
   ```

## 2. Quy tắc làm chung nhánh `feature/nosql`

- Trước khi làm, luôn chạy `git pull --rebase`.
- Tiến **chỉ thêm hoặc sửa file trong các thư mục**:
  - `docs/nosql/screenshots/` (ảnh minh chứng `S-xx.png`);
  - `docs/nosql/tim_hieu_tool/` (ghi chú tìm hiểu Kibana và Elasticvue);
  - `docs/nosql/ghi_chu_tien/` (ghi chú kiểm tra, nhận xét, lỗi chính tả phát hiện).
- **Không sửa** `docs/nosql/build/`, `facts.md`, code trong `core-backend/` và `mobile-app/`. Các file đó do Trí sửa. Thấy chỗ sai thì ghi vào `docs/nosql/ghi_chu_tien/`.
- Commit nhỏ, mỗi việc một commit, message tiếng Việt rõ ràng. Ví dụ: `docs(nosql): ảnh minh chứng Q-01..Q-05 trên Compass`. Sau đó `git push`.
- Không commit file `.docx`, `.pptx` hay video (repo bỏ qua các file này). Gửi file cho Trí qua Drive hoặc Zalo.

## 3. Dựng CSDL demo trên máy (không cần chạy cả hệ thống)

Các lệnh dưới đây chạy ở thư mục gốc repo. Cổng được chọn để **không trùng** với stack chính, nếu máy đang chạy stack đó.

**MongoDB (cho Compass):**
```bash
docker run -d --name nosql-demo-mongo -p 127.0.0.1:27018:27017 -v "$PWD/scripts/nosql:/s:ro" mongo:6.0
docker exec -w /s nosql-demo-mongo mongosh --quiet mongodb_init.js
docker exec -w /s nosql-demo-mongo mongosh --quiet mongodb_demo.js
```
Mở Compass, kết nối `mongodb://127.0.0.1:27018`, rồi xem DB `finance_nosql` (schema, index) và `finance_nosql_demo` (dữ liệu mẫu).

**Redis (cho RedisInsight):**
```bash
docker run -d --name nosql-demo-redis -p 127.0.0.1:6380:6379 redis:8.10-alpine
docker exec -i nosql-demo-redis redis-cli < scripts/nosql/redis_demo.txt
```
Trong RedisInsight, thêm database `127.0.0.1:6380`.

**Elasticsearch + Kibana + Elasticvue (cho mục 2.5):** xem `scripts/nosql/elasticsearch/README.md` để nạp dữ liệu. Bản học tập nhanh, tắt bảo mật:
```bash
docker network create nosql-demo
docker run -d --name nosql-demo-es --net nosql-demo -p 127.0.0.1:9201:9200 \
  -e discovery.type=single-node -e xpack.security.enabled=false \
  -e http.cors.enabled=true -e 'http.cors.allow-origin=http://localhost:8081' \
  -e ES_JAVA_OPTS="-Xms512m -Xmx512m" elasticsearch:8.11.4
docker run -d --name nosql-demo-kibana --net nosql-demo -p 127.0.0.1:5602:5601 \
  -e ELASTICSEARCH_HOSTS=http://nosql-demo-es:9200 kibana:8.11.4
docker run -d --name nosql-demo-elasticvue -p 127.0.0.1:8081:8080 cars10/elasticvue
```
Kibana mở ở http://localhost:5602, Elasticvue ở http://localhost:8081 (kết nối `http://localhost:9201`).

**Dọn dẹp khi xong:**
```bash
docker rm -f nosql-demo-mongo nosql-demo-redis nosql-demo-es nosql-demo-kibana nosql-demo-elasticvue
docker network rm nosql-demo
```

> Đã có script `scripts/nosql/demo-stack.sh` (hướng dẫn: `scripts/nosql/demo-stack.README.md`). Script dựng toàn bộ phần trên bằng một lệnh (`up`, xóa bằng `down`), có bật bảo mật như bản thật và nạp sẵn dữ liệu demo. Chụp ảnh thì dùng script thay cho các lệnh ở trên.

## 4. Phần việc của Tiến

| # | Việc | Bắt đầu được khi nào | Kết quả nộp |
|---|---|---|---|
| T1 | Đọc hiểu hệ thống: file `docs/superpowers/specs/2026-10-26-nosql-report-and-elasticsearch-design.md`, thư mục `scripts/nosql/`, và 41 truy vấn Q-01..Q-41. Nắm vai trò của từng CSDL: MongoDB lưu bản sao phân tích lỗi AI; Redis lo cache, OTP, bảng xếp hạng và Pub/Sub cho sự kiện admin realtime (Q-41); Elasticsearch lo tìm kiếm tiếng Việt. | Ngay | Tự trả lời được các câu ở mục 5 |
| T2 | **MongoDB:** chạy `mongodb_init.js` và `mongodb_demo.js`, xem từng truy vấn Q-01..Q-16 trên Compass (tab Documents, Aggregations, Explain Plan, Indexes, Validation) | Ngay | Ghi chú `docs/nosql/ghi_chu_tien/mongodb.md`; ảnh chụp theo danh sách ở T6 |
| T3 | **Tìm hiểu Kibana và Elasticvue** (mục 2.5 của báo cáo, 2 điểm), theo 4 tiêu chí: (1) lý thuyết, kiến trúc, phiên bản, các bước cài đặt kèm ảnh; (2) các chức năng: quản lý index, Dev Tools, import/export, snapshot/restore, phân quyền, giám sát; (3) bảng so sánh: chức năng, giao diện, hỗ trợ truy vấn, hiệu năng, giấy phép, nền tảng, cộng đồng (có nguồn hoặc số đo, ví dụ RAM bằng `docker stats`); (4) phù hợp với loại ứng dụng nào và lý do, gắn với đề tài | Ngay | `docs/nosql/tim_hieu_tool/kibana_vs_elasticvue.md` + ảnh. Trí đưa vào báo cáo |
| T4 | **Chạy lại backup/restore** theo `scripts/nosql/backup_restore.md` cho cả 3 CSDL (đếm, xóa, khôi phục, đếm lại) | Ngay | Ghi số đếm trước và sau vào `ghi_chu_tien/backup.md` + ảnh |
| T5 | Chạy lại các truy vấn Redis (Q-17..Q-29, Q-41) và Elasticsearch (Q-30..Q-40) trên RedisInsight và Kibana Dev Tools | Ngay | Ghi chú + ảnh |
| T6 | **Chụp toàn bộ ảnh minh chứng** theo danh sách `docs/nosql/screenshots.md`, đặt tên đúng mã `S-xx.png`. **Cắt ảnh** chỉ giữ khung liên quan (Compass: vùng kết quả/Explain; trang admin: bảng hoặc thẻ đang minh họa, bỏ menu và vùng trống), vì ô ảnh trong báo cáo in chỉ khoảng 10 × 5,6 cm; chữ trong ảnh sau khi in phải đọc được | Khi Trí gửi danh sách | `docs/nosql/screenshots/S-xx.png` |
| T7 | Soát nội dung Chương 2 và Chương 5 của báo cáo (đúng kiến thức, khớp ảnh), và soát chính tả toàn bộ | Khi có bản báo cáo v1/v4 | `ghi_chu_tien/soat_bao_cao.md` |
| T8 | **Slide PowerPoint** dựa trên dàn ý `docs/nosql/slides_outline.md` (Trí làm bản đầu, Tiến hoàn thiện và tập thuyết trình) | Khi có dàn ý | File `.pptx` gửi Trí |
| T9 | **Quay video demo 5–7 phút** theo `docs/nosql/kich_ban_demo.md` | Khi có kịch bản | Link video |
| T10 | Đọc `docs/nosql/hoi_dap_bao_ve.md` và tập trả lời, nhất là phần MongoDB và Kibana | Khi có file | Sẵn sàng trả lời GV |

## 5. Tự kiểm tra hiểu bài (trả lời được thì làm T2–T5 nhanh)

1. Vì sao dữ liệu thô của AI vẫn lưu trong PostgreSQL, còn MongoDB chỉ giữ bản sao để phân tích?
2. `ocr_feedbacks` được ghi khi nào? Vì sao mỗi cặp (hóa đơn, trường) chỉ có một document? (Gợi ý: unique index `receipt_field_uq` + upsert `$setOnInsert`)
3. Quy tắc ESR khi tạo compound index là gì? Index `status_date_idx` phục vụ truy vấn nào?
4. Bảng xếp hạng tháng lưu ở đâu, kiểu dữ liệu Redis nào, TTL bao lâu, và vì sao dựng lại được từ PostgreSQL?
5. Vì sao gõ "pho" vẫn tìm ra "Phở"? (Gợi ý: analyzer `vi_folded` = lowercase + asciifolding)
6. Khi Redis hoặc Elasticsearch sập thì ứng dụng làm gì?
7. Vì sao không dùng Cassandra và Neo4j?
