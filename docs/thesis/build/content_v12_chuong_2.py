# Nội dung phiên K2 (01/11/2026): rà soát văn bản Chương 2 (Phân tích hệ thống) theo loi_phan_B.md.
# Sinh KhoaLuan_KLCN175_v12.docx từ v11 bằng builder.py. Chỉ sửa chính tả, dấu câu, câu văn và các câu đã lệch so với mã
# nguồn; không thêm hoặc bớt mục, hình, bảng, không đổi số bước của các bảng đặc tả (các sơ đồ và dòng thay thế tham chiếu
# số bước). Câu nào sửa theo mã nguồn thì ghi file trong chú thích. Thuật ngữ toàn quyển (tỉ lệ/tỷ lệ, module/mô-đun, tên
# màn hình, "Nguồn:" viết hoa ở chú thích) để K5.
SESSION_TAG = None
SECTIONS = {}


def _reorder(tag, cur, order, edits=None):
    """Đổi chỗ các đoạn trong cùng một ô bảng: mỗi đoạn cũ thành một dấu tạm duy nhất, rồi dấu tạm thành nội dung mới.

    cur: nội dung hiện có theo thứ tự hiện có; order[j] = chỉ số (trong cur) của đoạn sẽ đứng ở vị trí j;
    edits: {chỉ số trong cur: nội dung mới của đoạn đó}."""
    edits = edits or {}
    out = [(text, f"@@{tag}_{j}@@", 1) for j, text in enumerate(cur)]
    out += [(f"@@{tag}_{j}@@", edits.get(order[j], cur[order[j]]), 1) for j in range(len(cur))]
    return out


# ---- 18 đoạn dẫn lặp ở 2.2.2-2.2.7: rút gọn, giữ tham chiếu Hình (quy ước chung nằm ở 2.2.1) ----
_FLOWS = [
    ("Ghi chép thu chi", 2),
    ("Quét hóa đơn và đối soát", 5),
    ("Lập và theo dõi ngân sách", 8),
    ("Thống kê và báo cáo thói quen chi tiêu", 11),
    ("Quản trị hệ thống", 14),
    ("Duyệt hóa đơn AI", 17),
]
_INTRO_REPLACE = []
for _name, _n in _FLOWS:
    _INTRO_REPLACE.append((f"Hình 2.{_n} chia các hoạt động",
                           ("p", f"Hình 2.{_n} là sơ đồ hoạt động của quy trình “{_name}”.")))
    _INTRO_REPLACE.append((f"Hình 2.{_n + 1} trình bày dòng cơ bản",
                           ("p", f"Hình 2.{_n + 1} là sơ đồ tuần tự của dòng cơ bản.")))
    _INTRO_REPLACE.append((f"Hình 2.{_n + 2} thể hiện cùng dòng cơ bản",
                           ("p", f"Hình 2.{_n + 2} là sơ đồ cộng tác của dòng cơ bản, có số thông điệp trùng với Hình 2.{_n + 1}.")))

PARA_REPLACE = _INTRO_REPLACE + [
    # #1, #2 (P248): mục 2.1, bớt chuỗi câu "Mục ..." liền nhau
    ("Mục 2.2 mô hình hóa nghiệp vụ:",
     ("p", "Mục 2.2 mô hình hóa nghiệp vụ bằng sơ đồ use case (ca sử dụng) nghiệp vụ và sáu quy trình chính, mỗi quy trình gồm "
           "bảng đặc tả bằng văn bản, sơ đồ hoạt động, sơ đồ tuần tự và sơ đồ cộng tác. Mục 2.3 đặc tả các use case ở mức hệ "
           "thống, mục 2.4 xây dựng sơ đồ lớp mức phân tích. Mục 2.5 phân tích bài toán trích xuất bốn trường thông tin và "
           "kiến trúc của mô hình DONUT, còn mục 2.6 phân tích bài toán phân tích chi tiêu và phân khúc khách hàng. Các bước "
           "trong mục 2.2 mô tả đúng cách ứng dụng di động, Core Backend và AI Service đang xử lý, nên mỗi nhánh rẽ trên sơ đồ "
           "tương ứng một nhánh xử lý trong mã nguồn.")),
    # #3, #4, #5, #6 (P258): quy ước đọc ba loại sơ đồ nêu một lần ở 2.2.1; ba gạch đầu dòng ở INSERT_AFTER
    ("Các mục 2.2.2 đến 2.2.7 lần lượt",
     ("p", "Các mục 2.2.2 đến 2.2.7 lần lượt mô hình hóa sáu quy trình trên. Sơ đồ tuần tự và sơ đồ cộng tác chỉ vẽ dòng cơ bản "
           "để giữ số thông điệp ở mức đọc được; các dòng thay thế được thể hiện trên sơ đồ hoạt động. Hai loại sơ đồ này đều "
           "thuộc nhóm sơ đồ tương tác của UML: sơ đồ tuần tự nhấn mạnh thứ tự thông điệp theo thời gian, còn sơ đồ cộng tác "
           "(communication diagram trong UML 2) nhấn mạnh liên kết giữa các đối tượng [47]. Cả ba loại sơ đồ của sáu quy trình "
           "được đọc theo các quy ước sau.")),
    # #17 (P314)
    ("Quy trình này gồm hai phần.",
     ("p", "Quy trình này gồm hai phần. Phần thống kê do ứng dụng di động tính từ danh sách giao dịch của người dùng. Phần báo cáo "
           "thói quen chi tiêu do AI Service thực hiện: AI Service dựng chuỗi chi tiêu theo tuần, khai phá mẫu tuần tự có trọng "
           "số bằng thuật toán WCM-SPADE (module wcm_spade.py, dựa trên id-list dọc của SPADE [48]), sinh luật tuần tự từ "
           "id-list thô và tính các thói quen chi tiêu định kỳ. Ngoài ra, AI Service đưa ra gợi ý ngân sách dựa trên mục tiêu "
           "tiết kiệm. Bảng 2.5 đặc tả quy trình; cơ sở thuật toán nằm ở mục 2.6.")),
    # #30, #31 (P368): ba điểm chung thành ba gạch đầu dòng ngắn (INSERT_AFTER)
    ("Sáu quy trình trên cho thấy",
     ("p", "Sáu quy trình trên có ba điểm chung về cách hệ thống xử lý dữ liệu.")),
    # #90 (P511): teacher forcing in nghiêng
    ("Mô hình gốc được Kim và cộng sự",
     ("p", "Mô hình gốc được Kim và cộng sự tiền huấn luyện bằng nhiệm vụ đọc toàn bộ văn bản trong ảnh theo thứ tự đọc (mục "
           "1.5.3) [5]. Đề tài không tiền huấn luyện lại mà tinh chỉnh (fine-tune) từ trọng số "
           "naver-clova-ix/donut-base-finetuned-cord-v2, bản đã được tinh chỉnh trên tập hóa đơn CORD. Khi tinh chỉnh, mô hình "
           "được huấn luyện theo kiểu *teacher forcing*: tại mỗi vị trí, đầu vào của bộ giải mã là token đúng của nhãn ở vị trí "
           "trước, thay vì token mô hình tự sinh [5].")),
    # #116 (P549): ba định nghĩa thành ba mục danh sách (hai mục sau ở INSERT_AFTER)
    ("sup(A): số tuần có A",
     ("b1", "sup(A): số tuần có A trong một ngày.")),
    # #118 (P552): "interest" in nghiêng thay cho ngoặc kép
    ("Lift: confidence / (sup(B) / N).",
     ("b1", "Lift: confidence / (sup(B) / N). Đại lượng này tương ứng độ *interest* của Brin, Motwani và Silverstein [80] "
            "(thường gọi là lift): lớn hơn 1 là A và B phụ thuộc dương. Mức nền sup(B) / N tính cả tuần B xuất hiện trước A nên "
            "lift ở đây là ước lượng thận trọng.")),
    # #129 (P564): các bước tính thành danh sách (INSERT_AFTER); mã nguồn: ai-service/budget_advisor.py dòng 168-210
    ("Các bước tính:",
     ("p", "AI Service tính gợi ý ngân sách theo các bước sau.")),
    # #135, #137 (P573)
    ("Chương 2 đã phân tích hệ thống LedgerMind",
     ("p", "Chương 2 đã phân tích hệ thống LedgerMind theo UML [47]. Ở mức nghiệp vụ, sáu quy trình chính được mô tả bằng bảng "
           "đặc tả và ba loại sơ đồ: hoạt động, tuần tự và cộng tác. Ở mức hệ thống, 26 use case của người dùng, quản trị viên "
           "và tác nhân phụ AI Service được đặc tả đủ tám trường. Sơ đồ lớp mức phân tích xác định 15 lớp thực thể và quan hệ "
           "giữa chúng, trong đó giao dịch, hóa đơn và các lượt AI đọc hóa đơn là các lớp trung tâm.")),
    # #136 (P574): rút gọn, nêu đúng "Mục 2.5"
    ("Phần phân tích mô hình đã phát biểu",
     ("p", "Mục 2.5 phát biểu bài toán trích xuất bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST dưới dạng sinh chuỗi từ ảnh, "
           "chỉ ra ba khó khăn của hướng dựa trên OCR với hóa đơn tiếng Việt chụp bằng điện thoại, mô tả kiến trúc DONUT gồm bộ "
           "mã hóa Swin Transformer, bộ giải mã mBART và task token <s_seller> [5], [8], [10], rồi nêu hạn chế của mô hình cùng "
           "cách hệ thống giảm rủi ro bằng bước đối soát. Vấn đề tokenizer tiếng Việt của bản V3 và giải pháp mở rộng từ vựng "
           "Unigram ở bản V5 là cơ sở cho phần thiết kế mô hình AI. Mục 2.6 phân tích riêng bài toán phân tích chi tiêu, từ chuỗi "
           "theo tuần, mẫu tuần tự có trọng số WCM-SPADE, luật tuần tự và thói quen định kỳ đến gợi ý ngân sách và phân khúc "
           "RFM bảy nhóm.")),
]

