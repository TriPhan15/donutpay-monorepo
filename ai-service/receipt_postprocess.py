"""Hậu xử lý 4 trường Donut V5 (SELLER, ADDRESS, TIMESTAMP, TOTAL_COST) bằng Regex.

Model đọc đúng phần lớn ký tự nhưng hay sai ở dấu câu, khoảng trắng và định dạng; module này chuẩn hóa
giá trị và gắn cờ `valid` cho từng trường để app biết trường nào người dùng cần sửa. Chỉ dùng thư viện
chuẩn + Pydantic, không tải model, nên test được độc lập với ai_service.py.
"""

from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime, timedelta
from enum import Enum
from typing import Dict, List, Mapping, Optional, Tuple

from pydantic import BaseModel

from local_time import local_today


class ReceiptField(str, Enum):
    """Tên thẻ trường trong chuỗi Donut V5 (Version5/model_config.py FIELD_TAGS)."""

    SELLER = "seller_name"
    ADDRESS = "address"
    TIMESTAMP = "timestamp"
    TOTAL_COST = "total_cost"


# --- Giới hạn hợp lệ --------------------------------------------------------
MIN_AMOUNT = 100  # VND: hóa đơn nhỏ nhất hợp lý
MAX_AMOUNT = 1_000_000_000
MIN_YEAR = 2000
FUTURE_YEAR_SLACK = 1
TWO_DIGIT_YEAR_BASE = 2000
SELLER_MAX_LENGTH = 100
ADDRESS_MAX_LENGTH = 250
SELLER_MIN_LETTERS = 2
ADDRESS_MIN_LETTERS = 3
NOON_HOUR = 12

# Từ khóa tổng tiền, xếp theo độ ưu tiên (cụm cụ thể trước cụm chung)
TOTAL_KEYWORDS: Tuple[str, ...] = (
    "tổng thanh toán",
    "cần thanh toán",
    "khách phải trả",
    "phải trả",
    "tổng cộng",
    "tổng tiền",
    "thành tiền",
    "grand total",
    "total",
    "tổng",
    "thanh toán",
)

PM_MARKERS = frozenset({"pm", "p.m.", "ch"})  # CH = chiều
AM_MARKERS = frozenset({"am", "a.m.", "sa"})  # SA = sáng

MONTH_NAMES: Dict[str, int] = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}

# --- Regex --------------------------------------------------------------------
_TAG = re.compile(r"</?s_[a-z_]+>")
_JUNK_CHARS = re.compile(r"[^\w\s.,\-/&'’+()!:;#]|_")
_REPEATED_PUNCT = re.compile(r"([.,;:\-/])\1+")
_SPACE_BEFORE_PUNCT = re.compile(r"\s+([,;:!)])")
_COMMA_WITHOUT_SPACE = re.compile(r",(?=[^\W\d_]{2})|(?<=[^\W\d_]),(?=\d)")
_ABBREVIATION_DOT = re.compile(r"(?<![^\W\d_])([^\W\d_]{1,2})\.(?=[^\W\d_])")
_EDGE_JUNK = re.compile(r"^[\s.,;:\-/]+|[\s.,;:\-/]+$")
_LETTER = re.compile(r"[^\W\d_]")

# Số tiền: nhóm nghìn bằng . , hoặc dấu cách (30,200.00 / 1.011.780 / 105 000), hoặc số liền (55000)
_AMOUNT = re.compile(r"(?<![\d.,])(?:\d{1,3}(?:[.,]\d{3})+|\d{1,3}(?: \d{3})+|\d+)(?:[.,]\d{1,2})?(?![\d])")
_DECIMAL_SUFFIX = re.compile(r"[.,]\d{1,2}$")
_THOUSANDS_ONLY = re.compile(r"\d{1,3}(?:[.,]\d{3})+")

