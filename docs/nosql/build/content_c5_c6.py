"""Nội dung Chương 5 (Xây dựng CSDL và truy vấn trên GUI tool) và Chương 6 (Kết nối ứng dụng và demo) – báo cáo NoSQL nhóm 38.

Dựng v4 từ v3 (từ thư mục gốc repo):
    python3 docs/nosql/build/build_version.py v3 v4 content_c5_c6.py 5
    python3 docs/nosql/build/check_report.py /home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38/NoSQL_38_BaoCao_v4.docx --chapter 6
(build_version.py chỉ kiểm một chương; chương 6 kiểm bằng lệnh thứ hai.)

Nguồn: các script nộp kèm scripts/nosql (mọi lệnh cắt nguyên văn từ tệp lúc dựng, kèm "đường dẫn:dòng"; đoạn rút gọn ghi
rõ), mã nguồn core-backend (cấu hình, repository, service), docs/nosql/bench_results.md (E1–E6, sao lưu NFR-13),
docs/nosql/screenshots.md (S-xx). Kết quả truy vấn MongoDB và Redis ghi trong văn bản là kết quả chạy thật mongodb_demo.js và
redis_demo.txt trong container dùng một lần (mongo:6.0, redis:8.10-alpine, mạng none) ngày 28/10/2026; kết quả Elasticsearch
đọc từ ảnh chụp Kibana của stack demo. scripts/nosql/sample_data/*.json xuất bằng mongoexport --jsonArray --jsonFormat=canonical
từ dữ liệu demo trong container dùng một lần, rồi được nhập lại vào một database rỗng để kiểm (36 + 36 document, 13 index).
"""
import json
import tempfile
import textwrap
from pathlib import Path

SESSION_TAG = None
SECTIONS = {}
RENUMBER = True

REPO = Path(__file__).resolve().parents[3]
J = "core-backend/src/main/java/vn/edu/huit/finance/core/"
R = "core-backend/src/main/resources/"
S = "scripts/nosql/"
MONGO_DEMO = S + "mongodb_demo.js"
REDIS_DEMO = S + "redis_demo.txt"
KIBANA = S + "elasticsearch/kibana-devtools.txt"
SCREENSHOTS = REPO / "docs/nosql/screenshots"


def src(rel, first, last):
    """Các dòng first..last (đánh số từ 1) của một tệp trong repo, nguyên văn, chỉ bỏ phần thụt lề chung."""
    lines = (REPO / rel).read_text(encoding="utf8").splitlines()[first - 1:last]
    return textwrap.dedent("\n".join(lines))


def short(rel):
    return rel.replace(J, "J/").replace(R, "R/")


def code(rel, first, last, what):
    """Dòng dẫn "<what> (đường dẫn:dòng)" rồi khối MaNguon nguyên văn."""
    rng = f"{first}" if first == last else f"{first}–{last}"
    return [("lead", f"{what} ({short(rel)}:{rng}):"), ("code", src(rel, first, last))]


def es_compact(rel, first, last, what):
    """Một khối Kibana Dev Tools: dòng GET giữ nguyên, thân JSON in gọn (json.dumps, ngắt dòng ở ~100 ký tự).
    Nội dung truy vấn không đổi, chỉ đổi khoảng trắng; dòng dẫn ghi "định dạng gọn"."""
    lines = src(rel, first, last).split("\n")
    out, body = [], []

    def flush():
        if body:
            text = json.dumps(json.loads("\n".join(body)), ensure_ascii=False, separators=(", ", ": "))
            out.extend(textwrap.wrap(text, 100, break_long_words=False, break_on_hyphens=False))
            body.clear()
    for line in lines:
        if line.startswith(("GET ", "POST ", "PUT ", "DELETE ")) or not line.strip():
            flush()
            if line.strip():
                out.append(line)
        else:
            body.append(line)
    flush()
    return [("lead", f"{what} ({short(rel)}:{first}–{last}, thân JSON in gọn):"), ("code", "\n".join(out))]


def code_cut(rel, ranges, what):
    """Rút gọn: nhiều khoảng dòng của cùng một tệp, nối bằng một dòng "...". Dòng dẫn ghi "rút gọn từ"."""
    parts = [src(rel, a, b) for a, b in ranges]
    rng = ", ".join(f"{a}–{b}" if a != b else f"{a}" for a, b in ranges)
    return [("lead", f"{what} (rút gọn từ {short(rel)}, dòng {rng}):"), ("code", "\n...\n".join(parts))]


# --------------------------------------------------------------------------------------------------------------------
# Danh sách truy vấn Q-01..Q-41 (loại, CSDL, AP theo bảng Q đã chốt ở Chương 3; dòng lệnh trong script nộp kèm).
# result: kết quả chạy thật (MongoDB, Redis: container dùng một lần ngày 28/10/2026; Elasticsearch: ảnh Kibana).
# --------------------------------------------------------------------------------------------------------------------

def Q(qid, kind, db, ap, req, op, file, ranges, cap, result, width=15.0):
    return dict(qid=qid, kind=kind, db=db, ap=ap, req=req, op=op, file=file, ranges=ranges, cap=cap, result=result,
                width=width, sid=f"S-{int(qid[2:]) + 19:02d}", key=f"hinh_q{qid[2:]}")


