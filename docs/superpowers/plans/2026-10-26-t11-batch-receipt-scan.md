# T11 – Quét nhiều hóa đơn (hàng đợi ở điện thoại) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Người dùng chụp hoặc chọn tối đa 20 hóa đơn một lượt. DONUT đọc lần lượt ở nền trong lúc người dùng dùng các tab khác. Đọc xong, hóa đơn vào danh sách "Chờ xác nhận"; người dùng review từng cái hoặc bấm "Xác nhận tất cả hợp lệ".

**Architecture:**
- Hàng đợi nằm trên điện thoại: một singleton `ReceiptScanQueue` lưu từng mục trong bảng SQLite mới (DB v8) và gọi `/donut/scan` **tuần tự**. Đóng app thì hàng đợi còn nguyên; mở lại thì đọc tiếp.
- Logic đổi kết quả scan thành bản nháp giao dịch được tách khỏi `ReviewFormPage` thành `ReceiptScanResult`. Form review và nút xác nhận hàng loạt cùng dùng hàm này, và cùng lưu qua `AppRepository.createTransaction` (clientId + chặn trùng 409 của T10).
- ai-service chạy inference ngoài event loop, mỗi lúc chỉ một lượt.

**Tech Stack:** Flutter (sqflite, image_picker `pickMultiImage`, google_mlkit_document_scanner, path_provider, uuid — tất cả đã có trong pubspec), FastAPI (`starlette.concurrency.run_in_threadpool`, `threading.Lock`).

**Spec:** `docs/superpowers/specs/2026-10-20-hoan-thien-khoa-luan-design.md`, mục "### T11." (và T10d cho luồng lưu/chặn trùng).

## Global Constraints

- Tuân thủ `CLAUDE.md`. Agent **không** chạy `flutter test` / `pytest` / build, **không** git add/commit, **không** sửa `pubspec.yaml`/`pom.xml`. Lệnh "Run" trong plan là 👤 người dùng chạy; agent được chạy `dart analyze lib test | tail`, `flutter gen-l10n`.
- Tối đa **20 ảnh mỗi lượt** (`ReceiptScanQueue.maxBatch = 20`). Đọc **tuần tự, mỗi lần 1 ảnh**. Không có background service khi app đã tắt.
- Không đổi hợp đồng API `/donut/scan`; không đổi backend `core-backend/`.
- Chuỗi UI chỉ qua ARB (vi + en, key mới thêm **cuối** `app_en.arb`/`app_vi.arb`, en có `@metadata`), phản hồi bằng `AppToast`/`AppDialog`, màu từ `colorScheme`/`AppTheme`, `if (!mounted) return;` sau mỗi `await` trong State.
- Lưu giao dịch **chỉ** qua `AppRepository.instance.createTransaction(userId, draft, allowDuplicate:)`. Không gọi checkout trực tiếp.
- File CRLF giữ CRLF (`profile_bottom_sheets.dart`, `ai_service.py`). Không ghi lại file bằng Python text mode.

## Review Focus

1. **Phiên hết hạn hoặc đăng xuất giữa lúc đang đọc:** vòng đọc dừng, các mục còn lại giữ `queued` (không thành `failed`), và chỉ chạy lại khi chính user đó đăng nhập. Người khác đăng nhập trên cùng máy không thấy hàng đợi của người trước. Test ở Task 3.
2. **App bị kill khi một mục đang `reading`:** mở lại thì mục đó về `queued` và được đọc lại, không kẹt mãi. Test ở Task 3.
3. **File ảnh tạm bị hệ điều hành dọn mất** (scanner/picker để ảnh trong cache): hàng đợi chép ảnh vào thư mục của app ngay lúc thêm. Nếu file vẫn mất thì mục thành `failed` với lý do "ảnh không còn", không crash. Test ở Task 3.
4. **"Xác nhận tất cả hợp lệ" gặp hóa đơn trùng (409) hoặc lỗi upload ảnh giữa chừng:** các mục khác vẫn được lưu; mục lỗi ở lại danh sách; toast tóm tắt "đã lưu x, trùng y, chưa lưu z". Không có mục nào bị lưu 2 lần. Test ở Task 4.
5. **Chọn hơn 20 ảnh, hoặc thêm lượt mới khi lượt cũ chưa xong:** chỉ nhận đến khi tổng số mục `queued`+`reading` chạm 20, báo số ảnh bị bỏ; lượt mới nối vào sau lượt cũ. Test ở Task 3.

---

### Task 1: ai-service – inference ngoài event loop, một lượt mỗi lúc

