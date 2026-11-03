# Nội dung phiên K3 (01/11/2026): rà soát văn bản Chương 3 (Thiết kế hệ thống) theo loi_phan_C.md.
# Sinh KhoaLuan_KLCN175_v13.docx từ v12 bằng builder.py. Chỉ sửa chính tả, dấu câu, câu văn và các câu đã lệch so với mã
# nguồn; không thêm hoặc bớt mục, hình, bảng (chỉ tách đoạn, đổi chuỗi liệt kê thành gạch đầu dòng, thêm hai dòng tham số
# vào Bảng 3.32). Các ghi chú [Nhóm] và khung ảnh chụp màn hình giữ nguyên. Câu nào sửa theo mã nguồn thì ghi file trong
# chú thích. Thuật ngữ và dấu câu toàn quyển (tỉ/tỷ, cache/bộ nhớ đệm, service, endpoint, "Nguồn:", "..." và "…") để K5.
SESSION_TAG = None
SECTIONS = {}

PARA_REPLACE = [
    # ---- 3.1 (#1, #2) ----
    ("Chương 2 đã xác định hệ thống cần làm gì",
     ("p", "Chương 2 đã xác định hệ thống cần làm gì thông qua 26 use case và 15 lớp thực thể mức phân tích. Chương 3 trả lời câu "
           "hỏi hệ thống được tổ chức như thế nào để thực hiện các yêu cầu đó. Phần đầu của chương nêu kiến trúc tổng thể gồm ba "
           "dịch vụ ứng dụng và ba hệ lưu trữ, cùng cách các container được triển khai trên máy chủ. Tiếp theo là thiết kế cơ sở "
           "dữ liệu quan hệ: chuyển lớp phân tích thành bảng, sơ đồ thực thể kết hợp, mô tả từng bảng và đặc tả các ràng buộc toàn "
           "vẹn. Sau đó, chương mô tả phần dữ liệu đặt ngoài PostgreSQL (nhật ký AI trên MongoDB, bộ nhớ đệm và mã OTP trên Redis), "
           "danh sách API RESTful và cơ chế xác thực bằng JWT. Các mục 3.6 đến 3.9 lần lượt trình bày giao diện, lớp thiết kế, "
           "thiết kế chức năng và mô hình AI.")),
    # ---- 3.2.1 (#3) ----
    ("Ở tầng trình bày, ứng dụng di động Flutter",
     ("p", "Ở tầng trình bày, ứng dụng di động Flutter là kênh duy nhất của người dùng cuối. Ứng dụng gọi Core Backend để đọc, ghi "
           "dữ liệu và gọi thẳng AI Service để quét hóa đơn, phân tích thói quen chi tiêu. Kết quả quét chỉ được lưu khi người dùng "
           "đối soát xong và gửi giao dịch về Core Backend. SQLite trên máy là hàng đợi (outbox) cho những giao dịch tạo khi mất "
           "mạng. Web Admin không phải một ứng dụng riêng mà là các trang Thymeleaf do Core Backend sinh ra dưới đường dẫn /admin, "
           "dùng phiên đăng nhập thay vì JWT.")),
    # ---- 3.2.2 (#5, #6, #7, #8) ----
    # core-backend/.../Security/JwtUtil.java dòng 29-30 (MIN_SECRET_BYTES = 32); .github/workflows/ci.yml dòng 90 (JWT_SECRET=.{32,})
    ("Thiết kế mạng tuân theo nguyên tắc",
     ("p", "Thiết kế mạng tuân theo nguyên tắc chỉ mở những gì cần mở. Proxy là container duy nhất công bố cổng ra Internet; "
           "core-api và data-mining-api chỉ khai báo cổng nội bộ (expose) trên mạng bridge finance-network. PostgreSQL và MongoDB "
           "chỉ gắn vào địa chỉ loopback 127.0.0.1 của máy chủ để quản trị viên kết nối qua đường hầm SSH khi cần, còn Redis không "
           "mở cổng nào. Khóa ký JWT (JWT_SECRET) và các mật khẩu CSDL nằm trong tệp .env trên máy chủ, không có trong kho mã "
           "nguồn. Ở profile prod, Core Backend từ chối khởi động nếu thiếu JWT_SECRET hoặc khóa ngắn hơn 32 byte, mức tối thiểu "
           "256 bit của thuật toán HS256.")),
    ("Quy trình tích hợp và triển khai liên tục",
     ("p", "Quy trình tích hợp và triển khai liên tục dùng GitHub Actions [45]. Mỗi lần đẩy mã, ba job backend-ci, mobile-ci và "
           "ai-ci chạy kiểm thử của từng thành phần. Khi mã được đẩy lên nhánh main và cả ba job đều đạt, job deploy kết nối SSH "
           "tới máy chủ EC2 và kiểm tra tệp .env có JWT_SECRET dài ít nhất 32 ký tự (với khóa chỉ gồm ký tự ASCII, đó cũng là 32 "
           "byte). Sau đó job cập nhật mã theo origin/main, rồi chạy docker compose build và docker compose up -d --wait để thay "
           "container mới. Khi đẩy một tag bắt đầu bằng v, job release-apk biên dịch tệp APK đã ký và đính kèm vào bản phát hành "
           "trên GitHub, để người dùng tải về điện thoại Android.")),
    # ---- 3.3.1 (#10, #11, #12) ----
    ("Mô hình quan hệ biểu diễn dữ liệu dưới dạng",
     ("p", "Mô hình quan hệ biểu diễn dữ liệu dưới dạng các quan hệ (bảng), mỗi quan hệ là tập các bộ có cùng tập thuộc tính, và "
           "liên kết giữa các quan hệ được thể hiện bằng giá trị khóa [50]. Nhóm chuyển 15 lớp thực thể ở mục 2.4 sang mô hình này "
           "theo bốn quy tắc quen thuộc:")),
    ("Mô hình quan hệ thu được gồm 13 bảng",
     ("p", "Mô hình quan hệ thu được gồm 13 bảng nghiệp vụ. Tám trong 13 bảng kế thừa lớp BaseEntity nên có thêm hai cột "
           "created_at, updated_at do Spring Data tự điền. Chín thực thể được đánh dấu @Audited (users, categories, transactions, "
           "receipts, budgets, saving_goals, notifications, payment_orders, subscription_plans). Hibernate Envers sinh cho mỗi "
           "thực thể một bảng lịch sử có hậu tố _aud cùng một bảng revision ghi người sửa. Các bảng lịch sử này là phần kỹ thuật, "
           "không được vẽ trong ERD.")),
    # ---- 3.3.4 (#19, #20, #27, #28) ----
    ("Ràng buộc toàn vẹn (RBTV) là điều kiện",
     ("p", "Ràng buộc toàn vẹn (RBTV) là điều kiện mà dữ liệu phải thỏa mãn ở mọi thời điểm. Mỗi ràng buộc dưới đây được mô tả "
           "bằng bối cảnh (các bảng liên quan), nội dung, tầm ảnh hưởng và nơi kiểm tra.")),
    ("Một số ràng buộc hiện chỉ được bảo đảm",
     ("p", "Một số ràng buộc hiện chỉ được bảo đảm ở tầng ứng dụng, chưa có ràng buộc tương ứng ở CSDL: amount > 0 của giao dịch, "
           "rating từ 1 đến 5, các trạng thái của receipts (cột chuỗi, không phải enum), và LB2 về số dư không âm (cột "
           "wallet_balance không có CHECK). Nhóm ghi nhận việc bổ sung các ràng buộc CHECK ở CSDL cho phiên bản sau.")),
    # ---- 3.4.1 (#30, #31) ----
    ("Việc ghi vào ocr_logs được thiết kế",
     ("p", "Việc ghi vào ocr_logs được thiết kế để không ảnh hưởng tới giao dịch chính. Khi lưu một giao dịch kèm hóa đơn, "
           "ReceiptProcessingService phát sự kiện OcrProcessedEvent. OcrMongoService nhận sự kiện bằng @TransactionalEventListener "
           "ở pha AFTER_COMMIT và chạy bất đồng bộ trên luồng mongoAsyncExecutor. Nhờ vậy, document chỉ được ghi khi dữ liệu trong "
           "PostgreSQL đã chắc chắn tồn tại, và yêu cầu của người dùng không phải chờ MongoDB. Nếu chuỗi trả về không phải JSON "
           "hợp lệ, nó được bọc vào trường unparsed_raw_string. Nếu MongoDB lỗi, service chỉ ghi log lỗi chứ không ném ngoại lệ. "
           "Vì vậy, mất một document trong ocr_logs không làm mất dữ liệu nghiệp vụ: bản gốc vẫn nằm trong "
           "receipt_processing_attempts. Quản trị viên xem ocr_logs qua API GET /api/admin/ocr-logs.")),
    # ---- 3.4.2 (#32, #34, #35, #36, #37, #38, #106) ----
    # Hai endpoint thống kê có cache chưa được app gọi: mobile-app/lib không có app-dashboard, popular-vendors (grep);
    # AdminController.java dòng 117, 128 dùng AdminStatisticsService (cache quản trị)
    ("Redis là kho dữ liệu khóa – giá trị nằm trong bộ nhớ",
     ("p", "Redis là kho khóa – giá trị trong bộ nhớ, có độ trễ thấp và cho phép đặt thời gian sống (TTL) cho từng khóa nên thường "
           "được dùng làm bộ nhớ đệm [36]. Core Backend dùng Redis cho hai việc: đệm kết quả các truy vấn thống kê tốn kém theo mô "
           "hình cache-aside qua Spring Cache [31], và lưu mã OTP đặt lại mật khẩu. Các cache quản trị phục vụ trang Bảng điều khiển "
           "của Web Admin. Các cache người dùng phục vụ hai endpoint /api/transactions/app-dashboard và "
           "/api/transactions/popular-vendors, mà ứng dụng di động hiện chưa gọi vì tự tính thống kê trên thiết bị (mục 3.8.5). "
           "Bảng 3.22 liệt kê các loại khóa.")),
    ("Khóa của các cache thống kê có dạng",
     ("p", "Khóa của các cache thống kê có dạng <tiền tố>:v1:<tên cache>:<tham số>, trong đó tiền tố mặc định là ledgermind:<profile "
           "đang chạy> và v1 là phiên bản cấu trúc dữ liệu. Khi đổi cấu trúc DTO, chỉ cần tăng phiên bản để bỏ qua toàn bộ khóa cũ. "
           "Giá trị được lưu dưới dạng JSON thuần và được đọc lại bằng bộ chuyển đổi theo đúng kiểu DTO của từng cache. Hệ thống "
           "không dùng tuần tự hóa Java. TTL được cấu hình trong redis-cache.properties và bị trừ ngẫu nhiên tối đa 10% để các khóa "
           "không hết hạn cùng lúc.")),
    ("Điểm quan trọng nhất của thiết kế",
     ("p", "Thời điểm xóa cache là quyết định thiết kế chính. Các service không xóa cache trực tiếp mà phát sự kiện "
           "StatisticsChangedEvent kèm loại thay đổi (TRANSACTION_TOTALS, RECEIPT_STATUS, ACCOUNT_CREATED…) và mã người dùng. "
           "StatisticsCacheEvictor nhận sự kiện ở pha AFTER_COMMIT: nó xóa các khóa của đúng người dùng đó trong các cache người "
           "dùng, và xóa toàn bộ các cache quản trị bị ảnh hưởng. Nếu xóa ngay trong giao dịch, một yêu cầu đọc chen vào trước khi "
           "giao dịch hoàn tất có thể nạp lại số liệu cũ vào cache. Xóa sau khi giao dịch hoàn tất tránh được điều này, và nếu "
           "giao dịch bị hủy thì cache không bị xóa vô ích.")),
    ("Redis được coi là thành phần",
     ("p", "Hệ thống được thiết kế để vẫn chạy khi Redis gặp sự cố. Thư viện Lettuce (client Redis) từ chối lệnh ngay khi mất kết "
           "nối, với thời gian chờ lệnh là 500 ms. FallbackCacheErrorHandler biến lỗi đọc cache thành truy vấn thẳng vào "
           "PostgreSQL. Lỗi xóa chỉ được ghi log, và khóa sẽ tự hết hạn theo TTL. Riêng kho OTP không có đường dự phòng: khi Redis "
           "lỗi, yêu cầu quên mật khẩu nhận mã 503. Việc lưu và kiểm tra OTP chạy bằng script Lua để kiểm tra mã, hạn dùng và đếm "
           "số lần sai trong một thao tác nguyên tử. Hạn chế đã biết là mô hình cache-aside không có khóa phân tán, nên vài yêu cầu "
           "đồng thời khi cache trống có thể cùng tính lại một số liệu.")),
    # ---- 3.5.1 (#40, #41, #42) ----
    # UserController.java dòng 47-55 và UserService.java dòng 103-107: PUT /api/users/{id} từ chối (403) id khác người gọi
    ("REST là kiểu kiến trúc",
     ("p", "REST là kiểu kiến trúc trong đó tài nguyên được định danh bằng URI và được thao tác qua các phương thức chuẩn của HTTP. "
           "Mỗi yêu cầu mang đủ thông tin để máy chủ xử lý mà không cần lưu phiên [29].")),
    # ---- 3.5.2 (#44, #46-#49) ----
    # P732 gốc có chữ đậm sai (builder cũ hiểu "/**" là đánh dấu đậm); viết lại không dùng ký tự *
    ("JSON Web Token (JWT) là chuỗi gồm",
     ("p", "JSON Web Token (JWT) là chuỗi gồm phần đầu, phần nội dung (các claim) và chữ ký, cho phép máy chủ kiểm tra tính toàn "
           "vẹn của thông tin mà không cần lưu phiên [28]. Core Backend dùng Spring Security [32] với hai chuỗi bộ lọc. Chuỗi thứ "
           "nhất áp cho các đường dẫn /admin, dùng phiên đăng nhập bằng biểu mẫu và chỉ cho vai trò ROLE_ADMIN. Chuỗi thứ hai áp "
           "cho các đường dẫn /api, không lưu phiên (STATELESS), tắt CSRF và xác thực bằng JWT trong tiêu đề Authorization: "
           "Bearer. Trong chuỗi thứ hai, quyền truy cập chia thành ba mức:")),
    ("Ba cơ chế thu hồi bổ sung cho nhau",
     ("p", "Hệ thống thu hồi token theo ba cách: đăng xuất, xoay vòng refresh token và đổi mật khẩu.")),
    # ---- 3.6.1 (#50, #51, #52, #54-#56, #59-#61) ----
    ("Ứng dụng di động được xây dựng bằng Flutter [33] theo hệ thống",
     ("p", "Ứng dụng di động được xây dựng bằng Flutter [33] theo hệ thống thiết kế Material 3 [57] (useMaterial3 = true, bảng màu "
           "sinh từ ColorScheme.fromSeed, phông chữ Poppins). Mỗi màn hình có hai bộ màu sáng và tối.")),
    ("Hình 3.5 thể hiện đường đi giữa các màn hình chính",
     ("p", "Hình 3.5 thể hiện đường đi giữa các màn hình chính. Luồng xác thực là một nhánh riêng: chỉ khi đăng nhập thành công, "
           "ứng dụng mới thay toàn bộ ngăn xếp điều hướng bằng MainScaffold, nên nút quay lại không đưa người dùng về màn hình "
           "đăng nhập. Việc thay này dùng lệnh pushAndRemoveUntil, đẩy màn hình mới và xóa các màn hình cũ. Từ MainScaffold, nút "
           "Quét AI mở thẳng ReviewFormPage khi quét một ảnh, còn banner (thanh thông báo) hàng chờ phía trên thanh tab mở "
           "PendingReceiptsScreen, nơi mỗi hóa đơn Sẵn sàng lại mở ReviewFormPage. Chạm một thông báo giao dịch hoặc hóa đơn đưa "
           "người dùng về Sổ sách với bảng chi tiết của giao dịch đó.")),
    ("Màn hình Đăng nhập (Hình 3.6) gồm logo",
     ("p", "Màn hình Đăng nhập (Hình 3.6) gồm logo, hai ô Email và Mật khẩu, ô chọn Ghi nhớ đăng nhập, liên kết Quên mật khẩu, nút "
           "Đăng nhập và hai nút đăng nhập bằng Google, Facebook. Ô Ghi nhớ đăng nhập giữ phiên qua lần mở ứng dụng sau và điền sẵn "
           "email ở lần đăng nhập tới. Mật khẩu do trình quản lý mật khẩu của hệ điều hành lưu và tự điền, ứng dụng không lưu.")),
    ("Khôi phục mật khẩu đi qua hai màn hình",
     ("p", "Khôi phục mật khẩu đi qua hai màn hình. Màn hình Quên mật khẩu (Hình 3.8) chỉ có ô Email và nút Gửi mã OTP.")),
    ("Trang chủ (Hình 3.10) xếp theo chiều dọc",
     ("p", "Trang chủ (Hình 3.10) xếp theo chiều dọc gồm các khối sau:")),
    ("Màn hình Sổ sách (Hình 3.11) có ô tìm kiếm",
     ("p", "Màn hình Sổ sách (Hình 3.11) có các thành phần sau:")),
    # ---- 3.6.1 quét hóa đơn (#64, #67) ----
    # mobile-app/lib/l10n/app_vi.arb dòng 79-88: scanSheetTitle, scanOptionCamera, scanOptionGallery, scanOptionBatch, scanOptionBatchGallery
    ("Nút Quét AI mở bảng chọn nguồn ảnh",
     ("p", "Nút Quét AI mở bảng chọn nguồn ảnh “Quét hóa đơn bằng AI” (Hình 3.15) với bốn lựa chọn:")),
    ("Khi hàng chờ có mục, banner ScanQueueBanner",
     ("p", "Khi hàng chờ có mục, banner ScanQueueBanner (Hình 3.19) nằm ngay trên thanh tab của MainScaffold nên hiện ở mọi tab. "
           "Banner thay đổi theo trạng thái của hàng chờ:")),
    ("Màn hình Ngân sách (Hình 3.21) liệt kê",
     ("p", "Màn hình Ngân sách (Hình 3.21) liệt kê các ngân sách, mỗi thẻ gồm danh mục, kỳ, số đã chi trên hạn mức và thanh tiến "
           "độ đổi màu khi đạt 80% và 100%.")),
    # ---- 3.6.1 tab AI (#73, #108) ----
    ("Tab AI (Hình 3.23), lớp AITabPage",
     ("p", "Tab AI (Hình 3.23), lớp AITabPage, có bộ chọn khoảng thời gian ở thanh tiêu đề và nút làm mới. Nội dung gồm các khối "
           "sau:")),
    ("Màn hình Thông báo (Hình 3.24) là danh sách",
     ("p", "Màn hình Thông báo (Hình 3.24) là danh sách tải theo trang, thông báo chưa đọc được tô nổi và gắn nhãn Chưa đọc. Nút "
           "Đọc tất cả trên thanh tiêu đề đánh dấu toàn bộ. Chạm vào một thông báo luôn đánh dấu nó đã đọc rồi mở đích của nó:")),
    ("Trang Cá nhân (Hình 3.25) là danh sách nhóm dòng",
     ("p", "Trang Cá nhân (Hình 3.25) gồm bốn nhóm mục:")),
    # ---- 3.6.1 tiết kiệm, tài khoản, ví liên kết (#76-#79) ----
    ("Màn hình Sổ tiết kiệm (Hình 3.27) có thẻ tổng",
     ("p", "Màn hình Sổ tiết kiệm (Hình 3.27) có thẻ tổng đã tiết kiệm trên tổng mục tiêu, danh sách mục tiêu với thanh tiến độ và "
           "ngày đạt mục tiêu. Vuốt một mục để xóa, còn nút Cập nhật cho sửa tay số đã tiết kiệm. Khi tạo mục tiêu, ô Đã tiết kiệm "
           "và ô Ngày đạt mục tiêu đều không bắt buộc. Nút Góp tiền trên từng mục tiêu mở bảng nhập số tiền (Hình 3.28) với lời "
           "giải thích “Trừ vào số dư ví và ghi thành khoản chi ‘Tiết kiệm’” (UC25).")),
    ("Màn hình Dịch vụ liên kết (Hình 3.30) liệt kê",
     ("p", "Màn hình Dịch vụ liên kết (Hình 3.30) liệt kê ví điện tử đã liên kết. Chọn một ví mở hộp nhập số tiền (tối thiểu 1.000 "
           "đồng), rồi ứng dụng tạo đơn thanh toán qua cổng giả lập và theo dõi trạng thái đơn. Dữ liệu ví ở màn hình này là giả "
           "lập (nhà cung cấp MOCK), nên cả tiêu đề màn hình lẫn dòng Dịch vụ liên kết ở trang Cá nhân đều gắn nhãn “Bản demo” và "
           "ghi chú rằng ứng dụng không kết nối với ngân hàng hay ví điện tử thật.")),
    # ---- 3.6.2 (#80-#84) ----
    ("Web Admin là các trang Thymeleaf",
     ("p", "Web Admin là các trang Thymeleaf [55] do Core Backend sinh ở phía máy chủ, dùng Bootstrap 5.3 [56] cho bố cục và "
           "Chart.js [58] cho biểu đồ. Mọi trang dùng chung khung layout/_layout.html: thanh trên có tiêu đề trang và nút Đăng xuất, "
           "thanh bên trái có tám mục “Bảng điều khiển”, “Quản lý Danh mục”, “Quản lý Gói Hội Viên”, “Quản lý Người dùng”, “Quản lý "
           "Hóa đơn AI”, “Quản lý Đánh giá”, “Nhật ký Hệ thống” và “Backup Dữ liệu” (mục này mở trang Sao lưu).")),
    # templates/admin/dashboard.html dòng 16, 28, 40, 52, 177; TransactionService.LOW_BALANCE_THRESHOLD = 50000 (dòng 81)
    ("Trang Đăng nhập (Hình 3.33) gồm hai ô",
     ("p", "Trang Đăng nhập (Hình 3.33) gồm hai ô Tài khoản, Mật khẩu và nút Đăng nhập hệ thống. Sau khi nhập sai nhiều lần liên "
           "tiếp, tài khoản hoặc địa chỉ IP bị khóa tạm thời theo quy tắc ở mục 3.5.2, như ở ứng dụng di động.")),
    ("Trang Quản lý người dùng (Hình 3.37)",
     ("p", "Trang Quản lý người dùng (Hình 3.37) là bảng phân trang gồm ID, username, email, số điện thoại, vai trò và cột trạng "
           "thái với các nút Sửa, Khóa/Mở khóa, Xóa, cùng nút Thêm người dùng mở hộp thoại tạo tài khoản.")),
    ("Trang Đánh giá (Hình 3.39)",
     ("p", "Trang Đánh giá (Hình 3.39) liệt kê đánh giá từ ứng dụng với số sao, nội dung, trạng thái Chờ duyệt/Đã duyệt và nút "
           "Duyệt, Xóa.")),
    # ---- 3.7 (#92, #93, #94) ----
    ("Hình 3.43 trình bày ba tầng của Core Backend",
     ("p", "Hình 3.43 trình bày ba tầng của Core Backend. Controller chỉ nhận yêu cầu, kiểm tra dữ liệu bằng @Valid và gọi service. "
           "Service giữ toàn bộ nghiệp vụ trong giao dịch @Transactional. Repository là các interface Spring Data JPA. Người dùng "
           "hiện tại luôn được CurrentUserProvider lấy từ SecurityContext. TransactionService là lớp trung tâm, với bốn việc:")),
    ("Ở ứng dụng di động (Hình 3.44)",
     ("p", "Ở ứng dụng di động (Hình 3.44), các màn hình không gọi thẳng Dio mà đi qua AppRepository và RemoteApiHelper. "
           "AppRepository quyết định một giao dịch mới được ghi vào bảng SQLite cục bộ trước rồi mới gửi lên máy chủ, và cập nhật "
           "cờ SyncStatus (pending, synced, error) theo kết quả gửi. RemoteApiHelper giữ hai đối tượng Dio: _dio cho Core Backend "
           "và _mlDio cho AI Service. Cả hai đều cần access token vì Caddy chỉ chuyển yêu cầu tới AI Service khi token hợp lệ, nên "
           "dùng chung một bộ chặn (interceptor) phiên: bộ chặn này gắn access token lấy từ SessionService và làm mới token khi "
           "nhận 401.")),
    # ---- 3.8.1 (#96, #97) ----
    ("Mỗi chức năng chính được thiết kế bằng hai sơ đồ",
     ("p", "Mỗi chức năng chính được thiết kế bằng hai sơ đồ. Sơ đồ ba lớp phân loại các thành phần tham gia thành biên (Boundary, "
           "giao tiếp với tác nhân hoặc hệ thống khác), điều khiển (Control, điều phối nghiệp vụ) và thực thể (Entity, dữ liệu được "
           "lưu) theo cách phân loại của Jacobson [54]. Sơ đồ tuần tự mức thiết kế dùng đúng tên lớp và tên phương thức trong mã "
           "nguồn, chỉ vẽ dòng sự kiện chính của use case tương ứng ở Chương 2 [47].")),
    ("Hình 3.46 là sơ đồ tuần tự.",
     ("p", "Hình 3.46 là sơ đồ tuần tự. credentialsVersion được đọc (thông điệp 5) trước khi so mật khẩu (thông điệp 6), nên nếu "
           "mật khẩu bị đổi trong lúc đang kiểm tra, token sinh ra mang phiên bản cũ và bị từ chối ngay ở yêu cầu kế tiếp. Khi xác "
           "thực thất bại, AuthController ghi một lần sai rồi trả 401, hoặc 429 nếu lần sai này làm tài khoản bị khóa.")),
    # ---- 3.8.2 (#98-#100) ----
    ("Chức năng ghi giao dịch (UC06) và đồng bộ",
     ("p", "Chức năng ghi giao dịch (UC06) và đồng bộ giao dịch offline (UC07) dùng chung các lớp ở Hình 3.47. Phía ứng dụng, "
           "AppRepository là lớp điều khiển, đồng thời giữ hàng đợi gửi trong bảng SQLite qua SqfliteHelper. Phía máy chủ, "
           "TransactionService cập nhật đồng thời ba thực thể User (số dư ví), Transaction và Category (tạo danh mục theo tên khi "
           "chưa có).")),
    ("Hình 3.48 trình bày dòng chính khi có mạng",
     ("p", "Hình 3.48 trình bày dòng chính khi có mạng. Giao dịch được ghi cục bộ với trạng thái pending và một clientId dạng UUID "
           "trước khi gửi (thông điệp 3), nên không mất dữ liệu nếu ứng dụng bị tắt giữa chừng. TransactionController chuyển thẳng "
           "yêu cầu cho createMyTransaction() nên không vẽ thành lifeline riêng. Ở máy chủ, dòng ví bị khóa trước khi tìm clientId "
           "(thông điệp 6, 7). Nếu clientId đã tồn tại, máy chủ trả lại giao dịch đã tạo thay vì tạo bản thứ hai. Ràng buộc duy "
           "nhất (user_id, client_id) ở mục 3.3.4 là lớp bảo vệ cuối ở tầng CSDL.")),
    ("Khi mất mạng, hết thời gian chờ",
     ("p", "Khi mất mạng, hết thời gian chờ hoặc máy chủ lỗi 5xx, _send() đổi cờ thành error và màn hình báo “Chưa gửi được lên "
           "máy chủ”. Giao dịch vẫn hiển thị trong Sổ sách với huy hiệu đồng bộ.")),
    # ---- 3.8.3 (#101, #102) ----
    ("Theo Hình 3.50, sau khi người dùng xác nhận",
     ("p", "Theo Hình 3.50, sau khi người dùng xác nhận, ảnh mới được tải lên Cloudinary qua POST /api/upload (thông điệp 9). Nếu tải "
           "ảnh lỗi, ứng dụng hỏi người dùng lưu không kèm ảnh hay để sau. Giao dịch sau đó đi theo đúng đường ghi giao dịch ở mục "
           "3.8.2, chỉ có thêm rawReceiptData và imageUrl.")),
    # ReceiptProcessingService.java dòng 128-137 (Javadoc, "What the client sent always wins (D3)") và dòng 154-165
    ("Thiết kế hiện tại có một hạn chế",
     ("p", "Khi hóa đơn kèm ngày và địa điểm do AI đọc, attachReceipt() chỉ điền hai trường này vào giao dịch nếu ứng dụng gửi lên "
           "để trống. Giá trị người dùng đã nhập hoặc đã sửa trên biểu mẫu đối soát luôn được giữ, còn hồ sơ hóa đơn vẫn lưu "
           "nguyên giá trị AI đọc được.")),
    # ---- 3.8.4 (#103-#105) ----
    ("Hình 3.52 gồm hai đoạn",
     ("p", "Hình 3.52 gồm hai đoạn. Đoạn đầu lưu ngân sách: BudgetScreen nhận dữ liệu từ BudgetFormSheet và gọi "
           "AppRepository.saveBudget(), sau đó existsDuplicate() kiểm tra trùng bộ (người dùng, categoryKey, periodType, "
           "startDate) trước khi lưu. Ràng buộc duy nhất cùng tên ở CSDL xử lý trường hợp hai yêu cầu đến cùng lúc.")),
    ("Ngân sách có thêm kỳ năm",
     ("p", "Ngân sách có thêm kỳ năm (BudgetPeriodType.YEAR, tối đa 366 ngày để chứa năm nhuận) và có thể đặt theo tên danh mục do "
           "người dùng gõ. Khi BudgetRequestDto không có categoryId mà có categoryName (tối đa 50 ký tự, đã bỏ khoảng trắng hai "
           "đầu), BudgetService gọi CategoryService.resolveOrCreate(). Hàm này dùng lại danh mục cùng tên, không phân biệt hoa "
           "thường; chưa có thì tạo danh mục chi mới và ghi nhật ký CATEGORY_CREATED. TransactionService dùng cùng hàm này khi giao "
           "dịch nêu danh mục theo tên, nên một khoản chi ghi “cà phê” được tính vào ngân sách đặt cho “Cà phê”.")),
    # ---- 3.8.5 (#107, #108) ----
    ("Hình 3.54 là dòng chính khi người dùng mở tab AI",
     ("p", "Hình 3.54 là dòng chính khi người dùng mở tab AI. Danh sách giao dịch đi qua AppRepository để có cả giao dịch chưa đồng "
           "bộ. Ứng dụng lọc ra các khoản chi trong cửa sổ phân tích 26 tuần (mục 3.9.4) và gửi tới POST /spade/analyze. Nếu có mục "
           "tiêu tiết kiệm, ứng dụng gửi thêm thu chi của 7 tháng dương lịch tới POST /spade/recommend. Hai lời gọi AI chỉ báo lỗi "
           "bằng hộp thoại khi người dùng chủ động bấm làm mới. Hai endpoint thống kê có cache ở mục 3.4.2, "
           "/api/transactions/app-dashboard và /api/transactions/popular-vendors, hiện chưa được ứng dụng di động gọi.")),
    # ---- 3.8.6 (#109, #110) ----
    ("Chức năng duyệt hóa đơn AI (UC19) cho phép",
     ("p", "Chức năng duyệt hóa đơn AI (UC19) cho phép quản trị viên chốt số tiền của một hóa đơn theo tổng tiền mà AI đọc được, "
           "hoặc từ chối hóa đơn. Hình 3.55 cho thấy hai lớp điều khiển. TransactionService.approveReceipt() xử lý thao tác duyệt, "
           "vì duyệt có thể làm thay đổi số tiền giao dịch và số dư ví. ReceiptProcessingService.rejectReceipt() xử lý thao tác từ "
           "chối và chỉ đổi trạng thái hóa đơn sang FAILED với mã REJECTED_BY_ADMIN.")),
    ("Theo Hình 3.56, approveReceipt() khóa ví",
     ("p", "Theo Hình 3.56, approveReceipt() khóa ví của chủ hóa đơn rồi đọc lại giao dịch, nên hai yêu cầu duyệt cùng lúc chỉ đổi "
           "ví một lần. approvableTotal() từ chối ba trường hợp: hóa đơn đã hủy, hóa đơn có trạng thái không được phép chuyển sang "
           "APPROVED, và hóa đơn không có tổng tiền dương. Chênh lệch giữa tổng tiền đã duyệt và số tiền cũ được cộng hoặc trừ vào "
           "ví. Nếu có chênh lệch, cảnh báo ngân sách được tính lại và nhật ký ghi thêm TRANSACTION_UPDATED bên cạnh "
           "RECEIPT_APPROVED.")),
    # ---- 3.8.7 (#111-#116) ----
    # mobile-app/lib/services/receipt_scan_queue.dart dòng 90-91 (maxBatch = 20, "queued or being read at a time")
    ("Chức năng quét nhiều hóa đơn (UC23) và xác nhận",
     ("p", "Chức năng quét nhiều hóa đơn (UC23) và xác nhận hóa đơn chờ (UC24) có các lớp như Hình 3.57. ReceiptScanQueue là lớp "
           "điều khiển duy nhất của hàng đợi, dùng một thể hiện cho cả ứng dụng (singleton): MainScaffold thêm ảnh, ScanQueueBanner "
           "nghe tiến độ qua một ValueListenable, PendingReceiptsScreen đọc danh sách và ra lệnh đọc lại, bỏ hoặc xác nhận.")),
    ("Theo Hình 3.58, enqueue()",
     ("p", "Theo Hình 3.58, enqueue() trả về ngay sau khi ghi các dòng queued (thông điệp 2–4), còn việc đọc chạy trong một vòng lặp "
           "riêng: mỗi lượt lấy mục cũ nhất của người dùng đang đăng nhập, gửi /donut/scan và chỉ sang mục kế tiếp khi mục trước đã "
           "có kết quả (thông điệp 6–14). Ứng dụng chỉ giữ một vòng đọc. Gọi enqueue() hay resume() trong lúc đang đọc chỉ báo cho "
           "vòng đó xem lại hàng đợi.")),
    ("Hình 3.59 là sơ đồ trạng thái của một mục",
     ("p", "Hình 3.59 là sơ đồ trạng thái của một mục trong hàng đợi [47]. Một số chuyển trạng thái quay về queued thay vì "
           "failed:")),
    ("Thiết kế này có hai giới hạn có chủ đích",
     ("p", "Thiết kế này có hai giới hạn có chủ đích. Hàng đợi chỉ chạy khi ứng dụng đang mở: không có dịch vụ nền của hệ điều hành "
           "và không thêm thư viện mới, nên tắt hẳn ứng dụng thì việc đọc tạm dừng tới lần mở sau. Hàng đợi nhận tối đa 20 mục đang "
           "chờ hoặc đang đọc cùng lúc (ReceiptScanQueue.maxBatch). AI Service chỉ đọc một ảnh mỗi lúc (mục 4.5.1), nên các mục được "
           "đọc lần lượt.")),
    # ---- 3.8.8 (#117, #118, #119) ----
    ("Mã clientId ở mục 3.8.2 chỉ chống gửi lặp",
     ("p", "Mã clientId ở mục 3.8.2 chỉ chống gửi lặp của cùng một lần lưu. Hai lần quét cùng một tờ hóa đơn sinh hai clientId khác "
           "nhau và trước đây đều được lưu. Chức năng chống lưu trùng (UC26) dùng các lớp của Hình 3.49, thêm "
           "DuplicateReceiptException và truy vấn findPossibleReceiptDuplicates() của TransactionRepository.")),
    # ---- 3.8.9 (#120) ----
    ("Chức năng góp tiền (UC25) có các lớp",
     ("p", "Chức năng góp tiền (UC25) có các lớp như Hình 3.61. SavingGoalService không tự trừ ví mà dựng một TransactionRequestDto "
           "rồi gọi TransactionService.createMyTransaction(). Yêu cầu này là một khoản chi trong danh mục “Tiết kiệm” "
           "(DefaultCategory.SAVINGS), có ghi chú là tên mục tiêu, phương thức WALLET và ngày hiện tại. Nhờ vậy, khoản góp đi qua "
           "đúng các bước khóa ví, kiểm tra số dư, cảnh báo ngân sách, nhật ký và xóa cache như mọi khoản chi khác.")),
    # ---- 3.9.1 (#122, #123) ----
    ("Mục 2.5.5 đã phân tích vì sao",
     ("p", "Mục 2.5.5 đã phân tích vì sao cách thêm ký tự bằng added token ở bản V3 làm sai khoảng trắng tiếng Việt. Mục này trình "
           "bày thiết kế cụ thể của bản V5 trong ai-service/Version5/model_config.py. Sau khi huấn luyện xong, AI Service chuyển "
           "sang phục vụ bản V5 (mục 4.5.1); bản V3 được giữ làm mốc so sánh ở Chương 5. Bảng 3.28 tóm tắt các tham số thiết kế của "
           "hai bản. Ở bản V3, mô hình gốc donut-base-finetuned-cord-v2 được nạp qua processor của donut-base và tokenizer của V3 "
           "khi phục vụ.")),
    # ---- 3.9.1 (#124-#126) ----
    ("Thứ tự các bước trong setup_model_and_processor()",
     ("p", "Thứ tự các bước trong setup_model_and_processor() là có chủ đích. Hàm find_unk_chars() duyệt mọi ký tự của nhãn train và "
           "giữ lại ký tự không có trong từ vựng hoặc bị mã hóa thành <unk>. Hàm extend_unigram_vocab() ghi các ký tự đó vào "
           "tokenizer.json dưới dạng piece (đơn vị từ vựng) mới của mô hình Unigram (cài đặt trong SentencePiece [12]) rồi nạp lại "
           "tokenizer. Sau đó, 10 thẻ của nhiệm vụ mới được thêm dưới dạng token đặc biệt, và ma trận embedding (vector biểu diễn "
           "token) của bộ giải mã được mở rộng theo kích thước tokenizer. Các dòng ứng với ký tự mới được gán vector trung bình của "
           "từ vựng gốc, để huấn luyện bắt đầu từ một điểm trung tính. Cuối cùng, chương trình mã hóa rồi giải mã lại toàn bộ nhãn "
           "train và dừng nếu dưới 99% nhãn được giữ nguyên.")),
    # ---- 3.9.2 (#128, #129) ----
    # ai-service/Version5/model_config.py dòng 15-16 (TASK_TOKEN = "<s_seller>", TASK_END_TOKEN = "</s_seller>")
    ("Khi huấn luyện, build_target() chuyển mỗi bản ghi",
     ("p", "Trong ví dụ trên, TOTAL_COST giữ nguyên cách in trên hóa đơn gốc nên “88,000” dùng dấu phẩy ngăn cách nghìn. Khi huấn "
           "luyện, build_target() chuyển mỗi bản ghi thành chuỗi đích theo thứ tự cố định của Bảng 3.29, kết thúc bằng </s_seller> "
           "và token </s>. Cặp <s_seller> và </s_seller> là thẻ nhiệm vụ bao quanh cả chuỗi, khác với các thẻ của từng trường ở "
           "Bảng 3.29 như <s_seller_name>. Đầu vào của bộ giải mã là <s_seller> nối với chuỗi đích lùi một vị trí.")),
    # ---- 3.9.3 (#132-#134, #137-#139) ----
    ("Chuỗi do DONUT sinh ra cần được làm sạch",
     ("p", "Chuỗi do DONUT sinh ra cần được làm sạch trước khi điền vào biểu mẫu đối soát và trước khi lưu vào CSDL. Hình 3.63 trình "
           "bày quy trình hậu xử lý, gồm hai chặng: ở AI Service ngay sau khi suy luận, và ở Core Backend khi giao dịch kèm hóa "
           "đơn được lưu. Khối màu xám là mô-đun do nhóm thiết kế thêm, các khối còn lại là phần xử lý đã có trước đó.")),
    # ai-service/Version5/postprocess.py dòng 1-6 ("V5 không cần hàm này"); ai-service/ai_service.py dòng 195-202 (total_cost_number
    # nay lấy từ normalize_receipt, extract_final_cost không còn)
    ("Ở bản V3, AI Service bỏ token kết thúc",
     ("p", "Phần xử lý đã có ở AI Service (bản V3) gồm các bước sau:")),
    ("Cách lấy số lớn nhất cho tổng tiền",
     ("p", "Cách lấy số lớn nhất trong chuỗi tổng tiền đơn giản nhưng sai khi hóa đơn in số tiền khách đưa hoặc mã số lớn hơn tổng "
           "tiền. Ngoài ra, tên cửa hàng, địa chỉ và ngày giờ chưa được chuẩn hóa ở AI Service.")),
    # ---- 3.9.4 (#140-#142, #147-#149, #151, #152) ----
    ("Phần phân tích chi tiêu của AI Service được thiết kế",
     ("p", "Phần phân tích chi tiêu của AI Service được thiết kế như một đường xử lý một chiều, không giữ trạng thái giữa hai yêu "
           "cầu: mỗi lần gọi POST /spade/analyze nhận đủ giao dịch và trả đủ kết quả. Hình 3.64 trình bày các bước của đường xử lý. "
           "Điểm rẽ duy nhất là điều kiện có chi tiêu từ 8 tuần trở lên. Nếu không đạt, mẫu và luật để rỗng, nhưng thói quen định "
           "kỳ và cơ cấu danh mục vẫn được tính. Các endpoint chạy đồng bộ (def, không phải async def) vì tính toán chỉ dùng CPU, "
           "FastAPI chạy chúng trong thread pool và không chặn vòng lặp sự kiện.")),
    ("Bảng 3.31 liệt kê các hằng số",
     ("p", "Bảng 3.31 liệt kê các hằng số điều khiển đường xử lý, giá trị và nguồn. Những dòng có nguồn “Đề tài” là giá trị do nhóm "
           "thực hiện chọn, chưa có tài liệu nào đưa ra giá trị đó. Các giá trị này có thể được chỉnh khi có dữ liệu thực của nhiều "
           "người dùng hơn.")),
    # ai-service/ai_service.py dòng 211-216 (max_length, top_n ge=1 le=50, min_sup_factor gt=0 le=1; trường thừa bị bỏ qua);
    # spending_analysis.py dòng 31-32 (FLOAT_DIGITS = 4, GAP_DIGITS = 1)
    ("Hợp đồng của POST /spade/analyze được tóm tắt",
     ("p", "Hợp đồng của POST /spade/analyze được tóm tắt ở Bảng 3.32. Trường thừa trong yêu cầu bị bỏ qua, nên ứng dụng bản cũ gửi "
           "thêm trường vẫn nhận mã 200. Mọi đầu vào sai, như quá 5.000 giao dịch, top_n ngoài khoảng, tên danh mục 256 ký tự hay "
           "số tiền âm, đều nhận mã 422. Mã 413 không thuộc /spade/analyze mà chỉ do /donut/scan trả khi ảnh quá lớn. Số thực trong "
           "kết quả được làm tròn đến 4 chữ số thập phân, riêng khoảng cách ngày làm tròn đến 1 chữ số thập phân.")),
    # mobile-app/lib/l10n/app_vi.arb dòng 527 (aiSpadeNotEnoughWeeks); các tiêu đề thẻ đã nêu ở mục 3.6.1 nên không lặp lại
    ("Ứng dụng di động gửi cho /spade/analyze các khoản chi",
     ("p", "Ứng dụng di động gửi cho /spade/analyze các khoản chi của 26 tuần gần nhất, tính từ 00:00 thứ Hai của tuần hôm nay lùi "
           "25 tuần. Khoản thu và khoản góp tiết kiệm không được gửi, và bộ chọn khoảng thời gian trên màn hình không ảnh hưởng "
           "đến cửa sổ này. Ứng dụng không gửi top_n và min_sup_factor nên server dùng giá trị mặc định (Bảng 3.32). Với "
           "/spade/recommend, ứng dụng gửi thu chi của 7 tháng dương lịch kể từ ngày 1 (trừ khoản góp tiết kiệm) cùng mục tiêu tiết "
           "kiệm khẩn cấp nhất. Các thẻ kết quả của tab AI được mô tả ở mục 3.6.1. Khi chưa đủ tuần, thẻ mẫu hiển thị “Mới có "
           "{weeks} tuần có chi tiêu; cần ít nhất {minWeeks} tuần để tìm mẫu tuần tự”.")),
    # ---- 3.10 (#153-#155) ----
    ("Chương 3 đã chuyển kết quả phân tích",
     ("p", "Chương 3 đã chuyển kết quả phân tích ở Chương 2 thành thiết kế có thể cài đặt. Kiến trúc gồm ứng dụng di động, Web "
           "Admin, Core Backend, AI Service và ba kho dữ liệu PostgreSQL, Redis, MongoDB, triển khai bằng Docker Compose sau "
           "reverse proxy Caddy. CSDL quan hệ có các ràng buộc toàn vẹn bám theo mã nguồn, còn API RESTful được bảo vệ bằng JWT có "
           "thu hồi.")),
    ("Phần thiết kế giao diện mô tả 22 màn hình",
     ("p", "Phần thiết kế giao diện mô tả 22 màn hình của ứng dụng di động và 9 trang Web Admin; ảnh chụp màn hình sẽ được nhóm bổ "
           "sung. Sơ đồ lớp mức thiết kế cùng tám sơ đồ ba lớp, chín sơ đồ tuần tự và một sơ đồ trạng thái cho thấy ba nhóm quyết "
           "định chính:")),
    # ReceiptProcessingService.java dòng 154-165: ngày và địa điểm người dùng nhập luôn thắng giá trị AI, nên bỏ hạn chế cũ
    ("Thiết kế vẫn còn hạn chế",
     ("p", "Thiết kế vẫn còn hai hạn chế: duyệt hoặc từ chối hóa đơn chưa tạo thông báo cho người dùng, và hàng đợi quét nhiều hóa "
           "đơn chỉ chạy khi ứng dụng đang mở. Chương 4 trình bày việc cài đặt các thiết kế này và quá trình huấn luyện mô hình "
           "DONUT.")),
    # ---- Heading4 (#156) ----
    ("Màn hình phân tích AI", ("h4", "Màn hình Phân tích AI")),
]

