"""Điền phiếu minh chứng của môn Dữ liệu NoSQL (nhóm 38) từ mẫu của khoa.

Chạy lại được (từ thư mục gốc repo):  python3 docs/nosql/build/fill_minhchung.py [mẫu.docx] [đầu_ra.docx]
Mặc định:
  mẫu    = /home/triphan/Workspace/Deploy_Project/Nosql/YC_NoSql/BaoCaoMinhChung_DoAn_DuLieuNoSQL.docx (không bao giờ sửa)
  đầu ra = /home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38/38_BaoCaoMinhChung.docx

Cách làm: sửa XML ở mức ô của các bảng trong mẫu (giữ nguyên tiêu đề trang "HỌC PHẦN DỮ LIỆU NoSQL", viền, tô nền, cỡ
chữ của mẫu), thêm hình bằng mã drawing + rels riêng (chép từ Doc.add_image/Doc.drawing của builder_nosql.py), thêm
phần III "đối chiếu tiêu chí và tự đánh giá" lấy từ BAREM_ROWS của content_c7_c9.py (cùng nguồn với barem.py).
Chữ trong ⟦ ⟧ là ghi chú cho người dùng: nghiêng + tô vàng (cùng quy ước với builder_nosql.py).
"""
import importlib.util
import re
import shutil
import struct
import sys
import unicodedata
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
DIAGRAMS = REPO / "docs/nosql/diagrams"
TEMPLATE = Path("/home/triphan/Workspace/Deploy_Project/Nosql/YC_NoSql/BaoCaoMinhChung_DoAn_DuLieuNoSQL.docx")
OUTPUT = Path("/home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38/38_BaoCaoMinhChung.docx")

EMU_PER_CM = 360000
FONT = '<w:rFonts w:ascii="Times New Roman" w:eastAsia="Arial" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>'

TITLE = ("ỨNG DỤNG CƠ SỞ DỮ LIỆU MONGODB VÀ BỘ NHỚ ĐỆM REDIS TRONG VIỆC XÂY DỰNG HỆ THỐNG QUẢN LÝ TÀI CHÍNH CÁ NHÂN")
REPO_URL = "https://github.com/TriPhan15/donutpay-monorepo"

# ------------------------------------------------------------------------------------------------------------------
# Nội dung. Mỗi ô là danh sách dòng; dòng là chuỗi (inline **đậm**, ⟦vàng⟧) hoặc ("img", tên_png, rộng_cm, chú_thích).
# ------------------------------------------------------------------------------------------------------------------

INFO = {
    0: [f"**{TITLE}**",
        "Ứng dụng LedgerMind (quản lý chi tiêu cá nhân: Flutter + Spring Boot + PostgreSQL) được mở rộng bằng MongoDB, "
        "Redis và Elasticsearch (CSDL tự tìm hiểu)."],
    1: ["**38**"],
    2: ["1. Phan Thanh Trí – 2001230977 (nhóm trưởng)",
        "2. Phan Minh Tiến – 2001230806",
        "Giảng viên hướng dẫn: ThS. Ngô Minh Anh Thư"],
    3: [f"{REPO_URL} (nhánh main).",
        "Kho riêng tư: nhóm thêm giảng viên làm collaborator hoặc nộp kèm tệp nén mã nguồn.",
        "Phần NoSQL hiện nằm ở nhánh feature/nosql. ⟦Gộp feature/nosql vào main trước khi nộp để link này đúng.⟧"],
    4: [f"Mã nguồn, script, tài liệu: {REPO_URL}; script từng CSDL và truy vấn Q-01..Q-41: thư mục scripts/nosql; "
        "bộ gọi thử API: scripts/nosql/NoSQL_Postman_Collection.json (Phụ lục A, C của báo cáo).",
        "Kịch bản demo 4 phần (5–7 phút): docs/nosql/kich_ban_demo.md (Phụ lục D). Tài liệu tham khảo kiểu IEEE: mục 9.1.",
        "Video demo: ⟦chưa quay, nhóm điền link khi có⟧"],
}