**Files:**
- Modify: `ai-service/ai_service.py` (handler `/donut/scan` ở khoảng dòng 56-140; file CRLF)
- Test: `ai-service/test_main.py`

**Interfaces:**
- Produces: `def _run_donut(pil_img: Image.Image) -> str` (đồng bộ: processor + `model.generate` + decode, trả về chuỗi sequence đã bỏ eos/pad). Thêm `_donut_lock = threading.Lock()`. Handler vẫn là `async def`: đọc file bằng `await image.read()`, rồi `sequence = await run_in_threadpool(_run_donut_locked, pil_img)`, trong đó `_run_donut_locked` giữ `_donut_lock` quanh `_run_donut`. Phần `token2json`, regex hậu xử lý và response giữ nguyên.

- [ ] **Step 1: Write the failing tests** trong `test_main.py`
  - `test_scans_run_one_at_a_time_and_health_stays_responsive`: patch `ai_service._run_donut` bằng hàm ngủ 0,3 s, đồng thời ghi lại số lượt chạy cùng lúc lớn nhất. Dùng `asyncio.run` + `httpx.AsyncClient(transport=httpx.ASGITransport(app=app))`, gửi cùng lúc 2 POST `/donut/scan` và 1 GET `/health`. Assert: số lượt chạy cùng lúc lớn nhất `== 1`; `/health` trả 200 **trước** khi lượt scan thứ hai trả về (so thời điểm hoàn thành); cả 2 scan đều 200.
  - `test_extract_receipt_info_success` (đã có) phải vẫn xanh. Nếu nó đang patch `model`/`processor` thì giữ nguyên cách patch.
- [ ] **Step 2: Run** (👤) `cd ai-service && .venv/bin/pytest test_main.py -v` → test mới FAIL.
- [ ] **Step 3: Implement** `_run_donut`, `_run_donut_locked`, gọi qua `run_in_threadpool` như trong Interfaces.
- [ ] **Step 4: Run** (👤) `.venv/bin/pytest test_main.py test_receipt_postprocess.py -v` → tất cả PASS.
- [ ] **Step 5: Commit** (người dùng báo xanh, Claude commit): `git add ai-service/ai_service.py ai-service/test_main.py` – `feat(ai): run DONUT inference off the event loop, one at a time (T11)`

### Task 2: `ReceiptScanResult` – tách logic kết quả scan khỏi form review

**Files:**
- Create: `mobile-app/lib/models/receipt_scan_result.dart`
- Modify: `mobile-app/lib/screens/receipt_scanner/review_form_page.dart` (`_callDonutApi` ~116-230, constructor ~55-70)
- Test: `mobile-app/test/models/receipt_scan_result_test.dart`, `mobile-app/test/screens/receipt_scanner/review_form_save_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class ReceiptScanResult {
    final String storeName;          // '' khi không đọc được
    final double? amount;            // null khi không đọc được hoặc <= 0
    final DateTime? date;            // null khi không parse được
    final String category;           // danh mục mặc định mà form đang chọn ban đầu
    final Map<String, dynamic> raw;  // nguyên văn response /donut/scan (để gửi rawReceiptData)
    final Set<String> invalidFields; // các key trong khối "normalized" có valid=false
    bool get allValid;               // invalidFields rỗng && amount != null && date != null && storeName.isNotEmpty
    factory ReceiptScanResult.fromResponse(Map<String, dynamic> response);
    Map<String, dynamic> toJson();   // = raw (để lưu SQLite)
    TransactionModel toDraft({String? imageUrl}); // cùng quy tắc với _draftOf của form: title = storeName hoặc category
  }
  ```
- `ReviewFormPage` nhận thêm `final ReceiptScanResult? initialScan;`. Có giá trị thì **không** gọi `/donut/scan`, và form điền bằng đúng các giá trị đó (tô viền các trường `invalidFields`, cảnh báo ngày khi `date == null`).

- [ ] **Step 1: Write the failing tests**
  - `receipt_scan_result_test.dart`:
    - Response đủ khối `normalized`, mọi trường hợp lệ → `allValid` true, `amount`/`date`/`storeName` khớp.
    - Có trường `valid:false` → nằm trong `invalidFields`, `allValid` false.
    - Không có khối `normalized` (ai-service cũ) → `invalidFields` rỗng, giá trị lấy từ trường thô.
    - Tổng tiền 0 → `amount` null, `allValid` false.
    - Ngày không parse được → `date` null.
    - `toDraft(imageUrl: 'u')` có `rawReceiptData == jsonEncode(raw)`, `imageUrl == 'u'`, `isExpense` true.
  - `review_form_save_test.dart`: `ReviewFormPage(imagePath:…, initialScan: …)` không gửi request `/donut/scan` nào. Các ô hiển thị đúng giá trị đó; trường không hợp lệ được tô viền như T5.
