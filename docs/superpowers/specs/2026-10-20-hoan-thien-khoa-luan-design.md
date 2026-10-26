# Hoàn thiện đồ án CNTT-KLCN175 — Thiết kế & lộ trình

- Ngày lập: 2026-10-20 · Hạn đồ án (theo `ycda.txt`): **06/11/2026**
- Đề tài: *Nghiên cứu mô hình DONUT OCR-free trong trích xuất thông tin hóa đơn tiếng Việt và ứng dụng trong quản lý tài chính cá nhân* (GVHD Phùng Thế Bảo).
- Nguồn yêu cầu: `ycda.txt` (đề cương + thang điểm 10), `CNTT-KLCN175-Phung The Bao.docx`.

## 1. Mục đích

Đưa hệ thống (Mobile Flutter + Web Admin Thymeleaf + Core Spring Boot + AI FastAPI) về trạng thái **không lỗi chức năng, song ngữ đầy đủ trên mobile, đóng gói và deploy được lên VPS**, rồi viết lại quyển khóa luận (`NhomA7_BigData.docx`, hiện chỉ là file mẫu) cho đúng đề tài và đủ mọi mục trong thang điểm.

## 2. Mục tiêu / Không làm / Thất bại nếu

**Mục tiêu**
- Mọi chức năng 1–5 trong `ycda.txt` chạy đúng ở chế độ có server.
- Chuyển sang English thì **toàn bộ** app mobile đổi ngôn ngữ (mặc định vẫn tiếng Việt).
- Regex hậu xử lý cho đủ 4 trường Seller, Address, Timestamp, Total Cost.
- Có Swagger, bộ Postman cho API chính, kịch bản JMeter: đủ yêu cầu "Kiểm thử và tài liệu hóa".
- Deploy Docker lên AWS EC2 (Ubuntu) qua GitHub Actions; mã QR tải thẳng file APK.
- Quyển khóa luận đúng đề tài, đủ chương, có số liệu thật.

**Không làm**
- Không dịch Web Admin sang tiếng Anh (đề cương không yêu cầu).
- Không train lại DONUT ở đây: việc đó ở một conversation khác, trong `ai-service/Version5/`. **Phiên này không sửa gì trong `ai-service/Version5/`.**
- Không làm thật liên kết ngân hàng hay nạp/rút tiết kiệm.

**Thất bại nếu** (dù code vẫn chạy)
- Đổi database schema hoặc làm mất dữ liệu đang có.
- Chuỗi tiếng Anh bị dịch máy móc, sai nghĩa nghiệp vụ tài chính.
- Đụng vào stack Docker local `finance-*` đang chạy, hoặc khởi động app trên DB thật (`ddl-auto=update`).
- Commit secret: `.env_deploy` hiện **chưa bị ignore** (`.gitignore` chỉ có `.env` và `.env.*`).

## 3. Ràng buộc chung cho mọi task

- Tuân thủ `CLAUDE.md`: agent **không** commit/push, **không** tự chạy `mvn test` / `flutter test` / build (trừ khi bạn yêu cầu rõ), **không** sửa `pom.xml`/`pubspec.yaml`, **không** in nguyên file ra chat. Báo cáo cuối task = danh sách file đã sửa + 1–2 câu.
- Mỗi task chạy trong **một phiên mới**: `/clear`, dán "Câu mở đầu" của task. Agent chỉ đọc file liên quan tới task.
- Mỗi task kết thúc bằng phần **"Bạn làm"**: chạy test, thử trên máy, commit. Chưa xong phần đó thì chưa sang task sau.
- Lỗi test: agent được sửa **tối đa 1 lần**, sau đó dừng lại hỏi bạn.

Ký hiệu: 🤖 = agent làm · 👤 = bạn làm.

---

## 4. Danh sách task (theo thứ tự)

### T1. Sửa `docker-compose.yml` + đưa MongoDB vào đúng vai

**Bối cảnh.** `docker compose config` báo `yaml: line 181: mapping values are not allowed`. Block MongoDB bị chèn giữa service `db` và `data-mining-api`; dòng volumes `postgres_data:  mongodb_data:` sai cú pháp. core-api không nhận `MONGO_URI` (fallback `localhost` + `admin:admin_password` trong `application.yml`). Cổng 27017 đang mở ra mọi interface. Code Mongo (OCR raw log, feedback) vẫn chưa commit. `@EnableAsync` bị khai báo 2 lần (`CoreBackendApplication` và `AsyncConfig`).

**Quyết định.** PostgreSQL là nguồn dữ liệu chính. MongoDB chỉ lưu log thô của AI, ghi bất đồng bộ sau commit. Mongo chết thì app vẫn chạy (polyglot persistence: viết thành một mục riêng trong khóa luận).

- 🤖 Sửa cấu trúc compose. Mongo chỉ bind `127.0.0.1`, có healthcheck và volume. core-api nhận `MONGO_URI` từ env, `depends_on` mongo ở mức không chặn khởi động. Kiểm bằng `docker compose config -q` (không `up`).
- 🤖 Thêm `.env_deploy` vào `.gitignore`. Bỏ `@EnableAsync` trùng.
- 🤖 Rà `OcrMongoService`: lỗi Mongo chỉ log, không làm hỏng luồng chính. Kiểm tra không trùng vai với bảng `receipt_processing_attempts`.
- 👤 `docker compose up -d` trên máy, mở web admin + app, quét 1 hóa đơn, xem log Mongo. Sau đó commit.
- **Xong khi:** `docker compose config -q` không lỗi và bạn đã test local.
- **Câu mở đầu:** `Làm task T1 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T2. Bỏ "chế độ local" + xóa nút/code thừa (mobile)

**Quyết định.** Bỏ `AppConfig.isFull = false` (app chạy hoàn toàn bằng SQLite): mỗi chức năng phải viết 2 bản, là nguồn lỗi và trái với kiến trúc microservices của đề tài. **Giữ** SQLite làm bộ nhớ tạm + hàng đợi offline (outbox, `syncStatus`, `clientId` từ A8): đây là offline-first, chuẩn doanh nghiệp.

- 🤖 Xóa mọi nhánh `!AppConfig.isFull` và chính cờ đó. Luồng ghi cục bộ chỉ còn vai trò outbox.
- 🤖 Xóa:
  - các nút "Tính năng sắp ra mắt": liên kết ngân hàng / thêm nguồn tiền (`widgets/dialogs/dashboard_bottom_sheets.dart:121,216`), Nạp/Rút/Chia sẻ (`screens/profile/savings_page.dart:388-407`);
  - file trùng `screens/receipt_scanner/user_info_screen.dart`;
  - `ReceiptModel.mock`;
  - các hàm API chết trong `services/remote_api_helper.dart`: `getWallet`, `transfer`, GET `/api/transactions?userId=`, GET `/api/users/{id}`;
  - test tương ứng của những thứ đã xóa.
- **Giữ** gói PRO / thanh toán (mock gateway): đây là phần mở rộng, chạy thật.
- 👤 `flutter analyze` + `flutter test` (theo runbook mobile), mở app kiểm tra Trang chủ / Tiết kiệm. Commit.
- **Câu mở đầu:** `Làm task T2 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T2b. Seeder dữ liệu demo chuẩn thực tế (backend)

**Bối cảnh.** Hệ thống chưa có người dùng thật; EC2 chưa có database nên sẽ khởi tạo mới. `Config/DataSeeder.java` (245 dòng) hiện tạo dữ liệu cho user id 1–2, không có `@Profile`/cờ bật tắt, và dùng id cứng. `Config/MongoDataSeeder.java` (114 dòng) seed log OCR.

**Mục tiêu.** Vừa đủ để test, demo và cho dashboard/thống kê/phân khúc AI có ý nghĩa. Không seed dư thừa. Khả năng chịu tải được chứng minh bằng JMeter (T6), không phải bằng việc seed thật nhiều dữ liệu.

