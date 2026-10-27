"""Input normalisation for /spade/analyze: typed transactions and ISO weeks."""
from __future__ import annotations

import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Dict, Iterable, List, Sequence, Tuple

from pydantic import BaseModel, Field

from local_time import parse_local_date

SAVINGS_CATEGORY = "Tiết kiệm"
MAX_TRANSACTIONS = 5000
MAX_CATEGORY_LENGTH = 64
MAX_AMOUNT = 1e12
MAX_DATE_LENGTH = 40
WINDOW_WEEKS = 26
MIN_WEEKS_WITH_DATA = 8


class TransactionIn(BaseModel):
    category: str = Field(min_length=1, max_length=MAX_CATEGORY_LENGTH)
    amount: float = Field(0.0, ge=0, le=MAX_AMOUNT)
    date: str = Field("", max_length=MAX_DATE_LENGTH)
    isExpense: bool = True


@dataclass(frozen=True)
class Expense:
    day: date
    category: str
    amount: float


@dataclass(frozen=True)
class Income:
    day: date
    amount: float


def _nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text.strip())


def is_savings(category: str) -> bool:
    return _nfc(category) == _nfc(SAVINGS_CATEGORY)


def expenses_from(txs: Iterable[TransactionIn]) -> List[Expense]:
    """Expenses only, without savings and unparseable dates, sorted by day."""
    out: List[Expense] = []
    for tx in txs:
        if not tx.isExpense or is_savings(tx.category):
            continue
        day = parse_local_date(tx.date)
        if day is None:
            continue
        out.append(Expense(day, _nfc(tx.category), float(tx.amount)))
    out.sort(key=lambda e: e.day)
    return out


def incomes_from(txs: Iterable[TransactionIn]) -> List[Income]:
    out: List[Income] = []
    for tx in txs:
        if tx.isExpense:
            continue
        day = parse_local_date(tx.date)
        if day is None:
            continue
        out.append(Income(day, float(tx.amount)))
    out.sort(key=lambda i: i.day)
    return out


def iso_week_label(day: date) -> str:
    year, week, _ = day.isocalendar()
    return f"{year}-W{week:02d}"


@dataclass(frozen=True)
class WeeklyDatabase:
    labels: List[str]
    sequences: List[List[Tuple[str, ...]]]
    spending_totals: Dict[str, float]
    expenses: List[Expense]


def weekly_database(
    expenses: Sequence[Expense], window_weeks: int = WINDOW_WEEKS
) -> WeeklyDatabase:
    """Group expenses into one sequence per ISO week inside the window.

    The window is [Monday of the latest expense's week - (window_weeks - 1)
    weeks, latest expense]. Each day is one sorted, de-duplicated itemset.

    Precondition for the miner: WCMSpade.mine counts every sequence passed in
    as a week in N (the lift denominator), so only weeks with at least one
    expense become sequences; empty weeks are never emitted. `labels` is the
    parallel list of week labels, ascending.
    """
    if not expenses:
        return WeeklyDatabase([], [], {}, [])
    latest = max(e.day for e in expenses)
    monday = latest - timedelta(days=latest.weekday())
    start = monday - timedelta(weeks=window_weeks - 1)
    in_window = sorted(
        (e for e in expenses if start <= e.day <= latest), key=lambda e: e.day
    )

    by_week: Dict[str, Dict[date, set]] = defaultdict(lambda: defaultdict(set))
    totals: Dict[str, float] = defaultdict(float)
    for e in in_window:
        by_week[iso_week_label(e.day)][e.day].add(e.category)
        totals[e.category] += e.amount

    labels = sorted(by_week)  # zero-padded ISO labels sort chronologically
    sequences = [
        [tuple(sorted(cats)) for _, cats in sorted(by_week[label].items())]
        for label in labels
    ]
    return WeeklyDatabase(labels, sequences, dict(totals), in_window)
