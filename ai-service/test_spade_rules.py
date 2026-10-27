"""Test luật tuần tự trên WCM-SPADE: confidence, Laplace, lift và dữ liệu cấy mẫu.

Dữ liệu cấy (26 tuần, tất định):
- "A" ở 16 tuần (thứ 2–3); 12 tuần trong đó có "B" sau A (thứ 5–6); "B" còn ở 3
  tuần không có A. Kỳ vọng A⇒B: support 12/16, conf 0,75, lift 0,75 / (15/26).
- "C" ở 16 tuần; "D" ở 8/16 tuần có C (luôn sau C) và 5/10 tuần không có C, nên
  conf(C⇒D) = 0,5 = P(D) = 13/26: cặp độc lập, lift 1,0.
- "E" ở cả 26 tuần, ngày cuối tuần.
- Nhiễu "N1".."N3" rải bằng ``random.Random(7)``.
"""

import random
from typing import Dict, List, Optional, Tuple

import pytest

from wcm_spade import (
    MIN_ANTECEDENT_SUPPORT,
    MIN_LAPLACE_CONFIDENCE,
    MIN_LIFT,
    SequentialRule,
    WCMSpade,
    sequential_rules,
)

Itemset = Tuple[str, ...]
Week = List[Itemset]

N_WEEKS = 26
DAYS_PER_WEEK = 7
NOISE_SEED = 7
NOISE_ITEMS = ("N1", "N2", "N3")
NOISE_PROBABILITY = 0.3

A_WEEKS = range(0, 16)
A_THEN_B_WEEKS = range(0, 12)
B_ONLY_WEEKS = (16, 17, 18)
C_WEEKS = tuple(range(0, 8)) + tuple(range(16, 24))
D_WITH_C_WEEKS = (0, 1, 2, 3, 16, 17, 18, 19)
D_WITHOUT_C_WEEKS = (8, 9, 10, 24, 25)

MONDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY = 0, 2, 3, 4, 5, 6


def _planted_weeks() -> List[Week]:
    rng = random.Random(NOISE_SEED)
    weeks: List[Week] = []
    for week in range(N_WEEKS):
        days: Dict[int, set] = {}

        def put(day: int, item: str) -> None:
            days.setdefault(day, set()).add(item)

        shift = week % 2
        if week in A_WEEKS:
            put(MONDAY + shift, "A")
        if week in A_THEN_B_WEEKS or week in B_ONLY_WEEKS:
            put(THURSDAY + shift, "B")
        if week in C_WEEKS:
            put(WEDNESDAY, "C")
        if week in D_WITH_C_WEEKS or week in D_WITHOUT_C_WEEKS:
            put(FRIDAY, "D")
        put(SATURDAY + shift, "E")
        for item in NOISE_ITEMS:
            if rng.random() < NOISE_PROBABILITY:
                put(rng.randrange(DAYS_PER_WEEK), item)
        weeks.append([tuple(sorted(days[day])) for day in sorted(days)])
    return weeks


def _equal_totals() -> Dict[str, float]:
    return {item: 1.0 for item in ("A", "B", "C", "D", "E") + NOISE_ITEMS}


def _rule_or_none(rules: List[SequentialRule], a: Itemset, b: Itemset) -> Optional[SequentialRule]:
    return next((r for r in rules if r.antecedent == a and r.consequent == b), None)


def _rule(rules: List[SequentialRule], a: Itemset, b: Itemset) -> SequentialRule:
    rule = _rule_or_none(rules, a, b)
    assert rule is not None, f"không có luật {a} ⇒ {b}"
    return rule


def _planted_result():
    return WCMSpade(min_sup=0.25).mine(_planted_weeks(), _equal_totals())


def test_thresholds_are_the_documented_values():
    assert (MIN_ANTECEDENT_SUPPORT, MIN_LAPLACE_CONFIDENCE, MIN_LIFT) == (4, 0.6, 1.2)


def test_planted_data_has_the_intended_counts():
    weeks = _planted_weeks()
    has = lambda item: sum(any(item in day for day in week) for week in weeks)  # noqa: E731
    assert len(weeks) == N_WEEKS
    assert (has("A"), has("B"), has("C"), has("D"), has("E")) == (16, 15, 16, 13, 26)
    assert _planted_result().raw_bound == 7


def test_planted_rule_is_found_with_expected_confidence():
    rule = _rule(sequential_rules(_planted_result()), ("A",), ("B",))
    assert (rule.support, rule.antecedent_support) == (12, 16)
    assert (rule.consequent_support, rule.n_sequences) == (15, 26)
    assert rule.confidence == pytest.approx(0.75)
    assert rule.laplace_confidence == pytest.approx(13 / 18)
    assert rule.lift == pytest.approx(0.75 / (15 / 26))


