# Phase 2 vòng đời hóa đơn: phần mobile (viết ngày 2026-10-30, trên `main` 6511ece)

> **Cách dùng file này**
> 1. Chạy `git checkout main && git pull origin main` để lấy code mới nhất.
> 2. Chép file này vào `docs/handoff/2026-10-30-receipt-phase2-mobile.md` trong repo.
> 3. Mở Claude Code ở thư mục gốc repo rồi dán **prompt ở mục 9**. Claude sẽ đọc file này và tự làm hết: tạo nhánh, code, test, commit, push và tạo PR.
> 4. Người làm chỉ cần đọc PR và báo Trí review. **Không tự merge.**

## 1. Bối cảnh

- **Phase 1 (backend, đã xong):**
  - Hóa đơn có vòng đời gồm các trạng thái: `PENDING`, `COMPLETED_RAW`, `EDITED`, `FAILED`, `WAITING_FOR_REVIEW`, `APPROVED`, `CANCELED`. `PROCESSING` chỉ để dành, không bao giờ xảy ra.
  - Mỗi lần AI đọc hóa đơn được lưu riêng và không bao giờ bị ghi đè.
  - Có API cho chủ hóa đơn: xem, sửa, đọc lại và gửi số tiền đúng.
- **Phase 2 (việc trong file này):**
  - Hiện app mobile **chưa gọi API nào** dưới `/api/receipts/*`.
  - Người dùng chỉ thấy nhãn trạng thái của hóa đơn trên giao dịch. Họ không mở được hóa đơn để sửa, đọc lại hay báo sai.
- **Luồng đang chạy (không đổi):**
  1. Điện thoại gọi ai-service `POST /donut/scan` (`RemoteApiHelper.scanReceipt`).
  2. Người dùng kiểm tra kết quả.
  3. App gửi `POST /api/transactions/checkout`, kèm `rawReceiptData` là JSON của kết quả AI, tạo bằng `jsonEncode(raw)` trong `lib/models/receipt_scan_result.dart`.
  4. core-backend **không bao giờ tự gọi AI**. Vì vậy khi đọc lại, điện thoại phải tự quét lại rồi gửi kết quả lên.

## 2. Điều kiện trước khi bắt đầu (bắt buộc)

PR backend `fix/backlog-schema` (của Anh Tuấn) có sửa phần hóa đơn. PR này thêm chủ sở hữu cho hóa đơn, giới hạn **tối đa 10 lần đọc**, và đổi lỗi "không cho gửi số tiền" từ 500 thành **409**. Chạy lệnh sau để kiểm tra PR đã vào `main` chưa:

```bash
git fetch origin
git log origin/main --oneline | grep -i "receipts have an owner"
```

- **Có kết quả:** bắt đầu làm.
- **Không có kết quả:** **dừng lại, báo Trí**, chưa code gì cả.

## 3. Hợp đồng API (đọc từ code backend, không được sửa backend)

Mọi response đều theo dạng `{ code, message, data }`. Gọi qua `_dio` có sẵn trong `RemoteApiHelper`, vì `_dio` đã gắn JWT và ngôn ngữ.

| API | Body / tham số | Trả về `data` | Lỗi chính |
|---|---|---|---|
| `GET /api/receipts/transaction/{transactionId}` | | `ReceiptResponseDto` | 404 nếu giao dịch không có hóa đơn hoặc không phải của mình |
| `GET /api/receipts/{id}` | | `ReceiptResponseDto` | 404 |
| `PUT /api/receipts/{id}` | `{ version, vendorName?, extractedTotal?, extractedDate? }`, cần ít nhất 1 trường | `ReceiptResponseDto` mới (đã sang `EDITED`, `version` mới) | **409** nếu `version` cũ hoặc trạng thái không cho sửa; 400 nếu sai dữ liệu |
| `POST /api/receipts/{id}/retry` | `{ rawReceiptData: "<JSON text>", clientId: "<uuid v4>" }` | `ReceiptResponseDto`, là `COMPLETED_RAW` hoặc lại `FAILED` kèm lý do | **409** nếu hóa đơn không còn `FAILED`, có request khác sửa trước, hoặc đã quá 10 lần đọc |
| `POST /api/receipts/feedback/{id}?manualAmount=<số>` | query param, không có body | `null` | **409** nếu hóa đơn không `FAILED`; 400 nếu số tiền ≤ 0 |

