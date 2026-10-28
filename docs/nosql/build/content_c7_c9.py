"""Nội dung Chương 7 (Kiểm thử và đánh giá), Chương 8 (Kết quả và tổng kết hoạt động nhóm), Chương 9 (Tài liệu tham khảo
và phụ lục) – báo cáo NoSQL nhóm 38.

Dựng v5 từ v4 (từ thư mục gốc repo):
    python3 docs/nosql/build/build_version.py v4 v5 content_c7_c9.py 7
    python3 docs/nosql/build/check_report.py /home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38/NoSQL_38_BaoCao_v5.docx --chapter 8
    python3 docs/nosql/build/check_report.py /home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38/NoSQL_38_BaoCao_v5.docx --chapter 9
    python3 docs/nosql/build/check_report.py /home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38/NoSQL_38_BaoCao_v5.docx
    python3 docs/nosql/build/barem.py

Nguồn: kết quả surefire của hai lần chạy 40 lớp kiểm thử (27/10/2026 tại 1cae4de; 28/10/2026 tại 21814f4, sau hai commit sửa
truy vấn mờ 7f07caa, b35cd6e), docs/nosql/bench_results.md (E1–E6, NFR-13, NFR-14), kết quả chạy script của Chương 5,
docs/nosql/screenshots.md (S-xx, người chụp), docs/nosql/references.md (danh sách IEEE), HUONG_DAN_TIEN.md (việc của Tiến).
Văn bản không trích facts.md.

Số hình/bảng của chương khác (ảnh S-80, S-82, S-88 ở Chương 6; bảng phân công, bảng NFR) được đọc từ chính tệp nguồn lúc dựng
(sys.argv[1] = thư mục giải nén mà builder_nosql.py nhận), nên vẫn đúng khi Chương 1–6 đổi số; khi module được import ở nơi
khác (barem.py) thì dùng số của v4. Trạng thái trong bảng barem (mục 8.6) và số ảnh còn giữ chỗ tính lúc dựng từ
docs/nosql/screenshots (khóa PNG ledgermind-placeholder).
"""
import importlib.util
import re
import sys
import textwrap
import zipfile
from pathlib import Path

SESSION_TAG = None
SECTIONS = {}
RENUMBER = True

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
NOSQL = REPO / "docs/nosql"
SHOTS = NOSQL / "screenshots"
PLACEHOLDER_KEY = b"ledgermind-placeholder"

# Đặt True khi người dùng đã chạy JMeter và chụp S-85 (mục 7.2); False thì 7.2 ghi rõ là không chạy, không chèn ảnh.
JMETER_RUN = False


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


AP_DESIGN_ROWS = _load("content_c4").AP_DESIGN_ROWS
_C56 = _load("content_c5_c6")


def legible(sid, cap, key, spec):
    """Ảnh S-xx cắt và đặt bề rộng sao cho chữ in ra khoảng spec["pt"] (dùng lại legible_png của Chương 5–6)."""
    png, width = _C56.legible_png(sid, spec)
    return ("fig", cap, 7, str(png), width, None, None, key)


def src(rel, first, last):
    lines = (REPO / rel).read_text(encoding="utf8").splitlines()[first - 1:last]
    return textwrap.dedent("\n".join(lines))


def code(rel, first, last, what):
    rng = f"{first}" if first == last else f"{first}–{last}"
    return [("lead", f"{what} ({rel}:{rng}):"), ("code", src(rel, first, last))]


# --------------------------------------------------------------------------------------------------------------------
# Số hình/bảng của các chương đã dựng: đọc từ tệp nguồn (xem docstring).
# --------------------------------------------------------------------------------------------------------------------

def _source_xml():
    if len(sys.argv) > 1:
        p = Path(sys.argv[1]) / "word/document.xml"
        if p.exists():
            return p.read_text(encoding="utf8")
    return None


_XML = _source_xml()
_P_RE = re.compile(r"<w:p[ >](?:(?!<w:p[ >]).)*?</w:p>", re.S)


def _text(p):
    return "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", p))


def fig_of(sid, default):
    """"Hình c.n" của ảnh S-xx: chú thích Caption đầu tiên sau hình vẽ dùng tệp S-xx.png."""
    if _XML is None:
        return default
    i = _XML.find(f'name="{sid}.png"')
    if i < 0:
        raise SystemExit(f"Không thấy ảnh {sid}.png trong tệp nguồn")
    for m in _P_RE.finditer(_XML, i):
        if '<w:pStyle w:val="Caption"/>' in m.group(0):
            n = re.match(r"Hình (\d+\.\d+)", _text(m.group(0)))
            if n:
                return f"Hình {n.group(1)}"
    raise SystemExit(f"Không thấy chú thích của {sid}")


def table_of(contains, default):
    """"Bảng c.n" của bảng có chú thích chứa chuỗi contains (phải khớp đúng một bảng)."""
    if _XML is None:
        return default
    hits = []
    for m in _P_RE.finditer(_XML):
        p = m.group(0)
        if '<w:pStyle w:val="ChuThichBang"/>' in p and contains in _text(p):
            hits.append(re.match(r"Bảng (\d+\.\d+)", _text(p)).group(1))
    if len(hits) != 1:
        raise SystemExit(f"Chú thích bảng chứa {contains!r} khớp {len(hits)} lần")
    return f"Bảng {hits[0]}"


FIG_S80 = fig_of("S-80", "Hình 6.14")
FIG_S82 = fig_of("S-82", "Hình 6.16")
FIG_S88 = fig_of("S-88", "Hình 6.17")
TAB_GOALS = table_of("Mục tiêu đo được của đề tài", "Bảng 1.1")
TAB_TEAM = table_of("Cơ cấu tổ chức", "Bảng 1.4")
TAB_TASKS = table_of("Bảng phân công nhiệm vụ", "Bảng 1.5")
TAB_NFR = table_of("Yêu cầu phi chức năng, cách kiểm chứng", "Bảng 3.11")
TAB_GUI = table_of("So sánh Kibana", "Bảng 2.6")


# --------------------------------------------------------------------------------------------------------------------
# Ảnh còn giữ chỗ (tính lúc dựng) và người chụp (docs/nosql/screenshots.md).
# --------------------------------------------------------------------------------------------------------------------

def placeholder_ids():
    out = set()
    for png in SHOTS.glob("S-*.png"):
        if PLACEHOLDER_KEY in png.read_bytes()[:4096]:
            out.add(png.stem)
    return out


PLACEHOLDERS = placeholder_ids()
_SHOT_ROWS = re.findall(r"^\| (S-\d+) \|.*\| (agent|Tiến|Trí) \| ([^|]+) \|$",
                        (NOSQL / "screenshots.md").read_text(encoding="utf8"), re.M)
SHOT_OWNER = {sid: who for sid, who, _ in _SHOT_ROWS}
N_SHOTS = len(SHOT_OWNER)
N_AGENT = sum(1 for w in SHOT_OWNER.values() if w == "agent")
N_DONE = N_SHOTS - len(PLACEHOLDERS & set(SHOT_OWNER))


def sids(a, b):
    return [f"S-{i:02d}" for i in range(a, b + 1)]


def missing(ids):
    return [s for s in ids if s in PLACEHOLDERS]


def shot_status(ids, done="Có minh chứng"):
    miss = missing(ids)
    if not miss:
        return done
    return "Còn ảnh giữ chỗ: " + ", ".join(miss)


def nb(rows):
    """Ô bảng hẹp: mã S-xx, Q-xx, TC-xx, FR/NFR/AP-xx dùng gạch nối không ngắt (U+2011) để Word không ngắt dòng giữa mã."""
    fix = lambda c: re.sub(r"\b(S|Q|TC|NFR|FR|AP)-(?=\d)", lambda m: m.group(1) + "\u2011", c)
    return [[fix(c) for c in r] for r in rows]


# ====================================================================================================================
# CHƯƠNG 7
# ====================================================================================================================

C7_0 = [
    ("p", "Chương này trình bày kết quả kiểm thử của phần mở rộng NoSQL: kiểm thử chức năng theo các ca TC-01..TC-55 đã chốt "
          "cùng yêu cầu (7.1), đánh giá hiệu năng tầng dữ liệu (7.2), hành vi khi một CSDL dừng (7.3) và phần thảo luận, "
          "hạn chế (7.4). Mỗi con số ghi rõ nguồn: kết quả chạy kiểm thử tự động, script trên **dữ liệu demo**, hoặc phép đo "
          "trên **dữ liệu tổng hợp 100k (sinh bằng gen_data.py)**."),
]

# --------------------------------------------------------------------------------------------------------------------
# 7.1 Kiểm thử chức năng
# --------------------------------------------------------------------------------------------------------------------

# Lần chạy 40 lớp ngày 27/10/2026 tại 1cae4de (surefire, đếm testcase trong TEST-*.xml, lớp lồng cộng vào lớp ngoài):
# 702 test, 0 lỗi. Sau đó commit 7f07caa, b35cd6e (28/10/2026) đổi truy vấn mờ và thêm 5 test vào lớp tích hợp
# Elasticsearch (9 → 14); lớp đó chạy lại xanh tại b35cd6e trong một lượt 65 test, 0 lỗi. Từ b35cd6e tới HEAD mã chính chỉ
# đổi một dòng chú thích. Số đếm từng lớp dưới đây = lần 27/10, trừ lớp tích hợp Elasticsearch = 14.
RUN1 = dict(date="27/10/2026", sha="1cae4de", tests=702, classes=40)
RUN2 = dict(date="28/10/2026", sha="b35cd6e", tests=707, classes=40)
# (lớp, số test hiện tại, CSDL thật trong test; "mock" = kho dữ liệu PostgreSQL được giả lập bằng Mockito)
CLASSES = [
    ("AdminDashboardPageTest", 3, "-"),
    ("AdminEventPublisherTest", 6, "-"),
    ("AdminEventRelayIntegrationTest", 3, "Redis"),
    ("AdminEventRelayTest", 15, "-"),
    ("AdminEventsControllerTest", 8, "-"),
    ("AdminLeaderboardControllerTest", 10, "-"),
    ("AdminMongoBackupControllerTest", 6, "-"),
    ("AdminNoSqlPageControllerTest", 29, "-"),
    ("AdminNoSqlSearchReindexTest", 8, "-"),
    ("AdminOcrFeedbackControllerTest", 9, "-"),
    ("AdminSearchControllerTest", 7, "-"),
    ("AdminStatisticsServiceTest", 6, "-"),
    ("CacheConfigTest", 32, "-"),
    ("ElasticsearchTransactionSearchEngineIntegrationTest", 14, "ES"),
    ("MongoBackupServiceIntegrationTest", 1, "MongoDB"),
    ("MongoBackupServiceTest", 22, "-"),
    ("MongoDataSeederTest", 4, "-"),
    ("OcrCorrectionDetectorTest", 7, "-"),
    ("OcrMongoServiceMongoIntegrationTest", 15, "MongoDB"),
    ("OcrMongoServiceTest", 20, "-"),
    ("ReceiptConcurrencyH2Test", 7, "H2"),
    ("ReceiptConcurrencyPostgresTest", 7, "PG 15"),
    ("ReceiptProcessingServiceTest", 125, "-"),
    ("RedisOutageTest", 3, "Redis"),
    ("RedisPasswordResetOtpStoreIntegrationTest", 9, "Redis"),
    ("RedisStatisticsCacheIntegrationTest", 15, "Redis"),
    ("SearchConfigTest", 4, "-"),
    ("SpendingLeaderboardServiceIntegrationTest", 16, "Redis, mock"),
    ("SpendingLeaderboardServiceTest", 4, "-"),
    ("StatisticsCacheEvictorTest", 8, "-"),
    ("StatisticsCacheTransactionTest", 9, "Redis, H2"),
    ("StatisticsChangeTest", 30, "-"),
    ("TransactionRepositoryTest", 19, "H2"),
    ("TransactionSearchControllerTest", 7, "-"),
    ("TransactionSearchIndexerIntegrationTest", 12, "ES, mock"),
    ("TransactionSearchIndexerReindexLockTest", 2, "-"),
    ("TransactionSearchRepositoryTest", 5, "H2"),
    ("TransactionSearchServiceTest", 6, "-"),
    ("TransactionServiceTest", 192, "-"),
    ("UserStatisticsServiceTest", 2, "-"),
]
assert len(CLASSES) == RUN2["classes"] and sum(n for _, n, _ in CLASSES) == RUN2["tests"], sum(n for _, n, _ in CLASSES)

