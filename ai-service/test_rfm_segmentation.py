import pytest

from rfm_segmentation import RfmInput, Segment, quintile_scores, segment_of, segment_users


def test_distinct_values_spread_over_one_to_five():
    assert quintile_scores([10, 20, 30, 40, 50]) == [1, 2, 3, 4, 5]


def test_ties_share_a_score():
    assert quintile_scores([5, 5, 5, 5]) == [3, 3, 3, 3]


def test_single_user_gets_the_middle_score():
    assert quintile_scores([7]) == [3]


def test_recency_lower_is_better():
    r = quintile_scores([1, 100], higher_is_better=False)
    assert r[0] > r[1]


def test_empty_input():
    assert quintile_scores([]) == [] and segment_users([]) == []


@pytest.mark.parametrize(("rfm", "segment"), [
    ((5, 5, 5), Segment.CHAMPIONS), ((5, 1, 1), Segment.NEW),
    ((3, 4, 2), Segment.LOYAL), ((1, 5, 5), Segment.AT_RISK),
    ((2, 1, 1), Segment.HIBERNATING), ((3, 1, 1), Segment.NEED_ATTENTION)])
def test_segment_table(rfm, segment):
    assert segment_of(*rfm) is segment


def test_every_score_combination_has_a_segment():
    found = {segment_of(r, f, m) for r in range(1, 6) for f in range(1, 6) for m in range(1, 6)}
    assert found <= set(Segment) - {Segment.LOST}


def test_users_without_spending_are_lost_and_not_scored():
    out = segment_users([RfmInput("1", 366, 0, 0.0), RfmInput("2", 3, 9, 5e6), RfmInput("3", 90, 2, 1e5)])
    assert (out[0].label, out[0].rfm) == (Segment.LOST, "000")
    assert out[1].rfm != out[2].rfm
    assert [o.user_id for o in out] == ["1", "2", "3"]


def test_two_distinct_users():
    assert quintile_scores([10, 20]) == [2, 4]


def _brute_force(values, higher_is_better=True):
    import math
    n = len(values)
    s = [v if higher_is_better else -v for v in values]
    return [min(5, 1 + math.floor(5 * (sum(x < v for x in s) + 0.5 * sum(x == v for x in s)) / n))
            for v in s]


@pytest.mark.parametrize("higher", [True, False])
def test_matches_brute_force_with_many_ties(higher):
    import random
    rng = random.Random(42)
    values = [rng.randint(0, 12) for _ in range(400)]
    assert quintile_scores(values, higher) == _brute_force(values, higher)


def test_twenty_thousand_users_are_fast():
    import random
    import time
    rng = random.Random(7)
    users = [RfmInput(str(i), rng.randint(0, 365), rng.randint(1, 500), rng.random() * 1e8)
             for i in range(20_000)]
    start = time.perf_counter()
    out = segment_users(users)
    assert time.perf_counter() - start < 2.0
    assert len(out) == 20_000


def test_lost_users_do_not_shift_other_scores():
    base = segment_users([RfmInput("2", 3, 9, 5e6), RfmInput("3", 90, 2, 1e5)])
    with_lost = segment_users([RfmInput("1", 366, 0, 0.0), RfmInput("2", 3, 9, 5e6),
                               RfmInput("3", 90, 2, 1e5)])
    assert [r.rfm for r in with_lost[1:]] == [r.rfm for r in base]
