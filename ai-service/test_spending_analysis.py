"""Test spending_analysis.analyze_spending (không import ai_service)."""
import re
from datetime import date, timedelta
from typing import List

from spending_analysis import LEGACY_PATTERN_FIELDS, MIN_PATTERN_ITEMS, analyze_spending
from spending_data import Expense
from test_spade_rules import _planted_weeks

FIRST_MONDAY = date(2026, 1, 5)
DAYS_PER_WEEK = 7


def _expenses_in_weeks(n: int) -> List[Expense]:
    return [
        Expense(FIRST_MONDAY + timedelta(days=DAYS_PER_WEEK * w), cat, 1000.0)
        for w in range(n)
        for cat in ("Ăn uống", "Đi lại")
    ]


def _planted_expenses() -> List[Expense]:
    out: List[Expense] = []
    for w, week in enumerate(_planted_weeks()):
        for d, itemset in enumerate(week):
            day = FIRST_MONDAY + timedelta(days=DAYS_PER_WEEK * w + d)
            out.extend(Expense(day, item, 1000.0) for item in itemset)
    return out


def test_fewer_than_eight_weeks_is_insufficient_but_describes_spending():
    out = analyze_spending(_expenses_in_weeks(7)).model_dump(by_alias=True)
    assert out["status"] == "INSUFFICIENT_DATA"
    assert out["patterns"] == [] and out["rules"] == []
    assert out["categories"] and out["meta"]["weeksWithData"] == 7 and out["meta"]["minWeeks"] == 8
    assert out["meta"]["rawSupportBound"] == 0 and out["meta"]["maxWeight"] == 0


def test_planted_rule_reaches_the_response_with_week_labels():
    out = analyze_spending(_planted_expenses()).model_dump(by_alias=True)
    assert out["status"] == "OK"
    rule = next(r for r in out["rules"] if r["antecedent"] == ["A"] and r["consequent"] == ["B"])
    assert (rule["support"], rule["antecedentSupport"]) == (12, 16)
    assert len(rule["weeks"]) == 12 and all(re.fullmatch(r"\d{4}-W\d{2}", w) for w in rule["weeks"])


def test_patterns_are_structured_and_have_at_least_two_items():
    out = analyze_spending(_planted_expenses()).model_dump(by_alias=True)
    assert out["patterns"]
    for p in out["patterns"]:
        assert isinstance(p["itemsets"][0], list)
        assert sum(len(i) for i in p["itemsets"]) >= MIN_PATTERN_ITEMS
        structured = {k: v for k, v in p.items() if k not in LEGACY_PATTERN_FIELDS}
        assert "→" not in str(structured) and "+" not in "".join(sum(p["itemsets"], []))
    ws = [p["weightedSupport"] for p in out["patterns"]]
    assert ws == sorted(ws, reverse=True)


def test_patterns_carry_legacy_fields_for_old_apk():
    out = analyze_spending(_planted_expenses()).model_dump(by_alias=True)
    weeks = out["meta"]["weeksWithData"]
    assert out["patterns"]
    for p in out["patterns"]:
        assert p["pattern"] == " → ".join("+".join(i) for i in p["itemsets"])
        assert p["count"] == p["support"]
        assert p["wsupport"] == f"{p['support'] / weeks * 100:.1f}%"
        assert {"itemsets", "weightedSupport", "weeks"} <= p.keys()


def test_top_n_caps_patterns_rules_and_habits():
    wide = analyze_spending(_planted_expenses(), top_n=50)
    assert len(wide.patterns) > 1 and len(wide.habits) > 1 and len(wide.rules) >= 1
    one = analyze_spending(_planted_expenses(), top_n=1)
    assert len(one.patterns) == len(one.rules) == len(one.habits) == 1


def test_empty_input_is_insufficient_with_zero_weeks():
    out = analyze_spending([]).model_dump(by_alias=True)
    assert out["status"] == "INSUFFICIENT_DATA"
    assert out["meta"]["weeksWithData"] == 0
    assert out["categories"] == [] and out["habits"] == []
    assert out["meta"]["algorithm"] == "WCM-SPADE"


def test_categories_report_share_total_and_weeks():
    out = analyze_spending(_expenses_in_weeks(3)).model_dump(by_alias=True)
    assert out["categories"][0] == {"category": "Ăn uống", "total": 3000.0, "share": 0.5, "weeks": 3}
