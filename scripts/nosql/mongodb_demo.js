// =============================================================================
// MONGODB DEMO - DỮ LIỆU MẪU VÀ CÁC CÂU TRUY VẤN Q-01 ... Q-16 (ĐỒ ÁN NOSQL)
// -----------------------------------------------------------------------------
// KHÔNG chạy trên database thật. Script này làm việc trong database RIÊNG "finance_nosql_demo":
// xóa sạch database đó, nạp schema + index bằng chính mongodb_init.js (cùng file app dùng), rồi chèn dữ liệu mẫu
// và chạy truy vấn. Database thật "finance_nosql" không bị đụng tới.
//
// Cách chạy (container dùng một lần, không auth; /s là thư mục scripts/nosql):
//   docker run --rm -v "$PWD/scripts/nosql:/s:ro" mongo:6.0 bash -c \
//       'mongod --fork --logpath /tmp/m.log >/dev/null && cd /s && mongosh --quiet mongodb_demo.js'
// (phải đứng trong thư mục chứa hai file, vì load() của mongosh tìm mongodb_init.js theo thư mục hiện tại)
//
// Mỗi truy vấn có nhãn [CƠ BẢN] hoặc [NÂNG CAO] và "Access pattern" (app/admin hỏi gì, index nào phục vụ).
// Báo cáo trích dẫn theo số Q-xx. Trên hệ thống thật, các truy vấn này tương ứng với OcrMongoService
// (Service/OcrMongoService.java) và AdminOcrFeedbackController (/api/admin/ocr-feedbacks).
// =============================================================================

// NumberLong nhận chuỗi để không mất độ chính xác (mongosh cảnh báo khi truyền số).
function L(n) { return NumberLong(String(n)); }

const DEMO_DB_NAME = "finance_nosql_demo";
var TARGET_DB = DEMO_DB_NAME;               // mongodb_init.js đọc biến này để biết tạo schema ở đâu

print("========================================================");
print("  PHẦN A. Khởi tạo database demo " + DEMO_DB_NAME);
print("========================================================");
db.getSiblingDB(DEMO_DB_NAME).dropDatabase();
// Nạp cùng một file schema + index mà docker-compose gắn vào initdb (load() tìm theo thư mục hiện tại).
load("mongodb_init.js");

const d = db.getSiblingDB(DEMO_DB_NAME);

// -----------------------------------------------------------------------------
// PHẦN B. Dữ liệu mẫu: 36 ocr_logs + 36 ocr_feedbacks, đúng hình dạng document mà code Java ghi.
//   - 3 tháng (2026-08, 09, 10), 2 phiên bản mô hình: donut-v4 (nửa đầu) và donut-v5 (nửa sau, đọc tốt hơn).
//   - rawJsonData giống câu trả lời AI thật: {"seller": {seller_name, address, timestamp, total_cost, ...}}.
//   - feedbacks: 24 hóa đơn, 12 hóa đơn bị sửa 2 trường; (receiptId, fieldError) không trùng (receipt_field_uq).
// Số liệu sinh bằng công thức cố định (không dùng ngẫu nhiên) để chạy lần nào cũng ra cùng kết quả.
// -----------------------------------------------------------------------------
print("\n========================================================");
print("  PHẦN B. Chèn dữ liệu mẫu");
print("========================================================");

const SELLERS = ["Highlands Coffee", "Phúc Long", "KFC Hai Bà Trưng", "Circle K", "WinMart", "Phở Thìn", "The Coffee House", "GS25"];
const MISREAD = ["Hlghlands C0ffee", "Phuc L0ng", "KEC Ha1 Ba Trung", "Circ1e K", "W1nMart", "Ph0 Th1n", "The C0ffee House", "G525"];
const FIELD_ORDER = ["total_cost", "seller_name", "total_cost", "receipt_date"];   // total_cost bị sửa nhiều nhất
function corrected(i, field) { return field === "seller_name" ? (i < 12 || (i < 24 && i % 4 === 1) || i === 29) : (i < 24 && i % 4 === 3) || (i < 12 && i % 4 === 1); }   // hóa đơn i bị sửa trường này (addFeedback, Q-09): lần đọc AI giữ giá trị sai
function logTime(i) {                       // i = 0..35: 12 log mỗi tháng
  const month = 7 + Math.floor(i / 12);     // JS tháng bắt đầu từ 0: 7 = tháng 8
  const day = 1 + (i % 12) * 2;
  return new Date(Date.UTC(2026, month, day, 1 + (i % 9), 15 * (i % 4)));
}

