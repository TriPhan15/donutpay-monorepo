"""Bản sao NoSQL của docs/thesis/build/builder.py (báo cáo môn Dữ liệu NoSQL, nhóm 38).

Thêm so với builder.py của khóa luận:
  ("code", text): mỗi dòng của text thành một đoạn style MaNguon (Consolas 10, nền xám nhạt; make_skeleton.py thêm
      style này vào styles.xml), giữ nguyên khoảng trắng đầu dòng, tab đổi thành 4 dấu cách, không đọc **đậm**/*nghiêng*.
  ("sid", "S-xx", caption, chapter, width_cm[, key]): một hình ảnh chụp màn hình S-xx; ảnh lấy từ
      SCREENSHOT_DIR/S-xx.png (mặc định docs/nosql/screenshots, đổi bằng biến môi trường NOSQL_SCREENSHOT_DIR hoặc
      SCREENSHOT_DIR trong content module). Ảnh giữ chỗ do make_placeholder_png.py tạo; ảnh thật thay sau bằng
      IMAGE_REPLACE [("S-xx.png", đường dẫn, "fit")], chú thích và số hình giữ nguyên.
  add_image từ chối chép đè một ảnh khác cùng tên trong word/media.
Mọi content module của báo cáo NoSQL khai báo SESSION_TAG = None, SECTIONS = {}, RENUMBER = True và đưa nội dung vào
bằng HEADING_PLACEHOLDERS (dòng giữ chỗ [T7.cN_x] ngay sau tiêu đề).

--- Tài liệu gốc của builder.py ---
Thay các dòng giữ chỗ [T7.x] trong document.xml bằng nội dung sinh từ content module.

Cách dùng: python3 builder_nosql.py <unpacked_dir> <content_module.py>
Content module định nghĩa SECTIONS: dict {tiêu đề mục ngay trước dòng giữ chỗ: [block, ...]}
và tùy chọn ABBREVIATIONS: list[(viết tắt, tiếng Anh, tiếng Việt)].
Block: ("p", text) | ("b1", text) | ("b2", text) | ("h4", text) | ("y", text)
       ("table", caption, chapter, widths, header, rows, source)
       ("fig", caption, chapter, png_or_None, width_cm, source, placeholder_note)
Inline: **đậm**, *nghiêng*.
Tùy chọn (từ T7.2b): COUNTER_START {("Hình"|"Bảng", chương): số đã dùng} để đánh số tiếp;
REPLACE {tiêu đề Heading3: (counter_start, [block, ...])} viết lại toàn bộ thân một mục đã có nội dung;
PARA_REPLACE [(đầu đoạn cũ, block)] thay một đoạn đã có.
Tùy chọn (từ phiên T10/T11, chèn vào giữa quyển):
  SESSION_TAG = None nếu phiên không thay dòng giữ chỗ nào theo tag;
  block ("h2", text) | ("h3", text); fig/table có thể thêm phần tử cuối là khóa (key) để văn bản tham chiếu
  bằng [[key]] ("Hình c.n") hoặc [[#key]] ("c.n");
  INSERT_BEFORE / INSERT_AFTER [(đầu đoạn hoặc chữ của bảng, [block, ...])] chèn cạnh đúng một phần tử;
  HEADING_PLACEHOLDERS {tiêu đề: [block, ...]} thay dòng giữ chỗ [T7.x] ngay sau tiêu đề đó (mọi tag);
  PARA_LINES_AFTER [(đầu đoạn, [dòng, ...])] chèn đoạn cùng style ngay sau một đoạn (kể cả đoạn trong ô bảng);
  TABLE_ROWS [(đầu chú thích bảng, chữ của dòng đứng trước hoặc None = cuối bảng, [[ô, ...], ...])];
  TEXT_REPLACE [(chuỗi cũ, chuỗi mới, số lần)] thay trong từng <w:t>;
  RENUMBER = True: đánh số lại mọi chú thích Hình/Bảng theo thứ tự trong quyển, cập nhật mọi tham chiếu
  "Hình c.n"/"Bảng c.n" trong văn bản theo số mới và thay [[key]].
Tùy chọn (từ phiên v9):
  PARA_DELETE [đầu đoạn, ...] xóa đúng một đoạn (ví dụ ghi chú tô vàng đã hết hiệu lực);
  IMAGE_REPLACE [(tên tệp trong word/media, đường dẫn PNG mới[, "fit"])] thay ảnh, giữ chiều rộng đang đặt và tính lại
  chiều cao; với "fit", ảnh mới được thu lại để không cao hơn ảnh cũ và không quá MAX_FIT_CM.
"""
import filecmp
import html
import importlib.util
import os
import re
import shutil
import struct
import sys
from pathlib import Path

