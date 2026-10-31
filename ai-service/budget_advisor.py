"""Budget advice from full calendar months of income and spending (no pattern mining)."""
from __future__ import annotations

from collections import defaultdict
from datetime import date
from typing import FrozenSet, List, Literal, Optional, Sequence, Tuple

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel

from local_time import local_today
from spending_data import TransactionIn, count_undated, expenses_from, incomes_from

# Must match essentialExpenses in mobile-app/lib/core/constants/transaction_categories.dart
# (the DefaultCategory names core-backend stores).
ESSENTIAL_CATEGORIES: FrozenSet[str] = frozenset({
    "Ăn uống", "Siêu thị & Chợ", "Di chuyển", "Nhà ở", "Điện nước",
    "Internet & Điện thoại", "Sức khỏe", "Giáo dục", "Gia đình & Con cái", "Bảo hiểm",
})
DISCRETIONARY_CATEGORIES: FrozenSet[str] = frozenset({"Mua sắm", "Giải trí", "Du lịch", "Hiếu hỉ"})

MAX_CUT_RATIO = 0.30
ESSENTIAL_CUT_RATIO = 0.10
LIGHT_CUT_RATIO = 0.10
DISCRETIONARY_SHARE_ALERT = 15
ADVICE_MAX_MONTHS = 6

NO_EXPENSE_MESSAGE = "Không có giao dịch chi để phân tích."
NOT_ENOUGH_HISTORY_MESSAGE = "Cần ít nhất một tháng chi tiêu trọn vẹn để AI đưa ra lời khuyên."
NO_DEADLINE_PREFIX = "Mục tiêu chưa có hạn nên AI không tính số cần góp mỗi tháng."
ADVICE_FAILED_MESSAGE = "AI chưa thể đưa ra lời khuyên cho dữ liệu này."
# Các câu AdviceError được phép trả nguyên văn cho app; câu khác bị thay bằng ADVICE_FAILED_MESSAGE.
ADVICE_ERROR_MESSAGES: FrozenSet[str] = frozenset({NO_EXPENSE_MESSAGE, NOT_ENOUGH_HISTORY_MESSAGE})


class AdviceError(ValueError):
    """The request cannot be advised on; the message is one of the fixed texts above."""


class _CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


# Response của /spade/recommend: tên field (camelCase) giữ đúng như dict advise() trả về, app mobile đang đọc chúng.
class TagStatOut(_CamelModel):
    tag: str
    monthly_avg: int
    share: float
    type: Literal["essential", "discretionary", "neutral"]


class GoalOut(_CamelModel):
    needed_monthly: int
    monthly_income: int
    monthly_expense: int
    surplus: int
    gap: int
    has_deadline: bool


class RecommendationOut(_CamelModel):
    tag: str
    current: int
    suggested: int
    delta: int
    action: str
    reason: str


class AdviceMeta(_CamelModel):
    n_months: int
    first_month: str
    last_month: str
    # Số giao dịch bị bỏ vì ngày không đọc được (spending_data.count_undated).
    skipped_rows: int = 0


class RecommendResponse(_CamelModel):
    tag_stats: List[TagStatOut]
    goal: GoalOut
    recommendations: List[RecommendationOut]
    summary: str
    meta: AdviceMeta


def classify(category: str) -> Literal["essential", "discretionary", "neutral"]:
    name = category.strip()
    if name in ESSENTIAL_CATEGORIES:
        return "essential"
    if name in DISCRETIONARY_CATEGORIES:
        return "discretionary"
    return "neutral"