CLASS_LISTING = "\n".join(
    [f"{'Lớp kiểm thử':<52}{'Test':>5}  CSDL thật"] +
    [f"{c:<52}{n:>5}  {db}" for c, n, db in CLASSES] +
    [f"{'Tổng (40 lớp, 0 lỗi)':<52}{RUN2['tests']:>5}"])

OK = "Như mong đợi"
TC_W = [850, 1150, 1750, 1250, 1650, 1250, 604]
TC_H = ["Mã TC", "Yêu cầu / AP", "Bước thực hiện", "Dữ liệu vào", "Kết quả mong đợi", "Kết quả thực tế", "Đạt"]


def tc(tid, req, step, data, expect, actual=OK, ok="Đạt"):
    return [tid, req, step, data, expect, actual, ok]


TC_REDIS = [
    tc("TC-01", "FR-02 / AP-06", "Lưu OTP, kiểm tra mã đúng hai lần", "Email, mã 6 số", "Lần đầu nhận, lần sau báo không có"),
    tc("TC-02", "FR-02 / AP-06", "Nhập sai ba lần rồi nhập mã đúng", "Ba mã sai, một mã đúng", "Lần sai thứ ba xóa OTP, mã đúng bị từ chối"),
    tc("TC-03", "FR-02 / AP-05", "Lưu OTP, đọc TTL của khóa", "Email, hạn 5 phút", "Khóa có TTL bằng hạn OTP"),
    tc("TC-04", "FR-02 / AP-06", "Hai instance gửi mã sai song song", "Nhiều mã sai đồng thời", "Lua nguyên tử: chỉ ba lần sai được tính"),
    tc("TC-05", "FR-07 / AP-07, AP-09", "Gọi dashboard nhiều lần qua proxy cache", "userId", "Lần trượt đọc CSDL một lần, các lần sau từ Redis"),
    tc("TC-06", "FR-07 / AP-07", "Đọc khóa và giá trị trong Redis", "userId", "Khóa ghi môi trường, phiên bản, cache, user; JSON thuần; có TTL"),
    tc("TC-07", "NFR-11 / AP-07", "Hai người dùng đọc dashboard", "Hai userId", "Không ai đọc được cache của người kia"),
    tc("TC-55", "NFR-16 / AP-07", "Instance A tính, instance B đọc", "Hai bản chạy, một Redis", "B đọc được giá trị A đã cache"),
    tc("TC-08", "FR-03 / AP-10", "Checkout rồi đọc lại dashboard", "Giao dịch mới", "Cache bị xóa sau commit, lần đọc sau thấy số mới"),
    tc("TC-09", "NFR-10 / AP-10", "Ghi rồi rollback", "Giao dịch lỗi", "Không xóa cache; giá trị vẫn khớp CSDL"),
    tc("TC-10", "NFR-07", "Ứng dụng nối tới Redis không tồn tại", "Cổng không mở", "Mọi lần đọc trả lời từ CSDL, không ném lỗi"),
    tc("TC-11", "NFR-07", "Tạm dừng (pause) container Redis giữa chừng", "Redis treo", "Vẫn trả lời từ CSDL, chậm thêm tối đa bằng timeout"),
    tc("TC-12", "FR-10 / AP-12", "Đọc top khi chưa có khóa tháng", "Tháng, limit", "Dựng từ PostgreSQL, khóa có TTL"),
    tc("TC-13", "FR-10 / AP-11", "Đọc top khi khóa đã có", "Tháng, limit", "Không truy vấn PostgreSQL"),
    tc("TC-14", "FR-03 / AP-13", "Sự kiện giao dịch đổi sau commit", "userId, tháng", "Score = tổng tuyệt đối đọc lại từ PostgreSQL"),
    tc("TC-15", "FR-03 / AP-13", "Khóa hết hạn trong lúc đọc tổng", "Khóa vừa hết hạn", "Lua không tạo lại set một phần tử"),
    tc("TC-16", "FR-15 / AP-14", "Sự kiện khôi phục CSDL", "Nhiều tháng", "SCAN xóa mọi tháng; lần đọc sau dựng lại"),
    tc("TC-17", "FR-16 / AP-15, AP-16", "Phát một sự kiện, hai instance nghe", "Một PUBLISH", "Emitter SSE của cả hai instance nhận được"),
    tc("TC-18", "NFR-15", "Khởi động instance khi Redis chưa chạy", "Redis bật sau", "Ứng dụng vẫn lên, sau đó tự đăng ký kênh"),
    tc("TC-19", "NFR-12 / FR-16", "Người dùng thường mở luồng SSE", "Tài khoản USER", "Bị từ chối"),
    tc("TC-51", "FR-02 / AP-06", "Script Q-27: EVAL Lua lưu, sai hai lần, đúng, dùng lại", "Mã 111111, 123456",
       "Trả lần lượt 1, 2, 0, -1", "Lưu trả 1; sai trả 1, 2; đúng trả 0; dùng lại trả -1"),
]

TC_MONGO = [
    tc("TC-20", "FR-06 / AP-18", "Ghi chỗ sửa hai lần cho cùng hóa đơn, trường", "Hóa đơn, trường", "Đúng một document mỗi cặp"),
    tc("TC-21", "FR-06 / AP-18", "Gửi lại cùng giá trị, rồi giá trị khác", "Phản hồi đã xử lý", "Cùng giá trị: giữ đã xử lý; khác: mở lại"),
    tc("TC-22", "FR-06 / AP-18", "Sửa trường về đúng giá trị AI", "Giá trị AI", "Xóa chỗ sửa lỗi thời"),
    tc("TC-23", "FR-05 / AP-17", "Ghi log OCR thô sau commit", "JSON của AI", "Log có modelVersion và aiReading"),
    tc("TC-24", "FR-11 / AP-19", "Lọc phản hồi theo trường, trạng thái", "field, resolved", "Đúng tập lọc, mới nhất trước"),
    tc("TC-25", "FR-12 / AP-22, AP-23, AP-24", "Gọi thống kê theo khoảng ngày", "from, to", "Số lỗi theo trường, theo mô hình, độ tin cậy theo tháng đúng"),
    tc("TC-26", "FR-12 / AP-25", "Phản hồi báo sau khoảng thống kê", "from, to", "Tỉ lệ lần đọc bị sửa không vượt 1"),
    tc("TC-27", "FR-11 / AP-20", "Đánh dấu đã xử lý", "id", "isResolved = true"),
    tc("TC-28", "FR-11 / AP-21", "Xóa phản hồi", "id", "Document bị xóa"),
    tc("TC-29", "FR-15 / AP-27, AP-28", "Dump, xóa, khôi phục trên MongoDB thật", "Ba collection",
       "Hai collection trở lại, collection khác không bị đụng"),
    tc("TC-30", "NFR-09 / AP-17", "Lệnh ghi MongoDB ném lỗi", "Lỗi khi ghi", "Không ném lỗi về luồng gọi, chỉ log"),
    tc("TC-31", "NFR-12 / FR-15", "Người dùng thường gọi sao lưu MongoDB", "Tài khoản USER", "Bị từ chối, không chạy gì"),
    tc("TC-46", "NFR-05 / AP-19", "Script Q-16: explain với executionStats cho Q-03", "Dữ liệu demo", "Kế hoạch thắng có IXSCAN",
       "IXSCAN; số khóa, document đọc, trả về đều là 24"),
    tc("TC-47", "AP-18", "Script Q-05: thêm document sai kiểu", "Mã hóa đơn kiểu chuỗi", "Bị validator từ chối", "Lỗi 121"),
    tc("TC-48", "AP-18", "Script Q-06: thêm bản trùng", "Cặp đã có", "Bị unique index từ chối", "Lỗi 11000"),
    tc("TC-49", "NFR-13 / AP-27, AP-28", "Đếm, mongodump, xóa database, mongorestore, đếm lại", "Dữ liệu demo",
       "Số document trước bằng sau", "Trước = sau: 36, 36, 13 index, 2 validator"),
]

TC_SEARCH = [
    tc("TC-32", "FR-08 / AP-29", "Tìm \"pho\"", "Giao dịch \"Phở Hùng\"", "Ra \"Phở Hùng\""),
    tc("TC-33", "NFR-04 / AP-29", "Tìm chuỗi gõ sai một ký tự", "\"Phở Hùng\"", "Vẫn ra \"Phở Hùng\""),
    tc("TC-34", "NFR-04 / AP-29", "Tìm tiền tố \"phu\"", "\"Phúc Long\"", "Ra \"Phúc Long\""),
    tc("TC-35", "NFR-11 / AP-29", "Tìm khi index có document người khác", "Hai userId", "Không trả document người khác"),
    tc("TC-36", "NFR-08 / AP-31", "Engine Elasticsearch ném lỗi", "Truy vấn hợp lệ", "PostgreSQL trả lời, engine = postgres"),
    tc("TC-37", "NFR-11 / AP-30", "Id trả từ index không còn ở PostgreSQL", "Id đã xóa", "Id đó bị bỏ khỏi kết quả"),
    tc("TC-38", "FR-03 / AP-32", "Sự kiện giao dịch được tạo", "Giao dịch có hóa đơn", "Document có vendorName của hóa đơn"),
    tc("TC-39", "FR-04 / AP-32", "Sự kiện giao dịch bị xóa", "Mã giao dịch", "Document bị xóa"),
    tc("TC-40", "NFR-08 / AP-32", "Elasticsearch dừng khi có sự kiện", "ES dừng", "Bộ nghe chỉ log, không ném lỗi"),
    tc("TC-41", "FR-14 / AP-34", "Ghi khi index chưa có", "Index trống", "Index tạo từ mapping của ứng dụng, không dynamic"),
    tc("TC-42", "FR-14 / AP-33", "Sự kiện khôi phục CSDL và các sự kiện khác", "Sự kiện khôi phục", "Chỉ khôi phục mới dựng lại index"),
    tc("TC-43", "FR-08 / AP-31", "Tìm chuỗi chứa ký tự %", "\"50%\"", "% là ký tự thường; mới nhất trước"),
    tc("TC-44", "NFR-11 / AP-31", "Tìm khi bảng có dòng người khác", "Hai userId", "Chỉ trả dòng của người gọi"),
    tc("TC-45", "NFR-12 / FR-08", "Gọi API tìm kiếm không kèm token", "Không token", "Bị từ chối"),
    tc("TC-50", "NFR-13", "Snapshot, xóa index, restore, đếm", "47 giao dịch demo", "Số document trước bằng sau",
       "47; sau khi xóa: không còn index; restore: 47"),
]

TC_PG = [
    tc("TC-52", "NFR-10 / AP-02", "Gửi lại checkout cùng clientId", "clientId đã dùng", "Trả giao dịch gốc, không tạo bản trùng"),
    tc("TC-53", "NFR-10 / AP-02", "Số dư đổi giữa lần đọc trước và lúc khóa ví", "Hai lần đọc số dư", "Dùng số dư đọc dưới khóa ví"),
    tc("TC-54", "NFR-10 / AP-04", "Hai lần sửa hóa đơn từ cùng phiên bản, cùng lúc", "Cùng version", "Một lần ghi, lần kia không đổi gì (409)"),
]
assert len(TC_REDIS) + len(TC_MONGO) + len(TC_SEARCH) + len(TC_PG) == 55


def tc_table(caption, rows, key):
    return ("table", caption, 7, TC_W, TC_H, rows, "", key)


