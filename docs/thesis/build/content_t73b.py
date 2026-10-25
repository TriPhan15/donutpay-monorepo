# Nội dung phiên T7.3b: Chương 3, mục 3.6–3.10 (giao diện, lớp thiết kế, thiết kế chức năng, mô hình AI, kết chương).
# Đối chiếu mã nguồn tại HEAD 62e8efe ngày 25/10/2026: mobile-app/lib/screens/** (đọc bằng git show HEAD vì một phiên
# khác đang sửa i18n), lib/repositories/app_repository.dart, lib/services/remote_api_helper.dart;
# core-backend Controller/{AuthController, TransactionController, BudgetController, AdminController}.java,
# Service/{TransactionService, ReceiptProcessingService, OcrService, BudgetService, BudgetAlertService, LoginAttemptService,
# BackupService}.java, Entity/*.java, Config/SecurityConfig.java, resources/templates/admin/*.html;
# ai-service/ai_service.py (V3 đang phục vụ), ai-service/Version5/{model_config.py, labels.py, postprocess.py}.
# Trích dẫn: [5] DONUT, [12] SentencePiece, [33] Flutter, [40] HF Donut, [47] UML, [54] Jacobson OOSE,
# [48] SPADE, [49] RFM, [55] Thymeleaf, [56] Bootstrap 5.3, [57] Material Design 3, [58] Chart.js, [59] ML Kit, [60] Pydantic.
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = "T7.3b"
SRC = "nguồn: nhóm thực hiện"
NGUON = "Nguồn: nhóm thực hiện"
COUNTER_START = {("Hình", "3"): 4, ("Bảng", "3"): 24}


def shot(caption, screen, path):
    """Hình giữ chỗ cho ảnh chụp màn hình do nhóm cung cấp."""
    return ("fig", caption, "3", None, 0, SRC,
            f"[Nhóm] Chèn ảnh chụp màn hình {screen} ({path}).")


def diagram(caption, name, width=16.0):
    return ("fig", caption, "3", PNG + name, width, SRC, None)


MOBILE_SCREENS = [
    ["LoginScreen", "auth/login_page.dart", "Đăng nhập bằng email/mật khẩu hoặc Google, Facebook", "UC02"],
    ["RegisterScreen", "auth/register_page.dart", "Đăng ký tài khoản, kiểm tra độ mạnh mật khẩu", "UC01"],
    ["ForgotPasswordScreen", "auth/forgot_password_page.dart", "Nhập email để nhận mã OTP", "UC05"],
    ["ResetPasswordScreen", "auth/reset_password_page.dart", "Nhập OTP 6 chữ số và mật khẩu mới", "UC05"],
    ["DashboardPage", "dashboard/dashboard_page.dart", "Trang chủ: số dư, ngân sách, tiện ích, giao dịch gần đây", "UC12"],
    ["LedgerPage", "ledger/ledger_page.dart", "Sổ sách: danh sách, lọc, chi tiết, gửi lại giao dịch chưa đồng bộ", "UC06, UC07"],
    ["AddTransactionPage", "ledger/add_transaction_page.dart", "Thêm giao dịch thu hoặc chi", "UC06"],
    ["EditTransactionPage", "ledger/edit_transaction_page.dart", "Sửa số tiền, danh mục, ghi chú của giao dịch", "UC06"],
    ["ReviewFormPage", "receipt_scanner/review_form_page.dart", "Đối soát kết quả quét hóa đơn và lưu giao dịch", "UC08, UC09"],
    ["BudgetScreen", "budget/budget_screen.dart", "Danh sách và tiến độ ngân sách", "UC10"],
    ["AITabPage", "ai/ai_tab_page.dart", "Thống kê và phân tích thói quen chi tiêu", "UC12, UC13"],
    ["NotificationScreen", "notifications/notification_screen.dart", "Danh sách thông báo, đánh dấu đã đọc", "UC11, UC15"],
    ["ProfilePage", "profile/profile_page.dart", "Trang cá nhân, lối vào các cài đặt, đăng xuất", "UC03"],
    ["SettingsScreen", "profile/settings_screen.dart", "Chọn giao diện sáng/tối và ngôn ngữ", "UC16"],
    ["SavingsPage", "profile/savings_page.dart", "Quản lý mục tiêu tiết kiệm", "UC14"],
    ["AccountCredentialsScreen", "profile/account_credentials_screen.dart", "Xem tài khoản, đổi mật khẩu", "UC04"],
    ["AccountInfoScreen, UserInfoScreen, SetUserInfoScreen", "profile/*.dart",
     "Thông tin tài khoản, xem và sửa họ tên, số điện thoại", "–"],
    ["LinkedServicesPage", "linked/linked_services_page.dart", "Nạp tiền từ ví điện tử liên kết vào ví ứng dụng", "–"],
    ["PaymentHistoryScreen", "payment/payment_history_screen.dart", "Lịch sử đơn nạp/rút, hủy đơn đang chờ", "–"],
]

ADMIN_PAGES = [
    ["/admin/login", "login.html", "Đăng nhập quản trị (form login của Spring Security)"],
    ["/admin/dashboard", "dashboard.html", "Thẻ tổng quan, biểu đồ, top người chi tiêu, phân khúc RFM"],
    ["/admin/categories", "categories.html", "Thêm, đổi tên, xóa danh mục thu chi"],
    ["/admin/subscriptions", "subscriptions.html", "Quản lý gói hội viên PRO"],
    ["/admin/receipts", "receipts.html", "Danh sách hóa đơn AI và danh sách tài khoản"],
    ["/admin/reviews", "reviews.html", "Duyệt hoặc xóa đánh giá ứng dụng"],
    ["/admin/auditlog", "auditlog.html", "Tra cứu nhật ký dữ liệu và bảo mật, gỡ khóa đăng nhập"],
    ["/admin/backup", "backup.html", "Sao lưu và phục hồi CSDL PostgreSQL"],
]