def full_months(first_day: date, today: date,
                max_months: int = ADVICE_MAX_MONTHS) -> List[Tuple[int, int]]:
    """Calendar months fully covered by data: after a partial first month, before the current one.

    A first day other than the 1st means that month started before the data did.
    Keeps the latest `max_months`.
    """
    idx = first_day.year * 12 + first_day.month - 1
    if first_day.day != 1:
        idx += 1
    end = today.year * 12 + today.month - 1  # exclusive: the current month is partial
    months = [(i // 12, i % 12 + 1) for i in range(idx, end)]
    return months[-max_months:]


def _fmt(val: float) -> str:
    return f"{int(val):,}".replace(",", ".")


def advise(
    transactions: Sequence[TransactionIn],
    target: float = 0.0,
    current: float = 0.0,
    months_left: Optional[int] = None,
    monthly_income: Optional[float] = None,
    needed_monthly: Optional[float] = None,
    today: Optional[date] = None,
) -> dict:
    today = today or local_today()
    expenses = expenses_from(transactions)
    incomes = incomes_from(transactions)
    if not expenses:
        raise AdviceError(NO_EXPENSE_MESSAGE)

    first_day = min([e.day for e in expenses] + [i.day for i in incomes])
    # Chỉ các tháng trọn vẹn có ít nhất một khoản chi: tháng trống ở giữa không được tính là chi 0đ,
    # nếu không một giao dịch lẻ từ lâu sẽ chia nhỏ chi tiêu thật và thổi phồng phần dư.
    expense_months = {(e.day.year, e.day.month) for e in expenses}
    months = [m for m in full_months(first_day, today) if m in expense_months]
    month_set = set(months)
    exp = [e for e in expenses if (e.day.year, e.day.month) in month_set]
    if not months or not exp:
        raise AdviceError(NOT_ENOUGH_HISTORY_MESSAGE)
    n_months = len(months)

    tag_total = defaultdict(float)
    for e in exp:
        tag_total[e.category] += e.amount
    tag_monthly = {t: v / n_months for t, v in tag_total.items()}
    total_monthly_exp = sum(tag_monthly.values())
    share_base = total_monthly_exp or 1.0

    tag_stats = [
        {
            "tag": t,
            "monthlyAvg": round(m),
            "share": round(m / share_base * 100, 1),
            "type": classify(t),
        }
        for t, m in sorted(tag_monthly.items(), key=lambda kv: kv[1], reverse=True)
    ]

    # Không có mục tiêu (target = 0) thì không có hạn và không cần góp gì, dù request có months_left/needed_monthly.
    has_target = target > 0
    has_deadline = has_target and (months_left is not None or needed_monthly is not None)
    if not has_target:
        needed_monthly = 0.0
    elif needed_monthly is None:
        if months_left is not None and months_left > 0:
            needed_monthly = max(target - current, 0.0) / months_left
        else:
            needed_monthly = 0.0
            has_deadline = False

    if monthly_income is None:
        income_total = sum(i.amount for i in incomes if (i.day.year, i.day.month) in month_set)
        monthly_income = income_total / n_months
    surplus = monthly_income - total_monthly_exp
    gap = needed_monthly - surplus

    remaining_gap = gap
    recommendations = []
    prefix = "" if has_deadline else NO_DEADLINE_PREFIX + " "

    if gap <= 0:
        summary = (f"Thặng dư {_fmt(surplus)}đ/tháng ≥ cần {_fmt(needed_monthly)}đ/tháng. "
                   f"Đang đúng hướng — duy trì và đẩy phần dư vào tiết kiệm.")
        for s in tag_stats:
            if s["type"] == "discretionary" and s["share"] >= DISCRETIONARY_SHARE_ALERT:
                cut = round(s["monthlyAvg"] * LIGHT_CUT_RATIO)
                recommendations.append({
                    "tag": s["tag"], "current": s["monthlyAvg"],
                    "suggested": s["monthlyAvg"] - cut, "delta": -cut,
                    "action": "giảm nhẹ",
                    "reason": f"Mục tùy ý chiếm {s['share']}% — cắt 10% để dư thêm.",
                })
    else:
        for group in ("discretionary", "neutral", "essential"):
            pool = [s for s in tag_stats if s["type"] == group and s["monthlyAvg"] > 0]
            pool_total = sum(s["monthlyAvg"] for s in pool)
            if pool_total <= 0 or remaining_gap <= 0:
                continue
            ratio_cap = ESSENTIAL_CUT_RATIO if group == "essential" else MAX_CUT_RATIO
            label = {"discretionary": "Mục tùy ý", "essential": "Mục thiết yếu"}.get(group, "Mục linh hoạt")
            for s in pool:
                if remaining_gap <= 0:
                    break
                want = remaining_gap * (s["monthlyAvg"] / pool_total)
                cut = round(min(s["monthlyAvg"] * ratio_cap, want))
                if cut <= 0:
                    continue
                recommendations.append({
                    "tag": s["tag"], "current": s["monthlyAvg"],
                    "suggested": s["monthlyAvg"] - cut, "delta": -cut,
                    "action": "cắt giảm",
                    "reason": f"{label}, chiếm {s['share']}% chi tiêu.",
                })
                remaining_gap -= cut

        total_cut = sum(-r["delta"] for r in recommendations)
        if remaining_gap > 0:
            summary = (f"Cần tiết kiệm {_fmt(needed_monthly)}đ/tháng, thiếu {_fmt(gap)}đ. "
                       f"Đề xuất cắt được {_fmt(total_cut)}đ, vẫn thiếu {_fmt(remaining_gap)}đ - "
                       f"cân nhắc tăng thu nhập hoặc giãn hạn mục tiêu.")
        else:
            summary = (f"Cần tiết kiệm {_fmt(needed_monthly)}đ/tháng, thiếu {_fmt(gap)}đ. "
                       f"Đề xuất cắt tổng {_fmt(total_cut)}đ từ các mục dưới → đủ đạt mục tiêu.")

    return {
        "tagStats": tag_stats,
        "goal": {
            "neededMonthly": round(needed_monthly),
            "monthlyIncome": round(monthly_income),
            "monthlyExpense": round(total_monthly_exp),
            "surplus": round(surplus),
            "gap": round(gap),
            "hasDeadline": has_deadline,
        },
        "recommendations": recommendations,
        "summary": prefix + summary,
        "meta": {
            "nMonths": n_months,
            "firstMonth": f"{months[0][0]}-{months[0][1]:02d}",
            "lastMonth": f"{months[-1][0]}-{months[-1][1]:02d}",
            "skippedRows": count_undated(transactions),
        },
    }
