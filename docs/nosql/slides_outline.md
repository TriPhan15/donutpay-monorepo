# Dàn ý slide báo cáo NoSQL nhóm 38 (LedgerMind)

Dành cho Tiến dựng file `.pptx` bằng tay (việc R2 trong `docs/nosql/HUONG_DAN_TIEN.md` mục 4b). File này tự đủ: mỗi slide có tiêu đề, 3–5 ý chính, hình (đường dẫn thật), và lời nói. Thứ tự và mốc thời gian bám `docs/nosql/kich_ban_demo.md` (video demo 7 phút: 0:00–1:00, 1:00–3:00, 3:00–5:30, 5:30–7:00). Mọi con số lấy từ `docs/nosql/facts.md` và `docs/nosql/bench_results.md`.

## Quy tắc dựng

- 16:9, một theme đơn giản (nền sáng, một màu nhấn), chữ tối thiểu 18 pt, tiếng Việt có dấu (font Arial hoặc Calibri). Tiêu đề 28–32 pt, tối đa 2 dòng.
- Mỗi slide chỉ giữ 3–5 ý chính (các gạch đầu dòng bên dưới); phần "Lời nói" cho vào Notes của slide, không in lên slide.
- Hình chèn nguyên khung, không kéo méo, chữ trong hình phải đọc được khi chiếu. Ảnh chụp (S-xx) cắt chỉ giữ vùng liên quan.
- **Ảnh giữ chỗ:** các ảnh S-15, 16, 17, 20..35, 65..85 hiện vẫn là ô xám "S-xx – chưa chụp" (kiểm bằng `docs/nosql/screenshots.md`). Chụp xong, lưu đè đúng tên file rồi mới dựng slide. Mỗi slide dưới đây ghi rõ ảnh nào đã có thật (**có**) hay còn giữ chỗ (**giữ chỗ**).
- Cột "Thời lượng": slide thuộc kịch bản video ghi mốc phút của kịch bản; slide ghi "ngoài video" chỉ dùng khi báo cáo trực tiếp (cộng khoảng 1 phút mỗi slide).
- Không đưa lên slide: "Circuit Breaker" (đó là cơ chế dự phòng/fallback), "CQRS read model" như một sự thật (chỉ là phép so sánh), "không ảnh hưởng" (nói "vẫn trả lời" kèm độ trễ), việc server thật đang chạy Elasticsearch (chưa triển khai; mặc định `SEARCH_ENGINE=postgres`).
- Mọi số liệu đo ghi rõ "dữ liệu tổng hợp 100k (sinh bằng gen_data.py)", mọi số đếm demo ghi "dữ liệu demo".

Tổng cộng 20 slide.

---

## Slide 1. Bìa và nhóm

- Thời lượng: 0:00–0:20 (video)
- Tiêu đề: ỨNG DỤNG CƠ SỞ DỮ LIỆU MONGODB VÀ BỘ NHỚ ĐỆM REDIS TRONG VIỆC XÂY DỰNG HỆ THỐNG QUẢN LÝ TÀI CHÍNH CÁ NHÂN
- Nội dung (dòng chữ trên slide):
  - Bộ Công Thương – Trường ĐH Công Thương TP.HCM – Khoa CNTT
  - BÁO CÁO MÔN HỌC – DỮ LIỆU NOSQL, nhóm 38
  - Phan Thanh Trí (2001230977, nhóm trưởng), Phan Minh Tiến (2001230806)
  - GVHD: ThS. Ngô Minh Anh Thư
  - TP. Hồ Chí Minh, tháng 11 năm 2026
- Hình: không (hoặc logo trường nếu nhóm có).
- Lời nói: Giới thiệu tên đề tài và hai thành viên. Nói ngay: ứng dụng là LedgerMind (app Flutter, web quản trị, backend Spring Boot), PostgreSQL là nguồn sự thật; MongoDB và Redis là hai CSDL NoSQL chính, Elasticsearch là CSDL tự tìm hiểu.

## Slide 2. Bài toán và vì sao cần NoSQL

