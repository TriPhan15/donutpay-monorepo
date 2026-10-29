# Dàn ý báo cáo NoSQL nhóm 38 (đầu vào của make_skeleton.py)

Cú pháp (make_skeleton.py đọc từ dòng `---` đầu tiên trở xuống):
- `#` = Heading1 (CHƯƠNG n, tự đánh số), `##` = Heading2 (n.m), `###` = Heading3 (n.m.k), `####` = Heading4.
- Số thứ tự viết trong dòng chỉ để người đọc dàn ý; make_skeleton bỏ phần số đầu dòng, Word tự đánh số theo style.
- `{cN_x}` = mã dòng giữ chỗ `[T7.cN_x]` ngay dưới tiêu đề (content module thay bằng HEADING_PLACEHOLDERS).
- Dòng `>` dưới tiêu đề = mô tả nội dung cần viết, in vàng sau mã giữ chỗ.
- Tiêu đề phải duy nhất trong cả quyển (make_skeleton kiểm tra).
- Bám template `REFS_NoSQL_SRS&SDS_Template.docx` từng tiêu đề, với các điều chỉnh của plan Task 1.

---

# 1. TỔNG QUAN ĐỀ TÀI {c1_0}
> Mở chương (1–2 câu). Ngân sách cả chương: 4–5 trang.

## 1.1 BỐI CẢNH VÀ LÝ DO CHỌN ĐỀ TÀI {c1_1}
> "Ứng dụng có sẵn" = LedgerMind (app mobile + web admin Thymeleaf), mở rộng theo hướng 1; vì sao cần NoSQL (dữ liệu AI bán cấu trúc, thống kê đọc nhiều, tìm kiếm tiếng Việt). Trích [1], [2], [3].

## 1.2 MỤC TIÊU ĐỀ TÀI {c1_2}
> Mục tiêu đo được, lấy từ NFR đã đóng băng trong facts.md §2.3 (ghi "mục tiêu").

## 1.3 PHẠM VI ĐỀ TÀI {c1_3}
> Trong phạm vi / ngoài phạm vi (Cassandra, Neo4j, cluster nhiều node, Kafka, push mobile).

## 1.4 PHƯƠNG PHÁP THỰC HIỆN {c1_4}
> Phương pháp và mốc tuần 6/7/11.

## 1.5 CÔNG NGHỆ SỬ DỤNG {c1_5}
> Bảng công nghệ kèm phiên bản (facts.md §1.0).

## 1.6 KẾ HOẠCH DỰ ÁN {c1_6}
> a)–f) là chữ đậm, không phải tiêu đề: a) cơ cấu tổ chức (Họ tên · MSSV · Vai trò · Phụ trách CSDL); b) bảng phân công (Mã · Công việc · Người thực hiện · Bắt đầu · Kết thúc · Sản phẩm bàn giao · Trạng thái) chỉ theo [Q3], ô ngày để vàng; c) SDLC và lý do; d) giai đoạn, mốc tuần 6/7/11; e) công cụ; f) kế hoạch kiểm thử, đạt = đạt NFR mục 3.4. Ghi công (facts.md §0): mỗi người chỉ được ghi những ảnh/việc thật sự do mình làm (cột "Người chụp" facts.md §2.6 sau khi sửa theo thực tế); ảnh agent chụp không ghi công cho ai.

# 2. TỔNG QUAN NOSQL VÀ TÌM HIỂU TOOL {c2_0}
> Mở chương. Ngân sách cả chương: 10–12 trang; chỉ viết những gì đồ án dùng.

## 2.1 TỔNG QUAN VỀ NOSQL {c2_1}
> Giới thiệu, lịch sử, thuật ngữ; NoSQL vs RDBMS; ưu nhược; ACID vs BASE; CAP [4], [5]; PACELC [6].

## 2.2 PHÂN TÁN DỮ LIỆU {c2_2}
> Sharding, replication, mức nhất quán (strong, eventual, tunable) [7].

