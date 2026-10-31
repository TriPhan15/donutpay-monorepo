"""K7 (v16 -> v17): xếp lại danh mục tài liệu tham khảo (tiếng Việt trước) và đánh số lại trích dẫn [n] trong thân bài.

Quy trình (chạy trên thư mục đã giải nén của v16, rồi đóng gói thành v17):

    python -X utf8 -I renumber_citations_v17.py renumber       <dir>   # 1. thay mọi [n] cũ bằng số mới, một lượt duy nhất
    python -X utf8 -I renumber_citations_v17.py fix-abbr       <dir>   # 2. sửa vài ô của bảng chữ viết tắt (xem ABBR_CELL_FIXES)
    python -X utf8 builder.py <dir> content_v17_tai_lieu.py            # 3. chèn danh mục, thêm dòng viết tắt, xóa dòng nhắc
    python -X utf8 -I renumber_citations_v17.py format-refs    <dir>   # 4. thụt dòng treo cho các mục của danh mục
    python -X utf8 -I renumber_citations_v17.py check          <dir>   # 5. kiểm tra hai chiều và bảng viết tắt

Bước 1 phải chạy TRƯỚC bước 3: danh mục mới đã mang số mới, chạy lại sau sẽ ánh xạ lần hai.

Quy tắc xếp: tài liệu tiếng Việt trước (VIETNAMESE_OLD, giữ thứ tự cũ), rồi tài liệu nước ngoài (thứ tự cũ tăng dần).
Mục không được trích trong thân bài (UNCITED_OLD) bị bỏ khỏi danh mục. Trong một nhóm "[a], [b], [c]" các số được
xếp tăng dần theo số mới. Mô-đun này cũng được content_v17_tai_lieu.py nạp để lấy thứ tự danh mục.
"""
import html
import re
import sys
from pathlib import Path

ALL_OLD = list(range(1, 89))
# Tài liệu viết bằng tiếng Việt (tên tài liệu bằng tiếng Việt): văn bản pháp luật, tạp chí trong nước,
# hai ứng dụng có tên tiếng Việt trên Google Play và trang hướng dẫn webhook của Casso.
VIETNAMESE_OLD = [1, 2, 3, 4, 43, 44, 72]
# Có trong references.md nhưng thân bài không trích: không đưa vào danh mục.
UNCITED_OLD = [16, 25, 26, 27]

KEPT_OLD = [n for n in ALL_OLD if n not in UNCITED_OLD]
ORDER_OLD = VIETNAMESE_OLD + [n for n in KEPT_OLD if n not in VIETNAMESE_OLD]
MAP = {old: new for new, old in enumerate(ORDER_OLD, start=1)}
INVERSE = {new: old for old, new in MAP.items()}

P_RE = re.compile(r"<w:p[ >](?:(?!<w:p[ >]).)*?</w:p>", re.S)
T_RE = re.compile(r"(<w:t(?: [^>]*)?>)([^<]*)(</w:t>)")
GROUP_RE = re.compile(r"\[\d+\](?:, \[\d+\])*")
TOKEN_RE = re.compile(r"\[(\d+)\]")
RANGE_RE = re.compile(r"\[\d+\]\s*[-–—]\s*\[\d+\]")

# Ô của bảng chữ viết tắt cần sửa: (viết tắt, cột 1 = Tiếng Anh | 2 = Tiếng Việt, chữ cũ, chữ mới).
ABBR_CELL_FIXES = [
    ("CMAP", 2, "Bản đồ đồng xuất hiện của các item", "Bản đồ đồng xuất hiện của các phần tử"),
    ("BCE", 1, "Boundary – Control – Entity", "Boundary, Control, Entity"),
    ("BCE", 2, "Mô hình ba lớp biên – điều khiển – thực thể", "Mô hình ba lớp: biên, điều khiển, thực thể"),
    ("RFM", 1, "Recency – Frequency – Monetary", "Recency, Frequency, Monetary"),
    ("SROIE", 2, "Cuộc thi OCR và trích xuất thông tin hóa đơn scan", "Cuộc thi OCR và trích xuất thông tin hóa đơn quét"),
    ("UQ", 1, "Unique", "Unique constraint"),
]


def text_of_paragraph(p):
    return html.unescape("".join(m.group(2) for m in T_RE.finditer(p)))


def parse_references(md_path):
    """{số cũ: dòng đầu của mục, bỏ nhãn [n]} từ references.md (chỉ phần trước '## Đã loại')."""
    text = Path(md_path).read_text(encoding="utf8")
    text = text.split("## Đã loại")[0]
    entries = {}
    for line in text.splitlines():
        m = re.match(r"^\[(\d+)\] (.+)$", line)
        if m:
            entries[int(m.group(1))] = m.group(2).strip()
    assert sorted(entries) == ALL_OLD, "references.md phải có đúng mục 1..88"
    return entries