const logs = [];
for (let i = 0; i < 36; i++) {
  const v5 = i >= 18;
  const total = 35000 + 15000 * ((i * 7) % 20);
  const score = Math.round(((v5 ? 0.86 : 0.68) + ((i * 7) % 11) / 100) * 100) / 100;                 // v4: 0.68-0.78, v5: 0.86-0.96
  const when = logTime(i);
  const seller = (corrected(i, "seller_name") ? MISREAD : SELLERS)[i % SELLERS.length];   // AI đọc sai thì log giữ chữ sai
  const dateText = corrected(i, "receipt_date") ? "2026-01-01" : when.toISOString().slice(0, 10);
  logs.push({
    _class: "vn.edu.huit.finance.core.Document.OcrRawLog",
    transactionId: L(1001 + i),
    rawJsonData: {
      seller: { seller_name: seller, address: "TP. Hồ Chí Minh", timestamp: dateText, total_cost: total.toLocaleString("en-US"), total_cost_number: total },
      confidence_score: score       // dữ liệu mẫu có độ tin cậy; câu trả lời thật của Donut V5 không có, ứng dụng ghi null
    },
    modelVersion: v5 ? "donut-v5" : "donut-v4",
    aiReading: { sellerName: seller, totalCost: String(total), receiptDate: dateText },
    averageConfidenceScore: score,
    createdAt: when
  });
}
d.ocr_logs.insertMany(logs);

const feedbacks = [];
function addFeedback(receiptIndex, field) {          // receiptIndex 0..23 -> receiptId 501.., transactionId 1001..
  const log = logs[receiptIndex];
  const seller = SELLERS[receiptIndex % SELLERS.length];
  const values = {
    seller_name: [seller, MISREAD[receiptIndex % MISREAD.length]],
    total_cost: [String(log.rawJsonData.seller.total_cost_number * 10), String(log.rawJsonData.seller.total_cost_number)],
    receipt_date: [log.createdAt.toISOString().slice(0, 10), "2026-01-01"]
  }[field];
  feedbacks.push({
    _class: "vn.edu.huit.finance.core.Document.OcrFeedback",
    receiptId: L(501 + receiptIndex),
    transactionId: L(1001 + receiptIndex),
    userId: L(1 + (receiptIndex % 3)),
    fieldError: field,
    expectedValue: values[0],
    aiValue: values[1],
    modelVersion: log.modelVersion,
    isResolved: receiptIndex % 3 === 0,                                    // 1/3 đã xử lý
    reportedAt: new Date(log.createdAt.getTime() + 5 * 60000),
    updatedAt: new Date(log.createdAt.getTime() + 5 * 60000)
  });
}
for (let r = 0; r < 24; r++) addFeedback(r, FIELD_ORDER[r % 4]);           // mỗi hóa đơn một trường
for (let r = 0; r < 12; r++) addFeedback(r, FIELD_ORDER[r % 4] === "seller_name" ? "receipt_date" : "seller_name");  // 12 hóa đơn sửa thêm trường thứ hai
d.ocr_feedbacks.insertMany(feedbacks);

print("ocr_logs      : " + d.ocr_logs.countDocuments() + " document");
print("ocr_feedbacks : " + d.ocr_feedbacks.countDocuments() + " document");

// =============================================================================
print("\n========================================================");
print("  PHẦN C. Truy vấn Q-01 ... Q-16");
print("========================================================");

// ---- Q-01 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: admin mở log OCR thô của một giao dịch. Index unique `transactionId`.
print("\n-- Q-01 [CƠ BẢN] findOne theo transactionId (index unique transactionId) --");
printjson(d.ocr_logs.findOne({ transactionId: L(1025) }, { _id: 0, transactionId: 1, modelVersion: 1, averageConfidenceScore: 1, "rawJsonData.seller": 1 }));

// ---- Q-02 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: tìm lần đọc AI kém (độ tin cậy < 0.75), mới nhất trước. Compound index `score_date_idx`.
print("\n-- Q-02 [CƠ BẢN] find + projection + sort: log có độ tin cậy < 0.75, mới nhất trước --");
d.ocr_logs.find({ averageConfidenceScore: { $lt: 0.75 } }, { _id: 0, transactionId: 1, modelVersion: 1, averageConfidenceScore: 1, createdAt: 1 })
  .sort({ createdAt: -1 }).limit(5).forEach(printjson);

// ---- Q-03 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: danh sách "chưa xử lý, mới nhất trước" của admin. Compound index `status_date_idx`.
print("\n-- Q-03 [CƠ BẢN] feedback chưa xử lý, mới nhất trước (status_date_idx) --");
d.ocr_feedbacks.find({ isResolved: false }, { _id: 0, receiptId: 1, fieldError: 1, reportedAt: 1 })
  .sort({ reportedAt: -1 }).limit(5).forEach(printjson);

