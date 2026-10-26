"""Đọc lại nhãn hóa đơn bằng Gemini API (đọc chính)."""

import io
import os
import re
import sys
import time
from argparse import ArgumentParser, Namespace
from pathlib import Path
from typing import Callable

from labels import read_image
from relabel_common import QuotaExhausted, ReceiptFields, run_cli

# Tra ngày 2026-10-17 trên https://ai.google.dev/gemini-api/docs/latest-model: gemini-3.6-flash là bản Flash GA mới nhất.
# Free tier của Flash theo báo cáo trên forum Google chỉ khoảng 20 request/ngày (Flash-Lite ~500/ngày);
# xem lại https://ai.google.dev/gemini-api/docs/rate-limits và đổi bằng --model nếu cần.
GEMINI_MODEL = "gemini-3.6-flash"
API_KEY_NAME = "GEMINI_API_KEY"
MAX_MINUTE_RETRIES = 5
DEFAULT_RETRY_SECONDS = 30
JPEG_QUALITY = 95
_DAILY = re.compile(r"per[\s_-]*day|perday|daily", re.IGNORECASE)
_RETRY_DELAY = re.compile(r"retryDelay['\"]?\s*[:=]\s*['\"]?(\d+)")


def get_api_key() -> str:
    try:
        from kaggle_secrets import UserSecretsClient  # type: ignore[import-not-found]
        return UserSecretsClient().get_secret(API_KEY_NAME)
    except ImportError:
        pass
    key = os.environ.get(API_KEY_NAME)
    if key:
        return key
    raise RuntimeError(f"Chưa có {API_KEY_NAME}: trên Kaggle vào Add-ons -> Secrets để thêm, "
                       f"ở máy local thì đặt biến môi trường {API_KEY_NAME}.")


def _is_rate_limited(exc: Exception) -> bool:
    return getattr(exc, "code", None) == 429 or "RESOURCE_EXHAUSTED" in str(exc)


def is_daily_quota_error(exc: Exception) -> bool:
    return _is_rate_limited(exc) and bool(_DAILY.search(str(exc)))


def _retry_seconds(exc: Exception) -> int:
    match = _RETRY_DELAY.search(str(exc))
    return int(match.group(1)) + 1 if match else DEFAULT_RETRY_SECONDS


def _jpeg_bytes(path: Path) -> bytes:
    buf = io.BytesIO()
    read_image(path).save(buf, format="JPEG", quality=JPEG_QUALITY)
    return buf.getvalue()


def make_gemini_reader(api_key: str, model: str, prompt: str) -> Callable[[Path], str]:
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)
    config = types.GenerateContentConfig(
        response_mime_type="application/json", response_schema=ReceiptFields, temperature=0
    )

    def read(path: Path) -> str:
        image = types.Part.from_bytes(data=_jpeg_bytes(path), mime_type="image/jpeg")
        for attempt in range(MAX_MINUTE_RETRIES + 1):
            try:
                return client.models.generate_content(model=model, contents=[image, prompt], config=config).text or ""
            except Exception as exc:  # noqa: BLE001 - chỉ xử lý lỗi quota ở đây, lỗi khác ném tiếp
                if is_daily_quota_error(exc):
                    raise QuotaExhausted(str(exc)[:200]) from exc
                if not _is_rate_limited(exc) or attempt == MAX_MINUTE_RETRIES:
                    raise
                wait = _retry_seconds(exc)
                print(f"Bị giới hạn theo phút, chờ {wait}s rồi thử lại ({path.name})")
                time.sleep(wait)
        raise RuntimeError("unreachable")

    return read


def _add_args(parser: ArgumentParser) -> None:
    parser.add_argument("--model", default=GEMINI_MODEL)


def _make(prompt: str, args: Namespace) -> Callable[[Path], str]:
    return make_gemini_reader(get_api_key(), args.model, prompt)


if __name__ == "__main__":
    sys.exit(run_cli("gemini", _make, add_args=_add_args))
