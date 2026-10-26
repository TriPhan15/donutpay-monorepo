# Kết quả huấn luyện và đánh giá DONUT V5 (Kaggle, 2026-10-25/26)

Nguồn: log notebook `ai-service/donut-v5.ipynb` (train_model.py + evaluate.py trong `ai-service/Version5/`). Dùng cho Chương 4 (huấn luyện) và Chương 5 (đánh giá).

## Huấn luyện

- Tokenizer: thêm 65 ký tự tiếng Việt vào vocab Unigram + 10 thẻ trường; embedding mới khởi tạo theo phân phối chuẩn nhiều chiều (mean/covariance của embedding cũ, `mean_resizing`). Tỉ lệ nhãn encode/decode giữ nguyên: 100,00%.
- Dữ liệu: ảnh 1920x1440, 5080 ảnh train (6677 mẫu/epoch sau khi nhân 2 các hóa đơn dài), 150 ảnh validation để chọn checkpoint, 636 ảnh test.
- Chạy thử 20 bước: GPU tối đa 7,9 GB, 10,0 giây/bước, ước tính 2,3 giờ/epoch (18,5 giờ cho 8 epoch).
- Lịch: 6680 bước dự kiến (8 epoch); chạy tiếp từ checkpoint-4000; early stopping dừng ở bước 5600 (epoch 6,707), train_runtime phiên cuối 18 010 s; train_loss trung bình phiên 0,006349; loss từng bước ~0,012–0,047.
- Checkpoint tốt nhất theo `eval_field_exact` trên validation = **0,9350**, ở bước **3200** (theo `trainer_state.json`).

| Bước | Epoch | field_exact | seller | address | timestamp | total_cost |
|---|---|---|---|---|---|---|
| 4400 | 5,27 | 0,9232 | 0,9603 | 0,7981 | 0,9248 | 0,9793 |
| 4800 | 5,75 | 0,9291 | 0,9603 | 0,8173 | 0,9323 | 0,9793 |
| 5200 | 6,23 | 0,9331 | 0,9603 | 0,8269 | 0,9398 | 0,9793 |
| 5600 | 6,71 | 0,9311 | 0,9603 | 0,8269 | 0,9323 | 0,9793 |

(Các lần eval trước bước 4400 nằm trong `trainer_state.json` của checkpoint, nếu đã tải về.)

## Đánh giá trên tập test (636 ảnh), V3 so với V5

exact = khớp hoàn toàn; @80% = độ tương đồng ≥ 80%; sim = độ tương đồng trung bình.

### Toàn bộ test – chỉ số chính (2237 trường có nhãn)

| Trường | V3 exact | V5 exact | V3 @80% | V5 @80% | V3 sim | V5 sim |
|---|---|---|---|---|---|---|
| SELLER | 16,35% | 87,97% | 23,31% | 91,54% | 31,98% | 94,60% |
| ADDRESS | 2,56% | 79,88% | 10,85% | 96,06% | 16,13% | 96,89% |
| TIMESTAMP | 0,53% | 92,95% | 5,29% | 96,12% | 18,30% | 97,66% |
| TOTAL_COST | 48,65% | 97,15% | 50,24% | 97,46% | 53,16% | 98,59% |
| ALL | 18,33% | 89,99% | 23,51% | 95,40% | 30,90% | 97,02% |

### Bỏ các ảnh V3 đã thấy khi train (2153 trường)

| Trường | V3 exact | V5 exact | V3 @80% | V5 @80% | V3 sim | V5 sim |
|---|---|---|---|---|---|---|
| SELLER | 13,31% | 87,48% | 20,55% | 91,19% | 29,31% | 94,38% |
| ADDRESS | 0,00% | 79,63% | 7,61% | 96,30% | 12,67% | 96,85% |
| TIMESTAMP | 0,55% | 92,67% | 3,30% | 95,97% | 16,30% | 97,57% |
| TOTAL_COST | 47,21% | 97,05% | 48,69% | 97,38% | 51,65% | 98,54% |
| ALL | 16,67% | 89,74% | 21,23% | 95,31% | 28,58% | 96,93% |

