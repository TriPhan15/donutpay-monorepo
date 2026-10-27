"""WCM-SPADE: khai phá mẫu tuần tự có trọng số trên chuỗi chi tiêu theo tuần.

Thành phần:
- CM-SPADE (Fournier-Viger et al. 2014): SPADE id-list dọc + CMAP (bản đồ đồng
  xuất hiện) để tỉa ứng viên trước khi nối id-list. CMAP ở đây giữ cả cặp a→a và
  so với ngưỡng support thô ``raw_bound``.
- Weighted support kiểu WSpan (Yun & Leggett 2006): trọng số mẫu = trung bình
  trọng số item; tỉa bằng cận trên ``support × maxW``. Công thức MaxW CHƯA KIỂM
  CHỨNG trong bài gốc.
- Lọc closed (BIDE, Wang & Han 2004): ẩn mẫu khi có mẫu cha được hiện với cùng
  support thô.
- Luật tuần tự A ⇒ B (``sequential_rules``): confidence, Laplace, lift trên các
  mẫu 2 itemset đã khai phá; xem ghi chú phương pháp trong docstring của hàm.

Mỗi chuỗi là một tuần ISO (danh sách itemset theo ngày). Đây là xấp xỉ WINEPI với
cửa sổ tumbling 7 ngày (Mannila et al. 1997).

Trọng số item: ``w(i) = m · total(i) / Σ total`` (tỷ trọng chi tiêu chia cho tỷ
trọng trung bình, m = số item có mặt), nên trung bình trọng số bằng 1.
"""

from __future__ import annotations

import logging
import math
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, Iterable, List, Mapping, Sequence, Set, Tuple

logger = logging.getLogger(__name__)

Item = str
Itemset = Tuple[Item, ...]
Sequence_ = List[Itemset]
PatternKey = Tuple[Itemset, ...]
IDList = Dict[int, List[int]]

DEFAULT_MIN_SUP: float = 0.25
DEFAULT_MAX_PATTERN_LENGTH: int = 4
DEFAULT_MAX_PATTERNS: int = 50_000

# Sai số dấu phẩy động khi so ngưỡng weighted support.
FLOAT_TOLERANCE: float = 1e-9
# Trọng số khi tổng chi bằng 0 (mọi item ngang nhau).
NEUTRAL_WEIGHT: float = 1.0
MIN_RAW_BOUND: int = 1

# Ngưỡng cảnh báo cho luật tuần tự (lựa chọn thiết kế, xem ``sequential_rules``).
MIN_ANTECEDENT_SUPPORT: int = 4
MIN_LAPLACE_CONFIDENCE: float = 0.6
MIN_LIFT: float = 1.2


@dataclass(frozen=True)
class Pattern:
    itemsets: PatternKey
    sids: Tuple[int, ...]
    raw_sup: int
    weight: float
    wsup: float

    def item_count(self) -> int:
        return sum(len(itemset) for itemset in self.itemsets)


@dataclass(frozen=True)
class WCMSpadeResult:
    patterns: List[Pattern]
    explored: Dict[PatternKey, Pattern]
    n_sequences: int
    min_wsup: float
    raw_bound: int
    max_weight: float
    item_weights: Dict[Item, float]
    # True khi max_patterns cắt DFS lúc còn mẫu đạt raw_bound chưa được ghi.
    truncated: bool = False


def item_weights_from_totals(
    items: Iterable[Item], spending_totals: Mapping[Item, float]
) -> Dict[Item, float]:
    """``w(i) = m · total(i) / Σ total`` trên các item có mặt; Σ = 0 thì mọi w = 1."""
    unique_items = sorted(set(items))
    totals = {item: max(0.0, float(spending_totals.get(item, 0.0))) for item in unique_items}
    grand_total = sum(totals.values())
    if grand_total <= 0.0:
        return {item: NEUTRAL_WEIGHT for item in unique_items}
    m = len(unique_items)
    return {item: m * total / grand_total for item, total in totals.items()}


def is_subpattern(sub: PatternKey, sup: PatternKey) -> bool:
    """Mỗi itemset của ``sub`` là tập con của một itemset của ``sup``, đúng thứ tự."""
    position = 0
    for itemset in sub:
        wanted = set(itemset)
        while position < len(sup) and not wanted.issubset(sup[position]):
            position += 1
        if position == len(sup):
            return False
        position += 1
    return True


