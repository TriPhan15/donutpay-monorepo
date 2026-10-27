"""Nội dung Chương 1 (Tổng quan đề tài) và Chương 2 (Tổng quan NoSQL và tìm hiểu Tool) – báo cáo NoSQL nhóm 38.

Dựng v1 từ v0: python3 builder_nosql.py <thư mục giải nén v0> content_c1_c2.py
Nguồn sự thật: docs/nosql/facts.md (CODE_SHA 1cae4de), bench_results.md (số đo), screenshots.md (S-xx), references.md
([1]–[17] trích lần đầu theo thứ tự trong hai chương này), HUONG_DAN_TIEN.md (việc của Tiến, bảng 1.6 b).
Ngày "Kết thúc" của việc Trí đã xong = ngày commit trong lịch sử nhánh feature/nosql (a24fe68, 5bd6fea, 2169cd4, cd77f70,
ffcfe58, 1378b75, 38328fd, 9112ead, 93b4e1b, 6a019cd, 327833e, 7f07caa, b35cd6e, f7babd9, ec2ff6c); mọi ngày chưa biết là ô
tô vàng ⟦…⟧ (builder_nosql: inline ⟦chữ⟧ = nghiêng + tô vàng). Văn bản không trích facts.md (tệp làm việc nội bộ).
"""

SESSION_TAG = None
SECTIONS = {}
RENUMBER = True

CHUA = "⟦chưa có⟧"

# --------------------------------------------------------------------------------------------------------------------
# CHƯƠNG 1
# --------------------------------------------------------------------------------------------------------------------

C1_0 = [
    ("p", "Chương này giới thiệu ứng dụng có sẵn được mở rộng, lý do cần NoSQL, mục tiêu đo được, phạm vi, phương pháp, "
          "công nghệ và kế hoạch thực hiện của nhóm 38."),
]

C1_1 = [
    ("p", "LedgerMind là ứng dụng quản lý tài chính cá nhân nhóm đã xây dựng trước môn học: ứng dụng di động Flutter cho "
          "người dùng, trang web quản trị Thymeleaf cho quản trị viên và backend Spring Boot cung cấp REST API. Người dùng "
          "ghi thu chi, quét hóa đơn để mô hình AI DONUT đọc tên cửa hàng, tổng tiền, ngày, rồi xem thống kê; quản trị viên "
          "quản lý tài khoản, xem thống kê toàn hệ thống và sao lưu. Mọi dữ liệu nghiệp vụ nằm trong PostgreSQL."),
    ("p", "Nhóm chọn **hướng 1** của đề: mở rộng ứng dụng có sẵn dùng RDBMS, tích hợp các hệ NoSQL đã học và ít nhất một "
          "CSDL tự tìm hiểu. PostgreSQL vẫn là nguồn sự thật cho tiền, giao dịch, hóa đơn; NoSQL chỉ nhận các phần việc mà "
          "mô hình quan hệ làm kém. Rà lại ứng dụng, nhóm thấy bốn nhu cầu như vậy:"),
    ("b1", "**Dữ liệu bán cấu trúc của AI:** mỗi lần đọc hóa đơn, mô hình trả một khối JSON có cấu trúc đổi theo phiên bản; "
           "đội phát triển cần thống kê trường nào hay sai, mô hình nào sai nhiều – hợp với mô hình document."),
    ("b1", "**Thống kê đọc nhiều hơn ghi:** trang chủ và dashboard quản trị chạy câu SQL gộp ở mỗi lần mở dù số liệu chỉ đổi "
           "khi có giao dịch mới – hợp với bộ nhớ đệm key-value, cùng hệ đó lưu được OTP có hạn và bảng xếp hạng."),
    ("b1", "**Tìm kiếm tiếng Việt:** gõ \"pho\" muốn ra \"Phở\", gõ sai một chữ vẫn ra; câu LIKE của PostgreSQL không bỏ "
           "dấu, không chịu lỗi chính tả, không xếp theo độ liên quan."),
    ("b1", "**Thông báo tức thời** cho quản trị viên khi có hóa đơn chờ duyệt hoặc chỗ sửa OCR mới."),
    ("p", "Sadalage và Fowler cho rằng NoSQL không thay thế CSDL quan hệ mà mở ra việc dùng nhiều mô hình dữ liệu trong cùng "
          "một hệ thống, mỗi mô hình cho phần việc hợp với nó [1]; Fowler gọi cách làm này là polyglot persistence [2]. Đồ án "
          "áp dụng đúng tinh thần đó: MongoDB giữ bản sao phân tích các câu trả lời AI và phản hồi OCR (DONUT hiểu tài liệu "
          "không cần bước OCR riêng và trả kết quả dạng JSON có cấu trúc [3]); Redis làm cache thống kê, kho OTP, bảng xếp "
          "hạng và kênh sự kiện realtime; Elasticsearch – CSDL tự tìm hiểu – làm chỉ mục tìm kiếm giao dịch tiếng Việt. Tên "
          "đề tài đã đăng ký nêu MongoDB và Redis, hai hệ của môn học."),
]

C1_2 = [
    ("p", "Mục tiêu tổng quát: thêm các chức năng NoSQL vào LedgerMind mà không làm thay đổi tính đúng đắn của dữ liệu tiền "
          "trong PostgreSQL. Các con số dưới đây là **mục tiêu** chốt ngày 27/10/2026, trước mọi phép đo; chúng là các yêu "
          "cầu phi chức năng của mục 3.4 và được kiểm chứng ở Chương 7."),
    ("table", "Mục tiêu đo được của đề tài", 1, [1700, 5304, 1500],
     ["Nhóm", "Mục tiêu (tầng dữ liệu, 1 luồng, p95)", "Mã"],
     [
         ["Cache", "Đọc cache Redis < 5 ms; cache hit nhanh hơn miss ≥ 5 lần (p50)", "NFR-01, NFR-02"],
         ["Tìm kiếm", "Elasticsearch < 100 ms trên 100 000 giao dịch tổng hợp; \"pho\" ra \"Phở\", sai một ký tự vẫn ra; "
                      "không bao giờ trả giao dịch của người khác", "NFR-03, NFR-04, NFR-11"],
         ["MongoDB, xếp hạng", "Truy vấn có index dùng IXSCAN, < 20 ms; top 10 bảng xếp hạng < 5 ms", "NFR-05, NFR-06"],
         ["Sẵn sàng", "Redis, Elasticsearch hoặc MongoDB dừng thì ứng dụng vẫn trả lời", "NFR-07, NFR-08, NFR-09"],
         ["Nhất quán, bảo mật", "PostgreSQL nhất quán mạnh; NoSQL nhất quán cuối cùng sau commit; quản trị chỉ ROLE_ADMIN",
          "NFR-10, NFR-12"],
         ["Sao lưu, tài nguyên", "Khôi phục MongoDB khớp 100 %, < 5 phút (dữ liệu demo); chạy trong giới hạn bộ nhớ của "
                                 "docker-compose.yml", "NFR-13, NFR-14"],
         ["Realtime", "Sự kiện quản trị tới trình duyệt < 1 s sau PUBLISH", "NFR-15"],
     ], "Chi tiết và cách kiểm chứng: mục 3.4, Chương 7", "bang_muc_tieu"),
    ("p", "Đồ án cũng phải đạt yêu cầu tối thiểu của môn: MongoDB ≥ 2 collection, dữ liệu mẫu JSON, CRUD, lọc, sắp xếp, "
          "thống kê; Redis ≥ 2 nhóm key-value, có cache, bảng xếp hạng hoặc OTP, có thời gian hết hạn; ≥ 1 CSDL tự tìm hiểu; "
          "xử lý ≥ 4 loại dữ liệu khác nhau."),
]

