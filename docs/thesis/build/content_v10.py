# Nội dung phiên v10 (28/10/2026, đợt 5 task 2): viết phần phân tích chi tiêu (WCM-SPADE, luật tuần tự, thói quen định kỳ,
# gợi ý ngân sách) và phân khúc RFM theo đúng mã nguồn sau đợt 3, thay các đoạn cũ (độ dài tối đa 4 kèm "A → B", nhãn
# CHURN/AT-RISK/VIP/ACTIVE, khoảng thời gian đang chọn). Sinh KhoaLuan_KLCN175_v10.docx từ v9 bằng builder.py.
# Đối chiếu mã nguồn tại HEAD 6a009f9 (nhánh fix/ai-analysis); mọi con số lấy từ docs/thesis/facts_ai.md (có file:line).
# Đã đọc: ai-service/{ai_service, spending_data, spending_analysis, wcm_spade, spending_habits, budget_advisor,
# rfm_segmentation, local_time}.py và test_*.py; core-backend CustomerSegmentationService, AiSegmentClient, CustomerSegment,
# UserRepository (truy vấn RFM), AdminController + templates/admin/dashboard.html; mobile-app ai_tab_page.dart,
# core/utils/spending_history.dart, widgets/dialogs/ai_components.dart, l10n/app_vi.arb.
# Tài liệu: [48] Zaki, [49] Fader, [76]-[88] trong docs/thesis/references.md (trạng thái từng tài liệu ở facts_ai.md mục 12).
# Hình mới: ch2_phan_tich_chi_tieu (đặt ở Chương 3, giữ tiền tố ch2 theo tên tệp của kế hoạch). Vẽ lại bốn hình cũ có chữ
# "khoảng thời gian đang chọn": ch2_thong_ke_{hoat_dong,tuan_tu,cong_tac}, ch3_thong_ke_tuan_tu.
PNG = "/home/triphan/Workspace/Deploy_Project/.claude/worktrees/dot1-bao-mat/docs/thesis/diagrams/"
SESSION_TAG = None
SECTIONS = {}
RENUMBER = True
SRC = "nguồn: nhóm thực hiện"

IMAGE_REPLACE = [
    ("ch2_thong_ke_hoat_dong.png", PNG + "ch2_thong_ke_hoat_dong.png", "fit"),
    ("ch2_thong_ke_tuan_tu.png", PNG + "ch2_thong_ke_tuan_tu.png", "fit"),
    ("ch2_thong_ke_cong_tac.png", PNG + "ch2_thong_ke_cong_tac.png", "fit"),
    ("ch3_thong_ke_tuan_tu.png", PNG + "ch3_thong_ke_tuan_tu.png", "fit"),
]

ABBREVIATIONS = [
    ("CMAP", "Co-occurrence MAP", "Bản đồ đồng xuất hiện của các item"),
    ("CV", "Coefficient of Variation", "Hệ số biến thiên (độ lệch chuẩn chia trung bình)"),
    ("SPADE", "Sequential PAttern Discovery using Equivalence classes", "Khai phá mẫu tuần tự bằng lớp tương đương"),
    ("WCM-SPADE", "Weighted CM-SPADE (tên do nhóm đặt)", "SPADE kèm bản đồ đồng xuất hiện, có trọng số chi tiêu và lọc mẫu đóng"),
]