# (tên tệp hoặc đường dẫn, đã nộp, ghi chú) cho 7 dòng hồ sơ
# Số lớp và số test của lần chạy kiểm thử mới nhất (RUN2 trong content_c7_c9.py), để mẫu minh chứng khớp mục 7.1.
_RUN2 = re.search(r'RUN2 = dict\(date="([^"]+)", sha="(\w+)", tests=(\d+), classes=(\d+)\)',
                  (Path(__file__).resolve().parent / "content_c7_c9.py").read_text(encoding="utf8"))
RUN_TESTS, RUN_CLASSES = int(_RUN2.group(3)), int(_RUN2.group(4))

DELIVERABLES = [
    (["Kho mã nguồn (link ở phần trên): core-backend/, mobile-app/, ai-service/, docker-compose.yml"],
     ["Có"],
     ["Nhánh main sau khi gộp feature/nosql. Repo riêng tư: thêm giảng viên làm collaborator hoặc nộp kèm zip."]),
    (["scripts/nosql/: mongodb_init.js, mongodb_demo.js, redis_demo.txt, elasticsearch/, sample_data/, backup_restore.md, "
      "demo-stack.sh"],
     ["Có"],
     ["41 truy vấn Q-01..Q-41 cho MongoDB, Redis, Elasticsearch; cách chạy ở Chương 5 và Phụ lục C."]),
    (["38_SRS_… (bìa tuần 6) và Chương 3 của 38_BaoCao_NoSQL.docx"],
     ["Có"],
     ["Chương 3: yêu cầu chức năng FR, phi chức năng NFR, mẫu truy cập AP."]),
    (["Chương 4 của 38_BaoCao_NoSQL.docx; sơ đồ ở docs/nosql/diagrams/"],
     ["Có"],
     ["Thiết kế từng CSDL (MongoDB, Redis, Elasticsearch, PostgreSQL), đồng bộ sau commit, ánh xạ AP."]),
    (["Chương 7 của 38_BaoCao_NoSQL.docx (ca TC-01..TC-55, đo hiệu năng, thử dừng từng CSDL)",
      f"Mã kiểm thử: core-backend/src/test/java/vn/edu/huit/finance/core/ – {RUN_CLASSES} lớp, {RUN_TESTS} test. Các lớp chính: "
      "OcrMongoServiceMongoIntegrationTest, RedisStatisticsCacheIntegrationTest, RedisPasswordResetOtpStoreIntegrationTest, "
      "SpendingLeaderboardServiceIntegrationTest, ElasticsearchTransactionSearchEngineIntegrationTest, "
      "TransactionSearchIndexerIntegrationTest, MongoBackupServiceTest, RedisOutageTest, AdminNoSqlPageControllerTest"],
     ["Có"],
     [f"Danh sách đủ {RUN_CLASSES} lớp, số test và CSDL thật mỗi lớp dùng: mục 7.1. Test tích hợp chạy Redis, MongoDB, "
      "Elasticsearch, PostgreSQL 15 thật bằng Testcontainers."]),
    (["38_BaoCao_NoSQL.docx (Chương 1–9, Phụ lục A–D)",
      "Báo cáo hoạt động nhóm: mục 8.3 và mục 1.6 của báo cáo (cơ cấu tổ chức, bảng phân công T01..T12)"],
     ["Có"],
     ["Kết quả đạt được: mục 8.1–8.2; đối chiếu tiêu chí: mục 8.6. Slide: 38_SlideBaoCao_NoSQL.pptx ⟦chưa có, nhóm bổ sung "
      "khi dựng xong⟧"]),
    (["⟦chưa có tệp hoặc link⟧"],
     ["⟦Chưa⟧"],
     ["Kịch bản 4 phần, 5–7 phút: docs/nosql/kich_ban_demo.md (Phụ lục D). Nhóm điền link khi quay xong."]),
]

