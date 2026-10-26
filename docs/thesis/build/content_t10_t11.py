# Nội dung phiên cập nhật T10/T11 (26/10/2026): các chức năng thêm sau đợt dùng thử ngày 26/10 và chức năng quét nhiều
# hóa đơn. Sinh KhoaLuan_KLCN175_v8.docx từ v7 bằng builder.py (chèn vào giữa quyển, RENUMBER đánh số lại Hình/Bảng).
# Đối chiếu mã nguồn tại HEAD c29c071: core-backend Service/{TransactionService (refuseDuplicateReceipt,
# normalizedSeller), SavingGoalService.contributeToMySaving, CategoryService.resolveOrCreate, BudgetService},
# Entity/BudgetPeriodType (YEAR(366)), Exception/{DuplicateReceiptException, GlobalExceptionHandler},
# Controller/SavingGoalController (POST /{id}/contributions), resources/db/budget-period-year-migration.sql;
# ai-service/ai_service.py (_run_donut, _donut_lock, run_in_threadpool), test_main.py;
# mobile-app lib/services/{receipt_scan_queue.dart, sqflite_helper.dart (v8), session_service.dart},
# lib/models/{receipt_scan_result.dart, scan_queue_item.dart}, lib/screens/{main_scaffold.dart,
# receipt_scanner/pending_receipts_screen.dart, receipt_scanner/review_form_page.dart, auth/login_page.dart,
# profile/savings_page.dart, dashboard/dashboard_page.dart, ledger/ledger_page.dart, budget/budget_form_sheet.dart,
# notifications/notification_destination.dart, linked/linked_services_page.dart}, lib/widgets/{feedback/app_toast.dart,
# inputs/date_field.dart, receipt/scan_queue_banner.dart, receipt/receipt_image_viewer.dart, common/demo_badge.dart},
# lib/core/utils/money_input_formatter.dart, l10n/app_vi.arb.
# Trích dẫn mới: [71] SePay webhook, [72] Casso webhook, [73] Android Keystore, [74] Apple Keychain Services,
# [75] Flutter AutofillGroup (đã thêm vào references.md). Dùng lại [33] Flutter, [34] FastAPI, [47] UML, [54] Jacobson,
# [59] ML Kit.
# Số trong văn bản: số Hình/Bảng đã có ghi theo số cũ của v7 (RENUMBER tự đổi); hình/bảng mới tham chiếu bằng [[khóa]].
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = None
SECTIONS = {}
RENUMBER = True
SRC = "nguồn: nhóm thực hiện"
NGUON = "Nguồn: nhóm thực hiện"

FIELDS = ["Tên use case", "Tóm tắt", "Tác nhân", "Use case liên quan", "Điều kiện tiên quyết",
          "Dòng sự kiện chính", "Dòng sự kiện phụ", "Hậu điều kiện"]


def uc(key, code, name, summary, actors, related, pre, main, alt, post):
    rows = [[f, v] for f, v in zip(FIELDS, [f"{code} – {name}", summary, actors, related, pre,
                                             "\n".join(main), "\n".join(alt), post])]
    return ("table", f"Đặc tả use case {code} “{name}”", "2", [2000, 6504], ["Trường", "Nội dung"], rows, NGUON, key)


def shot(key, caption, screen, path):
    """Hình giữ chỗ cho ảnh chụp màn hình do nhóm cung cấp (tô vàng)."""
    return ("fig", caption, "3", None, 0, SRC, f"[Nhóm] Chèn ảnh chụp màn hình {screen} ({path}).", key)


def diagram(key, caption, chapter, name, width=16.0):
    return ("fig", caption, chapter, PNG + name, width, SRC, None, key)


# ============================================================ Chương 2 – 2.3.2 Sơ đồ use case hệ thống
UC_DIAGRAM_INTRO = (
    "Sơ đồ use case hệ thống được tách thành ba hình để giữ cỡ chữ đọc được khi in. Hình 2.20 là phân hệ người dùng "
    "trên ứng dụng di động với 16 use case; Hình 2.21 là phân hệ quản trị trên Web Admin với 6 use case riêng, cộng "
    "thêm hai use case Đăng nhập và Đăng xuất dùng chung với phân hệ người dùng; [[uc_bs]] vẽ bốn use case UC23–UC26 "
    "được bổ sung sau đợt dùng thử ngày 26/10/2026 cùng các use case gốc mà chúng gắn vào.")

UC_SUPPLEMENT = [
    ("p", "Bốn use case bổ sung xuất phát từ góp ý khi nhóm dùng thử ứng dụng. UC23 Quét nhiều hóa đơn cho chọn tối đa "
          "20 ảnh một lượt và đọc lần lượt ở nền, còn UC24 Xác nhận hóa đơn chờ là nơi người dùng duyệt kết quả; UC24 "
          "«include» UC09 vì mỗi hóa đơn vẫn được lưu qua đúng biểu mẫu đối soát. UC26 Xử lý hóa đơn có thể trùng "
          "«extend» UC09: hành vi này chỉ xảy ra khi Core Backend nhận thấy hóa đơn đang lưu giống một giao dịch đã có. "
          "UC25 Góp tiền vào mục tiêu tiết kiệm «extend» UC14 tại nút Góp tiền trên từng mục tiêu, và tạo một khoản chi "
          "theo đường xử lý của UC06 (quan hệ này ghi trong bảng đặc tả để sơ đồ không bị rối)."),
    diagram("uc_bs", "Sơ đồ use case hệ thống – các use case bổ sung", "2", "ch2_uc_bo_sung.png", 13.0),
]

UC_LIST_ROWS = [
    ["UC23", "Quét nhiều hóa đơn", "Người dùng, AI Service", "Bảng quét (Quét nhiều, Chọn nhiều ảnh); banner hàng chờ"],
    ["UC24", "Xác nhận hóa đơn chờ", "Người dùng", "Màn hình Chờ xác nhận"],
    ["UC25", "Góp tiền vào mục tiêu tiết kiệm", "Người dùng", "Màn hình Sổ tiết kiệm (nút Góp tiền)"],
    ["UC26", "Xử lý hóa đơn có thể trùng", "Người dùng", "Hộp thoại hóa đơn trùng trên màn hình Xác nhận hóa đơn"],
]

