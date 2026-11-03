"""K9 (v18 -> v19): viết Chương 5 Thử nghiệm và triển khai, trong phạm vi bằng chứng hiện có.

Nguồn số liệu: docs/thesis/v5_results.md (đánh giá mô hình), ai-service/Version5/evaluate.py và labels.py (độ đo),
lần chạy CI của pull request #2 ngày 31/10/2026 (backend 2.407 ca, mobile 1.477 ca, AI Service 235 ca),
lần chạy pytest toàn ai-service ngày 01/11/2026, .github/workflows/ci.yml, docs/deploy/DEPLOY_GUIDE.md,
docs/testing/README.md, bộ Postman, Config/OpenApiConfig.java (tất cả trên origin/main 62b8861).

Giữ lại đúng 4 dòng giữ chỗ [T7.5] vì chưa đo được: kết quả Postman, báo cáo JMeter, kết quả triển khai EC2, APK và mã QR.
Mọi thay đổi ngoài Chương 5 chỉ gồm một đoạn của Kết luận (PARA_REPLACE) đã bị K8 đánh dấu "xem lại sau Chương 5"
và Lời cảm ơn (thay dòng [T7.9] bằng bản nháp loi_cam_on_nhap.md).

Các mục dùng HEADING_PLACEHOLDERS: dòng giữ chỗ [T7.5] đầu tiên sau mỗi tiêu đề của Chương 5.
Số bảng do builder đánh theo thứ tự xuất hiện trong Chương 5 (Bảng 5.1 đến 5.13); các tham chiếu trong văn bản đã viết sẵn
theo thứ tự đó và được kiểm bằng script.
"""

SESSION_TAG = None
SECTIONS = {}

SRC_EVAL = "Nguồn: nhóm thực hiện, chạy ai-service/Version5/evaluate.py trên 636 ảnh test (Kaggle, 25–26/10/2026)"

