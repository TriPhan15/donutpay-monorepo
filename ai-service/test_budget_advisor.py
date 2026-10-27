from datetime import date

import pytest

import budget_advisor
from budget_advisor import (
    ESSENTIAL_CATEGORIES, ESSENTIAL_CUT_RATIO, MAX_CUT_RATIO, NOT_ENOUGH_HISTORY_MESSAGE,
    NO_DEADLINE_PREFIX, NO_EXPENSE_MESSAGE, AdviceError, advise, classify, full_months,
)
from spending_data import TransactionIn

TODAY = date(2026, 10, 15)


def _exp(cat, amount, day):
    return TransactionIn(category=cat, amount=amount, date=day, isExpense=True)


def _inc(amount, day):
    return TransactionIn(category="Lương", amount=amount, date=day, isExpense=False)


def _two_full_months():
    return [_exp("Ăn uống", 3_000_000, "2026-08-01"), _exp("Mua sắm", 2_000_000, "2026-08-09"),
            _exp("Khác", 1_000_000, "2026-09-05"), _exp("Giải trí", 2_000_000, "2026-09-09"),
            _exp("Ăn uống", 3_000_000, "2026-09-12"), _inc(6_000_000, "2026-09-01")]


def test_essential_set_matches_mobile():
    assert ESSENTIAL_CATEGORIES == {"Ăn uống", "Siêu thị & Chợ", "Di chuyển", "Nhà ở", "Điện nước",
                                    "Internet & Điện thoại", "Sức khỏe", "Giáo dục",
                                    "Gia đình & Con cái", "Bảo hiểm"}


@pytest.mark.parametrize(("name", "kind"), [
    ("Ăn uống", "essential"), (" Bảo hiểm ", "essential"), ("Mua sắm", "discretionary"),
    ("Hiếu hỉ", "discretionary"), ("Khác", "neutral"), ("an uong", "neutral"),
    ("Cà phê", "neutral")])
def test_classify_by_default_category_names(name, kind):
    assert classify(name) == kind


def test_full_months_skip_partial_first_and_current_month():
    assert full_months(date(2026, 8, 20), TODAY) == [(2026, 9)]
    assert full_months(date(2026, 8, 1), TODAY) == [(2026, 8), (2026, 9)]
    assert full_months(date(2025, 1, 1), TODAY) == [(2026, m) for m in range(4, 10)]


def test_income_and_expense_share_one_span():
    out = advise([_exp("Ăn uống", 2_000_000, "2026-08-01"), _exp("Ăn uống", 4_000_000, "2026-09-10"),
                  _inc(10_000_000, "2026-09-05"), _exp("Mua sắm", 9_000_000, "2026-10-02")],
                 today=TODAY)
    assert out["goal"]["monthlyExpense"] == 3_000_000 and out["goal"]["monthlyIncome"] == 5_000_000
    assert out["meta"] == {"nMonths": 2, "firstMonth": "2026-08", "lastMonth": "2026-09"}


def test_only_current_month_raises_not_enough_history():
    with pytest.raises(AdviceError, match=NOT_ENOUGH_HISTORY_MESSAGE):
        advise([_exp("Ăn uống", 1, "2026-10-02")], today=TODAY)


def test_no_expense_raises():
    with pytest.raises(AdviceError, match=NO_EXPENSE_MESSAGE):
        advise([], today=TODAY)
    with pytest.raises(AdviceError, match=NO_EXPENSE_MESSAGE):
        advise([_inc(1, "2026-09-02")], today=TODAY)


def test_no_deadline_needs_nothing_monthly():
    out = advise(_two_full_months(), target=300_000_000, current=0, today=TODAY)
    assert out["goal"]["neededMonthly"] == 0 and out["goal"]["hasDeadline"] is False
    assert out["summary"].startswith(NO_DEADLINE_PREFIX)


def test_deadline_computes_needed_monthly():
    out = advise(_two_full_months(), target=12_000_000, current=0, months_left=6, today=TODAY)
    assert out["goal"]["neededMonthly"] == 2_000_000 and out["goal"]["hasDeadline"] is True


def test_cuts_are_capped_and_never_negative():
    out = advise(_two_full_months(), target=10**9, current=0, months_left=1, today=TODAY)
    assert out["recommendations"]
    for r in out["recommendations"]:
        cap = ESSENTIAL_CUT_RATIO if classify(r["tag"]) == "essential" else MAX_CUT_RATIO
        assert r["suggested"] >= 0 and -r["delta"] <= round(r["current"] * cap) + 1


def test_savings_rows_are_not_spending():
    out = advise(_two_full_months() + [_exp("Tiết kiệm", 5_000_000, "2026-09-20")], today=TODAY)
    assert "Tiết kiệm" not in [s["tag"] for s in out["tagStats"]]
    assert out["goal"]["monthlyExpense"] == 5_500_000


def test_advisor_no_longer_mines_patterns():
    assert not hasattr(budget_advisor, "WCMSpade")
    assert "trends" not in advise(_two_full_months(), today=TODAY)
