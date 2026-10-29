"""Ảnh giữ chỗ cho các khung ảnh chụp màn hình S-xx của báo cáo NoSQL.

Cách dùng:
  python3 make_placeholder_png.py S-01 S-02 ... [--out DIR]
  python3 make_placeholder_png.py --all [--out DIR]      (mọi S-xx trong bảng S của docs/nosql/facts.md)
Mặc định ghi vào docs/nosql/screenshots/S-xx.png; KHÔNG ghi đè một ảnh đã có mà không phải ảnh giữ chỗ (ảnh thật).

Ảnh 1600x900, nền xám, chữ "S-xx – chưa chụp" và mô tả ngắn lấy từ facts.md (nếu có). PNG mang khóa tEXt
"ledgermind-placeholder" = S-xx: check_report.py đọc khóa này để liệt kê các ảnh còn chưa chụp trong một bản .docx.
"""
import argparse
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from PIL.PngImagePlugin import PngInfo

HERE = Path(__file__).resolve().parent
KEY = "ledgermind-placeholder"
SIZE = (1600, 900)
BG, FG, BORDER = (217, 217, 217), (64, 64, 64), (150, 150, 150)
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def s_rows(facts):
    """{S-xx: mô tả} từ các dòng bảng '| S-xx | ... |' của facts.md (cột thứ 3 là nội dung ảnh)."""
    rows = {}
    for line in facts.read_text(encoding="utf8").splitlines():
        m = re.match(r"^\|\s*(S-\d{2,3})\s*\|([^|]*)\|([^|]*)\|", line)
        if m:
            rows[m.group(1)] = m.group(3).strip() or m.group(2).strip()
    return rows


def is_placeholder(path):
    try:
        with Image.open(path) as im:
            return im.info.get(KEY) is not None
    except OSError:
        return False


def wrap(draw, text, font, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=font) <= width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines[:4]


def make(sid, desc, out):
    im = Image.new("RGB", SIZE, BG)
    d = ImageDraw.Draw(im)
    d.rectangle([20, 20, SIZE[0] - 21, SIZE[1] - 21], outline=BORDER, width=6)
    big = ImageFont.truetype(FONT_BOLD, 96)
    small = ImageFont.truetype(FONT, 40)
    title = f"{sid} – chưa chụp"
    tw = d.textlength(title, font=big)
    d.text(((SIZE[0] - tw) / 2, 300), title, font=big, fill=FG)
    y = 460
    for line in wrap(d, desc, small, SIZE[0] - 200):
        lw = d.textlength(line, font=small)
        d.text(((SIZE[0] - lw) / 2, y), line, font=small, fill=FG)
        y += 56
    meta = PngInfo()
    meta.add_text(KEY, sid)
    im.save(out, pnginfo=meta)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--out", default=str(HERE.parent / "screenshots"))
    ap.add_argument("--facts", default=str(HERE.parent / "facts.md"))
    args = ap.parse_args()
    facts = Path(args.facts)
    rows = s_rows(facts) if facts.exists() else {}
    ids = sorted(rows) if args.all else args.ids
    if not ids:
        sys.exit("Không có S-xx nào (truyền mã hoặc --all)")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    made = kept = 0
    for sid in ids:
        if not re.match(r"^S-\d{2,3}$", sid):
            sys.exit(f"Mã không hợp lệ: {sid}")
        path = out / f"{sid}.png"
        if path.exists() and not is_placeholder(path):
            kept += 1
            continue
        make(sid, rows.get(sid, ""), path)
        made += 1
    print(f"placeholder: {made} tạo/ghi lại, {kept} ảnh thật giữ nguyên, thư mục {out}")


if __name__ == "__main__":
    main()