# Đoạn và gạch đầu dòng mới: neo theo đầu đoạn gốc (hoặc đầu chú thích hình) đứng ngay trước
INSERT_AFTER = [
    # #10: bốn quy tắc chuyển đổi (đoạn gốc P620 tách làm ba phần)
    ("Mô hình quan hệ biểu diễn dữ liệu dưới dạng", [
        ("b1", "Mỗi lớp thành một bảng có khóa chính thay thế id kiểu bigint tự tăng."),
        ("b1", "Quan hệ một – nhiều thành khóa ngoại ở phía nhiều."),
        ("b1", "Quan hệ hợp thành thêm ràng buộc xóa dây chuyền (cascade)."),
        ("b1", "Thuộc tính kiểu liệt kê thành cột chuỗi có miền giá trị giới hạn."),
        ("p", "Hai lớp «document» không chuyển thành bảng mà thành hai collection của MongoDB (mục 3.4.1). Bảng 3.3 ghi lại kết quả "
              "và các quyết định riêng cho từng lớp."),
    ]),
    # #12: tách kiểm toán và quản lý lược đồ
    ("Mô hình quan hệ thu được gồm 13 bảng", [
        ("p", "Lược đồ được Hibernate tạo và cập nhật tự động (ddl-auto = update). Những thay đổi Hibernate không tự làm được, như "
              "chuyển dữ liệu cũ của hóa đơn sang bảng lượt đọc, được viết thành tệp SQL trong "
              "core-backend/src/main/resources/db."),
    ]),
    # #20: ví dụ cho ký hiệu T/X/S
    ("Ràng buộc toàn vẹn (RBTV) là điều kiện", [
        ("p", "Trong cột tầm ảnh hưởng, T, X, S lần lượt là thao tác thêm, xóa, sửa; dấu (+) nghĩa là thao tác đó có thể vi phạm "
              "ràng buộc và phải kiểm tra. Ví dụ, “T(+), S(+ amount)” nghĩa là thêm bản ghi, hoặc sửa cột amount, đều có thể vi "
              "phạm. Cột nơi kiểm tra ghi rõ ràng buộc được bảo đảm ở CSDL (CHECK, UNIQUE, khóa ngoại) hay ở tầng ứng dụng (Bean "
              "Validation trên DTO, phương thức của thực thể hoặc service). Nhóm chỉ liệt kê những ràng buộc có trong mã nguồn hoặc "
              "lược đồ."),
    ]),
    # #28: LB2 tách khỏi danh sách hạn chế
    ("Một số ràng buộc hiện chỉ được bảo đảm", [
        ("p", "LB2 được kiểm tra trên mọi đường đổi số dư, và các đường này đều chạy khi dòng ví đang bị khóa (Bảng 3.19), nên hai "
              "yêu cầu đồng thời không thể cùng vượt qua kiểm tra."),
    ]),
    # #40, #41, #42: quy ước API thành danh sách
    ("REST là kiểu kiến trúc", [
        ("p", "API của Core Backend theo các quy ước sau."),
        ("b1", "Đường dẫn có tiền tố /api/<tài nguyên>; GET để đọc, POST để tạo, PUT hoặc PATCH để sửa, DELETE để xóa."),
        ("b1", "Dữ liệu của chính người gọi nằm ở đường dẫn /mine hoặc được lọc theo người dùng trong JWT, không dựa vào userId do "
               "ứng dụng gửi lên. Riêng PUT /api/users/{id} có {id} trên đường dẫn, nhưng UserService từ chối (mã 403) mọi id khác "
               "id của người đang đăng nhập."),
        ("b1", "Mọi phản hồi dùng chung cấu trúc ApiResponse gồm code (trùng mã trạng thái HTTP), message (tiếng Việt) và data."),
        ("b1", "Dữ liệu vào được kiểm tra bằng Bean Validation. Lỗi được GlobalExceptionHandler chuyển thành mã 400, 401, 403, 404, "
               "409 hoặc 503 tùy loại."),
    ]),
    # #44: ba mức quyền truy cập
    ("JSON Web Token (JWT) là chuỗi gồm", [
        ("b1", "Công khai: /api/auth/ (trừ change-password, logout và check), /api/payment/webhook và /api/categories."),
        ("b1", "Cần vai trò ROLE_ADMIN: /api/admin/."),
        ("b1", "Cần đăng nhập: mọi đường dẫn còn lại."),
        ("p", "Mật khẩu được băm bằng BCrypt. Đăng nhập sai 5 lần liên tiếp bị khóa 15 phút."),
    ]),
    # #47, #48, #49: ba cơ chế thu hồi
    ("Ba cơ chế thu hồi bổ sung cho nhau", [
        ("b1", "Đăng xuất: access token đang dùng và refresh token gửi kèm được đưa vào revoked_tokens. Bảng chỉ lưu giá trị băm và "
               "thời điểm hết hạn, và một tác vụ định kỳ lúc 03:30 hằng ngày xóa các dòng đã hết hạn."),
        ("b1", "Làm mới token: hệ thống khóa dòng người dùng, thu hồi refresh token cũ và cấp cặp token mới trong cùng một giao dịch "
               "(xoay vòng), nên mỗi refresh token chỉ dùng được một lần."),
        ("b1", "Đổi hoặc đặt lại mật khẩu: mật khẩu mới và credentials_version tăng thêm 1 được ghi bằng một câu UPDATE duy nhất. "
               "Mọi token đã phát trước đó, trên mọi thiết bị, lập tức bị từ chối ở bước 3 của Bảng 3.24 mà không phải liệt kê từng "
               "token."),
        ("p", "Thông tin người dùng hiện tại luôn được CurrentUserProvider lấy từ SecurityContext, không lấy từ tham số do ứng dụng "
              "gửi lên."),
    ]),
    # #50, #51, #52: tách đoạn nền tảng, ngôn ngữ, MainScaffold
    ("Ứng dụng di động được xây dựng bằng Flutter [33] theo hệ thống", [
        ("p", "Chuỗi giao diện của các màn hình lấy từ tệp ARB tiếng Việt và tiếng Anh (mục 4.7.3), nên khi đổi ngôn ngữ trong Cài "
              "đặt, toàn bộ giao diện được đổi theo. Chỉ dữ liệu do người dùng nhập và thông báo lỗi tiếng Việt từ Core Backend giữ "
              "nguyên ngôn ngữ gốc."),
        ("p", "Sau khi đăng nhập, người dùng vào MainScaffold. Khung này giữ bốn tab Trang chủ (DashboardPage), Thống kê (LedgerPage, "
              "tiêu đề màn hình là Sổ sách), AI (AITabPage) và Cá nhân (ProfilePage) trong một IndexedStack (ngăn xếp chỉ hiển thị "
              "một con) để không dựng lại tab khi chuyển qua lại, và đặt nút tròn Quét AI ở giữa thanh điều hướng. Bảng 3.25 liệt "
              "kê các màn hình cùng use case ở Chương 2 mà mỗi màn hình hiện thực."),
    ]),
    # #55, #56: màn hình Đăng nhập tách thành bố cục và thông báo lỗi; màn hình Đăng ký ở sau Hình 3.6
    ("Màn hình Đăng nhập (Hình 3.6) gồm logo", [
        ("p", "Khi thiếu dữ liệu, ứng dụng báo “Thiếu thông tin” mà không gửi yêu cầu. Khi máy chủ trả 401, hộp thoại hiển thị “Sai "
              "email hoặc mật khẩu!”."),
    ]),
    ("Hình 3.6:", [
        ("p", "Màn hình Đăng ký (Hình 3.7) có các ô Họ và tên, Email, Số điện thoại, Mật khẩu. Ngay dưới ô mật khẩu là danh sách năm "
              "điều kiện (độ dài tối thiểu, chữ hoa, chữ thường, chữ số, ký tự đặc biệt) được đánh dấu khi người dùng gõ. Danh sách "
              "này chặt hơn quy tắc @StrongPassword ở máy chủ, chỉ yêu cầu 8–72 ký tự gồm ít nhất một chữ cái và một chữ số."),
    ]),
    # #59: màn hình Đặt lại mật khẩu đặt sau Hình 3.8
    ("Hình 3.8:", [
        ("p", "Màn hình Đặt lại mật khẩu (Hình 3.9) hiển thị email đã che bớt, ô mã OTP 6 chữ số, hai ô mật khẩu mới và nút gửi lại "
              "mã có đếm ngược 60 giây. Trong lúc đang đặt lại, thao tác quay lại bị chặn. Khi thành công, ứng dụng quay về màn "
              "hình Đăng nhập và không tự tạo phiên."),
    ]),
    # #60: Trang chủ thành danh sách khối
    ("Trang chủ (Hình 3.10) xếp theo chiều dọc", [
        ("b1", "Lời chào và chuông thông báo có số chưa đọc."),
        ("b1", "Thẻ Số dư hiện tại, kèm mức thay đổi so với tháng trước. Mặc định thẻ che số dư mỗi lần mở trang. Bấm biểu tượng mắt "
               "để hiện số dư, và lựa chọn này không được lưu."),
        ("b1", "Khối Ngân sách với thanh tiến độ từng ngân sách. Bấm vào khối thì mở màn hình Ngân sách."),
        ("b1", "Lưới Tiện ích gồm bốn ô đều nhau: Thêm giao dịch, Quét hóa đơn, Ngân sách, Sổ tiết kiệm."),
        ("b1", "Danh sách Giao dịch gần đây. Bấm một dòng thì mở đúng bảng chi tiết giao dịch của Sổ sách."),
        ("p", "Ngày của giao dịch được ghi “Hôm nay”, “Hôm qua” khi phù hợp. Kéo xuống để làm mới. Khi đang tải, các khối được thay "
              "bằng khung xương (skeleton)."),
    ]),
    # #62: Sổ sách thành danh sách thành phần; bảng chi tiết ở sau Hình 3.11
    ("Màn hình Sổ sách (Hình 3.11) có ô tìm kiếm", [
        ("b1", "Ô tìm kiếm theo tên và danh mục, cùng nút Lịch mở hộp chọn ngày."),
        ("b1", "Dải ngày trong tuần và bộ chọn kỳ Tuần/Tháng/Năm, kèm nút Hôm nay (chỉ hiện khi kỳ đang xem không chứa ngày hôm "
               "nay)."),
        ("b1", "Biểu đồ cột Thu nhập/Chi tiêu."),
        ("b1", "Thẻ Tổng kết (tổng thu, tổng chi, số dư), kèm nút xuất tệp Excel."),
        ("b1", "Danh sách giao dịch của kỳ."),
        ("p", "Bảng Bộ lọc & Sắp xếp cho phép lọc theo loại giao dịch, khoảng tiền và sắp xếp theo mới nhất, cũ nhất hoặc giá trị "
              "cao nhất."),
    ]),
    ("Hình 3.11:", [
        ("p", "Chạm vào một giao dịch mở bảng chi tiết (Hình 3.12) gồm số tiền, thời gian, trạng thái hóa đơn, trạng thái đồng bộ, ảnh "
              "hóa đơn gốc và các nút Sửa, Xóa. Với giao dịch chưa được máy chủ xác nhận, bảng có thêm nút Gửi lại."),
    ]),
    # #64, #65, #67: bảng chọn nguồn ảnh thành danh sách; hai đoạn Xác nhận hóa đơn ở sau Hình 3.15
    ("Nút Quét AI mở bảng chọn nguồn ảnh", [
        ("b1", "“Quét bằng camera” dùng trình quét tài liệu ML Kit [59] để cắt khung một hóa đơn."),
        ("b1", "“Chọn từ thư viện” cho chọn một ảnh có sẵn."),
        ("b1", "“Quét nhiều” và “Chọn nhiều ảnh” đưa tối đa 20 ảnh vào hàng chờ của UC23."),
    ]),
    ("Hình 3.15:", [
        ("p", "Với một ảnh, màn hình Xác nhận hóa đơn (Hình 3.16) hiển thị trạng thái “Đang phân tích hóa đơn...” trong lúc chờ AI "
              "Service, sau đó là biểu mẫu đối soát gồm ảnh hóa đơn, nhóm Thông tin chung (tên cửa hàng, tổng tiền, ngày giao dịch, "
              "danh mục) và thẻ Tổng kết (tạm tính, thuế, tổng tiền)."),
        ("p", "Khi AI không đọc được tổng tiền, ô tổng tiền để trống kèm lời nhắc nhập tay. Khi không đọc được ngày, ô ngày lấy thời "
              "điểm hiện tại và hiện chú thích cảnh báo. Nếu ngày hóa đơn không thuộc tháng hiện tại, biểu mẫu nhắc “Giao dịch ngày "
              "dd/mm vẫn được tính vào số dư hiện tại”. Nút lưu có nhãn “Xác nhận và lưu”."),
    ]),
    # #70: ba trạng thái của banner; màn hình Chờ xác nhận ở sau Hình 3.19
    ("Khi hàng chờ có mục, banner ScanQueueBanner", [
        ("b1", "Trong lúc đọc, banner ghi “Đang đọc hóa đơn x/y” kèm thanh tiến độ."),
        ("b1", "Đọc xong, banner ghi “m hóa đơn chờ xác nhận”."),
        ("b1", "Hàng chờ trống thì banner không chiếm chỗ."),
    ]),
    ("Hình 3.19:", [
        ("p", "Bấm banner mở màn hình Chờ xác nhận (Hình 3.20), lớp PendingReceiptsScreen. Mỗi dòng có ảnh thu nhỏ, tên cửa hàng, số "
              "tiền, ngày và nhãn trạng thái. Mục Sẵn sàng mở biểu mẫu đối soát, mục Lỗi có nút Đọc lại, và cả hai loại đều có nút "
              "Bỏ. Nút cuối màn hình “Xác nhận tất cả hợp lệ (n)” bị tắt khi n bằng 0."),
    ]),
    # #71: bảng nhập ngân sách ở sau Hình 3.21
    ("Hình 3.21:", [
        ("p", "Nút Thiết lập ngân sách mở bảng nhập (Hình 3.22) có ô số tiền, lựa chọn kỳ Tuần/Tháng/Năm và ô Kỳ để chọn ngày áp "
              "dụng (thành phần DateField dùng chung). Bảng còn có danh sách chip (nhãn chọn) danh mục, trong đó có lựa chọn “Tất cả "
              "danh mục”. Chọn chip “Khác” thì hiện thêm ô Tên danh mục, bắt buộc và tối đa 50 ký tự. Ngân sách khi đó tính theo đúng "
              "tên người dùng nhập."),
    ]),
    # #73: các khối của tab AI
    ("Tab AI (Hình 3.23), lớp AITabPage", [
        ("b1", "Thẻ “Hôm nay tiêu được bao nhiêu?” (số tiền an toàn mỗi ngày còn lại của tháng)."),
        ("b1", "Các thẻ nhận định Xu hướng chi tiêu, Chi nhiều nhất, Mẹo tiết kiệm và So sánh tuần."),
        ("b1", "Biểu đồ cột thu chi theo tuần."),
        ("b1", "Thẻ Mẫu Chi Tiêu Tuần Tự, liệt kê các chuỗi do WCM-SPADE [48] tìm được kèm số tuần chứa chuỗi."),
        ("b1", "Thẻ Thói quen cần lưu ý (luật “sau khi chi A, bạn chi tiếp B trong cùng tuần”)."),
        ("b1", "Thẻ Thói quen định kỳ (khoảng cách ngày giữa các lần chi)."),
        ("b1", "Thẻ Gợi ý phân bổ tiền khi người dùng có mục tiêu tiết kiệm."),
        ("p", "Bộ chọn khoảng thời gian chỉ vẽ lại các biểu đồ, còn phân tích WCM-SPADE không phụ thuộc vào bộ chọn này (mục 3.9.4). "
              "Khi chưa có giao dịch, màn hình chỉ hiển thị thông báo “Chưa có dữ liệu”."),
    ]),
    # #74: đích mở của thông báo
    ("Màn hình Thông báo (Hình 3.24) là danh sách", [
        ("b1", "Thông báo ngân sách mở màn hình Ngân sách."),
        ("b1", "Thông báo giao dịch và thông báo hóa đơn mở bảng chi tiết của giao dịch liên quan, hoặc mở Sổ sách khi thông báo không "
               "kèm mã giao dịch."),
        ("b1", "Loại không xác định mở một bảng hiển thị toàn bộ nội dung."),
    ]),
    # #75: bốn nhóm mục của trang Cá nhân; màn hình Cài đặt ở sau Hình 3.25
    ("Trang Cá nhân (Hình 3.25) là danh sách nhóm dòng", [
        ("b1", "Tài khoản: Thông tin tài khoản."),
        ("b1", "Tiện ích: Nguồn tiền, Dịch vụ liên kết, Sổ tiết kiệm, Ngân sách."),
        ("b1", "Cài đặt: Ngôn ngữ, Giao diện, Thông báo, Bảo mật."),
        ("b1", "Hỗ trợ: Hướng dẫn sử dụng, Gửi phản hồi, Về ứng dụng."),
        ("p", "Cuối trang là nút Đăng xuất có hộp thoại xác nhận."),
    ]),
    ("Hình 3.25:", [
        ("p", "Màn hình Cài đặt (Hình 3.26) cho chọn giao diện theo thiết bị, sáng hoặc tối, và ngôn ngữ tiếng Việt hoặc tiếng Anh. "
              "Thay đổi được áp dụng ngay."),
    ]),
    # #77: màn hình Tài khoản tách khỏi Sổ tiết kiệm, đặt sau Hình 3.28
    ("Hình 3.28:", [
        ("p", "Màn hình Tài khoản (Hình 3.29) hiển thị tên đăng nhập và cho đổi mật khẩu qua hộp nhập mật khẩu cũ, mật khẩu mới và "
              "xác nhận."),
    ]),
    # #78: Lịch sử nạp/rút và thông tin cá nhân tách khỏi Dịch vụ liên kết
    ("Hình 3.30:", [
        ("p", "Màn hình Lịch sử nạp/rút (Hình 3.31) liệt kê các đơn kèm mã đơn và nút hủy đơn chưa hoàn tất."),
    ]),
    ("Hình 3.31:", [
        ("p", "Ba màn hình thông tin cá nhân (Hình 3.32) hiển thị email, họ tên, số điện thoại và cho sửa họ tên, số điện thoại (số "
              "gồm 10 chữ số, bắt đầu bằng 0)."),
    ]),
    # #81: tách đoạn JWT / phiên khỏi danh sách mục menu
    ("Web Admin là các trang Thymeleaf", [
        ("p", "Khác với ứng dụng di động dùng JWT, Web Admin dùng chuỗi bộ lọc riêng của Spring Security với đăng nhập bằng biểu mẫu "
              "và phiên làm việc, và mọi đường dẫn /admin/ yêu cầu vai trò ROLE_ADMIN. Các thao tác thêm, sửa, xóa trên trang gọi "
              "các endpoint /admin/ajax/ bằng hàm fetch (gửi yêu cầu HTTP từ JavaScript) rồi cập nhật bảng. Bảng 3.26 liệt kê các "
              "trang."),
    ]),
    # #82, #83, #84: các thành phần của Bảng điều khiển, tên nhãn lấy đúng từ dashboard.html
    ("Trang Đăng nhập (Hình 3.33) gồm hai ô", [
        ("p", "Bảng điều khiển (Hình 3.34) gồm các thành phần sau:"),
        ("b1", "Bốn thẻ số liệu “Tổng Dòng Tiền”, “Tổng User”, “Hóa đơn tháng này” và “User sắp cạn ví (< 50k)”, thẻ cuối đếm người "
               "dùng có số dư ví dưới 50.000 đồng."),
        ("b1", "Biểu đồ cột số hóa đơn sáu tháng và biểu đồ tròn tỉ lệ xử lý hóa đơn AI."),
        ("b1", "Bảng năm người chi tiêu nhiều nhất và danh sách người dùng sắp cạn ví."),
        ("b1", "Khối Phân khúc khách hàng RFM [49]: bảng 10 người dùng đã gán nhãn AI, nút “Chạy Phân Lớp AI Tự Động” và biểu đồ "
               "tỉ trọng bảy nhóm CHAMPIONS, LOYAL, NEW, NEED_ATTENTION, AT_RISK, HIBERNATING, LOST."),
    ]),
    # #86, #87: trang Quản lý hóa đơn AI tách khỏi Quản lý người dùng, đặt sau Hình 3.37
    # templates/admin/receipts.html dòng 50-52 ("Đang xử lý" là nhãn cho mọi trạng thái khác SUCCESS và FAILED)
    ("Hình 3.37:", [
        ("p", "Trang Quản lý hóa đơn AI (Hình 3.38) là bảng phân trang gồm ID, tên cửa hàng, số tiền AI đọc được, nút xem ảnh gốc, "
              "trạng thái và cột Hành động. Cột trạng thái có ba nhãn là Thành công, Lỗi AI và Đang xử lý, trong đó Đang xử lý là "
              "nhãn gộp cho mọi trạng thái còn lại của hóa đơn."),
        ("p", "Nút Duyệt chỉ hiện ở hóa đơn được phép chuyển sang APPROVED, và nút Từ chối chỉ hiện ở hóa đơn được phép chuyển sang "
              "FAILED. Hai nút gửi POST tới /admin/receipts/approve/{id} và /admin/receipts/reject/{id} (mục 3.8.6)."),
    ]),
    # #88, #89: Nhật ký hệ thống và Sao lưu tách khỏi trang Đánh giá
    ("Hình 3.39:", [
        ("p", "Trang Nhật ký hệ thống (Hình 3.40) chia thành các thẻ Dữ liệu (CRUD), Bảo mật, Thống kê và Tra cứu nâng cao. Thẻ tra "
              "cứu lọc theo người thực hiện, loại và mã đối tượng, khoảng thời gian. Thẻ Bảo mật có nút Gỡ khóa cho tài khoản đang bị "
              "khóa đăng nhập."),
    ]),
    ("Hình 3.40:", [
        ("p", "Trang Sao lưu (Hình 3.41) có ba nút sao lưu ứng với ba giá trị của BackupType: FULL (toàn bộ cấu trúc và dữ liệu), "
              "SCHEMA_ONLY (chỉ cấu trúc) và DATA_ONLY (chỉ dữ liệu). Mỗi loại chạy pg_dump ở định dạng “custom” với tham số riêng, "
              "và loại không thuộc danh sách bị từ chối. Nút phục hồi chỉ dùng bản FULL mới nhất và hiện hộp thoại cảnh báo xác "
              "nhận, vì hai loại còn lại không đủ để dựng lại CSDL."),
    ]),
    # #92: bốn việc của TransactionService
    ("Hình 3.43 trình bày ba tầng của Core Backend", [
        ("b1", "Khóa dòng ví bằng PESSIMISTIC_WRITE (lockWallet) trước khi đổi số dư ở mọi thao tác tạo, sửa, xóa giao dịch và duyệt "
               "hóa đơn."),
        ("b1", "Đổi số dư qua moveWallet(), phương thức ném InsufficientBalanceException khi số dư sẽ âm."),
        ("b1", "Gọi ReceiptProcessingService khi giao dịch có hóa đơn."),
        ("b1", "Gọi BudgetAlertService sau khi lưu để sinh cảnh báo ngân sách."),
        ("p", "Riêng đăng nhập vẫn được xử lý ngay trong AuthController (mục 3.8.1)."),
    ]),
    # #100: gửi lại hàng đợi tách khỏi lỗi mạng
    ("Khi mất mạng, hết thời gian chờ", [
        ("p", "resendUnsyncedTransactions() gửi lại toàn bộ hàng đợi theo thứ tự từ cũ đến mới, khi ứng dụng mở, khi ứng dụng quay lại "
              "tiền cảnh và khi người dùng kéo làm mới Sổ sách. Mỗi lần chỉ chạy một luồng gửi. Khi máy chủ từ chối (lỗi 4xx), giao "
              "dịch mới tạo bị xóa khỏi bảng cục bộ để người dùng sửa biểu mẫu, còn giao dịch gửi lại thì được giữ với cờ error để "
              "người dùng chủ động xóa."),
    ]),
    # #101: tạo hóa đơn và trạng thái ban đầu; mã lỗi tham chiếu Bảng 3.7
    ("Theo Hình 3.50, sau khi người dùng xác nhận", [
        ("p", "Trong cùng giao dịch CSDL, ReceiptProcessingService tạo Receipt và lượt đọc đầu tiên (ReceiptProcessingAttempt số 1) "
              "chứa nguyên văn câu trả lời của AI. Nếu OcrService đọc được tổng tiền, hóa đơn ở trạng thái COMPLETED_RAW; nếu không, "
              "hóa đơn chuyển FAILED với mã lỗi AI_NO_TOTAL hoặc AI_UNREADABLE (Bảng 3.7). Sau khi giao dịch CSDL hoàn tất, câu trả "
              "lời thô được ghi thêm vào MongoDB (mục 3.4.1)."),
    ]),
    # #104: cảnh báo ngân sách tách khỏi lưu ngân sách
    ("Hình 3.52 gồm hai đoạn", [
        ("p", "Đoạn sau là cảnh báo: findCoveringDate() lấy các ngân sách bao ngày của khoản chi, gồm ngân sách của đúng danh mục và "
              "ngân sách tất cả danh mục. Với mỗi ngân sách, tổng chi trước và sau khoản chi được so với hạn mức. Một thông báo "
              "BUDGET_WARNING (80%) hoặc BUDGET_EXCEEDED (100%) chỉ được tạo khi khoản chi này đưa ngân sách lên một mốc cao hơn mốc "
              "trước đó, nên người dùng không bị nhắc lại cùng một mốc."),
    ]),
    # #111: cấu trúc bảng receipt_scan_queue và ReceiptScanResult tách khỏi vai trò các lớp
    ("Chức năng quét nhiều hóa đơn (UC23) và xác nhận", [
        ("p", "Mỗi mục là một dòng của bảng receipt_scan_queue trong SQLite, gồm mã, user_id, đường dẫn ảnh đã chép, trạng thái, kết "
              "quả JSON, mã lỗi và thời điểm tạo. Việc chuyển câu trả lời của AI Service thành bản nháp giao dịch được tách thành lớp "
              "ReceiptScanResult, dùng chung cho biểu mẫu đối soát và cho thao tác xác nhận hàng loạt, nên hai đường lưu áp cùng một "
              "quy tắc."),
    ]),
    # #112: confirmAllValid tách khỏi vòng đọc
    ("Theo Hình 3.58, enqueue()", [
        ("p", "confirmAllValid() xử lý tuần tự từng mục Sẵn sàng có allValid. Với mỗi mục, hàm tải ảnh lên trước, rồi lưu qua "
              "AppRepository.createTransaction() với allowDuplicate = false, tức đúng đường lưu có clientId và kiểm tra trùng của "
              "UC09. Nếu hàm được gọi lần nữa khi lần trước chưa xong thì không làm gì."),
    ]),
    # #113, #114, #115: các chuyển trạng thái về queued và các mã lỗi cố định
    ("Hình 3.59 là sơ đồ trạng thái của một mục", [
        ("b1", "Khi lượt đọc nhận 403, hoặc nhận 401 mà không làm mới được token, phiên đăng nhập đã kết thúc và việc đọc tiếp không "
               "thể thành công, nên mục được trả về hàng chờ và vòng đọc dừng."),
        ("b1", "Khi người dùng đăng xuất, vòng đọc dừng trước mục kế tiếp. Các mục còn lại chỉ được đọc tiếp khi chính người dùng đó "
               "đăng nhập lại."),
        ("b1", "Khi ứng dụng bị tắt lúc một mục đang reading, lần mở sau MainScaffold gọi resume(). Đầu mỗi lượt chạy, mọi mục "
               "reading của người dùng được đưa về queued vì không còn ai đọc chúng."),
        ("p", "Lỗi mạng, lỗi máy chủ và ảnh không còn trên máy được ghi thành failed với ba mã cố định network, server và "
              "missing_image, để màn hình hiển thị lý do bằng ngôn ngữ người dùng chọn."),
    ]),
    # #117, #118: tách tiêu chí lọc, kiểm tra dưới khóa ví và so tên người bán
    ("Mã clientId ở mục 3.8.2 chỉ chống gửi lặp", [
        ("p", "Hình 3.60 cho thấy kiểm tra chạy sau attachReceipt(), vì cần tên người bán của hồ sơ hóa đơn vừa tạo. Kiểm tra cũng chạy "
              "khi dòng ví đang bị khóa, nên hai lần lưu cùng một hóa đơn gửi đồng thời không thể cùng vượt qua."),
        ("p", "Truy vấn lọc theo người dùng, chiều thu chi, số tiền và khoảng [phút, phút + 1) của ngày giao dịch, và lấy kèm hồ sơ hóa "
              "đơn bằng LEFT JOIN FETCH trong một câu lệnh. Giao dịch nhập tay cùng số tiền và cùng phút (không có người bán) cũng "
              "được coi là bản đã lưu. Tên người bán được so trong bộ nhớ sau khi normalizedSeller() chuyển về chữ thường, bỏ dấu và "
              "dấu câu."),
    ]),
    # #134: các bước xử lý của AI Service thành danh sách
    ("Ở bản V3, AI Service bỏ token kết thúc", [
        ("b1", "Bỏ token kết thúc và token đệm của chuỗi sinh ra."),
        ("b1", "Đưa chuỗi qua clean_vietnamese_text() để ghép lại các âm tiết bị tách bởi tokenizer V3. Bước này chỉ cần cho V3, vì "
               "tokenizer mở rộng của V5 không làm sai khoảng trắng (mục 2.5.5)."),
        ("b1", "Dùng processor.token2json() chuyển chuỗi thành JSON [40]."),
        ("b1", "Nếu chuyển được sang JSON, extract_final_cost() bỏ dấu chấm, dấu phẩy rồi lấy số lớn nhất trong chuỗi total_cost làm "
               "total_cost_number. Nếu không, dịch vụ trả về {\"raw_text\": …} để ứng dụng cho người dùng nhập tay."),
        ("p", "Ở Core Backend, OcrService.extract() là nơi duy nhất đọc câu trả lời của AI. Bảng 3.30 liệt kê các quy tắc của nó."),
    ]),
    # #138, #139: ba nhóm quy tắc của mô-đun mới
    ("Cách lấy số lớn nhất cho tổng tiền", [
        ("p", "Vì vậy, nhóm thiết kế mô-đun ai-service/receipt_postprocess.py đặt ngay sau token2json() (khối màu xám ở Hình 3.63), "
              "với các quy tắc theo ba nhóm trường:"),
        ("b1", "Tổng tiền: ưu tiên số đứng gần các từ khóa “Tổng”, “Thành tiền”, “Total” và hiểu dấu chấm, dấu phẩy theo cách viết "
               "tiền Việt Nam (ví dụ “1.011.780” là số nguyên 1011780, không phải số thập phân)."),
        ("b1", "Ngày giờ: nhận các dạng dd/MM/yyyy, dd-MM-yy, HH:mm và chuẩn hóa về dạng yyyy-MM-ddTHH:mm:ss."),
        ("b1", "Tên cửa hàng và địa chỉ: bỏ ký tự rác, chuẩn hóa khoảng trắng và chữ hoa, chữ thường."),
        ("p", "Kết quả là một mô hình Pydantic [60], mỗi trường kèm cờ valid để ứng dụng biết trường nào cần người dùng kiểm tra, và "
              "các khóa JSON cũ ở Bảng 3.29 được giữ nguyên để ứng dụng hiện tại không bị ảnh hưởng."),
    ]),
    # #154: ba nhóm quyết định chính ở kết chương
    ("Phần thiết kế giao diện mô tả 22 màn hình", [
        ("b1", "Ghi giao dịch không trùng và không mất khi mất mạng: hàng đợi gửi với clientId, khóa dòng ví khi đổi số dư, và chặn "
               "lưu hóa đơn trùng bằng mã 409 có lối “Vẫn lưu”."),
        ("b1", "Giữ dữ liệu hóa đơn AI: lưu từng lượt đọc của AI và đọc tuần tự từng ảnh bằng hàng đợi quét trên thiết bị."),
        ("b1", "Giữ nghiệp vụ nhất quán: cảnh báo ngân sách chỉ khi vượt một mốc mới, và góp tiền tiết kiệm trong một giao dịch CSDL."),
        ("p", "Thiết kế mô hình AI xác định tokenizer mở rộng từ vựng Unigram, định dạng nhãn bốn trường có che các trường chưa kiểm "
              "tra và quy trình hậu xử lý hai chặng."),
    ]),
]