C7_1 = [
    ("p", "**Cách kiểm thử.** Có hai loại ca. Ca *tự động* là phương thức JUnit 5 trong core-backend/src/test: kiểm thử đơn vị "
          "tầng service bằng Mockito, kiểm thử tầng web bằng MockMvc với chuỗi bảo mật thật, và kiểm thử tích hợp với "
          "Redis, MongoDB, Elasticsearch, PostgreSQL 15 thật chạy trong container Testcontainers (mỗi lần chạy dựng container "
          "mới rồi xóa). Ca *script* (TC-46..TC-51) là các truy vấn và kịch bản sao lưu của Chương 5, chạy trên dữ liệu demo "
          "trong container dùng một lần hoặc stack demo."),
    ("p", f"**Lần chạy.** Bốn mươi lớp kiểm thử liên quan đến phần NoSQL chạy ngày {RUN1['date']} tại commit {RUN1['sha']} "
          f"bằng Maven 3.9.12, Java 21, ngoại tuyến, cây mã sạch: **{RUN1['tests']} test, 0 lỗi**, mọi test dùng Docker "
          f"đều chạy thật. Sau đó truy vấn mờ của Elasticsearch được sửa (commit 7f07caa và {RUN2['sha']} ngày "
          f"{RUN2['date']}, xem mục 7.4); lớp kiểm thử tích hợp Elasticsearch có thêm 5 test và chạy lại xanh tại "
          f"{RUN2['sha']} (03:34 ngày {RUN2['date']}, lượt 65 test, 0 lỗi). Số đếm đọc từ báo cáo surefire (TEST-∗.xml), không đếm chú thích @Test. "
          f"Danh sách lớp, số test hiện tại ({RUN2['tests']}) và CSDL thật mà lớp dùng:"),
    ("code", CLASS_LISTING),
    ("p", "Cột CSDL thật: \"-\" là test không cần CSDL (Mockito, MockMvc); \"mock\" là kho dữ liệu PostgreSQL được giả lập "
          "bằng Mockito bên cạnh CSDL NoSQL thật; H2 là CSDL nhúng dùng cho kiểm thử JPA. Bốn bảng dưới đây ghi từng ca theo "
          "CSDL. Ca tự động được tính là đạt khi phương thức của nó chạy xanh ở lần chạy gần nhất của lớp đó; ca script "
          "(chạy ngày 28/10/2026) ghi kết quả đọc được."),
    ("lead", "Ca Redis: RedisPasswordResetOtpStoreIntegrationTest (TC-01..TC-04), RedisStatisticsCacheIntegrationTest (TC-05..TC-07, "
             "TC-55), StatisticsCacheTransactionTest (TC-08, TC-09), RedisOutageTest (TC-10, TC-11), "
             "SpendingLeaderboardServiceIntegrationTest (TC-12..TC-16), AdminEventRelayIntegrationTest (TC-17, TC-18), "
             "AdminEventsControllerTest (TC-19); TC-51 là script."),
    tc_table("Ca kiểm thử Redis (OTP, cache, bảng xếp hạng, realtime)", TC_REDIS, "bang_tc_redis"),
    ("lead", "Ca MongoDB: OcrMongoServiceMongoIntegrationTest (TC-20..TC-28), MongoBackupServiceIntegrationTest (TC-29), "
             "OcrMongoServiceTest (TC-30), AdminMongoBackupControllerTest (TC-31); TC-46..TC-49 là script."),
    tc_table("Ca kiểm thử MongoDB (phản hồi OCR, log thô, sao lưu)", TC_MONGO, "bang_tc_mongo"),
    ("lead", "Ca tìm kiếm: ElasticsearchTransactionSearchEngineIntegrationTest (TC-32..TC-35), TransactionSearchServiceTest "
             "(TC-36, TC-37), TransactionSearchIndexerIntegrationTest (TC-38..TC-42), TransactionSearchRepositoryTest (TC-43, "
             "TC-44), TransactionSearchControllerTest (TC-45); TC-50 là script."),
    tc_table("Ca kiểm thử tìm kiếm (Elasticsearch và dự phòng PostgreSQL)", TC_SEARCH, "bang_tc_search"),
    ("lead", "Ca nhất quán PostgreSQL: TransactionServiceTest (TC-52, TC-53), ReceiptConcurrencyPostgresTest (TC-54, hợp đồng "
             "ReceiptConcurrencyContract chạy trên PostgreSQL 15 thật; cùng hợp đồng chạy trên H2 ở ReceiptConcurrencyH2Test)."),
    tc_table("Ca kiểm thử nhất quán PostgreSQL", TC_PG, "bang_tc_pg"),
    ("p", "Kết quả: **55/55 ca đạt**. Không chạy trong các lần trên: widget test Flutter của ô tìm kiếm Sổ cái "
          "(mobile-app/test/screens/ledger/ledger_search_test.dart) và kiểm thử tải JMeter ở mức ứng dụng (mục 7.2). Độ trễ "
          "người dùng thấy khi một CSDL dừng chưa đo trên ứng dụng thật; mục 7.3 ghi giới hạn mà kiểm thử khẳng định."),
]

# --------------------------------------------------------------------------------------------------------------------
# 7.2 Đánh giá hiệu năng
# --------------------------------------------------------------------------------------------------------------------

PERF_W = [2150, 1100, 900, 900, 900, 1000, 1554]
PERF_H = ["Kịch bản", "NFR", "p50 (ms)", "p95 (ms)", "p99 (ms)", "Thông lượng (ops/s)", "Đạt NFR"]
SYN = "dữ liệu tổng hợp 100k (sinh bằng gen_data.py)"


def perf(caption, rows, key):
    return ("table", caption, 7, PERF_W, PERF_H, rows, "", key)


def chart(n, caption, key, width=15.0):
    return ("fig", caption, 7, str(NOSQL / f"diagrams/bench_E{n}.png"), width, SYN, None, key)


E1 = [
    ["Q-01 có index (transactionId)", "NFR-05", "0,34", "0,40", "0,45", "2.927", "Đạt"],
    ["Q-01 không index (COLLSCAN)", "–", "20,7", "39,0", "42,5", "48", "– (chậm hơn 60× ở p50)"],
    ["Q-02 có index (createdAt)", "NFR-05", "0,43", "0,51", "0,56", "2.317", "Không đạt: đọc 61 để trả 5"],
    ["Q-02 không index (COLLSCAN)", "–", "45,8", "50,3", "65,6", "21", "– (106×)"],
    ["Q-03 có index (status_date_idx)", "NFR-05", "0,33", "0,40", "0,46", "3.007", "Đạt"],
    ["Q-03 không index (COLLSCAN)", "–", "21,8", "24,1", "28,3", "45", "– (65×)"],
]
E2 = [
    ["Elasticsearch, người dùng điển hình (khoảng 80 giao dịch)", "NFR-03", "3,70", "5,65", "12,6", "202", "Đạt"],
    ["PostgreSQL LIKE, người dùng điển hình", "–", "0,66", "0,98", "1,15", "1.432", "– (PostgreSQL nhanh hơn)"],
    ["Elasticsearch, người dùng nặng (19.788 giao dịch)", "NFR-03", "3,70", "4,95", "6,20", "257", "Đạt"],
    ["PostgreSQL LIKE, người dùng nặng", "–", "78,2", "85,1", "96,8", "13", "– (chậm hơn 21× ở p50)"],
]
E2Q = [
    ["\"phở\"", "1.517", "1.233 / 284", "1.852 / 0"],
    ["\"pho\"", "1.517", "176 / 1.376", "1.852 / 0"],
    ["\"cà phê\"", "2.665", "2.561 / 104", "2.665 / 0"],
    ["\"ca phe\"", "2.665", "112 / 2.553", "2.665 / 0"],
    ["\"tiền điện\"", "391", "352 / 39", "391 / 0"],
    ["\"tien dien\"", "391", "39 / 352", "391 / 0"],
]
E3 = [
    ["Redis ZREVRANGE 0 9 WITHSCORES (chỉ đọc Sorted Set)", "NFR-06", "0,080", "0,15", "0,19", "10.330", "Đạt"],
    ["Redis ZREVRANGE kèm tra tên 10 người dùng (đường đầy đủ của ứng dụng)", "NFR-06", "0,36", "0,39", "0,42", "2.902",
     "Đạt; nhanh hơn SQL 66× ở p50"],
    ["PostgreSQL: câu JPQL tổng chi theo người dùng của tháng", "–", "23,6", "27,1", "40,2", "41", "–"],
    ["Redis: Lua cập nhật một người (EVALSHA)", "–", "0,067", "0,11", "0,14", "12.150", "– (đường ghi)"],
    ["Redis: dựng lại cả tháng (DEL + ZADD)", "–", "2,67", "2,89", "3,37", "368", "– (phần Redis của một lần thiếu khóa)"],
]
E4 = [
    ["Dashboard người dùng: Redis GET", "NFR-01", "0,054", "0,063", "0,11", "17.887", "Đạt"],
    ["Dashboard người dùng: 3 câu SQL", "NFR-02", "2,13", "2,49", "3,76", "455", "Đạt: GET nhanh hơn 39×"],
    ["Dashboard người dùng: trượt đầy đủ (SQL, JSON, SET)", "–", "2,39", "2,68", "3,49", "412", "–"],
    ["Cửa hàng hay mua: Redis GET", "NFR-01", "0,053", "0,065", "0,100", "18.083", "Đạt"],
    ["Cửa hàng hay mua: 1 câu SQL", "NFR-02", "0,57", "0,61", "0,65", "1.750", "Đạt: GET nhanh hơn 11×"],
    ["Cửa hàng hay mua: trượt đầy đủ", "–", "0,81", "0,97", "1,12", "1.215", "–"],
    ["Tổng quan quản trị: Redis GET", "NFR-01", "0,051", "0,060", "0,099", "18.866", "Đạt"],
    ["Tổng quan quản trị: 5 câu SQL", "NFR-02", "27,2", "30,3", "32,9", "36", "Đạt: GET nhanh hơn 529×"],
    ["Tổng quan quản trị: trượt đầy đủ", "–", "27,7", "30,6", "32,2", "36", "–"],
]
E5 = [
    ["A, toàn bộ seller_name: $lookup (Q-13 nguyên bản)", "–", "871,6", "988,2", "1069,9", "1", "–"],
    ["A: Q-13 sắp lại ($sort, $limit trước $lookup)", "–", "0,75", "0,80", "0,83", "1.330", "– (nhanh hơn 1155×)"],
    ["A: bản sao nhúng, cùng thứ tự Q-13", "–", "49,5", "55,1", "63,0", "20", "– (nhanh hơn 17,6×)"],
    ["A: bản sao nhúng, sắp lại", "–", "0,48", "0,57", "0,62", "2.046", "– (1,57× so với Q-13 sắp lại)"],
    ["B, theo một người dùng: $lookup (Q-13 nguyên bản)", "–", "1,63", "2,15", "2,40", "604", "–"],
    ["B: Q-13 sắp lại", "–", "0,91", "1,17", "1,28", "1.056", "– (1,8×)"],
    ["B: bản sao nhúng, cùng thứ tự Q-13", "–", "0,64", "0,73", "0,81", "1.542", "– (2,5×)"],
    ["B: bản sao nhúng, sắp lại", "–", "0,63", "0,73", "0,83", "1.574", "– (1,46× so với Q-13 sắp lại)"],
]

