"""Nội dung Chương 3 (Đặc tả yêu cầu phần mềm – SRS) – báo cáo NoSQL nhóm 38.

Dựng v2 từ v1: python3 builder_nosql.py <thư mục giải nén v1> content_c3.py
Nguồn sự thật: docs/nosql/facts.md (CODE_SHA 1cae4de; FR/AP/NFR/TC/S đóng băng ngày 27/10/2026), bench_results.md
(E1–E6, NFR-13, NFR-14), screenshots.md (S-xx của 3.7), docs/nosql/diagrams/*.png (sơ đồ Task 2), references.md
([18], [19] trích lần đầu ở chương này). Mọi số đếm dữ liệu ghi rõ nguồn: "dữ liệu demo" (scripts/nosql) hoặc "dữ liệu
tổng hợp 100k (sinh bằng gen_data.py)". Độ trễ mức ứng dụng không có số đo (JMeter chưa chạy) nên giữ là "mục tiêu".
Sơ đồ cao (uc_nguoi_dung, uc_quan_tri, seq_bang_xep_hang, bpmn_quet_hoa_don) được đặt cỡ theo chiều cao để nằm gọn một trang.
"""
import struct
from pathlib import Path

SESSION_TAG = None
SECTIONS = {}
RENUMBER = True

DIAGRAMS = Path(__file__).resolve().parents[1] / "diagrams"
TEXT_WIDTH_CM = 15.0  # vùng chữ: 8504 dxa