# ============================================================ Chương 2 – 2.3.3 bốn bảng đặc tả mới
UC_NEW = [
    ("p", "Bốn use case UC23–UC26 ([[uc23]] đến [[uc26]]) được đặc tả theo cùng tám trường. Hàng đợi quét của UC23 nằm "
          "trên thiết bị: các ảnh và kết quả đọc được lưu trong SQLite, gắn với mã người dùng đang đăng nhập, nên đóng "
          "ứng dụng rồi mở lại thì việc đọc vẫn tiếp tục, còn người dùng khác đăng nhập trên cùng máy không thấy hàng "
          "đợi này."),
    uc("uc23", "UC23", "Quét nhiều hóa đơn",
       "Người dùng chụp nhiều trang hoặc chọn nhiều ảnh hóa đơn trong một lượt; ứng dụng xếp ảnh vào hàng đợi trên "
       "thiết bị và gửi lần lượt từng ảnh tới AI Service trong lúc người dùng dùng các tab khác.",
       "Người dùng, AI Service",
       "Là phương án nhiều ảnh của UC08, dùng cùng endpoint /donut/scan; kết quả được xử lý ở UC24.",
       "Người dùng đã đăng nhập (UC02).",
       ["1. Người dùng bấm nút Quét AI và chọn “Quét nhiều” (trình quét tài liệu ML Kit, tối đa 20 trang) hoặc “Chọn "
        "nhiều ảnh” (thư viện ảnh, tối đa 20 ảnh).",
        "2. Ứng dụng chép từng ảnh vào thư mục riêng của ứng dụng, ghi mỗi ảnh thành một mục trạng thái queued của "
        "người dùng hiện tại trong SQLite và báo “Đã thêm n hóa đơn vào hàng chờ”.",
        "3. Ứng dụng lấy mục cũ nhất, đổi sang reading và gửi ảnh tới AI Service; mỗi lúc chỉ một ảnh được gửi.",
        "4. AI Service trả bốn trường kèm khối normalized; ứng dụng lưu kết quả, đổi mục sang ready rồi lặp lại bước "
        "3 tới khi hết mục queued.",
        "5. Trong lúc đọc, banner phía trên thanh tab hiển thị “Đang đọc hóa đơn x/y” trên mọi tab; đọc xong, banner "
        "chuyển thành “m hóa đơn chờ xác nhận”."],
       ["2a. Số mục queued và reading đã đủ 20: ứng dụng chỉ nhận số ảnh còn chỗ và báo số ảnh bị bỏ.",
        "3a. Mất mạng, AI Service lỗi hoặc ảnh đã chép không còn: mục chuyển failed với lý do tương ứng; các mục khác "
        "vẫn được đọc.",
        "3b. Phiên đăng nhập kết thúc (401, 403) hoặc người dùng đăng xuất: vòng đọc dừng, mục đang đọc trở về queued "
        "và chỉ được đọc tiếp khi chính người dùng đó đăng nhập lại.",
        "3c. Ứng dụng bị tắt giữa chừng: lần mở sau, mục còn ở trạng thái reading được đưa về queued và đọc lại."],
       "Mỗi ảnh có một mục ready hoặc failed trong hàng đợi của người dùng; chưa có giao dịch nào được ghi."),
    uc("uc24", "UC24", "Xác nhận hóa đơn chờ",
       "Người dùng xem các hóa đơn đã đọc, mở từng hóa đơn để đối soát và lưu, bỏ hoặc đọc lại hóa đơn lỗi, hoặc lưu "
       "một lần mọi hóa đơn hợp lệ.",
       "Người dùng",
       "UC24 «include» UC09 (mở và lưu từng hóa đơn); UC26 có thể xảy ra khi lưu.",
       "Hàng đợi của người dùng có ít nhất một mục (UC23).",
       ["1. Người dùng bấm banner; màn hình Chờ xác nhận liệt kê các mục, mỗi dòng gồm ảnh thu nhỏ, tên cửa hàng, số "
        "tiền, ngày và nhãn trạng thái Đang chờ, Đang đọc, Sẵn sàng hoặc Lỗi.",
        "2. Người dùng chọn một mục Sẵn sàng; ứng dụng mở biểu mẫu đối soát điền sẵn kết quả đã đọc, không gửi lại ảnh "
        "tới AI Service.",
        "3. Người dùng đối soát và lưu như UC09; lưu thành công thì mục rời khỏi danh sách."],
       ["2a. Người dùng chọn “Xác nhận tất cả hợp lệ (n)” và đồng ý: ứng dụng lần lượt lưu các mục Sẵn sàng có đủ tên "
        "cửa hàng, số tiền, ngày và không có trường nào bị cờ sai, rồi báo “Đã lưu x, trùng y, chưa lưu z”. Mục bị "
        "coi là trùng (UC26), mục tải ảnh lỗi hoặc bị từ chối được giữ lại; mục đã vào hàng đợi gửi khi mất mạng "
        "(UC07) được tính là đã lưu.",
        "2b. Người dùng chọn “Bỏ” và xác nhận: mục cùng ảnh đã chép bị xóa.",
        "2c. Mục Lỗi: người dùng chọn “Đọc lại”, mục trở về queued và được đọc lại theo UC23."],
       "Mỗi mục đã lưu trở thành một khoản chi kèm hồ sơ hóa đơn và rời khỏi hàng đợi; các mục còn lại giữ nguyên."),
    uc("uc25", "UC25", "Góp tiền vào mục tiêu tiết kiệm",
       "Người dùng chuyển một khoản tiền từ ví vào một mục tiêu; hệ thống ghi một khoản chi danh mục “Tiết kiệm” và "
       "cộng số tiền đã tiết kiệm của mục tiêu trong cùng một giao dịch cơ sở dữ liệu.",
       "Người dùng",
       "UC25 «extend» UC14 (điểm mở rộng: nút Góp tiền trên từng mục tiêu); UC25 «include» UC06 (khoản chi đi theo "
       "đường ghi giao dịch), nên UC11 có thể xảy ra.",
       "Người dùng đã đăng nhập, có ít nhất một mục tiêu tiết kiệm và thiết bị có kết nối mạng.",
       ["1. Trên màn hình Sổ tiết kiệm, người dùng bấm “Góp tiền” ở một mục tiêu và nhập số tiền.",
        "2. Ứng dụng gửi POST /api/savings/{id}/contributions với trường amount.",
        "3. Core Backend khóa dòng mục tiêu và kiểm tra mục tiêu thuộc người dùng lấy từ JWT.",
        "4. Core Backend tạo khoản chi danh mục “Tiết kiệm”, ghi chú là tên mục tiêu, ngày là thời điểm hiện tại, qua "
        "đường ghi giao dịch: khóa ví, trừ số dư, tính cảnh báo ngân sách.",
        "5. Core Backend cộng số tiền góp vào số đã tiết kiệm, ghi nhật ký SAVING_UPDATED và trả mục tiêu đã cập nhật.",
        "6. Ứng dụng báo “Đã góp tiền vào …”; khi tiến độ đạt 100%, ứng dụng hiện thêm lời chúc mừng."],
       ["1a. Số tiền trống hoặc không lớn hơn 0: ứng dụng báo “Nhập số tiền lớn hơn 0” và không gửi.",
        "3a. Mục tiêu không tồn tại: Core Backend trả 400; mục tiêu của người khác: trả 403. Ví chưa bị đụng tới.",
        "4a. Số dư ví không đủ: Core Backend trả 400 (InsufficientBalanceException), không có gì được ghi."],
       "Số dư ví giảm và số đã tiết kiệm của mục tiêu tăng đúng bằng số tiền góp; Sổ giao dịch có thêm một khoản chi "
       "“Tiết kiệm”."),
    uc("uc26", "UC26", "Xử lý hóa đơn có thể trùng",
       "Khi lưu một hóa đơn đã quét, Core Backend từ chối nếu người dùng đã có giao dịch cùng loại, cùng số tiền, cùng "
       "thời điểm tính đến phút và cùng người bán; người dùng chọn xem bản đã lưu hoặc vẫn lưu.",
       "Người dùng",
       "UC26 «extend» UC09 (điểm mở rộng: bước 5 của UC09, Core Backend trả 409). Giao dịch nhập tay (UC06) không bị "
       "kiểm tra, vì hai lần mua giống hệt nhau trong ngày là chuyện bình thường.",
       "Người dùng đang lưu một hóa đơn từ UC09 hoặc UC24.",
       ["1. Core Backend khóa ví, tạo hồ sơ hóa đơn từ kết quả AI, rồi tìm các giao dịch của người dùng cùng chiều thu "
        "chi, cùng số tiền và có ngày giao dịch trong cùng một phút.",
        "2. Với mỗi giao dịch tìm được, Core Backend so tên người bán sau khi chuẩn hóa (chữ thường, bỏ dấu, “đ” thành "
        "“d”, bỏ dấu câu); tên trống ở một trong hai bên được coi là khớp.",
        "3. Có giao dịch khớp: Core Backend hủy toàn bộ thao tác ghi và trả 409 với thông báo “Hóa đơn này có vẻ đã "
        "được lưu trước đó”, kèm mã và ngày của giao dịch đã có.",
        "4. Ứng dụng hiện hộp thoại “Hóa đơn này có vẻ đã lưu ngày …” với hai lựa chọn “Xem bản đã lưu” và “Vẫn lưu”.",
        "5. Người dùng chọn “Vẫn lưu”; ứng dụng gửi lại với allowDuplicate=true và Core Backend lưu giao dịch như UC09."],
       ["4a. Đang chạy “Xác nhận tất cả hợp lệ” (UC24): không hiện hộp thoại, mục được đếm là trùng và giữ lại để "
        "người dùng mở riêng.",
        "5a. Người dùng chọn “Xem bản đã lưu”: ứng dụng mở bảng chi tiết của giao dịch đã có; nếu không mở được từ màn "
        "hình hiện tại, ứng dụng nhắc tìm giao dịch ở tab Thống kê. Hóa đơn đang đối soát chưa được lưu.",
        "5b. Người dùng đóng hộp thoại: không có gì được ghi, biểu mẫu vẫn mở."],
       "Không có giao dịch trùng nào được ghi, trừ khi người dùng chủ động chọn “Vẫn lưu”."),
]

