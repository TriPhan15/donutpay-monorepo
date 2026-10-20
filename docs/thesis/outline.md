# Dàn ý khóa luận CNTT-KLCN175 (T7.0)

- Ngày lập: 2026-10-21. Nguồn: `ycda.txt` (thang điểm mục 9), `format_khoaluan_2025.txt`, spec `docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`.
- File khung tương ứng: `KhoaLuan_KLCN175_v0.docx` (thư mục gốc repo). Các đề mục trong file khung trùng 1–1 với dàn ý này; mỗi mục lá có một dòng tô vàng `[phiên] ghi chú` để thay bằng nội dung.
- Số liệu hệ thống chỉ lấy từ `docs/thesis/facts.md`; trích dẫn chỉ lấy từ `docs/thesis/references.md`.
- Cột **Phiên**: phiên viết mục đó. Cột **Thang điểm**: mã dòng trong bảng dưới.

## 1. Mã dòng thang điểm (`ycda.txt` mục 9)

| Mã | STT | Nội dung | CLO | Điểm | Mục đáp ứng trong quyển |
|---|---|---|---|---|---|
| R1a | 1 | Xác định lý do, mục tiêu đề tài | CLO1.1 | 0.25 | Mở đầu › 1. Giới thiệu và lý do chọn đề tài, Mở đầu › 2. Mục tiêu đề tài, Mở đầu › 3. Đối tượng và phạm vi đề tài |
| R1b | 1 | Khảo sát hiện trạng: ứng dụng tài chính, quy trình và biểu mẫu hóa đơn | CLO1.1 | 0.5 | 1.2, 1.2.1, 1.2.2, 1.2.3, 1.3, 1.3.1, 1.3.2, 1.3.3 … (+7) |
| R2 | 2 | Lập kế hoạch và phân công thực hiện công việc | CLO6 | 0.25 | Bảng phân công nhiệm vụ, Mở đầu › 5. Kế hoạch thực hiện, 4.2.2 |
| R3a | 3 | Sơ đồ use case nghiệp vụ và đặc tả | CLO1.2 | 0.25 | 2.2, 2.2.1, 2.2.2, 2.2.3, 2.2.4, 2.2.5, 2.2.6, 2.2.7 |
| R3b | 3 | Sơ đồ use case hệ thống và đặc tả | CLO1.2 | 0.25 | 2.3, 2.3.1, 2.3.2, 2.3.3, 2.3.4 |
| R3c | 3 | Sơ đồ lớp phân tích | CLO1.2 | 0.25 | 2.4, 2.4.1, 2.4.2 |
| R4a | 4 | Sơ đồ lớp thiết kế | CLO2.1 | 0.25 | 3.7, 3.8 |
| R4b | 4 | Mô hình dữ liệu | CLO2.1 | 0.25 | 3.3, 3.3.1, 3.3.2, 3.3.3, 3.3.4, 3.4, 3.4.1, 3.4.2 |
| R4c | 4 | Thiết kế giao diện | CLO2.2 | 0.5 | 3.6, 3.6.1, 3.6.2, 4.7.3 |
| R5a | 5 | Khái niệm/định nghĩa: mô hình DONUT OCR-free | CLO1.1 | 0.25 | 1.5.3, 2.5, 2.5.3, 2.5.4, 2.5.5, 3.9.1 |
| R5b | 5 | Vấn đề thuật toán giải quyết: trích xuất không phụ thuộc OCR truyền thống | CLO1.1 | 0.25 | 1.5, 1.5.1, 1.5.2, 1.5.4, 2.5.1, 2.5.2 |
| R6.0 | 6 | Chức năng cơ bản: đăng nhập, đăng xuất, đổi mật khẩu, phân quyền (Spring Security & JWT) | CLO3 | 0.5 | 3.5, 3.5.1, 3.5.2, 3.8.1, 4.6, 4.6.1 |
| R6.1 | 6 | Chức năng 1: quản lý giao dịch, danh mục; đồng bộ lên Core Backend | CLO3 | 0.5 | 3.8.2, 4.6.2, 4.7, 4.7.1 |
| R6.2 | 6 | Chức năng 2: ngân sách tuần/tháng và cảnh báo vượt ngưỡng | CLO3 | 0.5 | 3.8.4, 4.6.3 |
| R6.3 | 6 | Chức năng 3: Web Admin (người dùng, danh mục mặc định, log, thống kê) | CLO3 | 0.5 | 3.8.6, 4.8 |
| R6.4 | 6 | Chức năng 4: biểu đồ trên Mobile và báo cáo thói quen tiêu dùng | CLO3 | 0.5 | 3.8.5, 4.6.4, 4.7.2 |
| R6.5 | 6 | Chức năng 5: chụp/chọn ảnh hóa đơn, trích xuất qua AI Service, đối soát | CLO3 | 0.5 | 3.8.3, 4.5, 4.5.1 |
| R6.6a | 6 | Cài đặt thuật toán: huấn luyện thành công DONUT | CLO3 | 0.5 | 3.9.2, 4.3, 4.3.1, 4.3.2, 4.3.3, 4.4, 4.4.1, 4.4.2 … (+6) |
| R6.6b | 6 | Tích hợp kết quả: Regex 4 trường, đối soát và cập nhật giao dịch | CLO3 | 0.5 | 3.9, 3.9.3, 4.5.2, 4.6.5 |
| R6.7 | 6 | Kiểm thử và triển khai hệ thống | CLO4 | 0.75 | 3.2.2, 4.9, 5.3, 5.3.1, 5.3.2, 5.4, 5.4.1, 5.4.2 … (+5) |
| R7 | 7 | Nội dung kiến thức trình bày trong quyển báo cáo | CLO5.1 | 0.5 | Mở đầu › 4. Phương pháp nghiên cứu, 1.6, 1.6.1, 1.6.2, 1.6.3, 1.7, 1.7.1, 1.7.2 … (+11) |
| R8 | 8 | Hình thức, định dạng quyển báo cáo | CLO5.1 | 0.5 | Lời cảm ơn, Nhận xét của giảng viên hướng dẫn, Mục lục, Danh mục các ký hiệu và chữ viết tắt, Danh mục hình, Danh mục bảng, Mở đầu › 6. Bố cục báo cáo, 1.1 … (+11) |
| — | 9, 10 | Thái độ (CLO6), slide (CLO5.2) | | 1.0 | Không nằm trong quyển. |
| — | 11 | Điểm cộng NCKH | CLO3 | ≤1.0 | Không nằm trong quyển. |

