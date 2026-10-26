"""Gộp mọi kết quả Claude đã đọc cho train vào nhãn Version5 (chạy được nhiều lần).

Đọc relabel_cache/train.claude.jsonl + mọi relabel_cache/train.claude.b*.jsonl (kể cả file do người khác
đọc gửi về), chuẩn hóa theo quy ước nhãn, ghi vào data1/train/metadata.jsonl qua apply_claude_labels,
rồi đánh dấu "chưa kiểm tra" các ô trống ở những dòng chưa ai đọc.
"""

import json
import re
import shutil
import subprocess
import sys

from labels import FIELDS, dump_metadata, load_metadata
from paths import BUNDLE_DIR, LABEL_ROOT

CACHE = BUNDLE_DIR / "relabel_cache"
MERGED = CACHE / "train.claude.jsonl"


def normalize(fields: dict[str, str]) -> None:
    if fields["SELLER"] == "PHÚC LONG":
        fields["SELLER"] = "PHUC LONG"
    fields["ADDRESS"] = fields["ADDRESS"].replace("Linh Chiều", "Linh Chiểu")
    if re.match(r"^\d{1,2} tháng", fields["TIMESTAMP"]):
        fields["TIMESTAMP"] = "Ngày " + fields["TIMESTAMP"]
    fields["TIMESTAMP"] = re.sub(r"^Ngày (?=\d{1,2}/)", "", fields["TIMESTAMP"])


def main() -> int:
    parts = sorted(CACHE.glob("train.claude.b*.jsonl"))
    rows: dict[str, dict] = {}
    for path in [MERGED] + parts:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip() and '"fields"' in line:
                row = json.loads(line)
                rows[row["file_name"]] = row
    for row in rows.values():
        normalize(row["fields"])
    (CACHE / "claude_raw").mkdir(exist_ok=True)
    for path in parts:
        shutil.move(str(path), CACHE / "claude_raw" / path.name)
    MERGED.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows.values()), encoding="utf-8")

    result = subprocess.run([sys.executable, str(BUNDLE_DIR / "apply_claude_labels.py"), "--split", "train"],
                            capture_output=True, text=True)
    print(result.stdout or result.stderr)

    label_path = LABEL_ROOT / "train" / "metadata.jsonl"
    records = load_metadata(label_path)
    masked = 0
    for rec in records:
        if rec.file_name in rows:
            continue
        for f in FIELDS:
            if not rec.fields[f] and f not in rec.unverified:
                rec.unverified.append(f)
                masked += 1
    dump_metadata(records, label_path)
    print(f"Claude đã đọc {len(rows)}/{len(records)} dòng train; che thêm {masked} ô trống chưa đọc")
    return 0


if __name__ == "__main__":
    sys.exit(main())