INSERT_AFTER = [
    ("Các mục 2.2.2 đến 2.2.7 lần lượt", [
        ("b1", "**Sơ đồ hoạt động:** các hoạt động được chia theo làn (swimlane), mỗi làn là một bên tham gia, gồm người dùng "
               "hoặc quản trị viên và từng thành phần phần mềm. Các nút quyết định thể hiện những dòng thay thế đã nêu trong "
               "bảng đặc tả."),
        ("b1", "**Sơ đồ tuần tự:** dòng cơ bản được trình bày theo trình tự thời gian. Các thông điệp được đánh số liên tục, kể "
               "cả thông điệp trả về, để đối chiếu với sơ đồ cộng tác."),
        ("b1", "**Sơ đồ cộng tác:** cùng dòng cơ bản được vẽ dưới dạng liên kết giữa các đối tượng, với số thứ tự thông điệp "
               "trùng với sơ đồ tuần tự của quy trình đó. Mũi tên ↓ chỉ chiều từ đối tượng phía trên xuống đối tượng phía dưới "
               "của liên kết, mũi tên ↑ chỉ chiều ngược lại, còn nhãn gắn với vòng tự gọi là thông điệp mà đối tượng gửi cho "
               "chính nó."),
    ]),
    ("Sáu quy trình trên cho thấy", [
        ("b1", "Mọi thay đổi số dư ví đều đi qua Core Backend. Các thao tác tạo, sửa, xóa giao dịch và duyệt hóa đơn đều khóa "
               "bản ghi ví trước khi đọc số dư và từ chối thay đổi làm số dư âm. Nhờ vậy hai yêu cầu đồng thời không ghi đè "
               "lên nhau. Khi tạo giao dịch, mã clientId còn bảo đảm một giao dịch gửi lặp không làm trừ tiền hai lần."),
        ("b1", "Ứng dụng di động gọi trực tiếp AI Service cho các tác vụ đọc hóa đơn và phân tích. Kết quả chỉ được ghi vào cơ "
               "sở dữ liệu khi người dùng xác nhận; khi chưa gửi được, giao dịch nằm trong hàng đợi trên thiết bị cùng kết quả "
               "gốc của AI."),
        ("b1", "Các thao tác thay đổi dữ liệu quan trọng đều có bản ghi trong nhật ký hoạt động."),
        ("p", "Mục 2.3 dựa trên các quy trình này để xác định use case ở mức hệ thống."),
    ]),
    ("sup(A): số tuần có A", [
        ("b1", "sup(B): số tuần có B ở bất kỳ đâu trong tuần."),
        ("b1", "sup(A ⇒ B): số tuần có B ở một ngày sau lần đầu A xuất hiện trong tuần đó."),
    ]),
    ("Các bước tính:", [
        ("b1", "Chi tiêu trung bình mỗi tháng của từng nhóm bằng tổng chi chia số tháng."),
        ("b1", "Số cần góp mỗi tháng bằng max(mục tiêu − đã có, 0) / số tháng còn lại (hoặc giá trị needed_monthly nếu ứng "
               "dụng truyền vào)."),
        ("b1", "Thặng dư bằng thu nhập trung bình trừ chi trung bình."),
        ("b1", "Thiếu hụt bằng số cần góp trừ thặng dư."),
        ("p", "Nếu thiếu hụt không dương, người dùng đang đi đúng hướng và AI Service chỉ gợi ý giảm nhẹ 10% các mục tùy ý "
              "chiếm từ 15% chi tiêu trở lên. Nếu thiếu hụt dương, AI Service duyệt các nhóm theo thứ tự tùy ý, trung tính, "
              "thiết yếu và cắt từng mục theo hai giới hạn:"),
        ("b1", "Mỗi mục bị cắt không quá 30% mức trung bình của chính mục đó, riêng nhóm thiết yếu không quá 10%."),
        ("b1", "Phần cắt của một mục không vượt quá phần thiếu hụt còn lại nhân với tỷ trọng của mục đó trong nhóm đang duyệt."),
        ("p", "Việc duyệt dừng khi hết thiếu hụt. Nếu cắt hết mà vẫn thiếu, câu tóm tắt gợi ý tăng thu nhập hoặc giãn hạn. Chưa "
              "có khoản chi nào, hoặc chưa có tháng trọn vẹn nào có chi, thì AI Service trả mã 422 kèm câu giải thích cố định. "
              "Các tỷ lệ 30%, 10% và 15% là lựa chọn của đề tài."),
    ]),
]

# Dòng thay thế mới (đoạn trong ô bảng, cùng kiểu với đoạn đứng trước)
PARA_LINES_AFTER = [
    # #21: tách 10a thành 10a và 10b (10b cũ thành 10c ở TEXT_REPLACE)
    ("10a. Người dùng đổi khoảng thời gian",
     ["10b. Người dùng bấm nút làm mới trên thẻ phân tích: ứng dụng chạy lại bước 7–8."]),
    # #53: tách 6a và 6c của UC13
    ("6b. AI Service không phản hồi khi người dùng chủ động làm mới",
     ["6c. Người dùng đổi khoảng thời gian: chỉ biểu đồ được vẽ lại, phân tích không đổi."]),
    # #62: UC19 tách 3a và 3b (3b cũ thành 3c)
    ("3a. Hóa đơn đã hủy, ở trạng thái không thể duyệt",
     ["3b. Hóa đơn không gắn với giao dịch nào: Core Backend từ chối thao tác."]),
    # #57: UC23 tách 3b và 3d
    ("3c. Ứng dụng bị tắt giữa chừng",
     ["3d. Người dùng đăng xuất: vòng đọc dừng trước mục kế tiếp. Các mục còn lại chỉ được đọc tiếp khi chính người dùng đó "
      "đăng nhập lại."]),
    # #54: UC15 dòng thay thế 4c (đặt cuối, rồi sắp lại ở _reorder)
    ("2a. Người dùng kéo để làm mới: quay lại bước 2.",
     ["4c. Màn hình liên quan phụ thuộc loại thông báo: cảnh báo ngân sách mở màn hình Ngân sách; thông báo giao dịch hoặc "
      "hóa đơn mở bảng chi tiết của giao dịch liên quan trên Sổ giao dịch."]),
]

# Sắp lại các dòng thay thế theo thứ tự tăng dần (#40) và sửa nội dung của các dòng đó
_UC02 = ["2a. Người dùng chọn đăng nhập bằng Google hoặc Facebook: ứng dụng lấy mã xác thực từ nhà cung cấp và gửi kèm tên nhà cung cấp tới Core Backend. Core Backend xác minh mã với Google (kiểm tra cả đối tượng nhận mã) hoặc Facebook và lấy email; nếu email chưa có tài khoản thì tạo tài khoản ROLE_USER mới. Tiếp tục bước 4.",
         "2b. Quản trị viên đăng nhập trên trang /admin/login của Web Admin: Core Backend kiểm tra như bước 3, lưu phiên đăng nhập phía máy chủ và chuyển tới trang Tổng quan quản trị; tài khoản không có vai trò ROLE_ADMIN bị từ chối truy cập các trang /admin/**.",
         "3a. Sai email hoặc mật khẩu: Core Backend tăng bộ đếm sai của tài khoản và địa chỉ IP, ghi nhật ký và trả mã 401; sau 5 lần sai, tài khoản và địa chỉ IP bị tạm khóa đăng nhập 15 phút (mã 429). Quay lại bước 2.",
         "3b. Tài khoản bị quản trị viên khóa: Core Backend từ chối đăng nhập.",
         "2c. Xác minh mã mạng xã hội thất bại hoặc nhà cung cấp không trả về email: Core Backend trả mã 401, ứng dụng báo lỗi.",
         "5a. Trong khi dùng ứng dụng, mã truy cập hết hạn: ứng dụng tự đổi mã làm mới lấy cặp mã mới (mã làm mới cũ bị thu hồi); nếu bị từ chối, phiên kết thúc và người dùng phải đăng nhập lại."]
