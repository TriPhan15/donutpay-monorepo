# Donut V5 – thiết kế lần train mới

## Mục đích

Model Donut đang chạy (`ai-service/Version3/donut_result`) đọc tốt hóa đơn đơn giản nhưng hỏng ở hóa đơn dài, nhiều chữ (ví dụ Circle K). Người dùng train trên Kaggle: upload một notebook + một thư mục dataset rồi bấm chạy. Mục tiêu là bộ "notebook mới + thư mục `Version5`" sao cho upload lên là train ra model V5 **đo được là tốt hơn V3** trên cùng một bộ chấm.

## Hiện trạng (đã kiểm tra 2026-10-17)

- `ai-service/data1/` (13 GB):
  - `train/` 5081 ảnh, `validation/` 635, `test/` 636, mỗi thư mục có `metadata.jsonl` đúng định dạng Donut (`file_name`, `ground_truth` = chuỗi JSON `{"gt_parse": {SELLER, ADDRESS, TIMESTAMP, TOTAL_COST}}`). Đủ ảnh (2 ảnh thiếu người dùng đã bổ sung), không trùng giữa 3 tập. Có 6 `.jpeg`, 1 `.png`, còn lại `.jpg`.
  - Nhãn mới: TOTAL_COST chỉ là số (`"50,000"`, `"33,000VND"`), nhiều trường để rỗng (train: ADDRESS 75%, SELLER 54%, TIMESTAMP 53%, TOTAL_COST 30%).
  - `train_metadata.jsonl` (5843) + `validation_metadata.jsonl` (172) ở gốc là nhãn **cũ của V3** (`mcocr_*`, `syn_*`), không có ảnh nào tương ứng trong `data1`. `label.py` là tool gán nhãn tay.
- `ai-service/model_config.py`, `ai-service/train_model.py`: code train V3 (start từ `naver-clova-ix/donut-base-finetuned-cord-v2`, ảnh 1280×960, thêm 10 tag trường + ~134 ký tự tiếng Việt làm added token, task token `<s_seller>`, Seq2SeqTrainer, chọn best theo `eval_loss`, early stop 5).
- `ai-service/donut-tranformer.ipynb`: cell 1 tìm `model_config.py` trong `/kaggle/input` rồi chạy `train_model.py`; cell 4 chấm điểm. Điểm V3 ghi lại: exact trung bình 63.95% trên 172 ảnh `mcocr` cũ.
- `ai-service/ai_service.py` (`/donut/scan`) load `Version3/donut_result`, ảnh 1280×960, `do_align_long_axis=True`, task token `<s_seller>`, `clean_vietnamese_text` vá dấu cách, `token2json` → `prediction["seller"][...]`.

### Lỗi đã thấy trong code train hiện tại

1. `train_model.py` đọc `data1/train_metadata.jsonl` + `validation_metadata.jsonl` (nhãn cũ) → tên ảnh không tồn tại → `DonutDataset` âm thầm thay bằng ảnh trắng. Train lại nguyên trạng sẽ ra model rác.
2. `duplication_factor=3` không có tác dụng (`__len__` trả `len(dataset)`).
3. Best checkpoint chọn theo loss, không theo độ chính xác khi generate.
4. Mỗi ký tự tiếng Việt là một added token → câu bị cắt vụn, phải vá dấu cách bằng regex sau decode.
5. Ảnh dài (184/636 ảnh test có cao/rộng > 2.2; có ảnh 2400×5600) bị nén về 1280×960 → chữ nhỏ mất.
6. Notebook chấm điểm dùng `do_align_long_axis=False` khác lúc train/serving (`True`).
7. Tham số albumentations `quality_lower/quality_upper`, `var_limit` là API cũ; `pip install albumentations` bản mới sẽ báo lỗi/cảnh báo.

## Mục tiêu

- Train V5 từ đúng dữ liệu `data1/{train,validation,test}`.
- Đọc tốt hơn hóa đơn dài/nhiều chữ.
- Có một bộ chấm chung, chạy cả V3 và V5 trên **`test/` (636 ảnh)**, báo cáo tổng + nhóm "hóa đơn dài" (cao/rộng > 2.2) + nhóm Circle K (3 ảnh test + 1 ảnh validation).
- **Thành công** = V5 hơn V3 ở exact-match trung bình trên toàn `test/` **và** trên nhóm hóa đơn dài.

