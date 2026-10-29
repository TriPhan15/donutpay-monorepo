"""Local (Vietnam, UTC+7) date handling for transaction timestamps.

A fixed offset is used on purpose: Vietnam has no DST, and this avoids a
tzdata dependency in the slim container image.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Optional

LOCAL_TZ = timezone(timedelta(hours=7))


def local_today() -> date:
    return datetime.now(LOCAL_TZ).date()


def parse_local_date(raw: str) -> Optional[date]:
    """Parse an ISO date/datetime into a local calendar date.

    Aware timestamps are converted to UTC+7; naive ones are taken as already
    local; a bare date is used as is. Never raises: bad input gives None.
    """
    try:
        text = (raw or "").strip()
        if not text:
            return None
        if text[-1] in "zZ":
            text = text[:-1] + "+00:00"
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is not None:
            return parsed.astimezone(LOCAL_TZ).date()
        return parsed.date()
    except (ValueError, TypeError, OverflowError):
        return None