def cited_numbers(xml):
    """Tập số cũ được trích trong document.xml (mọi [n] trong w:t, theo từng đoạn)."""
    found = set()
    for pm in P_RE.finditer(xml):
        s = "".join(m.group(2) for m in T_RE.finditer(pm.group(0)))
        found.update(int(x) for x in TOKEN_RE.findall(s))
    return found


def rewrite_paragraph(p, mapping):
    """Thay các [n] trong một đoạn theo mapping; trả về (đoạn mới, số token đã đổi)."""
    ts = list(T_RE.finditer(p))
    s = "".join(m.group(2) for m in ts)
    if RANGE_RE.search(s):
        raise SystemExit(f"Có khoảng trích dẫn [a]-[b] trong đoạn: {s[:80]!r}. Viết liệt kê tay rồi chạy lại.")
    edits = []  # (bắt đầu, kết thúc, chữ mới) của phần chữ số, theo chỉ số trong s
    count = 0
    for g in GROUP_RE.finditer(s):
        toks = list(TOKEN_RE.finditer(g.group(0)))
        olds = [int(t.group(1)) for t in toks]
        missing = [o for o in olds if o not in mapping]
        if missing:
            raise SystemExit(f"Trích dẫn tới mục đã bỏ khỏi danh mục: {missing} trong {s[:80]!r}")
        news = sorted(mapping[o] for o in olds)
        for t, new in zip(toks, news):
            edits.append((g.start() + t.start(1), g.start() + t.end(1), str(new)))
            count += 1
    if not edits:
        return p, 0
    chars = list(s)
    for a, b, new in edits:
        chars[a] = new
        for i in range(a + 1, b):
            chars[i] = ""
    out, pos, off = [], 0, 0
    for m in ts:
        n = len(m.group(2))
        out.append(p[pos:m.start()])
        out.append(m.group(1) + "".join(chars[off:off + n]) + m.group(3))
        pos, off = m.end(), off + n
    out.append(p[pos:])
    return "".join(out), count


def renumber(xml):
    cited = cited_numbers(xml)
    assert cited == set(KEPT_OLD), (
        f"Số được trích khác KEPT_OLD: thừa {sorted(cited - set(KEPT_OLD))}, thiếu {sorted(set(KEPT_OLD) - cited)}")
    total = 0

    def one(m):
        nonlocal total
        new, n = rewrite_paragraph(m.group(0), MAP)
        total += n
        return new

    xml = P_RE.sub(one, xml)  # một lượt duy nhất: số mới không bao giờ bị ánh xạ lần hai
    print("citation tokens renumbered:", total)
    print("map (old -> new):")
    for old in ORDER_OLD:
        print(f"  [{old}] -> [{MAP[old]}]" + ("   (tiếng Việt)" if old in VIETNAMESE_OLD else ""))
    print("dropped (not cited):", ", ".join(f"[{o}]" for o in UNCITED_OLD))
    return xml


def fix_abbr(xml):
    a = xml.index("DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT")
    t0 = xml.index("<w:tbl>", a)
    t1 = xml.index("</w:tbl>", t0)
    tbl = xml[t0:t1]
    for short, col, old, new in ABBR_CELL_FIXES:
        rows = [m for m in re.finditer(r"<w:tr[ >].*?</w:tr>", tbl, re.S)]
        hit = None
        for r in rows:
            cells = re.findall(r"<w:tc>.*?</w:tc>", r.group(0), re.S)
            if cells and text_of_paragraph(cells[0]) == short:
                hit = (r, cells[col])
        assert hit, f"không thấy dòng {short}"
        r, cell = hit
        assert text_of_paragraph(cell) == old, (short, text_of_paragraph(cell))
        new_cell = cell.replace(html.escape(old, quote=False), html.escape(new, quote=False), 1)
        assert new_cell != cell
        tbl = tbl[:r.start()] + r.group(0).replace(cell, new_cell, 1) + tbl[r.end():]
        print(f"abbr {short}: {old!r} -> {new!r}")
    return xml[:t0] + tbl + xml[t1:]


def reference_paragraphs(xml):
    """Các đoạn (match) nằm giữa tiêu đề TÀI LIỆU THAM KHẢO và PHỤ LỤC."""
    paras = list(P_RE.finditer(xml))
    texts = [text_of_paragraph(m.group(0)) for m in paras]
    start = max(i for i, t in enumerate(texts) if t == "TÀI LIỆU THAM KHẢO")
    end = next(i for i in range(start + 1, len(paras)) if texts[i] == "PHỤ LỤC")
    return paras, texts, start, end