## Không làm (lần này)

- Không thêm ảnh mới (sửa nhãn thì có, xem "Sửa nhãn trước khi train").
- Không đổi schema 4 trường, không đổi định dạng JSON mà `/donut/scan` trả về cho backend.
- Không train trên máy local; không đụng `requirements.txt`, backend, mobile.
- Không dùng tập `test/` để chọn checkpoint (chỉ dùng `validation/`).

## Anti-goal

- V5 "điểm cao" nhờ đổi cách chấm, hoặc chấm V3 và V5 khác nhau.
- Dữ liệu lỗi bị nuốt im lặng (ảnh trắng, nhãn parse lỗi) thay vì dừng ngay.
- Model V5 không chạy được trong `ai_service.py` như V3.

## Ràng buộc

- Kaggle GPU (T4 16 GB; notebook đang ép 1 GPU qua `CUDA_VISIBLE_DEVICES=0`), giới hạn ~12 giờ/phiên, fp16 (T4 không có bf16).
- Máy local còn ~16 GB trống, `data1` nặng 13 GB → **không copy ảnh**; tạo `Version5/data1` bằng hard link (`cp -al`), cùng phân vùng nên không tốn dung lượng.
- Không tự chạy train/test nặng (CLAUDE.md). Người dùng tự upload và chạy trên Kaggle.
- Không `git add/commit`.

## Sản phẩm giao

1. **`ai-service/Version5/`** – thư mục người dùng nén/upload thành Kaggle dataset:
   - `model_config.py`, `train_model.py` (bản sửa), `evaluate.py` (bộ chấm chung).
   - `data1/train|validation|test/` (hard link ảnh + `metadata.jsonl`). **Không** đưa `train_metadata.jsonl`, `validation_metadata.jsonl` cũ, `label.py` vào.
   - `check_data.py` (hoặc gộp vào bước đầu của train): kiểm tra mọi dòng jsonl parse được, mọi ảnh mở được, báo số trường rỗng; lỗi → dừng.
2. **`ai-service/donut-v5.ipynb`** – notebook mới (giữ nguyên notebook cũ). Các cell: cài thư viện → kiểm tra dữ liệu → train → chấm V3 vs V5 trên `test/` → nén `donut_result` để tải về.
3. **`ai_service.py`**: chỉ chuyển sang V5 **sau khi** người dùng có kết quả chấm cho thấy V5 thắng; khi đó đọc kích thước ảnh từ `processor_config.json` của model thay vì hằng số 1280×960, và bỏ/giữ `clean_vietnamese_text` theo tokenizer của V5. Đây là bước riêng, làm sau.

## Quyết định về cách làm

Người dùng đã giao các lựa chọn kỹ thuật cho người viết ("chốt theo ý bạn"). Các mục dưới là **quyết định của Claude**:

- **Model gốc:** vẫn start từ `naver-clova-ix/donut-base-finetuned-cord-v2` (không fine-tune tiếp từ V3, vì tokenizer V5 sẽ khác).
- **Tokenizer:** bỏ việc thêm từng ký tự tiếng Việt. Builder đo tỉ lệ `<unk>` của tokenizer gốc trên toàn bộ nhãn train; chỉ thêm (dạng added token thường) những ký tự thực sự ra `<unk>`. Kiểm tra round-trip: `decode(encode(nhãn)) == nhãn` cho ≥99% nhãn, nếu không đạt thì báo lại, không tự đoán. Giữ nguyên 10 tag trường và task token `<s_seller>` để `ai_service.py` không phải đổi luồng parse.
- **Độ phân giải:** tăng so với 1280×960 (hướng tới khoảng 1920×1440 hoặc 2560×1920 như Donut gốc), chọn mức lớn nhất chạy được trên T4 với batch 1 + gradient accumulation + gradient checkpointing. Notebook có một cell "thử 20 bước" in ra bộ nhớ GPU và thời gian/bước để người dùng chọn trước khi train thật; builder đặt mặc định hợp lý và ước lượng tổng thời gian so với giới hạn 12 giờ.
- **Lặp dữ liệu:** bỏ `duplication_factor` (đang không có tác dụng); số epoch quyết định lượng học.
- **Chọn checkpoint:** đánh giá bằng generate thật trên một phần `validation/` (cố định, ví dụ ~150 ảnh) theo chu kỳ; best = exact-match trung bình 4 trường. Early stopping theo chỉ số này. Lưu checkpoint đủ để chạy tiếp nếu Kaggle ngắt phiên.
- **Augmentation:** giữ tinh thần cũ (xoay nhẹ, sáng/tối, mờ, nén JPEG, nhiễu), viết lại theo API albumentations hiện hành; ghim phiên bản trong cell `pip install` của notebook.
- **Dữ liệu lỗi:** ảnh không mở được hoặc nhãn không parse được → dừng với danh sách file lỗi, không thay ảnh trắng.