def test_planted_independent_pair_is_not_reported():
    res = _planted_result()
    pairs = {(r.antecedent, r.consequent) for r in sequential_rules(res)}
    assert (("C",), ("D",)) not in pairs and (("D",), ("C",)) not in pairs
    assert res.explored[(("C",), ("D",))].raw_sup == 8   # có được khai phá, bị loại vì lift
    # Hạ ngưỡng Laplace về 0 thì C⇒D vẫn bị chặn: chỉ lift (= 1,0) loại nó.
    loose = sequential_rules(res, min_laplace_confidence=0.0)
    assert _rule_or_none(loose, ("C",), ("D",)) is None
    assert _rule_or_none(sequential_rules(res, 0, 0.0, 0.0), ("C",), ("D",)).lift == pytest.approx(1.0)


def test_every_week_consequent_has_no_lift():
    rules = sequential_rules(_planted_result())
    assert all(r.consequent != ("E",) for r in rules)


def test_rules_are_sorted_by_laplace_then_lift():
    rules = sequential_rules(_planted_result(), 0, 0.0, 0.0)
    keys = [(-r.laplace_confidence, -r.lift, -r.support, r.antecedent, r.consequent) for r in rules]
    assert keys == sorted(keys)


def test_small_antecedent_is_not_a_rule():   # 3/3 tuần: Laplace 0.8 nhưng sup(A) < 4
    seqs = [[("X",), ("Y",)]] * 3 + [[("Z",)]] * 9
    assert sequential_rules(WCMSpade(min_sup=0.2).mine(seqs, {"X": 1.0, "Y": 1.0, "Z": 1.0})) == []


def test_three_of_five_is_blocked_by_laplace():   # (3+1)/(5+2) = 0.571 < 0.6
    seqs = [[("X",), ("Y",)]] * 3 + [[("X",)]] * 2 + [[("Z",)]] * 7
    rules = sequential_rules(WCMSpade(min_sup=0.2).mine(seqs, {"X": 1.0, "Y": 1.0, "Z": 1.0}))
    assert _rule_or_none(rules, ("X",), ("Y",)) is None


def test_four_of_five_passes_laplace():   # (4+1)/(5+2) = 0.714 >= 0.6
    seqs = [[("X",), ("Y",)]] * 4 + [[("X",)]] * 1 + [[("Z",)]] * 7
    rules = sequential_rules(WCMSpade(min_sup=0.2).mine(seqs, {"X": 1.0, "Y": 1.0, "Z": 1.0}))
    rule = _rule(rules, ("X",), ("Y",))
    assert rule.laplace_confidence == pytest.approx(5 / 7)
    assert rule.lift == pytest.approx(0.8 / (4 / 12))


def test_rule_does_not_cross_iso_week_boundary():   # A Chủ nhật, B thứ Hai tuần sau: hai chuỗi khác nhau
    totals = {"A": 1.0, "B": 1.0, "Z": 1.0}
    split = [[("A",)], [("B",)]] * 5 + [[("Z",)]] * 2
    rules = sequential_rules(WCMSpade(min_sup=0.2).mine(split, totals))
    assert _rule_or_none(rules, ("A",), ("B",)) is None
    # Cùng các ngày nhưng nằm trong một tuần thì là luật.
    joined = [[("A",), ("B",)]] * 5 + [[("Z",)]] * 7
    assert _rule(sequential_rules(WCMSpade(min_sup=0.2).mine(joined, totals)), ("A",), ("B",))


def test_a_then_a_is_a_pattern_but_never_a_rule():
    seqs = [[("cafe",), ("cafe", "an")]] * 6 + [[("an",)]] * 6
    res = WCMSpade(min_sup=0.2).mine(seqs, {"cafe": 1.0, "an": 1.0})
    assert res.explored[(("cafe",), ("cafe",))].raw_sup == 6
    assert (("cafe",), ("an", "cafe")) in res.explored
    rules = sequential_rules(res, 0, 0.0, 0.0)
    assert rules and all(set(r.antecedent).isdisjoint(r.consequent) for r in rules)
    assert _rule_or_none(rules, ("cafe",), ("cafe",)) is None


def test_rule_lists_supporting_sequences():
    res = _planted_result()
    rule = _rule(sequential_rules(res), ("A",), ("B",))
    assert len(rule.sids) == 12
    assert rule.sids == tuple(A_THEN_B_WEEKS)


def test_rule_with_missing_side_support_is_skipped():
    res = _planted_result()
    res.explored.pop((("A",),))
    assert _rule_or_none(sequential_rules(res), ("A",), ("B",)) is None
