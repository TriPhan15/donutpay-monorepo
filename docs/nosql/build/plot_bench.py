#!/usr/bin/env python3
"""Charts of the benchmark results: docs/nosql/diagrams/bench_E1.png .. bench_E5.png (Vietnamese labels, <= 2000 px wide).

    python3 -m venv /tmp/venv && /tmp/venv/bin/pip install matplotlib==3.10.7
    /tmp/venv/bin/python docs/nosql/build/plot_bench.py [RAW_DIR] [OUT_DIR]

Reads the JSON that scripts/nosql/bench/run_all.sh wrote to docs/nosql/bench_raw/. Every bar is a measured p50 or p95 (log
scale, milliseconds, one thread, synthetic data); the numbers printed on the bars are the same figures as bench_results.md.
"""
import json
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
RAW = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "nosql", "bench_raw")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "nosql", "diagrams")
DPI = 150
FIG_W = 7.5  # inches; printed ~15 cm wide, so 9 pt text prints at ~7 pt

# colour-blind safe pair: blue = the design the app uses (index / cache / Redis / ES / embedded), vermillion = the baseline
BLUE, VERMILION, GREY = "#0072B2", "#D55E00", "#555555"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9.5, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.titleweight": "bold", "axes.titlesize": 13})


def load(name):
    with open(os.path.join(RAW, name), encoding="utf-8") as f:
        return json.load(f)


def fmt(v):
    if v < 0.1:
        return f"{v:.3f}".replace(".", ",")
    if v < 10:
        return f"{v:.2f}".replace(".", ",")
    return f"{v:.1f}".replace(".", ",")


def grouped(ax, groups, series, ylabel="Độ trễ (ms, thang log)"):
    """groups: list of labels; series: list of (name, colour, [(p50, p95)] per group)."""
    n = len(series)
    width = 0.8 / (n * 2)
    for si, (name, colour, values) in enumerate(series):
        for pi, (kind, alpha) in enumerate((("p50", 1.0), ("p95", 0.45))):
            xs = [gi + (si * 2 + pi - n + 0.5) * width for gi in range(len(groups))]
            ys = [v[pi] for v in values]
            bars = ax.bar(xs, ys, width * 0.95, color=colour, alpha=alpha, label=f"{name} ({kind})")
            for b, y in zip(bars, ys):
                ax.text(b.get_x() + b.get_width() / 2, y * 1.12, fmt(y), ha="center", va="bottom", fontsize=9, rotation=90)
    ax.set_yscale("log")
    ax.set_xticks(range(len(groups)))
    ax.set_xticklabels(groups)
    ax.set_ylabel(ylabel)
    ax.grid(axis="y", which="major", color="#DDDDDD", linewidth=0.8)
    ax.set_axisbelow(True)
    lo, hi = ax.get_ylim()
    ax.set_ylim(lo, hi * 4)


def finish(fig, name, note, ax=None, ncol=1, top=0.0):
    """Note at the bottom, legend (outside the axes) just above it, then tight_layout on the rest."""
    import textwrap
    r = fig.canvas.get_renderer()
    t = fig.text(0.01, 0.005, textwrap.fill(note, 70), fontsize=9, color=GREY, ha="left", va="bottom")
    fh = fig.get_size_inches()[1] * fig.dpi
    bottom = t.get_window_extent(r).height / fh + 0.012
    if ax is not None:
        h, l = [], []
        for a in (ax if isinstance(ax, (list, tuple)) else [ax]):
            for hh, ll in zip(*a.get_legend_handles_labels()):
                if ll not in l:
                    h.append(hh)
                    l.append(ll)
        lg = fig.legend(h, l, ncol=ncol, frameon=False, fontsize=9, loc="lower center", bbox_to_anchor=(0.5, bottom))
        bottom += lg.get_window_extent(r).height / fh + 0.01
    fig.tight_layout(rect=(0, bottom, 1, 1 - top))
    path = os.path.join(OUT, name)
    fig.savefig(path, dpi=DPI)
    plt.close(fig)
    print("wrote", path)


NOTE = "Dữ liệu tổng hợp (seed 42), 1 luồng, client trong cùng mạng docker; mỗi cột là một số đo thật (khởi động 200 lần, đo ≥ 1000 lần)."


