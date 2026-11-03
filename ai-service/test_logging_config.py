import logging
from typing import Iterator

import pytest

import logging_config
from logging_config import LOG_LEVEL_ENV, configure_logging


@pytest.fixture(autouse=True)
def isolated_root(monkeypatch: pytest.MonkeyPatch) -> Iterator[logging.Logger]:
    root = logging.getLogger()
    saved_handlers, saved_level = root.handlers[:], root.level
    root.handlers[:] = [h for h in saved_handlers if not getattr(h, logging_config._HANDLER_MARK, False)]
    monkeypatch.delenv(LOG_LEVEL_ENV, raising=False)
    yield root
    root.handlers[:] = saved_handlers
    root.setLevel(saved_level)


def _own(root: logging.Logger) -> list:
    return [h for h in root.handlers if getattr(h, logging_config._HANDLER_MARK, False)]


def test_explicit_level_adds_one_handler(isolated_root: logging.Logger) -> None:
    configure_logging("DEBUG")
    assert isolated_root.level == logging.DEBUG
    assert len(_own(isolated_root)) == 1


def test_second_call_does_not_duplicate(isolated_root: logging.Logger) -> None:
    configure_logging("DEBUG")
    configure_logging("DEBUG")
    assert len(_own(isolated_root)) == 1


def test_env_level_used_without_argument(
    isolated_root: logging.Logger, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(LOG_LEVEL_ENV, "WARNING")
    configure_logging()
    assert isolated_root.level == logging.WARNING


def test_invalid_level_falls_back_to_info(isolated_root: logging.Logger) -> None:
    configure_logging("bogus")
    assert isolated_root.level == logging.INFO


def test_default_is_info(isolated_root: logging.Logger) -> None:
    configure_logging()
    assert isolated_root.level == logging.INFO


def test_module_info_reaches_stream(
    isolated_root: logging.Logger, capsys: pytest.CaptureFixture
) -> None:
    configure_logging("INFO")
    logging.getLogger("ai_service").info("xin chao")
    assert "xin chao" in capsys.readouterr().err