_UC03 = ["2a. Người dùng không xác nhận: use case kết thúc, phiên giữ nguyên.",
         "3a. Không gọi được Core Backend: ứng dụng vẫn xóa phiên trên thiết bị và quay về màn hình Đăng nhập.",
         "1a. Quản trị viên chọn đăng xuất trên Web Admin: Core Backend hủy phiên phía máy chủ và chuyển về trang /admin/login."]
_UC09 = ["2a. Tổng tiền không hợp lệ: ứng dụng báo lỗi, quay lại bước 1.",
         "3a. Tải ảnh thất bại: ứng dụng hỏi “Lưu không kèm ảnh” hoặc “Để sau”; chọn “Để sau” thì quay lại bước 1.",
         "4a. Không gửi được lên máy chủ: ứng dụng báo giao dịch đã lưu trên thiết bị và sẽ gửi lại (UC07); biểu mẫu đóng lại.",
         "5a. Dữ liệu không hợp lệ hoặc số dư không đủ: Core Backend từ chối, ứng dụng báo lưu thất bại và giữ biểu mẫu.",
         "5b. Kết quả AI không có tổng tiền hợp lệ: hồ sơ hóa đơn được lưu trạng thái FAILED với mã lý do AI_NO_TOTAL hoặc AI_UNREADABLE.",
         "5c. Người dùng đã có giao dịch cùng loại, cùng số tiền, cùng phút và cùng người bán: Core Backend trả 409, ứng dụng hỏi xem bản đã lưu hay vẫn lưu (UC26).",
         "1a. Người dùng quay lại mà không lưu: không có dữ liệu nào được ghi."]
_UC14 = ["2a. Người dùng chạm vào một mục tiêu và nhập số tiền đã tiết kiệm mới: Core Backend kiểm tra mục tiêu thuộc người dùng, cập nhật và ghi nhật ký SAVING_UPDATED.",
         "2b. Người dùng vuốt hoặc nhấn giữ một mục tiêu để xóa: Core Backend kiểm tra quyền sở hữu, xóa và ghi nhật ký; ứng dụng báo đã xóa.",
         "3a. Tên trống hoặc số tiền mục tiêu không hợp lệ: ứng dụng không gửi yêu cầu, hộp thoại vẫn mở.",
         "2c. Mục tiêu không tồn tại (mã 400) hoặc thuộc người khác (mã 403): Core Backend từ chối."]
_UC15 = ["4a. Đánh dấu đã đọc thất bại: ứng dụng hiển thị lại thông báo ở trạng thái chưa đọc.",
         "4b. Người dùng chọn đánh dấu tất cả đã đọc: Core Backend cập nhật mọi thông báo chưa đọc của người dùng và trả về số thông báo đã cập nhật.",
         "3a. Tải trang kế tiếp thất bại: ứng dụng hiện nút thử lại, không tự tải lại khi cuộn.",
         "2a. Người dùng kéo để làm mới: quay lại bước 2.",
         "4c. Màn hình liên quan phụ thuộc loại thông báo: cảnh báo ngân sách mở màn hình Ngân sách; thông báo giao dịch hoặc hóa đơn mở bảng chi tiết của giao dịch liên quan trên Sổ giao dịch."]
_UC16 = ["3a. Lưu lựa chọn thất bại: lựa chọn vẫn có hiệu lực trong lần chạy hiện tại, ứng dụng báo không lưu được.",
         "1a. Lần mở ứng dụng sau: ứng dụng đọc lựa chọn đã lưu trước khi hiển thị màn hình đầu tiên."]
_UC20 = ["2a. Quản trị viên chọn gỡ khóa đăng nhập cho một email hoặc địa chỉ IP: Core Backend xóa bộ đếm đăng nhập sai tương ứng và ghi nhật ký.",
         "3a. Bộ lọc không hợp lệ: Core Backend báo lỗi, không trả kết quả.",
         "1a. Ứng dụng khác gọi /api/admin/audit-logs bằng mã JWT của tài khoản ROLE_ADMIN: Core Backend trả cùng dữ liệu dạng JSON."]

REORDER_REPLACE = (
    # UC02: #39 (audience) và #40 (2a, 2b, 2c, 3a, 3b, 5a). Mã nguồn: core-backend/.../Service/SocialAuthService.java dòng 64 và 79
    _reorder("uc02", _UC02, [0, 1, 4, 2, 3, 5], {
        0: "2a. Người dùng chọn đăng nhập bằng Google hoặc Facebook: ứng dụng lấy mã xác thực từ nhà cung cấp và gửi kèm tên nhà cung cấp tới Core Backend. Core Backend xác minh mã với Google hoặc Facebook (kiểm tra mã được cấp cho đúng ứng dụng, tức audience) và lấy email; nếu email chưa có tài khoản thì tạo tài khoản ROLE_USER mới. Tiếp tục bước 4."})
    + _reorder("uc03", _UC03, [2, 0, 1])
    # UC09: #49 (5c) và #40 mở rộng: 1a đứng đầu
    + _reorder("uc09", _UC09, [6, 0, 1, 2, 3, 4, 5], {
        5: "5c. Người dùng đã có giao dịch cùng loại, cùng số tiền, cùng phút và cùng người bán: Core Backend trả 409, ứng dụng hỏi người dùng muốn xem bản đã lưu hay vẫn lưu hóa đơn này (UC26)."})
    + _reorder("uc14", _UC14, [0, 1, 3, 2])
    # UC15: dòng 4c mới đứng cuối, rồi 2a, 3a, 4a, 4b, 4c
    + _reorder("uc15", _UC15, [3, 2, 0, 1, 4])
    + _reorder("uc16", _UC16, [1, 0])
    + _reorder("uc20", _UC20, [2, 0, 1])
)

