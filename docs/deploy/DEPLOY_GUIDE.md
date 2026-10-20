# Hướng dẫn triển khai

> Các bước deploy EC2 (T8) sẽ được bổ sung vào file này. Hiện file chỉ có phần dữ liệu demo (T2b).

## Dữ liệu demo

`core-backend` có bộ seed dữ liệu demo (`Config/DataSeeder.java`, `Service/DemoData/`). Mặc định **tắt**.

### Bật seed

Thêm vào `.env` (máy dev) hoặc `.env_deploy` (EC2), rồi `docker compose up -d`:

```env
SEED_DEMO=true
SEED_ADMIN_PASSWORD=<mật khẩu admin do bạn tự đặt, KHÔNG ghi vào repo>
SEED_DEMO_PASSWORD=<mật khẩu demo do bạn tự đặt, KHÔNG ghi vào repo>
```

- Hai mật khẩu phải đạt `@StrongPassword`: 8–72 ký tự, có ít nhất một chữ cái và một chữ số. Thiếu hoặc yếu thì
  core-api dừng ngay lúc khởi động và log ghi rõ lý do.
- Seed chỉ chạy khi bảng `users` **còn trống**. Database đã có người dùng thì bỏ qua; seeder không bao giờ xóa dữ liệu.
- Sau lần khởi động đầu tiên có thể để `SEED_DEMO=false` (để `true` cũng không sao vì seeder sẽ bỏ qua).
- Production thật (có người dùng thật): luôn để `SEED_DEMO=false`.
- Muốn seed lại trên máy dev: `docker compose down -v` (**xóa toàn bộ dữ liệu local**), rồi `up` lại với `SEED_DEMO=true`.

### Tài khoản

| Vai trò | Tên đăng nhập | Email | Mật khẩu |
|---|---|---|---|
| Admin (Web Admin) | `admin` | `admin@example.com` | giá trị `SEED_ADMIN_PASSWORD` |
| Demo: nhân viên văn phòng | `demo.vanphong` | `demo.vanphong@example.com` | giá trị `SEED_DEMO_PASSWORD` |
| Demo: sinh viên | `demo.sinhvien` | `demo.sinhvien@example.com` | giá trị `SEED_DEMO_PASSWORD` |

`example.com` là tên miền dành riêng cho ví dụ nên không email nào tới hộp thư thật. Vì vậy luồng quên mật khẩu (gửi OTP)
không dùng được với các tài khoản này. 36 tài khoản nền chỉ để thống kê có số liệu và không đăng nhập được.

### Nội dung được seed

- 21 danh mục mặc định (15 chi, 6 thu). Mỗi danh mục có `key` ổn định trong `Entity/DefaultCategory.java` để mobile
  dịch sang tiếng Anh (T4).
- Khoảng vài nghìn giao dịch. Tài khoản đang dùng có dữ liệu trong 3 tháng trước và tháng hiện tại; tài khoản nền chia
  theo nhóm VIP / ACTIVE / AT-RISK / CHURN. `walletBalance` của mỗi người bằng tổng thu trừ tổng chi.
- Riêng hai tài khoản demo:
  - ngân sách tuần và tháng; ngân sách "Ăn uống" tháng này của `demo.vanphong` đã vượt 80% nên có thông báo cảnh báo;
  - mục tiêu tiết kiệm;
  - hóa đơn ở các trạng thái `COMPLETED_RAW`, `EDITED`, `FAILED`, `WAITING_FOR_REVIEW`, `APPROVED`, kèm thông báo;
  - vài dòng nhật ký hệ thống.
- MongoDB: mỗi hóa đơn có một log OCR thô; hóa đơn được sửa hoặc đang chờ duyệt có thêm một phản hồi. Nếu MongoDB không
  chạy thì phần này bị bỏ qua và app vẫn khởi động.
- Nhãn phân khúc khách hàng (`ai_label`) **không** được seed sẵn. Vào Dashboard của Web Admin, bấm "Chạy Phân Lớp AI Tự
  Động" (cần ai-service đang chạy) để nhãn được tính từ dữ liệu demo.

Dữ liệu được sinh với hạt giống cố định (`Random(42)`) và tính theo ngày seed. Seed vào hai ngày khác nhau sẽ ra cùng
cấu trúc, nhưng khoảng ngày của dữ liệu sẽ dời theo.

Lưu ý: hạn mức ngân sách được tính từ số tiền đã chi trong kỳ hiện tại. Nếu seed vào sáng sớm ngày 1 (tháng chưa có
khoản chi nào) thì ngân sách "Ăn uống" chưa vượt 80% và sẽ không có thông báo cảnh báo. Nên seed từ ngày 2 trở đi.