EMU_PER_CM = 360000
CODE_STYLE = "MaNguon"
TAB_AS_SPACES = "    "
DEFAULT_SCREENSHOT_DIR = Path(__file__).resolve().parents[1] / "screenshots"
SID_RE = re.compile(r"^S-\d{2,3}$")
MAX_FIT_CM = 21  # chiều cao tối đa của hình "fit": vùng chữ 24,7 cm trừ chỗ cho chú thích


def esc(s):
    return html.escape(s, quote=False)


def runs(text, base_rpr=""):
    out = []
    for tok in re.split(r"(\*\*[^*]+\*\*|\*[^*]+\*)", text):
        if not tok:
            continue
        rpr = base_rpr
        if tok.startswith("**"):
            tok, rpr = tok[2:-2], rpr + "<w:b/>"
        elif tok.startswith("*"):
            tok, rpr = tok[1:-1], rpr + "<w:i/>"
        rp = f"<w:rPr>{rpr}</w:rPr>" if rpr else ""
        out.append(f'<w:r>{rp}<w:t xml:space="preserve">{esc(tok)}</w:t></w:r>')
    return "".join(out)


def para(style, text, extra_ppr="", base_rpr=""):
    return f'<w:p><w:pPr><w:pStyle w:val="{style}"/>{extra_ppr}</w:pPr>{runs(text, base_rpr)}</w:p>'


def seq_caption(style, label, chapter, number, title):
    fld = (
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
        f'<w:r><w:instrText xml:space="preserve"> SEQ {label} \\* ARABIC \\s 1 </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        f'<w:r><w:t>{number}</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
    )
    return (
        f'<w:p><w:pPr><w:pStyle w:val="{style}"/></w:pPr>'
        f'<w:r><w:t xml:space="preserve">{label} {chapter}.</w:t></w:r>{fld}'
        f'<w:r><w:t xml:space="preserve">: {esc(title)}</w:t></w:r></w:p>'
    )


def source_line(text):
    return para("Caption", text, base_rpr="<w:i/>")


def cell(width, text, header=False):
    shd = '<w:shd w:val="clear" w:color="auto" w:fill="D9D9D9"/>' if header else ""
    jc = '<w:jc w:val="center"/>' if header else ""
    paras = "".join(
        f'<w:p><w:pPr><w:pStyle w:val="NoiDungBang"/>{jc}</w:pPr>'
        f'{runs(line, "<w:b/>" if header else "")}</w:p>'
        for line in text.split("\n")
    )
    return (
        f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/>{shd}<w:vAlign w:val="center"/></w:tcPr>'
        f"{paras}</w:tc>"
    )


def table(widths, header, rows):
    assert sum(widths) == 8504, sum(widths)
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    trs = [
        '<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>'
        + "".join(cell(w, h, True) for w, h in zip(widths, header))
        + "</w:tr>"
    ]
    for r in rows:
        assert len(r) == len(widths), r
        trs.append(
            '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
            + "".join(cell(w, c) for w, c in zip(widths, r))
            + "</w:tr>"
        )
    return (
        '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="8504" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" '
        'w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>'
        f"<w:tblGrid>{grid}</w:tblGrid>{''.join(trs)}</w:tbl>"
    )


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