C7_2 = [
    ("p", "Đánh giá hiệu năng được khuyến khích nhưng không nằm trong thang điểm; nhóm vẫn đo để kiểm chứng các NFR hiệu "
          "năng đã chốt trước khi đo (mục 3.4). **Phương pháp.** Đo độ trễ tầng dữ liệu: một client Python 3.12 trong cùng "
          f"mạng Docker với CSDL gửi đúng câu lệnh mà ứng dụng gửi (câu SQL lấy từ log show-sql của Hibernate, thân yêu cầu "
          f"Elasticsearch dựng lại từ mã truy vấn), không qua Spring, JWT hay mạng ngoài; một luồng, 200 lần khởi động không "
          f"tính rồi 1.200 lần đo, phân vị nearest-rank. Dữ liệu là {SYN}, seed 42: 100.000 giao dịch của 1.000 người dùng "
          "(người dùng 1 \"nặng\" giữ 19.788 giao dịch), 100.000 ocr_logs, 45.471 ocr_feedbacks, 10 % văn bản viết không "
          "dấu. Máy đo: Intel Core i7-8750H (12 luồng), 15 GiB RAM, Docker Engine 29.1.3; mỗi CSDL chạy với giới hạn bộ nhớ "
          "như docker-compose.yml. Ba lượt đo ngày 28/10/2026 (02:12, 03:04 và 03:35 giờ Việt Nam): E1, E4 lấy từ lượt đầu, "
          "E3, E5 từ lượt hai, E2 từ lượt ba sau khi sửa truy vấn mờ. Mọi kịch bản có cùng tải (1 luồng) và mỗi thí nghiệm "
          "có một cỡ dữ liệu, nên hai cột này ghi ở tên bảng; các cột còn lại như bảng dưới."),
    ("p", "**E1 – index MongoDB** (AP-19, AP-38; NFR-05). [[bang_e1]] so ba truy vấn có index và không index; với lệnh có "
          "index, explain(\"executionStats\") cho kế hoạch FETCH → IXSCAN. Q-01 và Q-03 đọc đúng số document trả về (1/1 và "
          "5/5). Q-02 dùng index createdAt nhưng phải đọc 61 document để trả 5, nên không đạt vế \"số document đọc bằng số "
          "trả về\" của NFR-05 (giải thích ở mục 7.4)."),
    perf("E1 – MongoDB có và không có index (100.000 ocr_logs, 45.471 ocr_feedbacks; 1 luồng)", E1, "bang_e1"),
    chart(1, "E1 – độ trễ truy vấn MongoDB có và không có index", "hinh_e1"),
    ("p", "**E2 – Elasticsearch và PostgreSQL LIKE** (AP-29, AP-31; NFR-03, NFR-04). Hai engine chạy đúng truy vấn của ứng "
          "dụng trên cùng 100.000 giao dịch ([[bang_e2]]); Elasticsearch phản hồi trong 3,70 ms ở p50 bất kể người dùng có "
          "bao nhiêu giao dịch, PostgreSQL nhanh hơn với người dùng điển hình nhưng tăng theo số giao dịch của người đó vì "
          "không index nào giúp được LIKE '%…%'. [[bang_e2q]] so số kết quả với sự thật nền (các giao dịch có từ khóa như "
          "một từ trọn vẹn sau khi hạ chữ thường và bỏ dấu): Elasticsearch không bỏ sót dòng nào ở cả 20 chuỗi thử, còn "
          "PostgreSQL bỏ sót phần lớn khi cách gõ khác cách ghi trong dữ liệu."),
    perf("E2 – Tìm kiếm Elasticsearch và PostgreSQL LIKE (100.000 giao dịch; 1 luồng)", E2, "bang_e2"),
    ("table", "E2 – Số kết quả và số dòng bỏ sót của người dùng nặng", 7, [1900, 1700, 2452, 2452],
     ["Chuỗi tìm", "Sự thật nền", "PostgreSQL: số kết quả / bỏ sót", "Elasticsearch: số kết quả / bỏ sót"], E2Q,
     "Elasticsearch trả thêm 335 dòng cho \"phở\" và \"pho\" do khớp tiền tố (ví dụ \"phòng\"); các chuỗi khác không có "
     "dương tính giả", "bang_e2q"),
    chart(2, "E2 – độ trễ tìm kiếm và số kết quả của \"phở\", \"pho\"", "hinh_e2"),
    ("p", "**E3 – bảng xếp hạng** (AP-11, AP-12; NFR-06). Tháng 2026-10 có 27.067 dòng chi tiêu của 1.000 người dùng. "
          "Hàng so sánh công bằng với SQL là đường Redis đầy đủ của ứng dụng: ZREVRANGE rồi tra tên 10 người dùng bằng một "
          "câu SELECT theo khóa chính ([[bang_e3]]). Top 10 của hai đường khớp nhau (cùng id, cùng điểm)."),
    perf("E3 – Top 10 chi tiêu tháng: Redis Sorted Set và SQL (27.067 dòng, 1.000 người dùng; 1 luồng)", E3, "bang_e3"),
    chart(3, "E3 – độ trễ top 10 trên Redis và PostgreSQL", "hinh_e3", 13),
    ("p", "**E4 – cache Redis** (AP-07, AP-08; NFR-01, NFR-02). \"Trượt cache\" là đúng các câu SQL mà dịch vụ thống kê "
          "phát ra; \"trượt đầy đủ\" cộng thêm việc tạo JSON và lệnh SET ([[bang_e4]]). Lợi ích lớn nhất ở tổng quan quản "
          "trị (5 câu SQL quét toàn bảng). Thời gian trượt là cận dưới: ứng dụng thật có thể phát thêm một câu đọc hóa đơn."),
    perf("E4 – Có cache và không cache (JSON 0,8–1,9 KB; 100.000 giao dịch; 1 luồng)", E4, "bang_e4"),
    chart(4, "E4 – đọc cache Redis và chạy SQL của ba loại thống kê", "hinh_e4"),
    ("p", "**E5 – tham chiếu và nhúng** (AP-37; Q-13). Biến thể A lấy mọi phản hồi seller_name (15.211 document), biến thể B "
          "lấy phản hồi của một người dùng (khoảng 15 document) ([[bang_e5]]). Số 871,6 ms của A đo cái giá của một $lookup "
          "đặt muộn (tra 15.211 lần rồi mới cắt 4 dòng), không phải của tham chiếu: đặt $sort, $limit trước thì chỉ còn 4 "
          "lần tra và xuống 0,75 ms. B là phép so công bằng: nhúng nhanh hơn 2,5× ở p50 nhưng tốn thêm 12,2 MB dữ liệu "
          "chép lặp (ocr_feedbacks từ 11,0 MB lên 23,1 MB)."),
    perf("E5 – $lookup và bản sao nhúng (45.471 phản hồi, 100.000 log; 1 luồng)", E5, "bang_e5"),
    chart(5, "E5 – $lookup và bản sao nhúng, hai biến thể", "hinh_e5"),
    ("p", f"**E6 – độ trễ sự kiện realtime** (AP-15, AP-16; NFR-15). Bài đo JUnit chạy đúng lớp phát và lớp chuyển tiếp "
          f"của ứng dụng với một Redis thật, 300 sự kiện cách nhau 10 ms, ngày 28/10/2026 (03:44 giờ Việt Nam) "
          f"([[bang_e6]], ảnh kết quả là {FIG_S88} ở mục 6.4). Chặng từ server qua HTTP tới trình duyệt không được đo, nên "
          f"đây là cận dưới của độ trễ quản trị viên thấy."),
    ("table", "E6 – Độ trễ sự kiện realtime phía server (300 sự kiện, 1 luồng phát)", 7, [2504, 1000, 1000, 1000, 1000, 1000, 1000],
     ["Đường đi", "p50 (ms)", "p95 (ms)", "p99 (ms)", "max (ms)", "Trung bình (ms)", "Mất"],
     [["publish() → SseEmitter.send (phía server)", "1,177", "1,573", "1,920", "3,131", "1,202", "0/300"],
      ["Riêng lời gọi publish()", "0,701", "0,978", "1,104", "3,027", "0,716", "–"]],
     "Đạt NFR-15 cho phần phía server (mục tiêu dưới 1 s)", "bang_e6"),
    ("p", "**Sao lưu MongoDB** (NFR-13). Trên stack demo (MongoDB 6.0.28, giới hạn 512 MB), sáu lần khôi phục 36 ocr_logs, "
          "36 ocr_feedbacks, 13 index và 2 validator bằng mongorestore mất 0,500–0,897 s, trung vị của năm lần sau 0,543 s; "
          "số đếm trước và sau khớp hoàn toàn. Mục tiêu dưới 5 phút đạt với mongorestore; thời gian của thao tác khôi phục "
          "trên trang /admin/backup chưa đo (cần ứng dụng chạy)."),
    ("p", "**Tài nguyên** (NFR-14). [[bang_tai_nguyen]] là kết quả docker stats --no-stream của stack demo với giới hạn bộ "
          "nhớ bằng docker-compose.yml, sau khi nạp dữ liệu demo và chạy Q-01..Q-41, ngày 28/10/2026 ([[hinh_s89]]). Redis "
          "và MongoDB dùng dưới 20 % giới hạn. Elasticsearch 1 GB chỉ còn khoảng 3 % dư khi Kibana tắt; 22 giây sau khi bật "
          "Kibana, kernel giết tiến trình Java của Elasticsearch vì vượt giới hạn và container khởi động lại, nên NFR-14 "
          "**không đạt** với Elasticsearch khi Kibana cùng chạy. Với giới hạn 1,5 GB, Elasticsearch dùng 1,15 GiB và không "
          "khởi động lại lần nào."),
    ("table", "Bộ nhớ container của stack demo (docker stats, giới hạn như docker-compose.yml)", 7, [1800, 1300, 2700, 2704],
     ["Container", "Giới hạn", "Kibana tắt", "Kibana bật, 60 s sau đăng nhập"],
     [["Redis", "192 MiB", "6,1 MiB (3,2 %)", "5,4 MiB (2,8 %)"],
      ["MongoDB", "512 MiB", "84,2 MiB (16,5 %)", "83,8 MiB (16,4 %)"],
      ["Elasticsearch", "1 GiB", "997,2 MiB (97,4 %), không khởi động lại", "1022 MiB (99,8 %), khởi động lại 1 lần"],
      ["Kibana", "1 GiB", "Tắt", "561,9 MiB (54,9 %)"]],
     "Elasticvue và RedisInsight chỉ có ở stack demo, không tính", "bang_tai_nguyen"),
    # Ảnh terminal 1600 px, chữ 16 px: giữ 800 px bên trái (bảng docker stats, restarts, dòng OOM) để chữ in ra 7,5 pt.
    legible("S-89", "docker stats --no-stream của stack demo, giới hạn như docker-compose.yml (cắt phần bên phải các "
                    "dòng lệnh dài)", "hinh_s89", dict(kind="boxes", em=16.0, pt=7.5, boxes=[(0, 45, 800, 924)])),
]
if JMETER_RUN:
    C7_2 += [
        ("p", "**Mức ứng dụng (JMeter).** Kịch bản docs/testing/jmeter/ledgermind-load.jmx chạy trên ứng dụng thật; "
              "[[hinh_s85]] là Summary Report."),
        ("sid", "S-85", "JMeter Summary Report", 7, 15, "hinh_s85"),
        ("y", "Ghi chú cho nhóm: ghi số mẫu, p95, thông lượng, tỉ lệ lỗi và ngày chạy JMeter vào đây."),
    ]
else:
    C7_2 += [
        ("p", "**Mức ứng dụng.** Kịch bản JMeter có sẵn trong kho (docs/testing/jmeter/ledgermind-load.jmx) nhưng không được "
              "chạy cho báo cáo này, nên mọi số đo ở trên là tầng dữ liệu; độ trễ API đầu-cuối (Spring, JWT, mạng) chưa có "
              "số."),
    ]

# --------------------------------------------------------------------------------------------------------------------
# 7.3 Kiểm thử chịu lỗi
# --------------------------------------------------------------------------------------------------------------------

LAT = "⟦… ms, ghi khi chạy demo⟧"

