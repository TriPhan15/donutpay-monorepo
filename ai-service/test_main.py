"""Unit test cho ai_service.py bang mock, khong tai model Donut vat ly."""

import asyncio
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


SCAN_SECONDS = 0.3


def test_scans_run_one_at_a_time_and_health_stays_responsive(mocker):
    """Hai POST /donut/scan gui cung luc phai doc lan luot (toi da 1 luot
    DONUT chay cung luc), con GET /health van tra 200 truoc khi luot scan
    thu hai xong, tuc la suy luan khong chan event loop."""
    state: Dict[str, int] = {"running": 0, "max_running": 0}
    state_lock = threading.Lock()

    def fake_run_donut(pil_img: Image.Image) -> str:
        # Mock: thay suy luan DONUT that bang ham ngu (blocking) va dem so
        # luot dang chay cung luc.
        with state_lock:
            state["running"] += 1
            state["max_running"] = max(state["max_running"], state["running"])
        time.sleep(SCAN_SECONDS)
        with state_lock:
            state["running"] -= 1
        return "<s_seller>dummy text</s_seller>"

    mocker.patch.object(ai_service, "_run_donut", side_effect=fake_run_donut)
    mocker.patch.object(
        ai_service.processor,
        "token2json",
        return_value={"seller": {"total_cost": "100.000đ"}},
    )

    async def scenario() -> List[Tuple[str, int, float]]:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as async_client:
            started = time.monotonic()

            async def scan() -> Tuple[str, int, float]:
                response = await async_client.post(
                    "/donut/scan",
                    files={
                        "image": (
                            "receipt.jpg",
                            _make_test_image_bytes(),
                            "image/jpeg",
                        )
                    },
                )
                return "scan", response.status_code, time.monotonic() - started

            async def health() -> Tuple[str, int, float]:
                # Cho hai scan vao truoc de /health chay trong luc DONUT ban
                await asyncio.sleep(SCAN_SECONDS / 3)
                response = await async_client.get("/health")
                return "health", response.status_code, time.monotonic() - started

            return list(await asyncio.gather(scan(), scan(), health()))

    results = asyncio.run(scenario())

    scans = sorted(done for kind, _, done in results if kind == "scan")
    health_status, health_done = next(
        (status, done) for kind, status, done in results if kind == "health"
    )
    assert [status for kind, status, _ in results if kind == "scan"] == [200, 200]
    assert state["max_running"] == 1
    assert health_status == 200
    assert health_done < scans[1]
    # Tuan tu that su: luot thu hai xong sau it nhat hai lan ngu
    assert scans[1] >= 2 * SCAN_SECONDS


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
    {"transactions": [_tx(category="x" * 65)]}, {"transactions": [_tx(amount=-1)]},
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


def test_recommend_rejects_months_left_zero():
    r = client.post("/spade/recommend", json={"transactions": [_tx()], "months_left": 0})
    assert r.status_code == 422


def test_recommend_ignores_old_max_cut_ratio(mocker):
    m = mocker.patch("budget_advisor.advise", return_value={"summary": "ok"})
    r = client.post("/spade/recommend", json={"transactions": [_tx()], "max_cut_ratio": 5, "alpha": 1})
    assert r.status_code == 200
    assert "max_cut_ratio" not in m.call_args.kwargs and "alpha" not in m.call_args.kwargs