C1_3 = [
    ("table", "Phạm vi của đề tài", 1, [4252, 4252],
     ["Trong phạm vi", "Ngoài phạm vi"],
     [
         ["PostgreSQL 15 làm nguồn sự thật; Redis: cache, OTP, bảng xếp hạng, Pub/Sub",
          "Thay PostgreSQL bằng NoSQL; phiên đăng nhập trong Redis (ứng dụng dùng JWT)"],
         ["MongoDB: ocr_logs, ocr_feedbacks, trang quản trị phản hồi OCR, sao lưu từ web", "Cassandra, Neo4j (mục 4.6)"],
         ["Elasticsearch: chỉ mục giao dịch, tìm kiếm tiếng Việt, dự phòng bằng PostgreSQL",
          "Cụm nhiều node, replica set, sharding (chỉ ở mức thiết kế)"],
         ["Ô tìm kiếm di động, trang quản trị NoSQL, script và dữ liệu mẫu từng CSDL; Kibana, Elasticvue (mục 2.5)",
          "Kafka, Outbox, Change Streams; push trên di động; triển khai lên server thật"],
     ], "", "bang_pham_vi"),
]

C1_4 = [
    ("b1", "**Khảo sát ứng dụng có sẵn:** đọc mã nguồn, ghi mọi sự kiện kỹ thuật kèm vị trí trong mã vào một tệp ghi chép dùng "
           "chung cho cả báo cáo."),
    ("b1", "**Mẫu truy cập trước, cấu trúc sau:** liệt kê mọi câu hỏi ứng dụng đặt cho CSDL (tần suất, độ trễ, mức nhất quán) "
           "rồi mới chọn loại CSDL, khóa, document, chỉ mục."),
    ("b1", "**Đồng bộ sau commit:** mọi ghi sang NoSQL chạy trên luồng nền sau khi PostgreSQL commit, nên lỗi NoSQL không "
           "làm hỏng nghiệp vụ chính."),
    ("b1", "**Kiểm chứng bằng số đo:** test với CSDL thật trong container dùng một lần, đo tầng dữ liệu trên 100 000 bản ghi "
           "tổng hợp, chụp minh chứng trên stack demo riêng."),
    ("p", "Mốc theo đề: **tuần 6** nộp SRS, **tuần 7** nộp mô hình CSDL, **tuần 11** nộp báo cáo, mã nguồn, script, slide, "
          "video."),
]

C1_5 = [
    ("table", "Công nghệ sử dụng", 1, [1700, 3700, 3104],
     ["Thành phần", "Công nghệ, phiên bản", "Vai trò"],
     [
         ["Backend", "Java 21, Spring Boot 3.2.5; Spring Data Redis 3.2.5, MongoDB 4.2.5, Elasticsearch 5.2.5",
          "REST API, web quản trị, SSE; truy cập NoSQL"],
         ["CSDL", "PostgreSQL 15, Redis 8.10, MongoDB 6.0, Elasticsearch 8.11.4 (image Docker)",
          "Nguồn sự thật; key-value; document; tìm kiếm"],
         ["Giao diện", "Flutter (Dart SDK ≥ 3.10.8); Thymeleaf, Bootstrap 5.3.0", "Ứng dụng di động; web quản trị"],
         ["AI, hạ tầng", "FastAPI + DONUT V5; Docker Compose, Caddy 2.8", "Đọc hóa đơn; chạy cả hệ thống trên một máy"],
     ], "Nguồn: core-backend/pom.xml; docker-compose.yml; mobile-app/pubspec.yaml; "
     "core-backend/src/main/resources/templates/admin/layout/_layout.html", "bang_cong_nghe"),
]