class Doc:
    def __init__(self, root):
        self.root = Path(root)
        self.rels_path = self.root / "word/_rels/document.xml.rels"
        self.rels = self.rels_path.read_text(encoding="utf8")
        self.counters = {}
        self.next_pic = 900000
        self.screenshot_dir = Path(os.environ.get("NOSQL_SCREENSHOT_DIR", DEFAULT_SCREENSHOT_DIR))

    def add_image(self, png):
        media = self.root / "word/media"
        media.mkdir(parents=True, exist_ok=True)
        name = Path(png).name
        target = media / name
        if target.exists() and not filecmp.cmp(png, target, shallow=False):
            raise SystemExit(f"word/media/{name} đã có và khác {png}: đổi tên ảnh, hoặc dùng IMAGE_REPLACE")
        shutil.copy(png, target)
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

    def number(self, label, chapter):
        key = (label, chapter)
        self.counters[key] = self.counters.get(key, 0) + 1
        return self.counters[key]

    def render(self, block):
        kind = block[0]
        if kind == "p":
            return para("noidung", block[1])
        if kind == "b1":
            return para("GachDau1", block[1])
        if kind == "b2":
            return para("GachDau2", block[1])
        if kind in ("h2", "h3", "h4"):
            return para("Heading" + kind[1], block[1])
        if kind == "y":
            return para("noidung", block[1], base_rpr='<w:i/><w:highlight w:val="yellow"/>')
        if kind == "table":
            _, caption, chapter, widths, header, rows, source = block[:7]
            n = f"@{block[7]}@" if len(block) > 7 else self.number("Bảng", chapter)
            out = seq_caption("ChuThichBang", "Bảng", chapter, n, caption) + table(widths, header, rows)
            return out + (source_line(source) if source else "")
        if kind == "fig":
            _, caption, chapter, png, width_cm, source, note = block[:7]
            n = f"@{block[7]}@" if len(block) > 7 else self.number("Hình", chapter)
            if png:
                body = f'<w:p><w:pPr><w:pStyle w:val="Hinh"/></w:pPr>{self.drawing(png, width_cm)}</w:p>'
            else:
                body = para("Hinh", note, base_rpr='<w:i/><w:highlight w:val="yellow"/>')
            cap = caption + (f" ({source})" if source else "")
            return body + seq_caption("Caption", "Hình", chapter, n, cap)
        if kind == "code":
            return code_block(block[1])
        if kind == "sid":
            _, sid, caption, chapter, width_cm = block[:5]
            if not SID_RE.match(sid):
                raise SystemExit(f"Mã ảnh chụp không hợp lệ: {sid!r} (cần S-xx)")
            png = self.screenshot_dir / f"{sid}.png"
            if not png.exists():
                raise SystemExit(f"Chưa có {png}: chạy make_placeholder_png.py {sid} trước")
            fig = ("fig", caption, chapter, str(png), width_cm, None, None) + tuple(block[5:6])
            return self.render(fig)
        raise ValueError(kind)


def code_block(text):
    """Mỗi dòng một đoạn MaNguon; khoảng trắng giữ nguyên (xml:space="preserve"), không xử lý **/* như văn bản."""
    lines = text.expandtabs(len(TAB_AS_SPACES)).rstrip("\n").split("\n")
    out = []
    for line in lines:
        run = f'<w:r><w:t xml:space="preserve">{esc(line)}</w:t></w:r>' if line else ""
        out.append(f'<w:p><w:pPr><w:pStyle w:val="{CODE_STYLE}"/></w:pPr>{run}</w:p>')
    return "".join(out)


def text_of(p):
    return "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", p))


