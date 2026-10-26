"""Vẽ Hình 4.x: đường loss huấn luyện và field_exact trên validation của DONUT V5.

Nguồn: ai-service/Version5/trainer_state.json (log_history của checkpoint-5600, Kaggle 25-26/10/2026).
Cách dùng: python3 plot_ch4.py  (cần matplotlib; ảnh lưu vào docs/thesis/diagrams/ch4_*.png)
"""
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FuncFormatter  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
STATE = ROOT / "ai-service/Version5/trainer_state.json"
OUT = ROOT / "docs/thesis/diagrams"
SERIES = "#2a78d6"
ACCENT = "#eb6834"
TEXT = "#0b0b0b"
MUTED = "#52514e"
GRID = "#d9d8d4"
WIDTH_IN = 16 / 2.54  # in ra đúng 16 cm trong Word
STEPS_PER_EPOCH = 6680 / 8

plt.rcParams.update({
    "font.family": "DejaVu Serif",
    "font.size": 10,
    "axes.edgecolor": MUTED,
    "axes.labelcolor": TEXT,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "axes.spines.top": False,
    "axes.spines.right": False,
})


def vn(x, decimals):
    return f"{x:.{decimals}f}".replace(".", ",")


def epoch_axis(ax):
    top = ax.secondary_xaxis("top", functions=(lambda s: s / STEPS_PER_EPOCH, lambda e: e * STEPS_PER_EPOCH))
    top.set_xlabel("Epoch", color=MUTED)
    top.tick_params(colors=MUTED)


def style(ax):
    ax.grid(axis="y", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)


def plot_loss(history):
    rows = [(e["step"], e["loss"]) for e in history if "loss" in e]
    steps, loss = zip(*rows)
    fig, ax = plt.subplots(figsize=(WIDTH_IN, 2.9), dpi=200)
    ax.plot(steps, loss, color=SERIES, linewidth=1.4)
    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: vn(v, 2) if v < 1 else vn(v, 0)))
    ax.set_xlabel("Bước huấn luyện (mỗi bước = 8 ảnh)")
    ax.set_ylabel("Loss (thang log)")
    ax.set_xlim(0, max(steps) + 100)
    ax.annotate(f"bước 20: {vn(loss[0], 2)}", (steps[0], loss[0]), xytext=(40, -4),
                textcoords="offset points", color=TEXT, fontsize=9, va="center")
    ax.annotate(f"bước {steps[-1]}: {vn(loss[-1], 4)}", (steps[-1], loss[-1]), xytext=(-10, 22),
                textcoords="offset points", color=TEXT, fontsize=9, ha="right",
                arrowprops=dict(arrowstyle="-", color=MUTED, linewidth=0.6))
    style(ax)
    epoch_axis(ax)
    fig.tight_layout()
    fig.savefig(OUT / "ch4_loss_v5.png")
    plt.close(fig)


def plot_val(history, best_step):
    rows = [(e["step"], e["eval_field_exact"]) for e in history if "eval_field_exact" in e]
    steps, exact = zip(*rows)
    fig, ax = plt.subplots(figsize=(WIDTH_IN, 2.9), dpi=200)
    ax.plot(steps, exact, color=SERIES, linewidth=1.6, marker="o", markersize=4.5,
            markeredgecolor="white", markeredgewidth=0.8)
    best = exact[steps.index(best_step)]
    ax.plot([best_step], [best], marker="o", markersize=8, color=ACCENT, markeredgecolor="white",
            markeredgewidth=1, zorder=3)
    ax.annotate(f"tốt nhất: bước {best_step}, {vn(best, 4)}", (best_step, best), xytext=(0, -18),
                textcoords="offset points", ha="center", color=TEXT, fontsize=9)
    ax.annotate(f"bước {steps[0]}: {vn(exact[0], 4)}", (steps[0], exact[0]), xytext=(10, 0),
                textcoords="offset points", va="center", color=TEXT, fontsize=9)
    ax.set_xlabel("Bước huấn luyện (đánh giá mỗi 400 bước)")
    ax.set_ylabel("field_exact trên validation")
    ax.set_ylim(0.70, 0.96)
    ax.set_xlim(0, max(steps) + 200)
    ax.set_xticks(steps[::2])
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: vn(v, 2)))
    style(ax)
    epoch_axis(ax)
    fig.tight_layout()
    fig.savefig(OUT / "ch4_val_field_exact_v5.png")
    plt.close(fig)


def main():
    state = json.loads(STATE.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    plot_loss(state["log_history"])
    plot_val(state["log_history"], state["best_global_step"])
    print("Đã lưu", OUT / "ch4_loss_v5.png", "và", OUT / "ch4_val_field_exact_v5.png")


if __name__ == "__main__":
    main()
