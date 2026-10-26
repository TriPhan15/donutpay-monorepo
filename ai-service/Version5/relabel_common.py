"""Phần dùng chung khi cho model AI đọc lại nhãn: prompt, parse câu trả lời, cache và vòng lặp chạy tiếp được."""

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Literal

from pydantic import BaseModel, ConfigDict, ValidationError, field_validator

from labels import FIELDS, Record

Scope = Literal["all", "with_empty"]
PROGRESS_EVERY = 50
_FENCE = re.compile(r"^\s*```(?:json)?\s*(.*?)\s*```\s*$", re.DOTALL)


class ReceiptFields(BaseModel):
    model_config = ConfigDict(extra="ignore")

    # Bắt buộc đủ 4 khóa: JSON sai khóa (ví dụ "seller" viết thường) phải là lỗi, không phải 4 trường rỗng
    SELLER: str
    ADDRESS: str
    TIMESTAMP: str
    TOTAL_COST: str

    @field_validator("*", mode="before")
    @classmethod
    def _coerce(cls, value: Any) -> Any:
        if value is None:
            return ""
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            return str(value)
        return value

    def as_dict(self) -> dict[str, str]:
        return {f: getattr(self, f).strip() for f in FIELDS}


class ReplyParseError(ValueError):
    """Câu trả lời của model không phải JSON 4 trường hợp lệ."""


class QuotaExhausted(RuntimeError):
    """Hết hạn mức gọi API trong ngày: dừng vòng lặp, giữ nguyên cache."""


@dataclass
class RunSummary:
    done: int = 0
    skipped: int = 0
    errors: int = 0
    stopped: str | None = None


def select_examples(records: list[Record], k: int = 4) -> list[Record]:
    full = [r for r in records if all(r.fields[f] for f in FIELDS)]
    return sorted(full, key=lambda r: r.file_name)[:k]


def build_prompt(examples: list[Record]) -> str:
    shots = "\n".join(json.dumps({f: r.fields[f] for f in FIELDS}, ensure_ascii=False) for r in examples)
    return (
        "Bạn là hệ thống đọc hóa đơn tiếng Việt. Đọc ảnh hóa đơn và trích 4 trường:\n"
        "- SELLER: tên cửa hàng/doanh nghiệp, chép nguyên văn như in trên hóa đơn.\n"
        "- ADDRESS: địa chỉ cửa hàng, chép nguyên văn.\n"
        "- TIMESTAMP: ngày giờ in trên hóa đơn, chép đúng như in (không đổi định dạng).\n"
        "- TOTAL_COST: chỉ số tiền cuối cùng khách phải trả, giữ chữ số và dấu phân cách như in, "
        "không kèm chữ (ví dụ \"50,000\").\n"
        "Trường nào không có trên hóa đơn thì để chuỗi rỗng \"\". Không đoán, không bịa.\n"
        "Chỉ trả lời đúng một object JSON có đủ 4 khóa SELLER, ADDRESS, TIMESTAMP, TOTAL_COST.\n"
        f"Ví dụ nhãn đúng kiểu (của các hóa đơn khác):\n{shots}\n"
    )


def parse_reply(text: str) -> ReceiptFields:
    match = _FENCE.match(text or "")
    body = match.group(1) if match else (text or "")
    try:
        return ReceiptFields.model_validate_json(body)
    except ValidationError as exc:
        raise ReplyParseError(str(exc).splitlines()[0]) from exc


def load_cache(path: Path) -> dict[str, ReceiptFields]:
    cache: dict[str, ReceiptFields] = {}
    if not Path(path).exists():
        return cache
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            row = json.loads(line)
            if "fields" in row:
                cache[row["file_name"]] = ReceiptFields.model_validate(row["fields"])
            else:
                cache.pop(row["file_name"], None)
    return cache


def select_targets(records: list[Record], scope: Scope) -> list[Record]:
    if scope == "all":
        return list(records)
    return [r for r in records if any(not r.fields[f] for f in FIELDS)]


def run_reader(
    read: Callable[[Path], str],
    records: list[Record],
    image_root: Path,
    split: str,
    cache_path: Path,
    scope: Scope,
    limit: int | None = None,
) -> RunSummary:
    summary = RunSummary()
    cached = load_cache(cache_path)
    cache_path = Path(cache_path)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    attempted = 0
    with open(cache_path, "a", encoding="utf-8") as out:
        for rec in select_targets(records, scope):
            if rec.file_name in cached:
                summary.skipped += 1
                continue
            if limit is not None and attempted >= limit:
                break
            attempted += 1
            try:
                fields = parse_reply(read(image_root / split / rec.file_name))
                row: dict[str, Any] = {"file_name": rec.file_name, "fields": fields.as_dict()}
                summary.done += 1
            except QuotaExhausted:
                summary.stopped = "quota"
                print(f"Hết quota sau {summary.done} ảnh; chạy lại sau để đọc tiếp {split}.")
                break
            except Exception as exc:  # noqa: BLE001 - lỗi từng ảnh được ghi lại và thử lại ở lần chạy sau
                row = {"file_name": rec.file_name, "error": f"{type(exc).__name__}: {exc}"[:500]}
                summary.errors += 1
            out.write(json.dumps(row, ensure_ascii=False) + "\n")
            out.flush()
            if attempted % PROGRESS_EVERY == 0:
                print(f"{split}: đã đọc {summary.done}, lỗi {summary.errors}, bỏ qua {summary.skipped}")
    return summary


def run_cli(backend: str, make_reader: Callable[[str, argparse.Namespace], Callable[[Path], str]],
            argv: list[str] | None = None, add_args: Callable[[argparse.ArgumentParser], None] | None = None) -> int:
    """CLI chung cho relabel_gemini.py / relabel_qwen.py: đọc một split, ghi cache `<split>.<backend>.jsonl`."""
    from labels import load_metadata
    from paths import LABEL_ROOT, WORK_DIR, find_image_root

    parser = argparse.ArgumentParser(description=f"Đọc lại nhãn bằng {backend}")
    parser.add_argument("--split", required=True, choices=["test", "validation", "train"])
    parser.add_argument("--scope", choices=["all", "with_empty"], default=None,
                        help="mặc định: all cho test/validation, with_empty cho train")
    parser.add_argument("--limit", type=int, default=None)
    if add_args:
        add_args(parser)
    args = parser.parse_args(argv)
    scope: Scope = args.scope or ("with_empty" if args.split == "train" else "all")

    records = load_metadata(LABEL_ROOT / args.split / "metadata.jsonl")
    train_records = load_metadata(LABEL_ROOT / "train" / "metadata.jsonl")
    prompt = build_prompt(select_examples(train_records))
    image_root = find_image_root((args.split, records[0].file_name))
    cache_path = WORK_DIR / "relabel_cache" / f"{args.split}.{backend}.jsonl"
    summary = run_reader(make_reader(prompt, args), records, image_root, args.split, cache_path, scope, args.limit)
    print(f"{backend} / {args.split}: xong {summary.done}, lỗi {summary.errors}, đã có từ trước {summary.skipped}, "
          f"dừng: {summary.stopped or 'không'} -> {cache_path}")
    return 0