TEXT_REPLACE = REORDER_REPLACE + [
    # ================= 2.2.1 =================
    # #32: một tên cho AI Service là "tác nhân phụ" (UML: secondary actor)
    ("vai trò tác nhân hệ thống của AI Service được xét ở mục 2.3.", "vai trò tác nhân phụ của AI Service được xét ở mục 2.3.", 1),

    # ================= 2.2.2 (Bảng 2.2) =================
    # #9: bước 4 có năm hành động, tách thành hai câu (không thêm bước: Hình 2.2-2.4 và dòng 4a, 6a tham chiếu số bước)
    ("đặt phương thức thanh toán là ví, gán cho giao dịch một mã định danh phía máy khách (clientId, dạng UUID), lưu bản ghi vào SQLite",
     "đặt phương thức thanh toán là ví và gán cho giao dịch một mã định danh phía máy khách (clientId, dạng UUID). Sau đó ứng dụng lưu bản ghi vào SQLite", 1),
    # #8
    ("5. Core Backend kiểm tra dữ liệu: số tiền lớn hơn 0, nơi giao dịch, phương thức thanh toán và ngày giao dịch không được để trống.",
     "5. Core Backend kiểm tra số tiền lớn hơn 0 và các trường nơi giao dịch, phương thức thanh toán, ngày giao dịch không được để trống.", 1),
    # #47: mã lỗi gửi lại nêu ở UC07 (app_repository.dart dòng 86-90)
    ("4a. Thiết bị mất mạng, máy chủ lỗi (mã 5xx) hoặc trả về một trong các mã 401, 408, 429: bản ghi",
     "4a. Thiết bị mất mạng hoặc máy chủ chưa xử lý được yêu cầu (các mã lỗi nêu ở UC07, Bảng 2.16): bản ghi", 1),

    # ================= 2.2.3 (Bảng 2.3) =================
    # #10
    ("bốn trường Seller, Address, Timestamp, Total Cost", "bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST", 1),
    # #11
    ("ngày giờ trên hóa đơn; chuỗi thời gian được thử lần lượt theo một danh sách định dạng ngày giờ.",
     "ngày giờ trên hóa đơn. Chuỗi thời gian được thử lần lượt với một danh sách định dạng ngày giờ.", 1),
    # #12: mã nguồn core-backend/.../Service/ReceiptProcessingService.java dòng 158-164: giá trị người dùng đã nhập luôn thắng,
    # AI chỉ điền chỗ còn trống
    ("(đã đọc được tổng tiền); thời gian và địa chỉ do AI đọc được dùng làm ngày và nơi giao dịch, thay cho giá trị gửi từ biểu mẫu.",
     "(đã đọc được tổng tiền). Ngày và nơi giao dịch lấy từ giá trị người dùng đã xác nhận trên biểu mẫu; thời gian và địa chỉ do AI đọc chỉ được dùng để điền chỗ còn trống.", 1),
    # #13
    ("9. Core Backend kiểm tra ngân sách (quy trình 2.2.4), ghi nhật ký hoạt động; sau khi giao dịch cơ sở dữ liệu hoàn tất, kết quả gốc của AI được ghi vào MongoDB [37] để phục vụ phân tích sau này.",
     "9. Core Backend kiểm tra ngân sách (quy trình 2.2.4) và ghi nhật ký hoạt động. Sau khi giao dịch cơ sở dữ liệu hoàn tất, kết quả gốc của AI được ghi vào MongoDB [37] để phân tích về sau.", 1),
    # #14
    ("6b. Tải ảnh thất bại: ứng dụng hỏi có lưu giao dịch không kèm ảnh hay không.",
     "6b. Tải ảnh thất bại: ứng dụng hỏi người dùng có muốn lưu giao dịch không kèm ảnh hay không.", 1),

    # ================= 2.2.4 (Bảng 2.4) =================
    # #16: tách câu trong bước 5 (không thêm bước: Hình 2.8-2.10 và dòng 5a, 10a tham chiếu số bước)
    ("5. Core Backend xác định danh mục (theo mã, hoặc theo tên người dùng gõ khi chọn “Khác”: dùng lại danh mục cùng tên, chưa có thì tạo mới) và kiểm tra người dùng chưa có ngân sách cùng danh mục, cùng loại kỳ và cùng ngày bắt đầu, sau đó lưu ngân sách và ghi nhật ký hoạt động.",
     "5. Core Backend xác định danh mục. Danh mục được xác định theo mã; khi người dùng chọn “Khác” và gõ tên thì Core Backend dùng lại danh mục cùng tên, chưa có thì tạo mới. Sau đó Core Backend kiểm tra người dùng chưa có ngân sách cùng danh mục, cùng loại kỳ và cùng ngày bắt đầu, rồi lưu ngân sách và ghi nhật ký hoạt động.", 1),
    # #15
    ("Nếu giao dịch đưa tỉ lệ từ dưới lên bằng hoặc trên 80%, hệ thống tạo thông báo loại BUDGET_WARNING; nếu đạt hoặc vượt 100%, tạo thông báo BUDGET_EXCEEDED.",
     "Nếu giao dịch đưa tỉ lệ từ dưới 80% lên 80% trở lên, hệ thống tạo thông báo BUDGET_WARNING; nếu tỉ lệ đạt hoặc vượt 100%, hệ thống tạo thông báo BUDGET_EXCEEDED.", 1),

    # ================= 2.2.5 (Bảng 2.5) =================
    # #20: ứng dụng chỉ gửi khoản chi, không gồm khoản thu và khoản góp tiết kiệm (mobile-app/lib/core/utils/spending_history.dart dòng 22-37)
    ("7. Ứng dụng gửi các khoản chi của 26 tuần gần nhất (danh mục, số tiền, ngày, loại thu/chi), không phụ thuộc khoảng thời gian đang chọn trên màn hình, tới AI Service.",
     "7. Ứng dụng gửi tới AI Service các khoản chi của 26 tuần gần nhất (danh mục, số tiền, ngày; không gồm khoản thu và khoản góp tiết kiệm), không phụ thuộc khoảng thời gian đang chọn trên màn hình.", 1),
    # #18
    ("sinh luật tuần tự và tính thói quen định kỳ, cơ cấu danh mục; mỗi mẫu gồm các itemset kèm số tuần chứa mẫu, trọng số và support có trọng số, mỗi luật kèm support, độ tin cậy Laplace và lift.",
     "sinh luật tuần tự rồi tính thói quen định kỳ và cơ cấu danh mục. Định dạng các đầu ra được nêu ở Bảng 2.39.", 1),
    # #19, #127
    ("9. Song song với bước 7, ứng dụng chọn mục tiêu tiết kiệm gần hạn nhất và gửi thu chi của 7 tháng lịch gần nhất (AI Service dùng tối đa 6 tháng trọn vẹn trong đó) cùng số tiền mục tiêu, số tiền đã tiết kiệm và số tháng còn lại tới AI Service; AI Service trả về xu hướng chi tiêu, thống kê theo nhóm, các gợi ý ngân sách và đoạn tóm tắt.",
     "9. Song song với bước 7, ứng dụng chọn mục tiêu tiết kiệm gần hạn nhất, rồi gửi tới AI Service thu chi của 7 tháng dương lịch gần nhất cùng số tiền mục tiêu, số tiền đã tiết kiệm và số tháng còn lại. AI Service trả về xu hướng chi tiêu, thống kê theo nhóm, các gợi ý ngân sách và đoạn tóm tắt (cách chọn tháng nêu ở mục 2.6.6).", 1),
    # #21
    ("phân tích không đổi. Người dùng bấm nút làm mới trên thẻ phân tích: ứng dụng chạy lại bước 7–8.", "phân tích không đổi.", 1),
    ("10b. Người dùng kéo để làm mới tab AI", "10c. Người dùng kéo để làm mới tab AI", 1),
    # #22
    ("chỉ gồm thao tác lọc và vẽ biểu đồ trên thiết bị nên được mô tả trong Bảng 2.5 mà không vẽ lại trên các sơ đồ.",
     "chỉ gồm thao tác lọc và vẽ biểu đồ trên thiết bị, nên được mô tả trong Bảng 2.5 và không vẽ lại trên các sơ đồ.", 1),

    # ================= 2.2.6 (Bảng 2.6) =================
    # #43: gạch ngang giải thích thành dấu phẩy (Bảng 2.6 và UC21)
    ("(Recency – Frequency – Monetary) [49]", "(Recency, Frequency, Monetary) [49]", 2),
    # #23
    ("2. Core Backend kiểm tra tài khoản và địa chỉ IP không bị khóa đăng nhập và mật khẩu đúng, rồi ghi nhật ký đăng nhập thành công.",
     "2. Core Backend kiểm tra tài khoản và địa chỉ IP không bị khóa đăng nhập, kiểm tra mật khẩu đúng, rồi ghi nhật ký đăng nhập thành công.", 1),
    # #63 (kiểm tra): trang Tổng quan có ô "số người dùng có số dư thấp" (AdminController.java dòng 122, templates/admin/dashboard.html dòng 52-53)
    ("tổng giá trị giao dịch, số người dùng, số giao dịch trong tháng, người chi tiêu nhiều nhất, biểu đồ sáu tháng",
     "tổng giá trị giao dịch, số người dùng, số người dùng có số dư thấp, số giao dịch trong tháng, người chi tiêu nhiều nhất, biểu đồ sáu tháng", 1),
    # #24: phần RFM đã có ở mục 2.6.7
    (", trong đó AI Service chấm điểm từng chỉ số theo ngũ phân vị rồi xếp người dùng vào bảy nhóm bằng luật ưu tiên.",
     ". Cách chấm điểm và xếp người dùng vào bảy nhóm được trình bày ở mục 2.6.7.", 1),
    # #25
    ("nhật ký đăng nhập đã được ghi ở bước 2, nhưng Core Backend từ chối truy cập các trang quản trị.",
     "Core Backend đã ghi nhật ký đăng nhập ở bước 2 nhưng từ chối truy cập các trang quản trị.", 1),

    # ================= 2.2.7 (Bảng 2.7) =================
    # #26: chỉ có mã lý do REJECTED_BY_ADMIN, quản trị viên không nhập lý do (ReceiptProcessingService.java dòng 413-428)
    ("còn từ chối đánh dấu hóa đơn là lỗi kèm lý do do quản trị viên từ chối.",
     "còn từ chối thì đánh dấu hóa đơn là lỗi với mã lý do REJECTED_BY_ADMIN.", 1),
    # #27
    ("4. Kết quả đúng, quản trị viên chọn duyệt.", "4. Nếu kết quả đúng, quản trị viên chọn duyệt.", 1),
    # #28, #29
    ("4a. Kết quả AI sai, quản trị viên chọn từ chối: hóa đơn đã hủy không thể từ chối; nếu hóa đơn chưa ở trạng thái FAILED, Core Backend chuyển sang FAILED với mã lý do REJECTED_BY_ADMIN và ghi nhật ký; số dư ví không thay đổi.",
     "4a. Kết quả AI sai, quản trị viên chọn từ chối: nếu hóa đơn chưa bị hủy và chưa ở trạng thái FAILED, Core Backend chuyển sang FAILED với mã lý do REJECTED_BY_ADMIN và ghi nhật ký. Hóa đơn đã bị hủy không thể từ chối. Số dư ví không thay đổi.", 1),

    # ================= 2.3 =================
    # #32, #33 (P372)
    ("một tác nhân hệ thống (Bảng 2.8)", "một tác nhân phụ (Bảng 2.8)", 1),
    ("(dịch vụ FastAPI chạy trong container riêng) nhận yêu cầu và trả kết quả, nên đóng vai tác nhân phụ",
     "(dịch vụ FastAPI chạy trong container riêng). Dịch vụ này nhận yêu cầu và trả kết quả, nên đóng vai tác nhân phụ", 1),
    ("Tác nhân hệ thống", "Tác nhân phụ", 1),
    # #34 (P377)
    ("Hình 2.20 là phân hệ người dùng trên ứng dụng di động với 16 use case; Hình 2.21 là phân hệ quản trị trên Web Admin với 6 use case riêng, cộng thêm hai use case Đăng nhập và Đăng xuất dùng chung với phân hệ người dùng; Hình 2.22",
     "Hình 2.20 là phân hệ người dùng trên ứng dụng di động với 16 use case. Hình 2.21 là phân hệ quản trị trên Web Admin với 6 use case riêng, cộng thêm hai use case Đăng nhập và Đăng xuất dùng chung với phân hệ người dùng. Hình 2.22", 1),
    # #36: bỏ câu lặp ý với P377
    ("Bốn use case bổ sung xuất phát từ góp ý khi nhóm dùng thử ứng dụng. UC23 Quét nhiều hóa đơn", "UC23 Quét nhiều hóa đơn", 1),
    # #35
    ("tại nút Góp tiền trên từng mục tiêu, và tạo một khoản chi theo đường xử lý của UC06 (quan hệ này ghi trong bảng đặc tả để sơ đồ không bị rối).",
     "tại nút Góp tiền trên từng mục tiêu. UC25 còn «include» UC06 vì khoản góp được ghi thành một khoản chi theo đường xử lý của UC06; quan hệ này chỉ ghi trong bảng đặc tả để sơ đồ không bị rối.", 1),
    # #48 (Bảng 2.9): thống nhất tên nút quét với UC08
    ("Bảng quét (Quét nhiều, Chọn nhiều ảnh); banner hàng chờ", "Nút quét trên thanh điều hướng (Quét nhiều, Chọn nhiều ảnh); banner hàng chờ", 1),
    # #50 (P454)
    ("(UC02, dòng 2b)", "(UC02, dòng thay thế 2b)", 1),

    # ---- UC01 (Bảng 2.10) ----
    # #37: ứng dụng đặt tên đăng nhập bằng email (mobile-app/lib/services/remote_api_helper.dart dòng 394)
    ("3. Ứng dụng kiểm tra đủ bốn trường và mật khẩu đạt chính sách mật khẩu, rồi gửi yêu cầu đăng ký tới Core Backend.",
     "3. Ứng dụng kiểm tra đủ bốn trường và mật khẩu đạt chính sách mật khẩu, rồi gửi yêu cầu đăng ký tới Core Backend, trong đó tên đăng nhập được đặt bằng email.", 1),

    # ---- UC04 (Bảng 2.13) ----
    # #41
    ("Người dùng đã đăng nhập (UC02) và thiết bị có kết nối mạng. Tài khoản có mật khẩu.",
     "Người dùng đã đăng nhập (UC02), thiết bị có kết nối mạng và tài khoản có mật khẩu.", 1),
    # #42 (không thêm bước: dòng thay thế 5a tham chiếu bước)
    ("trong cùng một câu lệnh cập nhật, thu hồi mã truy cập đang dùng, ghi nhật ký AUTH_PASSWORD_CHANGED và cấp cặp mã mới.",
     "trong cùng một câu lệnh cập nhật. Sau đó Core Backend thu hồi mã truy cập đang dùng, ghi nhật ký AUTH_PASSWORD_CHANGED và cấp cặp mã mới.", 1),

    # ---- UC05 (Bảng 2.14) ----
    # #43
    ("nhận mã OTP (One-Time Password – mật khẩu dùng một lần) gồm 6 chữ số", "nhận mã OTP (One-Time Password, tức mật khẩu dùng một lần) gồm 6 chữ số", 1),
    # #44
    ("5b. Mã hết hạn hoặc không tồn tại: Core Backend yêu cầu gửi lại mã mới; quay lại bước 4a.",
     "5b. Mã hết hạn hoặc không tồn tại: Core Backend yêu cầu người dùng gửi lại mã mới; quay lại bước 4a.", 1),

    # ---- UC06 (Bảng 2.15) ----
    # #45
    ("Thao tác thêm không cần kết nối mạng; xem danh sách mới nhất, sửa và xóa cần kết nối.",
     "Thao tác thêm không cần kết nối mạng; các thao tác xem danh sách mới nhất, sửa và xóa cần kết nối.", 1),
    # #46
    ("kiểm tra ngân sách, ghi nhật ký TRANSACTION_CREATED.", "kiểm tra ngân sách và ghi nhật ký TRANSACTION_CREATED.", 1),

    # ---- UC07 (Bảng 2.16) ----
    # #47: các mã lỗi nêu ở đây một lần; điều kiện gửi lại tách thành hai câu
    ("2. Khi ứng dụng được mở hoặc quay lại từ nền, khi người dùng kéo để làm mới Sổ giao dịch hoặc chạm lại tab Sổ giao dịch, ứng dụng gửi lại lần lượt mọi bản ghi chưa đồng bộ; chỉ một lượt gửi chạy tại một thời điểm.",
     "2. Ứng dụng gửi lại lần lượt mọi bản ghi chưa đồng bộ; chỉ một lượt gửi chạy tại một thời điểm. Việc gửi lại được kích hoạt khi ứng dụng được mở hoặc quay lại từ nền, khi người dùng kéo để làm mới Sổ giao dịch hoặc khi người dùng chạm lại tab Sổ giao dịch.", 1),

    # ---- UC08/UC09: nút quét giữ nguyên ở UC08 ----
    # #12 (UC09 bước 5, mã nguồn như Bảng 2.3)
    ("5. Core Backend lưu giao dịch như UC06 và tạo hồ sơ hóa đơn trạng thái COMPLETED_RAW; thời gian và địa chỉ AI đọc được dùng làm ngày và nơi giao dịch.",
     "5. Core Backend lưu giao dịch như UC06 và tạo hồ sơ hóa đơn trạng thái COMPLETED_RAW. Ngày và nơi giao dịch lấy từ giá trị người dùng đã xác nhận; thời gian và địa chỉ AI đọc được chỉ điền vào chỗ còn trống.", 1),

    # ---- UC10 (Bảng 2.19) ----
    # #50
    ("hoặc theo tên ở dòng 2c)", "hoặc theo tên ở dòng thay thế 2c)", 1),
    # #51
    ("ứng dụng gửi tên thay cho mã danh mục; Core Backend dùng lại danh mục cùng tên không phân biệt hoa thường, chưa có thì tạo danh mục chi mới với tên đó.",
     "ứng dụng gửi tên thay cho mã danh mục. Core Backend dùng lại danh mục cùng tên (không phân biệt hoa thường), chưa có thì tạo danh mục chi mới với tên đó.", 1),

    # ---- UC11 (Bảng 2.20) ----
    # (mới) thống nhất cách viết mốc với Bảng 2.4 (#15)
    ("3. Nếu tỉ lệ vượt từ dưới lên mốc 80%, Core Backend tạo thông báo BUDGET_WARNING; nếu đạt hoặc vượt 100%, tạo thông báo BUDGET_EXCEEDED.",
     "3. Nếu tỉ lệ đi từ dưới 80% lên 80% trở lên, Core Backend tạo thông báo BUDGET_WARNING; nếu tỉ lệ đạt hoặc vượt 100%, Core Backend tạo thông báo BUDGET_EXCEEDED.", 1),

    # ---- UC13 (Bảng 2.22) ----
    # #52 (không thêm bước: dòng thay thế tham chiếu bước 3-4)
    ("4. AI Service dựng chuỗi theo tuần, khai phá các mẫu tuần tự có trọng số dựa trên cách biểu diễn id-list của SPADE [48] (mỗi mẫu tối đa 4 item, các itemset cùng ngày), sinh luật tuần tự mà vế trái",
     "4. AI Service dựng chuỗi theo tuần, rồi khai phá các mẫu tuần tự có trọng số dựa trên cách biểu diễn id-list của SPADE [48] (mỗi mẫu tối đa 4 item, các itemset cùng ngày). Sau đó AI Service sinh luật tuần tự mà vế trái", 1),
    # #127
    ("gửi thu chi của 7 tháng lịch gần nhất cùng mục tiêu tiết kiệm gần hạn nhất", "gửi thu chi của 7 tháng dương lịch gần nhất cùng mục tiêu tiết kiệm gần hạn nhất", 1),
    # #53
    ("ứng dụng chạy lại bước 3–4; đổi khoảng thời gian chỉ vẽ lại biểu đồ.", "ứng dụng chạy lại bước 3–4.", 1),

    # ---- UC15 (Bảng 2.24) ----
    # #54
    ("gửi yêu cầu đánh dấu đã đọc tới Core Backend rồi mở màn hình Ngân sách nếu là cảnh báo ngân sách, hoặc bảng chi tiết của giao dịch liên quan trên Sổ giao dịch nếu là thông báo giao dịch hay hóa đơn.",
     "gửi yêu cầu đánh dấu đã đọc tới Core Backend rồi mở màn hình liên quan.", 1),

    # ---- UC23 (Bảng 2.26) ----
    # #55 (P440)
    ("gắn với mã người dùng đang đăng nhập, nên đóng ứng dụng rồi mở lại thì việc đọc vẫn tiếp tục,",
     "gắn với mã người dùng đang đăng nhập. Vì vậy, đóng ứng dụng rồi mở lại thì việc đọc vẫn tiếp tục,", 1),
    # #48: cùng cách gọi nút quét như UC08
    ("1. Người dùng bấm nút Quét AI và chọn “Quét nhiều”", "1. Người dùng chọn nút quét trên thanh điều hướng, rồi chọn “Quét nhiều”", 1),
    # #56: nhãn trạng thái tiếng Việt khi mới xuất hiện
    ("ghi mỗi ảnh thành một mục trạng thái queued của người dùng hiện tại", "ghi mỗi ảnh thành một mục có trạng thái queued (Đang chờ) của người dùng hiện tại", 1),
    ("Ứng dụng lấy mục cũ nhất, đổi sang reading và gửi ảnh", "Ứng dụng lấy mục cũ nhất, đổi sang reading (Đang đọc) và gửi ảnh", 1),
    # khối normalized: ai-service/ai_service.py dòng 195-203
    ("AI Service trả bốn trường kèm khối normalized; ứng dụng lưu kết quả, đổi mục sang ready rồi",
     "AI Service trả bốn trường kèm khối normalized (giá trị đã chuẩn hóa và cờ hợp lệ của từng trường); ứng dụng lưu kết quả, đổi mục sang ready (Sẵn sàng) rồi", 1),
    ("mục chuyển failed với lý do tương ứng", "mục chuyển failed (Lỗi) với lý do tương ứng", 1),
    # #57
    ("3b. AI Service trả 401 không làm mới được hoặc 403: mục đang đọc trở về queued và vòng đọc dừng. Người dùng đăng xuất: vòng đọc dừng trước mục kế tiếp. Các mục còn lại chỉ được đọc tiếp khi chính người dùng đó đăng nhập lại.",
     "3b. AI Service trả 401 và việc làm mới mã không thành công, hoặc trả 403: mục đang đọc trở về queued và vòng đọc dừng.", 1),

    # ---- UC24 (Bảng 2.27) ----
    # #58
    ("không có trường nào bị cờ sai, rồi báo “Đã lưu x, trùng y, chưa lưu z”. Mục bị coi là trùng (UC26), mục tải ảnh lỗi hoặc bị từ chối được giữ lại; mục đã vào hàng đợi gửi khi mất mạng (UC07) được tính là đã lưu.",
     "không có trường nào bị đánh dấu không hợp lệ, rồi báo “Đã lưu x, trùng y, chưa lưu z”. Mục bị coi là trùng (UC26), mục tải ảnh lỗi và mục bị từ chối được giữ lại. Mục đã vào hàng đợi gửi khi mất mạng (UC07) được tính là đã lưu.", 1),
    ("mục trở về queued và được đọc lại theo UC23.", "mục trở về trạng thái queued (Đang chờ) và được đọc lại theo UC23.", 1),

    # ---- UC26 (Bảng 2.29) ----
    # #59
    ("vì hai lần mua giống hệt nhau trong ngày là chuyện bình thường.", "vì hai lần mua giống hệt nhau trong ngày là việc thường gặp.", 1),

    # ---- UC17 (Bảng 2.30) ----
    # #38, #61: UserCreateDto dùng @StrongPassword (Dto/UserCreateDto.java; Security/StrongPassword.java dòng 35-40)
    ("2. Quản trị viên chọn thêm người dùng, nhập tên đăng nhập, email, số điện thoại, mật khẩu (tối thiểu 6 ký tự) và vai trò.",
     "2. Quản trị viên chọn thêm người dùng, nhập tên đăng nhập, email, số điện thoại, mật khẩu (cùng quy tắc với đăng ký: dài 8–72 ký tự, có ít nhất một chữ cái và một chữ số) và vai trò.", 1),

    # ---- UC19 (Bảng 2.32) ----
    # #62, #29: tách 3a và 3b như Bảng 2.7 (5a, 5b); "đã bị hủy" thống nhất
    ("3a. Hóa đơn đã hủy, ở trạng thái không thể duyệt, không có tổng tiền hợp lệ hoặc không gắn với giao dịch: Core Backend từ chối thao tác.",
     "3a. Hóa đơn đã bị hủy, đang ở trạng thái không thể duyệt hoặc không có tổng tiền hợp lệ: Core Backend từ chối thao tác.", 1),
    ("3b. Hóa đơn vừa được cập nhật bởi yêu cầu khác", "3c. Hóa đơn vừa được cập nhật bởi yêu cầu khác", 1),

    # ---- UC20 (Bảng 2.33) ----
    # (mới)
    ("Quản trị viên xem và lọc nhật ký các thao tác bảo mật và dữ liệu, và gỡ tạm khóa đăng nhập cho một tài khoản hoặc địa chỉ IP.",
     "Quản trị viên xem và lọc nhật ký các thao tác bảo mật và dữ liệu, đồng thời gỡ tạm khóa đăng nhập cho một tài khoản hoặc địa chỉ IP.", 1),
    # #50
    ("(trừ dòng 2a)", "(trừ dòng thay thế 2a)", 1),

    # ---- UC21 (Bảng 2.34) ----
    # #63: tách ý bộ nhớ đệm thành câu riêng
    ("biểu đồ số giao dịch sáu tháng, tỉ lệ trạng thái hóa đơn và số người dùng theo từng phân khúc; các số liệu tổng hợp được đọc qua bộ nhớ đệm Redis [36] có thời hạn 45–60 giây.",
     "biểu đồ số giao dịch sáu tháng, tỉ lệ trạng thái hóa đơn và số người dùng theo từng phân khúc. Các số liệu tổng hợp được đọc qua bộ nhớ đệm Redis [36] có thời hạn 45–60 giây.", 1),
    # #64
    ("rồi gán một trong bảy nhóm theo luật: CHAMPIONS, LOYAL, NEW, NEED_ATTENTION, AT_RISK, HIBERNATING hoặc LOST.",
     "rồi gán một trong bảy nhóm theo luật ở Bảng 2.41.", 1),
    # #50
    ("sau dòng 3–6, mỗi người dùng", "sau các bước 3 đến 6, mỗi người dùng", 1),

    # ================= 2.4 =================
    # #66 (P473)
    ("Hai mươi sáu use case trên (UC01–UC26) phủ toàn bộ chức năng mà ứng dụng di động và Web Admin đang cung cấp.",
     "Hai mươi sáu use case trên (UC01–UC26) phủ các chức năng chính mà ứng dụng di động và Web Admin đang cung cấp. Sao lưu và khôi phục cơ sở dữ liệu, duyệt hoặc xóa đánh giá ứng dụng, nạp và rút tiền qua cổng thanh toán là các chức năng phụ trợ, chưa có use case riêng và chỉ được nêu ở Bảng 2.6 và Bảng 2.36.", 1),
    # #67 (P476)
    ("(người dùng, giao dịch, hóa đơn, ngân sách, thông báo…)", "(người dùng, giao dịch, hóa đơn, ngân sách, thông báo, v.v.)", 1),
    # #68 (P477)
    ("bảng bỏ qua khóa chính, khóa ngoại và các cột phục vụ kỹ thuật như số phiên bản dùng cho khóa lạc quan hay thời điểm tạo, sửa chung cho mọi bảng; các cột này được trình bày ở phần thiết kế cơ sở dữ liệu trong Chương 3.",
     "bảng bỏ qua khóa chính, khóa ngoại và các cột kỹ thuật chung cho mọi bảng (số phiên bản của khóa lạc quan, thời điểm tạo và sửa). Các cột này được trình bày ở phần thiết kế cơ sở dữ liệu trong Chương 3.", 1),
    # #71: liệt kê giá trị (Entity/ReceiptStatus.java dòng 22-42; Entity/NotificationType.java dòng 15-21)
    ("status (8 trạng thái)", "status (PENDING, PROCESSING, COMPLETED_RAW, EDITED, FAILED, WAITING_FOR_REVIEW, APPROVED hoặc CANCELED)", 1),
    ("type (4 loại)", "type (BUDGET_WARNING, BUDGET_EXCEEDED, TRANSACTION_ALERT hoặc RECEIPT_PROCESSED)", 1),
    # #69, #70 (P481)
    ("Một vài lựa chọn mô hình hóa cần nêu rõ.", "Một số lựa chọn mô hình hóa như sau.", 1),
    ("là thuộc tính logic isExpense", "là thuộc tính kiểu logic (boolean) isExpense", 1),
    # #72 (P486)
    ("chỉ lưu mã của giao dịch, ngân sách hoặc hóa đơn liên quan, không giữ liên kết trực tiếp tới các lớp đó, nên sơ đồ không vẽ thêm các quan hệ này.",
     "chỉ lưu mã của giao dịch, ngân sách hoặc hóa đơn liên quan. Thông báo không giữ liên kết trực tiếp tới các lớp đó, nên sơ đồ không vẽ thêm các quan hệ này.", 1),
    # #73 (P489)
    ("chưa có quan hệ lưu trữ nào gắn gói với người dùng; mã bị thu hồi chỉ được lưu dưới dạng giá trị băm",
     "chưa có quan hệ lưu trữ nào gắn gói với người dùng. Mã bị thu hồi chỉ được lưu dưới dạng giá trị băm", 1),

    # ================= 2.5 =================
    # #77, #78 (P497); mô tả total_cost_number theo ai-service/receipt_postprocess.py dòng 210-224 và ai_service.py dòng 198-202
    ("có khi kèm phần thập phân .00.", "có khi kèm phần thập phân “.00”.", 1),
    ("được thực hiện ở bước hậu xử lý; ví dụ, AI Service hiện tách số lớn nhất trong chuỗi tổng tiền thành trường phụ total_cost_number trước khi trả kết quả cho Core Backend.",
     "được thực hiện ở bước hậu xử lý. Ví dụ, AI Service tách số tiền trong chuỗi tổng tiền thành trường phụ total_cost_number trước khi trả kết quả cho Core Backend (mục 3.9.3).", 1),
    # #80, #82 (P500)
    ("chụp bằng điện thoại chứ không được scan.", "chụp bằng điện thoại chứ không được quét bằng máy quét.", 1),
    ("Mỗi bước bổ sung là một mô-đun riêng phải chọn tham số và có thể hỏng độc lập.",
     "Mỗi bước bổ sung là một mô-đun riêng, phải chọn tham số và có thể lỗi độc lập.", 1),
    # #83 (P501)
    ("ở bước sau không sửa được những lỗi này, còn mô hình bố cục như LayoutLM nhận văn bản và hộp bao do OCR trả về làm đầu vào [18], [19], nên cũng kế thừa chúng [5].",
     "ở bước sau không sửa được những lỗi này. Mô hình bố cục như LayoutLM nhận văn bản và hộp bao do OCR trả về làm đầu vào [18], [19], nên cũng kế thừa các lỗi đó [5].", 1),
    # #81 (P502)
    ("Thứ ba, chi phí gán nhãn và bảo trì.", "Thứ ba, chi phí gán nhãn và bảo trì cao.", 1),
    # #84, #85 (P503)
    ("Hệ thống giảm rủi ro này ở mức nghiệp vụ: kết quả AI luôn được đưa lên form đối soát",
     "Hệ thống giảm các rủi ro này ở mức nghiệp vụ: kết quả AI luôn được đưa lên biểu mẫu đối soát", 1),
    # #86 (P505)
    ("với cấu hình của bản V3, bản AI Service phục vụ trước khi chuyển sang V5 (mục 4.5.1), đọc từ tệp config.json của mô hình.",
     "với cấu hình của bản V3 (bản AI Service phục vụ trước khi chuyển sang V5; bản V5 đang phục vụ nêu ở mục 4.5.1), lấy từ tệp config.json của mô hình.", 1),
    # #87, #88 (P509)
    ("kích thước cửa sổ 10 [5]; tệp cấu hình của mô hình V3 có đúng các giá trị này,",
     "kích thước cửa sổ 10 × 10 patch [5]. Tệp cấu hình của mô hình V3 có đúng các giá trị này,", 1),
    ("Với ảnh đầu vào 1280 × 960, lưới patch", "Với ảnh đầu vào 1280 × 960 pixel, lưới patch", 1),
    # #89 (P510)
    ("DONUT chỉ dùng phần giải mã, gồm 4 lớp, khởi tạo từ trọng số của BART đa ngôn ngữ mBART [5], [10]; tệp cấu hình V3 ghi",
     "DONUT chỉ dùng phần giải mã, khởi tạo từ trọng số của BART đa ngôn ngữ mBART [5], [10]. Tệp cấu hình V3 ghi", 1),
    # #92, #93 (P516)
    ("chuyển được chuỗi trên một – một thành đối tượng JSON", "chuyển được chuỗi trên sang đối tượng JSON theo quan hệ một-một", 1),
    ("Mười thẻ của nhiệm vụ (một cặp task token và bốn cặp thẻ trường)",
     "Mười thẻ của nhiệm vụ (năm cặp thẻ mở và đóng: một cặp task token và bốn cặp thẻ trường)", 1),
    # #94 (P518)
    ("Mô hình không bao giờ sinh lại được ký tự đã thành <unk>.", "Mô hình không thể sinh ra lại ký tự đã bị mã hóa thành <unk>.", 1),
    # #95 (P519)
    ("Cách này gây ra lỗi khoảng trắng. Added token được tách ra khỏi câu trước khi SentencePiece chạy,",
     "Cách này gây ra lỗi khoảng trắng, vì added token được tách ra khỏi câu trước khi SentencePiece chạy,", 1),
    # #96 (P520)
    ("được dời ra sau cho khỏi trùng, rồi mới thêm mười thẻ của nhiệm vụ.",
     "được dời về phía sau để không trùng với mã của các piece mới, rồi mới thêm mười thẻ của nhiệm vụ.", 1),
    # #98 (P523)
    (", đối chiếu ai-service/model_config.py (mã huấn luyện cũ) và ai-service/Version5/model_config.py",
     ", dựa trên việc đối chiếu ai-service/model_config.py (mã huấn luyện cũ) và ai-service/Version5/model_config.py", 1),

    # ================= 2.6 =================
    # #99, #100 (P526)
    ("các chức năng này không dùng mạng nơ-ron mà dùng thuật toán khai phá dữ liệu và luật thống kê đơn giản, cài đặt bằng Python, không dùng thư viện học máy.",
     "các chức năng này dùng thuật toán khai phá dữ liệu và luật thống kê đơn giản thay cho mạng nơ-ron, cài đặt thuần bằng Python mà không dùng thư viện học máy.", 1),
    ("là lựa chọn thiết kế của đề tài, trừ chỗ có trích dẫn tài liệu; nhóm nói rõ điều này để không gán cho tài liệu những giá trị mà tài liệu không đưa ra.",
     "là lựa chọn thiết kế của đề tài, không phải giá trị lấy từ tài liệu, trừ chỗ có trích dẫn.", 1),
    # #101 (P528)
    ("Cùng với chúng, hệ thống có hai chức năng riêng:", "Ngoài bốn đầu ra này, AI Service có hai chức năng riêng:", 1),
    # #103 (P532)
    ("số tiền không quá 10¹²; đầu vào vi phạm", "số tiền không quá 10¹² đồng; đầu vào vi phạm", 1),
    # #104 (P535)
    ("cửa sổ 26 tuần cho tối đa 26 chuỗi, trong khi cùng khoảng đó (khoảng sáu tháng) chỉ cho khoảng sáu chuỗi nếu mỗi tháng là một chuỗi,",
     "cửa sổ 26 tuần (khoảng sáu tháng) cho tối đa 26 chuỗi, trong khi cùng khoảng thời gian đó chỉ cho sáu chuỗi nếu mỗi tháng là một chuỗi,", 1),
    # #106, #107 (P536); mã nguồn ai-service/spending_data.py dòng 124-141
    ("Cửa sổ 26 tuần tính từ thứ Hai của tuần chứa khoản chi muộn nhất còn lại, lùi 25 tuần, nên neo vào dữ liệu chứ không vào đồng hồ máy chủ.",
     "Cửa sổ 26 tuần kết thúc ở khoản chi muộn nhất còn lại và bắt đầu từ thứ Hai của tuần cách tuần chứa khoản chi đó 25 tuần, nên cửa sổ gắn với dữ liệu chứ không gắn với đồng hồ máy chủ.", 1),
    ("Tuần không có khoản chi nào không thành chuỗi: N, số chuỗi, là số tuần có ghi chép, vì tuần trống có thể chỉ là tuần người dùng chưa nhập chứ chưa chắc là tuần không chi.",
     "Tuần không có khoản chi nào thì không tạo chuỗi, nên N, số chuỗi, bằng số tuần có ghi chép. Lý do là tuần trống có thể chỉ là tuần người dùng chưa nhập chứ chưa chắc là tuần không chi.", 1),
    # #108 (P538); mã nguồn ai-service/wcm_spade.py dòng 176 và 265
    ("Trong đề tài, CMAP giữ cả cặp a đứng trước chính a và so với ngưỡng support thô.",
     "Trong đề tài, CMAP cũng ghi nhận cặp a đứng trước chính a, và các số đếm được so với ngưỡng support thô.", 1),
    # #109 (P539)
    ("Các công thức dưới đây là cách làm kiểu WSpan do đề tài chọn,", "Các công thức dưới đây theo hướng WSpan do đề tài lựa chọn,", 1),
    # #111 (P544)
    ("Ví dụ minh họa trọng số: ba danh mục có tổng chi 600 nghìn, 300 nghìn và 100 nghìn đồng cho w = 3 × 0,6 = 1,8; 0,9 và 0,3, trung bình bằng 1.",
     "Ví dụ minh họa trọng số: ba danh mục có tổng chi lần lượt 600 nghìn, 300 nghìn và 100 nghìn đồng, tức m = 3 và tổng chi là 1 triệu đồng. Trọng số của chúng là w = 3 × 0,6 = 1,8, w = 3 × 0,3 = 0,9 và w = 3 × 0,1 = 0,3, trung bình bằng 1.", 1),
    # #112, #113 (P545)
    ("⌈min_sup × N / maxW⌉); đây là cận trên, nên việc tỉa không làm mất mẫu hợp lệ.",
     "⌈min_sup × N / maxW⌉). Ngưỡng này được suy ra từ cận trên của wsup(P), nên việc tỉa không làm mất mẫu hợp lệ.", 1),
    ("Đây là hậu lọc theo tinh thần khai phá mẫu đóng của BIDE [78], không phải thuật toán BIDE, và chỉ so sánh trong tập mẫu đã đạt support có trọng số.",
     "Đây là bước hậu lọc theo tinh thần khai phá mẫu đóng của BIDE [78], không phải thuật toán BIDE. Bước này chỉ so sánh trong tập mẫu đã đạt support có trọng số.", 1),
    # #114 (P546)
    ("khi DFS bị cắt ở giới hạn này trong lúc còn ứng viên đạt ngưỡng,", "khi phép duyệt DFS dừng vì chạm giới hạn này mà vẫn còn ứng viên đạt ngưỡng,", 1),
    # #115 (P548)
    ("có B; cách hiểu luật tuần tự kèm độ tin cậy theo [79].", "có B. Luật tuần tự kèm độ tin cậy được hiểu theo [79].", 1),
    # #117 (P551)
    ("trong CN2 [81]; dạng (k + 1) / (n + 2) là trường hợp hai lớp do đề tài chọn, và nó kéo luật có ít bằng chứng về phía 0,5.",
     "trong CN2 [81]. Dạng (k + 1) / (n + 2) là trường hợp hai lớp do đề tài chọn, và ước lượng này kéo luật có ít bằng chứng về phía 0,5.", 1),
    # #119, #120 (P553)
    ("là số k nhỏ nhất thỏa (k + 1) / (4 + 2) ≥ 0,6.", "là số k nhỏ nhất thỏa mãn (k + 1) / (4 + 2) ≥ 0,6.", 1),
    ("độ tin cậy Laplace của A′ ⇒ B không nhỏ hơn của A ⇒ B; phép so sánh được thực hiện với mọi ứng viên đã qua các ngưỡng trên.",
     "độ tin cậy Laplace của A′ ⇒ B không nhỏ hơn độ tin cậy Laplace của luật A ⇒ B. Phép so sánh được thực hiện với mọi ứng viên đã qua các ngưỡng trên.", 1),
    # #121 (P554)
    ("Cũng vì vậy luật có thể chứa A và B nhiều item mà mẫu tương ứng không nằm trong danh sách mẫu.",
     "Vì vậy, một luật có thể có A và B gồm nhiều item mà mẫu tương ứng không nằm trong danh sách mẫu.", 1),
    # #122 (P555) và #123 (Bảng 2.40)
    ("Ở kịch bản thứ nhất A xuất hiện ở 16 tuần, B ở 15 tuần và có 12 tuần B đứng sau A; trọng số các danh mục bằng nhau nên min_sup × N = 0,25 × 26 = 6,5 và raw_bound = 7, mẫu A rồi B (support thô 12) được giữ.",
     "Ở kịch bản thứ nhất, trọng số các danh mục bằng nhau nên min_sup × N = 0,25 × 26 = 6,5 và raw_bound = 7, nên mẫu A rồi B (support thô 12) được giữ.", 1),
    ("lift bằng 1,0 nên luật bị loại", "lift bằng 1,00 nên luật bị loại", 1),
    ("8 / 16 = 0,5", "8 / 16 = 0,50", 1),
    ("13 / 18 ≈ 0,7222", "13 / 18 ≈ 0,72", 1),
    ("9 / 18 = 0,5", "9 / 18 = 0,50", 1),
    ("0,75 / (15 / 26) = 1,3", "0,75 / (15 / 26) = 1,30", 1),
    ("0,5 / (13 / 26) = 1,0", "0,5 / (13 / 26) = 1,00", 1),
    # #124, #125 (P560)
    ("Với mỗi danh mục, các ngày khác nhau có chi cho số lần chi; các khoảng cách (tính bằng ngày) giữa hai ngày liên tiếp cho trung bình μ và độ lệch chuẩn tổng thể σ.",
     "Với mỗi danh mục, nhóm lấy các ngày khác nhau có chi; số ngày đó là số lần chi. Khoảng cách giữa hai ngày liên tiếp (tính bằng ngày) có trung bình μ và độ lệch chuẩn tổng thể σ.", 1),
    ("Ngưỡng 3 lần theo quy tắc của Plaid cho luồng giao dịch định kỳ trưởng thành [85]; ngưỡng CV 0,5 là lựa chọn của đề tài, còn khái niệm mẫu xuất hiện định kỳ có nền trong khai phá mẫu định kỳ [83], [84] mà đề tài dùng bản đơn giản hơn nhiều.",
     "Ngưỡng 3 lần lấy theo quy tắc của Plaid cho luồng giao dịch định kỳ trưởng thành [85]. Ngưỡng CV 0,5 do đề tài chọn. Khái niệm mẫu xuất hiện định kỳ có nền tảng từ khai phá mẫu định kỳ [83], [84], nhưng đề tài dùng bản đơn giản hơn nhiều.", 1),
    # #126 (P561) và (mới) "cho μ ≈ 7,33"
    ("ứng dụng hiển thị nó là “khoảng” và dùng câu khác khi ngày ấy đã qua.",
     "ứng dụng hiển thị ngày này kèm từ “khoảng” và đổi câu hiển thị khi ngày đó đã qua.", 1),
    ("cách nhau 7, 7 và 8 ngày cho μ ≈ 7,33, σ ≈ 0,47 và CV ≈ 0,06,", "cách nhau 7, 7 và 8 ngày thì μ ≈ 7,33, σ ≈ 0,47 và CV ≈ 0,06,", 1),
    # #127, #128 (P563); danh mục theo ai-service/budget_advisor.py dòng 16-20
    ("gửi lịch sử 7 tháng lịch để AI Service", "gửi lịch sử 7 tháng dương lịch để AI Service", 1),
    ("thiết yếu (10 danh mục như Ăn uống, Nhà ở, Điện nước, Sức khỏe, Giáo dục), tùy ý (Mua sắm, Giải trí, Du lịch, Hiếu hỉ)",
     "thiết yếu (10 danh mục: Ăn uống, Siêu thị & Chợ, Di chuyển, Nhà ở, Điện nước, Internet & Điện thoại, Sức khỏe, Giáo dục, Gia đình & Con cái, Bảo hiểm), tùy ý (4 danh mục: Mua sắm, Giải trí, Du lịch, Hiếu hỉ)", 1),
    # #131 (P566)
    ("[88]; cách chấm điểm bằng ngũ phân vị dưới đây là lựa chọn của đề tài, vì ngũ phân vị là cách chấm phổ biến trong thực hành RFM.",
     "[88]. Đề tài chọn chấm điểm bằng ngũ phân vị, cách làm phổ biến trong thực hành RFM.", 1),
    # #132, #133 (P567)
    ("equal là số người có giá trị bằng nhau và n là số người được chấm", "equal là số người có giá trị bằng nhau (kể cả chính người đó) và n là số người được chấm", 1),
    ("với mã rfm “000” và không tham gia chấm điểm để khỏi kéo lệch điểm của những người còn lại.",
     "với mã RFM “000” và không tham gia chấm điểm, để không làm lệch điểm của những người còn lại.", 1),
    # #134 (P568)
    ("rút gọn từ các bảng phân nhóm RFM phổ biến trong thực hành; đề tài không dùng thuật toán gom cụm K-Means.",
     "rút gọn từ các bảng phân nhóm RFM phổ biến trong thực hành. Đề tài không dùng thuật toán gom cụm K-Means.", 1),
]