C7_3 = [
    ("p", "Mỗi CSDL NoSQL của hệ thống chạy **một node**, không có bản sao, nên không có failover hay bầu primary mới để đo: "
          "tắt một node nghĩa là tắt hẳn CSDL đó. Điều kiểm thử được là hệ thống **vẫn trả lời** khi một CSDL NoSQL dừng, "
          "nhờ PostgreSQL là nguồn sự thật và mọi lần ghi NoSQL chạy sau commit trên luồng nền. [[bang_chiu_loi]] tóm tắt "
          "hành vi, kiểm thử chứng minh và thời gian: giới hạn mà kiểm thử khẳng định, và ô độ trễ quan sát trên ứng dụng "
          "thật để trống tới khi nhóm chạy demo dừng dịch vụ (kịch bản ở Phụ lục D)."),
    ("table", "Hành vi khi một CSDL NoSQL dừng", 7, [1500, 3300, 1800, 1904],
     ["CSDL dừng", "Hệ thống làm gì", "Kiểm thử", "Thời gian"],
     [["Redis (cache thống kê)", "Đọc lỗi coi như trượt cache, trả lời từ PostgreSQL; ghi, xóa cache lỗi chỉ bị bỏ qua",
       "TC-10, TC-11", "Test: không với tới < 5 s; Redis treo < 3 s; Redis đã dừng < 450 ms. Quan sát: " + LAT],
      ["Redis (bảng xếp hạng)", "Lỗi Redis khi đọc → trả lời từ PostgreSQL; cập nhật sau commit lỗi chỉ log",
       "Kiểm thử đơn vị lớp xếp hạng", "Không đo"],
      ["Redis (OTP)", "Cố ý báo lỗi với câu cố định \"Dịch vụ mã OTP tạm thời gián đoạn…\", không dự phòng", "Kiểm thử tích hợp OTP",
       "Không đo"],
      ["Redis (realtime)", "Sự kiện mất (Pub/Sub không lưu tin); ứng dụng vẫn chạy, thử đăng ký lại kênh mỗi 10 s", "TC-18",
       "Không đo"],
      ["Elasticsearch", "Tìm kiếm trả lời bằng PostgreSQL, phản hồi ghi engine = postgres; cập nhật index chỉ log, ghi giao "
       "dịch vẫn thành công", "TC-36, TC-40", "Chờ thêm tối đa 1 s kết nối hoặc 2 s socket. Quan sát: " + LAT],
      ["MongoDB", "Ghi giao dịch, hóa đơn vẫn thành công; ghi log OCR, phản hồi OCR lỗi chỉ log trên luồng nền", "TC-30",
       "Luồng nền chờ tối đa 5 s chọn server. Quan sát: " + LAT]],
     "Giới hạn trong cột Thời gian là điều kiện mà kiểm thử khẳng định, không phải số đo trung bình", "bang_chiu_loi"),
    ("p", "**Redis.** RedisOutageTest chạy ba tình huống trên Redis thật: chưa từng với tới được, bị tạm dừng giữa chừng (kết "
          "nối còn mở nên mỗi lệnh chờ tới timeout 500 ms) và đã dừng hẳn (Lettuce từ chối lệnh ngay trong lúc kết nối lại). "
          "Cả ba đều trả lời bằng dữ liệu đọc từ CSDL, không trả cache cũ, và nằm trong giới hạn thời gian ở bảng. Đây là cơ "
          "chế dự phòng (fallback), không ngắt mạch: trong lúc Redis treo, mỗi request vẫn trả tối đa bằng timeout lệnh. Bảng "
          "xếp hạng có kiểm thử đơn vị riêng (SpendingLeaderboardServiceTest) cho trường hợp Redis lỗi khi đọc. Riêng OTP cố "
          "ý không dự phòng, vì một mã OTP không thể dựng lại từ PostgreSQL; RedisPasswordResetOtpStoreIntegrationTest kiểm "
          "rằng thông báo lỗi cố định và không chứa mã hay email."),
    ("p", f"**Elasticsearch.** Khi engine Elasticsearch ném bất kỳ lỗi nào, dịch vụ tìm kiếm ghi một dòng log và trả lời bằng "
          f"PostgreSQL (TC-36); việc cập nhật chỉ mục sau commit gặp Elasticsearch dừng chỉ log (TC-40). {FIG_S82} ở mục 6.4 "
          f"cho thấy cùng một yêu cầu trả engine=elasticsearch rồi engine=postgres sau khi dừng container. Kết quả lúc "
          f"Elasticsearch dừng là của chế độ PostgreSQL, nên gõ không dấu sẽ ra ít kết quả hơn (mục 7.4)."),
    ("p", "**MongoDB.** Lần ghi log OCR và phản hồi OCR chạy sau commit trên luồng nền; lỗi chỉ được log và không về tới "
          "luồng xử lý request (TC-30), nên quét và sửa hóa đơn vẫn lưu được. Phần mất là bản sao phân tích của những lần "
          "đọc trong lúc MongoDB dừng: không có cơ chế tự chép lại. Hành vi của trang /admin/ocr-feedbacks khi MongoDB dừng "
          "không có ca kiểm thử."),
    ("y", "Ghi chú cho nhóm (xóa trước khi nộp): khi chạy demo dừng dịch vụ (Phụ lục D, phần 3), ghi độ trễ Postman quan sát "
          "được vào ba ô \"Quan sát\" của bảng trên, rồi chụp S-83 (Redis) và S-84 (MongoDB) trên stack đầy đủ."),
    ("sid", "S-83", "Dừng Redis: dashboard vẫn trả lời (Postman, độ trễ quan sát)", 7, 14, "hinh_s83"),
    ("sid", "S-84", "Dừng MongoDB: quét hóa đơn vẫn lưu, log cảnh báo", 7, 14, "hinh_s84"),
]

# --------------------------------------------------------------------------------------------------------------------
# 7.4 Thảo luận kết quả
# --------------------------------------------------------------------------------------------------------------------

LIMITS = [
    ["L1", "Chế độ tìm kiếm PostgreSQL (mặc định) không bỏ dấu, không chịu lỗi chính tả, không xếp theo độ liên quan; "
           "LIKE '%…%' quét mọi dòng của người dùng"],
    ["L2", "Ghi NoSQL sau commit, bất đồng bộ, nhất quán cuối cùng: JVM dừng giữa commit và lần ghi nền thì chỉ được chữa "
           "ở lần đổi sau, lần dựng lại hoặc reindex; log OCR đã mất thì không tự chữa"],
    ["L3", "Hàng đợi của luồng nền đầy (500 tác vụ) thì tác vụ ghi NoSQL bị bỏ, chỉ log"],
    ["L4", "Cập nhật index Elasticsearch lỗi không được thử lại; tác vụ định kỳ chỉ thử lại việc tạo index"],
    ["L5", "Mô hình DONUT V5 không trả độ tin cậy, trường averageConfidenceScore để trống; thống kê độ tin cậy chỉ có số "
           "trên dữ liệu có trường này"],
    ["L6", "Mỗi CSDL một node, không replication, không sharding; replica set, Sentinel, cluster chỉ ở mức thiết kế"],
    ["L7", "Redis không ghi đĩa: OTP đang chờ mất khi Redis khởi động lại; cache, bảng xếp hạng dựng lại từ PostgreSQL"],
    ["L8", "Realtime chỉ cho web quản trị; ứng dụng di động không có push; Pub/Sub có thể mất tin"],
    ["L9", "ocr_logs chỉ lưu lần đọc đầu tiên của mỗi giao dịch; các lần đọc lại chỉ có trong PostgreSQL"],
    ["L10", "Không có trang tạo, sửa tay document MongoDB: phản hồi sinh từ chỗ sửa của người dùng, quản trị viên đọc, lọc, "
            "đánh dấu, xóa"],
    ["L11", "Sao lưu trên web chỉ có PostgreSQL và MongoDB; Redis không cần, Elasticsearch dùng snapshot qua script, Kibana "
            "hoặc reindex"],
    ["L12", "Thống kê Elasticsearch theo danh mục, tháng (Q-38..Q-40) và $facet, $lookup đối chiếu (Q-13, Q-14) chỉ có "
            "trong script"],
    ["L13", "Không có API tra log OCR theo giao dịch; bốn phương thức repository MongoDB khai báo nhưng chưa dùng"],
    ["L14", "Index đơn receiptId của ocr_feedbacks là dư (là tiền tố của receipt_field_uq)"],
    ["L15", "Chưa triển khai lên server thật; chưa có số đo mức ứng dụng (JMeter chưa chạy)"],
    ["L16", "Xử lý lỗi cache là dự phòng, không ngắt mạch: trong lúc Redis treo, mỗi request vẫn trả tối đa timeout lệnh"],
    ["L17", "Lần dựng lại chỉ mục chạy song song với các lần ghi: một trang vừa đọc có thể ghi đè bản mới hơn mà sự kiện sau "
            "commit vừa ghi (chưa dùng version ngoài); chỉ mục được chữa ở lần đổi kế tiếp của dòng đó hoặc lần reindex sau"],
    ["L18", "Bảng xếp hạng dựng lại khi đọc có thể bỏ lỡ một lần ghi xen giữa (đọc tổng từ PostgreSQL rồi mới ZADD), sai tới "
            "lần chi tiêu kế tiếp trong tháng của người đó hoặc khi hết TTL 62 ngày"],
    ["L19", "Chỉ mục đã có lúc khởi động được tin luôn: dòng ghi khi SEARCH_ENGINE=postgres hoặc bởi bộ nạp dữ liệu demo "
            "chỉ vào chỉ mục sau một lần reindex"],
    ["L20", "Một luồng nền dùng chung cho ghi Elasticsearch, Redis và MongoDB: khi một CSDL treo, hàng đợi đầy làm rơi cả "
            "tác vụ của CSDL khác (L3)"],
]

C7_4 = [
    ("p", "**Vì sao đạt.** Các NFR hiệu năng đạt với khoảng cách lớn vì mỗi CSDL chỉ nhận đúng mẫu truy cập hợp với cấu trúc "
          "của nó: Redis đọc một khóa hoặc một khoảng của Sorted Set trong dưới 0,1 ms ở máy chủ, chỉ mục đảo của "
          "Elasticsearch giữ thời gian tìm kiếm gần như không đổi theo số giao dịch, index MongoDB đưa truy vấn từ quét toàn "
          "collection về đọc vài khóa. Các yêu cầu nhất quán và bảo mật đạt nhờ thiết kế chứ không nhờ cấu hình: PostgreSQL "
          "giữ khóa ví, khóa lạc quan và clientId duy nhất; NoSQL chỉ được ghi sau commit nên rollback không để lại dấu vết; "
          "kết quả tìm kiếm luôn nạp lại từ PostgreSQL theo id và chủ sở hữu."),
    ("p", "**Vì sao chưa đạt.** Hai kết quả được ghi lại, không sửa mục tiêu. (1) NFR-05 với Q-02: bộ lọc là một khoảng trên "
          "độ tin cậy còn thứ tự sắp xếp là thời gian. Theo quy tắc ESR (Equality, Sort, Range), index {điểm, thời gian} "
          "đặt trường khoảng trước trường sắp xếp nên buộc phải sắp xếp trong bộ nhớ, còn index thời gian cho đúng thứ tự "
          "nhưng phải đọc document để lọc điểm; không index nào thỏa cả hai, nên Q-02 đọc 61 để trả 5 dù vẫn chỉ mất 0,51 ms "
          "ở p95. (2) NFR-14 với Elasticsearch 1 GB khi Kibana cùng chạy: Elasticsearch có bảo mật đã dùng gần hết 1 GB, "
          "Kibana tạo thêm các index hệ thống và đẩy nó vượt giới hạn. Cách xử lý là cấp 1,5 GB khi cần Kibana, hoặc chỉ "
          "bật Kibana khi quản trị như cấu hình hiện tại (profile tools)."),
    ("p", "**Kết quả ngược chiều.** Với người dùng có khoảng 80 giao dịch, PostgreSQL LIKE nhanh hơn Elasticsearch (0,66 ms "
          "so với 3,70 ms ở p50) vì chỉ lọc vài chục dòng trong bộ nhớ, còn mỗi lời gọi Elasticsearch qua HTTP tốn khoảng "
          "1 ms. Lợi thế của Elasticsearch ở đây là chất lượng (bỏ dấu, chịu lỗi chính tả, không bỏ sót) và độ trễ không "
          "tăng theo dữ liệu, không phải tốc độ trên tập nhỏ. Cũng chính phép đo E2 đã lộ một lỗi của ứng dụng: với "
          "fuzziness AUTO, từ ba ký tự \"pho\" được phép sai một ký tự nên khớp cả \"chợ\", \"phí\". Nhóm sửa thành AUTO:4,7 "
          "(từ dưới 4 ký tự không được sai) và prefix_length 1 (chữ cái đầu phải đúng), thêm kiểm thử, rồi đo lại; đổi lại, "
          "lỗi gõ ở từ ba ký tự hoặc ở chữ cái đầu không còn được bỏ qua."),
    ("p", "**Đánh đổi đã chấp nhận.** Nhất quán đổi lấy sẵn sàng và độ trễ: dữ liệu ở Redis, MongoDB, Elasticsearch là bản "
          "dẫn xuất, cập nhật sau commit, cũ tối đa bằng TTL 45–60 s khi một lần xóa cache lỗi, đúng hướng \"else latency\" "
          "của PACELC [6] và cách xử lý dữ liệu dẫn xuất trong [7]. Dư thừa đổi lấy tốc độ đọc: E5 cho thấy nhúng nhanh hơn "
          "2,5× nhưng gấp đôi dung lượng ocr_feedbacks, nên nhóm giữ tham chiếu bằng transactionId (log không đổi sau khi "
          "ghi, truy vấn theo người dùng đã dưới 2 ms). Đơn giản đổi lấy độ bền: không dùng outbox hay hàng đợi tin nhắn, "
          "chấp nhận cửa sổ mất dữ liệu nhỏ khi JVM dừng (L2 ở [[bang_han_che]])."),
    ("table", "Hạn chế của hệ thống", 7, [800, 7704], ["#", "Hạn chế"], LIMITS, "", "bang_han_che"),
]

# ====================================================================================================================
# CHƯƠNG 8
# ====================================================================================================================

C8_0 = [
    ("p", "Chương này đối chiếu sản phẩm với mục tiêu ban đầu (8.1, 8.2), tổng kết hoạt động của nhóm (8.3), rút kinh "
          "nghiệm (8.4), nêu hướng phát triển (8.5) và đối chiếu từng tiêu chí đánh giá của môn học với phần minh chứng "
          "trong báo cáo (8.6)."),
]

