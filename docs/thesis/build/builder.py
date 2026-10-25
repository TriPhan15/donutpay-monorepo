"""Thay các dòng giữ chỗ [T7.x] trong document.xml bằng nội dung sinh từ content module.

Cách dùng: python3 builder.py <unpacked_dir> <content_module.py>
Content module định nghĩa SECTIONS: dict {tiêu đề mục ngay trước dòng giữ chỗ: [block, ...]}
và tùy chọn ABBREVIATIONS: list[(viết tắt, tiếng Anh, tiếng Việt)].
Block: ("p", text) | ("b1", text) | ("b2", text) | ("h4", text) | ("y", text)
       ("table", caption, chapter, widths, header, rows, source)
       ("fig", caption, chapter, png_or_None, width_cm, source, placeholder_note)
Inline: **đậm**, *nghiêng*.
"""
import html
import importlib.util
import re
import shutil
import struct
import sys
from pathlib import Path

EMU_PER_CM = 360000


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

    def add_image(self, png):
        media = self.root / "word/media"
        name = Path(png).name
        shutil.copy(png, media / name)
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
        if kind == "h4":
            return para("Heading4", block[1])
        if kind == "y":
            return para("noidung", block[1], base_rpr='<w:i/><w:highlight w:val="yellow"/>')
        if kind == "table":
            _, caption, chapter, widths, header, rows, source = block
            n = self.number("Bảng", chapter)
            out = seq_caption("ChuThichBang", "Bảng", chapter, n, caption) + table(widths, header, rows)
            return out + (source_line(source) if source else "")
        if kind == "fig":
            _, caption, chapter, png, width_cm, source, note = block
            n = self.number("Hình", chapter)
            if png:
                body = f'<w:p><w:pPr><w:pStyle w:val="Hinh"/></w:pPr>{self.drawing(png, width_cm)}</w:p>'
            else:
                body = para("Hinh", note, base_rpr='<w:i/><w:highlight w:val="yellow"/>')
            cap = caption + (f" ({source})" if source else "")
            return body + seq_caption("Caption", "Hình", chapter, n, cap)
        raise ValueError(kind)


def text_of(p):
    return "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", p))


def main(root, content_path):
    spec = importlib.util.spec_from_file_location("content", content_path)
    content = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(content)
    doc = Doc(root)
    xml_path = Path(root) / "word/document.xml"
    xml = xml_path.read_text(encoding="utf8")

    # Duyệt đoạn theo thứ tự, nhớ tiêu đề gần nhất; thay đoạn giữ chỗ của phiên này.
    tag = content.SESSION_TAG
    used = set()
    out, pos, last_heading = [], 0, None
    for m in re.finditer(r"<w:p[ >].*?</w:p>|<w:tbl>.*?</w:tbl>", xml, flags=re.S):
        p = m.group(0)
        out.append(xml[pos:m.start()])
        pos = m.end()
        style = re.search(r'<w:pStyle w:val="([^"]+)"', p)
        style = style.group(1) if style else ""
        txt = text_of(p)
        if style in ("Heading1", "Heading2", "Heading3", "Heading4", "TieuDeKhongSo", "TieuDeMuc"):
            last_heading = txt
        if p.startswith("<w:p") and txt.startswith(f"[{tag}]"):
            key = last_heading
            if key not in content.SECTIONS:
                raise SystemExit(f"Chưa có nội dung cho mục: {key!r}")
            used.add(key)
            out.append("".join(doc.render(b) for b in content.SECTIONS[key]))
        else:
            out.append(p)
    out.append(xml[pos:])
    xml = "".join(out)
    missing = set(content.SECTIONS) - used
    if missing:
        raise SystemExit(f"Mục có nội dung nhưng không tìm thấy dòng giữ chỗ: {missing}")

    for abbr in getattr(content, "ABBREVIATIONS", []):
        xml = add_abbreviation(xml, *abbr)

    xml_path.write_text(xml, encoding="utf8")
    doc.rels_path.write_text(doc.rels, encoding="utf8")
    print("sections:", len(used), "counters:", doc.counters)


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