**Quyết định.**
- Chỉ chạy khi bật cờ `app.seed.demo=true` (env `SEED_DEMO`). Idempotent: đã có dữ liệu thì bỏ qua, không bao giờ xóa. Prod thật để tắt.
- **Danh mục mặc định** theo thực tế VN, có cả chi và thu, mỗi danh mục kèm `key` ổn định để T4 ánh xạ sang tiếng Anh.
  - Chi: Ăn uống, Đi chợ/Siêu thị, Di chuyển, Nhà ở (thuê nhà), Hóa đơn điện nước, Internet & Điện thoại, Mua sắm, Sức khỏe, Giáo dục, Giải trí, Du lịch, Gia đình & Con cái, Hiếu hỉ, Bảo hiểm, Khác.
  - Thu: Lương, Thưởng, Kinh doanh, Đầu tư, Được tặng, Thu khác.
  - Danh sách cuối do agent chốt. Bắt buộc khớp tên với `TransactionCategories` của mobile.
- **Tài khoản:**
  - 1 admin;
  - 2 user demo có mật khẩu đạt `@StrongPassword`, đăng nhập được, ghi trong `docs/deploy/DEPLOY_GUIDE.md`, **không** ghi vào code;
  - ~30–50 user nền để dashboard admin và phân khúc VIP/ACTIVE/AT-RISK/CHURN có đủ phân bố.
- **Giao dịch:** 3–4 tháng gần nhất cho mỗi user.
  - Thời gian: lương đầu tháng, tiền nhà và điện nước định kỳ, ăn uống hằng ngày, cuối tuần chi giải trí nhiều hơn.
  - Số tiền: theo mức giá VN, làm tròn nghìn đồng.
  - Người bán: tên cửa hàng VN thật kiểu chuỗi phổ biến.
  - Tổng cỡ vài nghìn giao dịch. `walletBalance` phải khớp với tổng giao dịch.
- **Kèm theo cho user demo:**
  - ngân sách tuần và tháng, trong đó 1 cái đã vượt 80% để demo cảnh báo;
  - 2–3 mục tiêu tiết kiệm;
  - vài hóa đơn ở các trạng thái khác nhau;
  - thông báo;
  - vài bản audit log.
- Dùng seed ngẫu nhiên cố định (`Random(42)`) để lần chạy nào cũng ra cùng dữ liệu, ảnh chụp khóa luận ổn định. Ghi theo lô (batch insert) cho nhanh.
- `MongoDataSeeder` cũng dùng chung cờ đó và seed số lượng nhỏ, khớp với các hóa đơn đã seed.

**Phân công.**
- 🤖 Viết lại `DataSeeder` theo các quyết định trên, xóa phần thừa. Viết test H2 kiểm tra: idempotent, `walletBalance` khớp, cờ tắt thì không seed.
- 👤 Chạy test. `docker compose down -v` stack **dev của bạn** (chỉ khi bạn chấp nhận xóa dữ liệu local) rồi `up` lại với `SEED_DEMO=true`, đăng nhập user demo kiểm tra. Commit.
- **Câu mở đầu:** `Làm task T2b trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T3. Sửa lỗi app (3 đợt, mỗi đợt một phiên)

Tất cả lỗi dưới đây đã được kiểm chứng trong code ngày 2026-10-20. Đường dẫn tính từ `mobile-app/lib/`, trừ khi ghi `core-backend/`.

**T3a. Làm mới dữ liệu + "Số dư hiện tại"**
- Trang chủ (và Hồ sơ) trong `IndexedStack` chỉ `_load()` một lần (`dashboard_page.dart:67`, `wantKeepAlive`). Thêm/sửa/xóa ở Ledger và lưu hóa đơn (`main_scaffold.dart:110-113,143-146`) chỉ reload Ledger. → Dashboard và Profile lắng nghe `dataChangedNotifier` (hiện chỉ tab AI dùng). Mọi luồng ghi đều phát notifier. Thanh ngân sách và cảnh báo 80/100% cập nhật theo.
- Đổi nhãn "Tổng tài sản hiện tại" (`dashboard_page.dart:529`) thành **"Số dư hiện tại"**: giá trị thật là Σthu − Σchi, có thể âm.
- Giao dịch bị đếm đôi: `app_repository.dart:59` gộp bản pending ở máy với bản trên server mà không khử trùng. → Backend trả `clientId` trong `TransactionResponseDto` (giữ `from()` là mapper duy nhất), mobile bỏ bản local nào trùng `clientId`.
- Tự gửi lại outbox khi mở app hoặc khi tải Ledger (hiện chỉ có nút Resend tay ở `ledger_page.dart:1180`).

**T3b. Luồng hóa đơn**
- `review_form_page.dart:101,139,390-414`: tổng tiền chỉ hiển thị, không sửa được. AI trả 0 thì không lưu được (backend `@Positive`). → Thêm ô số tiền sửa được, giá trị ban đầu lấy từ AI.
- `:126-131`: parse ngày lỗi thì âm thầm lấy `DateTime.now()`. → Dùng date picker và cảnh báo khi phải fallback.
- `:146-158`: lưu không kèm `clientId` → đi qua `AppRepository.createTransaction` để chống trừ tiền 2 lần.
- `:55-67`: upload Cloudinary chạy tuần tự trong spinner, lỗi thì bị nuốt. → Upload lúc lưu, báo người dùng khi lỗi.
- `main_scaffold.dart:112-114,124`: lỗi scanner/thư viện ảnh chỉ `debugPrint`. → Hiện dialog lỗi.

**T3c. Lỗi, thông báo & bảo mật**
- `remote_api_helper.dart:298-301`: mọi `DioException` khi login đều thành "Sai email hoặc mật khẩu". → Phân biệt mất mạng / 5xx / 401.
- Hiện thẳng `$e` cho người dùng ("LỖI THẬT: Code 401 khi gọi https://…"): `review_form_page.dart:168`, `login_page.dart:137,195`, `remote_api_helper.dart:330-337`, `linked_services_page.dart:132`, `register_page.dart:~153`, `set_user_info.dart:167`. → Thông báo cố định, raw text chỉ ghi log.
- (Ghi chú sau T2) `UserInfoScreen` + `SetUserInfoScreen` vẫn đọc/ghi bảng `users` SQLite (giờ luôn trống); `updateUserProfile` chưa ai gọi; sửa email ở màn tài khoản chỉ báo "Máy chủ chưa hỗ trợ đổi tên đăng nhập". Gom vào mục dưới.
- `set_user_info.dart:49,104,149`: sửa hồ sơ chỉ đụng SQLite. → `fetchMe` + PUT `/api/users/{id}` với đúng field của `UserUpdateDto` (`username`, `phone`). Kiểm lại backend có lấy user từ JWT không.
- `profile_page.dart:53-55`: không có try/catch, spinner quay mãi khi lỗi.
- `savings_page.dart:130,193,213` + `remote_api_helper.dart:752-758`: thêm/sửa/xóa không bắt lỗi, xóa không hoàn tác, `fetchSavings` nuốt lỗi.
- `linked_services_page.dart:158`: polling hết lượt mà không báo gì.
- `savings_page.dart:56-58`: controller trong dialog không dispose.
- (Ghi chú sau T2b) `AdminController` gọi cứng `http://localhost:8000/admin/segment`: trong Docker không tới được ai-service → đọc URL từ cấu hình (`AI_SERVICE_URL`, mặc định `http://data-mining-api:8000`), lỗi trả thông báo cố định.
- 🔒 `core-backend/.../Controller/AppReviewMobileController.java:28`: lấy `userId` từ body (IDOR) và trả `e.getMessage()`. → Dùng `CurrentUserProvider` + exception riêng, mobile thôi gửi `userId`.
- `app_repository.dart:68-74`: `fullName` = phần đầu email. Nếu `/me` có tên thì dùng tên đó.