- Thời lượng: ngoài video (khoảng 1 phút)
- Tiêu đề: Bài toán và lý do dùng NoSQL
- Ý chính:
  - LedgerMind: ghi thu chi, quét hóa đơn bằng AI (DONUT V5), thống kê, tìm kiếm giao dịch.
  - Câu trả lời của AI là JSON bán cấu trúc, đổi theo phiên bản mô hình, cần thống kê chất lượng OCR.
  - Thống kê đọc rất nhiều, tính lại bằng SQL ở mỗi lần mở trang thì tốn.
  - Tìm kiếm tiếng Việt: gõ "pho" phải ra "Phở"; câu LIKE của PostgreSQL không bỏ dấu.
- Hình: `docs/nosql/diagrams/uc_tong_quat.png` (use case tổng quát), hoặc `docs/nosql/diagrams/ngu_canh.png` (sơ đồ ngữ cảnh), chọn một.
- Lời nói: Nhấn mạnh đây là bài toán có thật của ứng dụng đã có sẵn, không dựng dữ liệu cho hợp đề. Ba nhu cầu dẫn tới ba CSDL: dữ liệu AI linh hoạt (Document), đọc nhanh (Key-Value), tìm kiếm chữ (Search). Báo cáo mục 1.1.

## Slide 3. Kiến trúc tổng thể

- Thời lượng: 0:20–1:00 (video)
- Tiêu đề: Kiến trúc: PostgreSQL là nguồn sự thật, ba CSDL NoSQL
- Ý chính:
  - PostgreSQL giữ tiền, ví, giao dịch, hóa đơn, JSON thô của AI; ACID, khóa ví, khóa lạc quan.
  - Redis (Key-Value): cache thống kê, OTP quên mật khẩu, bảng xếp hạng chi tiêu tháng, Pub/Sub cho sự kiện quản trị.
  - MongoDB (Document): bản sao phân tích câu trả lời AI và chỗ người dùng sửa (`ocr_logs`, `ocr_feedbacks`).
  - Elasticsearch (CSDL tự tìm hiểu): tìm kiếm giao dịch tiếng Việt, dự phòng bằng PostgreSQL.
  - GUI tool: Compass, RedisInsight, Kibana.
- Hình: `docs/nosql/diagrams/arch_tong_the.png` (báo cáo mục 4.1). Có thể thêm `docs/nosql/diagrams/trien_khai.png` ở slide phụ nếu cần.
- Lời nói: Đúng lời kịch bản 0:20–1:00. Nói thêm một câu: ghi vào PostgreSQL trước, sau khi commit mới đồng bộ sang ba CSDL kia, nên CSDL NoSQL chậm hay chết không giữ yêu cầu của người dùng. Mỗi CSDL chạy một node, đây không phải cụm.

## Slide 4. Ma trận chọn CSDL, vì sao không Cassandra và Neo4j

- Thời lượng: ngoài video
- Tiêu đề: Vì sao chọn MongoDB, Redis, Elasticsearch; vì sao không Cassandra, Neo4j
- Ý chính (dựng thành bảng nhỏ 4 hàng: Dữ liệu / CSDL / lý do có số):
  - Cache thống kê, OTP, xếp hạng, Pub/Sub → Redis (GET p50 0,054 ms; top 10 nhanh hơn SQL 66×).
  - Câu trả lời thô AI, phản hồi OCR → MongoDB (document linh hoạt, aggregation, `$jsonSchema`).
  - Tìm kiếm giao dịch → Elasticsearch (chỉ mục đảo, asciifolding; "pho" bỏ sót 0 dòng so với 1.376/1.517 của LIKE).
  - Không dùng Cassandra (không có luồng ghi lớn theo thời gian, cụm cần ≥ 3 node) và Neo4j (quan hệ nông, một chiều, không AP duyệt ≥ 2 bước).
- Hình: `docs/nosql/diagrams/erd_da_csdl.png` (mọi dữ liệu NoSQL trỏ về khóa của PostgreSQL). Bảng dựng trên slide từ báo cáo mục 4.2 (bảng ma trận) và 4.6.
- Lời nói: Mỗi lựa chọn có AP (mẫu truy cập) và số đo đi kèm. Với Cassandra và Neo4j: nói là cân nhắc rồi loại, lý do nằm ở mục 4.6, không phải chưa biết. Số 66× và 1.376/1.517 là dữ liệu tổng hợp 100k.

