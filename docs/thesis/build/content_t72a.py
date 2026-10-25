# Nội dung phiên T7.2a: Chương 2, mục 2.1 và 2.2 (use case nghiệp vụ + sáu quy trình).
# Mỗi bước trong các quy trình đã đối chiếu với mã nguồn ngày 21/10/2026 (xem ghi chú cuối file).
# Trích dẫn: docs/thesis/references.md ([47] UML 2.5.1 thêm ở phiên này).
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = "T7.2a"
SRC = "nguồn: nhóm thực hiện"
W2 = [2000, 6504]
HDR = ["Thành phần", "Nội dung"]


def spec(caption, rows):
    return ("table", caption, "2", W2, HDR, rows, "Nguồn: nhóm thực hiện")


def figs(name, title, n0, w_act=15.0, w_seq=16.0, w_col=12.0):
    """Ba phần sơ đồ của một quy trình; n0 là số của hình hoạt động trong Chương 2."""
    return [
        ("h4", "Sơ đồ hoạt động"),
        ("p", f"Hình 2.{n0} chia các hoạt động của quy trình “{title}” theo làn (swimlane) của từng bên tham gia; "
              "các nút quyết định thể hiện những dòng thay thế đã nêu trong bảng đặc tả."),
        ("fig", f"Sơ đồ hoạt động của quy trình “{title}”", "2", PNG + f"ch2_{name}_hoat_dong.png", w_act, SRC, None),
        ("h4", "Sơ đồ tuần tự"),
        ("p", f"Hình 2.{n0 + 1} trình bày dòng cơ bản theo trình tự thời gian. Các thông điệp được đánh số liên tục, "
              "kể cả thông điệp trả về, để đối chiếu với sơ đồ cộng tác ở hình kế tiếp."),
        ("fig", f"Sơ đồ tuần tự của quy trình “{title}”", "2", PNG + f"ch2_{name}_tuan_tu.png", w_seq, SRC, None),
        ("h4", "Sơ đồ cộng tác"),
        ("p", f"Hình 2.{n0 + 2} thể hiện cùng dòng cơ bản dưới dạng liên kết giữa các đối tượng. Số thứ tự của mỗi "
              f"thông điệp trùng với Hình 2.{n0 + 1}; mũi tên ↓ chỉ chiều từ đối tượng phía trên xuống đối tượng phía dưới "
              "của liên kết, ↑ chỉ chiều ngược lại, nhãn trên vòng lặp là thông điệp đối tượng gửi cho chính nó."),
        ("fig", f"Sơ đồ cộng tác của quy trình “{title}”", "2", PNG + f"ch2_{name}_cong_tac.png", w_col, SRC, None),
    ]


INTRO = [
    ("p", "Chương 1 đã xác định người dùng mục tiêu, hạn chế của quy trình ghi chép thủ công và hướng trích xuất thông tin "
          "hóa đơn bằng DONUT [5]. Chương 2 chuyển các kết quả khảo sát đó thành mô hình phân tích của hệ thống LedgerMind "
          "theo ngôn ngữ mô hình hóa thống nhất UML (Unified Modeling Language) phiên bản 2.5.1 [47]."),
    ("p", "Mục 2.2 mô hình hóa nghiệp vụ: sơ đồ use case (ca sử dụng) nghiệp vụ và sáu quy trình chính, mỗi quy trình gồm "
          "bảng đặc tả bằng văn bản, sơ đồ hoạt động, sơ đồ tuần tự và sơ đồ cộng tác. Mục 2.3 đặc tả các use case ở mức "
          "hệ thống. Mục 2.4 xây dựng sơ đồ lớp mức phân tích. Mục 2.5 phân tích bài toán trích xuất bốn trường thông tin "
          "và kiến trúc của mô hình DONUT. Các bước trong mục 2.2 được mô tả theo đúng cách các thành phần ứng dụng di động, "
          "Core Backend và AI Service đang xử lý, nên mỗi nhánh rẽ trên sơ đồ ứng với một nhánh xử lý có trong mã nguồn."),
]

