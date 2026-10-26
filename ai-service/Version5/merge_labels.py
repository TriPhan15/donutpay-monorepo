"""Gộp nhãn cũ với câu trả lời của Gemini và Qwen theo luật từng trường; ghi metadata mới + review.csv."""

import argparse
import csv
import json
import sys
from copy import deepcopy
from dataclasses import astuple, dataclass, fields as dc_fields
from pathlib import Path
from typing import Literal

from labels import FIELDS, Record, dump_metadata, fields_match, load_metadata
from paths import LABEL_ROOT, WORK_DIR
from relabel_common import ReceiptFields, load_cache

Status = Literal["kept", "agree", "review", "unchecked"]
STATUSES: tuple[Status, ...] = ("kept", "agree", "review", "unchecked")
UNSETTLED: tuple[Status, ...] = ("review", "unchecked")
CACHE_DIR = WORK_DIR / "relabel_cache"
REVIEW_DIR = WORK_DIR / "relabel"


@dataclass(frozen=True)
class Decision:
    value: str
    status: Status


@dataclass(frozen=True)
class ReviewRow:
    file_name: str
    field: str
    old: str
    gemini: str
    qwen: str


def decide_field(field: str, old: str, gemini: str | None, qwen: str | None) -> Decision:
    if gemini is None and qwen is None:
        return Decision(old, "unchecked")
    if old and gemini is not None and fields_match(field, old, gemini):
        return Decision(old, "kept")
    if gemini is not None and qwen is not None and fields_match(field, gemini, qwen):
        return Decision(gemini, "agree")
    if gemini is None and old and qwen is not None and fields_match(field, old, qwen):
        return Decision(old, "kept")
    return Decision(old, "review")


def _answer(cache: dict[str, ReceiptFields], file_name: str, field: str) -> str | None:
    hit = cache.get(file_name)
    return None if hit is None else hit.as_dict()[field]


def merge_split(
    records: list[Record],
    gemini: dict[str, ReceiptFields],
    qwen: dict[str, ReceiptFields],
    settled: dict[tuple[str, str], str] | None = None,
) -> tuple[list[Record], list[ReviewRow], dict[str, dict[Status, int]]]:
    settled = settled or {}
    report: dict[str, dict[Status, int]] = {f: {s: 0 for s in STATUSES} for f in FIELDS}
    new_records: list[Record] = []
    review: list[ReviewRow] = []
    for rec in records:
        new = Record(rec.file_name, deepcopy(rec.fields), [])
        for f in FIELDS:
            g, q = _answer(gemini, rec.file_name, f), _answer(qwen, rec.file_name, f)
            key = (rec.file_name, f)
            if key in settled:
                # Người dùng đã duyệt trường này: giá trị của họ là cuối cùng
                new.fields[f] = settled[key]
                report[f]["kept"] += 1
                continue
            decision = decide_field(f, rec.fields[f], g, q)
            new.fields[f] = decision.value
            report[f][decision.status] += 1
            if decision.status == "review":
                review.append(ReviewRow(rec.file_name, f, rec.fields[f], g or "", q or ""))
            if decision.status in UNSETTLED and decision.value == "":
                new.unverified.append(f)
        new_records.append(new)
    return new_records, review, report


def write_review_csv(rows: list[ReviewRow], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # utf-8-sig để Excel hiển thị đúng tiếng Việt
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([fd.name for fd in dc_fields(ReviewRow)])
        writer.writerows(astuple(r) for r in rows)


def read_review_csv(path: Path) -> list[ReviewRow]:
    with open(path, encoding="utf-8-sig", newline="") as f:
        return [ReviewRow(**row) for row in csv.DictReader(f)]


def read_settled(path: Path) -> dict[tuple[str, str], str]:
    settled: dict[tuple[str, str], str] = {}
    if not Path(path).exists():
        return settled
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                row = json.loads(line)
                settled[(row["file_name"], row["field"])] = row["value"]
    return settled


def review_paths(split: str) -> tuple[Path, Path]:
    return REVIEW_DIR / f"{split}.review.csv", REVIEW_DIR / f"{split}.review_done.jsonl"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gộp nhãn Gemini + Qwen vào Version5/data1")
    parser.add_argument("--split", required=True, choices=["test", "validation", "train"])
    args = parser.parse_args(argv)

    label_path = LABEL_ROOT / args.split / "metadata.jsonl"
    review_csv, done_path = review_paths(args.split)
    gemini = load_cache(CACHE_DIR / f"{args.split}.gemini.jsonl")
    qwen = load_cache(CACHE_DIR / f"{args.split}.qwen.jsonl")
    new, review, report = merge_split(load_metadata(label_path), gemini, qwen, read_settled(done_path))
    dump_metadata(new, label_path)
    write_review_csv(review, review_csv)

    print(f"{args.split}: Gemini {len(gemini)} ảnh, Qwen {len(qwen)} ảnh, cần duyệt {len(review)} trường -> {review_csv}")
    print(f"{'Trường':<12}" + "".join(f"{s:>11}" for s in STATUSES))
    for f in FIELDS:
        print(f"{f:<12}" + "".join(f"{report[f][s]:>11}" for s in STATUSES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