TEAM = [
    ("Phan Thanh Trí (2001230977), nhóm trưởng",
     ["Phân tích, kiến trúc và toàn bộ mã nguồn: PostgreSQL, Redis (cache, OTP, bảng xếp hạng, Pub/Sub realtime), MongoDB "
      "(log và phản hồi OCR, sao lưu), Elasticsearch (tìm kiếm, dự phòng PostgreSQL), trang quản trị.",
      "Script Q-01..Q-41, bảng mẫu truy cập, sơ đồ, đo hiệu năng, stack demo, dựng báo cáo Word (việc T01..T07, mục 1.6)."],
     ["⟦… %⟧"]),
    ("Phan Minh Tiến (2001230806)",
     ["Truy vấn MongoDB Q-01..Q-16 và minh chứng trên Compass; tìm hiểu Kibana và Elasticvue (mục 2.5); chạy lại sao lưu, "
      "khôi phục ba CSDL và truy vấn Redis, Elasticsearch; chụp ảnh minh chứng phía người dùng.",
      "Soát Chương 2, 5 và chính tả; slide; video demo; tập trả lời câu hỏi (việc T08..T12, mục 1.6).",
      "⟦Mức hoàn thành T07..T12 và ngày bắt đầu, kết thúc: nhóm cập nhật khi chốt.⟧"],
     ["⟦… %⟧"]),
]
TEAM_NOTE = ("Ghi chú: phân công chi tiết và đối chiếu lịch sử commit ở mục 1.6 và 8.3 của báo cáo. Ảnh chụp tự động bằng "
             "script không ghi công cho ai; không ghi thành viên nào viết phần mã nguồn mà người đó không viết.")

