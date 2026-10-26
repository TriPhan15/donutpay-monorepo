# Nội dung phiên v9 (26/10/2026): sửa các câu đã lỗi thời sau T4 (song ngữ), đợt sửa lỗi (6bc797c, 1898d1c, e619f54:
# InsufficientBalanceException khi checkout và khi xóa khoản thu, khóa ví cả khi không có clientId, GET /api/auth/check +
# forward_auth của Caddy, BackupType FULL/SCHEMA_ONLY/DATA_ONLY, users.html và nút Duyệt/Từ chối trên receipts.html,
# phiên tương tác dùng chung cho _dio và _mlDio, chạm thông báo mở giao dịch), T10/T11 (kỳ năm, hàng chờ quét) và T5
# (AI Service phục vụ V5, bộ nhớ 3 GB). Sinh KhoaLuan_KLCN175_v9.docx từ v8 bằng builder.py.
# Vẽ lại: ch3_lop_thiet_ke_thuc_the (BudgetPeriodType có YEAR), ch2_ngan_sach_hoat_dong (kỳ năm, danh mục theo tên),
# ch3_dieu_huong_di_dong (PendingReceiptsScreen từ banner), ch3_trien_khai (3 GB, forward_auth),
# ch3_hang_doi_trang_thai (nhãn chuyển reading → queued).
# Đối chiếu mã nguồn tại HEAD 5ce957c: TransactionService (create/delete/moveWallet, refuseDuplicateReceipt),
# TransactionRepository.findPossibleReceiptDuplicates (LEFT JOIN FETCH), AuthPaths (CHECK), deploy/caddy/Caddyfile,
# AdminController, templates/admin/{_layout, users, receipts, backup}.html, Entity/BackupType, GlobalExceptionHandler
# (AiServiceUnavailableException 503), docker-compose.yml (data-mining-api 3G), ai-service/ai_service.py (Version5),
# mobile-app lib/services/{receipt_scan_queue, remote_api_helper}.dart, screens/{main_scaffold, ledger/edit_transaction_page,
# receipt_scanner/pending_receipts_screen, notifications/notification_destination}.dart.
# Số trong văn bản: số Hình/Bảng cũ theo v8 (RENUMBER tự đổi); hình mới tham chiếu bằng [[khóa]].
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = None
SECTIONS = {}
RENUMBER = True
SRC = "nguồn: nhóm thực hiện"

IMAGE_REPLACE = [
    ("ch2_ngan_sach_hoat_dong.png", PNG + "ch2_ngan_sach_hoat_dong.png", "fit"),
    ("ch3_trien_khai.png", PNG + "ch3_trien_khai.png"),
    ("ch3_dieu_huong_di_dong.png", PNG + "ch3_dieu_huong_di_dong.png"),
    ("ch3_lop_thiet_ke_thuc_the.png", PNG + "ch3_lop_thiet_ke_thuc_the.png"),
    ("ch3_hang_doi_trang_thai.png", PNG + "ch3_hang_doi_trang_thai.png"),
]

# Ghi chú tô vàng đã hết hiệu lực sau đợt sửa lỗi (users.html sửa đường dẫn khóa, receipts.html có nút Duyệt/Từ chối).
PARA_DELETE = [
    "[Nhóm] Nút khóa/mở khóa trên trang users.html",
    "[Nhóm] Trang /admin/receipts hiện chỉ hiển thị danh sách",
    "[Nhóm] UC17 mô tả chức năng ở Core Backend.",
    "[Nhóm] receipts.html chưa có nút Duyệt/Từ chối",
]

INSERT_BEFORE = [
    ("[Nhóm] Chèn ảnh chụp màn hình /admin/receipts",
     [("fig", "Trang Quản lý người dùng", "3", None, 0, SRC,
       "[Nhóm] Chèn ảnh chụp màn hình /admin/users (templates/admin/users.html).", "ui_users")]),
]

