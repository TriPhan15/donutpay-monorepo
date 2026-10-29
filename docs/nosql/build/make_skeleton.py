"""Dựng bộ khung v0 của báo cáo NoSQL từ khóa luận v9 + bìa SRS tuần 6 + outline.md.

Cách dùng: python3 make_skeleton.py <thesis_v9.docx> <srs.docx> <outline.md> <out.docx>

- Giữ của khóa luận: styles.xml (thêm style MaNguon), numbering.xml, theme, settings, footer số trang, ba trường TOC
  ("Mục lục", "Danh mục hình", "Danh mục bảng") và tiêu đề "DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT" với bảng rút còn dòng
  tiêu đề + một dòng dữ liệu (builder.add_abbreviation cần rows[1]). Bỏ toàn bộ phần còn lại của thân khóa luận
  (hai trang bìa, lời cảm ơn, nhận xét, phân công, mở đầu, 5 chương, kết luận, tài liệu, phụ lục) và ảnh không còn dùng.
- Ghép bìa SRS: các đoạn trước section break đầu tiên của SRS, giữ định dạng trực tiếp; logo (media + rel) và danh sách
  số (abstractNum + num) được chép sang; spacing after=200 của Normal bên SRS được ghi thẳng vào đoạn; bỏ bookmark _Hlk và
  header của section bìa. Sau đó đặt tên đề tài và dòng ngày tháng.
- Thêm các chương/mục của outline.md, mỗi tiêu đề có một dòng giữ chỗ vàng "[T7.cN_x] mô tả". Kiểm tra tiêu đề duy nhất.
"""
import re
import shutil
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from html import escape
from pathlib import Path

TITLE = ("ỨNG DỤNG CƠ SỞ DỮ LIỆU MONGODB VÀ BỘ NHỚ ĐỆM REDIS TRONG VIỆC XÂY DỰNG HỆ THỐNG QUẢN LÝ TÀI CHÍNH "
         "CÁ NHÂN")
DATE_LINE = "Thành phố Hồ Chí Minh tháng 11 năm 2026"
DOC_TITLE_FULL = ("Ứng dụng cơ sở dữ liệu MongoDB và bộ nhớ đệm Redis trong việc xây dựng hệ thống quản lý tài chính cá nhân")
DOC_SUBJECT = "Báo cáo môn Dữ liệu NoSQL – Nhóm 38"
AUTHOR = "Nhóm 38"
ABBR_HEADING = "DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT"
ABBR_KEEP_ROW = "CSDL"
FRONT_KEEP = ["MỤC LỤC", ABBR_HEADING, "DANH MỤC HÌNH", "DANH MỤC BẢNG"]
MANGUON_STYLE = (
    '<w:style w:type="paragraph" w:customStyle="1" w:styleId="MaNguon"><w:name w:val="Ma nguon"/>'
    '<w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepLines/>'
    '<w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>'
    '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:ind w:left="0" w:firstLine="0"/>'
    '<w:jc w:val="left"/></w:pPr><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:eastAsia="Consolas" '
    'w:cs="Consolas"/><w:noProof/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:style>')
HEADING_STYLE = {1: "Heading1", 2: "Heading2", 3: "Heading3", 4: "Heading4"}
REL_IMAGE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"


def text_of(x):
    return "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", x))


def top_level(body):
    """Phần tử con cấp một của <w:body>: [(tag, xml)]."""
    tok = re.compile(r"<(/?)(w:p|w:tbl|w:sdt|w:sectPr|w:bookmarkStart|w:bookmarkEnd)([ >/])")
    items, pos, depth, start, tag = [], 0, 0, 0, None
    while True:
        m = tok.search(body, pos)
        if not m:
            break
        closing, name = m.group(1), m.group(2)
        gt = body.index(">", m.start())
        selfclose = body[gt - 1] == "/"
        if depth == 0 and not closing:
            start, tag = m.start(), name
            if selfclose or name in ("w:bookmarkStart", "w:bookmarkEnd"):
                items.append((tag, body[start:gt + 1]))
                pos = gt + 1
                continue
            depth, pos = 1, gt + 1
            continue
        if name == tag:
            if closing:
                depth -= 1
                if depth == 0:
                    items.append((tag, body[start:gt + 1]))
                    pos = gt + 1
                    continue
            elif not selfclose:
                depth += 1
        pos = gt + 1
    rest = re.sub(r"\s+", "", body[pos:])
    assert not rest, f"còn nội dung không phân tích được: {rest[:80]}"
    return items


def split_document(xml):
    a = xml.index("<w:body>") + len("<w:body>")
    b = xml.rindex("</w:body>")
    return xml[:a], top_level(xml[a:b]), xml[b:]


