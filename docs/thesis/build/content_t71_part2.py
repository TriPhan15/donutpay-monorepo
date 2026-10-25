# Mục 1.5 – 1.6 (số liệu đã đối chiếu với bài báo gốc ngày 21/10/2026).
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"

SECTIONS2 = {
    "OCR truyền thống kết hợp luật": [
        ("p", "Hướng đầu tiên tách bài toán thành hai bước: nhận dạng ký tự quang học để chuyển ảnh thành văn bản, sau đó dùng luật để tìm các trường thông tin trong văn bản. Tesseract là một bộ máy OCR tiêu biểu: ảnh nhị phân được phân tích thành phần liên thông, các đường viền được gom thành khối, khối được xếp thành dòng văn bản rồi tách thành từ; việc nhận dạng diễn ra qua hai lượt, từ nhận dạng tốt ở lượt đầu được dùng làm dữ liệu cho bộ phân lớp thích nghi [17]. Tesseract giả định ảnh vào đã là ảnh nhị phân và không tự phân tích bố cục [17], nên ảnh hóa đơn chụp nghiêng hoặc thiếu sáng cần được tiền xử lý trước."),
        ("p", "Sau bước OCR, các trường được tìm bằng từ khóa và biểu thức chính quy, ví dụ dòng chứa “TỔNG CỘNG” hoặc “TOTAL” kèm một số tiền, hay chuỗi khớp mẫu ngày dd/mm/yyyy. Các nghiên cứu trong nước theo hướng này dùng các bộ OCR có sẵn kết hợp học sâu để số hóa tài liệu tài chính [3] và so sánh độ chính xác của các bộ OCR trên văn bản tiếng Việt [4]. Ưu điểm của hướng này là không cần dữ liệu huấn luyện cho bước trích xuất và dễ giải thích. Nhược điểm là luật phải viết lại khi gặp mẫu hóa đơn mới, và mọi lỗi nhận dạng dấu tiếng Việt hay chữ số của bước OCR đều truyền thẳng sang kết quả [24]."),
    ],
    "OCR kết hợp mô hình bố cục": [
        ("p", "Hướng thứ hai vẫn dùng OCR nhưng thay luật bằng một mô hình học được vị trí của văn bản trên trang. LayoutLM của Xu và cộng sự bổ sung vào mô hình ngôn ngữ dạng BERT (Bidirectional Encoder Representations from Transformers) hai loại embedding (vector biểu diễn): embedding vị trí hai chiều lấy từ hộp bao của từng từ, và embedding ảnh của vùng chứa từ đó [18]. Mô hình được tiền huấn luyện trên bộ IIT-CDIP với hơn 11 triệu ảnh tài liệu scan, rồi tinh chỉnh cho bài toán gán nhãn từng token (đơn vị văn bản sau khi tách); trên tập SROIE, LayoutLM đạt độ đo F1 (trung bình điều hòa của độ chính xác và độ phủ) 0,9524 [18]. LayoutLMv3 thống nhất việc che (masking) văn bản và che ảnh khi tiền huấn luyện, nhưng vẫn dùng một bộ OCR có sẵn để lấy nội dung văn bản và vị trí hai chiều làm đầu vào [19]."),
        ("p", "Với hóa đơn tiếng Việt, Pham và cộng sự biểu diễn các dòng văn bản do OCR trả về thành đồ thị và dùng mạng nơ-ron đồ thị (Graph Neural Network – GNN) để phân loại dòng nào thuộc trường nào [23]. Do học vị trí văn bản từ dữ liệu, về nguyên tắc hướng này thích ứng với thay đổi bố cục tốt hơn luật viết tay [18], [19], nhưng cần nhãn mức token hoặc mức dòng kèm hộp bao, và vẫn phụ thuộc vào chất lượng của bước OCR."),
    ],
    "Hướng tiếp cận OCR-free": [
        ("p", "Kim và cộng sự chỉ ra ba vấn đề của các phương pháp hiểu tài liệu dựa trên OCR: chi phí tính toán cao do phải chạy bộ máy OCR, OCR kém linh hoạt khi đổi ngôn ngữ hoặc loại tài liệu, và lỗi OCR lan truyền sang các bước sau [5]. Để tránh cả ba vấn đề, nhóm tác giả đề xuất DONUT, một mô hình Transformer nhận ảnh và sinh trực tiếp kết quả, không dùng OCR ở bất kỳ bước nào [5]."),
        ("p", "DONUT gồm bộ mã hóa ảnh Swin Transformer [8] và bộ giải mã văn bản khởi tạo từ BART đa ngôn ngữ [9], [10]. Mô hình được tiền huấn luyện bằng nhiệm vụ đọc toàn bộ văn bản trong ảnh theo thứ tự đọc, trên 11 triệu ảnh scan tiếng Anh của IIT-CDIP và 2 triệu ảnh tổng hợp do bộ sinh SynthDoG tạo ra; nhóm tác giả gọi nhiệm vụ này là “pseudo-OCR” [5]. Khi tinh chỉnh, đầu ra là chuỗi token có thể chuyển một – một thành JSON, trong đó mỗi trường cần trích xuất được bao bởi cặp token đặc biệt bắt đầu và kết thúc [5]. Vì vậy dữ liệu huấn luyện chỉ cần cặp (ảnh, JSON), không cần hộp bao hay nhãn từng từ. Kiến trúc và cơ chế sinh chuỗi của DONUT được phân tích chi tiết ở mục 2.5."),
        ("p", "Trên bộ dữ liệu hóa đơn CORD, DONUT đạt F1 mức trường 84,1 và độ chính xác dựa trên khoảng cách sửa cây 90,9, với thời gian suy luận 1,2 giây mỗi ảnh; các mô hình dựa trên OCR được so sánh trong cùng bảng như LayoutLM (F1 78,4) và LayoutLMv2 (F1 78,9) cần 1,7 giây mỗi ảnh; số tham số công bố của các mô hình này chưa gồm bộ OCR [5]."),
    ],
    "So sánh các hướng tiếp cận": [
        ("p", "Hình 1.8 đặt ba hướng tiếp cận cạnh nhau. Hai hướng đầu có chung bước OCR ở đầu luồng xử lý; hướng thứ ba thay toàn bộ luồng bằng một mô hình mã hóa – giải mã duy nhất."),
        ("fig", "Ba hướng trích xuất thông tin hóa đơn", "1", PNG + "ch1_ba_huong_trich_xuat.png", 15.0, "nguồn: nhóm thực hiện, tổng hợp từ [5], [17], [18]", None),
        ("p", "Bảng 1.4 so sánh ba hướng theo các tiêu chí liên quan trực tiếp đến bài toán của đề tài."),
        ("table", "So sánh các hướng trích xuất thông tin hóa đơn", "1", [2104, 2100, 2100, 2200],
         ["Tiêu chí", "OCR + luật", "OCR + mô hình bố cục", "OCR-free (DONUT)"],
         [
             ["Phụ thuộc bộ OCR", "Có", "Có", "Không"],
             ["Lan truyền lỗi OCR", "Toàn bộ", "Một phần, mô hình có thể bù bằng ngữ cảnh", "Không có bước OCR riêng"],
             ["Dữ liệu cần để huấn luyện", "Không cần, nhưng phải viết luật cho từng mẫu", "Nhãn mức token/dòng kèm hộp bao", "Cặp ảnh và JSON mức tài liệu"],
             ["Thích ứng mẫu hóa đơn mới", "Kém, phải sửa luật", "Khá", "Khá, cần dữ liệu đủ đa dạng"],
             ["Xử lý tiếng Việt có dấu", "Phụ thuộc độ chính xác của OCR", "Phụ thuộc OCR và tokenizer", "Phụ thuộc tokenizer của bộ giải mã"],
             ["Chi phí suy luận", "Thấp nếu OCR nhẹ", "OCR + mô hình", "Một mô hình, ảnh độ phân giải cao"],
             ["Khả năng giải thích", "Cao", "Trung bình", "Thấp hơn, đầu ra là chuỗi sinh"],
         ],
         "Nguồn: nhóm đánh giá, tổng hợp từ [5], [17], [18], [19], [24]"),
        ("p", "Nhóm chọn hướng OCR-free vì hai lý do. Tập dữ liệu của nhóm chỉ có nhãn mức tài liệu (bốn trường dạng JSON), không có hộp bao, nên phù hợp trực tiếp với cách huấn luyện của DONUT. Ngoài ra, việc bỏ bước OCR giúp AI Service chỉ phải đóng gói một mô hình. Hạn chế của lựa chọn này cũng được ghi nhận: tokenizer gốc của DONUT không được thiết kế riêng cho tiếng Việt và cần được mở rộng (mục 2.5.5), kết quả sinh ra có thể sai định dạng nên vẫn cần hậu xử lý bằng Regex, và mô hình khó giải thích hơn luật."),
    ],
    "Cuộc thi và bộ dữ liệu SROIE": [
        ("p", "SROIE (Scanned Receipts OCR and Information Extraction) là cuộc thi tổ chức tại hội nghị ICDAR 2019 [21]. Bộ dữ liệu gồm 1.000 ảnh hóa đơn scan nguyên tờ, chia thành 600 ảnh huấn luyện – kiểm định và 400 ảnh kiểm thử; văn bản chủ yếu là chữ số và ký tự tiếng Anh [21]. Cuộc thi có ba nhiệm vụ: định vị văn bản, nhận dạng văn bản và trích xuất thông tin chính từ hóa đơn [21]. Ở nhiệm vụ trích xuất, các công trình sau như LayoutLM sử dụng bốn loại thực thể company, date, address, total [18], tương ứng gần như hoàn toàn với bốn trường của đề tài. Kết quả tốt nhất của nhiệm vụ này khi tổ chức cuộc thi là Hmean (trung bình điều hòa của độ chính xác và độ phủ) 90,49% [21]."),
    ],
    "Bộ dữ liệu CORD": [
        ("p", "CORD (Consolidated Receipt Dataset) là bộ dữ liệu hóa đơn tiếng Indonesia thu từ cửa hàng và nhà hàng, được công bố tại NeurIPS 2019 Workshop on Document Intelligence [20]. Phiên bản công khai gồm 1.000 ảnh, chia 800/100/100 cho huấn luyện, kiểm định và kiểm thử; mỗi ảnh có hộp bao, văn bản và nhãn ngữ nghĩa nhiều cấp dạng JSON. Theo kho mã của bộ dữ liệu, bản công khai giữ 30 lớp con thuộc các nhóm món hàng, tạm tính và tổng tiền; các trường thông tin cửa hàng và thanh toán đã bị loại bỏ vì lý do pháp lý tại Indonesia [20]. CORD là một trong các bộ dữ liệu được dùng để đánh giá DONUT [5]; mô hình nền mà nhóm tinh chỉnh cũng là bản DONUT đã tinh chỉnh trên CORD (donut-base-finetuned-cord-v2), sau đó được chuyển sang bốn trường của hóa đơn tiếng Việt."),
    ],
    "Cuộc thi MC-OCR với hóa đơn tiếng Việt": [
        ("p", "MC-OCR (Mobile-Captured Image Document Recognition for Vietnamese Receipts) là cuộc thi tổ chức tại hội nghị RIVF 2021, tập trung vào hóa đơn tiếng Việt chụp bằng điện thoại [22]. Bộ dữ liệu gồm 2.436 hóa đơn, chia thành 500 ảnh khởi động, 1.155 ảnh huấn luyện công khai, 391 ảnh kiểm thử công khai và 390 ảnh kiểm thử riêng [22]. Ảnh được chụp trong nhiều điều kiện ánh sáng và bối cảnh khác nhau, hóa đơn có thể bị nhàu hoặc mờ [22]."),
        ("p", "Cuộc thi có hai nhiệm vụ: đánh giá chất lượng ảnh hóa đơn và trích xuất bốn trường SELLER, SELLER ADDRESS, TIMESTAMP, TOTAL COST [22]. Hai nhiệm vụ được đánh giá lần lượt bằng sai số căn quân phương (RMSE) và tỉ lệ lỗi ký tự (CER); kết quả tốt nhất trên tập kiểm thử riêng là RMSE 0,10 và CER 0,22 [22]. Đây là các độ đo lỗi nên giá trị càng thấp càng tốt. MC-OCR là công trình gần nhất với đề tài: cùng ngôn ngữ, cùng điều kiện chụp và cùng bốn trường thông tin. Điểm khác là đề tài dùng một mô hình OCR-free duy nhất để trích xuất, và tích hợp kết quả vào một ứng dụng quản lý tài chính có bước đối soát."),
        ("p", "Bảng 1.5 tóm tắt ba bộ dữ liệu trên."),
        ("table", "So sánh các bộ dữ liệu hóa đơn liên quan", "1", [1400, 1900, 1700, 1704, 1800],
         ["Bộ dữ liệu", "Ngôn ngữ, nguồn ảnh", "Quy mô", "Trường/nhãn", "Độ đo"],
         [
             ["SROIE [21]", "Chủ yếu tiếng Anh và chữ số; ảnh scan", "1.000 ảnh (600 / 400)", "company, date, address, total [18]", "Hmean"],
             ["CORD [20]", "Tiếng Indonesia; cửa hàng và nhà hàng", "1.000 ảnh công khai (800 / 100 / 100)", "30 lớp con: món hàng, tạm tính, tổng tiền", "F1 mức trường, độ chính xác dựa trên khoảng cách sửa cây (TED) [5]"],
             ["MC-OCR [22]", "Tiếng Việt; chụp bằng điện thoại", "2.436 ảnh", "SELLER, SELLER ADDRESS, TIMESTAMP, TOTAL COST", "RMSE (chất lượng ảnh), CER (trích xuất)"],
         ],
         "Nguồn: nhóm tổng hợp từ [5], [18], [20], [21], [22]"),
    ],
}

ABBREVIATIONS2 = [
    ("CER", "Character Error Rate", "Tỉ lệ lỗi ký tự"),
    ("RMSE", "Root Mean Square Error", "Sai số căn quân phương"),
    ("TED", "Tree Edit Distance", "Khoảng cách sửa cây"),
    ("ACID", "Atomicity, Consistency, Isolation, Durability", "Tính nguyên tử, nhất quán, cô lập, bền vững của giao dịch"),
    ("BERT", "Bidirectional Encoder Representations from Transformers", "Mô hình biểu diễn mã hóa hai chiều dựa trên Transformer"),
    ("BSON", "Binary JSON", "Định dạng JSON nhị phân"),
    ("SSH", "Secure Shell", "Giao thức truy cập từ xa có mã hóa"),
]