# Dòng mới trong ô bảng (cùng kiểu với đoạn đứng trước). Ô LB10 và ô Tổng tiền của Bảng 3.30 tách thành nhiều dòng
PARA_LINES_AFTER = [
    ("Một hóa đơn quét không được lưu thành giao dịch mới",
     ["– cùng chiều thu chi;", "– cùng số tiền;", "– cùng phút;", "– cùng người bán đã chuẩn hóa (người bán trống coi như khớp).",
      "Không áp dụng khi yêu cầu có allowDuplicate = true."]),
    ("Ưu tiên total_cost_number; nếu không có thì lấy số lớn nhất",
     ["Khi có cả dấu chấm và dấu phẩy, dấu đứng sau là dấu thập phân.",
      "Khi chỉ có một loại dấu, đó là dấu phân cách nghìn nếu lặp lại hoặc theo sau là đúng 3 chữ số.",
      "Giá trị phải dương và không quá 10¹² đồng."]),
]

# Hai dòng tham số yêu cầu của /spade/analyze (ai-service/ai_service.py dòng 211-213), đặt sau dòng transactions[]
TABLE_ROWS = [
    ("Bảng 3.32", "transactions[]",
     [["top_n", "Số nguyên từ 1 đến 50, mặc định 10", "Yêu cầu, không bắt buộc; số phần tử tối đa của mỗi danh sách kết quả"],
      ["min_sup_factor", "Số thực trong (0, 1], mặc định 0,25", "Yêu cầu, không bắt buộc; ngưỡng support có trọng số tối thiểu"]]),
]

