"""Hợp đồng /spade/analyze: ghép dữ liệu tuần, WCM-SPADE, luật tuần tự và thói quen.

Mô-đun thuần (không import ai_service) để test không cần tải model.
"""
from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date
from enum import Enum
from typing import Dict, List, Sequence, Set

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel

from spending_data import (
    MIN_WEEKS_WITH_DATA,
    WINDOW_WEEKS,
    Expense,
    iso_week_label,
    weekly_database,
)
from spending_habits import periodic_habits
from wcm_spade import DEFAULT_MIN_SUP, WCMSpade, sequential_rules

logger = logging.getLogger(__name__)

DEFAULT_TOP_N = 10
MIN_PATTERN_ITEMS = 2
ALGORITHM_NAME = "WCM-SPADE"
FLOAT_DIGITS = 4
GAP_DIGITS = 1


class _CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class AnalysisStatus(str, Enum):
    OK = "OK"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"


# Trường chỉ dành cho APK trước đợt 3 (đọc chuỗi "A+B → C", số lần, tỷ lệ tuần); mobile mới không đọc.
LEGACY_PATTERN_FIELDS = ("pattern", "count", "wsupport")


class PatternOut(_CamelModel):
    itemsets: List[List[str]]
    support: int
    weight: float
    weighted_support: float
    weeks: List[str]
    pattern: str
    count: int
    wsupport: str


def _legacy_pattern_fields(itemsets: List[List[str]], support: int, weeks_with_data: int) -> dict:
    cover = support / weeks_with_data * 100 if weeks_with_data else 0.0
    return {
        "pattern": " → ".join("+".join(itemset) for itemset in itemsets),
        "count": support,
        "wsupport": f"{cover:.1f}%",
    }


class RuleOut(_CamelModel):
    antecedent: List[str]
    consequent: List[str]
    support: int
    antecedent_support: int
    confidence: float
    laplace_confidence: float
    lift: float
    weeks: List[str]


class HabitOut(_CamelModel):
    category: str
    occurrences: int
    mean_gap_days: float
    std_gap_days: float
    last_date: date
    next_expected_date: date


class CategoryOut(_CamelModel):
    category: str
    total: float
    share: float
    weeks: int


class AnalysisMeta(_CamelModel):
    algorithm: str = ALGORITHM_NAME
    weeks_with_data: int
    min_weeks: int
    window_weeks: int
    min_support: float
    raw_support_bound: int
    max_weight: float


class SpadeAnalyzeResponse(_CamelModel):
    status: AnalysisStatus
    patterns: List[PatternOut]
    rules: List[RuleOut]
    habits: List[HabitOut]
    categories: List[CategoryOut]
    meta: AnalysisMeta


def _round(value: float) -> float:
    return round(value, FLOAT_DIGITS)


def _categories(expenses: Sequence[Expense]) -> List[CategoryOut]:
    totals: Dict[str, float] = defaultdict(float)
    weeks: Dict[str, Set[str]] = defaultdict(set)
    for e in expenses:
        totals[e.category] += e.amount
        weeks[e.category].add(iso_week_label(e.day))
    grand = sum(totals.values())
    ordered = sorted(totals, key=lambda c: (-totals[c], c))
    return [
        CategoryOut(
            category=c,
            total=_round(totals[c]),
            share=_round(totals[c] / grand) if grand > 0 else 0.0,
            weeks=len(weeks[c]),
        )
        for c in ordered
    ]


def _habits(expenses: Sequence[Expense], top_n: int) -> List[HabitOut]:
    return [
        HabitOut(
            category=h.category,
            occurrences=h.occurrences,
            mean_gap_days=round(h.mean_gap_days, GAP_DIGITS),
            std_gap_days=round(h.std_gap_days, GAP_DIGITS),
            last_date=h.last_date,
            next_expected_date=h.next_expected_date,
        )
        for h in periodic_habits(expenses)[:top_n]
    ]


def analyze_spending(
    expenses: Sequence[Expense],
    top_n: int = DEFAULT_TOP_N,
    min_sup: float = DEFAULT_MIN_SUP,
) -> SpadeAnalyzeResponse:
    """Phân tích chi tiêu (CPU-bound, đồng bộ). Khoản chi đã loại tiết kiệm."""
    db = weekly_database(expenses)
    weeks_with_data = len(db.labels)
    categories = _categories(db.expenses)
    habits = _habits(db.expenses, top_n)

    patterns: List[PatternOut] = []
    rules: List[RuleOut] = []
    raw_bound = 0
    max_weight = 0.0
    if weeks_with_data >= MIN_WEEKS_WITH_DATA:
        result = WCMSpade(min_sup=min_sup).mine(db.sequences, db.spending_totals)
        raw_bound, max_weight = result.raw_bound, result.max_weight
        if result.truncated:
            logger.warning("WCM-SPADE bị cắt do giới hạn số mẫu")
        mined = [p for p in result.patterns if p.item_count() >= MIN_PATTERN_ITEMS]
        mined.sort(key=lambda p: -p.wsup)  # sort ổn định: giữ thứ hạng gốc khi bằng nhau
        patterns = [
            PatternOut(
                itemsets=[list(itemset) for itemset in p.itemsets],
                support=p.raw_sup,
                weight=_round(p.weight),
                weighted_support=_round(p.wsup),
                weeks=[db.labels[sid] for sid in p.sids],
                **_legacy_pattern_fields(p.itemsets, p.raw_sup, weeks_with_data),
            )
            for p in mined[:top_n]
        ]
        rules = [
            RuleOut(
                antecedent=list(r.antecedent),
                consequent=list(r.consequent),
                support=r.support,
                antecedent_support=r.antecedent_support,
                confidence=_round(r.confidence),
                laplace_confidence=_round(r.laplace_confidence),
                lift=_round(r.lift),
                weeks=[db.labels[sid] for sid in r.sids],
            )
            for r in sequential_rules(result)[:top_n]
        ]

    logger.info(
        "spade/analyze: %d khoản chi, %d tuần, %d luật",
        len(db.expenses), weeks_with_data, len(rules),
    )
    return SpadeAnalyzeResponse(
        status=AnalysisStatus.OK if weeks_with_data >= MIN_WEEKS_WITH_DATA
        else AnalysisStatus.INSUFFICIENT_DATA,
        patterns=patterns,
        rules=rules,
        habits=habits,
        categories=categories,
        meta=AnalysisMeta(
            weeks_with_data=weeks_with_data,
            min_weeks=MIN_WEEKS_WITH_DATA,
            window_weeks=WINDOW_WEEKS,
            min_support=min_sup,
            raw_support_bound=raw_bound,
            max_weight=_round(max_weight),
        ),
    )
