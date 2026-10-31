"""Test lõi WCM-SPADE: trọng số tỷ trọng, cận maxW, CMAP a→a, lọc closed."""

import random
from typing import Dict, List, Tuple

import pytest

from wcm_spade import WCMSpade, is_subpattern, item_weights_from_totals

Itemset = Tuple[str, ...]
Week = List[Itemset]

RANDOM_MAX_DAYS_PER_WEEK = 5
RANDOM_MAX_ITEMS_PER_DAY = 3
RANDOM_MAX_TOTAL = 1000.0


def _weeks(*days: str) -> Week:
    """Một tuần: mỗi chuỗi ký tự là một ngày, mỗi ký tự là một item."""
    return [tuple(sorted(set(day))) for day in days]


def _random_db(seed: int, n_seq: int, items: str) -> Tuple[List[Week], Dict[str, float]]:
    rng = random.Random(seed)
    seqs: List[Week] = []
    for _ in range(n_seq):
        n_days = rng.randint(1, RANDOM_MAX_DAYS_PER_WEEK)
        days = [
            "".join(rng.sample(items, rng.randint(1, RANDOM_MAX_ITEMS_PER_DAY)))
            for _ in range(n_days)
        ]
        seqs.append(_weeks(*days))
    totals = {item: rng.uniform(0.0, RANDOM_MAX_TOTAL) for item in items}
    return seqs, totals


def _db_with_heavy_item() -> List[Week]:
    # 8 tuần: "rent" ở 3 tuần, "snack" ở 5 tuần, "food" ở cả 8 tuần.
    rent_weeks = [[("rent",), ("food",)]] * 3
    snack_weeks = [[("food",), ("snack",)]] * 5
    return rent_weeks + snack_weeks


def _totals_heavy() -> Dict[str, float]:
    # m = 3, tổng 300: w(rent) = 3*160/300 = 1.6, w(snack) = 0.4, w(food) = 1.0
    return {"rent": 160.0, "snack": 40.0, "food": 100.0}


def test_weeks_helper_builds_sorted_itemsets():
    assert _weeks("A", "CB") == [("A",), ("B", "C")]


def test_weights_are_spending_share_over_mean_share():
    w = item_weights_from_totals(["A", "B"], {"A": 300.0, "B": 100.0})
    assert w == pytest.approx({"A": 1.5, "B": 0.5})


def test_zero_spending_gives_equal_weights():
    assert item_weights_from_totals(["A", "B"], {"A": 0.0, "B": 0.0}) == {"A": 1.0, "B": 1.0}


def test_cmap_keeps_a_then_a_across_two_days():
    seqs = [[("cafe",), ("cafe",)]] * 4 + [[("an",)]] * 4
    res = WCMSpade(min_sup=0.5).mine(seqs, {"cafe": 1.0, "an": 1.0})
    assert (("cafe",), ("cafe",)) in res.explored
    assert res.explored[(("cafe",), ("cafe",))].raw_sup == 4


@pytest.mark.parametrize("seed", range(5))
def test_cmap_pruning_is_lossless(seed):
    seqs, totals = _random_db(seed, n_seq=20, items="ABCDE")
    with_cmap = WCMSpade(min_sup=0.2).mine(seqs, totals)
    without = WCMSpade(min_sup=0.2, use_cmap=False).mine(seqs, totals)
    assert with_cmap.explored.keys() == without.explored.keys()


def test_raw_bound_uses_max_weight():
    # N=8, min_sup=0.5 -> min_wsup=4; maxW=1.6 -> raw_bound = ceil(4/1.6) = 3
    res = WCMSpade(min_sup=0.5).mine(_db_with_heavy_item(), _totals_heavy())
    assert res.raw_bound == 3 and res.max_weight == pytest.approx(1.6)


def test_heavy_pattern_below_raw_min_sup_is_kept_and_light_one_dropped():
    res = WCMSpade(min_sup=0.5).mine(_db_with_heavy_item(), _totals_heavy())
    keys = {p.itemsets for p in res.patterns}
    assert (("rent",),) in keys          # sup 3 * w 1.6 = 4.8 >= 4
    assert (("snack",),) not in keys     # sup 5 * w 0.4 = 2.0 < 4


def test_pattern_weight_is_mean_item_weight_and_ranking_follows_wsup():
    # 4 tuần [A],[B] + 4 tuần [C],[D]; w = 2.4, 0.4, 0.4, 0.8 (m=4, tổng 1000)
    seqs = [[("A",), ("B",)]] * 4 + [[("C",), ("D",)]] * 4
    res = WCMSpade(min_sup=0.25).mine(seqs, {"A": 600.0, "B": 100.0, "C": 100.0, "D": 200.0})
    keys = [p.itemsets for p in res.patterns]
    ab, cd = res.explored[(("A",), ("B",))], res.explored[(("C",), ("D",))]
    assert (ab.raw_sup, cd.raw_sup) == (4, 4)
    assert ab.weight == pytest.approx(1.4) and cd.weight == pytest.approx(0.6)
    assert keys.index(ab.itemsets) < keys.index(cd.itemsets)
    assert [p.wsup for p in res.patterns] == sorted((p.wsup for p in res.patterns), reverse=True)


