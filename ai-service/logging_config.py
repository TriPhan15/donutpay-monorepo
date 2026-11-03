import logging
import os
import sys
from typing import Optional

LOG_LEVEL_ENV = "LOG_LEVEL"
DEFAULT_LOG_LEVEL = "INFO"
LOG_FORMAT = "%(asctime)s %(levelname)s [%(name)s] %(message)s"

# Dấu hiệu để nhận ra handler do module này gắn, tránh nhân đôi khi gọi lại
_HANDLER_MARK = "_ledgermind_handler"


def _resolve_level(level: Optional[str]) -> int:
    name = (level or os.environ.get(LOG_LEVEL_ENV) or DEFAULT_LOG_LEVEL).strip().upper()
    value = logging.getLevelName(name)
    return value if isinstance(value, int) else logging.getLevelName(DEFAULT_LOG_LEVEL)


def configure_logging(level: Optional[str] = None) -> None:
    """Gắn một StreamHandler (stderr) vào root logger để logger.info của các module hiện ra ở log container.

    Chỉ root bị đụng tới: các logger uvicorn.* có handler riêng và không propagate nên không bị ghi trùng.
    """
    root = logging.getLogger()
    root.setLevel(_resolve_level(level))
    if any(getattr(h, _HANDLER_MARK, False) for h in root.handlers):
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter(LOG_FORMAT))
    setattr(handler, _HANDLER_MARK, True)
    root.addHandler(handler)