## 2.3 PHÂN LOẠI NOSQL {c2_3}
> Bảng 4 họ (Key-Value, Document, Column-family, Graph) + vị trí của Elasticsearch: search engine có kho document trên chỉ mục ngược Lucene [8], [9], nằm ngoài 4 họ → CSDL tự tìm hiểu.

## 2.4 CÁC HỆ QUẢN TRỊ ĐỀ TÀI SỬ DỤNG {c2_4}
> Mở mục: PostgreSQL giữ vai trò nguồn sự thật; ba hệ NoSQL dưới đây.

### Hệ quản trị MongoDB {c2_4_1}
> Đặc điểm; cài đặt/cấu hình (compose); Database, Collection, Document, Field; References, Embedded, Tree Structures, Atomic Operations; cú pháp chính [10]; GUI tool MongoDB Compass [11] (trích lần đầu ở đây).

### Hệ quản trị Redis {c2_4_2}
> Đặc điểm; cài đặt/cấu hình; Key, Value; String, Hash, List, Set, Sorted Set; TTL, Lua, Pub/Sub [12]; GUI tool Redis Insight [13] (trích lần đầu ở đây).

### Hệ quản trị Elasticsearch {c2_4_3}
> Đặc điểm; cài đặt (profile search, security); index, document, mapping, analyzer; Query DSL [14].

## 2.5 TÌM HIỂU GUI TOOL KIBANA, SO SÁNH VỚI ELASTICVUE {c2_5}
> Tiêu chí 1–4, mỗi tiêu chí 0,5 điểm; đúng tiêu chí so sánh của template; mọi nhận định giấy phép/cộng đồng/hiệu năng có nguồn [15], [16], [17] (trích lần đầu theo thứ tự này) hoặc số đo (S-14).

### Lý thuyết và cài đặt Kibana {c2_5_1}
> Giới thiệu, kiến trúc, phiên bản 8.11.4; các bước cài đặt kèm ảnh S-01, S-02, S-10.

### Các chức năng của Kibana {c2_5_2}
> Quản lý index, Dev Tools, import/export, snapshot/restore, phân quyền, giám sát (S-03..S-09).

### So sánh Kibana với Elasticvue {c2_5_3}
> Bảng: chức năng, giao diện, hỗ trợ truy vấn, hiệu năng (đo), giấy phép, nền tảng, cộng đồng (S-11..S-14).

### Kibana phù hợp với loại ứng dụng nào {c2_5_4}
> Loại ứng dụng, lý do, ví dụ thực tế, gắn với LedgerMind.

# 3. ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS) {c3_0}
> Mở chương: khung IEEE 830 / ISO/IEC/IEEE 29148 [18], [19].

## 3.1 GIỚI THIỆU TÀI LIỆU SRS {c3_1}
> Mục đích, đối tượng đọc, phạm vi sản phẩm, định nghĩa, tài liệu tham chiếu.

## 3.2 MÔ TẢ TỔNG QUAN {c3_2}
> Context diagram; tác nhân; ràng buộc (free tier/1 máy, 1 node mỗi CSDL, Java/Dart); giả định và phụ thuộc.

## 3.3 YÊU CẦU CHỨC NĂNG {c3_3}
> Bảng FR → AP (facts.md §2.1); đặc tả use case chính (tiền điều kiện, luồng chính/thay thế, hậu điều kiện, dữ liệu đọc/ghi theo CSDL).

### Mô hình hóa nghiệp vụ (Business Process Modeling) {c3_3_1}
> Quy trình thực tế; BPMN quét hóa đơn có swimlane; dữ liệu sinh/đọc ở mỗi bước.

### Mô hình hóa chức năng (Functional Modeling) {c3_3_2}
> Use case, activity ×3, sequence ×4, state machine hóa đơn (PROCESSING dành sẵn), DFD mức 0/1; mỗi sơ đồ ghi CSDL tham gia.