def e1():
    d = load("E1.json")
    qs = ["Q-01", "Q-02", "Q-03"]
    labels = ["Q-01\ntransactionId", "Q-02\nđộ tin cậy < 0,75,\nmới nhất trước", "Q-03\nchưa xử lý,\nmới nhất trước"]
    fig, ax = plt.subplots(figsize=(FIG_W, 5.0))
    grouped(ax, labels, [
        ("không index (COLLSCAN)", VERMILION, [(d["scenarios"][f"{q}/noindex"]["p50_ms"], d["scenarios"][f"{q}/noindex"]["p95_ms"]) for q in qs]),
        ("có index (IXSCAN)", BLUE, [(d["scenarios"][f"{q}/indexed"]["p50_ms"], d["scenarios"][f"{q}/indexed"]["p95_ms"]) for q in qs]),
    ])
    ax.set_title("E1. MongoDB: có index và không index")
    finish(fig, "bench_E1.png", NOTE + " (100.000 ocr_logs, 45.471 ocr_feedbacks)", ax, 2)


def e2():
    d = load("E2.json")
    sc = d["scenarios"]
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(FIG_W, 5.0), gridspec_kw={"width_ratios": [1.1, 1]})
    groups = ["người dùng điển hình\n(~80 giao dịch)", f"người dùng nặng\n({d['heavy_user_rows']:,} giao dịch)".replace(",", ".")]
    grouped(a1, groups, [
        ("PostgreSQL LIKE", VERMILION, [(sc[f"{s}/postgres"]["p50_ms"], sc[f"{s}/postgres"]["p95_ms"]) for s in ("typical", "heavy")]),
        ("Elasticsearch", BLUE, [(sc[f"{s}/elasticsearch"]["p50_ms"], sc[f"{s}/elasticsearch"]["p95_ms"]) for s in ("typical", "heavy")]),
    ])
    a1.axhline(100, color=GREY, linestyle="--", linewidth=1)
    a1.text(0.02, 100 * 0.9, "NFR-03: ES p95 < 100 ms", fontsize=9, color=GREY, transform=a1.get_yaxis_transform(), va="top")
    a1.set_title("Độ trễ tìm kiếm")
    h = d["quality"]["heavy"]
    words = ["phở", "pho"]
    xs = range(2)
    w = 0.26
    series = (("PostgreSQL LIKE", "pg_total", VERMILION), ("Elasticsearch", "es_total", BLUE), ("Sự thật nền (đúng từ nguyên vẹn)", "truth", "#009E73"))
    top = max(h[x][k] for x in words for _, k, _ in series)
    for i, (lab, key, colour) in enumerate(series):
        vals = [h[x][key] for x in words]
        bars = a2.bar([x + (i - 1) * w for x in xs], vals, w * 0.95, color=colour, label=lab)
        for b_, v in zip(bars, vals):
            a2.text(b_.get_x() + b_.get_width() / 2, v + top * 0.01, f"{v:,.0f}".replace(",", "."), ha="center", va="bottom", fontsize=9)
    a2.set_xticks(list(xs))
    a2.set_xticklabels(["\"phở\" (có dấu)", "\"pho\" (không dấu)"])
    a2.set_ylabel("Số kết quả (người dùng nặng)")
    a2.set_title("Hai cách gõ một từ")
    a2.grid(axis="y", color="#DDDDDD", linewidth=0.8)
    a2.set_axisbelow(True)
    a2.set_ylim(0, top * 1.12)
    fig.suptitle("E2. Elasticsearch và PostgreSQL LIKE", fontweight="bold", fontsize=13)
    finish(fig, "bench_E2.png", NOTE + " ES (AUTO:4,7) không bỏ sót dòng nào của sự thật nền; phần dư của \"pho\" là tiền tố (\"phòng\"); AUTO:4,7 + prefix_length 1.", [a1, a2], 2, 0.05)