- [ ] **Step 2: Run** (👤) `flutter test test/models/receipt_scan_result_test.dart test/screens/receipt_scanner/review_form_save_test.dart` → FAIL.
- [ ] **Step 3: Implement.** Chuyển phần parse trong `_callDonutApi` (gồm `_scannedDateFormats`, `_NormalizedScan`) sang `receipt_scan_result.dart`. Form gọi `ReceiptScanResult.fromResponse` và không còn logic parse trùng lặp.
- [ ] **Step 4: Run** (👤) cùng lệnh, cộng thêm `test/screens/receipt_scanner/` → PASS.
- [ ] **Step 5: Commit** – `refactor(mobile): ReceiptScanResult shared by the review form and the scan queue (T11)`

### Task 3: Hàng đợi `ReceiptScanQueue` + bảng SQLite v8

**Files:**
- Create: `mobile-app/lib/models/scan_queue_item.dart`, `mobile-app/lib/services/receipt_scan_queue.dart`
- Modify: `mobile-app/lib/services/sqflite_helper.dart` (`_dbVersion` 7 → 8, `onCreate` + `onUpgrade` `if (oldVersion < 8)`), `mobile-app/lib/screens/main_scaffold.dart` (gọi `resume()` trong `initState`)
- Test: `mobile-app/test/services/receipt_scan_queue_test.dart`

**Interfaces:**
- Consumes: `ReceiptScanResult.fromResponse` (Task 2), `RemoteApiHelper.instance.scanReceipt(String imagePath) → Future<Map<String, dynamic>>`, `SessionService.currentUserId`.
- Produces:
  ```dart
  enum ScanQueueStatus { queued, reading, ready, failed }   // lưu dạng name
  class ScanQueueItem { final int id; final int userId; final String imagePath; final ScanQueueStatus status;
                        final ReceiptScanResult? result; final String? error; final DateTime createdAt; }
  class ScanQueueProgress { final int done; final int total; final int ready; final int failed; bool get isReading; }
  class ReceiptScanQueue {
    static final ReceiptScanQueue instance;
    static const int maxBatch = 20;
    ValueListenable<ScanQueueProgress> get progress;
    Future<int> enqueue(List<String> imagePaths);   // trả về số ảnh đã nhận
    Future<void> resume();                          // reading→queued của user hiện tại, rồi chạy vòng đọc
    Future<List<ScanQueueItem>> items();            // của user hiện tại, cũ trước
    Future<void> retry(int id);                     // failed → queued, chạy vòng đọc
    Future<void> remove(int id);                    // xóa dòng + file ảnh đã chép
  }
  ```
- Bảng `receipt_scan_queue`: `id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, image_path TEXT NOT NULL, status TEXT NOT NULL, result_json TEXT, error TEXT, created_at TEXT NOT NULL`.
- `enqueue` chép từng ảnh sang `<getApplicationDocumentsDirectory()>/receipt_queue/<uuid>.<ext>`. Số ảnh nhận được = `min(paths.length, maxBatch − số mục queued/reading hiện có)`.
- `progress.total` = số mục của lượt đang chạy (queued + reading + các mục đã xong từ lúc vòng đọc bắt đầu). Khi vòng đọc kết thúc: `total` về 0 và `ready` = số mục `ready` còn trong bảng.
- Lỗi khi đọc: mất mạng, 5xx hoặc file mất → `failed` với `error` là mã cố định (`network` / `server` / `missing_image`). 401/403 hoặc `currentUserId == null` → dừng vòng đọc, mục giữ `queued`.
- Mỗi lần ghi phát `RemoteApiHelper.instance.dataChangedNotifier` **không** cần; chỉ `progress` thay đổi.

- [ ] **Step 1: Write the failing tests** (`receipt_scan_queue_test.dart`; dùng sqflite_common_ffi in-memory và fake backend như các test repository hiện có; xem `mobile-tooling-runbook`):
  - `scans one image at a time in the order they were added`: 3 ảnh; fake `/donut/scan` trả về chậm. Request thứ 2 chỉ bắt đầu sau khi request thứ 1 xong; kết quả cả 3 là `ready` theo đúng thứ tự.
  - `progress counts done over total while reading`: giá trị `progress` lần lượt là 0/3 → 1/3 → 2/3 → 3/3, cuối cùng `ready == 3`.
  - `a network failure marks only that item failed and retry reads it again`.
  - `an item left reading by a killed app is read again on resume`.
  - `a signed-out or expired session stops the loop and keeps the rest queued`, và `items()` của user khác trả về rỗng.
  - `accepts at most 20 queued or reading items`: thêm 15 rồi thêm 10 → lần sau trả về 5.
  - `a copied image that disappeared fails with missing_image`.
  - `remove deletes the row and the copied image`.
  - Migration: mở DB v7 rồi nâng lên v8 thì tạo bảng, giữ nguyên dữ liệu `transactions`.