HEADING_PLACEHOLDERS = {
    # ------------------------------------------------------------------ 5.1
    "GIỚI THIỆU": [
        ("p",
         "Chương này đưa ra số liệu để đánh giá hai phần của đề tài. Phần nghiên cứu được đánh giá bằng cách chấm mô "
         "hình DONUT V5 và mô hình V3 cũ trên cùng 636 ảnh test (mục 5.2). Phần ứng dụng được đánh giá qua kiểm thử tự "
         "động của Core Backend, ứng dụng di động và AI Service (mục 5.3), qua tài liệu API, kiểm thử API và kiểm thử "
         "chịu tải (mục 5.4), và qua quy trình tích hợp, triển khai (mục 5.5)."),
        ("p",
         "Không phải kết quả nào cũng đã có tại thời điểm viết (01/11/2026). Số liệu ở mục 5.2 và 5.3 là số đã đo, kèm "
         "ngày đo và nơi đo. Với bộ kiểm thử Postman, kịch bản JMeter, triển khai trên máy chủ EC2 và gói APK, nhóm "
         "chưa có kết quả chạy, nên các mục 5.4.2, 5.4.3, 5.5.2 và 5.5.3 mô tả cách thực hiện và để trống phần kết "
         "quả. Chương không ước lượng thay cho số đo."),
    ],

    # ---------------------------------------------------------------- 5.2.1
    "Tập dữ liệu và độ đo đánh giá": [
        ("p",
         "Mô hình được chấm trên thư mục test của data1 (636 ảnh, Bảng 4.3). Thư mục này không tham gia huấn luyện hay "
         "chọn checkpoint. Mỗi ảnh có bốn trường nên tối đa có 2.544 trường. Trong đó 2.237 trường có nhãn khác rỗng và "
         "307 trường có nhãn rỗng (Bảng 4.2: 104 SELLER, 129 ADDRESS, 69 TIMESTAMP và 5 TOTAL_COST). Chỉ số chính chỉ "
         "chấm 2.237 trường có nhãn. Kết quả cũng được báo cáo khi tính cả 307 trường rỗng, để đo việc mô hình điền giá "
         "trị vào trường mà nhãn để trống."),
        ("p",
         "Hai mô hình được chấm bằng cùng một chương trình, ai-service/Version5/evaluate.py, trên cùng ảnh và cùng cách "
         "chấm. Mỗi mô hình sinh chuỗi theo kiểu tham lam (num_beams = 1), tối đa 768 token, với kích thước ảnh trong "
         "processor của chính nó (V5 dùng 1920 × 1440, V3 dùng 1280 × 960). Chuỗi của V3 được đưa qua hàm "
         "clean_vietnamese_text của V3 trước khi tách trường, đúng như khi V3 phục vụ. Dự đoán của từng ảnh được ghi vào "
         "pred_v3_test.jsonl và pred_v5_test.jsonl, còn kết quả từng trường ghi vào compare_test.csv. Phần chấm điểm có "
         "7 hàm kiểm thử trong Version5/tests/test_evaluate.py: tách trường từ chuỗi sinh ra, cách chấm có và không tính "
         "trường rỗng, ngưỡng 0,80, các tập con và kết luận cuối."),
        ("p",
         "Ba độ đo được tính cho từng trường và cho cả bốn trường gộp (ALL). ALL là tổng số trường khớp chia cho tổng "
         "số trường được chấm, không phải trung bình của bốn tỉ lệ. Bảng 5.1 ghi công thức, với N là số trường được "
         "chấm."),
        ("table", "Ba độ đo của evaluate.py", 5, [1700, 2800, 4004],
         ["Độ đo", "Công thức", "Cách tính"],
         [["Khớp hoàn toàn (exact)", "exact = (số trường khớp) / N",
           "Một trường khớp khi hàm fields_match trả đúng. TOTAL_COST so theo giá trị số tiền. Ba trường còn lại so "
           "sau khi chuẩn hóa NFC, đổi chữ thường và gộp khoảng trắng"],
          ["Khớp từ 80% (@80%)", "@80% = (số trường có sim ≥ 0,80) / N",
           "Ngưỡng 0,80 là hằng RELAXED_THRESHOLD. Độ đo này tính cả trường chỉ lệch nhẹ"],
          ["Độ tương đồng trung bình (sim)", "sim = (tổng các sim_i) / N, với sim_i = 2M / T",
           "sim_i là tỉ lệ của SequenceMatcher (thư viện difflib): M là tổng độ dài các đoạn chung tìm được, T là tổng "
           "độ dài hai chuỗi. Hai chuỗi rỗng cho sim_i = 1. Với TOTAL_COST, hai chuỗi chữ số của số tiền được so với "
           "nhau"]],
         "Nguồn: nhóm thực hiện, theo ai-service/Version5/evaluate.py và labels.py"),
        ("p",
         "Với TOTAL_COST, hàm money_value lấy mọi cụm số trong chuỗi, bỏ dấu chấm và dấu phẩy phân cách, bỏ hai chữ số "
         "lẻ sau dấu cuối cùng rồi lấy số lớn nhất. Vì vậy “1.011.780” và “1011780” là một giá trị. Ba trường còn lại "
         "được so nguyên chuỗi sau chuẩn hóa. Độ đo bỏ qua khác biệt chữ hoa, chữ thường và khoảng trắng nhưng vẫn tính "
         "dấu tiếng Việt: thiếu một dấu là sai."),
        ("p", "Ngoài toàn bộ tập test, evaluate.py chấm ba tập con:"),
        ("b1",
         "Bỏ 21 ảnh trong v3_seen_test.txt mà V3 có thể đã thấy khi huấn luyện (mục 4.3.3). Còn 615 ảnh và 2.153 "
         "trường có nhãn."),
        ("b1",
         "Hóa đơn dài, tức ảnh có tỉ lệ chiều cao trên chiều rộng lớn hơn 2,2 (mục 4.3.1). Có 632 trường có nhãn."),
        ("b1",
         "Ba ảnh Circle K được chỉ định sẵn trong chương trình, với 12 trường. Tập này quá nhỏ nên chỉ để minh họa."),
        ("p",
         "Chương trình in kết luận “V5 THẮNG” khi exact của V5 vượt V3 ở cả hai tập con bỏ ảnh đã thấy và hóa đơn dài, "
         "ngược lại in “V5 CHƯA THẮNG”."),
    ],

    # ---------------------------------------------------------------- 5.2.2
    "Kết quả theo từng trường thông tin": [
        ("p",
         "Bảng 5.2 là kết quả của V5 trên toàn bộ tập test. Tính chung bốn trường, 89,99% trường khớp hoàn toàn, "
         "95,40% khớp từ 80% và độ tương đồng trung bình là 97,02%. TOTAL_COST được đọc tốt nhất (97,15% khớp hoàn "
         "toàn), ADDRESS kém nhất (79,88%)."),
        ("table", "Kết quả của DONUT V5 theo từng trường trên tập test (chỉ tính trường có nhãn)", 5,
         [1704, 1700, 1700, 1700, 1700],
         ["Trường", "Số trường có nhãn", "Khớp hoàn toàn (exact)", "Khớp từ 80% (@80%)", "Độ tương đồng (sim)"],
         [["SELLER", "532", "87,97%", "91,54%", "94,60%"],
          ["ADDRESS", "507", "79,88%", "96,06%", "96,89%"],
          ["TIMESTAMP", "567", "92,95%", "96,12%", "97,66%"],
          ["TOTAL_COST", "631", "97,15%", "97,46%", "98,59%"],
          ["ALL", "2.237", "89,99%", "95,40%", "97,02%"]],
         SRC_EVAL + ". Số trường có nhãn lấy từ Bảng 4.8"),
        ("p",
         "Khoảng cách giữa khớp hoàn toàn và khớp từ 80% cho biết kiểu lỗi. ADDRESS có khoảng cách lớn nhất, 16,18 điểm "
         "phần trăm (79,88% và 96,06%): phần lớn địa chỉ sai chỉ lệch nhẹ về dấu, viết tắt hoặc khoảng trắng. SELLER thì "
         "khác, 87,97% và 91,54% chỉ cách nhau 3,57 điểm phần trăm, nên phần lớn tên cửa hàng đọc sai là sai nhiều chứ "
         "không lệch nhỏ. Hai trường còn lại có khoảng cách 3,17 điểm (TIMESTAMP) và 0,31 điểm (TOTAL_COST)."),
        ("p",
         "Mô-đun hậu xử lý ở mục 4.5.2 nâng tỉ lệ khớp hoàn toàn của ALL từ 89,99% lên 91,01%: ADDRESS lên 81,85%, "
         "TIMESTAMP lên 95,06%, TOTAL_COST lên 97,31% và SELLER giữ nguyên 87,97% (Bảng 4.8). Con số 93,50% ở mục 4.4.3 "
         "là field_exact trên 150 ảnh validation, cao nhất trong 14 lần đánh giá. Hai con số khác tập ảnh và khác cách "
         "chọn nên không so trực tiếp với 89,99% trên tập test."),
    ],

    # ---------------------------------------------------------------- 5.2.3
    "So sánh các phiên bản mô hình": [
        ("p",
         "Bảng 5.3 đặt V3 cạnh V5 trên toàn bộ tập test. Ở chỉ số chính, tỉ lệ khớp hoàn toàn của ALL tăng từ 18,33% "
         "lên 89,99%, khớp từ 80% từ 23,51% lên 95,40% và độ tương đồng từ 30,90% lên 97,02%. Mức tăng lớn nhất ở "
         "TIMESTAMP (0,53% lên 92,95%) và ADDRESS (2,56% lên 79,88%), hai trường mà V3 gần như không khớp hoàn toàn. "
         "TOTAL_COST là trường V3 đọc khá nhất (48,65%) và cũng là trường V5 đọc tốt nhất (97,15%)."),
        ("table", "So sánh V3 và V5 trên toàn bộ tập test (2.237 trường có nhãn)", 5,
         [1404, 1180, 1180, 1180, 1180, 1190, 1190],
         ["Trường", "V3 exact", "V5 exact", "V3 @80%", "V5 @80%", "V3 sim", "V5 sim"],
         [["SELLER", "16,35%", "87,97%", "23,31%", "91,54%", "31,98%", "94,60%"],
          ["ADDRESS", "2,56%", "79,88%", "10,85%", "96,06%", "16,13%", "96,89%"],
          ["TIMESTAMP", "0,53%", "92,95%", "5,29%", "96,12%", "18,30%", "97,66%"],
          ["TOTAL_COST", "48,65%", "97,15%", "50,24%", "97,46%", "53,16%", "98,59%"],
          ["ALL", "18,33%", "89,99%", "23,51%", "95,40%", "30,90%", "97,02%"]],
         SRC_EVAL),
        ("p",
         "Hai bản khác nhau ở nhiều điểm: nhãn huấn luyện (Bảng 4.2), tokenizer, kích thước ảnh (Bảng 4.4) và tiêu chí "
         "chọn checkpoint (mục 4.4.2). Nhóm không chạy thí nghiệm bỏ từng yếu tố, nên Bảng 5.3 cho biết V5 tốt hơn V3 "
         "chứ không cho biết mỗi yếu tố đóng góp bao nhiêu."),
        ("p",
         "V3 có thể đã gặp 21 ảnh test lúc huấn luyện, nên Bảng 5.4 chấm lại khi bỏ các ảnh này. Số của cả hai mô hình "
         "giảm nhẹ: ALL khớp hoàn toàn của V3 từ 18,33% xuống 16,67%, của V5 từ 89,99% xuống 89,74%. V3 giảm nhiều hơn, "
         "phù hợp với việc V3 đã thấy một số ảnh đó. Dù vậy V5 vẫn hơn V3 73,07 điểm phần trăm, nên chênh lệch ở Bảng "
         "5.3 không đến từ 21 ảnh này. Cách tìm 21 ảnh chỉ dựa vào địa chỉ trùng với nhãn train cũ, nên có thể còn ảnh "
         "V3 đã thấy mà không bị loại."),
        ("table", "So sánh V3 và V5 khi bỏ 21 ảnh V3 có thể đã thấy (2.153 trường có nhãn)", 5,
         [1404, 1180, 1180, 1180, 1180, 1190, 1190],
         ["Trường", "V3 exact", "V5 exact", "V3 @80%", "V5 @80%", "V3 sim", "V5 sim"],
         [["SELLER", "13,31%", "87,48%", "20,55%", "91,19%", "29,31%", "94,38%"],
          ["ADDRESS", "0,00%", "79,63%", "7,61%", "96,30%", "12,67%", "96,85%"],
          ["TIMESTAMP", "0,55%", "92,67%", "3,30%", "95,97%", "16,30%", "97,57%"],
          ["TOTAL_COST", "47,21%", "97,05%", "48,69%", "97,38%", "51,65%", "98,54%"],
          ["ALL", "16,67%", "89,74%", "21,23%", "95,31%", "28,58%", "96,93%"]],
         SRC_EVAL),
        ("p",
         "Bảng 5.5 chỉ chấm hóa đơn dài. V5 vẫn hơn V3 rõ rệt (ALL khớp hoàn toàn 86,23% so với 13,92%) nhưng thấp hơn "
         "mức 89,99% của toàn tập. Phần thiếu nằm ở hai trường chữ: ADDRESS còn 67,76% và SELLER còn 83,66%. TIMESTAMP "
         "(94,41%) và TOTAL_COST (97,28%) không thấp hơn mức chung của toàn tập (92,95% và 97,15%)."),
        ("table", "So sánh V3 và V5 trên hóa đơn dài (632 trường có nhãn)", 5,
         [1404, 1180, 1180, 1180, 1180, 1190, 1190],
         ["Trường", "V3 exact", "V5 exact", "V3 @80%", "V5 @80%", "V3 sim", "V5 sim"],
         [["SELLER", "1,96%", "83,66%", "9,15%", "86,93%", "28,22%", "91,40%"],
          ["ADDRESS", "0,00%", "67,76%", "1,97%", "93,42%", "8,68%", "94,74%"],
          ["TIMESTAMP", "0,70%", "94,41%", "3,50%", "97,20%", "23,96%", "97,62%"],
          ["TOTAL_COST", "45,65%", "97,28%", "46,74%", "97,83%", "53,10%", "99,09%"],
          ["ALL", "13,92%", "86,23%", "17,09%", "93,99%", "29,80%", "95,85%"]],
         SRC_EVAL),
        ("p",
         "Với ba ảnh Circle K (12 trường), V3 khớp hoàn toàn 50,00% (đúng SELLER và TOTAL_COST, sai ADDRESS và "
         "TIMESTAMP), còn V5 đúng cả bốn trường. Mẫu quá nhỏ nên kết quả này không dùng để kết luận."),
        ("p",
         "Bảng 5.6 tính cả trường có nhãn rỗng, nên giá trị mô hình điền vào trường mà nhãn để trống bị tính là sai. ALL "
         "khớp hoàn toàn của V5 giảm từ 89,99% xuống 84,20%, tức 5,79 điểm phần trăm. Của V3 lại tăng từ 18,33% lên "
         "25,31%, vì V3 hay để trống ở những trường mà nhãn cũng trống, và những trường đó được tính là khớp."),
        ("table", "So sánh V3 và V5 khi tính cả trường có nhãn rỗng (2.544 trường)", 5,
         [1404, 1180, 1180, 1180, 1180, 1190, 1190],
         ["Trường", "V3 exact", "V5 exact", "V3 @80%", "V5 @80%", "V3 sim", "V5 sim"],
         [["SELLER", "23,74%", "82,70%", "29,56%", "85,69%", "36,82%", "88,25%"],
          ["ADDRESS", "19,50%", "73,90%", "26,10%", "86,79%", "30,31%", "87,46%"],
          ["TIMESTAMP", "9,59%", "83,33%", "13,84%", "86,16%", "25,44%", "87,54%"],
          ["TOTAL_COST", "48,43%", "96,86%", "50,00%", "97,17%", "52,90%", "98,29%"],
          ["ALL", "25,31%", "84,20%", "29,87%", "88,95%", "36,37%", "90,38%"]],
         SRC_EVAL),
        ("p",
         "Bảng 5.7 chấm theo cách này cho hai tập con còn lại là bỏ 21 ảnh và hóa đơn dài. Ở hóa đơn dài mức giảm lớn hơn: ALL khớp hoàn "
         "toàn của V5 chỉ còn 74,73%, trong đó SELLER 70,11%, ADDRESS 58,15% và TIMESTAMP 73,37%. Hóa đơn dài là điểm "
         "yếu còn lại của V5."),
        ("table", "Chỉ số ALL ở hai tập con khi tính cả trường có nhãn rỗng", 5,
         [1704, 900, 980, 980, 980, 980, 990, 990],
         ["Tập con", "Số trường", "V3 exact", "V5 exact", "V3 @80%", "V5 @80%", "V3 sim", "V5 sim"],
         [["Bỏ 21 ảnh V3 có thể đã thấy", "2.460", "24,11%", "83,78%", "28,09%", "88,66%", "34,53%", "90,07%"],
          ["Hóa đơn dài", "736", "23,23%", "74,73%", "25,95%", "81,39%", "36,87%", "82,99%"]],
         SRC_EVAL),
        ("p",
         "Một phần các giá trị bị tính là điền thừa có thể là trường mà nhãn bỏ sót chứ không phải mô hình bịa, vì 127 "
         "dòng của tập test còn trường chưa được kiểm tra (Bảng 4.3). Nhóm chưa tách riêng hai trường hợp này."),
        ("p",
         "Theo quy tắc của evaluate.py, exact của V5 vượt V3 ở cả tập bỏ ảnh đã thấy và tập hóa đơn dài, nên kết luận "
         "của chương trình là “V5 THẮNG”."),
    ],

    # ---------------------------------------------------------------- 5.2.4
    "Phân tích lỗi": [
        ("p",
         "Sau hậu xử lý, 201 trong 2.237 trường có nhãn vẫn sai. Bảng 5.8 chia 201 trường này theo trường. ADDRESS và "
         "SELLER chiếm 156 trong 201 trường (77,6%)."),
        ("table", "Số trường còn sai sau hậu xử lý trên tập test", 5,
         [1704, 1700, 1700, 1700, 1700],
         ["Trường", "Số trường có nhãn", "Khớp sau hậu xử lý", "Còn sai", "Tỉ lệ sai"],
         [["SELLER", "532", "468", "64", "12,03%"],
          ["ADDRESS", "507", "415", "92", "18,15%"],
          ["TIMESTAMP", "567", "539", "28", "4,94%"],
          ["TOTAL_COST", "631", "614", "17", "2,69%"],
          ["ALL", "2.237", "2.036", "201", "8,99%"]],
         "Nguồn: nhóm thực hiện, tính từ Bảng 4.8 (số trường còn sai bằng số trường có nhãn trừ số trường khớp)"),
        ("p",
         "Lỗi ADDRESS trước hậu xử lý chủ yếu là lệch nhẹ (khớp từ 80% là 96,06% trong khi khớp hoàn toàn là 79,88%), "
         "gồm sai dấu, viết tắt và khoảng trắng. Đây là loại lỗi mà luật chuẩn hóa sửa được: hậu xử lý làm đúng thêm 23 "
         "trường (10 ADDRESS, 12 TIMESTAMP và 1 TOTAL_COST), không trường nào đang đúng bị làm sai. Phần lớn lỗi còn lại "
         "là giá trị đúng định dạng mà sai nội dung. SELLER không đổi sau hậu xử lý, và cờ valid chỉ phát hiện 23 trong 201 trường còn sai, báo nhầm 4 trong "
         "2.036 trường đúng (mục 4.5.2). Vì vậy màn hình đối soát vẫn cần thiết."),
        ("p",
         "Ở hóa đơn dài, lỗi tập trung vào hai trường chữ. ADDRESS chỉ khớp hoàn toàn 67,76% và SELLER 83,66%, trong "
         "khi TOTAL_COST vẫn ở mức 97,28% (Bảng 5.5). Điều này phù hợp với nhận định ở mục 4.3.1 rằng chữ nhỏ đi khi "
         "ảnh được thu về kích thước đầu vào cố định, nhưng nhóm chưa thử nguyên nhân bằng thí nghiệm, chẳng hạn dùng ảnh "
         "có độ phân giải cao hơn. Dữ liệu cũng không cho thấy TOTAL_COST kém đi ở hóa đơn dài."),
        ("p", "Các số đo trên có những giới hạn sau:"),
        ("b1",
         "Nhãn của tập test do hai mô hình thị giác – ngôn ngữ đọc rồi người duyệt (mục 4.3.2), và 127 dòng còn trường "
         "chưa được kiểm tra (Bảng 4.3). Nhãn sai làm một dự đoán đúng bị tính là sai, hoặc ngược lại."),
        ("b1",
         "Tập test được chia sẵn từ cùng nguồn data1 với tập huấn luyện và chưa có ảnh do người dùng thật chụp bằng ứng "
         "dụng, nên 89,99% và 91,01% chưa chắc giữ nguyên với ảnh ngoài phân bố này."),
        ("b1",
         "Mỗi mô hình chỉ được chạy một lần với cách sinh tham lam, nên bảng không có độ lệch chuẩn hay khoảng tin cậy. "
         "Chênh lệch vài phần mười điểm phần trăm, chẳng hạn 89,99% và 89,74%, không nên diễn giải."),
        ("b1",
         "Mức tăng 23 trường nhờ hậu xử lý (Bảng 4.8) được đo trên cùng tập test này. Nhóm chưa đo mô-đun trên một tập "
         "thứ hai."),
        ("b1",
         "Các độ đo tính theo từng trường. Chương chưa tính tỉ lệ hóa đơn có đủ bốn trường đúng, và chưa đo thời gian "
         "đọc một hóa đơn trên CPU của máy chủ."),
    ],

    # ---------------------------------------------------------------- 5.3.1
    "Kịch bản kiểm thử chức năng": [
        ("p",
         "Các kịch bản kiểm thử chức năng được viết thành lớp kiểm thử tự động nằm trong mã nguồn: "
         "core-backend/src/test, mobile-app/test và các tệp test_*.py của ai-service. Bảng 5.9 gom chúng "
         "theo kịch bản chức năng và ghi tên lớp thật của từng kịch bản. Kết quả “Đạt” nghĩa là mọi ca của các lớp được "
         "ghi đã chạy và qua trong lần chạy CI ngày 31/10/2026 (mục 5.3.2). Bảng chỉ gồm kiểm thử tự động. Chương này "
         "không báo cáo lần chạy thủ công trên thiết bị nào."),
        ("table", "Kịch bản kiểm thử chức năng và các lớp kiểm thử tự động tương ứng", 5,
         [620, 1450, 2900, 2784, 750],
         ["Mã", "Chức năng", "Tình huống được kiểm tra", "Lớp kiểm thử tự động", "Kết quả"],
         [["TC01", "Đăng ký tài khoản",
           "Máy chủ dựng tài khoản với mật khẩu băm, vai trò người dùng và ví rỗng; tài khoản bị cơ sở dữ liệu từ chối "
           "không được ghi. Ứng dụng kiểm tra mật khẩu đủ năm quy tắc",
           "AuthServiceRegisterTest\nregister_page_test.dart", "Đạt"],
          ["TC02", "Đăng nhập",
           "Đăng nhập thường và đăng nhập mạng xã hội cấp access token và refresh token mang phiên bản thông tin xác "
           "thực. Ứng dụng nhớ email và giữ hoặc kết thúc phiên theo ô ghi nhớ",
           "AuthControllerTokenIssueTest\nlogin_remember_email_test.dart\nlogin_page_errors_test.dart", "Đạt"],
          ["TC03", "Làm mới token và đăng xuất",
           "Làm mới thu hồi token cũ trước khi cấp cặp mới, token đã dùng hoặc đã thu hồi bị từ chối. Đăng xuất thu "
           "hồi cả hai token. Đổi mật khẩu kết thúc phiên của mọi thiết bị",
           "AuthServiceRefreshTest\nAuthServiceLogoutTest\nCrossSessionTokenRevocationTest\nprofile_logout_test.dart",
           "Đạt"],
          ["TC04", "Đặt lại mật khẩu bằng OTP",
           "Mật khẩu mới lưu dạng băm. Sai OTP bị đếm lần thử và mã bị hủy ở lần sai thứ ba. Yêu cầu lặp lại trong thời "
           "gian chờ bị từ chối với mã 429. Mọi phiên của tài khoản kết thúc",
           "AuthServiceResetPasswordTest\nforgot_password_page_test.dart\nreset_password_page_test.dart", "Đạt"],
          ["TC05", "Ghi, sửa và xóa giao dịch",
           "Số dư ví đổi đúng theo chênh lệch. Khoản chi vượt số dư bị từ chối và không thay đổi gì. Gửi lại cùng "
           "clientId, kể cả hai yêu cầu đến cùng lúc, chỉ tạo một giao dịch. Lỗi giữa chừng hoàn tác cả ví",
           "TransactionServiceTest\nTransactionServiceRollbackTest\nTransactionControllerTest\n"
           "add_transaction_page_test.dart", "Đạt"],
          ["TC06", "Lưu khi mất mạng và đồng bộ",
           "Giao dịch lưu cục bộ được gửi lại đúng một lần. Khi mất mạng ứng dụng không ném lỗi, giữ nguyên hàng chờ "
           "và đánh dấu lỗi",
           "app_repository_sync_test.dart\nledger_sync_status_test.dart", "Đạt"],
          ["TC07", "Ngân sách và cảnh báo",
           "Ngân sách trùng danh mục và kỳ bị từ chối. Khoản chi mới tạo thông báo ở mức đạt tới và chỉ một lần. Góp "
           "tiền tiết kiệm không kích hoạt cảnh báo",
           "BudgetServiceTest\nBudgetAlertServiceTest\nBudgetControllerTest\nbudget_screen_test.dart", "Đạt"],
          ["TC08", "Mục tiêu tiết kiệm",
           "Góp tiền là khoản chi thuộc danh mục “Tiết kiệm”, khóa mục tiêu trước khi trừ ví. Ví không đủ thì mục tiêu "
           "giữ nguyên. Xóa mục tiêu còn tiền thì hoàn vào ví",
           "SavingGoalServiceTest\nSavingGoalContributionRollbackTest\nsavings_page_contribute_test.dart", "Đạt"],
          ["TC09", "Quét hóa đơn và đối soát",
           "Kết quả của AI chỉ điền vào chỗ người dùng để trống. Hóa đơn của người khác bị từ chối. Sửa kèm số phiên "
           "bản, thua một lần ghi khác cùng phiên bản thì trả 409. Duyệt cùng hóa đơn hai lần chỉ đổi ví một lần. Hàng "
           "đợi quét đọc tuần tự, tối đa 20 mục",
           "ReceiptProcessingServiceTest\nReceiptControllerTest\nReceiptWorkflowIntegrationTest\n"
           "review_form_save_test.dart\nreceipt_scan_queue_test.dart", "Đạt"],
          ["TC10", "Ghi đồng thời trên hóa đơn",
           "Hai lần sửa từ cùng một phiên bản, hoặc một lần duyệt gặp một lần sửa, thì chỉ một bên được ghi. Chạy trên "
           "H2 và trên PostgreSQL thật (Testcontainers)",
           "ReceiptConcurrencyH2Test\nReceiptConcurrencyPostgresTest", "Đạt"],
          ["TC11", "Duyệt và từ chối hóa đơn (Web Admin)",
           "Người dùng thường bị cấm. Quản trị viên duyệt qua dịch vụ đối soát ví; từ chối chỉ đổi trạng thái hóa đơn",
           "AdminReceiptReviewTest\nReceiptProcessingServiceTest", "Đạt"],
          ["TC12", "Nạp và rút ví qua cổng thanh toán",
           "Webhook đúng chữ ký tạo giao dịch thu hoặc chi, sai chữ ký bị từ chối. Cùng một webhook gửi hai lần song "
           "song chỉ cộng ví một lần. Rút thiếu tiền thì đơn thất bại và không tạo giao dịch",
           "PaymentServiceTest\nPaymentWebhookControllerTest\nPaymentWebhookConcurrencyPostgresTest\n"
           "top_up_sheet_test.dart", "Đạt"],
          ["TC13", "Thông báo",
           "Danh sách theo trang của người gọi, số chưa đọc, đánh dấu đã đọc. Thông báo của người khác trả cùng lỗi 404 "
           "như mã không tồn tại",
           "NotificationServiceTest\nNotificationControllerTest\nnotification_screen_test.dart", "Đạt"],
          ["TC14", "Thống kê và bộ nhớ đệm Redis",
           "Lần đọc đầu hỏi cơ sở dữ liệu, các lần sau đọc từ Redis; khóa theo từng người dùng. Redis không với tới "
           "được thì mọi lần đọc về cơ sở dữ liệu",
           "RedisStatisticsCacheIntegrationTest\nRedisOutageTest\nUserStatisticsServiceTest", "Đạt"],
          ["TC15", "Phân quyền và nhật ký kiểm toán",
           "Người dùng thường vào URL quản trị nhận 403 và bị ghi lại, không token nhận 401. Người dùng không tự nâng "
           "mình thành quản trị viên. Thao tác trên giao dịch, hóa đơn, ngân sách được ghi kèm người thực hiện",
           "AccessDeniedAuditTest\nUserControllerRoleTest\nAuditTrailIntegrationTest", "Đạt"],
          ["TC16", "Phân khúc khách hàng RFM",
           "Backend lấy chi tiêu 12 tháng không tính tiết kiệm, từ chối câu trả lời sai và không ghi gì khi AI Service "
           "không với tới được. AI Service chấm ngũ phân vị và bảy nhóm",
           "CustomerSegmentationServiceTest\nAdminSegmentationTest\ntest_rfm_segmentation.py", "Đạt"],
          ["TC17", "Phân tích chi tiêu và gợi ý ngân sách",
           "Các điểm cuối /spade/analyze và /spade/recommend trả đúng khung phản hồi và mã 422 khi đầu vào sai. Khai "
           "phá mẫu, luật tuần tự và gợi ý cắt giảm cho kết quả đúng với dữ liệu cấy sẵn",
           "test_main.py\ntest_wcm_spade.py\ntest_spade_rules.py\ntest_spending_analysis.py\ntest_budget_advisor.py",
           "Đạt"],
          ["TC18", "Đọc hóa đơn bằng AI Service",
           "Điểm cuối /donut/scan từ chối tệp rỗng, quá lớn hoặc sai định dạng. Mỗi lúc chỉ một lượt suy luận và /health "
           "vẫn trả lời. Hậu xử lý chuẩn hóa bốn trường. Mô hình DONUT được thay bằng bản giả",
           "test_main.py\ntest_receipt_postprocess.py", "Đạt, 1 ca bỏ qua"]],
         "Nguồn: nhóm thực hiện, đối chiếu với mã kiểm thử trong kho và kết quả lần chạy CI ngày 31/10/2026"),
        ("p",
         "Bảng 5.9 không thay cho kiểm thử trên thiết bị thật. Với TC18, mô hình DONUT được thay bằng bản giả nên các "
         "ca chỉ kiểm tra hợp đồng của điểm cuối, không kiểm tra độ chính xác của mô hình; độ chính xác được đánh giá ở "
         "mục 5.2. Ca bị bỏ qua là test_postprocess_never_breaks_an_exact_v5_prediction, vì cần tệp "
         "Version5/compare_test.csv không có trong kho."),
    ],

    # ---------------------------------------------------------------- 5.3.2
    "Kiểm thử đơn vị và tích hợp": [
        ("p",
         "Core Backend dùng JUnit 5 với Spring Boot Test và Mockito. Tầng truy cập dữ liệu và các luồng khóa dòng được "
         "kiểm thử trên H2, còn một số lớp chạy trên PostgreSQL, Redis và MongoDB thật trong Docker nhờ Testcontainers. "
         "Các lớp này tự bỏ qua khi máy không có Docker, còn trên CI Docker có sẵn nên chúng chạy. Ứng dụng di động dùng "
         "flutter_test cho kiểm thử đơn vị và kiểm thử widget, cùng flutter analyze. AI Service dùng pytest, và các "
         "kiểm thử điểm cuối thay mô hình DONUT bằng bản giả nên CI không cần tệp trọng số."),
        ("p",
         "Bảng 5.10 ghi kết quả. Số liệu của Core Backend, của ứng dụng di động và của AI Service chạy như CI là của lần "
         "chạy GitHub Actions ngày 31/10/2026 cho pull request #2. Pull request này gồm mã nhánh main và một commit chỉ sửa kiểm thử, đặt múi giờ của ứng "
         "dụng trước khi cơ sở dữ liệu H2 khởi động để kiểm thử cho cùng kết quả trên máy chạy UTC của CI. Cả ba job "
         "kiểm thử đều thành công."),
        ("table", "Kết quả chạy kiểm thử tự động", 5, [1500, 2600, 2204, 2200],
         ["Thành phần", "Công cụ và lệnh", "Kết quả", "Nơi và ngày chạy"],
         [["Core Backend", "JUnit 5, Maven Surefire: mvn -B clean test -Dtest=!CoreBackendApplicationTests",
           "2.407 ca kiểm thử, 0 lỗi, 1 ca bỏ qua (bài đo độ trễ AdminEventLatencyBench)", "CI, 31/10/2026"],
          ["Ứng dụng di động", "flutter analyze và flutter test",
           "flutter analyze không có vấn đề; 1.477 ca đạt", "CI, 31/10/2026"],
          ["AI Service (như CI)", "pytest test_*.py", "235 đạt, 1 bỏ qua",
           "CI, 31/10/2026; máy của nhóm, 01/11/2026 cho cùng kết quả"],
          ["AI Service, bộ Version5/tests", "pytest Version5/tests", "72 đạt, 5 bỏ qua",
           "Máy của nhóm, 01/11/2026 (CI không chạy bộ này)"],
          ["AI Service, toàn thư mục", "pytest trong ai-service, gồm cả Version5/tests", "307 đạt, 6 bỏ qua",
           "Máy của nhóm, 01/11/2026. Lần chạy 31/10/2026 ghi 305 đạt, 8 bỏ qua (mục 4.5.3)"]],
         "Nguồn: nhóm thực hiện, từ log GitHub Actions của pull request #2 và lần chạy pytest ngày 01/11/2026"),
        ("p",
         "Trong lần chạy ngày 01/11/2026, 6 ca bị bỏ qua gồm 3 ca cần sổ tay (notebook) nằm cạnh bundle, 2 ca cần thư "
         "viện accelerate chỉ có trên Kaggle và 1 ca cần tệp compare_test.csv. Số ca bị bỏ qua phụ thuộc môi trường "
         "chạy; lần chạy 31/10/2026 có 8 ca. Trên CI, 235 ca của AI Service chỉ gồm các tệp test_*.py ở thư mục "
         "gốc. Bộ Version5/tests kiểm tra mã chấm điểm, xử lý nhãn và cấu hình huấn luyện, được chạy trước khi huấn "
         "luyện trên Kaggle (mục 4.4.1) nhưng chưa nằm trong CI."),
        ("p",
         "Nhóm chưa đo độ bao phủ mã: dự án không cấu hình công cụ đo như JaCoCo, nên chương không nêu tỉ lệ này. Số ca "
         "kiểm thử cho biết số tình huống đã viết, chưa cho biết phần mã nào chưa được kiểm tra. Ứng dụng di động chưa "
         "có kiểm thử tích hợp chạy trên thiết bị, vì thư mục integration_test không tồn tại. Một số ca trong "
         "ai_tab_range_test.dart phụ thuộc ngày chạy và có thể lỗi vào một số ngày của tháng, nên số 1.477 gắn với "
         "ngày chạy 31/10/2026."),
    ],

    # ---------------------------------------------------------------- 5.4.1
    "Tài liệu API với Swagger/OpenAPI": [
        ("p",
         "Core Backend sinh tài liệu API theo đặc tả OpenAPI [38] bằng thư viện springdoc-openapi (phiên bản 2.5.0) và "
         "hiển thị bằng Swagger UI. Cấu hình nằm trong lớp OpenApiConfig. Tài liệu chia thành hai nhóm: “API người dùng "
         "(mobile)” gồm các đường dẫn bắt đầu bằng /api/ trừ nhánh /api/admin/, và “API quản trị (ROLE_ADMIN)” gồm "
         "nhánh /api/admin/. Giao diện ở /swagger-ui.html, tệp JSON của hai nhóm ở /v3/api-docs/user và "
         "/v3/api-docs/admin. Các trang quản trị Thymeleaf (nhánh /admin/) không thuộc nhóm nào."),
        ("p",
         "Mọi thao tác đều yêu cầu JWT dạng bearer. Lược đồ bảo mật bearerAuth áp dụng cho cả tài liệu, trừ các điểm "
         "cuối xác thực công khai (AuthPaths.isPublic), nơi yêu cầu này bị bỏ để Swagger UI không gửi token. Để thử một "
         "API, người dùng gọi POST /api/auth/login, sao chép data.token, bấm Authorize và dán token, không gõ tiền tố "
         "“Bearer ”. Token được giữ lại khi tải lại trang."),
        ("p",
         "Tài liệu chỉ tồn tại ở profile dev. Ở mọi profile khác, lớp lồng DisabledOutsideDev nạp "
         "openapi-disabled.properties để tắt springdoc.api-docs và springdoc.swagger-ui, nên hai đường dẫn trên không "
         "tồn tại và mô tả API không bị công bố ra ngoài. Profile mặc định của ứng dụng là prod (application.yml, "
         "Dockerfile và docker-compose), nên máy chủ triển khai thuộc trường hợp này. Hai biến môi trường "
         "SPRINGDOC_API_DOCS_ENABLED và SPRINGDOC_SWAGGER_UI_ENABLED vẫn bật lại được khi cần. Ở profile dev, hai đường "
         "dẫn không qua bộ lọc bảo mật nên mở với mọi người, phù hợp với máy phát triển."),
        ("p",
         "OpenApiConfigTest có 8 ca, đạt trong lần chạy CI ngày 31/10/2026. Các ca kiểm tra tài liệu bị tắt khi không có "
         "profile dev và ở prod, được bật ở dev, biến môi trường ghi đè được mặc định tắt, nhóm người dùng không chứa "
         "API quản trị, mọi thao tác cần JWT theo mặc định và chỉ các điểm cuối xác thực công khai được bỏ yêu cầu đó."),
        ("y",
         "[Nhóm] Chụp màn hình Swagger UI chạy ở profile dev: danh sách hai nhóm API, một API được mở rộng (ví dụ POST "
         "/api/transactions/checkout), hộp Authorize và một lần Try it out thành công, rồi chèn vào đây làm hình của "
         "mục này."),
    ],

    # ---------------------------------------------------------------- 5.4.2
    "Kiểm thử API bằng Postman": [
        ("p",
         "Bộ kiểm thử Postman gồm hai tệp trong docs/testing/postman: LedgerMind.postman_collection.json (bộ “LedgerMind "
         "Core API”) và LedgerMind.local.postman_environment.json (môi trường “LedgerMind Local”, có địa chỉ máy chủ, "
         "email và mật khẩu của người dùng demo và của quản trị viên; hai mật khẩu để trống trong kho mã). Bộ có 42 "
         "yêu cầu (request) chia thành bảy thư mục, theo đúng thứ tự chạy ở Bảng 5.11."),
        ("table", "Các thư mục của bộ kiểm thử Postman", 5, [2300, 1000, 5204],
         ["Thư mục", "Số yêu cầu", "Nội dung kiểm tra"],
         [["01 - Xác thực", "5",
           "Đăng nhập sai mật khẩu (401), đăng nhập, hồ sơ, danh mục công khai, gọi không token (401)"],
          ["02 - Giao dịch", "10",
           "Danh sách, checkout, gửi lại cùng clientId không tạo trùng, thiếu số tiền (400), sửa, lọc, dashboard, cửa "
           "hàng hay mua, xóa, xóa lần nữa (404)"],
          ["03 - Ngân sách", "7",
           "Tạo, tạo trùng (409), khoảng ngày dài hơn kỳ hạn (400), danh sách, chi tiết, sửa, xóa"],
          ["04 - Hóa đơn (OCR)", "6",
           "Checkout kèm kết quả OCR, hóa đơn của giao dịch, sửa kết quả, sửa bằng version cũ (409), chi tiết, sửa mà "
           "không có trường nào (400)"],
          ["05 - Thông báo", "5",
           "Danh sách, số chưa đọc, đánh dấu một thông báo và tất cả đã đọc, kích thước trang quá lớn (400)"],
          ["06 - Quản trị", "5",
           "Người dùng thường gọi API quản trị (403), đăng nhập quản trị viên, nhật ký kiểm toán, dashboard của một "
           "người dùng, các lần đọc OCR của hóa đơn"],
          ["07 - Làm mới token và đăng xuất", "4",
           "Làm mới token, dùng lại refresh token cũ (401), đăng xuất, dùng token đã đăng xuất (401)"],
          ["Tổng", "42", ""]],
         "Nguồn: nhóm thực hiện, đếm từ docs/testing/postman/LedgerMind.postman_collection.json"),
        ("p",
         "Mọi yêu cầu đều có kịch bản kiểm tra trạng thái HTTP và mã code của ApiResponse. Cả bộ có thêm hai kiểm tra "
         "chung: phản hồi là JSON và thời gian phản hồi dưới 3000 ms. Có 12 yêu cầu chủ động gây lỗi để xem hệ thống từ "
         "chối đúng mã (400, 401, 403, 404 và 409). Các biến như token, transactionId và receiptVersion được lưu từ "
         "yêu cầu này sang yêu cầu sau, nên bộ phải chạy một lượt theo thứ tự bằng Collection Runner hoặc newman."),
        ("p",
         "Bộ được thiết kế để chạy trên máy cục bộ qua Docker Compose với profile dev và dữ liệu demo "
         "(SEED_DEMO=true), không chạy vào máy chủ EC2. Mỗi lần chạy để lại một giao dịch 45.000 đồng kèm hóa đơn, để "
         "quản trị viên xem được lịch sử OCR, cùng các dòng nhật ký kiểm toán. Giao dịch và ngân sách ở thư mục 02 và 03 "
         "được xóa ngay trong lần chạy."),
        ("y",
         "[T7.5] Kết quả chạy bộ Postman: số yêu cầu đạt trên tổng 42, thời gian phản hồi, ngày chạy và ảnh chụp bảng "
         "Passed/Failed của Collection Runner."),
    ],

    # ---------------------------------------------------------------- 5.4.3
    "Kiểm thử chịu tải bằng JMeter": [
        ("p",
         "Kịch bản chịu tải nằm trong docs/testing/jmeter/ledgermind-load.jmx. Mỗi người dùng ảo đăng nhập một lần bằng "
         "POST /api/auth/login, lấy data.token, rồi lặp hai yêu cầu đọc là GET /api/transactions/mine và GET "
         "/api/transactions/app-dashboard. Giữa các yêu cầu có thời gian nghĩ ngẫu nhiên đều từ 300 đến 1000 ms. Mỗi "
         "yêu cầu kiểm tra mã 200, hai yêu cầu đọc kiểm thêm code bằng 200 trong ApiResponse. Bảng 5.12 liệt kê các "
         "tham số, đặt bằng tùy chọn -J khi chạy."),
        ("table", "Tham số của kịch bản JMeter", 5, [2400, 1700, 4404],
         ["Tham số", "Mặc định", "Ý nghĩa"],
         [["protocol, host, port", "http, localhost, 8080", "Địa chỉ Core Backend"],
          ["users", "20", "Số người dùng ảo (luồng)"],
          ["rampUp", "20", "Số giây để khởi động hết các luồng"],
          ["loops", "10", "Số vòng lặp đọc dữ liệu của mỗi luồng"],
          ["thinkMs, thinkRangeMs", "300, 700", "Thời gian nghĩ bằng thinkMs cộng một số ngẫu nhiên từ 0 đến thinkRangeMs (ms)"],
          ["usersFile", "demo-users.txt", "Danh sách email, mỗi dòng một email, dùng xoay vòng giữa các luồng"],
          ["userPassword", "(trống)", "Mật khẩu chung của các tài khoản demo"]],
         "Nguồn: nhóm thực hiện, theo docs/testing/README.md và ledgermind-load.jmx"),
        ("p",
         "Kịch bản chạy bằng JMeter 5.6.x trên Java 17 trở lên, ở chế độ dòng lệnh, và sinh báo cáo HTML gồm APDEX, số "
         "mẫu, tỉ lệ lỗi, thời gian phản hồi trung bình, p90, p95, p99 và throughput. Tài liệu kiểm thử gợi ý chạy ba mức tải 10, 50 "
         "và 100 người dùng ảo với rampUp bằng 30 giây và loops bằng 20, ghi cấu hình máy chạy và nêu rõ là chạy trên "
         "máy cục bộ qua Docker Compose."),
        ("p",
         "Kịch bản có giới hạn. Nó chỉ đo hai API đọc, không đo ghi giao dịch, quét hóa đơn hay AI Service. Tệp "
         "demo-users.txt chỉ có hai tài khoản demo dùng xoay vòng, nên bộ nhớ đệm Redis theo từng người dùng có thể làm "
         "số đo tốt hơn thực tế. Kịch bản không chạy trên máy chủ triển khai, nên số đo không đại diện cho EC2."),
        ("y",
         "[T7.5] Kết quả JMeter: cấu hình máy chạy, các mức tải đã chạy, throughput, thời gian phản hồi trung bình và "
         "p90/p95/p99, tỉ lệ lỗi, lấy từ báo cáo HTML."),
    ],

    # ---------------------------------------------------------------- 5.5.1
    "Quy trình CI/CD với GitHub Actions": [
        ("p",
         "Quy trình nằm trong .github/workflows/ci.yml với tên “Microservices CI” [42]. Quy trình chạy khi đẩy mã lên "
         "main, khi đẩy tag dạng v* và khi mở pull request vào main. Khi có commit mới trên một nhánh khác main, lần "
         "chạy cũ của nhánh đó bị hủy. Bảng 5.13 liệt kê năm job. Mục 4.2.2 đã nêu tóm tắt các job kiểm thử."),
        ("table", "Các job của quy trình CI/CD", 5, [1500, 2300, 4704],
         ["Job", "Khi nào chạy", "Nội dung"],
         [["backend-ci", "Đẩy lên main, đẩy tag v*, pull request vào main",
           "Ubuntu, Temurin Java 21, bộ nhớ đệm Maven; mvn -B clean test -Dtest=!CoreBackendApplicationTests; tối đa 15 phút"],
          ["mobile-ci", "Như backend-ci",
           "Cài clang, cmake, ninja và GTK; Flutter kênh stable; flutter pub get, flutter analyze rồi flutter test; "
           "tối đa 15 phút"],
          ["ai-ci", "Như backend-ci",
           "Python 3.10; pip install -r requirements-dev.txt rồi pytest test_*.py; tối đa 15 phút"],
          ["deploy", "Chỉ khi đẩy lên main và cả ba job trên thành công",
           "SSH vào máy chủ, đồng bộ mã về origin/main, build image, docker compose up -d --wait"],
          ["release-apk", "Chỉ khi đẩy tag v*, sau mobile-ci",
           "Build APK release đã ký, đưa lên GitHub Release với tên LedgerMind.apk; tối đa 30 phút"]],
         "Nguồn: nhóm thực hiện, theo .github/workflows/ci.yml"),
        ("p",
         "Cổng kiểm tra gồm bốn phép: mvn test của Core Backend, flutter analyze và flutter test của ứng dụng di động, "
         "pytest của AI Service. Ba job chạy song song, và job nào có một phép thất bại thì kết thúc với mã lỗi. Job "
         "deploy khai báo needs: [backend-ci, mobile-ci, ai-ci] và điều kiện github.ref bằng refs/heads/main cùng sự "
         "kiện push. Vì vậy deploy chỉ chạy sau khi đẩy mã lên main và cả ba job kiểm thử đều xanh. Với pull request "
         "hoặc nhánh khác, deploy bị bỏ qua, như ở lần chạy ngày 31/10/2026 của pull request #2: ba job kiểm thử thành "
         "công còn deploy và release-apk ở trạng thái bỏ qua."),
        ("p",
         "Khi chạy, job deploy làm theo các bước sau. Nó kiểm tra thư mục ~/Deploy_Project và tệp .env tồn tại, và "
         "JWT_SECRET trong .env dài ít nhất 32 ký tự, để báo lỗi sớm thay vì đợi kiểm tra tình trạng hết giờ. Sau đó "
         "nó lấy mã về origin/main bằng git reset --hard, build image mới trong lúc bản cũ vẫn chạy, rồi chạy docker "
         "compose up -d --wait --remove-orphans để thay container và chờ cho tới khi các dịch vụ qua kiểm tra tình "
         "trạng. Cuối cùng nó dọn image và bộ nhớ đệm build cũ. Thông tin kết nối (AWS_HOST, AWS_USERNAME, AWS_SSH_KEY) "
         "lấy từ GitHub Secrets."),
        ("p",
         "Quy trình có những giới hạn. CI không dựng image Docker và không chạy mô hình DONUT thật, nên lỗi Dockerfile "
         "hay thiếu tệp trọng số chỉ lộ ra ở bước deploy. Bộ Version5/tests không nằm trong CI. Chỉ có một đích triển "
         "khai, không có môi trường thử, nên mỗi lần đẩy lên main là cập nhật máy chủ chính. ci.yml cũng không có bước "
         "tự quay lại bản trước; việc này làm tay theo mục 11 của docs/deploy/DEPLOY_GUIDE.md."),
        ("y",
         "[Nhóm] Chụp màn hình trang Actions của một lần chạy xanh trên nhánh main (ba job kiểm thử và deploy) để chèn "
         "vào mục này."),
    ],

    # ---------------------------------------------------------------- 5.5.2
    "Triển khai trên máy chủ AWS EC2": [
        ("p",
         "Khi viết chương này, nhóm chưa có kết quả triển khai trên máy chủ thật. Mục này mô tả quy trình trong "
         "docs/deploy/DEPLOY_GUIDE.md, là thiết kế thủ tục chứ không phải báo cáo kết quả. Các bước chính như sau:"),
        ("b1",
         "Máy chủ: một máy ảo Amazon EC2 [50] chạy Ubuntu Server 24.04 LTS, gắn Elastic IP cố định, cài Docker và Docker "
         "Compose. Tài liệu khuyến nghị thêm vùng hoán đổi (swap) để lần build đầu không hết bộ nhớ."),
        ("b1",
         "Mạng: Security Group chỉ mở cổng 22 (SSH), 80 và 443; các cổng 8080, 8000, 5432, 6379 và 27017 không mở. Bản "
         "ghi DNS loại A trỏ tên miền API về Elastic IP, tạo trước lần khởi động đầu để Caddy xin được chứng chỉ "
         "Let’s Encrypt."),
        ("b1",
         "Mã nguồn và cấu hình: clone mã vào ~/Deploy_Project, tạo tệp .env từ .env.example với "
         "SPRING_PROFILES_ACTIVE là prod, JWT_SECRET từ 32 ký tự trở lên và mật khẩu của từng kho dữ liệu."),
        ("b1",
         "Trọng số mô hình: tệp model.safetensors (khoảng 806 MB) không nằm trong Git, được chép từ máy của nhóm lên "
         "máy chủ bằng scp hoặc rsync và đối chiếu sha256sum ở hai đầu. Chỉ chép một lần, vì git reset --hard của job "
         "deploy không xóa tệp bị bỏ qua."),
        ("b1",
         "Khởi động lần đầu: docker compose up -d --build --wait. Theo tài liệu, lần build đầu mất 10 đến 20 phút. "
         "Caddy tự xin và gia hạn chứng chỉ HTTPS."),
        ("b1",
         "Kiểm tra sau triển khai: truy cập HTTP phải được chuyển sang HTTPS (mã 308); /actuator/health trả UP; "
         "/ai/health trả lời; /ai/spade/analyze không có token trả 401; /ai/admin/segment trả 404 vì không mở ra "
         "ngoài; kết nối từ ngoài tới cổng 8080 và 8000 phải thất bại. Sau đó mở Web Admin, cài APK và quét thử một "
         "hóa đơn."),
        ("b1",
         "Quay lại bản trước: git reset --hard về một commit ổn định rồi chạy lại docker compose up. Không dùng docker "
         "compose down -v trên máy chủ vì lệnh này xóa volume cơ sở dữ liệu và chứng chỉ."),
        ("p",
         "Từ lần sau, việc cập nhật do job deploy ở mục 5.5.1 thực hiện. Tài liệu hướng dẫn cũng có phương án dùng máy "
         "Oracle Cloud Always Free thay cho EC2 (Phụ lục A của tài liệu), các bước còn lại giữ nguyên."),
        ("y",
         "[T7.5] Kết quả deploy T8: loại máy và vùng đã tạo, thời gian build lần đầu, kết quả các lệnh kiểm tra sau "
         "triển khai và bộ nhớ thực tế của container data-mining-api khi quét một hóa đơn."),
    ],

    # ---------------------------------------------------------------- 5.5.3
    "Phân phối ứng dụng di động": [
        ("p",
         "Tệp APK cho Android được tạo và đưa lên GitHub Release bởi job release-apk trong ci.yml. Job chỉ chạy khi "
         "đẩy tag dạng v* và sau khi mobile-ci thành công, với các bước sau:"),
        ("b1",
         "Kiểm tra các secret ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, "
         "ANDROID_KEY_PASSWORD, GOOGLE_SERVICES_JSON_BASE64 và biến APP_API_BASE, trong đó APP_API_BASE phải bắt đầu "
         "bằng https://. Thiếu một giá trị thì job dừng và in tên giá trị đó."),
        ("b1",
         "Khôi phục keystore và google-services.json từ secret, build bằng flutter build apk --release. Tên phiên bản "
         "lấy từ tag (v1.1.0 thành 1.1.0), số bản dựng lấy từ số lần chạy của quy trình, nên không phải sửa pubspec.yaml. "
         "Hai khóa API_BASE và ML_BASE được truyền bằng --dart-define, với ML_BASE bằng API_BASE cộng /ai."),
        ("b1",
         "Xóa keystore khỏi máy chạy kể cả khi các bước trước thất bại, rồi đưa tệp LedgerMind.apk lên GitHub Release và "
         "đặt là bản mới nhất."),
        ("p",
         "Trang index.html có nút tải và mã QR mã hóa liên kết "
         "https://github.com/TriPhan15/donutpay-monorepo/releases/latest/download/LedgerMind.apk. Vì liên kết dùng "
         "latest nên luôn trỏ tới bản phát hành mới nhất. Theo tài liệu hướng dẫn, kho mã phải để công khai thì liên kết "
         "mới mở được khi chưa đăng nhập GitHub."),
        ("y",
         "[T7.5] APK + mã QR: ảnh mã QR, liên kết tải và phiên bản đã phát hành thử."),
    ],

    # ------------------------------------------------------------------ 5.6
    "KẾT CHƯƠNG": [
        ("p", "Các kết quả đã đo của chương này như sau:"),
        ("b1",
         "Mô hình: trên 636 ảnh test, DONUT V5 khớp hoàn toàn 89,99% trong 2.237 trường có nhãn, 91,01% sau hậu xử lý, "
         "và khớp từ 80% là 95,40%. TOTAL_COST đạt 97,15%, ADDRESS thấp nhất với 79,88%."),
        ("b1",
         "So sánh: V3 chỉ khớp hoàn toàn 18,33%. V5 vẫn hơn V3 khi bỏ 21 ảnh V3 có thể đã thấy (89,74% so với 16,67%) và "
         "ở hóa đơn dài (86,23% so với 13,92%), nên evaluate.py kết luận V5 thắng."),
        ("b1",
         "Hạn chế của số đo: khi tính cả trường nhãn rỗng, V5 còn 84,20% (74,73% ở hóa đơn dài). Nhãn test, một lần "
         "chạy mỗi mô hình và nguồn ảnh chung với tập huấn luyện là các giới hạn của kết luận."),
        ("b1",
         "Kiểm thử tự động: lần chạy CI ngày 31/10/2026 cho Core Backend 2.407 ca với 0 lỗi, ứng dụng di động 1.477 ca "
         "đạt và AI Service 235 ca đạt. Chạy toàn ai-service ngày 01/11/2026 được 307 ca đạt và 6 ca bị bỏ qua. Nhóm "
         "chưa đo độ bao phủ mã."),
        ("p",
         "Quy trình CI quy định rằng deploy chỉ chạy sau khi đẩy mã lên main và cả ba job kiểm thử đều thành công, còn "
         "APK chỉ được dựng khi đẩy tag v*."),
        ("p",
         "Bốn việc chưa có số liệu: kết quả chạy bộ 42 yêu cầu Postman, báo cáo tải JMeter, kết quả triển khai trên EC2 "
         "và gói APK kèm mã QR. Các mục 5.4.2, 5.4.3, 5.5.2 và 5.5.3 mô tả cách thực hiện và còn để trống phần kết quả. "
         "Thời gian đọc một hóa đơn trên CPU của máy chủ và mức bộ nhớ thực của container AI Service cũng chưa được đo."),
    ],
}