## 3.4 YÊU CẦU PHI CHỨC NĂNG {c3_4}
> Bảng NFR đóng băng (facts.md §2.3) với cách kiểm chứng.

## 3.5 YÊU CẦU DỮ LIỆU {c3_5}
> a) 3V kèm nguồn số đếm + đoạn "4 loại dữ liệu"; b) ERD khái niệm + từ điển dữ liệu.

## 3.6 MẪU TRUY CẬP DỮ LIỆU (ACCESS PATTERNS) {c3_6}
> Bảng AP đóng băng (facts.md §2.2).

## 3.7 YÊU CẦU GIAO DIỆN {c3_7}
> Màn hình thật: **dùng lại** S-67, S-68, S-69, S-72, S-74, S-76, S-77, S-78, S-80, S-81 (không có khung ảnh riêng; tham chiếu hình ở 6.3 hoặc chèn lại); danh sách API (facts.md §1.5); phần cứng/phần mềm.

## 3.8 MA TRẬN TRUY VẾT YÊU CẦU {c3_8}
> FR → AP → CSDL/cấu trúc → TC.

# 4. THIẾT KẾ CƠ SỞ DỮ LIỆU VÀ HỆ THỐNG (SDS) {c4_0}
> Mở chương: khung IEEE 1016 [20]; quy tắc vàng: mỗi AP có cấu trúc đáp ứng.

## 4.1 KIẾN TRÚC TỔNG THỂ {c4_1}
> Sơ đồ kiến trúc và triển khai (container, cổng, profile); vai trò từng thành phần.

## 4.2 LỰA CHỌN LOẠI CƠ SỞ DỮ LIỆU {c4_2}
> Ma trận: nhóm dữ liệu/AP → CSDL → lý do → phương án loại; JSON thô AI ở PG vì vòng đời hóa đơn. So sánh CQRS [21] (trích lần đầu ở đây).

## 4.3 THIẾT KẾ CSDL KEY-VALUE [REDIS] {c4_3}
> Quy ước khóa `ledgermind:<tính năng>:…`; bảng key; cache-aside + xóa sau commit, jitter, allkeys-lru; không persistence; RDB/AOF, Sentinel/Cluster ở mức thiết kế; trích Lua. Spring Data Redis [22] (trích lần đầu ở đây).

## 4.4 THIẾT KẾ CSDL DOCUMENT [MONGODB] {c4_4}
> Embed/reference; pattern (Computed, Extended Reference); document mẫu; bảng index (ESR); `$jsonSchema`; pipeline; explain (E1); replica set/shard key ở mức thiết kế. Spring Data MongoDB [23] (trích lần đầu ở đây).

## 4.5 THIẾT KẾ CSDL SEARCH/DOCUMENT [ELASTICSEARCH] – CSDL TỰ TÌM HIỂU {c4_5}
> Settings, analyzer, mapping, truy vấn thật; nhất quán (sau commit, chặn tự tạo index, reindex); cluster ở mức thiết kế. Spring Data Elasticsearch [24] (trích lần đầu ở đây).

## 4.6 CASSANDRA VÀ NEO4J: KHÔNG SỬ DỤNG {c4_6}
> Lý do không dùng, dựa trên ma trận 4.2.

## 4.7 ĐỒNG BỘ DỮ LIỆU GIỮA CÁC CSDL (POLYGLOT PERSISTENCE) {c4_7}
> Nguồn sự thật từng nhóm; sự kiện sau commit thay vì Outbox/Change Streams/MQ và vì sao; cửa sổ mất dữ liệu khi JVM chết; xử lý lỗi.

## 4.8 PHÂN TÁN, SAO CHÉP VÀ CAP {c4_8}
> Bảng CAP/PACELC từng CSDL (hiện tại 1 node + thiết kế cụm).

