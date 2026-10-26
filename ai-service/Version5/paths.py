"""Vị trí bundle, nhãn và ảnh (trên Kaggle hoặc máy local)."""

from pathlib import Path

BUNDLE_DIR = Path(__file__).resolve().parent
LABEL_ROOT = BUNDLE_DIR / "data1"
KAGGLE_INPUT = Path("/kaggle/input")
IS_KAGGLE = KAGGLE_INPUT.exists()
WORK_DIR = Path("/kaggle/working") if IS_KAGGLE else BUNDLE_DIR
LOCAL_IMAGE_ROOT = BUNDLE_DIR.parent / "data1"


def _search_roots() -> list[Path]:
    return [KAGGLE_INPUT] if IS_KAGGLE else [LOCAL_IMAGE_ROOT]


def find_image_root(probe: tuple[str, str], search_roots: list[Path] | None = None) -> Path:
    """Tìm thư mục chứa `<split>/<file_name>`; nhãn trong Version5 không chứa ảnh."""
    split, file_name = probe
    for root in search_roots if search_roots is not None else _search_roots():
        if (root / split / file_name).is_file():
            return root
        for candidate in sorted(root.rglob(file_name)):
            if candidate.parent.name == split and candidate.is_file():
                return candidate.parent.parent
    raise FileNotFoundError(f"Không tìm thấy ảnh {split}/{file_name} trong các thư mục ảnh")


# Thư mục nằm cạnh bundle trong output của một phiên Kaggle trước (không phải dataset Version5 mới upload)
PREVIOUS_OUTPUT_MARKERS = ("donut_checkpoints", "donut_result", "relabel_cache", "relabel")


def pick_bundle(candidates: list[Path]) -> Path:
    fresh = [c for c in candidates if not any((c.parent / m).exists() for m in PREVIOUS_OUTPUT_MARKERS)]
    if len(fresh) == 1:
        return fresh[0]
    raise RuntimeError(f"Không chọn được bundle Version5 duy nhất trong {candidates}; "
                       f"đặt BUNDLE_SRC = đường dẫn bundle đúng ở cell này")