def para(style, text, rpr=""):
    rp = f"<w:rPr>{rpr}</w:rPr>" if rpr else ""
    return (f'<w:p><w:pPr><w:pStyle w:val="{style}"/></w:pPr>'
            f'<w:r>{rp}<w:t xml:space="preserve">{escape(text, quote=False)}</w:t></w:r></w:p>')


def parse_outline(path):
    text = Path(path).read_text(encoding="utf8")
    text = text[text.index("\n---\n") + 5:]
    entries = []
    for line in text.splitlines():
        m = re.match(r"^(#{1,4})\s+(.*?)\s*\{(c\d+_\w+)\}\s*$", line)
        if m:
            heading = re.sub(r"^\d+(?:\.\d+)*\.?\s+", "", m.group(2)).strip()
            entries.append({"level": len(m.group(1)), "text": heading, "ph": m.group(3), "note": []})
        elif line.startswith(">") and entries:
            entries[-1]["note"].append(line[1:].strip())
        elif line.startswith("#"):
            raise SystemExit(f"Dòng tiêu đề thiếu mã {{cN_x}}: {line!r}")
    texts = [e["text"] for e in entries]
    dup = {t for t in texts if texts.count(t) > 1}
    if dup:
        raise SystemExit(f"Tiêu đề trùng: {dup}")
    phs = [e["ph"] for e in entries]
    if len(set(phs)) != len(phs):
        raise SystemExit("Mã giữ chỗ trùng")
    for e in entries:
        if not re.match(r"c(\d+)_", e["ph"]):
            raise SystemExit(f"Mã giữ chỗ sai dạng: {e['ph']}")
    return entries


def outline_xml(entries):
    out, chapter = [], 0
    for e in entries:
        if e["level"] == 1:
            chapter += 1
        if int(re.match(r"c(\d+)_", e["ph"]).group(1)) != chapter:
            raise SystemExit(f"{e['ph']} nằm ở chương {chapter}")
        out.append(para(HEADING_STYLE[e["level"]], e["text"]))
        note = " ".join(e["note"]) or "Nội dung mục này."
        out.append(para("noidung", f"[T7.{e['ph']}] {note}", '<w:i/><w:highlight w:val="yellow"/>'))
    return "".join(out)


def reduce_abbreviation_table(tbl):
    rows = re.findall(r"<w:tr[ >].*?</w:tr>", tbl, flags=re.S)
    keep = [r for r in rows[1:] if text_of(re.findall(r"<w:tc>.*?</w:tc>", r, flags=re.S)[0]) == ABBR_KEEP_ROW]
    if not keep:
        raise SystemExit(f"Bảng viết tắt không có dòng {ABBR_KEEP_ROW}")
    first = tbl.index(rows[0])
    end = tbl.rindex("</w:tbl>")
    return tbl[:first] + rows[0] + keep[0] + tbl[end:]


