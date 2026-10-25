# Nội dung phiên T7.2b: Chương 2, mục 2.3 (use case hệ thống + 22 bảng đặc tả), viết lại mục 2.2.3 và đoạn
# tổng kết cuối mục 2.2.7 theo mã nguồn commit 4d7a9ee (T3b). Đối chiếu mã nguồn tại HEAD f50a6d2 ngày 25/10/2026.
# Trích dẫn: [28] JWT, [32] Spring Security, [36] Redis, [37] MongoDB, [47] UML 2.5.1, [48] SPADE, [49] RFM.
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = "T7.2b"
SRC = "nguồn: nhóm thực hiện"
NGUON = "Nguồn: nhóm thực hiện"

# Chương 2 đã có Hình 2.1–2.19 và Bảng 2.1–2.7 từ phiên T7.2a.
COUNTER_START = {("Hình", "2"): 19, ("Bảng", "2"): 7}

FIELDS = ["Tên use case", "Tóm tắt", "Tác nhân", "Use case liên quan", "Điều kiện tiên quyết",
          "Dòng sự kiện chính", "Dòng sự kiện phụ", "Hậu điều kiện"]


def uc(code, name, summary, actors, related, pre, main, alt, post):
    rows = [[f, v] for f, v in zip(FIELDS, [f"{code} – {name}", summary, actors, related, pre,
                                             "\n".join(main), "\n".join(alt), post])]
    return ("table", f"Đặc tả use case {code} “{name}”", "2", [2000, 6504], ["Trường", "Nội dung"], rows, NGUON)


# ============================================================ 2.2.3 (viết lại)
def figs(name, title, n0, w_act=15.0, w_seq=16.0, w_col=12.0):
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


SEC_223 = [
    ("p", "Quy trình quét hóa đơn thay bước đọc và nhập tay của quy trình thủ công ở mục 1.2.2 bằng mô hình DONUT. Ứng dụng "
          "di động gọi trực tiếp AI Service để đọc ảnh, người dùng đối chiếu và sửa kết quả trên biểu mẫu, sau đó giao dịch "
          "được lưu theo cùng cơ chế hàng đợi ngoại tuyến với mã clientId như quy trình 2.2.2. Bảng 2.3 đặc tả quy trình."),
    ("h4", "Đặc tả bằng văn bản"),
    ("table", "Đặc tả quy trình nghiệp vụ quét hóa đơn và đối soát", "2", [2000, 6504], ["Thành phần", "Nội dung"], [
        ["Use case nghiệp vụ", "Quét hóa đơn và đối soát"],
        ["Tác nhân", "Người dùng"],
        ["Mô tả", "Người dùng chụp hoặc chọn ảnh hóa đơn; AI Service trích xuất bốn trường Seller, Address, Timestamp, "
                  "Total Cost; người dùng đối chiếu, sửa tên cửa hàng, tổng tiền, ngày giờ, chọn danh mục rồi lưu thành một "
                  "khoản chi kèm ảnh và hồ sơ hóa đơn. Quy trình kết thúc khi giao dịch được máy chủ ghi nhận, được giữ lại "
                  "trên thiết bị để gửi sau, hoặc khi người dùng quay lại mà không lưu."],
        ["Dòng cơ bản",
         "1. Người dùng chụp hóa đơn bằng trình quét tài liệu của ứng dụng hoặc chọn ảnh có sẵn trong thư viện.\n"
         "2. Ứng dụng mở biểu mẫu đối soát ở trạng thái đang phân tích và gửi ảnh tới AI Service.\n"
         "3. AI Service chạy mô hình DONUT và trả về tên người bán, địa chỉ, thời gian và tổng tiền.\n"
         "4. Ứng dụng điền sẵn tên cửa hàng, tổng tiền (khi AI đọc được giá trị lớn hơn 0) và ngày giờ trên hóa đơn; chuỗi thời gian được thử lần lượt theo một danh sách định dạng ngày giờ.\n"
         "5. Người dùng đối chiếu với hóa đơn giấy, sửa tên cửa hàng, tổng tiền hoặc chọn lại ngày giờ bằng bộ chọn ngày và giờ, chọn danh mục chi rồi chọn “Xác nhận & Lưu”.\n"
         "6. Ứng dụng kiểm tra tổng tiền lớn hơn 0, sau đó tải ảnh gốc lên Core Backend; Core Backend lưu ảnh trên dịch vụ lưu trữ ảnh đám mây (Cloudinary) và trả về đường dẫn. Ảnh chỉ được tải một lần, các lần lưu lại dùng đường dẫn đã có.\n"
         "7. Ứng dụng tạo giao dịch chi với mã clientId mới, lưu bản ghi vào SQLite ở trạng thái chờ đồng bộ (kèm kết quả gốc của AI và đường dẫn ảnh) rồi gửi lên Core Backend.\n"
         "8. Core Backend kiểm tra dữ liệu, khóa bản ghi ví, kiểm tra clientId chưa tồn tại và số dư đủ, trừ số tiền khỏi ví và lưu giao dịch như quy trình 2.2.2. Đồng thời Core Backend tạo hồ sơ hóa đơn với trạng thái COMPLETED_RAW (đã đọc được tổng tiền); thời gian và địa chỉ do AI đọc được dùng làm ngày và nơi giao dịch, thay cho giá trị gửi từ biểu mẫu.\n"
         "9. Core Backend kiểm tra ngân sách (quy trình 2.2.4), ghi nhật ký hoạt động; sau khi giao dịch cơ sở dữ liệu hoàn tất, kết quả gốc của AI được ghi vào MongoDB [37] để phục vụ phân tích sau này.\n"
         "10. Ứng dụng đánh dấu bản ghi là đã đồng bộ, báo lưu thành công, đóng biểu mẫu và cập nhật Sổ giao dịch. Quy trình kết thúc."],
        ["Dòng thay thế",
         "3a. AI Service không phản hồi hoặc trả lỗi: ứng dụng báo quét thất bại, các trường để trống và người dùng nhập tay ngay trên biểu mẫu; quy trình tiếp tục ở bước 5.\n"
         "4a. AI đọc tổng tiền bằng 0: ô tổng tiền để trống, ứng dụng nhắc người dùng nhập tay.\n"
         "4b. Không đọc được hoặc không nhận dạng được ngày trên hóa đơn: ứng dụng dùng thời điểm hiện tại và hiển thị dòng cảnh báo dưới ô ngày cho tới khi người dùng chọn lại.\n"
         "5a. Người dùng quay lại mà không lưu: không có dữ liệu nào được ghi. Quy trình kết thúc.\n"
         "6a. Tổng tiền trống hoặc bằng 0: ứng dụng báo số tiền không hợp lệ; quay lại bước 5.\n"
         "6b. Tải ảnh thất bại: ứng dụng hỏi có lưu giao dịch không kèm ảnh hay không. Chọn “Lưu không kèm ảnh” thì tiếp tục bước 7; chọn “Để sau” thì biểu mẫu được giữ nguyên để lưu lại sau.\n"
         "7a. Thiết bị mất mạng hoặc máy chủ không trả lời: bản ghi chuyển sang trạng thái lỗi đồng bộ, ứng dụng báo chưa gửi được và hướng dẫn gửi lại từ Sổ giao dịch; lần gửi lại mang cùng clientId, kết quả gốc của AI và đường dẫn ảnh nên không tạo giao dịch trùng. Quy trình kết thúc.\n"
         "8a. Dữ liệu không hợp lệ hoặc số dư không đủ: Core Backend từ chối, ứng dụng xóa bản ghi cục bộ, báo lưu thất bại và giữ nguyên biểu mẫu. Quy trình kết thúc.\n"
         "8b. Kết quả gốc của AI không chứa tổng tiền hợp lệ: hóa đơn được lưu với trạng thái FAILED và mã lý do AI_NO_TOTAL (đọc được một phần) hoặc AI_UNREADABLE (không đọc được trường nào); giao dịch vẫn được lưu với số tiền người dùng đã nhập."],
    ], NGUON),
    *figs("quet_hoa_don", "Quét hóa đơn và đối soát", 5, w_act=15.5, w_seq=16.0, w_col=13.0),
]

REPLACE = {
    "Mô hình hóa quy trình quét hóa đơn và đối soát": ({("Hình", "2"): 4, ("Bảng", "2"): 2}, SEC_223),
}

