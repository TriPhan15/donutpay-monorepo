# Nội dung phiên K6 (01/11/2026): cập nhật các câu đã lệch so với mã nguồn trên origin/main (62b8861). Sinh
# KhoaLuan_KLCN175_v16.docx từ v15 bằng builder.py.
# Chỉ dùng TEXT_REPLACE (số lần ghi đúng với tệp v15), TABLE_ROWS (thêm dòng cột mới vào bảng CSDL, bảng ràng buộc) và
# PARA_LINES_AFTER (một nhóm đoạn mới ở cuối mục 4.6.5). Không thêm hoặc bớt mục, hình, chú thích bảng; không đổi số hình,
# số bảng; ghi chú [T7.x] và [Nhóm] không đổi. Thuật ngữ theo K5: mô-đun, bộ nhớ đệm, điểm cuối, ca sử dụng, tỉ lệ, tab Thống kê.
# Chỉ mô tả những gì có trên origin/main. Không viết về M1, M2, M4, B9 (PR chưa merge): hai câu ở mục 3.8.6 và Kết chương
# “duyệt và từ chối chưa tạo thông báo” vẫn đúng nên giữ nguyên.
#
# Dẫn chứng (đường dẫn tính từ core-backend/src/main/java/vn/edu/huit/finance/core/ nếu không ghi khác; số dòng của origin/main 62b8861):
#   receipts.owner_id: Entity/Receipt.java 92 (cột owner_id, chú thích 86-91), 124-129 (ownerId()); Service/ReceiptProcessingService.java
#     167-168 (gán chủ khi tạo hóa đơn), 575-581 (requireOwner); Service/TransactionService.java 418 (hủy hóa đơn);
#     docs/deploy/MIGRATION_RUNBOOK.md 95-104 (receipt-owner-migration.sql).
#   transactions.source: Entity/Transaction.java 26 (SOURCE_MAX_LENGTH = 16), 95-98; Entity/TransactionSource.java; Service/SavingGoalService.java
#     160-181 (deleteSaving hoàn tiền vào ví với nguồn GOAL_REFUND, dòng 165, 174); Dto/TransactionResponseDto.java 43, 63;
#     ai-service/spending_data.py 84-95 (bỏ GOAL_REFUND khỏi thu nhập), ai-service/budget_advisor.py 125; docs/deploy/MIGRATION_RUNBOOK.md 74-93.
#   10 lượt đọc rồi 409: Service/ReceiptProcessingService.java 111-114 (MAX_ATTEMPTS_PER_RECEIPT = 10), 336-340.
#   Lỗi không lường trước trả 500 kèm câu cố định: Exception/GlobalExceptionHandler.java 36 (MSG_SYSTEM_ERROR), 329-335 (lỗi CSDL), 337-342 (mọi
#     ngoại lệ còn lại); 413: 194-198; 429: 105-109.
#   Mail OTP bất đồng bộ: Service/AsyncMailSender.java 12-31, Config/AsyncConfig.java 21-35 (mailAsyncExecutor, 2 luồng, hàng đợi 100),
#     Service/AuthService.java 119, 204-231 (mailSender.send ở dòng 230); email chưa đăng ký nhận cùng phản hồi: AuthService.java 216-220,
#     Controller/AuthController.java 47, 219-228; app vẫn chuyển sang màn hình đặt lại: mobile-app/lib/screens/auth/forgot_password_page.dart 76-77.
#   Liên kết ảnh chỉ https: Util/ImageUrls.java 8-27, Dto/TransactionRequestDto.java 59-62, Service/ReceiptProcessingService.java 141-150,
#     Exception/GlobalExceptionHandler.java 262-265 (InvalidImageUrlException trả 400).
#   Tải ảnh tối đa 15 MB, JPEG/PNG/WEBP, 413: Service/Storage/ImageUploadService.java 29, 33, 52-66, Controller/FileUploadController.java 24,
#     Exception/GlobalExceptionHandler.java 189-204 (400, 413, 503); ai-service/ai_service.py 27 (cùng 15 MB).
#   Mật khẩu mạnh khi quản trị viên tạo người dùng: Dto/UserCreateDto.java 20-22, Security/StrongPassword.java 35-37, Controller/AdminController.java 239.
#   Bảng điều khiển: Controller/AdminController.java 155 (10 người dùng mới nhất theo id giảm dần), templates/admin/dashboard.html 205-218.
#   Điểm cuối chưa có trong Bảng 3.23: Controller/TransactionController.java 92-96; AdminLeaderboardController.java 30, 51, 60;
#     AdminOcrFeedbackController.java 36, 62, 77, 82, 88; AdminSearchController.java 26, 43.
#   ci.yml: .github/workflows/ci.yml 32, 51, 70. Compose: docker-compose.yml 151-154, 163-166, 209-212 (profile search, tools), 284 (SEARCH_ENGINE).
#   SQLite 9: mobile-app/lib/services/sqflite_helper.dart 20, 255-266; mobile-app/lib/models/transaction_model.dart 60-62.
#   Toast xếp chồng: mobile-app/lib/widgets/feedback/app_toast.dart 15-18; mobile-app/lib/widgets/feedback/toast_stack.dart 42 (maxLayers = 3).
#   Số tệp đếm ngày 01/11/2026 trên origin/main (62b8861) bằng git ls-tree -r origin/main --name-only: 284 tệp .java trong
#   core-backend/src/main/java, 172 tệp .dart trong mobile-app/lib, 702 khóa trong app_vi.arb (và app_en.arb), không tính khóa bắt đầu bằng @.
SESSION_TAG = None
SECTIONS = {}