## Sửa nhãn trước khi train (bước 0)

Người dùng xác nhận nhãn bị **điền thiếu so với ảnh** (ví dụ `test/00005385.jpg` có đủ 4 trường trên ảnh nhưng jsonl chỉ có SELLER). Người dùng muốn **chính xác nhất**, không muốn duyệt tay hàng nghìn ảnh, và không muốn tốn token Claude để đọc ảnh.

- **Đọc chính:** Gemini API (Google AI Studio, model Flash mới nhất tại thời điểm chạy – builder tra tên model và hạn mức free tier hiện hành). Chọn vì chính xác hơn model mở. Người dùng tự tạo API key; key đọc từ biến môi trường / Kaggle Secrets, không ghi vào file.
- **Ý kiến thứ hai:** Qwen2.5-VL-7B-Instruct chạy offline trên GPU Kaggle (quyết định của Claude), cùng prompt.
- **Prompt:** few-shot bằng vài nhãn hiện có đúng kiểu (TOTAL_COST chỉ ghi số tiền như `"50,000"`; TIMESTAMP ghi đúng như in trên hóa đơn; SELLER/ADDRESS chép nguyên văn), trả JSON 4 trường, trường không có trên hóa đơn = `""`. Parse bằng JSON, không regex.
- **Phạm vi:** `test/` và `validation/` đọc lại **toàn bộ 4 trường** (vì nhãn người dùng điền cũng có thể sai); `train/` đọc lại các dòng có ít nhất một trường rỗng, và nếu hạn mức cho phép thì cả phần còn lại.
- **Luật hợp nhất (mỗi trường):**
  - Gemini và Qwen khớp (so chuẩn hóa; TOTAL_COST so theo giá trị số) → nhận tự động.
  - Nhãn cũ không rỗng và khớp Gemini → giữ.
  - Mọi trường hợp khác → đưa vào `review.csv` (ảnh, nhãn cũ, Gemini, Qwen).
- **Duyệt:** tool nhỏ (nâng cấp `label.py`) chỉ hiện các dòng trong `review.csv`: Enter = nhận Gemini, gõ lại nếu sai, `-` = hóa đơn không có. Lưu tiến độ, chạy tiếp được.
- **Đầu ra:** `Version5/data1/<split>/metadata.jsonl` mới; file gốc trong `data1/` không bị sửa. Kèm báo cáo số trường đã đổi / đã điền / còn chờ duyệt cho mỗi tập.
- **Thứ tự:** `test/` → `validation/` → `train/`. Script resume được (cache kết quả theo tên file) vì free tier có giới hạn theo ngày và Kaggle có giới hạn phiên.
- **Train trước khi `train/` sửa xong:** các trường còn rỗng *chưa được kiểm tra* sẽ được che loss (model không bị phạt ở trường đó); trường rỗng *đã được xác nhận* (cả hai model cùng rỗng hoặc người dùng gõ `-`) thì train là rỗng.
- **Lưu ý trung thực:** không công cụ nào đúng 100%; độ chính xác đến từ việc hai model độc lập phải khớp nhau, còn chỗ lệch thì người dùng quyết. Ảnh được gửi lên Google khi dùng Gemini (free tier có thể được Google dùng để cải thiện sản phẩm); người dùng đã chọn ưu tiên độ chính xác.