# ---------------------------------------------------------------------------------------------------------------------
# Chương 2: mục 2.6 mới
# ---------------------------------------------------------------------------------------------------------------------
CH2 = [
    ("h2", "PHÂN TÍCH BÀI TOÁN PHÂN TÍCH CHI TIÊU"),
    ("p", "Mục này phân tích phần thứ hai của AI Service, tức các chức năng phục vụ use case UC13 (xem báo cáo thói quen chi "
          "tiêu) và UC21 (xem thống kê hệ thống, gồm chạy phân khúc khách hàng). Khác với mô hình DONUT ở mục 2.5, các chức năng này không dùng mạng nơ-ron "
          "mà dùng thuật toán khai phá dữ liệu và luật thống kê đơn giản, cài đặt bằng Python, không dùng thư viện học máy. Mọi ngưỡng được nêu "
          "trong mục là lựa chọn thiết kế của đề tài, trừ chỗ có trích dẫn tài liệu; nhóm nói rõ điều này để không gán cho "
          "tài liệu những giá trị mà tài liệu không đưa ra."),

    ("h3", "Phát biểu bài toán phân tích chi tiêu"),
    ("p", "Đầu vào của bài toán là danh sách giao dịch của một người dùng, mỗi giao dịch gồm danh mục, số tiền, ngày và cờ "
          "thu hoặc chi. Từ các khoản chi trong khoảng 26 tuần gần nhất, AI Service trả về bốn đầu ra được tóm tắt ở "
          "[[t_dau_ra]]: mẫu tuần tự, luật tuần tự, thói quen định kỳ và cơ cấu danh mục. Cùng với chúng, hệ thống có hai "
          "chức năng riêng: gợi ý phân bổ ngân sách theo mục tiêu tiết kiệm (cho người dùng) và phân khúc khách hàng theo "
          "mô hình RFM (cho quản trị viên). Bài toán chỉ mô tả những gì đã xảy ra trong lịch sử chi tiêu; hệ thống không "
          "dự báo chi tiêu tương lai và các kết quả không được kiểm định ý nghĩa thống kê."),
    ("table", "Bốn đầu ra của phân tích chi tiêu", "2", [1700, 3700, 3104],
     ["Đầu ra", "Câu hỏi mà đầu ra trả lời", "Nội dung kết quả"],
     [["Mẫu tuần tự", "Những khoản chi nào hay xuất hiện cùng nhau hoặc nối tiếp nhau trong tuần?",
       "Chuỗi các itemset (tập danh mục chi trong một ngày), số tuần chứa chuỗi, trọng số"],
      ["Luật tuần tự", "Sau khi chi A, người dùng có hay chi tiếp B trong cùng tuần không?",
       "Cặp A và B kèm support, độ tin cậy, độ tin cậy Laplace và lift"],
      ["Thói quen định kỳ", "Danh mục nào được chi đều đặn theo một chu kỳ ngày?",
       "Số lần chi, khoảng cách trung bình và độ lệch chuẩn (ngày), ngày gần nhất, ngày kế tiếp “khoảng”"],
      ["Cơ cấu danh mục", "Mỗi danh mục chiếm bao nhiêu trong tổng chi?",
       "Tổng tiền, tỷ trọng và số tuần có danh mục"]],
     SRC, "t_dau_ra"),
    ("p", "Khi trong cửa sổ có chi tiêu ở ít hơn 8 tuần, trạng thái trả về là INSUFFICIENT_DATA: danh sách mẫu và luật rỗng, "
          "còn thói quen định kỳ và cơ cấu danh mục vẫn được tính vì hai đầu ra này không cần nhiều tuần. Về giới hạn đầu "
          "vào, một yêu cầu có tối đa 5.000 giao dịch, tên danh mục dài tối đa 255 ký tự (khớp độ dài cột của Core "
          "Backend) và số tiền không quá 10¹²; đầu vào vi phạm bị từ chối bằng mã 422."),

    ("h3", "Biểu diễn lịch sử chi tiêu thành chuỗi theo tuần"),
    ("p", "Khai phá mẫu tuần tự cần một tập chuỗi. Đề tài lấy tuần theo chuẩn ISO 8601 làm đơn vị: mỗi tuần có ít nhất một "
          "khoản chi là một chuỗi; trong chuỗi, mỗi ngày là một itemset (tập các danh mục có chi trong ngày đó, đã sắp "
          "thứ tự và khử trùng), các ngày xếp theo thời gian. Ví dụ minh họa, một tuần chi Ăn uống vào thứ Hai, Ăn uống "
          "và Di chuyển vào thứ Tư, Giải trí vào thứ Sáu cho chuỗi ⟨{Ăn uống}, {Ăn uống, Di chuyển}, {Giải trí}⟩. Mẫu tuần "
          "tự được hiểu theo định nghĩa của Agrawal và Srikant [87]: một dãy itemset là mẫu của chuỗi nếu các itemset của "
          "nó xuất hiện đúng thứ tự trong chuỗi."),
    ("p", "Đề tài chọn tuần thay vì tháng vì hai lý do. Thứ nhất, số chuỗi quyết định độ tin cậy của phép đếm support: cửa "
          "sổ 26 tuần cho tối đa 26 chuỗi, trong khi cùng khoảng đó (khoảng sáu tháng) chỉ cho khoảng sáu chuỗi nếu mỗi tháng là một chuỗi, "
          "quá ít để phân biệt thói quen với sự trùng hợp. Thứ hai, theo nhận định của nhóm, nhịp sinh hoạt như đi chợ, đi lại, ăn uống lặp lại theo "
          "tuần nên một tuần đủ ngắn để mẫu mang nghĩa “sau khi chi A thì chi B”. Việc cắt chuỗi theo tuần là một xấp xỉ "
          "lấy cảm hứng từ khai phá episode theo cửa sổ [82], không phải là cài đặt của thuật toán WINEPI."),
    ("p", "Dữ liệu được chuẩn bị theo các quy tắc sau. Chỉ khoản chi được dùng: khoản thu, khoản có danh mục “Tiết kiệm” "
          "(so sánh sau khi chuẩn hóa NFC và cắt khoảng trắng) và khoản có ngày không đọc được bị bỏ. Khoản có ngày sau "
          "ngày mai (dung sai 1 ngày) bị bỏ trước khi cắt cửa sổ, để một ngày gõ nhầm không kéo cả cửa sổ đi xa. Cửa sổ "
          "26 tuần tính từ thứ Hai của tuần chứa khoản chi muộn nhất còn lại, lùi 25 tuần, nên neo vào dữ liệu chứ không "
          "vào đồng hồ máy chủ. Ngày được tính theo múi giờ cố định UTC+7. Tuần không có khoản chi nào không thành chuỗi: "
          "N, số chuỗi, là số tuần có ghi chép, vì tuần trống có thể chỉ là tuần người dùng chưa nhập chứ chưa chắc là tuần "
          "không chi. Phép khai phá chỉ chạy khi có ít nhất 8 tuần như vậy."),

    ("h3", "Khai phá mẫu tuần tự có trọng số WCM-SPADE"),
    ("p", "Thuật toán SPADE [48] biểu diễn mỗi item bằng một id-list dọc, tức danh sách các cặp (mã chuỗi, vị trí itemset) "
          "nơi item xuất hiện. Mẫu dài hơn được tạo bằng phép nối hai id-list: nối theo chuỗi (S-extension, item mới nằm ở "
          "itemset sau) hoặc nối theo itemset (I-extension, item mới nằm cùng itemset). Support thô của một mẫu là số chuỗi, "
          "ở đây là số tuần, chứa mẫu. CM-SPADE [76] thêm bản đồ đồng xuất hiện CMAP: hai bảng đếm số chuỗi mà item a đứng "
          "trước hẳn item b và số chuỗi mà a, b cùng itemset, dùng để loại ứng viên không thể đạt ngưỡng trước khi nối "
          "id-list. Trong đề tài, CMAP giữ cả cặp a đứng trước chính a và so với ngưỡng support thô."),
    ("p", "Đề tài thêm trọng số chi tiêu theo hướng khai phá mẫu tuần tự có trọng số của WSpan [77], với ý tưởng khoản "
          "chi lớn quan trọng hơn khoản chi nhỏ. Các công thức dưới đây là cách làm kiểu WSpan do đề tài chọn, không phải "
          "công thức nguyên văn của bài gốc:"),
    ("b1", "Trọng số của item i: w(i) = m × tổng chi(i) / Σ tổng chi, với m là số danh mục có mặt. Đây là tỷ trọng chi "
           "tiêu chia cho tỷ trọng trung bình nên trung bình các trọng số bằng 1; nếu tổng chi bằng 0 thì mọi w(i) = 1."),
    ("b1", "Trọng số của mẫu P: w(P) = trung bình w(i) của các item trong P."),
    ("b1", "Support có trọng số: wsup(P) = sup(P) × w(P) / N, với sup(P) là support thô và N là số chuỗi."),
    ("b1", "Mẫu được giữ khi wsup(P) ≥ min_sup, mặc định min_sup = 0,25 (min_sup_factor của yêu cầu)."),
    ("p", "Ví dụ minh họa trọng số: ba danh mục có tổng chi 600 nghìn, 300 nghìn và 100 nghìn đồng cho w = 3 × 0,6 = 1,8; "
          "0,9 và 0,3, trung bình bằng 1. Mẫu gồm hai danh mục đầu có trọng số (1,8 + 0,9) / 2 = 1,35."),
    ("p", "Vì w(P) không vượt quá trọng số lớn nhất maxW nên wsup(P) ≤ sup(P) × maxW / N. Do đó chỉ cần xét các mẫu có "
          "support thô không nhỏ hơn raw_bound = max(1, ⌈min_sup × N / maxW⌉); đây là cận trên, nên việc tỉa không làm mất "
          "mẫu hợp lệ. Cả bước duyệt theo chiều sâu (DFS) và CMAP đều dùng ngưỡng thô này. Kết quả được lọc đóng: bỏ mẫu P khi có mẫu Q khác P với cùng "
          "support thô mà P là mẫu con của Q. Đây là hậu lọc theo tinh thần khai phá mẫu đóng của BIDE [78], không phải "
          "thuật toán BIDE, và chỉ so sánh trong tập mẫu đã đạt support có trọng số."),
    ("p", "Độ dài tối đa của mẫu (DEFAULT_MAX_PATTERN_LENGTH = 4) được đếm theo số item, không theo số itemset: một mẫu "
          "⟨{A, B}, {C}⟩ có độ dài 3. Chỉ mẫu có ít nhất hai item mới được đưa ra API. Số mẫu khai phá tối đa là 50.000; "
          "khi DFS bị cắt ở giới hạn này trong lúc còn ứng viên đạt ngưỡng, kết quả mang cờ truncated và AI Service ghi một "
          "dòng cảnh báo vào nhật ký."),

    ("h3", "Luật tuần tự"),
    ("p", "Luật tuần tự A ⇒ B có nghĩa: trong một tuần, nếu có A (các danh mục của A chi trong cùng một ngày) thì sau đó, "
          "cũng trong tuần ấy, có B; cách hiểu luật tuần tự kèm độ tin cậy theo [79]. A và B là các itemset cùng ngày, rời nhau, mỗi bên có thể gồm nhiều danh mục, với "
          "|A| + |B| ≤ 4. Các đại lượng đều đếm theo số tuần:"),
    ("b1", "sup(A): số tuần có A trong một ngày; sup(B): số tuần có B ở bất kỳ đâu trong tuần; sup(A ⇒ B): số tuần có B "
           "ở một ngày sau lần đầu A xuất hiện trong tuần đó."),
    ("b1", "Độ tin cậy: confidence = sup(A ⇒ B) / sup(A)."),
    ("b1", "Độ tin cậy Laplace: (sup(A ⇒ B) + 1) / (sup(A) + 2). Ước lượng Laplace được dùng để đánh giá độ chính xác của "
           "luật trong CN2 [81]; dạng (k + 1) / (n + 2) là trường hợp hai lớp do đề tài chọn, và nó kéo luật có ít bằng "
           "chứng về phía 0,5."),
    ("b1", "Lift: confidence / (sup(B) / N). Đại lượng này tương ứng độ “interest” của Brin, Motwani và Silverstein [80] "
           "(thường gọi là lift): lớn hơn 1 là A và B phụ thuộc dương. Mức nền sup(B) / N tính cả tuần B xuất hiện trước A "
           "nên lift ở đây là ước lượng thận trọng."),
    ("p", "Một luật được giữ khi đồng thời sup(A) ≥ 4, sup(A ⇒ B) ≥ 3, độ tin cậy Laplace ≥ 0,6 và lift ≥ 1,2. Giá trị 3 "
          "của support luật là số k nhỏ nhất thỏa (k + 1) / (4 + 2) ≥ 0,6. Độ tin cậy thô được tính và trả về nhưng không "
          "dùng làm ngưỡng lọc. Luật bị trội cũng bị loại: A ⇒ B bị bỏ khi có A′ ⇒ B với A′ là tập con thật sự của A và độ "
          "tin cậy Laplace của A′ ⇒ B không nhỏ hơn của A ⇒ B; phép so sánh được thực hiện với mọi ứng viên đã qua các "
          "ngưỡng trên. Luật được xếp theo độ tin cậy Laplace giảm dần, rồi lift, rồi support."),
    ("p", "Luật không phụ thuộc trọng số. Luật được đếm lại từ id-list thô của mọi item, không lấy từ các mẫu đã khai phá. "
          "Lý do là trọng số chỉ phục vụ việc xếp hạng mẫu: một danh mục chi rất lớn nhưng không liên quan sẽ làm tăng "
          "maxW, nâng raw_bound và có thể làm mất luật của các danh mục nhỏ nếu luật lấy từ kết quả khai phá có trọng số. "
          "Cũng vì vậy luật có thể chứa A và B nhiều item mà mẫu tương ứng không nằm trong danh sách mẫu. Các ngưỡng 4, 0,6, "
          "1,2 và 3 cùng việc bỏ luật bị trội là lựa chọn của đề tài. Lift và độ tin cậy Laplace không thay được kiểm định "
          "ý nghĩa thống kê, vốn cần phương pháp như của Webb [86]; kết quả vì thế chỉ có giá trị mô tả."),
    ("p", "[[t_vidu]] lấy hai kịch bản cấy sẵn trong kiểm thử của AI Service, mỗi kịch bản gồm 26 tuần. Ở kịch bản thứ nhất "
          "A xuất hiện ở 16 tuần, B ở 15 tuần và có 12 tuần B đứng sau A; trọng số các danh mục bằng nhau nên min_sup × N = "
          "0,25 × 26 = 6,5 và raw_bound = 7, mẫu A rồi B (support thô 12) được giữ. Ở kịch bản thứ hai, C và D độc lập: lift "
          "bằng 1,0 nên luật bị loại dù mẫu C rồi D vẫn được khai phá."),
    ("table", "Hai kịch bản cấy sẵn để kiểm tra luật tuần tự (N = 26 tuần)", "2", [3100, 2700, 2704],
     ["Đại lượng", "Kịch bản 1: A ⇒ B", "Kịch bản 2: C ⇒ D"],
     [["sup(A) (hoặc sup(C))", "16", "16"],
      ["sup(B) (hoặc sup(D))", "15", "13"],
      ["sup(luật)", "12", "8"],
      ["Độ tin cậy", "12 / 16 = 0,75", "8 / 16 = 0,5"],
      ["Độ tin cậy Laplace", "13 / 18 ≈ 0,7222", "9 / 18 = 0,5"],
      ["Lift", "0,75 / (15 / 26) = 1,3", "0,5 / (13 / 26) = 1,0"],
      ["Kết quả", "Giữ (Laplace ≥ 0,6, lift ≥ 1,2)", "Loại (Laplace < 0,6, lift < 1,2)"]],
     SRC, "t_vidu"),

    ("h3", "Thói quen chi tiêu định kỳ"),
    ("p", "Thói quen định kỳ không dùng khai phá mẫu mà đo trực tiếp khoảng cách giữa các lần chi. Với mỗi danh mục, các "
          "ngày khác nhau có chi cho số lần chi; các khoảng cách (tính bằng ngày) giữa hai ngày liên tiếp cho trung "
          "bình μ và độ lệch chuẩn tổng thể σ. Hệ số biến thiên CV = σ / μ đo độ đều đặn: CV càng nhỏ, chu kỳ càng đều. "
          "Danh mục được giữ khi có ít nhất 3 lần chi và CV ≤ 0,5. Ngưỡng 3 lần theo quy tắc của Plaid cho luồng giao dịch "
          "định kỳ trưởng thành [85]; ngưỡng CV 0,5 là lựa chọn của đề tài, còn khái niệm mẫu xuất hiện định kỳ có nền "
          "trong khai phá mẫu định kỳ [83], [84] mà đề tài dùng bản đơn giản hơn nhiều."),
    ("p", "Ngày kế tiếp là ngày gần nhất cộng thêm μ làm tròn ngày; ứng dụng hiển thị nó là “khoảng” và dùng câu khác khi "
          "ngày ấy đã qua. Đây là phép ngoại suy đơn giản từ khoảng cách đã xảy ra, không phải mô hình dự báo. Thói quen được xếp theo CV "
          "tăng dần (đều nhất trước) và tính trên toàn bộ khoản chi của cửa sổ, không cần đủ 8 tuần. Ví dụ minh họa: một "
          "danh mục có bốn ngày chi cách nhau 7, 7 và 8 ngày cho μ ≈ 7,33, σ ≈ 0,47 và CV ≈ 0,06, nên được giữ với chu kỳ "
          "khoảng 7 ngày."),

    ("h3", "Gợi ý ngân sách theo mục tiêu tiết kiệm"),
    ("p", "Phần gợi ý ngân sách không dùng khai phá mẫu mà chỉ tính trên các tháng dương lịch trọn vẹn: bỏ tháng hiện "
          "tại, tháng đầu tiên chỉ được tính khi dữ liệu bắt đầu từ ngày 1, và giữ tối đa 6 tháng gần nhất "
          "(ADVICE_MAX_MONTHS = 6). Ứng dụng di động gửi lịch sử 7 tháng lịch để AI Service phân biệt được tháng đầu thiếu "
          "với tháng đầy đủ; sau đó AI Service dùng nhiều nhất 6 tháng trọn vẹn. Danh mục chia thành ba nhóm: thiết yếu "
          "(10 danh mục như Ăn uống, Nhà ở, Điện nước, Sức khỏe, Giáo dục), tùy ý (Mua sắm, Giải trí, Du lịch, Hiếu hỉ) "
          "và trung tính (các danh mục còn lại, kể cả “Khác” và danh mục người dùng tự tạo)."),
    ("p", "Các bước tính: chi tiêu trung bình mỗi tháng của từng nhóm bằng tổng chia số tháng; số cần góp mỗi tháng bằng "
          "max(mục tiêu − đã có, 0) / số tháng còn lại (hoặc giá trị needed_monthly nếu ứng dụng truyền vào); thặng dư = "
          "thu nhập trung bình − chi trung bình; thiếu hụt = số cần góp − thặng dư. Nếu thiếu hụt không dương, người "
          "dùng đang đi đúng hướng và AI Service chỉ gợi ý giảm nhẹ 10% các mục tùy ý chiếm từ 15% chi tiêu trở lên. Nếu "
          "thiếu hụt dương, AI Service duyệt các nhóm theo thứ tự tùy ý, trung tính, thiết yếu; mỗi mục bị cắt không quá "
          "30% mức trung bình (thiết yếu không quá 10%), phần cắt không vượt phần thiếu hụt còn lại chia theo tỷ trọng "
          "của mục trong nhóm, và dừng khi hết thiếu hụt. Nếu cắt hết mà vẫn thiếu, câu tóm tắt gợi ý tăng thu nhập hoặc "
          "giãn hạn. Chưa có khoản chi nào, hoặc chưa có tháng trọn vẹn nào có chi, thì AI Service trả mã 422 kèm câu giải "
          "thích cố định. Các tỷ lệ 30%, 10% và 15% là lựa chọn của đề tài."),

    ("h3", "Phân khúc khách hàng theo mô hình RFM"),
    ("p", "Phân khúc RFM [49] chấm mỗi người dùng theo ba chỉ số trong 12 tháng gần nhất, chỉ tính khoản chi và bỏ khoản "
          "góp tiết kiệm: Recency R là số ngày từ lần chi gần nhất, Frequency F là số khoản chi và Monetary M là tổng tiền "
          "chi. RFM là kỹ thuật quen thuộc trong tiếp thị trực tiếp [88]; cách chấm điểm bằng ngũ phân vị dưới đây là lựa chọn "
          "của đề tài, vì ngũ phân vị là cách chấm phổ biến trong thực hành RFM."),
    ("p", "Mỗi chỉ số được chấm từ 1 đến 5 theo thứ hạng phần trăm trung điểm: điểm = min(5, 1 + ⌊5 × (less + 0,5 × equal) / "
          "n⌋), trong đó less là số người có giá trị thấp hơn, equal là số người có giá trị bằng nhau và n là số người "
          "được chấm; những người cùng giá trị nhận cùng điểm. Recency được chấm ngược (ít ngày hơn thì điểm cao hơn), F và "
          "M chấm thuận. Ví dụ minh họa: với n = 10, một người có 4 người thấp hơn và không ai bằng ngoài chính mình "
          "(equal = 1) nhận 1 + ⌊5 × 4,5 / 10⌋ = 3 điểm. Nếu chỉ có một người hoặc mọi giá trị bằng nhau, điểm là 3. "
          "Người chưa có khoản chi nào (F = 0) được xếp thẳng vào nhóm LOST với mã rfm “000” và không tham gia chấm điểm để "
          "khỏi kéo lệch điểm của những người còn lại."),
    ("p", "Từ bộ ba điểm (R, F, M), luật ở [[t_rfm]] được áp dụng theo thứ tự ưu tiên, luật khớp đầu tiên thắng. Monetary chỉ "
          "ảnh hưởng nhóm CHAMPIONS. Luật ánh xạ và tên bảy nhóm là lựa chọn của đề tài, rút gọn từ các bảng phân nhóm RFM "
          "phổ biến trong thực hành; đề tài không dùng thuật toán gom cụm K-Means."),
    ("table", "Luật xếp bảy nhóm RFM theo thứ tự ưu tiên", "2", [900, 3304, 2000, 2300],
     ["Thứ tự", "Điều kiện", "Nhóm", "Tên hiển thị"],
     [["1", "Frequency = 0", "LOST", "Đã rời bỏ"],
      ["2", "R ≥ 4, F ≥ 4 và M ≥ 4", "CHAMPIONS", "Khách hàng tốt nhất"],
      ["3", "R ≥ 4 và F ≤ 2", "NEW", "Khách mới"],
      ["4", "R ≥ 3 và F ≥ 3", "LOYAL", "Trung thành"],
      ["5", "R ≤ 2 và F ≥ 3", "AT_RISK", "Có nguy cơ rời bỏ"],
      ["6", "R ≤ 2", "HIBERNATING", "Ngủ đông"],
      ["7", "Các trường hợp còn lại", "NEED_ATTENTION", "Cần chú ý"]],
     SRC, "t_rfm"),
]

