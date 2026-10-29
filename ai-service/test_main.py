"""Unit test cho ai_service.py bang mock, khong tai model Donut vat ly."""

import asyncio
import inspect
import threading
import time
from datetime import date, timedelta
from io import BytesIO
from typing import Dict, List, Tuple
from unittest.mock import patch

import httpx
import pytest
from PIL import Image

# --- Global Import Trap ---------------------------------------------------
# CI khong co file weights that (Version5/donut_result), va ai_service.py
# tai model ngay o top-level khi import module (khong nam trong ham/lifespan).
# Cac patch() nay PHAI chay va .start() truoc dong "from ai_service import app"
# ben duoi de chan viec load model vat ly + khoi tao class that.
# Patch chi song trong luc import: giu chung chay mai se lam lech moi test
# khac trong cung tien trinh (Path.exists / skipif cua test_receipt_postprocess).
_import_patches = [
    patch("os.path.exists", return_value=True),
    patch("transformers.DonutProcessor.from_pretrained"),
    patch("transformers.VisionEncoderDecoderModel.from_pretrained"),
]
for _p in _import_patches:
    _p.start()

from fastapi.testclient import TestClient  # noqa: E402

import ai_service  # noqa: E402
from ai_service import app  # noqa: E402

for _p in _import_patches:
    _p.stop()

from test_spade_rules import _planted_weeks  # noqa: E402

FIRST_MONDAY = date(2026, 1, 5)
client = TestClient(app)


def _make_test_image_bytes() -> bytes:
    """Tao anh JPEG 1x1 pixel hop le trong bo nho de gui qua /donut/scan."""
    buffer = BytesIO()
    Image.new("RGB", (1, 1), color=(255, 0, 0)).save(buffer, format="JPEG")
    return buffer.getvalue()


