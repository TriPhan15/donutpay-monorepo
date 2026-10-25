# Nội dung phiên T7.1: Mở đầu + Chương 1.
# Số liệu hệ thống: docs/thesis/facts.md. Trích dẫn: docs/thesis/references.md ([1]–[46]).
PNG = "/home/triphan/Workspace/Deploy_Project/docs/thesis/diagrams/"
SESSION_TAG = "T7.1"
SRC_NHOM = "Nguồn: nhóm thực hiện"

PLAN_ROWS = [
    ("1", "15/08 – 21/08/2026", "Lập kế hoạch, phân công công việc, thiết lập kho mã nguồn Git/GitHub; khảo sát giải pháp OCR và ứng dụng quản lý tài chính; thu thập, làm sạch dữ liệu hóa đơn."),
    ("2", "22/08 – 28/08/2026", "Lập sơ đồ use case (ca sử dụng) nghiệp vụ, use case hệ thống và đặc tả; phân tích luồng dữ liệu của Core Backend; nghiên cứu DONUT và phương án mở rộng tokenizer tiếng Việt."),
    ("3", "29/08 – 04/09/2026", "Thiết kế kiến trúc microservices, mô hình dữ liệu quan hệ, bộ nhớ đệm và sơ đồ lớp thiết kế; tiền xử lý dữ liệu; bắt đầu huấn luyện DONUT."),
    ("4", "05/09 – 11/09/2026", "Thiết kế giao diện ứng dụng di động và Web Admin; thiết kế API theo kiến trúc REST giữa các thành phần; theo dõi kết quả huấn luyện."),
    ("5", "12/09 – 18/09/2026", "Lập trình các dịch vụ lõi bằng Java, cấu hình Spring Security và JWT; tối ưu mô hình theo kết quả huấn luyện."),
    ("6", "19/09 – 25/09/2026", "Xây dựng API giao dịch, danh mục, thống kê; đóng gói AI Service và viết luật hậu xử lý bằng biểu thức chính quy (Regex) cho bốn trường."),
    ("7", "26/09 – 02/10/2026", "Lập trình giao diện Flutter, tích hợp API xác thực và quản lý ngân sách; đánh giá độ chính xác của mô hình trên AI Service."),
    ("8", "03/10 – 09/10/2026", "Xây dựng Web Admin; chức năng giao dịch thủ công và biểu đồ trên ứng dụng; tích hợp camera thu nhận ảnh hóa đơn."),
    ("9", "10/10 – 16/10/2026", "Gọi AI Service từ ảnh chụp trên thiết bị; xây dựng luồng đối soát hóa đơn và lưu kết quả vào Core Backend."),
    ("10", "17/10 – 23/10/2026", "Kiểm thử toàn luồng Mobile – Core Backend – AI Service; kiểm thử API bằng Postman, chịu tải bằng JMeter, tài liệu hóa API bằng Swagger/OpenAPI."),
    ("11", "24/10 – 30/10/2026", "Sửa lỗi phát sinh khi kiểm thử; đóng gói bằng Docker Compose và triển khai lên máy chủ ảo; tổng hợp tài liệu thiết kế."),
    ("12", "31/10 – 06/11/2026", "Hoàn chỉnh quyển báo cáo, chuẩn bị slide và nộp báo cáo."),
]