def transplant_cover(srs_dir, out_dir, rels):
    """Các đoạn bìa SRS (đến section break đầu tiên) đã sửa để sống được trong document của khóa luận."""
    sxml = (srs_dir / "word/document.xml").read_text(encoding="utf8")
    _, items, _ = split_document(sxml)
    cover = []
    for tag, x in items:
        cover.append(x)
        if "<w:sectPr" in x:
            break
    else:
        raise SystemExit("SRS không có section break sau bìa")
    xml = "".join(cover)
    # Bookmark _Hlk của SRS, thuộc tính rsid/paraId, và header của section bìa: bỏ.
    xml = re.sub(r"<w:bookmark(Start|End)[^>]*/>", "", xml)
    xml = re.sub(r' (w:rsid\w*|w14:paraId|w14:textId|wp14:anchorId|wp14:editId)="[^"]*"', "", xml)
    xml = re.sub(r"<w:headerReference[^>]*/>|<w:footerReference[^>]*/>", "", xml)
    xml = re.sub(r' w:themeColor="[^"]*"', "", xml)
    # Normal của SRS có spacing after=200 (docDefaults); ghi thẳng vào đoạn để bìa giữ đúng khoảng cách.
    xml = re.sub(r"<w:spacing (?![^>]*w:after=)", '<w:spacing w:after="200" ', xml)
    # Logo: chép ảnh và thêm rel mới.
    srels = (srs_dir / "word/_rels/document.xml.rels").read_text(encoding="utf8")
    for rid in sorted(set(re.findall(r'r:embed="(rId\d+)"', xml))):
        target = re.search(rf'Id="{rid}"[^>]*Target="([^"]+)"', srels) or re.search(rf'Target="([^"]+)"[^>]*Id="{rid}"', srels)
        src = srs_dir / "word" / target.group(1)
        name = "srs_cover_" + src.name
        shutil.copy(src, out_dir / "word/media" / name)
        ids = [int(i) for i in re.findall(r'Id="rId(\d+)"', rels)]
        new = f"rId{max(ids) + 1}"
        rels = rels.replace("</Relationships>",
                            f'<Relationship Id="{new}" Type="{REL_IMAGE}" Target="media/{name}"/></Relationships>')
        xml = xml.replace(f'r:embed="{rid}"', f'r:embed="{new}"')
    if re.search(r'r:(id|link)="', xml):
        raise SystemExit("Bìa SRS còn rel chưa xử lý")
    # Tên đề tài và ngày tháng.
    paras = re.findall(r"<w:p[ >].*?</w:p>", xml, flags=re.S)
    title_p = [p for p in paras if text_of(p).startswith("ĐỀ TÀI:")]
    date_p = [p for p in paras if text_of(p).startswith("Thành phố Hồ Chí Minh")]
    if len(title_p) != 1 or len(date_p) != 1:
        raise SystemExit("Không tìm thấy đúng một dòng ĐỀ TÀI và một dòng ngày tháng trên bìa SRS")
    runs = re.findall(r"<w:t[^>]*>[^<]*</w:t>", title_p[0])
    new_title = title_p[0].replace(runs[-1], f"<w:t>{escape(TITLE, quote=False)}</w:t>", 1)
    if len(runs) > 2:
        for r in runs[1:-1]:
            new_title = new_title.replace(r, "<w:t></w:t>", 1)
    xml = xml.replace(title_p[0], new_title)
    druns = re.findall(r"<w:t[^>]*>[^<]*</w:t>", date_p[0])
    new_date = date_p[0].replace(druns[0], f"<w:t>{DATE_LINE}</w:t>", 1)
    for r in druns[1:]:
        new_date = new_date.replace(r, "<w:t></w:t>", 1)
    xml = xml.replace(date_p[0], new_date)
    return xml, rels


def transplant_numbering(srs_dir, out_dir, cover_xml):
    """Chép mỗi danh sách số mà bìa dùng (num → abstractNum) sang numbering.xml của khóa luận với id mới."""
    snum = (srs_dir / "word/numbering.xml").read_text(encoding="utf8")
    npath = out_dir / "word/numbering.xml"
    num = npath.read_text(encoding="utf8")
    for old_id in sorted(set(re.findall(r'<w:numId w:val="(\d+)"/>', cover_xml))):
        nm = re.search(rf'<w:num w:numId="{old_id}"[^>]*>.*?</w:num>', snum, re.S).group(0)
        abs_id = re.search(r'<w:abstractNumId w:val="(\d+)"', nm).group(1)
        ab = re.search(rf'<w:abstractNum [^>]*w:abstractNumId="{abs_id}".*?</w:abstractNum>', snum, re.S).group(0)
        new_abs = max(int(i) for i in re.findall(r'w:abstractNumId="(\d+)"', num)) + 1
        new_num = max(int(i) for i in re.findall(r'<w:num w:numId="(\d+)"', num)) + 1
        ab = re.sub(r' (w15|w16cid|w:rsid)\w*:?\w*="[^"]*"', "", ab)
        ab = re.sub(r'w:abstractNumId="\d+"', f'w:abstractNumId="{new_abs}"', ab, count=1)
        ab = re.sub(r'<w:nsid w:val="[0-9A-F]+"/>', f'<w:nsid w:val="{0x5C0A1E00 + new_abs:08X}"/>', ab)
        new = f'<w:num w:numId="{new_num}"><w:abstractNumId w:val="{new_abs}"/></w:num>'
        first_num = num.index("<w:num ")
        num = num[:first_num] + ab + num[first_num:]
        num = num.replace("</w:numbering>", new + "</w:numbering>")
        cover_xml = cover_xml.replace(f'<w:numId w:val="{old_id}"/>', f'<w:numId w:val="{new_num}"/>')
    npath.write_text(num, encoding="utf8")
    return cover_xml