QUERIES = [
    # ---------------- MongoDB (Compass), database finance_nosql_demo ----------------
    Q("Q-01", "CB", "MongoDB", "AP-38", "Xem câu trả lời thô của AI cho một giao dịch (giao dịch 1025)",
      "Tìm theo điều kiện, chiếu trường", MONGO_DEMO, [(115, 115)],
      "Compass: log OCR thô của giao dịch 1025 (Q-01)",
      "Kết quả: đúng một document của mô hình donut-v5, độ tin cậy 0,89, người bán \"Highlands Coffee\", tổng "
      "\"155,000\". Truy vấn đi qua index unique transactionId (xem Q-16).", 14),
    Q("Q-02", "CB", "MongoDB", "AP-38", "Năm lần đọc AI kém nhất gần đây (độ tin cậy dưới 0,75), mới nhất trước",
      "Lọc, sắp xếp, giới hạn", MONGO_DEMO, [(120, 121)],
      "Compass: lần đọc có độ tin cậy dưới 0,75, mới nhất trước (Q-02)",
      "Kết quả: 5 log, đều của donut-v4, độ tin cậy 0,68–0,74; mới nhất là giao dịch 1017 (09/09/2026).", 14),
    Q("Q-03", "CB", "MongoDB", "AP-19", "Danh sách phản hồi OCR chưa xử lý, mới nhất trước",
      "Lọc, sắp xếp, giới hạn (limit)", MONGO_DEMO, [(126, 127)],
      "Compass: phản hồi chưa xử lý, mới nhất trước (Q-03)",
      "Kết quả lúc script chạy tới Q-03: 5 phản hồi của các hóa đơn 524, 523, 521, 520, 518 (23/09 về 11/09/2026). "
      "Trên dữ liệu demo sau khi chạy hết script, phản hồi do Q-09 thêm (hóa đơn 530, 20/10/2026) đứng đầu danh sách.", 14),
    Q("Q-04", "CB", "MongoDB", "AP-19", "Tháng 9/2026 có bao nhiêu lỗi tổng tiền; các loại trường bị báo lỗi",
      "Đếm theo điều kiện, giá trị phân biệt", MONGO_DEMO, [(132, 136)],
      "Compass (mongosh): đếm lỗi total_cost tháng 9/2026 và các giá trị fieldError (Q-04)",
      "Kết quả: 6 lỗi total_cost trong tháng 9/2026; ba giá trị fieldError là receipt_date, seller_name, total_cost.", 14),
    Q("Q-05", "CB", "MongoDB", "AP-18", "Hệ thống phải từ chối một phản hồi sai cấu trúc",
      "Thêm (bị validator chặn)", MONGO_DEMO, [(141, 146)],
      "Compass (mongosh): $jsonSchema từ chối document sai kiểu (Q-05)",
      "Kết quả: insertOne bị từ chối với mã lỗi 121 \"Document failed validation\" (receiptId là chuỗi, fieldError "
      "\"price\" không thuộc danh sách cho phép).", 14),
    Q("Q-06", "CB", "MongoDB", "AP-18", "Một hóa đơn không được có hai phản hồi cho cùng một trường",
      "Thêm (bị unique index chặn)", MONGO_DEMO, [(151, 156)],
      "Compass (mongosh): unique index receipt_field_uq chặn bản trùng (Q-06)",
      "Kết quả: insertOne bị từ chối với mã lỗi 11000, index receipt_field_uq.", 14),
    Q("Q-07", "CB", "MongoDB", "AP-20", "Quản trị viên đánh dấu một phản hồi là đã xử lý",
      "Sửa (updateOne, $set)", MONGO_DEMO, [(161, 164)],
      "Compass: phản hồi được đánh dấu đã xử lý (Q-07)",
      "Kết quả: matched=1 modified=1 (phản hồi seller_name của hóa đơn 502).", 14),
    Q("Q-08", "CB", "MongoDB", "AP-21", "Quản trị viên xóa một phản hồi",
      "Xóa (deleteOne)", MONGO_DEMO, [(169, 171)],
      "Compass: xóa một phản hồi (Q-08)",
      "Kết quả: deleted=1; số phản hồi 36 → 35 (Q-09 thêm lại một document nên dữ liệu demo cuối cùng vẫn có 36).", 14),
    Q("Q-09", "NC", "MongoDB", "AP-18", "Ghi chỗ người dùng sửa kết quả AI mà không bao giờ tạo bản trùng; sửa lại bằng "
      "giá trị khác thì mở lại phản hồi", "Cập nhật có điều kiện + upsert $setOnInsert (atomic)", MONGO_DEMO, [(180, 201)],
      "Compass (mongosh): upsert hai bước, ba lần sửa cùng một trường (Q-09)",
      "Kết quả: lần 1 \"thêm mới\"; lần 2 (cùng giá trị, sau khi quản trị viên đã xử lý) \"không đổi\", isResolved vẫn "
      "true; lần 3 (giá trị khác) \"sửa tại chỗ, mở lại\": isResolved=false, reportedAt giữ 20/10/2026, updatedAt "
      "21/10/2026; cặp (530, seller_name) chỉ có 1 document.", 14),
    Q("Q-10", "NC", "MongoDB", "AP-22", "Trường nào AI đọc sai nhiều nhất trong ba tháng 8–10/2026",
      "Aggregation $match, $group, $sort", MONGO_DEMO, [(206, 210)],
      "Compass Aggregations: số lỗi theo trường (Q-10)",
      "Kết quả: seller_name 15, total_cost 12, receipt_date 9.", 14),
    Q("Q-11", "NC", "MongoDB", "AP-23", "So sánh số lỗi của hai phiên bản mô hình donut-v4 và donut-v5",
      "$group theo biểu thức $ifNull", MONGO_DEMO, [(215, 218)],
      "Compass Aggregations: số lỗi theo mô hình (Q-11)",
      "Kết quả: donut-v4 29 lỗi, donut-v5 7 lỗi.", 14),
    Q("Q-12", "NC", "MongoDB", "AP-24", "Độ tin cậy trung bình của AI theo từng tháng (giờ Việt Nam)",
      "$project $dateToString, $group $avg", MONGO_DEMO, [(223, 228)],
      "Compass Aggregations: độ tin cậy trung bình theo tháng (Q-12)",
      "Kết quả: 2026-08: 12 log, 0,726; 2026-09: 12 log, 0,822; 2026-10: 12 log, 0,908.", 14),
    Q("Q-13", "NC", "MongoDB", "AP-37", "Với mỗi chỗ sửa tên người bán, xem câu trả lời thô của AI cho giao dịch đó",
      "$lookup, $unwind, $project", MONGO_DEMO, [(234, 241)],
      "Compass Aggregations: chỗ sửa tên người bán kèm câu trả lời thô (Q-13)",
      "Kết quả: 4 dòng, ví dụ hóa đơn 501: câu trả lời thô của AI ghi \"Hlghlands C0ffee\" (đúng bằng aiValue), người "
      "dùng sửa thành \"Highlands Coffee\", độ tin cậy 0,68, mô hình donut-v4. Truy vấn này chỉ có trong script, ứng dụng chưa có API tương ứng.", 14),
    Q("Q-14", "NC", "MongoDB", "AP-37", "Ba thống kê (theo trường, theo mô hình, theo trạng thái) trong một lần truy vấn",
      "$facet", MONGO_DEMO, [(246, 253)],
      "Compass Aggregations: ba thống kê bằng $facet (Q-14)",
      "Kết quả: theo trường 15/12/9, theo mô hình 29/7, chưa xử lý 24 và đã xử lý 12, tổng 36. Chỉ có trong script.", 14),
    Q("Q-15", "NC", "MongoDB", "AP-25", "Bao nhiêu phần trăm lần đọc của AI bị người dùng sửa ít nhất một chỗ",
      "$lookup, $group, $cond, $divide", MONGO_DEMO, [(260, 265)],
      "Compass Aggregations: tỉ lệ lần đọc bị sửa (Q-15)",
      "Kết quả: 36 lần đọc, 25 lần bị sửa, tỉ lệ 0,694.", 14),
    Q("Q-16", "NC", "MongoDB", "AP-19, AP-38", "Chứng minh các truy vấn chính dùng index",
      "explain(\"executionStats\")", MONGO_DEMO, [(275, 286)],
      "Compass Explain Plan: truy vấn Q-03 dùng IXSCAN trên status_date_idx (Q-16)",
      "Kết quả: Q-03 đi FETCH → IXSCAN trên status_date_idx, totalKeysExamined = totalDocsExamined = nReturned = 24; "
      "Q-01 đi IXSCAN trên transactionId, 1 khóa, 1 document; Q-06 đi IXSCAN trên receipt_field_uq.", 14),
    # ---------------- Redis (RedisInsight Workbench) ----------------
    Q("Q-17", "CB", "Redis", "AP-05", "Lưu mã OTP quên mật khẩu, tự hết hạn sau 5 phút",
      "Thêm Hash, đặt TTL", REDIS_DEMO, [(20, 24)],
      "RedisInsight: lưu OTP bằng HSET và PEXPIRE (Q-17)",
      "Kết quả: HSET trả 2 (hai trường), PEXPIRE trả 1, PTTL 300000 ms; HGETALL trả code và expiresAt."),
    Q("Q-18", "CB", "Redis", "AP-06", "Đếm số lần nhập sai mã; mã hết hạn thì không còn",
      "Sửa Hash, đọc một trường, hết hạn", REDIS_DEMO, [(28, 33)],
      "RedisInsight: đếm lần nhập sai và cho OTP hết hạn (Q-18)",
      "Kết quả: HINCRBY và HGET trả 1; EXISTS trả 1 trước và 0 sau PEXPIREAT về quá khứ; HGETALL rỗng."),
    Q("Q-19", "CB", "Redis", "AP-07", "Lưu kết quả dashboard của người dùng 1 vào cache",
      "Thêm String JSON có TTL, đọc", REDIS_DEMO, [(40, 43)],
      "RedisInsight: cache dashboard của người dùng 1 (Q-19)",
      "Kết quả: GET trả đúng chuỗi JSON, TTL 285 s, TYPE string."),
    Q("Q-20", "CB", "Redis", "AP-07, AP-10", "Các mục cache hết hạn lệch nhau; xóa một mục khi dữ liệu đổi",
      "Thêm nhiều khóa, TTL khác nhau, xóa", REDIS_DEMO, [(47, 53)],
      "RedisInsight: TTL lệch nhau và xóa một mục cache (Q-20)",
      "Kết quả: TTL 270 s và 298 s; DEL trả 1, EXISTS sau đó trả 0."),
    Q("Q-21", "CB", "Redis", "AP-10", "Liệt kê các khóa của một cache mà không chặn Redis",
      "Tìm khóa theo mẫu (SCAN)", REDIS_DEMO, [(57, 58)],
      "RedisInsight: SCAN MATCH thay cho KEYS (Q-21)",
      "Kết quả: con trỏ 0 (đã quét hết) và 2 khóa user-dashboard; với TYPE string: 3 khóa."),
    Q("Q-29", "CB", "Redis", "–", "Kiểm tra cấu hình lưu đĩa của Redis (NFR-13)",
      "Đọc cấu hình, BGSAVE", REDIS_DEMO, [(129, 134)],
      "RedisInsight: cấu hình persistence trên stack demo (Q-29)",
      "Kết quả trên stack demo (cấu hình giống docker-compose.yml): save rỗng, appendonly no, tức không ghi đĩa định kỳ; "
      "BGSAVE vẫn chạy được khi gọi tay (\"Background saving started\") nên dùng được cho bài sao lưu ở mục 5.6.", 14),
    Q("Q-22", "NC", "Redis", "AP-12", "Dựng bảng xếp hạng chi tiêu tháng 10/2026",
      "Sorted Set: ZADD nhiều phần tử, EXPIRE", REDIS_DEMO, [(66, 71)],
      "RedisInsight: dựng bảng xếp hạng tháng (Q-22)",
      "Kết quả: ZADD trả 6, TTL 5356800 s (62 ngày), ZCARD 6, TYPE zset."),
    Q("Q-23", "NC", "Redis", "AP-11", "Ba người chi tiêu nhiều nhất tháng",
      "ZREVRANGE … WITHSCORES", REDIS_DEMO, [(75, 75)],
      "RedisInsight: top 3 chi tiêu tháng (Q-23)",
      "Kết quả: người dùng 4 (9.100.000), 2 (6.850.000), 1 (4.200.000)."),
    Q("Q-24", "NC", "Redis", "AP-11", "Người dùng 1 đứng thứ mấy; bao nhiêu người chi từ 3 đến 7 triệu",
      "ZREVRANK, ZSCORE, ZCOUNT", REDIS_DEMO, [(79, 81)],
      "RedisInsight: thứ hạng, điểm và đếm theo khoảng (Q-24)",
      "Kết quả: hạng 2 (tính từ 0), điểm 4.200.000, có 3 người trong khoảng."),
    Q("Q-25", "NC", "Redis", "AP-13", "Cập nhật tổng chi bằng giá trị tuyệt đối; gỡ người không còn chi tiêu",
      "ZINCRBY so với ZADD, ZREM", REDIS_DEMO, [(85, 90)],
      "RedisInsight: ZINCRBY, ZADD tuyệt đối và ZREM (Q-25)",
      "Kết quả: ZINCRBY cho 3800000; ZADD cùng giá trị trả 0 (cập nhật, không thêm); ZREM trả 1; bảng còn 5 người. "
      "Ứng dụng chỉ dùng ZADD/ZREM với tổng đọc lại từ PostgreSQL, không dùng ZINCRBY."),
    Q("Q-26", "NC", "Redis", "AP-12", "Dựng bảng tháng 9 và gắn TTL như một khối không bị lệnh khác xen vào",
      "MULTI … EXEC", REDIS_DEMO, [(94, 99)],
      "RedisInsight: giao dịch MULTI/EXEC (Q-26)",
      "Kết quả: ba lệnh QUEUED, EXEC trả 3, 1 và người đứng đầu (4, 7400000); TTL 5356800 s."),
    Q("Q-27", "NC", "Redis", "AP-05, AP-06", "Kiểm tra mã OTP nguyên tử: đúng thì dùng một lần, sai quá 3 lần thì hủy",
      "Lua (EVAL)", REDIS_DEMO, [(107, 107), (109, 109)],
      "RedisInsight: script Lua lưu và kiểm tra OTP (Q-27)",
      "Các dòng 110–113 gọi lại đúng script kiểm tra ở dòng 109 với mã 111111 rồi hai lần 123456. Kết quả: lưu trả 1; hai "
      "lần sai trả 1, 2; mã đúng trả 0 và xóa khóa; dùng lại trả -1; EXISTS trả 0."),
    Q("Q-28", "NC", "Redis", "AP-14", "Dọn mọi tháng của bảng xếp hạng sau khi khôi phục CSDL",
      "SCAN MATCH + DEL", REDIS_DEMO, [(121, 123)],
      "RedisInsight: dọn các tháng bảng xếp hạng (Q-28)",
      "Kết quả: SCAN thấy hai khóa 2026-09, 2026-10; DEL trả 2; SCAN lần sau rỗng."),
    Q("Q-41", "NC", "Redis", "AP-15, AP-16", "Đưa sự kiện realtime tới các trang quản trị đang mở",
      "Pub/Sub: PUBSUB, PUBLISH, SUBSCRIBE", REDIS_DEMO, [(138, 141)],
      "RedisInsight Pub/Sub (trên) nhận tin; redis-cli PUBLISH (dưới) (Q-41)",
      "Kết quả: khi chưa ai nghe, PUBLISH trả 0 (tin mất, Pub/Sub không lưu). Trong ảnh, cửa sổ trên đăng ký kênh "
      "bằng RedisInsight (đăng ký theo mẫu nên NUMSUB = 0, NUMPAT = 1), cửa sổ dưới PUBLISH trả 1 và tin hiện ngay ở "
      "cửa sổ trên.", 14),
    # ---------------- Elasticsearch (Kibana Dev Tools), index transactions, 47 document demo ----------------
    Q("Q-30", "CB", "ES", "AP-35", "Index giao dịch có mặt không, có bao nhiêu document",
      "_cat/indices, _count", KIBANA, [(19, 21)],
      "Kibana Dev Tools: index transactions và số document (Q-30)",
      "Kết quả: index transactions có 47 document (bằng số dòng của tệp nạp)."),
    Q("Q-31", "CB", "ES", "AP-32", "Đối chiếu một giao dịch giữa PostgreSQL và index",
      "Lấy document theo _id", KIBANA, [(27, 27)],
      "Kibana Dev Tools: document có _id 1 (Q-31)",
      "Kết quả: document của giao dịch 1 với các trường của mapping (userId, note, vendorName, amount, …)."),
    Q("Q-32", "CB", "ES", "AP-29", "Ba giao dịch mới nhất của người dùng 1",
      "Lọc term, sắp xếp, giới hạn (size)", KIBANA, [(33, 39)],
      "Kibana Dev Tools: giao dịch mới nhất của người dùng 1 (Q-32)",
      "Kết quả: 3 giao dịch của người dùng 1, ngày giảm dần; không có dòng của người khác."),
    Q("Q-33", "CB", "ES", "AP-29", "Gõ \"ca phe\" (không dấu) vẫn ra danh mục \"Cà phê\"",
      "match trên trường bỏ dấu", KIBANA, [(45, 53)],
      "Kibana Dev Tools: \"ca phe\" khớp \"Cà phê\" (Q-33)",
      "Kết quả: 2 giao dịch \"Cà phê\" của người dùng 2 (Cộng Cà Phê, Starbucks)."),
    Q("Q-34", "CB", "ES", "AP-29", "Xem analyzer tách chữ tiếng Việt thành token thế nào",
      "_analyze", KIBANA, [(59, 69)],
      "Kibana Dev Tools: token của vi_folded và vi_autocomplete (Q-34)",
      "Kết quả: vi_folded biến \"Phở Bò Hòa Pasteur\" thành pho, bo, hoa, pasteur; vi_autocomplete cắt \"Highlands\" "
      "thành hi, hig, high, … highlands."),
    Q("Q-35", "NC", "ES", "AP-29", "Tìm giao dịch của tôi với từ khóa \"pho\" đúng như ứng dụng tìm",
      "bool: filter + hai multi_match (chính xác, mờ); phân trang from/size", KIBANA, [(79, 107)],
      "Kibana Dev Tools: truy vấn thật của ứng dụng cho \"pho\" (Q-35)",
      "Kết quả: 4 giao dịch \"Phở …\" của người dùng 1, không có dòng của người dùng 2, 3. Đây là truy vấn mà "
      "GET /api/transactions/search gửi đi."),
    Q("Q-36", "NC", "ES", "AP-29", "Gõ sai \"highlans cofee\" vẫn ra \"Highlands Coffee\"",
      "multi_match fuzziness AUTO:4,7", KIBANA, [(113, 126)],
      "Kibana Dev Tools: tìm mờ \"highlans cofee\" (Q-36)",
      "Kết quả: 2 giao dịch Highlands Coffee của người dùng 1."),
    Q("Q-37", "NC", "ES", "AP-29", "Gợi ý khi đang gõ \"hig\"",
      "multi_match trên trường edge_ngram", KIBANA, [(133, 144)],
      "Kibana Dev Tools: tiền tố \"hig\" khớp \"Highlands\" (Q-37)",
      "Kết quả: 2 giao dịch Highlands Coffee."),
    Q("Q-38", "NC", "ES", "AP-36", "Các khoản chi tháng 9/2026 của tôi, số tiền lớn trước",
      "bool filter term + range, sort", KIBANA, [(150, 160)],
      "Kibana Dev Tools: khoản chi tháng 9/2026 theo số tiền (Q-38)",
      "Kết quả: 5 khoản chi, lớn nhất 185.000 (Bách Hóa Xanh, Mua sắm). Chỉ có trong script, chưa có API."),
    Q("Q-39", "NC", "ES", "AP-36", "Tổng chi theo từng danh mục",
      "Aggregation terms + sum", KIBANA, [(167, 177)],
      "Kibana Dev Tools: tổng chi theo danh mục (Q-39)",
      "Kết quả: 16 khoản chi của người dùng 1; Ăn uống 5 khoản 394.000, Cà phê 4 khoản 244.000, Di chuyển 2 khoản "
      "218.000, … Chỉ có trong script."),
    Q("Q-40", "NC", "ES", "AP-36", "Tổng chi theo từng tháng",
      "Aggregation date_histogram + sum", KIBANA, [(183, 193)],
      "Kibana Dev Tools: tổng chi theo tháng (Q-40)",
      "Kết quả: 2026-08: 6 khoản 1.402.000; 2026-09: 5 khoản 475.000; 2026-10: 5 khoản 499.000. Chỉ có trong script."),
]