## 2. Dàn ý chi tiết

| Đề mục | Phiên | Thang điểm | Ghi chú nội dung |
|---|---|---|---|
| **LỜI CẢM ƠN** | T7.9 | R8 | Nhóm cung cấp nội dung. |
| **NHẬN XÉT CỦA GIẢNG VIÊN HƯỚNG DẪN** | - | R8 | Giữ khung kẻ dòng của mẫu. |
| **BẢNG PHÂN CÔNG NHIỆM VỤ** | T7.9 | R2 | Bảng thành viên – nhiệm vụ – mức hoàn thành; nhóm cung cấp số liệu thật. |
| **MỤC LỤC** | T7.9 | R8 | Trường TOC tự động, cấp 1–3. |
| **DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT** | T7.9 | R8 | Bảng 3 cột Viết tắt / Tiếng Anh / Tiếng Việt; bổ sung dần theo từng chương. |
| **DANH MỤC HÌNH** | T7.9 | R8 | Trường TOC \c "Hình". |
| **DANH MỤC BẢNG** | T7.9 | R8 | Trường TOC \c "Bảng". |
| **MỞ ĐẦU** | T7.1 |  |  |
| &nbsp;&nbsp;1. Giới thiệu và lý do chọn đề tài | T7.1 | R1a | Bài toán ghi chép chi tiêu thủ công, hóa đơn giấy tiếng Việt; lý do chọn DONUT. |
| &nbsp;&nbsp;2. Mục tiêu đề tài | T7.1 | R1a | Ba mục tiêu theo đề cương: khảo sát + thiết kế microservices; hệ thống tích hợp; DONUT 4 trường + Docker. |
| &nbsp;&nbsp;3. Đối tượng và phạm vi đề tài | T7.1 | R1a | Đối tượng: hóa đơn bán lẻ tiếng Việt, mô hình DONUT, người dùng cá nhân. Phạm vi: 4 trường, không liên kết ngân hàng. |
| &nbsp;&nbsp;4. Phương pháp nghiên cứu | T7.1 | R7 | Nghiên cứu tài liệu, khảo sát, thực nghiệm huấn luyện, phát triển phần mềm lặp. |
| &nbsp;&nbsp;5. Kế hoạch thực hiện | T7.1 | R2 | Bảng 12 tuần (15/08–06/11/2026) theo mục 10 của đề cương. |
| &nbsp;&nbsp;6. Bố cục báo cáo | T7.1 | R8 | Tóm tắt nội dung 5 chương. |
| **CHƯƠNG 1: KHẢO SÁT HỆ THỐNG VÀ TỔNG QUAN** | T7.1 |  |  |
| &nbsp;&nbsp;**1.1. Giới thiệu** | T7.1 | R8 | Đoạn dẫn nhập chương. |
| &nbsp;&nbsp;**1.2. Khảo sát nhu cầu quản lý tài chính cá nhân** | T7.1 | R1b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.2.1. Nhu cầu quản lý tài chính cá nhân | T7.1 | R1b | Số liệu bên ngoài phải có [n] trong references.md. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.2.2. Quy trình ghi chép chi tiêu hiện nay | T7.1 | R1b | Quy trình thủ công: giữ hóa đơn → nhập tay → tổng hợp. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.2.3. Hạn chế của quy trình ghi chép thủ công | T7.1 | R1b |  |
| &nbsp;&nbsp;**1.3. Khảo sát các ứng dụng quản lý tài chính hiện có** | T7.1 | R1b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.3.1. Ứng dụng Money Lover | T7.1 | R1b | Ảnh chụp do nhóm cung cấp. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.3.2. Ứng dụng MISA MoneyKeeper | T7.1 | R1b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.3.3. Ứng dụng Sổ Thu Chi | T7.1 | R1b | Kiểm tra lại tên ứng dụng khi viết T7.1. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.3.4. So sánh tính năng và định hướng của đề tài | T7.1 | R1b | Bảng so sánh tính năng; nêu khoảng trống: quét hóa đơn tiếng Việt. |
| &nbsp;&nbsp;**1.4. Khảo sát biểu mẫu hóa đơn** | T7.1 | R1b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.4.1. Danh sách biểu mẫu thu thập | T7.1 | R1b | Bảng biểu mẫu: loại, nguồn, số lượng (số từ facts.md). |
| &nbsp;&nbsp;&nbsp;&nbsp;1.4.2. Hóa đơn siêu thị và cửa hàng tiện lợi | T7.1 | R1b | Ảnh mẫu do nhóm cung cấp. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.4.3. Hóa đơn nhà hàng và quán ăn | T7.1 | R1b | Ảnh mẫu do nhóm cung cấp. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.4.4. Hóa đơn điện tử | T7.1 | R1b | Căn cứ pháp lý về hóa đơn điện tử nếu có trong references.md. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.4.5. Đặc điểm của bốn trường thông tin cần trích xuất | T7.1 | R1b | Seller, Address, Timestamp, Total Cost: vị trí, định dạng, nhiễu thường gặp. |
| &nbsp;&nbsp;**1.5. Tổng quan các hướng trích xuất thông tin hóa đơn** | T7.1 | R5b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.5.1. OCR truyền thống kết hợp luật | T7.1 | R5b | Tesseract, luật/Regex. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.5.2. OCR kết hợp mô hình bố cục | T7.1 | R5b | LayoutLM. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.5.3. Hướng tiếp cận OCR-free | T7.1 | R5a | Giới thiệu DONUT ở mức tổng quan; chi tiết ở 2.5. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.5.4. So sánh các hướng tiếp cận | T7.1 | R5b | Bảng so sánh: phụ thuộc OCR, lan truyền lỗi, chi phí, tiếng Việt. |
| &nbsp;&nbsp;**1.6. Các công trình liên quan** | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.6.1. Cuộc thi và bộ dữ liệu SROIE | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.6.2. Bộ dữ liệu CORD | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.6.3. Cuộc thi MC-OCR với hóa đơn tiếng Việt | T7.1 | R7 |  |
| &nbsp;&nbsp;**1.7. Tổng quan công nghệ sử dụng** | T7.1 | R7 | Phiên bản lấy từ facts.md. |
| &nbsp;&nbsp;&nbsp;&nbsp;1.7.1. Flutter và Dart | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.7.2. Spring Boot, Spring Security và JWT | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.7.3. FastAPI, PyTorch và Hugging Face Transformers | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.7.4. PostgreSQL, Redis và MongoDB | T7.1 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;1.7.5. Docker và GitHub Actions | T7.1 | R7 |  |
| &nbsp;&nbsp;**1.8. Kết chương** | T7.1 | R8 | Tiểu kết chương. |
| **CHƯƠNG 2: PHÂN TÍCH HỆ THỐNG** | T7.2a |  |  |
| &nbsp;&nbsp;**2.1. Giới thiệu** | T7.2a | R8 | Đoạn dẫn nhập chương. |
| &nbsp;&nbsp;**2.2. Mô hình hóa nghiệp vụ** | T7.2a | R3a | Mỗi quy trình 2.2.2–2.2.7 gồm: bảng văn bản (mô tả, dòng cơ bản, dòng thay thế) + sơ đồ hoạt động + sơ đồ tuần tự + sơ đồ cộng tác. |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.1. Sơ đồ use case nghiệp vụ | T7.2a | R3a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.2. Mô hình hóa quy trình ghi chép thu chi | T7.2a | R3a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.3. Mô hình hóa quy trình quét hóa đơn và đối soát | T7.2a | R3a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.4. Mô hình hóa quy trình lập và theo dõi ngân sách | T7.2a | R3a | Gồm cảnh báo vượt ngưỡng. |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.5. Mô hình hóa quy trình thống kê và báo cáo thói quen chi tiêu | T7.2a | R3a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.6. Mô hình hóa quy trình quản trị hệ thống | T7.2a | R3a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.2.7. Mô hình hóa quy trình duyệt hóa đơn AI | T7.2a | R3a |  |
| &nbsp;&nbsp;**2.3. Mô hình hóa chức năng hệ thống** | T7.2b | R3b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.3.1. Các tác nhân của hệ thống | T7.2b | R3b | Người dùng, Quản trị viên, AI Service (tác nhân hệ thống). |
| &nbsp;&nbsp;&nbsp;&nbsp;2.3.2. Sơ đồ use case hệ thống | T7.2b | R3b | include/extend đúng chuẩn UML. |
| &nbsp;&nbsp;&nbsp;&nbsp;2.3.3. Đặc tả use case phân hệ người dùng | T7.2b | R3b | Bảng 8 trường cho mỗi use case: Đăng ký, Đăng nhập, Đăng xuất, Đổi mật khẩu, Quên/Đặt lại mật khẩu, Quản lý giao dịch, Đồng bộ giao dịch offline, Quét hóa đơn, Đối soát và lưu hóa đơn, Quản lý ngân sách, Nhận cảnh báo ngân sách, Xem thống kê, Xem báo cáo thói quen chi tiêu, Quản lý mục tiêu tiết kiệm, Xem thông báo, Cài đặt ngôn ngữ/giao diện. |
| &nbsp;&nbsp;&nbsp;&nbsp;2.3.4. Đặc tả use case phân hệ quản trị | T7.2b | R3b | Quản lý người dùng, Quản lý danh mục mặc định, Duyệt hóa đơn AI, Xem nhật ký hoạt động, Xem thống kê hệ thống, Quản lý gói dịch vụ. Chỉ giữ use case có thật trong code. |
| &nbsp;&nbsp;**2.4. Sơ đồ lớp mức phân tích** | T7.2c | R3c |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.4.1. Xác định các lớp thực thể | T7.2c | R3c | Từ danh sách entity trong facts.md. |
| &nbsp;&nbsp;&nbsp;&nbsp;2.4.2. Sơ đồ lớp mức phân tích | T7.2c | R3c |  |
| &nbsp;&nbsp;**2.5. Phân tích bài toán và mô hình DONUT** | T7.2c | R5a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.5.1. Phát biểu bài toán trích xuất bốn trường thông tin | T7.2c | R5b | Đầu vào ảnh, đầu ra JSON 4 trường. |
| &nbsp;&nbsp;&nbsp;&nbsp;2.5.2. Hạn chế của OCR truyền thống mà DONUT giải quyết | T7.2c | R5b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.5.3. Kiến trúc Swin Transformer encoder và BART decoder | T7.2c | R5a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.5.4. Cơ chế prompt và task token | T7.2c | R5a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;2.5.5. Vấn đề tokenizer với tiếng Việt và giải pháp mở rộng | T7.2c | R5a | Đề cương mục 6: mở rộng tokenizer tiếng Việt. |
| &nbsp;&nbsp;**2.6. Kết chương** | T7.2c | R8 | Tiểu kết chương. |
| **CHƯƠNG 3: THIẾT KẾ HỆ THỐNG** | T7.3a |  |  |
| &nbsp;&nbsp;**3.1. Giới thiệu** | T7.3a | R8 | Đoạn dẫn nhập chương. |
| &nbsp;&nbsp;**3.2. Kiến trúc tổng thể** | T7.3a | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.2.1. Kiến trúc microservices | T7.3a | R7 | Mobile, Web Admin, Core, AI, PostgreSQL, Redis, MongoDB. |
| &nbsp;&nbsp;&nbsp;&nbsp;3.2.2. Sơ đồ triển khai | T7.3a | R6.7 | Container lấy từ docker-compose.yml qua facts.md. |
| &nbsp;&nbsp;**3.3. Thiết kế cơ sở dữ liệu** | T7.3a | R4b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.3.1. Chuyển từ sơ đồ lớp phân tích sang mô hình quan hệ | T7.3a | R4b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.3.2. Sơ đồ thực thể kết hợp | T7.3a | R4b | ERD. |
| &nbsp;&nbsp;&nbsp;&nbsp;3.3.3. Mô tả các bảng dữ liệu | T7.3a | R4b | Một bảng mô tả cho mỗi bảng dữ liệu. |
| &nbsp;&nbsp;&nbsp;&nbsp;3.3.4. Đặc tả ràng buộc toàn vẹn | T7.3a | R4b | Miền giá trị, liên thuộc tính, liên quan hệ/liên bộ, duy nhất; mỗi RBTV trùng ràng buộc thật trong code/DB. |
| &nbsp;&nbsp;**3.4. Thiết kế lưu trữ đa mô hình và bộ nhớ đệm** | T7.3a | R4b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.4.1. Lưu trữ nhật ký AI trên MongoDB | T7.3a | R4b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.4.2. Thiết kế bộ nhớ đệm Redis | T7.3a | R4b | Key, TTL, xóa cache sau commit. |
| &nbsp;&nbsp;**3.5. Thiết kế API và bảo mật** | T7.3a | R6.0 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.5.1. Danh sách API RESTful | T7.3a | R6.0 | Bảng endpoint từ facts.md. |
| &nbsp;&nbsp;&nbsp;&nbsp;3.5.2. Xác thực và phân quyền bằng JWT | T7.3a | R6.0 |  |
| &nbsp;&nbsp;**3.6. Thiết kế giao diện** | T7.3b | R4c | Mỗi màn hình kèm ảnh do nhóm chụp. |
| &nbsp;&nbsp;&nbsp;&nbsp;3.6.1. Giao diện ứng dụng di động | T7.3b | R4c |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.6.2. Giao diện Web Admin | T7.3b | R4c |  |
| &nbsp;&nbsp;**3.7. Sơ đồ lớp mức thiết kế** | T7.3b | R4a |  |
| &nbsp;&nbsp;**3.8. Thiết kế chức năng** | T7.3b | R4a | Mỗi chức năng: sơ đồ ba lớp Boundary – Control – Entity + sơ đồ tuần tự mức thiết kế. |
| &nbsp;&nbsp;&nbsp;&nbsp;3.8.1. Thiết kế chức năng đăng nhập và phân quyền | T7.3b | R6.0 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.8.2. Thiết kế chức năng quản lý giao dịch | T7.3b | R6.1 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.8.3. Thiết kế chức năng quét và đối soát hóa đơn | T7.3b | R6.5 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.8.4. Thiết kế chức năng quản lý ngân sách và cảnh báo | T7.3b | R6.2 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.8.5. Thiết kế chức năng thống kê và báo cáo | T7.3b | R6.4 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.8.6. Thiết kế chức năng duyệt hóa đơn AI | T7.3b | R6.3 |  |
| &nbsp;&nbsp;**3.9. Thiết kế mô hình AI** | T7.3b | R6.6b |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.9.1. Tokenizer mở rộng cho tiếng Việt | T7.3b | R5a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.9.2. Định dạng nhãn dữ liệu | T7.3b | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;3.9.3. Quy trình hậu xử lý bằng Regex | T7.3b | R6.6b | Dựa trên ai-service/receipt_postprocess.py (T5). |
| &nbsp;&nbsp;**3.10. Kết chương** | T7.3b | R8 | Tiểu kết chương. |
| **CHƯƠNG 4: CÀI ĐẶT HỆ THỐNG** | T7.4 |  |  |
| &nbsp;&nbsp;**4.1. Giới thiệu** | T7.4 | R8 | Đoạn dẫn nhập chương. |
| &nbsp;&nbsp;**4.2. Môi trường và công cụ** | T7.4 | R7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.2.1. Môi trường phát triển | T7.4 | R7 | Bảng phiên bản từ facts.md. |
| &nbsp;&nbsp;&nbsp;&nbsp;4.2.2. Quản lý mã nguồn với Git và GitHub | T7.4 | R2 |  |
| &nbsp;&nbsp;**4.3. Thu thập và chuẩn hóa dữ liệu hóa đơn** | T7.4 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.3.1. Thu thập dữ liệu | T7.4 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.3.2. Gán nhãn dữ liệu | T7.4 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.3.3. Chuẩn hóa và chia tập dữ liệu | T7.4 | R6.6a | Ghi rõ cách chia train/val/test. |
| &nbsp;&nbsp;**4.4. Huấn luyện mô hình DONUT** | T7.4 | R6.6a | Số liệu train V5 do nhóm cung cấp. |
| &nbsp;&nbsp;&nbsp;&nbsp;4.4.1. Môi trường huấn luyện trên Kaggle | T7.4 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.4.2. Cấu hình và siêu tham số | T7.4 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.4.3. Quá trình huấn luyện | T7.4 | R6.6a | Đường loss, thời gian huấn luyện. |
| &nbsp;&nbsp;**4.5. Cài đặt AI Service** | T7.4 | R6.5 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.5.1. API suy luận | T7.4 | R6.5 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.5.2. Hậu xử lý bằng Regex | T7.4 | R6.6b |  |
| &nbsp;&nbsp;**4.6. Cài đặt Core Backend** | T7.4 | R6.0 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.6.1. Xác thực, phân quyền và quản lý tài khoản | T7.4 | R6.0 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.6.2. Quản lý giao dịch và đồng bộ dữ liệu | T7.4 | R6.1 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.6.3. Quản lý ngân sách và cảnh báo | T7.4 | R6.2 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.6.4. Thống kê và bộ nhớ đệm | T7.4 | R6.4 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.6.5. Xử lý và đối soát hóa đơn | T7.4 | R6.6b |  |
| &nbsp;&nbsp;**4.7. Cài đặt ứng dụng di động** | T7.4 | R6.1 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.7.1. Tổ chức mã nguồn | T7.4 | R6.1 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;4.7.2. Các chức năng chính | T7.4 | R6.4 | Giao dịch, ngân sách, biểu đồ, quét hóa đơn (camera/thư viện). |
| &nbsp;&nbsp;&nbsp;&nbsp;4.7.3. Đa ngôn ngữ và giao diện sáng/tối | T7.4 | R4c |  |
| &nbsp;&nbsp;**4.8. Cài đặt Web Admin** | T7.4 | R6.3 |  |
| &nbsp;&nbsp;**4.9. Đóng gói hệ thống bằng Docker** | T7.4 | R6.7 |  |
| &nbsp;&nbsp;**4.10. Kết chương** | T7.4 | R8 | Tiểu kết chương. |
| **CHƯƠNG 5: THỬ NGHIỆM VÀ TRIỂN KHAI** | T7.5 |  |  |
| &nbsp;&nbsp;**5.1. Giới thiệu** | T7.5 | R8 | Đoạn dẫn nhập chương. |
| &nbsp;&nbsp;**5.2. Đánh giá mô hình DONUT** | T7.5 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.2.1. Tập dữ liệu và độ đo đánh giá | T7.5 | R6.6a | Metric kèm công thức. |
| &nbsp;&nbsp;&nbsp;&nbsp;5.2.2. Kết quả theo từng trường thông tin | T7.5 | R6.6a |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.2.3. So sánh các phiên bản mô hình | T7.5 | R6.6a | Đối chiếu baseline. |
| &nbsp;&nbsp;&nbsp;&nbsp;5.2.4. Phân tích lỗi | T7.5 | R6.6a | Nêu cả hạn chế. |
| &nbsp;&nbsp;**5.3. Kiểm thử chức năng** | T7.5 | R6.7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.3.1. Kịch bản kiểm thử chức năng | T7.5 | R6.7 | Bảng test case. |
| &nbsp;&nbsp;&nbsp;&nbsp;5.3.2. Kiểm thử đơn vị và tích hợp | T7.5 | R6.7 | Số lượng test từ facts.md. |
| &nbsp;&nbsp;**5.4. Kiểm thử API và hiệu năng** | T7.5 | R6.7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.4.1. Tài liệu API với Swagger/OpenAPI | T7.5 | R6.7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.4.2. Kiểm thử API bằng Postman | T7.5 | R6.7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.4.3. Kiểm thử chịu tải bằng JMeter | T7.5 | R6.7 | Throughput/latency từ report JMeter của nhóm. |
| &nbsp;&nbsp;**5.5. Triển khai hệ thống** | T7.5 | R6.7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.5.1. Quy trình CI/CD với GitHub Actions | T7.5 | R6.7 |  |
| &nbsp;&nbsp;&nbsp;&nbsp;5.5.2. Triển khai trên máy chủ AWS EC2 | T7.5 | R6.7 | Kết quả deploy T8. |
| &nbsp;&nbsp;&nbsp;&nbsp;5.5.3. Phân phối ứng dụng di động | T7.5 | R6.7 | APK + mã QR. |
| &nbsp;&nbsp;**5.6. Kết chương** | T7.5 | R8 | Tiểu kết chương. |
| **KẾT LUẬN** | T7.9 |  |  |
| &nbsp;&nbsp;1. Kết quả đạt được | T7.9 | R7 |  |
| &nbsp;&nbsp;2. Đánh giá kết quả | T7.9 | R7 | Mức hoàn thành so với mục tiêu ở Mở đầu. |
| &nbsp;&nbsp;3. Hạn chế | T7.9 | R7 |  |
| &nbsp;&nbsp;4. Hướng phát triển | T7.9 | R7 |  |
| **TÀI LIỆU THAM KHẢO** | T7.9 | R8 | Từ docs/thesis/references.md; khớp 1–1 với trích dẫn [n]. |
| **PHỤ LỤC** | T7.9 | R8 | Nếu cần. |