- [ ] **Step 2: Run** (👤) `flutter test test/services/receipt_scan_queue_test.dart` → FAIL.
- [ ] **Step 3: Implement** theo Interfaces. Vòng đọc là một `Future` duy nhất, dùng cờ `_running` để gọi `resume()`/`enqueue()` lần nữa thì không mở vòng thứ hai. `MainScaffold.initState` gọi `ReceiptScanQueue.instance.resume()`.
- [ ] **Step 4: Run** (👤) cùng lệnh, cộng thêm `test/services/` `test/repositories/` → PASS.
- [ ] **Step 5: Commit** – `feat(mobile): persistent sequential receipt scan queue, SQLite v8 (T11)`

### Task 4: Xác nhận hàng loạt

**Files:**
- Modify: `mobile-app/lib/services/receipt_scan_queue.dart`
- Test: `mobile-app/test/services/receipt_scan_queue_test.dart`

**Interfaces:**
- Consumes: `ReceiptScanResult.allValid` / `toDraft` (Task 2), `RemoteApiHelper.instance.uploadImage(String path) → Future<String?>`, `AppRepository.instance.createTransaction(int userId, TransactionModel draft, {bool allowDuplicate})`, `DuplicateReceiptException`.
- Produces:
  ```dart
  class BulkConfirmResult { final int saved; final int duplicates; final int notSaved; }
  Future<BulkConfirmResult> confirmAllValid();   // trên ReceiptScanQueue
  Future<void> markConfirmed(int id);            // = remove, dùng sau khi form review lưu xong
  ```
- `confirmAllValid` xử lý **tuần tự** từng mục `ready` có `allValid`: upload ảnh trước, upload lỗi thì `notSaved++` và giữ mục lại. Sau đó `createTransaction(allowDuplicate: false)`: thành công (kể cả khi kết quả là pending offline) → `saved++` rồi `remove`; `DuplicateReceiptException` → `duplicates++` và giữ mục; lỗi khác → `notSaved++` và giữ mục. Gọi lần nữa trong lúc đang chạy thì trả về ngay `BulkConfirmResult(0,0,0)`. Chạy xong thì tăng `dataChangedNotifier` một lần.

- [ ] **Step 1: Write the failing tests:**
  - `confirms only the valid ready items`: gồm 2 mục hợp lệ, 1 mục có trường sai, 1 mục `failed` → `saved == 2`, còn lại 2 mục.
  - `a duplicate (409) is kept and counted, the others are saved`.
  - `an upload failure keeps that item and saves the rest`.
  - `a second call while confirming does nothing` (kiểm số request checkout).
  - `offline: the draft goes to the outbox and the item leaves the queue`.
- [ ] **Step 2: Run** (👤) → FAIL. **Step 3: Implement.** **Step 4: Run** (👤) → PASS.
- [ ] **Step 5: Commit** – `feat(mobile): confirm every valid scanned receipt at once (T11)`

### Task 5: Giao diện – sheet quét, thanh tiến độ, màn "Chờ xác nhận"

**Files:**
- Create: `mobile-app/lib/screens/receipt_scanner/pending_receipts_screen.dart`, `mobile-app/lib/widgets/receipt/scan_queue_banner.dart`
- Modify: `mobile-app/lib/screens/main_scaffold.dart` (`_showScannerOptions` ~91-230: thêm 2 lựa chọn; gắn banner phía trên thanh tab), `mobile-app/lib/l10n/app_en.arb`, `app_vi.arb`
- Test: `mobile-app/test/screens/receipt_scanner/pending_receipts_screen_test.dart`, `mobile-app/test/screens/main_scaffold_test.dart`

**Interfaces:**
- Consumes: mọi thứ ở Task 3 và Task 4; `ReviewFormPage(imagePath:, initialScan:, onOpenTransaction:)` (Task 2).
- Sheet quét gồm:
  - "Quét 1 hóa đơn" / "Chọn 1 ảnh": luồng cũ, giữ nguyên.
  - **"Quét nhiều hóa đơn"**: `DocumentScanner` với `pageLimit: ReceiptScanQueue.maxBatch`.
  - **"Chọn nhiều ảnh"**: `ImagePicker().pickMultiImage(limit: ReceiptScanQueue.maxBatch)`.

  Sau khi chọn hoặc chụp xong: gọi `enqueue`, rồi toast "Đã thêm n hóa đơn vào hàng chờ". Nếu có ảnh bị bỏ, toast thêm "… (bỏ k ảnh vì quá 20)".
