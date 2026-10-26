import pytest

from relabel_gemini import get_api_key, is_daily_quota_error


class FakeApiError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def test_get_api_key_from_env(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "k")
    assert get_api_key() == "k"


def test_get_api_key_missing(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    with pytest.raises(RuntimeError, match="Secrets"):
        get_api_key()


def test_daily_quota_detection():
    assert is_daily_quota_error(FakeApiError(429, "RESOURCE_EXHAUSTED: Quota exceeded for metric generate_requests_per_model_per_day"))
    assert is_daily_quota_error(FakeApiError(429, "Quota exceeded ... PerDay limit"))
    assert not is_daily_quota_error(FakeApiError(429, "Quota exceeded for metric ... per minute"))
    assert not is_daily_quota_error(ValueError("x"))
