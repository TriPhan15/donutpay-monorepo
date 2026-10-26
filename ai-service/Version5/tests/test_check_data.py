import json

from PIL import Image

from check_data import check_split, main
from labels import Record, dump_metadata


def _fields(**kw):
    base = {"SELLER": "S", "ADDRESS": "A", "TIMESTAMP": "T", "TOTAL_COST": "1"}
    base.update(kw)
    return base


def _setup(tmp_path, records, images):
    label_root, image_root = tmp_path / "labels", tmp_path / "images"
    dump_metadata(records, label_root / "train" / "metadata.jsonl")
    (image_root / "train").mkdir(parents=True)
    for name, kind in images.items():
        p = image_root / "train" / name
        if kind == "ok":
            Image.new("RGB", (10, 10)).save(p)
        else:
            p.write_text("không phải ảnh")
    return label_root, image_root


def test_reports_missing_and_unreadable(tmp_path):
    recs = [Record("a.jpg", _fields()), Record("b.jpg", _fields()), Record("c.jpg", _fields())]
    label_root, image_root = _setup(tmp_path, recs, {"a.jpg": "ok", "c.jpg": "bad", "d.png": "ok"})
    rep = check_split("train", label_root, image_root)
    assert rep.missing == ["b.jpg"] and rep.unreadable == ["c.jpg"]
    assert rep.unlabeled == ["d.png"] and not rep.ok


def test_empty_counts(tmp_path):
    recs = [Record("a.jpg", _fields(ADDRESS="")), Record("b.jpg", _fields())]
    label_root, image_root = _setup(tmp_path, recs, {"a.jpg": "ok", "b.jpg": "ok"})
    rep = check_split("train", label_root, image_root)
    assert rep.ok and rep.rows == 2
    assert rep.empty_counts == {"SELLER": 0, "ADDRESS": 1, "TIMESTAMP": 0, "TOTAL_COST": 0}


def test_main_exit_code(tmp_path):
    recs = [Record("a.jpg", _fields())]
    label_root, image_root = _setup(tmp_path, recs, {})
    for split in ("validation", "test"):
        dump_metadata([], label_root / split / "metadata.jsonl")
        (image_root / split).mkdir()
    args = ["--label-root", str(label_root), "--image-root", str(image_root)]
    assert main(args) == 1
    Image.new("RGB", (10, 10)).save(image_root / "train" / "a.jpg")
    assert main(args) == 0
