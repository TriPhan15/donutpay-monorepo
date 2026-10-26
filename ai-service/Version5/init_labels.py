"""Copy metadata.jsonl gốc sang Version5/data1 lần đầu; không bao giờ ghi đè nhãn đã sửa."""

import shutil
from pathlib import Path

from labels import SPLITS
from paths import LABEL_ROOT, LOCAL_IMAGE_ROOT

METADATA_NAME = "metadata.jsonl"


def init_labels(src_root: Path, dst_root: Path) -> list[str]:
    copied: list[str] = []
    for split in SPLITS:
        dst = dst_root / split / METADATA_NAME
        if dst.exists():
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src_root / split / METADATA_NAME, dst)
        copied.append(split)
    return copied


if __name__ == "__main__":
    done = init_labels(LOCAL_IMAGE_ROOT, LABEL_ROOT)
    print(f"Đã copy nhãn cho: {done}" if done else "Nhãn đã có sẵn trong Version5, không ghi đè.")