# Đoạn của Kết luận mà K8 đánh dấu "xem lại sau Chương 5" và nay không còn đúng: Chương 5 đã có số kiểm thử của
# Core Backend và ứng dụng di động. Hai câu sau của đoạn thay bằng câu mới; câu đầu giữ nguyên.
PARA_REPLACE = [
    ("Mục tiêu xây dựng hệ thống tích hợp:",
     ("p",
      "Mục tiêu xây dựng hệ thống tích hợp: cả bốn nhóm nghiệp vụ mà Mở đầu nêu là giao dịch, ngân sách, thống kê và "
      "quản trị đều đã được cài đặt trên ứng dụng di động hoặc Web Admin (mục 4.6 đến 4.8). Trong lần chạy CI ngày "
      "31/10/2026, kiểm thử tự động của ba thành phần không có ca nào lỗi: Core Backend chạy 2.407 ca (1 ca bỏ qua), "
      "ứng dụng di động đạt 1.477 ca và AI Service đạt 235 ca (1 ca bỏ qua) (mục 5.3.2). Các số này cho biết những "
      "tình huống nhóm đã viết đều qua, còn nhóm chưa đo độ bao phủ mã nên chưa biết phần nào chưa được kiểm tra. Kết "
      "quả chạy Postman và JMeter chưa có (mục 5.4), nên phần này chưa đánh giá chức năng ở mức API và hiệu năng chịu "
      "tải.")),
]