**Các trường của `ReceiptResponseDto`:**
- `id`, `transactionId`
- `status`: tên trạng thái vòng đời, ví dụ `COMPLETED_RAW`
- `version` (Long): phải gửi lại khi sửa
- `vendorName`, `extractedTotal` (số), `extractedDate` (`yyyy-MM-dd`), `imageUrl`
- `errorCode`: `AI_UNREADABLE`, `AI_NO_TOTAL` hoặc `REJECTED_BY_ADMIN`
- `errorMessage`: câu tiếng Việt cố định đi kèm `errorCode`
- `createdAt`, `updatedAt`

**Ai được làm gì (theo máy trạng thái của backend):**

| Trạng thái | Sửa (PUT) | Đọc lại (retry) | Gửi số tiền đúng (feedback) |
|---|---|---|---|
| `COMPLETED_RAW`, `EDITED` | có | không | không |
| `FAILED` | không | có | có |
| `PENDING`, `WAITING_FOR_REVIEW`, `APPROVED`, `CANCELED` | không | không | không (chỉ xem) |

**Lưu ý quan trọng:**
- Sửa hóa đơn **không đổi số tiền giao dịch hay số dư ví**. Chỉ khi admin duyệt thì tổng tiền mới đã sửa được áp vào giao dịch và ví. Giao diện phải nói rõ điều này bằng một dòng gợi ý.
- `TransactionResponseDto.receiptStatus` vẫn trả **tên cũ**:
  - `COMPLETED_RAW`, `EDITED` và `APPROVED` đều trả về `"SUCCESS"`.
  - Enum `lib/models/receipt_status.dart` (`ReceiptStatus.fromServer`) đọc tên cũ này. **Không đổi enum đó.**
- Giao dịch **không có `receiptId`**. Vì vậy mở hóa đơn bằng `GET /api/receipts/transaction/{transactionId}`.
- Giao dịch chưa đồng bộ (id null, `syncStatus` khác synced) thì **không** hiện lối vào hóa đơn.

## 4. Phạm vi (đã chốt, không tự mở rộng)

**Làm:**
1. Ở `TransactionDetailPage` (`lib/screens/ledger/transaction_detail_page.dart`), hàng **"Hóa đơn"** có nhãn trạng thái (khoảng dòng 281) bấm được khi giao dịch đã đồng bộ. Bấm vào thì mở **sheet chi tiết hóa đơn**.
2. **Sheet chi tiết hóa đơn** (file mới `lib/widgets/receipt/receipt_detail_sheet.dart`, mở bằng hàm `showReceiptDetailSheet(...)`, theo mẫu `scan_options_sheet.dart` và `category_picker_sheet.dart`):
   - Hiện tên trạng thái vòng đời (nhãn tiếng Việt/Anh qua ARB), cửa hàng, tổng tiền (`CurrencyHelper.formatVND`) và ngày (`DateFormat` của `intl`, cùng cách `transaction_detail_page.dart` định dạng ngày).
   - Khi `FAILED`: thêm khối lỗi, hiện `errorMessage`.
   - Đang tải thì hiện vòng xoay. Tải lỗi thì dùng `AppStateView` có nút thử lại.
   - Nút theo trạng thái (bảng ở mục 3):
     - **"Sửa thông tin"**: hiện khi `COMPLETED_RAW` hoặc `EDITED`.
     - **"Đọc lại"** và **"Gửi số tiền đúng"**: hiện khi `FAILED`.
     - Trạng thái khác thì không có nút.
3. **Sửa thông tin:**
   - Form trong sheet gồm 3 trường: cửa hàng, tổng tiền, ngày.
   - Dùng lại `CustomTextField`, ô nhập tiền giống form giao dịch (`lib/core/utils/money_input_formatter.dart`), và `showDatePickerSheet`.
   - Chỉ gửi những trường người dùng đã đổi, kèm `version`.
   - Có dòng gợi ý: "Giao dịch và số dư chỉ đổi sau khi quản trị viên duyệt."
4. **Đọc lại:**
   - Nếu có `imageUrl`: tải ảnh về thư mục tạm (`path_provider` → `getTemporaryDirectory()`) bằng **một `Dio()` riêng, không gắn JWT**, vì không được gửi token sang Cloudinary.
   - Gọi `RemoteApiHelper.scanReceipt(path)`.
   - Gửi `retry` với `rawReceiptData = jsonEncode(kết quả)` và `clientId = Uuid().v4()`. **Nếu request lỗi mạng thì dùng lại đúng `clientId` cũ khi bấm lại.**
   - Xóa file tạm khi xong, kể cả khi lỗi (`finally`).
   - Nếu không có `imageUrl` thì ẩn nút "Đọc lại".
