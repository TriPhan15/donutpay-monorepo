# Nội dung phiên K4 (01/11/2026): rà soát văn bản Chương 4 (Cài đặt hệ thống) theo loi_phan_D.md.
# Sinh KhoaLuan_KLCN175_v14.docx từ v13 bằng builder.py. Chỉ sửa chính tả, dấu câu, câu văn, số liệu kiểm thử và các câu đã
# kiểm tra lại với mã nguồn; không thêm hoặc bớt mục, hình, bảng (chỉ tách đoạn, đổi chuỗi liệt kê thành gạch đầu dòng, thêm
# dòng Tổng vào Bảng 4.10). Các ghi chú [Nhóm] giữ nguyên. Thuật ngữ và dấu câu toàn quyển (tỉ/tỷ, module/mô-đun,
# cache/bộ nhớ đệm, "nguồn:", dấu ";" còn lại, dạng 0,xxxx hay %) để K5; mô tả code đã lệch sau 26/10 để K6.
#
# Số liệu kiểm thử:
#   - AI Service: 305 passed, 8 skipped (pytest, main, 31/10/2026, theo README mục 8).
#   - Số hàm từng tệp (Bảng 4.10): `git grep -c 'def test_' origin/main -- 'ai-service/test_*.py'`, đếm 01/11/2026 trên
#     origin/main (62b8861): 20, 18, 10, 11, 7, 17, 12, 31, 19, tổng 145 hàm.
#   - test_receipt_postprocess.py: 19 hàm; 74 trường hợp = tổng số phần tử của các @pytest.mark.parametrize (đếm bằng ast).
#   - Version5/tests: 64 hàm trong 12 tệp (`grep -c 'def test_' ai-service/Version5/tests/test_*.py`, 01/11/2026).
# Thời gian huấn luyện: 5.600 bước x 10,0-11,3 giây = 15,6-17,6 giờ; phiên cuối 18.010 giây = 5,0 giờ (v5_results.md).
SESSION_TAG = None
SECTIONS = {}

NBSP = " "

