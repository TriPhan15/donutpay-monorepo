"""Phân lớp người dùng theo RFM (Recency, Frequency, Monetary) bằng ngũ phân vị.

Nguồn:
- RFM và cách chấm điểm theo ngũ phân vị: Hughes, A. M. (1994) "Strategic
  Database Marketing", Probus (CHƯA KIỂM CHỨNG); Bult, J. R., Wansbeek, T.
  (1995) "Optimal selection for direct mail", Marketing Science 14(4):378-394
  (CHƯA KIỂM CHỨNG).
- Tên segment rút gọn từ bảng segment RFM phổ biến trong ngành
  (Champions / Loyal / At Risk / Hibernating / Lost; ví dụ tài liệu "RFM
  segmentation" của Putler; CHƯA KIỂM CHỨNG, nguồn không bình duyệt).
- Luật ánh xạ điểm RFM sang segment là lựa chọn thiết kế của dự án.

Người dùng không có khoản chi nào trong 12 tháng (frequency == 0) là LOST và
không tham gia chấm ngũ phân vị, để họ không kéo lệch điểm của người còn lại.
"""

import math
from bisect import bisect_left, bisect_right
from dataclasses import dataclass
from enum import Enum
from typing import List, Sequence

QUINTILES = 5
HIGH_SCORE = 4
MID_SCORE = 3
LOW_SCORE = 2
LOST_RFM_CODE = "000"


class Segment(str, Enum):
    CHAMPIONS = "CHAMPIONS"
    LOYAL = "LOYAL"
    NEW = "NEW"
    NEED_ATTENTION = "NEED_ATTENTION"
    AT_RISK = "AT_RISK"
    HIBERNATING = "HIBERNATING"
    LOST = "LOST"


@dataclass(frozen=True)
class RfmInput:
    user_id: str
    recency: int
    frequency: int
    monetary: float


@dataclass(frozen=True)
class SegmentResult:
    user_id: str
    label: Segment
    rfm: str


def quintile_scores(values: Sequence[float], higher_is_better: bool = True) -> List[int]:
    """Điểm 1..5 theo thứ hạng phần trăm trung điểm (giá trị bằng nhau chung điểm).

    score = min(5, 1 + floor(5 * (less + 0.5 * equal) / n)). Một người dùng
    duy nhất, hoặc mọi giá trị bằng nhau, nhận điểm giữa (3).
    """
    n = len(values)
    if n == 0:
        return []
    signed = [v if higher_is_better else -v for v in values]
    scores = []
    ordered = sorted(signed)
    for v in signed:
        less = bisect_left(ordered, v)
        equal = bisect_right(ordered, v) - less
        scores.append(min(QUINTILES, 1 + math.floor(QUINTILES * (less + 0.5 * equal) / n)))
    return scores


def segment_of(r: int, f: int, m: int) -> Segment:
    """Luật đầu tiên khớp thắng.

    Lựa chọn thiết kế: Monetary chỉ ảnh hưởng tới CHAMPIONS; các segment còn
    lại chỉ xét Recency và Frequency.
    """
    if r >= HIGH_SCORE and f >= HIGH_SCORE and m >= HIGH_SCORE:
        return Segment.CHAMPIONS
    if r >= HIGH_SCORE and f <= LOW_SCORE:
        return Segment.NEW
    if r >= MID_SCORE and f >= MID_SCORE:
        return Segment.LOYAL
    if r <= LOW_SCORE and f >= MID_SCORE:
        return Segment.AT_RISK
    if r <= LOW_SCORE:
        return Segment.HIBERNATING
    return Segment.NEED_ATTENTION


def segment_users(users: Sequence[RfmInput]) -> List[SegmentResult]:
    """Giữ nguyên thứ tự input; frequency == 0 là LOST và không được chấm điểm."""
    active = [u for u in users if u.frequency > 0]
    r_scores = quintile_scores([u.recency for u in active], higher_is_better=False)
    f_scores = quintile_scores([u.frequency for u in active])
    m_scores = quintile_scores([u.monetary for u in active])
    scored = iter(zip(r_scores, f_scores, m_scores))

    results = []
    for u in users:
        if u.frequency <= 0:
            results.append(SegmentResult(u.user_id, Segment.LOST, LOST_RFM_CODE))
            continue
        r, f, m = next(scored)
        results.append(SegmentResult(u.user_id, segment_of(r, f, m), f"{r}{f}{m}"))
    return results