PARA_REPLACE = [
    # Chương 1 – Docker: Caddy là dịch vụ thứ sáu (T8)
    ("Docker đóng gói ứng dụng cùng toàn bộ phụ thuộc",
     ("p", "Docker đóng gói ứng dụng cùng toàn bộ phụ thuộc thành image (ảnh đóng gói) và chạy dưới dạng container (vùng "
           "chạy cô lập); Docker Compose mô tả nhiều container cùng mạng, volume (vùng lưu trữ) và thứ tự khởi động trong "
           "một tệp YAML [38]. Hệ thống của đề tài được mô tả trong một tệp docker-compose.yml gồm sáu dịch vụ: reverse "
           "proxy Caddy, PostgreSQL, Redis, MongoDB, Core Backend và AI Service. Core Backend chỉ khởi động khi "
           "PostgreSQL, Redis và AI Service đã vượt qua kiểm tra sức khỏe (healthcheck); MongoDB không chặn việc khởi "
           "động vì chỉ dùng để lưu nhật ký.")),
    # 2.2 – đoạn kết: khóa ví không còn phụ thuộc clientId
    ("Sáu quy trình trên cho thấy ba điểm chung",
     ("p", "Sáu quy trình trên cho thấy ba điểm chung về cách hệ thống xử lý dữ liệu. Thứ nhất, mọi thay đổi số dư ví đều "
           "đi qua Core Backend. Các thao tác tạo, sửa, xóa giao dịch và duyệt hóa đơn đều khóa bản ghi ví trước khi đọc "
           "số dư và từ chối thay đổi nào làm số dư âm, nên hai yêu cầu đồng thời không ghi đè lên nhau; khi tạo giao "
           "dịch, mã clientId bảo đảm một giao dịch gửi lặp không làm trừ tiền hai lần. Thứ hai, ứng dụng di động gọi "
           "trực tiếp AI Service cho các tác vụ đọc hóa đơn và phân tích, còn kết quả chỉ được ghi vào cơ sở dữ liệu khi "
           "người dùng xác nhận; khi chưa gửi được, giao dịch nằm trong hàng đợi trên thiết bị cùng kết quả gốc của AI. "
           "Thứ ba, các thao tác thay đổi dữ liệu quan trọng đều có bản ghi trong nhật ký hoạt động. Mục 2.3 dựa trên các "
           "quy trình này để xác định use case ở mức hệ thống.")),
    ("Hai mươi hai use case trên phủ toàn bộ chức năng",
     ("p", "Hai mươi sáu use case trên (UC01–UC26) phủ toàn bộ chức năng mà ứng dụng di động và Web Admin đang cung cấp. "
           "Các chức năng có trong mã nguồn nhưng chưa được giao diện nào gọi (ví dụ đường dẫn lọc giao dịch, bảng điều "
           "khiển tổng hợp của người dùng hay đường dẫn gửi phản hồi về hóa đơn) không được đưa vào danh sách. Các bảng "
           "đặc tả này là cơ sở để xây dựng sơ đồ lớp mức phân tích ở mục 2.4.")),
    # 3.2.1 – Caddy chặn /ai/donut, /ai/spade khi chưa đăng nhập
    ("Mọi yêu cầu từ bên ngoài đi qua reverse proxy",
     ("p", "Mọi yêu cầu từ bên ngoài đi qua reverse proxy (máy chủ ủy quyền ngược) Caddy [52]. Caddy chuyển /ai/donut/, "
           "/ai/spade/ và /ai/health tới AI Service (bỏ tiền tố /ai), chặn các đường dẫn /actuator/* trừ /actuator/health, "
           "và chuyển phần còn lại tới Core Backend. Riêng /ai/donut/ và /ai/spade/ chỉ được chuyển tiếp khi Core Backend "
           "xác nhận access token của yêu cầu qua GET /api/auth/check (cơ chế forward_auth của Caddy), nên người chưa đăng "
           "nhập không gọi được mô hình. Đường dẫn /admin/segment của AI Service không đi ra ngoài được; chỉ Core Backend "
           "gọi nó qua mạng nội bộ khi quản trị viên chạy phân khúc khách hàng. Bảng 3.1 tóm tắt vai trò của từng thành "
           "phần.")),
    # 3.3.4 – LB2 nay áp cho mọi đường đổi số dư
    ("Một số ràng buộc hiện chỉ được bảo đảm ở tầng ứng dụng",
     ("p", "Một số ràng buộc hiện chỉ được bảo đảm ở tầng ứng dụng, chưa có ràng buộc tương ứng ở CSDL: amount > 0 của "
           "giao dịch, rating từ 1 đến 5, các trạng thái của receipts (cột chuỗi, không phải enum), và LB2 về số dư không "
           "âm (cột wallet_balance không có CHECK). LB2 được kiểm tra trên mọi đường đổi số dư: thêm, sửa giao dịch, xóa "
           "một khoản thu và duyệt hóa đơn đều đi qua moveWallet() khi dòng ví đang bị khóa, nên hai yêu cầu đồng thời "
           "không thể cùng vượt qua kiểm tra. Nhóm ghi nhận việc bổ sung các ràng buộc CHECK ở CSDL cho phiên bản sau.")),
    # 3.6.1 – T4 đã dịch toàn bộ ứng dụng
    ("Ứng dụng di động được xây dựng bằng Flutter [33] theo hệ thống thiết kế Material 3",
     ("p", "Ứng dụng di động được xây dựng bằng Flutter [33] theo hệ thống thiết kế Material 3 [57] (useMaterial3 = true, "
           "bảng màu sinh từ ColorScheme.fromSeed, phông chữ Poppins). Mỗi màn hình có hai bộ màu sáng và tối. Mọi chuỗi "
           "giao diện của các màn hình đều lấy từ tệp ARB tiếng Việt và tiếng Anh (mục 4.7.3), nên đổi ngôn ngữ trong Cài "
           "đặt là đổi toàn bộ ứng dụng; chỉ dữ liệu do người dùng nhập và thông báo lỗi tiếng Việt từ Core Backend giữ "
           "nguyên ngôn ngữ gốc. Sau khi đăng nhập, người dùng vào MainScaffold: khung này giữ bốn tab Trang chủ "
           "(DashboardPage), Thống kê (LedgerPage, tiêu đề màn hình là Sổ sách), AI (AITabPage) và Cá nhân (ProfilePage) "
           "trong một IndexedStack (ngăn xếp chỉ hiển thị một con) để không dựng lại tab khi chuyển qua lại, và đặt nút "
           "tròn Quét AI ở giữa thanh điều hướng. Bảng 3.25 liệt kê các màn hình cùng use case ở Chương 2 mà mỗi màn hình "
           "hiện thực.")),
    ("Hình 3.5 thể hiện đường đi giữa các màn hình chính.",
     ("p", "Hình 3.5 thể hiện đường đi giữa các màn hình chính. Luồng xác thực là một nhánh riêng: chỉ khi đăng nhập thành "
           "công, ứng dụng mới thay toàn bộ ngăn xếp điều hướng bằng MainScaffold (lệnh pushAndRemoveUntil, đẩy màn hình "
           "mới và xóa các màn hình cũ), nên nút quay lại không đưa người dùng về màn hình đăng nhập. Từ MainScaffold, nút "
           "Quét AI mở thẳng ReviewFormPage khi quét một ảnh, còn banner hàng chờ phía trên thanh tab mở "
           "PendingReceiptsScreen, nơi mỗi hóa đơn Sẵn sàng lại mở ReviewFormPage. Chạm một thông báo giao dịch hoặc hóa "
           "đơn đưa người dùng về Sổ sách với bảng chi tiết của giao dịch đó.")),
    # 3.6.2 – Web Admin sau khi tách users.html
    ("Web Admin là các trang Thymeleaf [55] do Core Backend sinh",
     ("p", "Web Admin là các trang Thymeleaf [55] do Core Backend sinh ở phía máy chủ, dùng Bootstrap 5.3 [56] cho bố cục "
           "và Chart.js [58] cho biểu đồ. Mọi trang dùng chung khung layout/_layout.html: thanh trên có tiêu đề trang và nút "
           "Đăng xuất, thanh bên trái có tám mục Bảng điều khiển, Quản lý Danh mục, Quản lý Gói Hội Viên, Quản lý Người "
           "dùng, Quản lý Hóa đơn AI, Quản lý Đánh giá, Nhật ký Hệ thống, Backup Dữ liệu. Khác với ứng dụng di động dùng "
           "JWT, Web Admin dùng chuỗi bộ lọc riêng của Spring Security với đăng nhập bằng biểu mẫu và phiên làm việc; mọi "
           "đường dẫn /admin/ yêu cầu vai trò ROLE_ADMIN. Các thao tác thêm, sửa, xóa trên trang gọi các endpoint "
           "/admin/ajax/ bằng hàm fetch (gửi yêu cầu HTTP từ JavaScript) rồi cập nhật bảng. Bảng 3.26 liệt kê các trang.")),
    ("Trang Quản lý User &",
     ("p", "Trang Quản lý người dùng ([[ui_users]]) là bảng phân trang gồm ID, username, email, số điện thoại, vai trò và "
           "cột trạng thái với các nút Sửa, Khóa/Mở khóa, Xóa, cùng nút Thêm người dùng mở hộp thoại tạo tài khoản. Trang "
           "Quản lý hóa đơn AI (Hình 3.37) là bảng phân trang gồm ID, tên cửa hàng, số tiền AI đọc được, nút xem ảnh gốc, "
           "trạng thái (Thành công, Lỗi AI, Đang xử lý) và cột Hành động. Nút Duyệt chỉ hiện ở hóa đơn được phép chuyển "
           "sang APPROVED, nút Từ chối chỉ hiện ở hóa đơn được phép chuyển sang FAILED; hai nút gửi POST tới "
           "/admin/receipts/approve/{id} và /admin/receipts/reject/{id} (mục 3.8.6).")),
    ("Trang Đánh giá (Hình 3.38) liệt kê đánh giá",
     ("p", "Trang Đánh giá (Hình 3.38) liệt kê đánh giá từ ứng dụng với số sao, nội dung, trạng thái Chờ duyệt/Đã duyệt và "
           "nút Duyệt, Xóa. Trang Nhật ký hệ thống (Hình 3.39) chia thành các thẻ Dữ liệu (CRUD), Bảo mật, Thống kê và Tra "
           "cứu nâng cao; thẻ tra cứu lọc theo người thực hiện, loại và mã đối tượng, khoảng thời gian, và thẻ Bảo mật có "
           "nút Gỡ khóa cho tài khoản đang bị khóa đăng nhập. Trang Sao lưu (Hình 3.40) có ba nút sao lưu ứng với ba giá trị "
           "của BackupType: FULL (toàn bộ cấu trúc và dữ liệu), SCHEMA_ONLY (chỉ cấu trúc) và DATA_ONLY (chỉ dữ liệu); mỗi "
           "loại chạy pg_dump ở định dạng custom với tham số riêng, và loại không thuộc danh sách bị từ chối. Nút phục "
           "hồi kèm cảnh báo xác nhận chỉ dùng bản FULL mới nhất, vì hai bản còn lại không tự dựng lại được CSDL.")),
    # 3.7 – khóa ví khi tạo giao dịch không còn phụ thuộc clientId; _mlDio có token
    ("Hình 3.42 trình bày ba tầng của Core Backend.",
     ("p", "Hình 3.42 trình bày ba tầng của Core Backend. Controller chỉ nhận yêu cầu, kiểm tra dữ liệu bằng @Valid và gọi "
           "service; service giữ toàn bộ nghiệp vụ trong giao dịch @Transactional; repository là các interface Spring Data "
           "JPA. Người dùng hiện tại luôn được CurrentUserProvider lấy từ SecurityContext. TransactionService là lớp trung "
           "tâm: nó khóa dòng ví bằng PESSIMISTIC_WRITE (lockWallet) trước khi đổi số dư ở mọi thao tác tạo, sửa, xóa "
           "giao dịch và duyệt hóa đơn, đổi số dư qua moveWallet() (ném InsufficientBalanceException khi số dư sẽ âm), "
           "gọi ReceiptProcessingService khi giao dịch có hóa đơn và gọi BudgetAlertService sau khi lưu để sinh cảnh báo "
           "ngân sách. Riêng đăng nhập vẫn được xử lý ngay trong AuthController (mục 3.8.1).")),
    ("Ở ứng dụng di động (Hình 3.43), các màn hình không gọi thẳng Dio",
     ("p", "Ở ứng dụng di động (Hình 3.43), các màn hình không gọi thẳng Dio mà đi qua AppRepository và RemoteApiHelper. "
           "AppRepository quyết định một giao dịch mới được ghi vào bảng SQLite cục bộ trước rồi mới gửi lên máy chủ, và "
           "cập nhật cờ SyncStatus (pending, synced, error) theo kết quả gửi. RemoteApiHelper giữ hai đối tượng Dio: _dio "
           "cho Core Backend và _mlDio cho AI Service. Cả hai dùng chung một bộ chặn phiên: gắn access token lấy từ "
           "SessionService và làm mới token khi nhận 401, vì Caddy chỉ chuyển yêu cầu tới AI Service khi token hợp lệ.")),
    ("[Nhóm] Bước 1 của Hình 3.55 giả định",
     ("p", "Duyệt và từ chối hiện chưa tạo thông báo cho người dùng; chủ hóa đơn chỉ thấy trạng thái mới qua nhãn hóa đơn "
           "trên Sổ sách.")),
    # 3.8.7 – đăng xuất không đưa mục đang đọc về queued nếu yêu cầu đã gửi thành công
    ("Hình 3.58 là sơ đồ trạng thái của một mục",
     ("p", "Hình 3.58 là sơ đồ trạng thái của một mục trong hàng đợi [47]. Hai chuyển trạng thái đáng chú ý đều quay về "
           "queued thay vì failed. Khi lượt đọc nhận 401 không làm mới được hoặc 403, phiên đăng nhập đã kết thúc và việc "
           "đọc tiếp không thể thành công, nên mục được trả về hàng chờ và vòng đọc dừng. Khi người dùng đăng xuất, vòng "
           "đọc dừng trước mục kế tiếp; các mục còn lại chỉ được đọc tiếp khi chính người dùng đó đăng nhập lại. Khi ứng "
           "dụng bị tắt lúc một mục đang reading, lần mở sau MainScaffold gọi resume(); đầu mỗi lượt chạy, mọi mục reading "
           "của người dùng được đưa về queued vì không còn ai đọc chúng. Lỗi mạng, lỗi máy chủ và ảnh không còn trên máy "
           "được ghi thành failed với mã cố định network, server, missing_image để màn hình hiển thị lý do bằng ngôn ngữ "
           "người dùng chọn.")),
    # 3.8.8 – truy vấn dùng LEFT JOIN FETCH, giao dịch nhập tay cũng là ứng viên
    ("Mã clientId ở mục 3.8.2 chỉ chống gửi lặp",
     ("p", "Mã clientId ở mục 3.8.2 chỉ chống gửi lặp của cùng một lần lưu; hai lần quét cùng một tờ hóa đơn sinh hai "
           "clientId khác nhau và trước đây đều được lưu. Chức năng chống lưu trùng (UC26) dùng các lớp của Hình 3.48, "
           "thêm DuplicateReceiptException và truy vấn findPossibleReceiptDuplicates() của TransactionRepository. Hình "
           "3.59 cho thấy kiểm tra chạy sau attachReceipt(), vì cần tên người bán của hồ sơ hóa đơn vừa tạo, và chạy khi "
           "dòng ví đang bị khóa, nên hai lần lưu cùng một hóa đơn gửi đồng thời không thể cùng vượt qua. Truy vấn lọc theo "
           "người dùng, chiều thu chi, số tiền và khoảng [phút, phút + 1) của ngày giao dịch, lấy kèm hồ sơ hóa đơn bằng "
           "LEFT JOIN FETCH trong một câu lệnh, nên một giao dịch nhập tay cùng số tiền và cùng phút (không có người bán) "
           "cũng được coi là bản đã lưu; tên người bán được so trong bộ nhớ sau khi normalizedSeller() chuyển về chữ "
           "thường, bỏ dấu và dấu câu.")),
    # 3.9 – AI Service đã chuyển sang V5 (T5)
    ("Mục 2.5.5 đã phân tích vì sao cách thêm ký tự",
     ("p", "Mục 2.5.5 đã phân tích vì sao cách thêm ký tự bằng added token ở bản V3 làm sai khoảng trắng tiếng Việt. Mục "
           "này trình bày thiết kế cụ thể của bản V5 trong ai-service/Version5/model_config.py. Sau khi huấn luyện xong, "
           "AI Service chuyển sang phục vụ bản V5 (mục 4.5.1); bản V3 được giữ làm mốc so sánh ở Chương 5. Bảng 3.28 tóm "
           "tắt các tham số thiết kế của hai bản.")),
    ("Ở AI Service, chuỗi sinh ra được bỏ token kết thúc",
     ("p", "Ở bản V3, AI Service bỏ token kết thúc và token đệm của chuỗi sinh ra, đưa chuỗi qua clean_vietnamese_text() "
           "để ghép lại các âm tiết bị tách bởi tokenizer V3, rồi dùng processor.token2json() chuyển thành JSON [40]. "
           "extract_final_cost() bỏ dấu chấm, dấu phẩy và lấy số lớn nhất trong chuỗi tổng tiền làm total_cost_number. "
           "Nếu chuỗi không chuyển được sang JSON, dịch vụ trả về {\"raw_text\": …} để ứng dụng cho người dùng nhập tay. "
           "Ở Core Backend, OcrService.extract() là nơi duy nhất đọc câu trả lời của AI; Bảng 3.30 liệt kê các quy tắc của "
           "nó.")),
    ("Thiết kế vẫn còn hạn chế: hậu xử lý ở AI Service",
     ("p", "Thiết kế vẫn còn hạn chế: ngày và địa điểm người dùng sửa trên biểu mẫu đối soát có thể bị giá trị AI ghi đè; "
           "duyệt hoặc từ chối hóa đơn chưa tạo thông báo cho người dùng; hàng đợi quét nhiều hóa đơn chỉ chạy khi ứng "
           "dụng đang mở. Chương 4 trình bày việc cài đặt các thiết kế này và quá trình huấn luyện mô hình DONUT.")),
    # 4.7.2 – sửa giao dịch đi thẳng PUT, không qua createTransaction
    ("Ghi chép thu chi: AddTransactionPage và EditTransactionPage",
     ("p", "Ghi chép thu chi: AddTransactionPage gửi giao dịch mới qua AppRepository.createTransaction(). Hàm này sinh "
           "clientId, ghi bản chờ vào SQLite trước, rồi mới gọi API; kết quả trả về là một SyncStatus (đã đồng bộ, chưa "
           "gửi được, bị từ chối). Các giao dịch chưa gửi được hiển thị nhãn trạng thái trong LedgerPage và được "
           "resendUnsyncedTransactions() gửi lại khi ứng dụng khởi động, khi quay lại từ nền, hoặc khi người dùng kéo để "
           "làm mới. EditTransactionPage chỉ gửi các trường đã đổi bằng PUT /api/transactions/{id} qua "
           "RemoteApiHelper.updateTransaction(), nên việc sửa cần có kết nối mạng.")),
    # 4.8 – giới hạn bộ nhớ AI Service là 3 GB
    ("Hai rủi ro còn lại: giới hạn 1 GB",
     ("p", "Hai rủi ro còn lại: giới hạn 3 GB cho AI Service mới được chọn theo ước lượng cho mô hình V5 (tệp trọng số "
           "khoảng 806 MB) chạy trên CPU với ảnh 1920 × 1440, chưa được đo trên máy chủ, và chỉ đủ cho một lượt suy luận "
           "mỗi lúc (mục 4.5.1); trọng số không nằm trong Git nên phải chép thủ công lên máy chủ trước khi build. Kết quả "
           "triển khai thực tế được trình bày ở Chương 5.")),
    ("[Nhóm] Sau khi triển khai, ghi bộ nhớ thực tế",
     ("y", "[Nhóm] Sau khi triển khai, ghi bộ nhớ thực tế của container data-mining-api khi quét một hóa đơn (lệnh docker "
           "stats) để xác nhận hoặc điều chỉnh giới hạn 3 GB.")),
]