SECTIONS = {
    # ------------------------------------------------------------------ MỞ ĐẦU
    "1. GIỚI THIỆU VÀ LÝ DO CHỌN ĐỀ TÀI": [
        ("p", "Theo báo cáo Global Findex 2025 của Ngân hàng Thế giới, năm 2024 có 71% người trưởng thành tại Việt Nam sở hữu tài khoản tại tổ chức tài chính hoặc ví điện tử và 62% đã thực hiện hoặc nhận một khoản thanh toán số [41]. Dòng tiền của một cá nhân vì thế phân tán trên nhiều kênh: tiền mặt, thẻ ngân hàng, ví điện tử. Muốn biết mình đã chi bao nhiêu cho từng nhóm nhu cầu, người dùng phải tự tổng hợp từ nhiều nguồn."),
        ("p", "Các ứng dụng quản lý tài chính cá nhân phổ biến tại Việt Nam như Money Lover hay MISA MoneyKeeper giải quyết phần tổng hợp bằng sổ thu chi điện tử, ngân sách và biểu đồ [42], [43]. Bước tốn công nhất vẫn là nhập liệu: với mỗi hóa đơn giấy, người dùng phải đọc tên cửa hàng, thời gian, tổng tiền rồi gõ lại vào ứng dụng. Hóa đơn bán lẻ tại Việt Nam thường in nhiệt, khổ hẹp, chữ tiếng Việt có dấu, bố cục khác nhau giữa các chuỗi cửa hàng; ảnh chụp bằng điện thoại còn bị nghiêng, nhòe hoặc thiếu sáng. Những đặc điểm này làm cho việc tự động hóa bằng nhận dạng ký tự quang học (Optical Character Recognition – OCR) truyền thống kém ổn định, nhất là với dấu thanh tiếng Việt [4], [24]."),
        ("p", "Hướng tiếp cận thông thường là chạy OCR để lấy văn bản rồi dùng luật hoặc mô hình thứ hai để tìm các trường thông tin; lỗi của bước OCR khi đó lan sang bước trích xuất [5]. DONUT (Document Understanding Transformer) do Kim và cộng sự đề xuất bỏ hẳn bước OCR (hướng tiếp cận OCR-free): mô hình nhận ảnh tài liệu và sinh trực tiếp chuỗi có cấu trúc tương ứng với các trường cần lấy [5]. Kiến trúc này phù hợp với bài toán của nhóm vì chỉ cần cặp dữ liệu (ảnh, nhãn dạng JSON – JavaScript Object Notation) để huấn luyện, không cần nhãn hộp bao cho từng từ."),
        ("p", "Từ hai nhận xét trên, nhóm chọn đề tài **“Nghiên cứu mô hình DONUT OCR-free trong trích xuất thông tin hóa đơn tiếng Việt và ứng dụng trong quản lý tài chính cá nhân”**. Đề tài gồm hai phần gắn với nhau: phần nghiên cứu huấn luyện DONUT trích xuất bốn trường Seller, Address, Timestamp, Total Cost từ ảnh hóa đơn tiếng Việt; phần ứng dụng xây dựng hệ thống quản lý tài chính cá nhân gồm ứng dụng di động, Web Admin, Core Backend và AI Service, trong đó kết quả trích xuất được người dùng đối soát trước khi ghi thành giao dịch."),
    ],
    "2. MỤC TIÊU ĐỀ TÀI": [
        ("p", "Đề tài đặt ra ba mục tiêu, bám theo đề cương đã được duyệt:"),
        ("b1", "Khảo sát, đánh giá các giải pháp nhận dạng thông tin hóa đơn và phân tích nhu cầu của ứng dụng quản lý tài chính cá nhân; thiết kế hệ thống theo kiến trúc microservices (kiến trúc vi dịch vụ, chia hệ thống thành các dịch vụ nhỏ triển khai độc lập) để AI Service hoạt động độc lập với các luồng xử lý trung tâm."),
        ("b1", "Xây dựng hệ thống tích hợp gồm ứng dụng di động, Web Admin và Core Backend Java, đáp ứng các nghiệp vụ quản lý giao dịch, quản lý ngân sách, thống kê trực quan và quản trị hệ thống."),
        ("b1", "Nghiên cứu và ứng dụng mô hình DONUT OCR-free để tự động trích xuất bốn trường thông tin Seller, Address, Timestamp, Total Cost từ ảnh hóa đơn; đóng gói và triển khai toàn bộ hệ thống bằng Docker."),
    ],
    "3. ĐỐI TƯỢNG VÀ PHẠM VI ĐỀ TÀI": [
        ("p", "**Đối tượng nghiên cứu** gồm: mô hình DONUT và các thành phần của nó (bộ mã hóa ảnh Swin Transformer, bộ giải mã BART, tokenizer – bộ tách từ thành các đơn vị token); ảnh chụp hóa đơn bán lẻ tiếng Việt; nghiệp vụ quản lý thu chi của người dùng cá nhân."),
        ("p", "**Phạm vi** của đề tài được giới hạn như sau:"),
        ("b1", "Về dữ liệu: ảnh hóa đơn bán lẻ tiếng Việt (siêu thị, cửa hàng tiện lợi, nhà hàng, quán cà phê) chụp bằng điện thoại. Tập dữ liệu nhóm sử dụng có 6.351 ảnh, chia thành 5.080 ảnh huấn luyện, 635 ảnh kiểm định và 636 ảnh kiểm thử."),
        ("b1", "Về trích xuất: chỉ bốn trường Seller (tên người bán), Address (địa chỉ), Timestamp (thời gian), Total Cost (tổng tiền); không trích xuất danh sách mặt hàng, thuế hay mã số thuế."),
        ("b1", "Về hệ thống: một người dùng quản lý một số dư ví; hệ thống không liên kết tài khoản ngân hàng. Ứng dụng di động chạy trên Android; Web Admin dành cho quản trị viên chạy trên trình duyệt."),
        ("b1", "Về huấn luyện: mô hình được tinh chỉnh (fine-tune) trên GPU của nền tảng Kaggle; AI Service phục vụ suy luận trên CPU (mã nguồn tự chuyển sang GPU nếu máy chủ có)."),
    ],
    "4. PHƯƠNG PHÁP NGHIÊN CỨU": [
        ("p", "**Nghiên cứu tài liệu.** Nhóm đọc các công trình gốc về Transformer [6], Vision Transformer [7], Swin Transformer [8], BART [9] và DONUT [5]; các công trình trích xuất thông tin hóa đơn dựa trên OCR [17], [18], [19], [23] và các bộ dữ liệu SROIE [21], CORD [20], MC-OCR [22]; tài liệu chính thức của các công nghệ sử dụng."),
        ("p", "**Khảo sát.** Nhóm khảo sát ba ứng dụng quản lý tài chính cá nhân trên Google Play theo cùng một danh sách tính năng, và khảo sát các loại hóa đơn bán lẻ thường gặp để xác định đặc điểm của bốn trường cần trích xuất."),
        ("p", "**Thực nghiệm.** Mô hình được huấn luyện trên tập huấn luyện, chọn checkpoint (bản lưu trọng số tại một bước huấn luyện) trên tập kiểm định và đánh giá trên tập kiểm thử tách riêng. Kết quả được đo theo từng trường để so sánh giữa các phiên bản mô hình."),
        ("p", "**Phát triển phần mềm lặp.** Hệ thống được xây dựng theo từng chức năng trong kế hoạch 12 tuần. Các chức năng chính có kiểm thử tự động (JUnit cho Core Backend, flutter_test cho ứng dụng di động, pytest cho AI Service) và chạy lại trên GitHub Actions ở mỗi lần đẩy mã."),
    ],
    "5. KẾ HOẠCH THỰC HIỆN": [
        ("p", "Đề tài thực hiện trong 12 tuần, từ ngày 15/08/2026 đến ngày 06/11/2026. Bảng 0.1 trình bày nội dung công việc của từng tuần theo mục 10 của đề cương; phân công chi tiết cho từng thành viên nằm ở Bảng phân công nhiệm vụ ở phần đầu quyển."),
        ("table", "Kế hoạch thực hiện đề tài", "0", [900, 2000, 5604], ["Tuần", "Thời gian", "Nội dung công việc"], PLAN_ROWS, "Nguồn: đề cương chi tiết khóa luận CNTT-KLCN175"),
    ],
    "6. BỐ CỤC BÁO CÁO": [
        ("p", "Ngoài phần Mở đầu và Kết luận, báo cáo gồm năm chương:"),
        ("b1", "**Chương 1 – Khảo sát hệ thống và tổng quan:** khảo sát nhu cầu, quy trình ghi chép chi tiêu, các ứng dụng hiện có và biểu mẫu hóa đơn; tổng quan các hướng trích xuất thông tin hóa đơn, các công trình liên quan và công nghệ sử dụng."),
        ("b1", "**Chương 2 – Phân tích hệ thống:** mô hình hóa nghiệp vụ, use case hệ thống và đặc tả, sơ đồ lớp mức phân tích; phân tích bài toán và mô hình DONUT."),
        ("b1", "**Chương 3 – Thiết kế hệ thống:** kiến trúc tổng thể, cơ sở dữ liệu, bộ nhớ đệm, API và bảo mật, giao diện, sơ đồ lớp thiết kế, thiết kế chức năng và thiết kế mô hình AI."),
        ("b1", "**Chương 4 – Cài đặt hệ thống:** môi trường, chuẩn bị dữ liệu, huấn luyện DONUT, cài đặt AI Service, Core Backend, ứng dụng di động, Web Admin và đóng gói Docker."),
        ("b1", "**Chương 5 – Thử nghiệm và triển khai:** đánh giá mô hình, kiểm thử chức năng, kiểm thử API và hiệu năng, triển khai hệ thống."),
    ],
    # --------------------------------------------------------------- CHƯƠNG 1
    "GIỚI THIỆU": [
        ("p", "Chương này trình bày kết quả khảo sát làm cơ sở cho việc phân tích và thiết kế ở các chương sau. Phần đầu khảo sát nhu cầu quản lý tài chính cá nhân, quy trình ghi chép chi tiêu đang được áp dụng, ba ứng dụng quản lý tài chính trên thị trường và các loại hóa đơn mà hệ thống cần xử lý. Phần sau tổng quan ba hướng trích xuất thông tin hóa đơn, các bộ dữ liệu và cuộc thi liên quan, và các công nghệ nhóm sử dụng để xây dựng hệ thống."),
    ],
    "Nhu cầu quản lý tài chính cá nhân": [
        ("p", "Trong đề tài, nhóm hiểu quản lý tài chính cá nhân là việc ghi nhận các khoản thu và chi, phân loại chúng theo nhóm nhu cầu, đặt hạn mức chi tiêu và theo dõi mức độ thực hiện theo thời gian. Mục đích của việc này là giúp người dùng biết tiền của mình đi đâu, phát hiện các khoản chi vượt dự tính và dành ra một phần để tiết kiệm."),
        ("p", "Nhu cầu này gắn với mức độ tham gia vào hệ thống tài chính chính thức. Số liệu Global Findex 2025 cho thấy năm 2024 tỉ lệ người trưởng thành có tài khoản trên toàn cầu là 79%, tăng 28 điểm phần trăm so với mức 51% của năm 2011 [41]. Tại Việt Nam, 71% người trưởng thành có tài khoản, 62% thực hiện hoặc nhận thanh toán số, 45% có tiết kiệm qua kênh chính thức và 98% sở hữu điện thoại di động [41]. Tỉ lệ sở hữu điện thoại gần như tuyệt đối cho thấy điện thoại là kênh phù hợp để triển khai công cụ quản lý chi tiêu. Cũng theo báo cáo, chênh lệch tỉ lệ sở hữu tài khoản giữa nhóm thu nhập cao và thấp ở Việt Nam là 37 điểm phần trăm, lớn nhất thế giới [41], nên một bộ phận người dùng vẫn chi tiêu chủ yếu bằng tiền mặt và nhận hóa đơn giấy."),
        ("p", "Từ các số liệu trên, nhóm xác định người dùng mục tiêu của hệ thống là cá nhân dùng điện thoại thông minh, chi tiêu qua nhiều kênh (tiền mặt, thẻ, ví điện tử) và có nhu cầu gom các khoản chi về một nơi để theo dõi theo tuần hoặc theo tháng."),
    ],
    "Quy trình ghi chép chi tiêu hiện nay": [
        ("p", "Qua khảo sát, nhóm mô tả quy trình ghi chép chi tiêu phổ biến hiện nay bằng sơ đồ hoạt động ở Hình 1.1. Sau khi mua hàng, người dùng nhận hóa đơn giấy hoặc hóa đơn điện tử và cất giữ lại. Đến cuối ngày hoặc cuối tuần, họ mở sổ ghi chép (sổ tay, bảng tính hoặc ứng dụng), đọc từng hóa đơn để lấy tên cửa hàng, thời gian và tổng tiền, chọn danh mục rồi nhập tay một dòng thu chi. Sau khi nhập hết, công cụ ghi chép cộng dồn chi tiêu theo danh mục; người dùng đối chiếu với hạn mức đã đặt và tự điều chỉnh nếu vượt."),
        ("fig", "Quy trình ghi chép chi tiêu thủ công", "1", PNG + "ch1_quy_trinh_ghi_chep_thu_cong.png", 10.5, "nguồn: nhóm thực hiện", None),
        ("p", "Khi dùng ứng dụng quản lý tài chính, bước tổng hợp và so sánh với hạn mức được tự động hóa: ứng dụng tự cộng dồn, vẽ biểu đồ và cảnh báo khi vượt ngân sách. Tuy vậy, bước đọc hóa đơn và nhập tay vẫn do người dùng thực hiện, trừ các giao dịch được đồng bộ từ ngân hàng ở những ứng dụng có hỗ trợ liên kết tài khoản [42], [43]."),
    ],
    "Hạn chế của quy trình ghi chép thủ công": [
        ("p", "Quy trình ở Hình 1.1 có bốn hạn chế chính."),
        ("b1", "**Tốn thời gian và dễ bỏ dở.** Mỗi hóa đơn cần ít nhất bốn thao tác nhập (cửa hàng, thời gian, số tiền, danh mục). Khi số hóa đơn tích lũy nhiều, người dùng dễ bỏ qua việc ghi chép."),
        ("b1", "**Dễ sai số liệu.** Số tiền trên hóa đơn Việt Nam có thể dùng dấu chấm hoặc dấu phẩy để phân cách hàng nghìn (ví dụ “20.000” và “100,000” trong cùng tập dữ liệu của nhóm), dễ gõ nhầm số chữ số."),
        ("b1", "**Mất hóa đơn gốc.** Theo quan sát của nhóm, hóa đơn giấy dễ thất lạc hoặc mờ chữ sau một thời gian cất giữ; khi cần đối chiếu lại một khoản chi, bản giấy có thể không còn đọc được."),
        ("b1", "**Phản hồi chậm.** Khi chỉ nhập vào cuối tuần, cảnh báo vượt ngân sách đến muộn, lúc người dùng đã chi quá hạn mức."),
        ("p", "Hạn chế thứ nhất và thứ hai nằm ở bước chuyển thông tin từ hóa đơn vào hệ thống. Đây là bước đề tài tự động hóa bằng mô hình trích xuất thông tin từ ảnh, kèm bước đối soát để người dùng sửa kết quả trước khi lưu."),
    ],
    "Ứng dụng Money Lover": [
        ("p", "Money Lover do Finsify phát triển, có tên hiển thị trên Google Play tiếng Việt là “Money Lover: Sổ Thu Chi”, trên 5 triệu lượt tải và điểm đánh giá 4,1 tại thời điểm khảo sát (21/10/2026) [42]. Theo mô tả của nhà phát triển, ứng dụng cho phép nhập nhanh giao dịch thu chi, đặt ngân sách cho từng danh mục và dự báo chi tiêu, xem báo cáo bằng biểu đồ, lập kế hoạch tiết kiệm và đồng bộ dữ liệu giữa các thiết bị [42]. Gói trả phí bổ sung nhiều ví và các báo cáo đa dạng hơn; gói ví liên kết đồng bộ tự động số dư và lịch sử giao dịch từ một số ngân hàng Việt Nam [42]. Hình 1.2 minh họa giao diện chính của ứng dụng."),
        ("fig", "Giao diện ứng dụng Money Lover", "1", None, 0, "nguồn: nhóm chụp từ ứng dụng", "[T7.1 – nhóm chèn ảnh chụp màn hình Money Lover]"),
        ("p", "Mô tả trên Google Play của Money Lover không đề cập chức năng quét hóa đơn bằng camera [42]. Với các khoản chi bằng tiền mặt, người dùng vẫn phải nhập tay."),
    ],
    "Ứng dụng MISA MoneyKeeper": [
        ("p", "MISA MoneyKeeper do Công ty Cổ phần MISA phát triển, có tên hiển thị trên Google Play tiếng Việt là “Sổ Thu Chi MISA: My Money”, trên 1 triệu lượt tải tại thời điểm khảo sát [43]. Ứng dụng quản lý nhiều loại tài khoản (tiền mặt, tài khoản ngân hàng, ví điện tử, sổ tiết kiệm), tự phân loại giao dịch, đặt ngân sách theo danh mục và cảnh báo trước khi chi vượt, xuất báo cáo ra Excel/PDF, đồng bộ dữ liệu giữa điện thoại và máy tính bảng, và liên kết ngân hàng để giao dịch tự cập nhật [43]. Giao diện ứng dụng được minh họa ở Hình 1.3."),
        ("fig", "Giao diện ứng dụng MISA MoneyKeeper", "1", None, 0, "nguồn: nhóm chụp từ ứng dụng", "[T7.1 – nhóm chèn ảnh chụp màn hình MISA MoneyKeeper]"),
        ("p", "Đây là ứng dụng duy nhất trong ba ứng dụng khảo sát có mô tả chức năng quét hóa đơn bằng trí tuệ nhân tạo: người dùng chụp hóa đơn, ứng dụng ghi khoản chi mà không cần gõ và tự phân loại [43]. Tuy nhiên, nhà phát triển không công bố mô hình sử dụng, các trường được trích xuất hay độ chính xác, nên không thể dùng làm cơ sở so sánh định lượng."),
    ],
    "Ứng dụng Sổ thu chi: Quản lý chi tiêu": [
        ("p", "Tên “Sổ thu chi” được nhiều ứng dụng trên Google Play sử dụng, kể cả Money Lover và MISA MoneyKeeper ở hai mục trên. Nhóm chọn ứng dụng có tên chính là “Sổ thu chi : Quản lý chi tiêu” của nhà phát triển Horoscope365, vì đây là ứng dụng mang tên này có lượt tải cao nhất (trên 5 triệu) khi tìm kiếm “sổ thu chi” trên Google Play Việt Nam ngày 21/10/2026 [44]. Ứng dụng đại diện cho nhóm sổ thu chi đơn giản: người dùng nhập khoản thu hoặc chi trên một màn hình, tự tạo danh mục, đặt ngân sách và xem lịch, báo cáo và biểu đồ [44]. Hình 1.4 minh họa giao diện ứng dụng."),
        ("fig", "Giao diện ứng dụng Sổ thu chi: Quản lý chi tiêu", "1", None, 0, "nguồn: nhóm chụp từ ứng dụng", "[T7.1 – nhóm chèn ảnh chụp màn hình Sổ thu chi (Horoscope365)]"),
        ("p", "Dữ liệu của ứng dụng được lưu cục bộ trên máy theo mô tả “phiên bản ngoại tuyến” [44]; mô tả không đề cập liên kết ngân hàng hay quét hóa đơn. Vì vậy, khi đổi điện thoại, người dùng có thể phải tự sao lưu và chuyển dữ liệu."),
    ],
    "So sánh tính năng và định hướng của đề tài": [
        ("p", "Bảng 1.1 tổng hợp các tính năng của ba ứng dụng theo mô tả chính thức trên Google Play, đặt cạnh hệ thống của đề tài. Ô “Không nêu” nghĩa là mô tả của nhà phát triển không đề cập tính năng đó, không có nghĩa là ứng dụng chắc chắn không có."),
        ("table", "So sánh tính năng các ứng dụng quản lý tài chính cá nhân", "1", [1704, 1700, 1700, 1700, 1700],
         ["Tính năng", "Money Lover", "MISA MoneyKeeper", "Sổ thu chi (Horoscope365)", "Hệ thống của đề tài"],
         [
             ["Nhập thu chi thủ công, danh mục", "Có", "Có", "Có", "Có"],
             ["Ngân sách theo danh mục", "Có", "Có, cảnh báo trước khi vượt", "Có", "Có, theo tuần/tháng, cảnh báo ở 80% và 100%"],
             ["Báo cáo, biểu đồ", "Có", "Có, xuất Excel/PDF", "Có", "Có, kèm báo cáo thói quen chi tiêu"],
             ["Nhiều ví/tài khoản", "Có (gói trả phí)", "Có", "Không nêu", "Không (một số dư ví)"],
             ["Liên kết ngân hàng", "Có (gói trả phí)", "Có", "Không nêu", "Không"],
             ["Quét hóa đơn bằng AI", "Không nêu", "Có, không công bố trường trích xuất", "Không nêu", "Có, DONUT trích 4 trường, người dùng đối soát"],
             ["Đồng bộ đám mây", "Có", "Có", "Không, lưu cục bộ", "Có, lưu trên Core Backend, hàng đợi khi mất mạng"],
             ["Mục tiêu tiết kiệm", "Có", "Không nêu", "Không nêu", "Có"],
             ["Gói trả phí", "Có", "Có", "Có mua trong ứng dụng", "Có (gói PRO)"],
         ],
         "Nguồn: nhóm tổng hợp từ [42], [43], [44] (truy cập 21/10/2026) và mã nguồn hệ thống"),
        ("p", "Từ Bảng 1.1, nhóm rút ra ba nhận xét. Thứ nhất, các chức năng nền tảng (nhập thu chi, danh mục, ngân sách, báo cáo) đã phổ biến; hệ thống của đề tài phải có đủ các chức năng này để dùng được trong thực tế. Thứ hai, cách giảm công nhập liệu mà hai ứng dụng lớn chọn là liên kết ngân hàng, vốn không áp dụng được cho các khoản chi bằng tiền mặt có hóa đơn giấy. Thứ ba, chức năng quét hóa đơn bằng AI đã xuất hiện trên thị trường nhưng ở dạng đóng: người dùng không biết trường nào được trích xuất và kết quả có đáng tin hay không. Chưa ứng dụng nào trong ba ứng dụng công bố một mô hình trích xuất các trường thông tin cụ thể từ hóa đơn tiếng Việt kèm độ chính xác đo được."),
        ("p", "Do đó, định hướng của đề tài là xây dựng đủ các chức năng nền tảng và tập trung vào phần còn thiếu: một mô hình trích xuất bốn trường thông tin từ ảnh hóa đơn tiếng Việt được huấn luyện và đánh giá công khai theo từng trường, cùng quy trình đối soát cho phép người dùng kiểm tra và sửa kết quả trước khi ghi thành giao dịch. Nhóm không triển khai liên kết ngân hàng và nhiều ví, vì hai chức năng này nằm ngoài mục tiêu của đề cương."),
    ],
    "Danh sách biểu mẫu thu thập": [
        ("p", "Hệ thống xử lý chứng từ phát sinh khi người dùng mua hàng. Nhóm phân các chứng từ này thành ba loại biểu mẫu, liệt kê ở Bảng 1.2."),
        ("table", "Danh sách biểu mẫu hóa đơn khảo sát", "1", [750, 2050, 3504, 2200],
         ["STT", "Loại biểu mẫu", "Hình thức và đặc điểm", "Liên quan đến hệ thống"],
         [
             ["1", "Hóa đơn bán lẻ của siêu thị, cửa hàng tiện lợi", "Giấy in nhiệt khổ hẹp, in từ máy bán hàng (POS). Đầu hóa đơn có tên chuỗi, địa chỉ chi nhánh; giữa là danh sách mặt hàng; cuối là tổng tiền, tiền khách đưa, tiền thối.", "Đối tượng chính của mô hình; thường có đủ bốn trường"],
             ["2", "Hóa đơn, phiếu thanh toán của nhà hàng, quán ăn, quán cà phê", "In nhiệt hoặc viết tay; có số bàn, tên thu ngân, phí dịch vụ, giảm giá; có thể có nhiều dòng tổng (tạm tính, tổng cộng, thanh toán).", "Thuộc phạm vi mô hình; khó ở trường Total Cost"],
             ["3", "Hóa đơn điện tử", "Tệp điện tử do người bán lập và gửi qua thư điện tử hoặc cổng tra cứu, có ký hiệu, số hóa đơn, mã số thuế và chữ ký số theo quy định [1], [2].", "Người dùng có thể chụp màn hình bản thể hiện để quét; dữ liệu có cấu trúc sẵn"],
         ],
         "Nguồn: nhóm thực hiện khảo sát"),
        ("p", "Tập dữ liệu nhóm dùng để huấn luyện và đánh giá gồm 6.351 ảnh hóa đơn, mỗi ảnh kèm nhãn JSON phẳng gồm bốn khóa SELLER, ADDRESS, TIMESTAMP, TOTAL_COST. Tập được chia theo tỉ lệ xấp xỉ 80/10/10 thành 5.080 ảnh huấn luyện, 635 ảnh kiểm định và 636 ảnh kiểm thử. Quy trình thu thập, gán nhãn và chuẩn hóa được trình bày ở Chương 4."),
        ("y", "[T7.1 – nhóm bổ sung] Nguồn gốc tập 6.351 ảnh (tự chụp / MC-OCR / nguồn khác, giấy phép) và số lượng ảnh theo từng loại biểu mẫu ở Bảng 1.2, nếu nhóm có thống kê."),
    ],
    "Hóa đơn siêu thị và cửa hàng tiện lợi": [
        ("p", "Hóa đơn của siêu thị và cửa hàng tiện lợi có bố cục ổn định trong cùng một chuỗi: tên chuỗi và địa chỉ chi nhánh ở đầu, ngày giờ in cùng số hóa đơn ngay bên dưới, phần cuối có dòng tổng tiền in đậm hoặc cỡ chữ lớn. Hình 1.5 là một hóa đơn mẫu thuộc loại này. Khó khăn khi đọc tự động nằm ở chỗ tên người bán in trên hóa đơn có thể là tên pháp nhân (ví dụ “VinCommerce” trong tập dữ liệu của nhóm) thay vì tên cửa hàng mà người dùng quen gọi, và địa chỉ thường viết tắt (“P.”, “TP.”, “Q.”)."),
        ("fig", "Hóa đơn mẫu của siêu thị / cửa hàng tiện lợi", "1", None, 0, "nguồn: nhóm thu thập", "[T7.1 – nhóm chèn ảnh hóa đơn siêu thị hoặc cửa hàng tiện lợi]"),
    ],
    "Hóa đơn nhà hàng và quán ăn": [
        ("p", "Hóa đơn nhà hàng, quán ăn và quán cà phê (Hình 1.6) đa dạng hơn: mỗi cửa hàng dùng một mẫu riêng, nhiều nơi in tên thương hiệu bằng chữ in hoa không dấu hoặc bằng tiếng Anh (ví dụ “HIGHLANDS COFFEE”, “PHUC LONG Coffee & Tea”). Phần cuối thường có nhiều dòng số tiền liên tiếp như tạm tính, giảm giá, phí phục vụ và tổng thanh toán, nên mô hình phải chọn đúng dòng tổng cuối cùng."),
        ("fig", "Hóa đơn mẫu của nhà hàng / quán cà phê", "1", None, 0, "nguồn: nhóm thu thập", "[T7.1 – nhóm chèn ảnh hóa đơn nhà hàng hoặc quán cà phê]"),
    ],
    "Hóa đơn điện tử": [
        ("p", "Từ ngày 01/07/2022, hóa đơn điện tử được áp dụng bắt buộc theo Nghị định 123/2020/NĐ-CP [1]. Nghị định này đã được thay thế bởi Nghị định 254/2026/NĐ-CP về hóa đơn điện tử, chứng từ điện tử, có hiệu lực từ ngày 01/07/2026 [2]. Hóa đơn điện tử là dữ liệu có cấu trúc do người bán lập, gồm ký hiệu, số hóa đơn, thông tin người bán và người mua, mã số thuế, danh sách hàng hóa và tổng tiền thanh toán [1], [2]. Hình 1.7 minh họa bản thể hiện của một hóa đơn điện tử."),
        ("fig", "Bản thể hiện của hóa đơn điện tử", "1", None, 0, "nguồn: nhóm thu thập", "[T7.1 – nhóm chèn ảnh bản thể hiện hóa đơn điện tử (đã che thông tin cá nhân)]"),
        ("p", "Với người dùng cá nhân, hóa đơn điện tử ít khi được lập riêng cho từng lần mua lẻ; ở quầy thanh toán, người dùng chủ yếu nhận phiếu in nhiệt. Vì vậy, đề tài tập trung vào ảnh chụp hóa đơn giấy; bản thể hiện của hóa đơn điện tử được xử lý như một ảnh hóa đơn thông thường."),
    ],
    "Đặc điểm của bốn trường thông tin cần trích xuất": [
        ("p", "Bốn trường thông tin cần trích xuất tương ứng với bốn trường SELLER, SELLER ADDRESS, TIMESTAMP, TOTAL COST của cuộc thi MC-OCR cho hóa đơn tiếng Việt [22]. Bảng 1.3 tóm tắt vị trí thường gặp, định dạng và các biến thể mà nhóm ghi nhận trong nhãn của tập dữ liệu."),
        ("table", "Đặc điểm của bốn trường thông tin cần trích xuất", "1", [1750, 1900, 2504, 2350],
         ["Trường", "Vị trí thường gặp", "Ví dụ trong tập dữ liệu", "Biến thể và nhiễu"],
         [
             ["SELLER\n(tên người bán)", "Dòng đầu hóa đơn, thường in hoa hoặc là logo", "“HIGHLANDS COFFEE”, “VinCommerce”, “MINIMART ANAN”", "Tên pháp nhân khác tên cửa hàng; logo dạng hình; chữ không dấu"],
             ["ADDRESS\n(địa chỉ)", "Ngay dưới tên người bán, có thể kéo dài 2–3 dòng", "“216 Vo Van Ngan, Ward Binh Tho, Thu Duc”", "Viết tắt (P., Q., TP.); có hoặc không dấu; trộn tiếng Anh"],
             ["TIMESTAMP\n(thời gian)", "Phần đầu, cạnh số hóa đơn hoặc tên thu ngân", "“14/02/2023”, “15/08/2020-17:29”, “31/03/2023 20:02:49”", "Có hoặc không có giờ, giây; ký tự nối khác nhau"],
             ["TOTAL_COST\n(tổng tiền)", "Phần cuối, sau danh sách mặt hàng", "“100,000”, “20.000”, “205.500”", "Dấu phân cách hàng nghìn là “.” hoặc “,”; nhiều dòng tổng"],
         ],
         "Nguồn: nhóm tổng hợp từ nhãn của tập dữ liệu"),
        ("p", "Nhãn của tập dữ liệu không đầy đủ cho mọi trường. Trong 5.080 ảnh huấn luyện, chỉ 450 ảnh có đủ cả bốn trường; số ảnh có nhãn rỗng là 2.757 với SELLER, 3.822 với ADDRESS, 2.702 với TIMESTAMP và 1.530 với TOTAL_COST. Tỉ lệ tương tự xuất hiện ở tập kiểm định (49/635 ảnh đủ bốn trường) và tập kiểm thử (59/636). Đặc điểm này ảnh hưởng trực tiếp đến cách đánh giá mô hình ở Chương 5: trường có nhãn rỗng phải được tính riêng để không làm sai lệch độ chính xác."),
        ("p", "Do có nhiều biến thể định dạng, đầu ra của mô hình cần một bước hậu xử lý bằng biểu thức chính quy (Regex) trước khi ghi vào giao dịch. Ở phiên bản AI Service hiện tại, bước này đưa TOTAL_COST về số nguyên bằng cách bỏ dấu phân cách hàng nghìn; các luật chuẩn hóa cho những trường còn lại được trình bày ở Chương 3."),
    ],
    # 1.5 – 1.6: điền sau khi đối chiếu tài liệu (xem content_t71_part2.py)
    "Flutter và Dart": [
        ("p", "Flutter là bộ công cụ giao diện mã nguồn mở của Google, cho phép xây dựng ứng dụng di động từ một mã nguồn duy nhất bằng ngôn ngữ Dart [33], [46]. Giao diện được mô tả bằng cây widget (thành phần giao diện); khi trạng thái thay đổi, Flutter dựng lại phần cây bị ảnh hưởng. Dart là ngôn ngữ hướng đối tượng, có kiểu tĩnh và cơ chế an toàn null, hỗ trợ lập trình bất đồng bộ bằng async/await [46]."),
        ("p", "Ứng dụng di động của đề tài dùng Dart SDK ^3.10.8. Các thư viện chính gồm dio (gọi API), sqflite (cơ sở dữ liệu SQLite cục bộ làm hàng đợi giao dịch khi mất mạng), fl_chart (biểu đồ), flutter_bloc (quản lý trạng thái giao diện sáng/tối và ngôn ngữ), image_picker và google_mlkit_document_scanner (chọn ảnh từ thư viện và chụp hóa đơn bằng camera)."),
    ],
    "Spring Boot, Spring Security và JWT": [
        ("p", "Spring Boot là nền tảng xây dựng ứng dụng Java theo hướng cấu hình tự động: nhà phát triển khai báo các “starter” và Spring Boot tự cấu hình máy chủ web, kết nối cơ sở dữ liệu, bộ nhớ đệm [31]. Core Backend của đề tài dùng Java 21 và Spring Boot 3.2.5, cùng Spring Data JPA (Jakarta Persistence API) để ánh xạ đối tượng – quan hệ và Hibernate Envers để lưu lịch sử thay đổi dữ liệu."),
        ("p", "Spring Security cung cấp chuỗi bộ lọc (filter chain) chặn mọi yêu cầu HTTP (Hypertext Transfer Protocol) để xác thực và phân quyền trước khi tới controller [32]. JSON Web Token (JWT) là chuẩn biểu diễn các khẳng định (claim) dưới dạng JSON, được ký số để bên nhận kiểm tra tính toàn vẹn [28]. Trong hệ thống, Core Backend cấp access token có hạn 15 phút và refresh token có hạn 30 ngày, ký bằng thuật toán HS256 qua thư viện JJWT 0.11.5; mỗi yêu cầu tới /api/**, trừ các đường dẫn công khai như /api/auth/** (đăng ký, đăng nhập, quên mật khẩu), được bộ lọc JWT kiểm tra trước khi xử lý, mật khẩu được băm bằng BCrypt."),
    ],
    "FastAPI, PyTorch và Hugging Face Transformers": [
        ("p", "FastAPI là framework web Python dựa trên gợi ý kiểu (type hint), dùng Pydantic để kiểm tra dữ liệu vào/ra và tự sinh tài liệu OpenAPI [34]. AI Service của đề tài viết bằng FastAPI trên Python 3.10, cung cấp endpoint POST /donut/scan nhận ảnh hóa đơn và trả về bốn trường thông tin, cùng các endpoint phân tích chi tiêu."),
        ("p", "PyTorch là thư viện học sâu theo phong cách lập trình mệnh lệnh, tính toán trên CPU hoặc GPU [14]. Hugging Face Transformers cung cấp cài đặt và trọng số huấn luyện sẵn của các mô hình Transformer, trong đó có VisionEncoderDecoderModel và DonutProcessor dùng cho DONUT [13], [40]. Nhóm dùng hai thư viện này để tinh chỉnh mô hình trên GPU của Kaggle và để chạy suy luận trong AI Service."),
    ],
    "PostgreSQL, Redis và MongoDB": [
        ("p", "PostgreSQL là hệ quản trị cơ sở dữ liệu quan hệ mã nguồn mở, hỗ trợ giao dịch ACID (Atomicity, Consistency, Isolation, Durability – tính nguyên tử, nhất quán, cô lập, bền vững), ràng buộc khóa ngoại, khóa duy nhất và khóa dòng [35]. Đề tài dùng PostgreSQL 15 để lưu người dùng, giao dịch, hóa đơn, ngân sách và nhật ký hoạt động; các thao tác thay đổi số dư ví được khóa dòng bi quan để tránh ghi đè khi có yêu cầu đồng thời."),
        ("p", "Redis là kho dữ liệu khóa – giá trị lưu trong bộ nhớ, thường dùng làm bộ nhớ đệm [36]. Hệ thống dùng Redis để lưu tạm kết quả các truy vấn thống kê (bảng điều khiển của người dùng và của quản trị viên) với thời gian sống 45–60 giây, và xóa bộ đệm sau khi giao dịch cơ sở dữ liệu được xác nhận. MongoDB là cơ sở dữ liệu hướng tài liệu, lưu bản ghi dạng BSON (Binary JSON – JSON nhị phân) không cần lược đồ cố định [37]; nhóm dùng MongoDB để lưu nhật ký thô của các lần suy luận AI, vì cấu trúc kết quả trả về của mô hình có thể thay đổi giữa các phiên bản."),
    ],
    "Docker và GitHub Actions": [
        ("p", "Docker đóng gói ứng dụng cùng toàn bộ phụ thuộc thành image (ảnh đóng gói) và chạy dưới dạng container (vùng chạy cô lập); Docker Compose mô tả nhiều container cùng mạng, volume (vùng lưu trữ) và thứ tự khởi động trong một tệp YAML [38]. Hệ thống của đề tài được mô tả trong một tệp docker-compose.yml gồm năm dịch vụ: PostgreSQL, Redis, MongoDB, Core Backend và AI Service. Core Backend chỉ khởi động khi PostgreSQL, Redis và AI Service đã vượt qua kiểm tra sức khỏe (healthcheck); MongoDB không chặn việc khởi động vì chỉ dùng để lưu nhật ký."),
        ("p", "GitHub Actions là dịch vụ tích hợp và triển khai liên tục (CI/CD) của GitHub, chạy các quy trình (workflow) khai báo bằng YAML khi có sự kiện trên kho mã [45]. Workflow của đề tài chạy kiểm thử Core Backend, ứng dụng di động và AI Service song song; khi cả ba thành công trên nhánh main, bước triển khai kết nối SSH (Secure Shell – giao thức truy cập từ xa có mã hóa) tới máy chủ, kéo mã mới và khởi động lại các container."),
    ],
    "KẾT CHƯƠNG": [
        ("p", "Chương 1 đã xác định nhu cầu và người dùng mục tiêu của hệ thống, chỉ ra bước nhập liệu từ hóa đơn là khâu tốn công và dễ sai của quy trình ghi chép chi tiêu. Khảo sát ba ứng dụng trên thị trường cho thấy các chức năng nền tảng đã phổ biến, còn chức năng quét hóa đơn bằng AI mới xuất hiện ở dạng đóng. Khảo sát biểu mẫu xác định ba loại hóa đơn và đặc điểm của bốn trường cần trích xuất, trong đó TOTAL_COST và TIMESTAMP có nhiều biến thể định dạng cần hậu xử lý."),
        ("p", "Phần tổng quan cho thấy hướng OCR-free với DONUT tránh được việc lan truyền lỗi từ bước OCR và chỉ cần nhãn mức tài liệu, phù hợp với tập dữ liệu nhãn JSON của nhóm. Các bộ dữ liệu SROIE, CORD và MC-OCR cho biết cách đặt bài toán và đánh giá, trong đó MC-OCR dùng đúng bốn trường của đề tài. Chương 2 sẽ dựa trên các kết quả này để mô hình hóa nghiệp vụ, đặc tả chức năng và phân tích chi tiết mô hình DONUT."),
    ],
}

