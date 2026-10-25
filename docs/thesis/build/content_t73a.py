# Nội dung phiên T7.3a: Chương 3, mục 3.1–3.5 (kiến trúc, triển khai, CSDL/ERD/RBTV, MongoDB, Redis, API, JWT).
# Đối chiếu mã nguồn tại HEAD dbcf0c3 ngày 25/10/2026 (core-backend sạch): Entity/*.java, Document/*.java, Dto/*.java,
# Config/{CacheConfig, SecurityConfig}.java, Service/{Cache/*, RedisPasswordResetOtpStore, AuthService, TokenBlacklistService,
# OcrMongoService, TransactionService, LoginAttemptService}.java, Security/{JwtUtil, JwtAuthFilter, TokenRejection}.java,
# Controller/*.java, resources/{redis-cache.properties, db/*.sql}, docker-compose.yml, deploy/caddy/Caddyfile,
# .github/workflows/ci.yml, docs/deploy/DEPLOY_GUIDE.md.
# Trích dẫn: [28] JWT, [29] Fielding REST, [30] Newman, [31] Spring Boot, [32] Spring Security, [35] PostgreSQL, [36] Redis,
# [37] MongoDB, [38] Docker Compose, [45] GitHub Actions, [50] Codd, [51] Chen, [52] Caddy, [53] AWS EC2.
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = "T7.3a"
SRC = "nguồn: nhóm thực hiện"
NGUON = "Nguồn: nhóm thực hiện"

W_COL = [2400, 1700, 1700, 2704]          # Tên cột | Kiểu | Ràng buộc | Ý nghĩa
H_COL = ["Tên cột", "Kiểu dữ liệu", "Ràng buộc", "Ý nghĩa"]
W_RB = [800, 1500, 3304, 1500, 1400]      # Mã | Bối cảnh | Nội dung | Tầm ảnh hưởng | Cài đặt
H_RB = ["Mã", "Bối cảnh", "Nội dung", "Tầm ảnh hưởng", "Nơi kiểm tra"]
AUDIT = ["created_at, updated_at", "timestamp", "", "Thời điểm tạo, sửa gần nhất (BaseEntity, Spring Data Auditing)"]


def tbl(caption, rows):
    return ("table", caption, "3", W_COL, H_COL, rows, NGUON)


T_USERS = [
    ["id", "bigint", "PK, tự tăng", "Mã người dùng"],
    ["username", "varchar(255)", "NOT NULL, UNIQUE", "Tên đăng nhập"],
    ["password", "varchar(255)", "NOT NULL", "Mật khẩu đã băm bằng BCrypt"],
    ["email", "varchar(255)", "NOT NULL, UNIQUE", "Email, dùng để đăng nhập và nhận mã OTP"],
    ["phone", "varchar(255)", "NOT NULL, UNIQUE", "Số điện thoại"],
    ["role", "varchar(255)", "NOT NULL, mặc định ROLE_USER", "Vai trò: ROLE_USER, ROLE_ADMIN hoặc ROLE_LOCKED"],
    ["active", "boolean", "NOT NULL, mặc định true", "Tài khoản còn hoạt động"],
    ["wallet_balance", "numeric(38,2)", "NOT NULL, mặc định 0", "Số dư ví, cập nhật khi giao dịch thay đổi"],
    ["credentials_version", "integer", "NOT NULL, mặc định 0", "Phiên bản thông tin đăng nhập, tăng khi đổi hoặc đặt lại mật khẩu"],
    ["ai_label", "varchar(50)", "", "Nhãn phân khúc khách hàng do AI Service gán"],
    ["last_login_time, last_action_time", "timestamp", "", "Lần đăng nhập và lần thao tác gần nhất"],
    AUDIT,
]
T_CATEGORIES = [
    ["id", "bigint", "PK, tự tăng", "Mã danh mục"],
    ["name", "varchar(255)", "NOT NULL", "Tên danh mục"],
    ["type", "varchar(255)", "NOT NULL", "Loại danh mục: EXPENSE (chi) hoặc INCOME (thu)"],
    AUDIT,
]
T_TRANSACTIONS = [
    ["id", "bigint", "PK, tự tăng", "Mã giao dịch"],
    ["user_id", "bigint", "NOT NULL, FK → users", "Chủ giao dịch"],
    ["category_id", "bigint", "NOT NULL, FK → categories", "Danh mục của giao dịch"],
    ["receipt_id", "bigint", "FK → receipts, UNIQUE", "Hóa đơn đính kèm (nếu có)"],
    ["amount", "numeric(38,2)", "NOT NULL", "Số tiền, luôn dương"],
    ["is_expense", "boolean", "NOT NULL", "true là khoản chi, false là khoản thu"],
    ["transaction_date", "timestamp", "NOT NULL", "Thời điểm phát sinh giao dịch"],
    ["client_id", "varchar(64)", "UNIQUE (user_id, client_id)", "Khóa chống ghi trùng do ứng dụng di động sinh (UUID)"],
    ["category_name, note, location, payment_method", "varchar(255)", "", "Tên danh mục hiển thị, ghi chú, địa điểm, nguồn tiền"],
    ["additional_images", "text", "", "Danh sách URL ảnh phụ dạng JSON"],
    ["raw_receipt_data", "text", "chỉ đọc", "Cột cũ giữ câu trả lời AI của các bản trước; dữ liệu mới nằm ở receipt_processing_attempts"],
    ["status, voucher_code", "varchar(255)", "", "Hai cột dự phòng, hiện không có luồng nào ghi"],
    AUDIT,
]
T_RECEIPTS = [
    ["id", "bigint", "PK, tự tăng", "Mã hóa đơn"],
    ["status", "varchar(255)", "NOT NULL, mặc định PENDING", "Trạng thái trong vòng đời hóa đơn (8 giá trị của ReceiptStatus)"],
    ["version", "bigint", "NOT NULL, mặc định 0", "Số phiên bản cho khóa lạc quan (@Version)"],
    ["vendor_name", "varchar(255)", "", "Tên cửa hàng sau đối soát"],
    ["extracted_total", "numeric(38,2)", "", "Tổng tiền sau đối soát"],
    ["extracted_date", "date", "", "Ngày trên hóa đơn"],
    ["image_url", "varchar(2048)", "", "URL ảnh hóa đơn trên Cloudinary"],
    ["error_code", "varchar(40)", "", "Lý do thất bại: AI_UNREADABLE, AI_NO_TOTAL, REJECTED_BY_ADMIN"],
    ["ai_raw_data", "text", "chỉ đọc", "Cột cũ, đã được chuyển thành lượt đọc LEGACY"],
    AUDIT,
]
T_ATTEMPTS = [
    ["id", "bigint", "PK, tự tăng", "Mã lượt đọc"],
    ["receipt_id", "bigint", "NOT NULL, FK → receipts, ON DELETE CASCADE", "Hóa đơn được đọc"],
    ["attempt_number", "integer", "NOT NULL, UNIQUE (receipt_id, attempt_number)", "Số thứ tự lượt đọc, bắt đầu từ 1"],
    ["status", "varchar(20)", "NOT NULL", "COMPLETED, FAILED hoặc LEGACY"],
    ["ai_raw_data", "text", "NOT NULL", "Nguyên văn câu trả lời của AI Service, không bao giờ bị ghi đè"],
    ["error_code", "varchar(40)", "", "Mã lỗi khi lượt đọc thất bại"],
    ["safe_error_message", "varchar(255)", "", "Thông báo lỗi an toàn để hiển thị"],
    ["client_id", "varchar(64)", "UNIQUE (receipt_id, client_id)", "Khóa chống gửi lặp một lần quét lại"],
    ["created_at", "timestamp", "NOT NULL", "Thời điểm ghi nhận lượt đọc"],
    ["completed_at", "timestamp", "", "Thời điểm kết thúc lượt đọc"],
]
T_BUDGETS = [
    ["id", "bigint", "PK, tự tăng", "Mã ngân sách"],
    ["user_id", "bigint", "NOT NULL, FK → users", "Chủ ngân sách"],
    ["category_id", "bigint", "FK → categories, cho phép NULL", "Danh mục bị giới hạn; NULL là mọi danh mục"],
    ["category_key", "bigint", "NOT NULL, mặc định 0", "Bằng category_id, hoặc 0 khi áp cho mọi danh mục"],
    ["amount", "numeric(19,2)", "NOT NULL", "Hạn mức chi trong kỳ"],
    ["period_type", "varchar(10)", "NOT NULL, CHECK (WEEK, MONTH)", "Loại kỳ hạn"],
    ["start_date, end_date", "date", "NOT NULL", "Ngày bắt đầu và kết thúc kỳ"],
    AUDIT,
]
T_SAVINGS = [
    ["id", "bigint", "PK, tự tăng", "Mã mục tiêu"],
    ["user_id", "bigint", "NOT NULL, FK → users", "Chủ mục tiêu"],
    ["title", "varchar(255)", "NOT NULL", "Tên mục tiêu"],
    ["target_amount", "numeric(38,2)", "NOT NULL", "Số tiền cần đạt"],
    ["current_amount", "numeric(38,2)", "NOT NULL, mặc định 0", "Số tiền đã tích lũy"],
    ["deadline", "varchar(255)", "", "Hạn hoàn thành do người dùng nhập"],
    AUDIT,
]
T_NOTIFICATIONS = [
    ["id", "bigint", "PK, tự tăng", "Mã thông báo"],
    ["user_id", "bigint", "NOT NULL, FK → users", "Người nhận"],
    ["type", "varchar(30)", "NOT NULL, CHECK (4 giá trị)", "BUDGET_WARNING, BUDGET_EXCEEDED, TRANSACTION_ALERT, RECEIPT_PROCESSED"],
    ["message", "varchar(500)", "NOT NULL", "Nội dung thông báo"],
    ["is_read", "boolean", "NOT NULL, mặc định false", "Đã đọc hay chưa"],
    ["transaction_id, budget_id, receipt_id", "bigint", "không có FK", "Mã đối tượng liên quan để ứng dụng mở đúng màn hình"],
    AUDIT,
]
T_PAYMENTS = [
    ["id", "bigint", "PK, tự tăng", "Mã lệnh"],
    ["order_code", "varchar(64)", "NOT NULL, UNIQUE", "Mã lệnh gửi sang cổng thanh toán"],
    ["user_id", "bigint", "NOT NULL, không có FK", "Người tạo lệnh"],
    ["amount", "numeric(19,2)", "NOT NULL", "Số tiền nạp hoặc rút"],
    ["type", "varchar(16)", "NOT NULL, CHECK (DEPOSIT, WITHDRAW)", "Loại lệnh"],
    ["status", "varchar(16)", "NOT NULL, CHECK (4 giá trị)", "PENDING, SUCCESS, FAILED, CANCELLED"],
    ["provider", "varchar(16)", "NOT NULL", "Cổng thanh toán"],
    ["description", "varchar(255)", "", "Mô tả"],
    ["gateway_txn_id", "varchar(64)", "", "Mã giao dịch phía cổng thanh toán"],
    ["signature", "varchar(128)", "", "Chữ ký xác thực webhook"],
    AUDIT,
]
T_PLANS = [
    ["id", "bigint", "PK, tự tăng", "Mã gói"],
    ["plan_name", "varchar(255)", "", "Tên gói"],
    ["price", "float(53)", "", "Giá gói"],
    ["duration_days", "integer", "", "Số ngày hiệu lực"],
    ["max_ai_scans", "integer", "", "Số lượt quét AI tối đa"],
    ["is_wcm_spade_enabled", "boolean", "NOT NULL", "Gói có báo cáo thói quen chi tiêu hay không"],
    ["active", "boolean", "NOT NULL, mặc định true", "Gói đang được bán"],
]
T_REVIEWS = [
    ["id", "bigint", "PK, tự tăng", "Mã đánh giá"],
    ["user_id", "bigint", "FK → users, cho phép NULL", "Người đánh giá"],
    ["user_email", "varchar(255)", "", "Email người đánh giá lấy từ JWT"],
    ["rating", "integer", "NOT NULL", "Số sao"],
    ["comment", "text", "", "Nội dung đánh giá"],
    ["status", "varchar(255)", "NOT NULL, mặc định PENDING", "PENDING hoặc APPROVED"],
    ["created_at", "timestamp", "không sửa được", "Thời điểm gửi"],
]
T_LOGS = [
    ["id", "bigint", "PK, tự tăng", "Mã nhật ký"],
    ["user_id", "bigint", "không có FK", "Người thực hiện (NULL với thao tác chưa đăng nhập)"],
    ["user_email", "varchar(255)", "", "Email người thực hiện tại thời điểm ghi"],
    ["action", "varchar(255)", "", "Mã hành động, ví dụ PASSWORD_CHANGED, RECEIPT_RETRIED"],
    ["target_type, target_id", "varchar(32), bigint", "", "Loại và mã đối tượng bị tác động"],
    ["result", "varchar(16)", "", "Kết quả của thao tác"],
    ["description", "varchar(1000)", "", "Mô tả bằng tiếng Việt"],
    ["ip_address", "varchar(255)", "", "Địa chỉ IP của yêu cầu"],
    ["timestamp", "timestamp", "", "Thời điểm ghi"],
]
T_REVOKED = [
    ["id", "bigint", "PK, tự tăng", "Mã bản ghi"],
    ["token_hash", "varchar(64)", "NOT NULL, UNIQUE", "Giá trị băm SHA-256 của JWT bị thu hồi"],
    ["expires_at", "timestamp", "NOT NULL, có chỉ mục", "Thời điểm token hết hạn tự nhiên"],
    ["revoked_at", "timestamp", "NOT NULL", "Thời điểm thu hồi"],
]