# ============================================================ Chương 3 – 3.6.1 giao diện
HOME_PARA = (
    "Trang chủ (Hình 3.10) xếp theo chiều dọc: lời chào và chuông thông báo có số chưa đọc; thẻ Số dư hiện tại kèm mức "
    "thay đổi so với tháng trước, mặc định che số dư mỗi lần mở trang (bấm biểu tượng mắt để hiện, lựa chọn không được "
    "lưu); khối Ngân sách với thanh tiến độ từng ngân sách, bấm vào thì mở màn hình Ngân sách; lưới Tiện ích gồm bốn ô "
    "đều nhau Thêm giao dịch, Quét hóa đơn, Ngân sách, Sổ tiết kiệm; và danh sách Giao dịch gần đây, bấm một dòng thì "
    "mở đúng bảng chi tiết giao dịch của Sổ sách. Ngày của giao dịch được ghi “Hôm nay”, “Hôm qua” khi phù hợp. Kéo "
    "xuống để làm mới; khi đang tải, các khối được thay bằng khung xương (skeleton).")

ADD_TX_PARA = (
    "Màn hình Thêm giao dịch (Hình 3.13) có công tắc Tiền chi/Tiền thu, ô số tiền lớn ở đầu trang, ô danh mục mở danh "
    "sách chọn, ô ngày giao dịch và ô ghi chú. Ô số tiền tự nhóm chữ số theo ngôn ngữ khi gõ (tiếng Việt 1.000.000, "
    "tiếng Anh 1,000,000). Ô ngày là thành phần dùng chung DateField: bấm vào mở lịch, hai nhãn chọn nhanh Hôm nay và "
    "Hôm qua, cùng nút Về hôm nay khi ngày đang chọn khác hôm nay; biểu mẫu luôn mở với ngày hôm nay. Màn hình Sửa giao "
    "dịch (Hình 3.14) cho sửa số tiền, danh mục, ngày giao dịch và ghi chú, và từ chối lưu khi không có thay đổi nào.")

SCAN_SHEET_PARA = (
    "Nút Quét AI mở bảng chọn nguồn ảnh (Hình 3.15) với bốn lựa chọn. Quét AI dùng trình quét tài liệu ML Kit [59] để "
    "cắt khung một hóa đơn, Từ thư viện chọn một ảnh có sẵn; hai lựa chọn Quét nhiều và Chọn nhiều ảnh đưa tối đa 20 "
    "ảnh vào hàng chờ của UC23. Với một ảnh, màn hình Xác nhận hóa đơn (Hình 3.16) hiển thị trạng thái “Đang phân tích "
    "hóa đơn...” trong lúc chờ AI Service, sau đó là biểu mẫu đối soát gồm ảnh hóa đơn, nhóm Thông tin chung (tên cửa "
    "hàng, tổng tiền, ngày giao dịch, danh mục) và thẻ Tổng kết (tạm tính, thuế, tổng tiền). Khi AI không đọc được tổng "
    "tiền, ô tổng tiền để trống kèm lời nhắc nhập tay; khi không đọc được ngày, ô ngày lấy thời điểm hiện tại và hiện "
    "chú thích cảnh báo. Nếu ngày hóa đơn không thuộc tháng hiện tại, biểu mẫu nhắc “Giao dịch ngày dd/mm vẫn được tính "
    "vào số dư hiện tại”. Nút lưu có nhãn “Xác nhận và lưu”.")

SCAN_NEW = [
    ("p", "Bấm vào ảnh trên biểu mẫu mở màn xem ảnh toàn màn hình, phóng to bằng hai ngón hoặc chạm hai lần "
          "(InteractiveViewer của Flutter [33]). Nút Đối chiếu với ảnh trên thanh tiêu đề bật chế độ đối chiếu "
          "([[ui_compare]]): ảnh nằm ở nửa trên và vẫn phóng to được, bốn trường AI đọc nằm ở nửa dưới và sửa được ngay; "
          "trường có cờ không hợp lệ vẫn được viền màu báo lỗi. Khi Core Backend trả 409 cho một hóa đơn có thể trùng "
          "(UC26), ứng dụng hiện hộp thoại ở [[ui_duplicate]] với hai nút Xem bản đã lưu và Vẫn lưu."),
    shot("ui_compare", "Chế độ đối chiếu trên màn hình Xác nhận hóa đơn", "ReviewFormPage ở chế độ Đối chiếu với ảnh",
         "lib/screens/receipt_scanner/review_form_page.dart"),
    shot("ui_duplicate", "Hộp thoại hóa đơn có thể trùng", "hộp thoại “Hóa đơn này có vẻ đã lưu ngày …” sau khi lưu "
         "lại một hóa đơn đã lưu", "lib/screens/receipt_scanner/review_form_page.dart"),
    ("p", "Khi hàng chờ có mục, banner ScanQueueBanner ([[ui_banner]]) nằm ngay trên thanh tab của MainScaffold nên "
          "hiện ở mọi tab: trong lúc đọc, banner ghi “Đang đọc hóa đơn x/y” kèm thanh tiến độ; đọc xong, banner ghi "
          "“m hóa đơn chờ xác nhận”; hàng chờ trống thì banner không chiếm chỗ. Bấm banner mở màn hình Chờ xác nhận "
          "([[ui_pending]]), lớp PendingReceiptsScreen: mỗi dòng có ảnh thu nhỏ, tên cửa hàng, số tiền, ngày và nhãn "
          "trạng thái; mục Sẵn sàng mở biểu mẫu đối soát, mục Lỗi có nút Đọc lại, mọi mục có nút Bỏ. Nút cuối màn hình "
          "“Xác nhận tất cả hợp lệ (n)” bị tắt khi n bằng 0."),
    shot("ui_banner", "Banner tiến độ đọc hóa đơn phía trên thanh tab", "MainScaffold khi đang đọc hàng chờ (banner "
         "“Đang đọc hóa đơn x/y”)", "lib/widgets/receipt/scan_queue_banner.dart"),
    shot("ui_pending", "Màn hình Chờ xác nhận", "PendingReceiptsScreen có đủ các trạng thái Sẵn sàng, Lỗi",
         "lib/screens/receipt_scanner/pending_receipts_screen.dart"),
]