// ---- Q-04 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: bộ lọc GET /api/admin/ocr-feedbacks?field=total_cost&from=&to= (khoảng [from, to] gồm ngày to).
print("\n-- Q-04 [CƠ BẢN] countDocuments theo trường + khoảng thời gian (tháng 9/2026) --");
print("total_cost trong 09/2026: " + d.ocr_feedbacks.countDocuments({
  fieldError: "total_cost",
  reportedAt: { $gte: ISODate("2026-09-01T00:00:00Z"), $lt: ISODate("2026-10-01T00:00:00Z") }
}));
print("Các giá trị fieldError có trong dữ liệu: " + d.ocr_feedbacks.distinct("fieldError").join(", "));

// ---- Q-05 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: schema validator chặn ghi sai kiểu / thiếu trường bắt buộc / fieldError lạ.
print("\n-- Q-05 [CƠ BẢN] $jsonSchema validator từ chối document sai schema --");
try {
  d.ocr_feedbacks.insertOne({ receiptId: "khong-phai-so", userId: L(1), fieldError: "price", isResolved: false });
  print("KHÔNG mong đợi: insert sai schema lại thành công");
} catch (e) {
  print("Bị từ chối đúng như mong đợi: " + "mã lỗi " + e.code + " - " + e.message);
}

// ---- Q-06 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: không được có hai document cho cùng (hóa đơn, trường). Unique index `receipt_field_uq`.
print("\n-- Q-06 [CƠ BẢN] unique index receipt_field_uq chặn trùng (receiptId, fieldError) --");
try {
  d.ocr_feedbacks.insertOne({ receiptId: L(501), userId: L(1), fieldError: "total_cost", isResolved: false });
  print("KHÔNG mong đợi: insert trùng lại thành công");
} catch (e) {
  print("Bị từ chối đúng như mong đợi: " + "mã lỗi " + e.code + " - index " + (e.message.match(/index: (\S+)/) || [])[1]);
}

// ---- Q-07 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: PATCH /api/admin/ocr-feedbacks/{id}/resolve - admin đánh dấu đã xử lý.
print("\n-- Q-07 [CƠ BẢN] updateOne: admin resolve một feedback --");
const target = d.ocr_feedbacks.findOne({ isResolved: false }, { receiptId: 1, fieldError: 1 });
const resolved = d.ocr_feedbacks.updateOne({ _id: target._id }, { $set: { isResolved: true } });
print("matched=" + resolved.matchedCount + " modified=" + resolved.modifiedCount +
  " (receiptId " + target.receiptId + ", " + target.fieldError + ")");

// ---- Q-08 [CƠ BẢN] -----------------------------------------------------------
// Access pattern: DELETE /api/admin/ocr-feedbacks/{id} - xóa một feedback.
print("\n-- Q-08 [CƠ BẢN] deleteOne: xóa feedback vừa xử lý --");
const before = d.ocr_feedbacks.countDocuments();
const deleted = d.ocr_feedbacks.deleteOne({ _id: target._id });
print("deleted=" + deleted.deletedCount + "; số feedback " + before + " -> " + d.ocr_feedbacks.countDocuments());

// ---- Q-09 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: người dùng sửa lại hóa đơn (OcrMongoService.upsertCorrection), hai bước:
//   1) cặp (hóa đơn, trường) đã có với giá trị KHÁC: ghi đè và đặt lại "chưa xử lý";
//   2) chưa có: thêm mới bằng upsert chỉ có $setOnInsert. Đã có với CÙNG giá trị (một lần sửa trường khác của hóa đơn
//      gửi lại chỗ sửa này) thì cả hai bước không đổi gì: phản hồi admin đã xử lý vẫn là đã xử lý.
// Trường người dùng trả về đúng giá trị AI thì chỗ sửa cũ bị xóa (deleteMany theo receiptId + fieldError).
print("\n-- Q-09 [NÂNG CAO] updateOne có điều kiện + upsert $setOnInsert (không bao giờ tạo bản trùng nhờ receipt_field_uq) --");
function upsertCorrection(receiptId, transactionId, userId, field, aiValue, expectedValue, now) {
  const key = { receiptId: L(receiptId), fieldError: field };
  const fields = {
    transactionId: L(transactionId), userId: L(userId), aiValue: aiValue, expectedValue: expectedValue,
    modelVersion: "donut-v5", isResolved: false, updatedAt: now
  };
  const changed = d.ocr_feedbacks.updateOne(
    { $and: [key, { $or: [{ expectedValue: { $ne: expectedValue } }, { aiValue: { $ne: aiValue } }] }] },
    { $set: fields });
  if (changed.matchedCount > 0) {
    return "sửa tại chỗ, mở lại";
  }
  const inserted = d.ocr_feedbacks.updateOne(key, { $setOnInsert: Object.assign({ reportedAt: now }, fields) }, { upsert: true });
  return inserted.upsertedCount === 1 ? "thêm mới" : "không đổi";
}
print("lần 1: " + upsertCorrection(530, 1030, 2, "seller_name", "Ph0 Th1n", "Phở Thìn", ISODate("2026-10-20T08:00:00Z")));
d.ocr_feedbacks.updateOne({ receiptId: L(530), fieldError: "seller_name" }, { $set: { isResolved: true } });   // admin xử lý
print("lần 2 (cùng giá trị): " + upsertCorrection(530, 1030, 2, "seller_name", "Ph0 Th1n", "Phở Thìn", ISODate("2026-10-20T12:00:00Z"))
  + ", isResolved=" + d.ocr_feedbacks.findOne({ receiptId: L(530), fieldError: "seller_name" }).isResolved);