PARA_REPLACE = [
    # ---- 4.1 (#1) ----
    ("Chương 3 đã chốt kiến trúc",
     ("p", "Chương 3 đã chốt kiến trúc, cơ sở dữ liệu, API và mô hình AI ở mức thiết kế. Chương này trình bày cách nhóm hiện thực "
           "các thiết kế đó. Mục 4.2 nêu môi trường và công cụ phát triển. Mục 4.3 mô tả việc thu thập và gán nhãn lại tập ảnh hóa "
           "đơn, còn mục 4.4 là cấu hình huấn luyện DONUT V5 trên Kaggle. Các mục 4.5 đến 4.8 lần lượt trình bày phần cài đặt AI "
           "Service, Core Backend, ứng dụng di động và Web Admin, và mục 4.9 nói về việc đóng gói toàn bộ hệ thống bằng Docker. Số "
           "liệu trong chương được lấy từ mã nguồn, tệp nhãn và nhật ký huấn luyện của nhóm. Phần đánh giá mô hình trên tập kiểm "
           "thử được trình bày ở Chương 5.")),
    # ---- 4.3.2 (#15, #16): bốn quy tắc của lời nhắc thành gạch đầu dòng ----
    ("Bước đọc ảnh dùng hai mô hình thị giác",
     ("p", "Bước đọc ảnh dùng hai mô hình thị giác – ngôn ngữ (VLM, Vision-Language Model) làm hai “ý kiến” độc lập. Mô hình thứ "
           "nhất là Qwen2.5-VL-7B-Instruct [61], chạy offline trên GPU Kaggle bằng thư viện transformers (relabel_qwen.py). Mô "
           "hình này đã đọc hết tập test, validation và một phần tập train. Mô hình thứ hai là Claude của Anthropic [62], đọc ảnh "
           "theo từng lô và ghi kết quả vào các tệp relabel_cache/<split>.claude*.jsonl. Cả hai nhận cùng một lời nhắc (prompt) do "
           "relabel_common.build_prompt() tạo ra, gồm bốn quy tắc:")),
    # ---- 4.3.3 (#22): tách cách chia tập và rủi ro V3 đã thấy ảnh test ----
    ("Cách chia train/validation/test giữ nguyên",
     ("p", "Cách chia train/validation/test giữ nguyên ba thư mục của data1 để có thể so sánh công bằng với V3 trên cùng một tập "
           "test. Tập validation 635 ảnh chỉ dùng để chọn checkpoint. Vì mỗi lần đánh giá phải cho mô hình sinh chuỗi thật, "
           "train_model.py lấy ngẫu nhiên 150 ảnh validation với seed 42 (hàm val_subset) để giới hạn thời gian. Tập test 636 ảnh "
           "không tham gia huấn luyện hay chọn mô hình.")),
    # ---- 4.3.3 (#24): các phép tăng cường ảnh (xác suất theo build_augment, Version5/model_config.py dòng 175-186) ----
    ("Ảnh train được tăng cường ngẫu nhiên",
     ("p", "Ảnh train được tăng cường ngẫu nhiên bằng thư viện Albumentations [63] (hàm build_augment) với các phép sau:")),
    # ---- 4.4.2 (#28, #29, #30): tách bước mở rộng từ vựng và bước thêm thẻ ----
    # Version5/model_config.py dòng 15-17, 49-53 (TASK_TOKEN <s_seller> cùng 4 cặp thẻ trường = 10 thẻ), dòng 126-131
    ("Mô hình gốc là naver-clova-ix",
     ("p", "Mô hình gốc là naver-clova-ix/donut-base-finetuned-cord-v2 [5], [40], gồm bộ mã hóa Swin Transformer [8] và bộ giải "
           "mã kiểu BART [9] bốn lớp. Trước khi huấn luyện, hàm setup_model_and_processor() mở rộng tokenizer theo thiết kế ở mục "
           "3.9.1. Đầu tiên, hàm tìm các ký tự trong nhãn train không có piece riêng trong từ vựng Unigram của SentencePiece [12] "
           "và thêm 65 ký tự tiếng Việt thẳng vào từ vựng. Các ký tự này không được thêm dưới dạng added token, để tránh lỗi tách "
           "“Dươ ng” của V3.")),
    # ---- 4.4.4 (#36, #37): EarlyStoppingCallback, patience = 4 (train_model.py dòng 23, 156) ----
    ("Hình 4.3 và Bảng 4.5 trình bày",
     ("p", "Hình 4.3 và Bảng 4.5 trình bày field_exact trên 150 ảnh validation sau mỗi 400 bước. Độ đo tăng nhanh từ 0,7480 ở bước "
           "400 lên 0,9055 ở bước 800, rồi tăng chậm và đạt cao nhất 0,9350 ở bước 3200 (epoch 3,83). Sau đó field_exact dao động "
           "trong khoảng 0,92–0,93 mà không vượt được giá trị này. Phiên cuối chạy tiếp từ checkpoint-4000 và bộ đếm của "
           "EarlyStoppingCallback tính lại từ đầu, nên bốn lần đánh giá liên tiếp không cải thiện là các bước 4400, 4800, 5200 và "
           "5600. Huấn luyện dừng ở bước 5600 (epoch 6,71) thay vì chạy đủ 6.680 bước. Nhờ load_best_model_at_end, mô hình được lưu "
           "vào donut_result là checkpoint ở bước 3200.")),
    # ---- 4.5.1 (#43, #44): các bước xử lý của /donut/scan thành danh sách; khóa theo Bảng 3.29 ----
    ("Endpoint /donut/scan đọc tệp ảnh",
     ("p", "Endpoint /donut/scan xử lý một hóa đơn qua các bước sau:")),
    # ---- 4.6.1 (#71, #72): P1183 gốc có chữ đậm sai (builder cũ hiểu "/admin/**" là đánh dấu đậm); viết lại không dùng ký tự * ----
    ("SecurityConfig khai báo hai chuỗi",
     ("p", "SecurityConfig khai báo hai chuỗi bộ lọc của Spring Security [32]. Chuỗi thứ nhất (@Order(1)) phục vụ các đường dẫn dưới "
           "/admin/ bằng form đăng nhập và phiên làm việc cho Web Admin. Chuỗi thứ hai (@Order(2)) phục vụ các đường dẫn dưới /api/ "
           "ở chế độ STATELESS: JwtAuthFilter đọc token Bearer, JwtUtil kiểm tra chữ ký, hạn dùng, loại token trong header JOSE typ "
           "(ACCESS hoặc REFRESH) và credentialsVersion [28]. Access token có thời hạn 15 phút, refresh token có thời hạn 30 ngày. "
           "Khi người dùng đổi hoặc đặt lại mật khẩu, credentialsVersion tăng trong cùng một câu lệnh UPDATE với mật khẩu, nên mọi "
           "token cũ bị từ chối. Khi đăng xuất, TokenBlacklistService ghi token vào bảng revoked_tokens. Mã người dùng hiện tại luôn "
           "được lấy từ SecurityContext qua CurrentUserProvider, không bao giờ từ tham số do client gửi.")),
    # ---- 4.6.2 (#78) ----
    ("Mã clientId chỉ chống gửi lặp",
     ("p", "Mã clientId chỉ chống gửi lặp của cùng một lần lưu. Để chặn việc lưu hai lần cùng một tờ hóa đơn, hàm "
           "refuseDuplicateReceipt() chạy trên luồng lưu có rawReceiptData, sau attachReceipt() và khi ví vẫn đang bị khóa. Hàm tìm "
           "giao dịch cùng chiều thu chi, cùng số tiền, cùng phút và cùng người bán đã chuẩn hóa (người bán trống coi như khớp). "
           "Nếu có, DuplicateReceiptException được ném, giao dịch CSDL quay lui và GlobalExceptionHandler trả 409 kèm mã và ngày "
           "của giao dịch đã có. TransactionRequestDto có cờ allowDuplicate để người dùng vẫn lưu khi đó là một lần mua khác.")),
    # ---- 4.6.3 (#79, #82) ----
    ("BudgetPeriodType có thêm hằng YEAR",
     ("p", "BudgetPeriodType gồm các hằng WEEK (7 ngày), MONTH (31 ngày) và YEAR (366 ngày). Hàm allowsRange() so số ngày của khoảng "
           "ngày, tính cả hai đầu, với độ dài tối đa của kỳ.")),
    # ---- 4.7.2 (#79, #94, #95): câu chủ đề hoàn chỉnh thay nhãn rời, thì hiện tại ----
    ("Ghi chép thu chi: AddTransactionPage",
     ("p", "Với chức năng ghi chép thu chi, AddTransactionPage gửi giao dịch mới qua AppRepository.createTransaction(). Hàm này sinh "
           "clientId, ghi bản chờ vào SQLite trước rồi mới gọi API, và trả về một SyncStatus (đã đồng bộ, chưa gửi được hoặc bị từ "
           "chối). Các giao dịch chưa gửi được hiển thị nhãn trạng thái trong LedgerPage và được resendUnsyncedTransactions() gửi "
           "lại khi ứng dụng khởi động, khi quay lại từ nền, hoặc khi người dùng kéo để làm mới. EditTransactionPage chỉ gửi các "
           "trường đã đổi bằng PUT /api/transactions/{id} qua RemoteApiHelper.updateTransaction(), nên chỉ sửa được khi có kết nối "
           "mạng.")),
    ("Ngân sách và biểu đồ: BudgetScreen",
     ("p", "Với ngân sách và biểu đồ, BudgetScreen hiển thị thanh tiến độ và cảnh báo 80%/100%. DashboardPage và AITabPage vẽ biểu đồ "
           "chi tiêu bằng fl_chart. Để hiển thị báo cáo thói quen chi tiêu, ứng dụng gọi /ai/spade/analyze với các khoản chi của 26 "
           "tuần gần nhất. Bộ chọn khoảng thời gian chỉ thay đổi biểu đồ, không thay đổi dữ liệu gửi tới /ai/spade/analyze.")),
    # review_form_page.dart dòng 155-175 và receipt_scan_result.dart dòng 41-43: biểu mẫu đối soát chỉ có ô tên cửa hàng, tổng
    # tiền, ngày giờ (và danh mục); địa chỉ không có ô riêng
    ("Quét hóa đơn: người dùng chụp",
     ("p", "Với chức năng quét hóa đơn, người dùng chụp bằng trình quét tài liệu của Google ML Kit [59] (tự cắt viền, nắn phối cảnh) "
           "hoặc chọn ảnh từ thư viện bằng image_picker. Ảnh được gửi tới /ai/donut/scan, sau đó ReviewFormPage điền sẵn tên cửa "
           "hàng, ngày giờ và tổng tiền để người dùng sửa. Ngày giờ quét được thử đối chiếu với một danh sách định dạng. Nếu không "
           "khớp, ứng dụng lấy thời điểm hiện tại và hiện ghi chú nhắc người dùng kiểm tra. Ảnh chỉ được tải lên Cloudinary khi "
           "người dùng bấm lưu. Nếu tải ảnh thất bại, ứng dụng hỏi có lưu giao dịch không kèm ảnh hay không. Giao dịch từ hóa đơn "
           "đi qua cùng đường lưu có clientId và hàng đợi như giao dịch nhập tay.")),
    # receipt_scan_queue.dart dòng 91 (maxBatch = 20) và 142-151 (đủ 20 mục queued + reading thì không nhận thêm)
    ("Quét nhiều hóa đơn: ReceiptScanQueue",
     ("p", "Với chức năng quét nhiều hóa đơn, ReceiptScanQueue (lib/services/receipt_scan_queue.dart) giữ hàng đợi trong bảng "
           "receipt_scan_queue. Khi nâng lược đồ SQLite từ phiên bản 7 lên 8, nhánh onUpgrade chỉ tạo bảng này và giữ nguyên dữ liệu "
           "các bảng cũ. Hàng đợi nhận tối đa 20 mục đang chờ hoặc đang đọc (ReceiptScanQueue.maxBatch). Ảnh từ trình quét hoặc thư "
           "viện nằm trong thư mục tạm mà hệ điều hành có thể dọn, nên enqueue() chép từng ảnh vào thư mục receipt_queue trong thư "
           "mục tài liệu của ứng dụng, đặt tên bằng UUID. Mọi truy vấn của hàng đợi đều lọc theo user_id lấy từ "
           "SessionService.currentUserId, nên hai người dùng trên cùng một máy không thấy hàng đợi của nhau. MainScaffold gọi "
           "resume() trong initState để đọc tiếp sau khi ứng dụng mở lại.")),
    ("Biểu mẫu đối soát nhận thêm",
     ("p", "Biểu mẫu đối soát nhận tham số initialScan. Khi mở từ màn hình “Chờ xác nhận”, biểu mẫu điền sẵn bằng kết quả đã lưu "
           "(ReceiptScanResult), không gọi lại /donut/scan. Ảnh hóa đơn mở được ở chế độ xem toàn màn hình "
           "(ReceiptImageViewerPage), và chế độ đối chiếu đặt ảnh cạnh bốn trường để sửa. Khi checkout trả 409, AppRepository ném "
           "DuplicateReceiptException. Khi đó biểu mẫu hiện hộp thoại AppDialog với hai lựa chọn và gửi lại bằng allowDuplicate = "
           "true nếu người dùng chọn “Vẫn lưu”.")),
    ("Thành phần giao diện dùng chung: AppToast",
     ("p", "Các thành phần giao diện dùng chung gồm AppToast, MoneyInputFormatter và DateField. AppToast "
           "(lib/widgets/feedback/app_toast.dart) hiển thị thông báo ngắn thay cho ScaffoldMessenger. Thông báo trượt xuống ở phía "
           "trên màn hình, có biểu tượng và màu theo ba loại (thành công, lỗi, thông tin) lấy từ ColorScheme, tự tắt sau 3 giây (5 "
           "giây nếu có nút thao tác) và mỗi lúc chỉ hiện một thông báo. MoneyInputFormatter "
           "(lib/core/utils/money_input_formatter.dart) nhóm chữ số theo ngôn ngữ trong lúc gõ và giữ vị trí con trỏ. Hàm parse() "
           "của lớp này là nơi duy nhất chuyển chuỗi nhập thành số tiền, và MoneyInputFormatter được dùng ở các ô tiền của màn hình "
           "thêm và sửa giao dịch, đối soát hóa đơn, ngân sách và tiết kiệm. DateField (lib/widgets/inputs/date_field.dart) là ô "
           "chọn ngày dùng chung cho các biểu mẫu đó.")),
    ("Đăng nhập: “Ghi nhớ",
     ("p", "Ở màn hình đăng nhập, tùy chọn “Ghi nhớ đăng nhập” giữ phiên đăng nhập qua các lần mở ứng dụng và lưu email để điền sẵn "
           "ở màn hình đăng nhập. Khi đăng nhập thành công và tùy chọn được bật, SessionService lưu email vào shared_preferences "
           "(khóa remembered_email). Sau khi đăng xuất, màn hình đăng nhập điền sẵn email này. Nếu bỏ chọn, email đã lưu bị xóa. Ứng "
           "dụng không lưu mật khẩu. Biểu mẫu được bọc trong AutofillGroup với autofillHints cho email và mật khẩu, và gọi "
           "TextInput.finishAutofillContext() khi đăng nhập thành công [75], để trình quản lý mật khẩu của hệ điều hành đề nghị lưu "
           "rồi tự điền ở lần sau.")),
    # session_service.dart: không còn khóa app_pin; arb: linkedDemoBadge = "Bản demo"
    ("Dọn chức năng:",
     ("p", "Mục “Tạo / Đổi mã PIN” trong Hồ sơ đã được gỡ cùng các khóa ARB có tiền tố pin và chỗ ghi app_pin, vì mã PIN từng được ghi "
           "vào shared_preferences dưới dạng văn bản thuần (không mã hóa) mà không nơi nào đọc lại để khóa ứng dụng. Màn hình Dịch "
           "vụ liên kết được giữ lại nhưng dùng dữ liệu giả lập, vì vậy tiêu đề và dòng menu của màn hình gắn nhãn DemoBadge “Bản "
           "demo”.")),
    # ---- 4.9 (#118, #119, #120): Dockerfile thành danh sách; tách các chủ đề của Caddy ----
    ("Image của Core Backend được build hai tầng",
     ("p", "Image của Core Backend được build nhiều giai đoạn (multi-stage) với các đặc điểm sau:")),
    ("Caddy [52] là cửa vào duy nhất",
     ("p", "Caddy [52] là cửa vào duy nhất. Đường dẫn /ai/ được bỏ tiền tố rồi chuyển tới AI Service. Trong đó /ai/health công khai, "
           "còn /ai/donut/ và /ai/spade/ phải qua forward_auth: Caddy gọi GET /api/auth/check của Core Backend với header "
           "Authorization của yêu cầu và chỉ chuyển tiếp yêu cầu khi nhận mã 204 (No Content).")),
    # ---- 4.10 (#123): kết chương thành năm gạch đầu dòng ----
    ("Chương 4 đã trình bày phần cài đặt",
     ("p", "Chương 4 đã trình bày phần cài đặt của hệ thống, với các kết quả chính sau:")),
]