C1_6 = [
    ("p", "**a) Cơ cấu tổ chức và vai trò** (giảng viên hướng dẫn: ThS. Ngô Minh Anh Thư)"),
    ("table", "Cơ cấu tổ chức của nhóm 38", 1, [1800, 1550, 2702, 2452],
     ["Họ tên", "MSSV", "Vai trò", "Phụ trách CSDL"],
     [
         ["Phan Thanh Trí", "2001230977", "Nhóm trưởng; phân tích, kiến trúc, toàn bộ mã nguồn, dựng báo cáo",
          "PostgreSQL, Redis, MongoDB, Elasticsearch"],
         ["Phan Minh Tiến", "2001230806", "Thành viên; minh chứng trên GUI tool, tìm hiểu tool, kiểm tra, slide, video",
          "MongoDB (Compass); Elasticsearch (Kibana, Elasticvue)"],
     ], "", "bang_to_chuc"),
    ("p", "**b) Bảng phân công nhiệm vụ.** Bảng ghi đúng việc mỗi người thật sự làm. \"Kết thúc\" của việc đã xong là ngày "
          "commit trong kho mã; ô tô vàng là ngày chưa ghi nhận, nhóm điền khi chốt báo cáo. Ảnh chụp tự động bằng script "
          "không ghi công cho ai."),
    ("table", "Bảng phân công nhiệm vụ", 1, [650, 2100, 1000, 1000, 1500, 1200, 1054],
     ["Mã", "Công việc", "Người thực hiện", "Bắt đầu", "Kết thúc", "Sản phẩm bàn giao", "Trạng thái"],
     [
         ["T01", "Cache thống kê Redis, xóa cache sau commit", "Trí", CHUA, "30/09/2026", "Mã, test", "Hoàn thành"],
         ["T02", "OTP trên Redis; log OCR thô trên MongoDB", "Trí", CHUA, "21/10/2026", "Mã, test", "Hoàn thành"],
         ["T03", "Bảng xếp hạng Sorted Set; phân tích chỗ sửa OCR (MongoDB); script Q-01..Q-41", "Trí", CHUA,
          "27/10/2026", "Mã, test, script", "Hoàn thành"],
         ["T04", "Trang quản trị OCR, vận hành NoSQL, sao lưu MongoDB từ web, sự kiện realtime", "Trí", CHUA,
          "27/10/2026", "Mã, test", "Hoàn thành"],
         ["T05", "Tìm kiếm Elasticsearch có dự phòng PostgreSQL, ô tìm kiếm di động", "Trí", CHUA, "28/10/2026",
          "Mã, test", "Hoàn thành"],
         ["T06", "Bảng mẫu truy cập, sơ đồ, đo hiệu năng E1–E5", "Trí", CHUA, "28/10/2026", "Bảng yêu cầu, sơ đồ, số đo",
          "Hoàn thành"],
         ["T07", "Stack demo; dựng và viết báo cáo Word", "Trí", CHUA, CHUA, "Script, docx", "Đang thực hiện"],
         ["T08", "Đọc hiểu hệ thống; truy vấn MongoDB Q-01..Q-16 trên Compass", "Tiến", CHUA, CHUA, "Ghi chú, ảnh",
          "Đang thực hiện"],
         ["T09", "Tìm hiểu Kibana và Elasticvue (mục 2.5)", "Tiến", CHUA, CHUA, "Ghi chú so sánh", "Đang thực hiện"],
         ["T10", "Chạy lại sao lưu/khôi phục 3 CSDL, truy vấn Redis và Elasticsearch", "Tiến", CHUA, CHUA,
          "Số đếm, ảnh", "Đang thực hiện"],
         ["T11", "Chụp minh chứng phía người dùng (Compass, ứng dụng, trang quản trị, Postman)", "Tiến", CHUA, CHUA,
          "Ảnh S-xx", "Đang thực hiện"],
         ["T12", "Soát Chương 2, 5 và chính tả; slide; video demo; tập trả lời câu hỏi", "Tiến", CHUA, CHUA,
          "Ghi chú, pptx, video", "Đang thực hiện"],
     ], "Nguồn: lịch sử commit của kho mã; docs/nosql/HUONG_DAN_TIEN.md (việc T1–T10 của Tiến)", "bang_phan_cong"),
    ("p", "**c) Quy trình phát triển:** mô hình **lặp và tăng dần**. Ứng dụng đã chạy trước môn học, nên mỗi vòng chỉ thêm "
          "một phần NoSQL (cache, OTP, bảng xếp hạng, phân tích OCR, tìm kiếm, trang quản trị) cùng test của nó và chạy lại "
          "toàn bộ test trước khi sang phần sau. Cách này khớp ba mốc nộp của môn và giữ ứng dụng luôn chạy được; mô hình "
          "thác nước không hợp vì yêu cầu NoSQL được làm rõ dần qua từng mốc."),
    ("p", "**d) Lịch trình và các mốc**"),
    ("table", "Các giai đoạn và mốc của đồ án", 1, [1300, 3804, 2000, 1400],
     ["Giai đoạn", "Nội dung", "Sản phẩm", "Mốc"],
     [
         ["Giai đoạn 1", "Khảo sát, mô hình hóa nghiệp vụ và chức năng, bảng mẫu truy cập, thiết kế dữ liệu NoSQL",
          "SRS; mô hình CSDL", "Tuần 6, tuần 7"],
         ["Giai đoạn 2", "Cài đặt chức năng và kỹ thuật nâng cao, kiểm thử, đo hiệu năng, minh chứng, báo cáo, slide, video",
          "Sản phẩm, báo cáo cuối kỳ", "Tuần 11"],
     ], "", "bang_giai_doan"),
    ("p", "**e) Công cụ:** Git, GitHub; Docker Compose; MongoDB Compass; Redis Insight; Kibana, Elasticvue; Postman, Swagger UI; "
          "PlantUML; JUnit 5, Mockito, Testcontainers; Python (matplotlib, Playwright) cho biểu đồ và ảnh chụp tự động."),
    ("p", "**f) Kế hoạch kiểm thử:** kiểm thử đơn vị tầng service (JUnit 5, Mockito); kiểm thử tích hợp với Redis, MongoDB, "
          "Elasticsearch, PostgreSQL 15 thật bằng Testcontainers; chạy script Q-01..Q-41 và sao lưu/khôi phục trong container "
          "dùng một lần; đo hiệu năng tầng dữ liệu và thử dừng từng CSDL; JMeter mức ứng dụng là tùy chọn. Tiêu chí đạt là "
          "các NFR ở mục 3.4 ([[bang_muc_tieu]])."),
]

# --------------------------------------------------------------------------------------------------------------------
# CHƯƠNG 2
# --------------------------------------------------------------------------------------------------------------------

C2_0 = [
    ("p", "Chương này tóm tắt phần lý thuyết NoSQL đồ án thực sự dùng, ba hệ NoSQL của đề tài và phần tìm hiểu GUI tool "
          "Kibana, so sánh với Elasticvue."),
]