BUDGET_PARA = (
    "Màn hình Ngân sách (Hình 3.17) liệt kê các ngân sách, mỗi thẻ gồm danh mục, kỳ, số đã chi trên hạn mức và thanh "
    "tiến độ đổi màu khi đạt 80% và 100%. Nút Thiết lập ngân sách mở bảng nhập (Hình 3.18) có ô số tiền, lựa chọn kỳ "
    "Tuần/Tháng/Năm, ô Kỳ chứa ngày (DateField) để chọn kỳ áp dụng và danh sách chip (nhãn chọn) danh mục, trong đó có "
    "lựa chọn “Tất cả danh mục”. Chọn chip “Khác” thì hiện thêm ô Tên danh mục, bắt buộc và tối đa 50 ký tự; ngân sách "
    "khi đó tính theo đúng tên người dùng nhập.")

NOTIF_PARA = (
    "Màn hình Thông báo (Hình 3.20) là danh sách tải theo trang, thông báo chưa đọc được tô nổi và gắn nhãn Chưa đọc; "
    "nút Đọc tất cả trên thanh tiêu đề đánh dấu toàn bộ. Chạm vào một thông báo luôn đánh dấu nó đã đọc rồi mở đích "
    "của nó: thông báo ngân sách mở màn hình Ngân sách; thông báo giao dịch và thông báo hóa đơn mở bảng chi tiết của "
    "giao dịch liên quan, hoặc mở Sổ sách khi thông báo không kèm mã giao dịch; loại không xác định mở một bảng hiển thị "
    "toàn bộ nội dung.")

SAVINGS_PARA = (
    "Màn hình Sổ tiết kiệm (Hình 3.23) có thẻ tổng đã tiết kiệm trên tổng mục tiêu, danh sách mục tiêu với thanh tiến "
    "độ và ngày đạt mục tiêu; vuốt một mục để xóa, nút Cập nhật để sửa tay số đã tiết kiệm. Khi tạo mục tiêu, ô Đã "
    "tiết kiệm và ô Ngày đạt mục tiêu đều không bắt buộc. Nút Góp tiền trên từng mục tiêu mở bảng nhập số tiền "
    "([[ui_contribute]]) với lời giải thích “Trừ vào số dư ví và ghi thành khoản chi \"Tiết kiệm\"” (UC25). Màn hình "
    "Tài khoản (Hình 3.24) hiển thị tên đăng nhập và cho đổi mật khẩu qua hộp nhập mật khẩu cũ, mật khẩu mới và xác "
    "nhận.")

LINKED_PARA = (
    "Màn hình Dịch vụ liên kết (Hình 3.25) liệt kê ví điện tử đã liên kết; chọn một ví mở hộp nhập số tiền (tối thiểu "
    "1.000 ₫) rồi tạo đơn thanh toán qua cổng giả lập và theo dõi trạng thái đơn. Dữ liệu ví ở màn hình này là giả lập "
    "(nhà cung cấp MOCK), nên cả tiêu đề màn hình lẫn dòng Dịch vụ liên kết ở trang Cá nhân đều gắn nhãn “Bản demo”, "
    "kèm lời ghi rằng ứng dụng không kết nối ngân hàng hay ví điện tử thật. Màn hình Lịch sử nạp/rút (Hình 3.26) liệt "
    "kê các đơn kèm mã đơn và nút hủy đơn chưa hoàn tất. Ba màn hình thông tin cá nhân (Hình 3.27) hiển thị email, họ "
    "tên, số điện thoại và cho sửa họ tên, số điện thoại (số gồm 10 chữ số, bắt đầu bằng 0).")