# Đoạn và gạch đầu dòng mới: neo theo đầu đoạn gốc đứng ngay trước
INSERT_AFTER = [
    # #15, #16: bốn quy tắc của lời nhắc, ví dụ, kiểm tra Pydantic và bộ đệm kết quả
    ("Bước đọc ảnh dùng hai mô hình thị giác", [
        ("b1", "Chép nguyên văn tên cửa hàng và địa chỉ."),
        ("b1", "Chép ngày giờ đúng như in trên hóa đơn."),
        ("b1", "Chỉ lấy số tiền cuối cùng khách phải trả, với dấu phân cách như in."),
        ("b1", "Để chuỗi rỗng khi hóa đơn không có thông tin, không đoán."),
        ("p", "Lời nhắc kèm bốn ví dụ nhãn đầy đủ lấy từ chính tập dữ liệu. Câu trả lời được kiểm tra bằng mô hình Pydantic "
              "ReceiptFields [60], bắt buộc đủ bốn khóa, nên một câu trả lời sai khóa bị coi là lỗi chứ không bị hiểu thành bốn "
              "trường rỗng."),
        ("p", "Mọi câu trả lời được lưu vào bộ đệm, nên vòng lặp có thể dừng khi hết hạn mức gọi API rồi chạy tiếp ở phiên sau mà "
              "không đọc lại ảnh đã xong."),
    ]),
    # #22, #23: rủi ro V3 đã thấy ảnh test; giải thích Bảng 4.3. Số liệu đếm từ ai-service/Version5/data1/*/metadata.jsonl:
    # train 1.044 dòng / 1.385 trường chưa kiểm tra, nằm trong 2.499 ô trống (749 + 1.104 + 593 + 53); 2.499 - 1.385 = 1.114
    ("Cách chia train/validation/test giữ nguyên", [
        ("p", "Riêng V3 có thể đã gặp một số ảnh test khi huấn luyện, vì nhãn train cũ của V3 khác với bản chia hiện tại. "
              "find_v3_seen.py tìm những ảnh test có địa chỉ (đã chuẩn hóa, dài hơn 15 ký tự) trùng với một địa chỉ trong nhãn train "
              "cũ của V3 và ghi 21 ảnh vào v3_seen_test.txt. Chương 5 báo cáo kết quả cả khi có và khi bỏ 21 ảnh này."),
        ("p", "Bảng 4.3 tóm tắt ba tập. Cột “Dòng có trường chưa kiểm tra” đếm số dòng của metadata.jsonl có unverified_fields khác "
              "rỗng. Ở tập train, 1.044 dòng chứa 1.385 trường như vậy, nằm trong số 2.499 ô trống của Bảng 4.2 (749 + 1.104 + "
              "593 + 53). Còn lại 1.114 ô trống đã được xác nhận là hóa đơn không có thông tin nên vẫn được tính loss."),
    ]),
    # #24
    ("Ảnh train được tăng cường ngẫu nhiên", [
        ("b1", "Xoay tối đa 10 độ với nền trắng."),
        ("b1", "Đổi độ sáng và độ tương phản."),
        ("b1", "Làm mờ Gauss và mờ chuyển động (mô phỏng rung tay khi chụp)."),
        ("b1", "Nén JPEG chất lượng 40–90 (mô phỏng ảnh gửi qua ứng dụng nhắn tin)."),
        ("b1", "Thêm nhiễu Gauss."),
        ("p", "Mỗi phép có xác suất áp dụng từ 0,3 đến 0,5. Ảnh validation và test không bị tăng cường."),
    ]),
    # #28, #29, #30
    ("Mô hình gốc là naver-clova-ix", [
        ("p", "Tiếp theo, hàm thêm 10 thẻ trường làm token đặc biệt: <s_seller> và </s_seller> (token mở đầu và kết thúc chuỗi), cùng "
              "cặp thẻ mở, đóng của bốn trường seller_name, address, timestamp, total_cost. Lớp embedding của bộ giải mã được mở "
              "rộng theo số token mới, và từ vựng sau khi mở rộng có 57.655 token. Hàng của 65 ký tự mới được gán bằng vector trung "
              "bình của từ vựng gốc."),
        ("p", "Sau đó chương trình encode rồi decode lại mọi nhãn train và chỉ cho huấn luyện khi ít nhất 99% nhãn tái tạo đúng. Kết "
              "quả thực tế là 100%. Bảng 4.4 liệt kê các siêu tham số còn lại."),
    ]),
    # #43, #44: ai_service.py dòng 191-203 (raw_text, total_cost_number, normalized); khóa seller.* ở Bảng 3.29
    ("Endpoint /donut/scan đọc tệp ảnh", [
        ("b1", "Đọc tệp ảnh và trả mã 400 nếu tệp rỗng hoặc không mở được."),
        ("b1", "Xoay ảnh theo thẻ EXIF bằng ImageOps.exif_transpose() (ảnh chụp từ camera Android thường bị xoay) và chuyển về RGB."),
        ("b1", "Processor thu ảnh về 1920 × 1440, đúng kích thước khi huấn luyện."),
        ("b1", "Bộ giải mã nhận token mở đầu <s_seller> làm prompt và sinh tham lam (greedy) tối đa 768 token."),
        ("b1", "Bỏ token kết thúc và token đệm khỏi chuỗi kết quả rồi chuyển thành JSON bằng processor.token2json() [40]. Khi chuỗi "
               "không chuyển được sang JSON, dịch vụ giữ chuỗi gốc trong khóa raw_text."),
        ("b1", "Đưa kết quả qua mô-đun hậu xử lý ở mục 4.5.2. Các khóa của Bảng 3.29 được giữ nguyên, trong đó total_cost_number lấy "
               "từ số tiền đã chuẩn hóa. Khóa normalized chứa kết quả chuẩn hóa kèm cờ hợp lệ của từng trường."),
        ("p", "Các tham số đầu vào của /spade/analyze và /spade/recommend được khai báo bằng mô hình Pydantic (SpadeRequest, "
              "RecommendRequest) [60]."),
    ]),
    # #81, #82: tách nguyên nhân, giải pháp và các bước của tệp SQL
    ("BudgetPeriodType có thêm hằng YEAR", [
        ("p", "Cột period_type của budgets và budgets_aud có ràng buộc CHECK do Hibernate sinh khi tạo bảng, và ddl-auto=update không "
              "nới được ràng buộc đã có. Vì vậy nhóm viết tệp core-backend/src/main/resources/db/budget-period-year-migration.sql "
              "để chạy tay bằng psql. Tệp chạy trong một giao dịch và dừng nếu có dòng mang giá trị lạ. Sau đó tệp xóa mọi CHECK cũ "
              "trên cột rồi thêm ràng buộc chấp nhận WEEK, MONTH, YEAR. Tệp có thể chạy lại nhiều lần mà kết quả không đổi "
              "(idempotent)."),
        ("p", "BudgetRequestDto có trường categoryName. CategoryService.resolveOrCreate() là nơi duy nhất tìm danh mục theo tên "
              "(findFirstByNameIgnoreCaseOrderByIdAsc) hoặc tạo mới, dùng chung cho ngân sách và giao dịch."),
    ]),
    # #98, #99: kiểm thử của hàng đợi thành danh sách (8 mục)
    ("Quét nhiều hóa đơn: ReceiptScanQueue", [
        ("p", "Tệp receipt_scan_queue_test.dart kiểm tra các nội dung sau:"),
        ("b1", "Thứ tự đọc từng ảnh."),
        ("b1", "Tiến độ."),
        ("b1", "Lỗi mạng và đọc lại."),
        ("b1", "Khôi phục mục bị bỏ dở."),
        ("b1", "Dừng khi hết phiên."),
        ("b1", "Giới hạn 20 mục."),
        ("b1", "Ảnh bị mất."),
        ("b1", "Nâng cấp từ phiên bản 7."),
    ]),
    # #118: Dockerfile của Core Backend
    ("Image của Core Backend được build hai tầng", [
        ("b1", "Giai đoạn build dùng maven:3.9.6-eclipse-temurin-21 để tải thư viện và đóng gói finance-api.jar."),
        ("b1", "Giai đoạn chạy dùng eclipse-temurin:21-jre-jammy, chỉ chứa JRE."),
        ("b1", "Múi giờ được đặt là Asia/Ho_Chi_Minh."),
        ("b1", "Ứng dụng chạy bằng người dùng không phải root."),
        ("b1", "tini là tiến trình số 1 của container."),
        ("b1", "JVM được giới hạn 75% bộ nhớ của container."),
        ("p", "Image của AI Service dựa trên python:3.10-slim. Tệp .dockerignore loại bỏ ảnh data1, notebook, thư mục Version3 và toàn "
              "bộ Version5 trừ Version5/donut_result, nên image chỉ chứa trọng số V5 đang phục vụ."),
    ]),
    # #119, #120
    ("Caddy [52] là cửa vào duy nhất", [
        ("p", "Các đường dẫn dưới /actuator/ (trừ /actuator/health) trả 404 để không lộ thông tin nội bộ. Mọi đường dẫn còn lại đi "
              "tới Core Backend."),
        ("p", "Mật khẩu CSDL, Redis, MongoDB, JWT_SECRET và khóa thanh toán được nạp từ tệp .env. Cú pháp ${BIẾN:?} làm docker compose "
              "dừng ngay nếu thiếu biến bắt buộc. Mỗi container được giới hạn nhật ký ở 3 tệp, mỗi tệp 10 MB."),
    ]),
    # #123, #125: kết chương
    ("Chương 4 đã trình bày phần cài đặt", [
        ("b1", "Dữ liệu: tập data1 gồm 6.351 ảnh được gán nhãn lại bằng hai mô hình VLM kết hợp người duyệt, nâng số ảnh train có đủ "
               "bốn trường từ 450 lên 3.463. Các ô chưa kiểm tra được che khi tính loss."),
        ("b1", "Mô hình: DONUT V5 được huấn luyện trên Kaggle với ảnh 1920 × 1440, tokenizer mở rộng 65 ký tự tiếng Việt và 10 thẻ "
               "trường (tái tạo đúng 100% nhãn), chọn checkpoint theo độ chính xác đọc thật. Checkpoint tốt nhất đạt field_exact "
               "0,9350 trên validation ở bước 3200."),
        ("b1", "AI Service: dịch vụ phục vụ mô hình qua FastAPI và có mô-đun hậu xử lý Regex cho bốn trường, nâng tỉ lệ trường khớp "
               "hoàn toàn trên tập test từ 89,99% lên 91,01%."),
        ("b1", "Core Backend: hiện thực xác thực JWT có thu hồi token, ghi giao dịch có khóa ví và lũy đẳng theo clientId, cảnh báo "
               "ngân sách chống gửi lặp và cache thống kê trên Redis."),
        ("b1", "Ứng dụng di động, Web Admin và Docker: ứng dụng hỗ trợ ngoại tuyến, song ngữ và giao diện sáng/tối. Web Admin được "
               "sinh giao diện phía máy chủ bằng Thymeleaf. Toàn bộ phía máy chủ được đóng gói thành sáu container sau một reverse "
               "proxy Caddy."),
    ]),
]

