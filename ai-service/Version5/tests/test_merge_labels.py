import pytest

from labels import Record
from merge_labels import Decision, ReviewRow, decide_field, merge_split, read_settled, write_review_csv
from relabel_common import ReceiptFields


@pytest.mark.parametrize("field,old,g,q,expected", [
    ("SELLER", "Circle K", "CIRCLE K", "x", Decision("Circle K", "kept")),
    ("TOTAL_COST", "", "33,000", "33.000", Decision("33,000", "agree")),
    ("ADDRESS", "", "", "", Decision("", "agree")),
    ("TOTAL_COST", "50,000", "60,000", "60,000", Decision("60,000", "agree")),
    ("SELLER", "", "A", "B", Decision("", "review")),
    ("SELLER", "X", None, "X", Decision("X", "kept")),
    ("SELLER", "X", None, "Y", Decision("X", "review")),
    ("SELLER", "", None, None, Decision("", "unchecked")),
    ("SELLER", "X", "Y", None, Decision("X", "review")),
])
def test_decide_field(field, old, g, q, expected):
    assert decide_field(field, old, g, q) == expected


def _rec(name, **kw):
    fields = {"SELLER": "S", "ADDRESS": "A", "TIMESTAMP": "T", "TOTAL_COST": "1"}
    fields.update(kw)
    return Record(name, fields)


def test_merge_split_unverified_only_empty_unsettled():
    rec = _rec("a.jpg", ADDRESS="")
    gem = {"a.jpg": ReceiptFields(SELLER="S", ADDRESS="12 Lê Lợi", TIMESTAMP="T", TOTAL_COST="1")}
    qwen = {"a.jpg": ReceiptFields(SELLER="S", ADDRESS="99 Hai Bà Trưng", TIMESTAMP="T", TOTAL_COST="1")}
    new, review, report = merge_split([rec], gem, qwen)
    assert new[0].unverified == ["ADDRESS"] and new[0].fields["ADDRESS"] == ""
    assert [(r.file_name, r.field) for r in review] == [("a.jpg", "ADDRESS")]
    assert report["ADDRESS"]["review"] == 1 and report["SELLER"]["kept"] == 1
    assert rec.fields["ADDRESS"] == ""                     # input records are not mutated


def test_merge_unchecked_empty_is_unverified_filled_is_not():
    new, review, _ = merge_split([_rec("a.jpg", TIMESTAMP="")], {}, {})
    assert new[0].unverified == ["TIMESTAMP"] and review == []


def test_merge_applies_settled_answers_and_skips_their_rows():
    rec = _rec("a.jpg", ADDRESS="")
    gem = {"a.jpg": ReceiptFields(SELLER="S", ADDRESS="G", TIMESTAMP="T", TOTAL_COST="1")}
    qwen = {"a.jpg": ReceiptFields(SELLER="S", ADDRESS="Q", TIMESTAMP="T", TOTAL_COST="1")}
    new, review, _ = merge_split([rec], gem, qwen, settled={("a.jpg", "ADDRESS"): "Đúng"})
    assert new[0].fields["ADDRESS"] == "Đúng" and new[0].unverified == [] and review == []


def test_review_csv_and_settled_roundtrip(tmp_path):
    rows = [ReviewRow("a.jpg", "SELLER", "", "Gê", "Qư")]
    write_review_csv(rows, tmp_path / "r.csv")
    assert (tmp_path / "r.csv").read_bytes().startswith(b"\xef\xbb\xbf")
    (tmp_path / "done.jsonl").write_text('{"file_name": "a.jpg", "field": "SELLER", "value": "X"}\n', encoding="utf-8")
    assert read_settled(tmp_path / "done.jsonl") == {("a.jpg", "SELLER"): "X"}
    assert read_settled(tmp_path / "missing.jsonl") == {}
