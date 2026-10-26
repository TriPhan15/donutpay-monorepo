import json
from pathlib import Path

import pytest

AI_SERVICE = Path(__file__).resolve().parents[2]


def _code(name: str) -> list[str]:
    path = AI_SERVICE / name
    if not path.exists():
        pytest.skip("notebook không nằm cạnh bundle (ví dụ khi chạy test trên Kaggle)")
    nb = json.loads(path.read_text(encoding="utf-8"))
    for cell in nb["cells"]:
        assert not cell.get("outputs"), f"{name}: notebook không được lưu output"
    return ["".join(c["source"]) for c in nb["cells"] if c["cell_type"] == "code"]


def _order(cells: list[str], needles: list[str]) -> list[int]:
    return [next(i for i, c in enumerate(cells) if n in c) for n in needles]


def test_relabel_notebook_order_and_no_key():
    cells = _code("relabel-v5.ipynb")
    idx = _order(cells, ["pip install", "copytree", "check_data.py --no-open",
                         "relabel_gemini.py --split test", "relabel_qwen.py --split test", "relabel_cache.zip"])
    assert idx == sorted(idx)
    assert all("GEMINI_API_KEY=" not in c for c in cells)
    gemini = next(c for c in cells if "relabel_gemini.py --split test" in c)
    assert gemini.index("--split test") < gemini.index("--split validation") < gemini.index("--split train")


def test_train_notebook_order_and_pins():
    cells = _code("donut-v5.ipynb")
    idx = _order(cells, ["pip install", "copytree", "\"-m\", \"pytest\"", "check_data.py", "DONUT_DRY_RUN_STEPS=20",
                         "!CUDA_VISIBLE_DEVICES=0 python train_model.py", "evaluate.py --v3", "donut_result.zip"])
    assert idx == sorted(idx)
    assert any("albumentations==2.0.8" in c for c in cells)
    assert any("CUDA_VISIBLE_DEVICES=0" in c for c in cells)


def test_train_notebook_stops_on_red_tests_and_keeps_output_small():
    cells = _code("donut-v5.ipynb")
    pytest_cell = next(c for c in cells if "\"pytest\"" in c)
    assert "SystemExit" in pytest_cell and not pytest_cell.lstrip().startswith("!")
    assert all("zip -qr donut_checkpoints" not in c for c in cells)
    assert all("pick_bundle" in c for c in cells if "copytree" in c)