# Mục 4.5.3 viết lại trọn vẹn để sửa số trong Bảng 4.10 (builder chỉ thay được chữ trong ô khi chuỗi duy nhất) và thêm dòng Tổng.
# Bảng 4.9 và 4.10 sinh lại bằng chính builder nên giữ nguyên định dạng; ô của Bảng 4.9 chỉ đổi "tỉa" thành "cắt tỉa" (#63).
REPLACE = {
    "Cài đặt phân tích chi tiêu và phân khúc khách hàng": ({("Bảng", "4"): 8}, [
        ("p", "Phần phân tích chi tiêu được tách thành các module nhỏ trong thư mục ai-service để mỗi module có một trách nhiệm và "
              "kiểm thử riêng. Bảng 4.9 liệt kê các module này cùng phần việc của Core Backend trong phân khúc RFM."),
        ("table", "Module của phân tích chi tiêu và phân khúc RFM", "4", [2700, 5804], ["Module", "Trách nhiệm"], [
            ["ai_service.py", "Khai báo SpadeRequest, RecommendRequest, AdminSegmentRequest và ba endpoint /spade/analyze, "
                              "/spade/recommend, /admin/segment; kiểm tra đầu vào bằng Pydantic, mã 422 khi sai"],
            ["spending_data.py", "Lọc khoản chi, chuẩn hóa NFC, bỏ ngày sau ngày mai, cắt cửa sổ 26 tuần ISO, dựng chuỗi tuần và tổng "
                                 "chi theo danh mục"],
            ["local_time.py", "Đổi ngày về múi giờ cố định UTC+7; đầu vào hỏng trả None thay vì ném lỗi"],
            ["wcm_spade.py", "Lớp WCMSpade (id-list, CMAP, trọng số, cắt tỉa, lọc mẫu đóng) và hàm sequential_rules (luật từ id-list "
                             "thô)"],
            ["spending_analysis.py", "Ghép các bước, quyết định status, dựng phản hồi camelCase gồm patterns, rules, habits, "
                                     "categories và meta"],
            ["spending_habits.py", "Thói quen định kỳ: khoảng cách ngày, hệ số biến thiên, ngày kế tiếp"],
            ["budget_advisor.py", "Gợi ý ngân sách theo tháng trọn vẹn, nhóm thiết yếu, tùy ý, trung tính"],
            ["rfm_segmentation.py", "Chấm ngũ phân vị R, F, M và luật bảy nhóm"],
            ["CustomerSegmentationService (Core Backend)", "Tính R, F, M từ PostgreSQL, gọi AI Service, kiểm tra câu trả lời và ghi "
                                                           "nhãn"],
            ["AiSegmentClient (Core Backend)", "Gọi POST /admin/segment với thời gian chờ kết nối 5 giây, đọc 60 giây"],
        ], "nguồn: nhóm thực hiện"),
        # #64, #65, #66: CustomerSegmentationService.java dòng 34 (NO_ACTIVITY_DAYS = 366), dòng 105-110 (validate) và
        # 56-66 (ghi nhãn, xóa nhãn của người dùng đã gửi mà AI không trả về)
        ("p", "Ở Core Backend, phân khúc RFM chạy qua CustomerSegmentationService. Truy vấn SQL lấy các khoản chi trong 12 tháng gần "
              "nhất, bỏ danh mục “Tiết kiệm” và dùng LEFT JOIN nên người chưa có giao dịch vẫn có một dòng. Recency là số ngày từ "
              "lần chi gần nhất đến hiện tại (ngày tương lai được kẹp về hôm nay), hoặc 366 ngày (hằng NO_ACTIVITY_DAYS, không ngắn "
              "hơn cửa sổ 12 tháng) nếu chưa có khoản chi nào. Lời gọi HTTP tới AI Service chạy trước và ngoài mọi giao dịch cơ sở "
              "dữ liệu, nên không giữ kết nối PostgreSQL trong lúc chờ. Câu trả lời bị từ chối nguyên khối, không ghi gì, trong hai "
              "trường hợp:"),
        ("b1", "user_id rỗng, không phải số, không nằm trong danh sách đã gửi hoặc bị trùng."),
        ("b1", "Có nhãn không thuộc các nhóm đã định nghĩa."),
        ("p", "Hai trường hợp này, cùng với lỗi mạng, thiếu trường segments hoặc mục không đúng dạng, đều thành "
              "AiServiceUnavailableException và trả mã 503. Khi câu trả lời hợp lệ, toàn bộ nhãn được ghi trong một "
              "TransactionTemplate, mỗi nhóm bằng một câu UPDATE theo danh sách mã người dùng. Người dùng đã gửi đi mà AI Service "
              "không trả về thì bị xóa nhãn cũ, không giữ nhãn của lần chạy trước. Nhãn cũ như VIP không còn thuộc enum "
              "CustomerSegment và bị bỏ qua khi hiển thị."),
        # #67: 305 passed, 8 skipped (31/10/2026); Bảng 4.10 đếm lại ngày 01/11/2026 trên origin/main
        ("p", "Ở lần chạy pytest ngày 31/10/2026 trên nhánh main, AI Service có 305 test đạt và 8 test bị bỏ qua (tính cả các ca tham "
              "số hóa). Bảng 4.10 cho số hàm test của từng tệp, đếm ngày 01/11/2026 trên cùng nhánh, tổng cộng 145 hàm. Các tệp "
              "test_wcm_spade.py và test_spade_rules.py kiểm tra khai phá và luật, trong đó có hai kịch bản cấy sẵn ở Bảng 2.40. Các "
              "tệp test_spending_analysis.py và test_spending_data.py kiểm tra dựng chuỗi và phản hồi. Tệp test_main.py kiểm tra các "
              "endpoint, trong đó có mã 422 cho đầu vào sai."),
        ("table", "Số hàm test của AI Service theo tệp", "4", [3700, 3804, 1000], ["Tệp", "Nhóm kiểm thử", "Số hàm"], [
            ["test_wcm_spade.py", "Khai phá mẫu có trọng số", "20"],
            ["test_spade_rules.py", "Luật tuần tự, kịch bản cấy sẵn", "18"],
            ["test_spending_analysis.py", "Ghép các bước, phản hồi", "10"],
            ["test_spending_data.py", "Lọc, cửa sổ, chuỗi tuần", "11"],
            ["test_spending_habits.py", "Thói quen định kỳ", "7"],
            ["test_budget_advisor.py", "Gợi ý ngân sách", "17"],
            ["test_rfm_segmentation.py", "Chấm điểm và bảy nhóm RFM", "12"],
            ["test_main.py", "Các endpoint của AI Service", "31"],
            ["test_receipt_postprocess.py", "Hậu xử lý Regex (mục 4.5.2)", "19"],
            ["Tổng", "9 tệp", "145"],
        ], "nguồn: nhóm thực hiện"),
    ]),
}