# Dòng mới cho các bảng CSDL: (đầu chú thích bảng, chữ của dòng đứng trước hoặc None = cuối bảng, [dòng, ...])
TABLE_ROWS = [
    ('Bảng 3.6: Mô tả bảng transactions', 'Khóa chống ghi trùng do ứng dụng di động sinh (UUID)', [
        ['source', 'varchar(16)', 'NOT NULL, mặc định NORMAL',
         'Nguồn giao dịch: NORMAL, hoặc GOAL_REFUND là khoản tiền một mục tiêu tiết kiệm đã xóa trả về ví, không tính là thu nhập'],
    ]),
    ('Bảng 3.7: Mô tả bảng receipts', 'Số phiên bản cho khóa lạc quan (@Version)', [
        ['owner_id', 'bigint', 'FK → users, cho phép NULL',
         'Chủ sở hữu hóa đơn, gán một lần khi tạo hóa đơn từ người đang đăng nhập; mọi kiểm tra quyền dùng cột này. '
         'NULL ở dòng cũ chưa điền được chủ: chỉ quản trị viên xử lý'],
    ]),
    ('Bảng 3.17: Ràng buộc miền giá trị', None, [
        ['MG14', 'transactions', 'source ∈ {NORMAL, GOAL_REFUND}', 'T(+)', 'CHECK do Hibernate sinh từ enum'],
        ['MG15', 'receipts', 'image_url để trống hoặc là địa chỉ bắt đầu bằng https://, dài tối đa 2048 ký tự', 'T(+)',
         '@Pattern, @Size (TransactionRequestDto), ImageUrls.isSafe, varchar(2048)'],
    ]),
]

