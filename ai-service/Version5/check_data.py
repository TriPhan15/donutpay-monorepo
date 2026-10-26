"""Kiểm tra dữ liệu trước khi train/đọc nhãn: nhãn parse được, ảnh tồn tại và mở được."""

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

from labels import FIELDS, SPLITS, LabelError, load_metadata, read_image
from paths import LABEL_ROOT, find_image_root

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}
MAX_LISTED = 20


@dataclass
class SplitReport:
    split: str
    rows: int = 0
    missing: list[str] = field(default_factory=list)
    unreadable: list[str] = field(default_factory=list)
    unlabeled: list[str] = field(default_factory=list)
    empty_counts: dict[str, int] = field(default_factory=dict)
    unverified_counts: dict[str, int] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.missing and not self.unreadable


def check_split(split: str, label_root: Path, image_root: Path, open_images: bool = True) -> SplitReport:
    records = load_metadata(label_root / split / "metadata.jsonl")
    image_dir = image_root / split
    report = SplitReport(split=split, rows=len(records))
    report.empty_counts = {f: sum(1 for r in records if not r.fields[f]) for f in FIELDS}
    report.unverified_counts = {f: sum(1 for r in records if f in r.unverified) for f in FIELDS}
    for rec in records:
        path = image_dir / rec.file_name
        if not path.is_file():
            report.missing.append(rec.file_name)
        elif open_images:
            try:
                read_image(path)
            except Exception:  # noqa: BLE001 - mọi lỗi mở ảnh đều được báo theo tên file
                report.unreadable.append(rec.file_name)
    labeled = {r.file_name for r in records}
    if image_dir.is_dir():
        report.unlabeled = sorted(
            p.name for p in image_dir.iterdir()
            if p.suffix.lower() in IMAGE_SUFFIXES and p.name not in labeled
        )
    return report


def _print_report(rep: SplitReport) -> None:
    status = "OK" if rep.ok else "LỖI"
    print(f"[{status}] {rep.split}: {rep.rows} dòng, thiếu ảnh {len(rep.missing)}, "
          f"ảnh hỏng {len(rep.unreadable)}, ảnh chưa có nhãn {len(rep.unlabeled)}")
    print(f"    trường rỗng: {rep.empty_counts}")
    print(f"    trường chưa kiểm tra: {rep.unverified_counts}")
    for title, names in (("thiếu", rep.missing), ("hỏng", rep.unreadable), ("chưa có nhãn", rep.unlabeled)):
        if names:
            print(f"    ảnh {title}: {names[:MAX_LISTED]}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Kiểm tra dữ liệu Donut V5")
    parser.add_argument("--label-root", type=Path, default=LABEL_ROOT)
    parser.add_argument("--image-root", type=Path, default=None)
    parser.add_argument("--no-open", action="store_true", help="chỉ kiểm tra file tồn tại, không mở ảnh")
    args = parser.parse_args(argv)

    all_ok = True
    for split in SPLITS:
        try:
            records = load_metadata(args.label_root / split / "metadata.jsonl")
        except (LabelError, FileNotFoundError) as exc:
            print(f"[LỖI] {split}: {exc}")
            all_ok = False
            continue
        image_root = args.image_root
        if image_root is None:
            if not records:
                continue
            image_root = find_image_root((split, records[0].file_name))
        rep = check_split(split, args.label_root, image_root, open_images=not args.no_open)
        _print_report(rep)
        all_ok = all_ok and rep.ok
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