def test_health_check():
    """GET /health tra ve HTTP 200 va trang thai ok."""
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_extract_receipt_info_success(mocker):
    """POST /donut/scan voi anh hop le tra ve JSON da boc tach kem
    total_cost_number tinh tu chuoi tien te cua Donut."""
    # Gan truc tiep: processor.tokenizer la MagicMock (bi mock o phan Global
    # Import Trap phia tren), can ep cac thuoc tinh token ve kieu du lieu
    # that (int/str) de tranh loi PyTorch/String khi endpoint gop chuoi.
    ai_service.processor.tokenizer.convert_tokens_to_ids.return_value = 1
    ai_service.processor.tokenizer.pad_token_id = 0
    ai_service.processor.tokenizer.eos_token_id = 2
    ai_service.processor.tokenizer.eos_token = "<eos>"
    ai_service.processor.tokenizer.pad_token = "<pad>"

    # Mock: bo qua suy luan PyTorch that, ep batch_decode tra ve chuoi token
    # tho nhu the model vua sinh xong.
    mocker.patch.object(
        ai_service.processor,
        "batch_decode",
        return_value=["<s_seller>dummy text</s_seller>"],
    )
    # Mock: ep token2json tra thang JSON long nhau chuan, bo qua logic
    # decode that cua Donut processor.
    mocker.patch.object(
        ai_service.processor,
        "token2json",
        return_value={
            "seller": {"total_cost": "100.000đ"},
            "address": "123 Test",
            "timestamp": "2026-09-22",
        },
    )

    response = client.post(
        "/donut/scan",
        files={"image": ("receipt.jpg", _make_test_image_bytes(), "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["seller"]["total_cost_number"] == 100000
    # Hau xu ly Regex: field cu giu nguyen, them "normalized" kem co valid
    normalized = response.json()["normalized"]
    assert normalized["total_cost"]["value"] == 100000
    assert normalized["total_cost"]["valid"] is True
    assert set(normalized["invalid_fields"]) == {"seller", "address", "timestamp"}


EVENT_TIMEOUT_SECONDS = 10


def _scan_files() -> dict:
    return {"image": ("receipt.jpg", _make_test_image_bytes(), "image/jpeg")}


async def _wait_until(condition, what: str) -> None:
    """Cho toi khi condition() dung, nhuong event loop giua cac lan kiem; qua han thi bao loi."""
    deadline = time.monotonic() + EVENT_TIMEOUT_SECONDS
    while not condition():
        if time.monotonic() > deadline:
            raise AssertionError(f"Het thoi gian cho: {what}")
        await asyncio.sleep(0.01)


def test_scans_run_one_at_a_time_and_health_stays_responsive(mocker):
    """Hai POST /donut/scan gui cung luc phai doc lan luot (toi da 1 luot
    DONUT chay cung luc), con GET /health van tra 200 trong luc luot dau
    dang chay, tuc la suy luan khong chan event loop. Dong bo bang
    threading.Event, khong dua vao do thoi gian."""
    events: List[str] = []
    events_lock = threading.Lock()
    first_started = threading.Event()
    release_first = threading.Event()
    state: Dict[str, int] = {"calls": 0, "running": 0, "max_running": 0}

    def fake_run_donut(pil_img: Image.Image) -> str:
        # Mock: thay suy luan DONUT that; luot dau dung lai cho toi khi test cho phep.
        with events_lock:
            state["calls"] += 1
            call = state["calls"]
            state["running"] += 1
            state["max_running"] = max(state["max_running"], state["running"])
            events.append(f"start{call}")
        if call == 1:
            first_started.set()
            assert release_first.wait(EVENT_TIMEOUT_SECONDS)
        with events_lock:
            state["running"] -= 1
            events.append(f"end{call}")
        return "<s_seller>dummy text</s_seller>"

    mocker.patch.object(ai_service, "_run_donut", side_effect=fake_run_donut)
    mocker.patch.object(ai_service.processor, "token2json", return_value={"seller": {"total_cost": "100.000đ"}})

    async def scenario() -> Tuple[List[int], int, bool]:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as async_client:
            scans = [asyncio.create_task(async_client.post("/donut/scan", files=_scan_files())) for _ in range(2)]
            await _wait_until(first_started.is_set, "luot scan dau bat dau")
            await _wait_until(lambda: ai_service._scan_gate.admitted == 2, "luot scan thu hai vao hang")
            health = await async_client.get("/health")
            first_still_running = not release_first.is_set() and events == ["start1"]
            release_first.set()
            responses = await asyncio.gather(*scans)
            return [r.status_code for r in responses], health.status_code, first_still_running

    scan_statuses, health_status, first_still_running = asyncio.run(scenario())

    assert scan_statuses == [200, 200]
    assert health_status == 200 and first_still_running
    assert state["max_running"] == 1
    assert events == ["start1", "end1", "start2", "end2"]


def test_scan_answers_503_when_the_queue_is_full(mocker):
    """Mot luot dang chay + SCAN_QUEUE_LIMIT luot cho: luot ke tiep bi tu choi 503 ngay,
    khong chiem thread; sau khi giai phong, cac luot da nhan van xong 200."""
    mocker.patch.object(ai_service, "SCAN_QUEUE_LIMIT", 1)
    started = threading.Event()
    release = threading.Event()

    def fake_run_donut(pil_img: Image.Image) -> str:
        started.set()
        assert release.wait(EVENT_TIMEOUT_SECONDS)
        return "<s_seller>x</s_seller>"

    mocker.patch.object(ai_service, "_run_donut", side_effect=fake_run_donut)
    mocker.patch.object(ai_service.processor, "token2json", return_value={"seller": {"total_cost": "100.000đ"}})

    async def scenario() -> Tuple[List[int], httpx.Response]:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as async_client:
            accepted = [asyncio.create_task(async_client.post("/donut/scan", files=_scan_files())) for _ in range(2)]
            await _wait_until(started.is_set, "luot scan dau bat dau")
            await _wait_until(lambda: ai_service._scan_gate.admitted == 2, "hang cho day")
            refused = await async_client.post("/donut/scan", files=_scan_files())
            release.set()
            responses = await asyncio.gather(*accepted)
            return [r.status_code for r in responses], refused

    accepted_statuses, refused = asyncio.run(scenario())

    assert refused.status_code == 503
    assert refused.json() == {"detail": ai_service.SCAN_BUSY_MESSAGE}
    assert accepted_statuses == [200, 200]
    assert ai_service._scan_gate.admitted == 0


def _image_bytes(width: int, height: int, fmt: str) -> bytes:
    buffer = BytesIO()
    Image.new("RGB", (width, height), color=(10, 20, 30)).save(buffer, format=fmt)
    return buffer.getvalue()


def _png_bytes(width: int, height: int) -> bytes:
    return _image_bytes(width, height, "PNG")


def _mock_donut(mocker, token2json_value):
    ai_service.processor.tokenizer.convert_tokens_to_ids.return_value = 1
    mocker.patch.object(ai_service, "_run_donut", return_value="<s_seller>x</s_seller>")
    mocker.patch.object(ai_service.processor, "token2json", return_value=token2json_value)


def test_health_is_async():
    assert inspect.iscoroutinefunction(ai_service.health_check)


def test_scan_rejects_file_over_size_limit(mocker):
    mocker.patch.object(ai_service, "MAX_UPLOAD_BYTES", 10)
    r = client.post("/donut/scan", files={"image": ("r.jpg", _make_test_image_bytes(), "image/jpeg")})
    assert r.status_code == 413 and r.json()["detail"] == ai_service.IMAGE_TOO_LARGE_MESSAGE


def test_scan_rejects_too_many_pixels_before_decoding(mocker):
    mocker.patch.object(ai_service, "MAX_IMAGE_PIXELS", 100)
    run = mocker.patch.object(ai_service, "_run_donut")
    r = client.post("/donut/scan", files={"image": ("r.png", _png_bytes(20, 20), "image/png")})
    assert r.status_code == 413 and run.call_count == 0
    assert r.json()["detail"] == ai_service.IMAGE_TOO_LARGE_MESSAGE


@pytest.mark.parametrize("stage", ["open", "decode"])
def test_scan_maps_decompression_bomb_to_413(mocker, stage):
    bomb = ai_service.Image.DecompressionBombError("too many pixels")
    if stage == "open":
        mocker.patch.object(ai_service.Image, "open", side_effect=bomb)
    else:
        mocker.patch.object(ai_service.ImageOps, "exif_transpose", side_effect=bomb)
    run = mocker.patch.object(ai_service, "_run_donut")
    r = client.post("/donut/scan", files={"image": ("r.png", _png_bytes(4, 4), "image/png")})
    assert r.status_code == 413 and r.json()["detail"] == ai_service.IMAGE_TOO_LARGE_MESSAGE
    assert run.call_count == 0


def test_scan_rejects_unsupported_format(mocker):
    run = mocker.patch.object(ai_service, "_run_donut")
    r = client.post("/donut/scan", files={"image": ("r.gif", _image_bytes(2, 2, "GIF"), "image/gif")})
    assert r.status_code == 415 and r.json()["detail"] == ai_service.UNSUPPORTED_IMAGE_MESSAGE
    assert run.call_count == 0


def test_scan_hides_decoder_errors():
    r = client.post("/donut/scan", files={"image": ("r.jpg", b"not an image", "image/jpeg")})
    assert r.status_code == 400 and r.json()["detail"] == ai_service.UNREADABLE_IMAGE_MESSAGE
    assert "identify" not in r.text


def test_scan_rejects_empty_file():
    r = client.post("/donut/scan", files={"image": ("r.jpg", b"", "image/jpeg")})
    assert r.status_code == 400 and r.json()["detail"] == ai_service.EMPTY_IMAGE_MESSAGE


def test_scan_accepts_jpeg_sent_as_octet_stream(mocker):
    _mock_donut(mocker, {"seller": {"total_cost": "100.000đ"}})
    r = client.post(
        "/donut/scan",
        files={"image": ("r.jpg", _make_test_image_bytes(), "application/octet-stream")},
    )
    assert r.status_code == 200


def test_total_cost_number_absent_when_total_invalid(mocker):
    _mock_donut(mocker, {"seller": {"total_cost": "2.000.000.000đ", "total_cost_number": 5}})
    r = client.post("/donut/scan", files={"image": ("r.jpg", _make_test_image_bytes(), "image/jpeg")})
    assert r.status_code == 200
    assert "total_cost_number" not in r.json()["seller"]


def test_extract_receipt_info_missing_file():
    """POST /donut/scan thieu file anh bat buoc phai bi FastAPI chan o
    buoc validation (422), chua cham toi logic model."""
    response = client.post("/donut/scan")

    assert response.status_code == 422


def _tx(category: str = "an uong", amount: float = 1000, date: str = "2026-10-20") -> dict:
    return {"category": category, "amount": amount, "date": date, "isExpense": True}


def _planted_payload() -> list:
    """26 tuan cay san cua test_spade_rules, moi ngay la mot ngay that."""
    payload = []
    for w, week in enumerate(_planted_weeks()):
        for d, itemset in enumerate(week):
            day = FIRST_MONDAY + timedelta(days=7 * w + d)
            payload.extend(_tx(item, 1000, day.isoformat()) for item in itemset)
    return payload


def test_spade_analyze_contract():
    response = client.post("/spade/analyze", json={"transactions": _planted_payload()})
    body = response.json()
    assert response.status_code == 200
    assert set(body) == {"status", "patterns", "rules", "habits", "categories", "meta"}
    assert body["status"] == "OK"
    assert body["meta"]["algorithm"] == "WCM-SPADE"
    rule = next(r for r in body["rules"] if r["antecedent"] == ["A"] and r["consequent"] == ["B"])
    assert {"antecedentSupport", "laplaceConfidence", "lift", "weeks"} <= set(rule)


def test_analyze_leaves_savings_out():
    payload = _planted_payload() + [_tx("Tiết kiệm", 9e9, "2026-10-20")]
    body = client.post("/spade/analyze", json={"transactions": payload}).json()
    assert "Tiết kiệm" not in {c["category"] for c in body["categories"]}


def test_analyze_accepts_old_request_fields():
    r = client.post("/spade/analyze", json={"transactions": [], "alpha": 0.5, "beta": 0.5,
                                            "max_gap_days": 7, "min_sup_factor": 0.5})
    assert r.status_code == 200 and r.json()["status"] == "INSUFFICIENT_DATA"


@pytest.mark.parametrize("bad", [
    {"transactions": [_tx()] * 5001}, {"transactions": [], "top_n": 0}, {"transactions": [], "top_n": 51},
    {"transactions": [], "min_sup_factor": 0}, {"transactions": [], "min_sup_factor": 1.5},
    {"transactions": [_tx(category="x" * 256)]}, {"transactions": [_tx(amount=-1)]},
])
def test_analyze_rejects_out_of_range_input(bad):
    assert client.post("/spade/analyze", json=bad).status_code == 422


def test_recommend_budget(mocker):
    """POST /spade/recommend tra ve loi khuyen lay tu budget_advisor.advise
    (da mock), khong phu thuoc thuat toan tinh ngan sach that."""
    fake_advice = {
        "trends": [],
        "tagStats": [],
        "goal": {
            "neededMonthly": 1000000,
            "monthlyIncome": 5000000,
            "monthlyExpense": 3000000,
            "surplus": 2000000,
            "gap": -1000000,
        },
        "recommendations": [],
        "summary": "Đề xuất ngân sách giả lập cho kiểm thử.",
    }
    # Mock: chan ham budget_advisor.advise, ep tra ve dict loi khuyen gia
    # lap de chi kiem tra endpoint truyen/tra du lieu dung.
    mocker.patch("budget_advisor.advise", return_value=fake_advice)

    payload = {
        "transactions": [
            {
                "category": "an uong",
                "amount": 50000,
                "date": "2026-09-01",
                "isExpense": True,
            },
        ],
        "target": 10000000,
        "current": 2000000,
        "months_left": 6,
    }
    response = client.post("/spade/recommend", json=payload)

    assert response.status_code == 200
    assert response.json()["summary"] == "Đề xuất ngân sách giả lập cho kiểm thử."


def _prev_month_day(months_back: int, day: int = 1) -> str:
    from local_time import local_today
    t = local_today()
    idx = t.year * 12 + (t.month - 1) - months_back
    return date(idx // 12, idx % 12 + 1, day).isoformat()


def test_recommend_real_advisor_path_without_mock():
    """No mock of advise: a signature drift between endpoint and advisor must fail here."""
    txs = [_tx("Ăn uống", 3_000_000, _prev_month_day(2)), _tx("Mua sắm", 2_000_000, _prev_month_day(1)),
           _tx("Ăn uống", 3_000_000, _prev_month_day(1))]
    r = client.post("/spade/recommend", json={"transactions": txs, "target": 6_000_000, "months_left": 3})
    assert r.status_code == 200
    body = r.json()
    assert body["meta"]["nMonths"] == 2 and body["goal"]["hasDeadline"] is True
    assert "trends" not in body


def test_recommend_without_months_left_is_allowed():
    txs = [_tx("Ăn uống", 3_000_000, _prev_month_day(1))]
    r = client.post("/spade/recommend", json={"transactions": txs, "target": 6_000_000})
    assert r.status_code == 200 and r.json()["goal"]["hasDeadline"] is False


def test_recommend_empty_list_is_422_fixed_text():
    import budget_advisor
    r = client.post("/spade/recommend", json={"transactions": []})
    assert r.status_code == 422 and r.json() == {"detail": budget_advisor.NO_EXPENSE_MESSAGE}


def test_recommend_maps_advice_error_to_422_with_fixed_text(mocker):
    import budget_advisor
    mocker.patch("budget_advisor.advise",
                 side_effect=budget_advisor.AdviceError(budget_advisor.NOT_ENOUGH_HISTORY_MESSAGE))
    r = client.post("/spade/recommend", json={"transactions": [_tx()]})
    assert r.status_code == 422 and r.json() == {"detail": budget_advisor.NOT_ENOUGH_HISTORY_MESSAGE}


def test_recommend_hides_an_advice_error_text_that_is_not_a_known_fixed_text(mocker):
    import budget_advisor
    mocker.patch("budget_advisor.advise",
                 side_effect=budget_advisor.AdviceError("KeyError: 'amount' at budget_advisor.py:88"))
    r = client.post("/spade/recommend", json={"transactions": [_tx()]})
    assert r.status_code == 422 and r.json() == {"detail": budget_advisor.ADVICE_FAILED_MESSAGE}
    assert "KeyError" not in r.text


def test_recommend_rejects_months_left_zero():
    r = client.post("/spade/recommend", json={"transactions": [_tx()], "months_left": 0})
    assert r.status_code == 422


def test_recommend_ignores_old_max_cut_ratio(mocker):
    m = mocker.patch("budget_advisor.advise", return_value={"summary": "ok"})
    r = client.post("/spade/recommend", json={"transactions": [_tx()], "max_cut_ratio": 5, "alpha": 1})
    assert r.status_code == 200
    assert "max_cut_ratio" not in m.call_args.kwargs and "alpha" not in m.call_args.kwargs


def test_admin_segment_endpoint_returns_labels_and_codes():
    from rfm_segmentation import Segment
    users = [{"user_id": "1", "recency": 400, "frequency": 0, "monetary": 0},
             {"user_id": "2", "recency": 2, "frequency": 20, "monetary": 9e6},
             {"user_id": "3", "recency": 60, "frequency": 3, "monetary": 1e5}]
    res = client.post("/admin/segment", json={"users": users})
    assert res.status_code == 200
    segs = res.json()["segments"]
    assert [s["user_id"] for s in segs] == ["1", "2", "3"]
    for s in segs:
        assert s["label"] in {x.value for x in Segment}
        assert len(s["rfm"]) == 3 and s["rfm"].isdigit()
    assert segs[0]["label"] == "LOST"


@pytest.mark.parametrize("user", [
    {"user_id": None, "recency": 1, "frequency": 1, "monetary": 1},
    {"user_id": "7", "recency": -1, "frequency": 1, "monetary": 1},
    {"user_id": "abc", "recency": 1, "frequency": 1, "monetary": 1}])
def test_admin_segment_rejects_bad_users(user):
    assert client.post("/admin/segment", json={"users": [user]}).status_code == 422