# ---------------------------------------------------------------------------------------------------------------------
# Chương 3: mục 3.9.4
# ---------------------------------------------------------------------------------------------------------------------
CH3 = [
    ("h3", "Thiết kế pipeline phân tích chi tiêu"),
    ("p", "Phần phân tích chi tiêu của AI Service được thiết kế như một đường xử lý một chiều, không giữ trạng thái giữa hai "
          "yêu cầu: mỗi lần gọi POST /spade/analyze nhận đủ giao dịch và trả đủ kết quả. [[f_pipeline]] trình bày các bước của "
          "đường xử lý; điểm rẽ duy nhất là điều kiện có chi tiêu từ 8 tuần trở lên, nếu không thì mẫu và luật để rỗng "
          "nhưng thói quen định kỳ và cơ cấu danh mục vẫn được tính. Các endpoint chạy đồng bộ (def, không phải async def) "
          "vì tính toán chỉ dùng CPU, nên FastAPI chạy chúng trong thread pool và không chặn vòng lặp sự kiện."),
    ("fig", "Đường xử lý của yêu cầu /spade/analyze", "3", PNG + "ch2_phan_tich_chi_tieu.png", 8.5, SRC, None, "f_pipeline"),
    ("p", "[[t_hang]] liệt kê các hằng số điều khiển đường xử lý, giá trị và nguồn. Những dòng ghi “đề tài” là lựa chọn thiết "
          "kế, chưa có tài liệu nào đưa ra giá trị đó; chúng có thể được chỉnh khi có dữ liệu thực của nhiều người dùng "
          "hơn."),
    ("table", "Hằng số và ngưỡng của phân tích chi tiêu và RFM", "3", [2900, 1000, 3204, 1400],
     ["Hằng số", "Giá trị", "Ý nghĩa", "Nguồn"],
     [["WINDOW_WEEKS", "26", "Số tuần của cửa sổ phân tích", "Đề tài"],
      ["MIN_WEEKS_WITH_DATA", "8", "Số tuần có chi tiêu tối thiểu để khai phá mẫu và luật", "Đề tài"],
      ["FUTURE_TOLERANCE_DAYS", "1", "Số ngày sau hôm nay mà khoản chi còn được giữ", "Đề tài"],
      ["MAX_TRANSACTIONS", "5.000", "Số giao dịch tối đa một yêu cầu", "Đề tài"],
      ["MAX_CATEGORY_LENGTH", "255", "Số ký tự tối đa của tên danh mục", "Khớp cột của Core Backend"],
      ["DEFAULT_MIN_SUP", "0,25", "Support có trọng số tối thiểu (tỷ lệ số tuần)", "Đề tài"],
      ["DEFAULT_MAX_PATTERN_LENGTH", "4", "Số item tối đa của một mẫu; |A| + |B| của luật", "Đề tài"],
      ["MIN_PATTERN_ITEMS", "2", "Số item tối thiểu của mẫu đưa ra API", "Đề tài"],
      ["DEFAULT_MAX_PATTERNS", "50.000", "Số mẫu khai phá tối đa trước khi cắt (truncated)", "Đề tài"],
      ["MIN_ANTECEDENT_SUPPORT", "4", "sup(A) tối thiểu của luật", "Đề tài"],
      ["RULE_MIN_SUPPORT", "3", "Support tối thiểu của luật và của ứng viên A, B", "Đề tài"],
      ["MIN_LAPLACE_CONFIDENCE", "0,6", "Độ tin cậy Laplace tối thiểu", "Đề tài, ước lượng [81]"],
      ["MIN_LIFT", "1,2", "Lift tối thiểu", "Đề tài, khái niệm [80]"],
      ["MIN_OCCURRENCES", "3", "Số lần chi tối thiểu của thói quen định kỳ", "Theo [85]"],
      ["MAX_GAP_CV", "0,5", "Hệ số biến thiên tối đa của khoảng cách", "Đề tài"],
      ["ADVICE_MAX_MONTHS", "6", "Số tháng trọn vẹn tối đa của lời khuyên", "Đề tài"],
      ["MAX_CUT_RATIO", "0,30", "Tỷ lệ cắt tối đa mỗi mục", "Đề tài"],
      ["ESSENTIAL_CUT_RATIO", "0,10", "Tỷ lệ cắt tối đa mục thiết yếu", "Đề tài"],
      ["LIGHT_CUT_RATIO", "0,10", "Tỷ lệ giảm nhẹ khi đang đúng hướng", "Đề tài"],
      ["DISCRETIONARY_SHARE_ALERT", "15 (%)", "Tỷ trọng từ đó mục tùy ý bị gợi ý giảm nhẹ", "Đề tài"],
      ["RFM_WINDOW_MONTHS", "12", "Số tháng gần nhất để tính R, F, M (Core Backend)", "Đề tài"],
      ["NO_ACTIVITY_DAYS", "366", "Recency của người chưa có khoản chi nào", "Đề tài"],
      ["QUINTILES", "5", "Số mức điểm của mỗi chỉ số RFM", "Đề tài"]],
     SRC, "t_hang"),
    ("p", "Hợp đồng của POST /spade/analyze được tóm tắt ở [[t_json]]. Yêu cầu có tối đa 5.000 giao dịch; top_n nằm trong "
          "khoảng 1 đến 50 (mặc định 10) và min_sup_factor thuộc (0, 1] (mặc định 0,25). Trường thừa trong yêu cầu bị "
          "bỏ qua, nên ứng dụng bản cũ vẫn nhận mã 200. Mọi đầu vào sai, như quá 5.000 giao dịch, top_n ngoài khoảng, tên "
          "danh mục 256 ký tự hay số tiền âm, đều nhận mã 422; mã 413 chỉ thuộc /donut/scan khi ảnh quá lớn. Số thực "
          "trong kết quả được làm tròn 4 chữ số, riêng khoảng cách ngày làm tròn 1 chữ số."),
    ("table", "Hợp đồng JSON của POST /spade/analyze", "3", [1800, 3504, 3200],
     ["Trường", "Nội dung", "Ghi chú"],
     [["transactions[]", "category, amount, date (ISO 8601, tối đa 40 ký tự), isExpense", "Yêu cầu; amount từ 0 đến 10¹²"],
      ["status", "OK hoặc INSUFFICIENT_DATA", "Phản hồi"],
      ["patterns[]", "itemsets, support, weight, weightedSupport, weeks", "Cắt ở top_n; thêm ba trường cũ pattern, count, wsupport cho ứng dụng bản trước"],
      ["rules[]", "antecedent, consequent, support, antecedentSupport, confidence, laplaceConfidence, lift, weeks", "Cắt ở top_n"],
      ["habits[]", "category, occurrences, meanGapDays, stdGapDays, lastDate, nextExpectedDate", "Cắt ở top_n; vẫn trả khi INSUFFICIENT_DATA"],
      ["categories[]", "category, total, share (0 đến 1), weeks", "Sắp theo tổng giảm dần; vẫn trả khi INSUFFICIENT_DATA"],
      ["meta", "algorithm, weeksWithData, minWeeks, windowWeeks, minSupport, rawSupportBound, maxWeight", "algorithm là “WCM-SPADE”"]],
     SRC, "t_json"),
    ("p", "Ứng dụng di động gửi cho /spade/analyze các khoản chi của 26 tuần gần nhất, tính từ 00:00 thứ Hai của tuần hôm "
          "nay lùi 25 tuần, không gồm khoản thu và khoản góp tiết kiệm, và không phụ thuộc bộ chọn khoảng thời gian trên "
          "màn hình; nó không gửi top_n và min_sup_factor nên server dùng mặc định. Với /spade/recommend, ứng dụng gửi "
          "thu chi của 7 tháng lịch kể từ ngày 1 (trừ khoản góp tiết kiệm) cùng mục tiêu tiết kiệm khẩn cấp nhất. Tab AI "
          "dùng các tiêu đề thẻ sau, lấy từ tệp ARB tiếng Việt: “Mẫu Chi Tiêu Tuần Tự” cho mẫu, “Thói quen cần lưu ý” "
          "cho luật (câu “sau khi chi A, bạn chi tiếp B trong cùng tuần”), “Thói quen định kỳ” cho thói quen và “Gợi ý "
          "phân bổ tiền” cho lời khuyên ngân sách. Khi chưa đủ tuần, thẻ mẫu nói “Mới có {weeks} tuần có chi tiêu; cần "
          "ít nhất {minWeeks} tuần để tìm mẫu tuần tự.”"),
]