def _size(png):
    with open(png, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def fig(name, caption, key, width_cm=TEXT_WIDTH_CM, max_h_cm=None):
    """Hình từ docs/nosql/diagrams; max_h_cm: thu chiều rộng sao cho chiều cao không vượt max_h_cm."""
    png = DIAGRAMS / f"{name}.png"
    w, h = _size(png)
    width = min(width_cm, TEXT_WIDTH_CM)
    if max_h_cm is not None:
        width = min(width, max_h_cm * w / h)
    return ("fig", caption, 3, str(png), round(width, 2), None, None, key)


# --------------------------------------------------------------------------------------------------------------------
# 3.0 Mở chương
# --------------------------------------------------------------------------------------------------------------------

C3_0 = [
    ("p", "Chương này đặc tả yêu cầu của phần mở rộng NoSQL cho LedgerMind theo khung của IEEE 830 [18] và ISO/IEC/IEEE "
          "29148 [19]: giới thiệu, mô tả tổng quan, yêu cầu chức năng, yêu cầu phi chức năng, cộng hai mục riêng cho đồ án "
          "NoSQL là yêu cầu dữ liệu (3.5) và mẫu truy cập dữ liệu (3.6). Mọi mã yêu cầu (FR, NFR, AP) và mã ca kiểm thử (TC) "
          "được chốt ngày 27/10/2026, trước mọi phép đo; Chương 4 ánh xạ từng AP sang cấu trúc dữ liệu, Chương 7 kiểm chứng "
          "từng NFR."),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.1 Giới thiệu
# --------------------------------------------------------------------------------------------------------------------

C3_1 = [
    ("p", "**Mục đích.** Tài liệu mô tả đầy đủ những gì phần mở rộng NoSQL của LedgerMind phải làm và phải đạt, đủ chi tiết để "
          "thiết kế CSDL (Chương 4), xây dựng (Chương 5, 6) và kiểm thử (Chương 7) bám vào cùng một danh sách yêu cầu."),
    ("p", "**Đối tượng đọc.** Giảng viên hướng dẫn (đánh giá mức đáp ứng yêu cầu môn học); hai thành viên nhóm (thiết kế, "
          "lập trình, kiểm thử, chụp minh chứng); người vận hành hệ thống sau này (cấu hình, sao lưu, xử lý sự cố của từng CSDL)."),
    ("p", "**Phạm vi sản phẩm.** Sản phẩm là LedgerMind gồm ứng dụng di động, web quản trị và backend core-api (dịch vụ Spring Boot, thư mục "
          "core-backend), được mở rộng "
          "bằng ba hệ NoSQL quanh PostgreSQL: MongoDB giữ bản sao phân tích các câu trả lời AI và phản hồi OCR; Redis giữ cache "
          "thống kê, mã OTP, bảng xếp hạng và kênh sự kiện realtime; Elasticsearch giữ chỉ mục (index) tìm kiếm giao dịch. "
          "PostgreSQL vẫn là nguồn sự thật của tiền, giao dịch và hóa đơn. Phạm vi trong và ngoài đề tài đã nêu ở "
          "mục 1.3."),
    ("p", "**Định nghĩa và từ viết tắt** dùng trong chương được liệt kê ở [[bang_dinh_nghia]]."),
    ("table", "Định nghĩa và từ viết tắt dùng trong SRS", 3, [1700, 6804],
     ["Thuật ngữ", "Ý nghĩa trong tài liệu này"],
     [
         ["FR, NFR", "Yêu cầu chức năng (FR-01..FR-16), yêu cầu phi chức năng (NFR-01..NFR-16)"],
         ["AP", "Mẫu truy cập dữ liệu (access pattern, AP-01..AP-38): một câu hỏi cụ thể ứng dụng đặt cho một CSDL"],
         ["TC, Q, S", "Ca kiểm thử (TC-01..TC-55); truy vấn trên GUI tool (Q-01..Q-41); ảnh chụp màn hình (S-01..S-89)"],
         ["Nguồn sự thật", "CSDL giữ bản đúng của dữ liệu (PostgreSQL); bản ở NoSQL là bản sao dựng lại được"],
         ["Sau commit", "Việc chạy trên luồng nền sau khi giao dịch PostgreSQL đã commit; lỗi ở đây không hủy nghiệp vụ"],
         ["Strong / Eventual", "Đọc thấy ngay giá trị đã commit / thấy sau một khoảng ngắn, khi việc sau commit chạy xong"],
         ["At-most-once", "Tin nhắn được giao nhiều nhất một lần, có thể mất (Redis Pub/Sub)"],
         ["JWT, OTP, TTL", "Mã thông báo đăng nhập không trạng thái; mã dùng một lần để đặt lại mật khẩu; thời gian sống của một khóa Redis"],
         ["ZSET, Pub/Sub, SSE", "Sorted Set của Redis; cơ chế phát/nhận tin của Redis; luồng sự kiện máy chủ đẩy tới trình "
                                "duyệt (Server-Sent Events)"],
     ], "", "bang_dinh_nghia"),
    ("p", "**Tài liệu tham chiếu.** Khung SRS theo IEEE 830 [18] và ISO/IEC/IEEE 29148 [19]; đề cương và yêu cầu môn học; tài "
          "liệu chính thức của MongoDB [10], Redis [12], Elasticsearch [14]. Các sự kiện kỹ thuật lấy từ mã nguồn LedgerMind "
          "(nhánh feature/nosql); mọi số đo lấy từ kho mã nguồn (docs/nosql/bench_results.md)."),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.2 Mô tả tổng quan
# --------------------------------------------------------------------------------------------------------------------

C3_2 = [
    ("p", "**Bối cảnh sản phẩm.** [[hinh_ngu_canh]] đặt LedgerMind giữa hai tác nhân người và hai hệ thống ngoài. Người dùng "
          "làm việc qua ứng dụng di động: ghi thu chi, quét hóa đơn, tìm kiếm, xem thống kê, đặt lại mật khẩu. Ảnh hóa đơn đi "
          "thẳng từ ứng dụng tới ai-service (DONUT V5), ứng dụng nhận lại JSON rồi mới gửi giao dịch cho core-api. Quản trị "
          "viên làm việc qua web quản trị: duyệt phản hồi OCR, xem bảng xếp hạng, vận hành chỉ mục, sao lưu, nhận sự kiện "
          "realtime. core-api gửi mã OTP qua dịch vụ email."),
    fig("ngu_canh", "Sơ đồ ngữ cảnh của hệ thống LedgerMind", "hinh_ngu_canh", 11),
    ("p", "**Tác nhân và đặc điểm người dùng.**"),
    ("table", "Tác nhân của hệ thống", 3, [1700, 3402, 3402],
     ["Tác nhân", "Đặc điểm", "Kênh, xác thực"],
     [
         ["Người dùng", "Cá nhân quản lý chi tiêu, dùng điện thoại, gõ tiếng Việt có dấu hoặc không dấu, có thể gõ sai",
          "Ứng dụng di động; JWT; quyền ROLE_USER, chỉ thấy dữ liệu của mình"],
         ["Quản trị viên", "Người vận hành: theo dõi chất lượng AI, thống kê, sao lưu; dùng máy tính",
          "Web quản trị; đăng nhập form và phiên HTTP; quyền ROLE_ADMIN"],
         ["ai-service", "Dịch vụ Python chạy DONUT V5, nhận ảnh, trả JSON (không có độ tin cậy)", "HTTP từ ứng dụng di động"],
         ["Dịch vụ email", "Gửi mã OTP đặt lại mật khẩu", "core-api gọi khi người dùng yêu cầu"],
     ], "", "bang_tac_nhan"),
    ("p", "**Ràng buộc.**"),
    ("b1", "**Hạ tầng:** toàn bộ hệ thống chạy bằng Docker Compose trên một máy, mỗi CSDL một node, không replication, không "
           "sharding; giới hạn bộ nhớ container lấy từ docker-compose.yml (Redis 192 MB, MongoDB 512 MB, Elasticsearch 1 GB với "
           "heap 512 MB, Kibana 1 GB). Máy chủ thật dự kiến là một máy nhỏ thuộc gói miễn phí hoặc gói sinh viên; tại thời điểm "
           "viết, hệ thống chưa được triển khai lên máy chủ nào."),
    ("b1", "**Ngôn ngữ, nền tảng:** backend Java 21 với Spring Boot 3.2.5; ứng dụng di động Flutter (Dart); web quản trị "
           "Thymeleaf; ai-service Python. PostgreSQL 15, Redis 8.10, MongoDB 6.0, Elasticsearch 8.11.4."),
    ("b1", "**Dữ liệu tiền:** mọi ghi về tiền phải nhất quán mạnh trong PostgreSQL; NoSQL không được là nơi duy nhất giữ một "
           "dữ liệu nghiệp vụ nào."),
    ("b1", "**Bảo mật:** cổng MongoDB, Elasticsearch, Kibana chỉ mở trên 127.0.0.1; Redis không mở cổng ra máy chủ; mọi CSDL "
           "có mật khẩu."),
    ("p", "**Giả định và phụ thuộc.**"),
    ("b1", "PostgreSQL luôn sẵn sàng; khi PostgreSQL dừng thì cả hệ thống dừng (đây không phải yêu cầu sẵn sàng của đồ án)."),
    ("b1", "Elasticsearch là tùy chọn: dịch vụ chỉ chạy với profile search và ứng dụng chỉ dùng nó khi biến SEARCH_ENGINE đặt "
           "là elasticsearch; mặc định ứng dụng tìm kiếm bằng PostgreSQL."),
    ("b1", "Dữ liệu ở Redis, MongoDB, Elasticsearch có thể dựng lại hoặc chịu mất: cache và bảng xếp hạng dựng lại từ "
           "PostgreSQL, chỉ mục dựng lại bằng reindex; log OCR đã mất thì không tự dựng lại được (giới hạn, mục 7.4)."),
    ("b1", "Phụ thuộc ngoài: ai-service để đọc hóa đơn, dịch vụ email để gửi OTP; khi chúng lỗi, chức năng tương ứng báo lỗi "
           "cho người dùng chứ không ghi dữ liệu sai."),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.3 Yêu cầu chức năng
# --------------------------------------------------------------------------------------------------------------------

FR_ROWS = [
    ["FR-01", "Đăng nhập và phân quyền", "Người dùng, Quản trị viên",
     "Di động dùng JWT; web quản trị dùng form đăng nhập và phiên; trang và API quản trị chỉ cho ROLE_ADMIN", "Cao", "AP-01"],
    ["FR-02", "Quên mật khẩu bằng OTP", "Người dùng", "Gửi OTP 6 số qua email, hạn 5 phút, sai tối đa 3 lần, dùng một lần",
     "Cao", "AP-05, AP-06"],
    ["FR-03", "Ghi giao dịch thu/chi", "Người dùng",
     "Checkout chống trùng theo clientId, khóa ví; sau commit cập nhật cache, bảng xếp hạng, chỉ mục tìm kiếm", "Cao",
     "AP-02, AP-10, AP-13, AP-32"],
    ["FR-04", "Sửa, xóa giao dịch", "Người dùng", "Sửa, xóa giao dịch của mình; sau commit đồng bộ như FR-03", "Cao",
     "AP-03, AP-10, AP-13, AP-32"],
    ["FR-05", "Quét hóa đơn bằng AI", "Người dùng",
     "Lưu hóa đơn và lần đọc thô của AI ở PostgreSQL; sau commit ghi bản sao phân tích ocr_logs", "Cao", "AP-04, AP-17"],
    ["FR-06", "Sửa kết quả AI của hóa đơn", "Người dùng",
     "Sửa tên quán, tổng tiền, ngày, hoặc gửi số tiền khi AI không đọc được; sinh ocr_feedbacks (một document mỗi hóa đơn "
     "và trường) và báo realtime cho quản trị", "Cao", "AP-04, AP-18, AP-15"],
    ["FR-07", "Xem trang chủ thống kê", "Người dùng", "Dashboard và cửa hàng hay mua, đọc qua cache Redis", "Cao",
     "AP-07, AP-09"],
    ["FR-08", "Tìm kiếm giao dịch", "Người dùng",
     "Tìm theo từ khóa tiếng Việt, gõ không dấu, sai chính tả, tiền tố; chỉ giao dịch của mình; Elasticsearch dừng vẫn "
     "tìm được (PostgreSQL)", "Cao", "AP-29, AP-30, AP-31"],
    ["FR-09", "Dashboard quản trị", "Quản trị viên",
     "Tổng quan, thống kê giao dịch theo tháng (cache), top 5 chi tiêu tháng", "Trung bình", "AP-08, AP-09, AP-11"],
    ["FR-10", "Bảng xếp hạng chi tiêu tháng", "Quản trị viên", "Xem top N theo tháng, dựng lại từ PostgreSQL khi cần",
     "Trung bình", "AP-11, AP-12, AP-13, AP-14"],
    ["FR-11", "Duyệt phản hồi OCR", "Quản trị viên",
     "Danh sách lọc theo trường, trạng thái, khoảng ngày, sắp xếp, phân trang; đánh dấu đã xử lý; xóa", "Cao",
     "AP-19, AP-20, AP-21"],
    ["FR-12", "Thống kê chất lượng OCR", "Quản trị viên",
     "Lỗi theo trường, theo mô hình, độ tin cậy theo tháng, tỉ lệ lần đọc bị sửa; biểu đồ", "Trung bình",
     "AP-22, AP-23, AP-24, AP-25"],
    ["FR-13", "API xem log OCR thô", "Quản trị viên",
     "API REST trả một trang log câu trả lời thô của AI (phân trang; không có trang web, không tra theo giao dịch)", "Thấp",
     "AP-26"],
    ["FR-14", "Vận hành chỉ mục tìm kiếm", "Quản trị viên", "Dựng lại chỉ mục Elasticsearch từ PostgreSQL; xem số document",
     "Trung bình", "AP-33, AP-34, AP-35"],
    ["FR-15", "Sao lưu, khôi phục", "Quản trị viên",
     "PostgreSQL (pg_dump) và MongoDB (mongodump, mongorestore) từ trang sao lưu của web quản trị", "Cao", "AP-27, AP-28"],
    ["FR-16", "Thông báo realtime cho quản trị", "Quản trị viên",
     "Toast và badge khi có hóa đơn chờ duyệt, chỗ sửa OCR mới, reindex, dựng lại bảng xếp hạng", "Trung bình",
     "AP-15, AP-16"],
]


def uc_table(code, name, rows, key):
    return ("table", f"Đặc tả use case {code}: {name}", 3, [1500, 7004], ["Mục", "Nội dung"], rows, "", key)


UC_FR03 = uc_table("FR-03", "Ghi giao dịch thu/chi", [
    ["Tiền điều kiện", "Đã đăng nhập (JWT hợp lệ); ứng dụng sinh clientId (UUID) cho giao dịch mới"],
    ["Luồng chính", "1. Ứng dụng gửi POST /api/transactions/checkout.\n2. core-api khóa ví của người dùng (khóa bi quan) và "
                    "tra clientId.\n3. Ghi giao dịch (kèm hóa đơn nếu có), cập nhật số dư, phát sự kiện thay đổi, commit.\n"
                    "4. Trả giao dịch vừa ghi.\n5. Sau commit, trên luồng nền: xóa cache thống kê của người dùng, ghi lại tổng "
                    "chi tháng vào bảng xếp hạng, index document giao dịch."],
    ["Luồng thay thế", "2a. clientId đã có (ứng dụng gửi lại do mất mạng): trả giao dịch gốc, không tạo bản trùng.\n"
                       "5a. Redis hoặc Elasticsearch lỗi: chỉ ghi log; giao dịch vẫn đã lưu; cache tự hết hạn theo TTL, "
                       "chỉ mục được chữa ở lần đổi sau hoặc khi reindex."],
    ["Hậu điều kiện", "Giao dịch nằm trong PostgreSQL; các bản sao NoSQL được cập nhật sau commit (nhất quán cuối cùng)"],
    ["Dữ liệu đọc/ghi", "PostgreSQL: users (khóa), transactions, receipts. Redis: DEL cache, Lua ZADD/ZREM tổng tuyệt đối. "
                        "Elasticsearch: save document. AP-02, AP-10, AP-13, AP-32"],
], "bang_uc_fr03")

UC_FR06 = uc_table("FR-05, FR-06", "Quét hóa đơn và sửa kết quả AI", [
    ["Tiền điều kiện", "Đã đăng nhập; ai-service đã trả JSON đọc được (FR-05) hoặc hóa đơn đã lưu (FR-06)"],
    ["Luồng chính", "1. Người dùng chụp hóa đơn; ứng dụng nhận JSON từ ai-service và điền sẵn biểu mẫu.\n2. Người dùng đối "
                    "chiếu, lưu: checkout ghi giao dịch, hóa đơn và lần đọc AI đầu tiên vào PostgreSQL.\n3. Sau commit: ghi "
                    "một log vào ocr_logs; nếu số tiền người dùng nhập khác tổng AI đọc thì ghi chỗ sửa vào ocr_feedbacks.\n"
                    "4. Về sau người dùng sửa tên quán, tổng tiền hoặc ngày (PUT /api/receipts/{id}, kèm version): hóa đơn "
                    "chuyển sang EDITED.\n5. Sau commit: upsert một document ocr_feedbacks cho mỗi (hóa đơn, trường) bị sửa, "
                    "phát sự kiện OCR_FEEDBACK_REPORTED cho quản trị, index lại giao dịch nếu tên quán đổi."],
    ["Luồng thay thế", "4a. version đã cũ hoặc trạng thái không cho sửa: HTTP 409, không đổi gì.\n"
                       "4b. AI không đọc được tổng (FAILED): người dùng gửi số tiền (POST /api/receipts/feedback/{receiptId}), "
                       "hóa đơn chuyển WAITING_FOR_REVIEW.\n"
                       "5a. Người dùng sửa trường về đúng giá trị AI: chỗ sửa cũ bị xóa khỏi ocr_feedbacks.\n"
                       "5b. MongoDB lỗi: chỉ ghi log, hóa đơn vẫn đã lưu."],
    ["Hậu điều kiện", "Hóa đơn và các lần đọc AI ở PostgreSQL; bản sao phân tích ở MongoDB"],
    ["Dữ liệu đọc/ghi", "PostgreSQL: receipts (version), receipt_processing_attempts. MongoDB: ocr_logs (insert), "
                        "ocr_feedbacks (updateFirst, upsert, remove). Redis: DEL cache thống kê, PUBLISH. AP-04, AP-17, AP-18, AP-15"],
], "bang_uc_fr06")

UC_FR08 = uc_table("FR-08", "Tìm kiếm giao dịch", [
    ["Tiền điều kiện", "Đã đăng nhập; từ khóa 2 đến 100 ký tự; trang 0..199, cỡ trang 1..50"],
    ["Luồng chính", "1. Ứng dụng gửi GET /api/transactions/search với từ khóa (sau 350 ms ngừng gõ).\n2. core-api lấy userId từ "
                    "JWT, hỏi Elasticsearch: lọc userId, hai multi_match (chính xác và mờ), sắp xếp theo điểm rồi ngày.\n"
                    "3. Nạp lại các giao dịch theo id và chủ sở hữu từ PostgreSQL.\n4. Trả danh sách, tổng số và tên engine "
                    "đã trả lời."],
    ["Luồng thay thế", "2a. Elasticsearch lỗi hoặc quá hạn: ghi một dòng log, tìm bằng PostgreSQL (LOWER(cột) LIKE … ESCAPE), "
                       "engine = postgres.\n2b. Cấu hình mặc định (SEARCH_ENGINE = postgres): tìm thẳng bằng PostgreSQL.\n"
                       "3a. Id có trong chỉ mục nhưng không còn ở PostgreSQL hoặc không thuộc người dùng: bị bỏ.\n"
                       "1a. Mất mạng: ứng dụng lọc cục bộ."],
    ["Hậu điều kiện", "Không đổi dữ liệu; kết quả chỉ gồm giao dịch của người gọi"],
    ["Dữ liệu đọc/ghi", "Elasticsearch: đọc index transactions. PostgreSQL: đọc transactions theo id và userId. "
                        "AP-29, AP-30, AP-31"],
], "bang_uc_fr08")

UC_FR02 = uc_table("FR-02", "Quên mật khẩu bằng OTP", [
    ["Tiền điều kiện", "Người dùng nhớ email của tài khoản"],
    ["Luồng chính", "1. Người dùng nhập email (POST /api/auth/forgot-password).\n2. core-api lưu OTP 6 số vào Redis bằng một "
                    "script Lua nguyên tử (xóa mã cũ, ghi Hash, đặt hạn 5 phút) rồi gửi email.\n3. Người dùng nhập OTP và "
                    "mật khẩu mới (POST /api/auth/reset-password).\n4. Script Lua kiểm tra hạn và mã; đúng thì xóa OTP, "
                    "PostgreSQL ghi mật khẩu mới."],
    ["Luồng thay thế", "4a. Sai mã: tăng số lần sai; lần sai thứ 3 xóa OTP, kể cả mã đúng sau đó cũng bị từ chối.\n"
                       "4b. Hết 5 phút: Redis đã xóa khóa, người dùng xin mã mới.\n"
                       "2a. Redis không với tới: báo lỗi rõ ràng \"Dịch vụ mã OTP tạm thời gián đoạn\", không có đường dự "
                       "phòng (cố ý)."],
    ["Hậu điều kiện", "Mật khẩu mới ở PostgreSQL; OTP không còn trong Redis"],
    ["Dữ liệu đọc/ghi", "Redis: Hash ledgermind:password-reset-otp:<email> (code, expiresAt, failedAttempts). PostgreSQL: "
                        "users. AP-05, AP-06"],
], "bang_uc_fr02")

UC_FR10 = uc_table("FR-10", "Xem và dựng lại bảng xếp hạng chi tiêu tháng", [
    ["Tiền điều kiện", "Đăng nhập với ROLE_ADMIN"],
    ["Luồng chính", "1. Quản trị viên mở dashboard hoặc gọi GET /api/admin/leaderboard (tháng yyyy-MM, top 1..50).\n2. "
                    "core-api kiểm tra ZSET của tháng; có thì đọc ZREVRANGE 0 N-1 WITHSCORES.\n3. Lấy tên người dùng bằng "
                    "một truy vấn PostgreSQL theo danh sách id.\n4. Trả top N."],
    ["Luồng thay thế", "2a. Thiếu khóa (hết TTL, sau khôi phục DB): tính tổng chi từng người dùng bằng một câu SQL, ZADD mọi "
                       "member, đặt hạn 62 ngày rồi đọc.\n2b. Redis lỗi: trả lời bằng PostgreSQL.\n"
                       "1a. Quản trị viên bấm \"Dựng lại\": xóa ZSET của tháng, dựng lại từ PostgreSQL, phát sự kiện "
                       "LEADERBOARD_REBUILT."],
    ["Hậu điều kiện", "ZSET của tháng tồn tại với TTL; điểm là tổng chi tuyệt đối đọc từ PostgreSQL"],
    ["Dữ liệu đọc/ghi", "Redis: ZSET ledgermind:leaderboard:spend:yyyy-MM. PostgreSQL: tổng chi theo người dùng, bảng users. "
                        "AP-11, AP-12, AP-14"],
], "bang_uc_fr10")

UC_FR11 = uc_table("FR-11, FR-12", "Duyệt phản hồi OCR và xem thống kê chất lượng", [
    ["Tiền điều kiện", "Đăng nhập với ROLE_ADMIN; MongoDB đang chạy"],
    ["Luồng chính", "1. Quản trị viên mở trang phản hồi OCR, chọn trường, trạng thái, khoảng ngày.\n2. core-api đếm và đọc một "
                    "trang ocr_feedbacks theo bộ lọc, mới nhất trước (20 dòng mỗi trang).\n3. Trang vẽ ba biểu đồ từ các "
                    "phép tổng hợp: lỗi theo trường, lỗi theo mô hình, độ tin cậy theo tháng; kèm tỉ lệ lần đọc bị sửa.\n"
                    "4. Quản trị viên đánh dấu một phản hồi đã xử lý hoặc xóa nó."],
    ["Luồng thay thế", "4a. Phản hồi không còn: HTTP 404."],
    ["Hậu điều kiện", "Trạng thái isResolved đổi hoặc document bị xóa (nguyên tử trên một document)"],
    ["Dữ liệu đọc/ghi", "MongoDB: ocr_feedbacks (find, count, save, deleteById), ocr_logs ($lookup, $group). "
                        "AP-19 đến AP-25"],
], "bang_uc_fr11")

C3_3 = [
    ("p", "Hệ thống có 16 yêu cầu chức năng, mỗi yêu cầu truy vết tới các mẫu truy cập dữ liệu (AP) ở mục 3.6 "
          "([[bang_fr]]). FR-01..FR-08 là chức năng của người dùng, FR-09..FR-16 của quản trị viên. Sơ đồ use case ở mục "
          "3.3.2."),
    ("table", "Yêu cầu chức năng và truy vết tới mẫu truy cập dữ liệu", 3, [850, 1400, 1100, 3254, 850, 1050],
     ["Mã", "Tên yêu cầu", "Tác nhân", "Mô tả", "Ưu tiên", "Truy vết AP"], FR_ROWS, "Nguồn: kho mã nguồn LedgerMind, nhánh feature/nosql (chốt 27/10/2026)", "bang_fr"),
    ("p", "Sáu use case chính – các use case chạm vào nhiều CSDL nhất – được đặc tả ở [[bang_uc_fr03]] đến [[bang_uc_fr11]], "
          "mỗi bảng ghi rõ dữ liệu đọc, ghi ở từng CSDL và AP tương ứng."),
    UC_FR03, UC_FR06, UC_FR08, UC_FR02, UC_FR10, UC_FR11,
]

C3_3_1 = [
    ("p", "**Quy trình thực tế.** Ngoài đời, một khoản chi đi qua các bước: mua hàng và nhận hóa đơn giấy → ghi lại khoản chi "
          "(tên quán, số tiền, ngày) → về sau xem lại, tìm lại, tổng kết theo tháng. LedgerMind mô phỏng bước ghi bằng việc "
          "chụp hóa đơn cho AI đọc, người dùng chỉ đối chiếu và sửa. Phía quản trị, mỗi chỗ người dùng sửa là một tín hiệu "
          "AI đọc sai, được gom lại để đánh giá mô hình."),
    ("p", "Quy trình quét hóa đơn được vẽ ở [[hinh_bpmn]] dưới dạng **sơ đồ hoạt động UML có swimlane** (công cụ vẽ PlantUML "
          "không có ký hiệu BPMN), bốn làn: Người dùng, Ứng dụng, ai-service, core-api. Dữ liệu sinh ra và đọc ở mỗi bước "
          "được ghi ở [[bang_bpmn]]; đây là nguồn của các AP ở mục 3.6."),
    ("table", "Dữ liệu sinh ra và đọc ở từng bước của quy trình quét hóa đơn", 3, [500, 2400, 1300, 3204, 1100],
     ["#", "Bước", "Làn", "Dữ liệu sinh ra / đọc", "AP"],
     [
         ["1", "Chụp ảnh, gửi tới ai-service", "Người dùng, Ứng dụng", "Ảnh hóa đơn (không lưu ở core-api)", "–"],
         ["2", "DONUT V5 đọc tên quán, địa chỉ, tổng tiền, ngày", "ai-service", "JSON câu trả lời AI, không có độ tin cậy", "–"],
         ["3", "Điền sẵn, người dùng đối chiếu, sửa, lưu", "Người dùng, Ứng dụng", "Biểu mẫu; clientId; JSON thô gửi kèm", "–"],
         ["4", "Khóa ví, chống trùng clientId", "core-api", "Đọc users (khóa bi quan), tra giao dịch theo clientId", "AP-02"],
         ["5", "Ghi giao dịch, hóa đơn, lần đọc AI đầu tiên; commit", "core-api",
          "PostgreSQL: transactions, receipts, receipt_processing_attempts, action_logs", "AP-02, AP-04"],
         ["6", "Sau commit: ghi log AI thô", "core-api", "MongoDB: một document ocr_logs (unique transactionId)", "AP-17"],
         ["7", "Sau commit: ghi chỗ sửa nếu khác AI, báo quản trị", "core-api",
          "MongoDB: ocr_feedbacks; Redis: PUBLISH ledgermind:admin-events", "AP-18, AP-15"],
         ["8", "Sau commit: cập nhật chỉ mục", "core-api", "Đọc lại giao dịch ở PostgreSQL, save document Elasticsearch",
          "AP-32"],
         ["9", "Sau commit: bảng xếp hạng, cache", "core-api", "Redis: Lua ZADD/ZREM tổng tuyệt đối; DEL cache thống kê",
          "AP-13, AP-10"],
         ["10", "Hiện giao dịch trong sổ cái", "Ứng dụng", "Phản hồi 200 trả ngay sau bước 5, không chờ bước 6–9", "–"],
     ], "", "bang_bpmn"),
    fig("bpmn_quet_hoa_don", "Quy trình quét hóa đơn (sơ đồ hoạt động UML có swimlane) và dữ liệu ghi ở mỗi bước",
        "hinh_bpmn", max_h_cm=16),
]

C3_3_2 = [
    ("p", "Các sơ đồ dưới đây mô hình hóa chức năng theo yêu cầu của đề cương môn học; mỗi sơ đồ ghi rõ CSDL tham gia."),
    ("p", "**Use case.** [[hinh_uc_tong_quat]] là sơ đồ tổng quát, mỗi use case ghi mã FR và CSDL tham gia; [[hinh_uc_nguoi_dung]] "
          "và [[hinh_uc_quan_tri]] chi tiết theo hai phân quyền ROLE_USER và ROLE_ADMIN. Truy vết use case → AP nằm ở cột "
          "cuối của [[bang_fr]] và ở ma trận mục 3.8."),
    fig("uc_tong_quat", "Sơ đồ use case tổng quát (kèm CSDL tham gia)", "hinh_uc_tong_quat", 12.5),
    fig("uc_nguoi_dung", "Sơ đồ use case của Người dùng (phân quyền ROLE_USER)", "hinh_uc_nguoi_dung", max_h_cm=10.5),
    fig("uc_quan_tri", "Sơ đồ use case của Quản trị viên (phân quyền ROLE_ADMIN)", "hinh_uc_quan_tri", max_h_cm=10.5),
    ("p", "**Activity.** Ba luồng chính, mỗi luồng tách rõ nhánh NoSQL và nhánh PostgreSQL:"),
    ("b1", "[[hinh_act_dashboard]] là luồng đọc thống kê trang chủ theo cache-aside: Redis trả lời khi có khóa; trượt thì tính "
           "từ PostgreSQL rồi ghi cache với TTL tối đa 45 s trừ ngẫu nhiên tới 10 %; Redis lỗi thì coi như trượt và bỏ qua việc "
           "ghi cache. Cache bị xóa sau commit của mỗi lần ghi, nên lần đọc kế tiếp tính lại từ PostgreSQL."),
    ("b1", "[[hinh_act_tim_kiem]] là luồng tìm kiếm: nhánh Elasticsearch khi được bật, nhánh PostgreSQL khi tắt hoặc khi "
           "Elasticsearch lỗi; cả hai nhánh kết thúc bằng việc nạp lại giao dịch theo id và chủ sở hữu. Nhánh mờ dùng fuzziness "
           "AUTO:4,7 với prefix_length 1: chỉ sửa lỗi gõ ở từ từ 4 ký tự trở lên và giữ nguyên chữ cái đầu."),
    ("b1", "[[hinh_act_sua_hoa_don]] là luồng sửa hóa đơn: PostgreSQL kiểm tra version và trạng thái rồi ghi; sau commit ba "
           "nhánh song song cập nhật Redis (xóa cache), Elasticsearch (chỉ khi tên quán đổi) và MongoDB (chỗ sửa OCR)."),
    fig("act_dashboard_cache", "Sơ đồ hoạt động đọc thống kê trang chủ (Redis và PostgreSQL)", "hinh_act_dashboard", max_h_cm=10),
    fig("act_tim_kiem", "Sơ đồ hoạt động tìm kiếm giao dịch (Elasticsearch và PostgreSQL)", "hinh_act_tim_kiem", max_h_cm=10),
    fig("act_sua_hoa_don", "Sơ đồ hoạt động sửa hóa đơn (PostgreSQL, sau commit Redis, Elasticsearch, MongoDB)",
        "hinh_act_sua_hoa_don", max_h_cm=10),
    ("p", "**Sequence.** Bốn luồng, mỗi CSDL một lifeline riêng. Điểm chung: PostgreSQL commit trước, phản hồi trả về trước, "
          "các lifeline NoSQL chỉ nhận lệnh trong đoạn \"sau commit\" trên luồng nền."),
    ("b1", "Tìm kiếm ([[hinh_seq_tim_kiem]]): core-api lấy userId từ JWT, hỏi Elasticsearch (hoặc PostgreSQL khi tắt hay lỗi) để lấy danh "
           "sách id, rồi luôn nạp lại giao dịch từ PostgreSQL theo id và chủ sở hữu, nên kết quả không bao giờ lẫn dữ liệu của "
           "người khác."),
    ("b1", "Sửa kết quả OCR ([[hinh_seq_sua_ocr]]): lần sửa bị từ chối bằng 409 nếu version đã cũ; lần sửa hợp lệ commit ở PostgreSQL, trả 200, "
           "rồi mới xóa cache, ghi ocr_feedbacks, index lại (khi tên quán đổi) và PUBLISH sự kiện cho quản trị."),
    ("b1", "Bảng xếp hạng ([[hinh_seq_bang_xep_hang]]): đường đọc dựng lại ZSET từ PostgreSQL khi thiếu khóa; đường ghi sau commit đọc lại "
           "tổng chi tuyệt đối của người dùng rồi ghi bằng Lua ZADD hoặc ZREM, không dùng ZINCRBY."),
    ("b1", "Đồng bộ chỉ mục ([[hinh_seq_dong_bo]]): bộ index đọc lại giao dịch từ PostgreSQL rồi ghi cả document (hoặc xóa), không vá từ nội "
           "dung sự kiện; Elasticsearch lỗi thì document cũ giữ nguyên tới lần đổi sau hoặc khi reindex."),
    fig("seq_tim_kiem", "Sơ đồ tuần tự tìm kiếm giao dịch", "hinh_seq_tim_kiem", max_h_cm=10),
    fig("seq_sua_ocr", "Sơ đồ tuần tự sửa kết quả OCR", "hinh_seq_sua_ocr", max_h_cm=10),
    fig("seq_bang_xep_hang", "Sơ đồ tuần tự bảng xếp hạng chi tiêu tháng", "hinh_seq_bang_xep_hang", max_h_cm=10),
    fig("seq_dong_bo_index", "Sơ đồ tuần tự đồng bộ chỉ mục tìm kiếm sau commit", "hinh_seq_dong_bo", max_h_cm=10),
    ("p", "**State machine.** Đối tượng có vòng đời là hóa đơn ([[hinh_state]]). Trạng thái lưu ở PostgreSQL (cột status của "
          "receipts), không ở NoSQL, vì mọi bước chuyển cần nhất quán mạnh: chủ sửa và quản trị duyệt có thể đến cùng lúc, nên "
          "mỗi bước chuyển đi qua khóa lạc quan (version) và bảng chuyển hợp lệ; lần ghi thua nhận HTTP 409. Trạng thái "
          "PROCESSING được dành sẵn nhưng không bước chuyển nào đi tới hay đi ra; checkout không bao giờ lưu PENDING."),
    fig("state_hoa_don", "Máy trạng thái hóa đơn (lưu ở PostgreSQL)", "hinh_state", 13),
    ("p", "**DFD.** Mức 0 ([[hinh_dfd0]]) coi cả hệ thống là một tiến trình. Mức 1 tách sáu tiến trình: phần người dùng "
          "([[hinh_dfd1]], gồm xác thực và OTP, giao dịch và hóa đơn, thống kê, tìm kiếm) và phần quản trị ([[hinh_dfd1_admin]], gồm "
          "phản hồi và thống kê OCR, xếp hạng – vận hành – realtime). Kho dữ liệu là bốn CSDL; nhãn trên luồng ghi cụ thể bảng, "
          "collection, kiểu khóa Redis hoặc index tương ứng (D1 PostgreSQL: users, transactions, receipts; D2 Redis: Hash OTP, "
          "JSON cache, ZSET, kênh Pub/Sub; D3 MongoDB: ocr_logs, ocr_feedbacks; D4 Elasticsearch: index transactions)."),
    fig("dfd_muc0", "DFD mức 0 của hệ thống LedgerMind", "hinh_dfd0", 10),
    fig("dfd_muc1", "DFD mức 1, phần người dùng (tiến trình 1–4)", "hinh_dfd1", 12),
    fig("dfd_muc1_admin", "DFD mức 1, phần quản trị (tiến trình 5–6)", "hinh_dfd1_admin", 15),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.4 Yêu cầu phi chức năng
# --------------------------------------------------------------------------------------------------------------------

NFR_ROWS = [
    ["NFR-01", "Hiệu năng", "Đọc cache Redis (AP-07, AP-08) p95 < 5 ms ở tầng dữ liệu, 1 luồng", "Đo E4",
     "p95 0,060–0,065 ms (E4) → đạt"],
    ["NFR-02", "Hiệu năng", "Cache hit nhanh hơn cache miss (SQL của dashboard) ≥ 5 lần ở p50", "Đo E4",
     "11×, 39×, 529× tùy loại thống kê (E4) → đạt"],
    ["NFR-03", "Hiệu năng", "Tìm kiếm Elasticsearch (AP-29) p95 < 100 ms trên 100k giao dịch tổng hợp", "Đo E2",
     "p95 5,65 ms (người dùng điển hình), 4,95 ms (người dùng nặng) (E2) → đạt"],
    ["NFR-04", "Chất lượng tìm kiếm", "\"pho\" ra \"Phở\", sai 1 ký tự vẫn ra, tiền tố \"phu\" ra \"Phúc Long\", không ra "
                                       "giao dịch người khác; chế độ PostgreSQL không bỏ dấu (giới hạn)",
     "TC-32..TC-35; đo E2",
     "\"pho\" và \"phở\" cùng 1.852 kết quả, bỏ sót 0 (E2); PostgreSQL: \"phở\" 1.233, \"pho\" 176; còn dương tính giả do "
     "khớp tiền tố (P@20 70 % ở người dùng điển hình)"],
    ["NFR-05", "Hiệu năng", "Truy vấn MongoDB có index dùng IXSCAN, số document đọc = số trả về, p95 < 20 ms",
     "Q-16 (TC-46); đo E1",
     "Q-01, Q-03 đạt (p95 0,40 ms); Q-02 dùng IXSCAN, p95 0,51 ms nhưng đọc 61 để trả 5 → đạt một phần (E1)"],
    ["NFR-06", "Hiệu năng", "Top 10 bảng xếp hạng (AP-11) p95 < 5 ms, so với SQL", "Đo E3",
     "ZREVRANGE kèm tra tên p95 0,39 ms; p50 0,36 ms so với SQL p50 23,6 ms (66×) (E3) → đạt"],
    ["NFR-07", "Sẵn sàng", "Redis dừng: thống kê vẫn trả lời (đọc PostgreSQL), mỗi request thêm không quá 1 s kết nối / "
                           "500 ms lệnh; OTP báo lỗi rõ ràng", "TC-10, TC-11",
     "Kiểm chứng bằng test tích hợp; độ trễ quan sát trên ứng dụng: mục tiêu (chưa đo)"],
    ["NFR-08", "Sẵn sàng", "Elasticsearch dừng: tìm kiếm vẫn trả lời bằng PostgreSQL (engine=postgres), thêm không quá 1 s "
                           "kết nối / 2 s socket; ghi giao dịch vẫn thành công", "TC-36, TC-40",
     "Kiểm chứng bằng test; độ trễ quan sát trên ứng dụng: mục tiêu (chưa đo)"],
    ["NFR-09", "Sẵn sàng", "MongoDB dừng: ghi giao dịch, hóa đơn vẫn thành công; lỗi ghi MongoDB chỉ log, chờ tối đa 5 s trên "
                           "luồng nền", "TC-30; cấu hình timeout 5 s", "Kiểm chứng bằng test"],
    ["NFR-10", "Nhất quán", "PostgreSQL strong (khóa ví, khóa lạc quan 409, clientId duy nhất); NoSQL eventual sau commit; "
                            "cache cũ tối đa bằng TTL; rollback không đổi NoSQL", "TC-08, TC-09, TC-52, TC-53, TC-54",
     "Kiểm chứng bằng test"],
    ["NFR-11", "Bảo mật dữ liệu", "Không bao giờ trả giao dịch của người khác qua tìm kiếm; cache theo userId không lẫn",
     "TC-07, TC-35, TC-37, TC-44", "Kiểm chứng bằng test"],
    ["NFR-12", "Bảo mật", "API và trang quản trị chỉ ROLE_ADMIN (2 lớp); Redis có mật khẩu, không mở cổng; MongoDB, "
                          "Elasticsearch có mật khẩu, cổng chỉ 127.0.0.1; Elasticsearch chặn tự tạo index",
     "TC-19, TC-31, TC-45; đọc file compose", "Kiểm chứng bằng test và cấu hình"],
    ["NFR-13", "Sao lưu", "MongoDB: dump → xóa → khôi phục → đếm lại khớp 100 %, khôi phục < 5 phút (dữ liệu demo); Redis "
                          "dựng lại từ PostgreSQL; Elasticsearch: snapshot hoặc reindex", "TC-29, TC-49, TC-50; đo trên stack demo",
     "mongorestore 0,6 s (trung vị 0,543 s); 36 ocr_logs + 36 ocr_feedbacks, 13 index, 2 validator khớp trước/sau (dữ liệu demo) → đạt; thao tác trên trang sao "
     "lưu chưa đo"],
    ["NFR-14", "Tài nguyên", "Chạy trên một máy: Redis ≤ 192 MB, MongoDB ≤ 512 MB, Elasticsearch ≤ 1 GB (heap 512 MB), "
                             "Kibana chỉ bật khi demo", "docker stats trên stack demo (S-89)",
     "Redis 6,1 MiB, MongoDB 84,2 MiB → đạt; Elasticsearch 1 GB **không đạt** khi bật Kibana (bị OOM-kill sau 22 s), dùng "
     "97,4 % khi Kibana tắt"],
    ["NFR-15", "Realtime", "Sự kiện quản trị tới trình duyệt < 1 s sau PUBLISH; Redis chưa sẵn khi khởi động thì ứng dụng vẫn "
                           "chạy và tự đăng ký lại", "TC-17, TC-18; đo E6",
     "E6, chặng server, bài đo JUnit: p95 1,573 ms, mất 0/300 → đạt phần server; chặng tới trình duyệt chưa đo"],
    ["NFR-16", "Mở rộng", "Nhiều instance API dùng chung Redis thấy cache và sự kiện của nhau; mỗi CSDL 1 node, không đặt mục "
                          "tiêu mở rộng ngang CSDL", "TC-55, TC-17", "Kiểm chứng bằng test tích hợp hai instance"],
]

C3_4 = [
    ("p", "Mỗi yêu cầu phi chức năng có một con số hoặc một điều kiện kiểm được và cách kiểm chứng ([[bang_nfr]]). Các con số "
          "là **mục tiêu** chốt ngày 27/10/2026, trước mọi phép đo; cột \"Kết quả đo\" ghi lại số đo thật về sau để Chương 7 "
          "đối chiếu, mục tiêu không được sửa theo số đo. Độ trễ ở NFR-01..NFR-06 đo ở **tầng dữ liệu** (client cùng mạng "
          "docker với CSDL, 1 luồng, p95) trên dữ liệu tổng hợp 100k (sinh bằng gen_data.py); độ trễ ở mức ứng dụng chỉ có số "
          "khi chạy JMeter, hiện chưa chạy nên vẫn là mục tiêu. \"Kiểm chứng bằng test\" nghĩa là các lớp test chứa TC tương "
          "ứng đã chạy xanh ngày 27/10/2026 (Chương 7)."),
    ("table", "Yêu cầu phi chức năng, cách kiểm chứng và kết quả đo", 3, [1250, 3050, 1650, 2554],
     ["Mã, nhóm", "Yêu cầu (đo được)", "Cách kiểm chứng", "Kết quả đo"], [[f"{r[0]}\n{r[1]}"] + r[2:] for r in NFR_ROWS],
     "Mục tiêu chốt 27/10/2026; số đo: kho mã nguồn (docs/nosql/bench_results.md, E1–E6, NFR-13, NFR-14), ngày 27–28/10/2026", "bang_nfr"),
    ("p", "Hai yêu cầu chưa đạt trọn được ghi lại như kết quả, không sửa mục tiêu: NFR-05 với Q-02 (lọc theo khoảng độ tin "
          "cậy nhưng sắp xếp theo thời gian thì không index nào khớp trọn cả hai) và NFR-14 với Elasticsearch 1 GB khi Kibana "
          "cùng chạy (ở giới hạn 1,5 GB của stack demo thì không khởi động lại lần nào). Cả hai được phân tích ở Chương 7."),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.5 Yêu cầu dữ liệu
# --------------------------------------------------------------------------------------------------------------------

C3_5 = [
    ("p", "**a) Đặc tính dữ liệu (3V).** [[bang_3v]] mô tả từng nhóm dữ liệu theo khối lượng (Volume), tốc độ (Velocity), "
          "độ đa dạng (Variety) và vòng đời. Hệ thống chưa chạy với người dùng thật, nên mọi số đếm ghi rõ nguồn: \"dữ liệu "
          "demo\" (các script trong scripts/nosql) hoặc \"dữ liệu tổng hợp 100k (sinh bằng gen_data.py)\". Cột Velocity ghi "
          "mức tần suất của AP tương ứng (mục 3.6), không phải lưu lượng đo được."),
    ("table", "Đặc tính dữ liệu (3V) theo nhóm, kèm nguồn số đếm", 3, [1300, 2104, 1400, 1400, 1200, 1100],
     ["Nhóm dữ liệu", "Volume (nguồn)", "Velocity", "Variety", "Vòng đời / TTL", "CSDL"],
     [
         ["Người dùng, giao dịch, hóa đơn, lần đọc AI",
          "Dữ liệu tổng hợp 100k: 100.000 giao dịch, 34.943 hóa đơn, 1.000 người dùng",
          "Ghi: Cao (AP-02 đến AP-04); xác thực: Rất cao (AP-01)", "Quan hệ, cấu trúc cố định; JSON thô AI là văn bản",
          "Vĩnh viễn (nguồn sự thật)", "PG"],
         ["Log câu trả lời AI, phản hồi OCR",
          "Dữ liệu tổng hợp 100k: 100.000 ocr_logs (41,9 MB), 45.471 ocr_feedbacks (11,0 MB); dữ liệu demo: 36 + 36",
          "Ghi: Cao (AP-17), Trung bình (AP-18); đọc thống kê: Thấp", "Bán cấu trúc: JSON thô đổi theo phiên bản mô hình, "
                                                                     "document lồng", "Vĩnh viễn, không TTL index",
          "Mongo"],
         ["Cache thống kê", "Mỗi người dùng 2 khóa, cộng khóa quản trị; giá trị JSON 0,8–1,9 KB (dữ liệu tổng hợp 100k, E4)",
          "Đọc: Rất cao (AP-07); xóa sau mỗi lần ghi (AP-10)", "Key-value, giá trị JSON", "45–60 s, trừ ngẫu nhiên tới 10 %",
          "Redis"],
         ["OTP đặt lại mật khẩu", "Một Hash 3 trường cho mỗi email đang đặt lại mật khẩu (theo thiết kế)",
          "Thấp (AP-05, AP-06)", "Key-value (Hash)", "5 phút; xóa khi dùng hoặc sai 3 lần", "Redis"],
         ["Bảng xếp hạng chi tiêu", "Một ZSET mỗi tháng; tháng 2026-10: 1.000 member từ 27.067 dòng chi (dữ liệu tổng hợp 100k)",
          "Ghi: Cao (AP-13); đọc: Trung bình (AP-11)", "Sorted Set (member userId, score tổng chi)", "62 ngày", "Redis"],
         ["Sự kiện quản trị", "Không lưu; 4 loại sự kiện", "Trung bình (AP-15, AP-16)", "Thông điệp JSON nhỏ",
          "Không lưu (at-most-once)", "Redis"],
         ["Tài liệu tìm kiếm giao dịch", "Dữ liệu tổng hợp 100k: 100.000 document (10,9 MB); dữ liệu demo: 47 giao dịch của 3 "
                                         "người dùng (tệp bulk NDJSON)",
          "Đọc: Cao (AP-29); ghi sau mỗi giao dịch (AP-32)", "Văn bản tiếng Việt kèm số, ngày, cờ",
          "Theo giao dịch gốc", "ES"],
     ], "PG = PostgreSQL, Mongo = MongoDB, ES = Elasticsearch. Velocity là mức tần suất của AP: hệ thống chưa có lưu lượng thật. Số đếm: docs/nosql/bench_results.md (dữ liệu tổng hợp 100k, seed 42); scripts/nosql (dữ liệu demo)", "bang_3v"),
    ("p", "**Bốn loại dữ liệu khác nhau.** Đồ án xử lý bốn loại dữ liệu, mỗi loại ở CSDL hợp với nó: (1) **dữ liệu quan hệ** – "
          "người dùng, giao dịch, hóa đơn, ngân sách – ở PostgreSQL, vì cần khóa ngoại, giao dịch ACID và khóa ví; (2) **dữ "
          "liệu bán cấu trúc** – câu trả lời JSON của AI và các chỗ người dùng sửa – ở MongoDB, vì cấu trúc đổi theo phiên bản "
          "mô hình và cần thống kê bằng aggregation; (3) **dữ liệu key-value có hạn** – cache thống kê, mã OTP, bảng xếp hạng "
          "dạng Sorted Set, kênh sự kiện – ở Redis, vì cần đọc dưới một mili-giây và tự hết hạn; (4) **tài liệu tìm kiếm toàn "
          "văn** – giao dịch đã phân tích bằng analyzer tiếng Việt – ở Elasticsearch, vì cần chỉ mục đảo, bỏ dấu, chịu lỗi "
          "chính tả và xếp theo độ liên quan."),
    ("p", "**b) Mô hình khái niệm.** [[hinh_erd_khai_niem]] là ERD mức khái niệm của toàn hệ thống, chưa chuẩn hóa và chưa "
          "gắn với CSDL cụ thể; việc đặt thực thể vào CSDL nào là quyết định ở Chương 4 (mục 4.2). Nét liền là quan hệ có "
          "ràng buộc tham chiếu; nét đứt là liên kết logic chỉ qua id: log OCR gắn với giao dịch qua transactionId, phản hồi "
          "OCR gắn với hóa đơn qua receiptId, tài liệu tìm kiếm trùng id với giao dịch, mỗi mục của bảng xếp hạng mang userId. "
          "Từ điển dữ liệu ở [[bang_tu_dien]]; dấu ∗ đánh dấu thuộc tính bắt buộc, ví dụ lấy từ dữ liệu demo."),
    fig("erd_khai_niem", "ERD khái niệm (chưa gắn với CSDL cụ thể)", "hinh_erd_khai_niem", 11),
    ("table", "Từ điển dữ liệu mức khái niệm", 3, [1700, 4504, 2300],
     ["Thực thể", "Thuộc tính: kiểu (∗ = bắt buộc)", "Ví dụ (dữ liệu demo)"],
     [
         ["Người dùng", "mã∗: số; tên đăng nhập∗, email∗: chuỗi; vai trò∗: chuỗi; số dư ví∗: số thập phân",
          "vai trò ROLE_USER"],
         ["Giao dịch", "mã∗: số; số tiền∗: số thập phân; là khoản chi∗: logic; ngày∗: ngày giờ; ghi chú, danh mục, địa điểm, "
                       "phương thức trả: chuỗi; clientId: chuỗi", "65000; \"Ăn phở bò sáng\"; \"Ăn uống\"; WALLET"],
         ["Hóa đơn", "tên quán: chuỗi; tổng tiền: số thập phân; ngày: ngày; trạng thái∗: liệt kê; version∗: số",
          "\"Phở Thìn\"; EDITED"],
         ["Lần đọc AI", "số thứ tự lần đọc∗: số; trạng thái∗: chuỗi; JSON thô∗: văn bản; thời điểm∗: ngày giờ", "lần 1"],
         ["Log OCR thô", "transactionId∗: số (duy nhất); rawJsonData∗: document; modelVersion: chuỗi; aiReading: document "
                         "lồng; averageConfidenceScore: số hoặc null; createdAt: ngày giờ",
          "\"donut-v5\"; tên quán AI đọc \"Phở Thìn\""],
         ["Phản hồi OCR", "receiptId∗, transactionId, userId: số; fieldError∗: liệt kê 3 giá trị; expectedValue, aiValue: "
                          "chuỗi; isResolved: logic; reportedAt, updatedAt: ngày giờ",
          "fieldError seller_name; aiValue \"Ph0 Th1n\""],
         ["Tài liệu tìm kiếm", "id∗ = mã giao dịch; userId∗; ghi chú, tên quán, danh mục, địa điểm, phương thức trả: văn bản; "
                               "số tiền: số; là khoản chi: logic; ngày: ngày", "tên quán \"Phở Thìn\""],
         ["Bảng xếp hạng tháng", "tháng∗: yyyy-MM; mục: mã người dùng∗, điểm∗ = tổng chi của tháng", "tháng 2026-10"],
         ["OTP", "email∗; mã∗: chuỗi 6 số; hạn∗: mili-giây; số lần sai∗: số", "số lần sai 0..2"],
     ], "Nguồn: core-backend (lớp Entity, Document); scripts/nosql/mongodb_demo.js, scripts/nosql/elasticsearch/transactions-bulk.ndjson", "bang_tu_dien"),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.6 Mẫu truy cập dữ liệu
# --------------------------------------------------------------------------------------------------------------------

AP_ROWS = [
    ["AP-01", "Xác thực: đọc người dùng, kiểm tra JWT bị thu hồi", "PostgreSQL", "Đọc", "username hoặc email; hash token",
     "Rất cao", "< 20 ms", "Strong"],
    ["AP-02", "Checkout: khóa ví, chống trùng clientId, ghi giao dịch", "PostgreSQL", "Ghi", "userId, clientId, giao dịch",
     "Cao", "< 50 ms", "Strong"],
    ["AP-03", "Sửa/xóa giao dịch", "PostgreSQL", "Ghi", "transactionId", "Trung bình", "< 50 ms", "Strong"],
    ["AP-04", "Ghi hóa đơn và lần đọc AI; sửa hóa đơn có khóa lạc quan", "PostgreSQL", "Ghi", "receiptId, version", "Cao",
     "< 50 ms", "Strong"],
    ["AP-05", "Lưu OTP", "Redis", "Ghi", "email, code", "Thấp", "< 5 ms", "Strong (một node, Lua nguyên tử)"],
    ["AP-06", "Kiểm tra OTP", "Redis", "Đọc/Ghi", "email, code", "Thấp", "< 5 ms", "Strong"],
    ["AP-07", "Đọc cache thống kê của người dùng", "Redis", "Đọc", "userId", "Rất cao", "< 5 ms",
     "Eventual (cũ tối đa TTL 45–60 s nếu xóa cache lỗi)"],
    ["AP-08", "Đọc cache thống kê quản trị", "Redis", "Đọc", "tháng, ngưỡng, số tháng", "Trung bình", "< 5 ms", "Eventual"],
    ["AP-09", "Cache miss: tính từ PostgreSQL rồi ghi cache (TTL có jitter)", "PostgreSQL + Redis", "Đọc + Ghi",
     "như AP-07/08", "Theo miss", "< 200 ms", "Strong (đọc PG)"],
    ["AP-10", "Xóa cache sau commit", "Redis", "Ghi", "userId / cả cache", "Cao", "< 10 ms", "Eventual"],
    ["AP-11", "Top N chi tiêu của tháng", "Redis (+ PG lấy tên)", "Đọc", "tháng, limit", "Trung bình",
     "< 5 ms (phần Redis)", "Eventual"],
    ["AP-12", "Dựng lại bảng xếp hạng tháng từ PostgreSQL", "PostgreSQL + Redis", "Đọc + Ghi", "tháng",
     "Thấp", "< 500 ms", "Eventual"],
    ["AP-13", "Cập nhật tổng chi một người dùng sau commit", "PostgreSQL + Redis", "Ghi", "userId, tháng", "Cao", "< 20 ms",
     "Eventual"],
    ["AP-14", "Xóa mọi tháng bảng xếp hạng", "Redis", "Ghi", "–", "Rất thấp", "< 100 ms", "Eventual"],
    ["AP-15", "Phát sự kiện quản trị", "Redis", "Ghi", "type, id", "Trung bình", "< 5 ms", "At-most-once"],
    ["AP-16", "Nhận sự kiện và đẩy tới trình duyệt", "Redis → SSE", "Đọc", "–", "Trung bình",
     "< 1 s tới trình duyệt", "At-most-once"],
    ["AP-17", "Ghi log OCR thô sau commit", "MongoDB", "Ghi", "transactionId, JSON", "Cao", "< 20 ms", "Eventual"],
    ["AP-18", "Upsert chỗ sửa OCR, xóa chỗ sửa lỗi thời", "MongoDB", "Ghi", "receiptId, fieldError", "Trung bình", "< 20 ms",
     "Eventual (nguyên tử trên một document)"],
    ["AP-19", "Danh sách phản hồi OCR lọc/sắp xếp/phân trang", "MongoDB", "Đọc",
     "field, resolved, from, to, page, size, sort", "Trung bình", "< 20 ms", "Eventual"],
    ["AP-20", "Đánh dấu phản hồi đã xử lý", "MongoDB", "Ghi", "id", "Thấp", "< 20 ms", "Strong (một document)"],
    ["AP-21", "Xóa phản hồi", "MongoDB", "Ghi", "id", "Thấp", "< 20 ms", "Strong (một document)"],
    ["AP-22", "Số lỗi theo trường", "MongoDB", "Đọc", "from, to", "Thấp", "< 50 ms", "Eventual"],
    ["AP-23", "Số lỗi theo mô hình", "MongoDB", "Đọc", "from, to", "Thấp", "< 50 ms", "Eventual"],
    ["AP-24", "Độ tin cậy trung bình theo tháng", "MongoDB", "Đọc", "from, to", "Thấp", "< 50 ms", "Eventual"],
    ["AP-25", "Tỉ lệ lần đọc bị sửa", "MongoDB", "Đọc", "from, to", "Thấp", "< 100 ms", "Eventual"],
    ["AP-26", "Xem log OCR thô theo trang (REST)", "MongoDB", "Đọc", "page, size, sort", "Thấp", "< 20 ms", "Eventual"],
    ["AP-27", "Sao lưu MongoDB", "MongoDB", "Đọc toàn bộ", "–", "Rất thấp", "< 60 s (dữ liệu demo)",
     "Bản chụp tại thời điểm dump"],
    ["AP-28", "Khôi phục MongoDB", "MongoDB", "Ghi toàn bộ", "–", "Rất thấp", "< 60 s (dữ liệu demo)", "–"],
    ["AP-29", "Tìm giao dịch của mình theo từ khóa", "Elasticsearch", "Đọc", "userId (JWT), q, page, size", "Cao",
     "< 100 ms", "Eventual (index sau commit)"],
    ["AP-30", "Nạp lại kết quả theo id và chủ sở hữu", "PostgreSQL", "Đọc", "ids, userId", "Cao", "< 20 ms", "Strong"],
    ["AP-31", "Tìm kiếm dự phòng trên PostgreSQL", "PostgreSQL", "Đọc", "userId, q, page, size", "Khi ES lỗi",
     "< 500 ms", "Strong"],
    ["AP-32", "Index/xóa document một giao dịch sau commit", "PostgreSQL + Elasticsearch", "Ghi", "transactionId", "Cao",
     "< 50 ms", "Eventual"],
    ["AP-33", "Dựng lại toàn bộ chỉ mục", "PostgreSQL + Elasticsearch", "Ghi", "–", "Rất thấp", "< 60 s",
     "Eventual"],
    ["AP-34", "Tạo chỉ mục khi thiếu", "Elasticsearch", "Ghi", "–", "Khởi động", "< 5 s", "–"],
    ["AP-35", "Đếm document của chỉ mục", "Elasticsearch", "Đọc", "–", "Thấp", "< 50 ms", "Eventual"],
    ["AP-36", "Thống kê chi tiêu theo danh mục / tháng (chỉ trong script)", "Elasticsearch", "Đọc", "userId, khoảng ngày",
     "–", "< 100 ms", "Eventual"],
    ["AP-37", "Đối chiếu chỗ sửa với câu trả lời thô; thống kê gộp $facet (chỉ trong script)", "MongoDB", "Đọc",
     "fieldError", "–", "< 50 ms", "Eventual"],
    ["AP-38", "Tra log OCR của một giao dịch; tìm lần đọc có độ tin cậy thấp (chỉ trong script)", "MongoDB", "Đọc",
     "transactionId; ngưỡng", "–", "< 20 ms", "Eventual"],
]

AP_DB = {'PostgreSQL': 'PG', 'MongoDB': 'Mongo', 'Elasticsearch': 'ES', 'Redis (+ PG lấy tên)': 'Redis (+PG)', 'PostgreSQL + Redis': 'PG + Redis', 'PostgreSQL + Elasticsearch': 'PG + ES'}
AP_NQ = {'Strong (một node, Lua nguyên tử)': 'S (1)', 'Eventual (cũ tối đa TTL 45–60 s nếu xóa cache lỗi)': 'E (2)', 'Strong (đọc PG)': 'S (3)', 'Eventual (nguyên tử trên một document)': 'E (4)', 'Strong (một document)': 'S (4)', 'Bản chụp tại thời điểm dump': '(5)', 'Eventual (index sau commit)': 'E', 'Strong': 'S', 'Eventual': 'E', 'At-most-once': 'AMO', '–': '–'}

C3_6 = [
    ("p", "[[bang_ap]] liệt kê mọi câu hỏi ứng dụng đặt cho các CSDL, lập **trước** khi thiết kế cấu trúc dữ liệu; Chương 4 "
          "ánh xạ từng dòng sang khóa Redis, collection và index MongoDB, mapping Elasticsearch hoặc bảng PostgreSQL. Độ trễ "
          "là mục tiêu ở tầng dữ liệu (p95). AP-36..AP-38 chỉ có trong script truy vấn nộp kèm, ứng dụng chưa có API cho "
          "chúng; chúng vẫn được giữ vì là truy vấn minh chứng trên GUI tool (Chương 5)."),
    ("table", "Mẫu truy cập dữ liệu (access patterns)", 3, [850, 2404, 950, 1500, 1000, 1000, 800],
     ["Mã", "Mẫu truy cập", "CSDL, loại", "Tham số đầu vào", "Tần suất", "Độ trễ mục tiêu", "NQ"],
     [[r[0], r[1], f"{AP_DB.get(r[2], r[2])}\n{r[3]}", r[4], r[5], r[6], AP_NQ[r[7]]] for r in AP_ROWS],
     "Chốt ngày 27/10/2026; cột cấu trúc và lệnh ở Chương 4", "bang_ap"),
    ("p", "*Chú giải.* PG = PostgreSQL, Mongo = MongoDB, ES = Elasticsearch. NQ = mức nhất quán: S = strong, E = eventual, "
          "AMO = at-most-once. (1) Một node, script Lua nguyên tử. (2) Cũ tối đa bằng TTL 45–60 s nếu lần xóa cache lỗi. "
          "(3) Đọc từ PostgreSQL. (4) Nguyên tử trên một document. (5) Bản chụp tại thời điểm dump. Độ trễ của AP-16 tính từ "
          "lúc PUBLISH tới trình duyệt; của AP-29, AP-31, AP-33 đo trên dữ liệu tổng hợp 100k. AP-12 chạy khi thiếu khóa hoặc "
          "quản trị bấm dựng lại; AP-34 chạy lúc khởi động và thử lại mỗi 15 s; AP-31 chạy khi Elasticsearch tắt hoặc lỗi."),
    ("p", "Đọc theo cột CSDL, bảng cho thấy lý do chọn từng hệ: các AP cần nhất quán mạnh (tiền, OTP, trạng thái hóa đơn) "
          "nằm ở PostgreSQL hoặc trong một script Lua nguyên tử của Redis; các AP đọc nhiều, chịu được dữ liệu cũ vài chục giây "
          "(thống kê, bảng xếp hạng) nằm ở Redis; các AP thống kê trên JSON của AI nằm ở MongoDB; các AP tìm kiếm văn bản nằm "
          "ở Elasticsearch và luôn có đường dự phòng PostgreSQL (AP-31)."),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.7 Yêu cầu giao diện
# --------------------------------------------------------------------------------------------------------------------

C3_7 = [
    ("p", "**Giao diện người dùng.** Đồ án mở rộng một ứng dụng đã có, nên thay cho wireframe, mục này dùng các màn hình "
          "thật. Ảnh của chúng được trình bày một lần ở mục 6.3 (cùng mã S-xx) để không lặp hình; [[bang_man_hinh]] nêu mỗi "
          "màn hình phục vụ yêu cầu nào."),
    ("table", "Màn hình chính và yêu cầu chức năng tương ứng", 3, [900, 3604, 1700, 2300],
     ["Ảnh", "Màn hình", "Nền tảng", "Yêu cầu"],
     [
         ["S-67", "Đăng nhập", "Ứng dụng di động", "FR-01"],
         ["S-68", "Đăng nhập quản trị, trang người dùng (cột vai trò)", "Web quản trị", "FR-01"],
         ["S-69", "Quên mật khẩu, nhập OTP 6 số", "Ứng dụng di động", "FR-02"],
         ["S-72", "Phản hồi OCR: danh sách lọc và 3 biểu đồ", "Web quản trị", "FR-11, FR-12"],
         ["S-74", "Sổ cái: tìm \"pho\" ra các dòng \"Phở\"", "Ứng dụng di động", "FR-08"],
         ["S-76", "Quét hóa đơn rồi sửa; document ocr_feedbacks mới", "Ứng dụng di động, Compass", "FR-05, FR-06"],
         ["S-77", "Dashboard quản trị: top 5 chi tiêu tháng", "Web quản trị", "FR-09, FR-10"],
         ["S-78", "Vận hành NoSQL: dựng lại chỉ mục và bảng xếp hạng", "Web quản trị", "FR-10, FR-14"],
         ["S-80", "Toast sự kiện realtime", "Web quản trị", "FR-16"],
         ["S-81", "Trang chủ thống kê và khóa cache tương ứng", "Ứng dụng di động, RedisInsight", "FR-07"],
     ], "Ảnh: mục 6.3", "bang_man_hinh"),
    ("p", "**Giao diện API.** [[bang_api]] là các endpoint REST và trang web có dùng NoSQL. API di động trả JSON và xác thực "
          "bằng JWT; trang quản trị dùng phiên đăng nhập; luồng sự kiện realtime dùng SSE."),
    ("table", "Endpoint liên quan NoSQL (gộp theo controller)", 3, [1200, 4300, 2104, 900],
     ["Phương thức", "Đường dẫn", "Vai trò; CSDL", "FR"],
     [
         ["POST\nPOST", "/api/auth/forgot-password\n/api/auth/reset-password", "Công khai; Redis (OTP), PostgreSQL", "FR-02"],
         ["POST\nPUT, DELETE\nGET", "/api/transactions/checkout\n/api/transactions/{id}\n/api/transactions/search", "USER; PostgreSQL → sau commit Redis, MongoDB, ES; tìm kiếm: ES hoặc PostgreSQL", "FR-03, FR-04, FR-05, FR-08"],
         ["GET\nGET", "/api/transactions/popular-vendors\n/api/transactions/app-dashboard", "USER; Redis cache, PostgreSQL khi trượt", "FR-07"],
         ["PUT\nPOST\nPOST", "/api/receipts/{id}\n/api/receipts/{id}/retry\n/api/receipts/feedback/{receiptId}", "USER (chủ); PostgreSQL → MongoDB, ES, Redis Pub/Sub", "FR-05, FR-06"],
         ["GET\nGET", "/api/admin/transactions/popular-vendors\n/api/admin/transactions/app-dashboard", "ADMIN; Redis cache, PostgreSQL", "FR-09"],
         ["GET\nGET\nGET\nPATCH\nDELETE", "/api/admin/ocr-logs\n/api/admin/ocr-feedbacks\n/api/admin/ocr-feedbacks/analytics\n/api/admin/ocr-feedbacks/{id}/resolve\n/api/admin/ocr-feedbacks/{id}", "ADMIN; MongoDB", "FR-11, FR-12, FR-13"],
         ["GET\nPOST", "/api/admin/leaderboard\n/api/admin/leaderboard/rebuild", "ADMIN; Redis ZSET, PostgreSQL", "FR-10"],
         ["POST\nGET", "/api/admin/search/reindex\n/api/admin/receipts/{id}/attempts", "ADMIN; ES, PostgreSQL, Pub/Sub; PostgreSQL (JSON thô AI)", "FR-14, FR-05"],
         ["GET\nGET\nPOST\nPOST", "/admin/dashboard\n/admin/nosql\n/admin/nosql/search/reindex\n/admin/nosql/leaderboard/rebuild", "ADMIN (web); Redis cache, ZSET; ES, PostgreSQL", "FR-09, FR-10, FR-14"],
         ["GET\nPOST\nPOST", "/admin/ocr-feedbacks\n/admin/ocr-feedbacks/{id}/resolve\n/admin/ocr-feedbacks/{id}/delete", "ADMIN (web); MongoDB", "FR-11, FR-12"],
         ["POST\nPOST\nPOST\nPOST", "/admin/backup/execute\n/admin/backup/restore\n/admin/backup/mongo/execute\n/admin/backup/mongo/restore", "ADMIN (web); PostgreSQL; MongoDB", "FR-15"],
         ["GET", "/admin/events", "ADMIN (web); Redis Pub/Sub → SSE", "FR-16"],
     ], "Nguồn: các lớp Controller của core-backend", "bang_api"),
    ("p", "**Giao diện phần cứng, phần mềm.**"),
    ("table", "Phần cứng và phần mềm", 3, [1900, 3804, 2800],
     ["Thành phần", "Phiên bản, cấu hình", "Ghi chú"],
     [
         ["PostgreSQL", "15 (image postgres:15-alpine, 15.19)", "Nguồn sự thật"],
         ["Redis", "8.10 (image redis:8.10-alpine); giới hạn 192 MB, maxmemory 128 MB, allkeys-lru", "Không persistence, có "
                                                                                                     "mật khẩu"],
         ["MongoDB", "6.0 (6.0.28); giới hạn 512 MB, WiredTiger cache 0,25 GB", "Database finance_nosql"],
         ["Elasticsearch", "8.11.4, một node, heap 512 MB, giới hạn 1 GB", "Profile search, bảo mật bật"],
         ["Kibana, Elasticvue", "Kibana 8.11.4 (profile tools); Elasticvue 1.16.0 (chỉ ở stack demo)", "Công cụ quản trị"],
         ["Backend, web quản trị", "Java 21, Spring Boot 3.2.5; giới hạn container 512 MB", "Image Java 21 JRE (eclipse-temurin)"],
         ["Ứng dụng di động", "Flutter, Dart SDK ≥ 3.10.8", "Android"],
         ["Triển khai", "Docker Compose, một mạng bridge, Caddy 2.8 làm proxy", "Một máy"],
     ], "Nguồn: docker-compose.yml, core-backend/pom.xml, mobile-app/pubspec.yaml", "bang_phan_mem"),
]

# --------------------------------------------------------------------------------------------------------------------
# 3.8 Ma trận truy vết
# --------------------------------------------------------------------------------------------------------------------

TRACE_ROWS = [
    ["FR-01", "AP-01", "PostgreSQL: users, revoked_tokens", "AP-01 chưa có TC đóng băng; phân quyền: TC-19, TC-31, TC-45"],
    ["FR-02", "AP-05, AP-06", "Redis: Hash theo email (khóa …:password-reset-otp:<email>), Lua", "TC-01, TC-02, TC-03, TC-04, TC-51"],
    ["FR-03", "AP-02, AP-10, AP-13, AP-32", "PostgreSQL: transactions (khóa ví, clientId duy nhất); Redis: DEL cache, Lua "
                                            "ZADD/ZREM; Elasticsearch: index transactions",
     "TC-08, TC-14, TC-15, TC-38, TC-52, TC-53"],
    ["FR-04", "AP-03, AP-10, AP-13, AP-32", "Như FR-03", "TC-39"],
    ["FR-05", "AP-04, AP-17", "PostgreSQL: receipts, receipt_processing_attempts; MongoDB: ocr_logs", "TC-23, TC-30"],
    ["FR-06", "AP-04, AP-18, AP-15", "PostgreSQL: receipts.version; MongoDB: ocr_feedbacks (receipt_field_uq); Redis: "
                                     "PUBLISH", "TC-20, TC-21, TC-22, TC-47, TC-48, TC-54"],
    ["FR-07", "AP-07, AP-09", "Redis: JSON user-dashboard, user-popular-vendors; PostgreSQL khi trượt",
     "TC-05, TC-06, TC-07, TC-10, TC-11, TC-55"],
    ["FR-08", "AP-29, AP-30, AP-31", "Elasticsearch: bool + multi_match; PostgreSQL: LOWER LIKE ESCAPE, nạp lại theo chủ",
     "TC-32 đến TC-37, TC-43, TC-44, TC-45"],
    ["FR-09", "AP-08, AP-09, AP-11", "Redis: admin-dashboard-summary, admin-statistics, ZSET", "TC-13"],
    ["FR-10", "AP-11, AP-12, AP-13, AP-14", "Redis: ZSET theo tháng (khóa …:leaderboard:spend:yyyy-MM); PostgreSQL: tổng chi",
     "TC-12, TC-13, TC-14, TC-16"],
    ["FR-11", "AP-19, AP-20, AP-21", "MongoDB: ocr_feedbacks, status_date_idx", "TC-24, TC-27, TC-28, TC-46"],
    ["FR-12", "AP-22, AP-23, AP-24, AP-25", "MongoDB: aggregation trên ocr_feedbacks, ocr_logs ($lookup)", "TC-25, TC-26"],
    ["FR-13", "AP-26", "MongoDB: ocr_logs, đọc theo trang", "Chưa có ca kiểm thử riêng"],
    ["FR-14", "AP-33, AP-34, AP-35", "Elasticsearch: index transactions tạo từ file mapping; PostgreSQL", "TC-41, TC-42"],
    ["FR-15", "AP-27, AP-28", "MongoDB: mongodump, mongorestore 2 collection; PostgreSQL: pg_dump",
     "TC-29, TC-31, TC-49; liên quan: TC-16, TC-50"],
    ["FR-16", "AP-15, AP-16", "Redis: kênh ledgermind:admin-events; SSE", "TC-17, TC-18, TC-19"],
    ["NFR", "NFR-08, NFR-10", "Elasticsearch lỗi khi index: chỉ log; rollback không xóa cache", "TC-09, TC-40"],
    ["Chỉ trong script", "AP-36, AP-37, AP-38", "Elasticsearch: terms, date_histogram; MongoDB: $lookup, $facet, index "
                                                "transactionId, score_date_idx", "Q-38..Q-40, Q-13, Q-14, Q-01, Q-02"],
]

C3_8 = [
    ("p", "[[bang_truy_vet]] nối mỗi yêu cầu chức năng tới mẫu truy cập, cấu trúc dữ liệu thực hiện nó (chi tiết ở Chương 4) "
          "và ca kiểm thử chứng minh nó (kết quả ở Chương 7). Cả 16 FR đều có mặt; chỉ FR-13 (API xem log OCR thô, ưu tiên "
          "thấp) chưa có ca kiểm thử riêng, và AP-01 của FR-01 chưa có TC đóng băng. Dòng NFR gom các TC chỉ kiểm yêu cầu phi chức năng. Ba AP chỉ có trong script được truy vết tới các truy vấn Q trên GUI tool."),
    ("table", "Ma trận truy vết FR → AP → cấu trúc → TC", 3, [900, 1700, 3604, 2300],
     ["FR", "AP", "CSDL / cấu trúc", "TC"], TRACE_ROWS, "FR, AP, TC chốt ngày 27/10/2026; kết quả TC ở Chương 7", "bang_truy_vet"),
]

HEADING_PLACEHOLDERS = {
    "ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS)": C3_0,
    "GIỚI THIỆU TÀI LIỆU SRS": C3_1,
    "MÔ TẢ TỔNG QUAN": C3_2,
    "YÊU CẦU CHỨC NĂNG": C3_3,
    "Mô hình hóa nghiệp vụ (Business Process Modeling)": C3_3_1,
    "Mô hình hóa chức năng (Functional Modeling)": C3_3_2,
    "YÊU CẦU PHI CHỨC NĂNG": C3_4,
    "YÊU CẦU DỮ LIỆU": C3_5,
    "MẪU TRUY CẬP DỮ LIỆU (ACCESS PATTERNS)": C3_6,
    "YÊU CẦU GIAO DIỆN": C3_7,
    "MA TRẬN TRUY VẾT YÊU CẦU": C3_8,
}
