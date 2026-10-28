# Bảng dữ kiện: phân tích chi tiêu và phân khúc RFM

> Nguồn số liệu DUY NHẤT cho các đoạn viết lại về phân tích chi tiêu / RFM (đợt 5). Mỗi dòng có `file:line` tại HEAD `6a009f9` (nhánh `fix/ai-analysis`). Hằng số chép đúng như trong code. Đường dẫn tính từ gốc repo; `ai-service/` viết tắt `AI/`, `core-backend/src/main/java/vn/edu/huit/finance/core/` viết tắt `CB/`, `mobile-app/lib/` viết tắt `MB/`.
> Ngày lập: 2026-10-28. Chỉ đọc code, không chạy test (số test lấy từ lần chạy xanh đã báo: 209 passed).

## 1. Hợp đồng ba endpoint của ai-service

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| `POST /spade/analyze` request | `transactions` (danh sách tối đa `MAX_TRANSACTIONS` = 5000), `top_n` (mặc định `DEFAULT_TOP_N` = 10, 1..50), `min_sup_factor` (mặc định `DEFAULT_MIN_SUP` = 0.25, 0 < x ≤ 1) | `AI/ai_service.py:171-175`, `AI/spending_analysis.py:28`, `AI/wcm_spade.py:41` |
| Một giao dịch gửi lên | `category` (cắt khoảng trắng, 1..`MAX_CATEGORY_LENGTH` = 255 ký tự), `amount` (0 ≤ x ≤ `MAX_AMOUNT` = 1e12, mặc định 0.0), `date` (chuỗi ≤ `MAX_DATE_LENGTH` = 40 ký tự), `isExpense` (mặc định true) | `AI/spending_data.py:17-20`, `AI/spending_data.py:27-32` |
| Trường thừa trong request (alpha, beta, max_gap_days của APK cũ) | Bị Pydantic bỏ qua, vẫn trả 200 | `AI/ai_service.py:172`, `AI/test_main.py:295-298` |
| `/spade/analyze` response (camelCase) | `status`, `patterns`, `rules`, `habits`, `categories`, `meta` | `AI/spending_analysis.py:105-111`, `AI/spending_analysis.py:35-36` |
| `status` | `OK` hoặc `INSUFFICIENT_DATA` (khi số tuần có chi tiêu < `MIN_WEEKS_WITH_DATA`) | `AI/spending_analysis.py:39-41`, `AI/spending_analysis.py:203-204` |
| Khi `INSUFFICIENT_DATA` | `patterns` và `rules` rỗng, `habits` và `categories` vẫn được tính; `raw_support_bound` = 0 và `max_weight` = 0 | `AI/spending_analysis.py:157-166`, `AI/spending_analysis.py:164-165` |
| Trường của `patterns[]` | `itemsets` (danh sách các itemset), `support` (số tuần, thô), `weight`, `weightedSupport`, `weeks` (nhãn tuần ISO) và ba trường cũ `pattern`, `count`, `wsupport` chỉ cho APK trước đợt 3 | `AI/spending_analysis.py:44-56`, `AI/spending_analysis.py:59-65` |
| Trường của `rules[]` | `antecedent`, `consequent`, `support`, `antecedentSupport`, `confidence`, `laplaceConfidence`, `lift`, `weeks` | `AI/spending_analysis.py:68-76` |
| Trường của `habits[]` | `category`, `occurrences`, `meanGapDays`, `stdGapDays`, `lastDate`, `nextExpectedDate` | `AI/spending_analysis.py:79-85` |
| Trường của `categories[]` | `category`, `total`, `share` (tỷ trọng 0..1), `weeks` (số tuần ISO có danh mục đó); sắp theo tổng giảm dần rồi tên | `AI/spending_analysis.py:88-92`, `AI/spending_analysis.py:118-134` |
| Trường của `meta` | `algorithm` ("WCM-SPADE"), `weeksWithData`, `minWeeks`, `windowWeeks`, `minSupport`, `rawSupportBound`, `maxWeight` | `AI/spending_analysis.py:95-102`, `AI/spending_analysis.py:30`, `AI/spending_analysis.py:209-216` |
| Làm tròn | Số thực 4 chữ số (`FLOAT_DIGITS` = 4); `meanGapDays`, `stdGapDays` 1 chữ số (`GAP_DIGITS` = 1) | `AI/spending_analysis.py:31-32`, `AI/spending_analysis.py:142-143` |
| Số kết quả | `patterns`, `rules`, `habits` đều cắt ở `top_n` | `AI/spending_analysis.py:160`, `AI/spending_analysis.py:182`, `AI/spending_analysis.py:195` |
| `POST /spade/recommend` request | `transactions` (≤ 5000), `target` ≥ 0, `current` ≥ 0 (mặc định 0), `months_left` (tùy chọn, 1..600), `monthly_income` (tùy chọn), `needed_monthly` (tùy chọn); các số ≤ `MAX_AMOUNT` | `AI/ai_service.py:177-184` |
| `/spade/recommend` lỗi nghiệp vụ | HTTP 422, `detail` là câu cố định (`NO_EXPENSE_MESSAGE` hoặc `NOT_ENOUGH_HISTORY_MESSAGE`) | `AI/ai_service.py:195-208`, `AI/budget_advisor.py:25-26` |
| `POST /admin/segment` request | `users` (tối đa `MAX_RFM_USERS` = 100_000); mỗi user: `user_id` (chuỗi 1..20 chữ số, regex `^\d+$`), `recency` (0..36500), `frequency` (0..10_000_000), `monetary` (0..1e15) | `AI/ai_service.py:214-225` |
| `/admin/segment` response | `{"segments": [{"user_id", "label", "rfm"}]}`, giữ thứ tự input; `rfm` là chuỗi 3 chữ số, "000" cho LOST | `AI/ai_service.py:228-239`, `AI/rfm_segmentation.py:27`, `AI/rfm_segmentation.py:93-107` |
| Mã lỗi của ba endpoint này | Chỉ có 422 (Pydantic từ chối: quá 5000 giao dịch, `top_n` ngoài 1..50, `min_sup_factor` ngoài (0,1], category 256 ký tự, amount âm, user_id không phải số...). KHÔNG có mã 413 ở `/spade/*` và `/admin/segment`; 413 chỉ thuộc `/donut/scan` (ảnh quá lớn). | `AI/test_main.py:301-306`, `AI/test_main.py:411-418`, `AI/ai_service.py:116-141` |
| Endpoint phân tích chạy đồng bộ (`def`, không `async`) vì CPU-bound, nên chạy trong threadpool | | `AI/ai_service.py:187-192` |