S2 = {
    0: ["LedgerMind là ứng dụng quản lý chi tiêu cá nhân (di động Flutter, backend Spring Boot, web quản trị) đã chạy "
        "với PostgreSQL trước môn học. Người dùng ghi thu chi, quét hóa đơn bằng AI (DONUT V5), xem thống kê, tìm giao dịch.",
        "Đồ án chọn hướng 1 của đề: giữ PostgreSQL làm nguồn sự thật và thêm NoSQL, mỗi loại một vai trò rõ ràng:",
        "• **Redis**: cache thống kê, OTP đặt lại mật khẩu, bảng xếp hạng chi tiêu tháng, kênh sự kiện realtime cho web quản trị.",
        "• **MongoDB**: bản sao phân tích kết quả đọc hóa đơn của AI (ocr_logs) và phản hồi khi người dùng sửa kết quả "
        "(ocr_feedbacks), để đo chất lượng AI.",
        "• **Elasticsearch** (CSDL tự tìm hiểu): tìm kiếm giao dịch tiếng Việt có hoặc không dấu.",
        "Mọi ghi sang NoSQL chạy sau khi PostgreSQL commit, bất đồng bộ (nhất quán cuối cùng). Phạm vi: mỗi CSDL một node, "
        "không replication hay sharding; hệ thống chưa triển khai lên máy chủ thật."],
    1: ["• **Người dùng** (ROLE_USER): cá nhân dùng ứng dụng di động, xác thực JWT, chỉ thấy dữ liệu của mình.",
        "• **Quản trị viên** (ROLE_ADMIN): người vận hành dùng web quản trị.",
        "• Hệ thống ngoài: ai-service (DONUT V5) đọc ảnh hóa đơn; dịch vụ email gửi mã OTP."],
    2: ["**Người dùng:** FR-01 đăng nhập, phân quyền; FR-02 quên mật khẩu bằng OTP (Redis); FR-03, FR-04 ghi, sửa, xóa "
        "giao dịch; FR-05, FR-06 quét hóa đơn bằng AI và sửa kết quả; FR-07 trang chủ thống kê đọc qua cache Redis; "
        "FR-08 tìm kiếm giao dịch (Elasticsearch, dự phòng PostgreSQL).",
        "**Quản trị viên:** FR-09 dashboard; FR-10 bảng xếp hạng chi tiêu tháng; FR-11, FR-12 duyệt phản hồi OCR và thống kê "
        "chất lượng OCR (MongoDB); FR-13 API xem log OCR thô; FR-14 vận hành chỉ mục tìm kiếm; FR-15 sao lưu, khôi phục; "
        "FR-16 thông báo realtime (Redis Pub/Sub + SSE).",
        ("img", "phan_cap_chuc_nang.png", 7.5, "Sơ đồ phân cấp chức năng (Chương 3 của báo cáo)")],
    3: ["• Backend: Java 21, Spring Boot 3.2.5; REST API, web quản trị Thymeleaf + Bootstrap 5.3, luồng sự kiện SSE.",
        "• Ứng dụng di động: Flutter (Dart). AI: FastAPI + DONUT V5 (ai-service).",
        "• Truy cập NoSQL: Spring Data Redis 3.2.5, MongoDB 4.2.5, Elasticsearch 5.2.5.",
        "• Hạ tầng: Docker Compose (PostgreSQL, Redis, MongoDB, Elasticsearch, Kibana), Caddy 2.8 làm proxy.",
        "• Kiểm thử: JUnit 5, Mockito, Testcontainers."],
    4: ["**PostgreSQL 15** (image postgres:15-alpine): nguồn sự thật của dữ liệu nghiệp vụ (users, transactions, receipts, "
        "receipt_processing_attempts, categories, budgets, notifications, danh sách thu hồi JWT, ...). Khóa bi quan cho ví, "
        "khóa lạc quan cho hóa đơn; sao lưu bằng pg_dump từ trang /admin/backup."],
    5: ["**Redis 8.10 (Key-Value):** cache thống kê, thời hạn 45–60 giây, xóa sau commit; OTP đặt lại mật khẩu, hạn 5 phút, "
        "sai tối đa 3 lần, dùng một lần; bảng xếp hạng chi tiêu tháng bằng Sorted Set, cập nhật tổng tuyệt đối bằng script Lua, "
        "giữ 62 ngày, dựng lại được từ PostgreSQL; kênh Pub/Sub ledgermind:admin-events chuyển sự kiện tới web quản trị qua SSE.",
        "**MongoDB 6.0 (Document):** hai collection ocr_logs và ocr_feedbacks; kiểm tra cấu trúc bằng $jsonSchema, 11 chỉ mục "
        "(gồm chỉ mục duy nhất receipt_field_uq và upsert $setOnInsert); CRUD và thống kê (aggregation) qua trang "
        "/admin/ocr-feedbacks; sao lưu, khôi phục từ trang /admin/backup.",
        "**Elasticsearch 8.11.4 (tự tìm hiểu):** chỉ mục giao dịch với analyzer vi_folded (chữ thường + bỏ dấu) nên gõ \"pho\" "
        "vẫn ra \"Phở\"; đồng bộ sau commit, dựng lại bằng reindex từ trang quản trị; khi chỉ mục đang dựng lại thì tìm kiếm tự "
        "rơi về PostgreSQL. Công cụ giao diện: Kibana và Elasticvue (mục 2.5 của báo cáo).",
        "Bốn loại dữ liệu: quan hệ (PostgreSQL), tài liệu bán cấu trúc (MongoDB), key-value có hạn dùng (Redis), tài liệu tìm "
        "kiếm (Elasticsearch)."],
    6: ["Mỗi sơ đồ lấy từ docs/nosql/diagrams/ (mã PlantUML kèm theo) và được giải thích ở Chương 4 của báo cáo.",
        ("img", "arch_tong_the.png", 9.0, "Kiến trúc tổng thể: ứng dụng, PostgreSQL và ba CSDL NoSQL"),
        ("img", "erd_postgres.png", 11.5, "PostgreSQL: sơ đồ thực thể – quan hệ"),
        ("img", "mongo_document.png", 8.5, "MongoDB: cấu trúc document của ocr_logs và ocr_feedbacks"),
        ("img", "redis_keys.png", 12.0, "Redis: các nhóm khóa, kiểu dữ liệu và thời hạn"),
        ("img", "es_mapping.png", 6.0, "Elasticsearch: mapping và analyzer của chỉ mục giao dịch")],
}

SECTION3_TITLE = "III. ĐỐI CHIẾU TIÊU CHÍ VÀ TỰ ĐÁNH GIÁ"
SECTION3_INTRO = ("Mỗi dòng: tiêu chí (của đề và của thang điểm) → mục trong báo cáo → minh chứng → trạng thái, lấy từ bảng "
                  "đối chiếu mục 8.6 của báo cáo (cùng nguồn với barem.py). Cột trạng thái cho biết minh chứng nằm ở đâu và "
                  "còn thiếu gì; báo cáo không tự cho điểm.")
SECTION3_NOTES = [
    "⟦Cột \"Tự chấm\" để nhóm điền. Thang điểm chính thức chỉ có cho tiêu chí 10 (4 ý × 0,5 điểm); các tiêu chí khác nhóm chấm theo thang của giảng viên.⟧",
    "⟦Còn lại trước khi nộp: link video demo, file PowerPoint, ảnh minh chứng còn giữ chỗ, ngày và tỉ lệ đóng góp trong bảng phân công, gộp feature/nosql vào main.⟧",
]