# ============================================================ Chương 3 – 3.8 các chức năng mới
DESIGN_NEW = [
    ("h3", "Thiết kế chức năng quét nhiều hóa đơn"),
    ("p", "Chức năng quét nhiều hóa đơn (UC23) và xác nhận hóa đơn chờ (UC24) có các lớp như [[d_batch_bce]]. "
          "ReceiptScanQueue là lớp điều khiển duy nhất của hàng đợi, dùng một thể hiện cho cả ứng dụng (singleton): "
          "MainScaffold thêm ảnh, ScanQueueBanner nghe tiến độ qua một ValueListenable, PendingReceiptsScreen đọc danh "
          "sách và ra lệnh đọc lại, bỏ hoặc xác nhận. Mỗi mục là một dòng của bảng receipt_scan_queue trong SQLite (mã, "
          "user_id, đường dẫn ảnh đã chép, trạng thái, kết quả JSON, mã lỗi, thời điểm tạo). Việc chuyển câu trả lời của "
          "AI Service thành bản nháp giao dịch được tách thành lớp ReceiptScanResult, dùng chung cho biểu mẫu đối soát "
          "và cho thao tác xác nhận hàng loạt, nên hai đường lưu áp cùng một quy tắc."),
    diagram("d_batch_bce", "Sơ đồ ba lớp chức năng quét nhiều hóa đơn", "3", "ch3_quet_nhieu_ba_lop.png", 15.0),
    ("p", "Theo [[d_batch_seq]], enqueue() trả về ngay sau khi ghi các dòng queued (thông điệp 2–4), còn việc đọc chạy "
          "trong một vòng lặp riêng: mỗi lượt lấy mục cũ nhất của người dùng đang đăng nhập, gửi /donut/scan và chỉ "
          "sang mục kế tiếp khi mục trước đã có kết quả (thông điệp 6–14). Ứng dụng chỉ giữ một vòng đọc; gọi enqueue() "
          "hay resume() trong lúc đang đọc chỉ báo cho vòng đó xem lại hàng đợi. confirmAllValid() xử lý tuần tự từng mục "
          "Sẵn sàng có allValid: tải ảnh lên trước, rồi lưu qua AppRepository.createTransaction() với "
          "allowDuplicate = false, tức đúng đường lưu có clientId và kiểm tra trùng của UC09; gọi lần nữa khi lần trước "
          "chưa xong thì không làm gì."),
    diagram("d_batch_seq", "Sơ đồ tuần tự mức thiết kế chức năng quét nhiều hóa đơn", "3",
            "ch3_quet_nhieu_tuan_tu.png", 16.0),
    ("p", "[[d_queue_state]] là sơ đồ trạng thái của một mục trong hàng đợi [47]. Hai chuyển trạng thái đáng chú ý đều "
          "quay về queued thay vì failed. Khi phiên đăng nhập kết thúc (401 không làm mới được, 403) hoặc người dùng "
          "đăng xuất, việc đọc tiếp không thể thành công nên mục được trả về hàng chờ và vòng đọc dừng. Khi ứng dụng bị "
          "tắt lúc một mục đang reading, lần mở sau MainScaffold gọi resume(); đầu mỗi lượt chạy, mọi mục reading của "
          "người dùng được đưa về queued vì không còn ai đọc chúng. Lỗi mạng, lỗi máy chủ và ảnh không còn trên máy "
          "được ghi thành failed với mã cố định network, server, missing_image để màn hình hiển thị lý do bằng ngôn ngữ "
          "người dùng chọn."),
    diagram("d_queue_state", "Sơ đồ trạng thái của một mục trong hàng đợi quét", "3", "ch3_hang_doi_trang_thai.png",
            11.0),
    ("p", "Thiết kế này có hai giới hạn có chủ đích. Hàng đợi chỉ chạy khi ứng dụng đang mở: không có dịch vụ nền của "
          "hệ điều hành và không thêm thư viện mới, nên tắt hẳn ứng dụng thì việc đọc tạm dừng tới lần mở sau. Mỗi lượt "
          "nhận tối đa 20 mục đang chờ hoặc đang đọc, vì AI Service chỉ đọc một ảnh mỗi lúc (mục 4.5.1)."),
    ("h3", "Thiết kế chức năng chống lưu trùng hóa đơn"),
    ("p", "Mã clientId ở mục 3.8.2 chỉ chống gửi lặp của cùng một lần lưu; hai lần quét cùng một tờ hóa đơn sinh hai "
          "clientId khác nhau và trước đây đều được lưu. Chức năng chống lưu trùng (UC26) dùng các lớp của Hình 3.43, "
          "thêm DuplicateReceiptException và truy vấn findPossibleReceiptDuplicates() của TransactionRepository. "
          "[[d_dup_seq]] cho thấy kiểm tra chạy sau attachReceipt(), vì cần tên người bán của hồ sơ hóa đơn vừa tạo, và "
          "chạy khi dòng ví đang bị khóa, nên hai lần lưu cùng một hóa đơn gửi đồng thời không thể cùng vượt qua. Truy "
          "vấn lọc theo người dùng, chiều thu chi, số tiền và khoảng [phút, phút + 1) của ngày giao dịch, lấy kèm hồ sơ "
          "hóa đơn bằng JOIN FETCH trong một câu lệnh; tên người bán được so trong bộ nhớ sau khi normalizedSeller() "
          "chuyển về chữ thường, bỏ dấu và dấu câu."),
    diagram("d_dup_seq", "Sơ đồ tuần tự mức thiết kế chức năng chống lưu trùng hóa đơn", "3",
            "ch3_chong_trung_tuan_tu.png", 16.0),
    ("p", "Ngoại lệ làm giao dịch CSDL quay lui toàn bộ, kể cả phần trừ ví đã làm ở thông điệp 4. GlobalExceptionHandler "
          "trả 409 với message cố định và data gồm existingTransactionId, existingTransactionDate (lớp "
          "DuplicateReceiptResponseDto); phía ứng dụng, AppRepository chuyển phản hồi này thành DuplicateReceiptException "
          "mà không giữ bản ghi nào trong hàng đợi gửi. Lần gửi lại có allowDuplicate = true bỏ qua kiểm tra. Giao dịch "
          "nhập tay không có rawReceiptData nên không bao giờ bị kiểm tra."),
    ("h3", "Thiết kế chức năng góp tiền tiết kiệm"),
    ("p", "Chức năng góp tiền (UC25) có các lớp như [[d_save_bce]]. SavingGoalService không tự trừ ví mà dựng một "
          "TransactionRequestDto (khoản chi, danh mục “Tiết kiệm” của DefaultCategory.SAVINGS, ghi chú là tên mục tiêu, "
          "phương thức WALLET, ngày hiện tại) rồi gọi TransactionService.createMyTransaction(), nên khoản góp đi qua "
          "đúng các bước khóa ví, kiểm tra số dư, cảnh báo ngân sách, nhật ký và xóa cache như mọi khoản chi khác."),
    diagram("d_save_bce", "Sơ đồ ba lớp chức năng góp tiền tiết kiệm", "3", "ch3_gop_tien_ba_lop.png", 16.0),
    ("p", "Theo [[d_save_seq]], toàn bộ contributeToMySaving() là một @Transactional. Dòng mục tiêu được khóa "
          "PESSIMISTIC_WRITE bằng findLockedById() trước tiên, nên hai lần góp cùng lúc vào một mục tiêu được cộng dồn "
          "chứ không ghi đè nhau; quyền sở hữu được kiểm tra trước khi ví bị đụng tới. Nếu bước tạo khoản chi thất bại "
          "(ví dụ số dư không đủ), số đã tiết kiệm cũng không đổi. Chủ sở hữu luôn lấy từ JWT: thân yêu cầu "
          "SavingContributionRequestDto chỉ có amount (@NotNull, @Positive, @Digits)."),
    diagram("d_save_seq", "Sơ đồ tuần tự mức thiết kế chức năng góp tiền tiết kiệm", "3",
            "ch3_gop_tien_tuan_tu.png", 16.0),
]

BUDGET_DESIGN_LINES = [
    "Ngân sách có thêm kỳ năm (BudgetPeriodType.YEAR, tối đa 366 ngày để chứa năm nhuận) và có thể đặt theo tên danh "
    "mục do người dùng gõ. Khi BudgetRequestDto không có categoryId mà có categoryName (tối đa 50 ký tự, đã bỏ khoảng "
    "trắng hai đầu), BudgetService gọi CategoryService.resolveOrCreate(): danh mục cùng tên, không phân biệt hoa "
    "thường, được dùng lại; chưa có thì tạo danh mục chi mới và ghi nhật ký CATEGORY_CREATED. TransactionService dùng "
    "cùng hàm này khi giao dịch nêu danh mục theo tên, nên một khoản chi ghi “cà phê” được tính vào ngân sách đặt cho "
    "“Cà phê”.",
]

CH3_END_PARA = (
    "Phần thiết kế giao diện mô tả 22 màn hình của ứng dụng di động và 8 trang Web Admin; ảnh chụp màn hình sẽ được "
    "nhóm bổ sung. Sơ đồ lớp mức thiết kế cùng tám sơ đồ ba lớp, chín sơ đồ tuần tự và một sơ đồ trạng thái cho thấy "
    "các quyết định chính: hàng đợi gửi với clientId để ghi giao dịch không trùng khi mất mạng, khóa dòng ví khi đổi số "
    "dư, lưu từng lượt đọc của AI, cảnh báo ngân sách chỉ khi vượt một mốc mới, hàng đợi quét trên thiết bị đọc tuần tự "
    "từng ảnh, chặn lưu hóa đơn trùng bằng mã 409 có lối “Vẫn lưu”, và góp tiền tiết kiệm trong một giao dịch CSDL. "
    "Thiết kế mô hình AI xác định tokenizer mở rộng từ vựng Unigram, định dạng nhãn bốn trường có che các trường chưa "
    "kiểm tra và quy trình hậu xử lý hai chặng.")

# ============================================================ Chương 4
AI_LOOP_PARA = (
    "Suy luận DONUT là tác vụ nặng về CPU. Nếu gọi model.generate() trực tiếp trong hàm async def, vòng lặp sự kiện "
    "(event loop) của uvicorn bị chiếm suốt thời gian đọc một hóa đơn và không trả lời được /health hay yêu cầu khác. "
    "Vì vậy phần xử lý ảnh và sinh chuỗi được tách thành hàm đồng bộ _run_donut(); handler vẫn là async def, đọc tệp "
    "bằng await image.read() rồi gọi await run_in_threadpool(_run_donut_locked, pil_img) để chạy suy luận trong thread "
    "pool của Starlette [34]. Hàm _run_donut_locked() giữ một threading.Lock (_donut_lock) quanh lượt suy luận, nên "
    "mỗi lúc chỉ một hóa đơn được đọc: container AI Service được cấp 3 GB bộ nhớ, đủ cho một lượt sinh chuỗi của mô "
    "hình, và hai lượt song song có nguy cơ làm tràn bộ nhớ. Hợp đồng API của /donut/scan không đổi. Kiểm thử "
    "test_scans_run_one_at_a_time_and_health_stays_responsive trong test_main.py gửi đồng thời hai yêu cầu quét và một "
    "yêu cầu /health, khẳng định số lượt suy luận chạy cùng lúc lớn nhất là 1 và /health trả lời trước khi lượt quét thứ "
    "hai kết thúc.")