# Đoạn mới sau đoạn cuối của mục 4.6.5 (xử lý và đối soát hóa đơn)
PARA_LINES_AFTER = [
    ('Sau khi giao dịch được commit, sự kiện OcrProcessedEvent', [
        'Chủ sở hữu hóa đơn được ghi vào cột receipts.owner_id lúc hóa đơn được tạo, lấy từ người đang đăng nhập chứ không từ '
        'nội dung yêu cầu (ReceiptProcessingService.attachReceipt()). Mọi thao tác của người dùng trên hóa đơn (xem, sửa, đọc '
        'lại, gửi số tiền, hủy) so mã người dùng trong JWT với Receipt.ownerId() và nhận mã 403 nếu khác. Hóa đơn tạo trước '
        'khi có cột này lấy chủ từ giao dịch gắn kèm, còn hóa đơn không tìm được chủ thì chỉ quản trị viên xử lý được.',
        'Mỗi hóa đơn có tối đa 10 lượt đọc (ReceiptProcessingService.MAX_ATTEMPTS_PER_RECEIPT), gồm lượt đầu khi lưu giao dịch '
        'và các lần đọc lại. Yêu cầu đọc lại khi đã đủ 10 lượt bị từ chối bằng ReceiptConflictException (HTTP 409) kèm câu gợi ý '
        'gửi số tiền để quản trị viên duyệt, nhờ đó bảng receipt_processing_attempts không tăng vô hạn.',
        'Đường dẫn ảnh hóa đơn chỉ nhận địa chỉ https://. TransactionRequestDto kiểm bằng @Pattern, attachReceipt() kiểm lại '
        'bằng ImageUrls.isSafe() và ném InvalidImageUrlException (HTTP 400) nếu không đạt, vì quản trị viên bấm mở liên kết này '
        'trên trang Hóa đơn của Web Admin, và một liên kết dạng javascript: hay data: sẽ chạy mã trong phiên của quản trị viên.',
        'Điểm cuối POST /api/upload (ImageUploadService) chỉ nhận ảnh JPEG, PNG hoặc WEBP, nhận dạng theo các byte đầu của tệp '
        'chứ không theo Content-Type, và giới hạn 15 MB, bằng giới hạn của AI Service. Tệp rỗng hoặc sai định dạng nhận mã 400, '
        'tệp quá cỡ nhận mã 413, kho ảnh lỗi nhận mã 503.',
    ]),
]

