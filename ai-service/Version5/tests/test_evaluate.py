from PIL import Image

from evaluate import CIRCLE_K_TEST, score, sequence_to_fields, subsets, verdict
from labels import Record


def test_sequence_to_fields_v5_shape():
    seq = ("<s_seller><s_seller_name>CIRCLE K</s_seller_name><s_address></s_address>"
           "<s_timestamp>22/02/2023</s_timestamp><s_total_cost>32,000</s_total_cost></s_seller></s>")
    assert sequence_to_fields(seq, legacy_v3=False) == {
        "SELLER": "CIRCLE K", "ADDRESS": "", "TIMESTAMP": "22/02/2023", "TOTAL_COST": "32,000"}


def test_sequence_to_fields_garbage_is_empty():
    assert set(sequence_to_fields("<s_seller><s_seller_na", legacy_v3=False).values()) == {""}


def test_sequence_to_fields_legacy_cleans_spacing():
    seq = "<s_seller><s_seller_name> Dươ ng </s_seller_name></s_seller>"
    assert sequence_to_fields(seq, legacy_v3=True)["SELLER"] == "Dương"


def _f(**kw):
    base = {"SELLER": "", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": ""}
    base.update(kw)
    return base


def test_score_main_vs_including_empty():
    pairs = [(_f(SELLER="A", TOTAL_COST="50,000"), _f(SELLER="a", ADDRESS="bịa", TOTAL_COST="50.000đ"))]
    main = score(pairs, include_empty_gt=False)
    assert main["SELLER"].exact == 1 and main["ADDRESS"].count == 0 and main["ALL"].count == 2
    assert main["ALL"].exact == 2 and main["TOTAL_COST"].sim == 1.0
    full = score(pairs, include_empty_gt=True)
    assert full["ADDRESS"].exact == 0 and full["TIMESTAMP"].exact == 1 and full["ALL"].count == 4


def test_score_relaxed_threshold():
    pairs = [(_f(SELLER="SIEU THI CO.OP"), _f(SELLER="SIEU THI CO.0P"))]
    s = score(pairs, include_empty_gt=False)["SELLER"]
    assert s.exact == 0 and s.relaxed == 1


def test_subsets_long_and_circle_k(tmp_path):
    Image.new("RGB", (100, 300)).save(tmp_path / "tall.jpg")
    Image.new("RGB", (300, 100)).save(tmp_path / CIRCLE_K_TEST[0])
    recs = [Record("tall.jpg", _f()), Record(CIRCLE_K_TEST[0], _f())]
    sub = subsets(recs, tmp_path, seen={"tall.jpg"})
    assert sub["all"] == {"tall.jpg", CIRCLE_K_TEST[0]}
    assert sub["long"] == {"tall.jpg"} and sub["circle_k"] == {CIRCLE_K_TEST[0]}
    assert sub["all_minus_v3_seen"] == {CIRCLE_K_TEST[0]}


def test_verdict():
    win = {"all_minus_v3_seen": (0.6, 0.7), "long": (0.4, 0.5)}
    assert verdict(win) == "V5 THẮNG"
    assert verdict({"all_minus_v3_seen": (0.6, 0.7), "long": (0.5, 0.5)}) == "V5 CHƯA THẮNG"