def _closed(patterns: List[Pattern]) -> List[Pattern]:
    """Bỏ P khi có Q ≠ P cùng support thô mà P là mẫu con của Q."""
    by_support: Dict[int, List[Pattern]] = defaultdict(list)
    for pattern in patterns:
        by_support[pattern.raw_sup].append(pattern)
    kept: List[Pattern] = []
    for group in by_support.values():
        for pattern in group:
            absorbed = any(
                other.itemsets != pattern.itemsets and is_subpattern(pattern.itemsets, other.itemsets)
                for other in group
            )
            if not absorbed:
                kept.append(pattern)
    return kept


class WCMSpade:
    def __init__(
        self,
        min_sup: float = DEFAULT_MIN_SUP,
        max_pattern_length: int = DEFAULT_MAX_PATTERN_LENGTH,
        max_patterns: int = DEFAULT_MAX_PATTERNS,
        use_cmap: bool = True,
    ) -> None:
        self.min_sup = min_sup
        self.max_pattern_length = max_pattern_length
        self.max_patterns = max_patterns
        self.use_cmap = use_cmap

        self._n_sequences = 0
        self._raw_bound = MIN_RAW_BOUND
        self._min_wsup = 0.0
        self._item_weights: Dict[Item, float] = {}
        self._item_idlists: Dict[Item, IDList] = {}
        self._cmap_s: Dict[Item, Dict[Item, int]] = {}
        self._cmap_i: Dict[Item, Dict[Item, int]] = {}
        self._explored: Dict[PatternKey, Pattern] = {}
        self._truncated = False

    # ---- chuẩn bị dữ liệu ----

    @staticmethod
    def _normalize(sequences: Sequence[Sequence_]) -> List[List[Itemset]]:
        return [[tuple(sorted(set(itemset))) for itemset in seq] for seq in sequences]

    @staticmethod
    def _build_idlists(sequences: List[List[Itemset]]) -> Dict[Item, IDList]:
        idlists: Dict[Item, IDList] = defaultdict(lambda: defaultdict(list))
        for sid, seq in enumerate(sequences):
            for eid, itemset in enumerate(seq):
                for item in itemset:
                    idlists[item][sid].append(eid)
        return {item: dict(by_sid) for item, by_sid in idlists.items()}

    def _build_cmaps(self, sequences: List[List[Itemset]], frequent: Set[Item]) -> None:
        """CMAP: số chuỗi có a đứng trước hẳn b (kể cả a == b) / có a, b chung itemset."""
        cmap_s: Dict[Item, Dict[Item, int]] = defaultdict(lambda: defaultdict(int))
        cmap_i: Dict[Item, Dict[Item, int]] = defaultdict(lambda: defaultdict(int))
        for seq in sequences:
            seen_before: Set[Item] = set()
            pairs_after: Set[Tuple[Item, Item]] = set()
            pairs_same: Set[Tuple[Item, Item]] = set()
            for itemset in seq:
                items = [item for item in itemset if item in frequent]
                for a in seen_before:
                    for b in items:
                        pairs_after.add((a, b))
                for index, a in enumerate(items):
                    for b in items[index + 1:]:
                        pairs_same.add((a, b))
                seen_before.update(items)
            for a, b in pairs_after:
                cmap_s[a][b] += 1
            for a, b in pairs_same:
                cmap_i[a][b] += 1
        self._cmap_s = {a: dict(row) for a, row in cmap_s.items()}
        self._cmap_i = {a: dict(row) for a, row in cmap_i.items()}

    # ---- phép nối id-list ----

    @staticmethod
    def _s_extend(p_idlist: IDList, x_idlist: IDList) -> IDList:
        res: IDList = {}
        for sid, p_eids in p_idlist.items():
            x_eids = x_idlist.get(sid)
            if not x_eids:
                continue
            min_p = p_eids[0]
            kept = [e for e in x_eids if e > min_p]
            if kept:
                res[sid] = kept
        return res

    @staticmethod
    def _i_extend(p_idlist: IDList, x_idlist: IDList) -> IDList:
        res: IDList = {}
        for sid, p_eids in p_idlist.items():
            x_eids = x_idlist.get(sid)
            if not x_eids:
                continue
            xs = set(x_eids)
            kept = [e for e in p_eids if e in xs]
            if kept:
                res[sid] = kept
        return res

    # ---- DFS ----

    def _pattern_weight(self, itemsets: PatternKey) -> float:
        weights = [self._item_weights[item] for itemset in itemsets for item in itemset]
        return sum(weights) / len(weights)

    def _record(self, itemsets: PatternKey, idlist: IDList) -> Pattern:
        raw_sup = len(idlist)
        weight = self._pattern_weight(itemsets)
        pattern = Pattern(
            itemsets=itemsets,
            sids=tuple(sorted(idlist)),
            raw_sup=raw_sup,
            weight=weight,
            wsup=raw_sup * weight / self._n_sequences,
        )
        self._explored[itemsets] = pattern
        return pattern

    def _admit(self, itemsets: PatternKey, idlist: IDList) -> bool:
        """Ghi mẫu nếu còn ngân sách; hết ngân sách thì đánh dấu truncated."""
        if len(self._explored) >= self.max_patterns:
            self._truncated = True
            return False
        self._record(itemsets, idlist)
        return True

    def _cmap_allows(self, cmap: Dict[Item, Dict[Item, int]], last: Item, y: Item) -> bool:
        if not self.use_cmap:
            return True
        return cmap.get(last, {}).get(y, 0) >= self._raw_bound

    def _extend(self, itemsets: PatternKey, idlist: IDList, item_count: int) -> None:
        if item_count >= self.max_pattern_length:
            return
        last = itemsets[-1][-1]

        # S-extension: thêm itemset mới {y} sau cùng.
        for y, y_idlist in self._item_idlists.items():
            if self._truncated:
                return
            if not self._cmap_allows(self._cmap_s, last, y):
                continue
            new_idlist = self._s_extend(idlist, y_idlist)
            if len(new_idlist) >= self._raw_bound:
                child = itemsets + ((y,),)
                if not self._admit(child, new_idlist):
                    return
                self._extend(child, new_idlist, item_count + 1)

        # I-extension: thêm y > last vào itemset cuối.
        for y, y_idlist in self._item_idlists.items():
            if self._truncated:
                return
            if y <= last or not self._cmap_allows(self._cmap_i, last, y):
                continue
            new_idlist = self._i_extend(idlist, y_idlist)
            if len(new_idlist) >= self._raw_bound:
                child = itemsets[:-1] + (itemsets[-1] + (y,),)
                if not self._admit(child, new_idlist):
                    return
                self._extend(child, new_idlist, item_count + 1)

    def mine(
        self, sequences: Sequence[Sequence_], spending_totals: Mapping[Item, float]
    ) -> WCMSpadeResult:
        normalized = self._normalize(sequences)
        self._n_sequences = len(normalized)
        self._explored = {}
        self._truncated = False
        all_idlists = self._build_idlists(normalized)
        self._item_weights = item_weights_from_totals(all_idlists.keys(), spending_totals)
        max_weight = max(self._item_weights.values(), default=NEUTRAL_WEIGHT)
        self._min_wsup = self.min_sup * self._n_sequences
        self._raw_bound = max(
            MIN_RAW_BOUND, math.ceil(self._min_wsup / max_weight - FLOAT_TOLERANCE)
        )

        if self._n_sequences == 0:
            return self._result([], max_weight)

        self._item_idlists = {
            item: all_idlists[item]
            for item in sorted(all_idlists)
            if len(all_idlists[item]) >= self._raw_bound
        }
        self._build_cmaps(normalized, set(self._item_idlists))

        for item, idlist in self._item_idlists.items():
            root: PatternKey = ((item,),)
            if self._truncated or not self._admit(root, idlist):
                break
            self._extend(root, idlist, 1)

        if self._truncated:
            logger.warning("WCM-SPADE dừng sớm: đạt max_patterns=%d", self.max_patterns)

        shown = [
            p for p in self._explored.values()
            if p.raw_sup * p.weight >= self._min_wsup - FLOAT_TOLERANCE
        ]
        ranked = sorted(_closed(shown), key=lambda p: (-p.wsup, -p.raw_sup, p.itemsets))
        return self._result(ranked, max_weight)

    def _result(self, patterns: List[Pattern], max_weight: float) -> WCMSpadeResult:
        return WCMSpadeResult(
            patterns=patterns,
            explored=dict(self._explored),
            n_sequences=self._n_sequences,
            min_wsup=self._min_wsup,
            raw_bound=self._raw_bound,
            max_weight=max_weight,
            item_weights=dict(self._item_weights),
            truncated=self._truncated,
        )


