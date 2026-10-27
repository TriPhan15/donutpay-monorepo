import statistics
from datetime import date

import pytest

from spending_data import Expense
from spending_habits import periodic_habits


def _ex(cat, *days):
    return [Expense(d, cat, 1) for d in days]


def test_gap_statistics_and_next_date():
    days = [date(2026, 10, 1), date(2026, 10, 8), date(2026, 10, 14), date(2026, 10, 21)]
    h = periodic_habits(_ex("Siêu thị & Chợ", *days))[0]
    assert (h.occurrences, h.mean_gap_days) == (4, pytest.approx(20 / 3))
    assert h.std_gap_days == pytest.approx(statistics.pstdev([7, 6, 7]))
    assert h.next_expected_date == date(2026, 10, 28)


def test_fewer_than_three_occurrences_is_not_a_habit():
    assert periodic_habits(_ex("A", date(2026, 10, 1), date(2026, 10, 8))) == []


def test_same_day_purchases_count_once():
    ex = _ex("A", date(2026, 10, 1), date(2026, 10, 1), date(2026, 10, 8))
    assert periodic_habits(ex) == []


def test_most_regular_habit_first():
    ex = (_ex("Lệch", date(2026, 10, 1), date(2026, 10, 2), date(2026, 10, 12))
          + _ex("Đều", date(2026, 10, 1), date(2026, 10, 8), date(2026, 10, 15)))
    assert [h.category for h in periodic_habits(ex)] == ["Đều", "Lệch"]