Mỗi quy trình 2.2.2–2.2.7 có bốn phần cố định (dùng đề mục cấp 4 `Heading 4` nếu cần): bảng văn bản (mô tả, dòng cơ bản, dòng thay thế), sơ đồ hoạt động có swimlane, sơ đồ tuần tự, sơ đồ cộng tác. Mỗi chức năng 3.8.x có sơ đồ ba lớp (Boundary – Control – Entity) và sơ đồ tuần tự mức thiết kế. Nguồn PlantUML lưu ở `docs/thesis/diagrams/`.

## 3. Quy ước khi điền file Word (mọi phiên T7.x)

- **Không ghi đè**: phiên T7.x đọc bản `vN` mới nhất và lưu thành `KhoaLuan_KLCN175_v(N+1).docx`. `NhomA7_BigData.docx` và `Mau bao cao_Do an_Khoa luan_2025.docx` giữ nguyên.
- **Chỉ dùng style, không định dạng tay** (đã cài trong file khung):

| Style (styleId) | Dùng cho | Thể thức |
|---|---|---|
| `Heading1` | Tên chương | 18, IN HOA, đậm, giữa; tự đánh "CHƯƠNG n:"; sang trang mới |
| `Heading2` / `Heading3` / `Heading4` | Đề mục 1.1 / 1.1.1 / 1.1.1.1 | 14 IN HOA đậm / 13 đậm / 13 đậm; tự đánh số |
| `TieuDeKhongSo` | Lời cảm ơn, Mục lục, Mở đầu, Kết luận, TLTK, Phụ lục | 18, IN HOA, đậm, giữa; có trong mục lục |
| `TieuDeMuc` | "1. GIỚI THIỆU…" trong Mở đầu/Kết luận (số gõ tay) | 14, IN HOA, đậm |
| `noidung` | Đoạn văn | 13, giãn 1.3, trước/sau 6pt, canh đều, thụt 1 cm |
| `GachDau1` / `GachDau2` | Bullet "−" / "+" | position 0.3/indent 0.8 cm; 0.8/1.3 cm |
| `Hinh` | Đoạn chứa ảnh | canh giữa, giữ cùng trang với chú thích |
| `Caption` | "Hình c.n: …" đặt **dưới** hình | 13, canh giữa |
| `ChuThichBang` | "Bảng c.n: …" đặt **trên** bảng | 13, canh giữa, giữ cùng trang với bảng |
| `NoiDungBang` | Chữ trong bảng | 12, giãn 1.3, trước/sau 0pt |