# Chỉ gộp dấu cách quanh / : . ("11 / 08 / 2020 - 21 : 37"); " - " giữa giờ và ngày giữ nguyên
_SPACED_SEPARATOR = re.compile(r"(?<=\d)\s*([/.:])\s*(?=\d)|(?<=\d)\s+([/\-])(?=\d)|(?<=\d)([/\-])\s+(?=\d)")
# Tìm chồng lấn (lookahead) để một mẫu sai như "16-13/08" không nuốt mất ngày đúng "13/08/2020" phía sau
_DATE_YMD = re.compile(r"(?<!\d)(?=(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?!\d))")
# Nhóm 2 và 4 là dấu phân cách: năm 2 chữ số chỉ nhận "/" hoặc "-", vì "10.30.15" thường là giờ 10:30:15, không phải ngày.
_DATE_DMY = re.compile(r"(?<!\d)(?=(\d{1,2})([/\-.])(\d{1,2})([/\-.])(\d{4}|\d{2})(?!\d))")
TWO_DIGIT_YEAR_SEPARATORS = frozenset({"/", "-"})
# "10 tháng 02 năm 2023", "02 thg 2, 2023"
_DATE_VI_WORDS = re.compile(r"(?<!\d)(\d{1,2})\s*(?:tháng|thg)\s*(\d{1,2}),?\s*(?:năm\s*)?(\d{4})(?!\d)", re.IGNORECASE)
# "Jan 14, 22"
_DATE_EN_MONTH_FIRST = re.compile(r"\b([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4}|\d{2})(?!\d)")
# "Mon 09 Jan 2023"
_DATE_EN_DAY_FIRST = re.compile(r"(?<!\d)(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?,?\s+(\d{4})(?!\d)")
_TIME = re.compile(
    r"(?<![\d.:])(\d{1,2})\s*[:hH.]\s*(\d{2})(?:\s*:\s*(\d{2}))?(?![\d])\s*(a\.m\.|p\.m\.|am|pm|sa|ch)?(?![^\W\d_])",
    re.IGNORECASE,
)


# --- Kết quả --------------------------------------------------------------------
class TextFieldResult(BaseModel):
    raw: str
    value: str
    valid: bool


class AmountFieldResult(BaseModel):
    raw: str
    value: Optional[int] = None
    valid: bool


class TimestampFieldResult(BaseModel):
    raw: str
    value: str
    iso: Optional[str] = None
    valid: bool


class NormalizedReceipt(BaseModel):
    seller: TextFieldResult
    address: TextFieldResult
    timestamp: TimestampFieldResult
    total_cost: AmountFieldResult
    invalid_fields: List[str]


# --- Chuỗi Donut ------------------------------------------------------------------
def fields_from_sequence(sequence: str) -> Dict[str, str]:
    """Lấy nội dung từng thẻ trường như Version5/evaluate.py sequence_to_fields (khớp không tham lam)."""
    fields: Dict[str, str] = {}
    for field in ReceiptField:
        tag = field.value
        match = re.search(rf"<s_{tag}>(.*?)</s_{tag}>", sequence, re.DOTALL)
        fields[tag] = match.group(1).strip() if match else ""
    return fields


def _repair_leak(raw: str, field: ReceiptField) -> Tuple[str, bool]:
    """Chuỗi lỗi có thể chứa thẻ của trường khác: giữ phần sau thẻ mở cuối cùng của chính trường đó,
    nếu không có thì phần trước thẻ đầu tiên. Trả về (chuỗi, có_rò_thẻ)."""
    if not _TAG.search(raw):
        return raw, False
    opening = f"<s_{field.value}>"
    if opening in raw:
        return _TAG.sub(" ", raw.rsplit(opening, 1)[1]), True
    return _TAG.split(raw, 1)[0], True


