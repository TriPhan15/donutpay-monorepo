from labels import Record
from merge_labels import ReviewRow
from review_labels import apply_answer, parse_answer, pending_rows


def test_parse_answer():
    row = ReviewRow("a.jpg", "SELLER", "old", "gem", "qw")
    assert [parse_answer(x, row) for x in ["", "-", "o", "q", " Mới "]] == ["gem", "", "old", None, "Mới"]


def test_apply_answer_clears_unverified():
    r = Record("a.jpg", {"SELLER": "S", "ADDRESS": "", "TIMESTAMP": "T", "TOTAL_COST": "1"}, ["ADDRESS"])
    apply_answer(r, "ADDRESS", "")
    assert r.unverified == [] and r.fields["ADDRESS"] == ""
    apply_answer(r, "SELLER", "Mới")
    assert r.fields["SELLER"] == "Mới"


def test_pending_rows_skips_settled():
    rows = [ReviewRow("a.jpg", "SELLER", "", "", ""), ReviewRow("b.jpg", "SELLER", "", "", "")]
    assert pending_rows(rows, {("a.jpg", "SELLER"): "x"}) == [rows[1]]
