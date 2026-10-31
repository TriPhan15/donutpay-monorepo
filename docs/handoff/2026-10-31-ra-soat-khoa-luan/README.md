# Rà soát và sửa khóa luận KLCN175 (viết ngày 2026-10-31, trên `main` sau khi merge `fix/backlog-schema`)

File này dành cho người nhận việc và Claude Code của người đó. Đọc hết file trước khi làm.

## 1. Bối cảnh

- Quyển khóa luận mới nhất là **`KhoaLuan_KLCN175_v10.docx`**. File `.docx` bị git-ignore nên **không có trong repo**: Trí gửi file qua Zalo/Drive. Đặt file ở thư mục gốc repo (cạnh `README.md`). Git sẽ tự bỏ qua file này.
- Đã rà toàn quyển v10 và ghi lỗi vào 4 file trong thư mục này:

| File | Phạm vi | Số dòng lỗi |
|---|---|---|
| `loi_phan_A.md` | Phần đầu, Mở đầu, Chương 1, Chương 5 (phần đã viết), Kết luận, Tài liệu tham khảo | 104 |
| `loi_phan_B.md` | Chương 2 Phân tích hệ thống | 137 |
| `loi_phan_C.md` | Chương 3 Thiết kế hệ thống | 161 |
| `loi_phan_D.md` | Chương 4 Cài đặt hệ thống | 129 |

- Mỗi dòng lỗi có: vị trí (mục + mã đoạn `P<n>` hoặc ô bảng `T<n>.r<dòng>`), loại lỗi, câu trích nguyên văn và đề xuất sửa. Mã `P<n>` là thứ tự đoạn trong `word/document.xml` của v10, lấy bằng `docs/thesis/build/extract_text.py`. Mã này chỉ đúng với v10, sang v11 là lệch.
- Loại lỗi: `CHINH_TA` (chính tả), `AI_VAN` (câu nghe như máy viết), `LUNG_CUNG` (câu lủng củng hoặc quá dài), `DAU_CAU` (nháy thẳng/cong, `;`, `...`/`…`, khoảng trắng), `SO_LIEU` (số quá dài, lẫn `,`/`.`, câu nhồi nhiều số), `NOI_DUNG` (mâu thuẫn, lặp, ghi chú giữ chỗ còn sót).
- Danh sách do máy rà nên **không phải dòng nào cũng đúng**. Khoảng 10% câu trích bị rút gọn bằng `…`, hoặc khác nháy thẳng/cong so với bản gốc. Khi đó tìm theo vài chữ đầu. Dòng nào sai hoặc đề xuất làm câu tệ hơn thì bỏ qua và ghi lý do (mục 5).

## 2. Phạm vi

**Làm:** sửa chính tả, câu văn máy, câu lủng củng, dấu câu, cách viết số; thống nhất thuật ngữ toàn quyển; sửa các mâu thuẫn số liệu đã nêu; cập nhật vài chỗ đã lệch so với code mới (task K6).

**Không làm** (Trí tự làm hoặc quyết định sau, chỉ được sửa chính tả trong các đoạn này):
- 45 ghi chú tô vàng `[Nhóm] …`, phần lớn là "chèn ảnh chụp màn hình". Không xóa, không tự chèn ảnh.
- 14 đoạn `[T7.5]` của Chương 5 (cần kết quả deploy).
- 9 đoạn `[T7.9]`: Lời cảm ơn, Bảng phân công, danh mục chữ viết tắt, Kết luận mục 1-3, danh sách Tài liệu tham khảo (hiện chỉ có một dòng nhắc việc), đánh số lại trích dẫn `[n]`.
- 7 khung ảnh `[T7.1 …]` ở Chương 1.
- Không thêm hoặc bớt mục, hình, bảng. Không đổi ý chính của đoạn. Không bịa số liệu: số nào cũng phải có trong code, `docs/thesis/facts.md`, `docs/thesis/facts_ai.md` hoặc `docs/thesis/v5_results.md`.
- Không sửa code (`mobile-app/`, `core-backend/`, `ai-service/`), `docker-compose*.yml`, `deploy/`, `.env*`, `.github/`. Riêng mục 9 là task code, **chỉ làm khi Trí giao**.

## 3. Cách sửa file docx (bộ công cụ có sẵn trong repo)

Bộ sinh quyển là `docs/thesis/build/builder.py`. Đầu file có hướng dẫn đầy đủ. Mỗi task viết một content module mới, không sửa các file `content_*.py` cũ.

