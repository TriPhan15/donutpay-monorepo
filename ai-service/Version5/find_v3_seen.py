"""Liệt kê ảnh test mà V3 có thể đã học (ADDRESS trùng nhãn train cũ của V3)."""

import sys
from pathlib import Path

from labels import load_metadata, normalize_text
from paths import BUNDLE_DIR, LABEL_ROOT, LOCAL_IMAGE_ROOT

MIN_ADDRESS_LENGTH = 15
OUTPUT_NAME = "v3_seen_test.txt"


def v3_seen(old_train_metadata: Path, metadata_files: list[Path]) -> list[str]:
    old_addresses = {normalize_text(r.fields["ADDRESS"]) for r in load_metadata(old_train_metadata)}
    seen: set[str] = set()
    for path in metadata_files:
        for rec in load_metadata(path):
            address = normalize_text(rec.fields["ADDRESS"])
            if len(address) > MIN_ADDRESS_LENGTH and address in old_addresses:
                seen.add(rec.file_name)
    return sorted(seen)


if __name__ == "__main__":
    names = v3_seen(LOCAL_IMAGE_ROOT / "train_metadata.jsonl",
                    [LOCAL_IMAGE_ROOT / "test" / "metadata.jsonl", LABEL_ROOT / "test" / "metadata.jsonl"])
    (BUNDLE_DIR / OUTPUT_NAME).write_text("".join(f"{n}\n" for n in names), encoding="utf-8")
    print(f"{len(names)} ảnh test có thể V3 đã học -> {BUNDLE_DIR / OUTPUT_NAME}")
    sys.exit(0)