C2_1 = [
    ("p", "**Giới thiệu và lịch sử.** NoSQL là tên chung cho các CSDL không theo mô hình quan hệ: thường không ép lược đồ, lưu "
          "dữ liệu theo đơn vị gộp (aggregate) mà ứng dụng đọc ghi cùng nhau và được thiết kế để chạy trên cụm nhiều máy [1]. "
          "Khi các dịch vụ web cần phục vụ lượng dữ liệu rất lớn, mở rộng một máy chủ quan hệ trở nên khó và đắt; các bài "
          "báo về Bigtable của Google và Dynamo của Amazon mở ra hướng khác, và tên \"NoSQL\" phổ biến từ một buổi gặp năm "
          "2009 về CSDL phân tán mã nguồn mở [1]. Chữ \"No\" thường được hiểu là \"not only\"."),
    ("p", "**Thuật ngữ:** *aggregate* (đơn vị dữ liệu đọc ghi cùng nhau); *schemaless* (lược đồ do ứng dụng quyết định); "
          "*sharding* (chia dữ liệu ra nhiều node); *replication* (chép dữ liệu lên nhiều node); *nhất quán cuối cùng* (các "
          "bản sao sẽ giống nhau nếu không có ghi mới); *polyglot persistence* (nhiều loại CSDL trong một hệ thống [2])."),
    ("table", "So sánh NoSQL và RDBMS", 2, [1700, 3402, 3402],
     ["Tiêu chí", "RDBMS (PostgreSQL)", "NoSQL"],
     [
         ["Mô hình, lược đồ", "Bảng, khóa ngoại; lược đồ cố định", "Key-value, document, cột, đồ thị; lược đồ linh hoạt"],
         ["Truy vấn", "SQL chuẩn, JOIN tùy ý", "API riêng từng hệ; JOIN hạn chế"],
         ["Giao dịch, nhất quán", "ACID nhiều bảng; nhất quán mạnh", "Thường nguyên tử trên một khóa/document; thường "
                                                                     "nhất quán cuối cùng"],
         ["Mở rộng", "Chủ yếu theo chiều dọc", "Theo chiều ngang (thêm node)"],
     ], "Tổng hợp theo [1]", "bang_nosql_rdbms"),
    ("p", "**Ưu điểm** của NoSQL: mô hình khớp cách ứng dụng dùng dữ liệu, lược đồ dễ đổi, nhanh với mẫu truy cập biết trước, "
          "mở rộng ngang. **Nhược điểm:** truy vấn tùy ý kém SQL, giao dịch nhiều đối tượng hạn chế, nhất quán yếu hơn, mỗi hệ "
          "một ngôn ngữ và công cụ riêng [1]. Vì vậy đồ án giữ tiền và giao dịch trong PostgreSQL."),
    ("p", "**ACID và BASE.** Giao dịch ACID bảo đảm nguyên tử, nhất quán, cô lập, bền vững. Nhiều hệ NoSQL theo hướng BASE: "
          "luôn sẵn sàng về cơ bản (Basically Available), trạng thái mềm (Soft state), nhất quán cuối cùng (Eventual "
          "consistency) [1]. Trong LedgerMind, ghi giao dịch, khóa ví, chống trùng theo clientId chạy trong giao dịch ACID của "
          "PostgreSQL; ba hệ NoSQL nhận thay đổi sau commit nên mang tính BASE: có thể chậm hơn một khoảng ngắn nhưng không "
          "làm sai số tiền."),
    ("p", "**CAP và PACELC.** Brewer phát biểu rằng hệ phân tán không thể cùng lúc bảo đảm nhất quán (C), sẵn sàng (A) và chịu "
          "phân vùng mạng (P) [4]; Gilbert và Lynch chứng minh hình thức điều này [5]. Vì phân vùng là không tránh được, lựa "
          "chọn thực tế là khi mạng bị chia cắt thì ưu tiên C hay A. Abadi bổ sung: ngay cả khi mạng bình thường, hệ có sao "
          "chép vẫn phải đánh đổi độ trễ (L) và nhất quán (C) – PACELC: có P thì chọn A hay C, ngược lại (E) chọn L hay C [6]. "
          "Mục 4.8 dùng khung này cho từng CSDL."),
]

C2_2 = [
    ("b1", "**Sharding:** chia dữ liệu theo khoảng giá trị khóa (giữ thứ tự, quét khoảng được) hoặc theo giá trị băm (rải đều "
           "tải, mất thứ tự); khóa chọn sai sẽ dồn tải vào một node [7]."),
    ("b1", "**Replication:** một leader nhận ghi và follower chép lại, nhiều leader, hoặc không leader; sao chép đồng bộ an "
           "toàn nhưng chậm, bất đồng bộ nhanh nhưng có thể mất ghi mới nhất khi leader hỏng [7]."),
    ("b1", "**Mức nhất quán:** *mạnh* (đọc luôn thấy ghi đã xác nhận gần nhất); *cuối cùng* (bản sao hội tụ dần, có thể đọc dữ "
           "liệu cũ); *điều chỉnh được* (chọn số bản sao xác nhận ghi W và đọc R; với N bản sao, W + R > N thì lần đọc chạm ít "
           "nhất một bản sao mới nhất) [7]."),
    ("p", "Đồ án chạy mỗi CSDL một node; cụm chỉ ở mức thiết kế (Chương 4)."),
]

C2_3 = [
    ("table", "Bốn họ NoSQL: mô hình, ưu nhược điểm và vị trí trong đồ án", 2, [1250, 1900, 2200, 1800, 1354],
     ["Họ", "Mô hình dữ liệu", "Ưu điểm / nhược điểm", "Hệ tiêu biểu, dùng khi", "Trong đồ án"],
     [
         ["Key-Value", "key → value (string, hash, list, set, sorted set)",
          "Đọc ghi theo khóa rất nhanh, đơn giản / không truy vấn theo nội dung value",
          "Redis, DynamoDB; cache, session, xếp hạng", "Redis"],
         ["Document", "collection → document JSON/BSON lồng nhau",
          "Lược đồ linh hoạt, đọc cả aggregate một lần / JOIN và giao dịch nhiều document hạn chế",
          "MongoDB, CouchDB; dữ liệu bán cấu trúc", "MongoDB"],
         ["Column-family", "keyspace → table → partition + clustering key",
          "Ghi lớn, mở rộng ngang tốt / truy vấn phải theo khóa phân vùng đã thiết kế",
          "Cassandra, HBase; log, dữ liệu theo thời gian", "Không dùng"],
         ["Graph", "node, relationship, property",
          "Duyệt quan hệ nhiều tầng nhanh / khó phân mảnh, kém cho tổng hợp số lớn",
          "Neo4j, ArangoDB; gợi ý, mạng quan hệ", "Không dùng"],
     ], "Theo yêu cầu môn học và [1]", "bang_bon_ho"),
    ("p", "**Vị trí của Elasticsearch.** Elastic mô tả Elasticsearch là kho document phân tán: mỗi document là một đối tượng "
          "JSON, các trường được đưa vào chỉ mục ngược (inverted index) để tìm kiếm toàn văn rất nhanh [8]; lớp lưu trữ bên "
          "dưới là thư viện máy tìm kiếm Apache Lucene viết bằng Java [9]. Như vậy Elasticsearch là máy tìm kiếm có kho "
          "document: gần họ Document về mô hình dữ liệu nhưng tối ưu cho tìm văn bản, chấm điểm độ liên quan và tổng hợp. Nó "
          "nằm ngoài bốn họ của môn học, nên nhóm chọn làm **CSDL tự tìm hiểu**."),
]

C2_4 = [
    ("p", "PostgreSQL giữ vai trò nguồn sự thật: số tiền, giao dịch, hóa đơn và cả câu trả lời thô của AI (gắn với vòng đời "
          "hóa đơn) đều ghi ở đây trước. Ba hệ NoSQL dưới đây nhận bản sao hoặc dữ liệu tạm theo vai trò đã nêu ở Chương 1."),
]

MONGO_CODE = """d.ocr_feedbacks.find({ isResolved: false }, { _id: 0, receiptId: 1, fieldError: 1, reportedAt: 1 })
  .sort({ reportedAt: -1 }).limit(5).forEach(printjson);
const target = d.ocr_feedbacks.findOne({ isResolved: false }, { receiptId: 1, fieldError: 1 });
const resolved = d.ocr_feedbacks.updateOne({ _id: target._id }, { $set: { isResolved: true } });
d.ocr_feedbacks.aggregate([
  { $match: { reportedAt: { $gte: ISODate("2026-08-01T00:00:00Z"), $lt: ISODate("2026-11-01T00:00:00Z") } } },
  { $group: { _id: "$fieldError", count: { $sum: 1 } } },
  { $sort: { count: -1, _id: 1 } }
]).forEach(printjson);"""