Cho mỗi đợt T3:
- 🤖 sửa code + viết hoặc cập nhật test.
- 👤 chạy `flutter test` (T3a, T3c thêm test backend liên quan), thử tay trên máy, commit.
- **Câu mở đầu:** `Làm task T3a (hoặc T3b/T3c) trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T4. Song ngữ toàn app mobile (4 đợt)

**Hiện trạng.** `LanguageCubit` → `MaterialApp.locale` đã nối đúng (`main.dart:115-125`), accessor là `context.loc`, ARB có 70 key. Còn ~630 dòng tiếng Việt viết cứng trong 43 file; chỉ 7 file đã dịch.

**Quyết định.**
- Tên danh mục backend vẫn lưu tiếng Việt; mobile ánh xạ tên → key ARB, tên lạ (do người dùng tạo) giữ nguyên.
- Enum label (`SyncStatus`, `ReceiptStatus`, `BudgetPeriodType`), `DateHelper` ("Hôm nay/Hôm qua"), `PasswordPolicy`, `CurrencyHelper` nhận `AppLocalizations` thay vì trả chuỗi cố định.
- Đơn vị tiền vẫn là VND ở cả hai ngôn ngữ.

**Các đợt** (chạy `gen-l10n` sau khi sửa ARB):
- **T4a** – khung chung: `main_scaffold` (4 tab + sheet quét), `core/constants*`, models, utils, `app_dialog`, `remote_api_helper`/`app_repository` fallback.
- **T4b** – Auth + Profile: login, register, account_credentials, profile_page, set_user_info, user_info, account_info, `profile_bottom_sheets`, savings.
- **T4c** – Ledger + giao dịch + hóa đơn: ledger_page, add/edit_transaction, review_form, payment_history, linked_services.
- **T4d** – Dashboard + Ngân sách + AI: dashboard_page, `dashboard_bottom_sheets`, budget_screen/form/section/progress/alert, ai_tab_page, `ai_components`, spending_range_filter.

Cho mỗi đợt:
- 🤖 thêm key EN/VI, thay chuỗi, cập nhật test bị ảnh hưởng.
- 🤖 cuối T4d grep lại: không còn literal tiếng Việt trong `lib/` (trừ dữ liệu, log, comment).
- 👤 `flutter test`, bật English và đi hết các màn hình của đợt đó, commit.
- 🤖 Backend: kiểm `Accept-Language` có được dùng cho `message` hay không. Nếu không, mobile hiển thị thông báo theo mã lỗi/HTTP status thay vì message thô.
- **Câu mở đầu:** `Làm task T4a (…T4d) trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T5. Regex hậu xử lý 4 trường (AI service)

**Phụ thuộc.** Nên làm sau khi model V5 đã có tên trường đầu ra cố định. Nếu V5 chưa xong thì làm theo format model hiện tại, chỉ cần sửa 1 bảng ánh xạ.

**Hiện trạng.** `ai_service.py:41 extract_final_cost()` lấy "số lớn nhất", rất dễ sai. `clean_vietnamese_text()` chỉ sửa dấu. Seller, Address, Timestamp chưa có xử lý gì. `Version5/postprocess.py` cũng chỉ làm sạch dấu và chưa được nối vào service.

- 🤖 Đọc `Version5/labels.py` (chỉ đọc) để biết tên trường.
- 🤖 Tạo module mới `ai-service/receipt_postprocess.py`:
  - Pydantic model kết quả;
  - Total Cost: ưu tiên số gần các từ khóa "Tổng/Thành tiền/Total", hiểu dấu `.`/`,` kiểu VN;
  - Timestamp: các dạng `dd/MM/yyyy`, `dd-MM-yy`, `HH:mm`, chuẩn hóa ISO;
  - Seller/Address: bỏ ký tự rác, chuẩn hóa khoảng trắng và hoa/thường;
  - mỗi trường kèm cờ `valid` để mobile biết trường nào cần người dùng sửa.
