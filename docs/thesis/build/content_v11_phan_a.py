# Nội dung phiên K1 (31/10/2026): rà soát văn bản phần đầu, Mở đầu, Chương 1 và Kết luận mục 4 theo loi_phan_A.md.
# Sinh KhoaLuan_KLCN175_v11.docx từ v10 bằng builder.py. Chỉ sửa chính tả, dấu câu, câu văn; không đổi ý chính, không thêm
# hoặc bớt mục, hình, bảng. Số liệu giữ nguyên như v10 (chỉ đổi cách viết 0,9524 thành 95,24%). Không đụng các dòng [T7.x],
# [Nhóm], Chương 5, Kết luận mục 1-3, danh mục viết tắt và tài liệu tham khảo (việc của K7 và K8).
SESSION_TAG = None
SECTIONS = {}

PARA_REPLACE = [
    # Mở đầu, mục 6 (dòng 29): bỏ cách lặp tiêu đề chương rồi liệt kê lại
    ("Chương 1 – Khảo sát hệ thống và tổng quan",
     ("b1", "**Chương 1** trình bày kết quả khảo sát nhu cầu, quy trình ghi chép chi tiêu, các ứng dụng hiện có và biểu mẫu "
            "hóa đơn, cùng phần tổng quan về các hướng trích xuất thông tin hóa đơn, các công trình liên quan và công nghệ sử dụng.")),
    ("Chương 2 – Phân tích hệ thống",
     ("b1", "**Chương 2** trình bày việc mô hình hóa nghiệp vụ, đặc tả use case hệ thống, sơ đồ lớp mức phân tích, cùng phân "
            "tích bài toán và mô hình DONUT.")),
    ("Chương 3 – Thiết kế hệ thống",
     ("b1", "**Chương 3** trình bày kiến trúc tổng thể, cơ sở dữ liệu, bộ nhớ đệm, API và bảo mật, giao diện, sơ đồ lớp thiết "
            "kế, thiết kế chức năng và thiết kế mô hình AI.")),
    ("Chương 4 – Cài đặt hệ thống",
     ("b1", "**Chương 4** trình bày môi trường, chuẩn bị dữ liệu, huấn luyện DONUT, cài đặt AI Service, Core Backend, ứng dụng "
            "di động, Web Admin và đóng gói Docker.")),
    ("Chương 5 – Thử nghiệm và triển khai",
     ("b1", "**Chương 5** trình bày việc đánh giá mô hình, kiểm thử chức năng, kiểm thử API và hiệu năng, cùng triển khai hệ thống.")),
    # 1.3.4 (dòng 44, 45): ba nhận xét thành ba gạch đầu dòng ngắn (các gạch đầu dòng chèn ở INSERT_AFTER)
    ("Từ Bảng 1.1, nhóm rút ra ba nhận xét",
     ("p", "Từ Bảng 1.1, nhóm rút ra ba nhận xét sau.")),
    # 1.7.4 (dòng 82): tách đoạn trộn Redis và MongoDB; phần MongoDB nằm ở INSERT_AFTER
    ("Redis là kho dữ liệu khóa – giá trị lưu trong",
     ("p", "Redis là kho dữ liệu khóa – giá trị lưu trong bộ nhớ, thường dùng làm bộ nhớ đệm [36]. Hệ thống dùng Redis để lưu "
           "tạm kết quả các truy vấn thống kê (bảng điều khiển của người dùng và của quản trị viên) với thời gian sống 45–60 "
           "giây, và xóa bộ đệm sau khi giao dịch cơ sở dữ liệu được xác nhận.")),
    # Kết luận mục 4 (dòng 90, 91, 92)
    ("Thứ nhất, chuyển hàng đợi quét hóa đơn lên máy chủ",
     ("p", "Thứ nhất, chuyển hàng đợi quét hóa đơn lên máy chủ. Hiện hàng đợi nằm trên điện thoại nên chỉ chạy khi ứng dụng đang "
           "mở. Nếu đặt hàng đợi ở phía máy chủ (ảnh được tải lên trước, rồi Core Backend hoặc một tiến trình riêng gọi AI "
           "Service và gửi thông báo khi xử lý xong), việc đọc hóa đơn vẫn tiếp tục khi người dùng đã đóng ứng dụng và có thể "
           "thực hiện từ nhiều thiết bị. Nhóm chưa làm vì hai lý do: thời hạn nộp báo cáo, và AI Service hiện chỉ được cấp 3 GB "
           "bộ nhớ, đủ cho một lượt suy luận tại một thời điểm. Muốn xử lý song song cho nhiều người dùng cần thêm máy hoặc một "
           "hàng đợi có điều phối.")),
    # Kết luận mục 4 (dòng 93, 94): webhook được giải thích, phần việc của Core Backend thành ba gạch đầu dòng
    ("Thứ hai, liên kết ngân hàng thật",
     ("p", "Thứ hai, liên kết ngân hàng thật. Màn hình “Dịch vụ liên kết” hiện chỉ là bản minh họa với dữ liệu giả lập. Một cách "
           "khả thi cho tài khoản cá nhân là nhận webhook (lời gọi ngược do dịch vụ gửi tới máy chủ) báo biến động số dư từ các "
           "dịch vụ trung gian như SePay [71] hoặc Casso [72]. Mỗi khi tài khoản đã liên kết có giao dịch mới, dịch vụ gửi một "
           "yêu cầu HTTP POST tới máy chủ, kèm chữ ký hoặc khóa bí mật để xác thực. Khi đó, Core Backend cần một endpoint công "
           "khai thực hiện ba việc:")),
]