def e3():
    d = load("E3.json")
    s = d["scenarios"]
    fig, ax = plt.subplots(figsize=(FIG_W, 5.0))
    grouped(ax, ["top 10 tháng 2026-10"], [
        ("PostgreSQL sumExpensesByUserBetween", VERMILION, [(s["pg_sum_expenses_by_user"]["p50_ms"], s["pg_sum_expenses_by_user"]["p95_ms"])]),
        ("Redis ZREVRANGE 0 9 WITHSCORES", BLUE, [(s["redis_zrevrange_top10"]["p50_ms"], s["redis_zrevrange_top10"]["p95_ms"])]),
        ("Redis ZREVRANGE + tra tên (findAllById)", "#56B4E9", [(s["redis_zrevrange_plus_users_lookup"]["p50_ms"], s["redis_zrevrange_plus_users_lookup"]["p95_ms"])]),
        ("Redis Lua refresh (đường ghi)", "#009E73", [(s["redis_lua_refresh_member"]["p50_ms"], s["redis_lua_refresh_member"]["p95_ms"])]),
    ])
    ax.axhline(5, color=GREY, linestyle="--", linewidth=1)
    ax.text(0.99, 5 * 1.1, "mục tiêu NFR-06: p95 < 5 ms", fontsize=9, color=GREY, ha="right", transform=ax.get_yaxis_transform())
    ax.set_title("E3. Bảng xếp hạng top 10")
    finish(fig, "bench_E3.png", NOTE, ax)


def e4():
    d = load("E4.json")
    s = d["scenarios"]
    keys = ["dashboard", "popular_vendors", "admin_summary"]
    labels = ["Dashboard người dùng\n(3 câu SQL)", "Quán phổ biến\n(1 câu SQL)", "Tổng quan quản trị\n(5 câu SQL)"]
    fig, ax = plt.subplots(figsize=(FIG_W, 5.0))
    grouped(ax, labels, [
        ("SQL khi trượt cache", VERMILION, [(s[f"{k}/sql"]["p50_ms"], s[f"{k}/sql"]["p95_ms"]) for k in keys]),
        ("Redis GET", BLUE, [(s[f"{k}/redis_get"]["p50_ms"], s[f"{k}/redis_get"]["p95_ms"]) for k in keys]),
    ])
    for gi, k in enumerate(keys):
        ratio = s[f"{k}/sql"]["p50_ms"] / s[f"{k}/redis_get"]["p50_ms"]
        ax.text(gi, ax.get_ylim()[1] / 1.6, f"GET nhanh hơn {ratio:.0f}×", ha="center", fontsize=9.5, fontweight="bold")
    ax.axhline(5, color=GREY, linestyle="--", linewidth=1)
    ax.text(0.5, 5 * 1.1, "NFR-01: GET p95 < 5 ms", fontsize=9, color=GREY, ha="center", transform=ax.get_yaxis_transform())
    ax.set_title("E4. Có cache và không cache")
    finish(fig, "bench_E4.png", NOTE + " Trượt cache là cận dưới (xem bench_results.md).", ax, 2)


def e5():
    d = load("E5.json")
    s = d["scenarios"]
    labels = [f"A: mọi feedback seller_name\n({d['seller_name_feedbacks']:,} dòng)".replace(",", "."), "B: một người dùng\n(~15 dòng)"]
    fig, ax = plt.subplots(figsize=(FIG_W, 5.0))
    grouped(ax, labels, [
        ("$lookup Q-13 nguyên bản", VERMILION, [(s[f"{v}/reference"]["p50_ms"], s[f"{v}/reference"]["p95_ms"]) for v in ("A", "B")]),
        ("Q-13 sắp lại ($sort/$limit trước $lookup)", "#E69F00", [(s[f"{v}/reference_reordered"]["p50_ms"], s[f"{v}/reference_reordered"]["p95_ms"]) for v in ("A", "B")]),
        ("bản sao nhúng (cùng thứ tự Q-13)", BLUE, [(s[f"{v}/embedded"]["p50_ms"], s[f"{v}/embedded"]["p95_ms"]) for v in ("A", "B")]),
        ("bản sao nhúng sắp lại", "#56B4E9", [(s[f"{v}/embedded_reordered"]["p50_ms"], s[f"{v}/embedded_reordered"]["p95_ms"]) for v in ("A", "B")]),
    ])
    ax.set_title("E5. $lookup và bản sao nhúng")
    sz = d["sizes"]
    extra = (sz["ocr_feedbacks_embedded"]["size"] - sz["ocr_feedbacks"]["size"]) / 1e6
    finish(fig, "bench_E5.png", NOTE + f" A đo cái giá của $lookup đặt muộn; B là số so sánh công bằng. Bản nhúng thêm {str(round(extra, 1)).replace('.', ',')} MB dữ liệu trùng lặp.", ax)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in (e1, e2, e3, e4, e5):
        fn()