# ------------------------------------------------------------------------------------------------------------------
# XML
# ------------------------------------------------------------------------------------------------------------------


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def runs(text, sz, bold=False, italic=False):
    out = []
    for tok in re.split(r"(\*\*[^*]+\*\*|⟦[^⟧]+⟧)", text):
        if not tok:
            continue
        b, i, hl = bold, italic, ""
        if tok.startswith("⟦"):
            tok, i, hl = tok[1:-1], True, '<w:highlight w:val="yellow"/>'
        elif tok.startswith("**"):
            tok, b = tok[2:-2], True
        rpr = (f'{FONT}{"<w:b/>" if b else ""}{"<w:i/>" if i else ""}'
               f'<w:sz w:val="{sz}"/><w:szCs w:val="{sz}"/>{hl}')
        out.append(f'<w:r><w:rPr>{rpr}</w:rPr><w:t xml:space="preserve">{esc(tok)}</w:t></w:r>')
    return "".join(out)


def ppr(sz, jc="", after=40):
    j = f'<w:jc w:val="{jc}"/>' if jc else ""
    return (f'<w:pPr><w:spacing w:before="0" w:after="{after}" w:line="259" w:lineRule="auto"/>{j}'
            f'<w:rPr>{FONT}<w:sz w:val="{sz}"/><w:szCs w:val="{sz}"/></w:rPr></w:pPr>')


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


class Pkg:
    """Quản lý rels, media và id hình của gói docx đang dựng (chép từ Doc.add_image/Doc.drawing của builder_nosql.py)."""

    def __init__(self, rels, media_dir):
        self.rels = rels
        self.media_dir = media_dir
        self.next_pic = 910000

    def add_image(self, png):
        self.media_dir.mkdir(parents=True, exist_ok=True)
        name = Path(png).name
        shutil.copy(png, self.media_dir / name)
        ids = [int(i) for i in re.findall(r'Id="rId(\d+)"', self.rels)]
        rid = f"rId{max(ids) + 1}"
        self.rels = self.rels.replace(
            "</Relationships>",
            f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/'
            f'relationships/image" Target="media/{name}"/></Relationships>',
        )
        return rid

    def drawing(self, png, width_cm):
        rid = self.add_image(png)
        w, h = png_size(png)
        cx = int(width_cm * EMU_PER_CM)
        cy = int(cx * h / w)
        self.next_pic += 1
        pid = self.next_pic
        return (
            f'<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
            f'<wp:extent cx="{cx}" cy="{cy}"/><wp:effectExtent l="0" t="0" r="0" b="0"/>'
            f'<wp:docPr id="{pid}" name="Hinh {pid}"/><wp:cNvGraphicFramePr>'
            '<a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>'
            '</wp:cNvGraphicFramePr><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
            '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            f'<pic:nvPicPr><pic:cNvPr id="{pid}" name="{Path(png).name}"/><pic:cNvPicPr/></pic:nvPicPr>'
            f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
            "</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>"
        )


def paragraphs(pkg, items, sz, jc=""):
    out = []
    for it in items:
        if isinstance(it, tuple):
            _, name, width, caption = it
            png = DIAGRAMS / name
            if not png.exists():
                raise SystemExit(f"Thiếu sơ đồ {png}")
            out.append(f'<w:p><w:pPr><w:keepNext/><w:spacing w:before="80" w:after="20"/><w:jc w:val="center"/></w:pPr>'
                       f'{pkg.drawing(png, width)}</w:p>')
            out.append(f'<w:p>{ppr(sz - 4, "center", 120)}{runs(caption, sz - 4, italic=True)}</w:p>')
        else:
            hang = '<w:ind w:left="284" w:hanging="284"/>' if it.startswith(("•", "1.", "2.")) else ""
            p = ppr(sz, jc)
            if hang:
                p = p.replace("<w:jc", hang + "<w:jc", 1) if "<w:jc" in p else p.replace("<w:rPr>", hang + "<w:rPr>", 1)
            out.append(f"<w:p>{p}{runs(it, sz)}</w:p>")
    return "".join(out)