5. **Gửi số tiền đúng:** một ô nhập số tiền rồi gọi `feedback`. Thành công thì hóa đơn sang `WAITING_FOR_REVIEW`. Tải lại sheet để thấy trạng thái mới.
6. **Sau mỗi lần thay đổi thành công:**
   - Hiện toast thành công (`AppToast`).
   - Tải lại hóa đơn trong sheet.
   - Khi đóng sheet, trả `true` để `TransactionDetailPage` cập nhật nhãn trạng thái. Đọc code trang để xem cách làm mới `_tx`. Nếu không có cách tải lại, cập nhật `receiptStatus` tại chỗ: `FAILED` → failed; `COMPLETED_RAW`/`EDITED`/`APPROVED` → success; `PENDING`/`WAITING_FOR_REVIEW` → processing.
7. **Xử lý lỗi:**
   - **409:** toast hiện `message` của server, rồi **tự tải lại** hóa đơn để lấy `version` và trạng thái mới.
   - Các lỗi khác: dùng `UserFacingError.messageOf(e, loc)` như các màn khác. **Không bao giờ hiện chuỗi exception thô.**
   - Có cờ `_busy` chặn bấm hai lần, và `PopScope(canPop: !_busy)` khi đang gửi.
   - Sau mọi `await` phải có `if (!mounted) return;`.

**Không làm:**
- Không sửa backend, ai-service, `pubspec.yaml`, `docker-compose*`, `deploy/`, `.github/`.
- Không thêm thư viện. `dio`, `uuid` và `path_provider` đã có sẵn.
- Không đổi layout các màn T9 đã duyệt (spec `docs/superpowers/specs/2026-10-27-t9-redesign-design.md`). Chỉ thêm sheet mới và làm hàng "Hóa đơn" bấm được.
- Không thêm màn danh sách hóa đơn, không xem lịch sử các lần đọc (đó là API admin), không hủy hóa đơn.
- Không đổi enum `ReceiptStatus` hay `ReceiptStatusBadge`.

## 5. Quy ước code (bắt buộc; `CLAUDE.md` không có trong repo vì bị git-ignore)

- **Stack:** Flutter 3.x, Dart `^3.10.8`, package `finance_ai_app`. Import tuyệt đối `package:finance_ai_app/...`.
- **State:** `StatefulWidget` + `setState`. Không dùng provider/bloc cho phần này.
- **Gọi API:** chỉ thêm hàm vào `lib/services/remote_api_helper.dart`, theo mẫu `updateTransaction` và `deleteTransaction`. Màn hình không gọi `dio` trực tiếp. Ngoại lệ duy nhất là `Dio()` không JWT để tải ảnh, và nó cũng nằm trong `RemoteApiHelper`.
- **Model:** file mới `lib/models/receipt_detail.dart`:
  - `class ReceiptDetail` có `fromJson`.
  - Các getter `canEdit`, `canRetry`, `canSendAmount` lấy theo bảng ở mục 3.
  - Tên trạng thái lấy từ hằng, **không dùng magic string rải rác**.
- **Màu và chữ:**
  - Màu đi qua `Theme.of(context).colorScheme` hoặc `context.colors`.
  - Cỡ chữ đi qua `AppTextSize` (`lib/core/theme/app_typography.dart`).
  - Phải đúng ở **cả sáng và tối**. Không viết mã hex.
  - Độ trong suốt dùng `.withValues(alpha: ...)`.
- **Chữ hiển thị:**
  - Mọi chuỗi phải nằm trong `lib/l10n/app_vi.arb` và `app_en.arb`. Key bản `en` có `@description`.
  - Đặt tên key theo tiền tố `receiptDetail...`.
  - Chỉ thêm đúng các key cần. Sửa ARB xong thì chạy `flutter gen-l10n`.
  - Đọc chuỗi bằng `context.loc`.
- **Widget dùng chung:**
  - Ưu tiên dùng lại `lib/widgets/common/`, `lib/widgets/dialogs/app_dialog.dart`, `lib/widgets/feedback/app_toast.dart`, `lib/widgets/inputs/date_picker_sheet.dart`, `lib/core/utils/currency_helper.dart`, `lib/core/utils/money_input_formatter.dart`, `lib/core/utils/user_facing_error.dart`.
  - **Không sửa `lib/widgets/common/`.** Nếu bắt buộc phải sửa thì chỉ được thêm tham số tùy chọn, không đổi API cũ, và phải ghi lại trong PR.
