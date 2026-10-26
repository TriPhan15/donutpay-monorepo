"""Test receipt_postprocess bằng chuỗi thật của Donut V5 (Version5/compare_test.csv), không tải model."""

import csv
import sys
from pathlib import Path
from typing import Optional

import pytest

from receipt_postprocess import (
    ReceiptField,
    clean_text,
    fields_from_sequence,
    normalize_amount_field,
    normalize_receipt,
    normalize_text_field,
    normalize_timestamp_field,
    parse_amount,
)

COMPARE_CSV = Path(__file__).resolve().parent / "Version5" / "compare_test.csv"


# --- TOTAL_COST ---------------------------------------------------------------------
@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("30,200.00", 30200),
        ("88,000", 88000),
        ("54.000", 54000),
        ("1.011.780", 1011780),
        ("105 000", 105000),
        ("7 527 660", 7527660),
        ("VND10,900", 10900),
        ("32,955,050", 32955050),
        ("100.000đ", 100000),
        ("Tổng thanh toán 30,200.00", 30200),
        ("Tổng cộng : 88.000", 88000),
        ("Tiền hàng 120.000 Giảm giá 20.000 Tổng cộng 100.000 Tiền khách đưa 200.000", 100000),
        ("Thành tiền 45 000 Tiền thối 5 000", 45000),
    ],
)
def test_parse_amount_reads_vietnamese_formats(raw: str, expected: int) -> None:
    assert parse_amount(raw) == expected


def test_amount_without_number_is_invalid() -> None:
    result = normalize_amount_field("")
    assert result.value is None and not result.valid


@pytest.mark.parametrize("raw", ["0", "0.00"])
def test_zero_amount_is_invalid(raw: str) -> None:
    assert not normalize_amount_field(raw).valid


def test_amount_leaked_from_other_tags_is_recovered_but_flagged() -> None:
    raw = ("35.2016/TT-BGTƯờng - Huyện Từ Nghia, Tỉi</s_address><s_timestamp> 15/11/2016</s_timestamp>"
           "<s_total_cost> 35.000")
    result = normalize_amount_field(raw)
    assert result.value == 35000
    assert not result.valid


# --- TIMESTAMP ----------------------------------------------------------------------
@pytest.mark.parametrize(
    ("raw", "iso"),
    [
        ("10/01/2023 10:13", "2023-01-10T10:13:00"),
        ("10/08/2020-17:20", "2020-08-10T17:20:00"),
        ("11 / 08 / 2020 - 21 : 37", "2020-08-11T21:37:00"),
        ("27 / 12 / 2022 17:46", "2022-12-27T17:46:00"),
        ("24.04.2023 13.06", "2023-04-24T13:06:00"),
        ("08/11/22 18:33", "2022-11-08T18:33:00"),
        ("22/12/2022 08:58 AM", "2022-12-22T08:58:00"),
        ("12/01/2023 5:11 CH", "2023-01-12T17:11:00"),
        ("09/08/2020 (07.26 CH - 07:26 CH)", "2020-08-09T19:26:00"),
        ("10 tháng 02 năm 2023", "2023-02-10"),
        ("02 thg 2, 2023 13:02", "2023-02-02T13:02:00"),
        ("Mon 09 Jan 2023 23:22:42", "2023-01-09T23:22:42"),
        ("Jan 14, 22 11:17 AM", "2022-01-14T11:17:00"),
        ("10:26:16 - 13/08/2020", "2020-08-13T10:26:16"),
        ("2023-03-03 21:40", "2023-03-03T21:40:00"),
        ("12/21/2022 11:48 AM", "2022-12-21T11:48:00"),
        ("14-10-2022", "2022-10-14"),
    ],
)
def test_timestamp_to_iso(raw: str, iso: str) -> None:
    result = normalize_timestamp_field(raw)
    assert result.iso == iso
    assert result.valid


@pytest.mark.parametrize("raw", ["", "15:29:03", "20 10-2022 16:20", "21-11-2923 15:30", "31/02/2023"])
def test_timestamp_without_plausible_date_is_invalid(raw: str) -> None:
    result = normalize_timestamp_field(raw)
    assert result.iso is None
    assert not result.valid


def test_timestamp_value_collapses_spaced_separators() -> None:
    assert normalize_timestamp_field("11 / 08 / 2020 - 21 : 37").value == "11/08/2020 - 21:37"