## Slide 5. Thiết kế Redis

- Thời lượng: ngoài video
- Tiêu đề: Redis: bốn vai trò, khóa quy ước `ledgermind:…`
- Ý chính:
  - Cache-aside cho 4 cache thống kê, TTL 45–60 s có jitter 10%, xóa sau commit (rollback không xóa gì).
  - OTP: Hash `ledgermind:password-reset-otp:<email>`, Lua nguyên tử, hạn 5 phút, tối đa 3 lần sai.
  - Bảng xếp hạng: Sorted Set `ledgermind:leaderboard:spend:<yyyy-MM>`, score là tổng tuyệt đối, ghi bằng Lua `ZADD`/`ZREM`, không `ZINCRBY`.
  - Không lưu đĩa, `allkeys-lru`; mất thì dựng lại từ PostgreSQL (riêng OTP đang chờ thì xin mã mới).
- Hình: `docs/nosql/diagrams/redis_keys.png`; thêm `docs/nosql/diagrams/seq_bang_xep_hang.png` nếu còn chỗ.
- Lời nói: Báo cáo mục 4.3. Nếu bị hỏi vì sao Lua và vì sao không ZINCRBY: xem hoi_dap_bao_ve.md câu 10 và 11.

## Slide 6. Thiết kế MongoDB

- Thời lượng: ngoài video
- Tiêu đề: MongoDB: bản sao phân tích câu trả lời AI
- Ý chính:
  - Hai collection: `ocr_logs` (một log mỗi giao dịch, unique `transactionId`) và `ocr_feedbacks` (một document mỗi cặp hóa đơn và trường, unique `receipt_field_uq`).
  - Quan hệ bằng tham chiếu `transactionId`; Computed (`aiReading`, độ tin cậy) và Extended Reference.
  - 11 index theo quy tắc ESR, `status_date_idx {isResolved, reportedAt}`; `$jsonSchema` moderate + error.
  - Thống kê bằng aggregation: lỗi theo trường, theo mô hình, độ tin cậy theo tháng, tỉ lệ lần đọc bị sửa.
- Hình: `docs/nosql/diagrams/mongo_document.png` (document mẫu). Ảnh Compass S-15, S-16, S-17 hiện **giữ chỗ**; có ảnh thật thì thay hoặc thêm một ảnh.
- Lời nói: MongoDB không phải nguồn sự thật: JSON thô vẫn ở PostgreSQL. Độ tin cậy trong dữ liệu demo có, nhưng DONUT V5 thật không trả nên ứng dụng ghi null. Báo cáo mục 4.4.

## Slide 7. Thiết kế Elasticsearch (CSDL tự tìm hiểu)

- Thời lượng: ngoài video
- Tiêu đề: Elasticsearch: tìm kiếm tiếng Việt, gõ không dấu vẫn ra
- Ý chính:
  - Index `transactions`, 1 shard, 0 replica; mapping tạo từ file, không để dynamic.
  - Analyzer `vi_folded` = standard + lowercase + asciifolding; `vi_autocomplete` thêm edge_ngram 2..15.
  - Truy vấn thật của app: lọc `userId`, hai `multi_match` (khớp đúng boost 2, mờ `AUTO:4,7`, `prefix_length 1`).
  - Lỗi hoặc đang dựng lại chỉ mục thì trả lời bằng PostgreSQL ngay, phản hồi có trường `engine`.
- Hình: `docs/nosql/diagrams/es_mapping.png`; có thể thêm `docs/nosql/diagrams/seq_tim_kiem.png`. Ảnh Dev Tools S-04 (**có**) minh họa "pho" ra "Phở".
- Lời nói: Elasticsearch là CSDL tự tìm hiểu, không phải kỹ thuật nào khác. Mặc định `SEARCH_ENGINE=postgres`, bật Elasticsearch bằng profile `search`. Báo cáo mục 4.5.