def main(root, content_path):
    spec = importlib.util.spec_from_file_location("content", content_path)
    content = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(content)
    if content.SESSION_TAG is not None or content.SECTIONS or getattr(content, "RENUMBER", False) is not True:
        raise SystemExit("Content module NoSQL phải khai báo SESSION_TAG = None, SECTIONS = {}, RENUMBER = True")
    doc = Doc(root)
    if hasattr(content, "SCREENSHOT_DIR"):
        doc.screenshot_dir = Path(content.SCREENSHOT_DIR)
    xml_path = Path(root) / "word/document.xml"
    xml = xml_path.read_text(encoding="utf8")

    # Duyệt đoạn theo thứ tự, nhớ tiêu đề gần nhất; thay đoạn giữ chỗ của phiên này.
    tag = content.SESSION_TAG
    used = set()
    doc.counters.update(getattr(content, "COUNTER_START", {}))
    replace = getattr(content, "REPLACE", {})
    para_replace = list(getattr(content, "PARA_REPLACE", []))
    replaced, para_done, skipping = set(), set(), False
    insert_before = list(getattr(content, "INSERT_BEFORE", []))
    insert_after = list(getattr(content, "INSERT_AFTER", []))
    heading_ph = dict(getattr(content, "HEADING_PLACEHOLDERS", {}))
    hits_before, hits_after, ph_done = [0] * len(insert_before), [0] * len(insert_after), set()
    para_delete = list(getattr(content, "PARA_DELETE", []))
    hits_delete = [0] * len(para_delete)
    pending_after = ""
    out, pos, last_heading = [], 0, None
    for m in re.finditer(r"<w:p[ >].*?</w:p>|<w:tbl>.*?</w:tbl>", xml, flags=re.S):
        p = m.group(0)
        if pending_after:
            out.append(pending_after)
            pending_after = ""
        out.append(xml[pos:m.start()])
        pos = m.end()
        style = re.search(r'<w:pStyle w:val="([^"]+)"', p)
        style = style.group(1) if style else ""
        txt = text_of(p)
        if style in ("Heading1", "Heading2", "Heading3", "Heading4", "TieuDeKhongSo", "TieuDeMuc"):
            last_heading = txt
        if style in ("Heading1", "Heading2", "Heading3"):
            skipping = False
        if skipping:
            continue
        hit_del = next((i for i, prefix in enumerate(para_delete) if p.startswith("<w:p") and txt.startswith(prefix)), None)
        if hit_del is not None:
            hits_delete[hit_del] += 1
            continue
        for i, (prefix, blocks) in enumerate(insert_before):
            if txt.startswith(prefix):
                hits_before[i] += 1
                out.append("".join(doc.render(b) for b in blocks))
        for i, (prefix, blocks) in enumerate(insert_after):
            if txt.startswith(prefix):
                hits_after[i] += 1
                pending_after += "".join(doc.render(b) for b in blocks)
        if p.startswith("<w:p") and re.match(r"\[T7\.\w+\]", txt) and last_heading in heading_ph \
                and last_heading not in ph_done:
            out.append("".join(doc.render(b) for b in heading_ph[last_heading]))
            ph_done.add(last_heading)
            continue
        if style == "Heading3" and txt in replace:
            start, blocks = replace[txt]
            saved = dict(doc.counters)
            doc.counters.update(start)
            out.append(p + "".join(doc.render(b) for b in blocks))
            doc.counters = saved
            replaced.add(txt)
            skipping = True
            continue
        hit = next((i for i, (prefix, _) in enumerate(para_replace) if p.startswith("<w:p") and txt.startswith(prefix)), None)
        if hit is not None:
            out.append(doc.render(para_replace[hit][1]))
            para_done.add(hit)
            continue
        if tag and p.startswith("<w:p") and txt.startswith(f"[{tag}]"):
            key = last_heading
            if key not in content.SECTIONS:
                raise SystemExit(f"Chưa có nội dung cho mục: {key!r}")
            used.add(key)
            out.append("".join(doc.render(b) for b in content.SECTIONS[key]))
        else:
            out.append(p)
    out.append(pending_after)
    out.append(xml[pos:])
    xml = "".join(out)
    missing = set(content.SECTIONS) - used
    if missing:
        raise SystemExit(f"Mục có nội dung nhưng không tìm thấy dòng giữ chỗ: {missing}")
    if set(replace) - replaced or len(para_done) != len(para_replace):
        raise SystemExit(f"Không tìm thấy mục/đoạn cần thay: {set(replace) - replaced}, đoạn {len(para_done)}/{len(para_replace)}")

    bad = [x for x, n in zip(insert_before, hits_before) if n != 1] + [x for x, n in zip(insert_after, hits_after) if n != 1]
    if bad or set(heading_ph) - ph_done:
        raise SystemExit(f"Điểm chèn không khớp đúng một lần: {[b[0] for b in bad]}, {set(heading_ph) - ph_done}")
    bad_del = [x for x, n in zip(para_delete, hits_delete) if n != 1]
    if bad_del:
        raise SystemExit(f"PARA_DELETE không khớp đúng một đoạn: {bad_del}")
    for anchor, lines in getattr(content, "PARA_LINES_AFTER", []):
        xml = para_lines_after(xml, anchor, lines)
    for caption, after_row, rows in getattr(content, "TABLE_ROWS", []):
        xml = table_rows(xml, caption, after_row, rows)
    for old, new, count in getattr(content, "TEXT_REPLACE", []):
        xml = text_replace(xml, old, new, count)
    if getattr(content, "RENUMBER", False):
        xml = renumber(xml)

    for abbr in getattr(content, "ABBREVIATIONS", []):
        xml = add_abbreviation(xml, *abbr)
    for media_name, png, *opt in getattr(content, "IMAGE_REPLACE", []):
        xml = image_replace(doc, xml, media_name, png, "fit" in opt)

    xml_path.write_text(xml, encoding="utf8")
    doc.rels_path.write_text(doc.rels, encoding="utf8")
    print("sections:", len(used), "counters:", doc.counters)


