// =============================================================================
// MONGODB - TẠO COLLECTION, SCHEMA VALIDATOR VÀ INDEX CỦA LEDGERMIND
// -----------------------------------------------------------------------------
// Vai trò MongoDB trong dự án (Polyglot Persistence: PostgreSQL + Redis + MongoDB + Elasticsearch):
//   kho phân tích phụ cho AI OCR. PostgreSQL vẫn là nguồn dữ liệu chính của hóa đơn.
//     - ocr_logs      : câu trả lời thô của AI (Donut) cho mỗi lần đọc hóa đơn + độ tin cậy + phiên bản mô hình.
//     - ocr_feedbacks : chỗ người dùng sửa lại kết quả AI (mỗi cặp hóa đơn + trường đúng MỘT document).
//
// File này là cách THẬT để app có index: Spring Data MongoDB KHÔNG tự tạo index (auto-index-creation tắt),
// nên mọi index khai báo bằng @Indexed / @CompoundIndex trong Document/OcrRawLog.java và OcrFeedback.java
// đều được tạo ở đây, với đúng tên và đúng khóa mà annotation sẽ sinh ra.
//
// An toàn khi chạy lại và chạy trên DB thật (IDEMPOTENT, KHÔNG ghi dữ liệu):
//   - createCollection chỉ chạy khi collection chưa tồn tại;
//   - validator đặt bằng collMod (chạy lại chỉ ghi đè bằng đúng nội dung này);
//   - createIndex không làm gì nếu index cùng tên, cùng khóa đã có (khác khóa thì báo lỗi - đúng ý, cần người xem).
// Dữ liệu mẫu và các câu truy vấn demo nằm ở file RIÊNG: mongodb_demo.js (không chạy file đó trên DB thật).
//
// Cách chạy:
//   1) Tự động: docker-compose.yml gắn file này vào /docker-entrypoint-initdb.d/. Image mongo chỉ chạy thư mục đó
//      khi volume mongodb_data còn TRỐNG (lần khởi động đầu tiên).
//   2) Bằng tay trên volume đã có dữ liệu:
//      docker compose exec mongodb sh -c 'mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" \
//          --authenticationDatabase admin --quiet /docker-entrypoint-initdb.d/10-mongodb-init.js'
//   3) Chạy thử trong container dùng một lần (không auth):
//      docker run --rm -v "$PWD/scripts/nosql:/s:ro" mongo:6.0 bash -c \
//          'mongod --fork --logpath /tmp/m.log >/dev/null && mongosh --quiet /s/mongodb_init.js'
// =============================================================================

// Tên database của app (docker-compose: MONGO_INITDB_DATABASE=finance_nosql, MONGO_URI .../finance_nosql).
// mongodb_demo.js đặt biến TARGET_DB trước khi nạp file này để tạo schema trong một database demo riêng.
const INIT_DB_NAME = (typeof TARGET_DB !== "undefined") ? TARGET_DB : "finance_nosql";
const appDb = db.getSiblingDB(INIT_DB_NAME);

print("========================================================");
print("  MONGODB INIT - database: " + INIT_DB_NAME);
print("========================================================");

// -----------------------------------------------------------------------------
// BƯỚC 1. $jsonSchema validator
// -----------------------------------------------------------------------------
// Kiểu BSON khớp với những gì Spring Data ghi: Long -> "long", boolean -> "bool", LocalDateTime -> "date",
// bean lồng nhau -> "object". Khóa của document giữ tên thuộc tính Java (camelCase), còn GIÁ TRỊ của fieldError
// là seller_name / total_cost / receipt_date (OcrField.key()).
//
// validationLevel "moderate": document MỚI luôn bị kiểm tra; document cũ đang không hợp lệ không chặn việc sửa
//   (an toàn khi áp lên DB đã có dữ liệu). validationAction "error": ghi sai schema bị từ chối.
const FIELD_KEYS = ["seller_name", "total_cost", "receipt_date"];

const OCR_LOGS_VALIDATOR = {
  $jsonSchema: {
    bsonType: "object",
    required: ["transactionId", "rawJsonData"],
    properties: {
      transactionId: { bsonType: "long", description: "Khóa ảo -> PostgreSQL transactions.id (UNIQUE)" },
      rawJsonData: { bsonType: "object", description: "Câu trả lời thô của AI; nếu không phải JSON thì {unparsed_raw_string: ...}" },
      modelVersion: { bsonType: ["string", "null"], description: "app.ocr.model-version lúc ghi, ví dụ donut-v5" },
      aiReading: {
        bsonType: ["object", "null"],
        description: "Những gì AI đọc được, đã chuẩn hóa thành chuỗi (cùng định dạng với ocr_feedbacks)",
        properties: {
          sellerName: { bsonType: ["string", "null"] },
          totalCost: { bsonType: ["string", "null"] },
          receiptDate: { bsonType: ["string", "null"] }
        }
      },
      // null khi câu trả lời của AI không có độ tin cậy (Donut V5 không trả về): ứng dụng không bịa 1.0; $avg bỏ qua null.
      averageConfidenceScore: { bsonType: ["double", "null"] },
      createdAt: { bsonType: ["date", "null"] }
    }
  }
};