## Slide 8. Mẫu truy cập (AP) tiêu biểu

- Thời lượng: ngoài video
- Tiêu đề: Từ yêu cầu đến cấu trúc dữ liệu: mẫu truy cập (AP)
- Ý chính (dựng bảng 6 hàng: AP / việc / CSDL / cấu trúc / nhất quán):
  - AP-02 Checkout chống trùng: PostgreSQL, khóa ví + `clientId` duy nhất, Strong.
  - AP-07 Đọc cache dashboard: Redis String JSON, Eventual (≤ 45–60 s).
  - AP-11 Top N chi tiêu tháng: Redis Sorted Set, `ZREVRANGE`.
  - AP-18 Upsert chỗ sửa OCR: MongoDB `$setOnInsert` + unique index.
  - AP-29 Tìm giao dịch của mình: Elasticsearch `bool` + `multi_match`; AP-31 dự phòng PostgreSQL.
- Hình: không (bảng); tham khảo `docs/nosql/diagrams/phan_cap_chuc_nang.png` nếu muốn một hình.
- Lời nói: Có 38 AP trong báo cáo (mục 3.6, bảng đầy đủ trong `facts.md` §2.2); mỗi AP có cấu trúc đáp ứng ở mục 4.11. Chọn 5 cái đại diện cho 4 CSDL. Quy tắc nhóm: không có AP thì không thêm cấu trúc.

## Slide 9. GUI tool: Kibana so với Elasticvue

- Thời lượng: ngoài video
- Tiêu đề: Tìm hiểu GUI tool: Kibana so với Elasticvue
- Ý chính (bảng nhỏ hai cột, số đo ngày 28/10/2026, trung vị 5 lần):
  - Kibana 8.11.4: đủ sáu nhóm chức năng (index, Dev Tools, import/export, snapshot, user/role, thống kê); RAM 631 MiB; image 1,67 GB; trang đầu 1,38 s.
  - Elasticvue 1.16.0: nhẹ, MIT, cần bật CORS; RAM 10,5 MiB; image 105 MB; trang đầu 0,25 s.
  - Kibana cần Elasticsearch ≥ 1,5 GB khi bật (ở 1 GB bị OOM-kill); Elasticvue không có dashboard hay nhập file.
  - Kết luận: việc quản trị có tổ chức (snapshot, phân quyền) làm trên Kibana, xem nhanh dùng Elasticvue.
- Hình: `docs/nosql/screenshots/S-14.png` (**có**, đo RAM/CPU/tải trang). Phụ: `S-04.png` (Dev Tools), `S-11.png` (Elasticvue), `S-07.png` (Snapshot) đều **có**.
- Lời nói: Đây là mục 2.5 của báo cáo, phần Tiến tìm hiểu và soát. Giấy phép và cộng đồng có nguồn [15], [16], [17] trong báo cáo; chỉ nói điều có nguồn. Kibana phù hợp ứng dụng phân tích log/số liệu trên Elasticsearch; trong LedgerMind nó là công cụ quản trị, bật khi cần.

## Slide 10. Demo nhóm 1 và 2: quản trị người dùng, thao tác trên CSDL

- Thời lượng: 1:00–2:10 (video)
- Tiêu đề: Demo (1) Quản trị người dùng và (2) Thao tác trên CSDL
- Ý chính:
  - Đăng nhập app và web quản trị (vai trò USER/ADMIN); Quên mật khẩu: OTP 6 số, thấy Hash trong RedisInsight với TTL đếm ngược từ 300 s.
  - `/admin/ocr-feedbacks`: lọc theo trường, đánh dấu đã xử lý, xóa một dòng; Compass thấy `isResolved` đổi.
  - `/admin/backup` thẻ MongoDB: Sao lưu, xóa thêm một phản hồi, Khôi phục; đếm lại bằng số trước khi xóa.
  - Mỗi thao tác mở GUI tool song song để thấy dữ liệu đổi thật.