def format_refs(xml):
    paras, texts, start, end = reference_paragraphs(xml)
    out, pos, n = [], 0, 0
    old_ppr = '<w:pPr><w:pStyle w:val="noidung"/></w:pPr>'
    new_ppr = '<w:pPr><w:pStyle w:val="noidung"/><w:ind w:left="680" w:hanging="680"/><w:jc w:val="left"/></w:pPr>'
    for i in range(start + 1, end):
        if re.match(r"\[\d+\] ", texts[i]):
            p = paras[i].group(0)
            assert p.count(old_ppr) == 1, p[:120]
            out.append(xml[pos:paras[i].start()])
            out.append(p.replace(old_ppr, new_ppr, 1))
            pos = paras[i].end()
            n += 1
    out.append(xml[pos:])
    print("reference paragraphs formatted:", n)
    return "".join(out)


def check(xml, refs_md):
    entries = parse_references(refs_md)
    paras, texts, start, end = reference_paragraphs(xml)
    listed = {}
    for i in range(start + 1, end):
        m = re.match(r"\[(\d+)\] (.*)$", texts[i])
        assert m, f"đoạn trong danh mục không bắt đầu bằng [n]: {texts[i][:60]!r}"
        n = int(m.group(1))
        assert n not in listed, f"trùng số [{n}] trong danh mục"
        listed[n] = m.group(2)
    ok = True
    n_list = len(listed)
    if sorted(listed) != list(range(1, n_list + 1)):
        print("FAIL: số trong danh mục không liên tục 1..N"); ok = False
    # nội dung từng mục khớp đúng references.md (mục cũ tương ứng)
    for new, text in listed.items():
        want = entries[INVERSE[new]]
        if text != want:
            print(f"FAIL: mục [{new}] khác references.md [{INVERSE[new]}]"); ok = False
    # Việt trước, nước ngoài sau
    if [INVERSE[n] for n in range(1, len(VIETNAMESE_OLD) + 1)] != VIETNAMESE_OLD:
        print("FAIL: nhóm tiếng Việt không đứng đầu"); ok = False
    # trích dẫn trong thân bài (mọi đoạn ngoài danh mục)
    cited = set()
    for i, m in enumerate(paras):
        if start < i < end:
            continue
        s = "".join(t.group(2) for t in T_RE.finditer(m.group(0)))
        cited.update(int(x) for x in TOKEN_RE.findall(s))
    missing = sorted(cited - set(listed))
    unused = sorted(set(listed) - cited)
    print(f"danh mục: {n_list} mục; số được trích: {len(cited)}")
    print("trích dẫn không có trong danh mục:", missing or "không")
    print("mục trong danh mục không được trích:", unused or "không")
    if missing or unused:
        ok = False
    # bảng viết tắt: xếp A-Z, không trùng
    a = xml.index("DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT")
    t0 = xml.index("<w:tbl>", a)
    tbl = xml[t0:xml.index("</w:tbl>", t0)]
    keys = []
    for r in re.findall(r"<w:tr[ >].*?</w:tr>", tbl, re.S)[1:]:
        keys.append(text_of_paragraph(re.findall(r"<w:tc>.*?</w:tc>", r, re.S)[0]))
    if keys != sorted(keys, key=str.casefold):
        print("FAIL: bảng viết tắt chưa xếp A-Z"); ok = False
    if len(set(keys)) != len(keys):
        print("FAIL: bảng viết tắt có dòng trùng"); ok = False
    print("bảng viết tắt:", len(keys), "dòng, xếp A-Z:", keys == sorted(keys, key=str.casefold))
    if re.search(r"Danh mục khởi tạo|Từ docs/thesis/references\.md", xml):
        print("FAIL: còn dòng nhắc"); ok = False
    print("KẾT QUẢ:", "OK" if ok else "LỖI")
    return ok


def main(argv):
    cmd, root = argv[1], Path(argv[2])
    path = root / "word/document.xml"
    xml = path.read_text(encoding="utf8")
    if cmd == "renumber":
        path.write_text(renumber(xml), encoding="utf8")
    elif cmd == "fix-abbr":
        path.write_text(fix_abbr(xml), encoding="utf8")
    elif cmd == "format-refs":
        path.write_text(format_refs(xml), encoding="utf8")
    elif cmd == "check":
        refs = Path(argv[3]) if len(argv) > 3 else Path(__file__).resolve().parents[1] / "references.md"
        sys.exit(0 if check(xml, refs) else 1)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