RESULTS = [
    ["FR-01 Đăng nhập và phân quyền", "100 %", "JWT cho di động; form login cho web; hai lớp kiểm tra ROLE_ADMIN"],
    ["FR-02 Quên mật khẩu bằng OTP", "100 %", "Hash Redis, Lua nguyên tử, hạn 5 phút, sai tối đa 3 lần"],
    ["FR-03 Ghi giao dịch", "100 %", "Chống trùng clientId, khóa ví; sau commit cập nhật cache, xếp hạng, index"],
    ["FR-04 Sửa, xóa giao dịch", "100 %", "Đồng bộ sau commit như FR-03"],
    ["FR-05 Quét hóa đơn bằng AI", "100 %", "JSON thô ở PostgreSQL; bản sao phân tích ocr_logs chỉ cho lần đọc đầu (L9)"],
    ["FR-06 Sửa kết quả AI", "100 %", "Một document mỗi hóa đơn và trường; báo realtime cho quản trị viên"],
    ["FR-07 Trang chủ thống kê", "100 %", "Cache Redis, TTL có jitter"],
    ["FR-08 Tìm kiếm giao dịch", "100 %", "Đủ yêu cầu ở chế độ Elasticsearch; chế độ PostgreSQL không bỏ dấu (L1)"],
    ["FR-09 Dashboard quản trị", "100 %", "Tổng quan có cache, top 5 chi tiêu tháng"],
    ["FR-10 Bảng xếp hạng", "100 %", "Sorted Set, dựng lại từ PostgreSQL"],
    ["FR-11 Duyệt phản hồi OCR", "100 %", "Lọc, sắp xếp, phân trang, đánh dấu, xóa trên web và REST"],
    ["FR-12 Thống kê chất lượng OCR", "100 %", "Ba biểu đồ; độ tin cậy trống với DONUT V5 (L5)"],
    ["FR-13 API xem log OCR thô", "100 %", "Chỉ REST, đúng như đặc tả"],
    ["FR-14 Vận hành chỉ mục", "100 %", "Reindex trên web và REST, đếm document"],
    ["FR-15 Sao lưu, khôi phục", "100 %", "PostgreSQL và MongoDB trên web; Redis, Elasticsearch bằng script (L11)"],
    ["FR-16 Thông báo realtime", "100 %", "Toast và badge trên web quản trị; chưa có push di động (L8)"],
]


def deliverable_rows():
    pct = round(100 * N_DONE / N_SHOTS)
    return [
        ["Script cho từng CSDL", "100 %", "Q-01..Q-41, sao lưu/khôi phục, dữ liệu mẫu JSON, stack demo"],
        ["Kiểm thử", "100 %", f"55/55 ca đạt; {RUN2['tests']} test tự động xanh"],
        ["Ảnh minh chứng", f"{pct} %", f"{N_DONE}/{N_SHOTS} ảnh đã có; {N_SHOTS - N_DONE} ảnh giữ chỗ"],
        ["Báo cáo Word", "⟦…⟧", "Đủ 9 chương; còn ảnh giữ chỗ và các ô tô vàng"],
        ["Slide, video demo", "⟦…⟧", "Kịch bản demo ở Phụ lục D"],
    ]


NFR_RESULT = [
    ["NFR-01", "Đọc cache p95 < 5 ms", "p95 0,060–0,065 ms (E4)", "Đạt"],
    ["NFR-02", "Cache nhanh hơn ≥ 5× (p50)", "11×, 39×, 529× (E4)", "Đạt"],
    ["NFR-03", "Tìm kiếm p95 < 100 ms trên 100k", "p95 5,65 ms và 4,95 ms (E2)", "Đạt"],
    ["NFR-04", "\"pho\" ra \"Phở\", chịu lỗi gõ, tiền tố, không lộ dữ liệu", "Bỏ sót 0 (E2); TC-32..TC-35", "Đạt ở chế độ "
     "Elasticsearch; PostgreSQL không bỏ dấu"],
    ["NFR-05", "IXSCAN, đọc bằng số trả về, p95 < 20 ms", "Q-01, Q-03 đạt; Q-02 đọc 61 trả 5 (E1)", "Đạt một phần"],
    ["NFR-06", "Top 10 p95 < 5 ms", "p95 0,39 ms kèm tra tên (E3)", "Đạt"],
    ["NFR-07", "Redis dừng vẫn trả lời", "TC-10, TC-11; trên ứng dụng chưa đo", "Đạt theo kiểm thử"],
    ["NFR-08", "Elasticsearch dừng vẫn tìm được", "TC-36, TC-40; trên ứng dụng chưa đo", "Đạt theo kiểm thử"],
    ["NFR-09", "MongoDB dừng vẫn ghi giao dịch", "TC-30", "Đạt theo kiểm thử"],
    ["NFR-10", "PostgreSQL strong, NoSQL eventual sau commit", "TC-08, TC-09, TC-52..TC-54", "Đạt"],
    ["NFR-11", "Không lộ dữ liệu người khác", "TC-07, TC-35, TC-37, TC-44", "Đạt"],
    ["NFR-12", "Quản trị chỉ ROLE_ADMIN; CSDL có mật khẩu", "TC-19, TC-31, TC-45; cấu hình", "Đạt"],
    ["NFR-13", "Khôi phục MongoDB khớp 100 %, < 5 phút", "mongorestore 0,543 s, số đếm khớp", "Đạt; thao tác trên web chưa đo"],
    ["NFR-14", "Chạy trong giới hạn bộ nhớ", "Redis, MongoDB < 20 %; Elasticsearch bị OOM khi bật Kibana", "Đạt một phần"],
    ["NFR-15", "Sự kiện tới trình duyệt < 1 s", "p95 1,573 ms phía server (E6)", "Đạt phần server; chặng trình duyệt chưa đo"],
    ["NFR-16", "Nhiều instance dùng chung Redis", "TC-55, TC-17", "Đạt"],
]

C8_1 = [
    ("p", "[[bang_ket_qua]] so từng chức năng với mô tả ở mục 3.3 và các sản phẩm phải nộp. Mức hoàn thành 100 % nghĩa là "
          "chức năng có mã nguồn, có ca kiểm thử chạy xanh và làm đúng mô tả; phần cột ghi chú nêu giới hạn còn lại. Số ảnh "
          "minh chứng được đếm lúc dựng báo cáo."),
    ("table", "Kết quả đạt được so với mục tiêu", 8, [3000, 1100, 4404], ["Chức năng / sản phẩm", "Hoàn thành", "Ghi chú"],
     RESULTS + deliverable_rows(), "", "bang_ket_qua"),
    ("y", "Ghi chú cho nhóm: điền mức hoàn thành của báo cáo Word, slide và video khi chốt."),
]

C8_2 = [
    ("p", f"[[bang_nfr_ket_qua]] đối chiếu từng NFR (mục tiêu ở {TAB_GOALS}, chi tiết ở {TAB_NFR}) với kết quả của Chương 7. "
          f"Tám NFR đạt trọn; NFR-04, NFR-13, NFR-15 đạt ở phần đã đo, phần còn lại ghi rõ trong bảng; ba NFR sẵn sàng "
          f"(NFR-07..NFR-09) đạt theo kiểm thử nhưng chưa có độ trễ quan sát trên ứng dụng; NFR-05 và NFR-14 đạt một phần. "
          f"Mục tiêu không được sửa theo số đo."),
    ("table", "Đối chiếu yêu cầu phi chức năng với kết quả", 8, [1150, 2450, 2700, 2204],
     ["NFR", "Mục tiêu (rút gọn)", "Kết quả", "Kết luận"], NFR_RESULT,
     "Số đo E1–E6: mục 7.2; kiểm thử: mục 7.1, 7.3", "bang_nfr_ket_qua"),
    ("p", "Ngoài NFR, đồ án đạt yêu cầu tối thiểu của môn: MongoDB hai collection có dữ liệu mẫu JSON, CRUD, lọc, sắp xếp, "
          "thống kê; Redis ba nhóm khóa (cache, OTP, bảng xếp hạng) và một kênh Pub/Sub, đều có hết hạn trừ kênh; "
          "Elasticsearch là CSDL tự tìm hiểu; bốn loại dữ liệu (mục 3.5). Đối chiếu chi tiết ở mục 8.6."),
]

C8_3 = [
    ("p", f"**Mức độ hoàn thành theo bảng phân công.** Theo {TAB_TASKS} (mục 1.6), các việc T01..T06 của Trí (cache, OTP, "
          f"log OCR, bảng xếp hạng, phân tích OCR, script, trang quản trị, sao lưu MongoDB, realtime, tìm kiếm, bảng yêu cầu, "
          f"sơ đồ, đo hiệu năng) đã hoàn thành; T07 (stack demo, dựng báo cáo Word) đang hoàn tất với Chương 7–9 trong bản "
          f"này. Các việc T08..T12 của Tiến là phần minh chứng và trình bày: truy vấn MongoDB trên Compass, tìm hiểu Kibana "
          f"và Elasticvue, chạy lại sao lưu và truy vấn, chụp ảnh phía người dùng, soát Chương 2, 5 và chính tả, slide, video "
          f"và hỏi đáp."),
    ("table", "Mức độ hoàn thành và đóng góp của từng thành viên", 8, [1500, 3104, 2300, 1600],
     ["Thành viên", "Việc (theo bảng phân công)", "Mức hoàn thành", "Đóng góp"],
     [["Phan Thanh Trí (nhóm trưởng)", "T01..T07: phân tích, kiến trúc, toàn bộ mã nguồn và kiểm thử, script, đo hiệu năng, "
       "stack demo, dựng báo cáo", "T01..T06 hoàn thành; T07 ⟦nhóm cập nhật⟧", "⟦khoảng 60 %⟧"],
      ["Phan Minh Tiến", "T08..T12: minh chứng trên GUI tool, tìm hiểu Kibana và Elasticvue, chạy lại script, ảnh phía người "
       "dùng, soát báo cáo, slide, video", "⟦nhóm cập nhật⟧", "⟦khoảng 40 %⟧"]],
     "Đóng góp do nhóm tự đánh giá; nhóm chốt trước khi nộp", "bang_dong_gop"),
    ("p", f"**Ghi công ảnh minh chứng.** Trong {N_SHOTS} ảnh S-xx, {N_AGENT} ảnh được chụp tự động bằng script trên stack demo "
          f"(Kibana, Elasticvue, RedisInsight, terminal) và không ghi công cho ai; các ảnh còn lại (Compass, ứng dụng, trang "
          f"quản trị, Postman, dừng dịch vụ) do thành viên chụp tay. Lúc dựng bản này còn {len(PLACEHOLDERS)} ảnh giữ chỗ."),
    ("p", "**Cách phối hợp.** Hai thành viên làm chung nhánh feature/nosql của kho mã: luôn git pull --rebase trước khi làm, "
          "mỗi việc một commit nhỏ. Phân vùng thư mục tránh xung đột: Trí sửa mã nguồn, script và bộ dựng báo cáo; Tiến chỉ "
          "thêm ảnh minh chứng và ghi chú (docs/nosql/screenshots, docs/nosql/tim_hieu_tool, docs/nosql/ghi_chu_tien), chỗ "
          "nào thấy sai thì ghi vào ghi chú để Trí sửa. Tài liệu hướng dẫn việc của Tiến (docs/nosql/HUONG_DAN_TIEN.md) liệt "
          "kê lệnh dựng CSDL demo, danh sách ảnh và câu hỏi tự kiểm tra. Quy ước mỗi người commit bằng tài khoản GitHub "
          "của chính mình để bảng phân công đối chiếu được với lịch sử commit."),
    ("y", "Ghi chú cho nhóm: điền mức hoàn thành T07..T12, tỉ lệ đóng góp chốt, và (nếu có) lịch họp, cách review khi chốt "
          "báo cáo; cột ngày của bảng phân công ở mục 1.6 cũng chờ nhóm điền."),
]