```bash
# 1. Giải nén bản trước (ví dụ v10 -> thư mục tạm)
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" KhoaLuan_KLCN175_v10.docx /tmp/kl_v11

# 2. Áp nội dung sửa
python3 docs/thesis/build/builder.py /tmp/kl_v11 docs/thesis/build/content_v11_phan_a.py

# 3. Đóng gói lại thành bản mới (không ghi đè bản cũ)
python3 - <<'EOF'
import zipfile, pathlib
src = pathlib.Path("/tmp/kl_v11"); out = "KhoaLuan_KLCN175_v11.docx"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(src / "[Content_Types].xml", "[Content_Types].xml")
    for p in sorted(src.rglob("*")):
        if p.is_file() and p.name != "[Content_Types].xml":
            z.write(p, p.relative_to(src).as_posix())
EOF
```

Content module dùng các khóa sau (xem docstring của `builder.py`):
- `SESSION_TAG = None`, `SECTIONS = {}`: bắt buộc. Task sửa lỗi không thay dòng giữ chỗ nào.
- `TEXT_REPLACE = [("chuỗi cũ", "chuỗi mới", số_lần)]`: thay trong từng `<w:t>`. Builder dừng lại nếu số lần xuất hiện không khớp, nên ghi đúng số lần. Một câu bị chia thành nhiều run (có chữ đậm/nghiêng, hoặc Word tách run) sẽ không khớp. Khi đó dùng `PARA_REPLACE`.
- `PARA_REPLACE = [("đầu đoạn cũ", ("p", "toàn bộ đoạn mới"))]`: viết lại cả một đoạn. Dùng `("b1", …)` cho đoạn gạch đầu dòng. Inline `**đậm**`, `*nghiêng*`.
- Không bật `RENUMBER` (task sửa lỗi không đổi số hình/bảng).

Muốn biết một chuỗi nằm trong một hay nhiều run: giải nén rồi `grep -c "chuỗi" /tmp/kl_vN/word/document.xml`. Ra 0 tức là chuỗi bị tách run, hoặc có ký tự `&`, `<`, `"` đã escape.

Chuỗi phiên bản: K1 tạo v11 từ v10, K2 tạo v12 từ v11, v.v. Làm các task theo thứ tự.

## 4. Kiểm tra sau mỗi task ("test" của task khóa luận, bắt buộc)

Một task chỉ xong khi qua đủ các bước sau. Bước nào hỏng thì sửa rồi chạy lại. Sửa một lần vẫn hỏng thì dừng và báo Trí.

```bash
# a) File mở được, không hỏng zip
python3 -c "import zipfile,sys; assert zipfile.ZipFile(sys.argv[1]).testzip() is None; print('zip OK')" KhoaLuan_KLCN175_v11.docx

# b) Trích chữ bản trước và bản mới, so khác biệt
python3 -I docs/thesis/build/extract_text.py KhoaLuan_KLCN175_v10.docx /tmp/v10.txt
python3 -I docs/thesis/build/extract_text.py KhoaLuan_KLCN175_v11.docx /tmp/v11.txt
diff /tmp/v10.txt /tmp/v11.txt | head -n 200
```

- c) Với **mỗi dòng lỗi đã sửa**: câu cũ không còn trong `/tmp/v11.txt` (`grep -c`), câu mới có. Số dòng `[P…]` của heading (`grep -c '|Heading'`) và số caption Hình/Bảng giữ nguyên so với bản trước.
- d) Diff chỉ chứa các đoạn của task. Đoạn nào đổi ngoài dự định thì sửa lại content module.
- e) Nếu máy có LibreOffice: `soffice --headless --convert-to pdf KhoaLuan_KLCN175_v11.docx`, mở PDF xem vài trang có sửa (font, gạch đầu dòng, chữ đậm còn đúng). Không có thì ghi "chưa render" trong PR.
- f) **Rà lại task:** đọc lại các đoạn vừa sửa trong `/tmp/v11.txt` và đối chiếu với file lỗi. Trong lúc đọc mà thấy lỗi nhỏ khác (chính tả, dấu, câu cụt) trong cùng phạm vi thì **sửa luôn** và thêm một dòng "(mới)" vào cuối bảng của file lỗi tương ứng.

## 5. Ghi trạng thái vào file lỗi

Trong `loi_phan_X.md`, thêm vào đầu ô `#` của mỗi dòng đã xử lý:
- `✅` nếu đã sửa (đúng như đề xuất, hoặc sửa khác nhưng hợp lý: ghi thêm "sửa thành: …" vào cuối ô Đề xuất).
- `⏭` nếu bỏ qua, kèm lý do ngắn (đề xuất sai, câu gốc đã ổn, thuộc phạm vi "Không làm"…).