## 4.9 BẢO MẬT, SAO LƯU, GIÁM SÁT {c4_9}
> Vai trò, TLS, chống injection toán tử `$`/multi_match; lịch backup; giám sát (actuator; Prometheus/Grafana là hướng phát triển).

## 4.10 THIẾT KẾ MODULE VÀ API {c4_10}
> Sơ đồ module; danh sách API: phương thức · endpoint · mô tả · CSDL · AP.

## 4.11 MA TRẬN ÁNH XẠ AP → THIẾT KẾ {c4_11}
> AP · CSDL · cấu trúc · lệnh.

## 4.12 MÔ HÌNH HÓA CẤU TRÚC (STRUCTURAL MODELING) {c4_12}
> Sơ đồ lớp có stereotype; ERD PostgreSQL; bảng ánh xạ thực thể (annotation thật).

## 4.13 CÁC KỸ THUẬT NÂNG CAO {c4_13}
> Mỗi kỹ thuật: vấn đề, đoạn mã, bằng chứng trước/sau, test chứng minh: @Async + @TransactionalEventListener; @Scheduled tạo index; xử lý tranh chấp (Lua, `$setOnInsert` + unique, khóa ví, khóa lạc quan 409, clientId); index ESR, cache-aside; realtime Pub/Sub + SSE.

# 5. XÂY DỰNG CƠ SỞ DỮ LIỆU VÀ TRUY VẤN TRÊN GUI TOOL {c5_0}
> Mở chương: tiêu chí 5, 6, 7.

## 5.1 MÔI TRƯỜNG CÀI ĐẶT {c5_1}
> Máy, phiên bản từng hệ và GUI tool, cấu hình một node.

## 5.2 TẠO CƠ SỞ DỮ LIỆU {c5_2}
> `mongodb_init.js`; tạo index ES; quy ước key/TTL Redis (S-15, S-16, S-18, S-19).

## 5.3 NHẬP DỮ LIỆU CHO ỨNG DỤNG {c5_3}
> Bảng nguồn và số đếm (dữ liệu demo / tổng hợp 100k) (S-17).

## 5.4 TRUY VẤN CƠ BẢN TRÊN GUI TOOL {c5_4}
> Bảng Q cơ bản (facts.md §2.4) với lệnh và ảnh S-(n+19).

## 5.5 TRUY VẤN NÂNG CAO ĐÁP ỨNG YÊU CẦU ỨNG DỤNG {c5_5}
> Bảng Q nâng cao, mỗi CSDL đủ hai loại.

## 5.6 IMPORT/EXPORT, SAO LƯU VÀ KHÔI PHỤC {c5_6}
> Đếm → xóa → khôi phục → đếm lại cho từng CSDL. MongoDB S-61, S-62, S-65, S-66; Redis S-63 (RDB) + S-86 (nhập `redis-cli <`, xuất `redis-cli --rdb`); Elasticsearch S-19, S-64 (snapshot) + S-87 (xuất `_search`, nhập `_bulk`). Thời gian khôi phục MongoDB (NFR-13) từ `bench_results.md`.

# 6. KẾT NỐI ỨNG DỤNG VÀ DEMO {c6_0}
> Mở chương: tiêu chí 8, 9.

## 6.1 KIẾN TRÚC ỨNG DỤNG {c6_1}
> Tham chiếu 4.1, 4.10; cấu trúc project, các tầng.

## 6.2 KẾT NỐI CSDL VỚI PHẦN MỀM {c6_2}
> Cấu hình/repository thật dạng mã nguồn kèm đường dẫn; xử lý lỗi kết nối từng CSDL.

## 6.3 DEMO CÁC CHỨC NĂNG THEO MÔ TẢ BÀI TOÁN {c6_3}
> 4 nhóm: quản trị người dùng; thao tác CSDL (thêm/xóa/sửa/tìm/backup); nghiệp vụ; hỗ trợ (thống kê, realtime); ghi rõ thao tác nào chỉ có REST (S-65..S-81).