- **Chú thích có số tự động** (để Danh mục hình/bảng tự cập nhật): `Hình 2.` + trường `SEQ Hình \* ARABIC \s 1` + `: tên hình`; bảng tương tự với `SEQ Bảng \* ARABIC \s 1`. Số chương gõ tay, `\s 1` cho số thứ tự bắt đầu lại ở mỗi chương. Bảng: dòng tiêu đề bật `tblHeader` (lặp khi sang trang), style bảng `TableGrid`, rộng 8504 dxa.
- **Trường tự động**: Mục lục (`TOC \o "1-3" \h \z \u`), Danh mục hình (`TOC \h \z \c "Hình"`), Danh mục bảng (`TOC \h \z \c "Bảng"`). File bật `updateFields` nên Word hỏi cập nhật khi mở; chọn Yes hoặc Ctrl+A → F9.
- **Số trang**: 3 section của mẫu được giữ nguyên: bìa (không số), phần đầu (i, ii…), từ Mở đầu (1, 2…).
- **Dòng tô vàng** `[T7.x] …` là chỗ giữ nội dung, xóa khi viết xong mục đó. Trước khi nộp không còn dòng tô vàng nào.

## 4. Lưu ý từ `facts.md` và `references.md` cần xử lý trước khi viết

- Model đang phục vụ trong AI Service là Version3; số liệu V5 chưa có. Chương 4–5 chờ nhóm cung cấp (spec mục rủi ro: dùng phiên bản tốt nhất nếu V5 chưa xong trước 31/10).
- Kết quả đánh giá duy nhất trong repo (exact match trung bình 63,95% trên 172 ảnh validation) chưa rõ thuộc model nào, nên chưa được trích.
- Mobile gọi `/api/wallets/*` và `GET /api/transactions?userId=` mà backend không có: thuộc phạm vi T3, không mô tả là chức năng ở Chương 2–3 cho tới khi sửa.
- Ở 1.4.4 trích Nghị định 254/2026/NĐ-CP (hiện hành, tên đã đối chiếu trên vanban.chinhphu.vn) và nếu nhắc Nghị định 123/2020/NĐ-CP thì ghi rõ "đã được thay thế".
- Chưa có bài báo tiếng Việt bình duyệt nào về trích xuất hóa đơn; [3], [4] trong `references.md` chỉ liên quan OCR tài liệu tiếng Việt nói chung.