INSERT_AFTER = [
    ("Từ Bảng 1.1, nhóm rút ra ba nhận xét", [
        ("b1", "Các chức năng nền tảng (nhập thu chi, danh mục, ngân sách, báo cáo) đã phổ biến, nên hệ thống của đề tài phải "
               "có đủ các chức năng này để dùng được trong thực tế."),
        ("b1", "Hai ứng dụng lớn giảm công nhập liệu bằng cách liên kết ngân hàng, vốn không áp dụng được cho các khoản chi "
               "bằng tiền mặt có hóa đơn giấy."),
        ("b1", "Chức năng quét hóa đơn bằng AI đã xuất hiện trên thị trường nhưng ở dạng đóng: người dùng không biết trường nào "
               "được trích xuất và kết quả có đáng tin hay không. Cả ba ứng dụng đều chưa công bố mô hình trích xuất các trường "
               "thông tin cụ thể từ hóa đơn tiếng Việt kèm độ chính xác đo được."),
    ]),
    ("Redis là kho dữ liệu khóa – giá trị lưu trong", [
        ("p", "MongoDB là cơ sở dữ liệu hướng tài liệu, lưu bản ghi dạng BSON (Binary JSON, tức JSON nhị phân) không cần lược đồ "
              "cố định [37]. Nhóm dùng MongoDB để lưu nhật ký thô của các lần suy luận AI, vì cấu trúc kết quả trả về của mô hình "
              "có thể thay đổi giữa các phiên bản."),
    ]),
    ("Thứ hai, liên kết ngân hàng thật", [
        ("b1", "Kiểm tra chữ ký của yêu cầu."),
        ("b1", "Chống nhận trùng theo mã giao dịch của bên gửi."),
        ("b1", "Tạo giao dịch chờ người dùng xác nhận danh mục."),
        ("p", "Hướng này cần tài khoản và đăng ký với nhà cung cấp."),
    ]),
]