RB_MIEN = [
    ["MG1", "users", "Mật khẩu khi đăng ký, đổi, đặt lại dài 8–72 ký tự, có ít nhất một chữ cái và một chữ số", "T(+), S(+ password)", "@StrongPassword"],
    ["MG2", "users", "Số điện thoại khi đăng ký gồm đúng 10 chữ số; email đúng định dạng", "T(+)", "RegisterRequestDto (@Pattern, @Email)"],
    ["MG3", "users", "role ∈ {ROLE_USER, ROLE_ADMIN, ROLE_LOCKED}", "T(+), S(+ role)", "Roles.normalize"],
    ["MG4", "transactions", "amount > 0", "T(+), S(+ amount)", "@Positive (TransactionRequestDto, TransactionUpdateRequestDto)"],
    ["MG5", "transactions", "client_id dài tối đa 64 ký tự", "T(+)", "@Size, cột varchar(64)"],
    ["MG6", "budgets", "amount > 0, tối đa 17 chữ số phần nguyên và 2 chữ số thập phân", "T(+), S(+ amount)", "@DecimalMin, @Digits, numeric(19,2)"],
    ["MG7", "budgets", "period_type ∈ {WEEK, MONTH}", "T(+), S(+ period_type)", "CHECK do Hibernate sinh từ enum"],
    ["MG8", "notifications", "type ∈ {BUDGET_WARNING, BUDGET_EXCEEDED, TRANSACTION_ALERT, RECEIPT_PROCESSED}; message tối đa 500 ký tự", "T(+)", "CHECK enum, varchar(500)"],
    ["MG9", "receipts", "status thuộc 8 giá trị của ReceiptStatus; error_code ∈ {AI_UNREADABLE, AI_NO_TOTAL, REJECTED_BY_ADMIN}", "T(+), S(+ status)", "Receipt.moveTo, Receipt.failWith"],
    ["MG10", "receipts", "extracted_total > 0 khi người dùng sửa hóa đơn", "S(+ extracted_total)", "@Positive (ReceiptUpdateRequestDto)"],
    ["MG11", "receipt_processing_attempts", "status ∈ {COMPLETED, FAILED, LEGACY}; attempt_number ≥ 1; ai_raw_data khác rỗng, tối đa 32.768 ký tự khi gửi lên", "T(+)", "ReceiptProcessingAttempt, @Size"],
    ["MG12", "payment_orders", "type ∈ {DEPOSIT, WITHDRAW}; status ∈ {PENDING, SUCCESS, FAILED, CANCELLED}; amount ≥ 1.000", "T(+), S(+ status)", "CHECK enum, @DecimalMin"],
    ["MG13", "app_reviews", "1 ≤ rating ≤ 5; comment khác rỗng", "T(+)", "@Min, @Max, @NotBlank (ReviewRequestDto)"],
]
RB_LIEN_TT = [
    ["LT1", "budgets", "end_date ≥ start_date", "T(+), S(+ start_date, end_date)", "@AssertTrue (BudgetRequestDto)"],
    ["LT2", "budgets", "Số ngày từ start_date tới end_date (tính cả hai đầu) không vượt độ dài kỳ: 7 ngày với WEEK, 31 ngày với MONTH", "T(+), S(+ start_date, end_date, period_type)", "BudgetPeriodType.allowsRange"],
    ["LT3", "budgets", "category_key = category_id khi có danh mục, = 0 khi category_id là NULL", "T(+), S(+ category_id)", "Budget.setCategory"],
    ["LT4", "receipts", "error_code khác NULL khi và chỉ khi status = FAILED", "S(+ status)", "Receipt.moveTo, Receipt.failWith"],
    ["LT5", "receipt_processing_attempts", "error_code và safe_error_message chỉ có giá trị khi status = FAILED", "T(+)", "ReceiptProcessingAttempt.failed"],
    ["LT6", "revoked_tokens", "revoked_at ≤ expires_at; bản ghi có expires_at đã qua bị xóa mỗi ngày lúc 03:30", "T(+)", "TokenBlacklistService"],
]
RB_LIEN_BO = [
    ["LB1", "users, transactions", "Khi thêm, sửa, xóa giao dịch, wallet_balance của chủ giao dịch được cộng hoặc trừ đúng phần chênh lệch, trong cùng một giao dịch CSDL, sau khi khóa dòng users (PESSIMISTIC_WRITE)", "transactions: T, X, S(amount, is_expense); users: S(wallet_balance)", "TransactionService"],
    ["LB2", "users, transactions", "Thêm hoặc sửa một khoản chi không được làm wallet_balance nhỏ hơn 0", "transactions: T, S", "TransactionService (InsufficientBalanceException)"],
    ["LB3", "transactions, categories", "Mỗi giao dịch thuộc đúng một danh mục tồn tại", "transactions: T, S(category_id); categories: X", "FK NOT NULL"],
    ["LB4", "transactions, receipts", "Một hóa đơn thuộc tối đa một giao dịch; hóa đơn được lưu và xóa cùng giao dịch", "transactions: T, X", "FK UNIQUE receipt_id, cascade ALL"],
    ["LB5", "receipts, receipt_processing_attempts", "Lượt đọc mới có attempt_number bằng số lượt hiện có cộng 1; lượt đọc không bị sửa; xóa hóa đơn thì xóa các lượt đọc", "attempts: T; receipts: X", "@Immutable, ON DELETE CASCADE"],
    ["LB6", "receipts", "Chỉ được chuyển trạng thái theo bảng chuyển hợp lệ (ví dụ PENDING → COMPLETED_RAW, FAILED → WAITING_FOR_REVIEW, WAITING_FOR_REVIEW → APPROVED); CANCELED là trạng thái cuối", "S(status)", "ReceiptStatus.canTransitionTo"],
    ["LB7", "receipts", "Hai yêu cầu sửa cùng một hóa đơn: yêu cầu mang version cũ bị từ chối với mã 409", "S", "@Version (khóa lạc quan)"],
    ["LB8", "budgets, categories", "Danh mục của ngân sách, nếu có, phải tồn tại", "budgets: T, S; categories: X", "FK category_id"],
    ["LB9", "users, các bảng con", "Người dùng chỉ đọc, sửa, xóa giao dịch, hóa đơn, ngân sách, mục tiêu, thông báo có user_id của chính mình (lấy từ JWT)", "mọi thao tác", "CurrentUserProvider + truy vấn theo user_id"],
]
RB_DUY_NHAT = [
    ["DN1", "users", "username, email, phone là duy nhất", "T(+), S(+)", "UNIQUE"],
    ["DN2", "transactions", "(user_id, client_id) là duy nhất; một yêu cầu gửi lại cùng client_id nhận lại giao dịch đã tạo thay vì tạo bản thứ hai", "T(+)", "uk_transactions_user_client_id"],
    ["DN3", "transactions", "receipt_id là duy nhất", "T(+), S(+)", "UNIQUE do @OneToOne"],
    ["DN4", "budgets", "(user_id, category_key, period_type, start_date) là duy nhất", "T(+), S(+)", "uk_budgets_user_category_period"],
    ["DN5", "receipt_processing_attempts", "(receipt_id, attempt_number) và (receipt_id, client_id) là duy nhất", "T(+)", "uk_receipt_attempts_receipt_number, uk_receipt_attempts_receipt_client_id"],
    ["DN6", "payment_orders", "order_code là duy nhất", "T(+)", "UNIQUE"],
    ["DN7", "revoked_tokens", "token_hash là duy nhất", "T(+)", "UNIQUE"],
    ["DN8", "ocr_logs (MongoDB)", "transactionId là duy nhất", "T(+)", "@Indexed(unique = true)"],
]

