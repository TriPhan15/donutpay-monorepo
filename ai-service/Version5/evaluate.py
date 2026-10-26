"""Chấm điểm V3 và V5 trên cùng một tập, cùng một cách chấm."""

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

from labels import FIELDS, Record, fields_match, is_long, load_metadata, money_value, normalize_text, read_image
from model_config import FIELD_TAGS, MAX_LENGTH, TASK_TOKEN
from paths import BUNDLE_DIR, LABEL_ROOT, WORK_DIR, find_image_root
from postprocess import clean_vietnamese_text

RELAXED_THRESHOLD = 0.80
CIRCLE_K_TEST = ("00005409.jpg", "00005385.jpg", "00006809.jpg")
SEEN_FILE = BUNDLE_DIR / "v3_seen_test.txt"
WIN_SUBSETS = ("all_minus_v3_seen", "long")
ALL_KEY = "ALL"


def sequence_to_fields(sequence: str, legacy_v3: bool) -> dict[str, str]:
    if legacy_v3:
        sequence = clean_vietnamese_text(sequence)
    fields: dict[str, str] = {}
    for f in FIELDS:
        tag = FIELD_TAGS[f]
        match = re.search(rf"<s_{tag}>(.*?)</s_{tag}>", sequence, re.DOTALL)
        fields[f] = match.group(1).strip() if match else ""
    return fields


def generate_fields(model, processor, image, legacy_v3: bool) -> dict[str, str]:
    import torch

    size = processor.image_processor.size
    pixel_values = processor(image, return_tensors="pt", do_resize=True,
                             size={"height": size["height"], "width": size["width"]},
                             do_align_long_axis=True).pixel_values.to(model.device)
    task_id = processor.tokenizer.convert_tokens_to_ids(TASK_TOKEN)
    with torch.no_grad(), torch.autocast(device_type=model.device.type, dtype=torch.float16,
                                         enabled=model.device.type == "cuda"):
        out = model.generate(pixel_values, decoder_input_ids=torch.tensor([[task_id]], device=model.device),
                             max_length=MAX_LENGTH, num_beams=1, use_cache=True,
                             pad_token_id=processor.tokenizer.pad_token_id,
                             eos_token_id=processor.tokenizer.eos_token_id)
    return sequence_to_fields(processor.batch_decode(out)[0], legacy_v3)


class Predictor:
    def __init__(self, model_dir: Path, legacy_v3: bool, device: str):
        from transformers import DonutProcessor, VisionEncoderDecoderModel

        self.processor = DonutProcessor.from_pretrained(model_dir)
        self.model = VisionEncoderDecoderModel.from_pretrained(model_dir).to(device).eval()
        self.legacy_v3 = legacy_v3

    def predict(self, image) -> dict[str, str]:
        return generate_fields(self.model, self.processor, image, self.legacy_v3)


@dataclass
class FieldScore:
    exact: int = 0
    relaxed: int = 0
    sim: float = 0.0
    count: int = 0

    def ratio(self, attr: str) -> float:
        return getattr(self, attr) / self.count if self.count else 0.0


def _similarity(field: str, gt: str, pred: str) -> float:
    if field == "TOTAL_COST":
        g, p = money_value(gt), money_value(pred)
        if g is not None and p is not None:
            return SequenceMatcher(None, str(g), str(p)).ratio()
    g, p = normalize_text(gt), normalize_text(pred)
    if not g and not p:
        return 1.0
    return SequenceMatcher(None, g, p).ratio()


def score(pairs: list[tuple[dict[str, str], dict[str, str]]], include_empty_gt: bool) -> dict[str, FieldScore]:
    result = {key: FieldScore() for key in (*FIELDS, ALL_KEY)}
    for gt, pred in pairs:
        for f in FIELDS:
            if not gt[f] and not include_empty_gt:
                continue
            sim = _similarity(f, gt[f], pred[f])
            exact = fields_match(f, gt[f], pred[f])
            for key in (f, ALL_KEY):
                s = result[key]
                s.count += 1
                s.exact += int(exact)
                s.relaxed += int(sim >= RELAXED_THRESHOLD)
                s.sim += sim
    return result


def subsets(records: list[Record], image_dir: Path, seen: set[str]) -> dict[str, set[str]]:
    names = {r.file_name for r in records}
    return {
        "all": names,
        "all_minus_v3_seen": names - seen,
        "long": {n for n in names if is_long(Path(image_dir) / n)},
        "circle_k": names & set(CIRCLE_K_TEST),
    }