print("lần 3 (giá trị khác): " + upsertCorrection(530, 1030, 2, "seller_name", "Ph0 Th1n", "Phở Thìn Bờ Hồ", ISODate("2026-10-21T09:00:00Z")));
printjson(d.ocr_feedbacks.findOne({ receiptId: L(530), fieldError: "seller_name" }, { _id: 0, expectedValue: 1, isResolved: 1, reportedAt: 1, updatedAt: 1 }));
print("số document của (530, seller_name): " + d.ocr_feedbacks.countDocuments({ receiptId: L(530), fieldError: "seller_name" }));

// ---- Q-10 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: GET /api/admin/ocr-feedbacks/analytics -> errorsByField. Trường nào AI đọc sai nhiều nhất.
print("\n-- Q-10 [NÂNG CAO] $match/$group/$sort: số lỗi theo trường (errorsByField) --");
d.ocr_feedbacks.aggregate([
  { $match: { reportedAt: { $gte: ISODate("2026-08-01T00:00:00Z"), $lt: ISODate("2026-11-01T00:00:00Z") } } },
  { $group: { _id: "$fieldError", count: { $sum: 1 } } },
  { $sort: { count: -1, _id: 1 } }
]).forEach(printjson);

// ---- Q-11 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: analytics -> errorsByModel. So donut-v4 với donut-v5; document cũ chưa có modelVersion là "unknown".
print("\n-- Q-11 [NÂNG CAO] $group theo modelVersion + $ifNull: lỗi theo mô hình (errorsByModel) --");
d.ocr_feedbacks.aggregate([
  { $group: { _id: { $ifNull: ["$modelVersion", "unknown"] }, count: { $sum: 1 } } },
  { $sort: { count: -1, _id: 1 } }
]).forEach(printjson);

// ---- Q-12 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: analytics -> confidenceByMonth. Độ tin cậy trung bình và số lần đọc theo tháng (giờ Việt Nam).
print("\n-- Q-12 [NÂNG CAO] $dateToString + $group $avg: độ tin cậy trung bình theo tháng (confidenceByMonth) --");
d.ocr_logs.aggregate([
  { $project: { month: { $dateToString: { format: "%Y-%m", date: "$createdAt", timezone: "Asia/Ho_Chi_Minh" } }, score: "$averageConfidenceScore" } },
  { $group: { _id: "$month", average: { $avg: "$score" }, logs: { $sum: 1 } } },
  { $sort: { _id: 1 } },
  { $project: { _id: 1, logs: 1, average: { $round: ["$average", 3] } } }
]).forEach(printjson);

// ---- Q-13 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: với mỗi feedback, xem câu trả lời thô của AI cho giao dịch đó. Nối bằng transactionId
// (khóa ảo tới PostgreSQL); phía ocr_logs có index unique transactionId nên $lookup tra bằng index.
print("\n-- Q-13 [NÂNG CAO] $lookup (feedbacks -> logs theo transactionId) + $unwind + $project --");
d.ocr_feedbacks.aggregate([
  { $match: { fieldError: "seller_name" } },
  { $lookup: { from: "ocr_logs", localField: "transactionId", foreignField: "transactionId", as: "log" } },
  { $unwind: "$log" },
  { $project: { _id: 0, receiptId: 1, aiValue: 1, expectedValue: 1, rawSeller: "$log.rawJsonData.seller.seller_name", confidence: "$log.averageConfidenceScore", model: "$log.modelVersion" } },
  { $sort: { receiptId: 1 } },
  { $limit: 4 }
]).forEach(printjson);