# (chuỗi cũ, chuỗi mới, số lần): thay trong từng <w:t>
TEXT_REPLACE = [
    # #4
    ("tính tốn chi phí", "tốn nhiều chi phí tính toán", 1),
    # #13
    ("Sơ đồ thực thể kết hợp (ERD) do Chen đề xuất biểu diễn", "Sơ đồ thực thể kết hợp (ERD), do Chen đề xuất, biểu diễn", 1),
    # #14: «chỉ đọc» là nhãn trong bảng, không phải stereotype UML
    ("Cột «chỉ đọc» là cột ứng dụng chỉ đọc, không bao giờ ghi", "Cột ghi “chỉ đọc” là cột mà ứng dụng chỉ đọc, không bao giờ ghi", 1),
    # #15
    ("cần chạy tệp migration ở mục 4.6.3", "cần chạy tệp SQL chuyển đổi lược đồ ở mục 4.6.3", 1),
    # #17
    ("mà không ảnh hưởng số dư ví; riêng thao tác Góp tiền vừa cộng current_amount vừa tạo một khoản chi “Tiết kiệm” trừ vào ví, "
     "trong cùng một giao dịch CSDL", "mà không ảnh hưởng số dư ví. Riêng thao tác Góp tiền cộng current_amount và tạo khoản chi "
     "“Tiết kiệm” trừ vào ví trong cùng một giao dịch CSDL", 1),
    # #18
    ("có hai chỉ mục (user_id, created_at, id) và (user_id, is_read, created_at, id) phục vụ",
     "có hai chỉ mục ghép: một trên (user_id, created_at, id), một trên (user_id, is_read, created_at, id), phục vụ", 1),
    # #21, #22
    ("Ràng buộc liên thuộc tính liên hệ giữa", "Ràng buộc liên thuộc tính biểu diễn mối liên hệ giữa", 1),
    ("Ràng buộc liên bộ và liên quan hệ liên hệ giữa", "Ràng buộc liên bộ và liên quan hệ biểu diễn mối liên hệ giữa", 1),
    # #23, #24
    ("amount ≥ 1.000", "amount ≥ 1.000 đồng", 1),
    ("tối đa 17 chữ số phần nguyên và 2 chữ số thập phân", "tối đa 17 chữ số phần nguyên và 2 chữ số thập phân (tổng 19 chữ số)", 1),
    # #26: ô LB10 (các dòng sau nằm ở PARA_LINES_AFTER)
    ("khi người dùng đã có giao dịch cùng chiều thu chi, cùng số tiền, cùng phút và cùng người bán đã chuẩn hóa (người bán trống "
     "coi như khớp), trừ khi yêu cầu có allowDuplicate = true", "khi người dùng đã có một giao dịch khớp cả bốn điều kiện sau:", 1),
    # #46
    ("nên mỗi bên từ chối loại còn lại và từ chối token không có typ",
     "nên điểm xử lý access token từ chối refresh token và ngược lại, đồng thời từ chối token không có typ", 1),
    # #63
    ("(tiếng Việt 1.000.000, tiếng Anh 1,000,000)", "(ví dụ một triệu đồng hiển thị là 1.000.000 ở tiếng Việt và 1,000,000 ở tiếng Anh)", 1),
    # #68
    ("mở màn xem ảnh toàn màn hình", "mở chế độ xem ảnh toàn màn hình", 1),
    # #85
    ("là bảng ID, tên, loại (Khoản Thu/Khoản Chi), ngày tạo với nút Sửa, Xóa và hộp thoại tạo danh mục",
     "là bảng gồm các cột ID, tên, loại (Khoản Thu/Khoản Chi) và ngày tạo, kèm nút Sửa, Xóa và hộp thoại tạo danh mục", 1),
    # #90
    ("Sơ đồ lớp mức thiết kế bổ sung cho sơ đồ lớp phân tích ở mục 2.4 kiểu dữ liệu cụ thể",
     "So với sơ đồ lớp phân tích ở mục 2.4, sơ đồ lớp mức thiết kế bổ sung kiểu dữ liệu cụ thể", 1),
    # #91
    ("của Receipt, hai phương thức này kiểm tra bảng chuyển trạng thái của kiểu liệt kê ReceiptStatus; trạng thái PROCESSING được "
     "khai báo", "của Receipt. Hai phương thức này kiểm tra bảng chuyển trạng thái của kiểu liệt kê ReceiptStatus. Trạng thái "
     "PROCESSING được khai báo", 1),
    # #95: các lớp của hàng đợi quét nằm trong dòng Receipt của Bảng 3.27
    ("ReviewFormPage, RemoteApiHelper.scanReceipt",
     "ReviewFormPage, RemoteApiHelper.scanReceipt, ReceiptScanQueue, ReceiptScanResult, ScanQueueBanner, PendingReceiptsScreen", 1),
    # chuông thông báo: dùng tên lớp như Bảng 3.27
    ("Phía ứng dụng, chuông trên Trang chủ đọc số thông báo chưa đọc", "Phía ứng dụng, chuông thông báo (NotificationBell) trên "
     "Trang chủ đọc số thông báo chưa đọc", 1),
    # #119
    ("Ngoại lệ làm giao dịch CSDL quay lui toàn bộ", "DuplicateReceiptException làm giao dịch CSDL quay lui toàn bộ", 1),
    # #121
    ("toàn bộ contributeToMySaving() là một @Transactional", "contributeToMySaving() chạy trong một giao dịch (@Transactional)", 1),
    # #123: chú thích dài của ô Bảng 3.28 chuyển vào đoạn dẫn bảng
    ("donut-base-finetuned-cord-v2 (khi phục vụ: processor của donut-base, tokenizer của V3)",
     "donut-base-finetuned-cord-v2 (khi phục vụ, xem đoạn dẫn bảng)", 1),
    # #130, #131
    ("nên các token của đoạn này được gán nhãn -100", "nên các token của trường đó được gán nhãn -100", 1),
    ("được coi là hóa đơn dài và được lặp 2 lần trong tập train", "được coi là hóa đơn dài và được nhân đôi (xuất hiện 2 lần) trong tập train", 1),
    # #135, #136: ô Tổng tiền của Bảng 3.30 (các dòng sau nằm ở PARA_LINES_AFTER); OcrService.java dòng 181-191, 46
    ("Ưu tiên total_cost_number; nếu không có thì lấy số lớn nhất trong total_cost. Khi có cả dấu chấm và dấu phẩy, dấu đứng sau là "
     "dấu thập phân; khi chỉ có một loại, nó là dấu phân cách nghìn nếu lặp lại hoặc theo sau là đúng 3 chữ số; giá trị phải dương "
     "và không quá 10^12",
     "Ưu tiên total_cost_number; nếu không có thì lấy số lớn nhất trong chuỗi total_cost.", 1),
    ("Yêu cầu; amount từ 0 đến 10¹²", "Yêu cầu; tối đa 5.000 giao dịch; amount từ 0 đến 10¹² đồng", 1),
    # #156: chú thích Hình 3.23 theo tiêu đề mục đã sửa
    ("Màn hình phân tích AI (nguồn", "Màn hình Phân tích AI (nguồn", 1),
    # #150
    ("Cắt ở top_n", "Giới hạn top_n phần tử", 3),
    ("; thêm ba trường cũ pattern, count, wsupport cho ứng dụng bản trước", ", đồng thời trả thêm ba trường cũ pattern, count, "
     "wsupport cho ứng dụng bản trước", 1),
]