PUB, JWT, ADM = "Công khai", "JWT", "JWT + ROLE_ADMIN"
API = [
    ["Xác thực", "POST /api/auth/register", "Đăng ký tài khoản", PUB],
    ["", "POST /api/auth/login", "Đăng nhập bằng email/tên đăng nhập và mật khẩu", PUB],
    ["", "POST /api/auth/social-login", "Đăng nhập bằng Google hoặc Facebook", PUB],
    ["", "POST /api/auth/forgot-password", "Gửi mã OTP đặt lại mật khẩu qua email", PUB],
    ["", "POST /api/auth/reset-password", "Đặt lại mật khẩu bằng mã OTP", PUB],
    ["", "PUT /api/auth/change-password", "Đổi mật khẩu, nhận cặp token mới", JWT],
    ["", "POST /api/auth/logout", "Đăng xuất, thu hồi access và refresh token", JWT],
    ["", "POST /api/auth/refresh", "Đổi refresh token lấy cặp token mới", PUB],
    ["Người dùng", "GET /api/users/me", "Thông tin tài khoản đang đăng nhập", JWT],
    ["", "PUT /api/users/{id}", "Sửa hồ sơ của chính mình", JWT],
    ["Giao dịch", "GET /api/transactions/mine", "Danh sách giao dịch của người dùng", JWT],
    ["", "POST /api/transactions/checkout", "Tạo giao dịch (kèm hóa đơn nếu có), cập nhật số dư", JWT],
    ["", "PUT /api/transactions/{id}", "Sửa giao dịch", JWT],
    ["", "DELETE /api/transactions/{id}", "Xóa giao dịch, hoàn số dư", JWT],
    ["", "GET /api/transactions/filter", "Lọc giao dịch theo điều kiện", JWT],
    ["", "PUT /api/transactions/cancel/{receiptId}", "Hủy hóa đơn của mình", JWT],
    ["", "GET /api/transactions/popular-vendors", "Cửa hàng chi tiêu nhiều nhất (có cache)", JWT],
    ["", "GET /api/transactions/app-dashboard", "Số liệu tổng quan của người dùng (có cache)", JWT],
    ["Danh mục", "GET /api/categories", "Danh sách danh mục", PUB],
    ["Hóa đơn", "GET /api/receipts/{id}", "Chi tiết hóa đơn", JWT],
    ["", "GET /api/receipts/transaction/{transactionId}", "Hóa đơn của một giao dịch", JWT],
    ["", "PUT /api/receipts/{id}", "Sửa kết quả đối soát (kèm version)", JWT],
    ["", "POST /api/receipts/{id}/retry", "Ghi lượt đọc lại cho hóa đơn FAILED", JWT],
    ["", "POST /api/receipts/feedback/{receiptId}", "Gửi số tiền đúng, chuyển hóa đơn sang chờ duyệt", JWT],
    ["Tệp", "POST /api/upload", "Tải ảnh hóa đơn lên Cloudinary", JWT],
    ["Ngân sách", "GET /api/budgets", "Danh sách ngân sách kèm tiến độ", JWT],
    ["", "GET /api/budgets/{id}", "Chi tiết một ngân sách", JWT],
    ["", "POST /api/budgets", "Tạo ngân sách", JWT],
    ["", "PUT /api/budgets/{id}", "Sửa ngân sách", JWT],
    ["", "DELETE /api/budgets/{id}", "Xóa ngân sách", JWT],
    ["Tiết kiệm", "GET /api/savings", "Danh sách mục tiêu tiết kiệm", JWT],
    ["", "POST /api/savings", "Tạo mục tiêu", JWT],
    ["", "PUT /api/savings/{id}", "Cập nhật số tiền đã tích lũy", JWT],
    ["", "DELETE /api/savings/{id}", "Xóa mục tiêu", JWT],
    ["Thông báo", "GET /api/notifications", "Danh sách thông báo theo trang", JWT],
    ["", "GET /api/notifications/unread-count", "Số thông báo chưa đọc", JWT],
    ["", "PATCH /api/notifications/{id}/read", "Đánh dấu một thông báo đã đọc", JWT],
    ["", "PATCH /api/notifications/read-all", "Đánh dấu tất cả đã đọc", JWT],
    ["Thanh toán", "POST /api/payment/create", "Tạo lệnh nạp hoặc rút tiền", JWT],
    ["", "POST /api/payment/webhook", "Cổng thanh toán báo kết quả (kiểm tra chữ ký)", PUB],
    ["", "GET /api/payment/status/{orderCode}", "Trạng thái một lệnh", JWT],
    ["", "GET /api/payment/mine", "Danh sách lệnh của người dùng", JWT],
    ["", "PUT /api/payment/cancel/{orderCode}", "Hủy lệnh đang chờ", JWT],
    ["Đánh giá", "POST /api/reviews", "Gửi đánh giá ứng dụng", JWT],
    ["Quản trị", "GET /api/admin/audit-logs", "Tra cứu nhật ký hoạt động có lọc và phân trang", ADM],
    ["", "GET /api/admin/receipts/{id}/attempts", "Các lượt AI đọc một hóa đơn", ADM],
    ["", "GET /api/admin/transactions/popular-vendors", "Cửa hàng phổ biến toàn hệ thống", ADM],
    ["", "GET /api/admin/transactions/app-dashboard", "Số liệu tổng quan toàn hệ thống", ADM],
    ["", "GET /api/admin/ocr-logs", "Nhật ký AI thô trong MongoDB, phân trang", ADM],
]