# ---------------------------------------------------------------------------------------------------------------------
# Chương 4: mục 4.5.3
# ---------------------------------------------------------------------------------------------------------------------
CH4 = [
    ("h3", "Cài đặt phân tích chi tiêu và phân khúc khách hàng"),
    ("p", "Phần phân tích chi tiêu được tách thành các module nhỏ trong thư mục ai-service để mỗi module có một trách "
          "nhiệm và kiểm thử riêng; [[t_module]] liệt kê chúng cùng phần việc của Core Backend trong phân khúc RFM."),
    ("table", "Module của phân tích chi tiêu và phân khúc RFM", "4", [2700, 5804],
     ["Module", "Trách nhiệm"],
     [["ai_service.py", "Khai báo SpadeRequest, RecommendRequest, AdminSegmentRequest và ba endpoint /spade/analyze, /spade/recommend, /admin/segment; kiểm tra đầu vào bằng Pydantic, mã 422 khi sai"],
      ["spending_data.py", "Lọc khoản chi, chuẩn hóa NFC, bỏ ngày sau ngày mai, cắt cửa sổ 26 tuần ISO, dựng chuỗi tuần và tổng chi theo danh mục"],
      ["local_time.py", "Đổi ngày về múi giờ cố định UTC+7; đầu vào hỏng trả None thay vì ném lỗi"],
      ["wcm_spade.py", "Lớp WCMSpade (id-list, CMAP, trọng số, tỉa, lọc mẫu đóng) và hàm sequential_rules (luật từ id-list thô)"],
      ["spending_analysis.py", "Ghép các bước, quyết định status, dựng phản hồi camelCase gồm patterns, rules, habits, categories và meta"],
      ["spending_habits.py", "Thói quen định kỳ: khoảng cách ngày, hệ số biến thiên, ngày kế tiếp"],
      ["budget_advisor.py", "Gợi ý ngân sách theo tháng trọn vẹn, nhóm thiết yếu, tùy ý, trung tính"],
      ["rfm_segmentation.py", "Chấm ngũ phân vị R, F, M và luật bảy nhóm"],
      ["CustomerSegmentationService (Core Backend)", "Tính R, F, M từ PostgreSQL, gọi AI Service, kiểm tra câu trả lời và ghi nhãn"],
      ["AiSegmentClient (Core Backend)", "Gọi POST /admin/segment với thời gian chờ kết nối 5 giây, đọc 60 giây"]],
     SRC, "t_module"),
    ("p", "Ở Core Backend, phân khúc RFM chạy qua CustomerSegmentationService. Truy vấn SQL lấy các khoản chi trong 12 tháng "
          "gần nhất, bỏ danh mục “Tiết kiệm” và dùng LEFT JOIN nên người chưa có giao dịch vẫn có một dòng; Recency là số "
          "ngày từ lần chi gần nhất đến hiện tại (ngày tương lai được kẹp về hôm nay), hoặc 366 ngày nếu chưa có khoản "
          "chi nào. Lời gọi HTTP tới AI Service chạy trước và ngoài mọi giao dịch cơ sở dữ liệu, nên không giữ kết nối "
          "PostgreSQL trong lúc chờ. Câu trả lời bị từ chối nguyên khối, không ghi gì, nếu có user_id rỗng, không phải "
          "số, không nằm trong danh sách đã gửi hay trùng, hoặc nếu có nhãn lạ; lỗi mạng, thiếu trường segments hay mục "
          "không đúng dạng đều thành AiServiceUnavailableException và trả mã 503. Khi câu trả lời hợp lệ, toàn bộ nhãn "
          "được ghi trong một TransactionTemplate, mỗi nhóm bằng một câu UPDATE theo danh sách mã người dùng; người dùng "
          "đã gửi mà AI Service bỏ sót bị xóa nhãn cũ thay vì giữ nhãn của lần chạy trước. Nhãn cũ như VIP không còn thuộc "
          "enum CustomerSegment và bị bỏ qua khi hiển thị."),
    ("p", "AI Service có 209 test chạy xanh ở lần chạy gần nhất (pytest, tính cả các ca tham số hóa); [[t_test]] cho số hàm "
          "test của từng tệp. Các tệp test_wcm_spade.py và test_spade_rules.py kiểm tra khai phá và luật, trong đó có hai "
          "kịch bản cấy sẵn ở [[t_vidu]]; test_spending_analysis.py và test_spending_data.py kiểm tra dựng chuỗi và phản hồi; "
          "test_main.py kiểm tra các endpoint, trong đó có mã 422 cho đầu vào sai."),
    ("table", "Số hàm test của AI Service theo tệp", "4", [3700, 3804, 1000],
     ["Tệp", "Nhóm kiểm thử", "Số hàm"],
     [["test_wcm_spade.py", "Khai phá mẫu có trọng số", "18"],
      ["test_spade_rules.py", "Luật tuần tự, kịch bản cấy sẵn", "18"],
      ["test_spending_analysis.py", "Ghép các bước, phản hồi", "7"],
      ["test_spending_data.py", "Lọc, cửa sổ, chuỗi tuần", "11"],
      ["test_spending_habits.py", "Thói quen định kỳ", "7"],
      ["test_budget_advisor.py", "Gợi ý ngân sách", "11"],
      ["test_rfm_segmentation.py", "Chấm điểm và bảy nhóm RFM", "12"],
      ["test_main.py", "Các endpoint của AI Service", "26"],
      ["test_receipt_postprocess.py", "Hậu xử lý Regex (mục 4.5.2)", "16"]],
     SRC, "t_test"),
]