TEXT_REPLACE = [
    # ---- Mở đầu ----
    # dòng 14
    ("Dòng tiền của một cá nhân vì thế phân tán trên nhiều kênh: tiền mặt, thẻ ngân hàng, ví điện tử.",
     "Vì vậy, dòng tiền của một cá nhân thường phân tán trên nhiều kênh như tiền mặt, thẻ ngân hàng và ví điện tử.", 1),
    # dòng 12, 13
    ("bố cục khác nhau giữa các chuỗi cửa hàng; ảnh chụp bằng điện thoại còn bị nghiêng",
     "bố cục khác nhau giữa các chuỗi cửa hàng. Ảnh chụp bằng điện thoại còn bị nghiêng", 1),
    ("đọc tên cửa hàng, thời gian, tổng tiền rồi gõ lại", "đọc tên cửa hàng, thời gian và tổng tiền rồi gõ lại", 1),
    # dòng 15
    ("bỏ hẳn bước OCR (hướng tiếp cận OCR-free): mô hình nhận ảnh",
     "theo hướng tiếp cận OCR-free, tức bỏ hẳn bước OCR. Mô hình nhận ảnh", 1),
    # dòng 16
    ("Từ hai nhận xét trên, nhóm chọn đề tài",
     "Từ thực trạng nhập liệu thủ công và khả năng của hướng OCR-free, nhóm chọn đề tài", 1),
    # dòng 17 (chỉ Mở đầu; bảng ở Chương 2 thuộc K2)
    ("huấn luyện DONUT trích xuất bốn trường Seller, Address, Timestamp, Total Cost từ",
     "huấn luyện DONUT trích xuất bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST từ", 1),
    ("bốn trường thông tin Seller, Address, Timestamp, Total Cost từ",
     "bốn trường thông tin SELLER, ADDRESS, TIMESTAMP, TOTAL_COST từ", 1),
    ("Seller (tên người bán), Address (địa chỉ), Timestamp (thời gian), Total Cost (tổng tiền)",
     "SELLER (tên người bán), ADDRESS (địa chỉ), TIMESTAMP (thời gian), TOTAL_COST (tổng tiền)", 1),
    # dòng 18
    ("(kiến trúc vi dịch vụ, chia hệ thống thành các dịch vụ nhỏ triển khai độc lập) để AI Service hoạt động độc lập với các luồng xử lý trung tâm",
     "(kiến trúc vi dịch vụ, chia hệ thống thành các dịch vụ nhỏ có thể triển khai độc lập), trong đó AI Service là một dịch vụ riêng, tách biệt với các luồng xử lý trung tâm", 1),
    # dòng 19
    ("không trích xuất danh sách mặt hàng, thuế hay mã số thuế",
     "không trích xuất danh sách mặt hàng, tiền thuế hay mã số thuế", 1),
    # dòng 21
    ("(mã nguồn tự chuyển sang GPU nếu máy chủ có)", "(mã nguồn tự dùng GPU nếu máy chủ có GPU)", 1),
    # dòng 49 (Mở đầu ghi ngắn, Chương 1 mục 1.4.1 mô tả đầy đủ)
    ("sử dụng có 6.351 ảnh, chia thành 5.080 ảnh huấn luyện, 635 ảnh kiểm định và 636 ảnh kiểm thử",
     "sử dụng có 6.351 ảnh, chia theo tỉ lệ xấp xỉ 80/10/10 cho huấn luyện, kiểm định và kiểm thử (số ảnh của từng tập nêu ở mục 1.4.1)", 1),
    # dòng 22
    ("BART [9] và DONUT [5]; các công trình trích xuất thông tin hóa đơn dựa trên OCR [17], [18], [19], [23] và các bộ dữ liệu SROIE [21], CORD [20], MC-OCR [22]; tài liệu chính thức của các công nghệ sử dụng.",
     "BART [9] và DONUT [5]. Nhóm cũng đọc các công trình trích xuất thông tin hóa đơn dựa trên OCR [17], [18], [19], [23] và các bộ dữ liệu SROIE [21], CORD [20], MC-OCR [22], cùng tài liệu chính thức của các công nghệ sử dụng.", 1),
    # dòng 24
    ("và chạy lại trên GitHub Actions ở mỗi lần đẩy mã.", "và được chạy lại trên GitHub Actions mỗi khi đẩy mã lên kho.", 1),
    # dòng 25
    ("phân công chi tiết cho từng thành viên nằm ở Bảng phân công nhiệm vụ ở phần đầu quyển",
     "phân công chi tiết cho từng thành viên được nêu trong Bảng phân công nhiệm vụ ở phần đầu quyển", 1),

    # ---- Chương 1 ----
    # dòng 30
    ("Chương này trình bày kết quả khảo sát làm cơ sở cho việc phân tích và thiết kế ở các chương sau.",
     "Chương này gồm hai phần là khảo sát và tổng quan, làm cơ sở cho việc phân tích ở Chương 2 và thiết kế ở Chương 3.", 1),
    # dòng 31, 32
    ("Tại Việt Nam, 71% người trưởng thành có tài khoản, 62% thực hiện hoặc nhận thanh toán số, 45% có tiết kiệm qua kênh chính thức và 98% sở hữu điện thoại di động [41].",
     "Tại Việt Nam, 45% người trưởng thành có tiết kiệm qua kênh chính thức và 98% sở hữu điện thoại di động [41], bên cạnh tỉ lệ có tài khoản và thanh toán số đã nêu ở phần Mở đầu.", 1),
    ("lớn nhất thế giới [41], nên một bộ phận người dùng vẫn chi tiêu chủ yếu bằng tiền mặt và nhận hóa đơn giấy.",
     "lớn nhất thế giới [41]. Theo nhận định của nhóm, chênh lệch này cho thấy một bộ phận người dùng có thể vẫn chi tiêu chủ yếu bằng tiền mặt và nhận hóa đơn giấy.", 1),
    # dòng 33
    ("Sau khi nhập hết, công cụ ghi chép cộng dồn chi tiêu theo danh mục; người dùng đối chiếu với hạn mức đã đặt và tự điều chỉnh nếu vượt.",
     "Sau khi nhập xong, người dùng cộng dồn chi tiêu theo danh mục (bằng tay hoặc bằng công thức của bảng tính), đối chiếu với hạn mức đã đặt và tự điều chỉnh nếu vượt.", 1),
    # dòng 34
    ("Khi dùng ứng dụng quản lý tài chính, bước tổng hợp và so sánh với hạn mức được tự động hóa: ứng dụng tự cộng dồn, vẽ biểu đồ và cảnh báo khi vượt ngân sách.",
     "Ứng dụng quản lý tài chính tự cộng dồn chi tiêu, vẽ biểu đồ và cảnh báo khi vượt ngân sách.", 1),
    # dòng 35
    ("dễ gõ nhầm số chữ số.", "dễ gõ thừa hoặc thiếu chữ số.", 1),
    # dòng 37, 38 (Money Lover)
    ("điểm đánh giá 4,1 tại thời điểm khảo sát", "điểm đánh giá 4,1/5 tại thời điểm khảo sát", 1),
    ("Theo mô tả của nhà phát triển, ứng dụng cho phép nhập nhanh",
     "Theo mô tả của nhà phát triển, ứng dụng (Hình 1.2) cho phép nhập nhanh", 1),
    (" Hình 1.2 minh họa giao diện chính của ứng dụng.", "", 1),
    # dòng 38, 40 (MISA MoneyKeeper)
    ("Ứng dụng quản lý nhiều loại tài khoản", "Ứng dụng (Hình 1.3) quản lý nhiều loại tài khoản", 1),
    ("cảnh báo trước khi chi vượt, xuất báo cáo ra Excel/PDF, đồng bộ dữ liệu giữa điện thoại và máy tính bảng, và liên kết ngân hàng để giao dịch tự cập nhật [43]. Giao diện ứng dụng được minh họa ở Hình 1.3.",
     "cảnh báo trước khi chi vượt [43]. Ngoài ra, ứng dụng xuất báo cáo ra Excel/PDF, đồng bộ dữ liệu giữa điện thoại và máy tính bảng, đồng thời liên kết ngân hàng để giao dịch tự cập nhật [43].", 1),
    # dòng 38, 42 (Sổ thu chi)
    ("Ứng dụng đại diện cho nhóm sổ thu chi đơn giản", "Ứng dụng (Hình 1.4) đại diện cho nhóm sổ thu chi đơn giản", 1),
    (" Hình 1.4 minh họa giao diện ứng dụng.", "", 1),
    ("có lượt tải cao nhất (trên 5 triệu) khi tìm kiếm “sổ thu chi”",
     "có lượt tải cao nhất (trên 5 triệu) trong kết quả tìm kiếm “sổ thu chi”", 1),
    # dòng 43
    ("Vì vậy, khi đổi điện thoại, người dùng có thể phải tự sao lưu và chuyển dữ liệu.",
     "Do đó, theo suy luận của nhóm, khi đổi điện thoại, người dùng có thể phải tự sao lưu và chuyển dữ liệu.", 1),
    # dòng 46
    ("và tập trung vào phần còn thiếu: một mô hình trích xuất bốn trường thông tin từ ảnh hóa đơn tiếng Việt được huấn luyện và đánh giá công khai theo từng trường, cùng quy trình đối soát",
     "và tập trung vào hai việc: huấn luyện một mô hình trích xuất bốn trường thông tin từ ảnh hóa đơn tiếng Việt kèm báo cáo độ chính xác theo từng trường, và xây dựng quy trình đối soát", 1),
    # dòng 50
    ("Khó khăn khi đọc tự động nằm ở chỗ tên người bán", "Khó khăn khi đọc tự động là tên người bán", 1),
    ("thay vì tên cửa hàng mà người dùng quen gọi, và địa chỉ thường viết tắt",
     "chứ không phải tên cửa hàng mà người dùng quen gọi. Địa chỉ cũng thường viết tắt", 1),
    # dòng 51
    ("phí phục vụ", "phí dịch vụ", 1),
    # dòng 47, 57
    ("Tỉ lệ tương tự xuất hiện ở tập kiểm định (49/635 ảnh đủ bốn trường) và tập kiểm thử (59/636).",
     "Tỉ lệ tương tự xuất hiện ở tập kiểm định (49/635 ảnh đủ bốn trường) và tập kiểm thử (59/636). Phần lớn ô trống là do nhãn gốc bị bỏ sót chứ không phải do hóa đơn thiếu thông tin, và nhóm đã gán nhãn lại tập dữ liệu ở Chương 4.", 1),
    ("ở Chương 5: trường có nhãn rỗng phải được tính riêng để không làm sai lệch độ chính xác.",
     "ở Chương 5: các ảnh có nhãn rỗng ở một trường phải được tách riêng để không làm sai lệch độ chính xác của trường đó.", 1),
    # dòng 54
    ("cho hóa đơn tiếng Việt [22]. Bảng 1.3 tóm tắt",
     "cho hóa đơn tiếng Việt [22]. Trong nhãn của nhóm, SELLER ADDRESS được đặt tên là ADDRESS và TOTAL COST là TOTAL_COST. Bảng 1.3 tóm tắt", 1),
    # dòng 59
    ("Tesseract là một bộ máy OCR tiêu biểu: ảnh nhị phân được phân tích thành phần liên thông, các đường viền được gom thành khối, khối được xếp thành dòng văn bản rồi tách thành từ; việc nhận dạng diễn ra qua hai lượt, từ nhận dạng tốt ở lượt đầu được dùng làm dữ liệu cho bộ phân lớp thích nghi [17].",
     "Tesseract là một bộ máy OCR tiêu biểu. Ảnh nhị phân được phân tích thành phần liên thông, các đường viền được gom thành khối, và khối được xếp thành dòng văn bản rồi tách thành từ [17]. Việc nhận dạng diễn ra qua hai lượt: từ nhận dạng tốt ở lượt đầu được dùng làm dữ liệu cho bộ phân lớp thích nghi [17].", 1),
    # dòng 60
    ("chuỗi khớp mẫu ngày dd/mm/yyyy", "chuỗi khớp mẫu ngày/tháng/năm dạng dd/mm/yyyy", 1),
    # dòng 9, 62 (thang điểm), 64
    ("độ phủ) 0,9524 [18]", "độ phủ) 95,24% [18]", 1),
    ("ảnh tài liệu scan, rồi tinh chỉnh", "ảnh tài liệu quét, rồi tinh chỉnh", 1),
    ("LayoutLMv3 thống nhất việc che (masking) văn bản và che ảnh khi tiền huấn luyện, nhưng vẫn dùng một bộ OCR có sẵn",
     "LayoutLMv3 dùng chung một cách che (masking) cho cả văn bản và ảnh khi tiền huấn luyện, nhưng vẫn cần một bộ OCR có sẵn", 1),
    # dòng 66, 9
    ("chuỗi token có thể chuyển một – một thành JSON", "chuỗi token có thể chuyển đổi một-một sang JSON", 1),
    ("trên 11 triệu ảnh scan tiếng Anh của IIT-CDIP", "trên 11 triệu ảnh quét tiếng Anh của IIT-CDIP", 1),
    # dòng 68 (tách câu; không đổi số liệu)
    ("với thời gian suy luận 1,2 giây mỗi ảnh; các mô hình dựa trên OCR được so sánh trong cùng bảng như LayoutLM (F1 78,4) và LayoutLMv2 (F1 78,9) cần 1,7 giây mỗi ảnh; số tham số công bố của các mô hình này chưa gồm bộ OCR [5].",
     "với thời gian suy luận 1,2 giây mỗi ảnh [5]. Trong cùng bảng, các mô hình dựa trên OCR như LayoutLM (F1 78,4) và LayoutLMv2 (F1 78,9) cần 1,7 giây mỗi ảnh [5]. Số tham số công bố của các mô hình này chưa gồm bộ OCR [5].", 1),
    # dòng 69 (Bảng 1.4)
    ("Khá, cần dữ liệu đủ đa dạng", "Tốt nếu có đủ dữ liệu đa dạng", 1),
    ("Thấp hơn, đầu ra là chuỗi sinh", "Thấp hơn hai hướng còn lại, đầu ra là chuỗi sinh", 1),
    # dòng 70
    ("Hạn chế của lựa chọn này cũng được ghi nhận: tokenizer gốc", "Lựa chọn này có ba hạn chế: tokenizer gốc", 1),
    # dòng 9, 71, 72
    ("1.000 ảnh hóa đơn scan nguyên tờ", "1.000 ảnh hóa đơn quét nguyên tờ", 1),
    ("các công trình sau như LayoutLM sử dụng bốn loại thực thể company, date, address, total [18], tương ứng gần như hoàn toàn với bốn trường của đề tài.",
     "các công trình đánh giá trên SROIE như LayoutLM sử dụng bốn loại thực thể “company”, “date”, “address”, “total” [18], gần trùng với bốn trường của đề tài.", 1),
    ("Hmean (trung bình điều hòa của độ chính xác và độ phủ) 90,49%", "Hmean (tương đương F1) 90,49%", 1),
    ("Chủ yếu tiếng Anh và chữ số; ảnh scan", "Chủ yếu tiếng Anh và chữ số; ảnh quét", 1),
    # dòng 73, 74
    ("nhãn ngữ nghĩa nhiều cấp dạng JSON.", "nhãn ngữ nghĩa nhiều cấp dạng JSON [20].", 1),
    ("CORD là một trong các bộ dữ liệu được dùng để đánh giá DONUT [5]; mô hình nền mà nhóm tinh chỉnh cũng là bản DONUT đã tinh chỉnh trên CORD (donut-base-finetuned-cord-v2), sau đó được chuyển sang bốn trường của hóa đơn tiếng Việt.",
     "CORD là một trong các bộ dữ liệu được dùng để đánh giá DONUT [5]. Nhóm lấy bản DONUT đã tinh chỉnh trên CORD (donut-base-finetuned-cord-v2) làm mô hình nền, rồi tinh chỉnh tiếp trên bốn trường của hóa đơn tiếng Việt.", 1),
    # dòng 75, 76
    ("MC-OCR là công trình gần nhất với đề tài: cùng ngôn ngữ, cùng điều kiện chụp và cùng bốn trường thông tin.",
     "MC-OCR gần với đề tài nhất vì cùng dùng ảnh hóa đơn tiếng Việt chụp bằng điện thoại và bốn trường thông tin.", 1),
    ("RMSE 0,10 và CER 0,22 [22]", "RMSE 0,10 và CER 0,22 (tức 22% ký tự bị đọc sai) [22]", 1),
    # dòng 77
    ("Dart SDK ^3.10.8", "Dart SDK từ 3.10.8", 1),
    # dòng 78
    ("được bộ lọc JWT kiểm tra trước khi xử lý, mật khẩu được băm bằng BCrypt.",
     "được bộ lọc JWT kiểm tra trước khi xử lý. Mật khẩu được băm bằng BCrypt.", 1),
    # dòng 81
    ("khóa duy nhất và khóa dòng [35]", "khóa duy nhất và khóa mức dòng (row-level lock) [35]", 1),
    ("được khóa dòng bi quan", "được khóa bi quan mức dòng", 1),
    # dòng 83
    ("nhiều container cùng mạng, volume (vùng lưu trữ)", "nhiều container, mạng chung, volume (vùng lưu trữ)", 1),
    # dòng 84, 85
    ("Chương 1 đã xác định nhu cầu và người dùng mục tiêu của hệ thống, chỉ ra bước nhập liệu từ hóa đơn là khâu tốn công và dễ sai của quy trình ghi chép chi tiêu.",
     "Chương này xác định người dùng mục tiêu và chỉ ra nhập liệu từ hóa đơn là khâu tốn công và dễ sai trong quy trình ghi chép chi tiêu.", 1),
    ("trong đó MC-OCR dùng đúng bốn trường của đề tài.",
     "trong đó MC-OCR dùng cùng bốn trường với đề tài. Về công nghệ, hệ thống được xây dựng trên Flutter (ứng dụng di động), Spring Boot (Core Backend), FastAPI (AI Service), cùng PostgreSQL, Redis, MongoDB và Docker.", 1),

    # ---- Kết luận mục 4 ----
    # dòng 89
    ("chủ yếu là những phần nhóm cố ý chưa làm để kịp thời hạn nộp ngày 06/11/2026.",
     "chủ yếu là những phần nhóm chưa thực hiện do giới hạn thời gian (hạn nộp ngày 06/11/2026).", 1),
    # dòng 95, 96
    ("Mã PIN cũ đã bị xóa vì không bảo vệ được gì; làm lại đúng cách cần lưu mã đã băm",
     "Mã PIN trước đây đã được loại bỏ vì không có tác dụng bảo vệ dữ liệu. Để làm lại đúng cách, cần lưu mã PIN đã băm", 1),
    ("nằm ngoài phạm vi đợt hoàn thiện hiện tại.", "nằm ngoài phạm vi khóa luận.", 1),
    # dòng 97, 98
    ("Khác với checkout có clientId, POST /api/savings/{id}/contributions",
     "Khác với thao tác ghi giao dịch POST /api/transactions/checkout (có clientId), POST /api/savings/{id}/contributions", 1),
    ("lưu cùng khoản chi và có ràng buộc duy nhất như (user_id, client_id)",
     "lưu cùng bản ghi giao dịch của lần góp (khoản chi “Tiết kiệm”) và có ràng buộc duy nhất như (user_id, client_id)", 1),
    # dòng 99
    ("Sổ sách đã lọc được theo tuần, tháng và năm, nhưng nút xuất Excel vẫn luôn lấy giao dịch của tháng chứa ngày đang chọn.",
     "Danh sách giao dịch đã lọc được theo tuần, tháng và năm, nhưng chức năng xuất Excel vẫn luôn lấy giao dịch của tháng chứa ngày đang chọn.", 1),
]