- Hình (1 hoặc 2 ảnh, ghép ngang): `docs/nosql/screenshots/S-70.png` (OTP trong RedisInsight), `S-72.png` (trang OCR feedbacks), `S-73.png` (đã xử lý/xóa + Compass), `S-65.png`, `S-66.png` (backup/restore). Tất cả hiện **giữ chỗ**, Tiến chụp trên stack demo trước khi dựng.
- Lời nói: Đúng bảng kịch bản mục 2, hai dòng 1:00–1:30 và 1:30–2:10. Q-id liên quan: Q-17, Q-03, Q-07, Q-08. Nói rõ: ocr_feedbacks do người dùng sửa kết quả AI sinh ra tự động; trang web chỉ đọc, lọc, đánh dấu, xóa (không có trang tạo tay), phần REST thì có Postman (S-71).

## Slide 11. Demo nhóm 3 và 4: nghiệp vụ, chức năng hỗ trợ

- Thời lượng: 2:10–3:00 (video)
- Tiêu đề: Demo (3) Nghiệp vụ và (4) Thống kê hỗ trợ
- Ý chính:
  - Quét hóa đơn, sửa tổng tiền, lưu: document `ocr_feedbacks` mới (`fieldError` = `total_cost`) hiện trong Compass.
  - Sổ cái gõ "pho": app hiện các dòng "Phở"; Kibana `GET transactions/_doc/<id>` thấy document của giao dịch vừa tạo.
  - `/admin/dashboard`: top 5 chi tiêu tháng từ Sorted Set `ledgermind:leaderboard:spend:<yyyy-MM>`.
  - Trang chủ app: khóa `…:user-dashboard:<userId>` có TTL trong RedisInsight.
- Hình: `docs/nosql/screenshots/S-76.png`, `S-74.png`, `S-75.png`, `S-77.png`, `S-79.png`, `S-81.png` (mỗi slide chọn 2–3 ảnh). Tất cả hiện **giữ chỗ**.
- Lời nói: Đúng bảng kịch bản mục 2, hai dòng 2:10–2:40 và 2:40–3:00. Q-id: Q-09, Q-31, Q-19, Q-23. Giải thích một câu: sau khi PostgreSQL commit, ba bản sao được cập nhật bất đồng bộ nên có thể trễ một nhịp ngắn.

## Slide 12. Kỹ thuật nâng cao: đồng bộ sau commit và xử lý tranh chấp

- Thời lượng: ngoài video (khoảng 1,5 phút khi báo cáo trực tiếp)
- Tiêu đề: Kỹ thuật nâng cao: sự kiện sau commit và tranh chấp
- Ý chính:
  - `@TransactionalEventListener(AFTER_COMMIT)` + `@Async`: rollback không để lại gì ở NoSQL; NoSQL chậm hay chết không giữ yêu cầu người dùng.
  - Năm cơ chế tranh chấp: Lua + tổng tuyệt đối (xếp hạng), `$setOnInsert` + unique (chỗ sửa OCR), khóa ví PESSIMISTIC_WRITE, khóa lạc quan `@Version` trả 409, `clientId` chống checkout lặp.
  - Index MongoDB theo ESR; cache-aside; tác vụ `@Scheduled` mỗi 15 s chỉ để thử lại việc tạo index Elasticsearch.
  - Cửa sổ mất dữ liệu: JVM chết giữa commit và lần ghi nền thì chỉ chữa ở lần đổi sau, dựng lại hoặc reindex (thiết kế đã nêu, Outbox là hướng phát triển).
- Hình: `docs/nosql/diagrams/seq_dong_bo_index.png` (đồng bộ chỉ mục sau commit); phụ: `docs/nosql/diagrams/seq_sua_ocr.png`.
- Lời nói: Mỗi kỹ thuật có test chứng minh (TC-14, TC-15, TC-20..22, TC-48, TC-52..54). Báo cáo mục 4.13 và 4.7. Không nói `@Scheduled` hay `@Async` là "CSDL tự tìm hiểu": CSDL tự tìm hiểu là Elasticsearch.

## Slide 13. Realtime: Redis Pub/Sub sang SSE

