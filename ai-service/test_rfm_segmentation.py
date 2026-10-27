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


def test_lost_users_do_not_shift_other_scores():
    base = segment_users([RfmInput("2", 3, 9, 5e6), RfmInput("3", 90, 2, 1e5)])
    with_lost = segment_users([RfmInput("1", 366, 0, 0.0), RfmInput("2", 3, 9, 5e6),
                               RfmInput("3", 90, 2, 1e5)])
    assert [r.rfm for r in with_lost[1:]] == [r.rfm for r in base]
