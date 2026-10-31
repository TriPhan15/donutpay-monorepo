"""K8 (v17 -> v18): viết phần Kết luận mục 1-3 và các hướng phát triển còn lại của mục 4.

Chỉ dùng kết quả đã có trong Chương 3-4 và các tệp dữ kiện (docs/thesis/facts*.md, v5_results.md).
Không dẫn kết quả của Chương 5. Lời cảm ơn và Bảng phân công không nằm trong module này.

Các mục được thay bằng HEADING_PLACEHOLDERS: dòng giữ chỗ [T7.9] đầu tiên sau mỗi tiêu đề mục của Kết luận.
"""

SESSION_TAG = None
SECTIONS = {}

HEADING_PLACEHOLDERS = {
    "1. KẾT QUẢ ĐẠT ĐƯỢC": [
        ("p",
         "Phần khảo sát và phân tích gồm nhu cầu quản lý tài chính cá nhân, ba ứng dụng trên Google Play và các loại "
         "hóa đơn bán lẻ, từ đó xác định 26 ca sử dụng và 15 lớp thực thể mức phân tích. Hệ thống được thiết kế gồm "
         "ứng dụng di động, Web Admin, Core Backend và AI Service, với PostgreSQL, Redis và MongoDB làm kho dữ liệu "
         "(mục 3.2). Thiết kế chi tiết gồm cơ sở dữ liệu, 51 điểm cuối REST, 22 màn hình của ứng dụng di động, "
         "9 trang Web Admin và các quyết định để giao dịch không bị trùng hay mất khi mất mạng (mục 3.8)."),
        ("p",
         "Ứng dụng di động cho phép ghi thu chi bằng tay hoặc từ ảnh hóa đơn, lưu giao dịch vào SQLite khi mất mạng "
         "rồi gửi lại với clientId để máy chủ không tạo bản trùng, theo dõi ngân sách với cảnh báo ở mức 80% và 100%, "
         "và xem thống kê cùng báo cáo thói quen chi tiêu ở tab AI (mục 4.7). Web Admin quản lý người dùng, danh mục, "
         "hóa đơn, gói dịch vụ, đánh giá, nhật ký kiểm toán và sao lưu cơ sở dữ liệu, đồng thời chạy phân khúc khách "
         "hàng (mục 4.8). Core Backend xác thực bằng JWT có thu hồi token, khóa dòng ví khi đổi số dư và lưu thống kê "
         "trong bộ nhớ đệm Redis (mục 4.6)."),
        ("p",
         "Về trích xuất hóa đơn, nhóm gán nhãn lại 6.351 ảnh của tập data1 bằng hai mô hình thị giác – ngôn ngữ kết hợp "
         "người duyệt, nâng số ảnh huấn luyện có đủ bốn trường từ 450 lên 3.463 (Bảng 4.2). DONUT V5 được tinh chỉnh "
         "từ donut-base-finetuned-cord-v2 với ảnh đầu vào 1920 × 1440 và tokenizer thêm 65 ký tự tiếng Việt. Checkpoint "
         "được chọn theo field_exact thay vì theo loss như bản V3 và đạt 93,50% trên 150 ảnh validation ở bước 3200. "
         "Trên 636 ảnh test, tỉ lệ trường khớp hoàn toàn là 89,99% khi chưa hậu xử lý và 91,01% sau khi qua mô-đun hậu "
         "xử lý bằng biểu thức chính quy, tức 2.036 trong 2.237 trường có nhãn (Bảng 4.8). Kết quả quét được người "
         "dùng đối soát trước khi ghi thành giao dịch."),
        ("p",
         "Phía máy chủ được đóng gói thành sáu container, trong đó Caddy là cửa vào duy nhất (mục 4.9). Quy trình tích "
         "hợp liên tục trên GitHub Actions chạy kiểm thử của Core Backend, ứng dụng di động và AI Service mỗi khi "
         "đẩy mã lên nhánh chính hoặc mở pull request (mục 4.2.2)."),
    ],
    "2. ĐÁNH GIÁ KẾT QUẢ": [
        ("p",
         "Phần này đối chiếu kết quả với ba mục tiêu ở Mở đầu. Mở đầu không đặt ngưỡng định lượng nào cho độ chính xác "
         "trích xuất hay hiệu năng, nên các nhận định dưới đây mô tả mức đạt được chứ không so với một chỉ tiêu định sẵn."),
        ("p",
         "Mục tiêu khảo sát và thiết kế đã được thực hiện: nhu cầu, ba ứng dụng hiện có và các loại hóa đơn được khảo "
         "sát ở Chương 1, nghiệp vụ được phân tích bằng 26 ca sử dụng ở Chương 2, và kiến trúc được thiết kế ở Chương 3. "
         "Kiến trúc microservices chỉ được áp dụng ở mức vừa phải, với hai dịch vụ nghiệp vụ là Core Backend và AI "
         "Service, còn Web Admin nằm trong Core Backend (mục 3.2.1). AI Service là một dịch vụ riêng như mục tiêu "
         "yêu cầu, nhưng mỗi lúc chỉ đọc một hóa đơn (mục 4.5.1), nên việc tách riêng giúp triển khai độc lập chứ "
         "chưa giúp xử lý song song cho nhiều người dùng."),
        ("p",
         "Mục tiêu xây dựng hệ thống tích hợp: cả bốn nhóm nghiệp vụ mà Mở đầu nêu là giao dịch, ngân sách, thống kê "
         "và quản trị đều đã được cài đặt trên ứng dụng di động hoặc Web Admin (mục 4.6 đến 4.8). Số lượng kiểm thử "
         "nêu trong Chương 3 và Chương 4 chỉ có của AI Service, với 305 test đạt và 8 test bị bỏ qua ở lần chạy ngày "
         "31/10/2026 (mục 4.5.3). Kết quả kiểm thử của Core Backend và ứng dụng di động, kiểm thử API và hiệu năng "
         "thuộc Chương 5, nên phần này chưa đánh giá mức chính xác của các chức năng đó."),
        ("p",
         "Mục tiêu trích xuất bốn trường bằng DONUT OCR-free đạt ở chỗ mô hình V5 đang phục vụ cả bốn trường trong AI "
         "Service và đọc đúng 91,01% trường có nhãn của tập test sau hậu xử lý. Mức này không đều giữa các trường: "
         "TOTAL_COST đạt 97,31% và TIMESTAMP đạt 95,06%, còn SELLER là 87,97% và ADDRESS là 81,85% (Bảng 4.8). "
         "Mô-đun hậu xử lý làm đúng thêm 23 trường, trong đó 10 trường ADDRESS và 12 trường TIMESTAMP, và không làm "
         "sai trường nào đang đúng. Con số 93,50% trên validation là giá trị cao nhất trong 14 lần đánh giá trên "
         "cùng 150 ảnh (Bảng 4.5), nên không dùng để so với kết quả trên tập test."),
        ("p",
         "Cờ valid chỉ phát hiện 23 trong 201 trường còn sai (11,4%), vì phần lớn lỗi là giá trị đúng định dạng mà sai "
         "nội dung (mục 4.5.2). Vì vậy kết quả của AI chỉ được điền sẵn vào biểu mẫu, và bước đối soát của người dùng "
         "vẫn cần thiết. Nhóm chưa có phép đo thời gian nhập liệu hay khảo sát người dùng để lượng hóa mức tiết "
         "kiệm công sức so với nhập tay."),
        ("p",
         "Mục tiêu đóng gói bằng Docker đã được cài đặt với sáu container (Bảng 4.12). Việc triển khai lên máy chủ được "
         "trình bày ở mục 5.5 nên không được đánh giá ở đây. Riêng giới hạn 3 GB của AI Service mới được chọn theo "
         "ước lượng, chưa đo trên máy chủ (mục 4.9)."),
    ],
    "3. HẠN CHẾ": [
        ("p",
         "Với mô hình và dữ liệu, ADDRESS vẫn là trường đọc kém nhất (81,85% sau hậu xử lý) và hóa đơn dài là nhóm khó "
         "nhất (mục 4.3.1). Hậu xử lý bằng luật không sửa được lỗi nội dung: SELLER không đổi sau hậu xử lý (87,97%) "
         "và cờ valid chỉ phát hiện 23 trong 201 trường còn sai. Nhãn của cả ba tập do hai mô hình thị giác – ngôn "
         "ngữ đọc rồi người duyệt, và vẫn còn trường chưa được kiểm tra: 1.044 dòng của tập train và 127 dòng của tập "
         "test có trường như vậy (Bảng 4.3), nên số đo trên test phụ thuộc vào chất lượng nhãn. Checkpoint cũng chỉ "
         "được chọn trên 150 trong 635 ảnh validation (mục 4.3.3). Các hằng số của phân tích chi tiêu (Bảng 3.31) là "
         "giá trị nhóm chọn, chưa được hiệu chỉnh bằng dữ liệu của nhiều người dùng."),
        ("p",
         "Với ứng dụng và Core Backend, hàng đợi quét nhiều hóa đơn chạy trên điện thoại nên chỉ đọc khi ứng dụng đang "
         "mở, nhận tối đa 20 mục và đọc lần lượt từng ảnh (mục 3.8.7). Duyệt hoặc từ chối hóa đơn chưa tạo thông báo "
         "cho người dùng (mục 3.8.6). Màn hình Dịch vụ liên kết và cổng thanh toán dùng dữ liệu giả lập, ứng dụng "
         "không kết nối với ngân hàng hay ví điện tử thật (mục 3.6.1). Mã PIN đã bị gỡ nên ứng dụng chưa có khóa màn "
         "hình (mục 4.7.2). Thao tác góp tiền tiết kiệm chưa có khóa chống gửi lặp như checkout, chức năng xuất Excel "
         "luôn lấy tháng chứa ngày đang chọn, và Core Backend chỉ trả thông báo bằng tiếng Việt (mục 4.7.3). Một số "
         "ràng buộc như amount > 0, rating từ 1 đến 5, các trạng thái của receipts và số dư không âm mới được bảo "
         "đảm ở tầng ứng dụng, chưa có CHECK ở cơ sở dữ liệu (mục 3.3.4)."),
        ("p",
         "Với hạ tầng, requirements.txt của AI Service không ghim phiên bản thư viện nên mỗi lần build image có thể "
         "cho kết quả khác nhau (mục 4.2.1). Trọng số mô hình (khoảng 806 MB) không nằm trong Git và phải chép thủ "
         "công lên máy chủ. Giới hạn bộ nhớ 3 GB của AI Service chưa được đo trên máy chủ và chỉ đủ cho một lượt "
         "suy luận mỗi lúc (mục 4.9)."),
    ],
    "4. HƯỚNG PHÁT TRIỂN": [
        ("p",
         "Với mô hình DONUT, lỗi tập trung ở ADDRESS và hóa đơn dài, nên bước tiếp theo là bổ sung hóa đơn dài và hóa "
         "đơn có địa chỉ viết tắt vào tập huấn luyện, duyệt nốt các trường còn chưa được kiểm tra (Bảng 4.3) rồi huấn "
         "luyện và đo lại. Cờ valid hiện chỉ dựa trên luật về định dạng. Có thể thêm một tín hiệu lấy từ chính mô "
         "hình, chẳng hạn xác suất của các token được sinh ra, để cảnh báo cả những giá trị đúng định dạng nhưng sai "
         "nội dung. Phạm vi trích xuất cũng có thể mở rộng sang danh sách mặt hàng, tiền thuế và mã số thuế, là các "
         "thông tin đề tài hiện loại ra (Mở đầu, mục 3)."),
        ("p",
         "Về triển khai, cần ghim phiên bản các thư viện trong requirements.txt để mỗi lần build image cho kết quả "
         "giống nhau, và đo bộ nhớ thực tế của container data-mining-api khi quét hóa đơn để xác nhận hoặc điều chỉnh "
         "giới hạn 3 GB. Trọng số mô hình có thể được đặt ở một kho lưu trữ riêng để bước build tự lấy về thay vì chép "
         "thủ công. Lược đồ cơ sở dữ liệu hiện do Hibernate cập nhật (ddl-auto=update) kèm các tệp SQL chạy tay "
         "(docs/deploy/MIGRATION_RUNBOOK.md). Một công cụ migration có đánh số phiên bản, như Flyway hoặc Liquibase, "
         "cho phép chạy các tệp đó tự động khi triển khai và thêm các ràng buộc CHECK còn thiếu (mục 3.3.4)."),
        ("p",
         "Về kiểm thử, ứng dụng di động mới có kiểm thử đơn vị và kiểm thử widget bằng flutter_test, chưa có kiểm thử "
         "tích hợp chạy trên thiết bị cho luồng từ camera, qua AI Service và đối soát, đến lúc lưu giao dịch. Mô hình "
         "cũng nên được đánh giá thêm trên ảnh do người dùng thật chụp ngoài tập data1, vì tập test hiện chia từ cùng "
         "nguồn với tập huấn luyện (mục 4.3.1). Cuối cùng, một khảo sát nhỏ so sánh thời gian nhập một hóa đơn bằng "
         "tay với thời gian quét và đối soát sẽ kiểm tra giả định nêu ở phần lý do chọn đề tài, đồng thời cho dữ liệu "
         "để hiệu chỉnh các hằng số của phân tích chi tiêu."),
    ],
}