PARA_REPLACE = [
    ("Sáu quy trình trên cho thấy ba điểm chung",
     ("p", "Sáu quy trình trên cho thấy ba điểm chung về cách hệ thống xử lý dữ liệu. Thứ nhất, mọi thay đổi số dư ví đều "
           "đi qua Core Backend. Các thao tác tạo giao dịch (nhập tay hoặc từ hóa đơn, đều kèm clientId), sửa, xóa giao dịch "
           "và duyệt hóa đơn khóa bản ghi ví trước khi đọc số dư, nên hai yêu cầu đồng thời không ghi đè lên nhau và một "
           "giao dịch gửi lặp không làm trừ tiền hai lần. Thứ hai, ứng dụng di động gọi trực tiếp AI Service cho các tác vụ "
           "đọc hóa đơn và phân tích, còn kết quả chỉ được ghi vào cơ sở dữ liệu khi người dùng xác nhận; khi chưa gửi được, "
           "giao dịch nằm trong hàng đợi trên thiết bị cùng kết quả gốc của AI. Thứ ba, các thao tác thay đổi dữ liệu quan "
           "trọng đều có bản ghi trong nhật ký hoạt động. Mục 2.3 dựa trên các quy trình này để xác định use case ở mức hệ thống.")),
]

# ============================================================ 2.3
ACTORS = [
    ("p", "Mục 2.2 mô tả hệ thống từ góc nhìn nghiệp vụ. Mục 2.3 chuyển sang mức chức năng: mỗi use case hệ thống là một "
          "chức năng cụ thể mà ứng dụng di động hoặc Web Admin cung cấp, được đặc tả bằng bảng tám trường gồm tên, tóm tắt, "
          "tác nhân, use case liên quan, điều kiện tiên quyết, dòng sự kiện chính, dòng sự kiện phụ và hậu điều kiện. Danh "
          "sách use case chỉ gồm những chức năng đã có trong mã nguồn tại thời điểm viết."),
    ("p", "Hệ thống có hai tác nhân chính và một tác nhân hệ thống (Bảng 2.8). Khác với mục 2.2.1, AI Service được vẽ thành "
          "tác nhân ở mức này: theo UML, tác nhân là vai trò của một người dùng hoặc một hệ thống khác tương tác với chủ thể "
          "được mô hình hóa [47]. Khi chủ thể là phần ứng dụng di động và Core Backend, AI Service là một hệ thống riêng "
          "(dịch vụ FastAPI chạy trong container riêng) nhận yêu cầu và trả kết quả, nên đóng vai tác nhân phụ trong các use "
          "case cần mô hình học máy. Các dịch vụ hạ tầng bên ngoài như Google, Facebook, Cloudinary và máy chủ thư điện tử "
          "không được vẽ thành tác nhân để sơ đồ tập trung vào chức năng; vai trò của chúng được nêu trong dòng sự kiện."),
    ("table", "Các tác nhân của hệ thống", "2", [2000, 1500, 5004], ["Tác nhân", "Loại", "Vai trò"], [
        ["Người dùng", "Tác nhân chính", "Cá nhân có tài khoản vai trò ROLE_USER, dùng ứng dụng di động để ghi chép thu chi, quét hóa đơn, lập ngân sách, đặt mục tiêu tiết kiệm, xem thống kê, báo cáo và thông báo."],
        ["Quản trị viên", "Tác nhân chính", "Tài khoản vai trò ROLE_ADMIN, dùng Web Admin để quản lý người dùng, danh mục, gói dịch vụ, duyệt hóa đơn AI, xem nhật ký và số liệu toàn hệ thống."],
        ["AI Service", "Tác nhân hệ thống", "Dịch vụ FastAPI cung cấp ba nhóm chức năng: đọc hóa đơn bằng DONUT (/donut/scan), khai phá mẫu chi tiêu và gợi ý ngân sách (/spade/analyze, /spade/recommend), phân khúc khách hàng theo RFM (/admin/segment)."],
    ], NGUON),
]

DIAGRAM = [
    ("p", "Sơ đồ use case hệ thống được tách thành hai hình theo phân hệ để giữ cỡ chữ đọc được khi in. Hình 2.20 là phân hệ "
          "người dùng trên ứng dụng di động với 16 use case; Hình 2.21 là phân hệ quản trị trên Web Admin với 6 use case "
          "riêng, cộng thêm hai use case Đăng nhập và Đăng xuất dùng chung với phân hệ người dùng."),
    ("p", "Hai loại quan hệ giữa các use case được dùng đúng nghĩa của UML [47]. Quan hệ «include» chỉ hành vi mà use case "
          "gốc luôn thực hiện: quét hóa đơn luôn dẫn tới biểu mẫu đối soát, và lưu hóa đơn luôn tạo một giao dịch theo cùng "
          "đường xử lý của chức năng thêm giao dịch. Quan hệ «extend» chỉ hành vi chỉ xảy ra khi thỏa điều kiện tại một điểm "
          "mở rộng của use case gốc: quên mật khẩu được mở từ màn hình đăng nhập; đồng bộ ngoại tuyến chỉ xảy ra khi giao "
          "dịch chưa gửi được; cảnh báo ngân sách chỉ phát sinh khi một khoản chi đưa tỉ lệ chi tiêu vượt mốc 80% hoặc 100%."),
    ("fig", "Sơ đồ use case hệ thống – phân hệ người dùng", "2", PNG + "ch2_uc_he_thong_nguoi_dung.png", 11.0, SRC, None),
    ("fig", "Sơ đồ use case hệ thống – phân hệ quản trị", "2", PNG + "ch2_uc_he_thong_quan_tri.png", 9.0, SRC, None),
    ("p", "Bảng 2.9 liệt kê 22 use case kèm tác nhân và màn hình hoặc trang thực hiện. Các mục 2.3.3 và 2.3.4 đặc tả lần lượt "
          "từng use case."),
    ("table", "Danh sách use case hệ thống", "2", [900, 2700, 1900, 3004], ["Mã", "Use case", "Tác nhân", "Nơi thực hiện"], [
        ["UC01", "Đăng ký", "Người dùng", "Màn hình Đăng ký"],
        ["UC02", "Đăng nhập", "Người dùng, Quản trị viên", "Màn hình Đăng nhập; trang /admin/login"],
        ["UC03", "Đăng xuất", "Người dùng, Quản trị viên", "Màn hình Hồ sơ; menu Web Admin"],
        ["UC04", "Đổi mật khẩu", "Người dùng", "Màn hình Thông tin đăng nhập"],
        ["UC05", "Quên và đặt lại mật khẩu", "Người dùng", "Màn hình Quên mật khẩu, Đặt lại mật khẩu"],
        ["UC06", "Quản lý giao dịch", "Người dùng", "Sổ giao dịch, Thêm giao dịch, Sửa giao dịch"],
        ["UC07", "Đồng bộ giao dịch ngoại tuyến", "Người dùng", "Sổ giao dịch (tự động và nút Gửi lại)"],
        ["UC08", "Quét hóa đơn", "Người dùng, AI Service", "Nút quét trên thanh điều hướng"],
        ["UC09", "Đối soát và lưu hóa đơn", "Người dùng", "Màn hình Xác nhận hóa đơn"],
        ["UC10", "Quản lý ngân sách", "Người dùng", "Màn hình Ngân sách"],
        ["UC11", "Nhận cảnh báo ngân sách", "Người dùng", "Hộp thoại cảnh báo, Trung tâm thông báo"],
        ["UC12", "Xem thống kê", "Người dùng", "Màn hình Tổng quan, Sổ giao dịch"],
        ["UC13", "Xem báo cáo thói quen chi tiêu", "Người dùng, AI Service", "Tab AI"],
        ["UC14", "Quản lý mục tiêu tiết kiệm", "Người dùng", "Màn hình Sổ tiết kiệm"],
        ["UC15", "Xem thông báo", "Người dùng", "Trung tâm thông báo"],
        ["UC16", "Cài đặt ngôn ngữ và giao diện", "Người dùng", "Màn hình Cài đặt"],
        ["UC17", "Quản lý người dùng", "Quản trị viên", "Web Admin: trang Người dùng, trang Hóa đơn"],
        ["UC18", "Quản lý danh mục mặc định", "Quản trị viên", "Web Admin: trang Danh mục"],
        ["UC19", "Duyệt hóa đơn AI", "Quản trị viên", "Web Admin: trang Hóa đơn"],
        ["UC20", "Xem nhật ký hoạt động", "Quản trị viên", "Web Admin: trang Nhật ký"],
        ["UC21", "Xem thống kê hệ thống", "Quản trị viên, AI Service", "Web Admin: trang Tổng quan"],
        ["UC22", "Quản lý gói dịch vụ", "Quản trị viên", "Web Admin: trang Gói dịch vụ"],
    ], NGUON),
]