# --- SELLER / ADDRESS ----------------------------------------------------------------
@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Co.opFood BD CC Samsora Riverside", "Co.opFood BD CC Samsora Riverside"),
        ("PHUC LONG", "PHUC LONG"),
        ("THREE O’CLOCK", "THREE O’CLOCK"),
        ("NHÀ HÀNG CAFE 30/4", "NHÀ HÀNG CAFE 30/4"),
        ("PHUC LONG Coffee & Tea", "PHUC LONG Coffee & Tea"),
        ("**KATINAT - HOÀNG DIỆU 2**", "KATINAT - HOÀNG DIỆU 2"),
        ("  lotte   mart  ", "Lotte Mart"),
        ("papaxốt", "Papaxốt"),
    ],
)
def test_seller_cleaning(raw: str, expected: str) -> None:
    result = normalize_text_field(raw, ReceiptField.SELLER)
    assert result.value == expected
    assert result.valid


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            "1.01-1.02,Block A, Khu căn hộ Sacom Bình Thắng,207A đường QL1A ,KP Quyết Thắng, Phường Bình Thắng, "
            "Thị xã Dĩ An, Tỉnh Bình Dương.",
            "1.01-1.02, Block A, Khu căn hộ Sacom Bình Thắng, 207A đường QL1A, KP Quyết Thắng, Phường Bình Thắng, "
            "Thị xã Dĩ An, Tỉnh Bình Dương",
        ),
        ("26 đoàn kết , p. bình thọ , q.thủ đức", "26 Đoàn Kết, P. Bình Thọ, Q. Thủ Đức"),
        ("01 Dương Văn Cam, P.Linh Tây, Q.Thủ Đức, TP.Hồ Chí Minh",
         "01 Dương Văn Cam, P. Linh Tây, Q. Thủ Đức, TP. Hồ Chí Minh"),
        ("Chợ Sủi Phú Thị Gia Lâm", "Chợ Sủi Phú Thị Gia Lâm"),
        ("Tang tret TTTM GO! BEN TRE Ap 1, Vo Ng Giap, xa Son Dong, BTre",
         "Tang tret TTTM GO! BEN TRE Ap 1, Vo Ng Giap, xa Son Dong, BTre"),
        ("196A,B Trần Bình Trọng, Q. 5, TP HCM", "196A,B Trần Bình Trọng, Q. 5, TP HCM"),
    ],
)
def test_address_cleaning(raw: str, expected: str) -> None:
    result = normalize_text_field(raw, ReceiptField.ADDRESS)
    assert result.value == expected
    assert result.valid


@pytest.mark.parametrize("raw", ["", "  ", "12345", "--"])
def test_text_without_letters_is_invalid(raw: str) -> None:
    assert not normalize_text_field(raw, ReceiptField.SELLER).valid


def test_text_with_leaked_tags_is_flagged() -> None:
    result = normalize_text_field("Tổ 7</s_address><s_timestamp> 15/11/2016", ReceiptField.ADDRESS)
    assert result.value == "Tổ 7"
    assert not result.valid


def test_clean_text_normalizes_unicode_to_nfc() -> None:
    decomposed = "Thủ Đưc"  # "Thủ Đưc" dạng tổ hợp
    assert clean_text(decomposed) == "Thủ Đưc"


# --- Gộp ------------------------------------------------------------------------------
def test_fields_from_sequence_and_normalize_receipt() -> None:
    sequence = ("<s_seller><s_seller_name>PHUC LONG</s_seller_name><s_address>1012 Kha Van Can P. Linh Chiểu"
                "</s_address><s_timestamp>06/01/2023 13:45</s_timestamp><s_total_cost>55,000</s_total_cost>"
                "</s_seller>")
    receipt = normalize_receipt(fields_from_sequence(sequence))
    assert receipt.seller.value == "PHUC LONG"
    assert receipt.timestamp.iso == "2023-01-06T13:45:00"
    assert receipt.total_cost.value == 55000
    assert receipt.invalid_fields == []


def test_normalize_receipt_lists_invalid_fields() -> None:
    receipt = normalize_receipt({"seller_name": "AEON", "timestamp": "15:29:03", "total_cost": None})
    assert receipt.invalid_fields == ["address", "timestamp", "total_cost"]


# --- Hồi quy trên tập test V5 (bỏ qua khi không có Version5/, ví dụ trong Docker) -------------
def _canonical_match(field: str, gt: str, pred: str, fields_match) -> bool:
    if field == "TOTAL_COST":
        return parse_amount(gt) == normalize_amount_field(pred).value
    if field == "TIMESTAMP":
        g, p = normalize_timestamp_field(gt), normalize_timestamp_field(pred)
        if g.iso and p.iso:
            return g.iso == p.iso
        return fields_match(field, g.value, p.value)
    tag = ReceiptField.SELLER if field == "SELLER" else ReceiptField.ADDRESS
    return fields_match(field, normalize_text_field(gt, tag).value, normalize_text_field(pred, tag).value)


@pytest.mark.skipif(not COMPARE_CSV.exists(), reason="cần Version5/compare_test.csv")
def test_postprocess_never_breaks_an_exact_v5_prediction() -> None:
    sys.path.insert(0, str(COMPARE_CSV.parent))
    try:
        from labels import fields_match  # chỉ đọc, cùng phép so khớp với Version5/evaluate.py
    finally:
        sys.path.remove(str(COMPARE_CSV.parent))

    gained, lost = 0, 0
    with open(COMPARE_CSV, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            gt: str = row["ground_truth"]
            pred: Optional[str] = row["v5"]
            if not gt:
                continue
            before = fields_match(row["field"], gt, pred)
            after = _canonical_match(row["field"], gt, pred, fields_match)
            gained += after and not before
            lost += before and not after
    assert lost == 0
    assert gained >= 20