# ---- luật tuần tự A ⇒ B ----

RULE_ITEMSET_COUNT: int = 2


@dataclass(frozen=True)
class SequentialRule:
    """Luật "tuần có A thì sau đó (cùng tuần) có B"; mọi support đếm theo số tuần."""

    antecedent: Itemset
    consequent: Itemset
    support: int
    antecedent_support: int
    consequent_support: int
    n_sequences: int
    sids: Tuple[int, ...]

    @property
    def confidence(self) -> float:
        return self.support / self.antecedent_support

    @property
    def laplace_confidence(self) -> float:
        return (self.support + 1) / (self.antecedent_support + 2)

    @property
    def lift(self) -> float:
        return self.confidence / (self.consequent_support / self.n_sequences)


def sequential_rules(
    result: WCMSpadeResult,
    min_antecedent_support: int = MIN_ANTECEDENT_SUPPORT,
    min_laplace_confidence: float = MIN_LAPLACE_CONFIDENCE,
    min_lift: float = MIN_LIFT,
) -> List[SequentialRule]:
    """Sinh luật A ⇒ B từ các mẫu đúng 2 itemset ``(A, B)`` trong ``result.explored``.

    Chỉ nhận A ∩ B = ∅ (mẫu a→a là mẫu, không phải luật). ``antecedent_support`` và
    ``consequent_support`` tra ở ``explored[(A,)]`` / ``explored[(B,)]``; thiếu thì
    bỏ luật đó. Giữ luật có sup(A) ≥ ``min_antecedent_support``, Laplace ≥
    ``min_laplace_confidence`` và lift ≥ ``min_lift``; xếp theo (Laplace giảm, lift
    giảm, support giảm, A, B).

    Ghi chú phương pháp:

    1. confidence = sup(A⇒B) / sup(A), theo định nghĩa luật tuần tự của
       Fournier-Viger et al. 2015 (IEEE TKDE 27(8)).
    2. Laplace ``(sup + 1) / (sup(A) + 2)`` và các ngưỡng 4 / 0,6 / 1,2 là lựa chọn
       thiết kế của dự án, không phải giá trị công bố trong tài liệu.
    3. Mức nền của lift là tỷ lệ "tuần có B ở bất kỳ đâu" (không đòi B đứng sau một
       mốc nào), nên lift là ước lượng bảo thủ.
    4. Ý nghĩa thống kê: khai phá nhiều luật trên 13–26 tuần sẽ có luật "trúng" do
       ngẫu nhiên. Lift và Laplace không thay được kiểm định (Fisher exact/binomial
       kèm hiệu chỉnh Holm, hoặc tách holdout) theo Webb, G. I. (2007) "Discovering
       significant patterns", Machine Learning 68(1):1–33 (CHƯA KIỂM CHỨNG). Kết quả
       chỉ là mô tả lịch sử chi tiêu, không phải phát hiện có ý nghĩa thống kê.
    """
    explored = result.explored
    rules: List[SequentialRule] = []
    for itemsets, pattern in explored.items():
        if len(itemsets) != RULE_ITEMSET_COUNT:
            continue
        antecedent, consequent = itemsets
        if not set(antecedent).isdisjoint(consequent):
            continue
        antecedent_pattern = explored.get((antecedent,))
        consequent_pattern = explored.get((consequent,))
        if antecedent_pattern is None or consequent_pattern is None:
            continue
        rule = SequentialRule(
            antecedent=antecedent,
            consequent=consequent,
            support=pattern.raw_sup,
            antecedent_support=antecedent_pattern.raw_sup,
            consequent_support=consequent_pattern.raw_sup,
            n_sequences=result.n_sequences,
            sids=pattern.sids,
        )
        if (
            rule.antecedent_support >= min_antecedent_support
            and rule.laplace_confidence >= min_laplace_confidence - FLOAT_TOLERANCE
            and rule.lift >= min_lift - FLOAT_TOLERANCE
        ):
            rules.append(rule)
    rules.sort(
        key=lambda r: (-r.laplace_confidence, -r.lift, -r.support, r.antecedent, r.consequent)
    )
    return rules
