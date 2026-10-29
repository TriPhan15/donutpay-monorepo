"""Input normalisation for /spade/analyze: typed transactions and ISO weeks."""
from __future__ import annotations

import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

from local_time import local_today, parse_local_date

SAVINGS_CATEGORY = "Tiết kiệm"
MAX_TRANSACTIONS = 5000
MAX_CATEGORY_LENGTH = 255  # backend category name is varchar(255)
MAX_AMOUNT = 1e12
MAX_DATE_LENGTH = 40
WINDOW_WEEKS = 26
MIN_WEEKS_WITH_DATA = 8
# Expenses dated later than local today + this many days are ignored (clock skew).
FUTURE_TOLERANCE_DAYS = 1


class TransactionIn(BaseModel):
    category: Annotated[str, StringConstraints(
        strip_whitespace=True, min_length=1, max_length=MAX_CATEGORY_LENGTH)]
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


def count_undated(txs: Iterable[TransactionIn]) -> int:
    """Số giao dịch có ngày không đọc được, bị expenses_from/incomes_from bỏ qua.

    Không trả 422 cho các dòng này vì APK cũ có thể đang gửi dữ liệu như vậy; số dòng bị bỏ được trả trong ``meta``
    để app (và log) biết vì sao kết quả có thể là "không đủ dữ liệu".
    """
    return sum(1 for tx in txs if parse_local_date(tx.date) is None)


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
    expenses: Sequence[Expense],
    window_weeks: int = WINDOW_WEEKS,
    today: Optional[date] = None,
) -> WeeklyDatabase:
    """Group expenses into one sequence per ISO week inside the window.

    Expenses dated after local today + FUTURE_TOLERANCE_DAYS are dropped first,
    so a mistyped future date can neither anchor the window nor be mined.
    The window is [Monday of the latest remaining expense's week -
    (window_weeks - 1) weeks, latest expense]. Each day is one sorted,
    de-duplicated itemset.

    Precondition for the miner: WCMSpade.mine counts every sequence passed in
    as a week in N (the lift denominator), so only weeks with at least one
    expense become sequences; empty weeks are never emitted. `labels` is the
    parallel list of week labels, ascending.
    """
    last_allowed = (today or local_today()) + timedelta(days=FUTURE_TOLERANCE_DAYS)
    expenses = [e for e in expenses if e.day <= last_allowed]
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
