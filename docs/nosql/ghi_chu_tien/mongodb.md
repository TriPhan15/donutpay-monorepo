# Ghi chú Thực hành MongoDB trên Compass (T2 — Phan Minh Tiến)

## 1. Môi trường & Khởi tạo Schema (`mongodb_init.js`, `mongodb_demo.js`)
- **Kết nối MongoDB Compass:** `mongodb://root:demo-mongo-pass@127.0.0.1:27018/?authSource=admin`
- **Database `finance_nosql`:** Đã kiểm tra `$jsonSchema` (`validationLevel: "moderate"`, `validationAction: "error"`) và bộ 13 chỉ mục (`ocr_logs`: 5 indexes; `ocr_feedbacks`: 8 indexes, nổi bật là unique index `receipt_field_uq` và compound index ESR `status_date_idx`) — Ảnh minh chứng: `S-15.png`, `S-16.png`.
- **Database `finance_nosql_demo`:** Đã nạp đủ `36` documents cho `ocr_logs` và `36` documents cho `ocr_feedbacks` — Ảnh minh chứng: `S-17.png`.

## 2. Kết quả Thực thi 16 Truy vấn (`Q-01` .. `Q-16`)

| Mã truy vấn | Nội dung kiểm chứng | Kết quả quan sát thực tế trên Compass | Ảnh minh chứng |
|---|---|---|---|
| **Q-01** | `findOne` theo `transactionId = Long("1025")` | Trả về đúng 1 log của `Highlands Coffee`, model `donut-v5`, điểm tin cậy `0.89`. | `S-20.png` |
| **Q-02** | Lọc `averageConfidenceScore < 0.75`, sort `createdAt: -1`, limit `5` | Trả về 5 log có độ tin cậy thấp (`0.68..0.74`) của model `donut-v4`. | `S-21.png` |
| **Q-03** | Lọc `isResolved: false`, sort `reportedAt: -1`, limit `5` | Trả về 5 phản hồi chưa xử lý mới nhất, tận dụng chỉ mục `status_date_idx`. | `S-22.png` |
| **Q-04** | `countDocuments` lỗi `total_cost` tháng 09/2026 & `distinct("fieldError")` | Số lượng lỗi `total_cost` trong tháng 09/2026 = `6`; danh sách trường lỗi: `['receipt_date', 'seller_name', 'total_cost']`. | `S-23.png` |
| **Q-05** | Kiểm chứng `$jsonSchema` chặn document sai kiểu | Lệnh `insertOne` với `receiptId` kiểu chuỗi và `fieldError: "price"` bị từ chối với lỗi `Document failed validation` (code 121). | `S-24.png` |
| **Q-06** | Kiểm chứng unique index `receipt_field_uq` chặn trùng `(receiptId, fieldError)` | Lệnh chèn trùng `(501, "total_cost")` bị chặn với lỗi `E11000 duplicate key error`. | `S-25.png` |
| **Q-07** | `updateOne` đánh dấu `isResolved: true` | Cập nhật thành công (`matchedCount: 1, modifiedCount: 1`). | `S-26.png` |
| **Q-08** | `deleteOne` xóa 1 phản hồi đã xử lý | Xóa thành công (`deletedCount: 1`), sau đó nạp lại đủ 36 bản ghi gốc. | `S-27.png` |
| **Q-09** | Upsert 2 bước với `$setOnInsert` trên `(receiptId: 530, fieldError: "total_cost")` | Sửa lại cùng giá trị giữ nguyên `isResolved: true`; sửa sang giá trị mới (`210000`) tự động mở lại `isResolved: false` và duy trì đúng `1` document duy nhất (`count: 1`). | `S-28.png` |
| **Q-10** | Aggregation thống kê lỗi theo trường (`errorsByField`) | `seller_name`: `15`, `total_cost`: `12`, `receipt_date`: `9` (tổng 36 lỗi). | `S-29.png` |
| **Q-11** | Aggregation thống kê lỗi theo phiên bản mô hình (`errorsByModel`) | `donut-v4`: `29` lỗi, `donut-v5`: `7` lỗi. | `S-30.png` |
| **Q-12** | Aggregation độ tin cậy trung bình theo tháng (`confidenceByMonth`) | `2026-08`: `0.7258` (12 logs), `2026-09`: `0.8217` (12 logs), `2026-10`: `0.9083` (12 logs). | `S-31.png` |
| **Q-13** | Aggregation `$lookup` từ `ocr_feedbacks` sang `ocr_logs` theo `transactionId` | Trả về 4 bản ghi lỗi `seller_name` kèm thông tin `confidence` (`0.68..0.70`) và `rawSeller` từ bảng log. | `S-32.png` |
| **Q-14** | Aggregation đa nhánh `$facet` trong 1 lần gọi | Trả về đồng thời 4 mảng thống kê: `byField` (3), `byModel` (2), `byStatus` (2), `total` (36). | `S-33.png` |
| **Q-15** | Aggregation tính tỉ lệ hóa đơn phải sửa lỗi (`receiptsWithErrorRate`) | Trên `36` lần đọc (`readings: 36`), có `25` hóa đơn phát sinh sửa lỗi (`withError: 25`), tỉ lệ lỗi `errorRate = 0.6944` (69,44%). | `S-34.png` |
| **Q-16** | `Explain Plan` kiểm chứng chỉ mục `status_date_idx` cho `Q-03` | Kế hoạch thực thi `LIMIT <- FETCH <- IXSCAN` trên `status_date_idx`: `5 documents returned`, `5 index keys examined`, `5 documents examined`, `0 ms`, `Is not sorted in memory` (đạt chuẩn NFR-05 và quy tắc ESR). | `S-35.png` |
