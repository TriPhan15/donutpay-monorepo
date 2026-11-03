# Kiểm thử và tài liệu hóa API (T6)

Ba công cụ, cùng nhắm vào `core-backend` chạy **trên máy local** (docker compose, `SPRING_PROFILES_ACTIVE=dev` trong `.env`,
dữ liệu demo `SEED_DEMO=true`). Không chạy Postman Runner hay JMeter vào server thật trên EC2.

| Công cụ | File | Dùng cho chương Kiểm thử |
|---|---|---|
| Swagger UI (springdoc) | `core-backend/.../Config/OpenApiConfig.java`, `openapi.properties` | Ảnh chụp tài liệu API |
| Postman | `postman/LedgerMind.postman_collection.json` + `postman/LedgerMind.local.postman_environment.json` | Bảng kết quả kiểm thử chức năng (42 request, mỗi request có test) |
| JMeter | `jmeter/ledgermind-load.jmx` + `jmeter/demo-users.txt` | Báo cáo HTML kiểm thử tải |

## 0. Chuẩn bị

1. `.env` có `SPRING_PROFILES_ACTIVE=dev`, `SEED_DEMO=true`, `SEED_ADMIN_PASSWORD`, `SEED_DEMO_PASSWORD` (xem
   `docs/deploy/DEPLOY_GUIDE.md`; seeder chỉ chạy khi bảng `users` còn trống).
2. `docker compose up -d --build`, đợi `curl -s http://localhost/actuator/health` trả `UP` (cổng 80 qua Caddy; core-api không mở cổng 8080 ra máy host).
3. Tài khoản dùng trong các bộ test:
   - người dùng: `demo.vanphong@example.com` / giá trị `SEED_DEMO_PASSWORD`;
   - admin: `admin@example.com` / giá trị `SEED_ADMIN_PASSWORD`.

> **Cẩn thận khóa đăng nhập:** 5 lần sai mật khẩu liên tiếp (theo email hoặc theo IP) khóa 15 phút. Luôn thử 1 request
> trước (Postman: chỉ request "Đăng nhập", JMeter: `-Jusers=1 -Jloops=1`) rồi mới chạy cả bộ.

## 1. Swagger UI

- Chỉ có ở profile `dev`: <http://localhost/swagger-ui.html>. JSON: `/v3/api-docs/user` và `/v3/api-docs/admin`.
- Ở mọi profile khác (`prod` trên EC2, test, không profile) hai URL này **không tồn tại** (404): `openapi-disabled.properties`
  tắt springdoc. Muốn bật tạm trên một máy khác thì đặt biến môi trường `SPRINGDOC_API_DOCS_ENABLED=true` và
  `SPRINGDOC_SWAGGER_UI_ENABLED=true`, rồi tắt lại.
- Dùng: chọn nhóm (góc trên phải) "API người dùng (mobile)" hoặc "API quản trị (ROLE_ADMIN)" → gọi `POST /api/auth/login`
  → copy `data.token` → nút **Authorize** → dán token (không gõ `Bearer `). Các API `/api/auth/**` công khai không có ổ khóa.
- 👤 Chụp màn hình: danh sách nhóm API, một API mở rộng (vd. `POST /api/transactions/checkout`), hộp Authorize, một lần
  "Try it out" thành công.

## 2. Postman (kiểm thử chức năng)

1. Postman → Import cả hai file trong `postman/`.
2. Chọn environment **LedgerMind Local**, điền **Current value** của `userPassword` và `adminPassword` (để trống trong repo,
   kiểu `secret`; Current value không bị đồng bộ hay export).
3. Collection → **Run** (Collection Runner), giữ nguyên thứ tự, 1 iteration → Run. Thứ tự các folder:
   xác thực → giao dịch → ngân sách → hóa đơn (OCR) → thông báo → quản trị → làm mới token & đăng xuất.
4. Mọi request có test kiểm status (và `ApiResponse.code`), cộng 2 test chung: phản hồi là JSON, thời gian < 3000 ms.
   Có cả ca lỗi mong đợi (400 thiếu dữ liệu, 401 không token / token đã thu hồi, 403 user gọi API admin, 404, 409 trùng
   hoặc sai version).
