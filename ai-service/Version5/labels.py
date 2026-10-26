"""Hàm dùng chung cho nhãn Donut V5: đọc/ghi jsonl, chuẩn hóa và so sánh giá trị trường."""

import json
import os
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageOps

FIELDS: tuple[str, ...] = ("SELLER", "ADDRESS", "TIMESTAMP", "TOTAL_COST")
SPLITS: tuple[str, ...] = ("train", "validation", "test")
MONEY_FIELD = "TOTAL_COST"
LONG_RATIO = 2.2

EXIF_ORIENTATION_TAG = 0x0112
# Orientation 5-8 nghĩa là ảnh bị xoay 90/270 độ: chiều cao và chiều rộng đổi chỗ
EXIF_SWAPPED_ORIENTATIONS = {5, 6, 7, 8}

_MONEY_TOKEN = re.compile(r"\d[\d.,]*")
_CENTS_SUFFIX = re.compile(r"[.,]\d{2}$")


class LabelError(ValueError):
    """Dòng metadata.jsonl không đọc được."""


@dataclass
class Record:
    file_name: str
    fields: dict[str, str]
    unverified: list[str] = field(default_factory=list)


def _parse_line(line: str) -> Record:
    row = json.loads(line)
    gt = json.loads(row["ground_truth"])
    parsed = gt.get("gt_parse", gt)
    if not isinstance(parsed, dict):
        raise ValueError("gt_parse không phải object")
    upper = {str(k).upper(): v for k, v in parsed.items()}
    fields = {f: str(upper.get(f) or "").strip() for f in FIELDS}
    unverified = [f for f in row.get("unverified_fields", []) if f in FIELDS]
    return Record(file_name=str(row["file_name"]), fields=fields, unverified=unverified)


def load_metadata(path: Path) -> list[Record]:
    records: list[Record] = []
    with open(path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            if not line.strip():
                continue
            try:
                records.append(_parse_line(line))
            except (ValueError, KeyError, TypeError) as exc:
                raise LabelError(f"{path}:{line_no}: {exc}") from exc
    return records


def dump_metadata(records: list[Record], path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        for rec in records:
            row: dict = {
                "file_name": rec.file_name,
                "ground_truth": json.dumps({"gt_parse": {k: rec.fields[k] for k in FIELDS}}, ensure_ascii=False),
            }
            if rec.unverified:
                row["unverified_fields"] = list(rec.unverified)
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    # os.replace tạo inode mới, nên không bao giờ ghi xuyên qua hard link sang file gốc
    os.replace(tmp, path)


def normalize_text(s: str) -> str:
    return " ".join(unicodedata.normalize("NFC", str(s)).lower().split())


def money_value(s: str) -> int | None:
    values: list[int] = []
    for token in _MONEY_TOKEN.findall(str(s)):
        token = _CENTS_SUFFIX.sub("", token)
        digits = re.sub(r"[.,]", "", token)
        if digits:
            values.append(int(digits))
    return max(values) if values else None


def fields_match(field_name: str, a: str, b: str) -> bool:
    if field_name == MONEY_FIELD:
        va, vb = money_value(a), money_value(b)
        if va is not None or vb is not None:
            return va == vb
    return normalize_text(a) == normalize_text(b)


def read_image(path: Path) -> Image.Image:
    with Image.open(path) as img:
        return ImageOps.exif_transpose(img).convert("RGB")


def image_hw(path: Path) -> tuple[int, int]:
    with Image.open(path) as img:
        width, height = img.size
        if img.getexif().get(EXIF_ORIENTATION_TAG) in EXIF_SWAPPED_ORIENTATIONS:
            width, height = height, width
    return height, width


def is_long(path: Path) -> bool:
    height, width = image_hw(path)
    return height / width > LONG_RATIO