P_RE = re.compile(r"<w:p[ >](?:(?!<w:p[ >]).)*?</w:p>", re.S)


def para_lines_after(xml, anchor, lines):
    found = [m for m in P_RE.finditer(xml) if text_of(m.group(0)).startswith(anchor)]
    if len(found) != 1:
        raise SystemExit(f"PARA_LINES_AFTER: {anchor!r} khớp {len(found)} đoạn")
    m = found[0]
    ppr = re.search(r"<w:pPr>.*?</w:pPr>", m.group(0), re.S)
    ppr = ppr.group(0) if ppr else ""
    new = "".join(f"<w:p>{ppr}{runs(line)}</w:p>" for line in lines)
    return xml[:m.end()] + new + xml[m.end():]


def table_rows(xml, caption, after_row, rows):
    caps = [m for m in P_RE.finditer(xml) if "ChuThichBang" in m.group(0) and caption in text_of(m.group(0))]
    if len(caps) != 1:
        raise SystemExit(f"TABLE_ROWS: chú thích {caption!r} khớp {len(caps)} lần")
    t0 = xml.index("<w:tbl>", caps[0].end())
    t1 = xml.index("</w:tbl>", t0)
    tbl = xml[t0:t1]
    widths = [int(w) for w in re.findall(r'<w:gridCol w:w="(\d+)"/>', tbl)]
    new = "".join('<w:tr><w:trPr><w:cantSplit/></w:trPr>' + "".join(cell(w, c) for w, c in zip(widths, r)) + "</w:tr>"
                  for r in rows)
    if after_row is None:
        tbl = tbl + new
    else:
        trs = [m for m in re.finditer(r"<w:tr[ >].*?</w:tr>", tbl, re.S) if after_row in text_of(m.group(0))]
        if len(trs) != 1:
            raise SystemExit(f"TABLE_ROWS: dòng {after_row!r} khớp {len(trs)} lần")
        tbl = tbl[:trs[0].end()] + new + tbl[trs[0].end():]
    return xml[:t0] + tbl + xml[t1:]


def text_replace(xml, old, new, count):
    e_old, e_new = esc(old), esc(new)
    n = xml.count(e_old)
    if n != count:
        raise SystemExit(f"TEXT_REPLACE: {old!r} xuất hiện {n} lần, cần {count}")
    return xml.replace(e_old, e_new)


CAP_RE = re.compile(r'(<w:p><w:pPr><w:pStyle w:val="(?:Caption|ChuThichBang)"/></w:pPr>'
                    r'<w:r><w:t xml:space="preserve">(Hình|Bảng) (\d+)\.</w:t></w:r>'
                    r'(?:(?!</w:p>).)*?<w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>)([^<]+)(</w:t>)', re.S)
REF_RE = re.compile(r"(Hình|Bảng|hình|bảng) (\d+)\.(\d+)((?: đến | và | tới )(?:(?:Hình|Bảng|hình|bảng) )?)?(\d+\.\d+)?")


def renumber(xml):
    """Đánh số lại chú thích theo thứ tự xuất hiện; ánh xạ số cũ sang số mới cho mọi tham chiếu trong văn bản."""
    counters, old_new, keys = {}, {}, {}

    def cap(m):
        label, ch, num = m.group(2), m.group(3), m.group(4)
        counters[(label, ch)] = counters.get((label, ch), 0) + 1
        n = counters[(label, ch)]
        if num.startswith("@"):
            keys[num.strip("@")] = (label, ch, n)
        else:
            old_new[(label, ch, int(num))] = n
        return m.group(1) + str(n) + m.group(5)

    xml = CAP_RE.sub(cap, xml)
    caption_spans = [(m.start(), m.end()) for m in P_RE.finditer(xml)
                     if re.search(r'<w:pStyle w:val="(?:Caption|ChuThichBang)"/>', m.group(0)[:120])]

    def map_ref(label, ch, n):
        key = ("Hình" if label.lower() == "hình" else "Bảng", ch, int(n))
        return old_new.get(key, int(n))

    def ref(m):
        label, ch, n, sep, second = m.groups()
        out = f"{label} {ch}.{map_ref(label, ch, n)}"
        if sep:
            out += sep
            if second:
                l2 = re.search(r"(Hình|Bảng|hình|bảng) $", sep)
                c2, n2 = second.split(".")
                out += f"{c2}.{map_ref(l2.group(1) if l2 else label, c2, n2)}"
        return out

    def fix_text(t):
        t = REF_RE.sub(ref, t)
        t = re.sub(r"\[\[(#?)([\w-]+)\]\]",
                   lambda m: (f"{keys[m.group(2)][1]}.{keys[m.group(2)][2]}" if m.group(1)
                              else f"{keys[m.group(2)][0]} {keys[m.group(2)][1]}.{keys[m.group(2)][2]}"), t)
        return t

    out, pos = [], 0
    for m in re.finditer(r"(<w:t(?: [^>]*)?>)([^<]*)(</w:t>)", xml):
        if any(a <= m.start() < b for a, b in caption_spans):
            continue
        out.append(xml[pos:m.start()])
        out.append(m.group(1) + fix_text(m.group(2)) + m.group(3))
        pos = m.end()
    out.append(xml[pos:])
    xml = "".join(out)
    if "[[" in re.sub(r"<[^>]+>", "", xml):
        raise SystemExit("Còn tham chiếu [[key]] chưa giải được")
    print("renumber:", {k: v for k, v in counters.items()}, "keys:", keys)
    return xml