LOGGED_IN = "Người dùng đã đăng nhập (UC02) và thiết bị có kết nối mạng."

USER_UC = [
    ("p", "Mục này đặc tả 16 use case của phân hệ người dùng (Bảng 2.10 đến Bảng 2.25). Trừ khi ghi khác, mọi yêu cầu từ ứng "
          "dụng tới Core Backend đều mang mã truy cập JWT (JSON Web Token) [28]; Core Backend xác định người dùng từ mã này "
          "chứ không từ tham số do ứng dụng gửi lên, nên mỗi người dùng chỉ đọc và sửa được dữ liệu của chính mình."),
    uc("UC01", "Đăng ký",
       "Người chưa có tài khoản tạo tài khoản mới bằng họ tên, email, số điện thoại và mật khẩu.",
       "Người dùng",
       "Không có. Đăng ký nhanh bằng Google hoặc Facebook được xử lý trong UC02.",
       "Thiết bị có kết nối mạng; người dùng chưa đăng nhập.",
       ["1. Người dùng chọn “Đăng ký” trên màn hình Đăng nhập.",
        "2. Người dùng nhập họ tên, email, số điện thoại và mật khẩu; ứng dụng hiển thị các tiêu chí mật khẩu đã đạt trong lúc nhập.",
        "3. Ứng dụng kiểm tra đủ bốn trường và mật khẩu đạt chính sách mật khẩu, rồi gửi yêu cầu đăng ký tới Core Backend.",
        "4. Core Backend kiểm tra dữ liệu: mật khẩu dài 8–72 ký tự, có ít nhất một chữ cái và một chữ số.",
        "5. Core Backend kiểm tra email và tên đăng nhập chưa được dùng, mã hóa mật khẩu bằng BCrypt, tạo tài khoản với vai trò ROLE_USER và ghi nhật ký USER_CREATED trong cùng một giao dịch cơ sở dữ liệu.",
        "6. Ứng dụng báo đăng ký thành công và quay về màn hình Đăng nhập."],
       ["3a. Thiếu thông tin hoặc mật khẩu chưa đạt: ứng dụng báo lỗi, quay lại bước 2.",
        "3b. Không kết nối được máy chủ: ứng dụng báo không thể kết nối, quay lại bước 2.",
        "4a. Dữ liệu không hợp lệ: Core Backend trả mã 400 kèm thông báo; ứng dụng hiển thị thông báo, quay lại bước 2.",
        "5a. Email, tên đăng nhập hoặc số điện thoại đã tồn tại: Core Backend trả mã 400 với thông báo tương ứng; quay lại bước 2."],
       "Tài khoản mới được lưu trong cơ sở dữ liệu với vai trò ROLE_USER; người dùng chưa có phiên đăng nhập."),
    uc("UC02", "Đăng nhập",
       "Người dùng đăng nhập ứng dụng di động bằng email và mật khẩu hoặc bằng tài khoản Google, Facebook; quản trị viên "
       "đăng nhập Web Admin bằng tên đăng nhập và mật khẩu.",
       "Người dùng, Quản trị viên",
       "UC05 «extend» UC02 (điểm mở rộng: liên kết “Quên mật khẩu” trên màn hình Đăng nhập).",
       "Người dùng đã có tài khoản (với đăng nhập mạng xã hội: tài khoản Google hoặc Facebook có email); thiết bị có kết nối mạng.",
       ["1. Người dùng mở ứng dụng; màn hình Đăng nhập hiển thị.",
        "2. Người dùng nhập email, mật khẩu và chọn “Đăng nhập”.",
        "3. Core Backend kiểm tra tài khoản và địa chỉ IP không bị tạm khóa đăng nhập, sau đó kiểm tra mật khẩu qua Spring Security [32].",
        "4. Core Backend đặt lại bộ đếm đăng nhập sai, ghi nhật ký đăng nhập thành công và cấp một mã truy cập JWT hiệu lực 15 phút cùng một mã làm mới hiệu lực 30 ngày [28].",
        "5. Ứng dụng lưu hai mã và mã người dùng, rồi chuyển tới màn hình chính (Tổng quan)."],
       ["2a. Người dùng chọn đăng nhập bằng Google hoặc Facebook: ứng dụng lấy mã xác thực từ nhà cung cấp và gửi kèm tên nhà cung cấp tới Core Backend. Core Backend xác minh mã với Google (kiểm tra cả đối tượng nhận mã) hoặc Facebook và lấy email; nếu email chưa có tài khoản thì tạo tài khoản ROLE_USER mới. Tiếp tục bước 4.",
        "2b. Quản trị viên đăng nhập trên trang /admin/login của Web Admin: Core Backend kiểm tra như bước 3, lưu phiên đăng nhập phía máy chủ và chuyển tới trang Tổng quan quản trị; tài khoản không có vai trò ROLE_ADMIN bị từ chối truy cập các trang /admin/**.",
        "3a. Sai email hoặc mật khẩu: Core Backend tăng bộ đếm sai của tài khoản và địa chỉ IP, ghi nhật ký và trả mã 401; sau 5 lần sai, tài khoản và địa chỉ IP bị tạm khóa đăng nhập 15 phút (mã 429). Quay lại bước 2.",
        "3b. Tài khoản bị quản trị viên khóa: Core Backend từ chối đăng nhập.",
        "2c. Xác minh mã mạng xã hội thất bại hoặc nhà cung cấp không trả về email: Core Backend trả mã 401, ứng dụng báo lỗi.",
        "5a. Trong khi dùng ứng dụng, mã truy cập hết hạn: ứng dụng tự đổi mã làm mới lấy cặp mã mới (mã làm mới cũ bị thu hồi); nếu bị từ chối, phiên kết thúc và người dùng phải đăng nhập lại."],
       "Người dùng có phiên đăng nhập hợp lệ; lần đăng nhập (thành công hay thất bại) được ghi vào nhật ký hoạt động."),
    uc("UC03", "Đăng xuất",
       "Người dùng kết thúc phiên trên thiết bị; hai mã của phiên bị thu hồi trên máy chủ.",
       "Người dùng, Quản trị viên",
       "Không có.",
       "Người dùng đang đăng nhập (UC02).",
       ["1. Người dùng chọn “Đăng xuất” trên màn hình Hồ sơ.",
        "2. Ứng dụng hỏi xác nhận; người dùng đồng ý.",
        "3. Ứng dụng gửi yêu cầu đăng xuất kèm mã làm mới tới Core Backend.",
        "4. Core Backend đưa mã truy cập và mã làm mới vào danh sách thu hồi (bảng revoked_tokens) và ghi nhật ký AUTH_LOGOUT.",
        "5. Ứng dụng xóa phiên trên thiết bị và quay về màn hình Đăng nhập."],
       ["2a. Người dùng không xác nhận: use case kết thúc, phiên giữ nguyên.",
        "3a. Không gọi được Core Backend: ứng dụng vẫn xóa phiên trên thiết bị và quay về màn hình Đăng nhập.",
        "1a. Quản trị viên chọn đăng xuất trên Web Admin: Core Backend hủy phiên phía máy chủ và chuyển về trang /admin/login."],
       "Phiên trên thiết bị bị xóa; mã cũ không dùng được nữa (yêu cầu mang mã đã thu hồi nhận mã 401)."),
    uc("UC04", "Đổi mật khẩu",
       "Người dùng đang đăng nhập đổi mật khẩu bằng cách nhập mật khẩu hiện tại và mật khẩu mới; mọi phiên khác của tài khoản kết thúc.",
       "Người dùng",
       "Không có.",
       LOGGED_IN + " Tài khoản có mật khẩu.",
       ["1. Người dùng mở màn hình Thông tin đăng nhập từ Hồ sơ và chọn đổi mật khẩu.",
        "2. Người dùng nhập mật khẩu hiện tại, mật khẩu mới và nhập lại mật khẩu mới.",
        "3. Ứng dụng kiểm tra các ô không trống, mật khẩu mới đạt chính sách mật khẩu và khớp với ô nhập lại, rồi gửi yêu cầu tới Core Backend.",
        "4. Core Backend khóa bản ghi người dùng, kiểm tra mật khẩu hiện tại đúng và mật khẩu mới khác mật khẩu cũ.",
        "5. Core Backend lưu mật khẩu mới và tăng phiên bản thông tin đăng nhập (credentialsVersion) trong cùng một câu lệnh cập nhật, thu hồi mã truy cập đang dùng, ghi nhật ký AUTH_PASSWORD_CHANGED và cấp cặp mã mới.",
        "6. Ứng dụng lưu cặp mã mới và báo đổi mật khẩu thành công."],
       ["3a. Dữ liệu chưa hợp lệ: ứng dụng báo lỗi tương ứng, quay lại bước 2.",
        "4a. Mật khẩu hiện tại sai: Core Backend ghi nhật ký AUTH_PASSWORD_CHANGE_REJECTED và từ chối; ứng dụng báo lỗi, quay lại bước 2.",
        "4b. Mật khẩu mới trùng mật khẩu cũ: Core Backend từ chối; quay lại bước 2.",
        "5a. Thông tin đăng nhập vừa bị thay đổi bởi một yêu cầu khác: Core Backend trả lỗi xung đột, người dùng thực hiện lại."],
       "Mật khẩu mới có hiệu lực; mọi mã cấp trước đó cho tài khoản (trên mọi thiết bị) bị từ chối vì mang phiên bản thông tin đăng nhập cũ; thiết bị hiện tại tiếp tục dùng cặp mã mới."),
    uc("UC05", "Quên và đặt lại mật khẩu",
       "Người dùng quên mật khẩu nhận mã OTP (One-Time Password – mật khẩu dùng một lần) gồm 6 chữ số qua email và dùng mã này để đặt mật khẩu mới.",
       "Người dùng",
       "UC05 «extend» UC02.",
       "Người dùng chưa đăng nhập; email đã đăng ký tài khoản; thiết bị có kết nối mạng.",
       ["1. Trên màn hình Đăng nhập, người dùng chọn “Quên mật khẩu”.",
        "2. Người dùng nhập email; ứng dụng kiểm tra định dạng email và gửi yêu cầu cấp mã tới Core Backend.",
        "3. Core Backend sinh mã OTP 6 chữ số, lưu mã trong Redis [36] với thời hạn 5 phút (mã mới thay mã cũ), gửi mã qua email và ghi nhật ký.",
        "4. Ứng dụng chuyển tới màn hình Đặt lại mật khẩu; người dùng nhập mã OTP, mật khẩu mới và nhập lại mật khẩu mới.",
        "5. Core Backend kiểm tra mã OTP bằng một thao tác nguyên tử trên Redis, xóa mã đã dùng, lưu mật khẩu mới, tăng phiên bản thông tin đăng nhập và ghi nhật ký AUTH_PASSWORD_RESET.",
        "6. Ứng dụng báo đặt lại thành công và quay về màn hình Đăng nhập (không tự đăng nhập)."],
       ["2a. Email sai định dạng: ứng dụng báo lỗi, quay lại bước 2.",
        "3a. Email chưa đăng ký: Core Backend từ chối và ghi nhật ký; ứng dụng hiển thị thông báo của máy chủ.",
        "4a. Người dùng chọn gửi lại mã: nút gửi lại chỉ bấm được sau 60 giây đếm ngược; quay lại bước 3.",
        "5a. Mã sai: Core Backend báo số lần thử còn lại; sau 3 lần sai, mã bị hủy và người dùng phải yêu cầu mã mới.",
        "5b. Mã hết hạn hoặc không tồn tại: Core Backend yêu cầu gửi lại mã mới; quay lại bước 4a.",
        "5c. Kho Redis không truy cập được: Core Backend trả mã 503, ứng dụng báo dịch vụ tạm thời không sẵn sàng."],
       "Mật khẩu mới có hiệu lực; mã OTP không dùng lại được; mọi phiên đăng nhập cũ của tài khoản kết thúc."),
    uc("UC06", "Quản lý giao dịch",
       "Người dùng xem, tìm kiếm, lọc, thêm, sửa và xóa các khoản thu chi; mỗi thay đổi cập nhật số dư ví trên máy chủ.",
       "Người dùng",
       "UC07 «extend» UC06 (khi giao dịch chưa gửi được); UC11 «extend» UC06 (khi khoản chi vượt mốc ngân sách); UC09 «include» UC06.",
       "Người dùng đã đăng nhập (UC02). Thao tác thêm không cần kết nối mạng; xem danh sách mới nhất, sửa và xóa cần kết nối.",
       ["1. Người dùng mở Sổ giao dịch; ứng dụng tải giao dịch của người dùng từ Core Backend, gộp các giao dịch chưa đồng bộ trên thiết bị và hiển thị theo kỳ tuần hoặc tháng.",
        "2. Người dùng có thể tìm theo nội dung và lọc theo khoảng số tiền.",
        "3. Người dùng chọn thêm giao dịch, chọn loại thu hoặc chi, nhập số tiền, chọn danh mục, ngày và ghi chú, rồi lưu.",
        "4. Ứng dụng lưu bản ghi chờ đồng bộ kèm clientId vào SQLite và gửi lên Core Backend (chi tiết ở quy trình 2.2.2).",
        "5. Core Backend kiểm tra số tiền lớn hơn 0 và các trường bắt buộc, khóa bản ghi ví, cập nhật số dư, lưu giao dịch, kiểm tra ngân sách, ghi nhật ký TRANSACTION_CREATED.",
        "6. Ứng dụng đánh dấu bản ghi đã đồng bộ, báo thành công và cập nhật Sổ giao dịch, Tổng quan."],
       ["3a. Người dùng chọn một giao dịch đã đồng bộ và sửa số tiền, danh mục hoặc ghi chú: Core Backend khóa ví, điều chỉnh số dư theo chênh lệch, kiểm tra lại ngân sách và ghi nhật ký; ứng dụng báo “Đã lưu thay đổi”. Nếu không có thay đổi, ứng dụng báo và không gửi yêu cầu.",
        "3b. Người dùng chọn xóa một giao dịch và xác nhận: Core Backend khóa ví, hoàn lại ảnh hưởng của giao dịch lên số dư rồi xóa; giao dịch chưa từng đồng bộ chỉ bị xóa trên thiết bị.",
        "4a. Không gửi được: thực hiện UC07.",
        "5a. Dữ liệu không hợp lệ hoặc khoản chi lớn hơn số dư: Core Backend từ chối, ứng dụng báo lỗi; bản ghi gửi lần đầu bị xóa khỏi thiết bị.",
        "5b. clientId đã tồn tại: Core Backend trả lại giao dịch đã lưu, không trừ tiền lần hai.",
        "5c. Khoản chi đưa tỉ lệ chi tiêu của ngân sách vượt mốc 80% hoặc 100%: thực hiện UC11."],
       "Giao dịch được lưu, sửa hoặc xóa trên máy chủ và số dư ví thay đổi tương ứng trong cùng một giao dịch cơ sở dữ liệu; bộ nhớ đệm thống kê của người dùng bị xóa sau khi giao dịch cơ sở dữ liệu hoàn tất."),
    uc("UC07", "Đồng bộ giao dịch ngoại tuyến",
       "Giao dịch được tạo khi thiết bị mất mạng hoặc máy chủ lỗi được giữ trên thiết bị và gửi lại sau mà không tạo bản ghi trùng.",
       "Người dùng",
       "UC07 «extend» UC06 (điểm mở rộng: gửi giao dịch thất bại).",
       "Có ít nhất một giao dịch ở trạng thái chờ hoặc lỗi đồng bộ trong SQLite; người dùng đã đăng nhập.",
       ["1. Khi gửi giao dịch thất bại vì mất mạng, máy chủ lỗi 5xx hoặc mã 401, 408, 429, ứng dụng chuyển bản ghi sang trạng thái lỗi đồng bộ và hiển thị nó trong Sổ giao dịch kèm dấu hiệu chưa gửi.",
        "2. Khi ứng dụng được mở hoặc quay lại từ nền, khi người dùng kéo để làm mới Sổ giao dịch hoặc chạm lại tab Sổ giao dịch, ứng dụng gửi lại lần lượt mọi bản ghi chưa đồng bộ; chỉ một lượt gửi chạy tại một thời điểm.",
        "3. Mỗi bản ghi được gửi với clientId ban đầu (kèm kết quả AI và đường dẫn ảnh nếu là giao dịch từ hóa đơn).",
        "4. Core Backend lưu giao dịch hoặc, nếu clientId đã tồn tại, trả lại giao dịch đã lưu mà không cập nhật ví lần hai.",
        "5. Ứng dụng đánh dấu bản ghi đã đồng bộ và cập nhật các màn hình."],
       ["2a. Người dùng mở chi tiết giao dịch chưa gửi và chọn “Gửi lại”: ứng dụng gửi riêng bản ghi đó và báo kết quả.",
        "4a. Core Backend từ chối dữ liệu khi gửi lại: bản ghi được giữ ở trạng thái lỗi đồng bộ để người dùng xem và xóa.",
        "4b. Vẫn chưa gửi được: bản ghi giữ trạng thái lỗi, chờ lần gửi kế tiếp.",
        "5a. Danh sách từ máy chủ đã chứa clientId của một bản ghi cục bộ: ứng dụng bỏ bản ghi cục bộ khỏi danh sách hiển thị và đánh dấu đã đồng bộ, tránh hiện hai lần."],
       "Mỗi giao dịch tạo ngoại tuyến được ghi đúng một lần trên máy chủ; số dư ví chỉ thay đổi một lần cho mỗi clientId."),
    uc("UC08", "Quét hóa đơn",
       "Người dùng chụp hoặc chọn ảnh hóa đơn; AI Service trích xuất tên người bán, địa chỉ, thời gian và tổng tiền.",
       "Người dùng, AI Service",
       "UC08 «include» UC09.",
       LOGGED_IN + " Ứng dụng được cấp quyền camera hoặc thư viện ảnh.",
       ["1. Người dùng chọn nút quét trên thanh điều hướng, rồi chọn chụp bằng trình quét tài liệu hoặc chọn ảnh từ thư viện.",
        "2. Ứng dụng mở màn hình Xác nhận hóa đơn với ảnh vừa chụp hoặc chọn, ở trạng thái đang phân tích.",
        "3. Ứng dụng gửi ảnh tới AI Service (/donut/scan).",
        "4. AI Service chạy mô hình DONUT, chuyển chuỗi sinh ra thành bốn trường và tách số tiền từ trường tổng tiền.",
        "5. Ứng dụng điền kết quả vào biểu mẫu và thực hiện UC09."],
       ["1a. Người dùng hủy trình quét: use case kết thúc, không hiển thị lỗi.",
        "1b. Trình quét hoặc bộ chọn ảnh báo lỗi: ứng dụng hiển thị hộp thoại lỗi; use case kết thúc.",
        "4a. AI Service không phản hồi hoặc trả lỗi: ứng dụng báo quét thất bại, biểu mẫu để trống để nhập tay; tiếp tục UC09.",
        "4b. Không đọc được tổng tiền: ô tổng tiền để trống, ứng dụng nhắc nhập tay."],
       "Biểu mẫu đối soát hiển thị ảnh và các trường AI đọc được; chưa có dữ liệu nào được ghi vào cơ sở dữ liệu."),
    uc("UC09", "Đối soát và lưu hóa đơn",
       "Người dùng đối chiếu kết quả AI với hóa đơn giấy, sửa thông tin và lưu thành một khoản chi kèm ảnh và hồ sơ hóa đơn.",
       "Người dùng",
       "UC08 «include» UC09; UC09 «include» UC06 (lưu theo đường xử lý thêm giao dịch, nên UC07 và UC11 cũng có thể xảy ra).",
       "UC08 đã hiển thị biểu mẫu đối soát.",
       ["1. Người dùng xem ảnh và các trường AI đọc, sửa tên cửa hàng, tổng tiền, chọn lại ngày giờ nếu cần và chọn danh mục chi.",
        "2. Người dùng chọn “Xác nhận & Lưu”; ứng dụng kiểm tra tổng tiền lớn hơn 0.",
        "3. Ứng dụng tải ảnh gốc lên Core Backend (một lần cho mỗi biểu mẫu); Core Backend lưu ảnh trên Cloudinary và trả đường dẫn.",
        "4. Ứng dụng tạo khoản chi với clientId mới kèm kết quả gốc của AI và đường dẫn ảnh, lưu vào SQLite và gửi lên Core Backend.",
        "5. Core Backend lưu giao dịch như UC06 và tạo hồ sơ hóa đơn trạng thái COMPLETED_RAW; thời gian và địa chỉ AI đọc được dùng làm ngày và nơi giao dịch.",
        "6. Sau khi giao dịch cơ sở dữ liệu hoàn tất, Core Backend ghi kết quả gốc của AI vào MongoDB [37].",
        "7. Ứng dụng báo lưu thành công, đóng biểu mẫu; Sổ giao dịch hiển thị giao dịch kèm nhãn trạng thái hóa đơn."],
       ["2a. Tổng tiền không hợp lệ: ứng dụng báo lỗi, quay lại bước 1.",
        "3a. Tải ảnh thất bại: ứng dụng hỏi “Lưu không kèm ảnh” hoặc “Để sau”; chọn “Để sau” thì quay lại bước 1.",
        "4a. Không gửi được lên máy chủ: ứng dụng báo giao dịch đã lưu trên thiết bị và sẽ gửi lại (UC07); biểu mẫu đóng lại.",
        "5a. Dữ liệu không hợp lệ hoặc số dư không đủ: Core Backend từ chối, ứng dụng báo lưu thất bại và giữ biểu mẫu.",
        "5b. Kết quả AI không có tổng tiền hợp lệ: hồ sơ hóa đơn được lưu trạng thái FAILED với mã lý do AI_NO_TOTAL hoặc AI_UNREADABLE.",
        "1a. Người dùng quay lại mà không lưu: không có dữ liệu nào được ghi."],
       "Một khoản chi và một hồ sơ hóa đơn gắn với nó được lưu; số dư ví giảm đúng bằng tổng tiền đã xác nhận; hóa đơn chờ quản trị viên duyệt (UC19)."),
    uc("UC10", "Quản lý ngân sách",
       "Người dùng tạo, xem, sửa và xóa hạn mức chi theo danh mục (hoặc tất cả danh mục) cho kỳ tuần hoặc tháng.",
       "Người dùng",
       "Không có. Kết quả của UC10 là đầu vào của UC11.",
       LOGGED_IN,
       ["1. Người dùng mở màn hình Ngân sách; ứng dụng tải danh sách ngân sách và danh mục chi từ Core Backend.",
        "2. Người dùng chọn thêm ngân sách, chọn danh mục hoặc tất cả danh mục, loại kỳ tuần hoặc tháng, ngày bắt đầu, ngày kết thúc và hạn mức.",
        "3. Core Backend kiểm tra hạn mức lớn hơn 0, ngày kết thúc không trước ngày bắt đầu, kỳ tuần không quá 7 ngày và kỳ tháng không quá 31 ngày.",
        "4. Core Backend kiểm tra danh mục tồn tại và chưa có ngân sách trùng (cùng người dùng, danh mục, loại kỳ, ngày bắt đầu), lưu ngân sách và ghi nhật ký BUDGET_CREATED.",
        "5. Ứng dụng hiển thị ngân sách kèm thanh tiến độ chi tiêu trên màn hình Ngân sách, Tổng quan và Sổ giao dịch."],
       ["2a. Người dùng sửa một ngân sách: các kiểm tra ở bước 3 và 4 được áp dụng lại.",
        "2b. Người dùng xóa một ngân sách: Core Backend xóa ngân sách và ghi nhật ký.",
        "3a. Dữ liệu không hợp lệ: Core Backend trả mã 400, ứng dụng báo lỗi; quay lại bước 2.",
        "4a. Ngân sách trùng: Core Backend trả mã 409, ứng dụng báo đã có ngân sách tương ứng; quay lại bước 2."],
       "Ngân sách được lưu, sửa hoặc xóa; các khoản chi sau đó được đối chiếu với ngân sách này."),
    uc("UC11", "Nhận cảnh báo ngân sách",
       "Khi một khoản chi làm tỉ lệ đã chi của ngân sách vượt mốc 80% hoặc 100%, hệ thống tạo thông báo và ứng dụng hiện hộp thoại cảnh báo.",
       "Người dùng",
       "UC11 «extend» UC06 (điểm mở rộng: sau khi lưu hoặc sửa một khoản chi).",
       "Người dùng có ít nhất một ngân sách có kỳ chứa ngày của khoản chi (UC10).",
       ["1. Sau khi lưu hoặc sửa một khoản chi (UC06, UC09), Core Backend tìm các ngân sách cùng danh mục hoặc áp dụng cho tất cả danh mục có kỳ chứa ngày giao dịch.",
        "2. Với mỗi ngân sách, Core Backend so sánh tỉ lệ đã chi trước và sau khoản chi.",
        "3. Nếu tỉ lệ vượt từ dưới lên mốc 80%, Core Backend tạo thông báo BUDGET_WARNING; nếu đạt hoặc vượt 100%, tạo thông báo BUDGET_EXCEEDED. Thông báo được lưu trong cùng giao dịch cơ sở dữ liệu với khoản chi.",
        "4. Ứng dụng cập nhật số thông báo chưa đọc trên biểu tượng chuông.",
        "5. Ứng dụng tự tính tiến độ ngân sách từ danh sách giao dịch và hiện hộp thoại cảnh báo khi một ngân sách chạm mốc."],
       ["3a. Tỉ lệ đã vượt mốc từ trước: không tạo thêm thông báo cho mốc đó.",
        "3b. Một khoản chi vượt cả hai mốc cùng lúc: chỉ tạo một thông báo ở mốc 100%.",
        "5a. Hộp thoại đã hiện cho cùng ngân sách, kỳ, hạn mức và mức cảnh báo: không hiện lại."],
       "Thông báo cảnh báo được lưu và xem được trong UC15; trạng thái đã hiện hộp thoại được ghi nhớ trên thiết bị."),
    uc("UC12", "Xem thống kê",
       "Người dùng xem số dư, tổng thu, tổng chi, giao dịch gần đây, tiến độ ngân sách và biểu đồ thu chi theo kỳ.",
       "Người dùng",
       "Không có.",
       LOGGED_IN,
       ["1. Người dùng mở ứng dụng hoặc chọn tab Tổng quan.",
        "2. Ứng dụng lấy hồ sơ, danh sách giao dịch và ngân sách của người dùng từ Core Backend, gộp các giao dịch chưa đồng bộ trên thiết bị.",
        "3. Ứng dụng tính số dư hiện tại (tổng thu trừ tổng chi), tổng thu, tổng chi, tiến độ các ngân sách đang hiệu lực và hiển thị các giao dịch gần đây.",
        "4. Người dùng mở Sổ giao dịch, chọn kỳ tuần hoặc tháng; ứng dụng vẽ biểu đồ cột thu chi và tổng thu, tổng chi của kỳ.",
        "5. Khi có dữ liệu thay đổi (thêm, sửa, xóa giao dịch, ngân sách), các màn hình đang mở tự tải lại."],
       ["3a. Chưa có giao dịch: màn hình hiển thị “Chưa có giao dịch nào.”"],
       "Không thay đổi dữ liệu; số liệu hiển thị khớp với danh sách giao dịch hiện có."),
    uc("UC13", "Xem báo cáo thói quen chi tiêu",
       "Người dùng xem các mẫu chi tiêu lặp lại do AI Service khai phá bằng WCM-SPADE và các gợi ý ngân sách theo mục tiêu tiết kiệm.",
       "Người dùng, AI Service",
       "Không có. Dùng dữ liệu của UC06 và UC14.",
       LOGGED_IN,
       ["1. Người dùng mở tab AI; khoảng thời gian mặc định là tháng hiện tại.",
        "2. Ứng dụng lấy đồng thời danh sách giao dịch và mục tiêu tiết kiệm từ Core Backend.",
        "3. Ứng dụng gửi các giao dịch trong khoảng thời gian đang chọn tới AI Service (/spade/analyze).",
        "4. AI Service khai phá các mẫu chuỗi chi tiêu có độ dài tối đa 4 dựa trên cách biểu diễn id-list của SPADE [48], trả về mỗi mẫu dạng “A → B” kèm số lần xuất hiện, trọng số và độ hỗ trợ.",
        "5. Song song với bước 3, ứng dụng gửi giao dịch cùng mục tiêu tiết kiệm gần hạn nhất tới AI Service (/spade/recommend); AI Service trả về xu hướng, thống kê theo nhóm, gợi ý ngân sách và đoạn tóm tắt.",
        "6. Ứng dụng hiển thị mẫu chi tiêu, biểu đồ và gợi ý."],
       ["4a. Khoảng thời gian có ít hơn 3 khoản chi: AI Service trả danh sách mẫu rỗng kèm thông điệp giải thích.",
        "5a. Chưa có mục tiêu tiết kiệm: ứng dụng bỏ qua bước 5.",
        "6a. Người dùng đổi khoảng thời gian hoặc chọn “Làm mới”: ứng dụng chạy lại bước 3–4.",
        "6b. AI Service không phản hồi khi người dùng chủ động làm mới: ứng dụng báo lỗi bằng hộp thoại."],
       "Không thay đổi dữ liệu trên máy chủ; báo cáo phản ánh giao dịch của khoảng thời gian đang chọn."),
    uc("UC14", "Quản lý mục tiêu tiết kiệm",
       "Người dùng tạo mục tiêu tiết kiệm, cập nhật số tiền đã tiết kiệm, theo dõi tiến độ và xóa mục tiêu.",
       "Người dùng",
       "Không có. Mục tiêu tiết kiệm là đầu vào cho phần gợi ý ngân sách của UC13.",
       LOGGED_IN,
       ["1. Người dùng mở Sổ tiết kiệm từ màn hình Tổng quan; ứng dụng tải các mục tiêu của người dùng và hiển thị tổng tiến độ cùng tiến độ từng mục tiêu.",
        "2. Người dùng chọn thêm mục tiêu, nhập tên, số tiền mục tiêu, số tiền đã tiết kiệm và hạn chót.",
        "3. Ứng dụng kiểm tra tên không trống và số tiền mục tiêu lớn hơn 0, rồi gửi tới Core Backend.",
        "4. Core Backend lưu mục tiêu cho người dùng hiện tại và ghi nhật ký SAVING_CREATED.",
        "5. Ứng dụng tải lại danh sách và đánh dấu để tab AI tính lại gợi ý."],
       ["2a. Người dùng chạm vào một mục tiêu và nhập số tiền đã tiết kiệm mới: Core Backend kiểm tra mục tiêu thuộc người dùng, cập nhật và ghi nhật ký SAVING_UPDATED.",
        "2b. Người dùng vuốt hoặc nhấn giữ một mục tiêu để xóa: Core Backend kiểm tra quyền sở hữu, xóa và ghi nhật ký; ứng dụng báo đã xóa.",
        "3a. Tên trống hoặc số tiền mục tiêu không hợp lệ: ứng dụng không gửi yêu cầu, hộp thoại vẫn mở.",
        "2c. Mục tiêu không tồn tại (mã 400) hoặc thuộc người khác (mã 403): Core Backend từ chối."],
       "Mục tiêu tiết kiệm được lưu, cập nhật hoặc xóa; tiến độ hiển thị theo số tiền mới."),
    uc("UC15", "Xem thông báo",
       "Người dùng xem danh sách thông báo mới nhất trước, đánh dấu đã đọc từng thông báo hoặc tất cả, và mở màn hình liên quan.",
       "Người dùng",
       "Không có. Thông báo do UC11 tạo ra.",
       LOGGED_IN,
       ["1. Ứng dụng hiển thị số thông báo chưa đọc trên biểu tượng chuông ở màn hình Tổng quan.",
        "2. Người dùng chạm biểu tượng chuông; ứng dụng tải trang thông báo đầu tiên từ Core Backend (20 thông báo mỗi trang; máy chủ chấp nhận 1–50).",
        "3. Khi người dùng cuộn gần cuối danh sách, ứng dụng tải trang kế tiếp.",
        "4. Người dùng chạm một thông báo; ứng dụng hiển thị ngay là đã đọc, gửi yêu cầu đánh dấu đã đọc tới Core Backend và mở màn hình Ngân sách nếu là cảnh báo ngân sách."],
       ["4a. Đánh dấu đã đọc thất bại: ứng dụng hiển thị lại thông báo ở trạng thái chưa đọc.",
        "4b. Người dùng chọn đánh dấu tất cả đã đọc: Core Backend cập nhật mọi thông báo chưa đọc của người dùng và trả về số thông báo đã cập nhật.",
        "3a. Tải trang kế tiếp thất bại: ứng dụng hiện nút thử lại, không tự tải lại khi cuộn.",
        "2a. Người dùng kéo để làm mới: quay lại bước 2."],
       "Trạng thái đã đọc của thông báo được lưu trên máy chủ; số trên biểu tượng chuông giảm tương ứng."),
    uc("UC16", "Cài đặt ngôn ngữ và giao diện",
       "Người dùng chọn chế độ giao diện sáng, tối hoặc theo hệ thống và ngôn ngữ tiếng Việt hoặc tiếng Anh.",
       "Người dùng",
       "Không có.",
       "Ứng dụng đã được mở; không cần kết nối mạng.",
       ["1. Người dùng mở Cài đặt từ màn hình Hồ sơ.",
        "2. Người dùng chọn một chế độ giao diện: sáng, tối hoặc theo hệ thống.",
        "3. Ứng dụng áp dụng ngay chế độ đã chọn cho toàn bộ ứng dụng và lưu lựa chọn trên thiết bị.",
        "4. Người dùng chọn ngôn ngữ tiếng Việt hoặc tiếng Anh.",
        "5. Ứng dụng áp dụng ngay ngôn ngữ cho giao diện và cho các yêu cầu gửi lên máy chủ kế tiếp, rồi lưu lựa chọn."],
       ["3a. Lưu lựa chọn thất bại: lựa chọn vẫn có hiệu lực trong lần chạy hiện tại, ứng dụng báo không lưu được.",
        "1a. Lần mở ứng dụng sau: ứng dụng đọc lựa chọn đã lưu trước khi hiển thị màn hình đầu tiên."],
       "Chế độ giao diện và ngôn ngữ được lưu trên thiết bị và áp dụng cho các lần mở sau."),
]

