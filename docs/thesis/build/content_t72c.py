# Nội dung phiên T7.2c: Chương 2, mục 2.4 (sơ đồ lớp mức phân tích), 2.5 (phân tích bài toán và mô hình DONUT), 2.6 (kết chương).
# Đối chiếu mã nguồn tại HEAD 0b84ffe ngày 25/10/2026: core-backend Entity/*.java, Document/*.java;
# ai-service/ai_service.py (V3 đang phục vụ), Version3/donut_result/{config.json, tokenizer.json};
# ai-service/Version5/{labels.py, model_config.py, evaluate.py} (chỉ đọc, không nêu số liệu huấn luyện V5).
# Trích dẫn: [5] DONUT, [6] Transformer, [7] ViT, [8] Swin, [9] BART, [10] mBART, [11] XLM-R, [12] SentencePiece,
# [13] HF Transformers, [17] Tesseract, [18] LayoutLM, [19] LayoutLMv3, [22] MC-OCR, [24] khảo sát tài liệu tiếng Việt, [40] HF Donut.
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = "T7.2c"
SRC = "nguồn: nhóm thực hiện"
NGUON = "Nguồn: nhóm thực hiện"

# Chương 2 đã có Hình 2.1–2.21 và Bảng 2.1–2.31 sau phiên T7.2b.
COUNTER_START = {("Hình", "2"): 21, ("Bảng", "2"): 31}

W3 = [2300, 3000, 3204]

CLASSES = [
    ["User", "Tài khoản người dùng hoặc quản trị viên; giữ số dư ví", "username, email, phone, password, role, active, walletBalance, aiLabel, lastLoginTime"],
    ["Transaction", "Một giao dịch thu hoặc chi", "amount, isExpense, transactionDate, categoryName, note, location, paymentMethod, clientId, rawReceiptData"],
    ["Category", "Danh mục thu chi dùng chung", "name, type (EXPENSE hoặc INCOME)"],
    ["Receipt", "Hóa đơn đính kèm giao dịch và kết quả AI đã đối soát", "vendorName, extractedTotal, extractedDate, imageUrl, status (8 trạng thái), errorCode"],
    ["ReceiptProcessingAttempt", "Một lượt AI đọc hóa đơn, lưu nguyên câu trả lời", "attemptNumber, status (COMPLETED, FAILED, LEGACY), aiRawData, errorCode, createdAt, completedAt"],
    ["Budget", "Hạn mức chi theo tuần hoặc tháng, cho một danh mục hoặc mọi danh mục", "amount, periodType (WEEK, MONTH), startDate, endDate"],
    ["SavingGoal", "Mục tiêu tiết kiệm", "title, targetAmount, currentAmount, deadline"],
    ["Notification", "Thông báo gửi người dùng (cảnh báo ngân sách, hóa đơn đã xử lý)", "type (4 loại), message, isRead; mã giao dịch, ngân sách, hóa đơn liên quan"],
    ["PaymentOrder", "Lệnh nạp tiền vào ví hoặc rút tiền từ ví qua cổng thanh toán", "orderCode, amount, type (DEPOSIT, WITHDRAW), status, provider, gatewayTxnId"],
    ["SubscriptionPlan", "Gói dịch vụ do quản trị viên định nghĩa", "planName, price, durationDays, maxAiScans, isWcmSpadeEnabled, active"],
    ["AppReview", "Đánh giá ứng dụng của người dùng, chờ quản trị viên duyệt", "rating, comment, status, createdAt"],
    ["ActionLog", "Nhật ký một thao tác nghiệp vụ hoặc bảo mật", "action, targetType, targetId, result, description, ipAddress, timestamp"],
    ["RevokedToken", "Mã JWT đã bị thu hồi trước hạn", "tokenHash, expiresAt, revokedAt"],
    ["OcrRawLog", "Bản ghi kết quả thô của AI cho một giao dịch (MongoDB)", "rawJsonData, averageConfidenceScore, createdAt"],
    ["OcrFeedback", "Phản hồi về một trường AI đọc sai (MongoDB)", "fieldError, expectedValue, aiValue, isResolved, reportedAt"],
]