// ---- Q-14 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: một màn hình thống kê cần nhiều số liệu cùng lúc; $facet chạy nhiều pipeline trên MỘT lần quét.
print("\n-- Q-14 [NÂNG CAO] $facet: lỗi theo trường + theo mô hình + tình trạng xử lý trong một lần truy vấn --");
d.ocr_feedbacks.aggregate([
  { $facet: {
      byField: [{ $group: { _id: "$fieldError", count: { $sum: 1 } } }, { $sort: { count: -1, _id: 1 } }],
      byModel: [{ $group: { _id: "$modelVersion", count: { $sum: 1 } } }, { $sort: { _id: 1 } }],
      byStatus: [{ $group: { _id: "$isResolved", count: { $sum: 1 } } }, { $sort: { _id: 1 } }],
      total: [{ $count: "n" }]
  } }
]).forEach(printjson);

// ---- Q-15 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: analytics -> receiptsWithErrorRate. Trong các lần đọc (ocr_logs) của khoảng thời gian, tỉ lệ lần đọc có
// giao dịch bị sửa ít nhất một chỗ (feedback báo lúc nào cũng được). Tử số là tập con của mẫu số nên tỉ lệ <= 1.
// $lookup theo transactionId dùng index transactionId của ocr_feedbacks.
print("\n-- Q-15 [NÂNG CAO] $lookup + $group: tỉ lệ lần đọc bị sửa (receiptsWithErrorRate) --");
d.ocr_logs.aggregate([
  { $match: { createdAt: { $gte: ISODate("2026-08-01T00:00:00Z"), $lt: ISODate("2026-11-01T00:00:00Z") } } },
  { $lookup: { from: "ocr_feedbacks", localField: "transactionId", foreignField: "transactionId", as: "feedbacks" } },
  { $group: { _id: null, readings: { $sum: 1 }, withError: { $sum: { $cond: [{ $gt: [{ $size: "$feedbacks" }, 0] }, 1, 0] } } } },
  { $project: { _id: 0, readings: 1, withError: 1, rate: { $round: [{ $divide: ["$withError", "$readings"] }, 3] } } }
]).forEach(printjson);

// ---- Q-16 [NÂNG CAO] ---------------------------------------------------------
// Access pattern: chứng minh index được dùng. winningPlan phải chứa IXSCAN (không phải COLLSCAN).
print("\n-- Q-16 [NÂNG CAO] explain('executionStats'): truy vấn dùng index (IXSCAN) --");
function stageNames(plan) {
  const names = [plan.stage];
  if (plan.inputStage) names.push.apply(names, stageNames(plan.inputStage));
  return names;
}
const plan1 = d.ocr_feedbacks.find({ isResolved: false }).sort({ reportedAt: -1 }).explain("executionStats");
print("Q-03 (status_date_idx): stages = " + stageNames(plan1.queryPlanner.winningPlan).join(" -> ") +
  "; index = " + plan1.queryPlanner.winningPlan.inputStage.indexName +
  "; totalKeysExamined=" + plan1.executionStats.totalKeysExamined + ", totalDocsExamined=" + plan1.executionStats.totalDocsExamined +
  ", nReturned=" + plan1.executionStats.nReturned);
const plan2 = d.ocr_logs.find({ transactionId: L(1025) }).explain("executionStats");
print("Q-01 (transactionId):   stages = " + stageNames(plan2.queryPlanner.winningPlan).join(" -> ") +
  "; index = " + plan2.queryPlanner.winningPlan.inputStage.indexName +
  "; totalKeysExamined=" + plan2.executionStats.totalKeysExamined + ", totalDocsExamined=" + plan2.executionStats.totalDocsExamined);
const plan3 = d.ocr_feedbacks.find({ receiptId: L(515), fieldError: "total_cost" }).explain("executionStats");
print("Q-06 (receipt_field_uq): stages = " + stageNames(plan3.queryPlanner.winningPlan).join(" -> ") +
  "; index = " + plan3.queryPlanner.winningPlan.inputStage.indexName);

// =============================================================================
print("\n========================================================");
print("  KẾT THÚC DEMO");
print("========================================================");
print("ocr_logs      : " + d.ocr_logs.countDocuments() + " document, " + d.ocr_logs.getIndexes().length + " index");
print("ocr_feedbacks : " + d.ocr_feedbacks.countDocuments() + " document, " + d.ocr_feedbacks.getIndexes().length + " index");
print("Database demo " + DEMO_DB_NAME + " được giữ lại để xem bằng mongosh; chạy lại script sẽ xóa và nạp lại.");