# (chuỗi cũ, chuỗi mới, số lần): thay trong từng <w:t>
TEXT_REPLACE = [
    # ---- 4.2.1 (#2, #3) ----
    ("Hai điểm cần lưu ý. Thứ nhất,", "Có hai điểm cần lưu ý. Thứ nhất,", 1),
    ("mới hơn bản đã dùng khi kiểm thử; đây là rủi ro tái lập mà nhóm ghi nhận ở phần hạn chế.",
     "mới hơn bản đã dùng khi kiểm thử. Đây là rủi ro về khả năng tái lập, được nhóm ghi nhận ở phần hạn chế.", 1),
    ("kho bánh xe chỉ dành cho CPU", "kho gói (wheel) dành riêng cho CPU", 1),
    # ---- 4.2.2 (#6, #7) ----
    ("Trong 55 commit có 22 commit feat, 8 docs, 5 fix, 4 chore và số còn lại thuộc refactor, test, style, ci, build.",
     "Trong 55 commit có 22 commit feat, 8 docs, 5 fix và 4 chore, còn 16 commit thuộc các loại refactor, test, style, ci và build.", 1),
    # .github/workflows/ci.yml: quy trình CI/CD nằm ở mục 5.5.1 (mục 5.4 là kiểm thử API và hiệu năng)
    ("Chi tiết triển khai được trình bày ở mục 5.4.", "Chi tiết triển khai được trình bày ở mục 5.5.1.", 1),
    # ---- 4.3.1 (#8, #10) ----
    ("đã chia sẵn thành ba thư mục train (5.080 ảnh), validation (635 ảnh) và test (636 ảnh), tỉ lệ xấp xỉ 80/10/10.",
     "đã chia sẵn thành ba thư mục train, validation và test theo tỉ lệ xấp xỉ 80/10/10 (số ảnh từng thư mục ở Bảng 4.3).", 1),
    ("Tập train có 1.597 ảnh dài, suy ra từ số mẫu mỗi epoch là 6.677 khi mỗi ảnh dài được lặp hai lần.",
     "Tập train có 1.597 ảnh dài. Vì mỗi ảnh dài được lặp hai lần nên mỗi epoch có 5.080 + 1.597 = 6.677 mẫu.", 1),
    # ---- 4.3.2 (#13, #14, #17, #18) ----
    ("ở tập train có 2.757 ảnh thiếu SELLER, 3.822 ảnh thiếu ADDRESS, 2.702 ảnh thiếu TIMESTAMP, 1.530 ảnh thiếu TOTAL_COST, "
     "và chỉ 450 trong 5.080 ảnh có đủ cả bốn trường.",
     "ở tập train, chỉ 450 trong 5.080 ảnh có đủ cả bốn trường, còn số ô trống của từng trường được ghi ở Bảng 4.2.", 1),
    ("Vì vậy, nhóm gán nhãn lại toàn bộ dữ liệu theo quy trình ở Hình 4.1, giữ nguyên nhãn gốc trong ai-service/data1 và ghi "
     "nhãn mới vào ai-service/Version5/data1.",
     "Vì vậy nhóm gán nhãn lại toàn bộ dữ liệu theo quy trình ở Hình 4.1. Nhãn gốc được giữ nguyên trong ai-service/data1, nhãn "
     "mới ghi vào ai-service/Version5/data1.", 1),
    ("Trường được đọc chắc chắn được ghi thẳng và coi như đã duyệt; trường mô hình tự đánh dấu là không chắc, hoặc hai nguồn cho "
     "giá trị khác nhau, được đưa vào",
     "Trường mà mô hình đọc chắc chắn được ghi thẳng và coi như đã duyệt. Trường mô hình tự đánh dấu là không chắc, hoặc hai nguồn "
     "cho giá trị khác nhau, được đưa vào", 1),
    ("Bảng 4.2 so sánh số ô trống trước và sau khi gán nhãn lại.",
     "Bảng 4.2 so sánh số ô trống trước và sau khi gán nhãn lại, mỗi ô ghi số trước → số sau.", 1),
    # ---- 4.3.3 (#21) ----
    ("Văn bản được chuẩn hóa Unicode NFC, gộp khoảng trắng; nhãn dài hơn 768 token bị báo lỗi thay vì cắt mất thẻ đóng "
     "(LabelTooLongError).",
     "Văn bản được chuẩn hóa Unicode NFC và gộp khoảng trắng. Nhãn dài hơn 768 token bị báo lỗi (LabelTooLongError) thay vì bị "
     "cắt mất thẻ đóng.", 1),
    # ---- 4.4.1 (#25, #26) ----
    # ai-service/Version5/tests: 64 hàm test_ trong 12 tệp test_*.py (đếm 01/11/2026)
    ("Trước khi tốn giờ GPU, notebook chạy toàn bộ kiểm thử pytest của thư mục Version5/tests (58 hàm kiểm thử trong 11 tệp) và "
     "dừng nếu có lỗi.",
     "Trước khi dùng giờ GPU, notebook chạy toàn bộ kiểm thử pytest trong Version5/tests (64 hàm trong 12 tệp, đếm ngày 01/11/2026) "
     "và dừng nếu có lỗi.", 1),
    ("nên train_model.py được viết để chạy tiếp: hàm find_resume_checkpoint() tìm",
     "nên train_model.py được viết để có thể chạy tiếp. Hàm find_resume_checkpoint() tìm", 1),
    # ---- Bảng 4.4 (#31): đơn vị của kích thước ảnh ----
    ("V3 dùng 1280 × 960; do_align_long_axis bật", "Đơn vị điểm ảnh. V3 dùng 1280 × 960; do_align_long_axis bật", 1),
    # ---- 4.4.3 (#32, #33) ----
    ("Điểm khác quan trọng nhất so với V3 là tiêu chí chọn checkpoint.", "Khác biệt quan trọng nhất so với V3 là tiêu chí chọn checkpoint.", 1),
    ("vì mô hình VisionEncoderDecoder trả về loss trung bình thông thường.", "vì VisionEncoderDecoder chỉ trả về loss trung bình thông thường.", 1),
    # ---- 4.4.4 (#40) ----
    ("Thời gian chạy của phiên cuối (1.600 bước, từ bước 4000 đến 5600) là 18.010 giây, khoảng 11,3 giây mỗi bước, gần với ước "
     "tính khi chạy thử; với 5.600 bước, tổng thời gian GPU ước tính khoảng 16–17 giờ, chia thành nhiều phiên Kaggle.",
     "Phiên cuối chạy 1.600 bước (từ bước 4000 đến 5600) mất 18.010 giây, tức 5,0 giờ hay khoảng 11,3 giây mỗi bước, gần với ước "
     "tính khi chạy thử. Với 5.600 bước, tổng thời gian GPU ước tính từ 15,6 đến 17,6 giờ (10,0 đến 11,3 giây mỗi bước), chia "
     "thành nhiều phiên Kaggle.", 1),
    # ---- 4.5.1 (#41, #42, #45, #46, #128) ----
    ("chọn CUDA nếu có, nếu không thì chạy trên CPU, và dừng ngay nếu không tìm thấy trọng số.",
     "dùng CUDA nếu có, ngược lại chạy trên CPU. Dịch vụ dừng ngay nếu không tìm thấy trọng số.", 1),
    ("Mẫu tuần tự, luật, thói quen định kỳ và cơ cấu danh mục bằng WCM-SPADE [48], [76]; mã 422 khi đầu vào sai",
     "Khai phá mẫu tuần tự, luật, thói quen định kỳ và cơ cấu danh mục bằng WCM-SPADE [48], [76]. Trả mã 422 khi đầu vào sai", 1),
    ("Kiểm tra dịch vụ còn sống (healthcheck của Docker)", "Kiểm tra dịch vụ còn sống (lệnh kiểm tra tình trạng, healthcheck, của Docker)", 1),
    ("Suy luận DONUT là tác vụ nặng về CPU.", "Suy luận DONUT là tác vụ tính toán nặng (chạy trên CPU ở máy chủ triển khai).", 1),
    ("để chạy suy luận trong thread pool của Starlette [34]", "để chạy suy luận trong nhóm luồng (thread pool) của Starlette [34]", 1),
    ("nên mỗi lúc chỉ một hóa đơn được đọc: container AI Service được cấp 3 GB bộ nhớ, đủ cho một lượt sinh chuỗi của mô hình, và "
     "hai lượt song song có nguy cơ làm tràn bộ nhớ.",
     "nên mỗi lúc chỉ một hóa đơn được đọc. Container AI Service được cấp 3 GB bộ nhớ, đủ cho một lượt sinh chuỗi của mô hình, còn "
     "hai lượt song song có nguy cơ làm tràn bộ nhớ.", 1),
    # ---- 4.5.2 (#48, #52, #53, #54, #55, #56, #57, #59, #60) ----
    ("lấy nội dung từng thẻ từ chuỗi DONUT bằng biểu thức khớp không tham lam.",
     "lấy nội dung từng thẻ từ chuỗi DONUT bằng biểu thức chính quy không tham lam (non-greedy).", 1),
    ("của phản hồi /donut/scan; các khóa cũ không đổi nên phiên bản ứng dụng cũ vẫn chạy.",
     "của phản hồi /donut/scan. Các khóa cũ được giữ nguyên nên phiên bản ứng dụng cũ vẫn dùng được.", 1),
    # receipt_scan_result.dart dòng 41-47 (checkedFields chỉ gồm seller, timestamp, total_cost vì biểu mẫu không có ô địa chỉ);
    # test_receipt_postprocess.py: 19 hàm test_ (git grep, origin/main, 01/11/2026), 74 ca tham số hóa
    ("cho tới khi người dùng sửa. Tệp test_receipt_postprocess.py có 15 hàm kiểm thử pytest, sinh 63 trường hợp nhờ tham số hóa.",
     "cho tới khi người dùng sửa. Địa chỉ không có ô riêng trên biểu mẫu đối soát nên không được viền. Tệp "
     "test_receipt_postprocess.py có 19 hàm kiểm thử pytest, sinh 74 trường hợp nhờ tham số hóa (đếm ngày 01/11/2026 trên nhánh "
     "main).", 1),
    (" Các cờ valid cho phép ứng dụng tô sáng trường cần người dùng xem lại trên màn hình đối soát.", "", 1),
    ("Bảng 4.8 cho thấy số trường khớp hoàn toàn tăng thêm 23 và không trường nào đang đúng bị làm sai.",
     "Bảng 4.8 là kết quả trên tập test, mẫu số của từng trường ghi ngay trong bảng. Số trường khớp hoàn toàn tăng thêm 23 và không "
     "trường nào đang đúng bị làm sai.", 1),
    ("được lợi nhiều nhất, đúng với nhận xét rằng lỗi của hai trường này chủ yếu là sai lệch nhỏ về dấu câu, khoảng trắng và định "
     "dạng; SELLER không đổi.",
     "được lợi nhiều nhất vì lỗi của hai trường này chủ yếu là sai lệch nhỏ về dấu câu, khoảng trắng và định dạng, còn SELLER "
     "không đổi.", 1),
    ("Cờ valid bắt được 23 trong 201 trường vẫn còn sai sau hậu xử lý và gắn nhầm cờ cho 4 trong 2.036 trường đúng. Như vậy cờ ít "
     "khi làm phiền người dùng, nhưng phần lớn lỗi còn lại (giá trị đúng định dạng mà sai nội dung) không thể phát hiện bằng luật, "
     "nên màn hình đối soát vẫn là bước bắt buộc.",
     "Cờ valid bắt được 23 trong 201 trường (11,4%) vẫn còn sai sau hậu xử lý và gắn nhầm cờ cho 4 trong 2.036 trường đúng (0,2%). "
     "Như vậy cờ hiếm khi báo nhầm, nhưng phần lớn lỗi còn lại là giá trị đúng định dạng mà sai nội dung nên luật không phát hiện "
     "được. Vì thế màn hình đối soát vẫn là bước cần thiết.", 1),
    # ---- Bảng 4.7 (#49, #50, #51) ----
    # receipt_postprocess.py dòng 36-39: SELLER_MAX_LENGTH 100, ADDRESS_MAX_LENGTH 250, SELLER_MIN_LETTERS 2, ADDRESS_MIN_LETTERS 3
    ("Bỏ ký tự rác (ngoài chữ, số và dấu câu thông dụng), bỏ dấu câu lặp, bỏ khoảng trắng trước dấu phẩy, thêm khoảng trắng sau dấu "
     "phẩy, bỏ dấu câu ở hai đầu; chuỗi toàn chữ thường được viết hoa đầu từ.",
     "Bỏ ký tự rác (ngoài chữ, số và dấu câu thông dụng), dấu câu lặp và dấu câu ở hai đầu. Bỏ khoảng trắng trước dấu phẩy, thêm "
     "khoảng trắng sau dấu phẩy. Chuỗi toàn chữ thường được viết hoa đầu từ.", 1),
    ("Tên ≥ 2 chữ cái, ≤ 100 ký tự; địa chỉ ≥ 3 chữ cái, ≤ 250 ký tự",
     "Tên có ít nhất 2 chữ cái và tối đa 100 ký tự. Địa chỉ có ít nhất 3 chữ cái và tối đa 250 ký tự.", 1),
    ("Nhận ngày dạng dd/MM/yyyy, dd-MM-yy, yyyy-MM-dd, “10 tháng 02 năm 2023”, “Jan 14, 22”, “09 Jan 2023”; ưu tiên thứ tự "
     "ngày/tháng/năm, chỉ đổi sang tháng/ngày khi tháng > 12; giờ dạng HH:mm[:ss], HHhmm, có AM/PM hoặc SA/CH.",
     "Nhận nhiều dạng ngày, ví dụ dd/MM/yyyy, “10 tháng 02 năm 2023” và “09 Jan 2023”. Ưu tiên thứ tự ngày/tháng/năm, chỉ đổi sang "
     "tháng/ngày khi tháng > 12. Giờ dạng HH:mm[:ss], HHhmm, có AM/PM hoặc SA/CH.", 1),
    ("(30,200.00; 1.011.780; 105 000)", "(ví dụ các kiểu nhóm nghìn của số tiền: “30,200.00”, “1.011.780”, “105 000”)", 1),
    # ---- 4.6.1 (#70-#75) ----
    # mốc 26/10/2026: facts.md mục 9 (216 tệp Java); trên main 62b8861 hiện có 284 tệp (K6 cập nhật nếu cần)
    ("gồm 216 tệp Java trong gói", "gồm 216 tệp Java (tại thời điểm 26/10/2026) trong gói", 1),
    ("Controller chỉ kiểm tra dữ liệu vào bằng @Valid rồi gọi Service; mọi phản hồi được bọc trong ApiResponse<T> (code, message, "
     "data), lỗi nghiệp vụ được ném thành ngoại lệ riêng",
     "Controller chỉ kiểm tra dữ liệu vào bằng @Valid rồi gọi Service. Mọi phản hồi được bọc trong ApiResponse<T> (code, message, "
     "data). Lỗi nghiệp vụ được ném thành ngoại lệ riêng", 1),
    # LoginAttemptService.java dòng 15 (LOCK_DURATION 15 phút); AuthService.java dòng 103 (OTP_VALIDITY 5 phút)
    ("sau 5 lần sai, đếm riêng theo email và theo địa chỉ IP.", "sau 5 lần sai, với số lần sai được đếm riêng theo email và theo địa chỉ IP.", 1),
    ("có 6 chữ số, sống 5 phút, được lưu trong Redis [36] qua RedisPasswordResetOtpStore; việc kiểm tra và xóa mã chạy trong một "
     "script Lua nên không thể dùng một mã hai lần.",
     "có 6 chữ số, có hiệu lực 5 phút và được lưu trong Redis [36] qua RedisPasswordResetOtpStore. Việc kiểm tra và xóa mã được "
     "thực hiện trong một script Lua (thao tác nguyên tử) nên một mã không thể dùng hai lần.", 1),
    # ---- 4.6.2 (#76, #77, #79, #80) ----
    ("ném InsufficientBalanceException (HTTP 400) khi một khoản chi, hoặc việc xóa một khoản thu, làm số dư âm.",
     "ném InsufficientBalanceException (HTTP 400) khi số dư sẽ âm, do một khoản chi mới hoặc do xóa một khoản thu.", 1),
    ("Nhờ vậy, việc gửi lại bao nhiêu lần cũng chỉ tạo một giao dịch và chỉ trừ ví một lần (tính lũy đẳng, idempotency).",
     "Nhờ vậy, dù gửi lại nhiều lần thì chỉ có một giao dịch được tạo và ví chỉ bị trừ một lần (tính lũy đẳng, idempotency).", 1),
    ("SavingGoalController có thêm POST /api/savings/{id}/contributions.", "SavingGoalController cung cấp POST /api/savings/{id}/contributions.", 1),
    ("tất cả trong một @Transactional; số dư không đủ thì InsufficientBalanceException (400) làm cả hai thay đổi quay lui.",
     "tất cả trong một @Transactional. Nếu số dư không đủ, InsufficientBalanceException (HTTP 400) được ném và cả hai thay đổi được "
     "quay lui.", 1),
    # ---- 4.6.3 (#83, #84) ----
    # BudgetAlertService.java dòng 124-132 (newlyReached) và 136-141 (highestReached): thông báo chỉ tạo khi mức sau cao hơn mức trước
    ("(80 cho BUDGET_WARNING, 100 cho BUDGET_EXCEEDED) để tránh", "(80% cho BUDGET_WARNING, 100% cho BUDGET_EXCEEDED) để tránh", 1),
    ("Mỗi mức chỉ sinh một thông báo trong một kỳ: nếu thông báo cùng mức đã tồn tại thì không tạo nữa, nên người dùng không bị gửi "
     "lặp khi tiếp tục chi.",
     "Một thông báo chỉ được tạo khi khoản chi đưa ngân sách lên một mức cao hơn mức trước đó (hàm newlyReached()), nên người dùng "
     "không nhận thông báo lặp khi tiếp tục chi tiêu.", 1),
    # ---- 4.6.4 (#85, #87); redis-cache.properties dòng 20-24 ----
    ("60 giây cho các thống kê còn lại, trừ ngẫu nhiên tối đa 10% để các khóa không hết hạn cùng lúc.",
     "60 giây cho các thống kê còn lại. TTL thực tế được giảm ngẫu nhiên tối đa 10% để các khóa không hết hạn cùng lúc.", 1),
    ("nên Redis ngừng hoạt động chỉ làm chậm thống kê chứ không làm hỏng chức năng.",
     "nên khi Redis ngừng hoạt động, thống kê chỉ chậm đi chứ chức năng không bị hỏng.", 1),
    # ---- 4.6.5 (#88, #89, #90) ----
    ("áp các quy tắc ở Bảng 3.30; câu trả lời thô được lưu nguyên", "áp dụng các quy tắc ở Bảng 3.30. Câu trả lời thô được lưu nguyên", 1),
    ("nên hai thao tác đồng thời trên cùng hóa đơn trả về 409 qua ReceiptConflictException.",
     "nên khi hai thao tác đồng thời tác động lên cùng một hóa đơn, thao tác sau bị từ chối bằng ReceiptConflictException (HTTP 409).", 1),
    ("Quản trị viên duyệt hoặc từ chối hóa đơn trên Web Admin; TransactionService.approveReceipt() đối soát số tiền và điều chỉnh "
     "ví dưới cùng cơ chế khóa ví như mục 4.6.2.",
     "Quản trị viên duyệt hoặc từ chối hóa đơn trên Web Admin. TransactionService.approveReceipt() đối soát số tiền và điều chỉnh "
     "ví với cùng cơ chế khóa ví đã nêu ở mục 4.6.2.", 1),
    # ---- 4.7.1 (#91, #93); mốc 26/10/2026 theo facts.md mục 9 (90 tệp .dart); main 62b8861 hiện có 172 tệp ----
    ("gồm 90 tệp .dart trong thư mục lib.", "gồm 90 tệp .dart trong thư mục lib (tại thời điểm 26/10/2026).", 1),
    ("khi nhận 401, nó gọi /api/auth/refresh đúng một lần (các yêu cầu khác cùng lúc chờ chung kết quả) rồi gửi lại yêu cầu ban đầu.",
     "khi nhận 401, nó gọi /api/auth/refresh một lần duy nhất. Các yêu cầu khác phát sinh cùng lúc chờ chung kết quả đó, sau đó "
     "cùng được gửi lại.", 1),
    # ---- 4.7.3 (#92, #109, #110, #111); số khóa ARB tại 26/10/2026 theo facts.md mục 9, main 62b8861 hiện có 702 khóa ----
    ("với 569 khóa; lệnh flutter gen-l10n", "với 569 khóa (tại thời điểm 26/10/2026); lệnh flutter gen-l10n", 1),
    ("(tiếng Việt “1.000.000 đ”, tiếng Anh “1,000,000 đ”)", f"(tiếng Việt “1.000.000{NBSP}đ”, tiếng Anh “1,000,000{NBSP}đ”)", 1),
    ("LanguageInterceptor gắn header Accept-Language vào mọi yêu cầu; vì Core Backend hiện chỉ trả thông báo tiếng Việt, khi chọn "
     "tiếng Anh ứng dụng hiển thị thông báo của chính ứng dụng theo mã HTTP.",
     "LanguageInterceptor gắn header Accept-Language vào mọi yêu cầu. Core Backend hiện chỉ trả thông báo tiếng Việt, nên khi người "
     "dùng chọn tiếng Anh, ứng dụng hiển thị thông báo riêng của ứng dụng theo mã HTTP.", 1),
    ("Giao diện sáng, tối hoặc theo hệ thống được ThemeCubit quản lý;", "Chế độ giao diện sáng, tối hoặc theo hệ thống do ThemeCubit quản lý;", 1),
    # ---- 4.8 (#112, #113, #114); AdminController.java dòng 155: bảng 10 người dùng mới nhất theo id giảm dần ----
    ("Web Admin được render ở phía máy chủ bằng Thymeleaf [55] ngay trong Core Backend, không phải một dự án riêng.",
     "Web Admin được sinh giao diện phía máy chủ bằng Thymeleaf [55] và nằm ngay trong Core Backend chứ không phải một dự án riêng.", 1),
    ("được gửi bằng fetch tới các endpoint /admin/ajax/** và nhận JSON; duyệt hoặc từ chối hóa đơn dùng POST",
     "được gửi bằng hàm fetch của JavaScript tới các endpoint /admin/ajax/** và nhận JSON. Việc duyệt hoặc từ chối hóa đơn dùng POST", 1),
    ("Trang dashboard vẽ biểu đồ từ AdminStatisticsService (có cache Redis) và nút “Chạy Phân Lớp AI Tự Động” gửi POST "
     "/admin/ajax/segmentation/run, Core Backend gọi /admin/segment của AI Service rồi trang hiển thị biểu đồ tỷ trọng bảy nhóm "
     "và bảng 10 người dùng mới nhất kèm tên nhóm tiếng Việt.",
     "Trang dashboard vẽ biểu đồ từ AdminStatisticsService (có cache Redis). Nút “Chạy Phân Lớp AI Tự Động” gửi POST "
     "/admin/ajax/segmentation/run. Core Backend gọi /admin/segment của AI Service, sau đó trang hiển thị biểu đồ tỷ trọng bảy "
     "nhóm và bảng 10 người dùng mới nhất cùng tên nhóm tiếng Việt.", 1),
    # ---- 4.9 (#116, #121) ----
    ("Chỉ Caddy mở cổng 80 và 443 ra ngoài; PostgreSQL và MongoDB chỉ nghe", "Chỉ Caddy mở cổng 80 và 443 ra ngoài. PostgreSQL và MongoDB chỉ nghe", 1),
    ("Hai rủi ro còn lại: giới hạn 3 GB cho AI Service mới được chọn theo ước lượng",
     "Còn hai rủi ro. Thứ nhất, giới hạn 3 GB cho AI Service mới chỉ được chọn theo ước lượng", 1),
    ("chưa được đo trên máy chủ, và chỉ đủ cho một lượt suy luận mỗi lúc (mục 4.5.1); trọng số không nằm trong Git",
     "chưa được đo trên máy chủ và chỉ đủ cho một lượt suy luận mỗi lúc (mục 4.5.1). Thứ hai, trọng số không nằm trong Git", 1),
    # ---- 4.10 (#126): mỗi hạn chế dẫn về mục đã nêu ----
    ("Phần cài đặt vẫn còn những hạn chế đã nêu: thư viện Python chưa ghim phiên bản, giới hạn bộ nhớ của AI Service chưa được đo "
     "trên máy chủ, và cờ valid của mô-đun hậu xử lý chỉ phát hiện được một phần nhỏ lỗi còn lại.",
     "Phần cài đặt vẫn còn những hạn chế đã nêu: thư viện Python chưa ghim phiên bản (mục 4.2.1), cờ valid của mô-đun hậu xử lý chỉ "
     "phát hiện được 23 trong 201 lỗi còn lại (mục 4.5.2) và giới hạn bộ nhớ của AI Service chưa được đo trên máy chủ (mục 4.9).", 1),
]