def main(thesis, srs, outline, out):
    work = Path(tempfile.mkdtemp(prefix="nosql_skel_"))
    tdir, sdir = work / "thesis", work / "srs"
    zipfile.ZipFile(thesis).extractall(tdir)
    zipfile.ZipFile(srs).extractall(sdir)

    doc_path = tdir / "word/document.xml"
    head, items, tail = split_document(doc_path.read_text(encoding="utf8"))

    # Phần đầu của khóa luận: giữ 4 mục danh mục + đoạn mang section break của phần đầu (số trang La Mã).
    sect_idx = [i for i, (t, x) in enumerate(items) if "<w:sectPr" in x and t == "w:p"]
    cover_end, front_end = sect_idx[0], sect_idx[1]
    front, keep_on = [], False
    for tag, x in items[cover_end + 1:front_end]:
        txt = text_of(x)
        if 'w:val="TieuDeKhongSo"' in x:
            keep_on = txt in FRONT_KEEP
            if keep_on:
                front.append(x)
            continue
        if not keep_on:
            continue
        if tag == "w:tbl" and front and ABBR_HEADING in text_of(front[-1]):
            front.append(reduce_abbreviation_table(x))
        elif tag == "w:p" and re.match(r"\[T7\.", txt):
            continue  # ghi chú giữ chỗ cũ của khóa luận
        else:
            front.append(x)
    kept_titles = [text_of(x) for x in front if 'w:val="TieuDeKhongSo"' in x]
    if kept_titles != FRONT_KEEP:
        raise SystemExit(f"Phần đầu giữ được {kept_titles}, cần {FRONT_KEEP}")
    front.append(items[front_end][1])
    final_sect = items[-1][1]
    if items[-1][0] != "w:sectPr":
        raise SystemExit("document.xml của khóa luận không kết thúc bằng sectPr")

    rels_path = tdir / "word/_rels/document.xml.rels"
    rels = rels_path.read_text(encoding="utf8")
    cover, rels = transplant_cover(sdir, tdir, rels)
    cover = transplant_numbering(sdir, tdir, cover)

    entries = parse_outline(outline)
    body = cover + "".join(front) + outline_xml(entries) + final_sect
    xml = head + body + tail

    # Bỏ ảnh không còn dùng (và rel của chúng).
    used = set(re.findall(r'r:embed="(rId\d+)"', xml))
    def keep_rel(m):
        r = m.group(0)
        if REL_IMAGE in r and re.search(r'Id="(rId\d+)"', r).group(1) not in used:
            target = re.search(r'Target="media/([^"]+)"', r).group(1)
            (tdir / "word/media" / target).unlink(missing_ok=True)
            return ""
        return r
    rels = re.sub(r"<Relationship [^>]*/>", keep_rel, rels)
    for r in re.findall(r'r:(?:id|embed)="(rId\d+)"', xml):
        if f'Id="{r}"' not in rels:
            raise SystemExit(f"rel {r} bị mất")
    rels_path.write_text(rels, encoding="utf8")
    doc_path.write_text(xml, encoding="utf8")

    # Style MaNguon.
    spath = tdir / "word/styles.xml"
    styles = spath.read_text(encoding="utf8")
    if 'w:styleId="MaNguon"' not in styles:
        styles = styles.replace("</w:styles>", MANGUON_STYLE + "</w:styles>")
    spath.write_text(styles, encoding="utf8")

    # Thuộc tính tài liệu: viết lại toàn bộ, không giữ tác giả/ngày/số lần sửa của khóa luận.
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    (tdir / "docProps/core.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        f"<dc:title>{escape(DOC_TITLE_FULL)}</dc:title><dc:subject>{escape(DOC_SUBJECT)}</dc:subject>"
        f"<dc:creator>{AUTHOR}</dc:creator><cp:keywords></cp:keywords><dc:description></dc:description>"
        f"<cp:lastModifiedBy>{AUTHOR}</cp:lastModifiedBy><cp:revision>1</cp:revision>"
        f'<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>'
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified></cp:coreProperties>',
        encoding="utf8")
    apath = tdir / "docProps/app.xml"
    app = apath.read_text(encoding="utf8")
    app = re.sub(r"<Company>.*?</Company>|<Company/>", "<Company></Company>", app)
    app = re.sub(r"<Manager>.*?</Manager>", "", app)
    app = re.sub(r"<TotalTime>\d+</TotalTime>", "<TotalTime>0</TotalTime>", app)
    apath.write_text(app, encoding="utf8")

    # Đóng gói: [Content_Types].xml đầu tiên.
    out = Path(out)
    files = sorted(p for p in tdir.rglob("*") if p.is_file())
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        ct = tdir / "[Content_Types].xml"
        z.write(ct, "[Content_Types].xml")
        for p in files:
            if p != ct:
                z.write(p, p.relative_to(tdir).as_posix())
    shutil.rmtree(work)
    print(f"skeleton: {out} – {len(entries)} tiêu đề, "
          f"{sum(1 for e in entries if e['level'] == 1)} chương, {len(used)} ảnh")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
