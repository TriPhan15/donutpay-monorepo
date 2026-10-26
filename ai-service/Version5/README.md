# Donut V5: hướng dẫn chạy

Thư mục này là **bundle upload lên Kaggle**: code + nhãn đã sửa (`data1/<split>/metadata.jsonl`).
Ảnh **không** nằm ở đây: code tự tìm ảnh trong dataset `data1` đã upload trước đây (trên Kaggle)
hoặc trong `ai-service/data1` (máy local). Nhãn gốc trong `ai-service/data1` không bao giờ bị sửa.

## 0. Chuẩn bị (một lần)

1. Tạo Gemini API key ở https://aistudio.google.com → **Get API key** → **Create API key**.
2. Trên Kaggle: mở notebook → **Add-ons → Secrets → Add a new secret**, Label `GEMINI_API_KEY`,
   Value là key, tick bật cho notebook. Không dán key vào code hay chat.
3. Lưu ý hạn mức: bản miễn phí của Gemini Flash hiện chỉ khoảng **20 ảnh/ngày** (Flash-Lite khoảng 500).
   Muốn đọc hết ~7000 ảnh trong 1–2 ngày cần bật billing cho project trong AI Studio (tốn phí theo số ảnh),
   hoặc chạy với `--model <tên Flash-Lite>` (nhanh hơn, kém chính xác hơn). Xem
   https://ai.google.dev/gemini-api/docs/rate-limits.

## 1. Sửa nhãn

1. `init_labels.py` đã chạy rồi (nhãn gốc đã copy vào `Version5/data1`). Chạy lại cũng không ghi đè.
2. Nén thư mục `ai-service/Version5` và tạo dataset Kaggle mới tên `Version5`.
3. Upload `ai-service/relabel-v5.ipynb`, Add Data: `Version5` + dataset ảnh `data1`. Chạy hết notebook.
   Hết quota thì để hôm sau chạy lại; ảnh đã đọc được bỏ qua (Add Data output phiên trước để giữ cache).
4. Tải `relabel_cache.zip`, giải nén thành `ai-service/Version5/relabel_cache/`.
5. Ở máy local, cho từng tập theo thứ tự `test` → `validation` → `train`:

   ```bash
   ai-service/venv/bin/python ai-service/Version5/merge_labels.py --split test
   ai-service/venv/bin/python ai-service/Version5/review_labels.py --split test
   ```

   Tool duyệt chỉ hiện những trường Gemini và Qwen không khớp nhau:
   Enter = nhận Gemini, `-` = hóa đơn không có thông tin này, `o` = giữ nhãn cũ,
   gõ chữ = giá trị đúng, `q` = lưu và thoát (lần sau làm tiếp).
6. Khi `test` đã duyệt xong: `ai-service/venv/bin/python ai-service/Version5/find_v3_seen.py`.

Không cần duyệt hết `train/` mới được train: các ô rỗng chưa kiểm tra được **bỏ qua khi tính loss**,
nên model không học thói quen trả rỗng.

## 2. Train

1. Upload version mới của dataset `Version5` (chỉ vài MB).
2. Upload `ai-service/donut-v5.ipynb`, Add Data: `Version5`, dataset ảnh `data1`, dataset chứa `Version3/donut_result`.
3. Chạy tới cell **chạy thử 20 bước**, đọc dòng `CHẠY THỬ`: bộ nhớ GPU và số giờ ước tính.
   Hết bộ nhớ hoặc quá 12 giờ thì giảm `DONUT_IMAGE_HEIGHT/WIDTH` (ví dụ 1600/1200 hoặc 1280/960).
4. Chạy cell train. Bị ngắt phiên: Save Version, Add Data output đó, chạy lại notebook (tự chạy tiếp).
5. Cell so sánh in bảng V3 vs V5 cho: toàn bộ test, test trừ 14 ảnh V3 có thể đã học,
   hóa đơn dài, Circle K; dòng cuối là `V5 THẮNG` hoặc `V5 CHƯA THẮNG`. File chi tiết: `compare_test.csv`.
6. Gửi lại bảng kết quả. Nếu V5 thắng, tải `donut_result.zip` về `ai-service/Version5/donut_result`
   (việc chuyển `ai_service.py` sang V5 là bước riêng, làm sau).

## Test

```bash
ai-service/venv/bin/python -m pytest ai-service/Version5/tests/test_labels.py -q
```
(mỗi file trong `tests/` chạy riêng như vậy; trên Kaggle notebook train tự chạy cả thư mục `tests`).