def test_wsup_is_a_ratio_of_sequences():
    seqs = [[("A",), ("B",)]] * 4 + [[("C",), ("D",)]] * 4
    res = WCMSpade(min_sup=0.25).mine(seqs, {"A": 600.0, "B": 100.0, "C": 100.0, "D": 200.0})
    assert res.explored[(("A",), ("B",))].wsup == pytest.approx(4 * 1.4 / 8)
    assert res.explored[(("A",), ("B",))].item_count() == 2


def test_closed_filter_on_raw_support():
    seqs = [[("A",), ("B",)]] * 5 + [[("A",)]]
    res = WCMSpade(min_sup=0.5).mine(seqs, {"A": 1.0, "B": 1.0})
    keys = {p.itemsets for p in res.patterns}
    assert (("A",), ("B",)) in keys and (("B",),) not in keys   # B: sup 5 == sup(A->B)
    assert (("A",),) in keys                                    # A: sup 6 > 5


def test_pattern_exposes_supporting_sequence_ids():
    seqs = [[("A",), ("B",)], [("C",)], [("A",), ("B",)]]
    res = WCMSpade(min_sup=0.5).mine(seqs, {"A": 1.0, "B": 1.0, "C": 1.0})
    assert res.explored[(("A",), ("B",))].sids == (0, 2)


def test_is_subpattern_respects_order():
    assert is_subpattern((("A",), ("B",)), (("A", "C"), ("D",), ("B",)))
    assert not is_subpattern((("B",), ("A",)), (("A",), ("B",)))


def test_itemset_extension_is_mined():
    seqs = [_weeks("AB", "C")] * 3 + [_weeks("D")]
    res = WCMSpade(min_sup=0.5).mine(seqs, {"A": 1.0, "B": 1.0, "C": 1.0, "D": 1.0})
    assert res.explored[(("A", "B"), ("C",))].raw_sup == 3


def test_max_pattern_length_limits_item_count():
    seqs = [_weeks("A", "B", "C")] * 4
    res = WCMSpade(min_sup=0.5, max_pattern_length=2).mine(seqs, {"A": 1.0, "B": 1.0, "C": 1.0})
    assert max(p.item_count() for p in res.explored.values()) == 2


def test_empty_database_gives_empty_result():
    res = WCMSpade().mine([], {})
    assert res.patterns == [] and res.explored == {} and res.n_sequences == 0


BRUTE_FORCE_MIN_SUP = 1e-9   # raw_bound = 1: mọi mẫu xuất hiện ít nhất một lần
BRUTE_FORCE_TOLERANCE = 1e-9


@pytest.mark.parametrize("seed", range(5))
def test_max_weight_bound_loses_no_weighted_frequent_pattern(seed):
    seqs, totals = _random_db(seed, n_seq=20, items="ABCDE")
    real = WCMSpade(min_sup=0.3).mine(seqs, totals)
    everything = WCMSpade(min_sup=BRUTE_FORCE_MIN_SUP).mine(seqs, totals)
    assert everything.raw_bound == 1 and not everything.truncated
    wanted = {
        key: p for key, p in everything.explored.items()
        if p.raw_sup * p.weight >= real.min_wsup - BRUTE_FORCE_TOLERANCE
    }
    assert wanted, "dữ liệu ngẫu nhiên phải có ít nhất một mẫu đạt weighted support"
    for key, p in wanted.items():
        assert key in real.explored
        assert real.explored[key].raw_sup == p.raw_sup
    assert {p.itemsets for p in real.patterns} <= set(wanted)


def test_result_is_not_truncated_by_default():
    seqs, totals = _random_db(0, n_seq=20, items="ABCDE")
    assert WCMSpade(min_sup=0.2).mine(seqs, totals).truncated is False


def test_max_patterns_stop_sets_truncated():
    seqs = [_weeks("A", "B", "C")] * 4
    totals = {"A": 1.0, "B": 1.0, "C": 1.0}
    full = WCMSpade(min_sup=0.5).mine(seqs, totals)
    assert not full.truncated
    cut = WCMSpade(min_sup=0.5, max_patterns=3).mine(seqs, totals)
    assert cut.truncated and len(cut.explored) == 3
    exact = WCMSpade(min_sup=0.5, max_patterns=len(full.explored)).mine(seqs, totals)
    assert not exact.truncated and exact.explored.keys() == full.explored.keys()


def test_join_budget_stops_the_dfs_and_sets_truncated():
    seqs, totals = _random_db(3, 30, "ABCDEF")
    full = WCMSpade(min_sup=0.2).mine(seqs, totals)
    assert not full.truncated
    cut = WCMSpade(min_sup=0.2, max_joins=5).mine(seqs, totals)
    assert cut.truncated and len(cut.explored) < len(full.explored)


def test_join_budget_of_the_rules_returns_what_was_found():
    from wcm_spade import sequential_rules
    seqs, totals = _random_db(3, 30, "ABCDEF")
    result = WCMSpade(min_sup=0.2).mine(seqs, totals)
    full = sequential_rules(result, min_lift=0.0, min_laplace_confidence=0.0)
    assert full
    assert len(sequential_rules(result, min_lift=0.0, min_laplace_confidence=0.0, max_joins=3)) <= len(full)
    assert sequential_rules(result, min_lift=0.0, min_laplace_confidence=0.0, max_joins=0) == []