BACKEND_TX_LINES = [
    "Mã clientId chỉ chống gửi lặp của cùng một lần lưu. Để chặn việc lưu hai lần cùng một tờ hóa đơn, trên luồng lưu "
    "có rawReceiptData, sau attachReceipt() và khi ví vẫn đang bị khóa, hàm refuseDuplicateReceipt() tìm giao dịch cùng "
    "chiều thu chi, cùng số tiền, cùng phút và cùng người bán đã chuẩn hóa (người bán trống coi như khớp). Nếu có, "
    "DuplicateReceiptException được ném, giao dịch CSDL quay lui và GlobalExceptionHandler trả 409 kèm mã và ngày của "
    "giao dịch đã có; TransactionRequestDto có thêm cờ allowDuplicate để người dùng vẫn lưu khi đó là một lần mua khác.",
    "SavingGoalController có thêm POST /api/savings/{id}/contributions. SavingGoalService.contributeToMySaving() khóa "
    "dòng mục tiêu, kiểm tra chủ sở hữu, ghi khoản chi danh mục “Tiết kiệm” qua createMyTransaction() rồi cộng "
    "currentAmount, tất cả trong một @Transactional; số dư không đủ thì InsufficientBalanceException (400) làm cả hai "
    "thay đổi quay lui. Kiểm thử SavingGoalContributionRollbackTest chạy trên giao dịch thật để khẳng định điều này.",
]

BACKEND_BUDGET_LINES = [
    "BudgetPeriodType có thêm hằng YEAR(366) bên cạnh WEEK(7) và MONTH(31); allowsRange() so số ngày của khoảng ngày, "
    "tính cả hai đầu, với độ dài tối đa của kỳ. Cột period_type của budgets và budgets_aud có ràng buộc CHECK do "
    "Hibernate sinh khi tạo bảng, mà ddl-auto=update không nới ràng buộc đã có, nên nhóm viết tệp "
    "core-backend/src/main/resources/db/budget-period-year-migration.sql để chạy tay bằng psql: tệp chạy trong một giao "
    "dịch, dừng nếu có dòng mang giá trị lạ, xóa mọi CHECK cũ trên cột rồi thêm ràng buộc chấp nhận WEEK, MONTH, YEAR, "
    "và chạy lại nhiều lần vẫn cho cùng kết quả. BudgetRequestDto nhận thêm categoryName; CategoryService.resolveOrCreate() "
    "là nơi duy nhất tìm danh mục theo tên (findFirstByNameIgnoreCaseOrderByIdAsc) hoặc tạo mới, dùng chung cho ngân "
    "sách và giao dịch.",
]

MOBILE_LINES = [
    "Quét nhiều hóa đơn: ReceiptScanQueue (lib/services/receipt_scan_queue.dart) giữ hàng đợi trong bảng mới "
    "receipt_scan_queue; SqfliteHelper nâng cơ sở dữ liệu từ phiên bản 7 lên 8, nhánh onUpgrade chỉ tạo bảng này và giữ "
    "nguyên dữ liệu các bảng cũ. Ảnh từ trình quét hoặc thư viện nằm trong thư mục tạm mà hệ điều hành có thể dọn, nên "
    "enqueue() chép từng ảnh vào thư mục receipt_queue trong thư mục tài liệu của ứng dụng, đặt tên bằng UUID. Mọi truy "
    "vấn của hàng đợi đều lọc theo user_id lấy từ SessionService.currentUserId, nên hai người dùng trên cùng một máy "
    "không thấy hàng đợi của nhau. MainScaffold gọi resume() trong initState để đọc tiếp sau khi ứng dụng mở lại. Tệp "
    "receipt_scan_queue_test.dart kiểm tra thứ tự đọc từng ảnh, tiến độ, lỗi mạng và đọc lại, khôi phục mục bị bỏ dở, "
    "dừng khi hết phiên, giới hạn 20 mục, ảnh bị mất và việc nâng cấp từ phiên bản 7.",
    "Biểu mẫu đối soát nhận thêm tham số initialScan: khi mở từ màn hình Chờ xác nhận, biểu mẫu điền bằng kết quả đã "
    "lưu (ReceiptScanResult) mà không gọi lại /donut/scan. Ảnh hóa đơn mở được ở màn xem toàn màn hình "
    "(ReceiptImageViewerPage), và chế độ đối chiếu đặt ảnh cạnh bốn trường để sửa. Khi checkout trả 409, AppRepository "
    "ném DuplicateReceiptException; biểu mẫu hiện hộp thoại AppDialog với hai lựa chọn và gửi lại bằng "
    "allowDuplicate = true khi người dùng chọn Vẫn lưu.",
    "Thành phần giao diện dùng chung: AppToast (lib/widgets/feedback/app_toast.dart) thay cho mọi chỗ gọi "
    "ScaffoldMessenger trước đây; thông báo trượt xuống ở phía trên màn hình, có biểu tượng và màu theo loại thành "
    "công, lỗi, thông tin lấy từ ColorScheme, tự tắt sau 3 giây (5 giây khi có nút thao tác) và mỗi lúc chỉ hiện một "
    "thông báo. MoneyInputFormatter (lib/core/utils/money_input_formatter.dart) nhóm chữ số theo ngôn ngữ trong lúc gõ, "
    "giữ vị trí con trỏ, và hàm parse() là chỗ duy nhất đọc ngược chuỗi ra số tiền; nó được dùng ở các ô tiền của thêm, "
    "sửa giao dịch, đối soát hóa đơn, ngân sách và tiết kiệm. DateField (lib/widgets/inputs/date_field.dart) là ô chọn "
    "ngày dùng chung cho các biểu mẫu đó.",
    "Đăng nhập: “Ghi nhớ đăng nhập” giữ nghĩa cũ là giữ phiên qua lần mở ứng dụng sau, và thêm việc nhớ email. Đăng "
    "nhập thành công khi có đánh dấu thì SessionService lưu email vào shared_preferences (khóa remembered_email); sau "
    "khi đăng xuất, màn hình đăng nhập điền sẵn email này; bỏ đánh dấu thì email đã lưu bị xóa. Ứng dụng không lưu mật "
    "khẩu. Biểu mẫu được bọc trong AutofillGroup với autofillHints cho email và mật khẩu, và gọi "
    "TextInput.finishAutofillContext() khi đăng nhập thành công [75], để trình quản lý mật khẩu của hệ điều hành đề "
    "nghị lưu rồi tự điền ở lần sau.",
    "Dọn chức năng: mục “Tạo / Đổi mã PIN” trong Hồ sơ bị xóa cùng các khóa ARB pin* và chỗ ghi app_pin, vì mã PIN "
    "này được ghi vào shared_preferences dưới dạng chữ thường nhưng không nơi nào đọc lại để khóa ứng dụng. Màn hình "
    "Dịch vụ liên kết được giữ, nhưng dùng dữ liệu giả lập nên tiêu đề và dòng menu của nó gắn DemoBadge “Bản demo”.",
]