C2_4_1 = [
    ("p", "**Đặc điểm.** MongoDB lưu document BSON (JSON nhị phân có thêm kiểu ngày, số 64 bit), document cùng collection không "
          "bắt buộc cùng cấu trúc, có index trên mọi trường kể cả trường lồng, có aggregation pipeline để lọc, nhóm, nối "
          "collection và hỗ trợ replica set, sharding [10] – hợp với câu trả lời AI có cấu trúc thay đổi."),
    ("p", "**Cài đặt và cấu hình.** Image mongo:6.0 trong Docker Compose, giới hạn 512 MB, cache WiredTiger 0,25 GB, cổng chỉ "
          "trên 127.0.0.1, có tài khoản root. Script scripts/nosql/mongodb_init.js gắn vào thư mục khởi tạo của image tạo hai "
          "collection, bộ kiểm tra $jsonSchema và mọi index (Spring không tự tạo index)."),
    ("table", "Khái niệm cấu trúc của MongoDB trong LedgerMind", 2, [1500, 7004],
     ["Khái niệm", "Trong LedgerMind"],
     [
         ["Database", "finance_nosql (ứng dụng), finance_nosql_demo (dữ liệu demo)"],
         ["Collection", "ocr_logs (câu trả lời thô của AI), ocr_feedbacks (chỗ người dùng sửa)"],
         ["Document", "một lần đọc AI của một giao dịch; một chỗ sửa của một cặp (hóa đơn, trường)"],
         ["Field", "transactionId, modelVersion, rawJsonData, aiReading (document lồng), fieldError, isResolved, reportedAt"],
     ], "Nguồn: scripts/nosql/mongodb_init.js; core-backend/src/main/java/vn/edu/huit/finance/core/Document", "bang_mongo_khai_niem"),
    ("p", "**Embedded và References** [10]. *Nhúng* đặt dữ liệu con trong document cha, đọc một lần là đủ; *tham chiếu* lưu "
          "khóa của document khác và nối bằng $lookup khi cần. Đồ án dùng cả hai: ocr_logs nhúng aiReading (tên cửa hàng, tổng "
          "tiền, ngày AI đọc được) cùng JSON thô rawJsonData; ocr_feedbacks chỉ tham chiếu transactionId, receiptId, userId "
          "vì các thực thể đó sống ở PostgreSQL, và thống kê tỉ lệ lần đọc bị sửa nối hai collection bằng $lookup."),
    ("p", "**Tree Structures.** Tài liệu MongoDB nêu các mẫu cho dữ liệu cây: tham chiếu cha, tham chiếu con, mảng tổ tiên, "
          "đường dẫn vật hóa, nested sets [10]. Dữ liệu NoSQL của đồ án không có cấu trúc cây (danh mục nằm ở PostgreSQL) nên "
          "không dùng các mẫu này."),
    ("p", "**Atomic Operations.** Mọi thao tác ghi trên một document là nguyên tử; giao dịch nhiều document cần replica set "
          "[10]. Đồ án không cần giao dịch nhiều document: chỗ sửa OCR ghi bằng hai lệnh nguyên tử (updateOne có điều kiện, "
          "rồi upsert chỉ với $setOnInsert), unique index receipt_field_uq trên (receiptId, fieldError) chặn bản trùng khi "
          "hai luồng ghi cùng lúc."),
    ("p", "**Cú pháp chính:** Q-03 (lọc, chiếu, sắp xếp; index status_date_idx), Q-07 (ghi nguyên tử trên một document) và "
          "Q-10 (aggregation), trích nguyên văn scripts/nosql/mongodb_demo.js dòng 126–127, 161–162, 206–210 (chạy bằng "
          "mongosh; d là database demo):"),
    ("code", MONGO_CODE),
    ("p", "GUI tool chính thức là MongoDB Compass, dùng để truy vấn, chạy aggregation và phân tích dữ liệu trực quan [11]; "
          "Chương 5 dùng Compass cho Q-01..Q-16."),
]

REDIS_CODE = """HSET "ledgermind:password-reset-otp:sv01@huit.edu.vn" code 482931 expiresAt 4102444800000
PEXPIRE "ledgermind:password-reset-otp:sv01@huit.edu.vn" 300000
SET "ledgermind:default:v1:user-dashboard:1" '{"totalBalance":12500000,"monthlyExpense":3150000,"monthlyIncome":15000000}' EX 285
ZADD "ledgermind:leaderboard:spend:2026-10" 4200000 1 6850000 2 1250000 3 9100000 4 3300000 5 780000 6
EXPIRE "ledgermind:leaderboard:spend:2026-10" 5356800
ZREVRANGE "ledgermind:leaderboard:spend:2026-10" 0 2 WITHSCORES"""

C2_4_2 = [
    ("p", "**Đặc điểm.** Redis là kho key-value trong bộ nhớ. Mỗi lệnh chạy trọn trước lệnh kế tiếp nên nguyên tử; nhiều lệnh "
          "gộp được bằng MULTI/EXEC hoặc script Lua chạy nguyên tử phía server; key có thời gian sống (TTL) để Redis tự xóa; "
          "kênh Pub/Sub đẩy tin tới client đang đăng ký và không lưu lại; lưu đĩa (RDB, AOF) là tùy chọn [12]."),
    ("p", "**Cài đặt và cấu hình.** Image redis:8.10-alpine, có mật khẩu, maxmemory 128mb với allkeys-lru, tắt lưu đĩa (mọi "
          "dữ liệu dựng lại được từ PostgreSQL), đổi tên KEYS, FLUSHALL, FLUSHDB thành rỗng, không mở cổng ra máy chủ; ứng "
          "dụng nối qua Lettuce với thời gian chờ kết nối 1 s, lệnh 500 ms."),
    ("table", "Các kiểu dữ liệu Redis và cách đồ án dùng", 2, [1300, 2700, 4504],
     ["Kiểu", "Lệnh chính", "Trong LedgerMind"],
     [
         ["String", "SET … EX, GET, DEL, TTL", "Cache thống kê: JSON dưới <prefix>:v1:<cache>:<key>, TTL 45–60 s có jitter"],
         ["Hash", "HSET, HGET, HINCRBY", "OTP ledgermind:password-reset-otp:<email> (code, expiresAt, failedAttempts), "
                                         "hạn 5 phút"],
         ["List, Set", "LPUSH, LRANGE; SADD, SISMEMBER", "Không dùng"],
         ["Sorted Set", "ZADD, ZREVRANGE, ZREM", "Bảng xếp hạng ledgermind:leaderboard:spend:<yyyy-MM>, member = userId, "
                                                 "score = tổng chi tháng, TTL 62 ngày"],
         ["Kênh Pub/Sub", "PUBLISH, SUBSCRIBE", "Sự kiện quản trị trên kênh ledgermind:admin-events"],
     ], "Nguồn: [12]; core-backend/src/main/resources/redis-cache.properties; mục 4.3", "bang_redis_kieu"),
    ("p", "**Cú pháp chính** (trích nguyên văn scripts/nosql/redis_demo.txt dòng 21–22, 40, 67–68, 75). Giá trị cache và "
          "TTL 285 s ở dòng SET là ví dụ minh họa của script; ứng dụng ghi JSON đầy đủ với TTL 45 s cho user-dashboard, trừ "
          "ngẫu nhiên tới 10 % (core-backend/src/main/resources/redis-cache.properties dòng 18, 22):"),
    ("code", REDIS_CODE),
    ("p", "Bảng xếp hạng ghi **tổng tuyệt đối** đọc lại từ PostgreSQL bằng ZADD (ZREM khi tổng về 0) trong một script Lua, "
          "không cộng dồn bằng ZINCRBY, nên sự kiện lặp hay mất không làm sai điểm lâu dài. GUI tool Redis Insight có trình "
          "duyệt key, CLI, Workbench, Profiler [13]; Chương 5 dùng nó cho Q-17..Q-29 và Q-41."),
]

