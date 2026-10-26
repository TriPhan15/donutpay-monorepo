"""Ghi kết quả Claude đọc ảnh vào nhãn Version5; trường đọc chắc được coi như đã duyệt."""

import argparse
import csv
import json
import sys
from copy import deepcopy
from pathlib import Path
from typing import Literal

from pydantic import BaseModel

from labels import FIELDS, Record, dump_metadata, fields_match, load_metadata
from merge_labels import CACHE_DIR, read_settled, review_paths
from relabel_common import ReceiptFields

FieldName = Literal["SELLER", "ADDRESS", "TIMESTAMP", "TOTAL_COST"]
REPORT_KEYS = ("filled", "changed", "same", "confirmed_empty", "unsure", "kept_existing_over_empty", "user_answer")


class ClaudeReading(BaseModel):
    file_name: str
    fields: ReceiptFields
    unsure: list[FieldName] = []
    note: str = ""


def load_readings(cache_dir: Path, split: str) -> dict[str, ClaudeReading]:
    readings: dict[str, ClaudeReading] = {}
    for part in sorted(Path(cache_dir).glob(f"{split}.claude*.jsonl")):
        for line in part.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            if "fields" in row:
                readings[row["file_name"]] = ClaudeReading.model_validate(row)
    return readings


def apply_readings(
    records: list[Record],
    readings: dict[str, ClaudeReading],
    settled: dict[tuple[str, str], str],
) -> tuple[list[Record], list[tuple[str, str, str]], dict[str, int], list[tuple[str, str, str, str]]]:
    report = {k: 0 for k in REPORT_KEYS}
    new_settled: list[tuple[str, str, str]] = []
    changes: list[tuple[str, str, str, str]] = []
    out: list[Record] = []
    for rec in records:
        new = Record(rec.file_name, deepcopy(rec.fields), list(rec.unverified))
        reading = readings.get(rec.file_name)
        for f in FIELDS if reading else ():
            old, value = rec.fields[f], reading.fields.as_dict()[f]
            if (rec.file_name, f) in settled:
                report["user_answer"] += 1  # câu trả lời người dùng đã duyệt luôn thắng
                continue
            if f in reading.unsure:
                report["unsure"] += 1
                if not old and f not in new.unverified:
                    new.unverified.append(f)
                continue
            if not value and old:
                # Claude không thấy trường này nhưng người dùng đã điền: giữ nhãn cũ, không xóa
                report["kept_existing_over_empty"] += 1
                continue
            if old and fields_match(f, old, value):
                value, key = old, "same"
            elif not old:
                key = "filled" if value else "confirmed_empty"
            else:
                key = "changed"
                changes.append((rec.file_name, f, old, value))
            report[key] += 1
            new.fields[f] = value
            if f in new.unverified:
                new.unverified.remove(f)
            new_settled.append((rec.file_name, f, value))
        out.append(new)
    return out, new_settled, report, changes


def main(argv: list[str] | None = None) -> int:
    from paths import LABEL_ROOT, WORK_DIR

    parser = argparse.ArgumentParser(description="Ghi nhãn Claude đã đọc vào Version5/data1")
    parser.add_argument("--split", required=True, choices=["test", "validation", "train"])
    args = parser.parse_args(argv)

    label_path = LABEL_ROOT / args.split / "metadata.jsonl"
    _, done_path = review_paths(args.split)
    readings = load_readings(CACHE_DIR, args.split)
    new, settled_rows, report, changes = apply_readings(load_metadata(label_path), readings, read_settled(done_path))
    dump_metadata(new, label_path)
    done_path.parent.mkdir(parents=True, exist_ok=True)
    with open(done_path, "a", encoding="utf-8") as done:
        for file_name, field, value in settled_rows:
            done.write(json.dumps({"file_name": file_name, "field": field, "value": value, "by": "claude"},
                                  ensure_ascii=False) + "\n")
    changes_path = WORK_DIR / "relabel" / f"{args.split}.claude_changes.csv"
    with open(changes_path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["file_name", "field", "old", "claude"])
        writer.writerows(changes)
    print(f"{args.split}: {len(readings)} ảnh Claude đã đọc -> {report}")
    print(f"Các nhãn bị sửa khác nhãn cũ: {changes_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