# "GIỚI THIỆU" trùng tên giữa các chương; builder lấy tiêu đề gần nhất làm khóa và dòng giữ chỗ
# [T7.2a] dưới "GIỚI THIỆU" chỉ có ở Chương 2, nên khóa này không nhầm với mục 1.1.
SECTIONS = {
    "GIỚI THIỆU": INTRO,
    # ------------------------------------------------------------------ 2.2.1
    "Sơ đồ use case nghiệp vụ": [
        ("p", "Ở mức nghiệp vụ, hệ thống phục vụ hai tác nhân. **Người dùng** là cá nhân dùng ứng dụng di động để ghi chép "
              "thu chi, quét hóa đơn, lập ngân sách và xem báo cáo. **Quản trị viên** dùng Web Admin (trang quản trị chạy trên trình duyệt) để vận hành hệ thống và "
              "kiểm tra kết quả đọc hóa đơn của AI. AI Service không được vẽ thành tác nhân ở mức này vì nó là một thành phần "
              "bên trong hệ thống; vai trò tác nhân hệ thống của AI Service được xét ở mục 2.3."),
        ("p", "Theo UML, use case mô tả một chuỗi hành động mà hệ thống thực hiện để mang lại kết quả có giá trị cho tác nhân "
              "[47]. Hình 2.1 là sơ đồ use case nghiệp vụ gồm sáu quy trình. Quan hệ «include» từ “Quét hóa đơn và đối soát” tới "
              "“Ghi chép thu chi” thể hiện việc mỗi hóa đơn được xác nhận đều được lưu thành một giao dịch theo cách ghi chép "
              "thông thường. Bảng 2.1 tóm tắt mục đích của từng quy trình."),
        ("fig", "Sơ đồ use case nghiệp vụ", "2", PNG + "ch2_uc_nghiep_vu.png", 12.5, SRC, None),
        ("table", "Danh sách use case nghiệp vụ", "2", [600, 2500, 1500, 3904],
         ["STT", "Use case nghiệp vụ", "Tác nhân", "Mục đích"],
         [
             ["1", "Ghi chép thu chi", "Người dùng", "Ghi nhận một khoản thu hoặc chi và cập nhật số dư ví, kể cả khi thiết bị mất kết nối mạng."],
             ["2", "Quét hóa đơn và đối soát", "Người dùng", "Đọc bốn trường của hóa đơn bằng DONUT, cho người dùng đối chiếu rồi lưu thành giao dịch kèm hóa đơn."],
             ["3", "Lập và theo dõi ngân sách", "Người dùng", "Đặt hạn mức chi theo tuần hoặc tháng và nhận cảnh báo khi chi tiêu chạm mốc 80% và 100%."],
             ["4", "Thống kê và báo cáo thói quen chi tiêu", "Người dùng", "Tổng hợp thu chi, vẽ biểu đồ và tìm các mẫu chi tiêu lặp lại để gợi ý ngân sách."],
             ["5", "Quản trị hệ thống", "Quản trị viên", "Quản lý tài khoản, danh mục, gói dịch vụ, đánh giá; xem nhật ký và số liệu toàn hệ thống."],
             ["6", "Duyệt hóa đơn AI", "Quản trị viên", "Kiểm tra kết quả AI đọc trên ảnh gốc, duyệt để đối soát số tiền giao dịch hoặc từ chối hóa đơn."],
         ],
         "Nguồn: nhóm thực hiện"),
        ("p", "Các mục 2.2.2 đến 2.2.7 lần lượt mô hình hóa sáu quy trình trên. Sơ đồ hoạt động có làn riêng cho người dùng "
              "hoặc quản trị viên và cho từng thành phần phần mềm tham gia. Sơ đồ tuần tự và sơ đồ cộng tác chỉ vẽ dòng cơ "
              "bản để giữ số thông điệp ở mức đọc được; các dòng thay thế được thể hiện trên sơ đồ hoạt động. Hai loại sơ đồ "
              "sau đều là sơ đồ tương tác của UML: sơ đồ tuần tự nhấn mạnh thứ tự thông điệp theo thời gian, còn sơ đồ cộng tác "
              "(communication diagram trong UML 2) nhấn mạnh liên kết giữa các đối tượng [47]."),
    ],
    # ------------------------------------------------------------------ 2.2.2
    "Mô hình hóa quy trình ghi chép thu chi": [
        ("p", "Ghi chép thu chi là quy trình được dùng nhiều nhất và là nền cho ba quy trình còn lại của người dùng: hóa đơn "
              "sau khi đối soát được lưu thành giao dịch, cảnh báo ngân sách được tính sau mỗi khoản chi, và báo cáo được "
              "lập từ danh sách giao dịch. Bảng 2.2 đặc tả quy trình bằng văn bản."),
        ("h4", "Đặc tả bằng văn bản"),
        spec("Đặc tả quy trình nghiệp vụ ghi chép thu chi", [
            ["Use case nghiệp vụ", "Ghi chép thu chi"],
            ["Tác nhân", "Người dùng"],
            ["Mô tả", "Người dùng ghi một khoản thu hoặc chi trên ứng dụng di động. Giao dịch được lưu tạm trên thiết bị trước, "
                      "sau đó gửi lên Core Backend; Core Backend cập nhật số dư ví và kiểm tra ngân sách. Quy trình kết thúc khi "
                      "giao dịch đã được máy chủ ghi nhận hoặc bị từ chối."],
            ["Dòng cơ bản",
             "1. Người dùng mở chức năng thêm giao dịch.\n"
             "2. Ứng dụng tải danh sách danh mục thu chi từ Core Backend.\n"
             "3. Người dùng chọn loại thu hoặc chi, nhập số tiền, chọn danh mục, ngày giao dịch và nhập ghi chú (không bắt buộc).\n"
             "4. Ứng dụng lấy ghi chú làm nơi giao dịch (dùng giá trị mặc định khi bỏ trống), đặt phương thức thanh toán là ví, gán cho giao dịch một mã định danh phía máy khách (clientId, dạng UUID), lưu bản ghi vào SQLite (cơ sở dữ liệu nhúng trên thiết bị) với trạng thái chờ đồng bộ và gửi giao dịch lên Core Backend.\n"
             "5. Core Backend kiểm tra dữ liệu: số tiền lớn hơn 0, nơi giao dịch, phương thức thanh toán và ngày giao dịch không được để trống.\n"
             "6. Vì yêu cầu có clientId, Core Backend khóa bản ghi ví của người dùng trước khi đọc số dư, sau đó trừ số tiền khỏi số dư nếu là khoản chi hoặc cộng vào nếu là khoản thu, rồi lưu giao dịch.\n"
             "7. Với khoản chi, Core Backend kiểm tra các ngân sách liên quan (quy trình 2.2.4) và ghi nhật ký hoạt động.\n"
             "8. Ứng dụng đánh dấu bản ghi cục bộ là đã đồng bộ, thông báo thành công và cập nhật Sổ giao dịch. Quy trình kết thúc."],
            ["Dòng thay thế",
             "4a. Thiết bị mất mạng, máy chủ lỗi (mã 5xx) hoặc trả về một trong các mã 401, 408, 429: bản ghi chuyển sang trạng thái lỗi đồng bộ và vẫn hiển thị trong Sổ giao dịch kèm cảnh báo. Ứng dụng gửi lại khi được mở lại, khi người dùng kéo để làm mới Sổ giao dịch hoặc khi người dùng chọn gửi lại; quy trình quay lại bước 4.\n"
             "5a. Dữ liệu không hợp lệ: Core Backend từ chối. Nếu đây là lần gửi đầu tiên, ứng dụng xóa bản ghi cục bộ và báo lỗi; nếu là lần gửi lại, bản ghi được giữ ở trạng thái lỗi đồng bộ. Quy trình kết thúc.\n"
             "6a. clientId đã tồn tại (giao dịch được gửi lặp sau khi mất kết nối): Core Backend trả lại giao dịch đã lưu trước đó và không cập nhật ví lần thứ hai; quy trình tiếp tục ở bước 8.\n"
             "6b. Khoản chi lớn hơn số dư ví: Core Backend từ chối như ở 5a.\n"
             "8a. Người dùng sửa một giao dịch đã đồng bộ: Core Backend điều chỉnh số dư theo chênh lệch và kiểm tra lại ngân sách; thao tác sửa không đi qua hàng đợi ngoại tuyến nên cần có kết nối mạng.\n"
             "8b. Người dùng xóa một giao dịch: Core Backend hoàn lại ảnh hưởng của giao dịch lên số dư rồi xóa; bản ghi chưa từng đồng bộ chỉ bị xóa trên thiết bị."],
        ]),
        *figs("ghi_chep", "Ghi chép thu chi", 2),
    ],
    # ------------------------------------------------------------------ 2.2.3
    "Mô hình hóa quy trình quét hóa đơn và đối soát": [
        ("p", "Quy trình quét hóa đơn thay bước đọc và nhập tay của quy trình thủ công ở mục 1.2.2 bằng mô hình DONUT. Ứng dụng "
              "di động gọi trực tiếp AI Service để đọc ảnh, sau đó người dùng đối chiếu kết quả với hóa đơn giấy trước khi lưu. "
              "Bảng 2.3 đặc tả quy trình."),
        ("y", "[Nhóm] Bảng 2.3 và Hình 2.5–2.7 mô tả mã nguồn đã commit (HEAD). Ngày 21/10/2026 review_form_page.dart đang được "
              "viết lại trong một phiên khác (tổng tiền sửa được, ảnh tải lên khi lưu, lưu qua hàng đợi ngoại tuyến kèm clientId). "
              "Khi bản viết lại được commit, cập nhật lại mục 2.2.3 và đoạn tổng kết cuối mục 2.2.7."),
        ("h4", "Đặc tả bằng văn bản"),
        spec("Đặc tả quy trình nghiệp vụ quét hóa đơn và đối soát", [
            ["Use case nghiệp vụ", "Quét hóa đơn và đối soát"],
            ["Tác nhân", "Người dùng"],
            ["Mô tả", "Người dùng chụp hoặc chọn ảnh hóa đơn; AI Service trích xuất bốn trường Seller, Address, Timestamp, "
                      "Total Cost; người dùng đối chiếu kết quả rồi lưu thành một khoản chi kèm hồ sơ hóa đơn. Quy trình kết thúc "
                      "khi giao dịch và hóa đơn được lưu, hoặc khi người dùng chuyển sang nhập tay."],
            ["Dòng cơ bản",
             "1. Người dùng chụp hóa đơn bằng trình quét tài liệu của ứng dụng hoặc chọn ảnh có sẵn trong thư viện.\n"
             "2. Ứng dụng gửi ảnh tới AI Service.\n"
             "3. AI Service chạy mô hình DONUT và trả về tên người bán, địa chỉ, thời gian và tổng tiền.\n"
             "4. Ứng dụng tải ảnh gốc lên Core Backend; Core Backend lưu ảnh trên dịch vụ lưu trữ ảnh đám mây (Cloudinary) và trả về đường dẫn.\n"
             "5. Ứng dụng hiển thị biểu mẫu đối soát gồm ảnh và các trường AI đã đọc.\n"
             "6. Người dùng đối chiếu với hóa đơn giấy, sửa tên cửa hàng và ngày nếu cần, chọn danh mục chi rồi xác nhận lưu. Tổng tiền chỉ hiển thị, không sửa được trên biểu mẫu.\n"
             "7. Ứng dụng gửi khoản chi kèm kết quả gốc của AI và đường dẫn ảnh.\n"
             "8. Core Backend kiểm tra dữ liệu và số dư, cập nhật ví và lưu giao dịch như quy trình 2.2.2, đồng thời tạo hồ sơ hóa đơn với trạng thái COMPLETED_RAW (đã đọc được tổng tiền). Yêu cầu này không kèm clientId nên không qua bước khóa ví và kiểm tra gửi lặp. Thời gian và địa chỉ do AI đọc được dùng làm ngày và nơi giao dịch, thay cho ngày người dùng đã sửa ở bước 6.\n"
             "9. Core Backend ghi nhật ký hoạt động; sau khi giao dịch cơ sở dữ liệu hoàn tất, kết quả gốc của AI được ghi vào MongoDB [37] để phục vụ phân tích sau này.\n"
             "10. Ứng dụng đóng biểu mẫu và cập nhật Sổ giao dịch. Quy trình kết thúc."],
            ["Dòng thay thế",
             "3a. AI Service không phản hồi hoặc trả lỗi: ứng dụng báo quét thất bại, người dùng nhập tay theo quy trình 2.2.2. Quy trình kết thúc.\n"
             "4a. Tải ảnh thất bại: quy trình vẫn tiếp tục, hóa đơn được lưu không kèm ảnh.\n"
             "5a. Tổng tiền AI đọc bằng 0: ứng dụng báo chưa đọc được tổng tiền và đề nghị nhập tay; Core Backend sẽ từ chối một khoản chi có số tiền bằng 0. Người dùng chuyển sang quy trình 2.2.2.\n"
             "6a. Người dùng không xác nhận mà quay lại: không có dữ liệu nào được lưu. Quy trình kết thúc.\n"
             "8a. Kết quả gốc của AI không chứa tổng tiền hợp lệ: hóa đơn được lưu với trạng thái FAILED và mã lý do AI_NO_TOTAL (đọc được một phần) hoặc AI_UNREADABLE (không đọc được trường nào).\n"
             "8b. Dữ liệu không hợp lệ, số dư không đủ hoặc mất kết nối: ứng dụng báo lưu thất bại và giữ nguyên biểu mẫu để người dùng thử lại. Giao dịch từ hóa đơn không đi qua hàng đợi ngoại tuyến của quy trình 2.2.2."],
        ]),
        *figs("quet_hoa_don", "Quét hóa đơn và đối soát", 5, w_col=15.5),
    ],
    # ------------------------------------------------------------------ 2.2.4
    "Mô hình hóa quy trình lập và theo dõi ngân sách": [
        ("p", "Quy trình ngân sách gồm hai giai đoạn: người dùng đặt hạn mức cho một kỳ, sau đó hệ thống theo dõi các khoản chi "
              "trong kỳ và cảnh báo khi chi tiêu chạm mốc 80% hoặc 100% hạn mức. Bảng 2.4 đặc tả quy trình."),
        ("h4", "Đặc tả bằng văn bản"),
        spec("Đặc tả quy trình nghiệp vụ lập và theo dõi ngân sách", [
            ["Use case nghiệp vụ", "Lập và theo dõi ngân sách"],
            ["Tác nhân", "Người dùng"],
            ["Mô tả", "Người dùng tạo ngân sách cho một danh mục chi (hoặc cho tất cả danh mục) theo kỳ tuần hoặc tháng. Mỗi khi "
                      "có khoản chi mới hoặc khoản chi được sửa, Core Backend tính lại tỉ lệ đã chi và tạo thông báo khi tỉ lệ "
                      "vượt qua một mốc cảnh báo."],
            ["Dòng cơ bản",
             "1. Người dùng mở màn hình Ngân sách và chọn thêm ngân sách.\n"
             "2. Ứng dụng tải danh sách danh mục chi từ Core Backend.\n"
             "3. Người dùng chọn danh mục hoặc tất cả danh mục, loại kỳ tuần hoặc tháng, ngày bắt đầu, ngày kết thúc và hạn mức.\n"
             "4. Core Backend kiểm tra hạn mức lớn hơn 0, ngày kết thúc không trước ngày bắt đầu, độ dài kỳ không quá 7 ngày với kỳ tuần và không quá 31 ngày với kỳ tháng.\n"
             "5. Core Backend kiểm tra danh mục tồn tại và người dùng chưa có ngân sách cùng danh mục, cùng loại kỳ và cùng ngày bắt đầu, sau đó lưu ngân sách và ghi nhật ký hoạt động.\n"
             "6. Ứng dụng hiển thị ngân sách cùng thanh tiến độ chi tiêu trên màn hình Ngân sách, Tổng quan và Sổ giao dịch.\n"
             "7. Khi người dùng ghi hoặc sửa một khoản chi (quy trình 2.2.2), Core Backend tìm các ngân sách có kỳ chứa ngày giao dịch và cùng danh mục, hoặc áp dụng cho tất cả danh mục.\n"
             "8. Với mỗi ngân sách đó, Core Backend so sánh tỉ lệ đã chi trước và sau giao dịch. Nếu giao dịch đưa tỉ lệ từ dưới lên bằng hoặc trên 80%, hệ thống tạo thông báo loại BUDGET_WARNING; nếu đạt hoặc vượt 100%, tạo thông báo BUDGET_EXCEEDED. Thông báo được lưu trong cùng giao dịch cơ sở dữ liệu với khoản chi.\n"
             "9. Ứng dụng lấy số thông báo chưa đọc từ Core Backend để hiển thị trên biểu tượng chuông. Đồng thời ứng dụng tự tính tiến độ ngân sách từ các giao dịch trên thiết bị và hiện hộp thoại cảnh báo khi một ngân sách chạm mốc 80% hoặc 100%.\n"
             "10. Người dùng mở Trung tâm thông báo, xem nội dung và đánh dấu đã đọc. Quy trình kết thúc."],
            ["Dòng thay thế",
             "4a. Dữ liệu không hợp lệ: Core Backend từ chối, ứng dụng báo lỗi. Quy trình kết thúc.\n"
             "5a. Ngân sách bị trùng: Core Backend trả mã lỗi xung đột (409), ứng dụng báo đã có ngân sách tương ứng. Quy trình kết thúc.\n"
             "8a. Tỉ lệ đã vượt mốc từ trước (ví dụ đang ở 85% và tăng lên 90%): không tạo thêm thông báo, tránh gửi lặp cho cùng một mốc.\n"
             "8b. Một khoản chi làm tỉ lệ vượt cả hai mốc cùng lúc: chỉ tạo một thông báo ở mốc 100%.\n"
             "9a. Hộp thoại cảnh báo trên ứng dụng chỉ hiện một lần cho mỗi tổ hợp ngân sách, kỳ, hạn mức và mức cảnh báo; các lần mở ứng dụng sau không hiện lại.\n"
             "10a. Người dùng sửa hoặc xóa ngân sách từ màn hình Ngân sách; việc sửa phải thỏa các điều kiện ở bước 4 và 5."],
        ]),
        *figs("ngan_sach", "Lập và theo dõi ngân sách", 8),
    ],
    # ------------------------------------------------------------------ 2.2.5
    "Mô hình hóa quy trình thống kê và báo cáo thói quen chi tiêu": [
        ("p", "Quy trình này gồm hai phần. Phần thống kê do ứng dụng di động tính từ danh sách giao dịch của người dùng. Phần "
              "báo cáo thói quen chi tiêu do AI Service thực hiện bằng thuật toán khai phá mẫu chuỗi WCM-SPADE cài đặt trong "
              "module wcm_spade.py, dựa trên cách biểu diễn danh sách định danh (id-list) theo chiều dọc của thuật toán SPADE [48], "
              "kèm phần gợi ý ngân sách dựa trên mục tiêu tiết kiệm. Bảng 2.5 đặc tả quy trình."),
        ("h4", "Đặc tả bằng văn bản"),
        spec("Đặc tả quy trình nghiệp vụ thống kê và báo cáo thói quen chi tiêu", [
            ["Use case nghiệp vụ", "Thống kê và báo cáo thói quen chi tiêu"],
            ["Tác nhân", "Người dùng"],
            ["Mô tả", "Người dùng xem tổng quan tài chính, biểu đồ thu chi theo khoảng thời gian và báo cáo các mẫu chi tiêu lặp "
                      "lại kèm gợi ý ngân sách. Quy trình chỉ đọc dữ liệu, không thay đổi giao dịch."],
            ["Dòng cơ bản",
             "1. Người dùng mở ứng dụng; màn hình Tổng quan được hiển thị.\n"
             "2. Ứng dụng lấy hồ sơ người dùng, danh sách giao dịch và danh sách ngân sách của chính người dùng từ Core Backend, gộp thêm các giao dịch chưa đồng bộ trên thiết bị.\n"
             "3. Ứng dụng tính số dư hiện tại (tổng thu trừ tổng chi), tổng thu, tổng chi và tiến độ của các ngân sách đang hiệu lực.\n"
             "4. Người dùng mở Sổ giao dịch, chọn khoảng thời gian và bộ lọc; ứng dụng lọc giao dịch và vẽ biểu đồ cột thu chi.\n"
             "5. Người dùng mở tab AI; khoảng thời gian mặc định là tháng hiện tại.\n"
             "6. Ứng dụng lấy đồng thời danh sách giao dịch và danh sách mục tiêu tiết kiệm từ Core Backend.\n"
             "7. Ứng dụng gửi các giao dịch nằm trong khoảng thời gian đang chọn (danh mục, số tiền, ngày, loại thu/chi) tới AI Service.\n"
             "8. AI Service khai phá các mẫu chuỗi chi tiêu có độ dài tối đa 4, trả về mỗi mẫu dạng “A → B” kèm số lần xuất hiện, trọng số và độ hỗ trợ.\n"
             "9. Song song với bước 7, ứng dụng chọn mục tiêu tiết kiệm gần hạn nhất và gửi toàn bộ giao dịch cùng số tiền mục tiêu, số tiền đã tiết kiệm và số tháng còn lại tới AI Service; AI Service trả về xu hướng chi tiêu, thống kê theo nhóm, các gợi ý ngân sách và đoạn tóm tắt.\n"
             "10. Ứng dụng hiển thị các mẫu chi tiêu, biểu đồ và gợi ý. Quy trình kết thúc."],
            ["Dòng thay thế",
             "8a. Khoảng thời gian có ít hơn 3 khoản chi hợp lệ: AI Service trả về danh sách mẫu rỗng kèm thông điệp giải thích.\n"
             "9a. Người dùng chưa có mục tiêu tiết kiệm đang theo đuổi: ứng dụng bỏ qua bước 9 và chỉ hiển thị các mẫu chi tiêu.\n"
             "10a. Người dùng đổi khoảng thời gian hoặc chọn Làm mới: ứng dụng chỉ chạy lại bước 7–8.\n"
             "10b. Người dùng kéo để làm mới tab AI: quy trình quay lại bước 6."],
        ]),
        ("p", "Nhánh Sổ giao dịch (bước 4) chỉ gồm thao tác lọc và vẽ biểu đồ trên thiết bị nên được mô tả trong Bảng 2.5 mà "
              "không vẽ lại trên các sơ đồ. Hình 2.11 và Hình 2.12 thể hiện việc hai yêu cầu tới AI Service được gửi song song "
              "bằng thanh phân nhánh (fork) và đoạn par của UML [47]."),
        *figs("thong_ke", "Thống kê và báo cáo thói quen chi tiêu", 11),
    ],
    # ------------------------------------------------------------------ 2.2.6
    "Mô hình hóa quy trình quản trị hệ thống": [
        ("p", "Quản trị viên làm việc trên Web Admin, một nhóm trang do Core Backend sinh bằng Thymeleaf (thư viện sinh trang "
              "HTML phía máy chủ) và được bảo vệ bởi chuỗi bộ lọc bảo mật riêng, chỉ cho phép tài khoản có vai trò ROLE_ADMIN. "
              "Bảng 2.6 đặc tả quy trình; sơ đồ tuần tự và sơ đồ cộng tác lấy thao tác thêm một danh mục làm ví dụ cho phần "
              "thao tác quản trị."),
        ("y", "[Nhóm] Nút khóa/mở khóa trên trang users.html gọi PUT /api/admin/users/{id}/toggle-status, đường dẫn không tồn "
              "tại (đúng là /admin/ajax/users/{id}/toggle-status), nên hiện không khóa được tài khoản từ giao diện. Cần sửa trước "
              "khi chụp giao diện cho Chương 3."),
        ("h4", "Đặc tả bằng văn bản"),
        spec("Đặc tả quy trình nghiệp vụ quản trị hệ thống", [
            ["Use case nghiệp vụ", "Quản trị hệ thống"],
            ["Tác nhân", "Quản trị viên"],
            ["Mô tả", "Quản trị viên đăng nhập Web Admin, xem số liệu tổng quan và thực hiện các thao tác quản trị: quản lý tài "
                      "khoản người dùng, danh mục, gói dịch vụ, đánh giá ứng dụng; xem nhật ký hoạt động; sao lưu và khôi phục cơ "
                      "sở dữ liệu; chạy phân khúc khách hàng. Các thao tác thay đổi dữ liệu được ghi vào nhật ký hoạt động."],
            ["Dòng cơ bản",
             "1. Quản trị viên nhập tên đăng nhập và mật khẩu trên trang đăng nhập Web Admin.\n"
             "2. Core Backend kiểm tra tài khoản và địa chỉ IP không bị khóa đăng nhập và mật khẩu đúng, rồi ghi nhật ký đăng nhập thành công.\n"
             "3. Khi chuyển tới trang Tổng quan, Core Backend kiểm tra tài khoản có vai trò ROLE_ADMIN và hiển thị: tổng giá trị giao dịch, số người dùng, số giao dịch trong tháng, người chi tiêu nhiều nhất, biểu đồ sáu tháng, tỉ lệ trạng thái hóa đơn và số người dùng theo phân khúc.\n"
             "4. Quản trị viên chọn một chức năng: người dùng (thêm, sửa, xóa, khóa hoặc mở khóa tài khoản), danh mục (thêm, sửa, xóa), gói dịch vụ (thêm, sửa, bật/tắt, xóa), đánh giá ứng dụng (duyệt, xóa), nhật ký hoạt động (xem, lọc, gỡ khóa đăng nhập cho tài khoản hoặc địa chỉ IP), sao lưu và khôi phục cơ sở dữ liệu, hoặc chạy phân khúc khách hàng theo mô hình RFM (Recency – Frequency – Monetary) [49], trong đó AI Service xếp nhóm bằng các ngưỡng cố định cho ba chỉ số.\n"
             "5. Core Backend kiểm tra thao tác, cập nhật dữ liệu và ghi nhật ký hoạt động.\n"
             "6. Web Admin cập nhật danh sách tương ứng. Quản trị viên lặp lại bước 4 cho đến khi đăng xuất. Quy trình kết thúc."],
            ["Dòng thay thế",
             "2a. Tài khoản hoặc địa chỉ IP đang bị khóa đăng nhập: Core Backend từ chối và ghi nhật ký. Quy trình kết thúc.\n"
             "2b. Sai tên đăng nhập hoặc mật khẩu: Core Backend tăng bộ đếm đăng nhập sai của tài khoản và địa chỉ IP rồi báo lỗi; sau 5 lần sai, tài khoản và địa chỉ IP bị khóa đăng nhập trong 15 phút. Quy trình kết thúc.\n"
             "3a. Tài khoản đăng nhập đúng nhưng không có vai trò ROLE_ADMIN: nhật ký đăng nhập đã được ghi ở bước 2, nhưng Core Backend từ chối truy cập các trang quản trị. Quy trình kết thúc.\n"
             "5a. Quản trị viên khóa một tài khoản có vai trò ROLE_ADMIN, kể cả tài khoản của chính mình: Core Backend từ chối thao tác.\n"
             "5b. Tài khoản người dùng bị khóa: yêu cầu kế tiếp của người dùng đó tới Core Backend bị từ chối, kể cả khi mã truy cập cũ còn hạn, và người dùng không đăng nhập lại được.\n"
             "5c. Dữ liệu vi phạm ràng buộc duy nhất (trùng tên đăng nhập, email hoặc số điện thoại): cơ sở dữ liệu từ chối bản ghi và thao tác không được lưu."],
        ]),
        *figs("quan_tri", "Quản trị hệ thống", 14, w_act=11.5, w_col=11.0),
    ],
    # ------------------------------------------------------------------ 2.2.7
    "Mô hình hóa quy trình duyệt hóa đơn AI": [
        ("p", "Kết quả đọc của DONUT có thể sai, nhất là ở trường tổng tiền. Quy trình duyệt cho phép quản trị viên đối chiếu "
              "kết quả AI với ảnh gốc: duyệt một hóa đơn sẽ đối soát số tiền của giao dịch theo tổng tiền của hóa đơn, còn từ "
              "chối đánh dấu hóa đơn là lỗi kèm lý do do quản trị viên từ chối. Bảng 2.7 đặc tả quy trình."),
        ("y", "[Nhóm] Trang /admin/receipts hiện chỉ hiển thị danh sách (người bán, tổng tiền AI đọc, ảnh, trạng thái), chưa có "
              "nút Duyệt/Từ chối dù Core Backend đã có hai đường dẫn POST /admin/receipts/approve/{id} và /reject/{id}. Cần bổ "
              "sung hai nút trước khi chụp giao diện cho Chương 3; nếu không bổ sung, mục này phải viết lại."),
        ("h4", "Đặc tả bằng văn bản"),
        spec("Đặc tả quy trình nghiệp vụ duyệt hóa đơn AI", [
            ["Use case nghiệp vụ", "Duyệt hóa đơn AI"],
            ["Tác nhân", "Quản trị viên"],
            ["Mô tả", "Quản trị viên xem danh sách hóa đơn do AI đọc, mở ảnh gốc để đối chiếu, sau đó duyệt hoặc từ chối từng "
                      "hóa đơn. Duyệt làm số tiền giao dịch khớp với tổng tiền hóa đơn và chuyển hóa đơn sang trạng thái APPROVED; "
                      "từ chối chuyển hóa đơn sang trạng thái FAILED với mã lý do REJECTED_BY_ADMIN."],
            ["Dòng cơ bản",
             "1. Quản trị viên mở trang Hóa đơn trên Web Admin.\n"
             "2. Core Backend trả về danh sách hóa đơn, mới nhất trước, gồm tên người bán, tổng tiền AI đọc, liên kết ảnh gốc và trạng thái.\n"
             "3. Quản trị viên mở ảnh gốc và đối chiếu với kết quả AI.\n"
             "4. Kết quả đúng, quản trị viên chọn duyệt.\n"
             "5. Core Backend khóa bản ghi ví của chủ hóa đơn, kiểm tra hóa đơn đang ở trạng thái được phép chuyển sang APPROVED và có tổng tiền lớn hơn 0.\n"
             "6. Nếu số tiền của giao dịch khác tổng tiền hóa đơn, Core Backend đặt lại số tiền giao dịch, điều chỉnh số dư ví theo phần chênh lệch và kiểm tra lại ngân sách liên quan.\n"
             "7. Core Backend chuyển hóa đơn sang APPROVED, ghi nhật ký duyệt hóa đơn (và nhật ký cập nhật giao dịch nếu có đối soát).\n"
             "8. Web Admin hiển thị danh sách đã cập nhật. Quy trình kết thúc."],
            ["Dòng thay thế",
             "4a. Kết quả AI sai, quản trị viên chọn từ chối: hóa đơn đã hủy không thể từ chối; nếu hóa đơn chưa ở trạng thái FAILED, Core Backend chuyển sang FAILED với mã lý do REJECTED_BY_ADMIN và ghi nhật ký; số dư ví không thay đổi. Quy trình tiếp tục ở bước 8.\n"
             "5a. Hóa đơn đã bị hủy, đang ở trạng thái không thể duyệt hoặc không có tổng tiền hợp lệ: Core Backend từ chối thao tác và báo lỗi. Quy trình kết thúc.\n"
             "5b. Hóa đơn không gắn với giao dịch nào: Core Backend từ chối thao tác.\n"
             "5c. Hóa đơn vừa được người khác cập nhật (khóa lạc quan theo số phiên bản): Core Backend từ chối thao tác, quản trị viên tải lại danh sách và thực hiện lại.\n"
             "6a. Đối soát làm tăng khoản chi vượt quá số dư ví hiện có: Core Backend từ chối thao tác, hóa đơn giữ nguyên trạng thái."],
        ]),
        *figs("duyet_hoa_don", "Duyệt hóa đơn AI", 17, w_act=14.0, w_col=15.5),
        ("p", "Sáu quy trình trên cho thấy ba điểm chung về cách hệ thống xử lý dữ liệu. Thứ nhất, mọi thay đổi số dư ví đều "
              "đi qua Core Backend. Các thao tác sửa, xóa giao dịch, duyệt hóa đơn và tạo giao dịch có clientId khóa bản ghi ví "
              "trước khi đọc số dư, nên hai yêu cầu đồng thời không ghi đè lên nhau; giao dịch tạo từ hóa đơn hiện chưa gửi "
              "clientId nên chưa được bảo vệ theo cách này. Thứ hai, ứng dụng di động gọi trực tiếp AI Service cho các tác vụ đọc hóa đơn và phân tích, còn kết "
              "quả chỉ được ghi vào cơ sở dữ liệu khi người dùng xác nhận. Thứ ba, các thao tác thay đổi dữ liệu quan trọng "
              "đều có bản ghi trong nhật ký hoạt động. Mục 2.3 dựa trên các quy trình này để xác định use case ở mức hệ thống."),
    ],
}