def _base_clean(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    return " ".join(text.split())


# --- SELLER / ADDRESS -------------------------------------------------------------
def _capitalize_if_all_lower(text: str) -> str:
    if any(ch.isupper() for ch in text):
        return text
    return " ".join(word[:1].upper() + word[1:] if word[:1].isalpha() else word for word in text.split(" "))


def clean_text(raw: str, is_address: bool = False) -> str:
    """Bỏ ký tự rác, chuẩn hóa khoảng trắng/dấu câu; chuỗi toàn chữ thường được viết hoa đầu từ."""
    text = _base_clean(raw)
    text = _JUNK_CHARS.sub(" ", text)
    text = _REPEATED_PUNCT.sub(r"\1", text)
    text = _SPACE_BEFORE_PUNCT.sub(r"\1", text)
    text = _COMMA_WITHOUT_SPACE.sub(", ", text)
    if is_address:
        # P.Linh Tây / Q.Thủ Đức / TP.Hồ Chí Minh -> "P. Linh Tây": cùng một cách viết viết tắt
        text = _ABBREVIATION_DOT.sub(r"\1. ", text)
    text = " ".join(text.split())
    text = _EDGE_JUNK.sub("", text)
    return _capitalize_if_all_lower(text)


def _text_is_valid(value: str, min_letters: int, max_length: int) -> bool:
    return bool(value) and len(_LETTER.findall(value)) >= min_letters and len(value) <= max_length


def normalize_text_field(raw: str, field: ReceiptField) -> TextFieldResult:
    is_address = field is ReceiptField.ADDRESS
    repaired, leaked = _repair_leak(raw or "", field)
    value = clean_text(repaired, is_address=is_address)
    min_letters = ADDRESS_MIN_LETTERS if is_address else SELLER_MIN_LETTERS
    max_length = ADDRESS_MAX_LENGTH if is_address else SELLER_MAX_LENGTH
    valid = not leaked and _text_is_valid(value, min_letters, max_length)
    return TextFieldResult(raw=raw or "", value=value, valid=valid)


# --- TOTAL_COST ----------------------------------------------------------------------
def parse_amount_token(token: str) -> Optional[int]:
    """'30,200.00' -> 30200, '1.011.780' -> 1011780, '105 000' -> 105000 (VND không có phần lẻ)."""
    token = token.strip()
    # "88.000" là nhóm nghìn; chỉ 1-2 chữ số sau dấu cuối ("30,200.00", "35.50") mới là phần lẻ bị bỏ
    if not _THOUSANDS_ONLY.fullmatch(token):
        token = _DECIMAL_SUFFIX.sub("", token)
    digits = re.sub(r"\D", "", token)
    return int(digits) if digits else None


def _amounts_with_positions(text: str) -> List[Tuple[int, int]]:
    result: List[Tuple[int, int]] = []
    for match in _AMOUNT.finditer(text):
        value = parse_amount_token(match.group(0))
        if value is not None:
            result.append((match.start(), value))
    return result


def parse_amount(text: str) -> Optional[int]:
    """Số ngay sau từ khóa tổng tiền ưu tiên cao nhất; không có từ khóa thì lấy số cuối cùng (dòng tổng nằm cuối)."""
    text = _base_clean(text)
    amounts = _amounts_with_positions(text)
    if not amounts:
        return None
    lowered = text.lower()
    for keyword in TOTAL_KEYWORDS:
        position = lowered.rfind(keyword)
        if position < 0:
            continue
        after = [value for start, value in amounts if start >= position + len(keyword)]
        if after:
            return after[0]
    return amounts[-1][1]


def normalize_amount_field(raw: str) -> AmountFieldResult:
    repaired, leaked = _repair_leak(raw or "", ReceiptField.TOTAL_COST)
    value = parse_amount(repaired)
    valid = not leaked and value is not None and MIN_AMOUNT <= value <= MAX_AMOUNT
    return AmountFieldResult(raw=raw or "", value=value, valid=valid)


# --- TIMESTAMP ----------------------------------------------------------------------
def _full_year(year: int) -> int:
    return year + TWO_DIGIT_YEAR_BASE if year < 100 else year


def _calendar_date(year: int, month: int, day: int) -> Optional[Tuple[int, int, int]]:
    try:
        datetime(year, month, day)
    except ValueError:
        return None
    return year, month, day


def _date_candidates(text: str) -> List[Tuple[int, Tuple[int, int, int], int]]:
    """(vị trí bắt đầu, (năm, tháng, ngày), vị trí kết thúc) của mọi ngày hợp lệ."""
    found: List[Tuple[int, Tuple[int, int, int], int]] = []

    def add(match: re.Match, year: int, month: int, day: int, end: int) -> None:
        parsed = _calendar_date(year, month, day)
        if parsed is None and month > 12:
            parsed = _calendar_date(year, day, month)  # thứ tự Mỹ MM/dd khi dd/MM không thể đúng
        if parsed is not None:
            found.append((match.start(), parsed, end))

    for match in _DATE_YMD.finditer(text):
        add(match, int(match.group(1)), int(match.group(2)), int(match.group(3)), match.end(3))
    for match in _DATE_DMY.finditer(text):
        year_text = match.group(5)
        if len(year_text) == 2 and not {match.group(2), match.group(4)} <= TWO_DIGIT_YEAR_SEPARATORS:
            continue
        add(match, _full_year(int(year_text)), int(match.group(3)), int(match.group(1)), match.end(5))
    for match in _DATE_VI_WORDS.finditer(text):
        add(match, int(match.group(3)), int(match.group(2)), int(match.group(1)), match.end())
    for match in _DATE_EN_MONTH_FIRST.finditer(text):
        month = MONTH_NAMES.get(match.group(1).lower())
        if month:
            add(match, _full_year(int(match.group(3))), month, int(match.group(2)), match.end())
    for match in _DATE_EN_DAY_FIRST.finditer(text):
        month = MONTH_NAMES.get(match.group(2).lower())
        if month:
            add(match, int(match.group(3)), month, int(match.group(1)), match.end())
    return found


def _find_date(text: str) -> Optional[Tuple[int, int, int, Tuple[int, int]]]:
    """(năm, tháng, ngày, (bắt đầu, kết thúc)) của ngày hợp lệ đứng đầu; ưu tiên thứ tự Việt Nam ngày/tháng/năm."""
    candidates = _date_candidates(text)
    if not candidates:
        return None
    start, (year, month, day), end = min(candidates, key=lambda c: c[0])
    return year, month, day, (start, end)


def _find_time(text: str) -> Optional[Tuple[int, int, int]]:
    for match in _TIME.finditer(text):
        hour, minute = int(match.group(1)), int(match.group(2))
        second = int(match.group(3) or 0)
        marker = (match.group(4) or "").lower()
        if marker in PM_MARKERS and hour < NOON_HOUR:
            hour += NOON_HOUR
        elif marker in AM_MARKERS and hour == NOON_HOUR:
            hour = 0
        if hour < 24 and minute < 60 and second < 60:
            return hour, minute, second
    return None


def clean_timestamp_text(raw: str) -> str:
    """'11 / 08 / 2020 - 21 : 37' -> '11/08/2020 - 21:37'."""
    text = _base_clean(raw)
    text = _SPACED_SEPARATOR.sub(lambda m: next(g for g in m.groups() if g), text)
    return _EDGE_JUNK.sub("", text)


def parse_timestamp(raw: str) -> Optional[str]:
    """ISO 8601: 'YYYY-MM-DDTHH:MM:SS' khi có giờ, 'YYYY-MM-DD' khi chỉ có ngày; None khi không có ngày hợp lệ."""
    text = clean_timestamp_text(raw)
    found = _find_date(text)
    if found is None:
        return None
    year, month, day, (start, end) = found
    max_year = local_today().year + FUTURE_YEAR_SLACK
    if not MIN_YEAR <= year <= max_year:
        return None
    time = _find_time(text[:start] + " " + text[end:])
    if time is None:
        return f"{year:04d}-{month:02d}-{day:02d}"
    hour, minute, second = time
    return datetime(year, month, day, hour, minute, second).isoformat()


MAX_FUTURE_DAYS = 1  # lệch múi giờ/đồng hồ máy in: cho phép hôm nay + 1 ngày


def _is_future(iso: str, today: date) -> bool:
    return date.fromisoformat(iso[:10]) > today + timedelta(days=MAX_FUTURE_DAYS)


def normalize_timestamp_field(raw: str, today: Optional[date] = None) -> TimestampFieldResult:
    repaired, leaked = _repair_leak(raw or "", ReceiptField.TIMESTAMP)
    iso = parse_timestamp(repaired)
    in_future = iso is not None and _is_future(iso, today or local_today())
    return TimestampFieldResult(
        raw=raw or "",
        value=clean_timestamp_text(repaired),
        iso=iso,
        valid=not leaked and iso is not None and not in_future,
    )


# --- Gộp ----------------------------------------------------------------------------
def normalize_receipt(fields: Mapping[str, object], today: Optional[date] = None) -> NormalizedReceipt:
    """`fields` có khóa là tên thẻ (seller_name, address, timestamp, total_cost)."""

    def raw(field: ReceiptField) -> str:
        value = fields.get(field.value)
        return "" if value is None else str(value)

    result = {
        "seller": normalize_text_field(raw(ReceiptField.SELLER), ReceiptField.SELLER),
        "address": normalize_text_field(raw(ReceiptField.ADDRESS), ReceiptField.ADDRESS),
        "timestamp": normalize_timestamp_field(raw(ReceiptField.TIMESTAMP), today),
        "total_cost": normalize_amount_field(raw(ReceiptField.TOTAL_COST)),
    }
    invalid = [name for name, item in result.items() if not item.valid]
    return NormalizedReceipt(**result, invalid_fields=invalid)