## 2. Dựng chuỗi tuần từ giao dịch

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Hằng số | `SAVINGS_CATEGORY` = "Tiết kiệm"; `WINDOW_WEEKS` = 26; `MIN_WEEKS_WITH_DATA` = 8; `FUTURE_TOLERANCE_DAYS` = 1; `MAX_TRANSACTIONS` = 5000; `MAX_CATEGORY_LENGTH` = 255; `MAX_AMOUNT` = 1e12 | `AI/spending_data.py:16-24` |
| Chỉ khoản chi được dùng | Bỏ khoản thu (`isExpense` false), bỏ khoản "Tiết kiệm", bỏ ngày không đọc được | `AI/spending_data.py:56-67` |
| Loại tiết kiệm so sánh sau chuẩn hóa NFC và cắt khoảng trắng | `_nfc(category) == _nfc(SAVINGS_CATEGORY)` | `AI/spending_data.py:48-53` |
| Tên danh mục lưu dạng NFC | `Expense(day, _nfc(tx.category), amount)` | `AI/spending_data.py:65` |
| Múi giờ | Cố định UTC+7 (`LOCAL_TZ`), không dùng tzdata; ngày có múi giờ đổi sang UTC+7, ngày không múi giờ coi là đã địa phương; đầu vào hỏng cho `None`, không ném lỗi | `AI/local_time.py:1-4`, `AI/local_time.py:11`, `AI/local_time.py:18-35` |
| Nhãn tuần | ISO: `f"{year}-W{week:02d}"` từ `date.isocalendar()` (vd. 2026-W31) | `AI/spending_data.py:83-85` |
| Bỏ chi tiêu ở tương lai | Khoản có ngày > hôm nay (giờ địa phương) + `FUTURE_TOLERANCE_DAYS` (1 ngày) bị bỏ trước, nên ngày gõ nhầm không neo được cửa sổ | `AI/spending_data.py:103-104`, `AI/spending_data.py:114-115` |
| Cửa sổ | Từ thứ Hai của tuần chứa khoản chi muộn nhất còn lại, lùi `WINDOW_WEEKS - 1` = 25 tuần, đến khoản chi muộn nhất. Neo vào dữ liệu, không neo vào đồng hồ máy chủ | `AI/spending_data.py:105-106`, `AI/spending_data.py:118-122` |
| Một chuỗi = một tuần ISO có ít nhất một khoản chi; mỗi ngày là một itemset đã sắp và khử trùng; tuần trống không bao giờ thành chuỗi (N đếm tuần có ghi chép) | | `AI/spending_data.py:107-112`, `AI/spending_data.py:125-135` |
| `spending_totals` | Tổng tiền theo danh mục trong cửa sổ (dùng tính trọng số) | `AI/spending_data.py:126-129` |

## 3. WCM-SPADE

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Tên gọi/thành phần | CM-SPADE (SPADE id-list dọc + CMAP) + weighted support kiểu WSpan + lọc mẫu đóng sau khai phá + luật tuần tự | `AI/wcm_spade.py:1-15` |
| Hằng số | `DEFAULT_MIN_SUP` = 0.25; `DEFAULT_MAX_PATTERN_LENGTH` = 4 (tính theo số item, không theo số itemset); `DEFAULT_MAX_PATTERNS` = 50_000; `FLOAT_TOLERANCE` = 1e-9; `NEUTRAL_WEIGHT` = 1.0; `MIN_RAW_BOUND` = 1 | `AI/wcm_spade.py:41-49` |
| Trọng số item | `w(i) = m · total(i) / Σ total` (m = số item có mặt), tức tỷ trọng chi tiêu chia tỷ trọng trung bình, nên trung bình trọng số = 1; Σ = 0 thì mọi w = 1 | `AI/wcm_spade.py:21-22`, `AI/wcm_spade.py:85-95` |
| Trọng số mẫu | Trung bình trọng số các item của mẫu | `AI/wcm_spade.py:221-223` |
| Weighted support | `wsup = raw_sup · weight / N` (N = số chuỗi/tuần) | `AI/wcm_spade.py:233` |
| Ngưỡng | `min_wsup = min_sup · N`; `max_weight = max w`; `raw_bound = max(MIN_RAW_BOUND, ⌈min_wsup / max_weight − FLOAT_TOLERANCE⌉)` | `AI/wcm_spade.py:291-295` |
| Tỉa | Chỉ item có support thô ≥ `raw_bound` mới vào DFS; mọi mẫu mở rộng cũng phải đạt `raw_bound` (cận trên `support × maxW`) | `AI/wcm_spade.py:301-305`, `AI/wcm_spade.py:263`, `AI/wcm_spade.py:276` |
| Mẫu hiển thị | Mẫu có `raw_sup · weight ≥ min_wsup − FLOAT_TOLERANCE`, rồi lọc đóng, rồi xếp (−wsup, −raw_sup, itemsets) | `AI/wcm_spade.py:317-322` |
| CMAP | Hai bảng: `cmap_s[a][b]` = số chuỗi có a đứng trước hẳn b (kể cả a == b); `cmap_i[a][b]` = số chuỗi có a, b chung itemset; ứng viên chỉ được nối khi giá trị ≥ `raw_bound` (ngưỡng thô, không phải ngưỡng có trọng số) | `AI/wcm_spade.py:167-189`, `AI/wcm_spade.py:246-249` |
| Phép nối id-list | S-extension (sau, `e > min_p` của lần đầu), I-extension (cùng itemset, `y > last`) | `AI/wcm_spade.py:193-217`, `AI/wcm_spade.py:256-280` |
| Lọc mẫu đóng | Bỏ P khi có Q ≠ P cùng support thô mà P là mẫu con của Q (hậu lọc, không phải thuật toán BIDE); chỉ so trong tập đã đạt weighted support | `AI/wcm_spade.py:10-12`, `AI/wcm_spade.py:98-125`, `AI/wcm_spade.py:317-321` |
| `truncated` | True khi `max_patterns` cắt DFS lúc còn mẫu đạt `raw_bound`; ghi `logger.warning` | `AI/wcm_spade.py:78-79`, `AI/wcm_spade.py:238-244`, `AI/wcm_spade.py:314-315` |
| Mẫu đưa ra API | Chỉ mẫu có ≥ `MIN_PATTERN_ITEMS` = 2 item, xếp lại ổn định theo `-wsup`, lấy `top_n` | `AI/spending_analysis.py:29`, `AI/spending_analysis.py:171-183` |
| Chia tuần là xấp xỉ | Lấy cảm hứng từ khai phá episode theo cửa sổ (Mannila 1997), không phải cài đặt WINEPI | `AI/wcm_spade.py:17-19` |
| Chuỗi tối thiểu | Chỉ khai phá khi `weeks_with_data ≥ MIN_WEEKS_WITH_DATA` (8) | `AI/spending_analysis.py:166`, `AI/spending_data.py:22` |

