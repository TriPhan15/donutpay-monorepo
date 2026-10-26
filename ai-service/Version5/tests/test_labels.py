import json

import pytest
from PIL import Image

from init_labels import init_labels
from labels import (
    SPLITS,
    LabelError,
    Record,
    dump_metadata,
    fields_match,
    image_hw,
    is_long,
    load_metadata,
    money_value,
    read_image,
)

EXIF_ORIENTATION = 0x0112


def _save_jpeg(path, size, orientation=None):
    img = Image.new("RGB", size, (255, 255, 255))
    if orientation is None:
        img.save(path)
    else:
        exif = Image.Exif()
        exif[EXIF_ORIENTATION] = orientation
        img.save(path, exif=exif)


def test_money_value_variants():
    assert money_value("33,000VND") == 33000
    assert money_value("33.000 đ") == 33000
    assert money_value("70,000.00") == 70000
    assert money_value("99,999.99") == 99999
    assert money_value("Tổng tiền : 387,000") == 387000
    assert money_value("1,234,567") == 1234567
    assert money_value("Tổng tiền :") is None


def test_fields_match_rules():
    assert fields_match("TOTAL_COST", "50,000", "50.000đ")
    assert not fields_match("TOTAL_COST", "50,000", "5,000")
    assert fields_match("SELLER", "  Circle  K ", "circle k")
    assert not fields_match("SELLER", "Circle K", "")
    assert fields_match("ADDRESS", "", "")
    assert fields_match("TOTAL_COST", "", "")
    assert not fields_match("TOTAL_COST", "", "50,000")


def test_load_metadata_lowercase_keys_and_missing(tmp_path):
    p = tmp_path / "m.jsonl"
    gt = json.dumps({"gt_parse": {"seller": "X"}})
    p.write_text(json.dumps({"file_name": "a.jpg", "ground_truth": gt}) + "\n", encoding="utf-8")
    [r] = load_metadata(p)
    assert r.fields == {"SELLER": "X", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": ""}
    assert r.unverified == []


def test_load_metadata_bad_line_names_line(tmp_path):
    p = tmp_path / "m.jsonl"
    p.write_text("{oops\n", encoding="utf-8")
    with pytest.raises(LabelError, match=r"m.jsonl:1"):
        load_metadata(p)


def test_dump_roundtrip_keeps_unverified(tmp_path):
    rec = Record("a.jpg", {"SELLER": "Ố", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "1"}, ["ADDRESS"])
    dump_metadata([rec], tmp_path / "m.jsonl")
    assert load_metadata(tmp_path / "m.jsonl") == [rec]
    assert "Ố" in (tmp_path / "m.jsonl").read_text(encoding="utf-8")


def test_init_labels_never_overwrites(tmp_path):
    src, dst = tmp_path / "src", tmp_path / "dst"
    for s in SPLITS:
        (src / s).mkdir(parents=True)
        (src / s / "metadata.jsonl").write_text("orig\n")
    assert init_labels(src, dst) == list(SPLITS)
    (dst / "test" / "metadata.jsonl").write_text("corrected\n")
    assert init_labels(src, dst) == []
    assert (dst / "test" / "metadata.jsonl").read_text() == "corrected\n"
    assert (dst / "test" / "metadata.jsonl").stat().st_nlink == 1


def test_read_image_applies_exif(tmp_path):
    p = tmp_path / "r.jpg"
    _save_jpeg(p, (20, 10), orientation=6)
    img = read_image(p)
    assert img.mode == "RGB" and img.size == (10, 20)


def test_image_hw_and_is_long(tmp_path):
    tall, rotated, wide = tmp_path / "t.jpg", tmp_path / "r.jpg", tmp_path / "w.jpg"
    _save_jpeg(tall, (100, 300))
    _save_jpeg(rotated, (300, 100), orientation=6)
    _save_jpeg(wide, (300, 100))
    assert image_hw(tall) == (300, 100) and is_long(tall)
    assert image_hw(rotated) == (300, 100) and is_long(rotated)
    assert image_hw(wide) == (100, 300) and not is_long(wide)


def test_pick_bundle_ignores_previous_outputs(tmp_path):
    from paths import pick_bundle

    fresh = tmp_path / "version5-dataset" / "Version5"
    old = tmp_path / "old-run-output" / "Version5"
    for b in (fresh, old):
        b.mkdir(parents=True)
    (old.parent / "donut_checkpoints").mkdir()
    assert pick_bundle([old, fresh]) == fresh
    other = tmp_path / "another" / "Version5"
    other.mkdir(parents=True)
    with pytest.raises(RuntimeError, match="BUNDLE_SRC"):
        pick_bundle([fresh, other])