def image_replace(doc, xml, media_name, png, fit=False):
    """Chép PNG mới đè lên word/media/<media_name>; mỗi hình dùng ảnh đó giữ cx, cy tính lại theo tỉ lệ ảnh mới."""
    rid = re.search(r'Id="(rId\d+)"[^>]*Target="media/' + re.escape(media_name) + '"', doc.rels)
    if not rid:
        raise SystemExit(f"IMAGE_REPLACE: không có ảnh media/{media_name}")
    rid = rid.group(1)
    shutil.copy(png, doc.root / "word/media" / media_name)
    w, h = png_size(png)
    count = 0

    def fix(m):
        nonlocal count
        d = m.group(0)
        if f'r:embed="{rid}"' not in d:
            return d
        count += 1
        old = re.search(r'<wp:extent cx="(\d+)" cy="(\d+)"', d)
        cx, old_cy = int(old.group(1)), int(old.group(2))
        cy = int(cx * h / w)
        limit = min(old_cy, MAX_FIT_CM * EMU_PER_CM)
        if fit and cy > limit:
            cx, cy = int(limit * w / h), limit
        size = lambda x: f'{x.group(1)}cx="{cx}" cy="{cy}"'
        d = re.sub(r'(<wp:extent )cx="\d+" cy="\d+"', size, d)
        return re.sub(r'(<a:ext )cx="\d+" cy="\d+"', size, d)

    xml = re.sub(r"<w:drawing>.*?</w:drawing>", fix, xml, flags=re.S)
    if count != 1:
        raise SystemExit(f"IMAGE_REPLACE: media/{media_name} được dùng {count} lần, cần 1")
    print("image replaced:", media_name, f"{w}x{h}")
    return xml


def add_abbreviation(xml, short, en, vi):
    """Chèn một dòng vào bảng viết tắt theo thứ tự chữ cái (bỏ qua nếu đã có)."""
    a = xml.index("DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT")
    t0 = xml.index("<w:tbl>", a)
    t1 = xml.index("</w:tbl>", t0)
    tbl = xml[t0:t1]
    rows = re.findall(r"<w:tr>.*?</w:tr>|<w:tr .*?</w:tr>", tbl, flags=re.S)
    keys = [text_of(re.findall(r"<w:tc>.*?</w:tc>", r, flags=re.S)[0]) for r in rows]
    if short in keys:
        return xml
    template = rows[1]
    cells = re.findall(r"<w:tc>.*?</w:tc>", template, flags=re.S)
    new_cells = []
    for c, val in zip(cells, (short, en, vi)):
        new_cells.append(re.sub(r"(<w:t[^>]*>)[^<]*(</w:t>)", lambda m: m.group(1) + esc(val) + m.group(2), c, count=1))
    new_row = template
    for c, nc in zip(cells, new_cells):
        new_row = new_row.replace(c, nc, 1)
    insert_before = None
    for r, k in zip(rows[1:], keys[1:]):
        if k.casefold() > short.casefold():
            insert_before = r
            break
    if insert_before is None:
        tbl = tbl + new_row
    else:
        i = tbl.index(insert_before)
        tbl = tbl[:i] + new_row + tbl[i:]
    return xml[:t0] + tbl + xml[t1:]


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