# ============================================================ Kết luận – 4. Hướng phát triển
FUTURE = [
    ("p", "Các hướng phát triển dưới đây xuất phát từ những giới hạn đã nêu ở Chương 3 và Chương 4, chủ yếu là những "
          "phần nhóm cố ý chưa làm để kịp thời hạn nộp ngày 06/11/2026."),
    ("p", "Thứ nhất, chuyển hàng đợi quét hóa đơn lên máy chủ. Hàng đợi hiện nằm trên điện thoại nên chỉ chạy khi ứng "
          "dụng đang mở; một hàng đợi phía server (ảnh được tải lên trước, Core Backend hoặc một tiến trình riêng gọi "
          "AI Service rồi gửi thông báo khi đọc xong) sẽ tiếp tục làm việc cả khi người dùng đã đóng ứng dụng và cho "
          "phép đọc từ nhiều thiết bị. Nhóm chưa làm vì hai lý do: thời hạn nộp, và máy chủ hiện chỉ cấp 3 GB bộ nhớ cho "
          "AI Service, đủ cho đúng một lượt suy luận, nên muốn đọc song song cho nhiều người dùng thì phải có thêm "
          "máy hoặc hàng đợi có điều phối."),
    ("p", "Thứ hai, liên kết ngân hàng thật. Màn hình Dịch vụ liên kết hiện chỉ là bản demo với dữ liệu giả lập. Một "
          "cách khả thi cho tài khoản cá nhân là nhận webhook biến động số dư từ các dịch vụ trung gian như SePay [71] "
          "hoặc Casso [72]: dịch vụ gửi một yêu cầu HTTP POST tới máy chủ mỗi khi tài khoản đã liên kết có giao dịch mới, "
          "kèm chữ ký hoặc khóa bí mật để xác thực. Core Backend khi đó cần một endpoint công khai kiểm tra chữ ký, chống "
          "nhận trùng theo mã giao dịch của bên gửi và tạo giao dịch chờ người dùng xác nhận danh mục. Hướng này cần tài "
          "khoản và đăng ký với nhà cung cấp."),
    ("p", "Thứ ba, khóa ứng dụng bằng mã PIN hoặc sinh trắc học. Mã PIN cũ đã bị xóa vì không bảo vệ được gì; làm lại "
          "đúng cách cần lưu mã đã băm trong kho khóa an toàn của hệ điều hành (Android Keystore [73], iOS Keychain [74]) "
          "thay vì shared_preferences, và một màn hình khóa hiện mỗi khi ứng dụng quay lại tiền cảnh. Việc này cần thêm "
          "thư viện, nằm ngoài phạm vi đợt hoàn thiện hiện tại."),
    ("p", "Thứ tư, khóa lũy đẳng (idempotency key) cho thao tác góp tiền tiết kiệm. Khác với checkout có clientId, "
          "POST /api/savings/{id}/contributions chưa có khóa chống gửi lặp: nếu mạng ngắt sau khi máy chủ đã ghi nhưng "
          "trước khi ứng dụng nhận phản hồi, người dùng bấm lại sẽ góp hai lần. Thêm một mã do ứng dụng sinh, lưu cùng "
          "khoản chi và có ràng buộc duy nhất như (user_id, client_id), sẽ đóng khoảng hở này."),
    ("p", "Thứ năm, xuất Excel theo đúng kỳ đang xem. Sổ sách đã lọc được theo tuần, tháng và năm, nhưng nút xuất Excel "
          "vẫn luôn lấy giao dịch của tháng chứa ngày đang chọn. Tệp xuất nên dùng cùng khoảng ngày với kỳ trên màn "
          "hình."),
    ("y", "[T7.9] Bổ sung các hướng phát triển khác (mô hình DONUT, triển khai, kiểm thử) khi viết phần Kết luận."),
]

# ============================================================ ghép vào builder
INSERT_AFTER = [
    ("Hình 2.21: Sơ đồ use case hệ thống", UC_SUPPLEMENT),
    ("Hình 3.16: Màn hình Xác nhận hóa đơn", SCAN_NEW),
    ("Hình 3.23: Màn hình Sổ tiết kiệm",
     [shot("ui_contribute", "Bảng góp tiền vào mục tiêu tiết kiệm", "bảng Góp tiền mở từ một mục tiêu trên SavingsPage",
           "lib/screens/profile/savings_page.dart")]),
    ("Bảng budgets (Bảng 3.9) lưu hạn mức chi",
     [("y", "[Nhóm] Chạy core-backend/src/main/resources/db/budget-period-year-migration.sql trên CSDL đã triển khai "
            "(sau khi sao lưu) trước khi tạo ngân sách kỳ Năm; nếu chưa chạy, lưu ngân sách YEAR bị CSDL từ chối và API "
            "trả 409.")]),
]

INSERT_BEFORE = [
    ("Đặc tả use case phân hệ quản trị", UC_NEW),
    ("THIẾT KẾ MÔ HÌNH AI", DESIGN_NEW),
]

HEADING_PLACEHOLDERS = {"4. HƯỚNG PHÁT TRIỂN": FUTURE}

PARA_REPLACE = [
    ("Sơ đồ use case hệ thống được tách thành hai hình", ("p", UC_DIAGRAM_INTRO)),
    ("Mục này đặc tả 16 use case của phân hệ người dùng",
     ("p", "Mục này đặc tả 20 use case của phân hệ người dùng (Bảng 2.10 đến [[uc26]]). Trừ khi ghi khác, mọi yêu cầu từ "
           "ứng dụng tới Core Backend đều mang mã truy cập JWT (JSON Web Token) [28]; Core Backend xác định người dùng "
           "từ mã này chứ không từ tham số do ứng dụng gửi lên, nên mỗi người dùng chỉ đọc và sửa được dữ liệu của chính "
           "mình.")),
    ("Trang chủ (Hình 3.10) xếp theo chiều dọc", ("p", HOME_PARA)),
    ("Màn hình Thêm giao dịch (Hình 3.13)", ("p", ADD_TX_PARA)),
    ("Nút Quét AI mở bảng chọn nguồn ảnh", ("p", SCAN_SHEET_PARA)),
    ("Màn hình Ngân sách (Hình 3.17)", ("p", BUDGET_PARA)),
    ("Màn hình Thông báo (Hình 3.20)", ("p", NOTIF_PARA)),
    ("Màn hình Sổ tiết kiệm (Hình 3.23)", ("p", SAVINGS_PARA)),
    ("Màn hình Dịch vụ liên kết (Hình 3.25)", ("p", LINKED_PARA)),
    ("Bảng budgets (Bảng 3.9) lưu hạn mức chi",
     ("p", "Bảng budgets (Bảng 3.9) lưu hạn mức chi theo tuần, tháng hoặc năm. Giá trị YEAR được thêm sau đợt dùng thử; "
           "CSDL đã tạo trước đó cần chạy tệp migration ở mục 4.6.3 để ràng buộc CHECK của cột period_type chấp nhận "
           "giá trị mới.")),
    ("Bảng saving_goals (Bảng 3.10) lưu mục tiêu tiết kiệm",
     ("p", "Bảng saving_goals (Bảng 3.10) lưu mục tiêu tiết kiệm. Người dùng có thể sửa tay current_amount (PUT "
           "/api/savings/{id}) mà không ảnh hưởng số dư ví; riêng thao tác Góp tiền vừa cộng current_amount vừa tạo một "
           "khoản chi “Tiết kiệm” trừ vào ví, trong cùng một giao dịch CSDL (ràng buộc LB11 ở Bảng 3.19).")),
    ("Phần thiết kế giao diện mô tả 21 màn hình", ("p", CH3_END_PARA)),
    ("Một hạn chế của bản cài đặt hiện tại: /donut/scan", ("p", AI_LOOP_PARA)),
]