- Thời lượng: 3:00–3:30 (video)
- Tiêu đề: Thông báo realtime cho quản trị: Redis Pub/Sub và SSE
- Ý chính:
  - Kênh `ledgermind:admin-events`; 4 loại sự kiện: hóa đơn chờ duyệt, chỗ sửa OCR mới, đã reindex, đã dựng lại bảng xếp hạng.
  - Mỗi instance API nghe kênh và đẩy tới các luồng SSE `GET /admin/events`; trình duyệt hiện toast và badge.
  - Tin không lưu (at-most-once), vì chỉ là thông báo; dữ liệu thật vẫn đọc từ trang quản trị.
  - Đo ở server (300 sự kiện): p50 1,18 ms, p95 1,57 ms, mất 0/300; chặng tới trình duyệt chưa đo.
- Hình: `docs/nosql/screenshots/S-88.png` (**có**, đo độ trễ), `S-60.png` (**có**, PUBLISH/SUBSCRIBE hai cửa sổ trên RedisInsight), `S-80.png` (toast trên web, **giữ chỗ**).
- Lời nói: Demo: hai tab web quản trị, tab 1 mở `/admin/nosql` và bấm "Dựng lại bảng xếp hạng", toast hiện ở tab 2 (Q-41). Realtime chỉ có trên web quản trị; push cho mobile (FCM) là hướng phát triển.

## Slide 14. Cache Redis và index MongoDB (số đo E4, E1)

- Thời lượng: 3:30–4:30 (video)
- Tiêu đề: Cache Redis và index MongoDB: số đo
- Ý chính:
  - Dashboard người dùng: Redis GET p50 0,054 ms so với 3 câu SQL 2,13 ms (39×); tổng quan quản trị 529×.
  - Demo: Postman `GET /api/transactions/app-dashboard` hai lần, lần 1 trượt, lần 2 trúng; RedisInsight thấy khóa và TTL.
  - Q-03 có index: IXSCAN `status_date_idx`, docs = nReturned = 5, p50 0,33 ms so với COLLSCAN 21,8 ms (65×).
  - Q-02 chỉ đạt một phần (kiểm tra 61 document để trả 5), nói thẳng ra.
- Hình: `docs/nosql/diagrams/bench_E4.png` và `docs/nosql/diagrams/bench_E1.png` (hai biểu đồ cạnh nhau, **có**); phụ `docs/nosql/screenshots/S-35.png` (Explain Plan, **giữ chỗ**).
- Lời nói: Kịch bản 3:30–4:00 và 4:00–4:30, Q-19 và Q-16. Đây là độ trễ ở tầng dữ liệu, một luồng, dữ liệu tổng hợp 100k (gen_data.py), không phải độ trễ API đầu cuối. Báo cáo mục 7.2.

## Slide 15. Chịu lỗi: dừng Redis, Elasticsearch, MongoDB

- Thời lượng: 4:30–5:15 (video)
- Tiêu đề: Một CSDL dừng, hệ thống vẫn trả lời
- Ý chính:
  - Dừng Redis: dashboard vẫn trả lời (đọc PostgreSQL); độ trễ quan sát: `____ ms` (điền sau khi quay).
  - Dừng Elasticsearch: tìm kiếm vẫn trả lời, trường `engine` đổi từ `elasticsearch` sang `postgres`; độ trễ quan sát: `____ ms`.
  - Dừng MongoDB: quét hóa đơn vẫn lưu, log ghi cảnh báo (nếu còn thời gian).
  - Mỗi CSDL một node, nên đây là "giảm chức năng nhưng vẫn trả lời", không phải failover. OTP cố ý báo lỗi vì mã không dựng lại được.
- Hình: `docs/nosql/screenshots/S-82.png` (engine elasticsearch rồi postgres), `S-83.png` (dừng Redis), `S-84.png` (dừng MongoDB). Cả ba hiện **giữ chỗ**; S-83 và S-84 cần stack đầy đủ của Trí. Phụ: `docs/nosql/diagrams/act_tim_kiem.png`.
- Lời nói: Hai ô `____ ms` phải điền bằng số quan sát thật khi quay (ghi vào bảng mục 7.3 của báo cáo, hằng `LAT`); chưa có thì để trống, không bịa. Lệnh: `docker compose stop redis` / `stop elasticsearch`, rồi `start`. Cơ chế dự phòng (`FallbackCacheErrorHandler`) không phải Circuit Breaker: lúc Redis treo mỗi yêu cầu vẫn tốn tối đa timeout lệnh 500 ms.