## 4. Luật tuần tự A ⇒ B

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Hằng số | `MIN_ANTECEDENT_SUPPORT` = 4; `MIN_LAPLACE_CONFIDENCE` = 0.6; `MIN_LIFT` = 1.2; `RULE_MIN_SUPPORT` = 3 | `AI/wcm_spade.py:52-54`, `AI/wcm_spade.py:343` |
| Ý nghĩa luật | "Tuần có A thì sau đó (cùng tuần) có B"; A, B là itemset cùng ngày, A ∩ B = ∅; mọi support đếm theo số tuần | `AI/wcm_spade.py:346-356`, `AI/wcm_spade.py:413` |
| sup(A) | Số tuần có A trong cùng một ngày | `AI/wcm_spade.py:419` |
| sup(B) | Số tuần có B ở bất kỳ đâu trong tuần | `AI/wcm_spade.py:419`, `AI/wcm_spade.py:468-469` |
| sup(A ⇒ B) | Số tuần có B ở một ngày SAU lần đầu A trong tuần đó | `AI/wcm_spade.py:420`, `AI/wcm_spade.py:193-204` |
| confidence | `support / antecedent_support` | `AI/wcm_spade.py:358-360` |
| Laplace | `(support + 1) / (antecedent_support + 2)` | `AI/wcm_spade.py:362-364` |
| lift | `confidence / (consequent_support / n_sequences)`; mức nền là tỷ lệ tuần có B ở bất kỳ đâu, nên lift là ước lượng bảo thủ | `AI/wcm_spade.py:366-368`, `AI/wcm_spade.py:439-440` |
| Nguồn id-list của luật | Đếm lại từ `result.item_idlists` (id-list thô mọi item), KHÔNG từ `explored`, nên KHÔNG phụ thuộc trọng số hay `raw_bound` (danh mục chi lớn không liên quan không làm mất luật). Khai phá/xếp hạng mẫu vẫn có trọng số; chỉ luật không trọng số | `AI/wcm_spade.py:415-418`, `AI/wcm_spade.py:428-429`, `AI/wcm_spade.py:449-451` |
| Ứng viên | Itemset cùng ngày có support thô ≥ `RULE_MIN_SUPPORT` (3), kích thước tối đa `max_pattern_length − 1` = 3 item; \|A\| + \|B\| ≤ `max_pattern_length` (4) | `AI/wcm_spade.py:371-393`, `AI/wcm_spade.py:449-451`, `AI/wcm_spade.py:457-458` |
| Lý do `RULE_MIN_SUPPORT` = 3 | k nhỏ nhất qua Laplace (k+1)/(sup(A)+2) ≥ 0,6 khi sup(A) = 4 | `AI/wcm_spade.py:341-343` |
| Điều kiện giữ luật | sup(A) ≥ 4 và support luật ≥ 3 và Laplace ≥ 0.6 và lift ≥ 1.2 (so với dung sai 1e-9) | `AI/wcm_spade.py:454-455`, `AI/wcm_spade.py:462-463`, `AI/wcm_spade.py:473-477` |
| Loại luật bị trội | Bỏ A ⇒ B khi có A' ⇒ B với A' ⊊ A và Laplace(A' ⇒ B) ≥ Laplace(A ⇒ B). Lưu ý: code so với mọi ứng viên đã qua ngưỡng, không chỉ với luật được giữ (docstring nói "được giữ") | `AI/wcm_spade.py:396-404`, `AI/wcm_spade.py:478` |
| Thứ tự | (−Laplace, −lift, −support, A, B); API lấy `top_n` | `AI/wcm_spade.py:479-481`, `AI/spending_analysis.py:195` |
| Ý nghĩa thống kê | Không kiểm định; docstring ghi lift/Laplace không thay được kiểm định (Fisher/binomial + Holm hoặc holdout, Webb 2007); kết quả chỉ mô tả lịch sử chi tiêu | `AI/wcm_spade.py:441-445` |
| Các ngưỡng 4 / 0,6 / 1,2, `RULE_MIN_SUPPORT` và luật bỏ luật bị trội là lựa chọn thiết kế của dự án, không phải giá trị trong tài liệu | | `AI/wcm_spade.py:436-438` |
| confidence thô | Có tính và trả về (`confidence`), nhưng KHÔNG dùng làm ngưỡng lọc; ngưỡng chính là Laplace và lift | `AI/wcm_spade.py:473-477`, `AI/spending_analysis.py:190` |
| Ví dụ cấy mẫu (test) | 26 tuần: A ở 16 tuần, B ở 15 tuần, 12 tuần có B sau A. Kết quả: support 12, sup(A) 16, sup(B) 15, N = 26; confidence 0,75; Laplace 13/18 ≈ 0,7222; lift 0,75/(15/26) = 1,3; `raw_bound` = 7 (min_wsup = 6,5, trọng số bằng nhau) | `AI/test_spade_rules.py:3-5`, `AI/test_spade_rules.py:94-99`, `AI/test_spade_rules.py:102-108` |
| Ví dụ cặp độc lập (test) | C ở 16 tuần, D ở 13/26 tuần, 8 tuần có D sau C: confidence 0,5 = P(D), lift 1,0 (Laplace 9/18 = 0,5): bị loại (mẫu C→D vẫn được khai phá với `raw_sup` = 8) | `AI/test_spade_rules.py:6-8`, `AI/test_spade_rules.py:111-119` |

## 5. Thói quen định kỳ

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Hằng số | `MIN_OCCURRENCES` = 3; `MAX_GAP_CV` = 0.5 (lựa chọn thiết kế của dự án, không phải giá trị công bố) | `AI/spending_habits.py:28-30`, `AI/spending_habits.py:14-17` |
| Số lần = số ngày mua khác nhau của danh mục; khoảng cách tính bằng ngày giữa các ngày liên tiếp | | `AI/spending_habits.py:46-56` |
| Điều kiện | `len(days) ≥ max(min_occurrences, 2)`; thống kê `mean` và độ lệch chuẩn tổng thể (`statistics.pstdev`); bỏ nếu `std / mean > MAX_GAP_CV` | `AI/spending_habits.py:57-64` |
| Ngày kế tiếp | `last_date + round(mean_gap)` ngày (làm tròn của Python), tên trường `nextExpectedDate`; diễn đạt trong ứng dụng là "khoảng" | `AI/spending_habits.py:71`, `MB/l10n/app_vi.arb:515` |
| Thứ tự | (std/mean tăng dần, −occurrences, category): đều đặn nhất đứng đầu; API lấy `top_n` | `AI/spending_habits.py:46`, `AI/spending_habits.py:73`, `AI/spending_analysis.py:147` |
| Tính trên toàn bộ khoản chi trong cửa sổ 26 tuần (không cần `weeks_with_data ≥ 8`) | | `AI/spending_analysis.py:157-160` |
| KHÔNG dự báo | Chỉ mô tả khoảng cách đã xảy ra; không có mô hình dự báo | `AI/spending_habits.py:1`, `docs/superpowers/plans/2026-10-28-dot3-ai.md` (D4) |

## 6. Gợi ý ngân sách (budget advisor)

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Không dùng khai phá mẫu | Chỉ tính trên tháng dương lịch | `AI/budget_advisor.py:1` |
| 10 danh mục thiết yếu | Ăn uống, Siêu thị & Chợ, Di chuyển, Nhà ở, Điện nước, Internet & Điện thoại, Sức khỏe, Giáo dục, Gia đình & Con cái, Bảo hiểm | `AI/budget_advisor.py:13-16` |
| 4 danh mục tùy ý | Mua sắm, Giải trí, Du lịch, Hiếu hỉ; còn lại (kể cả "Khác" và danh mục tự tạo) là trung tính | `AI/budget_advisor.py:17`, `AI/budget_advisor.py:34-40` |
| Hằng số | `MAX_CUT_RATIO` = 0.30; `ESSENTIAL_CUT_RATIO` = 0.10; `LIGHT_CUT_RATIO` = 0.10; `DISCRETIONARY_SHARE_ALERT` = 15 (%); `ADVICE_MAX_MONTHS` = 6 | `AI/budget_advisor.py:19-23` |
| Tháng trọn vẹn | Bỏ tháng hiện tại; tháng đầu chỉ tính khi ngày đầu tiên của dữ liệu là ngày 1; giữ tối đa 6 tháng gần nhất. Ngày đầu dữ liệu = ngày sớm nhất trong cả khoản chi lẫn khoản thu | `AI/budget_advisor.py:43-55`, `AI/budget_advisor.py:77-78` |
| 422 khi thiếu | Không có khoản chi nào: `NO_EXPENSE_MESSAGE` = "Không có giao dịch chi để phân tích."; không có tháng trọn vẹn hoặc không có chi trong đó: `NOT_ENOUGH_HISTORY_MESSAGE` = "Cần ít nhất một tháng chi tiêu trọn vẹn để AI đưa ra lời khuyên." | `AI/budget_advisor.py:25-26`, `AI/budget_advisor.py:74-82` |
| Trung bình tháng | `tag_monthly = tag_total / n_months`; `share = monthly / tổng × 100` (làm tròn 1 chữ số); thu nhập trung bình = tổng thu trong các tháng đó / n_months (hoặc `monthly_income` truyền vào) | `AI/budget_advisor.py:85-100`, `AI/budget_advisor.py:110-112` |
| Số cần góp mỗi tháng | `needed_monthly` truyền vào, hoặc `max(target − current, 0) / months_left` khi `months_left > 0`; không có hạn thì 0 và có tiền tố `NO_DEADLINE_PREFIX` | `AI/budget_advisor.py:27`, `AI/budget_advisor.py:102-109`, `AI/budget_advisor.py:118` |
| Thặng dư/thiếu hụt | `surplus = monthly_income − total_monthly_exp`; `gap = needed_monthly − surplus` | `AI/budget_advisor.py:113-114` |
| `gap ≤ 0` | Đúng hướng; chỉ gợi ý "giảm nhẹ" (cắt `LIGHT_CUT_RATIO` = 10%) các mục tùy ý có tỷ trọng ≥ 15% | `AI/budget_advisor.py:120-131` |
| `gap > 0` | Duyệt ba nhóm theo thứ tự tùy ý → trung tính → thiết yếu; trần cắt 30% mỗi mục (thiết yếu 10%); `want = remaining_gap × (monthlyAvg / tổng nhóm)`; `cut = round(min(monthlyAvg × trần, want))`; dừng khi hết gap | `AI/budget_advisor.py:132-153` |
| Còn thiếu sau khi cắt | Câu tóm tắt nói còn thiếu và gợi ý tăng thu nhập hoặc giãn hạn | `AI/budget_advisor.py:155-159` |
| Đầu ra | `tagStats`, `goal` (`neededMonthly`, `monthlyIncome`, `monthlyExpense`, `surplus`, `gap`, `hasDeadline`), `recommendations`, `summary`, `meta` (`nMonths`, `firstMonth`, `lastMonth`) | `AI/budget_advisor.py:164-181` |
| Lưu ý "7 tháng" | Advisor giữ tối đa 6 tháng trọn vẹn (`ADVICE_MAX_MONTHS`); di động gửi lịch sử 7 tháng lịch (`adviceMonths` = 7) để phân biệt tháng đầu thiếu với tháng đầy đủ | `AI/budget_advisor.py:23`, `MB/core/utils/spending_history.dart:8-9` |

## 7. RFM

### 7.1 ai-service

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Ngũ phân vị | `QUINTILES` = 5; điểm = `min(5, 1 + floor(5 · (less + 0,5 · equal) / n))` (thứ hạng phần trăm trung điểm; giá trị bằng nhau chung điểm); một user hoặc mọi giá trị bằng nhau → điểm 3 | `AI/rfm_segmentation.py:23`, `AI/rfm_segmentation.py:55-71` |
| Recency chấm ngược | `quintile_scores(recency, higher_is_better=False)` (ít ngày hơn = điểm cao); F và M chấm thuận | `AI/rfm_segmentation.py:96-98` |
| Hằng điểm | `HIGH_SCORE` = 4; `MID_SCORE` = 3; `LOW_SCORE` = 2; `LOST_RFM_CODE` = "000" | `AI/rfm_segmentation.py:24-27` |
| LOST ngoài ngũ phân vị | User có `frequency ≤ 0` là LOST, rfm "000", không tham gia chấm điểm (để khỏi kéo lệch điểm người còn lại) | `AI/rfm_segmentation.py:13-14`, `AI/rfm_segmentation.py:95`, `AI/rfm_segmentation.py:103-105` |
| 7 nhóm | CHAMPIONS, LOYAL, NEW, NEED_ATTENTION, AT_RISK, HIBERNATING, LOST | `AI/rfm_segmentation.py:30-37` |
| Luật theo thứ tự ưu tiên, luật khớp đầu tiên thắng | (0) frequency = 0 → LOST; (1) R ≥ 4 và F ≥ 4 và M ≥ 4 → CHAMPIONS; (2) R ≥ 4 và F ≤ 2 → NEW; (3) R ≥ 3 và F ≥ 3 → LOYAL; (4) R ≤ 2 và F ≥ 3 → AT_RISK; (5) R ≤ 2 → HIBERNATING; (6) còn lại → NEED_ATTENTION | `AI/rfm_segmentation.py:74-90` |
| Monetary chỉ ảnh hưởng CHAMPIONS | Lựa chọn thiết kế; các nhóm khác chỉ xét R và F | `AI/rfm_segmentation.py:77-78` |
| Mã rfm | `f"{r}{f}{m}"` | `AI/rfm_segmentation.py:107` |
| Trạng thái nguồn | Luật ánh xạ điểm sang nhóm là lựa chọn thiết kế của dự án; tên nhóm rút gọn từ bảng phổ biến trong ngành (nguồn không bình duyệt) | `AI/rfm_segmentation.py:8-11` |

### 7.2 Core Backend

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Hằng số | `RFM_WINDOW_MONTHS` = 12; `NO_ACTIVITY_DAYS` = 366 | `CB/Service/CustomerSegmentationService.java:33-34` |
| Truy vấn RFM | Chỉ khoản chi (`is_expense = TRUE`), từ `now − 12 tháng`, bỏ danh mục "Tiết kiệm" (`SavingsContributions.CATEGORY_NAME`); LEFT JOIN nên user không có giao dịch vẫn có dòng | `CB/Service/CustomerSegmentationService.java:49-50`, `CB/Repository/UserRepository.java:21-34` |
| Recency | Số ngày từ lần chi gần nhất đến `now`; ngày tương lai kẹp về hôm nay (`LEAST`); không có khoản chi nào → `noActivityDays` (366) | `CB/Repository/UserRepository.java:22-24`, `CB/Repository/UserRepository.java:27-28` |
| Frequency / Monetary | `COUNT(t.id)` và `COALESCE(SUM(t.amount), 0)` | `CB/Repository/UserRepository.java:29-30` |
| Gửi AI | `POST {AI_SERVICE_URL}/admin/segment` với `users[] {user_id (chuỗi), recency, frequency, monetary}`; mặc định `http://data-mining-api:8000` | `CB/Service/AiSegmentClient.java:24-34`, `CB/Service/AiSegmentClient.java:41-42`, `CB/Service/AiSegmentClient.java:51-65` |
| Timeout | Kết nối 5 giây (`CONNECT_TIMEOUT`), đọc 60 giây (`READ_TIMEOUT`) | `CB/Service/AiSegmentClient.java:25-26` |
| Lỗi mạng/thiếu "segments"/mục không phải object | Mọi trường hợp thành `AiServiceUnavailableException` với câu cố định "Dịch vụ AI tạm thời không phản hồi, vui lòng thử lại sau." → HTTP 503 | `CB/Service/AiSegmentClient.java:24`, `CB/Service/AiSegmentClient.java:66-69`, `CB/Service/AiSegmentClient.java:71-74`, `CB/Service/AiSegmentClient.java:77-79`, `CB/Exception/GlobalExceptionHandler.java:84-88` |
| Gọi AI NGOÀI transaction | Lời gọi HTTP chạy trước và ngoài mọi giao dịch (không giữ kết nối DB lúc chờ) | `CB/Service/CustomerSegmentationService.java:43-46`, `CB/Service/CustomerSegmentationService.java:56` |
| Từ chối nguyên khối | Câu trả lời có `user_id` null/không phải chữ số/không nằm trong danh sách đã gửi/trùng, hoặc nhãn lạ → ném lỗi, không ghi gì | `CB/Service/CustomerSegmentationService.java:92-105`, `CB/Service/CustomerSegmentationService.java:107-116` |
| Ghi nhãn trong MỘT transaction | `TransactionTemplate`; mỗi nhãn một câu `UPDATE ... WHERE id IN (...)` (`updateAiLabelForUsers`) | `CB/Service/CustomerSegmentationService.java:58-70` |
| Xóa nhãn user không được trả lời | User đã gửi mà AI bỏ sót → `clearAiLabelForUsers` (không giữ nhãn của lần trước); ghi `log.warn` nếu số được gán ≠ số hàng | `CB/Service/CustomerSegmentationService.java:60-68`, `CB/Service/CustomerSegmentationService.java:72-74` |
| Enum hiển thị | CHAMPIONS "Khách hàng tốt nhất", LOYAL "Trung thành", NEW "Khách mới", NEED_ATTENTION "Cần chú ý", AT_RISK "Có nguy cơ rời bỏ", HIBERNATING "Ngủ đông", LOST "Đã rời bỏ"; nhãn cũ như VIP không còn thuộc enum và bị bỏ qua | `CB/Entity/CustomerSegment.java:8-14`, `CB/Entity/CustomerSegment.java:26-29` |
| Đếm theo nhóm cho dashboard | Đủ mọi nhóm theo thứ tự enum, nhóm vắng là 0 | `CB/Service/CustomerSegmentationService.java:78-90` |
| Điểm vào quản trị | `POST /ajax/segmentation/run` (ADMIN) ghi nhật ký kiểm toán `SYSTEM_SEGMENTATION_RUN` sau khi commit | `CB/Controller/AdminController.java:525-535` |

## 8. Ứng dụng di động (tab "Phân tích AI")

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Tiêu đề màn hình | "Phân tích AI" | `MB/l10n/app_vi.arb:463` |
| Thứ tự thẻ khi có dữ liệu | Hôm nay tiêu được bao nhiêu? → Xu hướng chi tiêu → Chi nhiều nhất → Mẹo tiết kiệm → So sánh tuần → biểu đồ thu chi tuần (+ bộ lọc) → Mẫu Chi Tiêu Tuần Tự → Thói quen cần lưu ý → Thói quen định kỳ → quy tắc 50/30/20 → Gợi ý phân bổ tiền | `MB/screens/ai/ai_tab_page.dart:335-423`, `MB/l10n/app_vi.arb:478`, `MB/l10n/app_vi.arb:471-475` |
| Tiêu đề thẻ "Mẫu Chi Tiêu Tuần Tự" (`aiSpadeTitle`); phụ đề "Hành vi chi tiêu tuần tự thường gặp của bạn" | | `MB/l10n/app_vi.arb:494-495` |
| Dòng mẫu | `formatPattern`: các item cùng ngày nối bằng "+", các ngày nối bằng " → "; chi tiết "Có trong {count}/{total} tuần" (`aiSpadeWeeksDetail`; total = `weeksWithData`) | `MB/widgets/dialogs/ai_components.dart:16-17`, `MB/widgets/dialogs/ai_components.dart:23-32`, `MB/widgets/dialogs/ai_components.dart:148-151`, `MB/l10n/app_vi.arb:504` |
| Tiêu đề thẻ luật | "Thói quen cần lưu ý" (`aiGuardTitle`); phụ đề "Những thói quen đã lặp lại qua nhiều tuần trong lịch sử của bạn."; nhãn đầu thẻ "Mẫu lặp lại · Khai phá chuỗi" | `MB/l10n/app_vi.arb:508-510` |
| Dòng luật | "{count}/{total} tuần: sau khi chi {from}, bạn chi tiếp {to} trong cùng tuần."; luật đang kích hoạt: "Tuần này bạn đã chi {from} nhưng chưa chi {to}." | `MB/l10n/app_vi.arb:511-512` |
| Luật hiện tối đa | `maxHabitAlerts` = 3; luật "đang kích hoạt" (tuần hiện tại đã chi đủ danh mục của A và chưa chi B) đứng đầu, giữ thứ tự của server trong từng nhóm | `MB/widgets/dialogs/ai_components.dart:406`, `MB/widgets/dialogs/ai_components.dart:441-466` |
| Thẻ thói quen định kỳ | Tiêu đề "Thói quen định kỳ" (`aiHabitTitle`); phụ đề "Những khoản bạn chi khá đều đặn theo chu kỳ."; tối đa `maxHabits` = 5 | `MB/l10n/app_vi.arb:513-514`, `MB/widgets/dialogs/ai_components.dart:407`, `MB/widgets/dialogs/ai_components.dart:567` |
| Dòng thói quen | "{category}: khoảng {days} ngày/lần, lần tới khoảng {date}"; nếu ngày dự kiến đã qua: "{category}: khoảng {days} ngày/lần, lần gần nhất {last}" | `MB/l10n/app_vi.arb:515-516`, `MB/widgets/dialogs/ai_components.dart:542-543` |
| Thẻ gợi ý ngân sách | Tiêu đề "Gợi ý phân bổ tiền"; phụ đề "Đề xuất cắt/giữ từng mục để đạt mục tiêu tiết kiệm"; dòng "{current} → {suggested} / tháng" | `MB/l10n/app_vi.arb:505-507` |
| Thẻ 50/30/20 | Tiêu đề "Sức khỏe chi tiêu — quy tắc 50/30/20" (không dùng dịch vụ AI) | `MB/l10n/app_vi.arb:517`, `MB/screens/ai/ai_tab_page.dart:411-418` |
| Câu chưa đủ dữ liệu (thẻ mẫu) | Tiêu đề "Chưa đủ dữ liệu" (`aiSpadeNotEnoughTitle`); nội dung: "Mới có {weeks} tuần có chi tiêu; cần ít nhất {minWeeks} tuần để tìm mẫu tuần tự." (`aiSpadeNotEnoughWeeks`); chưa có tuần nào: "Chưa có khoản chi nào trong 26 tuần gần đây." (`aiSpadeNotEnoughNone`); không biết `minWeeks`: "Chưa đủ lịch sử chi tiêu để tìm mẫu tuần tự." (`aiSpadeNotEnoughUnknown`) | `MB/l10n/app_vi.arb:498-501`, `MB/widgets/dialogs/ai_components.dart:182-192` |
| Đủ dữ liệu nhưng không mẫu nào | "Chưa có mẫu nào" / "Chưa có chuỗi chi tiêu nào lặp lại đủ nhiều tuần." | `MB/l10n/app_vi.arb:502-503`, `MB/widgets/dialogs/ai_components.dart:174-181` |
| Lỗi tải | "Không tải được phân tích" / "Kiểm tra kết nối rồi làm mới để thử lại."; hộp thoại lỗi chỉ khi người dùng chủ động làm mới: "Không phân tích được thói quen chi tiêu" | `MB/l10n/app_vi.arb:468`, `MB/l10n/app_vi.arb:496-497`, `MB/screens/ai/ai_tab_page.dart:276-280` |
| Payload phân tích | `POST /spade/analyze` với `{"transactions": [{category, amount, date (ISO-8601), isExpense}]}`; KHÔNG gửi `top_n`, `min_sup_factor` (dùng mặc định server) | `MB/screens/ai/ai_tab_page.dart:250-258`, `MB/services/remote_api_helper.dart:523-531` |
| Khoảng ngày gửi | 26 tuần: từ 00:00 thứ Hai của tuần hôm nay lùi 25 tuần đến hết hôm nay; chỉ khoản chi (không thu, không tiết kiệm: `countsAsSpending`); không phụ thuộc bộ lọc trên màn hình | `MB/core/utils/spending_history.dart:3-6`, `MB/core/utils/spending_history.dart:11-16`, `MB/core/utils/spending_history.dart:22-37`, `MB/screens/ai/ai_tab_page.dart:196-203` |
| Không có chi tiêu thì không gọi AI | `history.isEmpty` → `SpendingAnalysis.empty` | `MB/screens/ai/ai_tab_page.dart:232-241` |
| Payload lời khuyên | `POST /spade/recommend` với `transactions` (thu và chi, trừ khoản góp tiết kiệm, từ ngày 1 của tháng cách đây 7 tháng), `target`, `current` của mục tiêu khẩn cấp nhất, `months_left` (tùy chọn) | `MB/core/utils/spending_history.dart:8-9`, `MB/core/utils/spending_history.dart:39-52`, `MB/screens/ai/ai_tab_page.dart:150-182`, `MB/services/remote_api_helper.dart:536-556` |
| Không có mục tiêu tiết kiệm thì không gọi advisor | `pickUrgentGoal` null → xóa lời khuyên | `MB/screens/ai/ai_tab_page.dart:151-160` |

## 9. Kiểm thử

| Dữ kiện | Giá trị | Bằng chứng |
|---|---|---|
| Số test ai-service | 209 passed (`pytest test_*.py`; con số do người giao việc cung cấp, không chạy lại) | yêu cầu Task 1 |
| Số hàm `def test_` theo file (chưa tính tham số hóa) | `test_wcm_spade.py` 18; `test_spade_rules.py` 18; `test_spending_analysis.py` 7; `test_spending_data.py` 11; `test_spending_habits.py` 7; `test_budget_advisor.py` 11; `test_rfm_segmentation.py` 12; `test_main.py` 26; `test_receipt_postprocess.py` 16 | `AI/test_*.py` (đếm bằng grep) |
| Test dữ liệu cấy | `AI/test_spade_rules.py:1-16` | xem mục 4 |

## 10. Những điều KHÔNG làm

- Không dự báo chi tiêu tương lai: thói quen chỉ mô tả khoảng cách ngày đã xảy ra; "ngày kế tiếp" chỉ là `last_date + round(mean)` và hiển thị là "khoảng" (`AI/spending_habits.py:71`, `MB/l10n/app_vi.arb:515`). Thẻ có tên "Thói quen cần lưu ý", không còn "thói quen tương lai".
- Không dùng confidence thô làm ngưỡng chính: lọc bằng Laplace ≥ 0,6 và lift ≥ 1,2 (`AI/wcm_spade.py:473-477`).
- Không kiểm định ý nghĩa thống kê của luật; kết quả là mô tả lịch sử (`AI/wcm_spade.py:441-445`).
- Không coi tuần trống là "không chi": N là số tuần có ít nhất một khoản chi (`AI/spending_data.py:109-112`).
- Không đưa khoản "Tiết kiệm" vào mọi đầu vào AI (`AI/spending_data.py:60`, `MB/core/utils/spending_history.dart:50`, `CB/Repository/UserRepository.java:33`).
- Không dùng khai phá mẫu trong lời khuyên ngân sách (`AI/budget_advisor.py:1`).
- Không dùng K-Means cho phân khúc: RFM bằng ngũ phân vị và luật ngưỡng, luật là lựa chọn thiết kế của dự án (`AI/rfm_segmentation.py:1`, `AI/rfm_segmentation.py:11`).
- Không cài đặt WINEPI, BIDE hay thuật toán công bố nguyên bản: cắt tuần ISO là xấp xỉ, lọc đóng là hậu lọc (`AI/wcm_spade.py:10-12`, `AI/wcm_spade.py:17-19`).

## 11. Điểm lệch giữa code và kế hoạch đợt 3

| Kế hoạch (dot3) | Code tại HEAD | Bằng chứng |
|---|---|---|
| E3: "Luật chỉ sinh từ mẫu đúng hai itemset [A] → [B]" | Luật sinh từ id-list thô; A và B là itemset cùng ngày có thể nhiều item, \|A\| + \|B\| ≤ 4 (A, B mỗi bên tối đa 3 item); không lấy từ `explored` | `AI/wcm_spade.py:371-393`, `AI/wcm_spade.py:449-460` |
| D7: category ≤ 64 ký tự | `MAX_CATEGORY_LENGTH` = 255 (khớp varchar(255) của backend) | `AI/spending_data.py:18` |
| Yêu cầu Task 1 nhắc mã lỗi "413/422" cho ba endpoint | Ba endpoint chỉ 422; 413 chỉ ở `/donut/scan` | mục 1 |
| Review Focus: xóa "độ dài tối đa 4" | Vẫn đúng với code: `DEFAULT_MAX_PATTERN_LENGTH` = 4 item. Nếu text cũ nói "độ dài tối đa 4" như một giới hạn của khai phá thì thực tế là 4 item tổng cộng cho mẫu và \|A\| + \|B\| của luật, không phải 4 itemset | `AI/wcm_spade.py:42`, `AI/wcm_spade.py:457` |
| Docstring loại luật bị trội: so với luật "được giữ" | Code so với mọi ứng viên đã qua ngưỡng Laplace và lift | `AI/wcm_spade.py:427-428`, `AI/wcm_spade.py:478` |
| Yêu cầu Task 1: advisor dùng "7 tháng" | Advisor giữ ≤ 6 tháng trọn vẹn; 7 là số tháng lịch mà di động gửi | mục 6 |

## 12. Tài liệu tham khảo: đã kiểm / bỏ

Số [n] là số trong `docs/thesis/references.md`. "Crossref" = siêu dữ liệu (tác giả, tiêu đề, nơi xuất bản, trang, năm, DOI) đối chiếu qua `api.crossref.org` ngày 28/10/2026.

| Tài liệu | Trạng thái | Ghi chú |
|---|---|---|
| Zaki 2001 SPADE | Đã có [48] | |
| Fader, Hardie, Lee 2005 RFM and CLV | Đã có [49] | Không dùng làm nguồn cho ngũ phân vị |
| Fournier-Viger et al. 2014, CM-SPADE (PAKDD, LNCS, pp. 40-52) | Đã kiểm, thêm [76] | Crossref. Số tập LNCS không ghi. Dùng cho CMAP và tỉa ứng viên |
| Yun, Leggett 2006, WSpan (IEEE IS 2006, pp. 512-517) | Đã kiểm, thêm [77] | Crossref. Công thức "trọng số mẫu = trung bình trọng số item", cận MaxW chưa đọc trong bài gốc: không gán công thức cho bài, ghi là cách làm của đề tài "kiểu WSpan" |
| Wang, Han 2004, BIDE (ICDE 2004, pp. 79-90) | Đã kiểm, thêm [78] | Crossref; năm 2004 từ ngày hội nghị (Boston, 28/9/2004). Code chỉ dùng "tinh thần mẫu đóng", không phải BIDE |
| Fournier-Viger et al. 2015, TKDE 27(8):2203-2216 | Đã kiểm, thêm [79] | Crossref. Định nghĩa support/confidence nguyên văn chưa đọc: chỉ dẫn cho khái niệm luật tuần tự có confidence |
| Brin, Motwani, Silverstein 1997, "Beyond market baskets: generalizing association rules to correlations" (SIGMOD '97, pp. 265-276) | Đã kiểm, thêm [80] | Crossref + đọc PDF: bài định nghĩa độ "interest" I(r) = O(r)/E[r], > 1 là phụ thuộc dương (tương đương lift). Bài không dùng chữ "lift" |
| Clark, Boswell 1991, CN2 (EWSL-91, LNCS 482, pp. 151-163) | Đã kiểm, thêm [81] | Crossref; tóm tắt nêu ước lượng Laplace cho độ chính xác luật (nguồn thứ cấp). Công thức (k+1)/(n+2) của đề tài là ca hai lớp, là lựa chọn thiết kế |
| Mannila, Toivonen, Verkamo 1997, DMKD 1(3):259-289 | Đã kiểm, thêm [82] | Crossref. Cắt tuần ISO là xấp xỉ lấy cảm hứng, không phải WINEPI |
| Tanbeer et al. 2009, PAKDD, pp. 242-253 | Đã kiểm, thêm [83] | Crossref. Docstring ghi thiếu trang |
| Fournier-Viger et al. 2017, PFPM | Đã kiểm, thêm [84] | Crossref (chương sách InTech 2017, không có số trang). Có bản tạp chí 2019 (AEEE 17(1), DOI 10.15598/aeee.v17i1.3185) với tiêu đề "Discovering Periodic Itemsets Using Novel Periodicity Measures"; bản này dùng tiêu đề của chương 2017 |
| Plaid, Transactions API (recurring) | Đã kiểm, thêm [85] | Đọc trang tài liệu: "A MATURE recurring stream should have at least 3 transactions and happen on a regular cadence (For Annual recurring stream, we will mark it MATURE after 2 instances)". `MIN_OCCURRENCES` = 3 theo quy tắc này; MAX_GAP_CV là lựa chọn của đề tài |
| Webb 2007, "Discovering significant patterns", Machine Learning 68(1):1-33 | Đã kiểm, thêm [86] | Crossref. Chỉ dùng để nói cần kiểm định ý nghĩa; nội dung bài (Fisher, Holm) không đọc lại |
| Agrawal, Srikant 1995, "Mining sequential patterns" (ICDE 1995, pp. 3-14) | Đã kiểm, thêm [87] | Crossref. Dùng cho định nghĩa mẫu tuần tự |
| Hughes 1994, *Strategic Database Marketing*, Probus | Thêm [88] với ghi chú | Có bản ghi thư viện (Probus, 1994) và bài điểm sách nêu sách bàn về phân tích RFM. Việc sách dùng ngũ phân vị CHƯA xác nhận: chỉ có nguồn thực hành thứ cấp mô tả cách chia 20% và mã 555. Văn bản không được viết "theo Hughes, ngũ phân vị"; nên viết ngũ phân vị là cách chấm phổ biến trong thực hành RFM. Không có ISBN/trang kiểm chứng |
| Bult, Wansbeek 1995, Marketing Science 14(4):378-394 | BỎ | Crossref khớp metadata, nhưng chưa xác nhận nội dung bài về RFM/ngũ phân vị nên không có cơ sở trích |
| Bảng segment "Putler" | BỎ | Nguồn thương mại, không bình duyệt, chưa mở được; tên nhóm là lựa chọn của đề tài |
| CN2 công thức Laplace (k+1)/(n+k) | Không gán | Không tìm được nguồn có công thức; chỉ dẫn [81] cho việc dùng ước lượng Laplace |