# Lời cảm ơn (thêm theo yêu cầu của người giao việc): nguyên văn thân bản nháp loi_cam_on_nhap.md, giữ các ô [ ] chờ điền tên.
HEADING_PLACEHOLDERS["LỜI CẢM ƠN"] = [
    ("p", 'Để hoàn thành khóa luận này, nhóm xin gửi lời cảm ơn chân thành đến TS. Phùng Thế Bảo, giảng viên hướng dẫn, đã tận tình hướng dẫn nhóm trong suốt thời gian thực hiện đề tài. [Nếu muốn nêu cụ thể điều thầy đã giúp, thêm vào đây.]'),
    ("p", 'Nhóm xin cảm ơn quý thầy cô Khoa Công nghệ thông tin, Trường Đại học Công Thương TP. HCM, đã truyền đạt kiến thức nền tảng làm cơ sở cho đề tài. [Nếu có: cảm ơn thêm các thầy cô hoặc đơn vị đã hỗ trợ cụ thể, ghi tên: ...]'),
    ("p", '[Nếu có: cảm ơn những người đã hỗ trợ dữ liệu hoặc thử nghiệm, ví dụ người tham gia duyệt nhãn hóa đơn hoặc dùng thử ứng dụng. Ghi tên hoặc nhóm người: ...]'),
    ("p", 'Cuối cùng, nhóm xin cảm ơn gia đình và bạn bè đã động viên trong quá trình thực hiện. Do thời gian và kinh nghiệm còn hạn chế, khóa luận khó tránh khỏi thiếu sót. Nhóm mong nhận được ý kiến đóng góp của quý thầy cô.'),
    ("p", 'TP. Hồ Chí Minh, tháng 11 năm 2026'),
    ("p", 'Nhóm sinh viên thực hiện'),
]