- **Comment:** cùng mật độ và giọng với file xung quanh. Các file mobile hiện viết comment bằng tiếng Anh.
- **Phạm vi:** không format lại, không "dọn" code ngoài task. Chỉ chạy `dart format` trên **đúng các file đã sửa**.
- Không tạo file trùng hay helper thừa, không để import thừa.

## 6. Test và cách chạy (TDD: viết test đỏ trước, rồi sửa cho xanh)

**Cách chạy:**
- Flutter cài qua snap. **Luôn pipe output**, không thì lệnh trả mã 255 và output dồn một dòng:
  ```bash
  cd mobile-app
  flutter test --no-pub test/<đường dẫn>_test.dart 2>&1 | tr '\r' '\n' | tail -60
  flutter analyze --no-pub 2>&1 | tr '\r' '\n' | tail -30
  ```
- Test widget giả lập HTTP bằng `test/helpers/fake_backend.dart` (`FakeBackend.on('GET', '/api/receipts/transaction/42', ...)`). Xem cách cài nó vào `RemoteApiHelper` trong `test/screens/ledger/transaction_detail_page_test.dart`.
- Test cần ARB thì bọc theo helper có sẵn trong `test/helpers/` (`app_settings_scope.dart`). Màu sáng/tối dùng `theme_colors.dart`.

**Test tối thiểu:**
1. `test/models/receipt_detail_test.dart`: `fromJson` đủ trường (cả khi null) và bảng `canEdit`/`canRetry`/`canSendAmount` cho từng trạng thái.
2. `test/services/remote_api_helper_receipt_test.dart`, mỗi hàm API một test:
   - Đúng method, đường dẫn và body. `retry` gửi `rawReceiptData` dạng **chuỗi** JSON; `feedback` gửi `manualAmount` dạng **query**.
   - 409 ném ra lỗi mang `message` của server.
3. `test/widgets/receipt/receipt_detail_sheet_test.dart`:
   - Hiện đúng nút theo trạng thái: `COMPLETED_RAW` có "Sửa"; `FAILED` có "Đọc lại" và "Gửi số tiền đúng"; `APPROVED` không có nút.
   - Sửa chỉ gửi trường đã đổi, kèm `version`.
   - 409 thì hiện toast và gọi lại `GET`.
   - Bấm hai lần chỉ gửi một request.
   - Retry khi lỗi mạng rồi bấm lại thì dùng lại cùng `clientId`.
   - Không có `imageUrl` thì không có nút "Đọc lại".
   - Hiển thị được ở theme sáng và tối, không lỗi tràn chữ ở chiều rộng 320 px.
4. Thêm vào `test/screens/ledger/transaction_detail_page_test.dart`:
   - Giao dịch đã đồng bộ có hóa đơn: bấm hàng "Hóa đơn" thì sheet mở.
   - Giao dịch chưa đồng bộ thì không bấm được.
   - Đóng sheet sau khi thay đổi thì nhãn trạng thái được cập nhật.

**Quy tắc khi chạy test:**
- Trong lúc làm, chỉ chạy test của file liên quan và `flutter analyze`.
- **Một lần cuối trước khi push**, chạy cả bộ test mobile:
  ```bash
  flutter test --no-pub 2>&1 | tr '\r' '\n' | tail -40
  ```
  Bộ test phải xanh hết, và `flutter analyze` phải ra "No issues found!".
- Nếu một test đỏ mà sửa **một lần** vẫn đỏ: **dừng lại, báo người làm**. Không thử sửa lung tung nhiều lần.
- Không bao giờ sửa test cũ chỉ để cho nó xanh. Nếu một test cũ phải đổi vì hành vi đổi có chủ đích, ghi rõ lý do trong PR.
- Không chạy app với DB thật, không đụng các container `finance-*` hay `docker compose`.

## 7. Thứ tự task (mỗi task 1 commit)

