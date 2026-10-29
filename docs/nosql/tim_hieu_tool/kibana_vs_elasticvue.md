# Tìm hiểu và So sánh Công cụ Quản trị GUI cho Elasticsearch: Kibana vs. Elasticvue (Mục 2.5 — Phan Minh Tiến)

## 1. Tổng quan Lý thuyết, Kiến trúc, Phiên bản và Cài đặt (Tiêu chí 1)
- **Kibana (`8.11.4`):** Công cụ quản trị và trực quan hóa chính thức thuộc hệ sinh thái Elastic Stack. Kiến trúc gồm một máy chủ Node.js kết nối tới Elasticsearch ở phía sau thông qua tài khoản dịch vụ `kibana_system` (xác thực qua REST API bảo mật của Elasticsearch). Cài đặt qua Docker Compose ở cổng `5602` (stack demo) / `5601` (stack chính) — Minh chứng: `S-01.png`, `S-02.png`.
- **Elasticvue (`1.16.0`):** Công cụ GUI mã nguồn mở gọn nhẹ viết dưới dạng ứng dụng trang đơn (SPA) chạy trực tiếp trong trình duyệt của người dùng và gọi thẳng REST API của Elasticsearch thông qua cấu hình CORS (`http.cors.enabled: true`). Cài đặt qua container `cars10/elasticvue` ở cổng `8081` — Minh chứng: `S-10.png`.

## 2. Thực hành 6 Nhóm Chức năng Quản trị trên Dữ liệu LedgerMind (Tiêu chí 2)
1. **Quản lý chỉ mục (Index Management):** Kiểm tra trạng thái `health = yellow` (do cấu hình 1 node, `number_of_shards: 1, number_of_replicas: 0`), xem `settings` (bộ phân tích tiếng Việt `vi_folded`, `vi_autocomplete`) và `mappings` của chỉ mục `transactions` (`47` tài liệu mẫu) trên cả Kibana (`S-03.png`) và Elasticvue (`S-11.png`).
2. **Truy vấn REST / Dev Tools:** Thực thi các truy vấn tìm kiếm `GET transactions/_search` (khớp không dấu, gợi ý tiền tố, chịu lỗi chính tả `fuzziness: "AUTO:4,7"` và gom nhóm `aggs`) trên Kibana Dev Tools (`S-04.png`) và tab REST của Elasticvue (`S-12.png`).
3. **Nhập / Xuất dữ liệu (Import / Export):** Trên Kibana, sử dụng tính năng *Upload a file* để nhập tệp `giao_dich_mau.csv` (`47` dòng) tạo chỉ mục `giao_dich_csv` (`S-05.png`) và xuất báo cáo CSV từ *Discover* (`S-06.png`). Elasticvue không hỗ trợ tính năng nhập tệp CSV trực tiếp.
4. **Sao lưu & Khôi phục (Snapshot & Restore):** Đăng ký kho lưu trữ `demo_repo` tại `/usr/share/elasticsearch/snapshots`, tạo bản chụp `snap-2026-10-28` chứa chỉ mục `transactions` và kiểm chứng khôi phục trên Kibana (`S-07.png`) cũng như xem nhanh trên Elasticvue (`S-13.png`).
5. **Phân quyền bảo mật (Security — Users & Roles):** Trên Kibana (*Stack Management -> Users / Roles*), tạo vai trò chỉ đọc `transactions_read` và tài khoản `tien_viewer` (`S-08.png`).
6. **Giám sát thống kê chỉ mục (Index Statistics):** Theo dõi dung lượng lưu trữ, số lượng phân đoạn (segments) và tốc độ truy vấn/lập chỉ mục (`S-09.png`).

## 3. Bảng So sánh Thực nghiệm 7 Khía cạnh (Tiêu chí 3 — Số đo từ `S-14.png`)

| Khía cạnh so sánh | Kibana `8.11.4` | Elasticvue `1.16.0` |
|---|---|---|
| **1. Phạm vi chức năng** | Toàn diện: Index Management, Dev Tools, Import/Export CSV, Snapshot/Restore, Security (Users/Roles), Discover & Dashboard. | Tập trung vào thao tác cốt lõi: Xem Cluster/Nodes, Shards, Index/Mapping, tìm kiếm tài liệu, REST Console và Snapshot cơ bản; không có Import CSV và Dashboard. |
| **2. Giao diện người dùng** | Nhiều phân hệ chuyên sâu, phù hợp quản trị hệ thống lớn nhưng nhiều tầng menu. | Tối giản, trực quan, phản hồi tức thì, mọi tab nằm trên một thanh điều hướng ngang. |
| **3. Hỗ trợ truy vấn** | **Dev Tools Console** hỗ trợ tự động gợi ý cú pháp DSL, chạy nhiều truy vấn trong một màn hình. | Có trình soạn thảo REST query và bộ lọc bảng trực quan nhưng ít gợi ý DSL nâng cao hơn. |
| **4. Hiệu năng & Tài nguyên (`docker stats` — `S-14.png`)** | - **RAM tiêu thụ:** `631 MiB`<br>- **Kích thước Docker Image:** `1,67 GB`<br>- **Thời gian tải trang đầu:** `1,38 s` | - **RAM tiêu thụ:** `10,5 MiB` *(nhẹ hơn ~60 lần)*<br>- **Kích thước Docker Image:** `105 MB`<br>- **Thời gian tải trang đầu:** `0,25 s` |
| **5. Giấy phép (License)** | Elastic License 2.0 (ELv2) / SSPL. | Giấy phép nguồn mở **MIT**. |
| **6. Nền tảng triển khai** | Chạy như một dịch vụ máy chủ (Docker container / Linux / Windows server). | Web tĩnh (Docker Nginx siêu nhẹ), ứng dụng Desktop (Tauri) hoặc tiện ích mở rộng trình duyệt. |
| **7. Hệ sinh thái & Cộng đồng** | Chính chủ Elastic, tài liệu đồ sộ, chuẩn công nghiệp cho ELK Stack. | Cộng đồng mã nguồn mở tích cực trên GitHub, rất phổ biến cho nhu cầu phát triển cục bộ. |

## 4. Đánh giá Mức độ Phù hợp với Đề tài LedgerMind (Tiêu chí 4)
- Trong quá trình phát triển **LedgerMind**, nếu giữ giới hạn bộ nhớ Elasticsearch ở mức `1 GB` mà bật đồng thời Kibana (`631 MiB RAM`), container Elasticsearch dễ chạm trần bộ nhớ và bị Linux kernel OOM-kill (`S-89.png`). Do đó, nhóm nâng giới hạn bộ nhớ Elasticsearch lên `1536M` và đặt Kibana vào Docker Compose profile `tools` (chỉ bật khi cần quản trị chuyên sâu như cấu hình Snapshot, phân quyền RBAC, nhập/xuất CSV hoặc chạy kịch bản kiểm thử trên Dev Tools).
- Đối với việc tra cứu nhanh tài liệu đồng bộ sau commit và kiểm tra mapping hàng ngày trên máy cá nhân, **Elasticvue** (`10,5 MiB RAM`) là lựa chọn bổ trợ cực kỳ hiệu quả nhờ tiêu tốn ít tài nguyên.