### Hóa đơn dài (632 trường)

| Trường | V3 exact | V5 exact | V3 @80% | V5 @80% | V3 sim | V5 sim |
|---|---|---|---|---|---|---|
| SELLER | 1,96% | 83,66% | 9,15% | 86,93% | 28,22% | 91,40% |
| ADDRESS | 0,00% | 67,76% | 1,97% | 93,42% | 8,68% | 94,74% |
| TIMESTAMP | 0,70% | 94,41% | 3,50% | 97,20% | 23,96% | 97,62% |
| TOTAL_COST | 45,65% | 97,28% | 46,74% | 97,83% | 53,10% | 99,09% |
| ALL | 13,92% | 86,23% | 17,09% | 93,99% | 29,80% | 95,85% |

### Circle K (12 trường)

V3: ALL exact 50,00% (seller và total_cost 100%, address và timestamp 0%); V5: 100% mọi trường.

### Tính cả trường rỗng – đo việc "bịa" giá trị (2544 trường)

| Trường | V3 exact | V5 exact | V3 @80% | V5 @80% | V3 sim | V5 sim |
|---|---|---|---|---|---|---|
| SELLER | 23,74% | 82,70% | 29,56% | 85,69% | 36,82% | 88,25% |
| ADDRESS | 19,50% | 73,90% | 26,10% | 86,79% | 30,31% | 87,46% |
| TIMESTAMP | 9,59% | 83,33% | 13,84% | 86,16% | 25,44% | 87,54% |
| TOTAL_COST | 48,43% | 96,86% | 50,00% | 97,17% | 52,90% | 98,29% |
| ALL | 25,31% | 84,20% | 29,87% | 88,95% | 36,37% | 90,38% |

Bỏ ảnh V3 đã thấy (2460 trường): ALL exact V3 24,11% / V5 83,78%; @80% 28,09% / 88,66%; sim 34,53% / 90,07%.
Hóa đơn dài (736 trường): ALL exact V3 23,23% / V5 74,73%; @80% 25,95% / 81,39%; sim 36,87% / 82,99% (seller 70,11%, address 58,15%, timestamp 73,37% exact cho V5: hóa đơn dài là điểm yếu còn lại).

Kết luận của script: **V5 THẮNG**.

## Nhận xét để viết phân tích lỗi

- ADDRESS có exact thấp nhất (79,88%) nhưng @80% cao (96,06%): lỗi chủ yếu là sai lệch nhỏ (dấu, viết tắt, khoảng trắng), phù hợp để hậu xử lý Regex chuẩn hóa (T5).
- Khoảng cách giữa "chỉ số chính" và "tính cả trường rỗng" (89,99% → 84,20%) cho thấy V5 vẫn đôi khi điền giá trị cho trường mà nhãn để trống, rõ nhất ở hóa đơn dài.
- Chi tiết từng ảnh: `compare_test.csv` và `pred_v3_test.jsonl` / `pred_v5_test.jsonl` trong /kaggle/working (nếu đã tải về `ai-service/Version5/`).

## Hậu xử lý Regex (T5, `ai-service/receipt_postprocess.py`)

Đo trên `compare_test.csv` (2237 trường có nhãn, cùng hàm `fields_match`, chuẩn hóa áp cho cả nhãn và dự đoán):

| Trường | Trước | Sau |
|---|---|---|
| SELLER | 468/532 = 87,97% | 468/532 = 87,97% |
| ADDRESS | 405/507 = 79,88% | 415/507 = 81,85% |
| TIMESTAMP | 527/567 = 92,95% | 539/567 = 95,06% |
| TOTAL_COST | 613/631 = 97,15% | 614/631 = 97,31% |
| ALL | 2013/2237 = 89,99% | 2036/2237 = 91,01% |

+23 trường thành khớp hoàn toàn, không trường nào từ đúng thành sai. Cờ `valid` bắt được 23/201 trường còn sai, báo nhầm 4/2036 trường đúng. 63 test pytest mới (68 tổng, xanh).