def verdict(exact_by_subset: dict[str, tuple[float, float]]) -> str:
    """exact_by_subset[subset] = (V3, V5) exact-match trung bình."""
    won = all(exact_by_subset[s][1] > exact_by_subset[s][0] for s in WIN_SUBSETS)
    return "V5 THẮNG" if won else "V5 CHƯA THẮNG"


def _predict_all(name: str, predictor_factory, records: list[Record], image_dir: Path, split: str,
                 limit: int | None) -> dict[str, dict[str, str]]:
    cache_path = WORK_DIR / f"pred_{name}_{split}.jsonl"
    preds: dict[str, dict[str, str]] = {}
    if cache_path.exists():
        for line in cache_path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            preds[row["file_name"]] = row["fields"]
    todo = [r for r in records if r.file_name not in preds][:limit]
    if todo:
        predictor = predictor_factory()
        with open(cache_path, "a", encoding="utf-8") as out:
            for i, rec in enumerate(todo, start=1):
                fields = predictor.predict(read_image(image_dir / rec.file_name))
                preds[rec.file_name] = fields
                out.write(json.dumps({"file_name": rec.file_name, "fields": fields}, ensure_ascii=False) + "\n")
                out.flush()
                if i % 50 == 0:
                    print(f"{name}: đã chấm {i}/{len(todo)} ảnh")
        del predictor
    return preds


def _print_table(title: str, v3: dict[str, FieldScore], v5: dict[str, FieldScore]) -> None:
    print(f"\n=== {title} (số trường: {v5[ALL_KEY].count}) ===")
    print(f"{'Trường':<12}| {'V3 exact':>9} {'V5 exact':>9} | {'V3 @80%':>8} {'V5 @80%':>8} | {'V3 sim':>7} {'V5 sim':>7}")
    for key in (*FIELDS, ALL_KEY):
        a, b = v3[key], v5[key]
        print(f"{key:<12}| {a.ratio('exact'):>9.2%} {b.ratio('exact'):>9.2%} | {a.ratio('relaxed'):>8.2%} "
              f"{b.ratio('relaxed'):>8.2%} | {a.ratio('sim'):>7.2%} {b.ratio('sim'):>7.2%}")


def main(argv: list[str] | None = None) -> int:
    import torch

    parser = argparse.ArgumentParser(description="So sánh V3 và V5")
    parser.add_argument("--v3", type=Path, required=True)
    parser.add_argument("--v5", type=Path, required=True)
    parser.add_argument("--split", default="test", choices=["test", "validation"])
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args(argv)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    records = load_metadata(LABEL_ROOT / args.split / "metadata.jsonl")
    image_dir = find_image_root((args.split, records[0].file_name)) / args.split
    preds = {
        "v3": _predict_all("v3", lambda: Predictor(args.v3, True, device), records, image_dir, args.split, args.limit),
        "v5": _predict_all("v5", lambda: Predictor(args.v5, False, device), records, image_dir, args.split, args.limit),
    }
    records = [r for r in records if r.file_name in preds["v3"] and r.file_name in preds["v5"]]
    seen = set(SEEN_FILE.read_text(encoding="utf-8").split()) if SEEN_FILE.exists() else set()
    groups = subsets(records, image_dir, seen)

    with open(WORK_DIR / f"compare_{args.split}.csv", "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["file_name", "field", "ground_truth", "v3", "v5", "v3_exact", "v5_exact"])
        for rec in records:
            for fld in FIELDS:
                g, a, b = rec.fields[fld], preds["v3"][rec.file_name][fld], preds["v5"][rec.file_name][fld]
                writer.writerow([rec.file_name, fld, g, a, b, int(fields_match(fld, g, a)), int(fields_match(fld, g, b))])

    exact_by_subset: dict[str, tuple[float, float]] = {}
    for include_empty in (False, True):
        label = "tính cả trường rỗng (đo việc bịa)" if include_empty else "chỉ số chính"
        for group, names in groups.items():
            chosen = [r for r in records if r.file_name in names]
            per_model = {m: score([(r.fields, preds[m][r.file_name]) for r in chosen], include_empty) for m in preds}
            _print_table(f"{group} - {label}", per_model["v3"], per_model["v5"])
            if not include_empty:
                exact_by_subset[group] = (per_model["v3"][ALL_KEY].ratio("exact"), per_model["v5"][ALL_KEY].ratio("exact"))
    print(f"\nKẾT LUẬN: {verdict(exact_by_subset)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