ADMIN_UC = [
    ("p", "Mục này đặc tả 6 use case riêng của phân hệ quản trị (Bảng 2.26 đến Bảng 2.31). Mọi trang và yêu cầu AJAX dưới "
          "/admin/** đi qua chuỗi bộ lọc bảo mật riêng của Web Admin, chỉ chấp nhận phiên đăng nhập của tài khoản vai trò "
          "ROLE_ADMIN [32]; vì vậy điều kiện tiên quyết chung của các use case dưới đây là quản trị viên đã đăng nhập Web "
          "Admin (UC02, dòng 2b)."),
    ("y", "[Nhóm] UC17 mô tả chức năng ở Core Backend. Trên giao diện hiện tại, các nút thêm, sửa, xóa, khóa/mở khóa người "
          "dùng hoạt động ở danh sách tài khoản trong trang Hóa đơn (receipts.html); nút khóa ở trang Người dùng gọi sai "
          "đường dẫn (ghi chú mục 2.2.6). UC19 cần bổ sung nút Duyệt/Từ chối trên trang Hóa đơn (ghi chú mục 2.2.7)."),
    uc("UC17", "Quản lý người dùng",
       "Quản trị viên xem danh sách tài khoản, thêm, sửa, xóa và khóa hoặc mở khóa tài khoản người dùng.",
       "Quản trị viên",
       "Không có.",
       "Quản trị viên đã đăng nhập Web Admin.",
       ["1. Quản trị viên mở danh sách tài khoản; Core Backend trả về tài khoản theo trang (mặc định 10 dòng), mới nhất trước.",
        "2. Quản trị viên chọn thêm người dùng, nhập tên đăng nhập, email, số điện thoại, mật khẩu (tối thiểu 6 ký tự) và vai trò.",
        "3. Core Backend kiểm tra dữ liệu, mã hóa mật khẩu, lưu tài khoản và ghi nhật ký.",
        "4. Web Admin cập nhật danh sách."],
       ["2a. Quản trị viên sửa tên đăng nhập, email, số điện thoại hoặc vai trò của một tài khoản: Core Backend lưu và ghi nhật ký.",
        "2b. Quản trị viên khóa hoặc mở khóa một tài khoản sau khi xác nhận: Core Backend chuyển trạng thái và ghi nhật ký; tài khoản bị khóa không đăng nhập được và yêu cầu kế tiếp bằng mã cũ bị từ chối.",
        "2c. Quản trị viên xóa một tài khoản sau khi xác nhận: nếu tài khoản đã có giao dịch, Core Backend khóa tài khoản thay vì xóa và báo lại cho quản trị viên.",
        "2d. Thao tác khóa nhắm vào tài khoản ROLE_ADMIN: Core Backend từ chối.",
        "3a. Trùng tên đăng nhập, email hoặc số điện thoại: cơ sở dữ liệu từ chối bản ghi, Web Admin báo lỗi."],
       "Tài khoản được tạo, cập nhật, khóa, mở khóa hoặc xóa; mỗi thao tác có một dòng trong nhật ký hoạt động."),
    uc("UC18", "Quản lý danh mục mặc định",
       "Quản trị viên quản lý danh mục thu chi dùng chung cho mọi người dùng: thêm, đổi tên và xóa.",
       "Quản trị viên",
       "Không có. Danh mục được ứng dụng di động dùng trong UC06, UC09 và UC10.",
       "Quản trị viên đã đăng nhập Web Admin.",
       ["1. Quản trị viên mở trang Danh mục; Web Admin hiển thị toàn bộ danh mục.",
        "2. Quản trị viên chọn thêm, nhập tên và loại (thu hoặc chi).",
        "3. Core Backend lưu danh mục và ghi nhật ký CATEGORY_CREATED.",
        "4. Web Admin cập nhật danh sách; ứng dụng di động thấy danh mục mới ở lần tải danh mục kế tiếp."],
       ["2a. Quản trị viên đổi tên một danh mục: Core Backend lưu tên mới và ghi nhật ký.",
        "2b. Quản trị viên xóa một danh mục: nếu còn giao dịch dùng danh mục, Core Backend từ chối với thông báo danh mục đang được sử dụng; ngược lại xóa và ghi nhật ký.",
        "2c. Danh mục không tồn tại: Core Backend báo không tìm thấy danh mục."],
       "Danh sách danh mục được cập nhật; không giao dịch nào mất danh mục do thao tác xóa."),
    uc("UC19", "Duyệt hóa đơn AI",
       "Quản trị viên đối chiếu kết quả AI với ảnh gốc, duyệt để đối soát số tiền giao dịch theo tổng tiền hóa đơn hoặc từ chối hóa đơn.",
       "Quản trị viên",
       "Không có. Hóa đơn được tạo bởi UC09.",
       "Quản trị viên đã đăng nhập Web Admin; có hóa đơn ở trạng thái cho phép duyệt.",
       ["1. Quản trị viên mở trang Hóa đơn; Core Backend trả về danh sách hóa đơn mới nhất trước, gồm tên người bán, tổng tiền AI đọc, ảnh gốc và trạng thái.",
        "2. Quản trị viên mở ảnh gốc và đối chiếu với kết quả AI, rồi chọn duyệt.",
        "3. Core Backend khóa bản ghi ví của chủ hóa đơn, kiểm tra hóa đơn được phép chuyển sang APPROVED và có tổng tiền lớn hơn 0.",
        "4. Nếu số tiền giao dịch khác tổng tiền hóa đơn, Core Backend đặt lại số tiền, điều chỉnh số dư theo chênh lệch và kiểm tra lại ngân sách.",
        "5. Core Backend chuyển hóa đơn sang APPROVED, ghi nhật ký và Web Admin tải lại danh sách."],
       ["2a. Quản trị viên chọn từ chối: Core Backend chuyển hóa đơn sang FAILED với mã lý do REJECTED_BY_ADMIN và ghi nhật ký; số dư không đổi.",
        "3a. Hóa đơn đã hủy, ở trạng thái không thể duyệt, không có tổng tiền hợp lệ hoặc không gắn với giao dịch: Core Backend từ chối thao tác.",
        "3b. Hóa đơn vừa được cập nhật bởi yêu cầu khác (khóa lạc quan theo số phiên bản): Core Backend trả lỗi xung đột 409; quản trị viên tải lại và thực hiện lại.",
        "4a. Đối soát làm khoản chi vượt số dư ví: Core Backend từ chối, hóa đơn giữ nguyên trạng thái."],
       "Hóa đơn ở trạng thái APPROVED (giao dịch khớp tổng tiền hóa đơn) hoặc FAILED kèm mã lý do; người dùng thấy trạng thái mới qua nhãn trên Sổ giao dịch."),
    uc("UC20", "Xem nhật ký hoạt động",
       "Quản trị viên xem và lọc nhật ký các thao tác bảo mật và dữ liệu, và gỡ tạm khóa đăng nhập cho một tài khoản hoặc địa chỉ IP.",
       "Quản trị viên",
       "Không có. Nhật ký do mọi use case thay đổi dữ liệu và UC02 ghi ra.",
       "Quản trị viên đã đăng nhập Web Admin.",
       ["1. Quản trị viên mở trang Nhật ký; Web Admin hiển thị bảng tổng hợp, các sự kiện bảo mật gần nhất (đăng nhập, từ chối truy cập) và các sự kiện hệ thống, dữ liệu gần nhất.",
        "2. Quản trị viên lọc theo hành động, mã người dùng, email, loại và mã đối tượng, khoảng thời gian.",
        "3. Core Backend kiểm tra bộ lọc (trang 0–10000, mỗi trang 1–100 dòng) và trả về kết quả theo trang.",
        "4. Web Admin hiển thị kết quả."],
       ["2a. Quản trị viên chọn gỡ khóa đăng nhập cho một email hoặc địa chỉ IP: Core Backend xóa bộ đếm đăng nhập sai tương ứng và ghi nhật ký.",
        "3a. Bộ lọc không hợp lệ: Core Backend báo lỗi, không trả kết quả.",
        "1a. Ứng dụng khác gọi /api/admin/audit-logs bằng mã JWT của tài khoản ROLE_ADMIN: Core Backend trả cùng dữ liệu dạng JSON."],
       "Không thay đổi dữ liệu nghiệp vụ (trừ dòng 2a); nhật ký không sửa hay xóa được từ giao diện."),
    uc("UC21", "Xem thống kê hệ thống",
       "Quản trị viên xem số liệu toàn hệ thống và chạy phân khúc khách hàng theo mô hình RFM (Recency – Frequency – Monetary) [49].",
       "Quản trị viên, AI Service",
       "Không có.",
       "Quản trị viên đã đăng nhập Web Admin.",
       ["1. Quản trị viên mở trang Tổng quan.",
        "2. Core Backend tính tổng giá trị giao dịch, số người dùng, số người dùng có số dư thấp, số giao dịch trong tháng, danh sách người chi tiêu nhiều nhất, biểu đồ số giao dịch sáu tháng, tỉ lệ trạng thái hóa đơn và số người dùng theo từng phân khúc; các số liệu tổng hợp được đọc qua bộ nhớ đệm Redis [36] có thời hạn 45–60 giây.",
        "3. Quản trị viên chọn chạy phân khúc khách hàng.",
        "4. Core Backend tính độ gần, tần suất và giá trị chi tiêu của mỗi người dùng và gửi tới AI Service (/admin/segment).",
        "5. AI Service gán nhãn theo luật: CHURN, AT-RISK, VIP hoặc ACTIVE.",
        "6. Core Backend lưu nhãn cho từng người dùng, ghi nhật ký SYSTEM_SEGMENTATION_RUN; Web Admin báo phân lớp hoàn tất và hiển thị số người dùng theo phân khúc."],
       ["2a. Redis không truy cập được: Core Backend đọc thẳng từ PostgreSQL, trang vẫn hiển thị.",
        "5a. AI Service không phản hồi hoặc không trả kết quả: Core Backend trả mã 400 kèm thông báo lỗi; nhãn cũ được giữ nguyên."],
       "Số liệu hiển thị đúng tại thời điểm đọc (chậm tối đa bằng thời hạn bộ nhớ đệm); sau dòng 3–6, mỗi người dùng mang nhãn phân khúc mới."),
    uc("UC22", "Quản lý gói dịch vụ",
       "Quản trị viên quản lý các gói hội viên: thêm, sửa, bật/tắt hiển thị và xóa.",
       "Quản trị viên",
       "Không có.",
       "Quản trị viên đã đăng nhập Web Admin.",
       ["1. Quản trị viên mở trang Gói dịch vụ; Web Admin hiển thị toàn bộ gói.",
        "2. Quản trị viên chọn thêm gói, nhập tên gói, giá, số ngày hiệu lực, số lượt quét AI tối đa và chọn có bật phân tích WCM-SPADE hay không.",
        "3. Core Backend lưu gói ở trạng thái đang mở và ghi nhật ký.",
        "4. Web Admin cập nhật danh sách."],
       ["2a. Quản trị viên sửa thông tin một gói: Core Backend lưu và ghi nhật ký.",
        "2b. Quản trị viên bật hoặc tắt một gói: Core Backend đảo trạng thái mở/ẩn và ghi nhật ký.",
        "2c. Quản trị viên xóa một gói: Core Backend xóa và ghi nhật ký.",
        "2d. Gói không tồn tại: Core Backend báo không tìm thấy gói hội viên."],
       "Danh sách gói được cập nhật. Ở phiên bản hiện tại, số lượt quét AI và cờ WCM-SPADE của gói chỉ được lưu, chưa có thành phần nào dùng chúng để giới hạn chức năng của người dùng."),
    ("p", "Hai mươi hai use case trên phủ toàn bộ chức năng mà ứng dụng di động và Web Admin đang cung cấp. Các chức năng có "
          "trong mã nguồn nhưng chưa được giao diện nào gọi (ví dụ đường dẫn lọc giao dịch, bảng điều khiển tổng hợp của "
          "người dùng hay đường dẫn gửi phản hồi về hóa đơn) không được đưa vào danh sách. Các bảng đặc tả này là cơ sở để "
          "xây dựng sơ đồ lớp mức phân tích ở mục 2.4."),
]