C8_4 = [
    ("p", "**Về quy trình nhóm.**"),
    ("b1", "Chốt mục tiêu đo được và danh sách ca kiểm thử trước khi đo giúp báo cáo trung thực: hai kết quả chưa đạt (Q-02, "
           "Elasticsearch 1 GB) được ghi lại thay vì sửa mục tiêu cho khớp."),
    ("b1", "Mỗi con số trong báo cáo đi kèm nguồn (kiểm thử, script, phép đo) và loại dữ liệu (demo hay tổng hợp 100k), nên "
           "người đọc chạy lại được và nhóm tránh được nhầm giữa hai tập dữ liệu."),
    ("b1", "Khi mọi commit cùng một tài khoản, lịch sử Git không chứng minh được phân công; vì vậy nhóm quy ước mỗi người "
           "commit bằng tài khoản riêng và ghi rõ trong bảng phân công ai làm gì, kể cả phần ảnh chụp tự động không ghi "
           "công cho ai."),
    ("b1", "Ảnh giữ chỗ có mã S-xx cố định cho phép viết báo cáo song song với việc chụp: thay ảnh thật vào sau mà số hình "
           "và chú thích không đổi."),
    ("p", "**Về lựa chọn và thiết kế NoSQL.**"),
    ("b1", "Giữ PostgreSQL làm nguồn sự thật và coi mọi dữ liệu NoSQL là bản dẫn xuất làm sao lưu, khôi phục và chịu lỗi đơn "
           "giản hơn nhiều: Redis không cần sao lưu, chỉ mục dựng lại bằng reindex."),
    ("b1", "Thiết kế bắt đầu từ mẫu truy cập: mỗi AP có cấu trúc đáp ứng, nên index MongoDB, khóa Redis và mapping "
           "Elasticsearch đều có lý do và có số đo."),
    ("b1", "Đo trên dữ liệu đủ lớn tìm ra lỗi mà kiểm thử chức năng không thấy: fuzziness AUTO làm \"pho\" khớp \"chợ\"; "
           "$lookup đặt trước $sort, $limit chậm hơn hơn một nghìn lần."),
    ("b1", "Giới hạn bộ nhớ một máy là ràng buộc thật: Elasticsearch có bảo mật cần hơn 1 GB khi Kibana cùng chạy."),
]

C8_5 = [
    ("b1", "**Push trên di động:** đưa sự kiện realtime tới ứng dụng di động bằng Firebase Cloud Messaging, dùng lại kênh sự "
           "kiện hiện có."),
    ("b1", "**Cụm và bản sao:** MongoDB replica set ba node, Redis Sentinel hoặc Redis Cluster, Elasticsearch ba node với "
           "một replica; khi đó mới đo được failover như mục 7.3 gợi ý."),
    ("b1", "**Giám sát:** thu số đo ứng dụng và CSDL bằng Prometheus, hiển thị bằng Grafana, cảnh báo khi một CSDL dừng hay "
           "bộ nhớ gần giới hạn."),
    ("b1", "**Tìm kiếm bỏ dấu ở chế độ PostgreSQL:** dùng extension unaccent và index trigram để chế độ mặc định không còn "
           "giới hạn L1."),
    ("b1", "**Độ bền của bản sao:** ghi sự kiện vào bảng outbox trong cùng giao dịch PostgreSQL rồi phát lại, để thay đổi "
           "không mất khi JVM dừng (L2, L3) và cập nhật index lỗi được thử lại (L4); dựng chỉ mục mới rồi đổi alias, ghi "
           "với version ngoài (L17); bộ đếm thế hệ cho bảng xếp hạng (L18); so số document với PostgreSQL lúc khởi động "
           "(L19); mỗi CSDL một luồng nền riêng (L20)."),
    ("b1", "**API còn thiếu:** đưa Q-13, Q-14 và thống kê Elasticsearch theo danh mục, tháng (Q-38..Q-40) thành API và "
           "biểu đồ; bỏ index dư của ocr_feedbacks (L12–L14)."),
    ("b1", "**Triển khai và đo mức ứng dụng:** chạy hệ thống trên server thật, chạy JMeter để có độ trễ đầu-cuối (L15); có "
           "thể dùng dịch vụ đám mây như MongoDB Atlas, Elastic Cloud."),
]

# --------------------------------------------------------------------------------------------------------------------
# 8.6 Đối chiếu tiêu chí đánh giá (barem). barem.py nhập BAREM_ROWS.
# Mỗi dòng: [tiêu chí / yêu cầu, mục trong báo cáo, minh chứng, trạng thái]. Không ghi điểm đạt được.
# --------------------------------------------------------------------------------------------------------------------

B_BASIC = sids(20, 27) + sids(36, 40) + [f"S-{i}" for i in (48, 49, 50, 51, 52, 53)]
B_ADV = sids(28, 35) + sids(41, 47) + sids(54, 60)

BAREM_ROWS = [
    ["Tiêu chí 1: lý thuyết và cài đặt GUI tool (Kibana)", "2.5.1", "Kiến trúc, phiên bản 8.11.4, các bước cài; S-01, S-02, "
     "S-10", shot_status(["S-01", "S-02", "S-10"])],
    ["Tiêu chí 2: các chức năng của tool", "2.5.2", "Quản lý index, Dev Tools, nhập/xuất, snapshot, phân quyền, giám sát; "
     "S-03..S-09", shot_status(sids(3, 9))],
    ["Tiêu chí 3: so sánh với Elasticvue", "2.5.3", f"{TAB_GUI} (7 tiêu chí, có nguồn hoặc số đo); S-11..S-14",
     shot_status(sids(11, 14))],
    ["Tiêu chí 4: tool phù hợp loại ứng dụng nào", "2.5.4", "Lập luận gắn với LedgerMind", "Có"],
    ["Tiêu chí 5–7: tạo database", "5.2", "mongodb_init.js ($jsonSchema, 11 index), index Elasticsearch, quy ước khóa và "
     "TTL Redis; S-15, S-16, S-18, S-19", shot_status(["S-15", "S-16", "S-18", "S-19"])],
    ["Tiêu chí 5–7: nhập dữ liệu", "5.3", "36 + 36 document MongoDB, 47 giao dịch Elasticsearch, khóa Redis; S-17",
     shot_status(["S-17"])],
    ["Tiêu chí 5–7: truy vấn cơ bản", "5.4", "19 truy vấn Q-01..Q-08, Q-17..Q-21, Q-29..Q-34; ảnh S-(n+19)",
     shot_status(B_BASIC)],
    ["Tiêu chí 5–7: truy vấn nâng cao", "5.5", "22 truy vấn Q-09..Q-16, Q-22..Q-28, Q-35..Q-41; ảnh S-(n+19)",
     shot_status(B_ADV)],
    ["Tiêu chí 5–7: nhập/xuất, sao lưu, khôi phục", "5.6", "Đếm → xóa → khôi phục → đếm cho cả ba CSDL; S-61..S-66, S-86, "
     "S-87; TC-29, TC-49, TC-50", shot_status(sids(61, 66) + ["S-86", "S-87"])],
    ["Tiêu chí 8: kết nối CSDL với phần mềm", "6.2", "Cấu hình, repository, xử lý lỗi kết nối từng CSDL (mã trích "
     "nguyên văn); TC-10, TC-30, TC-36", "Có"],
    ["Tiêu chí 9, nhóm 1: quản trị người dùng", "6.3", "Đăng nhập, phân quyền, OTP Redis; S-67..S-70",
     shot_status(sids(67, 70))],
    ["Tiêu chí 9, nhóm 2: thao tác trên CSDL", "6.3, 5.6", "Đọc, lọc, đánh dấu, xóa phản hồi; sao lưu, khôi phục MongoDB "
     "trên web; S-71..S-73, S-65, S-66", shot_status(sids(71, 73) + ["S-65", "S-66"])],
    ["Tiêu chí 9, nhóm 3: nghiệp vụ", "6.3", "Tìm kiếm tiếng Việt, đồng bộ chỉ mục, sửa kết quả AI; S-74..S-76",
     shot_status(sids(74, 76))],
    ["Tiêu chí 9, nhóm 4: chức năng hỗ trợ", "6.3, 6.4", "Thống kê, bảng xếp hạng, realtime, cache; S-77..S-81",
     shot_status(sids(77, 81))],
    ["Tiêu chí 10a: báo cáo đầy đủ, đúng chính tả, định dạng, không sao chép", "Chương 1–9", "Đủ 9 chương; tài liệu tham "
     "khảo IEEE (mục 9.1); mọi trích dẫn có nguồn", "Đang soát chính tả và định dạng"],
    ["Tiêu chí 10b: thuyết trình tự tin, trả lời câu hỏi", "Phụ lục D", "Kịch bản demo 5–7 phút", "Chờ buổi báo cáo"],
    ["Tiêu chí 10c: nộp đúng hạn, đủ Word, PowerPoint, mã nguồn", "1.6, Phụ lục A", "Báo cáo Word (bản này); mã nguồn: "
     "nhánh main của kho, sau khi gộp nhánh feature/nosql (repo riêng tư: thêm giảng viên làm collaborator hoặc nộp kèm tệp nén)", "PowerPoint chưa có"],
    ["Tiêu chí 10d: phân chia công việc rõ ràng", "1.6, 8.3", f"{TAB_TEAM}, {TAB_TASKS}; bảng đóng góp ở mục 8.3",
     "Ngày và tỉ lệ đóng góp chờ nhóm chốt"],
    ["MongoDB: ≥ 2 collection", "4.4, 5.2", "ocr_logs, ocr_feedbacks", "Có"],
    ["MongoDB: dữ liệu mẫu JSON", "5.3", "scripts/nosql/sample_data (ocr_logs.json, ocr_feedbacks.json)", "Có"],
    ["MongoDB: CRUD", "5.4, 5.5, 6.3", "Q-05..Q-09; trang /admin/ocr-feedbacks; TC-20..TC-28", "Có (thêm do ứng dụng sinh, "
     "không có trang thêm tay)"],
    ["MongoDB: lọc, tìm kiếm, sắp xếp, thống kê", "5.4, 5.5", "Q-01..Q-04, Q-10..Q-15", "Có"],
    ["Redis: ≥ 2 nhóm key-value", "4.3", "Cache thống kê, OTP, bảng xếp hạng (và kênh Pub/Sub)", "Có"],
    ["Redis: cache, leaderboard hoặc OTP", "4.3, 6.3", "Cả ba", "Có"],
    ["Redis: có thời gian hết hạn", "4.3, 5.4", "OTP 5 phút, cache 45–60 s, bảng xếp hạng 62 ngày; Q-17, Q-19, Q-20", "Có"],
    ["≥ 2/4 loại NoSQL đã học", "2.3, 4.2", "Key-Value (Redis), Document (MongoDB)", "Có"],
    ["≥ 1 CSDL tự tìm hiểu", "2.3, 4.5, 2.5", "Elasticsearch 8.11.4 và GUI tool Kibana", "Có"],
    ["≥ 4 loại dữ liệu khác nhau", "3.5", "Quan hệ, bán cấu trúc, key-value có hạn, tài liệu tìm kiếm", "Có"],
    ["SRS và SDS có tính năng mới", "Chương 3, 4", "Đặc tả FR, NFR, AP; thiết kế từng CSDL, đồng bộ, ánh xạ AP", "Có"],
    ["Nộp: source code", "Phụ lục A", "Nhánh main của kho mã", "Có"],
    ["Nộp: script cho từng CSDL", "5.2–5.6, Phụ lục C", "mongodb_init.js, mongodb_demo.js, redis_demo.txt, thư mục "
     "elasticsearch, backup_restore.md", "Có"],
    ["Nộp: tài liệu đặc tả, thiết kế", "Chương 3, 4", "SRS, SDS trong báo cáo này", "Có"],
    ["Nộp: tài liệu kiểm thử", "Chương 7", "55 ca TC, 40 lớp kiểm thử", "Có"],
    ["Nộp: báo cáo kết quả, báo cáo hoạt động nhóm", "Chương 8; 1.6", "8.1–8.3", "Có; tỉ lệ đóng góp chờ nhóm chốt"],
    ["Nộp: video demo", "Phụ lục D", "Kịch bản 4 phần", "Chưa quay"],
]

C8_6 = [
    ("p", "[[bang_barem]] nối từng tiêu chí đánh giá, yêu cầu tối thiểu và sản phẩm phải nộp với mục trong báo cáo, minh "
          "chứng và trạng thái hiện tại. Tiêu chí 10 gồm bốn ý, mỗi ý 0,5 điểm. Tiêu chí 5–7 được ghi theo từng mục "
          "5.2–5.6 vì mỗi mục là một phần chấm riêng. Bảng chỉ ghi trạng thái của minh chứng, không tự chấm điểm; cột "
          "trạng thái liệt kê các ảnh còn giữ chỗ lúc dựng bản này."),
    ("table", "Đối chiếu tiêu chí đánh giá với báo cáo", 8, [2400, 1200, 3100, 1804],
     ["Tiêu chí / yêu cầu", "Mục", "Minh chứng", "Trạng thái"], nb(BAREM_ROWS), "", "bang_barem"),
]

# ====================================================================================================================
# CHƯƠNG 9
# ====================================================================================================================

C9_0 = [
    ("p", "Chương này liệt kê tài liệu tham khảo theo thứ tự trích dẫn và bốn phụ lục: cấu trúc mã nguồn, ma trận ánh xạ "
          "mẫu truy cập sang thiết kế, hướng dẫn chạy demo và kịch bản demo."),
]


