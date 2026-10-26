import json

from find_v3_seen import v3_seen
from labels import Record, dump_metadata


def test_v3_seen_matches_address_only_when_long(tmp_path):
    old = tmp_path / "old.jsonl"
    rows = [{"ADDRESS": "55 Pham Viet Chanh, Quan 1"}, {"address": "Q1"}]
    old.write_text("".join(json.dumps({"file_name": f"m{i}.jpg", "ground_truth": json.dumps({"gt_parse": r})}) + "\n"
                           for i, r in enumerate(rows)), encoding="utf-8")
    empty = {"SELLER": "", "TIMESTAMP": "", "TOTAL_COST": ""}
    new = tmp_path / "new.jsonl"
    dump_metadata([Record("x.jpg", {**empty, "ADDRESS": "55  pham viet chanh, QUAN 1"}),
                   Record("y.jpg", {**empty, "ADDRESS": "Q1"}),
                   Record("z.jpg", {**empty, "ADDRESS": "khác hẳn và đủ dài"})], new)
    assert v3_seen(old, [new, new]) == ["x.jpg"]