| # | Task | File chính | Commit message |
|---|---|---|---|
| 1 | Model `ReceiptDetail` + test | `lib/models/receipt_detail.dart` | `feat(mobile): receipt detail model with lifecycle actions` |
| 2 | 4 hàm API + hàm tải ảnh không JWT + test | `lib/services/remote_api_helper.dart` | `feat(mobile): receipt read, edit, retry and feedback calls` |
| 3 | ARB keys + `flutter gen-l10n` | `lib/l10n/app_vi.arb`, `app_en.arb` (+ file sinh ra) | gộp vào commit 4 |
| 4 | Sheet chi tiết (xem + 3 hành động) + test | `lib/widgets/receipt/receipt_detail_sheet.dart` | `feat(mobile): receipt detail sheet (edit, read again, send the right amount)` |
| 5 | Nối vào `TransactionDetailPage` + test | `lib/screens/ledger/transaction_detail_page.dart` | `feat(mobile): open the receipt sheet from the transaction detail` |
| 6 | Chạy cả bộ test + analyze, sửa nếu cần (tối đa 1 lần), push, tạo PR | | |

## 8. Git: nhánh, commit, push, PR

```bash
git checkout main
git pull origin main
git checkout -b feat/receipt-phase2-mobile

# Sau mỗi task: chỉ add đúng file của task (KHÔNG dùng git add -A hay git add .)
git add <các file của task>
git commit -m "<message ở bảng mục 7>"

# Xong task 6:
git push -u origin feat/receipt-phase2-mobile
gh pr create --base main --head feat/receipt-phase2-mobile \
  --title "feat(mobile): receipt lifecycle phase 2 (view, edit, read again, send amount)" \
  --body-file <file tạm chứa nội dung PR theo mẫu dưới>
```

**Quy tắc git:**
- **KHÔNG** thêm dòng `Co-Authored-By: Claude ...`, `Claude-Session` hay "Generated with Claude Code" vào commit hoặc PR. Repo đã xóa hết các dòng này.
- Commit message viết tiếng Anh, theo dạng `feat(mobile): ...` hoặc `test(mobile): ...`.
- Không commit file ngoài phạm vi, như `docs/handoff/` hay file ghi chú cá nhân, và không commit file này.
- Không `git push --force` lên `main`, không merge PR, không xóa nhánh của người khác.
- Nếu `main` có commit mới trong lúc làm: `git fetch origin && git rebase origin/main`, chạy lại test liên quan, rồi `git push --force-with-lease` (chỉ trên nhánh của mình).

**Mẫu nội dung PR:**

```markdown
## Tóm tắt
Phase 2 vòng đời hóa đơn (mobile): từ chi tiết giao dịch mở được hóa đơn để xem, sửa (COMPLETED_RAW/EDITED), đọc lại (FAILED) và gửi số tiền đúng cho admin duyệt (FAILED). Không đổi backend.

## File đã sửa / thêm
- ...

## Test
- flutter analyze: No issues found!
- flutter test (cả bộ): <số> test, tất cả xanh
- Test mới: <liệt kê file>

## Quyết định đã tự chọn
- ...

## Cần Trí kiểm tra trên máy thật
- Đọc lại hóa đơn FAILED (cần ai-service chạy).
- Sửa hóa đơn rồi admin duyệt trên /admin/receipts: số tiền giao dịch đổi theo.
```

## 9. Prompt dán vào Claude Code

```text
Đọc toàn bộ docs/handoff/2026-10-30-receipt-phase2-mobile.md rồi làm theo đúng file đó:
1. Kiểm tra điều kiện ở mục 2. Không đạt thì dừng và báo tôi.
2. Tạo nhánh như mục 8.
3. Làm lần lượt các task ở mục 7 theo TDD (test đỏ trước, rồi sửa cho xanh), theo đúng phạm vi mục 4, quy ước mục 5 và cách chạy test mục 6. Mỗi task một commit, không thêm dòng Claude vào commit.
4. Trước khi code, đọc các file được nêu tên (transaction_detail_page.dart, remote_api_helper.dart, receipt_status.dart, scan_options_sheet.dart, category_picker_sheet.dart, test transaction_detail_page_test.dart, fake_backend.dart) để làm giống code hiện có. Thiếu thông tin về một class thì đọc file đó, không đoán.
5. Một test đỏ mà sửa một lần vẫn đỏ thì dừng và báo tôi.
6. Xong thì chạy cả bộ flutter test và flutter analyze, push, tạo PR theo mẫu ở mục 8. Không merge.
7. Báo cáo ngắn: link PR, danh sách file, kết quả test, các quyết định đã tự chọn. Không in toàn bộ code ra chat.
```