## 6.4 KẾT QUẢ ÁP DỤNG KỸ THUẬT NÂNG CAO {c6_4}
> Kết quả của các kỹ thuật mục 4.13 (S-80, S-82, S-88).

# 7. KIỂM THỬ VÀ ĐÁNH GIÁ {c7_0}
> Mở chương.

## 7.1 KIỂM THỬ CHỨC NĂNG {c7_1}
> Bảng TC (facts.md §2.5) với kết quả lần chạy facts.md §4 (ngày, số đếm surefire).

## 7.2 ĐÁNH GIÁ HIỆU NĂNG {c7_2}
> "Khuyến khích, không có trong thang điểm"; bảng theo cột của template; biểu đồ E1–E5; E6 độ trễ realtime p50/p95 (NFR-15, S-88); `docker stats` (NFR-14, S-89); thời gian khôi phục (NFR-13).

## 7.3 KIỂM THỬ CHỊU LỖI {c7_3}
> Redis/ES/Mongo sập: "vẫn trả lời" kèm độ trễ quan sát; không khẳng định failover.

## 7.4 THẢO LUẬN KẾT QUẢ {c7_4}
> Vì sao đạt/không đạt; đánh đổi; hạn chế (facts.md §3).

# 8. KẾT QUẢ ĐẠT ĐƯỢC VÀ TỔNG KẾT HOẠT ĐỘNG NHÓM {c8_0}
> Mở chương.

## 8.1 KẾT QUẢ ĐẠT ĐƯỢC {c8_1}
> Chức năng · % hoàn thành · ghi chú.

## 8.2 ĐÁNH GIÁ KẾT QUẢ THEO MỤC TIÊU {c8_2}
> NFR so với số đo Chương 7.

## 8.3 TỔNG KẾT HOẠT ĐỘNG NHÓM {c8_3}
> Theo [Q3]: hoàn thành so với bảng 1.6, % đóng góp, cách phối hợp. Cùng quy tắc ghi công như 1.6 (facts.md §0): chỉ ghi ảnh/việc người đó thật sự làm; ảnh agent không ghi công.

## 8.4 RÚT KINH NGHIỆM {c8_4}
> Quy trình nhóm; lựa chọn và thiết kế NoSQL.

## 8.5 HƯỚNG PHÁT TRIỂN {c8_5}
> Push mobile, cluster/replica, Prometheus/Grafana, tìm kiếm bỏ dấu ở chế độ PG, outbox.

## 8.6 ĐỐI CHIẾU TIÊU CHÍ ĐÁNH GIÁ {c8_6}
> Bảng barem: tiêu chí 1–10 (10 = 4 ý theo [Q1]), yêu cầu tối thiểu Mongo/Redis, ≥1 CSDL tự tìm hiểu, ≥4 loại dữ liệu, SRS/SDS, file nộp → mục, minh chứng, trạng thái.

# 9. TÀI LIỆU THAM KHẢO VÀ PHỤ LỤC {c9_0}
> Mở chương.

## 9.1 TÀI LIỆU THAM KHẢO {c9_1}
> Danh sách IEEE theo thứ tự trích lần đầu (docs/nosql/references.md).

## 9.2 PHỤ LỤC A: CẤU TRÚC THƯ MỤC MÃ NGUỒN {c9_2}
> Cây thư mục chính của repo.

## 9.3 PHỤ LỤC B: TRÍCH DOCKER-COMPOSE {c9_3}
> Các service CSDL (mã nguồn).

## 9.4 PHỤ LỤC C: HƯỚNG DẪN CHẠY DEMO {c9_4}
> Lệnh dựng stack demo và chạy script.

## 9.5 PHỤ LỤC D: KỊCH BẢN DEMO 5–7 PHÚT {c9_5}
> Bảng 4 phần của template (0:00–1:00, 1:00–3:00, 3:00–5:30, 5:30–7:00), mỗi dòng nêu màn hình/lệnh/Q-id.
