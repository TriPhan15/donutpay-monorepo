"""Tool duyệt nhãn trên terminal: chỉ hiện các trường mà Gemini và Qwen không thống nhất."""

import argparse
import json
import sys

from labels import Record, dump_metadata, load_metadata, read_image
from merge_labels import ReviewRow, read_review_csv, read_settled, review_paths
from paths import LABEL_ROOT, find_image_root

EMPTY_ANSWER = "-"
KEEP_OLD_ANSWER = "o"
QUIT_ANSWER = "q"


def parse_answer(raw: str, row: ReviewRow) -> str | None:
    answer = raw.strip()
    if answer == "":
        return row.gemini
    if answer == EMPTY_ANSWER:
        return ""
    if answer == KEEP_OLD_ANSWER:
        return row.old
    if answer == QUIT_ANSWER:
        return None
    return answer


def apply_answer(record: Record, field: str, value: str) -> None:
    record.fields[field] = value
    if field in record.unverified:
        record.unverified.remove(field)


def pending_rows(rows: list[ReviewRow], settled: dict[tuple[str, str], str]) -> list[ReviewRow]:
    return [r for r in rows if (r.file_name, r.field) not in settled]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Duyệt các trường nhãn còn lệch")
    parser.add_argument("--split", required=True, choices=["test", "validation", "train"])
    args = parser.parse_args(argv)

    label_path = LABEL_ROOT / args.split / "metadata.jsonl"
    review_csv, done_path = review_paths(args.split)
    records = load_metadata(label_path)
    by_name = {r.file_name: r for r in records}
    todo = pending_rows(read_review_csv(review_csv), read_settled(done_path))
    if not todo:
        print("Không còn trường nào cần duyệt.")
        return 0
    image_root = find_image_root((args.split, todo[0].file_name))
    print(f"Còn {len(todo)} trường. Enter = nhận Gemini, '-' = hóa đơn không có, "
          f"'o' = giữ nhãn cũ, gõ chữ = giá trị đúng, 'q' = lưu và thoát.")

    with open(done_path, "a", encoding="utf-8") as done:
        for i, row in enumerate(todo, start=1):
            read_image(image_root / args.split / row.file_name).show()
            print(f"\n[{i}/{len(todo)}] {row.file_name} - {row.field}")
            print(f"  nhãn cũ: {row.old!r}\n  Gemini : {row.gemini!r}\n  Qwen   : {row.qwen!r}")
            value = parse_answer(input("  > "), row)
            if value is None:
                break
            apply_answer(by_name[row.file_name], row.field, value)
            done.write(json.dumps({"file_name": row.file_name, "field": row.field, "value": value},
                                  ensure_ascii=False) + "\n")
            done.flush()
            dump_metadata(records, label_path)
    left = len(pending_rows(read_review_csv(review_csv), read_settled(done_path)))
    print(f"Đã lưu. Còn {left} trường chưa duyệt.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