Ví dụ: `| ✅ 12 | Ch.1 › 1.2 (P130) | …` và `| ⏭ 48 | … | … (bỏ qua: câu gốc đúng thuật ngữ UML) |`.

## 6. Git: mỗi task một nhánh, một PR (bắt buộc)

```bash
git checkout main
git pull origin main
git checkout -b docs/thesis-k1-phan-a          # tên nhánh ở bảng mục 7

# ... làm task, chạy kiểm tra mục 4 ...

# Chỉ add đúng file của task. KHÔNG dùng git add -A hay git add .
# docs/thesis/build/ bị .gitignore (**/build/) chặn, nên phải dùng -f cho file .py trong đó
git add -f docs/thesis/build/content_v11_phan_a.py
git add docs/handoff/2026-10-31-ra-soat-khoa-luan/loi_phan_A.md
git commit -m "docs(thesis): proofread front matter, chapter 1 and conclusion (v11)"

# Trước khi push: không được có chữ claude trong commit (phải ra 0)
git log --format='%an %ae %s %b' origin/main..HEAD | grep -ic claude

git push -u origin docs/thesis-k1-phan-a
gh pr create --base main --head docs/thesis-k1-phan-a \
  --title "docs(thesis): proofread part A (v11)" --body-file /tmp/pr_k1.md
```

**Quy tắc git:**
- **KHÔNG** thêm `Co-Authored-By: Claude …`, `Claude-Session`, "Generated with Claude Code" hay bất kỳ chữ "Claude" nào vào commit, PR hoặc comment. Repo đã xóa hết các dòng này. Author của commit là tên và email git của người làm.
- Commit message viết tiếng Anh, dạng `docs(thesis): …` (task code: `fix(mobile): …`, `test(mobile): …`).
- Không commit file `.docx`/`.pdf` (đã bị ignore, đừng `-f`), file ghi chú cá nhân, file tạm, hay các file đang chưa được track trong repo.
- Không push lên `main`, không merge PR, không `--force` lên `main`, không xóa nhánh của người khác. Trí review rồi merge.
- Nếu `main` có commit mới trong lúc làm: `git fetch origin && git rebase origin/main`, chạy lại kiểm tra, rồi `git push --force-with-lease` (chỉ trên nhánh của mình).
- Gửi file docx mới (vN) cho Trí qua Zalo/Drive, và ghi tên file vào PR.

**Mẫu nội dung PR** (`/tmp/pr_kN.md`):

```markdown
## Tóm tắt
Sửa lỗi văn bản phần <...> của khóa luận theo docs/handoff/2026-10-31-ra-soat-khoa-luan/loi_phan_<X>.md. Bản kết quả: KhoaLuan_KLCN175_v<N>.docx (gửi qua Zalo).

## Thống kê
- Đã sửa: <số> dòng, bỏ qua: <số> dòng (lý do ghi trong file lỗi), lỗi mới phát hiện và đã sửa: <số>

## Kiểm tra
- zip OK; diff v<N-1>→v<N> chỉ chứa đoạn của task; số heading và caption giữ nguyên
- Render PDF: <đã xem trang ... / chưa render>

## Cần Trí xem
- <câu đổi nghĩa, chỗ không chắc>
```

## 7. Danh sách task (làm theo thứ tự, mỗi task một nhánh)

| Task | Nhánh | Đầu vào → đầu ra | Nội dung | Content module |
|---|---|---|---|---|
| K1 | `docs/thesis-k1-phan-a` | v10 → v11 | Mọi dòng trong `loi_phan_A.md` thuộc phần được làm (bỏ qua dòng về `[T7.x]`/`[Nhóm]` theo mục 2) | `content_v11_phan_a.py` |
| K2 | `docs/thesis-k2-chuong-2` | v11 → v12 | `loi_phan_B.md`. Riêng 6 đoạn dẫn lặp nguyên văn ở 2.2.2-2.2.7 (xem Tóm tắt của file): rút gọn từng đoạn, giữ tham chiếu Hình | `content_v12_chuong_2.py` |
| K3 | `docs/thesis-k3-chuong-3` | v12 → v13 | `loi_phan_C.md`. File dài, có thể chia hai commit (3.1-3.5 và 3.6-3.9) trên cùng nhánh | `content_v13_chuong_3.py` |
| K4 | `docs/thesis-k4-chuong-4` | v13 → v14 | `loi_phan_D.md`, kèm số liệu ở mục 8 | `content_v14_chuong_4.py` |
| K5 | `docs/thesis-k5-thong-nhat` | v14 → v15 | Thống nhất toàn quyển: thuật ngữ (bảng mục 7.1), nháy cong `“ ”`, `…` thay `...` trong văn xuôi, `Nguồn:` viết hoa ở mọi chú thích nguồn, số thập phân dùng dấu phẩy (0,9350), cùng một chỉ số thì cùng một dạng viết (% hoặc 0,xx), giảm `;` trong văn xuôi (tách câu) | `content_v15_thong_nhat.py` |
| K6 | `docs/thesis-k6-cap-nhat-code` | v15 → v16 | Cập nhật các câu đã lệch so với code sau merge (mục 8). Mỗi câu sửa phải dẫn được file:line trong PR | `content_v16_cap_nhat_code.py` |

