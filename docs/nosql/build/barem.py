"""Bảng đối chiếu tiêu chí đánh giá (barem) của báo cáo NoSQL nhóm 38: in ra và kiểm tra.

Cách dùng (từ thư mục gốc repo): python3 docs/nosql/build/barem.py

Đọc BAREM_ROWS từ content_c7_c9.py (cùng bảng in ở mục 8.6 của báo cáo): mỗi dòng là
[tiêu chí / yêu cầu, mục trong báo cáo, minh chứng, trạng thái]. Trạng thái của các dòng có ảnh S-xx được tính lúc import
từ docs/nosql/screenshots (ảnh còn giữ chỗ). Không tính điểm: bảng chỉ cho biết minh chứng nằm ở đâu và còn thiếu gì.

Mã thoát 1 khi có dòng không có mục hoặc không có minh chứng (ô rỗng hoặc "–"), hoặc thiếu một trong các tiêu chí
1–10 (tiêu chí 10 phải đủ bốn ý a–d); 0 khi đủ.
"""
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load_rows():
    spec = importlib.util.spec_from_file_location("content_c7_c9", HERE / "content_c7_c9.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.BAREM_ROWS


def empty(cell):
    return not cell or not cell.strip() or cell.strip() in ("–", "-")


def main():
    rows = load_rows()
    problems = []
    for i, row in enumerate(rows, 1):
        if len(row) != 4:
            problems.append(f"dòng {i}: cần 4 cột, có {len(row)}")
            continue
        crit, section, evidence, status = row
        if empty(section):
            problems.append(f"dòng {i} ({crit}): không có mục trong báo cáo")
        if empty(evidence):
            problems.append(f"dòng {i} ({crit}): không có minh chứng")
        if empty(status):
            problems.append(f"dòng {i} ({crit}): không có trạng thái")

    names = [r[0] for r in rows]
    required = ["Tiêu chí 1:", "Tiêu chí 2:", "Tiêu chí 3:", "Tiêu chí 4:", "Tiêu chí 5–7:", "Tiêu chí 8:", "Tiêu chí 9",
                "Tiêu chí 10a:", "Tiêu chí 10b:", "Tiêu chí 10c:", "Tiêu chí 10d:"]
    for prefix in required:
        if not any(n.startswith(prefix) for n in names):
            problems.append(f"thiếu dòng {prefix.rstrip(':')}")

    width = max(len(r[0]) for r in rows)
    for crit, section, evidence, status in rows:
        print(f"{crit:<{width}} | {section:<16} | {status}")
        print(f"{'':<{width}} | {'':<16} |   minh chứng: {evidence}")
    waiting = [r for r in rows if r[3] not in ("Có", "Có minh chứng")]
    print(f"\n{len(rows)} dòng; {len(rows) - len(waiting)} dòng đủ minh chứng, {len(waiting)} dòng còn chờ "
          f"(ảnh giữ chỗ, việc của nhóm hoặc sản phẩm chưa có).")
    for p in problems:
        print("LỖI:", p)
    print("barem:", "LỖI" if problems else "đủ mục và minh chứng cho mọi dòng")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