5. Dữ liệu để lại sau mỗi lần chạy: 1 giao dịch 45.000 đ kèm hóa đơn (folder 04, để admin xem được lịch sử OCR) và các
   dòng audit log. Giao dịch và ngân sách của folder 02, 03 bị xóa ngay trong lần chạy.
6. 👤 Lưu kết quả: Runner → **Export Results** (JSON) và chụp màn hình bảng Passed/Failed.

Chạy bằng dòng lệnh (tùy chọn, cần Node.js): `npx newman run postman/LedgerMind.postman_collection.json
-e postman/LedgerMind.local.postman_environment.json --env-var userPassword=... --env-var adminPassword=...
-r cli,htmlextra` (reporter `htmlextra` cần `npm i -g newman-reporter-htmlextra`; không có thì dùng `-r cli,junit`).

## 3. JMeter (kiểm thử tải)

Kịch bản: mỗi người dùng ảo đăng nhập **một lần**, rồi lặp `GET /api/transactions/mine` → `GET /api/transactions/app-dashboard`
với think time 300–1000 ms. Mỗi request kiểm status 200; hai GET kiểm thêm `$.code = 200`.

Tham số (`-J<tên>=<giá trị>`):

| Tham số | Mặc định | Ý nghĩa |
|---|---|---|
| `protocol`, `host`, `port` | `http`, `localhost`, `80` | Địa chỉ đi qua proxy Caddy (cổng 80); jmx mặc định `port=80` |
| `users` | `20` | Số người dùng ảo (thread) |
| `rampUp` | `20` | Số giây để khởi động hết các thread |
| `loops` | `10` | Số vòng lặp đọc dữ liệu mỗi thread |
| `thinkMs`, `thinkRangeMs` | `300`, `700` | Thời gian nghĩ = thinkMs + ngẫu nhiên(0..thinkRangeMs) |
| `usersFile` | `demo-users.txt` | Danh sách email, mỗi dòng một email, dùng xoay vòng giữa các thread |
| `userPassword` | (trống) | Mật khẩu chung của các tài khoản demo (`SEED_DEMO_PASSWORD`) |

Chạy (từ thư mục `docs/testing/jmeter/`, JMeter 5.6.x, Java 17+):

```bash
cd docs/testing/jmeter
# 1) Thử khói: 1 user, 1 vòng
jmeter -n -t ledgermind-load.jmx -JuserPassword='<SEED_DEMO_PASSWORD>' -Jusers=1 -Jloops=1 -l results/smoke.jtl
# 2) Chạy thật + báo cáo HTML (thư mục report phải chưa tồn tại hoặc rỗng)
jmeter -n -t ledgermind-load.jmx -JuserPassword='<SEED_DEMO_PASSWORD>' -Jusers=50 -JrampUp=30 -Jloops=20 \
       -l results/result.jtl -e -o results/report/
```

- Mở `results/report/index.html`: APDEX, Statistics (số mẫu, % lỗi, trung bình, p90/p95/p99, throughput), biểu đồ
  Response Times Over Time. `results/` bị `.gitignore` của thư mục này bỏ qua.
- `demo-users.txt` chỉ có 2 tài khoản demo cố định. Email của 36 tài khoản nền do seeder sinh **phụ thuộc ngày seed**, nên
  không ghi sẵn được; muốn mỗi thread một người dùng khác (cache Redis dashboard theo từng user, ít tài khoản thì số đo bị
  "đẹp" hơn thực tế) thì xuất danh sách từ DB local:

  ```bash
  docker exec finance-postgres psql -U "$DB_USERNAME" -d finance_db -At \
    -c "select email from users where email like '%@example.com' and email <> 'admin@example.com' order by id" \
    > docs/testing/jmeter/all-demo-users.txt
  jmeter -n -t ledgermind-load.jmx -JusersFile=all-demo-users.txt -JuserPassword='<SEED_DEMO_PASSWORD>' ...
  ```
- Gợi ý cho chương Kiểm thử: chạy 3 mức tải (vd. 10 / 50 / 100 users, cùng `rampUp=30`, `loops=20`), lưu 3 báo cáo, ghi
  cấu hình máy (CPU, RAM) và ghi rõ "chạy trên máy local qua docker compose".