### 7.1 Thuật ngữ cần thống nhất (K5; chọn một cách, dùng cả quyển)

Các file lỗi đã nêu những cặp sau: `tỉ lệ`/`tỷ lệ`, `use case`/`ca sử dụng`, `module`/`mô-đun`, `cache`/`bộ nhớ đệm`, `service`/`dịch vụ`, `endpoint`, `server`/`máy chủ`, `framework`, `access token`/`refresh token`, `checkout`, `demo`, `reverse proxy`, tên trường hóa đơn (`SELLER`/`Seller`, `TOTAL_COST`/`Total Cost`), tên màn hình/tab ("Sổ giao dịch"/"Sổ sách"/"Thống kê"), "Gói Hội Viên"/"gói hội viên". Quy tắc: thuật ngữ đã có từ tiếng Việt quen dùng thì dùng tiếng Việt, lần đầu xuất hiện ghi kèm tiếng Anh trong ngoặc. Tên lớp, API, trường dữ liệu trong code giữ nguyên.

## 8. Số liệu và sự thật cần cập nhật (K4, K6; đã kiểm tra trên `main` ngày 31/10)

- **Test:** backend `mvn -B test -Dtest='!CoreBackendApplicationTests'` = **2407 test, 0 lỗi, 1 skip** (bench). AI service `pytest` = **305 passed, 8 skipped**. Quyển hiện ghi "AI Service có 209 test" (P1046) và các con số backend cũ. `ai-service/test_receipt_postprocess.py` hiện có **19** hàm test, trong khi quyển ghi 15 (P1033) và 16 (Bảng 4.10). Đếm lại từng tệp cho Bảng 4.10 bằng `grep -c 'def test_' ai-service/test_*.py`.
- **Thời gian huấn luyện** (`loi_phan_D.md` dòng 27): 5.600 bước × 10-11,3 s ra 15,6-17,6 giờ, không phải "16-17 giờ". Sửa cho khớp, hoặc lấy số thật trong `docs/thesis/v5_results.md`.
- **Code đã đổi sau khi viết v10** (merge `fix/backlog-schema`). Chương 3/4 cần kiểm tra và cập nhật các điểm:
  - `receipts` có cột chủ sở hữu `owner_id` (FK → users), quyền xem/sửa hóa đơn dựa vào cột này (`core-backend/.../Entity/Receipt.java`).
  - `transactions` có cột `source` (`NORMAL` | `GOAL_REFUND`): tiền hoàn khi xóa mục tiêu tiết kiệm không còn tính là thu nhập (`Entity/Transaction.java`, `Entity/TransactionSource.java`).
  - Mỗi hóa đơn được đọc lại tối đa **10 lần**, quá thì trả 409 (`ReceiptProcessingService.MAX_ATTEMPTS_PER_RECEIPT`).
  - Lỗi không lường trước trả **500** kèm câu cố định, không còn trả 400 kèm thông báo thô (`Exception/GlobalExceptionHandler.java`).
  - Mail OTP gửi bất đồng bộ; link ảnh hóa đơn chỉ nhận `https`; tải ảnh giới hạn 15 MB, chỉ JPEG/PNG/WEBP (413 nếu quá cỡ).
  - Admin tạo người dùng phải dùng mật khẩu mạnh như khi đăng ký (`UserCreateDto`). Quyển đang ghi "tối thiểu 6 ký tự" ở UC17 (`loi_phan_B.md`).
  - Hướng dẫn migrate CSDL: `docs/deploy/MIGRATION_RUNBOOK.md`.
  Bảng mô tả bảng CSDL (Bảng 3.x) thì thêm dòng cột mới. Hình ERD **không vẽ lại** ở task này: ghi vào PR mục "Cần Trí xem".