def reference_entries():
    text = (NOSQL / "references.md").read_text(encoding="utf8")
    refs = re.findall(r"^\[(\d+)\] (.+)$", text, re.M)
    nums = [int(n) for n, _ in refs]
    assert nums == list(range(1, len(nums) + 1)), nums
    return [("p", f"[{n}] {body.strip()}") for n, body in refs]


C9_1 = reference_entries()

TREE = """\
./
├── core-backend/          Spring Boot 3.2.5, Java 21: API, web admin
│   ├── src/main/java/vn/edu/huit/finance/core/
│   │   ├── Config/        Redis, cache, Elasticsearch, Async, Realtime
│   │   ├── Controller/    REST /api, web /admin, SSE /admin/events
│   │   ├── Document/      OcrRawLog, OcrFeedback, Search/
│   │   ├── Repository/    JPA; Mongo/
│   │   └── Service/       Cache/, Search/, Realtime/, OCR, backup
│   ├── src/main/resources/  *.properties, elasticsearch/, templates/
│   └── src/test/          JUnit 5, Mockito, Testcontainers
├── mobile-app/            Flutter
├── ai-service/            Python: DONUT, receipt reading
├── scripts/nosql/
│   ├── mongodb_init.js, mongodb_demo.js, redis_demo.txt
│   ├── elasticsearch/     kibana-devtools.txt, bulk, README
│   ├── sample_data/       ocr_logs.json, ocr_feedbacks.json
│   ├── backup_restore.md, NoSQL_Postman_Collection.json
│   ├── demo-stack.sh, demo-stack.compose.yml
│   └── bench/             gen_data.py, run_all.sh (E1-E5)
├── docs/nosql/            diagrams, bench, screenshots, demo script
├── docs/testing/          Postman, JMeter
└── docker-compose.yml     PostgreSQL, Redis, MongoDB, ES, Kibana"""

C9_2 = [
    ("p", "Cây thư mục chính của kho mã (nhánh main, sau khi gộp nhánh feature/nosql); chỉ ghi các thư mục liên quan tới phần NoSQL:"),
    ("code", TREE),
    ("p", "Đường dẫn J/ và R/ dùng trong báo cáo là core-backend/src/main/java/vn/edu/huit/finance/core/ và "
          "core-backend/src/main/resources/."),
]

C9_3 = [
    ("p", "Bảng đầy đủ 38 mẫu truy cập của mục 3.6 và cấu trúc, lệnh đáp ứng từng mẫu; mục 4.11 trích sáu dòng của bảng này. "
          "PG là PostgreSQL, ES là Elasticsearch, Mongo là MongoDB."),
    ("table", "Ma trận ánh xạ AP → thiết kế (đủ 38 mẫu truy cập)", 9, [900, 1100, 3300, 3204],
     ["AP", "CSDL", "Cấu trúc đáp ứng", "Truy vấn / lệnh"], AP_DESIGN_ROWS, "AP đóng băng ngày 27/10/2026 (mục 3.6)",
     "bang_ap_day_du"),
]

DEMO_README = "scripts/nosql/demo-stack.README.md"

C9_4 = [
    ("p", "**1. Stack demo (CSDL và GUI tool, không có ứng dụng).** Cần Docker và Docker Compose v2; chạy từ thư mục gốc của "
          "kho. Stack tách hẳn khỏi hệ thống thật: project nosql-demo, mạng và volume riêng, mọi cổng chỉ mở trên 127.0.0.1."),
] + code(DEMO_README, 14, 18, "Các lệnh của stack demo") + [
    ("p", "Địa chỉ mặc định: MongoDB Compass nối mongodb://127.0.0.1:27018 (tài khoản root của stack demo, authSource=admin); "
          "RedisInsight http://localhost:5541; Kibana http://localhost:5602; Elasticvue http://localhost:8081; "
          "Elasticsearch http://localhost:9201. Lệnh up in lại đầy đủ địa chỉ và tài khoản demo ở cuối."),
    ("p", "**2. Nạp dữ liệu và chạy script.** Lệnh up (hoặc load) chạy đúng các script nộp kèm trong container của stack: "
          "mongosh chạy mongodb_init.js rồi mongodb_demo.js (database finance_nosql_demo, 36 + 36 document); redis-cli đọc "
          "redis_demo.txt từ stdin; curl tạo index transactions từ hai tệp settings và mapping của ứng dụng rồi nạp "
          "transactions-bulk.ndjson bằng _bulk (47 giao dịch). Lệnh load chạy lại các bước này sau khi đã thử xóa, sửa."),

    ("p", "Truy vấn Q-01..Q-16 mở trong Compass (database finance_nosql_demo), Q-17..Q-29 và Q-41 trong RedisInsight "
          "Workbench, Q-30..Q-40 trong Kibana Dev Tools (scripts/nosql/elasticsearch/kibana-devtools.txt). Kịch bản sao lưu "
          "và khôi phục từng CSDL ở scripts/nosql/backup_restore.md."),
    ("p", "**3. Hệ thống đầy đủ có ứng dụng.** Elasticsearch chỉ chạy với profile search và ứng dụng chỉ dùng nó khi biến môi "
          "trường SEARCH_ENGINE là elasticsearch; Kibana cần thêm profile tools:"),
    ("code", "# .env: REDIS_PASSWORD, ELASTIC_PASSWORD, SEARCH_ENGINE=elasticsearch\n"
             "docker compose --profile search up -d\n"
             "docker compose --profile search --profile tools up -d   # thêm Kibana"),
    ("p", "**4. Kiểm thử.** Bốn mươi lớp kiểm thử của mục 7.1 chạy bằng Maven trong core-backend (cần Docker cho "
          "Testcontainers): mvn test với tham số -Dtest liệt kê tên lớp."),
]

DEMO_W = [1150, 1500, 4300, 1554]
DEMO_H = ["Thời lượng", "Phần", "Nội dung, màn hình, lệnh", "Q-id, ảnh"]
DEMO_ROWS = [
    ["0:00–0:20", "1. Giới thiệu", "Slide bìa: tên đề tài, nhóm 38, hai thành viên, giảng viên hướng dẫn", "–"],
    ["0:20–1:00", "1. Giới thiệu", "Sơ đồ kiến trúc (mục 4.1): PostgreSQL nguồn sự thật; Redis key-value; MongoDB document; "
     "Elasticsearch tìm kiếm (CSDL tự tìm hiểu); công cụ Compass, RedisInsight, Kibana", "–"],
    ["1:00–1:30", "2. Nhóm 1: người dùng", "Ứng dụng: đăng nhập; web quản trị: đăng nhập, trang người dùng; quên mật khẩu, nhập OTP; "
     "RedisInsight mở Hash OTP thấy TTL giảm", "S-67..S-70; Q-17"],
    ["1:30–2:10", "2. Nhóm 2: thao tác CSDL", "/admin/ocr-feedbacks: lọc, đánh dấu đã xử lý, xóa → Compass bấm Refresh "
     "thấy isResolved đổi, document mất; /admin/backup: sao lưu, khôi phục MongoDB → Compass đếm lại",
     "S-72, S-73, S-65, S-66; Q-03, Q-07, Q-08"],
    ["2:10–2:40", "2. Nhóm 3: nghiệp vụ", "Ứng dụng: quét hóa đơn, sửa tổng tiền → Compass thấy document ocr_feedbacks mới; "
     "Sổ cái gõ \"pho\" ra các dòng \"Phở\"; Kibana Dev Tools lấy document của giao dịch vừa tạo", "S-76, S-74, S-75; Q-09, Q-31"],
    ["2:40–3:00", "2. Nhóm 4: hỗ trợ", "/admin/dashboard top 5 chi tiêu tháng + RedisInsight mở Sorted Set của tháng; trang "
     "chủ ứng dụng + khóa cache user-dashboard", "S-77, S-79, S-81; Q-19, Q-23"],
    ["3:00–3:30", "3. Realtime", "Hai tab quản trị; tab 1 bấm \"Dựng lại bảng xếp hạng\" trên /admin/nosql → toast hiện ở "
     "tab 2", "S-78, S-80; Q-41"],
    ["3:30–4:00", "3. Cache", "Postman gọi /api/transactions/app-dashboard hai lần (lần đầu trượt, lần sau trúng), xem thời "
     "gian; RedisInsight thấy khóa và TTL; biểu đồ E4", "Q-19; E4"],
    ["4:00–4:30", "3. Index", "Compass Explain Plan của Q-03: IXSCAN trên status_date_idx; biểu đồ E1 có và không index",
     "S-35; Q-16; E1"],
    ["4:30–5:15", "3. Dừng dịch vụ", "docker compose stop redis → Postman gọi lại dashboard, vẫn trả lời (độ trễ ⟦… ms⟧) → "
     "docker compose start redis; docker compose stop elasticsearch → tìm \"pho\" vẫn trả lời, engine = postgres (độ trễ "
     "⟦… ms⟧) → docker compose start elasticsearch", "S-83, S-82"],
    ["5:15–5:30", "3. Benchmark", "Biểu đồ E2 (tìm kiếm) và E3 (bảng xếp hạng)", "E2, E3"],
    ["5:30–6:15", "4. Hạn chế", "Chế độ PostgreSQL không bỏ dấu; ghi NoSQL nhất quán cuối cùng; một node mỗi CSDL; realtime "
     "chỉ trên web; Elasticsearch 1 GB không đủ khi bật Kibana", "Mục 7.4"],
    ["6:15–7:00", "4. Hướng phát triển", "Push di động, replica set và Sentinel, Prometheus và Grafana, tìm kiếm bỏ dấu ở "
     "PostgreSQL, outbox", "Mục 8.5"],
]

C9_5 = [
    ("p", "Kịch bản 5–7 phút cho buổi báo cáo hoặc video, gồm bốn phần với thời lượng định sẵn. Mỗi thao tác demo mở GUI "
          "tool song song để thấy dữ liệu thay đổi thật; mỗi dòng ghi màn hình, lệnh và mã truy vấn hoặc ảnh tương ứng. Bản "
          "chi tiết kèm bước chuẩn bị ở docs/nosql/kich_ban_demo.md."),
    ("table", "Kịch bản demo 5–7 phút", 9, DEMO_W, DEMO_H, nb(DEMO_ROWS), "", "bang_kich_ban"),
    ("p", "Phần dừng dịch vụ chạy trên hệ thống đầy đủ của nhóm (có ứng dụng, Elasticsearch bật profile search và "
          "SEARCH_ENGINE là elasticsearch), không chạy trên stack demo. Độ trễ quan sát được ghi vào bảng ở mục 7.3."),
]

HEADING_PLACEHOLDERS = {
    "KIỂM THỬ VÀ ĐÁNH GIÁ": C7_0,
    "KIỂM THỬ CHỨC NĂNG": C7_1,
    "ĐÁNH GIÁ HIỆU NĂNG": C7_2,
    "KIỂM THỬ CHỊU LỖI": C7_3,
    "THẢO LUẬN KẾT QUẢ": C7_4,
    "KẾT QUẢ ĐẠT ĐƯỢC VÀ TỔNG KẾT HOẠT ĐỘNG NHÓM": C8_0,
    "KẾT QUẢ ĐẠT ĐƯỢC": C8_1,
    "ĐÁNH GIÁ KẾT QUẢ THEO MỤC TIÊU": C8_2,
    "TỔNG KẾT HOẠT ĐỘNG NHÓM": C8_3,
    "RÚT KINH NGHIỆM": C8_4,
    "HƯỚNG PHÁT TRIỂN": C8_5,
    "ĐỐI CHIẾU TIÊU CHÍ ĐÁNH GIÁ": C8_6,
    "TÀI LIỆU THAM KHẢO VÀ PHỤ LỤC": C9_0,
    "TÀI LIỆU THAM KHẢO": C9_1,
    "PHỤ LỤC A: CẤU TRÚC THƯ MỤC MÃ NGUỒN": C9_2,
    "PHỤ LỤC B: TRÍCH DOCKER-COMPOSE": C9_3,
    "PHỤ LỤC C: HƯỚNG DẪN CHẠY DEMO": C9_4,
    "PHỤ LỤC D: KỊCH BẢN DEMO 5–7 PHÚT": C9_5,
}

# Phụ lục B chứa ma trận AP đầy đủ (mục 4.11 trỏ tới đây), không phải trích docker-compose (đã trích ở Chương 4, 6).
TEXT_REPLACE = [("PHỤ LỤC B: TRÍCH DOCKER-COMPOSE", "PHỤ LỤC B: MA TRẬN ÁNH XẠ AP → THIẾT KẾ", 1)]