ES_CODE = """GET transactions/_search
{
  "size": 5,
  "query": { "bool": {
    "filter": [ { "term": { "userId": 2 } } ],
    "must": [ { "match": { "categoryName": "ca phe" } } ]
  } },
  "_source": [ "categoryName", "vendorName", "amount" ]
}"""

C2_4_3 = [
    ("p", "**Đặc điểm.** Elasticsearch lưu document JSON trong index, chia index thành shard (mỗi shard là một chỉ mục Lucene) "
          "có thể có replica; mọi thao tác qua REST API JSON; dữ liệu vừa ghi tìm được sau một lần làm mới ngắn (gần thời gian "
          "thực); truy vấn viết bằng Query DSL [14]. Khi index một trường văn bản, analyzer tách và chuẩn hóa nó thành các "
          "token; chỉ mục ngược lưu, cho mỗi token, danh sách các document chứa token đó (posting list) [8], [9]."),
    ("p", "**Cài đặt và cấu hình.** Elasticsearch 8.11.4 chỉ chạy với profile search của Docker Compose; ứng dụng chỉ dùng khi "
          "SEARCH_ENGINE=elasticsearch (mặc định postgres). Một node, bảo mật bật (user elastic), tắt TLS vì chỉ mạng nội bộ "
          "và 127.0.0.1 tới được, heap 512 MB trong giới hạn 1 GB, path.repo cho snapshot, action.auto_create_index=false để "
          "không index nào được tạo ngầm."),
    ("p", "**Cấu trúc dữ liệu.** Index transactions (1 shard, 0 replica) giữ mỗi giao dịch là một document kèm vendorName "
          "của hóa đơn. Mapping khai báo note, vendorName là text có trường con .autocomplete, categoryName là text có .keyword, "
          "amount là scaled_float, transactionDate là date, userId là long. Analyzer vi_folded = standard + lowercase + "
          "asciifolding biến \"Phở\" thành \"pho\"; vi_autocomplete thêm edge_ngram 2–15 cho tìm theo tiền tố."),
    ("p", "**Cú pháp chính** (Q-33, trích nguyên văn scripts/nosql/elasticsearch/kibana-devtools.txt dòng 45–53: gõ không "
          "dấu \"ca phe\" vẫn khớp danh mục \"Cà phê\" nhờ vi_folded):"),
    ("code", ES_CODE),
]

C2_5 = [
    ("p", "Elasticsearch là CSDL tự tìm hiểu nên nhóm tìm hiểu GUI tool của nó theo tiêu chí 1–4 của đề cương môn học: **Kibana** là "
          "công cụ chính, **Elasticvue** dùng để so sánh. Mọi ảnh được chụp trên stack demo riêng (scripts/nosql/demo-stack.sh) "
          "với 47 giao dịch demo; số đo lấy từ kho mã nguồn (docs/nosql/bench_results.md)."),
]

KIBANA_INSTALL = """#   docker compose --profile search up -d
#   docker compose --profile search exec elasticsearch bin/elasticsearch-reset-password -u kibana_system -i
# nhập cùng giá trị với KIBANA_PASSWORD, rồi: docker compose --profile search --profile tools up -d"""

KIBANA_COMPOSE = """  kibana:
    image: kibana:8.11.4
    container_name: finance-kibana
    profiles: ["tools"]
    ports:
      - "127.0.0.1:5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      # Not ":?": an empty value must not stop the default stack; Kibana then only fails to log in.
      - ELASTICSEARCH_PASSWORD=${KIBANA_PASSWORD:-}"""

ELASTICVUE_INSTALL = """      - http.cors.enabled=true
      - http.cors.allow-origin=/https?:\\/\\/(localhost|127\\.0\\.0\\.1)(:[0-9]+)?/
      - http.cors.allow-headers=Authorization,Content-Type

  elasticvue:
    image: cars10/elasticvue:latest
    container_name: nosql-demo-elasticvue
    ports:
      - "127.0.0.1:8081:8080\""""