## 9. Task code đã phát hiện (chỉ làm khi Trí giao; mỗi task một nhánh và một PR như mục 6)

Tìm được khi đối chiếu mobile với backend sau merge. Trí có thể tự làm.

| Task | Nhánh | Lỗi | Sửa | Test bắt buộc |
|---|---|---|---|---|
| M1 (lỗi thật) | `fix/mobile-goal-refund-income` | Backend trả `source: "GOAL_REFUND"` cho tiền hoàn khi xóa mục tiêu tiết kiệm. App bỏ qua trường này (`mobile-app/lib/models/transaction_model.dart` `fromJson`) nên thu nhập tháng, thu nhập theo ngày và hạn mức chi hôm nay bị cộng dư (`models/ledger_stats.dart` `_income`, `models/today_allowance.dart`, `screens/dashboard/dashboard_page.dart` thu nhập tháng). Bộ lọc "Thu" cũng liệt kê khoản này (`models/transaction_filter.dart`). | Thêm `source` vào model (mặc định NORMAL, đọc cả JSON cũ), getter kiểu `countsAsIncome`, dùng getter đó ở mọi chỗ tính thu nhập. Hiện nhãn "Hoàn tiền tiết kiệm" (thêm khóa ARB vi/en, chạy `flutter gen-l10n`) | TDD: test model fromJson, test ledger_stats/today_allowance có giao dịch GOAL_REFUND, rồi `flutter analyze` (phải 0 issue) và cả bộ `flutter test` |
| M2 (UX) | `fix/mobile-input-limits` | Backend giới hạn ghi chú/địa điểm 255 ký tự, nhận xét đánh giá 1000 ký tự, số tiền nạp tối đa 1.000.000.000 và tối đa 2 chữ số thập phân. App không chặn trước nên người dùng chỉ thấy lỗi 400 sau khi bấm lưu. Tải ảnh lỗi (400/413/503) bị nuốt im lặng (`services/remote_api_helper.dart` upload trả null), giao dịch được lưu mà mất ảnh, không báo gì. | `maxLength`/`LengthLimitingTextInputFormatter` cho `NoteField` (`screens/ledger/widgets/transaction_form_fields.dart`), tiêu đề ở form quét hóa đơn, `feedback_sheet.dart`. Giới hạn số tiền ở `top_up_sheet.dart`. Làm tròn số tiền trước khi gửi. Báo toast khi tải ảnh lỗi | Widget test cho từng giới hạn, `flutter analyze`, cả bộ `flutter test` |

Quy ước code mobile và cách chạy test: xem `docs/handoff/2026-10-30-receipt-phase2-mobile.md` mục 5 và 6 nếu có file đó, nếu không thì hỏi Trí. Mỗi task code: viết test đỏ trước, sửa cho xanh, chạy test của task **và** cả bộ trước khi push. Gặp lỗi nhỏ liên quan thì sửa luôn và ghi vào PR. Test đỏ mà sửa một lần vẫn đỏ thì dừng và báo Trí.

## 10. Prompt dán vào Claude Code

```text
Đọc toàn bộ docs/handoff/2026-10-31-ra-soat-khoa-luan/README.md rồi làm đúng theo file đó.
1. git checkout main && git pull origin main. Kiểm tra có KhoaLuan_KLCN175_v10.docx ở thư mục gốc repo; không có thì dừng và báo tôi.
2. Đọc docstring đầu docs/thesis/build/builder.py và một content module cũ (content_v10.py) để biết cú pháp.
3. Làm lần lượt K1 → K6 (mục 7). Mỗi task: tạo nhánh riêng từ main mới nhất, viết content module, build ra bản v mới, chạy đủ bước kiểm tra mục 4 (kể cả bước f: rà lại và sửa luôn lỗi nhỏ phát hiện thêm), đánh dấu ✅/⏭ trong file lỗi (mục 5), commit đúng file, kiểm tra không có chữ claude, push, tạo PR theo mẫu mục 6. Không merge.
4. Không thêm Co-Authored-By hay bất kỳ dòng Claude nào vào commit/PR.
5. Không bịa số liệu. Không chắc một câu sửa có đổi nghĩa không thì giữ câu gốc, đánh ⏭ và ghi vào "Cần Trí xem".
6. Một bước kiểm tra hỏng mà sửa một lần vẫn hỏng thì dừng và báo tôi.
7. Sau mỗi task báo ngắn: link PR, tên file docx mới, số dòng sửa/bỏ qua/lỗi mới. Không in nội dung file ra chat.
Mục 9 (task code M1, M2) chỉ làm khi tôi bảo.
```