ABBREVIATIONS = [
    ("CORD", "Consolidated Receipt Dataset", "Bộ dữ liệu hóa đơn hợp nhất CORD"),
    ("GNN", "Graph Neural Network", "Mạng nơ-ron đồ thị"),
    ("HTTP", "Hypertext Transfer Protocol", "Giao thức truyền tải siêu văn bản"),
    ("ICDAR", "International Conference on Document Analysis and Recognition", "Hội nghị quốc tế về phân tích và nhận dạng tài liệu"),
    ("MC-OCR", "Mobile-Captured Image Document Recognition for Vietnamese Receipts", "Cuộc thi nhận dạng ảnh hóa đơn tiếng Việt chụp bằng điện thoại"),
    ("POS", "Point of Sale", "Máy bán hàng tại quầy"),
    ("Regex", "Regular Expression", "Biểu thức chính quy"),
    ("SROIE", "Scanned Receipts OCR and Information Extraction", "Cuộc thi OCR và trích xuất thông tin hóa đơn scan"),
    ("YAML", "YAML Ain't Markup Language", "Định dạng tệp cấu hình YAML"),
]

# Gộp mục 1.5 – 1.6
import importlib.util as _u, os as _os
_spec = _u.spec_from_file_location("part2", _os.path.join(_os.path.dirname(__file__), "content_t71_part2.py"))
_p2 = _u.module_from_spec(_spec); _spec.loader.exec_module(_p2)
SECTIONS.update(_p2.SECTIONS2)
ABBREVIATIONS += _p2.ABBREVIATIONS2