C2_5_1 = [
    ("p", "**Giới thiệu và kiến trúc.** Theo Elastic, Kibana là công cụ giúp làm việc với dữ liệu và điều khiển Elastic Stack, "
          "từ tìm kiếm, phân tích đến quản trị [15]. Kibana không giữ dữ liệu nghiệp vụ: trình duyệt chạy giao diện (Discover, "
          "Dashboards, Dev Tools, Stack Management); server Kibana (trên stack demo là tiến trình Node.js trong image 1,67 GB) "
          "xác thực người dùng bằng tài khoản Elasticsearch và chuyển yêu cầu tới REST API; cấu hình của Kibana (data view, "
          "dashboard, báo cáo) được lưu trong các index hệ thống ngay trong Elasticsearch [15]. Server Kibana kết nối Elasticsearch "
          "bằng user kibana_system; người dùng đăng nhập bằng tài khoản riêng và chỉ thấy những gì role cho phép. Phiên bản "
          "Kibana phải khớp Elasticsearch (đồ án dùng 8.11.4). Với bản 8.11.4, bản phân phối mặc định theo Elastic License 2.0 "
          "(ELv2); mã nguồn phát hành theo SSPL 1.0 hoặc ELv2 [16]."),
    ("p", "**Các bước cài đặt** theo cấu hình đề tài: (1) bật Elasticsearch với profile search; (2) đặt mật khẩu cho "
          "kibana_system một lần, cùng giá trị KIBANA_PASSWORD; (3) bật Kibana với profile tools, mở http://127.0.0.1:5601 "
          "và đăng nhập bằng elastic. Các lệnh trích nguyên văn hướng dẫn trong .env.example (dòng 31, 38–39):"),
    ("code", KIBANA_INSTALL),
    ("p", "Dịch vụ kibana trong docker-compose.yml (dòng 190–200, nguyên văn) chỉ cần địa chỉ Elasticsearch và tài khoản "
          "kibana_system:"),
    ("code", KIBANA_COMPOSE),
    ("p", "Trên stack demo, mật khẩu kibana_system được đặt bằng API bảo mật thay cho elasticsearch-reset-password, vì công cụ "
          "này khởi động thêm một JVM và làm container Elasticsearch vượt giới hạn bộ nhớ. [[hinh_s01]]: Elasticsearch "
          "healthy, yêu cầu không đăng nhập bị từ chối (401), mật khẩu được đặt, Kibana báo available; [[hinh_s02]]: trang chủ "
          "Kibana sau khi đăng nhập."),
    ("sid", "S-01", "Elasticsearch healthy và đặt mật khẩu kibana_system trên stack demo", 2, 13, "hinh_s01"),
    ("sid", "S-02", "Trang chủ Kibana 8.11.4 sau khi đăng nhập", 2, 8, "hinh_s02"),
    ("p", "**Lưu ý về bộ nhớ (đã đo).** Giữ đúng giới hạn 1 GB của docker-compose.yml, Elasticsearch đã dùng 997 MiB trước "
          "khi Kibana chạy; 22 giây sau khi bật Kibana (Kibana kết nối và tạo các index hệ thống của nó), kernel giết tiến "
          "trình Java của Elasticsearch vì hết bộ nhớ và container phải khởi động lại (kho mã nguồn, docs/nosql/bench_results.md mục NFR-14; ảnh S-89 "
          "ở mục 7.2). Với 1,5 GB, Elasticsearch dùng 1,15 GiB và không khởi động lại lần nào. Vì vậy muốn chạy Kibana cùng "
          "Elasticsearch thì Elasticsearch cần khoảng 1,5 GB trở lên, hoặc chỉ bật Kibana khi cần quản trị."),
    ("p", "**Cài đặt Elasticvue.** Elasticvue là GUI cho Elasticsearch, phát hành dạng ứng dụng desktop, tiện ích trình duyệt, "
          "image Docker hoặc tự host [17]. Nó chạy trong trình duyệt và gọi thẳng REST API của Elasticsearch, nên "
          "Elasticsearch phải bật CORS cho địa chỉ của nó. Trên stack demo cluster được khai báo sẵn với Basic auth của user "
          "elastic ([[hinh_s10]]); cấu hình trích từ scripts/nosql/demo-stack.compose.yml: dòng 88–90 (CORS của "
          "Elasticsearch) nguyên văn, dòng 128–132 (dịch vụ elasticvue) rút gọn ở chỗ cổng máy chủ ghi giá trị mặc định "
          "8081 thay cho biến môi trường:"),
    ("code", ELASTICVUE_INSTALL),
    ("sid", "S-10", "Elasticvue 1.16.0 kết nối cluster Elasticsearch của stack demo", 2, 8, "hinh_s10"),
]

C2_5_2 = [
    ("p", "Đề cương môn học yêu cầu sáu nhóm chức năng; với Elasticsearch, \"database\" là index. Tất cả chạy trên bản miễn phí (Basic) "
          "của Kibana 8.11.4."),
    ("b1", "**Quản lý index** (Stack Management → Index Management): danh sách, settings, mapping, đóng/mở/xóa index. "
           "[[hinh_s03]]: mapping của transactions với analyzer vi_folded và trường con .autocomplete."),
    ("sid", "S-03", "Kibana Index Management: mapping của index transactions", 2, 8, "hinh_s03"),
    ("b1", "**Soạn và chạy truy vấn** (Dev Tools → Console): gõ yêu cầu REST với Query DSL, xem JSON kết quả bên cạnh; Q-30..Q-40 "
           "của Chương 5 chạy ở đây. [[hinh_s04]]: \"pho\" trên vendorName của người dùng 1 trả về 4 giao dịch \"Phở …\"."),
    ("sid", "S-04", "Kibana Dev Tools: truy vấn \"pho\" trả về các giao dịch \"Phở\"", 2, 8, "hinh_s04"),
    ("b1", "**Import** (Upload file): tải CSV, Kibana đoán kiểu cột, tạo index và nạp dữ liệu ([[hinh_s05]]: 47 giao dịch demo). "
           "**Export** (Discover → Share → CSV Reports): bản Basic có chức năng này ([[hinh_s06]]: báo cáo CSV 47 dòng hoàn tất)."),
    ("sid", "S-05", "Kibana Upload file: nhập 47 giao dịch demo từ CSV", 2, 8, "hinh_s05"),
    ("sid", "S-06", "Kibana xuất CSV từ Discover (trên) và trang Reporting báo hoàn tất (dưới)", 2, 6.5, "hinh_s06"),
    ("b1", "**Backup/restore** (Snapshot and Restore): repository, snapshot, khôi phục ([[hinh_s07]]: snapshot của transactions, "
           "0 shard lỗi). **Phân quyền** (Security → Users, Roles): role theo index và quyền ([[hinh_s08]]: role chỉ đọc "
           "index transactions)."),
    ("sid", "S-07", "Kibana Snapshot and Restore: repository và snapshot", 2, 8, "hinh_s07"),
    ("sid", "S-08", "Kibana Roles: role chỉ đọc index transactions", 2, 8, "hinh_s08"),
    ("b1", "**Giám sát:** ứng dụng Stack Monitoring của Kibana dựa vào một thành phần thu thập số liệu cài thêm (Metricbeat "
           "hoặc Elastic Agent) [15]; đồ án **không cài thành phần này** để tiết kiệm bộ nhớ, nên giám sát qua tab Statistics của Index Management ([[hinh_s09]]) và các API _cat, "
           "_cluster/health trong Dev Tools."),
    ("sid", "S-09", "Kibana Index Management: thống kê của index transactions", 2, 8, "hinh_s09"),
]