SECTIONS = {
    # ============================================================ 3.1
    "GIỚI THIỆU": [
        ("p", "Chương 2 đã xác định hệ thống cần làm gì thông qua 22 use case và 15 lớp thực thể mức phân tích. Chương 3 trả "
              "lời câu hỏi hệ thống được tổ chức như thế nào để thực hiện các yêu cầu đó. Phần đầu chương trình bày kiến trúc "
              "tổng thể gồm ba dịch vụ ứng dụng và ba hệ lưu trữ, cùng cách các container được triển khai trên máy chủ. Tiếp "
              "theo là thiết kế cơ sở dữ liệu quan hệ: chuyển lớp phân tích thành bảng, sơ đồ thực thể kết hợp, mô tả từng "
              "bảng và đặc tả các ràng buộc toàn vẹn. Sau đó, chương trình bày phần dữ liệu đặt ngoài PostgreSQL (nhật ký AI "
              "trên MongoDB, bộ nhớ đệm và mã OTP trên Redis), danh sách API RESTful và cơ chế xác thực bằng JWT. Các mục còn "
              "lại về giao diện, lớp thiết kế, thiết kế chức năng và mô hình AI được trình bày ở phần sau của chương."),
        ("p", "Mọi tên bảng, tên cột, ràng buộc, khóa cache và đường dẫn API trong chương được lấy trực tiếp từ mã nguồn của "
              "Core Backend, tệp docker-compose.yml và cấu hình Caddy tại thời điểm viết, để người đọc có thể đối chiếu."),
    ],
    # ============================================================ 3.2.1
    "Kiến trúc microservices": [
        ("p", "Kiến trúc microservices chia một ứng dụng thành các dịch vụ nhỏ, mỗi dịch vụ chạy trong tiến trình riêng, "
              "được triển khai độc lập và giao tiếp với nhau qua mạng [30]. Nhóm áp dụng cách chia này ở mức vừa phải: hệ "
              "thống có hai dịch vụ nghiệp vụ viết bằng hai ngôn ngữ khác nhau, vì phần suy luận mô hình DONUT cần hệ sinh "
              "thái Python (PyTorch, Hugging Face Transformers), còn phần nghiệp vụ tài chính cần giao dịch CSDL chặt chẽ của "
              "Spring. Hình 3.1 trình bày các thành phần và đường giao tiếp chính."),
        ("fig", "Kiến trúc tổng thể của hệ thống", "3", PNG + "ch3_kien_truc_tong_the.png", 16.0, SRC, None),
        ("p", "Ở tầng trình bày, ứng dụng di động Flutter là kênh duy nhất của người dùng cuối. Ứng dụng gọi Core Backend để "
              "đọc, ghi dữ liệu và gọi thẳng AI Service để quét hóa đơn, phân tích thói quen chi tiêu; kết quả quét chỉ được "
              "lưu khi người dùng đối soát xong và gửi giao dịch về Core Backend. SQLite trên máy chỉ còn vai trò hàng đợi "
              "(outbox) cho những giao dịch tạo khi mất mạng. Web Admin không phải một ứng dụng riêng mà là các trang Thymeleaf "
              "do Core Backend sinh ra dưới đường dẫn /admin, dùng phiên đăng nhập thay vì JWT."),
        ("p", "Mọi yêu cầu từ bên ngoài đi qua reverse proxy Caddy [52]. Caddy chuyển /ai/donut/*, /ai/spade/* và /ai/health "
              "tới AI Service (bỏ tiền tố /ai), chặn các đường dẫn /actuator/* trừ /actuator/health, và chuyển phần còn lại tới "
              "Core Backend. Nhờ đó, đường dẫn /admin/segment của AI Service không đi ra ngoài được; chỉ Core Backend gọi nó qua "
              "mạng nội bộ khi quản trị viên chạy phân khúc khách hàng. Bảng 3.1 tóm tắt vai trò của từng thành phần."),
        ("table", "Các thành phần trong kiến trúc hệ thống", "3", [2000, 2600, 3904],
         ["Thành phần", "Công nghệ", "Vai trò"], [
             ["Ứng dụng di động", "Flutter, Dart, Dio, SQLite", "Giao diện người dùng; quét hóa đơn; hàng đợi giao dịch offline"],
             ["Web Admin", "Thymeleaf (trong Core Backend)", "Quản lý người dùng, danh mục, gói dịch vụ, duyệt hóa đơn, xem nhật ký và thống kê"],
             ["Reverse proxy", "Caddy 2.8", "Cấp chứng chỉ và kết thúc HTTPS; định tuyến theo đường dẫn; nén gzip"],
             ["Core Backend", "Spring Boot 3.2.5, Java 21, Spring Security, Spring Data JPA, Hibernate Envers", "Toàn bộ nghiệp vụ tài chính, xác thực, phân quyền, nhật ký kiểm toán, thống kê"],
             ["AI Service", "FastAPI, PyTorch, Transformers", "Trích xuất 4 trường hóa đơn bằng DONUT; phân tích chuỗi chi tiêu (WCM-SPADE); phân khúc RFM"],
             ["PostgreSQL 15", "Hệ quản trị CSDL quan hệ", "Nguồn dữ liệu gốc của mọi nghiệp vụ, kể cả vòng đời hóa đơn"],
             ["Redis 8", "Kho khóa – giá trị trong bộ nhớ", "Cache số liệu thống kê; lưu mã OTP đặt lại mật khẩu"],
             ["MongoDB 6", "CSDL document", "Lưu câu trả lời thô của AI theo giao dịch để tra cứu và phân tích"],
         ], NGUON),
        ("p", "Ba hệ lưu trữ được chọn theo bản chất dữ liệu. Dữ liệu tiền bạc cần tính nhất quán và giao dịch ACID nên nằm "
              "trong PostgreSQL [35]. Số liệu thống kê được đọc nhiều, tính tốn chi phí nhưng chấp nhận trễ vài chục giây, nên "
              "được đệm trong Redis [36]. Câu trả lời JSON của AI có cấu trúc thay đổi theo phiên bản mô hình nên phù hợp với "
              "document của MongoDB [37]. Core Backend là dịch vụ duy nhất truy cập cả ba hệ lưu trữ; AI Service không giữ "
              "trạng thái và không kết nối CSDL nào."),
    ],
    # ============================================================ 3.2.2
    "Sơ đồ triển khai": [
        ("p", "Toàn bộ phía máy chủ được đóng gói thành sáu container và khởi chạy bằng Docker Compose [38] trên một máy ảo "
              "Amazon EC2 [53]. Hình 3.2 là sơ đồ triển khai theo tệp docker-compose.yml; Bảng 3.2 liệt kê chi tiết từng "
              "container."),
        ("fig", "Sơ đồ triển khai hệ thống", "3", PNG + "ch3_trien_khai.png", 15.0, SRC, None),
        ("table", "Các container trong tệp docker-compose.yml", "3", [1700, 2000, 2400, 2404],
         ["Service", "Image", "Cổng", "Ghi chú"], [
             ["proxy", "caddy:2.8-alpine", "80, 443 (TCP và UDP), công khai", "Giới hạn 128 MB; volume caddy_data, caddy_config giữ chứng chỉ"],
             ["core-api", "build ./core-backend (eclipse-temurin:21-jre-jammy)", "8080, chỉ trong mạng nội bộ", "Giới hạn 512 MB; chờ db, redis, data-mining-api sẵn sàng"],
             ["data-mining-api", "build ./ai-service (python:3.10-slim)", "8000, chỉ trong mạng nội bộ", "Giới hạn 1 GB; uvicorn ai_service:app"],
             ["db", "postgres:15-alpine", "127.0.0.1:5432", "Volume postgres_data"],
             ["redis", "redis:8.10-alpine", "không mở cổng", "Có mật khẩu, chính sách allkeys-lru, không ghi xuống đĩa, tắt lệnh KEYS, FLUSHALL, FLUSHDB"],
             ["mongodb", "mongo:6.0", "127.0.0.1:27017", "Giới hạn 512 MB; volume mongodb_data"],
         ], NGUON),
        ("p", "Thiết kế mạng tuân theo nguyên tắc chỉ mở những gì cần mở. Proxy là container duy nhất công bố cổng ra Internet; "
              "core-api và data-mining-api chỉ khai báo cổng nội bộ (expose) trên mạng bridge finance-network. PostgreSQL và "
              "MongoDB chỉ gắn vào địa chỉ loopback 127.0.0.1 của máy chủ để quản trị viên kết nối qua đường hầm SSH khi cần, "
              "còn Redis không mở cổng nào. Khóa ký JWT (JWT_SECRET) và các mật khẩu CSDL nằm trong tệp .env trên máy chủ, "
              "không có trong kho mã nguồn; ở profile prod, Core Backend từ chối khởi động nếu thiếu JWT_SECRET hoặc khóa ngắn "
              "hơn 32 byte."),
        ("p", "Quy trình tích hợp và triển khai liên tục dùng GitHub Actions [45]. Mỗi lần đẩy mã, ba job backend-ci, mobile-ci "
              "và ai-ci chạy kiểm thử của từng thành phần. Khi đẩy lên nhánh main và cả ba job đều đạt, job deploy kết nối SSH "
              "tới máy chủ EC2, kiểm tra tệp .env có JWT_SECRET đủ 32 ký tự, cập nhật mã theo origin/main rồi chạy docker compose "
              "build và docker compose up -d --wait để thay container mới. Khi đẩy một tag bắt đầu bằng v, job release-apk "
              "build tệp APK đã ký và đính kèm vào bản phát hành trên GitHub, để người dùng tải về điện thoại Android."),
        ("y", "[Nhóm] Bổ sung loại máy EC2 và hệ điều hành thực tế sau khi triển khai (hướng dẫn trong docs/deploy/DEPLOY_GUIDE.md "
              "đề xuất Ubuntu Server 24.04 LTS, t3.medium); kết quả triển khai trình bày ở Chương 5."),
    ],
    # ============================================================ 3.3.1
    "Chuyển từ sơ đồ lớp phân tích sang mô hình quan hệ": [
        ("p", "Mô hình quan hệ biểu diễn dữ liệu dưới dạng các quan hệ (bảng), mỗi quan hệ là tập các bộ có cùng tập thuộc "
              "tính, và liên kết giữa các quan hệ được thể hiện bằng giá trị khóa [50]. Nhóm chuyển 15 lớp thực thể ở mục 2.4 "
              "sang mô hình này theo các quy tắc quen thuộc: mỗi lớp thành một bảng có khóa chính thay thế id kiểu bigint tự "
              "tăng; quan hệ một – nhiều thành khóa ngoại ở phía nhiều; quan hệ hợp thành thêm ràng buộc xóa theo; thuộc tính "
              "kiểu liệt kê thành cột chuỗi có miền giá trị giới hạn. Hai lớp «document» không chuyển thành bảng mà thành hai "
              "collection của MongoDB (mục 3.4.1). Bảng 3.3 ghi lại kết quả và các quyết định riêng cho từng lớp."),
        ("table", "Chuyển các lớp phân tích thành bảng dữ liệu", "3", [2200, 2300, 4004],
         ["Lớp phân tích", "Bảng / collection", "Quyết định khi chuyển đổi"], [
             ["User", "users", "Vai trò là cột role kiểu chuỗi, không tách bảng; thêm credentials_version phục vụ thu hồi phiên"],
             ["Category", "categories", "Bảng dùng chung cho mọi người dùng"],
             ["Transaction", "transactions", "Khóa ngoại user_id, category_id; thêm client_id để chống ghi trùng khi gửi lại"],
             ["Receipt", "receipts", "Quan hệ hợp thành với Transaction đặt bằng khóa ngoại receipt_id duy nhất ở bảng transactions; thêm version cho khóa lạc quan"],
             ["ReceiptProcessingAttempt", "receipt_processing_attempts", "Khóa ngoại receipt_id với ON DELETE CASCADE; bảng chỉ thêm, không sửa"],
             ["Budget", "budgets", "Danh mục 0..1 thành khóa ngoại cho phép NULL, kèm cột category_key để ràng buộc duy nhất hoạt động cả khi không có danh mục"],
             ["SavingGoal", "saving_goals", "Khóa ngoại user_id"],
             ["Notification", "notifications", "Chỉ lưu mã giao dịch, ngân sách, hóa đơn liên quan, không đặt khóa ngoại để thông báo cũ còn đọc được khi đối tượng bị xóa"],
             ["PaymentOrder", "payment_orders", "user_id là cột số, không đặt khóa ngoại"],
             ["SubscriptionPlan", "subscription_plans", "Bảng danh mục độc lập"],
             ["AppReview", "app_reviews", "Khóa ngoại user_id cho phép NULL; lưu thêm user_email"],
             ["ActionLog", "action_logs", "user_id không đặt khóa ngoại để nhật ký còn nguyên khi tài khoản bị xóa; bảng chỉ thêm"],
             ["RevokedToken", "revoked_tokens", "Lưu giá trị băm của token, không gắn người dùng"],
             ["OcrRawLog", "ocr_logs (MongoDB)", "Document gắn với giao dịch qua transactionId"],
             ["OcrFeedback", "ocr_feedbacks (MongoDB)", "Document gắn với hóa đơn và người dùng qua receiptId, userId"],
         ], NGUON),
        ("p", "Mô hình quan hệ thu được gồm 13 bảng nghiệp vụ. Ngoài ra, tám bảng có lớp cha BaseEntity được bổ sung hai cột "
              "created_at và updated_at do Spring Data tự điền. Chín thực thể được đánh dấu @Audited (users, categories, "
              "transactions, receipts, budgets, saving_goals, notifications, payment_orders, subscription_plans); Hibernate "
              "Envers sinh cho mỗi thực thể một bảng lịch sử có hậu tố _aud cùng một bảng revision ghi người sửa. Các bảng lịch "
              "sử này là phần kỹ thuật, không được vẽ trong ERD. Lược đồ được Hibernate tạo và cập nhật tự động (ddl-auto = "
              "update); những thay đổi Hibernate không tự làm được, như chuyển dữ liệu cũ của hóa đơn sang bảng lượt đọc, được "
              "viết thành tệp SQL trong core-backend/src/main/resources/db."),
    ],
    # ============================================================ 3.3.2
    "Sơ đồ thực thể kết hợp": [
        ("p", "Sơ đồ thực thể kết hợp (ERD) do Chen đề xuất biểu diễn các thực thể, thuộc tính và mối kết hợp giữa chúng [51]. "
              "Nhóm vẽ ERD ở mức vật lý với ký hiệu chân chim: mỗi khối là một bảng, dấu chấm đánh dấu cột NOT NULL, «PK», «FK», "
              "«UQ» lần lượt là khóa chính, khóa ngoại và cột duy nhất. Tương tự sơ đồ lớp ở Chương 2, ERD được tách làm hai "
              "hình. Hình 3.3 gồm tám bảng của nghiệp vụ tài chính."),
        ("fig", "Sơ đồ thực thể kết hợp – nhóm bảng nghiệp vụ tài chính", "3", PNG + "ch3_erd_tai_chinh.png", 15.0, SRC, None),
        ("p", "Bảng users là trung tâm: một người dùng có không hoặc nhiều giao dịch, ngân sách, mục tiêu tiết kiệm và thông "
              "báo. Mỗi giao dịch thuộc đúng một danh mục; một ngân sách có thể không thuộc danh mục nào. Giữa transactions và "
              "receipts là quan hệ một – một không bắt buộc, cài đặt bằng khóa ngoại receipt_id duy nhất. Mỗi hóa đơn có không "
              "hoặc nhiều lượt đọc trong receipt_processing_attempts. Hình 3.4 gồm sáu bảng phục vụ thanh toán, quản trị và "
              "bảo mật."),
        ("fig", "Sơ đồ thực thể kết hợp – nhóm bảng thanh toán, quản trị và bảo mật", "3", PNG + "ch3_erd_he_thong.png", 15.0, SRC, None),
        ("p", "Trong Hình 3.4, đường liền thể hiện khóa ngoại thật (app_reviews.user_id). Hai đường nét đứt nối users với "
              "payment_orders và action_logs là liên kết logic: hai bảng này có cột user_id nhưng CSDL không ràng buộc khóa "
              "ngoại, như đã giải thích ở Bảng 3.3. subscription_plans và revoked_tokens không liên kết với bảng nào."),
    ],
    # ============================================================ 3.3.3
    "Mô tả các bảng dữ liệu": [
        ("p", "Các bảng 3.4 đến 3.16 mô tả từng bảng dữ liệu. Kiểu dữ liệu là kiểu PostgreSQL mà Hibernate sinh từ kiểu Java "
              "của thuộc tính: Long thành bigint, String thành varchar(255) nếu không khai báo độ dài, BigDecimal thành "
              "numeric(38,2) nếu không khai báo độ chính xác, LocalDateTime thành timestamp. Cột «chỉ đọc» là cột ứng dụng chỉ "
              "đọc, không bao giờ ghi (insertable = false, updatable = false)."),
        ("p", "Bảng users (Bảng 3.4) lưu tài khoản của cả người dùng và quản trị viên. Số dư ví nằm ngay trên dòng người dùng "
              "để mỗi giao dịch chỉ cần khóa một dòng khi cập nhật."),
        tbl("Mô tả bảng users", T_USERS),
        ("p", "Bảng categories (Bảng 3.5) lưu danh mục thu chi dùng chung; Web Admin quản lý danh sách này."),
        tbl("Mô tả bảng categories", T_CATEGORIES),
        ("p", "Bảng transactions (Bảng 3.6) lưu mọi khoản thu và chi. Cột category_name giữ tên danh mục tại thời điểm ghi để "
              "hiển thị nhanh, còn category_id là liên kết chính thức."),
        tbl("Mô tả bảng transactions", T_TRANSACTIONS),
        ("p", "Bảng receipts (Bảng 3.7) lưu kết quả cuối cùng của một hóa đơn sau khi người dùng đối soát. Trạng thái "
              "PROCESSING có trong danh sách nhưng hiện chưa có luồng nào chuyển tới, vì ứng dụng gọi AI trước khi tạo hóa đơn."),
        tbl("Mô tả bảng receipts", T_RECEIPTS),
        ("p", "Bảng receipt_processing_attempts (Bảng 3.8) lưu nguyên văn câu trả lời của AI cho từng lượt đọc. Lượt đọc có "
              "trạng thái LEGACY là dữ liệu chuyển từ các cột cũ transactions.raw_receipt_data và receipts.ai_raw_data."),
        tbl("Mô tả bảng receipt_processing_attempts", T_ATTEMPTS),
        ("p", "Bảng budgets (Bảng 3.9) lưu hạn mức chi theo tuần hoặc tháng."),
        tbl("Mô tả bảng budgets", T_BUDGETS),
        ("p", "Bảng saving_goals (Bảng 3.10) lưu mục tiêu tiết kiệm; các số tiền ở đây do người dùng tự theo dõi, không làm "
              "thay đổi số dư ví."),
        tbl("Mô tả bảng saving_goals", T_SAVINGS),
        ("p", "Bảng notifications (Bảng 3.11) có hai chỉ mục (user_id, created_at, id) và (user_id, is_read, created_at, id) "
              "phục vụ màn hình danh sách thông báo và bộ đếm chưa đọc."),
        tbl("Mô tả bảng notifications", T_NOTIFICATIONS),
        ("p", "Bảng payment_orders (Bảng 3.12) lưu lệnh nạp, rút tiền qua cổng thanh toán; ở phiên bản hiện tại, cổng thanh toán "
              "là cổng giả lập /mock-gateway do Core Backend cung cấp."),
        tbl("Mô tả bảng payment_orders", T_PAYMENTS),
        ("p", "Bảng subscription_plans (Bảng 3.13) lưu các gói dịch vụ do quản trị viên định nghĩa."),
        tbl("Mô tả bảng subscription_plans", T_PLANS),
        ("p", "Bảng app_reviews (Bảng 3.14) lưu đánh giá ứng dụng chờ quản trị viên duyệt."),
        tbl("Mô tả bảng app_reviews", T_REVIEWS),
        ("p", "Bảng action_logs (Bảng 3.15) là nhật ký kiểm toán chỉ thêm (@Immutable), có năm chỉ mục theo thời gian, hành "
              "động, người dùng, email và đối tượng để Web Admin lọc nhanh."),
        tbl("Mô tả bảng action_logs", T_LOGS),
        ("p", "Bảng revoked_tokens (Bảng 3.16) là danh sách đen JWT đã thu hồi, trình bày ở mục 3.5.2."),
        tbl("Mô tả bảng revoked_tokens", T_REVOKED),
    ],
    # ============================================================ 3.3.4
    "Đặc tả ràng buộc toàn vẹn": [
        ("p", "Ràng buộc toàn vẹn (RBTV) là điều kiện mà dữ liệu phải thỏa ở mọi thời điểm. Mỗi RBTV dưới đây được mô tả bằng "
              "bối cảnh (các bảng liên quan), nội dung, tầm ảnh hưởng và nơi kiểm tra. Trong cột tầm ảnh hưởng, T, X, S lần lượt "
              "là thao tác thêm, xóa, sửa; dấu (+) nghĩa là thao tác đó có thể vi phạm ràng buộc và phải kiểm tra. Cột nơi kiểm "
              "tra ghi rõ ràng buộc được bảo đảm ở CSDL (CHECK, UNIQUE, khóa ngoại) hay ở tầng ứng dụng (Bean Validation trên "
              "DTO, phương thức của thực thể hoặc service). Nhóm chỉ liệt kê những ràng buộc có trong mã nguồn hoặc lược đồ."),
        ("p", "Ràng buộc miền giá trị giới hạn giá trị của một thuộc tính (Bảng 3.17). Với các cột kiểu liệt kê được ánh xạ "
              "bằng @Enumerated(EnumType.STRING), Hibernate sinh ràng buộc CHECK liệt kê các giá trị hợp lệ khi tạo bảng."),
        ("table", "Ràng buộc miền giá trị", "3", W_RB, H_RB, RB_MIEN, NGUON),
        ("p", "Ràng buộc liên thuộc tính liên hệ giữa các thuộc tính của cùng một bộ (Bảng 3.18)."),
        ("table", "Ràng buộc liên thuộc tính", "3", W_RB, H_RB, RB_LIEN_TT, NGUON),
        ("p", "Ràng buộc liên bộ và liên quan hệ liên hệ giữa nhiều bộ của một bảng hoặc giữa nhiều bảng (Bảng 3.19). Quan "
              "trọng nhất là LB1 và LB2 về số dư ví: số dư được lưu thay vì tính lại, nên mọi đường ghi giao dịch đều phải cập "
              "nhật nó trong cùng một giao dịch CSDL."),
        ("table", "Ràng buộc liên bộ và liên quan hệ", "3", W_RB, H_RB, RB_LIEN_BO, NGUON),
        ("p", "Ràng buộc duy nhất được cài đặt bằng chỉ mục UNIQUE của PostgreSQL hoặc MongoDB (Bảng 3.20). Với DN2, "
              "PostgreSQL coi các giá trị NULL là khác nhau nên các giao dịch không gửi client_id không bị ràng buộc này chặn. "
              "Cũng vì lý do đó, DN4 dùng category_key (bằng 0 khi không có danh mục) thay cho category_id có thể NULL."),
        ("table", "Ràng buộc duy nhất", "3", W_RB, H_RB, RB_DUY_NHAT, NGUON),
        ("p", "Một số ràng buộc hiện chỉ được bảo đảm ở tầng ứng dụng, chưa có ràng buộc tương ứng ở CSDL: amount > 0 của "
              "giao dịch, rating từ 1 đến 5, các trạng thái của receipts (cột chuỗi, không phải enum). Ngoài ra, LB2 chỉ kiểm "
              "tra khi thêm và sửa; khi xóa một khoản thu, số dư được trừ lại mà không kiểm tra, nên về nguyên tắc vẫn có thể "
              "âm. Đây là các điểm nhóm ghi nhận để hoàn thiện ở phiên bản sau."),
    ],
    # ============================================================ 3.4.1
    "Lưu trữ nhật ký AI trên MongoDB": [
        ("p", "PostgreSQL là nguồn dữ liệu gốc của toàn bộ vòng đời hóa đơn: trạng thái nằm ở receipts, mọi câu trả lời của "
              "AI nằm ở receipt_processing_attempts, và mọi quyết định nghiệp vụ (đối soát, đọc lại, duyệt) chỉ đọc từ hai bảng "
              "này. MongoDB đóng vai trò kho nhật ký phụ: lưu câu trả lời của AI dưới dạng document BSON để quản trị viên tra cứu "
              "và để nhóm phân tích chất lượng mô hình mà không phải truy vấn chuỗi JSON trong cột text [37]. Bảng 3.21 mô tả "
              "hai collection trong CSDL finance_nosql."),
        ("table", "Các collection trong MongoDB", "3", [1600, 3000, 2104, 1800],
         ["Collection", "Trường", "Chỉ mục", "Nguồn ghi"], [
             ["ocr_logs (OcrRawLog)", "_id, transactionId, rawJsonData (document), averageConfidenceScore, createdAt",
              "transactionId duy nhất; averageConfidenceScore; createdAt; (averageConfidenceScore, createdAt giảm dần)",
              "OcrMongoService sau khi giao dịch có hóa đơn được commit"],
             ["ocr_feedbacks (OcrFeedback)", "_id, receiptId, userId, fieldError, expectedValue, aiValue, isResolved, reportedAt",
              "receiptId; userId; isResolved; reportedAt; (isResolved, reportedAt giảm dần)",
              "Bộ dữ liệu demo (MongoDataSeeder)"],
         ], NGUON),
        ("p", "Việc ghi vào ocr_logs được thiết kế để không ảnh hưởng tới giao dịch chính. Khi lưu một giao dịch kèm hóa đơn, "
              "ReceiptProcessingService phát sự kiện OcrProcessedEvent. OcrMongoService nhận sự kiện bằng "
              "@TransactionalEventListener ở pha AFTER_COMMIT và chạy bất đồng bộ trên luồng mongoAsyncExecutor, nên document "
              "chỉ được ghi khi dữ liệu trong PostgreSQL đã chắc chắn tồn tại, và yêu cầu của người dùng không phải chờ "
              "MongoDB. Nếu chuỗi trả về không phải JSON hợp lệ, nó được bọc vào trường unparsed_raw_string; nếu MongoDB lỗi, "
              "service chỉ ghi log lỗi chứ không ném ngoại lệ. Vì vậy, mất một document trong ocr_logs không làm mất dữ liệu "
              "nghiệp vụ: bản gốc vẫn nằm trong receipt_processing_attempts. Quản trị viên xem ocr_logs qua API "
              "GET /api/admin/ocr-logs."),
        ("p", "Collection ocr_feedbacks được thiết kế để lưu phản hồi về từng trường AI đọc sai. Ở phiên bản hiện tại, phản "
              "hồi của người dùng về một hóa đơn thất bại (POST /api/receipts/feedback/{receiptId}) được ghi vào PostgreSQL và "
              "chuyển hóa đơn sang WAITING_FOR_REVIEW; collection này mới chỉ chứa dữ liệu do bộ sinh dữ liệu demo tạo."),
    ],
    # ============================================================ 3.4.2
    "Thiết kế bộ nhớ đệm Redis": [
        ("p", "Redis là kho dữ liệu khóa – giá trị nằm trong bộ nhớ, thường dùng làm bộ nhớ đệm nhờ độ trễ thấp và hỗ trợ "
              "thời gian sống (TTL) cho từng khóa [36]. Core Backend dùng Redis cho hai việc: đệm kết quả các truy vấn thống kê "
              "tốn kém theo mô hình cache-aside qua Spring Cache [31], và lưu mã OTP đặt lại mật khẩu. Bảng 3.22 liệt kê các "
              "loại khóa."),
        ("table", "Các loại khóa trong Redis", "3", [2400, 2604, 1300, 2200],
         ["Cache / khóa", "Giá trị và tham số khóa", "TTL mặc định", "Bị xóa khi"], [
             ["user-dashboard", "Số liệu tổng quan của một người dùng; khóa = userId", "45 giây", "Giao dịch, hóa đơn của người đó thay đổi"],
             ["user-popular-vendors", "Cửa hàng chi nhiều nhất của một người dùng; khóa = userId", "60 giây", "Tổng tiền hoặc nội dung hóa đơn thay đổi"],
             ["admin-dashboard-summary", "Tổng quan toàn hệ thống; khóa = tháng:ngưỡng số dư thấp", "45 giây", "Giao dịch, hóa đơn, tài khoản thay đổi"],
             ["admin-top-spenders", "Người chi nhiều nhất; khóa = trang:số dòng", "60 giây", "Tổng tiền hoặc hồ sơ thay đổi, xóa tài khoản"],
             ["admin-statistics", "Số giao dịch theo tháng; khóa = monthly-transactions:tháng cuối:số tháng", "60 giây", "Tổng tiền thay đổi, xóa tài khoản"],
             ["ledgermind:password-reset-otp:<email>", "Hash gồm code, expiresAt, failedAttempts", "5 phút", "Đặt lại thành công, nhập sai 3 lần, hoặc hết hạn"],
         ], NGUON),
        ("p", "Khóa của các cache thống kê có dạng <tiền tố>:v1:<tên cache>:<tham số>, trong đó tiền tố mặc định là "
              "ledgermind:<profile đang chạy> và v1 là phiên bản cấu trúc dữ liệu; khi đổi cấu trúc DTO chỉ cần tăng phiên bản "
              "để bỏ qua toàn bộ khóa cũ. Giá trị được lưu dưới dạng JSON thuần, đọc lại bằng bộ chuyển đổi gắn với đúng kiểu "
              "DTO của cache, không dùng tuần tự hóa Java. TTL được cấu hình trong redis-cache.properties và bị trừ ngẫu nhiên "
              "tối đa 10% để các khóa không hết hạn cùng lúc."),
        ("p", "Điểm quan trọng nhất của thiết kế là thời điểm xóa cache. Các service không xóa cache trực tiếp mà phát sự "
              "kiện StatisticsChangedEvent kèm loại thay đổi (TRANSACTION_TOTALS, RECEIPT_STATUS, ACCOUNT_CREATED…) và mã "
              "người dùng. StatisticsCacheEvictor nhận sự kiện ở pha AFTER_COMMIT: nó xóa các khóa của đúng người dùng đó trong "
              "các cache người dùng, và xóa toàn bộ các cache quản trị bị ảnh hưởng. Nếu xóa ngay trong giao dịch, một yêu cầu "
              "đọc chen vào trước khi commit có thể nạp lại số liệu cũ vào cache; xóa sau commit tránh được trường hợp này, và "
              "nếu giao dịch bị hủy thì cache không bị xóa vô ích."),
        ("p", "Redis được coi là thành phần có thể hỏng mà hệ thống vẫn chạy. Client Lettuce từ chối lệnh ngay khi mất kết "
              "nối, thời gian chờ lệnh là 500 ms; FallbackCacheErrorHandler biến lỗi đọc cache thành truy vấn thẳng vào "
              "PostgreSQL, còn lỗi xóa chỉ được ghi log và khóa sẽ tự hết hạn theo TTL. Riêng kho OTP không có đường dự phòng: "
              "khi Redis lỗi, yêu cầu quên mật khẩu nhận mã 503. Việc lưu và kiểm tra OTP chạy bằng script Lua để kiểm tra mã, "
              "hạn dùng và đếm số lần sai trong một thao tác nguyên tử. Hạn chế đã biết là mô hình cache-aside không có khóa "
              "phân tán, nên vài yêu cầu đồng thời khi cache trống có thể cùng tính lại một số liệu."),
    ],
    # ============================================================ 3.5.1
    "Danh sách API RESTful": [
        ("p", "REST là kiểu kiến trúc trong đó tài nguyên được định danh bằng URI và được thao tác qua các phương thức chuẩn của "
              "HTTP, mỗi yêu cầu mang đủ thông tin để máy chủ xử lý mà không cần lưu phiên [29]. API của Core Backend theo các "
              "quy ước: tiền tố /api/<tài nguyên>; GET để đọc, POST để tạo, PUT hoặc PATCH để sửa, DELETE để xóa; dữ liệu của "
              "chính người gọi nằm ở đường dẫn /mine hoặc được lọc theo người dùng trong JWT, không bao giờ theo userId gửi "
              "lên. Mọi phản hồi dùng chung cấu trúc ApiResponse gồm code (trùng mã trạng thái HTTP), message (tiếng Việt) và "
              "data. Dữ liệu vào được kiểm tra bằng Bean Validation; lỗi được GlobalExceptionHandler chuyển thành mã 400, 401, "
              "403, 404, 409 hoặc 503 tùy loại."),
        ("p", "Bảng 3.23 liệt kê 49 endpoint REST dưới /api trên 15 lớp @RestController. Ngoài ra, MockGatewayController cung "
              "cấp hai trang /mock-gateway/pay và /mock-gateway/confirm giả lập cổng thanh toán, và AdminController phục vụ 29 "
              "đường dẫn /admin cho Web Admin (trang Thymeleaf và yêu cầu AJAX), được trình bày cùng thiết kế giao diện ở mục 3.6."),
        ("table", "Danh sách API RESTful của Core Backend", "3", [1300, 3504, 2500, 1200],
         ["Nhóm", "Phương thức và đường dẫn", "Chức năng", "Quyền"], API, NGUON),
        ("p", "Ở môi trường phát triển (profile dev), tài liệu OpenAPI và giao diện Swagger UI được sinh tự động từ các "
              "controller; ở môi trường thật, hai đường dẫn này bị tắt."),
    ],
    # ============================================================ 3.5.2
    "Xác thực và phân quyền bằng JWT": [
        ("p", "JSON Web Token (JWT) là chuỗi gồm phần đầu, phần nội dung (các claim) và chữ ký, cho phép máy chủ kiểm tra tính "
              "toàn vẹn của thông tin mà không cần lưu phiên [28]. Core Backend dùng Spring Security [32] với hai chuỗi bộ lọc. "
              "Chuỗi thứ nhất áp cho /admin/** và dùng phiên đăng nhập bằng biểu mẫu, chỉ cho vai trò ROLE_ADMIN. Chuỗi thứ hai "
              "áp cho /api/**, không lưu phiên (STATELESS), tắt CSRF và xác thực bằng JWT trong tiêu đề Authorization: Bearer. "
              "Trong chuỗi này, /api/auth/** (trừ change-password và logout), /api/payment/webhook và /api/categories là công "
              "khai, /api/admin/** cần ROLE_ADMIN, còn lại chỉ cần đăng nhập. Mật khẩu được băm bằng BCrypt; đăng nhập sai 5 "
              "lần liên tiếp bị khóa 15 phút."),
        ("p", "Hệ thống phát hai loại token, cùng ký bằng HMAC-SHA256 (HS256) với khóa JWT_SECRET. Access token sống 15 phút "
              "và là loại duy nhất mở được API; refresh token sống 30 ngày và chỉ dùng tại /api/auth/refresh. Loại token được "
              "ghi ở trường typ của phần đầu JOSE (ACCESS hoặc REFRESH), nên mỗi bên từ chối loại còn lại và từ chối token "
              "không có typ. Ngoài subject (tên người dùng), token mang claim credentialsVersion bằng giá trị cột "
              "users.credentials_version lúc phát hành. Bảng 3.24 trình bày các bước JwtAuthFilter kiểm tra một access token."),
        ("table", "Các bước kiểm tra access token trong JwtAuthFilter", "3", [700, 4304, 3500],
         ["Bước", "Kiểm tra", "Kết quả khi không đạt"], [
             ["1", "Chữ ký hợp lệ, token chưa hết hạn, typ = ACCESS, có subject và credentialsVersion", "401 (EXPIRED hoặc INVALID)"],
             ["2", "Giá trị băm SHA-256 của token không có trong bảng revoked_tokens", "401 (REVOKED), ghi nhật ký"],
             ["3", "credentialsVersion trong token bằng users.credentials_version hiện tại", "401 (OUTDATED), ghi nhật ký"],
             ["4", "Tài khoản không bị khóa (role khác ROLE_LOCKED, active = true)", "403 (ACCOUNT_LOCKED), ghi nhật ký"],
             ["5", "Đặt người dùng và vai trò vào SecurityContext; cập nhật last_action_time (cách quãng vài phút, không phải mỗi yêu cầu)", "–"],
         ], NGUON),
        ("p", "Bộ lọc không tự trả lời lỗi mà chỉ ghi lý do vào thuộc tính của yêu cầu; JsonAuthenticationEntryPoint đọc lý do "
              "đó và trả về ApiResponse với mã 401 hoặc 403 tương ứng. Nhờ vậy, một token hỏng gửi tới endpoint công khai vẫn "
              "được phục vụ như yêu cầu ẩn danh."),
        ("p", "Ba cơ chế thu hồi bổ sung cho nhau. Khi đăng xuất, access token đang dùng và refresh token gửi kèm được đưa vào "
              "revoked_tokens; bảng chỉ lưu giá trị băm và thời điểm hết hạn, và một tác vụ định kỳ lúc 03:30 hằng ngày xóa các "
              "dòng đã hết hạn. Khi làm mới, refresh token cũ bị thu hồi trong cùng giao dịch cấp cặp token mới (xoay vòng), "
              "sau khi khóa dòng người dùng, nên một refresh token chỉ dùng được một lần. Khi đổi hoặc đặt lại mật khẩu, mật "
              "khẩu mới và credentials_version tăng thêm 1 được ghi bằng một câu UPDATE duy nhất; mọi token đã phát trước đó, "
              "trên mọi thiết bị, lập tức bị từ chối ở bước 3 mà không phải liệt kê từng token. Thông tin người dùng hiện tại "
              "luôn được CurrentUserProvider lấy từ SecurityContext, không lấy từ tham số do ứng dụng gửi lên."),
    ],
}

ABBREVIATIONS = [
    ("AWS", "Amazon Web Services", "Dịch vụ điện toán đám mây của Amazon"),
    ("EC2", "Elastic Compute Cloud", "Dịch vụ máy ảo của AWS"),
    ("FK", "Foreign Key", "Khóa ngoại"),
    ("HMAC", "Hash-based Message Authentication Code", "Mã xác thực thông điệp dựa trên hàm băm"),
    ("HTTPS", "Hypertext Transfer Protocol Secure", "Giao thức HTTP bảo mật"),
    ("JDBC", "Java Database Connectivity", "Giao diện kết nối CSDL của Java"),
    ("LRU", "Least Recently Used", "Loại bỏ mục ít được dùng gần đây nhất"),
    ("PK", "Primary Key", "Khóa chính"),
    ("SHA", "Secure Hash Algorithm", "Thuật toán băm an toàn"),
    ("SMTP", "Simple Mail Transfer Protocol", "Giao thức gửi thư điện tử"),
    ("TTL", "Time To Live", "Thời gian sống của khóa"),
    ("UQ", "Unique", "Ràng buộc duy nhất"),
]