- `ScanQueueBanner` (lắng nghe `progress`):
  - `isReading` → "Đang đọc hóa đơn {done}/{total}" + `LinearProgressIndicator`.
  - Không đọc nhưng `ready > 0` → "{ready} hóa đơn chờ xác nhận".
  - Bấm vào banner → mở `PendingReceiptsScreen`. Không có gì thì banner ẩn hẳn (`SizedBox.shrink`).
- `PendingReceiptsScreen`:
  - Mỗi dòng gồm ảnh thu nhỏ, tên cửa hàng, số tiền (`formatVND`), ngày, và chip trạng thái (Đang chờ / Đang đọc / Sẵn sàng / Lỗi).
  - Mục `ready`: bấm vào mở `ReviewFormPage(initialScan: item.result)`; form trả về `true` thì gọi `markConfirmed(item.id)`. Có nút "Bỏ", xác nhận qua `AppDialog.confirm` rồi gọi `remove`.
  - Mục `failed`: nút "Đọc lại" gọi `retry`; lý do lỗi lấy từ ARB theo mã `network`/`server`/`missing_image`.
  - Nút dưới cùng "Xác nhận tất cả hợp lệ ({count})": tắt khi count = 0. Bấm thì hỏi `AppDialog.confirm`, gọi `confirmAllValid`, rồi toast "Đã lưu {saved}, trùng {duplicates}, chưa lưu {notSaved}".
  - Danh sách tải lại mỗi khi `progress` đổi.
- Key ARB mới, có cả vi và en:
  - sheet quét: `scanBatchCamera`, `scanBatchGallery`, `scanQueueAdded`, `scanQueueOverLimit`
  - banner: `scanQueueReading`, `scanQueueReady`
  - màn chờ xác nhận:
    - `pendingReceiptsTitle`, `pendingReceiptsEmpty`
    - `pendingStatusQueued`, `pendingStatusReading`, `pendingStatusReady`, `pendingStatusFailed`
    - `pendingRetry`, `pendingDiscard`, `pendingDiscardConfirm`
    - `pendingConfirmAll`, `pendingConfirmAllAsk`, `pendingConfirmAllResult`
    - `pendingErrorNetwork`, `pendingErrorServer`, `pendingErrorMissingImage`

- [ ] **Step 1: Write the failing tests:**
  - `pending_receipts_screen_test.dart`:
    - Mỗi trạng thái hiện đúng chip.
    - "Đọc lại" gọi retry.
    - "Bỏ" có hỏi trước khi xóa.
    - Bấm mục `ready` mở form và không gửi request `/donut/scan`; lưu thành công thì mục biến mất khỏi danh sách.
    - "Xác nhận tất cả hợp lệ" tắt khi count = 0; khi bật thì bấm vào hiện đúng toast tóm tắt.
    - Không có overflow ở 320 dp, cả vi lẫn en.
  - `main_scaffold_test.dart`:
    - Sheet có 2 lựa chọn mới.
    - Banner ẩn khi hàng đợi trống; hiện "Đang đọc hóa đơn 1/3" khi `progress` đang đọc; bấm banner mở màn Chờ xác nhận.
    - Chuyển tab không làm mất banner.
- [ ] **Step 2: Run** (👤) → FAIL. **Step 3: Implement.** Chạy `flutter gen-l10n`. **Step 4: Run** (👤) `flutter test` toàn bộ → PASS.
- [ ] **Step 5: Commit** – `feat(mobile): batch scan options, reading banner and pending receipts screen (T11)`
- [ ] **Step 6: Thử trên máy** (👤): chọn 5 ảnh rồi chuyển sang tab Thống kê. Banner phải chạy từ 1/5 đến 5/5. Bấm "Xác nhận tất cả hợp lệ" rồi kiểm số dư. Tắt app giữa chừng, mở lại thì app phải đọc tiếp.

## Thứ tự chạy

- **Task 1** (ai-service) chạy song song được với **Task 2**, vì hai task không đụng chung file.
- Sau đó chạy **Task 3 → Task 4 → Task 5**. Ba task này nối tiếp nhau và cùng sửa `receipt_scan_queue.dart` / `main_scaffold.dart`.
- Mỗi task xong thì 👤 chạy test rồi báo "ok", Claude commit, sau đó mới sang task tiếp theo.