DB_ORDER = ["MongoDB", "Redis", "ES"]
DB_LONG = {"MongoDB": "MongoDB", "Redis": "Redis", "ES": "Elasticsearch"}
DB_SHORT = {"MongoDB": "Mongo", "Redis": "Redis", "ES": "ES"}
TOOL = {"MongoDB": "MongoDB Compass", "Redis": "RedisInsight", "ES": "Kibana Dev Tools"}


CROP_DIR = Path(tempfile.gettempdir()) / "nosql_c5_c6_crops"
PT_CM = 2.54 / 72          # 1 pt tính bằng cm
MAX_CM = 15.0              # bề rộng vùng chữ dành cho hình
# Cỡ chữ (em, px) trong ảnh gốc: thẻ Workbench RedisInsight ~11 px; Kibana Console ~13 px; giao diện RedisInsight
# ~13 px; ảnh terminal do capture_tools.render_terminal vẽ bằng Noto Sans Mono 17 px (S-63, S-64, S-87: 15 px).
# Mỗi hình được cắt (bản sao tạm, ảnh gốc giữ nguyên) và đặt bề rộng sao cho chữ in ra khoảng 7–7,5 pt.
CARD = dict(kind="card", em=11.2, pt=7.5)
KIBANA_RESP = dict(kind="kibana", em=13.2, pt=7.0, cap=480)   # ~20 dòng đầu của khung kết quả
KIBANA_LONG = dict(KIBANA_RESP, cap=620)                       # aggregation, _analyze: cần thêm dòng
TERM17 = dict(kind="term", em=17.0, pt=7.5)
TERM15 = dict(kind="term", em=15.0, pt=7.5)
LEGIBLE = {f"S-{n}": CARD for n in range(36, 48)}
LEGIBLE.update({f"S-{n}": KIBANA_RESP for n in range(49, 60)})
LEGIBLE.update({sid: KIBANA_LONG for sid in ("S-53", "S-58", "S-59")})
LEGIBLE.update({
    "S-19": KIBANA_RESP,
    # Q-29: các câu trả lời save/appendonly, BGSAVE, LASTSAVE và các dòng rdb_∗ của INFO persistence
    "S-48": dict(kind="boxes", em=11.2, pt=7.5, boxes=[(0, 0, 600, 286), (0, 428, 600, 576)]),
    # RedisInsight Browser: danh sách khóa (trái) xếp trên khung chi tiết Hash OTP (phải)
    "S-18": dict(kind="boxes", em=13.0, pt=7.3, boxes=[(72, 166, 820, 420), (837, 182, 1583, 470)]),
    # Pub/Sub: bảng tin nhận được (trên) và terminal redis-cli (dưới), cùng cắt về 760 px
    "S-60": dict(kind="boxes", em=13.0, pt=7.0, boxes=[(70, 125, 830, 372), (0, 760, 760, 1030)]),
    "S-61": TERM17, "S-62": TERM17, "S-86": TERM17, "S-63": TERM15, "S-64": TERM15, "S-87": TERM15,
})
CAPTION_NOTE = {"kibana": " – khung kết quả", "term": " (cắt phần bên phải các dòng lệnh dài; lệnh đầy đủ ở khối mã)"}


def max_px(spec):
    return int(MAX_CM * spec["em"] / (spec["pt"] * PT_CM))