- 🤖 Viết test `pytest` với ~20 chuỗi mẫu thật.
- 🤖 Nối module vào `/donut/scan`, giữ nguyên các field cũ để mobile không vỡ.
- 👤 `pytest`, quét 3–5 hóa đơn thật, commit.
- **Câu mở đầu:** `Làm task T5 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T6. Tài liệu hóa & kiểm thử API (Swagger, Postman, JMeter)

- 🤖 Cấu hình springdoc:
  - `OpenApiConfig` với tiêu đề, version và bearer JWT;
  - nhóm `/api/**` và `/api/admin/**`;
  - Swagger UI public **chỉ ở profile dev**, hoặc được bảo vệ khi chạy prod.
- 🤖 `docs/testing/postman/LedgerMind.postman_collection.json` + environment:
  - luồng login → lấy token → giao dịch / ngân sách / hóa đơn / thông báo / admin;
  - mỗi request có test script kiểm status.
- 🤖 `docs/testing/jmeter/ledgermind-load.jmx`:
  - kịch bản login + GET `/api/transactions/mine` + dashboard;
  - tham số hóa host/users/ramp-up;
  - hướng dẫn chạy bằng CLI (`jmeter -n -t … -l result.jtl -e -o report/`).
- 👤 Mở `/swagger-ui.html` chụp màn hình. Chạy Postman Runner và JMeter **trên máy local**, lưu report HTML. Đây là số liệu cho chương Kiểm thử của khóa luận.
- **Câu mở đầu:** `Làm task T6 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T7. Viết lại quyển khóa luận (`NhomA7_BigData.docx`)

Mỗi phiên làm 1 bước. 🤖 dùng skill `docx` và giữ định dạng của file mẫu: font, lề, heading, mục lục tự động, đánh số hình/bảng. **Không ghi đè file gốc**: mỗi bước lưu một bản mới `KhoaLuan_KLCN175_vN.docx`, giữ nguyên `NhomA7_BigData.docx` làm mẫu.

#### T7.0 – Chốt nền tảng (bắt buộc làm trước mọi chương)
- 🤖 Đọc định dạng `NhomA7_BigData.docx`, `CNTT-KLCN175-Phung The Bao.docx` và `ycda.txt`. Đề xuất dàn ý chi tiết tới cấp 3 (x.y.z), mỗi mục ghi rõ ứng với dòng nào trong thang điểm.
- 🤖 Lập `docs/thesis/references.md` gồm 25–40 tài liệu.
  - **Mỗi tài liệu phải kiểm chứng bằng tìm kiếm web**: tác giả, năm, tên, nơi đăng, DOI/URL thật. Không tìm thấy thì bỏ. **Tuyệt đối không bịa tài liệu, không bịa số trang.**
  - Ưu tiên bài báo gốc (hội nghị/tạp chí), sau đó tới sách, tài liệu chính thức và RFC. Blog chỉ dùng khi không có nguồn khác.
  - Ứng viên cần kiểm: DONUT (Kim et al., ECCV 2022), Transformer (Vaswani et al., 2017), Swin (Liu et al., 2021), BART (Lewis et al., 2020), ViT (Dosovitskiy et al., 2021), LayoutLM (Xu et al., 2020), CORD (Park et al., 2019), SROIE (Huang et al., ICDAR 2019), MC-OCR tiếng Việt (RIVF 2021), Tesseract (Smith, 2007), Hugging Face Transformers (Wolf et al., 2020), JWT (RFC 7519), sách Microservices (Newman), tài liệu Spring/Flutter/FastAPI/PostgreSQL/Redis/MongoDB chính thức.
- 🤖 Lập `docs/thesis/facts.md`: bảng **sự thật của hệ thống**, mỗi dòng kèm bằng chứng.
  - Nội dung: số endpoint, số entity/bảng, số màn hình, số test, công nghệ và phiên bản (`pom.xml`/`pubspec.yaml`/`requirements.txt`), kiến trúc container, kích thước dataset.
  - Bằng chứng: đường dẫn file hoặc lệnh đếm.
  - Chương nào viết cũng chỉ lấy số liệu từ file này.
- 🤖 Tạo file khung `KhoaLuan_KLCN175_v0.docx` từ `Mau bao cao_Do an_Khoa luan_2025.docx`: điền bìa (đề tài, ngành, GVHD, 3 sinh viên theo `ycda.txt`), cài style đúng thể thức, đặt sẵn các đề mục chương. Không lấy nội dung từ `NhomA7_BigData.docx`.
- 👤 Duyệt dàn ý và file khung.
- **Câu mở đầu:** `Làm task T7.0 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

#### Quy tắc viết (áp dụng cho mọi chương)
- **Đúng với hệ thống thật:** mỗi mô tả chức năng, kiến trúc, số liệu phải khớp code hoặc `facts.md`. Không mô tả tính năng chưa có. Hạn chế ghi thành "hướng phát triển".
- **Trích dẫn:**
  - mọi khái niệm, định nghĩa, số liệu bên ngoài và hình lấy từ nguồn khác đều có [n];
  - chỉ trích những tài liệu có trong `references.md`;
  - danh mục tài liệu tham khảo và trích dẫn trong bài phải khớp 1–1, không thừa không thiếu.
- **Văn phong học thuật, không "giọng AI":**
  - câu khẳng định cụ thể, có số liệu và tên thành phần của hệ thống;
  - không mở bài sáo rỗng ("Trong thời đại công nghệ 4.0…", "Có thể nói rằng…", "Không chỉ… mà còn…");
  - không dùng từ cảm thán hay quảng cáo ("vượt trội", "hoàn hảo", "mạnh mẽ") khi không có số liệu chứng minh;
  - không lạm dụng gạch đầu dòng: phần lý thuyết và phân tích viết thành đoạn văn liền mạch, mỗi đoạn một ý;
  - độ dài câu thay đổi tự nhiên;
  - dùng ngôi "nhóm" / "nhóm thực hiện";
  - thuật ngữ tiếng Anh lần đầu ghi kèm nghĩa tiếng Việt, và có trong bảng từ viết tắt.
- **Khoa học:**
  - mỗi chương có đoạn dẫn nhập và đoạn tiểu kết;
  - mọi hình/bảng đều được đánh số, có tên, có nguồn và được nhắc tới trong văn bản trước khi xuất hiện;
  - phần đánh giá model ghi rõ tập dữ liệu, cách chia train/val/test, metric và công thức, đối chiếu baseline;
  - nêu cả hạn chế, không chỉ nêu ưu điểm.
- **Sau mỗi chương:** 🤖 chạy một agent rà soát độc lập, kiểm tra (1) khớp code/`facts.md`, (2) trích dẫn đủ và đúng, (3) văn phong theo quy tắc trên, (4) phủ đủ các dòng thang điểm của chương. Sửa xong mới bàn giao.
- 👤 Đọc lại và sửa câu theo giọng của nhóm. Trước khi nộp, chạy kiểm tra đạo văn bằng công cụ trường cung cấp (nếu có).

**Khung bắt buộc của trường** (`format_khoaluan_2025.txt`, file Word mẫu `Mau bao cao_Do an_Khoa luan_2025.docx`). Cách trình bày use case và sơ đồ tham khảo theo `07_HTQL_Cuahang_DongHo_PhuKien.docx`.

**Thể thức** (🤖 áp dụng bằng style của Word, không định dạng tay):
- Font: Times New Roman.
- Lề: trái 3.5 cm, phải 2.5 cm, trên 2.5 cm, dưới 2.5 cm.
- Cỡ chữ:
  - tên chương: 18, IN HOA, đậm, canh giữa;
  - đề mục 1.1: 14, IN HOA, đậm;
  - đề mục 1.1.1 và 1.1.1.1: 13, đậm;
  - nội dung: 13, giãn dòng 1.3, trước và sau 6pt, canh đều, thụt đầu dòng.
- Bullet: cấp 1 dùng "−" (position 0.3 / indent 0.8 cm), cấp 2 dùng "+" (0.8 / 1.3 cm).
- Hình: chú thích "Hình c.n: …" đặt **dưới** hình, canh giữa.
- Bảng: chú thích "Bảng c.n: …" đặt **trên** bảng; nội dung trong bảng cỡ 12, giãn dòng 1.3, trước và sau 0pt; lặp lại dòng tiêu đề khi bảng sang trang.
- Số trang: đặt ở chân trang, canh giữa. Bìa không đánh số. Từ Lời cảm ơn đến Danh mục bảng đánh số La Mã i, ii…; từ Mở đầu trở đi đánh số 1, 2…
- Mục lục, danh mục hình và danh mục bảng: tạo tự động.
- **Tài liệu tham khảo** theo mẫu của trường, đánh số [n]:
  - sách/bài báo: `[n] Tác giả, Tên tài liệu, Nơi xuất bản/Tạp chí (vol., pp.), Năm.`;
  - web: `[n] URL, truy cập ngày dd/mm/yyyy.`;
  - tài liệu tiếng Việt xếp trước, tiếng Anh xếp sau.

**Dàn ý** (đúng 5 chương của trường; mỗi mục ứng với một dòng trong thang điểm `ycda.txt`):
- **Phần đầu:**
  - bìa chính, bìa phụ;
  - lời cảm ơn;
  - nhận xét GVHD;
  - **bảng phân công nhiệm vụ thành viên** (CLO6);
  - mục lục;
  - danh mục ký hiệu và chữ viết tắt (bảng 3 cột: Viết tắt | Tiếng Anh | Tiếng Việt);
  - danh mục hình;
  - danh mục bảng.
- **Mở đầu:**
  - giới thiệu và lý do chọn đề tài;
  - mục tiêu;
  - đối tượng và phạm vi;
  - phương pháp nghiên cứu;
  - kế hoạch thực hiện 12 tuần.
- **Chương 1 – Khảo sát hệ thống và tổng quan** (nặng, review kỹ):
  - nhu cầu quản lý tài chính cá nhân và quy trình ghi chép chi tiêu hiện nay;
  - khảo sát các ứng dụng hiện có (Money Lover, MISA MoneyKeeper, Sổ Thu Chi…), kèm bảng so sánh tính năng;
  - **biểu mẫu**: các loại hóa đơn/biên lai VN thu thập được, gồm bảng danh sách biểu mẫu và ảnh mẫu (siêu thị, cửa hàng tiện lợi, nhà hàng, hóa đơn điện tử);
  - tổng quan các hướng trích xuất thông tin hóa đơn:
    - OCR truyền thống + luật;
    - OCR + mô hình layout (LayoutLM);
    - OCR-free (DONUT);
  - các công trình liên quan (SROIE, CORD, MC-OCR);
  - tổng quan công nghệ sử dụng;
  - kết chương.
- **Chương 2 – Phân tích hệ thống** (nặng nhất, review kỹ):
  - **Mô hình hóa nghiệp vụ:**
    - sơ đồ use case nghiệp vụ;
    - với mỗi quy trình nghiệp vụ chính (ghi chép thu chi; quét hóa đơn và đối soát; lập và theo dõi ngân sách, cảnh báo; thống kê và báo cáo thói quen chi tiêu; quản trị hệ thống; duyệt hóa đơn AI): bảng văn bản (mô tả, dòng cơ bản, dòng thay thế) + **sơ đồ hoạt động** + **sơ đồ tuần tự** + **sơ đồ cộng tác**.
  - **Mô hình hóa chức năng hệ thống:**
    - sơ đồ use case hệ thống (tác nhân: Người dùng, Quản trị viên, AI Service là tác nhân hệ thống);
    - **bảng đặc tả cho từng use case**, 8 trường: Tên use case | Tóm tắt | Tác nhân | Use case liên quan (include/extend) | Điều kiện tiên quyết | Dòng sự kiện chính | Dòng sự kiện phụ | Hậu điều kiện.
    - Danh sách use case (khoảng 18–22, chỉ lấy chức năng có thật): Đăng ký, Đăng nhập (email và mạng xã hội), Đăng xuất, Đổi mật khẩu, Quên/Đặt lại mật khẩu, Quản lý giao dịch, Đồng bộ giao dịch offline, Quét hóa đơn, Đối soát và lưu hóa đơn, Quản lý ngân sách, Nhận cảnh báo ngân sách, Xem thống kê, Xem báo cáo thói quen chi tiêu, Quản lý mục tiêu tiết kiệm, Xem thông báo, Cài đặt ngôn ngữ/giao diện; Admin: Quản lý người dùng, Quản lý danh mục mặc định, Duyệt hóa đơn AI, Xem nhật ký hoạt động, Xem thống kê hệ thống, Quản lý gói dịch vụ.
  - **Sơ đồ lớp mức phân tích.**
  - **Phân tích bài toán và mô hình DONUT:**
    - phát biểu bài toán trích xuất 4 trường;
    - vấn đề của OCR truyền thống mà DONUT giải quyết;
    - kiến trúc Swin encoder + BART decoder;
    - cơ chế prompt/task token;
    - vấn đề tokenizer với tiếng Việt và giải pháp mở rộng.
  - Kết chương.
- **Chương 3 – Thiết kế hệ thống:**
  - kiến trúc tổng thể microservices (Mobile, Web Admin, Core, AI, PostgreSQL, Redis, MongoDB) và sơ đồ triển khai;
  - **thiết kế CSDL:**
    - chuyển từ lớp phân tích sang mô hình quan hệ, **ERD**;
    - bảng mô tả từng bảng dữ liệu;
    - **đặc tả RBTV**: miền giá trị, liên thuộc tính, liên quan hệ/liên bộ, duy nhất. Mỗi ràng buộc phải trùng với ràng buộc thật trong code/DB (`@Positive`, CHECK enum, unique `(user_id, category_key, period_type, start_date)`, `clientId`…);
  - thiết kế lưu trữ đa mô hình (MongoDB cho log AI) và thiết kế cache Redis (key, TTL, cơ chế xóa sau commit);
  - thiết kế API RESTful (bảng endpoint) và bảo mật JWT;
  - **thiết kế giao diện** mobile + web admin, mỗi màn hình kèm ảnh;
  - **sơ đồ lớp mức thiết kế**;
  - **thiết kế chức năng**: với các chức năng chính, mỗi chức năng có **sơ đồ ba lớp** (Boundary – Control – Entity) + **sơ đồ tuần tự** mức thiết kế;
  - thiết kế mô hình AI: tokenizer mở rộng, định dạng nhãn, pipeline hậu xử lý Regex;
  - kết chương.
- **Chương 4 – Cài đặt hệ thống:**
  - môi trường và công cụ (bảng phiên bản);
  - thu thập, gán nhãn và chuẩn hóa dữ liệu;
  - huấn luyện DONUT trên Kaggle (cấu hình, siêu tham số);
  - cài đặt AI Service, Core Backend, Mobile, Web Admin;
  - đóng gói Docker.
- **Chương 5 – Thử nghiệm và triển khai:**
  - đánh giá mô hình: metric theo từng trường, so sánh các phiên bản, phân tích lỗi;
  - kiểm thử chức năng (bảng test case), kiểm thử đơn vị/tích hợp (số lượng);
  - Postman, JMeter (throughput/latency), Swagger;
  - triển khai CI/CD lên AWS EC2.
- **Kết luận:** kết quả đạt được, đánh giá mức hoàn thành so với mục tiêu, hạn chế, hướng phát triển.
- **Tài liệu tham khảo.**
- **Phụ lục** (nếu cần).

**Sơ đồ:** 🤖 viết bằng PlantUML, lưu nguồn `.puml` trong `docs/thesis/diagrams/` để 👤 sửa dễ, rồi xuất PNG chèn vào Word. Ký hiệu UML đúng chuẩn: include/extend, actor, lifeline, activation, swimlane cho sơ đồ hoạt động.

**Chia phiên** (Chương 1–2 nặng nhất nên chia nhỏ; mỗi phiên 👤 review rồi mới làm phiên sau):
- T7.1 – Mở đầu + Chương 1.
- T7.2a – Chương 2: use case nghiệp vụ + mô hình hóa các quy trình (văn bản + 3 sơ đồ mỗi quy trình).
- T7.2b – Chương 2: use case hệ thống + toàn bộ bảng đặc tả.
- T7.2c – Chương 2: sơ đồ lớp phân tích + phân tích DONUT + kết chương.
- T7.3a – Chương 3: kiến trúc, CSDL/ERD/RBTV, cache, Mongo, API.
- T7.3b – Chương 3: giao diện, lớp thiết kế, thiết kế chức năng (ba lớp + tuần tự), thiết kế AI.
- T7.4 – Chương 4 (sau T5 và khi đã train xong).
- T7.5 – Chương 5 (sau T6 và T8).
- T7.9 – phần đầu, kết luận, tài liệu tham khảo, mục lục tự động, rà soát toàn quyển.

Phân công:
- 🤖 viết nội dung, sơ đồ, bảng.
- 👤 chụp ảnh màn hình app/web và ảnh hóa đơn mẫu cho Chương 1; cung cấp số liệu train V5, report JMeter, lời cảm ơn, bảng phân công thực tế của nhóm; review sơ đồ và đặc tả; rà soát văn phong lần cuối.
- **Câu mở đầu:** `Làm task T7.<x> trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md` (ví dụ `T7.2a`).

### T8. Deploy AWS EC2 + mã QR tải APK

**Hiện trạng.**
- `.github/workflows/ci.yml` có các job test backend/mobile/ai, sau đó SSH vào EC2 bằng secrets `AWS_HOST`, `AWS_USERNAME`, `AWS_SSH_KEY`, chạy `git reset --hard` + `docker compose build/up`.
- Chưa có nginx/HTTPS. Cổng 8080/8000 đang mở thẳng ra ngoài.
- `index.html:39`: mã QR đang mã hóa `https://ledgermind.dev`, tức chính trang web, nên quét không tải được app.

- 🤖 Viết `docs/deploy/DEPLOY_GUIDE.md`, hướng dẫn từng bước cho người mới, có ô **[ĐIỀN]**:
  - tên miền, IP, user SSH;
  - cài Docker trên Ubuntu, tạo `.env` trên server (danh sách biến, **không** có giá trị thật);
  - Security Group (chỉ mở 22/80/443);
  - trỏ DNS, xin chứng chỉ HTTPS (nginx + certbot, hoặc Caddy);
  - thêm GitHub Secrets;
  - kiểm tra sau deploy, rollback, xem log.
- 🤖 Khóa bí mật JWT đang ghi cứng ở `core-backend/.../Security/JwtUtil.java:20` → đọc từ env (`JWT_SECRET`), bắt buộc ở prod, thêm vào `.env`/guide.
- 🤖 Thêm reverse proxy vào compose: chỉ proxy publish 80/443, core-api và ai-service nằm trong mạng nội bộ. Cập nhật `ci.yml` nếu cần.
- EC2 **không có dữ liệu cần giữ**: database tạo mới. Deploy lần đầu chạy với `SEED_DEMO=true`; sau khi seed xong có thể tắt cờ, dữ liệu vẫn giữ.
- 🤖 **CI build & release APK:** thêm job chạy khi push tag `v*`:
  - `flutter build apk --release`, URL backend HTTPS truyền qua `--dart-define`;
  - ký APK bằng keystore lấy từ secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`);
  - đẩy APK lên GitHub Release với tên cố định `LedgerMind.apk`.
  - Kiểm `android/app/build.gradle` đọc keystore từ file/env. Agent **không** tự sửa `pubspec.yaml`.
- 🤖 Sửa QR + nút tải thành `https://github.com/TriPhan15/donutpay-monorepo/releases/latest/download/LedgerMind.apk` (repo public nên link mở được).
- 👤 Tạo keystore bằng lệnh `keytool` trong guide và **cất bản sao an toàn**: mất keystore thì không cập nhật app được nữa. Thêm secrets, trỏ DNS, làm theo guide trên server, đẩy tag `v1.1.0`, quét QR thử bằng điện thoại.
- **Câu mở đầu:** `Làm task T8 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T9. Redesign UI (sau cùng)

Phạm vi và phong cách sẽ brainstorm riêng khi tới lúc làm, dùng mockup trực quan. Chỉ làm sau khi T1–T8 xong để không phá các ảnh chụp đã đưa vào khóa luận. Nếu redesign xong trước hạn thì chụp lại ảnh cho Chương 5 và 7.

### T10. Góp ý dùng thử của bạn (2026-10-26)

Nguồn: lần bạn dùng thử app trên máy ngày 26/10. Các nhận định "hiện trạng" dưới đây đã kiểm chứng trong code cùng ngày, trừ khi có ghi **(kiểm khi làm)**. Đường dẫn tính từ `mobile-app/lib/`, trừ khi có ghi `core-backend/`. **Phải làm xong T10 rồi mới chụp ảnh màn hình cho khóa luận**, vì T10 đổi giao diện.

**Trả lời các câu hỏi (không cần sửa code)**
- *Quét hóa đơn ngày cũ (10/07) làm số dư hôm nay (26/10) thay đổi, có đúng không?* **Đúng.** Số dư = Σ thu − Σ chi của mọi giao dịch đã ghi. Ngày của giao dịch chỉ quyết định nó rơi vào báo cáo tháng nào. Money Lover, MISA và Expensify cũng làm như vậy. Sửa duy nhất là ở T10d: hiện một dòng nhắc khi ngày hóa đơn không thuộc tháng hiện tại.
- *Quên mật khẩu chỉ dùng được với email đã đăng ký?* **Đúng, và nên như vậy.**
- *Mã PIN để làm gì?* Hiện **không để làm gì**. `profile_bottom_sheets.dart:390` ghi `app_pin` vào SharedPreferences dưới dạng chữ thường, nhưng không chỗ nào đọc lại. Khóa app chưa bao giờ được làm. Xử lý ở T10d.
- *Ghi nhớ đăng nhập có hoạt động không?* **Có, nhưng hiểu theo nghĩa khác với bạn nghĩ.** `remember` = giữ phiên khi tắt app rồi mở lại (`session_service.dart:53-60`). Đăng xuất thì luôn xóa phiên, và không có gì được điền sẵn. Xử lý ở T10d.
- *Dịch vụ liên kết có phải dữ liệu giả?* **Đúng**, provider `MOCK` (`linked_services_page.dart:22`). Liên kết ngân hàng thật nằm trong mục "Không làm". Hướng làm thật khả thi là webhook biến động số dư (SePay, Casso), cần tài khoản và đăng ký với bên đó. Phần này ghi vào Chương 6 là hướng phát triển.

**T10a. Trang chủ + tab AI** (`screens/dashboard/`, `screens/ai/`)
- Tiện ích (`dashboard_page.dart:639`, `_buildUtilityGrid`): 3 ô `spaceBetween` cách nhau quá xa. → Lưới **4 ô đều nhau**:
  1. Thêm giao dịch (mở form thêm như nút + của Ledger)
  2. Quét hóa đơn (mở sheet quét của `main_scaffold`)
  3. Ngân sách
  4. Sổ tiết kiệm

  "Báo cáo" và "Tất cả tính năng" bỏ khỏi lưới, vì đã có tab Thống kê và AI. Icon có nền tròn, nhãn tối đa 2 dòng.
- Số dư: `_balanceHidden = false` (`:58`). → Mặc định **che** mỗi lần mở trang chủ sau khi đăng nhập hoặc mở app, không lưu lựa chọn. Bấm icon mắt thì hiện.
- "Giao dịch gần đây" (`_buildTxItem`, `:774`) không bấm được. Đây là **thiếu sót, không phải chủ ý**. → Bấm vào thì mở đúng màn/sheet chi tiết mà Ledger đang dùng, dùng lại widget của Ledger chứ không viết lại.
- Phần ngân sách trên trang chủ: bấm cả khối hoặc một thanh thì mở `BudgetScreen`. Đây cũng là **thiếu sót**.
- Tab AI: "RIGHT OVERFLOWED BY 17 PIXELS" **(kiểm khi làm)**. Tìm `Row` bị tràn trong `ai_tab_page.dart` / `ai_components`, thêm widget test ở chiều rộng 360 dp và 320 dp, ở cả vi và en, để tái hiện rồi sửa (`Expanded` / `Flexible` / ellipsis).

**T10b. Widget dùng chung** (làm **trước** T10a/c/d vì các đợt kia dùng lại)
- **Thông báo (toast)**: 30 chỗ gọi `ScaffoldMessenger` trong 15 file hiện là thanh trắng ở đáy màn hình. → Thêm `widgets/feedback/app_toast.dart`: `AppToast.success/error/info(context, message)`, nổi ở **trên** màn hình, góc bo, có icon và màu theo loại (lấy từ `AppTheme`/colorScheme, chạy được cả dark mode), tự tắt sau khoảng 3 giây. Thay hết các chỗ gọi cũ, không thêm dependency.
  - Lỗi "Không thể kết nối máy chủ" thì hiện `AppDialog.error` có nút **Thử lại** khi màn hình có thao tác tải lại được; còn lại dùng toast lỗi.
  - Xóa giao dịch thành công thì hiện toast success, kèm nút **Hoàn tác** nếu luồng xóa cho phép (kiểm khi làm).
- **Ô nhập tiền**: thêm `core/utils/money_input_formatter.dart`. Khi gõ, chữ số tự nhóm theo locale: vi `1.000.000`, en `1,000,000`, cùng quy tắc với `CurrencyHelper.formatVND`. Đọc ngược ra `BigDecimal`/`num` qua một hàm duy nhất. Áp cho mọi ô nhập tiền: thêm/sửa giao dịch, review hóa đơn, ngân sách, tiết kiệm. Nếu `review_form_page` đã có formatter riêng thì gộp về file mới.
- **Chọn ngày**: thêm `widgets/inputs/date_field.dart` dùng chung. Gồm một ô hiển thị ngày (bấm mở `showDatePicker`, có icon lịch), hai chip **Hôm nay** / **Hôm qua**, và nút ↺ "về hôm nay" khi ngày đang chọn khác hôm nay. Form thêm giao dịch luôn mở với **ngày hôm nay**, không giữ tháng đang lọc ở Ledger (kiểm khi làm: luồng hiện tại truyền ngày gì vào). Dùng cho thêm/sửa giao dịch, review hóa đơn, hạn mục tiêu tiết kiệm, ngân sách.

**T10c. Thống kê + Ngân sách + Tiết kiệm**
- Ledger (`ledger_page.dart`): thêm chế độ lọc **Năm** bên cạnh Tuần/Tháng. Thêm nút **Hôm nay** trên thanh chọn kỳ (chỉ hiện khi kỳ đang xem không chứa hôm nay) để về kỳ hiện tại bằng 1 lần bấm. Sau khi thêm giao dịch mới, Ledger chuyển sang kỳ chứa giao dịch đó.
- Ngân sách:
  - Chọn danh mục "Khác" thì hiện ô nhập tên danh mục (bắt buộc, tối đa 50 ký tự). Ngân sách tính theo tên đó, khớp với tên danh mục người dùng nhập ở giao dịch (kiểm khi làm cách backend so khớp danh mục).
  - Thêm kỳ **Năm**: `core-backend/.../Entity/BudgetPeriodType.java` thêm `YEAR(366)`, mobile thêm nhãn EN/VI. Nếu cột có CHECK constraint thì viết SQL migration vào `core-backend/src/main/resources/db/` để bạn chạy tay. Không để `ddl-auto` tự đổi.
- Sổ tiết kiệm (`savings_page.dart`):
  - Ô "Đã tiết kiệm" khi tạo mục tiêu là **tùy chọn**, mặc định 0, gợi ý "Bỏ trống nếu chưa có hoặc không nhớ, sửa được sau".
  - "Hạn chót (dd/mm/yyyy)" đổi thành **"Ngày đạt mục tiêu"** (en: "Target date"), cũng tùy chọn, dùng `DateField`.
  - Tiền tiết kiệm không phải tự gõ lại mỗi lần: thêm nút **Góp tiền** trên từng mục tiêu. Backend thêm `POST /api/savings/{id}/contributions {amount}`, trong một `@Transactional` làm 2 việc:
    - khóa ví và tạo giao dịch chi, danh mục "Tiết kiệm", ghi chú tên mục tiêu;
    - cộng `currentAmount`.

    Chủ sở hữu lấy từ JWT. Nút "Cập nhật" giữ lại để sửa tay khi cần. Khi đạt 100%, hiện toast chúc mừng.

**T10d. Hóa đơn + đăng nhập + thông báo + dọn chức năng**
- Review hóa đơn (`receipt_scanner/review_form_page.dart:473`):
  - Ảnh không bấm được. → Bấm vào thì mở màn xem ảnh toàn màn hình, phóng to bằng `InteractiveViewer` (chụm 2 ngón, chạm 2 lần để zoom).
  - Thêm chế độ **đối chiếu**: ảnh ở nửa trên, có thể phóng to; 4 trường DONUT ở nửa dưới, sửa được ngay. Trường có cờ `valid=false` vẫn tô viền như T5.
  - Nút lưu: "Xác nhận & Lưu CSDL" → **"Xác nhận và lưu"** (`app_vi.arb:393`; en giữ "Confirm & save").
  - Nếu ngày hóa đơn không thuộc tháng hiện tại, hiện dòng nhắc: "Giao dịch ngày dd/mm vẫn được tính vào số dư hiện tại".
- 🐞 Lưu được 2 hóa đơn giống hệt nhau. `clientId` chỉ chống gửi trùng của **cùng một** lần lưu; hai lần quét là hai `clientId` khác nhau. → Backend: trên luồng lưu hóa đơn, kiểm tra xem người dùng đã có giao dịch cùng loại, **cùng số tiền**, **cùng thời điểm đến phút** và cùng người bán (so sau chuẩn hóa, bỏ qua nếu trống) hay chưa. Nếu có thì trả **409**, `message` cố định, kèm id giao dịch đã có. Mobile hiện dialog với 2 lựa chọn: "Hóa đơn này có vẻ đã lưu ngày …" → **Xem bản đã lưu** / **Vẫn lưu**. "Vẫn lưu" gửi lại với `allowDuplicate=true`. Thêm giao dịch tay **không** kiểm tra trùng, vì mua 2 ly cà phê giống nhau là chuyện bình thường.
- Ghi nhớ đăng nhập: giữ nghĩa cũ (giữ phiên qua lần mở app), **thêm** nhớ **email**. Lần đăng nhập thành công có tick "Ghi nhớ" thì lưu email vào SharedPreferences; sau khi đăng xuất, màn login điền sẵn email đó. Bỏ tick thì xóa email đã lưu. **Không lưu mật khẩu trong app.** Bọc form login bằng `AutofillGroup` + `autofillHints` (email, password) và gọi `TextInput.finishAutofillContext()` khi đăng nhập thành công, để Google Password Manager / iCloud Keychain đề nghị lưu rồi tự điền, đúng kiểu "giống Google" mà bạn muốn.
- Thông báo (`notifications/notification_destination.dart`):
  - Hiện chỉ ngân sách và giao dịch có `transactionId` là mở được, còn lại `null`. Thông báo trong danh sách là **thật** (từ backend), chỉ là bấm vào không đi đâu. → Mọi loại đều có đích:
    - `receiptProcessed` / `transactionAlert` không có id thì mở Ledger;
    - `unknown` thì mở sheet xem toàn bộ nội dung.
  - Bấm vào luôn đánh dấu đã đọc.
  - Kiểm khi làm: seeder có tạo thông báo thiếu id hay không.
- Mã PIN: **xóa** mục "Tạo / Đổi mã PIN" khỏi Hồ sơ, cùng các key ARB `pin*` và chỗ ghi `app_pin`. Khóa app bằng PIN thật cần lưu trữ bảo mật (dependency mới) và màn khóa khi app quay lại foreground, nằm ngoài phạm vi hạn 06/11; ghi vào Chương 6.
- Dịch vụ liên kết: giữ màn hình, thêm nhãn **"Bản demo"** rõ ràng trên trang và trên dòng menu, để hội đồng không hiểu nhầm là liên kết thật.

Cho mỗi đợt T10:
- 🤖 sửa code + viết/cập nhật test (widget test cho UI mới, `@WebMvcTest`/service test cho backend), chạy `gen-l10n` sau khi sửa ARB.
- 👤 `flutter test` (+ `mvn test` cho T10c, T10d), thử tay trên máy, commit.
- Thứ tự và chia luồng (3 terminal):
  - **Đợt 1, chạy song song:**
    - **T10b**: chỉ mobile, gồm widget dùng chung và thay 15 file đang gọi `ScaffoldMessenger`.
    - **T10a**: chỉ `screens/dashboard/`, `screens/ai/`, `widgets/` của dashboard/AI. **Không** sửa `ledger_page.dart` hay `main.dart`. Mở chi tiết giao dịch bằng đúng cơ chế mà thông báo đang dùng để mở chi tiết ở Ledger.
    - **T10-BE**: chỉ `core-backend/`:
      - `YEAR` cho ngân sách + SQL migration;
      - `POST /api/savings/{id}/contributions`;
      - kiểm tra trùng hóa đơn (409 + `allowDuplicate`) cho T10d;
      - test `@WebMvcTest`/service.

      Chỉ terminal này chạy `mvn`.
  - **Đợt 2, sau khi T10b đã commit:** phần mobile của **T10c** và **T10d** chạy song song (T10c: ledger/budget/savings; T10d: review_form/login/notifications/profile). Cả hai dùng hợp đồng API mà T10-BE đã làm.
  - ARB: mọi luồng thêm key **mới ở cuối** `app_en.arb`/`app_vi.arb`, đọc lại file ngay trước khi sửa, chạy `gen-l10n` lúc cuối phiên.
  - Sau mỗi đợt: 👤 `flutter test` một lần cho cả đợt, `mvn test` cho T10-BE.
- **Câu mở đầu:** `Làm task T10a (…T10d, T10-BE) trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

### T11. Quét nhiều hóa đơn một lúc, xử lý nền (kiểu Expensify)

**Mục đích.** Người dùng không phải đứng chờ từng hóa đơn. Họ chọn "Quét 1 hóa đơn" hoặc "Quét nhiều hóa đơn", chụp hoặc chọn bao nhiêu ảnh tùy ý, rồi đi sang tab khác. DONUT đọc lần lượt ở nền. Đọc xong hóa đơn nào thì hóa đơn đó vào danh sách **"Chờ xác nhận"**, người dùng mở từng cái ra review như T10d.

**Thiết kế.**
- Mobile:
  - `services/receipt_scan_queue.dart` là singleton, giữ hàng đợi trong SQLite (bảng mới, nâng version DB): ảnh, trạng thái `queued/reading/ready/failed`, kết quả `/donut/scan`. Gửi **tuần tự, mỗi lần một ảnh**.
  - Đóng app thì hàng đợi vẫn còn; mở lại thì chạy tiếp các mục `queued` và `reading`.
  - Không cần chạy khi app đã tắt hẳn: không có background service, không thêm dependency.
- Sheet quét trong `main_scaffold` có 2 lựa chọn:
  - **1 hóa đơn**: giữ luồng hiện tại.
  - **Nhiều hóa đơn**: ML Kit document scanner cho chụp nhiều trang, hoặc chọn nhiều ảnh từ thư viện.
- Thanh tab (hoặc trang chủ) có huy hiệu "đang đọc n / chờ xác nhận m". Thêm màn **Chờ xác nhận**: mỗi dòng là ảnh thu nhỏ + 4 trường + nút Xem/Xác nhận/Bỏ. Mục `failed` có nút "Đọc lại".
- Xác nhận đi qua đúng luồng lưu của T10d: `clientId` + kiểm tra trùng.
- ai-service: kiểm khi làm. `/donut/scan` phải chạy inference ngoài event loop (handler `def` hoặc `run_in_threadpool`) để `/health` và người dùng khác không bị chặn. Giới hạn 1 inference đồng thời, vì RAM 3G đủ cho đúng 1 model. Không đổi hợp đồng API.
- Không làm: đọc song song nhiều ảnh trên server, đẩy thông báo hệ điều hành khi đọc xong.

- 🤖 mobile + ai-service + test (queue: thứ tự, khôi phục sau khi mở lại app, lỗi mạng → `failed`).
- 👤 `flutter test`, pytest, thử quét 5 hóa đơn rồi chuyển tab, commit.
- Làm **sau T10**. Nếu không kịp trước 06/11 thì làm trước buổi bảo vệ, cùng đợt với T9, và Chương 6 ghi là hướng phát triển.
- **Câu mở đầu:** `Làm task T11 trong docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`

---

## 5. Chạy song song: 3 luồng

Mỗi luồng là 1 terminal. Trong một luồng, mỗi task là 1 phiên: xong thì `/clear`, rồi nhập task kế tiếp của luồng đó.

| Luồng | Thứ tự task | Lưu ý |
|---|---|---|
| **A – Mobile** | T2 → T3a → T3b → T3c → T4a → T4b → T4c → T4d → T5 | T4a chờ T2b xong (cần key danh mục). T5 đặt cuối vì cũng sửa `review_form_page.dart`. |
| **B – Backend/hạ tầng** | T1 → T2b → T6 | T3a và T3c (luồng A) có sửa backend: không chạy cùng lúc với T2b nếu đụng cùng file. |
| **C – Khóa luận** | T7.0 → T7.1 → T7.2a → T7.2b → T7.2c → T7.3a → T7.3b | Chỉ đụng `docs/thesis/` và file Word. Review kỹ từng phiên trước khi sang phiên sau. |
| **Giai đoạn cuối** (khi A, B, C xong) | T7.4 → T8 → T7.5 → T7.9 → T9 | T7.4 cần T5 và số liệu train; T7.5 cần report T6 và kết quả deploy T8. |
| **Góp ý dùng thử** (từ 26/10) | T10b → T10a ‖ T10c ‖ T10d → T11 | Chạy song song với T7.5 (chỉ đụng `docs/thesis/`). Chụp ảnh khóa luận sau T10. |

**Quy tắc khi chạy song song:**
- Commit theo đường dẫn của luồng mình (`git add mobile-app/ …`), **không** dùng `git add .`.
- Không chạy `mvn test` và `flutter test` cùng lúc.
- Nếu một phiên hỏi bạn thì trả lời ngay trong phiên đó, không `/clear` giữa chừng.

## 6. Lịch gợi ý (còn ~17 ngày)

| Ngày | Việc |
|---|---|
| 20–21/10 | T1, T2, T2b |
| 22–25/10 | T3a–c; song song T7.0, T7.1, T7.2a–c |
| 26–29/10 | T4a–d; song song T7.3a–b |
| 30/10 | T5 (nếu model V5 đã xong), T6 |
| 27–30/10 | T10b → T10a, T10c, T10d; deploy T8 (👤) |
| 31/10–02/11 | T7.5; chụp ảnh màn hình sau T10; T11 nếu kịp |
| 03–04/11 | T7.9 rà soát toàn quyển |
| 05/11 | Rà soát quyển, chạy toàn bộ test, đóng gói nộp |
| sau 06/11 (nếu kịp trước bảo vệ) | T9 redesign + làm slide |

## 7. Để lại cho người thực hiện tự quyết

- Tên key ARB, cấu trúc file test, cách chia nhỏ hàm.
- nginx + certbot hay Caddy (chọn cái đơn giản nhất cho người mới).
- Công cụ vẽ sơ đồ.

## 8. Các quyết định của agent (bạn kiểm tra lại khi đọc)

- Nhãn mới là "Số dư hiện tại".
- Swagger chỉ public ở môi trường dev.
- Regex nằm trong file mới `receipt_postprocess.py`, không sửa `Version5/`.
- Giữ gói PRO / thanh toán.
- T9 có thể rơi sau ngày nộp quyển 06/11.
- T2: dữ liệu chỉ lưu ở máy của chế độ local cũ (user/giao dịch/tiết kiệm SQLite) **bỏ, không migrate**: chỉ là dữ liệu demo. Khi mất mạng, app giữ hành vi hiện tại (đọc dữ liệu đã có + outbox), không chặn người dùng.
- T5: phần hiển thị cờ `valid` trên mobile (tô đỏ trường cần sửa ở `review_form_page`) làm **trong T5**, T5 được sửa file đó.
- T1: nếu Mongo trùng vai với `receipt_processing_attempts`: Postgres là nguồn sự thật cho quy trình duyệt hóa đơn; Mongo thu hẹp còn log thô + feedback phục vụ phân tích. Giữ mục polyglot persistence.
- T7 Ch.6: nếu V5 chưa xong trước 31/10 thì viết bằng số liệu phiên bản tốt nhất đang có, để sẵn bảng so sánh, cập nhật số V5 sau.
- T10a: lưới tiện ích gồm Thêm giao dịch · Quét hóa đơn · Ngân sách · Sổ tiết kiệm; bỏ "Báo cáo" và "Tất cả tính năng". Số dư che mặc định, không lưu lựa chọn.
- T10b: toast nổi phía trên, tự viết, không thêm package.
- T10c: "Góp tiền" tạo một giao dịch chi danh mục "Tiết kiệm" (tiền rời ví sang mục tiêu); chưa có "Rút tiền".
- T10d: kiểm tra trùng chỉ áp cho luồng lưu hóa đơn, khóa = loại + số tiền + thời điểm đến phút + người bán; có lối "Vẫn lưu".
- T10d: ghi nhớ đăng nhập chỉ nhớ email; mật khẩu để trình quản lý mật khẩu của hệ điều hành lo (AutofillGroup). Không lưu mật khẩu trong app.
- T10d: xóa mã PIN, vì nó chưa bao giờ được kiểm tra; dịch vụ liên kết giữ lại với nhãn "Bản demo".
- T11: hàng đợi nằm ở mobile, ai-service xử lý từng ảnh một; có thể rơi sau 06/11.