SECTIONS = {
    # ------------------------------------------------------------------------------------------------ 3.6 Giao diện
    "Giao diện ứng dụng di động": [
        ("p", "Ứng dụng di động được xây dựng bằng Flutter [33] theo hệ thống thiết kế Material 3 [57] (useMaterial3 = true, "
              "bảng màu sinh từ ColorScheme.fromSeed, phông chữ Poppins). Mỗi màn hình có hai bộ màu sáng và tối. Ứng dụng hỗ trợ tiếng Việt và tiếng "
              "Anh qua tệp ARB, nhưng tại thời điểm viết, một phần chuỗi của các màn hình đăng ký, đăng nhập, sổ sách, quét hóa "
              "đơn và phân tích AI vẫn viết cứng bằng tiếng Việt. Sau khi đăng nhập, người dùng vào MainScaffold: khung này giữ "
              "bốn tab Trang chủ (DashboardPage), Thống kê (LedgerPage, tiêu đề màn hình là Sổ sách), AI (AITabPage) và Cá nhân "
              "(ProfilePage) trong một IndexedStack (ngăn xếp chỉ hiển thị một con) để không dựng lại tab khi chuyển qua lại, "
              "và đặt nút tròn Quét AI ở giữa thanh điều hướng. Bảng 3.25 liệt kê các màn hình cùng use case "
              "ở Chương 2 mà mỗi màn hình hiện thực."),
        ("table", "Danh sách màn hình của ứng dụng di động", "3", [2300, 2500, 2904, 800],
         ["Màn hình (lớp)", "Tệp trong lib/screens", "Chức năng", "Use case"], MOBILE_SCREENS, NGUON),
        ("p", "Hình 3.5 thể hiện đường đi giữa các màn hình chính. Luồng xác thực là một nhánh riêng: chỉ khi đăng nhập thành "
              "công, ứng dụng mới thay toàn bộ ngăn xếp điều hướng bằng MainScaffold (lệnh pushAndRemoveUntil, đẩy màn hình mới và xóa các màn "
              "hình cũ), nên nút quay lại "
              "không đưa người dùng về màn hình đăng nhập."),
        diagram("Sơ đồ điều hướng giữa các màn hình của ứng dụng di động", "ch3_dieu_huong_di_dong.png", 16.0),
        ("h4", "Nhóm màn hình xác thực"),
        ("p", "Màn hình Đăng nhập (Hình 3.6) gồm logo, hai ô Email và Mật khẩu, ô chọn Ghi nhớ đăng nhập (hiện chưa có tác dụng: giá trị không được lưu), liên kết Quên mật "
              "khẩu, nút Đăng nhập và hai nút đăng nhập bằng Google, Facebook. Khi thiếu dữ liệu, ứng dụng báo “Thiếu thông "
              "tin” mà không gửi yêu cầu; khi máy chủ trả 401, hộp thoại hiển thị “Sai email hoặc mật khẩu!”. Màn hình Đăng ký "
              "(Hình 3.7) có các ô Họ và tên, Email, Số điện thoại, Mật khẩu; ngay dưới ô mật khẩu là danh sách năm điều kiện "
              "(độ dài tối thiểu, chữ hoa, chữ thường, chữ số, ký tự đặc biệt) được đánh dấu khi người dùng gõ. Danh sách "
              "này chặt hơn quy tắc @StrongPassword ở máy chủ, vốn chỉ yêu cầu 8–72 ký tự gồm ít nhất một chữ cái và một chữ số."),
        shot("Màn hình Đăng nhập", "LoginScreen", "lib/screens/auth/login_page.dart"),
        shot("Màn hình Đăng ký", "RegisterScreen", "lib/screens/auth/register_page.dart"),
        ("p", "Khôi phục mật khẩu đi qua hai màn hình. Màn hình Quên mật khẩu (Hình 3.8) chỉ có ô Email và nút Gửi mã OTP. "
              "Màn hình Đặt lại mật khẩu (Hình 3.9) hiển thị email đã che bớt, ô mã OTP 6 chữ số, hai ô mật khẩu mới và nút gửi "
              "lại mã có đếm ngược 60 giây. Trong lúc đang đặt lại, thao tác quay lại bị chặn; khi thành công, ứng dụng quay về "
              "màn hình Đăng nhập và không tự tạo phiên."),
        shot("Màn hình Quên mật khẩu", "ForgotPasswordScreen", "lib/screens/auth/forgot_password_page.dart"),
        shot("Màn hình Đặt lại mật khẩu", "ResetPasswordScreen", "lib/screens/auth/reset_password_page.dart"),
        ("h4", "Màn hình Trang chủ"),
        ("p", "Trang chủ (Hình 3.10) xếp theo chiều dọc: lời chào và chuông thông báo có số chưa đọc; thẻ Số dư hiện tại kèm "
              "mức thay đổi so với tháng trước; khối Ngân sách với thanh tiến độ từng ngân sách; lưới Tiện ích (Báo cáo, Sổ tiết "
              "kiệm, Tất cả) và danh sách Giao dịch gần đây, trong đó ngày được ghi “Hôm nay”, “Hôm qua” khi phù hợp. Kéo "
              "xuống để làm mới; khi đang tải, các khối được thay bằng khung xương (skeleton)."),
        shot("Màn hình Trang chủ", "DashboardPage (tab Trang chủ)", "lib/screens/dashboard/dashboard_page.dart"),
        ("h4", "Nhóm màn hình sổ sách và giao dịch"),
        ("p", "Màn hình Sổ sách (Hình 3.11) có ô tìm kiếm theo tên và danh mục, nút Lịch mở hộp chọn ngày, dải ngày trong tuần, "
              "bộ chọn kỳ Tuần/Tháng, biểu đồ cột Thu nhập/Chi tiêu, thẻ Tổng kết (tổng thu, tổng chi, số dư) kèm nút xuất tệp Excel và danh sách giao "
              "dịch của kỳ. Bảng Bộ lọc & Sắp xếp cho phép lọc theo loại giao dịch, khoảng tiền và sắp xếp theo mới nhất, cũ nhất "
              "hoặc giá trị cao nhất. Chạm vào một giao dịch mở bảng chi tiết (Hình 3.12) gồm số tiền, thời gian, trạng thái hóa "
              "đơn, trạng thái đồng bộ, ảnh hóa đơn gốc và các nút Sửa, Xóa; với giao dịch chưa được máy chủ xác nhận, bảng có "
              "thêm nút Gửi lại."),
        shot("Màn hình Sổ sách", "LedgerPage (tab Thống kê)", "lib/screens/ledger/ledger_page.dart"),
        shot("Bảng chi tiết giao dịch", "bảng chi tiết mở từ LedgerPage, chọn một giao dịch có hóa đơn và một giao dịch "
             "“chưa đồng bộ”", "lib/screens/ledger/ledger_page.dart"),
        ("p", "Màn hình Thêm giao dịch (Hình 3.13) có công tắc Tiền chi/Tiền thu, ô số tiền lớn ở đầu trang, ô danh mục mở danh "
              "sách chọn, ô ngày giao dịch và ô ghi chú. Màn hình Sửa giao dịch (Hình 3.14) chỉ cho sửa số tiền, danh mục và ghi "
              "chú, và từ chối lưu khi không có thay đổi nào."),
        shot("Màn hình Thêm giao dịch", "AddTransactionPage", "lib/screens/ledger/add_transaction_page.dart"),
        shot("Màn hình Sửa giao dịch", "EditTransactionPage", "lib/screens/ledger/edit_transaction_page.dart"),
        ("h4", "Nhóm màn hình quét hóa đơn"),
        ("p", "Nút Quét AI mở bảng chọn nguồn ảnh (Hình 3.15) với hai lựa chọn: Quét AI dùng trình quét tài liệu ML Kit [59] để cắt "
              "khung hóa đơn, Từ thư viện chọn ảnh có sẵn. Sau khi có ảnh, màn hình Xác nhận hóa đơn (Hình 3.16) hiển thị trạng "
              "thái “Đang phân tích hóa đơn...” trong lúc chờ AI Service, sau đó là biểu mẫu đối soát gồm ảnh hóa đơn, nhóm "
              "Thông tin chung (tên cửa hàng, tổng tiền, ngày giao dịch, danh mục) và thẻ Tổng kết (tạm tính, thuế, tổng tiền). "
              "Khi AI không đọc được tổng tiền, ô tổng tiền để trống kèm lời nhắc nhập tay; khi không đọc được ngày, ô ngày lấy "
              "thời điểm hiện tại và hiện chú thích cảnh báo."),
        shot("Bảng chọn nguồn ảnh hóa đơn", "bảng mở từ nút Quét AI của MainScaffold", "lib/screens/main_scaffold.dart"),
        shot("Màn hình Xác nhận hóa đơn", "ReviewFormPage, chụp sau khi AI trả kết quả", "lib/screens/receipt_scanner/review_form_page.dart"),
        ("h4", "Nhóm màn hình ngân sách"),
        ("p", "Màn hình Ngân sách (Hình 3.17) liệt kê các ngân sách, mỗi thẻ gồm danh mục, kỳ, số đã chi trên hạn mức và thanh "
              "tiến độ đổi màu khi đạt 80% và 100%. Nút Thiết lập ngân sách mở bảng nhập (Hình 3.18) có ô số tiền, lựa chọn kỳ "
              "Tuần/Tháng, kỳ áp dụng Tuần này/Tháng này và danh sách chip (nhãn chọn) danh mục, trong đó có lựa chọn “Tất cả danh mục”."),
        shot("Màn hình Ngân sách", "BudgetScreen", "lib/screens/budget/budget_screen.dart"),
        shot("Bảng thiết lập ngân sách", "BudgetFormSheet", "lib/screens/budget/budget_form_sheet.dart"),
        ("h4", "Màn hình phân tích AI"),
        ("p", "Tab AI (Hình 3.19), lớp AITabPage, có bộ chọn khoảng thời gian ở thanh tiêu đề và nút làm mới. Nội dung "
              "gồm thẻ “Hôm nay tiêu được bao nhiêu?” (số tiền an toàn mỗi ngày còn lại của tháng), các thẻ nhận định Xu hướng "
              "chi tiêu, Chi nhiều nhất, Mẹo tiết kiệm, So sánh tuần, biểu đồ cột thu chi theo tuần, thẻ Mẫu Chi Tiêu Tuần Tự liệt kê các mẫu "
              "chuỗi do WCM-SPADE [48] tìm được kèm tần suất và độ hỗ trợ có trọng số, và thẻ gợi ý phân bổ khi người "
              "dùng có mục tiêu tiết kiệm. Khi chưa có giao dịch, màn hình chỉ hiển thị thông báo “Chưa có dữ liệu”."),
        shot("Màn hình phân tích AI", "AITabPage (tab AI)", "lib/screens/ai/ai_tab_page.dart"),
        ("h4", "Màn hình Thông báo"),
        ("p", "Màn hình Thông báo (Hình 3.20) là danh sách tải theo trang, thông báo chưa đọc được tô nổi và gắn nhãn Chưa đọc; "
              "nút Đọc tất cả trên thanh tiêu đề đánh dấu toàn bộ. Chạm vào một thông báo đánh dấu nó đã đọc; với thông báo ngân sách, ứng dụng "
              "mở màn hình Ngân sách, còn thông báo giao dịch và thông báo hóa đơn chưa có màn hình đích nên chỉ hiện lời báo "
              "“Chưa thể mở chi tiết của thông báo này”."),
        shot("Màn hình Thông báo", "NotificationScreen", "lib/screens/notifications/notification_screen.dart"),
        ("h4", "Nhóm màn hình cá nhân"),
        ("p", "Trang Cá nhân (Hình 3.21) là danh sách nhóm dòng: Tài khoản (Thông tin tài khoản), Tiện ích (Nguồn tiền, Dịch vụ liên "
              "kết, Sổ tiết kiệm, Ngân sách), Cài đặt (Ngôn ngữ, Giao diện, Thông báo, Bảo mật) và Hỗ trợ (Hướng dẫn sử dụng, Gửi phản "
              "hồi, Về ứng dụng), cuối trang là nút Đăng xuất có hộp thoại xác nhận. Màn hình Cài đặt (Hình 3.22) cho chọn giao "
              "diện theo thiết bị, sáng hoặc tối, và ngôn ngữ tiếng Việt hoặc tiếng Anh; thay đổi được áp dụng ngay."),
        shot("Màn hình Cá nhân", "ProfilePage (tab Cá nhân)", "lib/screens/profile/profile_page.dart"),
        shot("Màn hình Cài đặt", "SettingsScreen", "lib/screens/profile/settings_screen.dart"),
        ("p", "Màn hình Sổ tiết kiệm (Hình 3.23) có thẻ tổng đã tiết kiệm trên tổng mục tiêu, danh sách mục tiêu với thanh tiến "
              "độ và hạn chót; vuốt một mục để xóa, chạm để cập nhật số đã tiết kiệm. Màn hình Tài khoản (Hình 3.24) hiển thị tên "
              "đăng nhập và cho đổi mật khẩu qua hộp nhập mật khẩu cũ, mật khẩu mới và xác nhận."),
        shot("Màn hình Sổ tiết kiệm", "SavingsPage", "lib/screens/profile/savings_page.dart"),
        shot("Màn hình Tài khoản và đổi mật khẩu", "AccountCredentialsScreen, kèm hộp thoại Đổi mật khẩu",
             "lib/screens/profile/account_credentials_screen.dart"),
        ("p", "Màn hình Dịch vụ liên kết (Hình 3.25) liệt kê ví điện tử đã liên kết; chọn một ví mở hộp nhập số tiền (tối thiểu "
              "1.000 ₫) rồi tạo đơn thanh toán qua cổng giả lập và theo dõi trạng thái đơn. Màn hình Lịch sử nạp/rút (Hình 3.26) "
              "liệt kê các đơn kèm mã đơn và nút hủy đơn chưa hoàn tất. Ba màn hình thông tin cá nhân (Hình 3.27) hiển thị email, "
              "họ tên, số điện thoại và cho sửa họ tên, số điện thoại (số gồm 10 chữ số, bắt đầu bằng 0)."),
        shot("Màn hình Dịch vụ liên kết", "LinkedServicesPage", "lib/screens/linked/linked_services_page.dart"),
        shot("Màn hình Lịch sử nạp/rút", "PaymentHistoryScreen", "lib/screens/payment/payment_history_screen.dart"),
        shot("Các màn hình thông tin cá nhân", "AccountInfoScreen, UserInfoScreen và SetUserInfoScreen (ghép 3 ảnh)",
             "lib/screens/profile/account_info_screen.dart, user_info_screen.dart, set_user_info.dart"),
    ],
    "Giao diện Web Admin": [
        ("p", "Web Admin là các trang Thymeleaf [55] do Core Backend sinh ở phía máy chủ, dùng Bootstrap 5.3 [56] cho bố cục và "
              "Chart.js [58] cho biểu đồ. Mọi trang dùng chung khung layout/_layout.html: thanh trên có tiêu đề trang và nút Đăng xuất, "
              "thanh bên trái có bảy mục Bảng điều khiển, Quản lý Danh mục, Quản lý Gói Hội viên, Quản lý User & Hóa đơn AI, Quản "
              "lý Đánh giá, Nhật ký Hệ thống, Backup Dữ liệu. Khác với ứng dụng di động dùng JWT, Web Admin dùng chuỗi bộ lọc riêng "
              "của Spring Security với đăng nhập bằng biểu mẫu và phiên làm việc; mọi đường dẫn /admin/** yêu cầu vai trò "
              "ROLE_ADMIN. Các thao tác thêm, sửa, xóa trên trang gọi các endpoint /admin/ajax/** bằng hàm fetch (gửi yêu cầu HTTP từ JavaScript) rồi cập nhật bảng. "
              "Bảng 3.26 liệt kê các trang."),
        ("table", "Danh sách trang của Web Admin", "3", [2200, 2000, 4304],
         ["Đường dẫn", "Template", "Chức năng"], ADMIN_PAGES, NGUON),
        ("p", "Trang Đăng nhập (Hình 3.28) gồm hai ô Tài khoản, Mật khẩu và nút Đăng nhập hệ thống; sau năm lần nhập sai, tài "
              "khoản hoặc địa chỉ IP bị khóa 15 phút như ở ứng dụng di động. Bảng điều khiển (Hình 3.29) có bốn thẻ số liệu (Tổng "
              "dòng tiền, Tổng user, Hóa đơn tháng này, User sắp cạn ví dưới 50.000 ₫), biểu đồ cột số hóa đơn sáu tháng, biểu "
              "đồ tròn tỉ lệ xử lý hóa đơn AI, bảng top 5 người chi tiêu nhiều nhất, danh sách người dùng sắp cạn ví và khối Phân "
              "khúc khách hàng RFM [49] gồm bảng 10 người dùng đã gán nhãn AI, với nút Chạy phân lớp AI tự động, biểu đồ tỉ trọng các nhãn VIP, ACTIVE, AT-RISK, CHURN."),
        shot("Trang đăng nhập Web Admin", "/admin/login", "templates/admin/login.html"),
        shot("Trang Bảng điều khiển", "/admin/dashboard", "templates/admin/dashboard.html"),
        ("p", "Trang Danh mục (Hình 3.30) là bảng ID, tên, loại (Khoản Thu/Khoản Chi), ngày tạo với nút Sửa, Xóa và hộp thoại "
              "tạo danh mục. Trang Gói hội viên PRO (Hình 3.31) quản lý tên gói, giá, thời hạn theo ngày, giới hạn số lần quét AI "
              "và cờ bật khai phá WCM-SPADE."),
        shot("Trang Quản lý danh mục", "/admin/categories", "templates/admin/categories.html"),
        shot("Trang Quản lý gói hội viên", "/admin/subscriptions", "templates/admin/subscriptions.html"),
        ("p", "Trang Quản lý User & Hóa đơn AI (Hình 3.32) có hai bảng phân trang. Bảng Danh sách hóa đơn AI gồm ID, tên cửa hàng, "
              "số tiền AI đọc được, nút xem ảnh gốc và trạng thái (Thành công, Lỗi AI, Đang xử lý). Bảng Danh sách tài khoản gồm "
              "username, email, số điện thoại, vai trò và các nút Sửa, Xóa, Khóa/Mở khóa, cùng nút Thêm người dùng."),
        ("y", "[Nhóm] receipts.html chưa có nút Duyệt/Từ chối cho từng hóa đơn, trong khi endpoint POST /admin/receipts/approve/{id} "
              "và /admin/receipts/reject/{id} đã có (xem mục 3.8.6). Nếu nhóm thêm nút trước khi chụp ảnh, cập nhật đoạn này; "
              "trang /admin/users (users.html) không có trên thanh bên và nút khóa của nó gọi /api/admin/users/{id}/toggle-status "
              "không tồn tại, nên không đưa vào bảng."),
        shot("Trang Quản lý User & Hóa đơn AI", "/admin/receipts", "templates/admin/receipts.html"),
        ("p", "Trang Đánh giá (Hình 3.33) liệt kê đánh giá từ ứng dụng với số sao, nội dung, trạng thái Chờ duyệt/Đã duyệt và nút "
              "Duyệt, Xóa. Trang Nhật ký hệ thống (Hình 3.34) chia thành các thẻ Dữ liệu (CRUD), Bảo mật, Thống kê và Tra cứu nâng "
              "cao; thẻ tra cứu lọc theo người thực hiện, loại và mã đối tượng, khoảng thời gian, và thẻ Bảo mật có nút Gỡ khóa "
              "cho tài khoản đang bị khóa đăng nhập. Trang Sao lưu (Hình 3.35) có ba nút sao lưu và một nút phục hồi kèm cảnh báo "
              "xác nhận. Ba nút sao lưu ghi nhãn FULL, DIFFERENTIAL và LOG nhưng đều chạy cùng một lệnh pg_dump "
              "toàn bộ CSDL ở định dạng custom; loại sao lưu chỉ khác nhau ở tên tệp."),
        shot("Trang Quản lý đánh giá", "/admin/reviews", "templates/admin/reviews.html"),
        shot("Trang Nhật ký hệ thống", "/admin/auditlog, thẻ Bảo mật", "templates/admin/auditlog.html"),
        shot("Trang Sao lưu và phục hồi dữ liệu", "/admin/backup", "templates/admin/backup.html"),
    ],
    # ------------------------------------------------------------------------------------------- 3.7 Lớp thiết kế
    "SƠ ĐỒ LỚP MỨC THIẾT KẾ": [
        ("p", "Sơ đồ lớp mức thiết kế bổ sung cho sơ đồ lớp phân tích ở mục 2.4 kiểu dữ liệu cụ thể của thuộc tính, phạm vi truy "
              "cập, phương thức và các lớp kỹ thuật không xuất hiện ở mức phân tích [47]. Nhóm chia sơ đồ thành ba phần để mỗi "
              "hình đọc được ở khổ giấy A4: lớp thực thể của Core Backend, các lớp điều khiển và dịch vụ của Core Backend, và tầng "
              "truy cập dữ liệu của ứng dụng di động."),
        ("p", "Hình 3.36 trình bày các lớp thực thể JPA. Tiền được biểu diễn bằng BigDecimal, ngày giờ bằng LocalDateTime hoặc "
              "LocalDate. Trạng thái hóa đơn được lưu dạng chuỗi nhưng chỉ đổi qua phương thức moveTo() và failWith() của Receipt, "
              "hai phương thức này kiểm tra bảng chuyển trạng thái của kiểu liệt kê ReceiptStatus; trạng thái PROCESSING được "
              "khai báo nhưng chưa có luồng nào chuyển tới nên không vẽ. Thuộc tính version của Receipt phục vụ khóa lạc quan, "
              "còn categoryKey của Budget là khóa danh mục dùng cho ràng buộc duy nhất ở mục 3.3.4 (0 nghĩa là tất cả danh mục)."),
        diagram("Sơ đồ lớp mức thiết kế – lớp thực thể của Core Backend", "ch3_lop_thiet_ke_thuc_the.png", 11.5),
        ("p", "Hình 3.37 trình bày ba tầng của Core Backend. Controller chỉ nhận yêu cầu, kiểm tra dữ liệu bằng @Valid và gọi "
              "service; service giữ toàn bộ nghiệp vụ trong giao dịch @Transactional; repository là các interface Spring Data JPA. "
              "Người dùng hiện tại luôn được CurrentUserProvider lấy từ SecurityContext. TransactionService là lớp trung tâm: nó "
              "khóa dòng ví bằng PESSIMISTIC_WRITE (lockWallet) trước khi đổi số dư khi sửa, xóa, duyệt giao dịch, và khi tạo "
              "giao dịch có clientId (ứng dụng di động luôn gửi), gọi ReceiptProcessingService khi "
              "giao dịch có hóa đơn và gọi BudgetAlertService sau khi lưu để sinh cảnh báo ngân sách. Riêng đăng nhập vẫn được xử lý "
              "ngay trong AuthController (mục 3.8.1)."),
        diagram("Sơ đồ lớp mức thiết kế – tầng điều khiển, dịch vụ và truy cập dữ liệu của Core Backend",
                "ch3_lop_thiet_ke_dich_vu.png", 16.0),
        ("p", "Ở ứng dụng di động (Hình 3.38), các màn hình không gọi thẳng Dio mà đi qua AppRepository và RemoteApiHelper. "
              "AppRepository quyết định một giao dịch mới được ghi vào bảng SQLite cục bộ trước rồi mới gửi lên máy chủ, và cập "
              "nhật cờ SyncStatus (pending, synced, error) theo kết quả gửi. RemoteApiHelper giữ hai đối tượng Dio: _dio cho Core "
              "Backend, gắn access token lấy từ SessionService, và _mlDio cho AI Service, không gửi token vì AI Service không "
              "xác thực yêu cầu."),
        diagram("Sơ đồ lớp mức thiết kế – tầng truy cập dữ liệu của ứng dụng di động", "ch3_lop_thiet_ke_di_dong.png", 12.5),
        ("p", "Bảng 3.27 đối chiếu các lớp phân tích ở mục 2.4 với các lớp thiết kế tương ứng."),
        ("table", "Đối chiếu lớp phân tích với lớp thiết kế", "3", [1900, 3300, 3304],
         ["Lớp phân tích", "Lớp thiết kế (Core Backend)", "Lớp thiết kế (ứng dụng di động)"],
         [["User", "User, UserRepository, CurrentUserProvider", "SessionService, UserModel"],
          ["Transaction", "Transaction, TransactionService, TransactionRepository", "TransactionModel, AppRepository, SqfliteHelper"],
          ["Receipt", "Receipt, ReceiptProcessingService, OcrService, ReceiptRepository", "ReviewFormPage, RemoteApiHelper.scanReceipt"],
          ["ReceiptProcessingAttempt", "ReceiptProcessingAttempt, ReceiptProcessingAttemptRepository", "–"],
          ["Budget", "Budget, BudgetService, BudgetAlertService, BudgetRepository", "BudgetModel, AppRepository.saveBudget"],
          ["Notification", "Notification, NotificationService, NotificationRepository", "NotificationScreen, NotificationBell"],
          ["SavingGoal", "SavingGoal, SavingGoalService, SavingGoalRepository", "SavingsPage"],
          ["Category", "Category, CategoryService, CategoryRepository", "TransactionCategories"]], NGUON),
    ],
    # ------------------------------------------------------------------------------------------ 3.8 Thiết kế chức năng
    "Thiết kế chức năng đăng nhập và phân quyền": [
        ("p", "Mỗi chức năng chính được thiết kế bằng hai sơ đồ. Sơ đồ ba lớp chia các lớp tham gia thành lớp biên (Boundary, "
              "giao tiếp với tác nhân hoặc hệ thống khác), lớp điều khiển (Control, điều phối nghiệp vụ) và lớp thực thể (Entity, "
              "dữ liệu được lưu) theo cách phân loại của Jacobson [54]. Sơ đồ tuần tự mức thiết kế dùng đúng tên lớp và tên phương "
              "thức trong mã nguồn, chỉ vẽ dòng sự kiện chính của use case tương ứng ở Chương 2 [47]."),
        ("p", "Chức năng đăng nhập (UC02) có các lớp như Hình 3.39. LoginScreen và RemoteApiHelper là lớp biên phía ứng dụng; "
              "AuthController điều phối LoginAttemptService (đếm lần sai trong bộ nhớ, riêng cho từng email và từng địa chỉ IP, "
              "khóa 15 phút sau 5 lần sai), AuthenticationManager của Spring Security (so mật khẩu BCrypt) và JwtUtil (ký access token và refresh token "
              "có kèm credentialsVersion). Sau khi đăng nhập, phân quyền diễn ra ở JwtAuthFilter theo các bước của Bảng 3.24."),
        diagram("Sơ đồ ba lớp chức năng đăng nhập", "ch3_dang_nhap_ba_lop.png", 15.0),
        ("p", "Hình 3.40 là sơ đồ tuần tự. Điểm cần lưu ý là credentialsVersion được đọc (thông điệp 5) trước bước so mật khẩu (thông điệp 6): "
              "nếu mật khẩu bị đổi trong lúc đang kiểm tra, token sinh ra mang phiên bản cũ và bị từ chối ngay ở yêu cầu kế tiếp. "
              "Khi xác thực thất bại, AuthController ghi một lần sai rồi trả 401, hoặc 429 nếu lần sai này làm tài khoản bị khóa."),
        diagram("Sơ đồ tuần tự mức thiết kế chức năng đăng nhập", "ch3_dang_nhap_tuan_tu.png", 15.5),
    ],
    "Thiết kế chức năng quản lý giao dịch": [
        ("p", "Chức năng ghi giao dịch (UC06) và đồng bộ giao dịch offline (UC07) dùng chung các lớp ở Hình 3.41. Phía ứng dụng, "
              "AppRepository vừa là lớp điều khiển vừa giữ hàng đợi gửi (outbox) trong bảng SQLite qua SqfliteHelper. Phía máy chủ, "
              "TransactionService cập nhật đồng thời ba thực thể User (số dư ví), Transaction và Category (tạo danh mục theo tên "
              "khi chưa có)."),
        diagram("Sơ đồ ba lớp chức năng quản lý giao dịch", "ch3_giao_dich_ba_lop.png", 16.0),
        ("p", "Hình 3.42 trình bày dòng chính khi có mạng. Giao dịch được ghi cục bộ với trạng thái pending và một clientId dạng "
              "UUID trước khi gửi (thông điệp 3), nên không mất dữ liệu nếu ứng dụng bị tắt giữa chừng. TransactionController "
              "chuyển thẳng yêu cầu cho createMyTransaction() nên không vẽ thành lifeline riêng. Ở máy chủ, dòng ví bị khóa trước "
              "khi tìm clientId (thông điệp 6, 7): nếu clientId đã tồn tại, máy chủ trả lại chính giao dịch cũ thay vì tạo bản thứ "
              "hai; ràng buộc duy nhất (user_id, client_id) ở mục 3.3.4 là lớp bảo vệ cuối ở tầng CSDL."),
        diagram("Sơ đồ tuần tự mức thiết kế chức năng ghi giao dịch", "ch3_giao_dich_tuan_tu.png", 16.0),
        ("p", "Khi mất mạng, hết thời gian chờ hoặc máy chủ lỗi 5xx, _send() đổi cờ thành error và màn hình báo “Chưa gửi được "
              "lên máy chủ”; giao dịch vẫn hiển thị trong Sổ sách với huy hiệu đồng bộ. resendUnsyncedTransactions() gửi lại toàn "
              "bộ hàng đợi, giao dịch cũ trước, khi ứng dụng mở, khi ứng dụng quay lại tiền cảnh và khi người dùng kéo làm mới Sổ "
              "sách; mỗi lần chỉ chạy một luồng gửi. Khi máy chủ từ chối (lỗi 4xx), giao dịch mới tạo bị xóa khỏi bảng cục bộ để "
              "người dùng sửa biểu mẫu, còn giao dịch gửi lại thì được giữ với cờ error để người dùng chủ động xóa."),
    ],
    "Thiết kế chức năng quét và đối soát hóa đơn": [
        ("p", "Chức năng quét hóa đơn (UC08) và đối soát, lưu hóa đơn (UC09) có các lớp như Hình 3.43. Ứng dụng gửi ảnh thẳng "
              "tới AI Service qua _mlDio, không qua Core Backend; Core Backend chỉ nhận câu trả lời của AI (rawReceiptData) cùng "
              "giao dịch khi người dùng lưu. Lớp TransactionController được lược đi vì giống mục 3.8.2."),
        diagram("Sơ đồ ba lớp chức năng quét và đối soát hóa đơn", "ch3_quet_hoa_don_ba_lop.png", 16.0),
        ("p", "Theo Hình 3.44, sau khi người dùng xác nhận, ảnh mới được tải lên Cloudinary qua POST /api/upload (thông điệp 9); "
              "nếu tải ảnh lỗi, ứng dụng hỏi người dùng lưu không kèm ảnh hay để sau. Giao dịch sau đó đi theo đúng đường ghi giao "
              "dịch ở mục 3.8.2, chỉ có thêm rawReceiptData và imageUrl. Trong cùng giao dịch CSDL, ReceiptProcessingService tạo "
              "Receipt và lượt đọc đầu tiên (ReceiptProcessingAttempt số 1) chứa nguyên văn câu trả lời của AI. Nếu OcrService "
              "đọc được tổng tiền, hóa đơn ở trạng thái COMPLETED_RAW; nếu không, hóa đơn chuyển FAILED với mã lỗi AI_NO_TOTAL "
              "hoặc AI_UNREADABLE. Sau khi giao dịch CSDL hoàn tất, câu trả lời thô được ghi thêm vào MongoDB (mục 3.4.1)."),
        diagram("Sơ đồ tuần tự mức thiết kế chức năng quét và lưu hóa đơn", "ch3_quet_hoa_don_tuan_tu.png", 16.0),
        ("p", "Thiết kế hiện tại có một hạn chế: attachReceipt() ghi đè ngày giao dịch và địa điểm bằng giá trị AI đọc được nếu "
              "có, kể cả khi người dùng đã sửa hai trường này trên biểu mẫu đối soát."),
    ],
    "Thiết kế chức năng quản lý ngân sách và cảnh báo": [
        ("p", "Chức năng quản lý ngân sách (UC10) và nhận cảnh báo ngân sách (UC11) có các lớp như Hình 3.45. BudgetService chỉ "
              "lo việc thêm, sửa, xóa ngân sách; việc sinh cảnh báo nằm ở BudgetAlertService và được TransactionService gọi mỗi "
              "khi một khoản chi được tạo, sửa hoặc được đối soát lại."),
        diagram("Sơ đồ ba lớp chức năng quản lý ngân sách và cảnh báo", "ch3_ngan_sach_ba_lop.png", 16.0),
        ("p", "Hình 3.46 gồm hai đoạn. Đoạn đầu lưu ngân sách: BudgetScreen nhận dữ liệu từ BudgetFormSheet và gọi "
              "AppRepository.saveBudget(), sau đó existsDuplicate() kiểm tra trùng bộ (người dùng, categoryKey, "
              "periodType, startDate) trước khi lưu, ràng buộc duy nhất cùng tên ở CSDL xử lý trường hợp hai yêu cầu đến cùng lúc. "
              "Đoạn sau là cảnh báo: findCoveringDate() lấy các ngân sách bao ngày của khoản chi, gồm ngân sách của đúng danh mục "
              "và ngân sách tất cả danh mục; với mỗi ngân sách, tổng chi trước và sau khoản chi được so với hạn mức. Một thông báo "
              "BUDGET_WARNING (80%) hoặc BUDGET_EXCEEDED (100%) chỉ được tạo khi khoản chi này đưa ngân sách lên một mốc cao hơn "
              "mốc trước đó, nên người dùng không bị nhắc lại cùng một mốc."),
        diagram("Sơ đồ tuần tự mức thiết kế chức năng ngân sách và cảnh báo", "ch3_ngan_sach_tuan_tu.png", 16.0),
        ("p", "Phía ứng dụng, chuông trên Trang chủ đọc số thông báo chưa đọc qua GET /api/notifications/unread-count, còn hộp "
              "thoại cảnh báo được BudgetAlertPresenter tính lại từ tiến độ ngân sách trên thiết bị và chỉ hiện một lần cho mỗi "
              "mốc."),
    ],
    "Thiết kế chức năng thống kê và báo cáo": [
        ("p", "Chức năng xem thống kê (UC12) và xem báo cáo thói quen chi tiêu (UC13) có các lớp như Hình 3.47. Phần lớn phép "
              "tính thống kê (số dư, tổng thu chi theo kỳ, biểu đồ tuần) được làm ngay trên thiết bị từ danh sách giao dịch; Core "
              "Backend chỉ cung cấp dữ liệu, còn AI Service khai phá mẫu chuỗi bằng WCM-SPADE [48] và đưa ra gợi ý ngân sách."),
        diagram("Sơ đồ ba lớp chức năng thống kê và báo cáo", "ch3_thong_ke_ba_lop.png", 15.0),
        ("p", "Hình 3.48 là dòng chính khi người dùng mở tab AI. Danh sách giao dịch đi qua AppRepository để có cả giao dịch "
              "chưa đồng bộ; sau khi lọc theo khoảng thời gian đang chọn, ứng dụng gửi giao dịch tới POST /spade/analyze, và nếu "
              "có mục tiêu tiết kiệm thì gửi thêm tới POST /spade/recommend. Hai lời gọi AI chỉ báo lỗi bằng hộp thoại khi người "
              "dùng chủ động bấm làm mới. Hai endpoint thống kê có cache ở mục 3.4.2, /api/transactions/app-dashboard "
              "và /api/transactions/popular-vendors, hiện chưa được ứng dụng di động gọi."),
        diagram("Sơ đồ tuần tự mức thiết kế chức năng thống kê và báo cáo", "ch3_thong_ke_tuan_tu.png", 13.0),
    ],
    "Thiết kế chức năng duyệt hóa đơn AI": [
        ("p", "Chức năng duyệt hóa đơn AI (UC19) cho phép quản trị viên chốt số tiền của một hóa đơn theo tổng tiền mà AI đọc "
              "được, hoặc từ chối hóa đơn. Hình 3.49 cho thấy hai lớp điều khiển: TransactionService.approveReceipt() cho thao tác "
              "duyệt, vì duyệt có thể làm thay đổi số tiền giao dịch và số dư ví, và ReceiptProcessingService.rejectReceipt() cho "
              "thao tác từ chối, chỉ đổi trạng thái hóa đơn sang FAILED với mã REJECTED_BY_ADMIN."),
        diagram("Sơ đồ ba lớp chức năng duyệt hóa đơn AI", "ch3_duyet_hoa_don_ba_lop.png", 15.0),
        ("p", "Theo Hình 3.50, approveReceipt() khóa ví của chủ hóa đơn rồi đọc lại giao dịch, nên hai yêu cầu duyệt cùng lúc "
              "chỉ đổi ví một lần. approvableTotal() từ chối hóa đơn đã hủy, hóa đơn ở trạng thái không được chuyển sang APPROVED "
              "và hóa đơn không có tổng tiền dương. Chênh lệch giữa tổng tiền đã duyệt và số tiền cũ được cộng hoặc trừ vào ví; "
              "nếu có chênh lệch, cảnh báo ngân sách được tính lại và nhật ký ghi thêm TRANSACTION_UPDATED bên cạnh "
              "RECEIPT_APPROVED."),
        diagram("Sơ đồ tuần tự mức thiết kế chức năng duyệt hóa đơn AI", "ch3_duyet_hoa_don_tuan_tu.png", 15.0),
        ("y", "[Nhóm] Bước 1 của Hình 3.50 giả định trang /admin/receipts có nút Duyệt; hiện template chưa có nút này (xem mục "
              "3.6.2). Ngoài ra, duyệt và từ chối chưa tạo thông báo cho người dùng."),
    ],
    # --------------------------------------------------------------------------------------------- 3.9 Mô hình AI
    "Tokenizer mở rộng cho tiếng Việt": [
        ("p", "Mục 2.5.5 đã phân tích vì sao cách thêm ký tự bằng added token ở bản V3 làm sai khoảng trắng tiếng Việt. Mục này "
              "trình bày thiết kế cụ thể của bản V5 trong ai-service/Version5/model_config.py. Bản V3 vẫn là bản đang phục vụ "
              "trong ai_service.py cho tới khi bản V5 được đánh giá tốt hơn trên cùng tập kiểm thử (Chương 5). Bảng 3.28 tóm tắt "
              "các tham số thiết kế của hai bản."),
        ("table", "Tham số thiết kế mô hình DONUT bản V3 và V5", "3", [2400, 2800, 3304],
         ["Tham số", "V3 (đang phục vụ)", "V5 (huấn luyện lại)"],
         [["Mô hình gốc [40]", "donut-base-finetuned-cord-v2 (khi phục vụ: processor của donut-base, tokenizer của V3)", "naver-clova-ix/donut-base-finetuned-cord-v2"],
          ["Kích thước ảnh vào (cao × rộng)", "1280 × 960 khi suy luận", "1920 × 1440, đổi được qua biến môi trường DONUT_IMAGE_HEIGHT/WIDTH"],
          ["Xoay theo cạnh dài", "do_align_long_axis = True", "do_align_long_axis = True"],
          ["Độ dài chuỗi tối đa", "768 token", "768 token; nhãn dài hơn bị báo lỗi LabelTooLongError thay vì cắt"],
          ["Ký tự tiếng Việt còn thiếu", "Thêm từng ký tự thành added token", "Thêm vào từ vựng Unigram với điểm bằng điểm thấp nhất"],
          ["Thẻ nhiệm vụ và thẻ trường", "10 thẻ thêm bằng add_tokens, không đánh dấu special", "10 token đặc biệt (thêm sau khi mở rộng từ vựng)"],
          ["Khởi tạo embedding ký tự mới", "Ngẫu nhiên khi resize", "Vector trung bình của từ vựng gốc"],
          ["Kiểm tra tokenizer", "Không có", "Tỉ lệ nhãn encode/decode giữ nguyên ≥ 99%, nếu thấp hơn thì dừng (TokenizerCheckError)"],
          ["Token bắt đầu giải mã", "<s_seller>", "<s_seller> (decoder_start_token_id)"]], NGUON),
        ("p", "Thứ tự các bước trong setup_model_and_processor() là có chủ đích. Hàm find_unk_chars() duyệt mọi ký tự của nhãn "
              "train và giữ lại ký tự không có trong từ vựng hoặc bị mã hóa thành <unk>. Hàm extend_unigram_vocab() ghi các ký tự "
              "đó vào tokenizer.json như piece (đơn vị từ vựng) mới của mô hình Unigram được hiện thực trong SentencePiece [12], rồi nạp lại tokenizer. Sau đó mười thẻ của nhiệm vụ "
              "mới được thêm dưới dạng token đặc biệt, ma trận embedding (vector biểu diễn token) của bộ giải mã được mở rộng theo kích thước tokenizer, và "
              "các dòng ứng với ký tự mới được gán vector trung bình để bắt đầu huấn luyện từ một điểm trung tính. Cuối cùng, "
              "chương trình mã hóa rồi giải mã lại toàn bộ nhãn train và dừng nếu dưới 99% nhãn được giữ nguyên."),
    ],
    "Định dạng nhãn dữ liệu": [
        ("p", "Nhãn được lưu theo từng tập (train, validation, test) trong tệp metadata.jsonl, mỗi dòng ứng với một ảnh. Trường "
              "ground_truth là một chuỗi JSON có khóa gt_parse chứa bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST, theo quy "
              "ước nhãn của DONUT [5], [40]. Trường tùy chọn unverified_fields liệt kê các trường chưa được người kiểm tra xác "
              "nhận. Ví dụ một dòng nhãn:"),
        ("p", "{\"file_name\": \"00000001.jpg\", \"ground_truth\": \"{\\\"gt_parse\\\": {\\\"SELLER\\\": \\\"MINIMART ANAN\\\", "
              "\\\"ADDRESS\\\": \\\"Chợ Sủi Phú Thị Gia Lâm\\\", \\\"TIMESTAMP\\\": \\\"10/08/2020-17:20\\\", "
              "\\\"TOTAL_COST\\\": \\\"88,000\\\"}}\", \"unverified_fields\": []}"),
        ("y", "[Nhóm] Tên tệp 00000001.jpg ở ví dụ trên là minh họa; thay bằng tên thật của một ảnh trong tập dữ liệu nếu cần."),
        ("p", "Khi huấn luyện, build_target() chuyển mỗi bản ghi thành chuỗi đích theo thứ tự cố định của Bảng 3.29, kết thúc "
              "bằng </s_seller> và token </s>. Đầu vào của bộ giải mã là <s_seller> nối với chuỗi đích lùi một vị trí."),
        ("table", "Ánh xạ trường nhãn sang thẻ của chuỗi đích và khóa JSON đầu ra", "3", [1600, 2900, 2200, 1804],
         ["Trường nhãn", "Thẻ trong chuỗi đích", "Khóa JSON đầu ra", "Ý nghĩa"],
         [["SELLER", "<s_seller_name>…</s_seller_name>", "seller.seller_name", "Tên cửa hàng"],
          ["ADDRESS", "<s_address>…</s_address>", "seller.address", "Địa chỉ"],
          ["TIMESTAMP", "<s_timestamp>…</s_timestamp>", "seller.timestamp", "Ngày giờ in trên hóa đơn"],
          ["TOTAL_COST", "<s_total_cost>…</s_total_cost>", "seller.total_cost", "Tổng tiền dạng chữ in"],
          ["–", "–", "seller.total_cost_number", "Tổng tiền dạng số do AI Service tính thêm"]], NGUON),
        ("p", "Thiết kế nhãn có hai quyết định riêng. Thứ nhất, một trường rỗng có tên trong unverified_fields có thể là nhãn bị "
              "bỏ sót chứ không phải hóa đơn không có trường đó, nên các token của đoạn này được gán nhãn -100 và không tính vào "
              "hàm mất mát. Thứ hai, ảnh có tỉ lệ cao trên rộng lớn hơn 2,2 được coi là hóa đơn dài và được lặp 2 lần trong tập "
              "train, vì đây là nhóm hóa đơn mà bản V3 đọc kém nhất. Khi đánh giá, tổng tiền được so theo giá trị số (money_value), "
              "các trường còn lại được so sau khi chuẩn hóa Unicode NFC, chữ thường và khoảng trắng."),
    ],
    "Quy trình hậu xử lý bằng Regex": [
        ("p", "Chuỗi do DONUT sinh ra cần được làm sạch trước khi điền vào biểu mẫu đối soát và trước khi lưu vào CSDL. Hình 3.51 "
              "trình bày quy trình hậu xử lý hiện có, gồm hai chặng: ở AI Service ngay sau khi suy luận, và ở Core Backend khi "
              "giao dịch kèm hóa đơn được lưu."),
        ("fig", "Quy trình hậu xử lý kết quả DONUT", "3", PNG + "ch3_hau_xu_ly.png", 7.5, SRC, None),
        ("p", "Ở AI Service, chuỗi sinh ra được bỏ token kết thúc và token đệm, đi qua clean_vietnamese_text() để ghép lại các "
              "âm tiết bị tách bởi tokenizer V3, rồi được processor.token2json() chuyển thành JSON [40]. extract_final_cost() bỏ "
              "dấu chấm, dấu phẩy và lấy số lớn nhất trong chuỗi tổng tiền làm total_cost_number. Nếu chuỗi không chuyển được "
              "sang JSON, dịch vụ trả về {\"raw_text\": …} để ứng dụng cho người dùng nhập tay. Ở Core Backend, OcrService.extract() "
              "là nơi duy nhất đọc câu trả lời của AI; Bảng 3.30 liệt kê các quy tắc của nó."),
        ("table", "Các quy tắc hậu xử lý trong OcrService", "3", [1600, 3900, 3004],
         ["Trường", "Quy tắc", "Kết quả khi không hợp lệ"],
         [["Tên cửa hàng, địa chỉ", "Gộp khoảng trắng, bỏ ký tự điều khiển, bỏ chuỗi \"null\", cắt tối đa 255 ký tự", "null"],
          ["Ngày giờ", "Tìm ngày dạng yyyy-MM-dd hoặc dd/MM/yyyy (phân cách / . -), giờ dạng HH:mm[:ss] hoặc HHhmm ở sau "
                       "hoặc trước ngày; năm phải trong [2000, 2100], ngày phải tồn tại; thiếu giờ thì lấy 00:00",
           "null, giao dịch giữ ngày ứng dụng gửi"],
          ["Tổng tiền", "Ưu tiên total_cost_number; nếu không có thì lấy số lớn nhất trong total_cost. Khi có cả dấu chấm và "
                        "dấu phẩy, dấu đứng sau là dấu thập phân; khi chỉ có một loại, nó là dấu phân cách nghìn nếu lặp lại "
                        "hoặc theo sau là đúng 3 chữ số; giá trị phải dương và không quá 10^12",
           "null, hóa đơn chuyển FAILED (AI_NO_TOTAL)"]], NGUON),
        ("p", "Cách lấy số lớn nhất cho tổng tiền đơn giản nhưng sai khi hóa đơn in số tiền khách đưa hoặc mã số lớn hơn tổng "
              "tiền, còn tên cửa hàng, địa chỉ và ngày giờ chưa được chuẩn hóa ở AI Service. Vì vậy, nhóm thiết kế mô-đun "
              "ai-service/receipt_postprocess.py đặt ngay sau token2json() (khối màu xám ở Hình 3.51), với các quy tắc: tổng tiền "
              "ưu tiên số đứng gần các từ khóa “Tổng”, “Thành tiền”, “Total” và hiểu dấu chấm, dấu phẩy theo cách viết tiền Việt "
              "Nam; ngày giờ nhận các dạng dd/MM/yyyy, dd-MM-yy, HH:mm và chuẩn hóa về dạng yyyy-MM-ddTHH:mm:ss; tên cửa hàng và địa chỉ được bỏ "
              "ký tự rác, chuẩn hóa khoảng trắng và chữ hoa, chữ thường. Kết quả là một mô hình Pydantic [60], mỗi trường kèm cờ valid "
              "để ứng dụng biết trường nào cần người dùng kiểm tra, và các khóa JSON cũ ở Bảng 3.29 được giữ nguyên để ứng dụng "
              "hiện tại không bị ảnh hưởng."),
        ("y", "[Nhóm] Mô-đun receipt_postprocess.py chưa được cài đặt (task T5). Sau khi làm T5, đối chiếu lại đoạn trên và Hình "
              "3.51 với mã thật (tên hàm, các dạng ngày giờ được hỗ trợ, cờ valid) rồi bỏ khối “dự kiến” trong hình."),
    ],
    # ------------------------------------------------------------------------------------------------- 3.10 Kết chương
    "KẾT CHƯƠNG": [
        ("p", "Chương 3 đã chuyển kết quả phân tích ở Chương 2 thành thiết kế có thể cài đặt. Kiến trúc gồm ứng dụng di động, "
              "Web Admin, Core Backend, AI Service và ba kho dữ liệu PostgreSQL, Redis, MongoDB, triển khai bằng Docker Compose "
              "sau reverse proxy Caddy. CSDL quan hệ được mô tả qua ERD, bảng mô tả từng bảng và các ràng buộc toàn vẹn gắn với "
              "ràng buộc thật trong mã nguồn; API RESTful được bảo vệ bằng JWT có thu hồi."),
        ("p", "Phần thiết kế giao diện mô tả 21 màn hình của ứng dụng di động và 8 trang Web Admin; ảnh chụp màn hình sẽ "
              "được nhóm bổ sung. Sơ đồ lớp mức thiết kế cùng sáu cặp sơ đồ ba lớp và sơ đồ tuần tự cho thấy các quyết định "
              "chính: hàng đợi gửi với clientId để ghi giao dịch không trùng khi mất mạng, khóa dòng ví khi đổi số dư, lưu từng "
              "lượt đọc của AI và cảnh báo ngân sách chỉ khi vượt một mốc mới. Thiết kế mô hình AI xác định tokenizer mở rộng từ "
              "vựng Unigram, định dạng nhãn bốn trường có che các trường chưa kiểm tra và quy trình hậu xử lý hai chặng."),
        ("p", "Thiết kế vẫn còn hạn chế: hậu xử lý ở AI Service chưa chuẩn hóa ngày giờ và tên, địa chỉ; ngày và địa điểm người "
              "dùng sửa có thể bị giá trị AI ghi đè; Web Admin chưa có nút duyệt hóa đơn trên giao diện; các endpoint /ai/donut/* và /ai/spade/* của AI Service "
              "được Caddy mở ra ngoài mà không yêu cầu xác thực. Chương 4 trình bày việc "
              "cài đặt các thiết kế này và quá trình huấn luyện mô hình DONUT."),
    ],
}

ABBREVIATIONS = [
    ("BCE", "Boundary – Control – Entity", "Mô hình ba lớp biên – điều khiển – thực thể"),
    ("CRUD", "Create, Read, Update, Delete", "Thêm, đọc, sửa, xóa"),
    ("UI", "User Interface", "Giao diện người dùng"),
    ("UUID", "Universally Unique Identifier", "Định danh duy nhất toàn cục"),
]