def split_cells(row):
    return re.findall(r"<w:tc>.*?</w:tc>", row, re.S)


def set_cell(pkg, tc, items, sz=24, jc=""):
    head = re.match(r"(<w:tc><w:tcPr>.*?</w:tcPr>)", tc, re.S).group(1)
    return head + paragraphs(pkg, items, sz, jc) + "</w:tc>"


def rows_of(tbl):
    return re.findall(r"<w:tr[ >].*?</w:tr>", tbl, re.S)


def replace_cells(pkg, tbl, edits, drop_cantsplit=()):
    """edits: {(行, 列): (items, sz, jc)}"""
    rows = rows_of(tbl)
    new = []
    for ri, row in enumerate(rows):
        cells = split_cells(row)
        newcells = []
        for ci, tc in enumerate(cells):
            if (ri, ci) in edits:
                items, sz, jc = edits[(ri, ci)]
                tc2 = set_cell(pkg, tc, items, sz, jc)
                row = row.replace(tc, tc2, 1)
        if ri in drop_cantsplit:
            row = row.replace("<w:cantSplit/>", "", 1)
        new.append((rows[ri], row))
    for old, nw in new:
        tbl = tbl.replace(old, nw, 1)
    return tbl


def load_barem():
    spec = importlib.util.spec_from_file_location("content_c7_c9", HERE / "content_c7_c9.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.BAREM_ROWS


def barem_table(pkg, rows, tbl_pr):
    widths = [3500, 1500, 4600, 2300, 1100]
    assert sum(widths) == 13000
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    mar = ('<w:tcMar><w:top w:w="50" w:type="dxa"/><w:left w:w="70" w:type="dxa"/><w:bottom w:w="50" w:type="dxa"/>'
           '<w:right w:w="70" w:type="dxa"/></w:tcMar>')

    def tc(w, items, fill, sz=20, bold=False, jc=""):
        shd = f'<w:shd w:val="clear" w:color="auto" w:fill="{fill}"/>'
        paras = "".join(f"<w:p>{ppr(sz, jc, 20)}{runs(t, sz, bold)}</w:p>" for t in items)
        return f'<w:tc><w:tcPr><w:tcW w:w="{w}" w:type="dxa"/>{shd}{mar}<w:vAlign w:val="center"/></w:tcPr>{paras}</w:tc>'

    head = ["Tiêu chí / yêu cầu", "Mục trong báo cáo", "Minh chứng", "Trạng thái", "Tự chấm"]
    trs = ['<w:tr><w:trPr><w:cantSplit/><w:tblHeader/><w:jc w:val="center"/></w:trPr>'
           + "".join(tc(w, [h], "D9EAF7", 22, True, "center") for w, h in zip(widths, head)) + "</w:tr>"]
    for crit, section, evidence, status in rows:
        score = "⟦…/0,5⟧" if crit.startswith("Tiêu chí 10") else "⟦điền⟧"
        trs.append('<w:tr><w:trPr><w:cantSplit/><w:jc w:val="center"/></w:trPr>'
                   + tc(widths[0], [crit], "F7F7F7") + tc(widths[1], [section], "FFFFFF")
                   + tc(widths[2], [evidence], "FFFFFF") + tc(widths[3], [status], "FFFFFF")
                   + tc(widths[4], [score], "FFFFFF", jc="center") + "</w:tr>")
    return f"<w:tbl>{tbl_pr}<w:tblGrid>{grid}</w:tblGrid>{''.join(trs)}</w:tbl>"


def main(template, output):
    nfc = lambda s: unicodedata.normalize("NFC", s)
    work = output.parent / ".fill_minhchung_tmp"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    with zipfile.ZipFile(template) as z:
        names = z.namelist()
        z.extractall(work)
    doc_path = work / "word/document.xml"
    doc = doc_path.read_text(encoding="utf8")
    rels = (work / "word/_rels/document.xml.rels").read_text(encoding="utf8")
    pkg = Pkg(rels, work / "word/media")

    tbls = re.findall(r"<w:tbl>.*?</w:tbl>", doc, re.S)
    assert len(tbls) == 4, len(tbls)
    t_info, t_del, t_team, t_s2 = tbls

    # 1. Bảng thông tin chung (cột 2 của 5 dòng)
    n_info = replace_cells(pkg, t_info, {(r, 1): (INFO[r], 26 if r < 2 else 24, "") for r in INFO})

    # 2. Bảy dòng hồ sơ (cột 3, 4, 5)
    edits = {}
    for i, (path, sent, note) in enumerate(DELIVERABLES, start=1):
        edits[(i, 2)] = (path, 22, "")
        edits[(i, 3)] = (sent, 24, "center")
        edits[(i, 4)] = (note, 22, "")
    n_del = replace_cells(pkg, t_del, edits)

    # 3. Bảng thành viên: nhóm hai người nên bỏ dòng thứ 3 để trống
    edits = {}
    for i, (name, work_items, share) in enumerate(TEAM, start=1):
        edits[(i, 1)] = ([name], 24, "")
        edits[(i, 2)] = (work_items, 22, "")
        edits[(i, 3)] = (share, 24, "center")
    n_team = replace_cells(pkg, t_team, edits)
    last = rows_of(n_team)[3]
    n_team = n_team.replace(last, "", 1)

    # 4. Phần II (cột 2 của 7 dòng); dòng dài bỏ cantSplit để Word cắt được qua trang
    n_s2 = replace_cells(pkg, t_s2, {(r, 1): (S2[r], 24, "") for r in S2}, drop_cantsplit=(0, 2, 4, 5, 6))

    # 5. Phần III: tiêu đề chép từ đoạn "II. TÓM TẮT…", bảng chép tblPr của bảng phần II
    m = re.search(r"<w:p [^>]*>(?:(?!</w:p>).)*II\. TÓM TẮT ĐỀ TÀI VÀ KIẾN TRÚC GIẢI PHÁP</w:t></w:r></w:p>", doc, re.S)
    heading = m.group(0).replace("II. TÓM TẮT ĐỀ TÀI VÀ KIẾN TRÚC GIẢI PHÁP", SECTION3_TITLE)
    heading = re.sub(r' w14:paraId="[^"]*"| w14:textId="[^"]*"', "", heading)
    tbl_pr = re.search(r"<w:tblPr>.*?</w:tblPr>", t_s2, re.S).group(0)
    rows = [[nfc(c) for c in r] for r in load_barem()]
    s3 = (
        '<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p>'
        + heading
        + f"<w:p>{ppr(24, 'both', 80)}{runs(SECTION3_INTRO, 24)}</w:p>"
        + barem_table(pkg, rows, tbl_pr)
        + '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:p>'
        + "".join(f"<w:p>{ppr(24, '', 60)}{runs(t, 24)}</w:p>" for t in SECTION3_NOTES)
    )

    team_note = f"<w:p>{ppr(22, '', 60)}{runs(TEAM_NOTE, 22, italic=True)}</w:p>"

    doc = doc.replace(t_info, n_info, 1).replace(t_del, n_del, 1)
    doc = doc.replace(t_team, n_team + team_note, 1).replace(t_s2, n_s2, 1)
    # chèn phần III ngay sau bảng phần II (trước đoạn trống cuối và sectPr)
    i = doc.find(n_s2) + len(n_s2)
    doc = doc[:i] + s3 + doc[i:]
    doc = unicodedata.normalize("NFC", doc)
    doc_path.write_text(doc, encoding="utf8")
    (work / "word/_rels/document.xml.rels").write_text(pkg.rels, encoding="utf8")

    ct_path = work / "[Content_Types].xml"
    ct = ct_path.read_text(encoding="utf8")
    if 'Extension="png"' not in ct:
        ct = ct.replace("<Default Extension=\"xml\"", '<Default Extension="png" ContentType="image/png"/><Default Extension="xml"', 1)
        ct_path.write_text(ct, encoding="utf8")

    output.parent.mkdir(parents=True, exist_ok=True)
    out_names = names + [str(p.relative_to(work)) for p in sorted((work / "word/media").glob("*"))]
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as z:
        for n in out_names:
            if n.endswith("/"):
                continue
            z.write(work / n, n)
    shutil.rmtree(work)
    print("đã ghi", output)


if __name__ == "__main__":
    tpl = Path(sys.argv[1]) if len(sys.argv) > 1 else TEMPLATE
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else OUTPUT
    main(tpl, out)