## Slide 16. Số đo tìm kiếm và bảng xếp hạng (E2, E3)

- Thời lượng: 5:15–5:30 (video)
- Tiêu đề: Elasticsearch và Sorted Set: số đo
- Ý chính:
  - Người dùng nặng (19.788 giao dịch): Elasticsearch p50 3,70 ms so với LIKE 78,2 ms (21×); không bỏ sót "Phở".
  - Người dùng điển hình (~80 dòng): PostgreSQL LIKE nhanh hơn (0,66 ms so với 3,70 ms); Elasticsearch thắng ở chất lượng, không phải ở tốc độ.
  - "pho": LIKE bỏ sót 1.376/1.517 dòng; Elasticsearch bỏ sót 0 (còn dương tính giả theo tiền tố, ví dụ "phòng").
  - Top 10 bảng xếp hạng: Redis kèm tra tên p50 0,36 ms so với SQL 23,6 ms (66×).
- Hình: `docs/nosql/diagrams/bench_E2.png` và `docs/nosql/diagrams/bench_E3.png` (**có**).
- Lời nói: Kịch bản 5:15–5:30. Nói cả kết quả ngược chiều (người dùng điển hình), vì giữ trung thực quan trọng hơn con số đẹp. Dữ liệu tổng hợp 100k, client Python cùng mạng docker, 1 luồng, phân vị nearest-rank. Biểu đồ E5 (`bench_E5.png`, $lookup và bản nhúng) để dành cho câu hỏi.

## Slide 17. Kiểm thử

- Thời lượng: ngoài video
- Tiêu đề: Kiểm thử: 707 test, 40 lớp, CSDL thật bằng Testcontainers
- Ý chính:
  - Lần chạy 28/10/2026 tại `b35cd6e`: 707 test, 40 lớp, 0 lỗi (lần 27/10/2026 tại `1cae4de`: 702 test); số đếm đọc từ surefire.
  - Redis, MongoDB, Elasticsearch, PostgreSQL 15 chạy thật bằng Testcontainers (OTP, cache, xếp hạng, upsert OCR, backup, tìm kiếm).
  - 55 ca TC có định danh, truy vết FR → AP → TC; trong đó 6 ca là script (explain, validator, unique, backup, Lua).
  - Tranh chấp có test hai luồng song song (TC-04, TC-54); Redis sập/treo có test riêng (TC-10, TC-11).
- Hình: không (bảng số liệu). Dựng bảng nhỏ: Lớp tiêu biểu / số test / CSDL thật, lấy từ `facts.md` §4.
- Lời nói: Báo cáo mục 7.1. Không đếm `@Test` mà đọc từ báo cáo surefire. Widget test mobile của ô tìm kiếm không nằm trong lần chạy này.

## Slide 18. Hạn chế và hướng phát triển

- Thời lượng: 5:30–7:00 (video)
- Tiêu đề: Hạn chế và hướng phát triển
- Ý chính (hạn chế, 5:30–6:15):
  - Chế độ tìm kiếm PostgreSQL không bỏ dấu; ghi NoSQL sau commit, bất đồng bộ, nhất quán cuối cùng (JVM dừng giữa chừng thì chờ lần đổi sau hoặc reindex).
  - Một node mỗi CSDL, không replication hay sharding; realtime chỉ trên web; DONUT V5 không trả độ tin cậy (null).
  - Elasticsearch 1 GB bị OOM khi bật Kibana; Q-02 chưa đạt "docs = nReturned".
  - Server thật chưa triển khai, mặc định `SEARCH_ENGINE=postgres`.
