"""Periodic spending habits from per-category gaps between purchase days.

References:
- Tanbeer, Ahmed, Jeong, Lee (2009). Discovering periodic-frequent patterns in
  transactional databases. PAKDD. DOI 10.1007/978-3-642-01307-2_24.
  (CHƯA KIỂM CHỨNG)
- PFPM, Fournier-Viger et al. (2017), "PFPM: Discovering periodic frequent
  patterns with novel periodicity measures": periodicity statistics over the
  gaps between occurrences; here the 1-itemset special case (one category).
  (CHƯA KIỂM CHỨNG)
- Plaid Transactions API: a recurring stream becomes MATURE only with at
  least 3 transactions, hence MIN_OCCURRENCES = 3. (CHƯA KIỂM CHỨNG)

MAX_GAP_CV is a design choice of this project, not a published value: a
category whose gap coefficient of variation (std/mean) exceeds 0.5 buys too
irregularly to be called a habit.
"""
from __future__ import annotations

import statistics
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Dict, List, Sequence, Set

from spending_data import Expense

MIN_OCCURRENCES = 3
# Coefficient of variation of the gaps (std/mean) above which there is no habit.
MAX_GAP_CV = 0.5


@dataclass(frozen=True)
class PeriodicHabit:
    category: str
    occurrences: int
    mean_gap_days: float
    std_gap_days: float
    last_date: date
    next_expected_date: date


def periodic_habits(
    expenses: Sequence[Expense], min_occurrences: int = MIN_OCCURRENCES
) -> List[PeriodicHabit]:
    """Habits ordered by (std/mean, -occurrences, category): most regular first.

    Occurrences are distinct purchase days per category; gaps are in days.
    Categories whose gap std/mean exceeds ``MAX_GAP_CV`` are not returned.
    """
    days_by_cat: Dict[str, Set[date]] = defaultdict(set)
    for e in expenses:
        days_by_cat[e.category].add(e.day)

    habits: List[PeriodicHabit] = []
    for category, days in days_by_cat.items():
        if len(days) < max(min_occurrences, 2):
            continue
        ordered = sorted(days)
        gaps = [(b - a).days for a, b in zip(ordered, ordered[1:])]
        mean = statistics.mean(gaps)
        std = statistics.pstdev(gaps)
        if std / mean > MAX_GAP_CV:
            continue
        habits.append(PeriodicHabit(
            category=category,
            occurrences=len(ordered),
            mean_gap_days=mean,
            std_gap_days=std,
            last_date=ordered[-1],
            next_expected_date=ordered[-1] + timedelta(days=round(mean)),
        ))
    habits.sort(key=lambda h: (h.std_gap_days / h.mean_gap_days, -h.occurrences, h.category))
    return habits