INSERT_AFTER = [
    ("Điều kiện dừng ở dòng thứ tư của Bảng 2.38", CH2),
    ("Phần cài đặt mô-đun này, cách nối vào /donut/scan", CH3),
    # Chương 4: sau đoạn cuối của mục 4.5.2, trước tiêu đề CÀI ĐẶT CORE BACKEND.
    ("Cờ valid bắt được 23 trong 201 trường", CH4),
]

PARA_REPLACE = [
    ("Quy trình này gồm hai phần. Phần thống kê do ứng dụng di động tính",
     ("p", "Quy trình này gồm hai phần. Phần thống kê do ứng dụng di động tính từ danh sách giao dịch của người dùng. Phần "
           "báo cáo thói quen chi tiêu do AI Service thực hiện: dựng chuỗi chi tiêu theo tuần, khai phá mẫu tuần tự có "
           "trọng số bằng thuật toán WCM-SPADE (module wcm_spade.py, dựa trên id-list dọc của SPADE [48]), sinh luật tuần tự "
           "từ id-list thô và tính các thói quen chi tiêu định kỳ; kèm phần gợi ý ngân sách dựa trên mục tiêu tiết kiệm. "
           "Bảng 2.5 đặc tả quy trình; cơ sở thuật toán nằm ở mục 2.6.")),
    ("Phần phân tích mô hình đã phát biểu bài toán trích xuất bốn trường",
     ("p", "Phần phân tích mô hình đã phát biểu bài toán trích xuất bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST dưới "
           "dạng sinh chuỗi từ ảnh, chỉ ra ba khó khăn của hướng dựa trên OCR với hóa đơn tiếng Việt chụp bằng điện thoại, và "
           "mô tả kiến trúc DONUT gồm bộ mã hóa Swin Transformer, bộ giải mã mBART và task token <s_seller> [5], [8], [10]. "
           "Chương cũng nêu hạn chế của DONUT, đặc biệt là việc không trả về vị trí trường và khả năng sinh chuỗi sai, cùng "
           "cách hệ thống giảm rủi ro bằng bước đối soát. Vấn đề tokenizer tiếng Việt của bản V3 và giải pháp mở rộng từ "
           "vựng Unigram ở bản V5 là cơ sở cho phần thiết kế mô hình AI. Mục 2.6 phân tích riêng bài toán phân tích chi "
           "tiêu: chuỗi theo tuần, mẫu tuần tự có trọng số WCM-SPADE, luật với độ tin cậy Laplace và lift, thói quen định "
           "kỳ, gợi ý ngân sách và phân khúc RFM bảy nhóm.")),
]