- Ý chính (hướng phát triển, 6:15–7:00): push mobile (FCM), MongoDB replica set, Redis Sentinel, Elasticsearch nhiều node, Prometheus + Grafana, tìm kiếm bỏ dấu ở PostgreSQL (unaccent, trigram), Outbox.
- Hình: không. Có thể chia slide làm hai cột "Hạn chế" và "Hướng phát triển".
- Lời nói: Báo cáo mục 7.4 (hạn chế L1–L20 trong `facts.md` §3) và 8.5. Chốt: Outbox là việc đầu tiên vì nó đóng được cửa sổ mất dữ liệu sau commit. Còn một lỗ hổng bảo mật đã ghi trong báo cáo: web quản trị đang tắt CSRF, phải bật lại trước khi triển khai.

## Slide 19. Phân công công việc

- Thời lượng: ngoài video
- Tiêu đề: Phân công và đóng góp
- Ý chính (theo `facts.md` §0 [Q3], không thêm bớt):
  - Phan Thanh Trí (nhóm trưởng, khoảng 60%): phân tích, kiến trúc, toàn bộ code (PostgreSQL, Redis, Elasticsearch, trang quản trị, realtime, backup), dựng báo cáo.
  - Phan Minh Tiến (khoảng 40%): MongoDB (truy vấn, minh chứng Compass), tìm hiểu Kibana/Elasticvue, chụp ảnh trên stack demo, chạy lại script và backup/restore, soát Chương 2 và 5, slide, video demo, soát chính tả.
  - Tiến commit bằng tài khoản GitHub riêng; ảnh do công cụ tự chụp trên stack demo không ghi công cho ai.
  - Ngày bắt đầu/kết thúc từng việc: điền theo thực tế (git không phân biệt được vì cùng một tài khoản).
- Hình: không (bảng bảng 1.6 b của báo cáo).
- Lời nói: Nói đúng sự thật, không ghi Tiến viết phần code đã có. Tỉ lệ phần trăm là nhóm tự thống nhất. Báo cáo mục 1.6 và 8.3; hướng dẫn việc của Tiến ở `docs/nosql/HUONG_DAN_TIEN.md` (T1–T10).

## Slide 20. Hỏi đáp

- Thời lượng: ngoài video
- Tiêu đề: Cảm ơn thầy/cô. Xin mời đặt câu hỏi
- Ý chính:
  - Tên đề tài, nhóm 38, hai thành viên (nhắc lại ngắn).
  - Mã nguồn: nhánh `main` của repo (repo riêng tư, GV được thêm làm collaborator hoặc nhận kèm zip source).
  - Video demo: link (điền khi có).
  - Phụ lục: biểu đồ dự phòng E5, bảng AP đầy đủ.
- Hình: `docs/nosql/diagrams/bench_E5.png` đặt trong một slide ẩn ngay sau slide này (slide dự phòng cho câu về `$lookup` và bản nhúng).
- Lời nói: Mở sẵn `docs/nosql/hoi_dap_bao_ve.md`. Câu hỏi về MongoDB để Tiến trả lời trước, câu về thiết kế và code để Trí trả lời trước. Những câu không chắc thì nói đúng giới hạn của hệ thống (xem mục hạn chế), không hứa điều chưa làm.

---

## Danh sách hình dùng (kiểm tra tồn tại ngày 28/10/2026)

Có thật, dùng được ngay:
- `docs/nosql/diagrams/`: uc_tong_quat, ngu_canh, arch_tong_the, trien_khai, erd_da_csdl, redis_keys, mongo_document, es_mapping, seq_tim_kiem, seq_bang_xep_hang, seq_dong_bo_index, seq_sua_ocr, act_tim_kiem, phan_cap_chuc_nang, bench_E1, bench_E2, bench_E3, bench_E4, bench_E5 (đều `.png`).
- `docs/nosql/screenshots/` ảnh thật: S-04, S-07, S-11, S-14, S-60, S-88.

Còn là ảnh giữ chỗ (Tiến chụp rồi lưu đè): S-15, S-16, S-17, S-35, S-65, S-66, S-70, S-72, S-73, S-74, S-75, S-76, S-77, S-79, S-80, S-81, S-82, S-83, S-84 (S-71 chỉ nhắc trong lời nói slide 10; S-78 và S-85 không dùng). Không có biểu đồ riêng cho E6 (độ trễ realtime); dùng ảnh S-88.
