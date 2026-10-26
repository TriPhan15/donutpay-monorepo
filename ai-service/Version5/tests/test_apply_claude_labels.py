import json

from apply_claude_labels import apply_readings, load_readings
from labels import Record

FULL = {"SELLER": "S", "ADDRESS": "A", "TIMESTAMP": "T", "TOTAL_COST": "1"}


def _rec(name, **kw):
    return Record(name, {**FULL, **kw})


def _write(path, rows):
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")


def test_load_readings_merges_parts_last_wins_and_skips_errors(tmp_path):
    _write(tmp_path / "test.claude.part1.jsonl", [
        {"file_name": "a.jpg", "fields": {**FULL, "SELLER": "old"}, "unsure": []},
        {"file_name": "b.jpg", "error": "không mở được ảnh"},
    ])
    _write(tmp_path / "test.claude.part2.jsonl", [{"file_name": "a.jpg", "fields": {**FULL, "SELLER": "new"}, "unsure": ["ADDRESS"]}])
    readings = load_readings(tmp_path, "test")
    assert set(readings) == {"a.jpg"}
    assert readings["a.jpg"].fields.SELLER == "new" and readings["a.jpg"].unsure == ["ADDRESS"]


def test_apply_fills_empty_and_settles(tmp_path):
    _write(tmp_path / "test.claude.part1.jsonl", [{"file_name": "a.jpg", "fields": {**FULL, "ADDRESS": "12 Lê Lợi"}, "unsure": []}])
    new, settled, report, changes = apply_readings([_rec("a.jpg", ADDRESS="")], load_readings(tmp_path, "test"), {})
    assert new[0].fields["ADDRESS"] == "12 Lê Lợi" and new[0].unverified == []
    assert ("a.jpg", "ADDRESS", "12 Lê Lợi") in settled and len(settled) == 4
    assert report["filled"] == 1 and changes == []


def test_unsure_empty_is_unverified_and_not_settled(tmp_path):
    _write(tmp_path / "test.claude.part1.jsonl", [{"file_name": "a.jpg", "fields": {**FULL, "TIMESTAMP": ""}, "unsure": ["TIMESTAMP"]}])
    new, settled, report, _ = apply_readings([_rec("a.jpg", TIMESTAMP="")], load_readings(tmp_path, "test"), {})
    assert new[0].unverified == ["TIMESTAMP"] and all(f != "TIMESTAMP" for _, f, _ in settled)
    assert report["unsure"] == 1


def test_claude_empty_never_erases_existing_label(tmp_path):
    _write(tmp_path / "test.claude.part1.jsonl", [{"file_name": "a.jpg", "fields": {**FULL, "SELLER": ""}, "unsure": []}])
    new, settled, report, _ = apply_readings([_rec("a.jpg", SELLER="Circle K")], load_readings(tmp_path, "test"), {})
    assert new[0].fields["SELLER"] == "Circle K" and all(f != "SELLER" for _, f, _ in settled)
    assert report["kept_existing_over_empty"] == 1


def test_changed_value_is_reported_and_same_value_keeps_spelling(tmp_path):
    _write(tmp_path / "test.claude.part1.jsonl", [{"file_name": "a.jpg", "fields": {**FULL, "TOTAL_COST": "50.000", "SELLER": "Bách Hóa X"}, "unsure": []}])
    new, _, report, changes = apply_readings([_rec("a.jpg", TOTAL_COST="50,000", SELLER="Bach Hoa X")], load_readings(tmp_path, "test"), {})
    assert new[0].fields["TOTAL_COST"] == "50,000"            # same amount: user's spelling kept
    assert new[0].fields["SELLER"] == "Bách Hóa X" and report["changed"] == 1
    assert changes == [("a.jpg", "SELLER", "Bach Hoa X", "Bách Hóa X")]


def test_user_review_answers_win(tmp_path):
    _write(tmp_path / "test.claude.part1.jsonl", [{"file_name": "a.jpg", "fields": {**FULL, "SELLER": "Claude"}, "unsure": []}])
    new, settled, _, _ = apply_readings([_rec("a.jpg", SELLER="User")], load_readings(tmp_path, "test"), {("a.jpg", "SELLER"): "User"})
    assert new[0].fields["SELLER"] == "User" and all(f != "SELLER" for _, f, _ in settled)