ABBREVIATIONS = [
    ("IP", "Internet Protocol", "Giao thức Internet"),
    ("RFM", "Recency – Frequency – Monetary", "Mô hình phân khúc theo độ gần, tần suất và giá trị chi tiêu"),
    ("UUID", "Universally Unique Identifier", "Mã định danh duy nhất toàn cục"),
]

# Đối chiếu mã nguồn (21/10/2026):
# - Ghi chép: AppRepository.createTransaction (outbox pending/synced/error), TransactionService.create (khóa ví, clientId,
#   số dư không đủ -> 400), updateTransaction/deleteTransaction, TransactionRequestDto (@Positive, @NotBlank, @NotNull).
# - Quét: review_form_page.dart (scan -> upload -> form; tổng tiền chỉ đọc; snack khi lỗi), ReceiptProcessingService
#   .attachReceipt/recordReading (COMPLETED_RAW / FAILED + AI_NO_TOTAL|AI_UNREADABLE; timestamp/address ghi đè giao dịch),
#   OcrMongoService (sau commit). Ứng dụng KHÔNG gửi clientId cho giao dịch từ hóa đơn.
# - Ngân sách: BudgetRequestDto, BudgetPeriodType (7/31 ngày), Budget unique key, BudgetAlertService (80/100, chống lặp),
#   budget_alert_tracker.dart (hộp thoại một lần).
# - Thống kê: app_repository.getHomeSummary (số dư tính trên máy), ledger_page.dart, ai_tab_page.dart, ai_service.py.
# - Quản trị: SecurityConfig form login + LoginAttemptService, AdminController, UserService.toggleUserStatus.
# - Duyệt: AdminController approve/reject, TransactionService.approveReceipt, ReceiptProcessingService.rejectReceipt,
#   ReceiptStatus.MOVES, Receipt @Version; templates/admin/receipts.html chưa có nút duyệt/từ chối.