def legible_png(sid, spec):
    """Bản cắt của ảnh S-xx (lưu ở thư mục tạm) và bề rộng cm để chữ in ra cỡ spec["pt"]."""
    from PIL import Image, ImageOps
    im = Image.open(SCREENSHOTS / f"{sid}.png").convert("RGB")
    limit = max_px(spec)
    kind = spec["kind"]
    if kind == "card":
        gray = im.convert("L").crop((0, 45, im.width, im.height))
        bb = ImageOps.invert(gray).point(lambda v: 255 if v > 40 else 0).getbbox()
        boxes = [(0, 0, min(im.width, bb[2] + 40, limit), min(im.height, 45 + bb[3] + 20))]
    elif kind == "kibana":
        pane = im.convert("L").crop((860, 175, im.width, im.height))
        bb = pane.point(lambda v: 255 if v < 140 else 0).getbbox()
        bottom = min(im.height, 175 + bb[3] + 12, 145 + spec["cap"])
        boxes = [(808, 145, im.width, bottom)]
    elif kind == "term":
        boxes = [(0, 0, min(im.width, limit), im.height)]
    else:
        boxes = spec["boxes"]
    parts = [im.crop((l, t, min(r, l + limit), b)) for l, t, r, b in boxes]
    w = max(pt.width for pt in parts)
    gap = 8
    out = Image.new("RGB", (w, sum(pt.height for pt in parts) + gap * (len(parts) - 1)), (255, 255, 255))
    y = 0
    for i, pt in enumerate(parts):
        out.paste(pt, (0, y))
        y += pt.height
        if i < len(parts) - 1:
            out.paste((190, 190, 190), (0, y + gap // 2 - 1, w, y + gap // 2 + 1))
            y += gap
    CROP_DIR.mkdir(exist_ok=True)
    path = CROP_DIR / f"{sid}.png"
    out.save(path)
    width_cm = round(min(MAX_CM, w * spec["pt"] * PT_CM / spec["em"]), 2)
    return path, width_cm


def q_width(q):
    return 10.0                    # ảnh giữ chỗ (Compass); ảnh agent tính trong figure()


def figure(sid, cap, chapter, width_cm, key):
    spec = LEGIBLE.get(sid)
    if spec:
        png, width = legible_png(sid, spec)
        return ("fig", cap + CAPTION_NOTE.get(spec["kind"], ""), chapter, str(png), width, None, None, key)
    return ("sid", sid, cap, chapter, width_cm, key)


def counts():
    c = {(db, k): 0 for db in DB_ORDER for k in ("CB", "NC")}
    for q in QUERIES:
        c[(q["db"], q["kind"])] += 1
    cb = sum(v for (db, k), v in c.items() if k == "CB")
    nc = sum(v for (db, k), v in c.items() if k == "NC")
    assert cb >= 10 and nc >= 10, (cb, nc)
    assert all(c[(db, "CB")] and c[(db, "NC")] for db in DB_ORDER), c
    assert len({q["qid"] for q in QUERIES}) == 41
    return c, cb, nc


COUNTS, N_CB, N_NC = counts()


def q_blocks(q):
    if q["qid"] == "Q-16":   # bỏ hàm phụ stageNames (dòng 270–274), chỉ giữ ba lệnh explain
        out = code_cut(q["file"], q["ranges"], "Q-16 – Lệnh")
    elif q["db"] == "ES" and q["qid"] != "Q-35" and q["ranges"][0][1] - q["ranges"][0][0] > 3:   # Q-35 (truy vấn thật) giữ nguyên văn
        a, b = q["ranges"][0]
        out = es_compact(q["file"], a, b, f"{q['qid']} – Lệnh")
    elif len(q["ranges"]) == 1:
        a, b = q["ranges"][0]
        out = code(q["file"], a, b, f"{q['qid']} – Lệnh")
    else:
        out = code_cut(q["file"], q["ranges"], f"{q['qid']} – Lệnh")
    out.append(("p", q["result"]))
    out.append(figure(q["sid"], q["cap"], 5, q_width(q), q["key"]))
    return out


def q_table(kind, caption, key):
    rows = []
    for db in DB_ORDER:
        for q in QUERIES:
            if q["db"] == db and q["kind"] == kind:
                rows.append([q["qid"], q["req"], DB_SHORT[db], q["op"], q["ap"].replace(", ", "\n"), f"[[{q['key']}]]"])
    return ("table", caption, 5, [800, 2804, 1000, 2100, 900, 900],
            ["Mã", "Yêu cầu (ngôn ngữ người dùng)", "CSDL", "Thao tác", "AP", "Hình"], rows, "", key)


def q_section(kind):
    out = []
    for db in DB_ORDER:
        qs = [q for q in QUERIES if q["db"] == db and q["kind"] == kind]
        label = "cơ bản" if kind == "CB" else "nâng cao"
        out.append(("h3", f"{DB_LONG[db]}: truy vấn {label} trên {TOOL[db]}"))
        for q in qs:
            out += q_blocks(q)
    return out


# --------------------------------------------------------------------------------------------------------------------
# 5.0 Mở chương
# --------------------------------------------------------------------------------------------------------------------

C5_0 = [
    ("p", "Chương này ứng với tiêu chí 5, 6, 7: tạo CSDL (5.2), nhập dữ liệu (5.3), truy vấn cơ bản và nâng cao trên GUI tool "
          "(5.4, 5.5), nhập/xuất, sao lưu và khôi phục (5.6). Mọi lệnh được trích nguyên văn từ các script nộp kèm trong "
          "thư mục scripts/nosql của kho mã, kèm số dòng, để người chấm chạy lại được. Truy vấn chạy trên **dữ liệu demo** "
          "(các tệp trong scripts/nosql, không phải dữ liệu người dùng thật), trong một stack demo riêng "
          "(scripts/nosql/demo-stack.sh, project nosql-demo, mọi cổng chỉ mở trên 127.0.0.1) để không đụng tới hệ thống "
          "đang chạy."),
    ("p", "GUI tool dùng cho từng CSDL: MongoDB Compass cho MongoDB, RedisInsight cho Redis, Kibana Dev Tools cho "
          "Elasticsearch (Kibana là GUI tool tự tìm hiểu ở mục 2.5). Kết quả của MongoDB và Redis ghi trong văn bản là kết "
          "quả chạy thật mongodb_demo.js và redis_demo.txt trong container dùng một lần ngày 28/10/2026; kết quả của "
          "Elasticsearch đọc từ ảnh Kibana."),
    ("y", "Ghi chú cho nhóm (xóa trước khi nộp): các hình chụp bằng Compass (S-15, S-16, S-17, S-20 đến S-35) và trang "
          "quản trị (S-65, S-66) đang là ảnh giữ chỗ; Tiến chụp trên stack demo theo docs/nosql/screenshots.md rồi thay "
          "vào, số hình và chú thích giữ nguyên."),
]

# --------------------------------------------------------------------------------------------------------------------
# 5.1 Môi trường cài đặt
# --------------------------------------------------------------------------------------------------------------------

C5_1 = [
    ("p", "Toàn bộ hệ thống chạy trên một máy bằng Docker Compose; mỗi CSDL là **một node**, không có replica set, Sentinel "
          "hay cụm Elasticsearch (thiết kế cụm chỉ ở mức thiết kế, mục 4.8). [[bang_moi_truong]] ghi cấu hình máy và phiên "
          "bản đã kiểm bằng lệnh trên máy này."),
    ("table", "Môi trường cài đặt và phiên bản", 5, [2000, 3304, 3200],
     ["Thành phần", "Phiên bản, cấu hình", "Ghi chú"],
     [
         ["Máy", "Intel Core i7-8750H 2,20 GHz (12 luồng), RAM 15,0 GiB; Ubuntu 26.04.1 LTS, nhân Linux 7.0.0-38",
          "Một máy cho cả ứng dụng, CSDL và GUI tool"],
         ["Docker", "Docker Engine 29.1.3, Docker Compose", "Mọi CSDL chạy trong container"],
         ["PostgreSQL", "15.19 (image postgres:15-alpine)", "Nguồn sự thật (RDBMS), không thuộc phạm vi truy vấn NoSQL"],
         ["MongoDB", "6.0.28 (image mongo:6.0); WiredTiger cache 0,25 GB; giới hạn 512 MB",
          "Một node; database finance_nosql (ứng dụng), finance_nosql_demo (demo)"],
         ["Redis", "8.10.2 (image redis:8.10-alpine); maxmemory 128 MB, allkeys-lru; giới hạn 192 MB",
          "Một node; không ghi đĩa; có mật khẩu; KEYS, FLUSHALL, FLUSHDB bị vô hiệu"],
         ["Elasticsearch", "8.11.4; single-node, heap 512 MB; giới hạn 1 GB",
          "Bật bảo mật (user elastic); chặn tự tạo index; stack demo dùng 1,5 GB khi bật Kibana (mục 2.5)"],
         ["Ứng dụng", "Java 21, Spring Boot 3.2.5; Spring Data Redis 3.2.5 (Lettuce 6.3.2), Spring Data MongoDB 4.2.5 "
                      "(driver 4.11.2), Spring Data Elasticsearch 5.2.5 (elasticsearch-java 8.10.4)", "Mục 6.2"],
         ["GUI tool", "MongoDB Compass ⟦phiên bản: Tiến điền⟧; RedisInsight (image redis/redisinsight, bản phát hành "
                      "20/07/2026); Kibana 8.11.4; Elasticvue 1.16.0; Postman ⟦phiên bản⟧",
          "Compass, Postman cài trên máy; RedisInsight, Kibana, Elasticvue chạy bằng Docker"],
     ], "", "bang_moi_truong"),
    ("p", "Stack demo dùng đúng image, lệnh khởi động và giới hạn bộ nhớ của docker-compose.yml, chỉ khác cổng và mật khẩu "
          "demo: MongoDB 127.0.0.1:27018, Redis 6380, Elasticsearch 9201, Kibana 5602, Elasticvue 8081, RedisInsight 5541. "
          "Lệnh scripts/nosql/demo-stack.sh up khởi động stack và nạp dữ liệu demo; demo-stack.sh load nạp lại dữ liệu "
          "sau khi các truy vấn thêm, sửa, xóa đã làm đổi nó."),
]

# --------------------------------------------------------------------------------------------------------------------
# 5.2 Tạo CSDL
# --------------------------------------------------------------------------------------------------------------------

C5_2 = [
    ("h3", "MongoDB: database, collection, schema validation và index"),
    ("p", "Database finance_nosql có hai collection ocr_logs và ocr_feedbacks. Spring Data MongoDB của ứng dụng không tự "
          "tạo index, nên mọi thứ được tạo bởi một script duy nhất, scripts/nosql/mongodb_init.js: tạo collection nếu chưa "
          "có, đặt $jsonSchema bằng collMod (nội dung validator ở mục 4.4; validationLevel moderate, validationAction error), rồi tạo 11 index (13 nếu kể "
          "hai index _id). Script chạy lại được nhiều lần và không ghi document nào. Trong docker-compose.yml, tệp được gắn "
          "vào thư mục khởi tạo của image mongo nên tự chạy khi volume còn trống; với volume đã có dữ liệu thì chạy bằng tay "
          "theo lệnh ở đầu tệp:"),
]
C5_2 += code(S + "mongodb_init.js", 23, 24, "Chạy bằng tay trên stack")
C5_2 += code(S + "mongodb_init.js", 119, 139, "Tạo index")
C5_2 += [
    ("p", "Script in ra tên từng collection và index vừa tạo; [[hinh_s15]] là tab Validation của Compass với $jsonSchema vừa đặt; [[hinh_s16]] là tab Indexes của ocr_feedbacks "
          "với unique index receipt_field_uq và compound index status_date_idx (lý do chọn từng index: mục 4.4)."),
    ("sid", "S-15", "Compass: database finance_nosql, tab Validation với $jsonSchema", 5, 10, "hinh_s15"),
    ("sid", "S-16", "Compass: tab Indexes của ocr_feedbacks", 5, 10, "hinh_s16"),
    ("h3", "Elasticsearch: index transactions"),
    ("p", "Elasticsearch của dự án chạy với action.auto_create_index=false, nên index transactions không bao giờ tự sinh "
          "với mapping động: nó chỉ được tạo từ hai tệp settings và mapping của ứng dụng (analyzer vi_folded, "
          "vi_autocomplete; mục 4.5). Khi chạy với SEARCH_ENGINE=elasticsearch, ứng dụng tự tạo index từ hai tệp đó lúc "
          "khởi động và thử lại mỗi 15 giây cho tới khi tạo được. Để demo trên GUI tool, index được tạo bằng tay theo "
          "scripts/nosql/elasticsearch/README.md, ghép hai tệp thật thành một yêu cầu PUT:"),
]
C5_2 += code(S + "elasticsearch/README.md", 34, 38, "Tạo index từ hai tệp của ứng dụng")
C5_2 += [
    ("p", "[[hinh_s19]] làm cùng việc trong Kibana Dev Tools trên stack demo: xóa index cũ, PUT index với settings và "
          "mapping thật, nạp 47 document bằng _bulk (\"errors\": false) và đếm lại được 47."),
    figure("S-19", "Kibana Dev Tools: tạo index transactions, nạp _bulk và đếm 47 document", 5, None, "hinh_s19"),
    ("h3", "Redis: quy ước khóa và thời gian sống"),
    ("p", "Redis không có schema; cấu trúc được chốt bằng quy ước tên khóa. Mọi khóa bắt đầu bằng ledgermind:, rồi tới tên "
          "tính năng; khóa cache có thêm môi trường (tên profile Spring, mặc định default) và phiên bản lược đồ v1 để đổi "
          "cấu trúc giá trị mà không đọc nhầm dữ liệu cũ. [[bang_khoa_redis]] liệt kê mọi nhóm khóa và TTL; TTL của cache "
          "đọc từ R/redis-cache.properties (dòng 15–25; biến môi trường ghi đè được), mỗi mục bị rút ngắn ngẫu nhiên tối đa 10 % (jitter) để các mục không hết hạn "
          "cùng lúc."),
    ("table", "Quy ước khóa Redis (sau tiền tố ledgermind:)", 5, [2000, 2704, 1500, 1400, 900],
     ["Nhóm", "Mẫu khóa", "Kiểu", "TTL", "AP"],
     [
         ["Cache dashboard người dùng", "<môi trường>:v1:user-dashboard:<userId>", "String (JSON)", "45 s, jitter 10 %",
          "AP-07"],
         ["Cache quán hay mua", "<môi trường>:v1:user-popular-vendors:<userId>", "String (JSON)", "60 s, jitter 10 %",
          "AP-07"],
         ["Cache tổng quan quản trị", "<môi trường>:v1:admin-dashboard-summary:<yyyy-MM>:<ngưỡng>", "String (JSON)",
          "45 s, jitter 10 %", "AP-08"],
         ["Cache thống kê quản trị", "<môi trường>:v1:admin-statistics:monthly-transactions:<yyyy-MM>:<n>",
          "String (JSON)", "60 s, jitter 10 %", "AP-08"],
         ["OTP quên mật khẩu", "password-reset-otp:<email>", "Hash", "5 phút", "AP-05\nAP-06"],
         ["Bảng xếp hạng chi tiêu", "leaderboard:spend:<yyyy-MM>", "Sorted Set", "62 ngày",
          "AP-11\nAP-14"],
         ["Sự kiện quản trị", "admin-events", "Kênh Pub/Sub", "–", "AP-15\nAP-16"],
     ], "Nguồn: R/redis-cache.properties, mã nguồn các service Redis", "bang_khoa_redis"),
]
C5_2 += [
    ("p", "Cấu hình máy chủ Redis (giới hạn bộ nhớ 128 MB với chính sách allkeys-lru, không ghi đĩa, mật khẩu, vô hiệu các "
          "lệnh nguy hiểm) nằm trong dịch vụ redis của docker-compose.yml và được giải thích ở mục 4.3. [[hinh_s18]] là "
          "RedisInsight trên stack demo sau khi nạp dữ liệu: năm khóa ledgermind:∗ với ba kiểu String, Hash, Sorted Set và "
          "cột TTL; khóa OTP còn 290 s. Hash OTP có ba trường code, expiresAt, failedAttempts; Sorted Set có member là "
          "userId và score là tổng chi của tháng; kênh Pub/Sub không lưu tin."),
    figure("S-18", "RedisInsight: các khóa ledgermind:∗ kèm kiểu và TTL", 5, None, "hinh_s18"),
]

# --------------------------------------------------------------------------------------------------------------------
# 5.3 Nhập dữ liệu
# --------------------------------------------------------------------------------------------------------------------

C5_3 = [
    ("p", "[[bang_du_lieu]] ghi nguồn và số bản ghi của từng tập dữ liệu. Có hai loại và mỗi con số trong báo cáo ghi rõ "
          "thuộc loại nào: **dữ liệu demo** (nhỏ, sát thực tế, dùng cho truy vấn và ảnh chụp) và **dữ liệu tổng hợp 100k "
          "(sinh bằng gen_data.py)** (chỉ dùng để đo hiệu năng ở Chương 7)."),
    ("table", "Nguồn và số bản ghi của dữ liệu", 5, [1100, 2404, 1300, 3700],
     ["CSDL", "Collection / index / khóa", "Số bản ghi", "Nguồn dữ liệu, cách sinh"],
     [
         ["Mongo", "finance_nosql_demo\n.ocr_logs", "36 document",
          "Dữ liệu demo: mongodb_demo.js sinh bằng công thức cố định (không ngẫu nhiên), 3 tháng 08–10/2026, hai mô hình "
          "donut-v4 và donut-v5, đúng hình dạng document mà mã Java ghi. Bản JSON: ocr_logs.json trong thư mục scripts/nosql/sample_data"],
         ["Mongo", "finance_nosql_demo\n.ocr_feedbacks", "36 document",
          "Dữ liệu demo: 24 hóa đơn, 12 hóa đơn bị sửa hai trường, không cặp (hóa đơn, trường) nào trùng. Bản JSON: "
          "ocr_feedbacks.json trong thư mục scripts/nosql/sample_data"],
         ["Redis", "ledgermind:∗", "5 khóa",
          "Dữ liệu demo: redis_demo.txt (Q-17..Q-29, Q-41) rồi demo-stack.sh thêm một bảng xếp hạng và một OTP: 3 String "
          "cache, 1 Hash, 1 Sorted Set"],
         ["ES", "transactions", "47 document",
          "Dữ liệu demo: elasticsearch/transactions-bulk.ndjson, 47 giao dịch tiếng Việt của 3 người dùng, tháng 08–10/2026, "
          "nạp bằng _bulk"],
         ["PG, Mongo, ES", "Bảng và collection tương ứng", "100.000 giao dịch",
          "Dữ liệu tổng hợp 100k (sinh bằng gen_data.py, seed 42): 100.000 giao dịch, 34.943 hóa đơn, 1.000 người dùng, "
          "100.000 ocr_logs, 45.471 ocr_feedbacks; chỉ nạp vào container đo E1–E5, không nạp vào stack demo"],
     ], "Nguồn: scripts/nosql, scripts/nosql/bench (gen_data.py)", "bang_du_lieu"),
    ("p", "**Dữ liệu mẫu dạng JSON.** Hai tệp scripts/nosql/sample_data/ocr_logs.json và ocr_feedbacks.json là dữ liệu demo "
          "của MongoDB xuất ra bằng mongoexport --jsonArray --jsonFormat=canonical (mỗi tệp một mảng JSON, dạng Extended JSON "
          "canonical để giữ kiểu Long và Date mà $jsonSchema đòi hỏi). Nhóm đã kiểm hai tệp bằng cách nạp lại vào một "
          "database rỗng chỉ có schema (container dùng một lần, 28/10/2026): mongoimport báo 36 và 36 document, không document "
          "nào lỗi; database có 13 index; một document đọc lại như sau (ẩn _id và _class):"),
    ("code", "mongoimport --db finance_nosql_demo --collection ocr_feedbacks --jsonArray --file sample_data/ocr_feedbacks.json\n"
             "36 document(s) imported successfully. 0 document(s) failed to import.\n"
             "{\n"
             "  fieldError: 'seller_name', receiptId: Long('530'), aiValue: 'Ph0 Th1n', expectedValue: 'Phở Thìn Bờ Hồ',\n"
             "  isResolved: false, modelVersion: 'donut-v5', reportedAt: ISODate('2026-10-20T08:00:00.000Z'),\n"
             "  transactionId: Long('1030'), updatedAt: ISODate('2026-10-21T09:00:00.000Z'), userId: Long('2')\n"
             "}"),
    ("p", "(Document được in gọn lại trên ít dòng hơn, giá trị giữ nguyên; ocr_logs.json nhập theo cùng lệnh, cũng 36 document. "
          "Lần đọc thô của AI trong ocr_logs giữ đúng giá trị AI đọc sai, ví dụ log của giao dịch 1030 ghi \"Ph0 Th1n\".) Độ tin cậy trong dữ liệu demo là số đặt sẵn "
          "để minh họa thống kê; câu trả lời thật của DONUT V5 không có độ tin cậy nên ứng dụng ghi null. Ngoài các script "
          "trên, core-api có bộ nạp dữ liệu demo riêng (biến SEED_DEMO, mặc định tắt) ghi log và phản hồi OCR cho các hóa "
          "đơn nó vừa tạo ở PostgreSQL; bộ nạp này không được dùng cho các truy vấn của chương."),
    ("p", "[[hinh_s17]] là danh sách collection của finance_nosql_demo trong Compass sau khi nạp: 36 và 36 document."),
    ("sid", "S-17", "Compass: database finance_nosql_demo với 36 ocr_logs và 36 ocr_feedbacks", 5, 10, "hinh_s17"),
]

# --------------------------------------------------------------------------------------------------------------------
# 5.4 / 5.5 Truy vấn
# --------------------------------------------------------------------------------------------------------------------

C5_4 = [
    ("p", f"Đồ án có {N_CB + N_NC} truy vấn Q-01..Q-41 trên ba CSDL: {N_CB} truy vấn cơ bản và {N_NC} truy vấn nâng cao, "
          "mỗi CSDL có cả hai loại ([[bang_dem_q]]). Yêu cầu bằng lời của người dùng, thao tác và mẫu truy cập (AP) của mỗi "
          "truy vấn nằm trong hai bảng tóm tắt; bên dưới mỗi bảng, từng truy vấn có câu lệnh nguyên văn trong script kèm số "
          "dòng, kết quả chạy và ảnh kết quả trên GUI tool (S-xx). Ví dụ phân trang là Q-35 (from, size); Q-02, Q-03 chỉ "
          "giới hạn số dòng (limit). Truy vấn MongoDB chạy trên database finance_nosql_demo, truy vấn Redis trên khóa "
          "demo cùng tiền tố với ứng dụng, truy vấn Elasticsearch trên index transactions với 47 document demo."),
    ("table", "Số truy vấn theo CSDL và loại", 5, [1600, 1000, 1000, 900, 4004],
     ["CSDL", "Cơ bản", "Nâng cao", "Tổng", "Thao tác tiêu biểu"],
     [
         ["MongoDB", str(COUNTS[("MongoDB", "CB")]), str(COUNTS[("MongoDB", "NC")]),
          str(COUNTS[("MongoDB", "CB")] + COUNTS[("MongoDB", "NC")]),
          "Cơ bản: tìm, lọc, sắp xếp, giới hạn, đếm, thêm, sửa, xóa. Nâng cao: aggregation $match, $group, $lookup, $unwind, "
          "$facet, upsert $setOnInsert, explain"],
         ["Redis", str(COUNTS[("Redis", "CB")]), str(COUNTS[("Redis", "NC")]),
          str(COUNTS[("Redis", "CB")] + COUNTS[("Redis", "NC")]),
          "Cơ bản: Hash, String, TTL, SCAN, cấu hình lưu đĩa. Nâng cao: Sorted Set, MULTI/EXEC, Lua, Pub/Sub"],
         ["Elasticsearch", str(COUNTS[("ES", "CB")]), str(COUNTS[("ES", "NC")]),
          str(COUNTS[("ES", "CB")] + COUNTS[("ES", "NC")]),
          "Cơ bản: đếm, lấy theo id, lọc và sắp xếp, match bỏ dấu, _analyze. Nâng cao: bool + multi_match, fuzzy, "
          "edge_ngram, range, aggregation"],
         ["Tổng", str(N_CB), str(N_NC), str(N_CB + N_NC), "Yêu cầu tối thiểu: 10 cơ bản và 10 nâng cao, CSDL nào cũng có "
                                                          "cả hai loại: đạt"],
     ], "", "bang_dem_q"),
    ("p", "[[bang_q_co_ban]] tóm tắt các truy vấn cơ bản; chi tiết từng truy vấn ở các mục con. Thứ tự trong bảng theo "
          "CSDL nên Q-29 (Redis) đứng trước Q-30. Các truy vấn thêm, sửa, xóa (Q-05..Q-08) làm đổi dữ liệu demo; chạy lại "
          "demo-stack.sh load để có lại trạng thái ban đầu."),
    q_table("CB", "Truy vấn cơ bản", "bang_q_co_ban"),
    ("p", "Câu lệnh đầy đủ và kết quả của từng truy vấn trong bảng trên được trình bày ngay sau đây, theo thứ tự của bảng."),
] + q_section("CB")

C5_5 = [
    ("p", "Truy vấn nâng cao trả lời các câu hỏi của ứng dụng: thống kê chất lượng OCR cho quản trị viên (MongoDB), bảng xếp "
          "hạng, kiểm tra OTP và sự kiện realtime (Redis), tìm kiếm tiếng Việt không dấu, sai chính tả, gợi ý và thống kê chi "
          "tiêu (Elasticsearch). [[bang_q_nang_cao]] tóm tắt. Một số truy vấn chỉ có trong script để minh họa khả năng của "
          "CSDL, ứng dụng chưa có API tương ứng: Q-13, Q-14 (AP-37) và Q-38..Q-40 (AP-36); điều này được ghi lại ở từng truy "
          "vấn."),
    q_table("NC", "Truy vấn nâng cao", "bang_q_nang_cao"),
    ("p", "Câu lệnh đầy đủ và kết quả của từng truy vấn trong bảng trên được trình bày ngay sau đây, theo thứ tự của bảng."),
] + q_section("NC")

# --------------------------------------------------------------------------------------------------------------------
# 5.6 Import/export, sao lưu, khôi phục
# --------------------------------------------------------------------------------------------------------------------

C5_6 = [
    ("p", "Mỗi CSDL được kiểm theo cùng một nhịp: **đếm → sao lưu hoặc xuất → xóa → khôi phục hoặc nhập → đếm lại**, và số "
          "đếm trước, sau phải bằng nhau. Các lệnh nằm trong scripts/nosql/backup_restore.md và chạy trong container dùng một "
          "lần hoặc trên stack demo. [[bang_sao_luu]] tóm tắt; vai trò của từng CSDL quyết định mức đầu tư cho sao lưu: "
          "PostgreSQL là nguồn sự thật, MongoDB giữ bản sao phân tích, còn Redis và Elasticsearch dựng lại được từ "
          "PostgreSQL."),
    ("table", "Nhập/xuất, sao lưu/khôi phục và số đếm trước, sau", 5, [1000, 2300, 2300, 1904, 1000],
     ["CSDL", "Nhập / xuất", "Sao lưu / khôi phục", "Đếm trước → sau xóa → sau khôi phục", "Hình"],
     [
         ["Mongo", "mongoexport / mongoimport (Extended JSON canonical; dạng mảng JSON cho sample_data)",
          "mongodump / mongorestore (archive gzip); trang /admin/backup", "36, 36, 13 index, 2 validator → 0 → 36, 36, "
                                                                          "13, 2", "[[hinh_s61]]\n[[hinh_s62]]"],
         ["Redis", "redis-cli < script; redis-cli --rdb", "RDB: SAVE, chép dump.rdb, khởi động lại với tệp",
          "4 khóa → 0 → 4 khóa; ZCARD 3; TTL còn lại", "[[hinh_s63]]\n[[hinh_s86]]"],
         ["ES", "_search (xuất) / _bulk (nhập)", "Snapshot / restore (repository fs); hoặc reindex từ PostgreSQL",
          "47 → index_not_found → 47", "[[hinh_s64]]\n[[hinh_s87]]"],
     ], "Nguồn: scripts/nosql/backup_restore.md; số đo: docs/nosql/bench_results.md", "bang_sao_luu"),
    ("h3", "MongoDB: mongodump/mongorestore, mongoexport/mongoimport và trang quản trị"),
    ("p", "**Sao lưu nhị phân.** mongodump ghi cả document, index và validator vào một archive nén; mongorestore khôi phục "
          "nguyên trạng. Kịch bản trong container dùng một lần:"),
]
C5_6 += code(S + "backup_restore.md", 21, 26, "Sao lưu, xóa, khôi phục")
C5_6 += [
    ("p", "Chạy trên stack demo ngày 28/10/2026 (MongoDB 6.0.28, giới hạn 512 MB như docker-compose.yml): trước khi xóa có "
          "36 ocr_logs, 36 ocr_feedbacks, 13 index và 2 validator; archive 4.612 byte; sau dropDatabase mọi số về 0; sau "
          "khôi phục lại đúng 36, 36, 13, 2 ([[hinh_s61]]). Lệnh time mongorestore đo 0,604 s ở lần trong ảnh; năm lần đo "
          "thêm có trung vị 0,543 s. Mục tiêu NFR-13 (khôi phục dưới 5 phút với dữ liệu demo) đạt với mongorestore."),
    figure("S-61", "MongoDB: đếm → mongodump → xóa → time mongorestore → đếm lại", 5, None, "hinh_s61"),
    ("p", "**Xuất, nhập JSON.** mongoexport phải dùng --jsonFormat=canonical: xuất dạng thường thì transactionId thành số "
          "nguyên 32 bit và bị $jsonSchema từ chối khi nhập lại. Vì mongoexport không mang theo index và validator, schema "
          "được tạo lại bằng chính mongodb_init.js trước khi nhập:"),
]
C5_6 += code(S + "backup_restore.md", 44, 49, "Xuất, xóa, tạo schema, nhập")
C5_6 += [
    ("p", "Kết quả: tệp xuất có 36 và 36 dòng; sau khi nhập lại có 36, 36, 13 index, 2 validator, transactionId vẫn kiểu Long "
          "và createdAt kiểu ISODate ([[hinh_s62]]). Hai tệp JSON mẫu ở mục 5.3 là cùng cách xuất với tùy chọn --jsonArray "
          "và đã được nhập lại thành công theo cùng cách."),
    figure("S-62", "MongoDB: mongoexport → xóa → mongodb_init.js → mongoimport → đếm lại", 5, None, "hinh_s62"),
    ("p", "**Từ trang quản trị.** Thẻ MongoDB trên /admin/backup có hai nút Sao lưu và Khôi phục, gọi "
          "/admin/backup/mongo/execute và /admin/backup/mongo/restore. Sao lưu chạy mongodump cho cả database finance_nosql "
          "vào volume core_backups; khôi phục lấy tệp mới nhất và chỉ thay hai collection ocr_logs, ocr_feedbacks (--drop "
          "kèm --nsInclude), collection khác giữ nguyên. Mỗi lúc chỉ một thao tác chạy, mật khẩu không vào tham số dòng lệnh "
          "hay log, mỗi lần thành công ghi một dòng nhật ký kiểm toán. Kiểm thử tích hợp trên MongoDB thật (Testcontainers) "
          "chứng minh dump → xóa → restore đưa hai collection trở lại và không đụng collection khác (TC-29, lớp "
          "MongoBackupServiceIntegrationTest). Kịch bản demo: đếm, bấm Sao lưu ([[hinh_s65]]), xóa vài phản hồi trên /admin/ocr-feedbacks, bấm Khôi "
          "phục, đếm lại bằng Compass ([[hinh_s66]])."),
    ("sid", "S-65", "Trang /admin/backup, thẻ MongoDB: sao lưu thành công", 5, 10, "hinh_s65"),
    ("sid", "S-66", "Khôi phục MongoDB từ /admin/backup và đếm lại bằng Compass", 5, 10, "hinh_s66"),
    ("y", "Ghi chú cho nhóm: thời gian từ lúc bấm Khôi phục tới khi thông báo hiện trên /admin/backup chưa đo (cần ứng dụng "
          "chạy); khi chụp S-66 thì bấm giờ và ghi số vào đây."),
    ("h3", "Redis: RDB, redis-cli và redis-cli --rdb"),
    ("p", "Redis của hệ thống chạy không ghi đĩa (save rỗng, appendonly no) và đã vô hiệu FLUSHALL, FLUSHDB, vì mọi khóa đều "
          "dựng lại được: cache tự nạp lại từ PostgreSQL, bảng xếp hạng dựng lại khi thiếu khóa, chỉ OTP đang chờ là mất và "
          "người dùng bấm gửi lại. Bài sao lưu dưới đây vì vậy chạy trong một container redis:8.10-alpine dùng một lần, mạng "
          "none, bật RDB:"),
]
C5_6 += code(S + "backup_restore.md", 122, 130, "Sao lưu RDB và khởi động lại với tệp")
C5_6 += [
    ("p", "Kết quả ([[hinh_s63]]): trước SAVE có 4 khóa, bảng xếp hạng 3 người, đứng đầu là người dùng 4; sau FLUSHALL còn 0 "
          "khóa; khởi động lại với dump.rdb thì có lại 4 khóa, 3 người, người dùng 4 đứng đầu, và khóa cache vẫn giữ TTL (còn "
          "281 s). Nhập dữ liệu bằng redis-cli đọc script từ stdin, xuất bằng redis-cli --rdb tải bản RDB qua mạng mà không "
          "cần vào máy chủ ([[hinh_s86]]): trên database logic 3 của stack demo, DBSIZE từ 0 lên 3 sau khi chạy "
          "redis_demo.txt (ba khóa cache còn lại sau Q-28), và lệnh xuất báo \"Transfer finished with success after 575 "
          "bytes\"."),
    figure("S-63", "Redis: SAVE → FLUSHALL → khởi động lại với dump.rdb → đếm lại", 5, None, "hinh_s63"),
    figure("S-86", "Redis: nhập bằng redis-cli < redis_demo.txt và xuất bằng redis-cli --rdb", 5, None, "hinh_s86"),
    ("h3", "Elasticsearch: snapshot/restore, _search/_bulk và reindex"),
    ("p", "**Snapshot.** Snapshot ghi index vào một repository dạng thư mục (stack thật: path.repo trỏ tới volume "
          "elasticsearch_snapshots). Kịch bản:"),
]
C5_6 += code(S + "backup_restore.md", 163, 168, "Tạo repository, snapshot, xóa, restore")
C5_6 += [
    ("p", "Kết quả ([[hinh_s64]]): _count 47; snapshot SUCCESS; sau DELETE, truy vấn báo index_not_found_exception; restore "
          "1/1 shard; _count lại 47, và analyzer cũng trở lại (_analyze vi_folded của \"Phở Bò\" vẫn ra pho, bo). Kibana làm "
          "được cùng việc qua Snapshot and Restore (mục 2.5)."),
    figure("S-64", "Elasticsearch: snapshot → xóa index → restore → _count", 5, None, "hinh_s64"),
    ("p", "**Xuất, nhập.** Xuất bằng GET transactions/_search?size=1000 (47 _id); xóa index; tạo lại từ hai tệp settings và "
          "mapping của ứng dụng; nhập lại bằng _bulk: \"errors\": false, 47 lần 201, _count 47 ([[hinh_s87]]). **Cách rẻ "
          "nhất** là không sao lưu: index chỉ là bản sao, nên sau mất mát hoặc sau khi khôi phục PostgreSQL chỉ cần dựng lại "
          "toàn bộ từ PostgreSQL bằng POST /api/admin/search/reindex hoặc nút trên trang /admin/nosql (mục 6.3)."),
    figure("S-87", "Elasticsearch: xuất _search → xóa → tạo lại index → nhập _bulk → _count 47", 5, None, "hinh_s87"),
]

# --------------------------------------------------------------------------------------------------------------------
# 6.0 Mở chương
# --------------------------------------------------------------------------------------------------------------------

C6_0 = [
    ("p", "Chương này ứng với tiêu chí 8 (kết nối CSDL với phần mềm) và 9 (demo chức năng). Phần mềm là LedgerMind: dịch vụ "
          "core-api viết bằng Java (Spring Boot 3.2.5), ứng dụng di động Flutter và web quản trị Thymeleaf do core-api phục "
          "vụ. Đoạn mã được trích nguyên văn kèm đường dẫn và số dòng; J/ là thư mục mã Java và R/ là thư mục tài nguyên của "
          "core-api, như ở Chương 4."),
    ("y", "Ghi chú cho nhóm (xóa trước khi nộp): các hình của mục 6.3 và S-82 cần ứng dụng chạy; Tiến chụp theo "
          "docs/nosql/screenshots.md rồi thay ảnh giữ chỗ, số hình và chú thích giữ nguyên."),
]

# --------------------------------------------------------------------------------------------------------------------
# 6.1 Kiến trúc ứng dụng
# --------------------------------------------------------------------------------------------------------------------

C6_1 = [
    ("p", "Kiến trúc tổng thể và sơ đồ triển khai đã trình bày ở mục 4.1, sơ đồ module và danh sách API ở mục 4.10. Mục này "
          "chỉ ra các tầng đó nằm ở đâu trong project. core-api theo kiến trúc phân tầng của Spring: controller nhận request, "
          "service giữ nghiệp vụ, tầng truy cập dữ liệu nói chuyện với từng CSDL ([[bang_tang]])."),
    ("table", "Các tầng của ứng dụng và vị trí trong project", 6, [1700, 3404, 3400],
     ["Tầng", "Thư mục, lớp tiêu biểu", "Phần liên quan NoSQL"],
     [
         ["Giao diện", "mobile-app/lib (Flutter); R/templates/admin (Thymeleaf), R/static/admin/js",
          "Ô tìm kiếm Sổ cái gọi API tìm kiếm; trang quản trị nhận sự kiện realtime qua EventSource"],
         ["Controller", "J/Controller: TransactionController, ReceiptController, AdminOcrFeedbackController, "
                        "AdminNoSqlPageController, AdminLeaderboardController, AdminSearchController, AdminEventsController",
          "REST dưới /api, trang web dưới /admin, luồng SSE /admin/events"],
         ["Service", "J/Service: TransactionService, ReceiptProcessingService, OcrMongoService, MongoBackupService, "
                     "RedisPasswordResetOtpStore; J/Service/Cache, J/Service/Search, J/Service/Realtime",
          "Ghi PostgreSQL trong giao dịch; phát sự kiện để các bộ nghe ghi NoSQL sau commit"],
         ["Truy cập dữ liệu", "J/Repository (JPA), J/Repository/Mongo; MongoTemplate, StringRedisTemplate, "
                              "ElasticsearchOperations; J/Document (OcrRawLog, OcrFeedback, TransactionSearchDocument)",
          "Ánh xạ document MongoDB, document Elasticsearch; lệnh Redis và Lua"],
         ["Cấu hình", "J/Config: CacheConfig, FallbackCacheErrorHandler, AsyncConfig, SearchConfig, RealtimeConfig; "
                      "R/redis-cache.properties, R/search.properties, R/ocr-analytics.properties, R/elasticsearch",
          "Kết nối, timeout, TTL, pool luồng nền, chọn công cụ tìm kiếm"],
     ], "", "bang_tang"),
    ("p", "Luồng dữ liệu chung của mọi chức năng ghi: request đi qua controller tới service, service ghi PostgreSQL rồi "
          "commit; các sự kiện phát trong giao dịch (TransactionChangedEvent, OcrProcessedEvent, StatisticsChangedEvent) "
          "chỉ được xử lý **sau commit** bởi các bộ nghe chạy trên pool luồng nền mongoAsyncExecutor, và các bộ nghe này mới "
          "ghi Redis, MongoDB, Elasticsearch. Chức năng đọc thì đi thẳng tới CSDL phục vụ nó (cache Redis, MongoDB cho "
          "thống kê OCR, Elasticsearch cho tìm kiếm), luôn có PostgreSQL làm đường dự phòng ở những chỗ mục 6.2 nêu."),
]

# --------------------------------------------------------------------------------------------------------------------
# 6.2 Kết nối CSDL với phần mềm
# --------------------------------------------------------------------------------------------------------------------

C6_2 = [
    ("p", "Cả ba CSDL NoSQL được kết nối qua Spring Data (phiên bản thư viện và driver ở [[bang_moi_truong]]), cấu hình bằng "
          "biến môi trường (mật khẩu không nằm trong mã). "
          "[[bang_ket_noi]] tóm tắt cấu hình, lớp truy cập và cách xử lý khi CSDL lỗi; các đoạn mã sau đó là cấu "
          "hình và lớp truy cập thật."),
    ("table", "Kết nối từng CSDL NoSQL", 6, [1000, 2500, 2600, 2404],
     ["CSDL", "Cấu hình kết nối", "Lớp truy cập dữ liệu", "Khi CSDL lỗi"],
     [
         ["Redis", "Host, cổng, mật khẩu từ biến môi trường; kết nối 1 s, lệnh 500 ms",
          "Spring Cache (@Cacheable); StringRedisTemplate và script Lua; bộ nghe kênh Pub/Sub",
          "Cache, bảng xếp hạng: đọc PostgreSQL; OTP: báo lỗi rõ ràng; Pub/Sub: thử đăng ký lại mỗi 10 s"],
         ["Mongo", "Biến MONGO_URI: database finance_nosql, authSource admin, timeout 5 s; health tắt",
          "Hai MongoRepository; MongoTemplate cho lọc, phân trang, aggregation, upsert",
          "Ghi sau commit trên luồng nền; lỗi chỉ ghi log, dữ liệu gốc đã ở PostgreSQL"],
         ["ES", "Biến SEARCH_ENGINE chọn công cụ; địa chỉ, mật khẩu từ biến môi trường; kết nối 1 s, socket 2 s",
          "ElasticsearchOperations; một lớp document, không repository",
          "Tìm kiếm: PostgreSQL trả lời (engine=postgres); cập nhật index: ghi log"],
     ], "", "bang_ket_noi"),
    ("h3", "Kết nối Redis"),
    ("p", "Spring Boot tạo kết nối Lettuce từ các thuộc tính trong redis-cache.properties; docker-compose.yml chỉ truyền host, "
          "cổng và mật khẩu (dịch vụ redis không mở cổng ra máy chủ). Hai timeout là cận trên của thời gian một Redis chậm "
          "hoặc không với tới có thể cộng vào một request:"),
]
C6_2 += code(R + "redis-cache.properties", 4, 13, "Kết nối Redis")
C6_2 += code("docker-compose.yml", 259, 262, "Biến môi trường của core-api")
C6_2 += [
    ("p", "**Xử lý lỗi kết nối.** Khi mất kết nối, Lettuce được đặt REJECT_COMMANDS để lệnh hỏng ngay thay vì xếp hàng chờ "
          "hết timeout; Lettuce tự nối lại ở nền:"),
]
C6_2 += code(J + "Config/CacheConfig.java", 117, 122, "Lệnh hỏng ngay khi mất kết nối")
C6_2 += [
    ("p", "Mọi lỗi của cache đi vào FallbackCacheErrorHandler: đọc lỗi được coi là trượt cache và thống kê được tính từ "
          "PostgreSQL, ghi lỗi thì trả kết quả mà không cache, xóa lỗi thì để mục cache tự hết hạn theo TTL. Đây là cơ chế "
          "dự phòng (fallback) cho từng lần gọi, không ngắt mạch: trong lúc Redis treo, mỗi request vẫn có thể chờ tới timeout "
          "lệnh 500 ms."),
]
C6_2 += code(J + "Config/FallbackCacheErrorHandler.java", 19, 29, "Đọc, ghi cache lỗi")
C6_2 += [
    ("p", "Bảng xếp hạng dùng StringRedisTemplate trực tiếp và cũng rơi về PostgreSQL khi Redis lỗi; lỗi của PostgreSQL thì "
          "không bị che. Riêng OTP quên mật khẩu cố ý không có dự phòng: Redis lỗi thì người dùng nhận thông báo \"Dịch vụ mã "
          "OTP tạm thời gián đoạn\" thay vì một mã không kiểm tra được."),
]
C6_2 += code(J + "Service/Cache/SpendingLeaderboardService.java", 88, 102, "Đọc top N, rơi về PostgreSQL")
C6_2 += [
    ("h3", "Kết nối MongoDB"),
    ("p", "Chuỗi kết nối là biến MONGO_URI do docker-compose.yml dựng từ tên và mật khẩu trong tệp .env; tệp application.yml "
          "cục bộ (không đưa vào kho mã) gán nó cho spring.data.mongodb.uri. Hai timeout 5 s giới hạn thời gian một lần ghi "
          "chờ MongoDB đang sập; health của MongoDB tắt và core-api khởi động không cần MongoDB:"),
]
C6_2 += code("docker-compose.yml", 232, 236, "Chuỗi kết nối MongoDB của core-api")
C6_2 += [
    ("p", "Lớp truy cập gồm document được ánh xạ bằng annotation và repository của Spring Data. Annotation index trên "
          "document chỉ để mô tả, vì việc tạo index tự động tắt và mongodb_init.js tạo index (mục 5.2):"),
]
C6_2 += code(J + "Document/OcrRawLog.java", 12, 21, "Document ocr_logs")
C6_2 += code(J + "Repository/Mongo/OcrFeedbackRepository.java", 10, 15, "Repository ocr_feedbacks")
C6_2 += [
    ("p", "Hai phương thức khai báo thêm trong repository trên (và hai phương thức của OcrRawLogRepository) hiện không được mã "
          "chính gọi tới; các truy vấn lọc, phân trang, thống kê và upsert dùng MongoTemplate với Criteria, như danh sách "
          "phản hồi của trang quản trị:"),
]
C6_2 += code(J + "Service/OcrMongoService.java", 228, 233, "Danh sách phản hồi theo bộ lọc")
C6_2 += [
    ("p", "**Xử lý lỗi kết nối.** Mọi lần ghi MongoDB chạy sau commit trên pool mongoAsyncExecutor, nên MongoDB chậm hay sập "
          "không giữ request của người dùng. Lỗi chỉ được ghi log, không ném về luồng gọi; hóa đơn và giao dịch đã nằm an "
          "toàn ở PostgreSQL (OcrMongoServiceTest, TC-30):"),
]
C6_2 += code_cut(J + "Service/OcrMongoService.java", [(95, 97), (126, 129)], "Bộ nghe ghi ocr_logs")
C6_2 += [
    ("h3", "Kết nối Elasticsearch"),
    ("p", "Công cụ tìm kiếm được chọn bằng SEARCH_ENGINE: postgres (mặc định) thì ứng dụng không bao giờ gọi tới "
          "Elasticsearch; elasticsearch thì index được giữ khớp sau mỗi commit và được dùng để tìm. Client chỉ kết nối ở "
          "request đầu tiên, nên tạo client không cần Elasticsearch đang chạy:"),
]
C6_2 += code(R + "search.properties", 5, 18, "Chọn công cụ và kết nối Elasticsearch")
C6_2 += [
    ("p", "Không dùng repository: document được khai báo với createIndex = false, settings và mapping lấy từ hai tệp JSON, "
          "còn truy vấn được dựng bằng ElasticsearchOperations:"),
]
C6_2 += code(J + "Document/Search/TransactionSearchDocument.java", 28, 33, "Document của index transactions")
C6_2 += [
    ("p", "**Xử lý lỗi kết nối.** Khi tìm kiếm, mọi lỗi của Elasticsearch (sập, chậm quá socket timeout 2 s, trả kết quả "
          "không dùng được) chuyển sang PostgreSQL và phản hồi ghi engine=postgres; lúc chỉ mục đang dựng lại hoặc chưa sẵn sàng "
          "(indexIsUsable trả false) thì PostgreSQL trả lời ngay từ đầu; kết quả của cả hai công cụ luôn được nạp "
          "lại từ PostgreSQL theo id và chủ sở hữu, nên index cũ không làm hiện dòng đã xóa hay dòng của người khác:"),
]
C6_2 += code(J + "Service/Search/TransactionSearchService.java", 60, 75, "Tìm bằng Elasticsearch, lỗi thì PostgreSQL")
C6_2 += [
    ("p", "Khi cập nhật index sau commit, lỗi chỉ được ghi log; document giữ bản cũ tới lần đổi kế tiếp của giao dịch đó hoặc "
          "lần reindex, còn PostgreSQL đã commit không bị ảnh hưởng:"),
]
C6_2 += code(J + "Service/Search/TransactionSearchIndexer.java", 157, 165, "Cập nhật index sau commit")

# --------------------------------------------------------------------------------------------------------------------
# 6.3 Demo các chức năng
# --------------------------------------------------------------------------------------------------------------------

C6_3 = [
    ("p", "Chức năng được demo theo bốn nhóm của tiêu chí 9; mỗi thao tác có ảnh giao diện và, khi thao tác làm đổi dữ "
          "liệu NoSQL, ảnh GUI tool cho thấy dữ liệu đã đổi. [[bang_demo]] tóm tắt và ghi rõ thao tác nào làm được trên giao "
          "diện, thao tác nào chỉ có API REST (gọi bằng Postman, bộ request nộp kèm scripts/nosql/NoSQL_Postman_Collection.json)."),
    ("table", "Bốn nhóm chức năng demo", 6, [1500, 3004, 1100, 1300, 1600],
     ["Nhóm", "Chức năng, thao tác", "CSDL", "Minh chứng", "Giao diện"],
     [
         ["Quản trị người dùng", "Đăng nhập (JWT trên di động, phiên trên web), phân quyền ROLE_ADMIN; quên mật khẩu bằng OTP",
          "PG, Redis", "[[hinh_s67]], [[hinh_s68]], [[hinh_s69]], [[hinh_s70]]", "Di động, web"],
         ["Thao tác trên CSDL", "Tìm, lọc phản hồi OCR; đánh dấu đã xử lý; xóa; sao lưu, khôi phục MongoDB; dựng lại index và "
                                "bảng xếp hạng", "Mongo, ES, Redis",
          "[[hinh_s71]], [[hinh_s72]], [[hinh_s73]], [[hinh_s65]], [[hinh_s66]]", "Web; REST tương đương"],
         ["Nghiệp vụ", "Ghi, sửa giao dịch; tìm giao dịch tiếng Việt; quét hóa đơn và sửa kết quả AI (FR-03..FR-06, FR-08)",
          "PG, ES, Mongo", "[[hinh_s74]], [[hinh_s75]], [[hinh_s76]]", "Di động"],
         ["Hỗ trợ", "Dashboard và cache thống kê; bảng xếp hạng tháng; biểu đồ chất lượng OCR; thông báo realtime",
          "Redis, Mongo", "[[hinh_s77]], [[hinh_s78]], [[hinh_s79]], [[hinh_s80]], [[hinh_s81]]", "Web, di động"],
     ], "", "bang_demo"),
    ("h3", "Nhóm 1: quản trị người dùng và phân quyền"),
    ("p", "Người dùng di động đăng nhập và nhận JWT; web quản trị dùng form đăng nhập và phiên HTTP ([[hinh_s67]], "
          "[[hinh_s68]]). Mọi đường dẫn /admin/∗∗ và /api/admin/∗∗ đòi ROLE_ADMIN ở cấu hình bảo mật, và hầu hết các controller "
          "quản trị kiểm thêm một lần bằng @PreAuthorize. Tài khoản, vai trò và danh sách JWT bị thu hồi nằm ở PostgreSQL; phần "
          "Redis duy nhất của nhóm này là OTP quên mật khẩu: người dùng gửi email ([[hinh_s69]], POST "
          "/api/auth/forgot-password), mã 6 số được lưu thành Hash ledgermind:password-reset-otp:<email> có TTL 5 phút "
          "([[hinh_s70]]), rồi POST /api/auth/reset-password kiểm mã bằng script Lua (đúng thì xóa, sai lần thứ 3 thì hủy)."),
    ("sid", "S-67", "Ứng dụng di động: đăng nhập", 6, 15, "hinh_s67"),
    ("sid", "S-68", "Web quản trị: đăng nhập và trang người dùng với cột vai trò", 6, 14, "hinh_s68"),
    ("sid", "S-69", "Ứng dụng di động: quên mật khẩu, nhập OTP", 6, 15, "hinh_s69"),
    ("sid", "S-70", "RedisInsight: Hash OTP của email vừa yêu cầu, kèm TTL", 6, 14, "hinh_s70"),
    ("h3", "Nhóm 2: thao tác trên CSDL"),
    ("p", "**Tìm, lọc.** Trang /admin/ocr-feedbacks đọc MongoDB: lọc theo trường bị sửa, trạng thái, khoảng ngày, phân trang "
          "20 dòng, kèm ba biểu đồ thống kê (lỗi theo trường, theo mô hình, độ tin cậy theo tháng) ([[hinh_s72]]). Cùng dữ "
          "liệu có qua API GET /api/admin/ocr-feedbacks với thêm tham số sắp xếp và cỡ trang ([[hinh_s71]])."),
    ("sid", "S-71", "Postman: GET /api/admin/ocr-feedbacks", 6, 14, "hinh_s71"),
    ("sid", "S-72", "Trang /admin/ocr-feedbacks: danh sách lọc và ba biểu đồ", 6, 14, "hinh_s72"),
    ("p", "**Sửa, xóa.** Trên cùng trang, nút đánh dấu đã xử lý (/admin/ocr-feedbacks/{id}/resolve) và nút xóa "
          "(/admin/ocr-feedbacks/{id}/delete); API tương đương là PATCH /api/admin/ocr-feedbacks/{id}/resolve và DELETE "
          "/api/admin/ocr-feedbacks/{id}. Compass cho thấy isResolved đổi thành true và document bị xóa biến mất "
          "([[hinh_s73]])."),
    ("sid", "S-73", "Đánh dấu đã xử lý và xóa phản hồi trên web; Compass thấy dữ liệu đổi", 6, 14, "hinh_s73"),
    ("p", "**Thêm.** Không có form tạo document MongoDB bằng tay: document ocr_feedbacks được thêm tự động khi người dùng sửa "
          "kết quả AI trên di động (nhóm 3, [[hinh_s76]]), document ocr_logs khi một hóa đơn được quét và lưu. **Sao lưu, "
          "khôi phục** MongoDB từ trang /admin/backup đã trình bày ở mục 5.6 ([[hinh_s65]], [[hinh_s66]]). Redis và "
          "Elasticsearch không có nút sao lưu (dựng lại từ PostgreSQL); việc dựng lại có nút trên trang /admin/nosql "
          "(nhóm 4)."),
    ("p", "**Chỉ có API REST (không có trang web):** GET /api/admin/ocr-logs (đọc log OCR thô theo trang), GET "
          "/api/admin/ocr-feedbacks/analytics (số liệu thô của ba biểu đồ), GET /api/admin/leaderboard với tham số month và "
          "limit tùy ý (trang web hiện top 5 và top 10), GET /api/admin/receipts/{id}/attempts (các lần đọc AI thô, ở "
          "PostgreSQL). Sao lưu Redis và Elasticsearch, thống kê chi tiêu bằng Elasticsearch (Q-38..Q-40) chỉ có ở script."),
    ("h3", "Nhóm 3: quản lý theo nghiệp vụ"),
    ("p", "**Tìm giao dịch.** Ô tìm kiếm của Sổ cái gọi GET /api/transactions/search sau 350 ms ngừng gõ; gõ \"pho\" ra các "
          "dòng \"Phở\" ([[hinh_s74]]). Khi SEARCH_ENGINE=elasticsearch, giao dịch vừa tạo xuất hiện trong index ngay sau "
          "commit, đọc được bằng Kibana hoặc Elasticvue ([[hinh_s75]]); khi Elasticsearch không trả lời, PostgreSQL trả lời và "
          "phản hồi ghi engine=postgres (mục 6.4)."),
    ("sid", "S-74", "Ứng dụng di động: Sổ cái tìm \"pho\" ra các dòng \"Phở\"", 6, 15, "hinh_s74"),
    ("sid", "S-75", "Document của giao dịch vừa tạo trong index transactions", 6, 14, "hinh_s75"),
    ("p", "**Quét hóa đơn và sửa kết quả AI.** Sau khi checkout, câu trả lời thô của AI được ghi vào ocr_logs; khi người dùng "
          "sửa tên người bán, tổng tiền hay ngày (PUT /api/receipts/{id}) hoặc gửi số tiền khi AI không đọc được (POST "
          "/api/receipts/feedback/{receiptId}), một document ocr_feedbacks mới xuất hiện trong Compass ([[hinh_s76]]) và quản "
          "trị viên nhận thông báo realtime."),
    ("sid", "S-76", "Quét hóa đơn rồi sửa trên di động; document ocr_feedbacks mới trong Compass", 6, 15, "hinh_s76"),
    ("h3", "Nhóm 4: chức năng hỗ trợ"),
    ("p", "**Thống kê và bảng xếp hạng.** /admin/dashboard hiện tổng quan (qua cache Redis) và top 5 chi tiêu của tháng đọc "
          "từ Sorted Set ([[hinh_s77]]); trang /admin/nosql cho xem số document của index, top 10 của tháng và hai nút dựng "
          "lại chỉ mục tìm kiếm và bảng xếp hạng từ PostgreSQL ([[hinh_s78]]). RedisInsight cho thấy Sorted Set "
          "ledgermind:leaderboard:spend:<yyyy-MM> tương ứng ([[hinh_s79]])."),
    ("sid", "S-77", "/admin/dashboard: top 5 chi tiêu tháng", 6, 14, "hinh_s77"),
    ("sid", "S-78", "/admin/nosql: dựng lại chỉ mục và bảng xếp hạng", 6, 14, "hinh_s78"),
    ("sid", "S-79", "RedisInsight: Sorted Set bảng xếp hạng của tháng", 6, 14, "hinh_s79"),
    ("p", "**Thông báo realtime.** Mọi trang quản trị mở một EventSource tới /admin/events; khi có hóa đơn chờ duyệt, chỗ sửa "
          "OCR mới, hay khi chỉ mục, bảng xếp hạng vừa được dựng lại, một toast và huy hiệu hiện ra ([[hinh_s80]]). "
          "**Cache thống kê.** Mở trang chủ di động làm xuất hiện khóa ledgermind:<môi trường>:v1:user-dashboard:<userId> "
          "trong RedisInsight ([[hinh_s81]]); lần mở sau trong thời gian TTL đọc thẳng từ Redis."),
    ("sid", "S-80", "Toast realtime trên trang quản trị (Redis Pub/Sub → SSE)", 6, 14, "hinh_s80"),
    ("sid", "S-81", "Trang chủ di động và khóa cache user-dashboard trong RedisInsight", 6, 15, "hinh_s81"),
]

# --------------------------------------------------------------------------------------------------------------------
# 6.4 Kết quả áp dụng kỹ thuật nâng cao
# --------------------------------------------------------------------------------------------------------------------

C6_4 = [
    ("p", "Mục 4.13 đã trình bày vấn đề, giải pháp và đoạn mã của từng kỹ thuật; [[bang_ket_qua_ky_thuat]] ghi kết quả đo "
          "hoặc quan sát được và kiểm thử chứng minh. Số đo E1–E5 là độ trễ tầng dữ liệu trên dữ liệu tổng hợp 100k (sinh "
          "bằng gen_data.py), p50, một luồng; E6 là chặng phía server đo bằng bài đo JUnit. Cột kiểm thử ghi mã TC của "
          "Chương 7; tên lớp và số test ở ngay sau bảng."),
    ("table", "Kết quả của các kỹ thuật nâng cao", 6, [1900, 3400, 1300, 1904],
     ["Kỹ thuật", "Kết quả", "Bằng chứng", "Kiểm thử"],
     [
         ["Đa luồng: @Async + sự kiện sau commit",
          "Rollback không làm đổi cache; MongoDB, Elasticsearch lỗi chỉ sinh log, request vẫn thành công; tìm kiếm vẫn trả "
          "lời bằng PostgreSQL khi Elasticsearch dừng", "[[hinh_s82]]",
          "TC-08, TC-09, TC-30, TC-36, TC-40"],
         ["Tác vụ nền @Scheduled", "Index được tạo khi Elasticsearch lên sau ứng dụng, không cần khởi động lại; tác vụ tự "
                                   "dừng khi đã có index", "Kiểm thử", "TC-41 và kiểm thử thử lại việc tạo index"],
         ["Xử lý tranh chấp", "Bảng xếp hạng ghi tổng tuyệt đối bằng Lua (EVALSHA p50 0,067 ms, E3); upsert không tạo bản "
                              "trùng (Q-06, Q-09); khóa ví; hai lần sửa hóa đơn đồng thời: một ghi, một nhận 409; checkout "
                              "lặp không tạo bản trùng", "E3; Q-06, Q-09",
          "TC-14, TC-15, TC-20, TC-21, TC-48, TC-52..TC-54"],
         ["Tối ưu truy vấn", "Index MongoDB 60–65× (E1); cache-aside 11–529× (E4); Sorted Set 66× (E3); chỉ mục đảo 21× và "
                             "không bỏ sót dòng \"Phở\" nào (E2)", "E1–E4; Q-16",
          "TC-05, TC-13, TC-32..TC-35, TC-46"],
         ["Realtime: Pub/Sub → SSE", "publish → SseEmitter.send p50 1,18 ms, p95 1,57 ms, max 3,13 ms; mất 0/300 (E6)",
          "[[hinh_s88]], [[hinh_s80]]", "TC-17, TC-18, TC-19; bài đo E6"],
     ], "Nguồn số đo: docs/nosql/bench_results.md", "bang_ket_qua_ky_thuat"),
    ("lead", "Các lớp kiểm thử tương ứng, số test chạy xanh ngày 27/10/2026 (lớp Elasticsearch: lần chạy 28/10/2026) và mã TC "
             "(thư mục core-backend/src/test):"),
    ("code", "StatisticsCacheTransactionTest                         9  TC-08, TC-09\n"
             "OcrMongoServiceTest                                   20  TC-30\n"
             "TransactionSearchServiceTest                           6  TC-36, TC-37\n"
             "TransactionSearchIndexerIntegrationTest               12  TC-38..TC-42\n"
             "SpendingLeaderboardServiceIntegrationTest             16  TC-12..TC-16\n"
             "OcrMongoServiceMongoIntegrationTest                   15  TC-20..TC-28\n"
             "TransactionServiceTest                               192  TC-52, TC-53\n"
             "ReceiptConcurrencyPostgresTest                         7  TC-54\n"
             "RedisStatisticsCacheIntegrationTest                   15  TC-05..TC-07, TC-55\n"
             "ElasticsearchTransactionSearchEngineIntegrationTest   14  TC-32..TC-35 (28/10/2026)\n"
             "AdminEventRelayIntegrationTest                         3  TC-17, TC-18\n"
             "AdminEventsControllerTest                              8  TC-19"),
    ("p", "**Đa luồng và dự phòng khi Elasticsearch dừng.** [[hinh_s82]] gọi cùng một yêu cầu tìm kiếm hai lần: khi "
          "Elasticsearch chạy, phản hồi ghi engine=elasticsearch; sau khi dừng container Elasticsearch, cùng yêu cầu vẫn "
          "trả lời với engine=postgres. Độ trễ quan sát khi dừng dịch vụ được ghi ở mục 7.3; thời gian chờ thêm tối đa bằng "
          "timeout kết nối 1 s hoặc socket 2 s đã cấu hình. Trong lúc đó việc ghi giao dịch vẫn thành công, vì cập nhật index "
          "chạy sau commit trên luồng nền (TC-40)."),
    ("sid", "S-82", "Postman: /api/transactions/search trả engine=elasticsearch, rồi engine=postgres sau khi dừng "
                    "Elasticsearch", 6, 14, "hinh_s82"),
    ("p", "**Xử lý tranh chấp.** Kết quả của cơ chế chống trùng MongoDB thấy được trực tiếp trên GUI tool: Q-06 cho thấy "
          "unique index receipt_field_uq chặn bản trùng với mã lỗi 11000, và Q-09 cho thấy upsert hai bước giữ đúng một "
          "document cho cặp (hóa đơn 530, seller_name) qua ba lần sửa, mở lại phản hồi khi giá trị đổi. Các cơ chế ở "
          "PostgreSQL (khóa ví, khóa lạc quan, clientId) được chứng minh bằng kiểm thử trên PostgreSQL 15 thật "
          "và trên lớp service (TC-52..TC-54)."),
    ("p", "**Tối ưu.** Q-16 cho thấy ba truy vấn chính của MongoDB đều đi IXSCAN, và với Q-03 số khóa, số document đã đọc "
          "và số document trả về bằng nhau (24 trên dữ liệu demo). Trên dữ liệu tổng hợp 100k, index rút Q-03 từ COLLSCAN "
          "21,8 ms xuống 0,33 ms; cache Redis rút dashboard quản trị từ 27,2 ms (5 câu SQL) xuống 0,051 ms; Sorted Set rút top "
          "10 từ 23,6 ms xuống 0,36 ms kể cả tra tên; Elasticsearch tìm \"pho\" cho người dùng có 19.788 giao dịch trong "
          "3,70 ms so với 78,2 ms của PostgreSQL LIKE, và không bỏ sót dòng nào trong khi LIKE bỏ sót 1.376 dòng. Kết quả "
          "ngược chiều cũng được giữ: với người dùng điển hình (khoảng 80 giao dịch) PostgreSQL LIKE nhanh hơn (0,66 ms so "
          "với 3,70 ms); biểu đồ và bảng đầy đủ ở Chương 7."),
    ("p", "**Realtime.** Bài đo JUnit (lớp AdminEventLatencyBench) chạy đúng hai lớp phát và chuyển tiếp sự kiện của "
          "ứng dụng với một Redis thật: 300 sự kiện, từ lúc gọi publish tới lúc relay gửi vào SseEmitter, không mất sự kiện nào "
          "([[hinh_s88]]). Chặng từ server qua HTTP tới trình duyệt không được đo, nên con số là cận dưới của độ trễ người "
          "quản trị thấy; mục tiêu NFR-15 (dưới 1 s) đạt cho phần phía server. Toast tương ứng trên trang quản trị là "
          "[[hinh_s80]] ở mục 6.3."),
    ("sid", "S-88", "Độ trễ sự kiện realtime phía server (bài đo AdminEventLatencyBench, E6)", 6, 15, "hinh_s88"),
]

HEADING_PLACEHOLDERS = {
    "XÂY DỰNG CƠ SỞ DỮ LIỆU VÀ TRUY VẤN TRÊN GUI TOOL": C5_0,
    "MÔI TRƯỜNG CÀI ĐẶT": C5_1,
    "TẠO CƠ SỞ DỮ LIỆU": C5_2,
    "NHẬP DỮ LIỆU CHO ỨNG DỤNG": C5_3,
    "TRUY VẤN CƠ BẢN TRÊN GUI TOOL": C5_4,
    "TRUY VẤN NÂNG CAO ĐÁP ỨNG YÊU CẦU ỨNG DỤNG": C5_5,
    "IMPORT/EXPORT, SAO LƯU VÀ KHÔI PHỤC": C5_6,
    "KẾT NỐI ỨNG DỤNG VÀ DEMO": C6_0,
    "KIẾN TRÚC ỨNG DỤNG": C6_1,
    "KẾT NỐI CSDL VỚI PHẦN MỀM": C6_2,
    "DEMO CÁC CHỨC NĂNG THEO MÔ TẢ BÀI TOÁN": C6_3,
    "KẾT QUẢ ÁP DỤNG KỸ THUẬT NÂNG CAO": C6_4,
}
