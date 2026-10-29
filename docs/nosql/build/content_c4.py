"""Nội dung Chương 4 (Thiết kế CSDL và hệ thống – SDS) – báo cáo NoSQL nhóm 38.

Dựng v3 từ v2: python3 docs/nosql/build/build_version.py v2 v3 content_c4.py 4
Nguồn: mã nguồn nhánh feature/nosql (đoạn mã được cắt nguyên văn từ tệp trong repo lúc dựng, kèm "đường dẫn:dòng"; đoạn
viết lại ghi "rút gọn từ <đường dẫn>"), docs/nosql/bench_results.md (E1–E6), docs/nosql/diagrams/*.png (sơ đồ Task 2),
references.md ([20] trích lần đầu ở 4.0, [21] ở 4.2, [22] ở 4.3, [23] ở 4.4, [24] ở 4.5). Mọi thiết kế cụm (Sentinel, replica
set, shard key, cụm Elasticsearch, RDB/AOF) chỉ ở mức thiết kế: hệ thống chạy mỗi CSDL một node.
"""
import struct
import textwrap
from pathlib import Path

SESSION_TAG = None
SECTIONS = {}
RENUMBER = True

REPO = Path(__file__).resolve().parents[3]
DIAGRAMS = REPO / "docs/nosql/diagrams"
J = "core-backend/src/main/java/vn/edu/huit/finance/core/"
R = "core-backend/src/main/resources/"
TEXT_WIDTH_CM = 15.0