SECTIONS = {
    # ============================================================ 2.4.1
    "Xác định các lớp thực thể": [
        ("p", "Lớp thực thể ở mức phân tích là lớp biểu diễn một khái niệm nghiệp vụ cần được lưu trữ lâu dài, chưa gắn với "
              "công nghệ cài đặt [47]. Nhóm xác định các lớp này bằng cách lấy các danh từ xuất hiện lặp lại trong 22 bảng đặc "
              "tả use case ở mục 2.3 (người dùng, giao dịch, hóa đơn, ngân sách, thông báo…) rồi đối chiếu với các lớp dữ liệu "
              "đang có trong Core Backend. Kết quả là 15 lớp: 13 lớp được lưu trong PostgreSQL và 2 lớp được lưu dưới dạng "
              "document trong MongoDB [37]. Lớp ghi phiên bản kiểm toán của Hibernate Envers không được đưa vào vì đó là lớp "
              "kỹ thuật, không xuất hiện trong use case nào."),
        ("p", "Bảng 2.32 liệt kê ý nghĩa và các thuộc tính chính của từng lớp. Ở mức phân tích, bảng bỏ qua khóa chính, khóa "
              "ngoại và các cột phục vụ kỹ thuật như số phiên bản dùng cho khóa lạc quan hay thời điểm tạo, sửa chung cho mọi "
              "bảng; các cột này được trình bày ở phần thiết kế cơ sở dữ liệu trong Chương 3. Tên lớp và tên thuộc tính giữ "
              "nguyên như trong mã nguồn để người đọc dễ lần theo từ mô hình phân tích sang mô hình thiết kế."),
        ("table", "Danh sách các lớp thực thể mức phân tích", "2", W3, ["Lớp", "Ý nghĩa", "Thuộc tính chính"], CLASSES, NGUON),
        ("p", "Một vài lựa chọn mô hình hóa cần nêu rõ. Chiều của giao dịch là thuộc tính logic isExpense chứ không phải hai "
              "lớp con thu và chi, vì hai loại giao dịch có cùng thuộc tính và cùng quy tắc cập nhật số dư. Số dư ví là thuộc "
              "tính walletBalance của User, được cập nhật mỗi khi giao dịch được thêm, sửa hoặc xóa, chứ không phải giá trị tính "
              "lại từ toàn bộ giao dịch. Vai trò người dùng là chuỗi (ROLE_USER, ROLE_ADMIN, ROLE_LOCKED), không phải một lớp "
              "riêng. Mỗi hóa đơn có thể được AI đọc nhiều lần, nên kết quả của từng lần đọc được tách thành lớp "
              "ReceiptProcessingAttempt; kết quả cuối cùng sau khi người dùng đối soát nằm ở Receipt."),
    ],
    # ============================================================ 2.4.2
    "Sơ đồ lớp mức phân tích": [
        ("p", "Do có 15 lớp, sơ đồ lớp được tách thành hai hình để vẫn đọc được ở khổ giấy A4. Hình 2.22 gồm các lớp phục vụ "
              "nghiệp vụ tài chính của người dùng; Hình 2.23 gồm các lớp phục vụ thanh toán, quản trị, bảo mật và lưu vết AI. "
              "Lớp User có mặt ở cả hai hình; ở Hình 2.23 lớp này chỉ ghi vài thuộc tính để nhận diện, và hai lớp Transaction, "
              "Receipt được vẽ thu gọn vì đã trình bày đầy đủ ở Hình 2.22."),
        ("fig", "Sơ đồ lớp mức phân tích – nhóm lớp nghiệp vụ tài chính", "2", PNG + "ch2_lop_phan_tich_tai_chinh.png", 16.0, SRC, None),
        ("p", "Trong Hình 2.22, mỗi người dùng ghi nhiều giao dịch, và mỗi giao dịch thuộc đúng một danh mục. Quan hệ giữa "
              "Transaction và Receipt là quan hệ hợp thành (composition): hóa đơn chỉ tồn tại như phần đính kèm của một giao "
              "dịch và được lưu, xóa cùng giao dịch đó. Quan hệ giữa Receipt và ReceiptProcessingAttempt cũng là hợp thành, "
              "với bội số 0..* vì một hóa đơn có thể được đọc lại khi lần đọc trước thất bại. Một ngân sách gắn với 0 hoặc 1 "
              "danh mục; khi không gắn danh mục, ngân sách giới hạn tổng chi của mọi danh mục trong kỳ. Thông báo thuộc về một "
              "người dùng và chỉ lưu mã của giao dịch, ngân sách hoặc hóa đơn liên quan, không giữ liên kết trực tiếp tới các "
              "lớp đó, nên sơ đồ không vẽ thêm các quan hệ này."),
        ("fig", "Sơ đồ lớp mức phân tích – nhóm lớp thanh toán, quản trị và lưu vết AI", "2", PNG + "ch2_lop_phan_tich_he_thong.png", 16.0, SRC, None),
        ("p", "Hình 2.23 cho thấy mỗi lệnh thanh toán thuộc một người dùng. Đánh giá ứng dụng và nhật ký hoạt động có bội số "
              "0..1 ở phía User: nhật ký vẫn được ghi cho các thao tác của hệ thống hoặc của người chưa đăng nhập, chẳng hạn "
              "đăng nhập sai. Hai lớp mang khuôn mẫu «document» được lưu trong MongoDB: OcrRawLog gắn với giao dịch có kết quả "
              "AI, OcrFeedback gắn với hóa đơn và người gửi phản hồi. SubscriptionPlan và RevokedToken đứng riêng: gói dịch vụ "
              "hiện là danh mục do quản trị viên quản lý, chưa có quan hệ lưu trữ nào gắn gói với người dùng; mã bị thu hồi "
              "chỉ được lưu dưới dạng giá trị băm để kiểm tra khi nhận yêu cầu, không cần biết chủ sở hữu."),
    ],
    # ============================================================ 2.5.1
    "Phát biểu bài toán trích xuất bốn trường thông tin": [
        ("p", "Mục này phân tích phần trí tuệ nhân tạo của hệ thống, tức chức năng mà AI Service cung cấp cho use case Quét "
              "hóa đơn. Đầu vào của bài toán là một ảnh hóa đơn bán lẻ tiếng Việt do người dùng chụp bằng camera điện thoại. "
              "Đầu ra là một đối tượng JSON gồm bốn trường: tên người bán (SELLER), địa chỉ người bán (ADDRESS), thời điểm "
              "giao dịch (TIMESTAMP) và tổng tiền thanh toán (TOTAL_COST). Đây cũng là bốn trường được dùng trong cuộc thi "
              "MC-OCR về hóa đơn tiếng Việt chụp bằng điện thoại [22]. Bảng 2.33 nêu định nghĩa từng trường, thẻ tương ứng "
              "trong chuỗi đầu ra của mô hình và nơi giá trị được dùng trong hệ thống."),
        ("table", "Bốn trường thông tin cần trích xuất", "2", [1500, 2200, 2304, 2500],
         ["Trường", "Ý nghĩa", "Ví dụ trong nhãn", "Sử dụng trong hệ thống"],
         [["SELLER\n(seller_name)", "Tên cửa hàng hoặc doanh nghiệp in trên hóa đơn", "HIGHLANDS COFFEE; VinCommerce; MINIMART ANAN", "Receipt.vendorName"],
          ["ADDRESS\n(address)", "Địa chỉ của điểm bán", "Chợ Sủi Phú Thị Gia Lâm", "Transaction.location"],
          ["TIMESTAMP\n(timestamp)", "Ngày, có thể kèm giờ, của giao dịch", "14/02/2023; 15/08/2020-17:29; 31/03/2023 20:02:49", "Transaction.transactionDate, Receipt.extractedDate"],
          ["TOTAL_COST\n(total_cost)", "Số tiền khách phải trả", "100,000; 20.000; 30,200.00", "Receipt.extractedTotal, gợi ý số tiền của giao dịch"]],
         "Nguồn: nhóm thực hiện, ví dụ lấy từ tệp nhãn data1/<split>/metadata.jsonl"),
        ("p", "Gọi ảnh đầu vào là x. Bài toán được phát biểu dưới dạng sinh chuỗi: mô hình cần sinh chuỗi token y = (y₁, …, "
              "y_T) mã hóa bốn trường trên, với xác suất p(y | x) được phân rã thành tích các xác suất có điều kiện p(y_t | y₁, "
              "…, y_{t−1}, x) [5], [6]. Khi huấn luyện, hàm mất mát là entropy chéo giữa token dự đoán và token của nhãn tại "
              "từng vị trí. Khi suy luận, chuỗi được sinh lần lượt từng token cho tới token kết thúc, rồi được chuyển thành "
              "JSON. Một trường có thể rỗng nếu hóa đơn không in thông tin đó hoặc phần ảnh chứa nó bị mờ, bị cắt."),
        ("p", "Dữ liệu cho bài toán gồm 6.351 ảnh hóa đơn, chia thành 5.080 ảnh huấn luyện, 635 ảnh kiểm định và 636 ảnh "
              "kiểm thử, xấp xỉ tỉ lệ 80/10/10. Mỗi ảnh có một nhãn gồm đúng bốn khóa trên. Bảng 2.33 cho thấy giá trị của cùng "
              "một trường có nhiều dạng: thời điểm có khi chỉ có ngày, có khi kèm giờ phút hoặc giây, phân cách bằng dấu cách "
              "hay dấu gạch ngang; số tiền có khi dùng dấu phẩy, có khi dùng dấu chấm để ngăn cách hàng nghìn, có khi kèm phần "
              "thập phân .00. Vì vậy đầu ra của mô hình được giữ nguyên dạng chữ như in trên hóa đơn, còn việc chuẩn hóa về "
              "kiểu ngày giờ và kiểu số được thực hiện ở bước hậu xử lý; ví dụ, AI Service hiện tách số lớn nhất trong chuỗi "
              "tổng tiền thành trường phụ total_cost_number trước khi trả kết quả cho Core Backend. Trong bộ nhãn ban đầu, chỉ "
              "450 trên 5.080 ảnh huấn luyện có đủ cả bốn trường khác rỗng, phần lớn do nhãn bị bỏ sót chứ không phải do hóa "
              "đơn thiếu thông tin; việc rà soát và gán lại nhãn được trình bày ở Chương 4."),
    ],
    # ============================================================ 2.5.2
    "Hạn chế của OCR truyền thống mà DONUT giải quyết": [
        ("p", "Mục 1.5 đã giới thiệu ba hướng trích xuất thông tin hóa đơn. Mục này phân tích cụ thể vì sao hai hướng dựa "
              "trên OCR gặp khó với dữ liệu của đề tài, làm cơ sở cho việc chọn DONUT."),
        ("p", "Thứ nhất, hóa đơn trong bài toán được chụp bằng điện thoại chứ không được scan. Ảnh có thể nghiêng, cong theo "
              "nếp giấy, thiếu sáng hoặc lóa, chữ in nhiệt bị phai; đây chính là đặc điểm mà MC-OCR đặt ra cho hóa đơn tiếng "
              "Việt chụp bằng thiết bị di động [22]. Một bộ máy OCR như Tesseract giả định ảnh vào đã được nhị phân hóa và "
              "không tự phân tích bố cục [17], nên luồng xử lý cần thêm các bước phát hiện vùng hóa đơn, xoay, khử nghiêng "
              "trước khi nhận dạng. Mỗi bước bổ sung là một mô-đun riêng phải chọn tham số và có thể hỏng độc lập."),
        ("p", "Thứ hai, lỗi của bước OCR lan sang bước trích xuất. Tiếng Việt có dấu thanh và dấu phụ đặt trên hoặc dưới "
              "nguyên âm; nhận dạng sai một dấu là đổi một chữ, và các khảo sát về xử lý tài liệu tiếng Việt ghi nhận dấu là "
              "nguồn lỗi chính của OCR [4], [24]. Với trường TOTAL_COST, nhầm dấu chấm với dấu phẩy hay mất một chữ số làm sai "
              "hẳn giá trị tiền. Luật và biểu thức chính quy ở bước sau không sửa được những lỗi này, còn mô hình bố cục như "
              "LayoutLM nhận văn bản và hộp bao do OCR trả về làm đầu vào [18], [19], nên cũng kế thừa chúng [5]."),
        ("p", "Thứ ba, chi phí gán nhãn và bảo trì. Luật phải viết lại khi gặp mẫu hóa đơn mới; mô hình bố cục cần nhãn mức "
              "token hoặc mức dòng kèm hộp bao [18]. DONUT chỉ cần cặp (ảnh, chuỗi đích) như mô tả ở mục 2.5.1 [5], đúng với "
              "dạng nhãn bốn trường mà nhóm có. Ngoài ra, Kim và cộng sự chỉ ra rằng việc chạy thêm một bộ OCR làm tăng chi "
              "phí tính toán của cả hệ thống [5]; với DONUT, AI Service chỉ phải nạp và chạy một mô hình."),
        ("p", "Đổi lại, DONUT có những hạn chế cần chấp nhận. Mô hình phải học cả việc đọc chữ lẫn việc chọn trường từ dữ "
              "liệu, nên cần tinh chỉnh trên ảnh hóa đơn tiếng Việt. Đầu ra là văn bản sinh ra, nên mô hình có thể sinh một "
              "chuỗi trông hợp lý nhưng không có trên ảnh; mô hình cũng không trả về vị trí của trường trên ảnh, nên không thể "
              "khoanh vùng để người dùng đối chiếu. Hệ thống giảm rủi ro này ở mức nghiệp vụ: kết quả AI luôn được đưa lên "
              "form đối soát để người dùng sửa trước khi lưu (mục 2.2.3)."),
    ],
    # ============================================================ 2.5.3
    "Kiến trúc Swin Transformer encoder và BART decoder": [
        ("p", "DONUT là một mô hình mã hóa – giải mã (encoder–decoder) dựa trên Transformer [5], [6]. Bộ mã hóa biến ảnh "
              "thành một dãy vector đặc trưng; bộ giải mã đọc dãy vector đó và sinh chuỗi token đầu ra. Trong thư viện Hugging "
              "Face Transformers, mô hình được cài đặt bằng lớp VisionEncoderDecoderModel kèm bộ tiền xử lý DonutProcessor "
              "[13], [40]. Hình 2.24 trình bày luồng dữ liệu qua mô hình với cấu hình của bản V3 mà AI Service đang phục vụ, "
              "đọc từ tệp config.json của mô hình."),
        ("fig", "Kiến trúc DONUT với cấu hình của mô hình đang phục vụ", "2", PNG + "ch2_donut_kien_truc.png", 14.0,
         "nguồn: nhóm thực hiện, dựa trên [5], [8]", None),
        ("p", "Bộ mã hóa là Swin Transformer [8]. Vision Transformer (ViT) chia ảnh thành các patch rồi tính self-attention "
              "giữa mọi cặp patch [7], nên chi phí tăng theo bình phương số patch; với ảnh hóa đơn độ phân giải cao, chi phí "
              "này rất lớn. Swin tính self-attention trong từng cửa sổ cục bộ không chồng lấn (W-MSA), nên chi phí chỉ tăng "
              "tuyến tính theo kích thước ảnh; ở khối kế tiếp, lưới cửa sổ được dịch đi một nửa kích thước cửa sổ (SW-MSA) để "
              "thông tin truyền được giữa các cửa sổ lân cận [8]. Sau mỗi tầng, lớp gộp patch (patch merging) gộp từng nhóm "
              "2 × 2 patch, làm độ phân giải giảm một nửa và số kênh tăng gấp đôi, tạo ra biểu diễn phân cấp [8]."),
        ("p", "DONUT dùng Swin với số khối ở bốn tầng là 2, 2, 14, 2 và kích thước cửa sổ 10 [5]; tệp cấu hình của mô hình "
              "V3 có đúng các giá trị này, cùng kích thước patch 4 và số kênh ban đầu 128. Với ảnh đầu vào 1280 × 960, lưới "
              "patch ở tầng 1 có kích thước 320 × 240; sau ba lần gộp, tầng 4 còn lưới 40 × 30 với 1024 kênh. Bộ giải mã vì "
              "thế nhận 1.200 vector, mỗi vector 1024 chiều, đại diện cho các vùng của ảnh. Kích thước ảnh đầu vào quyết định "
              "trực tiếp độ dài dãy này: ảnh càng lớn thì chữ nhỏ trên hóa đơn dài càng rõ, nhưng thời gian và bộ nhớ khi "
              "huấn luyện, suy luận càng tăng. Đây là một tham số mà nhóm cân nhắc lại khi huấn luyện phiên bản mới (Chương 4)."),
        ("p", "Bộ giải mã có kiến trúc của BART, một mô hình chuỗi sang chuỗi được tiền huấn luyện bằng cách khôi phục văn "
              "bản đã bị làm nhiễu, trong đó phần giải mã sinh văn bản theo kiểu tự hồi quy, từ trái sang phải [9]. DONUT chỉ "
              "dùng phần giải mã, gồm 4 lớp, khởi tạo từ trọng số của BART đa ngôn ngữ mBART [5], [10]; tệp cấu hình V3 ghi "
              "loại bộ giải mã là mbart với 4 lớp, chiều ẩn 1024, 16 đầu chú ý và độ dài tối đa 768 token. Mỗi lớp giải mã có "
              "self-attention có che (mỗi vị trí chỉ nhìn các token đứng trước) và cross-attention lên dãy vector của bộ mã "
              "hóa [6]; nhờ cross-attention, mỗi token sinh ra được gắn với vùng ảnh liên quan mà không cần bước OCR riêng."),
        ("p", "Mô hình gốc được Kim và cộng sự tiền huấn luyện bằng nhiệm vụ đọc toàn bộ văn bản trong ảnh theo thứ tự đọc "
              "(mục 1.5.3) [5]. Đề tài không tiền huấn luyện lại mà tinh chỉnh (fine-tune) từ trọng số "
              "naver-clova-ix/donut-base-finetuned-cord-v2, bản đã được tinh chỉnh trên tập hóa đơn CORD. Khi tinh chỉnh, "
              "mô hình được huấn luyện theo kiểu teacher forcing: tại mỗi vị trí, đầu vào của bộ giải mã là token đúng của "
              "nhãn ở vị trí trước, thay vì token mô hình tự sinh [5]."),
    ],
    # ============================================================ 2.5.4
    "Cơ chế prompt và task token": [
        ("p", "Trong DONUT, bộ giải mã luôn bắt đầu sinh từ một prompt (lời nhắc), tức một hoặc vài token đặc biệt cho mô hình "
              "biết cần làm nhiệm vụ gì [5]. Cùng một kiến trúc có thể được tinh chỉnh cho nhiều nhiệm vụ: khi tiền huấn luyện, "
              "prompt chỉ ra nguồn dữ liệu đọc; khi hỏi đáp trên tài liệu, prompt chứa cả câu hỏi và mô hình sinh tiếp câu trả "
              "lời [5]. Tokenizer của mô hình V3 vẫn còn các token <s_iitcdip> và <s_synthdog> của giai đoạn tiền huấn luyện "
              "cùng các thẻ trường của tập CORD như <s_menu>, <s_total_price>, cho thấy các nhiệm vụ trước đó được nhận diện "
              "bằng chính cơ chế này."),
        ("p", "Đề tài định nghĩa một nhiệm vụ mới với task token <s_seller>. Token này được đặt làm decoder_start_token_id khi "
              "huấn luyện, và khi suy luận AI Service truyền nó vào tham số decoder_input_ids của hàm generate. Sau task token, "
              "mỗi trường được bao bởi một cặp thẻ mở và đóng theo thứ tự cố định. Với hóa đơn có nhãn SELLER “MINIMART ANAN”, "
              "ADDRESS “Chợ Sủi Phú Thị Gia Lâm”, TIMESTAMP “10/08/2020-17:20” và TOTAL_COST “88,000”, chuỗi đích là:"),
        ("p", "<s_seller><s_seller_name>MINIMART ANAN</s_seller_name><s_address>Chợ Sủi Phú Thị Gia Lâm</s_address>"
              "<s_timestamp>10/08/2020-17:20</s_timestamp><s_total_cost>88,000</s_total_cost></s_seller></s>"),
        ("p", "Mười thẻ của nhiệm vụ (một cặp task token và bốn cặp thẻ trường) được thêm vào tokenizer dưới dạng token đặc "
              "biệt, nên mỗi thẻ là đúng một token và không bị tách nhỏ. Vì cấu trúc thẻ lồng nhau, hàm token2json của "
              "DonutProcessor chuyển được chuỗi trên một – một thành đối tượng JSON {\"seller\": {\"seller_name\": …, "
              "\"address\": …, \"timestamp\": …, \"total_cost\": …}} [40], đúng dạng mà Core Backend đọc khi lưu hóa đơn. Nếu "
              "chuỗi sinh ra hỏng cấu trúc, AI Service trả về chuỗi gốc trong trường raw_text để phía sau xử lý như một lần đọc "
              "thất bại. Chuỗi sinh ra bị giới hạn ở 768 token, bằng độ dài tối đa của bộ giải mã."),
    ],
    # ============================================================ 2.5.5
    "Vấn đề tokenizer với tiếng Việt và giải pháp mở rộng": [
        ("p", "Tokenizer của DONUT tách văn bản thành các subword (đơn vị dưới từ) theo mô hình Unigram của SentencePiece "
              "[12], cùng họ với tokenizer của XLM-R [11]. SentencePiece coi dấu cách là một ký hiệu thường, biểu diễn bằng "
              "ký tự “▁” ở đầu piece, nhờ đó giải mã ngược lại được đúng văn bản gốc [12]. Trong tệp tokenizer.json của mô "
              "hình V3, từ vựng Unigram có 57.522 piece. Từ vựng này không chứa đủ các ký tự cần cho hóa đơn tiếng Việt: một số "
              "ký tự có dấu không có piece riêng, và có ký tự chỉ xuất hiện ở dạng đứng đầu từ, ví dụ có “▁1” nhưng không có "
              "“1”, nên chuỗi như “QL1A” bị mã hóa thành token không xác định <unk>. Mô hình không bao giờ sinh lại được ký tự "
              "đã thành <unk>."),
        ("p", "Ở bản V3, nhóm xử lý việc này bằng cách thêm từng ký tự còn thiếu thành added token (token bổ sung): tokenizer "
              "của V3 có 207 added token, trong đó 134 token là một ký tự đơn, chủ yếu là nguyên âm tiếng Việt có dấu. Cách "
              "này gây ra lỗi khoảng trắng. Added token được tách ra khỏi câu trước khi SentencePiece chạy, nên phần còn lại "
              "của một từ trở thành một đoạn riêng và được thêm “▁” ở đầu như một từ mới. Từ “Dương” bị cắt thành “D”, “ư”, "
              "“ơ” và “ng”, trong đó “ng” mang dấu cách đứng trước, nên khi giải mã ra “Dươ ng”. Để bù lại, AI Service phải "
              "chạy hàm clean_vietnamese_text dùng biểu thức chính quy ghép lại các vần bị tách sau mỗi lần suy luận; cách vá "
              "này dựa trên danh sách vần nên không bảo đảm đúng cho mọi từ."),
        ("p", "Bản V5 thay cách làm trên bằng việc mở rộng chính từ vựng Unigram. Trước khi huấn luyện, chương trình duyệt "
              "toàn bộ nhãn huấn luyện, tìm các ký tự không có piece riêng hoặc bị mã hóa thành <unk>, rồi thêm mỗi ký tự thành "
              "một piece mới của mô hình Unigram với điểm bằng điểm thấp nhất của từ vựng gốc. Vì ký tự mới nằm trong từ vựng, "
              "nó được cắt chung với các ký tự còn lại của từ, nên không sinh thêm “▁” và giữ đúng khoảng trắng. Mã của các "
              "token đặc biệt đứng sau từ vựng gốc được dời ra sau cho khỏi trùng, rồi mới thêm mười thẻ của nhiệm vụ. Ma trận "
              "embedding của bộ giải mã được mở rộng theo kích thước tokenizer mới, và vector của mỗi ký tự mới được khởi tạo "
              "bằng trung bình các vector của từ vựng gốc. Bảng 2.34 so sánh hai cách làm."),
        ("table", "So sánh hai cách bổ sung ký tự tiếng Việt cho tokenizer", "2", [2100, 3202, 3202],
         ["Tiêu chí", "Thêm added token (V3)", "Mở rộng từ vựng Unigram (V5)"],
         [["Vị trí ký tự mới", "Danh sách added token, tách khỏi câu trước khi SentencePiece chạy", "Piece mới trong chính từ vựng Unigram"],
          ["Khoảng trắng khi giải mã", "Sai khi ký tự mới nằm giữa từ (“Dươ ng”)", "Giữ đúng vì từ được cắt như một khối"],
          ["Hậu xử lý cần thêm", "clean_vietnamese_text ghép vần bằng biểu thức chính quy", "Không cần ghép vần"],
          ["Kiểm tra trước khi huấn luyện", "Không có trong mã huấn luyện cũ", "Mã hóa rồi giải mã mọi nhãn huấn luyện; dừng nếu dưới 99% nhãn tái tạo nguyên vẹn"],
          ["Khởi tạo embedding ký tự mới", "Theo mặc định của hàm resize_token_embeddings", "Trung bình vector của từ vựng gốc"]],
         "Nguồn: nhóm thực hiện, đối chiếu ai-service/model_config.py (mã huấn luyện cũ) và ai-service/Version5/model_config.py"),
        ("p", "Điều kiện dừng ở dòng thứ tư của Bảng 2.34 biến chất lượng tokenizer thành một bước kiểm tra tự động: nếu dưới "
              "99% nhãn huấn luyện giữ nguyên sau khi mã hóa rồi giải mã, chương trình dừng và in các nhãn lỗi thay vì huấn "
              "luyện tiếp trên dữ liệu bị hỏng. Kết quả kiểm tra này trên bộ nhãn thực tế, cùng các số liệu huấn luyện và "
              "đánh giá của bản V5 so với V3, được trình bày ở Chương 4 và Chương 5."),
    ],
    # ============================================================ 2.6
    "KẾT CHƯƠNG": [
        ("p", "Chương 2 đã phân tích hệ thống LedgerMind theo UML [47]. Ở mức nghiệp vụ, sáu quy trình chính được mô tả bằng "
              "bảng đặc tả và ba loại sơ đồ hoạt động, tuần tự, cộng tác. Ở mức hệ thống, 22 use case của Người dùng, Quản trị "
              "viên và tác nhân hệ thống AI Service được đặc tả đủ tám trường. Sơ đồ lớp mức phân tích xác định 15 lớp thực "
              "thể và quan hệ giữa chúng, trong đó giao dịch, hóa đơn và các lượt AI đọc hóa đơn là trục chính của dữ liệu."),
        ("p", "Phần phân tích mô hình đã phát biểu bài toán trích xuất bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST dưới "
              "dạng sinh chuỗi từ ảnh, chỉ ra ba khó khăn của hướng dựa trên OCR với hóa đơn tiếng Việt chụp bằng điện thoại, "
              "và mô tả kiến trúc DONUT gồm bộ mã hóa Swin Transformer, bộ giải mã mBART và task token <s_seller> [5], [8], "
              "[10]. Chương cũng nêu hạn chế của DONUT, đặc biệt là việc không trả về vị trí trường và khả năng sinh chuỗi sai, "
              "cùng cách hệ thống giảm rủi ro bằng bước đối soát. Vấn đề tokenizer tiếng Việt của bản V3 và giải pháp mở rộng "
              "từ vựng Unigram ở bản V5 là cơ sở cho phần thiết kế mô hình AI."),
        ("p", "Chương 3 sẽ chuyển các kết quả này sang mức thiết kế: sơ đồ lớp phân tích được chuyển thành mô hình quan hệ "
              "và ERD, các use case được hiện thực bằng kiến trúc microservices và API RESTful, còn định dạng nhãn, tokenizer "
              "mở rộng và pipeline hậu xử lý được thiết kế chi tiết cho AI Service."),
    ],
}

ABBREVIATIONS = [
    ("mBART", "Multilingual BART", "BART đa ngôn ngữ"),
    ("SW-MSA", "Shifted Window Multi-head Self-Attention", "Tự chú ý đa đầu trên cửa sổ dịch"),
    ("W-MSA", "Window Multi-head Self-Attention", "Tự chú ý đa đầu trên cửa sổ"),
]