C2_5_3 = [
    ("p", "Elasticvue được chọn vì cũng là GUI tổng quát cho Elasticsearch nhưng theo hướng ngược lại: nhẹ, chạy trong trình "
          "duyệt. Chức năng được thử trên cùng stack demo ([[hinh_s11]] đến [[hinh_s13]]); hiệu năng đo bằng docker stats và "
          "thời gian tải trang đầu ([[hinh_s14]])."),
    ("sid", "S-11", "Elasticvue: danh sách index (trên) và tìm \"phở\" (dưới)", 2, 7, "hinh_s11"),
    ("sid", "S-12", "Elasticvue REST: truy vấn tổng hợp theo categoryName.keyword", 2, 8, "hinh_s12"),
    ("sid", "S-13", "Elasticvue: repository (trên) và snapshot (dưới)", 2, 7.5, "hinh_s13"),
    ("sid", "S-14", "RAM, CPU, kích thước image, thời gian tải trang đầu của Kibana và Elasticvue (đo)", 2, 14, "hinh_s14"),
    ("table", "So sánh Kibana 8.11.4 và Elasticvue 1.16.0", 2, [1400, 3552, 3552],
     ["Tiêu chí", "Kibana", "Elasticvue"],
     [
         ["Chức năng", "Đủ sáu nhóm (index, Dev Tools, import/export CSV, snapshot, user/role, thống kê index); thêm "
                       "Discover, Dashboards [15]",
          "Cluster, node, shard, index, tìm kiếm, REST, snapshot, user; menu không có dashboard hay nhập file"],
         ["Giao diện", "Nhiều ứng dụng trong một menu lớn, nhiều bước cho việc nhỏ", "Một thanh menu tám mục, xem nhanh "
                                                                                     "tình trạng cluster"],
         ["Hỗ trợ truy vấn", "Console Query DSL nhiều yêu cầu; KQL trong Discover [15]", "Tab REST gửi yêu cầu bất kỳ; tab "
                                                                                       "Search theo từ khóa"],
         ["Hiệu năng (đo)", "RAM 631 MiB; image 1,67 GB; trang đăng nhập 1,38 s, tới Home 1,74 s; làm Elasticsearch 1 GB "
                            "bị OOM-kill", "RAM 10,5 MiB; image 105 MB; trang đầu 0,25 s (trang tĩnh do nginx phục vụ)"],
         ["Giấy phép", "ELv2 (bản phân phối mặc định); mã nguồn: SSPL 1.0 hoặc ELv2 [16]", "MIT [17]"],
         ["Nền tảng", "Server (Docker hoặc gói cài) + trình duyệt [15]", "Desktop, tiện ích trình duyệt, Docker [17]; "
                                                                         "cần bật CORS"],
         ["Cộng đồng", "Elastic phát triển và hỗ trợ, tài liệu theo từng phiên bản [15]",
          "Dự án GitHub của một nhà phát triển (cars10), khoảng 2,8 nghìn sao ngày 27/10/2026 [17]"],
     ], "Số đo: kho mã nguồn (docs/nosql/bench_results.md, mục Kibana và Elasticvue, NFR-14), ngày 28/10/2026, trung vị 5 lần, cache trống",
     "bang_so_sanh_tool"),
    ("p", "**Nhận xét.** Kibana đầy đủ hơn hẳn: chỉ Kibana có đủ sáu nhóm chức năng của tiêu chí 2, có trực quan hóa và quản lý "
          "role trên giao diện. Elasticvue rẻ hơn hẳn: ít hơn khoảng 60 lần RAM, trang đầu tải nhanh hơn khoảng 5,5 lần (trang đăng nhập Kibana 1,38 s so với "
          "trang Home Elasticvue 0,25 s), không cần tài "
          "khoản hệ thống. Trên máy chủ nhỏ của đồ án, Elasticvue hợp để xem nhanh index và gửi vài yêu cầu REST; các việc "
          "quản trị có tổ chức (snapshot, phân quyền, xuất dữ liệu, minh chứng truy vấn) nên làm trên Kibana, bật khi cần."),
]

C2_5_4 = [
    ("p", "**Loại ứng dụng phù hợp.** Kibana mạnh nhất khi Elasticsearch là kho dữ liệu chính để phân tích: log và số liệu vận "
          "hành theo thời gian, giám sát và cảnh báo, phân tích bảo mật, ứng dụng tìm kiếm cần người vận hành xem trực tiếp dữ "
          "liệu đã index [15]. Lý do: Kibana nằm sẵn trong Elastic Stack, Discover và Dashboards đọc thẳng index theo trường "
          "thời gian, Dev Tools gỡ lỗi truy vấn và analyzer, Security và Snapshot and Restore gom việc vận hành vào một giao "
          "diện. Ví dụ thực tế quen thuộc là bộ Elasticsearch – Kibana tập trung log của nhiều dịch vụ: người vận hành tìm lỗi "
          "trong Discover và theo dõi số lỗi theo giờ trên dashboard [15]."),
    ("p", "**Gắn với đề tài.** Trong LedgerMind, Elasticsearch chỉ giữ bản sao tìm kiếm của bảng giao dịch, nên Kibana là công "
          "cụ quản trị chứ không phải công cụ báo cáo cho người dùng cuối: kiểm tra mapping và analyzer tiếng Việt (_analyze), "
          "chạy và chụp minh chứng Q-30..Q-40, xem một giao dịch vừa tạo đã vào index sau commit chưa, tạo snapshot trước khi "
          "dựng lại index, cấp role chỉ đọc cho thành viên. Vì Kibana tốn bộ nhớ ([[bang_so_sanh_tool]]), cấu hình đồ án chỉ "
          "bật nó với profile tools, cổng chỉ trên 127.0.0.1; khi chỉ cần xem nhanh thì dùng Elasticvue. Nếu sau này cần thống "
          "kê chi tiêu theo danh mục, theo tháng trên giao diện (hiện chỉ có trong script Q-39, Q-40), Dashboards của Kibana là "
          "hướng mở rộng tự nhiên."),
]

HEADING_PLACEHOLDERS = {
    "TỔNG QUAN ĐỀ TÀI": C1_0,
    "BỐI CẢNH VÀ LÝ DO CHỌN ĐỀ TÀI": C1_1,
    "MỤC TIÊU ĐỀ TÀI": C1_2,
    "PHẠM VI ĐỀ TÀI": C1_3,
    "PHƯƠNG PHÁP THỰC HIỆN": C1_4,
    "CÔNG NGHỆ SỬ DỤNG": C1_5,
    "KẾ HOẠCH DỰ ÁN": C1_6,
    "TỔNG QUAN NOSQL VÀ TÌM HIỂU TOOL": C2_0,
    "TỔNG QUAN VỀ NOSQL": C2_1,
    "PHÂN TÁN DỮ LIỆU": C2_2,
    "PHÂN LOẠI NOSQL": C2_3,
    "CÁC HỆ QUẢN TRỊ ĐỀ TÀI SỬ DỤNG": C2_4,
    "Hệ quản trị MongoDB": C2_4_1,
    "Hệ quản trị Redis": C2_4_2,
    "Hệ quản trị Elasticsearch": C2_4_3,
    "TÌM HIỂU GUI TOOL KIBANA, SO SÁNH VỚI ELASTICVUE": C2_5,
    "Lý thuyết và cài đặt Kibana": C2_5_1,
    "Các chức năng của Kibana": C2_5_2,
    "So sánh Kibana với Elasticvue": C2_5_3,
    "Kibana phù hợp với loại ứng dụng nào": C2_5_4,
}

# Bìa (chép từ bìa SRS): học vị viết đúng "ThS.".
TEXT_REPLACE = [("GVHD: Ths. ", "GVHD: ThS. ", 1)]