TABLE_ROWS = [
    ("Danh sách API RESTful của Core Backend", "POST /api/auth/refresh", [
        ["", "GET /api/auth/check", "Kiểm tra access token cho forward_auth của Caddy (204 khi hợp lệ)", "JWT"]]),
    ("Danh sách trang của Web Admin", "/admin/subscriptions", [
        ["/admin/users", "users.html", "Thêm, sửa, xóa, khóa hoặc mở khóa tài khoản người dùng"]]),
]

TEXT_REPLACE = [
    # Chương 2 – quy trình nghiệp vụ
    ("6. Vì yêu cầu có clientId, Core Backend khóa bản ghi ví",
     "6. Core Backend khóa bản ghi ví", 1),
    ("8b. Người dùng xóa một giao dịch: Core Backend hoàn lại ảnh hưởng của giao dịch lên số dư rồi xóa;",
     "8b. Người dùng xóa một giao dịch: Core Backend hoàn lại ảnh hưởng của giao dịch lên số dư rồi xóa (nếu xóa một "
     "khoản thu làm số dư âm thì từ chối, giao dịch được giữ);", 1),
    ("độ dài kỳ không quá 7 ngày với kỳ tuần và không quá 31 ngày với kỳ tháng.",
     "độ dài kỳ không quá 7 ngày với kỳ tuần, 31 ngày với kỳ tháng và 366 ngày với kỳ năm.", 1),
    ("5. Core Backend kiểm tra danh mục tồn tại và người dùng chưa có ngân sách",
     "5. Core Backend xác định danh mục (theo mã, hoặc theo tên người dùng gõ khi chọn “Khác”: dùng lại danh mục cùng "
     "tên, chưa có thì tạo mới) và kiểm tra người dùng chưa có ngân sách", 1),
    # 2.3 – use case
    ("Web Admin: trang Người dùng, trang Hóa đơn", "Web Admin: trang Người dùng", 1),
    ("sửa số tiền, danh mục hoặc ghi chú: Core Backend khóa ví",
     "sửa số tiền, danh mục, ngày giao dịch hoặc ghi chú: Core Backend khóa ví", 1),
    ("hoàn lại ảnh hưởng của giao dịch lên số dư rồi xóa; giao dịch chưa từng đồng bộ chỉ bị xóa trên thiết bị.",
     "hoàn lại ảnh hưởng của giao dịch lên số dư rồi xóa; nếu xóa một khoản thu làm số dư âm, Core Backend trả 400 "
     "(InsufficientBalanceException) và giữ giao dịch. Giao dịch chưa từng đồng bộ chỉ bị xóa trên thiết bị.", 1),
    ("và mở màn hình Ngân sách nếu là cảnh báo ngân sách.",
     "rồi mở màn hình Ngân sách nếu là cảnh báo ngân sách, hoặc bảng chi tiết của giao dịch liên quan trên Sổ giao "
     "dịch nếu là thông báo giao dịch hay hóa đơn.", 1),
    ("3b. Phiên đăng nhập kết thúc (401, 403) hoặc người dùng đăng xuất: vòng đọc dừng, mục đang đọc trở về queued và "
     "chỉ được đọc tiếp khi chính người dùng đó đăng nhập lại.",
     "3b. AI Service trả 401 không làm mới được hoặc 403: mục đang đọc trở về queued và vòng đọc dừng. Người dùng đăng "
     "xuất: vòng đọc dừng trước mục kế tiếp. Các mục còn lại chỉ được đọc tiếp khi chính người dùng đó đăng nhập lại.", 1),
    ("Core Backend trả mã 400 kèm thông báo lỗi; nhãn cũ được giữ nguyên.",
     "Core Backend trả mã 503 với thông báo cố định (AiServiceUnavailableException); nhãn cũ được giữ nguyên.", 1),
    ("trong 22 bảng đặc tả use case", "trong 26 bảng đặc tả use case", 1),
    ("với cấu hình của bản V3 mà AI Service đang phục vụ",
     "với cấu hình của bản V3, bản AI Service phục vụ trước khi chuyển sang V5 (mục 4.5.1)", 1),
    ("Kiến trúc DONUT với cấu hình của mô hình đang phục vụ", "Kiến trúc DONUT với cấu hình của mô hình V3", 1),
    # Chương 3
    ("thông qua 22 use case", "thông qua 26 use case", 1),
    ("Giới hạn 1 GB; uvicorn", "Giới hạn 3 GB; uvicorn", 1),
    ("; khi tạo giao dịch, chỉ khóa nếu yêu cầu có clientId", "", 1),
    ("Thêm hoặc sửa một khoản chi không được làm wallet_balance nhỏ hơn 0",
     "Thêm, sửa, xóa giao dịch (kể cả xóa một khoản thu) và duyệt hóa đơn không được làm wallet_balance nhỏ hơn 0", 1),
    ("TransactionService (RuntimeException khi tạo; InsufficientBalanceException khi sửa, duyệt)",
     "TransactionService.moveWallet() dưới khóa ví → InsufficientBalanceException (400)", 1),
    ("liệt kê 49 endpoint REST", "liệt kê 51 endpoint REST", 1),
    (" (trừ change-password và logout), /api/payment/webhook", " (trừ change-password, logout và check), /api/payment/webhook", 1),
    ("Sửa số tiền, danh mục, ghi chú của giao dịch", "Sửa số tiền, danh mục, ngày, ghi chú của giao dịch", 1),
    ("mục Lỗi có nút Đọc lại, mọi mục có nút Bỏ.", "mục Lỗi có nút Đọc lại, mục Sẵn sàng và mục Lỗi có nút Bỏ.", 1),
    ("Danh sách hóa đơn AI và danh sách tài khoản", "Danh sách hóa đơn AI, duyệt hoặc từ chối từng hóa đơn", 1),
    ("Trang Quản lý User & Hóa đơn AI (nguồn", "Trang Quản lý hóa đơn AI (nguồn", 1),
    ("V3 (đang phục vụ)", "V3 (bản trước)", 1),
    ("V5 (huấn luyện lại)", "V5 (đang phục vụ)", 1),
    ("và 8 trang Web Admin", "và 9 trang Web Admin", 1),
    # Chương 4 – Bảng 4.10
    ("1 GB", "3 GB", 1),
]