PARA_LINES_AFTER = [
    ("5b. Kết quả AI không có tổng tiền hợp lệ",
     ["5c. Người dùng đã có giao dịch cùng loại, cùng số tiền, cùng phút và cùng người bán: Core Backend trả 409, ứng "
      "dụng hỏi xem bản đã lưu hay vẫn lưu (UC26)."]),
    ("2b. Người dùng xóa một ngân sách",
     ["2c. Người dùng chọn danh mục “Khác” và nhập tên danh mục (bắt buộc, tối đa 50 ký tự): ứng dụng gửi tên thay cho "
      "mã danh mục; Core Backend dùng lại danh mục cùng tên không phân biệt hoa thường, chưa có thì tạo danh mục chi mới "
      "với tên đó."]),
    ("Phía ứng dụng, chuông trên Trang chủ đọc số thông báo chưa đọc", BUDGET_DESIGN_LINES),
    ("Đồng bộ ngoại tuyến dựa trên trường clientId", BACKEND_TX_LINES),
    ("BudgetController cung cấp các thao tác thêm, sửa, xóa", BACKEND_BUDGET_LINES),
    ("Quét hóa đơn: người dùng chụp bằng trình quét tài liệu", MOBILE_LINES),
]

TABLE_ROWS = [
    ("Danh sách use case hệ thống", None, UC_LIST_ROWS),
    ("Ràng buộc liên bộ và liên quan hệ", "CurrentUserProvider + truy vấn theo user_id", [
        ["LB10", "transactions, receipts",
         "Một hóa đơn quét không được lưu thành giao dịch mới khi người dùng đã có giao dịch cùng chiều thu chi, cùng số "
         "tiền, cùng phút và cùng người bán đã chuẩn hóa (người bán trống coi như khớp), trừ khi yêu cầu có "
         "allowDuplicate = true",
         "transactions: T (luồng lưu hóa đơn)",
         "TransactionService.refuseDuplicateReceipt() dưới khóa ví → 409"],
        ["LB11", "saving_goals, transactions, users",
         "Mỗi lần góp tiền, current_amount của mục tiêu tăng đúng bằng số tiền của khoản chi “Tiết kiệm” tạo cùng lúc, "
         "và wallet_balance giảm đúng chừng đó",
         "saving_goals: S (current_amount); transactions: T; users: S (wallet_balance)",
         "SavingGoalService.contributeToMySaving() (@Transactional, khóa dòng mục tiêu và dòng ví)"],
    ]),
    ("Danh sách API RESTful của Core Backend", "DELETE /api/savings/{id}", [
        ["", "POST /api/savings/{id}/contributions",
         "Góp tiền vào mục tiêu: tạo khoản chi “Tiết kiệm”, trừ ví, cộng số đã tiết kiệm", "JWT"]]),
    ("Danh sách màn hình của ứng dụng di động", "receipt_scanner/review_form_page.dart", [
        ["PendingReceiptsScreen", "receipt_scanner/pending_receipts_screen.dart",
         "Danh sách hóa đơn chờ xác nhận, đọc lại, bỏ, xác nhận tất cả hợp lệ", "UC23, UC24"]]),
]

TEXT_REPLACE = [
    ("Bảng 2.9 liệt kê 22 use case", "Bảng 2.9 liệt kê 26 use case", 1),
    ("Ở mức hệ thống, 22 use case", "Ở mức hệ thống, 26 use case", 1),
    ("“Xác nhận & Lưu”", "“Xác nhận và lưu”", 2),
    ("UC08 «include» UC09; UC09 «include» UC06",
     "UC08 «include» UC09; UC24 «include» UC09; UC26 «extend» UC09; UC09 «include» UC06", 1),
    ("kỳ tuần không quá 7 ngày và kỳ tháng không quá 31 ngày",
     "kỳ tuần không quá 7 ngày, kỳ tháng không quá 31 ngày và kỳ năm không quá 366 ngày", 1),
    ("4. Core Backend kiểm tra danh mục tồn tại và chưa có ngân sách trùng",
     "4. Core Backend xác định danh mục (theo mã, hoặc theo tên ở dòng 2c), kiểm tra chưa có ngân sách trùng", 1),
    ("Không có. Mục tiêu tiết kiệm là đầu vào cho phần gợi ý ngân sách của UC13.",
     "UC25 «extend» UC14. Mục tiêu tiết kiệm là đầu vào cho phần gợi ý ngân sách của UC13.", 1),
    ("nhập tên, số tiền mục tiêu, số tiền đã tiết kiệm và hạn chót.",
     "nhập tên và số tiền mục tiêu; số tiền đã tiết kiệm (mặc định 0) và ngày đạt mục tiêu không bắt buộc.", 1),
    ("tuần hoặc tháng", "tuần, tháng hoặc năm", 9),
    ("theo tuần/tháng, cảnh báo", "theo tuần/tháng/năm, cảnh báo", 1),
    ("periodType (WEEK, MONTH)", "periodType (WEEK, MONTH, YEAR)", 1),
    ("CHECK (WEEK, MONTH)", "CHECK (WEEK, MONTH, YEAR)", 1),
    ("period_type ∈ {WEEK, MONTH}", "period_type ∈ {WEEK, MONTH, YEAR}", 1),
    ("7 ngày với WEEK, 31 ngày với MONTH", "7 ngày với WEEK, 31 ngày với MONTH, 366 ngày với YEAR", 1),
    ("Tạo giao dịch (kèm hóa đơn nếu có), cập nhật số dư",
     "Tạo giao dịch (kèm hóa đơn nếu có), cập nhật số dư; hóa đơn có thể trùng trả 409 trừ khi allowDuplicate = true", 1),
    ("ô chọn Ghi nhớ đăng nhập (hiện chưa có tác dụng: giá trị không được lưu)",
     "ô chọn Ghi nhớ đăng nhập (giữ phiên qua lần mở ứng dụng sau và điền sẵn email ở lần đăng nhập tới; mật khẩu do "
     "trình quản lý mật khẩu của hệ điều hành lưu và tự điền, ứng dụng không lưu)", 1),
    ("bộ chọn kỳ Tuần/Tháng,", "bộ chọn kỳ Tuần/Tháng/Năm kèm nút Hôm nay (chỉ hiện khi kỳ đang xem không chứa ngày "
     "hôm nay),", 1),
    ("gồm 213 tệp Java", "gồm 216 tệp Java", 1),
    ("gồm 79 tệp .dart", "gồm 90 tệp .dart", 1),
    ("517 khóa", "569 khóa", 2),
    ("SqfliteHelper (SQLite phiên bản 7), LanguageInterceptor",
     "SqfliteHelper (SQLite phiên bản 8), ReceiptScanQueue (hàng đợi quét hóa đơn), LanguageInterceptor", 1),
    ("Thành phần dùng chung: hộp thoại AppDialog, thẻ, biểu đồ",
     "Thành phần dùng chung: hộp thoại AppDialog, AppToast, DateField, ScanQueueBanner, DemoBadge, thẻ, biểu đồ", 1),
    ("TransactionModel, BudgetModel, ReceiptModel, AppNotification, SyncStatus…",
     "TransactionModel, BudgetModel, ReceiptModel, ReceiptScanResult, ScanQueueItem, AppNotification, SyncStatus…", 1),
    (", /donut/scan chặn vòng lặp sự kiện khi suy luận", "", 1),
]