TEXT_REPLACE = [
    # ---- Chương 2: bảng đặc tả ca sử dụng, bảng lớp thực thể ----
    ('3a. Email chưa đăng ký: Core Backend từ chối và ghi nhật ký; ứng dụng hiển thị thông báo của máy chủ.',
     '3a. Email chưa đăng ký: Core Backend ghi nhật ký và không gửi thư, nhưng trả lời giống như với email đã đăng ký để không lộ '
     'email nào có tài khoản. Ứng dụng vẫn chuyển tới bước 4, nhưng không có mã nào được gửi tới.', 1),
    ('Core Backend kiểm tra quyền sở hữu, xóa và ghi nhật ký',
     'Core Backend kiểm tra quyền sở hữu. Nếu mục tiêu đang giữ tiền, Core Backend trả số tiền đó về ví bằng một khoản thu '
     'danh mục “Thu khác” mang nguồn GOAL_REFUND, rồi xóa mục tiêu và ghi nhật ký', 1),
    ('clientId, rawReceiptData', 'clientId, rawReceiptData, source', 1),

    # ---- Chương 3: triển khai Docker, CSDL, API ----
    ('Toàn bộ phía máy chủ được đóng gói thành sáu container và khởi chạy bằng Docker Compose [38]',
     'Phía máy chủ được đóng gói thành sáu container chạy mặc định và khởi chạy bằng Docker Compose [38]', 1),
    ('Bảng 3.2 liệt kê chi tiết từng container.',
     'Bảng 3.2 liệt kê chi tiết sáu container đó. Tệp còn khai báo ba container tùy chọn chỉ chạy khi bật profile tương ứng: '
     'elasticsearch-init-snapshots và elasticsearch (profile search) giữ chỉ mục tìm kiếm giao dịch, dùng khi đặt '
     'SEARCH_ENGINE=elasticsearch, và kibana (profile tools) là giao diện xem Elasticsearch cho quản trị viên.', 1),
    ('được viết thành tệp SQL trong core-backend/src/main/resources/db.',
     'được viết thành tệp SQL trong core-backend/src/main/resources/db. Tài liệu docs/deploy/MIGRATION_RUNBOOK.md chỉ rõ lúc nào cần '
     'chạy các tệp này. Máy chủ mới bắt đầu từ CSDL trống nên để Hibernate tạo lược đồ và không chạy tệp nào. CSDL cũ thì xóa đi '
     'tạo lại, hoặc chạy các tệp theo thứ tự trong tài liệu.', 1),
    ('Khóa ngoại user_id, category_id; thêm client_id để chống ghi trùng khi gửi lại',
     'Khóa ngoại user_id, category_id; thêm client_id để chống ghi trùng khi gửi lại; thêm source (NORMAL hoặc GOAL_REFUND) để tách '
     'khoản tiền hoàn từ mục tiêu tiết kiệm đã xóa khỏi giao dịch thường', 1),
    ('thêm version cho khóa lạc quan',
     'thêm version cho khóa lạc quan; thêm owner_id, khóa ngoại tới users, làm chủ sở hữu hóa đơn', 1),
    ('còn category_id là liên kết chính thức.',
     'còn category_id là liên kết chính thức. Cột source phân biệt giao dịch thường với khoản tiền một mục tiêu tiết kiệm đã xóa '
     'trả về ví (mục 4.6.2).', 1),
    ('vì ứng dụng gọi AI trước khi tạo hóa đơn.',
     'vì ứng dụng gọi AI trước khi tạo hóa đơn. Cột owner_id ghi chủ sở hữu hóa đơn, và mọi kiểm tra quyền xem, sửa, đọc lại, '
     'gửi số tiền và hủy hóa đơn dựa vào cột này.', 1),
    ('Mật khẩu khi đăng ký, đổi, đặt lại dài 8–72',
     'Mật khẩu khi đăng ký, đổi, đặt lại hoặc khi quản trị viên tạo người dùng dài 8–72', 1),
    ('xóa hóa đơn thì xóa các lượt đọc',
     'mỗi hóa đơn có tối đa 10 lượt đọc, yêu cầu đọc lại khi đã đủ 10 lượt nhận mã 409; xóa hóa đơn thì xóa các lượt đọc', 1),
    ('@Immutable, ON DELETE CASCADE',
     '@Immutable, ON DELETE CASCADE, ReceiptProcessingService.MAX_ATTEMPTS_PER_RECEIPT', 1),
    ('Người dùng chỉ đọc, sửa, xóa giao dịch, hóa đơn, ngân sách, mục tiêu, thông báo có user_id của chính mình (lấy từ JWT)',
     'Người dùng chỉ đọc, sửa, xóa giao dịch, ngân sách, mục tiêu, thông báo có user_id của chính mình, và hóa đơn có owner_id '
     'của chính mình (lấy từ JWT)', 1),
    ('CurrentUserProvider + truy vấn theo user_id',
     'CurrentUserProvider + truy vấn theo user_id; hóa đơn: Receipt.ownerId() trong ReceiptProcessingService.requireOwner()', 1),
    ('mọi id khác id của người đang đăng nhập.',
     'mọi id khác id của người đang đăng nhập. Hóa đơn không có cột user_id: các điểm cuối dưới /api/receipts và '
     'PUT /api/transactions/cancel/{receiptId} so mã người dùng trong JWT với cột receipts.owner_id, và trả mã 403 nếu hóa đơn '
     'của người khác.', 1),
    ('mã 400, 401, 403, 404, 409 hoặc 503 tùy loại.',
     'mã 400, 401, 403, 404, 409, 413, 429 hoặc 503 tùy loại. Lỗi không lường trước được trả bằng mã 500 kèm một câu cố định.', 1),
    ('Bảng 3.23 liệt kê 51 điểm cuối REST dưới /api trên 15 lớp @RestController.',
     'Bảng 3.23 liệt kê 51 điểm cuối REST dưới /api trên 15 lớp @RestController, là các điểm cuối của chức năng chính. Mã nguồn '
     'còn tám điểm cuối khác chưa có trong bảng: GET /api/transactions/search (tìm giao dịch của chính người gọi) và bảy điểm cuối '
     'quản trị của ba lớp AdminLeaderboardController (bảng xếp hạng chi tiêu theo tháng từ Redis), AdminOcrFeedbackController '
     '(phản hồi OCR trong MongoDB) và AdminSearchController (dựng lại chỉ mục tìm kiếm).', 1),
    ('hóa đơn có thể trùng trả 409 trừ khi allowDuplicate = true',
     'hóa đơn có thể trùng trả 409 trừ khi allowDuplicate = true; liên kết ảnh hóa đơn chỉ nhận địa chỉ https', 1),
    ('Ghi lượt đọc lại cho hóa đơn FAILED',
     'Ghi lượt đọc lại cho hóa đơn FAILED, tối đa 10 lượt đọc mỗi hóa đơn (quá thì trả 409)', 1),
    ('Tải ảnh hóa đơn lên Cloudinary',
     'Tải ảnh hóa đơn lên Cloudinary, chỉ nhận JPEG, PNG, WEBP và tối đa 15 MB (quá cỡ trả 413)', 1),
    ('Xóa mục tiêu',
     'Xóa mục tiêu, hoàn số tiền mục tiêu đang giữ về ví', 1),
    ('bảng 10 người dùng đã gán nhãn AI',
     'bảng 10 người dùng mới nhất kèm nhãn AI (người chưa phân lớp hiện “Chưa phân lớp”)', 1),
    ('cùng nút Thêm người dùng mở hộp thoại tạo tài khoản.',
     'cùng nút Thêm người dùng mở hộp thoại tạo tài khoản. Mật khẩu nhập ở hộp thoại này phải đạt cùng quy tắc @StrongPassword '
     'như khi đăng ký.', 1),
    ('câu trả lời thô được ghi thêm vào MongoDB (mục 3.4.1).',
     'câu trả lời thô được ghi thêm vào MongoDB (mục 3.4.1). Hóa đơn được gắn chủ sở hữu (cột owner_id) là người đang đăng nhập, '
     'lấy từ JWT chứ không từ nội dung yêu cầu.', 1),
    ('Thặng dư bằng thu nhập trung bình trừ chi trung bình.',
     'Thặng dư bằng thu nhập trung bình trừ chi trung bình, trong đó khoản thu có source = GOAL_REFUND (tiền hoàn khi xóa mục tiêu '
     'tiết kiệm) không được tính là thu nhập.', 1),

    # ---- Chương 4: Core Backend ----
    ('gồm 216 tệp Java (tại thời điểm 26/10/2026)', 'gồm 284 tệp Java (tại thời điểm 01/11/2026)', 1),
    ('GlobalExceptionHandler chuyển thành mã HTTP tương ứng.',
     'GlobalExceptionHandler chuyển thành mã HTTP tương ứng. Ngoại lệ không lường trước, kể cả lỗi truy cập CSDL, được trả bằng mã '
     '500 kèm câu cố định “Hệ thống đang gặp sự cố, vui lòng thử lại sau”. Nội dung lỗi gốc có thể chứa câu lệnh SQL hay tên bảng '
     'nên chỉ được ghi vào nhật ký máy chủ.', 1),
    ('Mật khẩu mới phải qua ràng buộc @StrongPassword (8–72 ký tự, có chữ và số) và được băm bằng BCrypt.',
     'Mật khẩu mới phải qua ràng buộc @StrongPassword (8–72 ký tự, có chữ và số) và được băm bằng BCrypt. Ràng buộc này cũng áp '
     'cho mật khẩu quản trị viên nhập khi tạo người dùng (UserCreateDto).', 1),
    ('nên một mã không thể dùng hai lần.',
     'nên một mã không thể dùng hai lần. Thư chứa mã được giao cho AsyncMailSender, gửi ngoài luồng xử lý yêu cầu trên nhóm luồng '
     'riêng mailAsyncExecutor (2 luồng, hàng đợi 100 thư). Nhờ vậy yêu cầu quên mật khẩu trả lời ngay, lỗi SMTP chỉ được ghi vào '
     'nhật ký chứ không thành lỗi 500, và khi hàng đợi đầy thì thư bị bỏ để người dùng xin mã lại.', 1),
    ('ghi nhật ký kiểm toán qua AuditLogService.',
     'ghi nhật ký kiểm toán qua AuditLogService. Danh sách giao dịch của người dùng được đọc bằng một truy vấn JOIN FETCH nạp sẵn '
     'danh mục và hóa đơn, nên không phát sinh truy vấn lặp theo từng dòng (N+1).', 1),
    ('Kiểm thử SavingGoalContributionRollbackTest chạy trên giao dịch thật để khẳng định điều này.',
     'Kiểm thử SavingGoalContributionRollbackTest chạy trên giao dịch thật để khẳng định điều này. Khi xóa một mục tiêu đang giữ '
     'tiền, deleteSaving() khóa dòng mục tiêu và hoàn số tiền đó vào ví trong cùng giao dịch, bằng một khoản thu danh mục “Thu khác” '
     'có source = GOAL_REFUND.', 1),
    ('Tệp có thể chạy lại nhiều lần mà kết quả không đổi (idempotent).',
     'Tệp có thể chạy lại nhiều lần mà kết quả không đổi (idempotent). Các tệp migration khác và lúc nào cần chạy chúng được ghi '
     'trong docs/deploy/MIGRATION_RUNBOOK.md, kể cả hai cột mới receipts.owner_id và transactions.source.', 1),

    # ---- Chương 4: công cụ, CI, đóng gói ----
    ('lệnh mvn -B clean test)',
     'lệnh mvn -B clean test -Dtest=!CoreBackendApplicationTests, tức mọi lớp kiểm thử trừ CoreBackendApplicationTests)', 1),
    ('flutter analyze và flutter test)', 'flutter pub get, flutter analyze và flutter test)', 1),
    ('pytest test_main.py)',
     'cài requirements-dev.txt rồi chạy pytest test_*.py, tức mọi tệp kiểm thử của AI Service)', 1),
    ('gồm sáu dịch vụ: proxy ngược', 'gồm sáu dịch vụ chạy mặc định: proxy ngược', 1),
    ('gồm sáu dịch vụ trên mạng nội bộ finance-network (Bảng 4.12).',
     'gồm sáu dịch vụ chạy mặc định trên mạng nội bộ finance-network (Bảng 4.12). Ba dịch vụ tùy chọn (elasticsearch-init-snapshots '
     'và elasticsearch thuộc profile search, kibana thuộc profile tools) chỉ chạy khi bật profile tương ứng, nên không có trong bảng.', 1),

    # ---- Chương 4: ứng dụng di động ----
    ('gồm 90 tệp .dart trong thư mục lib (tại thời điểm 26/10/2026)',
     'gồm 172 tệp .dart trong thư mục lib (tại thời điểm 01/11/2026)', 1),
    ('Tệp ARB tiếng Việt và tiếng Anh (569 khóa)', 'Tệp ARB tiếng Việt và tiếng Anh (702 khóa)', 1),
    ('SqfliteHelper (SQLite phiên bản 8)', 'SqfliteHelper (SQLite phiên bản 9)', 1),
    ('với 569 khóa (tại thời điểm 26/10/2026)', 'với 702 khóa (tại thời điểm 01/11/2026)', 1),
    ('giữ nguyên dữ liệu các bảng cũ.',
     'giữ nguyên dữ liệu các bảng cũ. Phiên bản 9 thêm cột allow_duplicate vào bảng giao dịch cục bộ, để lần gửi lại mang đúng lựa '
     'chọn “Vẫn lưu” của người dùng.', 1),
    ('và mỗi lúc chỉ hiện một thông báo.',
     'và xếp chồng: thông báo mới nhất nằm trên cùng, tối đa ba thông báo cùng lúc (ToastStack.maxLayers = 3), chạm vào chồng từ '
     'hai thông báo trở lên thì mở thành danh sách.', 1),
]