const OCR_FEEDBACKS_VALIDATOR = {
  $jsonSchema: {
    bsonType: "object",
    required: ["receiptId", "userId", "fieldError", "isResolved"],
    properties: {
      receiptId: { bsonType: "long", description: "Khóa ảo -> PostgreSQL receipts.id" },
      transactionId: { bsonType: ["long", "null"], description: "Khóa ảo -> PostgreSQL transactions.id (nối với ocr_logs)" },
      userId: { bsonType: "long", description: "Khóa ảo -> PostgreSQL users.id" },
      fieldError: { enum: FIELD_KEYS, description: "Trường AI đọc sai: seller_name | total_cost | receipt_date" },
      expectedValue: { bsonType: ["string", "null"], description: "Giá trị đúng người dùng nhập" },
      aiValue: { bsonType: ["string", "null"], description: "Giá trị AI đã đọc" },
      modelVersion: { bsonType: ["string", "null"] },
      isResolved: { bsonType: "bool", description: "Admin đã xử lý chưa (tên khóa thật là isResolved)" },
      reportedAt: { bsonType: ["date", "null"], description: "Lần báo đầu tiên (giữ nguyên khi sửa lại)" },
      updatedAt: { bsonType: ["date", "null"], description: "Lần cuối người dùng sửa lại trường này" }
    }
  }
};

function ensureCollection(name, validator) {
  if (!appDb.getCollectionNames().includes(name)) {
    appDb.createCollection(name);
    print("  + tạo collection " + name);
  } else {
    print("  = collection " + name + " đã có, giữ nguyên dữ liệu");
  }
  // collMod luôn chạy: tạo mới hay đã có thì validator cũng được đặt về đúng nội dung của file này.
  const result = appDb.runCommand({ collMod: name, validator: validator, validationLevel: "moderate", validationAction: "error" });
  if (result.ok !== 1) {
    throw new Error("collMod " + name + " thất bại: " + JSON.stringify(result));
  }
  print("    validator $jsonSchema đã đặt cho " + name);
}

print("\n-- BƯỚC 1: collections + $jsonSchema validator --");
ensureCollection("ocr_logs", OCR_LOGS_VALIDATOR);
ensureCollection("ocr_feedbacks", OCR_FEEDBACKS_VALIDATOR);

// -----------------------------------------------------------------------------
// BƯỚC 2. Index (B-Tree). Tên index = tên Spring Data đặt: @Indexed lấy tên thuộc tính, @CompoundIndex lấy name=.
// -----------------------------------------------------------------------------
print("\n-- BƯỚC 2: index --");

// ocr_logs (OcrRawLog.java)
// Mỗi giao dịch chỉ có một log; tra cứu log theo transactionId (GET /api/admin/ocr-logs) và ghi trùng bị chặn.
appDb.ocr_logs.createIndex({ transactionId: 1 }, { name: "transactionId", unique: true });          // @Indexed(unique = true)
appDb.ocr_logs.createIndex({ averageConfidenceScore: 1 }, { name: "averageConfidenceScore" });      // @Indexed
appDb.ocr_logs.createIndex({ createdAt: 1 }, { name: "createdAt" });                                // @Indexed: lọc khoảng thời gian
// Lọc log AI đọc kém rồi sắp xếp theo thời gian: @CompoundIndex(name = "score_date_idx")
appDb.ocr_logs.createIndex({ averageConfidenceScore: 1, createdAt: -1 }, { name: "score_date_idx" });

// ocr_feedbacks (OcrFeedback.java)
// receipt_field_uq: UNIQUE (receiptId, fieldError) = mỗi cặp hóa đơn + trường đúng một document. Đây là điều kiện
// để upsert của OcrMongoService.upsertCorrection không bao giờ tạo bản trùng khi hai request sửa cùng lúc.
appDb.ocr_feedbacks.createIndex({ receiptId: 1, fieldError: 1 }, { name: "receipt_field_uq", unique: true });  // @CompoundIndex(unique)
// Chú ý trung thực: index đơn receiptId bên dưới là tiền tố của receipt_field_uq nên thực tế dư; vẫn tạo vì
// OcrFeedback.java khai báo @Indexed trên receiptId, để script khớp 1-1 với annotation.
appDb.ocr_feedbacks.createIndex({ receiptId: 1 }, { name: "receiptId" });                           // @Indexed
appDb.ocr_feedbacks.createIndex({ userId: 1 }, { name: "userId" });                                 // @Indexed
// receiptsWithErrorRate nối ocr_logs sang ocr_feedbacks theo transactionId ($lookup): không có index này thì mỗi log là
// một lần quét cả collection.
appDb.ocr_feedbacks.createIndex({ transactionId: 1 }, { name: "transactionId" });                   // @Indexed
appDb.ocr_feedbacks.createIndex({ isResolved: 1 }, { name: "isResolved" });                         // @Indexed
appDb.ocr_feedbacks.createIndex({ reportedAt: 1 }, { name: "reportedAt" });                         // @Indexed
// Danh sách "chưa xử lý, mới nhất trước" (GET /api/admin/ocr-feedbacks?resolved=false): @CompoundIndex(name = "status_date_idx")
appDb.ocr_feedbacks.createIndex({ isResolved: 1, reportedAt: -1 }, { name: "status_date_idx" });

["ocr_logs", "ocr_feedbacks"].forEach(function (name) {
  print("  " + name + ": " + appDb.getCollection(name).getIndexes().map(function (i) { return i.name; }).join(", "));
});

print("\n✅ MongoDB init xong: 2 collection, " +
  (appDb.ocr_logs.getIndexes().length + appDb.ocr_feedbacks.getIndexes().length - 2) + " index (chưa kể _id), 0 document được ghi.");