## Bộ chấm (`evaluate.py`)

- Dùng chung cho V3 và V5, nhận đường dẫn model + thư mục tập.
- Mỗi model được giải mã đúng như cách nó chạy khi serving (V3 kèm `clean_vietnamese_text`; V5 theo tokenizer của nó), cùng `do_align_long_axis=True`, đúng kích thước ảnh của từng model (đọc từ `processor_config.json`).
- Chỉ số mỗi trường: exact (chuẩn hóa: lowercase, gộp khoảng trắng, strip), similarity (SequenceMatcher), match@80%. TOTAL_COST so theo giá trị số (như `extract_money_amount` cũ).
- **Chỉ số chính:** chỉ tính các trường có nhãn không rỗng (giống cách chấm V3 cũ). **Chỉ số phụ:** trường nhãn rỗng tính đúng nếu model cũng trả rỗng (đo việc model bịa).
- Xuất bảng so sánh V3 | V5 cho: toàn `test/`, nhóm hóa đơn dài, nhóm Circle K; kèm file CSV dự đoán từng ảnh để soi lỗi.
- **Nhóm Circle K** (quyết định của Claude): danh sách cố định `test/00005409.jpg`, `test/00005385.jpg`, `test/00006809.jpg` (các ảnh test có SELLER chứa "circle"), hard-code trong `evaluate.py`.
- **Rò rỉ dữ liệu V3:** ảnh trong `data1` đã đổi tên nên không ghép được theo tên file. Đã đối chiếu theo nội dung: 14/636 ảnh `test/` (và 13/635 `validation/`) có ADDRESS (>15 ký tự) trùng khớp hoàn toàn với nhãn train cũ của V3, tức V3 có thể đã thấy chúng. Builder sinh lại danh sách này bằng đúng phép so khớp đó (ADDRESS chuẩn hóa lowercase + gộp khoảng trắng, dài >15, có trong `train_metadata.jsonl` cũ), lưu thành `Version5/v3_seen_test.txt`, và `evaluate.py` báo thêm một cột "toàn test trừ ảnh V3 đã thấy". Điều kiện thành công tính trên cột đó (quyết định của Claude). Phép so khớp chỉ là ước lượng dưới: ảnh có ADDRESS rỗng thì không phát hiện được.

## Rủi ro đã biết

- **Trường rỗng có thể là thiếu nhãn chứ không phải không có trên hóa đơn.** Ví dụ `test/00005385.jpg` (Circle K) chỉ có SELLER, TIMESTAMP/TOTAL_COST rỗng. Nếu nhiều nhãn như vậy, model sẽ học trả rỗng và chỉ số chính sẽ không thấy. Chỉ số phụ + CSV giúp phát hiện; sửa nhãn là việc của người dùng ở vòng sau.
- Điểm V3 cũ (63.95%) không so trực tiếp được với số mới vì khác tập và khác kiểu nhãn; chỉ so số do `evaluate.py` sinh ra.
- Tăng độ phân giải làm train chậm hơn nhiều; có thể phải chia 2 phiên Kaggle (resume từ checkpoint).

## Để builder tự quyết

Tên biến/cấu trúc code, số epoch và lịch learning rate cụ thể, kích thước và chu kỳ của tập validation con, chi tiết cell notebook, cách in log.

## Việc người dùng phải làm

0. Tạo Gemini API key (Google AI Studio), thêm vào Kaggle Secrets; chạy notebook sửa nhãn; duyệt `review.csv` bằng tool.
1. Nén `ai-service/Version5/` và tạo Kaggle dataset mới; thêm cả dataset chứa V3 `donut_result` (đã có sẵn) vào notebook để chấm so sánh.
2. Upload `donut-v5.ipynb`, chạy cell "thử 20 bước", chọn độ phân giải, rồi chạy train.
3. Chạy cell chấm, gửi lại bảng kết quả; tải `donut_result` của V5 về `ai-service/Version5/donut_result` nếu V5 thắng.