SECTIONS = {
    "Các tác nhân của hệ thống": ACTORS,
    "Sơ đồ use case hệ thống": DIAGRAM,
    "Đặc tả use case phân hệ người dùng": USER_UC,
    "Đặc tả use case phân hệ quản trị": ADMIN_UC,
}

ABBREVIATIONS = [
    ("OTP", "One-Time Password", "Mật khẩu dùng một lần"),
    ("UC", "Use Case", "Ca sử dụng"),
]

# Đối chiếu mã nguồn (HEAD f50a6d2, 25/10/2026):
# - Xác thực: AuthController (register 400 trùng email/username/phone; login 401/429; social-login 401),
#   AuthService (OTP 6 số, 5 phút, 3 lần sai, Redis; changePassword khóa user, revoke, cấp mã mới; logout revoke 2 mã),
#   LoginAttemptService (5 lần, 15 phút), SocialAuthService (Google tokeninfo + aud, Facebook Graph), JwtUtil (15 phút/30 ngày).
#   Mobile: register_page, login, profile_page._logout (confirm, clearSession dù lỗi), account_credentials_screen,
#   forgot_password_page (EmailFormat), reset_password_page (cooldown 60 s).
# - Giao dịch/đồng bộ: TransactionService.create/update/delete (khóa ví, clientId), ledger_page (tìm, lọc số tiền, kỳ
#   tuần/tháng, xóa có xác nhận, Gửi lại), edit_transaction_page (số tiền, danh mục, ghi chú), AppRepository.resend*.
# - Hóa đơn: main_scaffold (DocumentScanner, ImagePicker, hủy bỏ qua), review_form_page (commit 4d7a9ee),
#   TransactionModel.toCheckoutJson (clientId, rawReceiptData, imageUrl), ReceiptProcessingService.attachReceipt.
# - Tiết kiệm: savings_page (thêm/sửa current/xóa bằng Dismissible hoặc nhấn giữ), SavingGoalService.findOwnedGoal.
# - Thông báo: notification_screen, notification_destination (chỉ BUDGET_* mở BudgetScreen).
# - Cài đặt: settings_screen, ThemeCubit/LanguageCubit.
# - Quản trị: AdminController (users trong receipts.html; categories; subscriptions; auditlog; security/unlock;
#   segmentation/run gọi /admin/segment), UserService (xóa -> khóa khi có giao dịch; không khóa ADMIN),
#   CategoryService (không xóa khi đang dùng), SubscriptionPlanService (maxAiScans/isWcmSpadeEnabled không được đọc ở đâu).