def _size(png):
    with open(png, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def fig(name, caption, key, width_cm=TEXT_WIDTH_CM, max_h_cm=11):
    png = DIAGRAMS / f"{name}.png"
    w, h = _size(png)
    width = min(width_cm, TEXT_WIDTH_CM)
    if max_h_cm is not None:
        width = min(width, max_h_cm * w / h)
    return ("fig", caption, 4, str(png), round(width, 2), None, None, key)


def src(rel, first, last):
    """Các dòng first..last (đánh số từ 1) của một tệp trong repo, nguyên văn, chỉ bỏ phần thụt lề chung."""
    lines = (REPO / rel).read_text(encoding="utf8").splitlines()[first - 1:last]
    return textwrap.dedent("\n".join(lines))


def lead(text):
    """Dòng dẫn của một đoạn mã: nghiêng, căn trái (đường dẫn dài không làm giãn dòng)."""
    return ("lead", text)


def code(rel, first, last, short):
    """Một đoạn mã nguyên văn: dòng dẫn "Mã nguồn (đường dẫn:dòng)" rồi khối MaNguon."""
    path = rel.replace(J, "J/").replace(R, "R/")
    return [lead(f"{short} ({path}:{first}–{last}):"), ("code", src(rel, first, last))]


def short_code(rel, ranges, short):
    """Đoạn mã rút gọn: chỉ giữ các khoảng dòng (mỗi dòng nguyên văn); dòng dẫn ghi "rút gọn từ"."""
    path = rel.replace(J, "J/").replace(R, "R/")
    lines = (REPO / rel).read_text(encoding="utf8").splitlines()
    body = "\n".join("\n".join(lines[x - 1:y]) for x, y in ranges)
    return [lead(f"{short} (rút gọn từ {path}:{ranges[0][0]}–{ranges[-1][1]}):"), ("code", textwrap.dedent(body))]


# Cỡ chữ đoạn mã cho cả quyển (builder_nosql.code_style): 9 pt, phần ngắt dòng thụt treo 0,5 cm.
CODE_FONT_HALF_POINTS = 18
CODE_HANGING_DXA = 284


# --------------------------------------------------------------------------------------------------------------------
# 4.0 Mở chương
# --------------------------------------------------------------------------------------------------------------------

C4_0 = [
    ("p", "Chương này mô tả thiết kế theo khung IEEE 1016 [20], trong đó mỗi góc nhìn thiết kế (viewpoint) trả lời một nhóm "
          "câu hỏi: ngữ cảnh và thành phần (4.1), thông tin và dữ liệu (4.2–4.6), tương tác và trạng thái giữa các CSDL "
          "(4.7–4.8), tài nguyên và bảo mật (4.9), giao diện (4.10), cấu trúc (4.12), cùng mục 4.13 dành cho các kỹ thuật "
          "nâng cao. Quy tắc xuyên suốt: mỗi mẫu truy cập AP-01..AP-38 của mục 3.6 có đúng một cấu trúc dữ liệu đáp ứng, "
          "và mỗi lựa chọn CSDL có lý do gắn với AP hoặc NFR; ma trận ở mục 4.11 kiểm lại điều đó."),
    ("p", "Quy ước trích mã: đoạn mã có ghi số dòng là bản trích nguyên văn; đoạn ghi \"rút gọn từ\" đã bỏ bớt dòng nhưng "
          "giữ nguyên ý nghĩa. Các phần chỉ là thiết kế (chưa chạy) được ghi rõ \"thiết kế\". Trong đường dẫn, J/ viết tắt "
          "cho thư mục mã Java của core-api (dịch vụ Spring Boot, thư mục core-backend) và R/ cho thư mục tài nguyên. "
          "Trong các bảng có cột hẹp, tên CSDL được viết tắt: PG = PostgreSQL, Mongo = MongoDB, ES = Elasticsearch."),
    ("b1", "J/ = core-backend/src/main/java/vn/edu/huit/finance/core/"),
    ("b1", "R/ = core-backend/src/main/resources/"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.1 Kiến trúc tổng thể
# --------------------------------------------------------------------------------------------------------------------

C4_1 = [
    ("p", "[[hinh_kien_truc]] chia hệ thống thành ba tầng. Máy khách (ứng dụng di động Flutter, web quản trị Thymeleaf) đi "
          "qua proxy Caddy. Tầng ứng dụng có core-api (Spring Boot) và ai-service (FastAPI, DONUT V5). Tầng dữ liệu có bốn "
          "CSDL: PostgreSQL là nguồn sự thật, ba hệ NoSQL giữ các bản sao hoặc dữ liệu ngắn hạn mà core-api đọc ghi qua "
          "Spring Data. Mũi tên \"sau commit (async)\" là nguyên tắc chính của thiết kế: không ghi NoSQL nào nằm trong giao "
          "dịch PostgreSQL (mục 4.7)."),
    fig("arch_tong_the", "Kiến trúc tổng thể của LedgerMind", "hinh_kien_truc", 13),
    ("p", "[[hinh_trien_khai]] là sơ đồ triển khai bằng Docker Compose trên một máy, mọi container chung mạng bridge "
          "finance-network; [[bang_thanh_phan]] ghi phiên bản, cổng và giới hạn tài nguyên lấy từ docker-compose.yml."),
    fig("trien_khai", "Sơ đồ triển khai bằng Docker Compose", "hinh_trien_khai", 15),
    ("table", "Thành phần triển khai, phiên bản và vai trò", 4, [1700, 2300, 1900, 2604],
     ["Thành phần", "Image, phiên bản", "Cổng, profile, bộ nhớ", "Vai trò"],
     [
         ["Caddy", "caddy:2.8-alpine", "80, 443; 128 MB", "Proxy ngược, chứng chỉ TLS (Let's Encrypt) cho máy khách"],
         ["core-api", "Spring Boot 3.2.5, Java 21", "Chỉ trong mạng nội bộ; 512 MB",
          "REST dưới /api, web quản trị dưới /admin, SSE; ghi PostgreSQL, rồi đồng bộ NoSQL sau commit"],
         ["ai-service", "FastAPI, DONUT V5", "Chỉ trong mạng nội bộ; 3 GB", "Đọc ảnh hóa đơn, trả JSON (không có độ tin cậy)"],
         ["PostgreSQL", "postgres:15-alpine (15.19)", "127.0.0.1:5432; volume postgres_data",
          "Nguồn sự thật: người dùng, giao dịch, ví, hóa đơn, các lần đọc AI"],
         ["Redis", "redis:8.10-alpine (8.10.2)", "Không mở cổng ra máy chủ; 192 MB, maxmemory 128 MB; không volume",
          "Cache thống kê, OTP, bảng xếp hạng, kênh Pub/Sub"],
         ["MongoDB", "mongo:6.0 (6.0.28)", "127.0.0.1:27017; 512 MB, WiredTiger cache 0,25 GB; volume mongodb_data",
          "Bản sao phân tích: ocr_logs, ocr_feedbacks"],
         ["Elasticsearch", "elasticsearch:8.11.4", "127.0.0.1:9200; profile search; 1 GB, heap 512 MB",
          "Chỉ mục (index) tìm kiếm transactions"],
         ["Kibana", "kibana:8.11.4", "127.0.0.1:5601; profile tools; 1 GB", "Công cụ quản trị Elasticsearch (chỉ bật khi demo)"],
     ], "Nguồn: docker-compose.yml, core-backend/pom.xml", "bang_thanh_phan"),
    ("p", "Elasticsearch và Kibana nằm trong profile riêng nên mặc định không chạy; khi đó SEARCH_ENGINE mặc định là "
          "postgres và tìm kiếm dùng PostgreSQL. Hệ thống chưa được triển khai lên máy chủ nào, nên cấu hình chạy thật "
          "(có bật Elasticsearch hay không) chưa được chốt."),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.2 Lựa chọn loại CSDL
# --------------------------------------------------------------------------------------------------------------------

C4_2 = [
    ("p", "[[bang_ma_tran_csdl]] là ma trận quyết định: mỗi nhóm dữ liệu được gắn với các AP của mục 3.6, CSDL được chọn, "
          "lý do (bằng số đo ở Chương 7 khi có) và phương án đã loại."),
    ("table", "Ma trận lựa chọn loại CSDL", 4, [1700, 1400, 2904, 2500],
     ["Nhóm dữ liệu / AP", "CSDL chọn", "Lý do", "Phương án loại và vì sao"],
     [
         ["Tiền, ví, giao dịch, hóa đơn, lần đọc AI thô (AP-01..AP-04, AP-30, AP-31)", "PG",
          "ACID: khóa ví PESSIMISTIC_WRITE, @Version, clientId duy nhất. JSON thô của AI ở bảng các lần đọc của hóa đơn vì "
          "vòng đời hóa đơn đổi trạng thái hóa đơn và lần đọc trong cùng một giao dịch",
          "MongoDB làm nguồn chính: giao dịch nhiều document cần replica set [10], hệ thống chạy một node"],
         ["Cache thống kê (AP-07..AP-10)", "Redis (String, TTL)",
          "GET p95 0,063 ms, nhanh hơn SQL 39–529× (E4); TTL, allkeys-lru có sẵn; các instance dùng chung (NFR-16)",
          "Cache trong JVM: instance không thấy nhau; MongoDB: tự làm TTL, chậm hơn"],
         ["OTP (AP-05, AP-06)", "Redis (Hash, Lua)",
          "PEXPIRE 5 phút; Lua kiểm tra và đếm lần sai nguyên tử giữa các instance (TC-04)",
          "Bảng PostgreSQL: cần dọn mã hết hạn, khóa dòng"],
         ["Bảng xếp hạng tháng (AP-11..AP-14)", "Redis (Sorted Set)",
          "Top 10 kèm tên p50 0,36 ms so với SQL 23,6 ms (66×, E3); dựng lại được từ PostgreSQL",
          "SQL GROUP BY ở mỗi lần đọc"],
         ["Sự kiện quản trị (AP-15, AP-16)", "Redis (Pub/Sub)",
          "Redis có sẵn; một PUBLISH tới mọi instance (TC-17); p95 phía server 1,6 ms (E6)",
          "Kafka, RabbitMQ: thêm một hệ thống cho thông báo không cần lưu"],
         ["Câu trả lời thô của AI, phản hồi OCR (AP-17..AP-28)", "Mongo (bản sao phân tích)",
          "JSON đổi theo phiên bản mô hình nên lưu nguyên document; thống kê bằng aggregation pipeline; $jsonSchema giữ "
          "phần cố định",
          "PostgreSQL JSONB lưu được, nhưng nhóm tách tải phân tích khỏi CSDL giao dịch và dùng pipeline; MongoDB cũng là "
          "CSDL Document học phần yêu cầu"],
         ["Tìm kiếm giao dịch (AP-29, AP-32..AP-35)", "ES",
          "Chỉ mục đảo, asciifolding, fuzzy, edge_ngram; người dùng nặng p50 3,7 ms so với 78,2 ms, bỏ sót 0 dòng (E2)",
          "PostgreSQL LIKE: không bỏ dấu, \"pho\" bỏ sót 1.376/1.517 dòng (giữ làm dự phòng); full-text của PostgreSQL "
          "có sẵn nhưng bỏ dấu cần extension unaccent và phải tự viết xếp hạng"],
         ["Dòng thời gian, quan hệ nhiều tầng", "Cassandra, Neo4j: không dùng", "Không AP nào cần (mục 4.6)", "–"],
     ], "Số đo E1–E6: Chương 7 và docs/nosql/bench_results.md", "bang_ma_tran_csdl"),
    ("p", "[[hinh_da_csdl]] cho thấy mọi dữ liệu NoSQL đều trỏ về một khóa của PostgreSQL (userId, transactionId, "
          "receiptId, email). Đây là polyglot persistence [2]: mỗi loại dữ liệu nằm ở CSDL hợp với cách nó được đọc."),
    fig("erd_da_csdl", "Mô hình dữ liệu đa CSDL và các khóa nối về PostgreSQL", "hinh_da_csdl", 15, 14),
    ("p", "**So sánh với CQRS.** CQRS tách mô hình ghi và mô hình đọc thành hai mô hình riêng [21]. Elasticsearch và MongoDB "
          "trong đồ án giống phía đọc của CQRS ở chỗ được dựng từ dữ liệu đã ghi và tối ưu cho một kiểu đọc. Tuy vậy, đồ án "
          "không áp dụng CQRS: mọi lệnh ghi và phần lớn lệnh đọc nghiệp vụ vẫn dùng chung mô hình PostgreSQL, còn MongoDB chỉ "
          "là bản sao phân tích phục vụ quản trị viên. Phép so sánh chỉ giúp giải thích vì sao các bản sao này được phép "
          "chậm hơn nguồn một khoảng ngắn."),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.3 Redis
# --------------------------------------------------------------------------------------------------------------------

REDIS_KEYS = [
    ["<prefix>:v1:user-dashboard:<userId>", "String JSON; 45 s", "AP-07, AP-09, AP-10", "GET, SET PX, DEL"],
    ["<prefix>:v1:user-popular-vendors:<userId>", "String JSON; 60 s", "AP-07, AP-09, AP-10", "GET, SET PX, DEL"],
    ["<prefix>:v1:admin-dashboard-summary:<yyyy-MM>:<ngưỡng>", "String JSON; 45 s", "AP-08..AP-10",
     "GET, SET PX; SCAN + DEL"],
    ["<prefix>:v1:admin-statistics:monthly-transactions:<yyyy-MM>:<n>", "String JSON; 60 s", "AP-08..AP-10",
     "GET, SET PX; SCAN + DEL"],
    ["ledgermind:password-reset-otp:<email>", "Hash: code, expiresAt, failedAttempts; 5 phút", "AP-05, AP-06",
     "Lua: DEL, HSET, PEXPIRE; HGET, HINCRBY, DEL"],
    ["ledgermind:leaderboard:\nspend:<yyyy-MM>", "Sorted Set: userId → tổng chi; 62 ngày", "AP-11..AP-14",
     "Lua ZADD/ZREM; ZREVRANGE WITHSCORES; EXPIRE; SCAN + DEL"],
    ["ledgermind:admin-events", "Kênh Pub/Sub, JSON (type, id, message, at); không lưu", "AP-15, AP-16",
     "PUBLISH, SUBSCRIBE"],
]

C4_3 = [
    ("p", "**Quy ước đặt tên khóa.** Mọi khóa bắt đầu bằng ledgermind:<tính năng>:… để cùng một Redis có thể dùng chung cho "
          "nhiều ứng dụng và để SCAN MATCH theo tiền tố xóa đúng một nhóm khóa. Khóa cache có thêm môi trường và phiên bản "
          "lược đồ: <prefix> là ledgermind:<profile Spring đang chạy> (không có profile thì ledgermind:default), sau đó là "
          "v1. Đổi cấu trúc JSON của một cache chỉ cần tăng v1 thành v2, các khóa cũ tự hết hạn. Tiền tố chỉ được chứa "
          "[A-Za-z0-9._:-] vì nó là một phần của mẫu SCAN (J/Config/CacheConfig.java:69-70). Ứng dụng dùng Spring Data Redis "
          "[22] qua RedisCacheManager, StringRedisTemplate và RedisScript, không dùng repository."),
    ("table", "Thiết kế khóa Redis (TTL cache có jitter 10 %)", 4, [3400, 1900, 1000, 2204],
     ["Mẫu khóa", "Kiểu, giá trị, TTL", "AP", "Lệnh chính"], REDIS_KEYS,
     "Nguồn: J/Service/Cache/CacheNames.java, J/Config/CacheConfig.java, R/redis-cache.properties, "
     "J/Service/RedisPasswordResetOtpStore.java, J/Service/Cache/SpendingLeaderboardService.java, "
     "J/Service/Realtime/AdminEventPublisher.java", "bang_redis_keys"),
    ("h3", "Chiến lược cache"),
    ("b1", "**Cache-aside qua @Cacheable:** UserStatisticsService.dashboardOf, popularVendorsOf và hai phương thức của "
           "AdminStatisticsService. Trúng thì trả JSON từ Redis trước khi mở giao dịch PostgreSQL; trượt thì tính từ "
           "PostgreSQL rồi ghi lại (AP-09). Không lưu giá trị null; giá trị là JSON thuần, không kèm kiểu Java."),
    ("b1", "**Xóa cache sau commit:** mỗi lệnh ghi phát StatisticsChangedEvent trong giao dịch; StatisticsCacheEvictor chỉ "
           "chạy khi giao dịch đã commit, nên lần đọc sau luôn thấy số đã commit, còn rollback không xóa gì (TC-08, TC-09). "
           "Enum StatisticsChange quyết định thay đổi nào xóa khóa của một người dùng, thay đổi nào xóa cả một cache."),
    ("b1", "**TTL có jitter:** TTL bị trừ ngẫu nhiên tối đa 10 % để các khóa ghi cùng lúc (sau khi xóa cả cache) không cùng "
           "hết hạn một lúc và dồn tải về PostgreSQL."),
    ("b1", "**Thu hồi bộ nhớ:** maxmemory 128 MB, maxmemory-policy allkeys-lru: hết bộ nhớ thì Redis bỏ khóa ít dùng nhất. "
           "Chính sách này an toàn vì mọi khóa đều dựng lại được (OTP bị bỏ thì người dùng xin mã mới)."),
    ("b1", "**Redis lỗi không làm hỏng request:** FallbackCacheErrorHandler là cơ chế dự phòng (fallback): đọc lỗi coi như "
           "trượt và đọc PostgreSQL, ghi lỗi thì bỏ qua, xóa lỗi thì để khóa tự hết TTL. Lettuce đặt REJECT_COMMANDS nên khi "
           "mất kết nối lệnh hỏng ngay, không chờ hết timeout lệnh 500 ms (TC-10, TC-11)."),
]
C4_3 += code(J + "Config/CacheConfig.java", 162, 169, "TTL có jitter")
C4_3 += [
    ("h3", "Bền vững và sẵn sàng"),
    ("p", "**Không persistence, có chủ đích.** docker-compose.yml chạy Redis với --save '' và --appendonly no, không có "
          "volume, và tắt KEYS, FLUSHALL, FLUSHDB. Lý do: cache và bảng xếp hạng đều dựng lại được từ PostgreSQL; nếu khôi "
          "phục từ một tệp RDB cũ, Redis sẽ trả những số cũ hơn CSDL, còn khởi động rỗng thì lần đọc đầu tự tính lại. Cái giá "
          "là OTP đang chờ bị mất khi Redis khởi động lại, người dùng phải xin mã mới. [[bang_redis_ben_vung]] ghi phương án "
          "cho môi trường thật; đây là thiết kế, chưa chạy."),
    ("table", "Thiết kế bền vững và sẵn sàng cho Redis (chưa triển khai)", 4, [1700, 3404, 3400],
     ["Phương án", "Cấu hình", "Khi nào dùng cho LedgerMind"],
     [
         ["RDB", "save 900 1, tệp dump.rdb trên volume", "Không cần: chỉ để sao lưu thử (Q-29, S-63)"],
         ["AOF", "appendonly yes, appendfsync everysec (mất tối đa khoảng 1 s)",
          "Nếu muốn OTP sống qua lần khởi động lại; khi đó các khóa cache vẫn có TTL nên không trả số cũ lâu"],
         ["Replication + Sentinel", "1 master, 2 replica, 3 sentinel (quorum 2); Lettuce kết nối qua sentinel",
          "Khi cần Redis sẵn sàng cao cho OTP; sao chép bất đồng bộ nên có thể mất vài lệnh ghi cuối khi chuyển master"],
         ["Redis Cluster", "16.384 hash slot chia cho các master",
          "Không cần: dữ liệu dưới 128 MB. Nếu dùng: mỗi script Lua chỉ dùng một khóa (KEYS[1]) nên tương thích; "
          "SCAN phải chạy trên từng node"],
     ], "", "bang_redis_ben_vung"),
    ("h3", "Script Lua"),
    ("p", "Lưu và kiểm tra OTP là hai script Lua; Redis chạy mỗi script một mình, nên đọc mã, so hạn, so mã, tăng số lần sai "
          "và xóa là một bước nguyên tử dù có nhiều instance API (TC-04, Q-27). Hạn 5 phút được đặt hai lần: trường "
          "expiresAt quyết định đúng sai theo đồng hồ của ứng dụng, còn PEXPIRE để Redis tự xóa mã không ai dùng."),
]
C4_3 += code(J + "Service/RedisPasswordResetOtpStore.java", 33, 60, "Hai script Lua của OTP")
C4_3 += [
    ("p", "Script thứ ba cập nhật bảng xếp hạng, được trình bày ở mục 4.13 cùng các cơ chế xử lý tranh chấp."),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.4 MongoDB
# --------------------------------------------------------------------------------------------------------------------

LOG_SAMPLE = """{
  "_id": { "$oid": "…" },
  "transactionId": 1001,
  "rawJsonData": {
    "seller": {
      "seller_name": "Hlghlands C0ffee",
      "address": "TP. Hồ Chí Minh",
      "timestamp": "2026-08-01",
      "total_cost": "35,000",
      "total_cost_number": 35000
    },
    "confidence_score": 0.68
  },
  "modelVersion": "donut-v4",
  "aiReading": {
    "sellerName": "Hlghlands C0ffee",
    "totalCost": "35000",
    "receiptDate": "2026-08-01"
  },
  "averageConfidenceScore": 0.68,
  "createdAt": ISODate("2026-08-01T01:00:00Z")
}"""


MONGO_INDEXES = [
    ["transactionId\n(ocr_logs, unique)", "{transactionId: 1}", "Đơn", "AP-17, AP-38, $lookup của AP-37"],
    ["createdAt (ocr_logs)", "{createdAt: 1}", "Đơn", "AP-24, AP-25, Q-02"],
    ["averageConfidenceScore\n(ocr_logs)", "{averageConfidenceScore: 1}", "Đơn", "AP-38"],
    ["score_date_idx (ocr_logs)", "{averageConfidenceScore: 1, createdAt: -1}", "Ghép", "AP-38 khi điều kiện điểm là bằng (E)"],
    ["receipt_field_uq\n(ocr_feedbacks, unique)", "{receiptId: 1, fieldError: 1}", "Ghép", "AP-18 (chặn bản trùng)"],
    ["status_date_idx\n(ocr_feedbacks)", "{isResolved: 1, reportedAt: -1}", "Ghép (E rồi S)", "AP-19 (Q-03)"],
    ["transactionId\n(ocr_feedbacks)", "{transactionId: 1}", "Đơn", "AP-25 ($lookup từ ocr_logs)"],
    ["userId (ocr_feedbacks)", "{userId: 1}", "Đơn", "Lọc theo người dùng (E5)"],
    ["isResolved, reportedAt\n(ocr_feedbacks)", "{isResolved: 1}, {reportedAt: 1}", "Đơn", "AP-19, AP-22"],
    ["receiptId (ocr_feedbacks)", "{receiptId: 1}", "Đơn", "Dư: là tiền tố của index duy nhất ở trên"],
]

C4_4 = [
    ("p", "Database finance_nosql có hai collection, ánh xạ sang hai lớp Java bằng Spring Data MongoDB [23]: OcrRawLog → "
          "ocr_logs (mỗi giao dịch có hóa đơn một document, ghi sau commit lần đọc đầu tiên), OcrFeedback → ocr_feedbacks "
          "(mỗi cặp hóa đơn + trường bị người dùng sửa đúng một document). [[hinh_mongo_doc]] là cấu trúc hai collection."),
    fig("mongo_document", "Cấu trúc document của ocr_logs và ocr_feedbacks", "hinh_mongo_doc", 12),
    ("h3", "Nhúng hay tham chiếu"),
    ("table", "Quyết định nhúng (embed) hay tham chiếu (reference)", 4, [2100, 1900, 4504],
     ["Quan hệ", "Quyết định", "Lý do"],
     [
         ["ocr_logs → câu trả lời thô của AI", "Nhúng (rawJsonData)",
          "Quan hệ 1–1, luôn đọc cùng nhau, cấu trúc đổi theo mô hình; JSON hỏng được bọc thành {unparsed_raw_string}"],
         ["ocr_logs → kết quả đọc đã chuẩn hóa", "Nhúng (aiReading)",
          "1–1, nhỏ, không bao giờ sửa riêng; dùng để so với chỗ sửa của người dùng mà không phải đọc lại JSON"],
         ["ocr_feedbacks → ocr_logs", "Tham chiếu theo transactionId",
          "Hai document ghi ở hai thời điểm khác nhau, một log có 0..3 chỗ sửa, chỗ sửa còn được cập nhật và xóa riêng. "
          "Thống kê nối bằng $lookup qua index transactionId"],
         ["ocr_feedbacks, ocr_logs → users, receipts, transactions", "Tham chiếu theo id (khóa ảo)",
          "Các thực thể này sống ở PostgreSQL; MongoDB không có khóa ngoại nên tính đúng do ứng dụng giữ"],
     ], "", "bang_embed"),
    ("p", "Bằng chứng cho lựa chọn tham chiếu là E5: trên dữ liệu tổng hợp 100k (sinh bằng gen_data.py), bản nhúng log vào "
          "mỗi feedback chỉ nhanh hơn 2,5× ở p50 khi xem theo một người dùng (0,64 ms so với 1,63 ms), nhưng tốn thêm 12,2 MB "
          "dữ liệu lặp (240 lên 508 byte mỗi document). Con số 871,6 ms của truy vấn Q-13 nguyên bản là giá của một $lookup "
          "đặt muộn: chuyển $sort/$limit lên trước $lookup thì còn 0,75 ms. Nhóm giữ tham chiếu."),
    ("p", "**Mẫu thiết kế đã dùng.** *Computed*: aiReading và averageConfidenceScore được tính một lần lúc ghi (chuẩn hóa tên "
          "quán, tổng tiền, ngày từ JSON thô) thay vì tính lại ở mỗi lần thống kê. *Extended Reference*: ngoài khóa "
          "transactionId, mỗi feedback chép sẵn những trường quản trị viên cần xem (aiValue, modelVersion, userId), nên danh "
          "sách phản hồi và thống kê theo mô hình không cần nối sang ocr_logs. Document mẫu dưới đây là log đầu tiên "
          "của dữ liệu demo (rút gọn từ scripts/nosql/mongodb_demo.js, phần B). Độ tin cậy 0,68 chỉ có trong dữ liệu demo: "
          "câu trả lời thật của DONUT V5 không có trường này nên ứng dụng ghi null (mongodb_demo.js:67)."),
    ("code", LOG_SAMPLE),
    ("h3", "Index và kiểm tra lược đồ"),
    ("p", "Spring không tự tạo index (auto-index-creation tắt); mọi index và validator được tạo bởi scripts/nosql/"
          "mongodb_init.js, gắn vào /docker-entrypoint-initdb.d/ của container và chạy lại được nhiều lần. [[bang_mongo_index]] "
          "đánh giá từng index theo quy tắc ESR (Equality → Sort → Range): status_date_idx đúng thứ tự E rồi S; score_date_idx là R rồi S nên chỉ phục vụ trọn vẹn khi điều kiện trên điểm là so bằng. Không có TTL index: log và phản hồi là dữ liệu phân "
          "tích, được giữ lâu dài."),
    ("table", "Index của MongoDB (không kể _id)", 4, [2900, 3104, 900, 1600],
     ["Tên index (collection)", "Khóa", "Loại", "Phục vụ"], MONGO_INDEXES,
     "Nguồn: scripts/nosql/mongodb_init.js:117-139; J/Document/OcrRawLog.java, J/Document/OcrFeedback.java",
     "bang_mongo_index"),
    ("p", "Validator $jsonSchema dùng validationLevel moderate (document mới luôn bị kiểm tra, document cũ không chặn việc "
          "sửa) và validationAction error (ghi sai kiểu bị từ chối, Q-05). Kiểu BSON khớp với những gì Spring Data ghi "
          "(Long thành long, LocalDateTime thành date); fieldError chỉ nhận ba giá trị của OcrField:"),
]
C4_4 += code("scripts/nosql/mongodb_init.js", 74, 91, "Validator của ocr_feedbacks")
C4_4 += [
    ("h3", "Pipeline và explain()"),
    ("p", "Bốn thống kê của trang quản trị (AP-22..AP-25) là aggregation pipeline chạy bằng MongoTemplate. Đoạn sau là "
          "pipeline tỉ lệ lần đọc bị sửa: $match theo createdAt, $lookup sang ocr_feedbacks theo transactionId (có index), "
          "rồi $project và $group để đếm."),
]
C4_4 += code(J + "Service/OcrMongoService.java", 345, 354, "Pipeline receiptsWithErrorRate")
C4_4 += [
    ("p", "[[bang_explain]] chép kết quả explain(\"executionStats\") của E1 trên dữ liệu tổng hợp 100k (sinh bằng "
          "gen_data.py). Có index thì kế hoạch là IXSCAN và độ trễ p50 giảm 60× đến 106× so với COLLSCAN."),
    ("table", "explain(\"executionStats\") có và không có index (E1)", 4, [1400, 2300, 2000, 1100, 800, 904],
     ["Truy vấn", "Kế hoạch thắng", "Index", "keys / docs", "Trả về", "p50 (ms)"],
     [
         ["Q-01 có index", "LIMIT → PROJECTION → FETCH → IXSCAN", "transactionId", "1 / 1", "1", "0,34"],
         ["Q-01 không index", "LIMIT → PROJECTION → COLLSCAN", "–", "0 / 81.645", "1", "20,7"],
         ["Q-02 có index", "LIMIT → PROJECTION → FETCH → IXSCAN", "createdAt", "61 / 61", "5", "0,43"],
         ["Q-02 không index", "PROJECTION → SORT → COLLSCAN", "–", "0 / 100.000", "5", "45,8"],
         ["Q-03 có index", "LIMIT → PROJECTION → FETCH → IXSCAN", "status_date_idx", "5 / 5", "5", "0,33"],
         ["Q-03 không index", "PROJECTION → SORT → COLLSCAN", "–", "0 / 45.471", "5", "21,8"],
     ], "Nguồn: docs/nosql/bench_results.md, mục E1", "bang_explain"),
    ("p", "Q-02 (độ tin cậy dưới 0,75, mới nhất trước) cho thấy giới hạn của ESR: điều kiện trên điểm là một khoảng (R) còn "
          "thứ tự sắp xếp là createdAt (S). Index score_date_idx đặt R trước S nên vẫn phải sắp xếp trong bộ nhớ và bị bộ lập "
          "kế hoạch bỏ qua; index createdAt cho đúng thứ tự nhưng phải đọc 61 document để trả 5. Vì vậy NFR-05 chỉ đạt một "
          "phần. Index đúng theo ESR cho Q-02 sẽ là {createdAt: -1, averageConfidenceScore: 1} (S rồi R)."),
    ("h3", "Phân tán (thiết kế)"),
    ("table", "Thiết kế replica set và sharding cho MongoDB (chưa triển khai)", 4, [1800, 6704],
     ["Hạng mục", "Thiết kế"],
     [
         ["Replica set", "3 thành viên (1 primary, 2 secondary) trên ba máy; bầu primary mới khi primary chết. Đồng thời "
                         "mở được giao dịch nhiều document và Change Streams (mục 4.7)"],
         ["Write concern", "majority cho ocr_feedbacks (chỗ sửa của người dùng không mất khi đổi primary); mức 1 đủ cho "
                           "ocr_logs vì bản gốc nằm ở PostgreSQL"],
         ["Read preference", "primary cho trang danh sách phản hồi (thấy ngay đánh dấu đã xử lý); secondary preferred cho "
                             "các pipeline thống kê để tách tải phân tích"],
         ["Shard key", "Chưa cần: 100.000 log chỉ chiếm 41,9 MB dữ liệu (E1). Nếu cần: ocr_feedbacks theo {receiptId: 1, "
                       "fieldError: 1}, trùng với receipt_field_uq nên ràng buộc duy nhất còn giữ được trên cụm (index duy "
                       "nhất phải có shard key làm tiền tố); ocr_logs theo {transactionId: 1}. Nhược điểm: id tăng dần dồn "
                       "ghi vào chunk cuối; shard key dạng hashed chia đều hơn nhưng không giữ được unique"],
     ], "", "bang_mongo_cum"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.5 Elasticsearch
# --------------------------------------------------------------------------------------------------------------------

ES_FIELDS = [
    ["userId", "long", "–", "Lọc term theo người gọi (bắt buộc)"],
    ["vendorName", "text + .autocomplete", "vi_folded; vi_autocomplete khi index, vi_folded khi tìm", "Tìm chính xác (^3), tiền tố (^2), mờ"],
    ["note", "text + .autocomplete", "như vendorName", "Tìm chính xác (^2), tiền tố, mờ"],
    ["categoryName", "text + .keyword", "vi_folded; keyword không phân tích", "Tìm; gom nhóm theo danh mục (Q-39)"],
    ["location, paymentMethod", "text", "vi_folded", "Tìm chính xác, mờ"],
    ["amount", "scaled_float ×100", "–", "Sắp xếp, tổng (Q-38..Q-40)"],
    ["expense", "boolean", "–", "Lọc chi/thu"],
    ["transactionDate", "date", "–", "Sắp xếp thứ hai, date_histogram"],
    ["receiptStatus", "keyword", "–", "Hiển thị trạng thái hóa đơn"],
]

C4_5 = [
    ("p", "Elasticsearch giữ một chỉ mục transactions: mỗi document là một giao dịch PostgreSQL (id = transactions.id) cộng "
          "tên quán của hóa đơn, không index các dòng món hàng. Lớp TransactionSearchDocument khai báo @Document với "
          "createIndex = false cùng @Setting, @Mapping trỏ tới hai tệp JSON của ứng dụng (Spring Data Elasticsearch [24]); "
          "chỉ mục chỉ được tạo từ hai tệp đó, không bao giờ để Elasticsearch tự đoán mapping."),
    ("h3", "Settings, analyzer, mapping"),
    ("p", "vi_folded gồm tokenizer standard, lowercase và asciifolding: \"Phở\" và \"pho\" cùng thành token pho, nên người "
          "dùng gõ không dấu vẫn tìm ra. vi_autocomplete thêm edge_ngram 2..15 lúc index để tiền tố \"phu\" khớp \"Phúc "
          "Long\". 1 shard, 0 replica vì cụm chỉ có một node."),
]
C4_5 += code(R + "elasticsearch/transactions-settings.json", 1, 11, "Settings và analyzer")
C4_5 += [
    ("table", "Mapping của chỉ mục transactions", 4, [2100, 1900, 2304, 2200],
     ["Trường", "Kiểu", "Analyzer", "Dùng cho"], ES_FIELDS,
     "Nguồn: R/elasticsearch/transactions-mapping.json:1-32", "bang_es_mapping"),
    ("h3", "Truy vấn"),
    ("p", "Truy vấn thật của GET /api/transactions/search là một bool: filter term userId (người dùng chỉ thấy giao dịch "
          "của mình), cộng hai multi_match trong should với minimum_should_match 1. Nhánh chính xác tìm từ nguyên vẹn và "
          "tiền tố trên các trường .autocomplete, boost 2. Nhánh mờ chỉ chạy trên trường nguyên từ với fuzziness "
          "\"AUTO:4,7\" (từ dưới 4 ký tự không được sai, từ 4 đến 6 ký tự sai 1, từ 7 ký tự trở lên sai 2) và prefix_length 1 (chữ cái đầu "
          "phải đúng). Hai giá trị này là kết quả của E2: với fuzziness AUTO, \"pho\" khớp cả \"chợ\", \"phí\"; không có "
          "prefix_length thì \"tien\" khớp \"dien\". Văn bản người dùng gõ chỉ là giá trị của multi_match, không bao giờ là "
          "query_string, nên không ký tự nào của nó có nghĩa cú pháp với Elasticsearch."),
]
C4_5 += [lead("Hai hằng của nhánh mờ (rút gọn từ J/Service/Search/ElasticsearchTransactionSearchEngine.java:38–41, "
               "bỏ hai dòng chú thích):"),
         ("code", src(J + "Service/Search/ElasticsearchTransactionSearchEngine.java", 39, 39) + "\n"
          + src(J + "Service/Search/ElasticsearchTransactionSearchEngine.java", 41, 41))]
C4_5 += code(J + "Service/Search/ElasticsearchTransactionSearchEngine.java", 51, 73, "Truy vấn bool")
C4_5 += [
    ("p", "Elasticsearch chỉ trả về danh sách id; TransactionSearchService nạp lại các dòng từ PostgreSQL bằng "
          "một truy vấn JPA theo id **và** chủ sở hữu (findAllByIdInAndUserIdWithReceipt, AP-30), nên một document cũ trong chỉ mục không làm "
          "lộ hay hiện sai dữ liệu (TC-37). Elasticsearch lỗi thì cùng request được trả lời bằng PostgreSQL "
          "(searchIdsByText, LOWER(col) LIKE … ESCAPE), trường engine của phản hồi cho biết bên nào đã trả lời (TC-36). Lúc chỉ mục đang được dựng lại, đang nạp hoặc "
          "chưa sẵn sàng (isReindexing, isIndexReady của TransactionSearchIndexer), Elasticsearch chỉ trả được một phần kết quả, "
          "nên yêu cầu đi thẳng sang PostgreSQL."),
    ("h3", "Nhất quán với PostgreSQL"),
    ("b1", "**Sau commit:** TransactionSearchIndexer.onTransactionChanged chạy sau commit trên luồng nền, đọc lại dòng từ "
           "PostgreSQL rồi ghi đè cả document (hoặc xóa), không vá theo nội dung sự kiện, nên sự kiện lặp hay đến muộn đều vô "
           "hại (AP-32). Không có thứ tự giữa các tác vụ: hai tác vụ của cùng một giao dịch chạy xen nhau có thể để lại "
           "document cũ tới lần đổi kế tiếp của dòng đó hoặc lần reindex."),
    ("b1", "**Chặn tự tạo chỉ mục:** action.auto_create_index=false trong docker-compose.yml; một lần ghi gặp index_not_found "
           "thì ứng dụng tạo chỉ mục từ tệp rồi ghi lại đúng một lần (TC-41)."),
    ("b1", "**Thử lại việc tạo chỉ mục:** @Scheduled mỗi 15 s cho tới khi tạo hoặc thấy được chỉ mục một lần; chỉ mục vừa "
           "tạo được nạp nền từ PostgreSQL. @Scheduled này không thử lại các lần cập nhật document bị hỏng."),
    ("b1", "**Dựng lại:** reindexAll xóa chỉ mục, tạo lại từ tệp và nạp bulk 500 dòng một lần, có khóa để lần thứ hai bị từ "
           "chối (409); khôi phục CSDL PostgreSQL thì chỉ mục được dựng lại nền (TC-42). Các trang được đọc theo khóa "
           "(id > id cuối của trang trước), không dùng OFFSET, nên một dòng bị xóa giữa hai trang không làm trang sau bỏ sót "
           "dòng; mỗi trang đọc trong một transaction chỉ đọc rồi xóa persistence context, nên bộ nhớ không tăng theo bảng."),
    ("b1", "**Xóa tài khoản:** các giao dịch đi theo tài khoản qua cascade, không phát sự kiện từng giao dịch; sự kiện "
           "ACCOUNT_DELETED sau commit xóa mọi document của người dùng đó (delete-by-query theo userId) và các ocr_feedbacks "
           "của họ trong MongoDB."),
    ("table", "Thiết kế cụm Elasticsearch (chưa triển khai)", 4, [1800, 6704],
     ["Hạng mục", "Thiết kế"],
     [
         ["Node", "3 node vừa đủ điều kiện làm master vừa giữ dữ liệu; bầu master cần đa số (2/3) nên một node chết cụm "
                  "vẫn chạy"],
         ["Shard", "Giữ 1 primary shard: 100.000 document chỉ 10,9 MB (E2), còn xa cỡ shard khuyến nghị hàng chục GB [14]"],
         ["Replica", "number_of_replicas 1: mỗi shard có một bản sao trên node khác, đọc được chia cho hai bản"],
         ["Sao lưu", "Snapshot vào kho dùng chung cho cả cụm (path.repo trên ổ chung hoặc kho đối tượng); vẫn dựng lại được "
                     "từ PostgreSQL bằng reindex"],
     ], "", "bang_es_cum"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.6 Cassandra và Neo4j
# --------------------------------------------------------------------------------------------------------------------

C4_6 = [
    ("table", "Lý do không dùng Cassandra và Neo4j", 4, [1300, 2604, 4600],
     ["Hệ", "Mạnh nhất khi", "Vì sao LedgerMind không cần"],
     [
         ["Cassandra (Column-family)", "Ghi lớn liên tục, dữ liệu theo thời gian, nhiều trung tâm dữ liệu",
          "Luồng ghi lớn nhất là giao dịch của người dùng (mỗi người vài giao dịch một ngày) và một log AI mỗi hóa đơn; "
          "không AP nào cần partition theo thời gian ở quy mô đó. Cụm Cassandra cần ít nhất 3 node để có RF 3, trong khi "
          "Elasticsearch 1 GB đã chạm giới hạn bộ nhớ của máy (NFR-14)"],
         ["Neo4j (Graph)", "Duyệt quan hệ nhiều tầng: gợi ý, mạng xã hội, phát hiện gian lận",
          "Quan hệ của đồ án nông và một chiều: người dùng → giao dịch → hóa đơn → lần đọc AI. Không AP nào duyệt từ hai "
          "bước quan hệ trở lên; JOIN của PostgreSQL và $lookup một bước của MongoDB là đủ"],
     ], "Đối chiếu với ma trận ở mục 4.2", "bang_khong_dung"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.7 Đồng bộ
# --------------------------------------------------------------------------------------------------------------------

C4_7 = [
    ("p", "**Nguồn sự thật.** [[bang_nguon_su_that]] cho biết bản đúng của từng nhóm dữ liệu nằm ở đâu và bản ở NoSQL được "
          "chữa ra sao khi lệch."),
    ("table", "Nguồn sự thật và cách chữa của từng nhóm dữ liệu", 4, [2200, 1500, 2404, 2400],
     ["Nhóm dữ liệu", "Nguồn sự thật", "Bản ở NoSQL", "Khi bản NoSQL lệch hoặc mất"],
     [
         ["Giao dịch, ví, hóa đơn, lần đọc AI", "PG", "–", "–"],
         ["Thống kê dashboard", "PG", "Redis cache", "Hết TTL 45–60 s, hoặc lần ghi kế tiếp xóa khóa"],
         ["Tổng chi tháng", "PG", "Redis ZSET", "Lần đổi kế tiếp của người đó; hết TTL 62 ngày; quản trị viên "
                                                       "dựng lại"],
         ["Văn bản tìm kiếm", "PG", "Chỉ mục ES", "Lần đổi kế tiếp của dòng đó; reindex"],
         ["Câu trả lời thô của AI", "PG (bảng các lần đọc)", "Mongo ocr_logs",
          "Không tự chữa (chỉ log lỗi)"],
         ["Chỗ người dùng sửa AI", "Suy ra từ thay đổi trên PG", "Mongo ocr_feedbacks",
          "Không tự chữa; lần sửa kế tiếp của cùng hóa đơn ghi lại trường đó"],
         ["OTP đặt lại mật khẩu", "Redis (dữ liệu ngắn hạn, không có bản ở nơi khác)", "–",
          "Mất khi Redis khởi động lại; người dùng xin mã mới"],
     ], "", "bang_nguon_su_that"),
    ("p", "**Cơ chế đồng bộ.** Mọi lệnh ghi phát một sự kiện Spring trong giao dịch PostgreSQL (TransactionChangedEvent, "
          "StatisticsChangedEvent, OcrProcessedEvent, OcrCorrectionEvent, ReceiptWaitingReviewEvent). Các bộ nghe khai báo "
          "@TransactionalEventListener(AFTER_COMMIT), phần lớn kèm @Async(\"mongoAsyncExecutor\"): chúng chỉ chạy khi giao "
          "dịch đã commit, trên một luồng nền, nên rollback không để lại gì ở NoSQL và CSDL NoSQL chậm hay chết không giữ "
          "request của người dùng. Luồng đồng bộ chỉ mục đã vẽ ở sơ đồ tuần tự của mục 3.3.2."),
    ("table", "Sự kiện sau commit và lớp xử lý", 4, [3000, 3104, 1300, 1100],
     ["Sự kiện", "Lớp xử lý", "Đích", "Kiểm thử"],
     [
         ["StatisticsChangedEvent", "StatisticsCacheEvictor (chạy ngay sau commit, không qua luồng nền)", "Redis cache",
          "TC-08, TC-09"],
         ["TransactionChangedEvent", "SpendingLeaderboardService", "Redis ZSET", "TC-14, TC-15"],
         ["TransactionChangedEvent", "TransactionSearchIndexer", "ES", "TC-38, TC-39, TC-40"],
         ["OcrProcessedEvent", "OcrMongoService", "Mongo (log)", "TC-23, TC-30"],
         ["OcrCorrectionEvent", "OcrMongoService", "Mongo (phản hồi); Pub/Sub", "TC-20, TC-21, TC-22"],
         ["ReceiptWaitingReviewEvent", "AdminEventPublisher", "Redis Pub/Sub", "TC-17"],
     ], "Mỗi lớp xử lý bằng một phương thức @TransactionalEventListener(AFTER_COMMIT)", "bang_su_kien"),
    ("p", "**Vì sao không dùng Outbox, Change Streams hay hàng đợi tin nhắn.** [[bang_so_sanh_dong_bo]] so sánh các cơ chế mà "
          "đề cương gợi ý [7]."),
    ("table", "So sánh các cơ chế đồng bộ", 4, [1700, 3404, 3400],
     ["Cơ chế", "Ưu điểm", "Vì sao chưa dùng"],
     [
         ["Outbox", "Ghi sự kiện vào bảng outbox trong cùng giao dịch, một tiến trình chuyển đi sau: không mất sự kiện khi "
                    "JVM chết", "Cần bảng, tiến trình chuyển, đánh dấu đã gửi và xử lý gửi lặp; là hướng phát triển đầu tiên "
                                "để đóng cửa sổ mất dữ liệu bên dưới"],
         ["MongoDB Change Streams", "Đọc luồng thay đổi của MongoDB",
          "Nguồn thay đổi ở đây là PostgreSQL, không phải MongoDB; Change Streams còn cần replica set"],
         ["Hàng đợi (Kafka, RabbitMQ)", "Bền, phát lại được, nhiều bên nhận",
          "Thêm một hệ thống cần bộ nhớ trên một máy nhỏ (Elasticsearch 1 GB đã không còn dư, NFR-14)"],
         ["Sự kiện sau commit (đang dùng)", "Không thêm hạ tầng; rollback không rò rỉ; NoSQL lỗi không làm hỏng nghiệp vụ",
          "Có cửa sổ mất dữ liệu (dưới đây)"],
     ], "", "bang_so_sanh_dong_bo"),
    ("p", "**Cửa sổ mất dữ liệu và cách chữa.** Ghi NoSQL là sau commit, bất đồng bộ, nhất quán cuối cùng. Nếu JVM chết giữa "
          "lúc PostgreSQL commit và lúc tác vụ nền chạy xong, thay đổi đó không tới NoSQL. Cache tự chữa khi hết TTL; bảng xếp "
          "hạng và chỉ mục được chữa ở lần đổi kế tiếp của cùng dòng, khi dựng lại hoặc reindex (vì luôn ghi giá trị tuyệt "
          "đối đọc từ PostgreSQL); log OCR và chỗ sửa OCR bị mất thì không có cơ chế tự chữa. Hai trường hợp khác cũng làm "
          "mất một lần ghi: hàng đợi của mongoAsyncExecutor đầy (500 tác vụ) thì tác vụ bị bỏ và ghi cảnh báo; một lần cập "
          "nhật chỉ mục bị hỏng thì không được thử lại."),
    ("p", "**Khi một CSDL lỗi.** Redis sập: thống kê vẫn trả lời bằng PostgreSQL, mỗi request tốn thêm tối đa timeout kết nối "
          "1 s hoặc lệnh 500 ms (NFR-07); OTP cố ý báo lỗi rõ ràng vì mã không lưu được thì không được gửi. Elasticsearch "
          "sập: tìm kiếm vẫn trả lời bằng PostgreSQL với engine=postgres (NFR-08). MongoDB sập: ghi giao dịch và hóa đơn vẫn "
          "thành công, luồng nền chờ tối đa 5 s (serverSelectionTimeoutMS=5000) rồi ghi log (NFR-09)."),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.8 Phân tán, sao chép, CAP
# --------------------------------------------------------------------------------------------------------------------

C4_8 = [
    ("p", "Hiện mỗi CSDL chạy một node nên không có phân vùng mạng giữa các bản sao: một CSDL dừng thì phần việc của nó dừng "
          "(và được xử lý như mục 4.7). Cột thiết kế dưới đây đặt mỗi hệ vào định lý CAP [4], [5] và mở rộng PACELC [6] (khi "
          "không có phân vùng thì chọn giữa độ trễ L và nhất quán C) cho trường hợp triển khai cụm."),
    ("table", "Phân tán, sao chép và vị trí CAP/PACELC", 4, [1600, 1300, 1900, 1400, 2304],
     ["CSDL", "Hiện tại", "Thiết kế cụm", "Phân mảnh", "CAP / PACELC (thiết kế)"],
     [
         ["PG", "1 node, volume", "Primary + standby sao chép đồng bộ", "Không", "CP; PC/EC: nguồn sự thật, ưu tiên "
                                                                                        "nhất quán"],
         ["Redis", "1 node, không lưu đĩa", "1 master + 2 replica + 3 Sentinel", "Không (Cluster 16.384 slot nếu cần)",
          "AP; PA/EL: sao chép bất đồng bộ, chấp nhận mất vài lệnh ghi cuối"],
         ["Mongo", "1 node đơn", "Replica set 3 thành viên, write concern majority", "Chưa cần (mục 4.4)",
          "CP (PC/EC) khi dùng write/read concern majority"],
         ["ES", "1 node, 1 shard, 0 replica", "3 node, 1 replica mỗi shard", "1 primary shard đủ",
          "Bầu master theo đa số (nghiêng về C); PA/EL cho đọc: bản sao có thể chậm một nhịp refresh"],
     ], "Hiện tại theo docker-compose.yml; cột thiết kế chưa triển khai", "bang_cap"),
    ("p", "Lựa chọn này khớp với vai trò dữ liệu: chỉ PostgreSQL giữ tiền nên cần nhất quán mạnh; ba hệ NoSQL giữ bản sao "
          "hoặc dữ liệu ngắn hạn, nên ưu tiên sẵn sàng và độ trễ, chấp nhận nhất quán cuối cùng như đã đóng băng ở NFR-10."),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.9 Bảo mật, sao lưu, giám sát
# --------------------------------------------------------------------------------------------------------------------

C4_9 = [
    ("table", "Thiết kế bảo mật", 4, [1600, 4504, 2400],
     ["Lớp", "Biện pháp", "Kiểm chứng"],
     [
         ["Xác thực", "API di động: JWT không trạng thái, danh sách thu hồi trong PostgreSQL (revoked_tokens). Web quản trị: "
                      "form login và phiên HTTP, khóa tài khoản khi đăng nhập sai nhiều lần", "TC-45"],
         ["Phân quyền", "Hai lớp: SecurityConfig chỉ cho ROLE_ADMIN vào /admin/… và /api/admin/…, controller quản trị thêm "
                        "@PreAuthorize; luồng SSE /admin/events cũng chỉ ROLE_ADMIN và kết thúc cùng phiên đăng nhập",
          "TC-19, TC-31"],
         ["CSRF (lỗ hổng còn mở)", "Chuỗi bảo mật của web quản trị tắt CSRF (J/Config/SecurityConfig.java:76), nên các form "
                                   "POST như xóa phản hồi, khôi phục sao lưu không có token chống giả mạo yêu cầu. Cần bật "
                                   "lại CSRF cho web quản trị trước khi triển khai", "Chưa có"],
         ["TLS", "Caddy cấp chứng chỉ và phục vụ HTTPS cho máy khách; trong mạng nội bộ Docker, kết nối tới các CSDL không "
                 "mã hóa (HTTP TLS của Elasticsearch tắt)", "docker-compose.yml"],
         ["Mạng, mật khẩu CSDL", "Redis không mở cổng ra máy chủ, có requirepass, tắt KEYS/FLUSHALL/FLUSHDB; MongoDB, "
                                 "Elasticsearch, PostgreSQL chỉ mở trên 127.0.0.1 và có mật khẩu; Elasticsearch bật "
                                 "security (user elastic)", "NFR-12"],
         ["Chống injection Mongo", "Kiểu tấn công thường gặp là gửi một object có toán tử (ví dụ {\"$ne\": null}) vào chỗ "
                                     "một giá trị. Ứng dụng không ghép chuỗi JSON truy vấn và không dùng $where: bộ lọc là "
                                     "Criteria của Spring Data với tham số đã có kiểu (OcrField enum, Boolean, LocalDate), "
                                     "sort chỉ nhận reportedAt hoặc updatedAt theo biểu thức chính quy, nên giá trị người "
                                     "dùng luôn là một giá trị BSON, không thành toán tử", "TC-24"],
         ["Chống injection ES, SQL", "Văn bản tìm kiếm là giá trị của multi_match, không dùng query_string; SQL "
                                                "dùng tham số JPQL, mẫu LIKE được thoát \\ % _ bằng ESCAPE", "TC-43"],
         ["Cách ly dữ liệu", "Tìm kiếm lọc userId ở Elasticsearch rồi nạp lại theo chủ sở hữu ở PostgreSQL; khóa cache "
                             "theo userId", "TC-07, TC-35, TC-37, TC-44"],
     ], "", "bang_bao_mat"),
    ("table", "Sao lưu và khôi phục từng CSDL", 4, [1300, 2604, 1700, 2900],
     ["CSDL", "Công cụ, cách chạy", "Tần suất", "Khôi phục"],
     [
         ["PG", "pg_dump từ trang /admin/backup", "Thủ công; thiết kế: hằng ngày",
          "pg_restore; sau khôi phục phát DATABASE_RESTORED để xóa cache, bảng xếp hạng và dựng lại chỉ mục"],
         ["Mongo", "mongodump --archive --gzip từ /admin/backup (POST /admin/backup/mongo/execute)",
          "Thủ công; thiết kế: hằng ngày", "mongorestore --drop hai collection; 0,543 s với dữ liệu demo (NFR-13)"],
         ["Redis", "Không sao lưu (dữ liệu dựng lại được); RDB chỉ để minh họa (Q-29)", "–", "Khởi động rỗng, tự dựng lại"],
         ["ES", "Snapshot vào path.repo (script, Kibana)", "Thủ công", "Restore snapshot, hoặc reindex từ "
                                                                                   "PostgreSQL"],
     ], "Lệnh chi tiết: mục 5.6 và scripts/nosql/backup_restore.md", "bang_sao_luu"),
    ("p", "**Giám sát.** core-api có Spring Boot Actuator; health của Redis, MongoDB và Elasticsearch được tắt có chủ đích, "
          "để một CSDL NoSQL sập không làm container core-api bị coi là hỏng (ứng dụng vẫn chạy bằng PostgreSQL). Lỗi của "
          "từng CSDL được ghi log một dòng mỗi lần (không in stack trace cho mỗi request khi Redis sập). Công cụ xem trực tiếp: "
          "Kibana, Compass, RedisInsight. Thu thập số liệu bằng Prometheus và Grafana là hướng phát triển."),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.10 Module và API
# --------------------------------------------------------------------------------------------------------------------

C4_10 = [
    ("table", "Module của core-api theo CSDL", 4, [1600, 4404, 1100, 1400],
     ["Gói (J/…)", "Lớp chính", "CSDL", "FR"],
     [
         ["Service", "TransactionService, ReceiptProcessingService, AuthService", "PG", "FR-01..FR-06"],
         ["Service, Service/Cache", "UserStatisticsService, AdminStatisticsService (@Cacheable), StatisticsCacheEvictor, "
                                    "SpendingLeaderboardService", "Redis", "FR-07, FR-09, FR-10"],
         ["Service", "RedisPasswordResetOtpStore", "Redis", "FR-02"],
         ["Service/Realtime", "AdminEventPublisher, AdminEventRelay, AdminEventSubscription", "Redis Pub/Sub", "FR-16"],
         ["Service", "OcrMongoService, MongoBackupService, OcrCorrectionDetector", "Mongo", "FR-05, FR-06, FR-11..FR-13, "
                                                                                              "FR-15"],
         ["Service/Search", "TransactionSearchService, ElasticsearchTransactionSearchEngine, TransactionSearchIndexer",
          "ES, PG", "FR-08, FR-14"],
         ["Config", "CacheConfig, FallbackCacheErrorHandler, AsyncConfig, RealtimeConfig, SearchConfig, SecurityConfig",
          "Cấu hình", "–"],
     ], "Sơ đồ lớp: mục 4.12; sơ đồ tuần tự tìm kiếm, sửa kết quả OCR, bảng xếp hạng và đồng bộ chỉ mục: mục 3.3.2", "bang_module"),
    ("p", "[[bang_api_ap]] là thiết kế API theo AP: mỗi endpoint ghi CSDL được gọi và mẫu truy cập nó thực hiện (danh sách "
          "theo vai trò và FR đã có ở mục 3.7)."),
    ("table", "Thiết kế API theo mẫu truy cập", 4, [1200, 2604, 2000, 1700, 1000],
     ["HTTP", "Endpoint", "Mô tả", "CSDL", "AP"],
     [
         ["POST", "/api/auth/forgot-password", "Sinh OTP, lưu bằng Lua, gửi email", "Redis, PG", "AP-05"],
         ["POST", "/api/auth/reset-password", "Kiểm tra OTP bằng Lua, đổi mật khẩu", "Redis, PG", "AP-06"],
         ["POST", "/api/transactions/checkout", "Khóa ví, chống trùng clientId, ghi; sau commit đồng bộ NoSQL",
          "PG → Redis, Mongo, ES", "AP-02, AP-10, AP-13, AP-17, AP-32"],
         ["PUT,\nDELETE", "/api/transactions/{id}", "Sửa, xóa; sau commit đồng bộ", "PG → Redis, ES",
          "AP-03, AP-10, AP-13, AP-32"],
         ["GET", "/api/transactions/search", "Tìm theo từ khóa, nạp lại theo chủ", "ES (hoặc PG) + PG",
          "AP-29, AP-30, AP-31"],
         ["GET", "/api/transactions/app-dashboard", "Dashboard qua cache", "Redis / PG", "AP-07, AP-09"],
         ["PUT", "/api/receipts/{id}", "Sửa hóa đơn có khóa lạc quan; sinh chỗ sửa OCR", "PG → Mongo, ES, Pub/Sub",
          "AP-04, AP-18, AP-15"],
         ["GET", "/api/admin/ocr-feedbacks", "Lọc, sắp xếp, phân trang phản hồi", "Mongo", "AP-19"],
         ["PATCH,\nDELETE", "/api/admin/ocr-feedbacks/{id}/resolve, /api/admin/ocr-feedbacks/{id}", "Đánh dấu đã xử lý, xóa",
          "Mongo", "AP-20, AP-21"],
         ["GET", "/api/admin/ocr-feedbacks/analytics", "Bốn thống kê bằng pipeline", "Mongo", "AP-22..AP-25"],
         ["GET", "/api/admin/ocr-logs", "Một trang log thô", "Mongo", "AP-26"],
         ["GET, POST", "/api/admin/leaderboard, /api/admin/leaderboard/rebuild", "Top N tháng; dựng lại", "Redis, PG",
          "AP-11, AP-12"],
         ["POST", "/api/admin/search/reindex", "Dựng lại chỉ mục", "ES, PG; Pub/Sub", "AP-33, AP-15"],
         ["POST", "/admin/backup/mongo/execute, /admin/backup/mongo/restore", "Sao lưu, khôi phục MongoDB", "Mongo",
          "AP-27, AP-28"],
         ["GET", "/admin/events", "Luồng SSE sự kiện quản trị", "Redis Pub/Sub", "AP-16"],
     ], "", "bang_api_ap"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.11 Ma trận AP → thiết kế
# --------------------------------------------------------------------------------------------------------------------

AP_DESIGN_ROWS = [  # đủ 38 dòng; Task 9 nhập hằng này cho Phụ lục B
    ["AP-01", "PG", "users, revoked_tokens", "đọc user; existsByTokenHash"],
    ["AP-02", "PG", "transactions, users; ràng buộc duy nhất (user_id, client_id)", "khóa PESSIMISTIC_WRITE; "
                                                                                   "findByUserIdAndClientId; INSERT"],
    ["AP-03", "PG", "transactions, khóa ví", "UPDATE / DELETE"],
    ["AP-04", "PG", "receipts (cột version), bảng các lần đọc", "UPDATE … WHERE version = ?"],
    ["AP-05", "Redis", "Hash ledgermind:password-reset-otp:<email>", "Lua DEL + HSET + PEXPIRE"],
    ["AP-06", "Redis", "Hash OTP", "Lua HGET, HINCRBY, DEL"],
    ["AP-07", "Redis", "String JSON user-dashboard, user-popular-vendors", "GET"],
    ["AP-08", "Redis", "String JSON admin-dashboard-summary, admin-statistics", "GET"],
    ["AP-09", "PG + Redis", "SQL thống kê → khóa cache", "SELECT; SET PX (TTL có jitter)"],
    ["AP-10", "Redis", "Khóa cache theo userId hoặc cả cache", "DEL; SCAN MATCH + DEL (lô 500)"],
    ["AP-11", "Redis (+ PG)", "ZSET của tháng (khóa ở mục 4.3)", "ZREVRANGE 0 N-1 WITHSCORES; "
                                                                                     "findAllById"],
    ["AP-12", "PG + Redis", "ZSET tháng", "sumExpensesByUserBetween → ZADD → EXPIRE 62 ngày"],
    ["AP-13", "PG + Redis", "ZSET tháng", "sumExpensesBetween → Lua EXISTS, ZADD/ZREM"],
    ["AP-14", "Redis", "Mọi ZSET tháng", "SCAN MATCH theo tiền tố bảng xếp hạng + DEL"],
    ["AP-15", "Redis", "Kênh ledgermind:admin-events", "PUBLISH"],
    ["AP-16", "Redis → SSE", "Kênh + SseEmitter", "SUBSCRIBE; GET /admin/events"],
    ["AP-17", "Mongo", "ocr_logs, unique transactionId", "insert"],
    ["AP-18", "Mongo", "ocr_feedbacks, unique receipt_field_uq", "updateFirst có điều kiện; upsert $setOnInsert; remove"],
    ["AP-19", "Mongo", "ocr_feedbacks, status_date_idx", "find + count, sort, skip/limit"],
    ["AP-20", "Mongo", "ocr_feedbacks theo _id", "findAndModify ($set isResolved)"],
    ["AP-21", "Mongo", "ocr_feedbacks theo _id", "deleteById"],
    ["AP-22", "Mongo", "ocr_feedbacks, index reportedAt", "$match → $group fieldError → $sort"],
    ["AP-23", "Mongo", "ocr_feedbacks", "$match → $group modelVersion"],
    ["AP-24", "Mongo", "ocr_logs, index createdAt", "$match → $project $dateToString → $group $avg"],
    ["AP-25", "Mongo", "ocr_logs → ocr_feedbacks (index transactionId)", "$match → $lookup → $project → $group"],
    ["AP-26", "Mongo", "ocr_logs", "findAll(pageable)"],
    ["AP-27", "Mongo", "database finance_nosql", "mongodump --archive --gzip"],
    ["AP-28", "Mongo", "ocr_logs, ocr_feedbacks", "mongorestore --drop --nsInclude"],
    ["AP-29", "ES", "index transactions, vi_folded, .autocomplete", "bool: filter term userId + 2 multi_match"],
    ["AP-30", "PG", "transactions JOIN FETCH receipts", "SELECT theo danh sách id và userId (mục 4.5)"],
    ["AP-31", "PG", "transactions", "searchIdsByText: LOWER(col) LIKE … ESCAPE"],
    ["AP-32", "PG + ES", "document theo transactions.id", "findForSearchIndex → save / delete"],
    ["AP-33", "PG + ES", "index transactions", "xóa → tạo từ tệp → bulk 500 → refresh"],
    ["AP-34", "ES", "index transactions", "exists / createWithMapping"],
    ["AP-35", "ES", "index transactions", "_count"],
    ["AP-36", "ES", "categoryName.keyword, transactionDate", "terms + sum; date_histogram (chỉ trong script)"],
    ["AP-37", "Mongo", "ocr_feedbacks → ocr_logs (index transactionId)", "$lookup; $facet (chỉ trong script)"],
    ["AP-38", "Mongo", "ocr_logs: transactionId, createdAt, score_date_idx", "findOne {transactionId}; find điểm < "
                                                                                 "ngưỡng + sort (chỉ trong script)"],
]

AP_SAMPLE = ("AP-02", "AP-07", "AP-11", "AP-19", "AP-29", "AP-37")

C4_11 = [
    ("p", "Quy tắc của chương là cả 38 mẫu truy cập đều có một cấu trúc dữ liệu và một lệnh đáp ứng. [[bang_ap_thiet_ke]] "
          "trích sáu dòng, mỗi CSDL ít nhất một dòng và một dòng chỉ có trong script (AP-36..AP-38 chưa có API dùng); toàn "
          "bộ 38 dòng ở Phụ lục B."),
    ("table", "Ma trận ánh xạ AP → thiết kế (trích)", 4, [900, 1100, 3300, 3204],
     ["AP", "CSDL", "Cấu trúc đáp ứng", "Truy vấn / lệnh"], [r for r in AP_DESIGN_ROWS if r[0] in AP_SAMPLE],
     "AP đóng băng ngày 27/10/2026 (mục 3.6); đủ 38 dòng: Phụ lục B", "bang_ap_thiet_ke"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.12 Mô hình hóa cấu trúc
# --------------------------------------------------------------------------------------------------------------------

C4_12 = [
    ("p", "[[hinh_lop]] là sơ đồ lớp của phần dữ liệu: các lớp dịch vụ và cấu trúc chúng đọc ghi, phân biệt nơi lưu bằng "
          "stereotype «Table» (PostgreSQL), «Document» (MongoDB), «EsDocument» (Elasticsearch) và «RedisKey» (Redis)."),
    fig("lop_nosql", "Sơ đồ lớp: dịch vụ và cấu trúc dữ liệu theo CSDL", "hinh_lop", 15, 14),
    ("p", "Phần dữ liệu quan hệ vẫn là nguồn sự thật nên vẫn có ERD vật lý ([[hinh_erd_pg]]); thiết kế vật lý của ba hệ NoSQL "
          "đã trình bày ở các mục 4.3–4.5, mô hình khái niệm ở mục 3.5."),
    fig("erd_postgres", "ERD PostgreSQL của phần dữ liệu liên quan", "hinh_erd_pg", 15),
    ("table", "Ánh xạ thực thể sang lớp Java", 4, [1000, 1800, 2600, 3104],
     ["CSDL", "Thư viện", "Annotation, API thật", "Lớp → nơi lưu"],
     [
         ["PG", "Spring Data JPA (Hibernate)", "@Entity, @Table với uniqueConstraints (@UniqueConstraint), @Version, "
                                                      "@Audited", "Transaction → transactions; Receipt → receipts"],
         ["Mongo", "Spring Data MongoDB [23]", "@Document(collection), @Id, @Indexed(unique = true), @CompoundIndex, "
                                                 "@CreatedDate, lớp lồng AiReading", "OcrRawLog → ocr_logs; OcrFeedback → "
                                                                                     "ocr_feedbacks"],
         ["ES", "Spring Data Elasticsearch [24]", "@Document với indexName và createIndex = false; @Setting, "
                                                             "@Mapping, @Field(type)",
          "TransactionSearchDocument → index transactions"],
         ["Redis", "Spring Data Redis [22]", "Không có lớp thực thể: RedisCacheManager + @Cacheable (JSON qua Jackson), "
                                             "StringRedisTemplate + RedisScript, convertAndSend",
          "AppDashboardResponseDto → user-dashboard; TopSpenderDto ← ZSET"],
     ], "", "bang_anh_xa"),
]

# --------------------------------------------------------------------------------------------------------------------
# 4.13 Kỹ thuật nâng cao
# --------------------------------------------------------------------------------------------------------------------

C4_13 = [
    ("p", "Mỗi kỹ thuật dưới đây có trong mã nguồn và được trình bày theo bốn ý: vấn đề, đoạn mã, bằng chứng trước/sau, "
          "kiểm thử chứng minh. Số đo E1–E6 là độ trễ tầng dữ liệu trên dữ liệu tổng hợp 100k (sinh bằng gen_data.py), "
          "riêng E6 là chặng server, bài đo JUnit."),
    ("h3", "Đa luồng: @Async và @TransactionalEventListener"),
    ("p", "**Vấn đề.** Nếu ghi MongoDB, Redis, Elasticsearch ngay trong request, một CSDL NoSQL chậm hoặc sập sẽ giữ request "
          "và kết nối PostgreSQL của người dùng (MongoDB sập: chờ tới 5 s rồi lỗi, theo serverSelectionTimeoutMS), còn ghi "
          "trước khi commit thì một lần rollback để lại dữ liệu ma ở NoSQL."),
    ("p", "**Giải pháp.** Bộ nghe chỉ chạy sau commit, trên pool mongoAsyncExecutor (5 luồng thường trực, tối đa 20, hàng đợi "
          "500); hàng đợi đầy thì bỏ tác vụ và ghi cảnh báo thay vì ném lỗi về luồng đã commit."),
]
C4_13 += code(J + "Service/OcrMongoService.java", 98, 100, "Bộ nghe ghi ocr_logs")
C4_13 += short_code(J + "Config/AsyncConfig.java", [(23, 26), (29, 30)], "Pool luồng nền")
C4_13 += [
    ("p", "**Bằng chứng và kiểm thử.** Trước: không có số đo độ trễ của kiểu ghi đồng bộ (thiết kế cũ không được dựng lại để "
          "đo); con số 5 s là cận trên suy từ cấu hình. Sau: lớp StatisticsCacheTransactionTest chứng minh cache chỉ bị xóa "
          "sau commit và rollback không xóa gì (TC-08, TC-09); lớp OcrMongoServiceTest (TC-30) và một phương thức của lớp "
          "TransactionSearchIndexerIntegrationTest (TC-40, tên phương thức ở khối dưới) chứng minh CSDL NoSQL lỗi chỉ sinh log, không ném "
          "lỗi về luồng gọi."),
    ("code", "TransactionSearchIndexerIntegrationTest\n    .esDown_listenerLogsAndDoesNotThrow()"),
    ("p", "**Giới hạn.** Pool có tới 20 luồng và không có thứ tự hay kiểm tra phiên bản giữa các tác vụ. Bộ nghe của bảng xếp "
          "hạng và của chỉ mục đọc lại PostgreSQL rồi mới ghi, nên sự kiện lặp hay đến muộn đều vô hại; nhưng hai tác vụ của "
          "cùng một dòng chạy xen nhau thì tác vụ đọc trước có thể ghi sau, để lại giá trị cũ tới lần đổi kế tiếp của người "
          "dùng hoặc dòng đó, khi hết TTL, khi dựng lại hoặc reindex."),
    ("h3", "Tác vụ nền @Scheduled"),
    ("p", "**Vấn đề.** Elasticsearch có thể khởi động chậm hơn core-api. Khi đó lần tạo chỉ mục lúc khởi động thất bại; vì "
          "auto_create_index tắt, mọi lần ghi sau đó sẽ hỏng cho tới khi có người khởi động lại ứng dụng."),
    ("p", "**Giải pháp.** Một tác vụ @Scheduled chạy mỗi 15 s, chỉ làm việc khi chỉ mục chưa được thấy hoặc tạo, rồi tự "
          "ngừng. Một tác vụ khác gửi dòng chú thích heartbeat mỗi 25 s trên các luồng SSE để proxy không đóng luồng nhàn "
          "rỗi và để dọn các trình duyệt đã đóng."),
]
C4_13 += code(J + "Service/Search/TransactionSearchIndexer.java", 131, 137, "Thử lại việc tạo chỉ mục")
C4_13 += [
    ("p", "**Bằng chứng và kiểm thử.** Trước: lần tạo hỏng lúc khởi động không được thử lại. Sau: một phương thức của lớp "
          "TransactionSearchIndexerIntegrationTest (tên phương thức ở khối dưới) chứng minh tác vụ thử cho tới khi chỉ mục có rồi dừng; "
          "TC-41 chứng minh chỉ mục luôn được tạo từ mapping của ứng dụng, không phải mapping động."),
    ("code", "TransactionSearchIndexerIntegrationTest\n    .indexCheck_retriesUntilTheIndexExists_thenStops()"),
    ("h3", "Xử lý tranh chấp"),
    ("table", "Năm cơ chế xử lý tranh chấp", 4, [1600, 2800, 2304, 1800],
     ["Tranh chấp", "Cơ chế", "Kết quả khi hai yêu cầu đến cùng lúc", "Kiểm thử"],
     [
         ["Hai cập nhật tổng chi của một người dùng",
          "Lua EXISTS → ZADD/ZREM với tổng tuyệt đối đọc từ PostgreSQL, không ZINCRBY",
          "Sự kiện lặp hay đến muộn vô hại; hai tác vụ chạy xen nhau có thể để lại tổng cũ tới lần đổi sau, hết TTL hoặc "
          "dựng lại", "TC-14, TC-15"],
         ["Hai luồng cùng tạo chỗ sửa OCR", "updateFirst có điều kiện, rồi upsert chỉ với $setOnInsert; unique "
                                            "receipt_field_uq",
          "Đúng một document mỗi (hóa đơn, trường); luồng thua bị index chặn và chỉ ghi log", "TC-20, TC-21, TC-48"],
         ["Hai lần ghi vào cùng một ví", "Khóa bi quan PESSIMISTIC_WRITE trên dòng users trước khi đọc số dư",
          "Lần sau chờ lần trước commit rồi đọc số dư mới", "TC-53"],
         ["Hai lần sửa một hóa đơn từ cùng phiên bản", "Khóa lạc quan @Version; xung đột phiên bản trả 409",
          "Một lần ghi, lần kia không đổi gì và nhận 409", "TC-54"],
         ["Ứng dụng gửi lại cùng một checkout (mạng chập chờn, hàng đợi ngoại tuyến)",
          "clientId duy nhất theo người dùng (ràng buộc trên user_id, client_id), tra trong khóa ví",
          "Lần lặp nhận lại giao dịch gốc, không tạo bản trùng", "TC-52"],
     ], "", "bang_tranh_chap"),
    ("p", "**Bảng xếp hạng.** ZINCRBY cộng một khoản chênh: nếu một sự kiện bị mất hoặc chạy hai lần, điểm sai mãi mãi. Thiết "
          "kế ghi tổng tuyệt đối nên lần cập nhật kế tiếp của người dùng đó sửa lại điểm. Script chỉ ghi khi set của tháng "
          "còn tồn tại: một set vừa hết hạn trong lúc đọc tổng không bị tạo lại thành set một phần tử không có TTL (TC-15). "
          "Cập nhật một phần tử bằng EVALSHA mất p50 0,067 ms (E3)."),
]
C4_13 += code(J + "Service/Cache/SpendingLeaderboardService.java", 54, 64, "Script cập nhật bảng xếp hạng")
C4_13 += [
    ("p", "**Chỗ sửa OCR.** Bước một ghi đè document đã có của (hóa đơn, trường) khi giá trị khác và mở lại nó; bước hai chỉ "
          "tạo mới khi chưa có, bằng $setOnInsert nên không đụng document đã có cùng giá trị (gửi lại y nguyên giữ trạng thái "
          "đã xử lý, TC-21)."),
]
C4_13 += code(J + "Service/OcrMongoService.java", 196, 208, "Upsert hai bước")
C4_13 += [
    ("p", "**Ví và checkout lặp.** TransactionService luôn khóa ví trước khi đọc số dư, kể cả khi không có clientId, rồi trong "
          "khóa đó tra findByUserIdAndClientId: clientId đã có thì trả lại giao dịch gốc (J/Service/TransactionService.java:"
          "176–186, TC-52). lockWallet tách bản sao User đọc trước đó khỏi persistence context để số dư dùng là số đọc dưới "
          "khóa (TC-53)."),
]
C4_13 += code(J + "Service/TransactionService.java", 662, 669, "lockWallet")
C4_13 += [
    ("p", "**Hóa đơn.** Cột version tăng ở mỗi lần cập nhật; lần sửa chuẩn bị từ phiên bản cũ không ghi được gì và nhận "
          "409. Lớp ReceiptConcurrencyPostgresTest chạy hai lần sửa đồng thời trên PostgreSQL 15 thật (Testcontainers): một "
          "lần ghi, lần kia không đổi gì (TC-54)."),
]
C4_13 += code(J + "Entity/Receipt.java", 75, 78, "Cột phiên bản của hóa đơn")
C4_13 += [
    ("h3", "Tối ưu CSDL"),
    ("p", "**Vấn đề.** Các truy vấn đọc nhiều nhất tốn thời gian tỉ lệ với lượng dữ liệu: danh sách phản hồi \"chưa xử lý, "
          "mới nhất trước\" quét cả collection rồi sắp xếp trong bộ nhớ; dashboard và bảng xếp hạng chạy lại SQL gộp ở mỗi "
          "lần mở trang; tìm kiếm LIKE '%…%' đọc mọi giao dịch của người dùng."),
    ("p", "**Giải pháp.** Index ghép theo thứ tự ESR (trường so bằng isResolved trước, trường sắp xếp reportedAt sau), "
          "cache-aside cho thống kê, Sorted Set cho bảng xếp hạng, chỉ mục đảo cho tìm kiếm. Index status_date_idx được khai "
          "báo ở lớp Java và tạo bởi script khởi tạo:"),
]
C4_13 += code(J + "Document/OcrFeedback.java", 14, 14, "Khai báo index")
C4_13 += code("scripts/nosql/mongodb_init.js", 139, 139, "Tạo index")
C4_13 += [
    ("table", "Trước và sau tối ưu (độ trễ p50 tầng dữ liệu, dữ liệu tổng hợp 100k)", 4, [2400, 2100, 2104, 1900],
     ["Kỹ thuật", "Trước", "Sau", "Hệ số, kiểm thử"],
     [
         ["Index MongoDB (Q-03, status_date_idx, E rồi S)", "COLLSCAN 21,8 ms", "IXSCAN 0,33 ms, docs = nReturned = 5",
          "65× (E1); TC-46"],
         ["Index MongoDB (Q-01, transactionId)", "COLLSCAN 20,7 ms", "IXSCAN 0,34 ms", "60× (E1)"],
         ["Cache-aside, dashboard người dùng", "3 câu SQL 2,13 ms", "Redis GET 0,054 ms", "39× (E4); TC-05"],
         ["Cache-aside, tổng quan quản trị", "5 câu SQL 27,2 ms", "Redis GET 0,051 ms", "529× (E4)"],
         ["Sorted Set cho top 10", "SQL GROUP BY 23,6 ms", "ZREVRANGE + tra tên 0,36 ms", "66× (E3); TC-13"],
         ["Chỉ mục đảo (người dùng 19.788 giao dịch)", "PostgreSQL LIKE 78,2 ms, \"pho\" bỏ sót 1.376 dòng",
          "Elasticsearch 3,70 ms, bỏ sót 0", "21× (E2); TC-32..TC-35"],
     ], "Nguồn: docs/nosql/bench_results.md", "bang_toi_uu"),
    ("p", "Hai kết quả ngược chiều được giữ nguyên: với người dùng điển hình (khoảng 80 giao dịch) PostgreSQL LIKE nhanh hơn "
          "Elasticsearch (0,66 ms so với 3,70 ms), Elasticsearch chỉ thắng về tốc độ khi một người có nhiều giao dịch và thắng "
          "về chất lượng ở mọi trường hợp; và Q-02 không đạt vế docs = nReturned (mục 4.4)."),
    ("h3", "Realtime: Redis Pub/Sub và Server-Sent Events"),
    ("p", "**Vấn đề.** Quản trị viên cần biết ngay khi có hóa đơn chờ duyệt, chỗ sửa OCR mới, hay khi chỉ mục và bảng xếp "
          "hạng vừa được dựng lại, kể cả khi API chạy nhiều instance và sự kiện phát sinh ở instance khác với instance đang "
          "giữ trình duyệt."),
    ("p", "**Giải pháp.** AdminEventPublisher gửi một tin JSON lên kênh Redis ledgermind:admin-events (sau commit, trên luồng "
          "nền). Mỗi instance có một AdminEventRelay nghe kênh đó và chuyển tin tới mọi luồng SSE GET /admin/events đang mở "
          "của instance mình; trình duyệt nhận bằng EventSource và hiện toast cùng huy hiệu. Tin không lưu ở đâu cả "
          "(at-most-once), chấp nhận được vì đây chỉ là thông báo; dữ liệu thật vẫn đọc từ trang quản trị. "
          "AdminActivityFilter chỉ ghi nhận các request quản trị thật là hoạt động của phiên, còn luồng SSE thì không, nên một "
          "tab bỏ quên không giữ phiên sống mãi: phiên nhàn rỗi quá hạn thì lần kết nối lại nhận 204 và EventSource dừng."),
]
C4_13 += code(J + "Service/Realtime/AdminEventPublisher.java", 32, 38, "Phát sự kiện")
C4_13 += short_code(J + "Service/Realtime/AdminEventRelay.java", [(112, 114)], "Đẩy tin tới các luồng SSE của instance")
C4_13 += [
    ("p", "**Bằng chứng và kiểm thử.** E6 đo bằng bài đo JUnit AdminEventLatencyBench với đúng các lớp của ứng dụng và một "
          "Redis thật: 300 sự kiện, từ lúc gọi publish tới lúc SseEmitter.send ở phía server p50 1,18 ms, p95 1,57 ms, max "
          "3,13 ms, mất 0/300. Đây là chặng server, bài đo JUnit; chặng từ server qua HTTP tới trình duyệt không được đo nên "
          "con số là cận dưới của độ trễ người dùng thấy (mục tiêu NFR-15 dưới 1 s). Lớp AdminEventRelayIntegrationTest "
          "chứng minh một PUBLISH tới luồng SSE của cả hai instance (TC-17) và instance khởi động lúc Redis chưa chạy vẫn chạy "
          "rồi tự đăng ký khi Redis lên (TC-18); lớp AdminEventsControllerTest chứng minh người dùng thường bị từ chối luồng "
          "SSE (TC-19)."),
]

HEADING_PLACEHOLDERS = {
    "THIẾT KẾ CƠ SỞ DỮ LIỆU VÀ HỆ THỐNG (SDS)": C4_0,
    "KIẾN TRÚC TỔNG THỂ": C4_1,
    "LỰA CHỌN LOẠI CƠ SỞ DỮ LIỆU": C4_2,
    "THIẾT KẾ CSDL KEY-VALUE [REDIS]": C4_3,
    "THIẾT KẾ CSDL DOCUMENT [MONGODB]": C4_4,
    "THIẾT KẾ CSDL SEARCH/DOCUMENT [ELASTICSEARCH] – CSDL TỰ TÌM HIỂU": C4_5,
    "CASSANDRA VÀ NEO4J: KHÔNG SỬ DỤNG": C4_6,
    "ĐỒNG BỘ DỮ LIỆU GIỮA CÁC CSDL (POLYGLOT PERSISTENCE)": C4_7,
    "PHÂN TÁN, SAO CHÉP VÀ CAP": C4_8,
    "BẢO MẬT, SAO LƯU, GIÁM SÁT": C4_9,
    "THIẾT KẾ MODULE VÀ API": C4_10,
    "MA TRẬN ÁNH XẠ AP → THIẾT KẾ": C4_11,
    "MÔ HÌNH HÓA CẤU TRÚC (STRUCTURAL MODELING)": C4_12,
    "CÁC KỸ THUẬT NÂNG CAO": C4_13,
}
