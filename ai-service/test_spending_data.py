import unicodedata
from datetime import date

import pytest
from pydantic import ValidationError

from local_time import parse_local_date
from spending_data import (
    Expense,
    Income,
    TransactionIn,
    expenses_from,
    incomes_from,
    iso_week_label,
    weekly_database,
)


@pytest.mark.parametrize(("raw", "expected"), [
    ("2026-10-28T12:00:00.000", date(2026, 10, 28)),
    ("2026-10-28", date(2026, 10, 28)),
    ("2026-10-27T18:30:00Z", date(2026, 10, 28)),
    ("2026-10-28T00:30:00+07:00", date(2026, 10, 28)),
    ("", None), ("hôm qua", None),
])
def test_parse_local_date(raw, expected):
    assert parse_local_date(raw) == expected


def test_utc_sunday_evening_is_local_monday_next_iso_week():
    d = parse_local_date("2026-10-25T18:30:00Z")
    assert d == date(2026, 10, 26) and iso_week_label(d) == "2026-W44"


def test_mixed_aware_and_naive_dates_never_raise():
    txs = [TransactionIn(category="Ăn uống", amount=1, date="2026-10-27T18:30:00Z"),
           TransactionIn(category="Ăn uống", amount=1, date="2026-10-20T08:00:00")]
    assert [e.day for e in expenses_from(txs)] == [date(2026, 10, 20), date(2026, 10, 28)]


def test_savings_income_and_bad_dates_are_left_out():
    txs = [TransactionIn(category=" Tiết kiệm ", amount=5, date="2026-10-01"),
           TransactionIn(category="Lương", amount=9, date="2026-10-01", isExpense=False),
           TransactionIn(category="Ăn uống", amount=2, date="xx"),
           TransactionIn(category="Ăn uống", amount=3, date="2026-10-02")]
    assert expenses_from(txs) == [Expense(date(2026, 10, 2), "Ăn uống", 3.0)]
    assert incomes_from(txs) == [Income(date(2026, 10, 1), 9.0)]


def _expenses_over_30_weeks_with_gaps():
    empty = {20, 22, 24, 26, 28, 30}
    out = []
    for wk in range(14, 44):  # W14..W43: 30 weeks
        if wk in empty:
            continue
        out.append(Expense(date.fromisocalendar(2026, wk, 3), "Ăn uống", 1.0))
    return out


def test_weekly_database_keeps_only_weeks_with_spending_inside_26_weeks():
    db = weekly_database(_expenses_over_30_weeks_with_gaps())
    assert db.labels[0] == "2026-W18" and db.labels[-1] == "2026-W43"
    assert len(db.labels) == 20
    assert len(db.sequences) == len(db.labels)
    assert all(e.day >= date.fromisocalendar(2026, 18, 1) for e in db.expenses)


def test_empty_expenses_give_empty_database():
    db = weekly_database([])
    assert db.labels == [] and db.sequences == [] and db.spending_totals == {}


def test_one_day_is_one_sorted_itemset_without_duplicates():
    db = weekly_database([Expense(date(2026, 10, 26), "B", 1), Expense(date(2026, 10, 26), "A", 1),
                          Expense(date(2026, 10, 26), "A", 2), Expense(date(2026, 10, 28), "C", 1)])
    assert db.sequences == [[("A", "B"), ("C",)]]
    assert db.spending_totals == {"A": 3.0, "B": 1.0, "C": 1.0}


def test_transaction_limits():
    with pytest.raises(ValidationError):
        TransactionIn(category="x" * 65, amount=1)
    with pytest.raises(ValidationError):
        TransactionIn(category="A", amount=-1)
    with pytest.raises(ValidationError):
        TransactionIn(category="A", amount=1e13)


def test_category_is_nfc_normalised_so_spellings_merge():
    composed = "Ăn uống"
    decomposed = unicodedata.normalize("NFD", composed)
    assert composed != decomposed
    txs = [TransactionIn(category=composed, amount=1, date="2026-10-20"),
           TransactionIn(category=decomposed, amount=1, date="2026-10-21")]
    assert {e.category for e in expenses_from(txs)} == {composed}