TEXT_REPLACE = [
    # Chương 3 – Web Admin: nhãn RFM cũ (review cuối, C1)
    ("với nút Chạy phân lớp AI tự động, biểu đồ tỉ trọng các nhãn VIP, ACTIVE, AT-RISK, CHURN.",
     "với nút Chạy Phân Lớp AI Tự Động và biểu đồ tỉ trọng bảy nhóm CHAMPIONS, LOYAL, NEW, NEED_ATTENTION, AT_RISK, "
     "HIBERNATING, LOST.", 1),
    # Chương 2: giới thiệu
    ("Mục 2.5 phân tích bài toán trích xuất bốn trường thông tin và kiến trúc của mô hình DONUT.",
     "Mục 2.5 phân tích bài toán trích xuất bốn trường thông tin và kiến trúc của mô hình DONUT. Mục 2.6 phân tích bài toán "
     "phân tích chi tiêu và phân khúc khách hàng.", 1),
    # 2.2.5 – đặc tả quy trình (Bảng 2.5)
    ("7. Ứng dụng gửi các giao dịch nằm trong khoảng thời gian đang chọn (danh mục, số tiền, ngày, loại thu/chi) tới AI Service.",
     "7. Ứng dụng gửi các khoản chi của 26 tuần gần nhất (danh mục, số tiền, ngày, loại thu/chi), không phụ thuộc khoảng "
     "thời gian đang chọn trên màn hình, tới AI Service.", 1),
    ("8. AI Service khai phá các mẫu chuỗi chi tiêu có độ dài tối đa 4, trả về mỗi mẫu dạng “A → B” kèm số lần xuất hiện, trọng số và độ hỗ trợ.",
     "8. AI Service dựng chuỗi theo tuần ISO, khai phá các mẫu tuần tự có trọng số (tối đa 4 item mỗi mẫu), sinh luật "
     "tuần tự và tính thói quen định kỳ, cơ cấu danh mục; mỗi mẫu gồm các itemset kèm số tuần chứa mẫu, trọng số và support "
     "có trọng số, mỗi luật kèm support, độ tin cậy Laplace và lift.", 1),
    ("gửi toàn bộ giao dịch cùng số tiền mục tiêu",
     "gửi thu chi của 7 tháng lịch gần nhất (AI Service dùng tối đa 6 tháng trọn vẹn trong đó) cùng số tiền mục tiêu", 1),
    ("8a. Khoảng thời gian có ít hơn 3 khoản chi hợp lệ: AI Service trả về danh sách mẫu rỗng kèm thông điệp giải thích.",
     "8a. Có chi tiêu ở ít hơn 8 tuần: AI Service trả trạng thái INSUFFICIENT_DATA, danh sách mẫu và luật rỗng (thói quen "
     "định kỳ và cơ cấu danh mục vẫn được trả); ứng dụng hiển thị thẻ “Chưa đủ dữ liệu”. Nếu người dùng chưa có khoản chi "
     "nào, ứng dụng không gọi AI Service.", 1),
    ("10a. Người dùng đổi khoảng thời gian hoặc chọn Làm mới: ứng dụng chỉ chạy lại bước 7–8.",
     "10a. Người dùng đổi khoảng thời gian: chỉ biểu đồ được vẽ lại, phân tích không đổi. Người dùng bấm nút làm mới trên thẻ "
     "phân tích: ứng dụng chạy lại bước 7–8.", 1),
    # 2.3 – UC13
    ("Người dùng xem các mẫu chi tiêu lặp lại do AI Service khai phá bằng WCM-SPADE và các gợi ý ngân sách theo mục tiêu tiết kiệm.",
     "Người dùng xem các mẫu chi tiêu tuần tự, luật “sau khi chi A thì chi B” và thói quen chi tiêu định kỳ do AI Service "
     "khai phá bằng WCM-SPADE, cùng các gợi ý ngân sách theo mục tiêu tiết kiệm.", 1),
    ("3. Ứng dụng gửi các giao dịch trong khoảng thời gian đang chọn tới AI Service (/spade/analyze).",
     "3. Ứng dụng gửi các khoản chi của 26 tuần gần nhất (không gồm khoản thu và khoản góp tiết kiệm) tới AI Service "
     "(/spade/analyze).", 1),
    ("4. AI Service khai phá các mẫu chuỗi chi tiêu có độ dài tối đa 4 dựa trên cách biểu diễn id-list của SPADE [48], trả về mỗi mẫu dạng “A → B” kèm số lần xuất hiện, trọng số và độ hỗ trợ.",
     "4. AI Service dựng chuỗi theo tuần, khai phá các mẫu tuần tự có trọng số dựa trên cách biểu diễn id-list của SPADE "
     "[48] (mỗi mẫu tối đa 4 item, các itemset cùng ngày), sinh luật tuần tự mà vế trái và vế phải đều là itemset cùng "
     "ngày, tính thói quen định kỳ và cơ cấu danh mục.", 1),
    ("gửi giao dịch cùng mục tiêu tiết kiệm gần hạn nhất",
     "gửi thu chi của 7 tháng lịch gần nhất cùng mục tiêu tiết kiệm gần hạn nhất", 1),
    ("4a. Khoảng thời gian có ít hơn 3 khoản chi: AI Service trả danh sách mẫu rỗng kèm thông điệp giải thích.",
     "4a. Có chi tiêu ở ít hơn 8 tuần: AI Service trả INSUFFICIENT_DATA, mẫu và luật rỗng, còn thói quen định kỳ và cơ cấu "
     "danh mục vẫn được trả.", 1),
    ("6a. Người dùng đổi khoảng thời gian hoặc chọn “Làm mới”: ứng dụng chạy lại bước 3–4.",
     "6a. Người dùng bấm nút làm mới hoặc kéo để làm mới: ứng dụng chạy lại bước 3–4; đổi khoảng thời gian chỉ vẽ lại biểu đồ.", 1),
    ("báo cáo phản ánh giao dịch của khoảng thời gian đang chọn.",
     "báo cáo phản ánh các khoản chi của 26 tuần gần nhất.", 1),
    # 2.3 – UC21 (RFM)
    ("4. Core Backend tính độ gần, tần suất và giá trị chi tiêu của mỗi người dùng và gửi tới AI Service (/admin/segment).",
     "4. Core Backend tính độ gần, tần suất và giá trị chi tiêu của mỗi người dùng trong 12 tháng gần nhất (chỉ khoản chi, "
     "không tính tiết kiệm) và gửi tới AI Service (/admin/segment).", 1),
    ("5. AI Service gán nhãn theo luật: CHURN, AT-RISK, VIP hoặc ACTIVE.",
     "5. AI Service chấm điểm R, F, M của từng người dùng theo ngũ phân vị rồi gán một trong bảy nhóm theo luật: CHAMPIONS, "
     "LOYAL, NEW, NEED_ATTENTION, AT_RISK, HIBERNATING hoặc LOST.", 1),
    ("trong đó AI Service xếp nhóm bằng các ngưỡng cố định cho ba chỉ số.",
     "trong đó AI Service chấm điểm từng chỉ số theo ngũ phân vị rồi xếp người dùng vào bảy nhóm bằng luật ưu tiên.", 1),
    # Tác nhân AI Service
    ("khai phá mẫu chi tiêu và gợi ý ngân sách (/spade/analyze, /spade/recommend), phân khúc khách hàng theo RFM (/admin/segment).",
     "khai phá mẫu, luật tuần tự và thói quen định kỳ trong chi tiêu cùng gợi ý ngân sách (/spade/analyze, "
     "/spade/recommend), phân khúc khách hàng theo RFM thành bảy nhóm (/admin/segment).", 1),
    # Chương 3
    ("phân tích chuỗi chi tiêu (WCM-SPADE [48]); phân khúc RFM [49]",
     "phân tích chi tiêu: mẫu tuần tự, luật, thói quen định kỳ (WCM-SPADE [48], [76], [77]) và gợi ý ngân sách; phân khúc "
     "RFM bảy nhóm [49]", 1),
    ("liệt kê các mẫu chuỗi do WCM-SPADE [48] tìm được kèm tần suất và độ hỗ trợ có trọng số, và thẻ gợi ý phân bổ khi người dùng có mục tiêu tiết kiệm",
     "liệt kê các chuỗi do WCM-SPADE [48] tìm được kèm số tuần chứa chuỗi, thẻ Thói quen cần lưu ý (luật “sau khi chi A, bạn "
     "chi tiếp B trong cùng tuần”), thẻ Thói quen định kỳ (khoảng cách ngày giữa các lần chi) và thẻ Gợi ý phân bổ tiền khi "
     "người dùng có mục tiêu tiết kiệm", 1),
    ("Khi chưa có giao dịch, màn hình chỉ hiển thị thông báo “Chưa có dữ liệu”.",
     "Bộ chọn khoảng thời gian chỉ vẽ lại các biểu đồ; phân tích WCM-SPADE luôn dùng 26 tuần gần nhất. Khi chưa có giao dịch, "
     "màn hình chỉ hiển thị thông báo “Chưa có dữ liệu”.", 1),
    ("AI Service khai phá mẫu chuỗi bằng WCM-SPADE [48] và đưa ra gợi ý ngân sách.",
     "AI Service khai phá mẫu, luật tuần tự và thói quen định kỳ bằng WCM-SPADE [48] và đưa ra gợi ý ngân sách.", 1),
    ("sau khi lọc theo khoảng thời gian đang chọn, ứng dụng gửi giao dịch tới POST /spade/analyze, và nếu có mục tiêu tiết kiệm thì gửi thêm tới POST /spade/recommend.",
     "ứng dụng lọc ra các khoản chi của 26 tuần gần nhất (khoảng thời gian đang chọn chỉ ảnh hưởng đến biểu đồ) và gửi tới "
     "POST /spade/analyze; nếu có mục tiêu tiết kiệm thì gửi thêm thu chi của 7 tháng lịch tới POST /spade/recommend.", 1),
    # Chương 4
    ("Tìm chuỗi chi tiêu phổ biến bằng SPADE [48]",
     "Mẫu tuần tự, luật, thói quen định kỳ và cơ cấu danh mục bằng WCM-SPADE [48], [76]; mã 422 khi đầu vào sai", 1),
    ("Gợi ý cắt giảm chi tiêu theo mục tiêu tiết kiệm",
     "Gợi ý cắt giảm chi tiêu theo mục tiêu tiết kiệm (tối đa 6 tháng trọn vẹn); mã 422 khi chưa đủ lịch sử", 1),
    ("Phân khúc RFM theo luật cho Web Admin [49]",
     "Phân khúc RFM: ngũ phân vị và luật bảy nhóm, cho Web Admin [49]", 1),
    ("gọi /ai/spade/analyze để hiển thị báo cáo thói quen chi tiêu theo khoảng thời gian người dùng chọn.",
     "gọi /ai/spade/analyze với các khoản chi của 26 tuần gần nhất để hiển thị báo cáo thói quen chi tiêu (bộ chọn khoảng "
     "thời gian chỉ đổi biểu đồ).", 1),
    ("nút chạy phân khúc RFM gọi /admin/segment của AI Service.",
     "nút “Chạy Phân Lớp AI Tự Động” gửi POST /admin/ajax/segmentation/run, Core Backend gọi /admin/segment của AI Service "
     "rồi trang hiển thị biểu đồ tỷ trọng bảy nhóm và bảng 10 người dùng mới nhất kèm tên nhóm tiếng Việt.", 1),
]

PARA_LINES_AFTER = [
    ("5a. AI Service không phản hồi hoặc không trả kết quả",
     ["5b. AI Service bỏ sót một người dùng đã gửi: Core Backend xóa nhãn cũ của người dùng đó thay vì giữ lại."]),
]
