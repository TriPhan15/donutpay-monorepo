#!/usr/bin/env python3
"""Deterministic synthetic data for the LedgerMind NoSQL benchmark (Task 3 of the NoSQL report).

DỮ LIỆU TỔNG HỢP: nothing here comes from a real user. Seed 42, no clock, no set/dict-order dependence, so two runs write
byte-identical files (the manifest carries one sha256 per file and one over the whole list).

    python3 gen_data.py OUT_DIR            # writes the files and OUT_DIR/MANIFEST.sha256

Files (all UTF-8, LF):
    users.csv, categories.csv, receipts.csv, transactions.csv   PostgreSQL COPY ... CSV HEADER (NULL = empty field)
    es_bulk.ndjson                                              Elasticsearch _bulk body, one document per transaction
    ocr_logs.ndjson, ocr_feedbacks.ndjson                       MongoDB documents (dates as ISO strings, ids as ints)

Shape (see README.md):
    100 000 transactions, 1 000 users (user 1 is a "heavy" account holding 20 % of the rows, the rest are ~80 rows each),
    10 expense + 2 income categories, receipts on 40 % of the expense rows, 3 months (2026-08-01 .. 2026-10-27),
    100 000 ocr_logs, ~45 000 ocr_feedbacks. 10 % of the free-text values are written without accents (people do that).
"""
import hashlib
import json
import math
import os
import random
import sys
import unicodedata
from datetime import datetime, timedelta

SEED = 42
N_TX = 100_000
N_USERS = 1_000
HEAVY_USER = 1
HEAVY_SHARE = 0.20
N_OCR = 100_000
UNACCENTED_SHARE = 0.10
START = datetime(2026, 8, 1, 0, 0, 0)
END = datetime(2026, 10, 27, 23, 59, 59)

EXPENSE_CATEGORIES = ["Ăn uống", "Cà phê", "Di chuyển", "Mua sắm", "Hóa đơn", "Y tế", "Giải trí", "Giáo dục", "Nhà ở", "Khác"]
INCOME_CATEGORIES = ["Lương", "Thưởng"]
VENDORS = [
    "Phở Hùng", "Phở Thìn", "Phở 24", "Phúc Long", "Highlands Coffee", "The Coffee House", "Cộng Cà Phê", "Cà Phê Trung Nguyên",
    "Bún Chả Hương Liên", "Bún Bò Huế O Cương", "Bún Riêu Cua", "Cơm Tấm Sài Gòn", "Cơm Tấm Ba Ghiền", "Bánh Mì Huỳnh Hoa",
    "Bánh Mì Phượng", "WinMart", "Circle K", "GS25", "Co.opmart", "Lotte Mart", "Big C", "Bách Hóa Xanh", "Điện Máy Xanh",
    "Nhà Sách Phương Nam", "Hiệu thuốc Long Châu", "Pharmacity", "Trà Sữa Gong Cha", "Trà Sữa Phúc Tea", "KFC", "Lotteria",
    "Jollibee", "Pizza 4P's", "Quán Ngon Sài Gòn", "Lẩu Dê Dũng Béo", "Tiệm Bánh Kinh Đô", "Grab", "Be", "Gojek",
    "Petrolimex", "Phở Gà Nguyễn Trãi", "Xúc Xích Phố Cổ", "Nhà Hàng Hoa Sen",
]
NOTE_TEMPLATES = [
    "Ăn sáng với đồng nghiệp", "Cà phê cuối tuần", "Mua đồ siêu thị", "Tiền điện tháng {m}", "Tiền nước tháng {m}",
    "Phở bò tái", "Đổ xăng xe máy", "Trả tiền nhà tháng {m}", "Ăn trưa văn phòng", "Mua sách tham khảo", "Tiền học thêm",
    "Khám bệnh định kỳ", "Mua thuốc cảm", "Xem phim cuối tuần", "Cơm tấm sườn bì", "Bún chả Hà Nội", "Bánh mì trứng",
    "Trà sữa trân châu", "Gửi xe tháng {m}", "Cước internet tháng {m}", "Cà phê với bạn", "Mua quần áo", "Sửa xe",
    "Đi chợ cuối tuần", "Tiệc sinh nhật bạn", "Học phí tháng {m}", "Mua phở mang về", "Thanh toán hóa đơn điện thoại",
    "Siêu thị mini gần nhà", "Ăn tối gia đình", "Quà tặng sinh nhật", "Vé xe buýt", "Phí chuyển khoản", "Tiền lương tháng {m}",
]
LOCATIONS = ["Quận 1, TP.HCM", "Quận 3, TP.HCM", "Quận Bình Thạnh, TP.HCM", "Thủ Đức, TP.HCM", "Cầu Giấy, Hà Nội",
             "Hoàn Kiếm, Hà Nội", "Đống Đa, Hà Nội", "Hải Châu, Đà Nẵng", "Ninh Kiều, Cần Thơ", "Nha Trang, Khánh Hòa"]
PAYMENTS = ["Tiền mặt", "Chuyển khoản", "Thẻ tín dụng", "Ví MoMo", "ZaloPay"]
RECEIPT_STATUSES = ["COMPLETED_RAW", "EDITED", "APPROVED"]
MODELS = ["donut-v4", "donut-v5"]
FIELDS = ["total_cost", "seller_name", "receipt_date"]


def unaccent(text):
    text = text.replace("đ", "d").replace("Đ", "D")
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


def maybe_unaccent(rng, text):
    """One rng draw per call, always, so the stream does not depend on the text."""
    return unaccent(text) if rng.random() < UNACCENTED_SHARE else text


def csv_field(value):
    if value is None:
        return ""
    s = str(value)
    if any(ch in s for ch in ',"\n'):
        return '"' + s.replace('"', '""') + '"'
    return s


def fmt_ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def iso_ms(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000")


def write_csv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(",".join(header) + "\n")
        for row in rows:
            f.write(",".join(csv_field(v) for v in row) + "\n")


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rng = random.Random(SEED)
    span = int((END - START).total_seconds())

    # ---- users, categories
    users = []
    for uid in range(1, N_USERS + 1):
        created = START - timedelta(days=30 + (uid * 7) % 300)
        users.append([uid, f"user{uid:04d}", f"user{uid:04d}@example.com", f"09{uid:08d}", "ROLE_USER", "true",
                      f"{(uid * 7919) % 5_000_000}.00", fmt_ts(created), fmt_ts(created), 0, "x"])
    write_csv(os.path.join(out_dir, "users.csv"),
              ["id", "username", "email", "phone", "role", "active", "wallet_balance", "created_at", "updated_at",
               "credentials_version", "password"], users)
    categories = [[i + 1, name, "EXPENSE"] for i, name in enumerate(EXPENSE_CATEGORIES)] + \
                 [[len(EXPENSE_CATEGORIES) + i + 1, name, "INCOME"] for i, name in enumerate(INCOME_CATEGORIES)]
    write_csv(os.path.join(out_dir, "categories.csv"), ["id", "name", "type"], categories)

    # ---- transactions: draw first, sort by date, then number them (ids grow with time like real IDENTITY ids)
    draft = []
    for _ in range(N_TX):
        when = START + timedelta(seconds=rng.randrange(span + 1))
        user = HEAVY_USER if rng.random() < HEAVY_SHARE else rng.randrange(2, N_USERS + 1)
        expense = rng.random() < 0.88
        draft.append((when, user, expense, rng.random()))
    draft.sort(key=lambda d: (d[0], d[1]))

    receipts = []
    tx_rows = []
    es_lines = []
    for idx, (when, user, expense, vendor_roll) in enumerate(draft):
        tid = idx + 1
        if expense:
            cat = rng.randrange(1, len(EXPENSE_CATEGORIES) + 1)
        else:
            cat = len(EXPENSE_CATEGORIES) + rng.randrange(1, len(INCOME_CATEGORIES) + 1)
        cat_name = categories[cat - 1][1]
        amount = max(1000, int(math.exp(rng.gauss(11.0, 0.9)) // 1000 * 1000))
        note = None
        note_roll = rng.random()
        note_text = NOTE_TEMPLATES[rng.randrange(len(NOTE_TEMPLATES))].format(m=rng.randrange(1, 13))
        note_text = maybe_unaccent(rng, note_text)
        if note_roll < 0.70:
            note = note_text
        location = None
        loc_roll = rng.random()
        loc_text = maybe_unaccent(rng, LOCATIONS[rng.randrange(len(LOCATIONS))])
        if loc_roll < 0.50:
            location = loc_text
        payment = maybe_unaccent(rng, PAYMENTS[rng.randrange(len(PAYMENTS))])
        voucher = f"VC{tid:06d}" if rng.random() < 0.05 else None
        client_id = f"c{tid:08x}" if rng.random() < 0.30 else None
        receipt_id = None
        vendor = None
        receipt_status = None
        vendor_text = maybe_unaccent(rng, VENDORS[rng.randrange(len(VENDORS))])
        status_pick = RECEIPT_STATUSES[rng.randrange(len(RECEIPT_STATUSES))]
        if expense and vendor_roll < 0.40:
            receipt_id = len(receipts) + 1
            vendor = vendor_text
            receipt_status = status_pick
            receipts.append([receipt_id, vendor, f"{amount}.00", when.strftime("%Y-%m-%d"), "", receipt_status, 0,
                             fmt_ts(when), fmt_ts(when)])
        tx_rows.append([tid, f"{amount}.00", note, fmt_ts(when), "true" if expense else "false", cat_name, location,
                        payment, voucher, user, cat, receipt_id, client_id, fmt_ts(when), fmt_ts(when)])
        doc = {"userId": user, "amount": float(amount), "expense": expense, "transactionDate": iso_ms(when),
               "categoryName": cat_name, "paymentMethod": payment}
        if note is not None:
            doc["note"] = note
        if location is not None:
            doc["location"] = location
        if vendor is not None:
            doc["vendorName"] = vendor
            doc["receiptStatus"] = "SUCCESS"
        es_lines.append(json.dumps({"index": {"_id": str(tid)}}, ensure_ascii=False))
        es_lines.append(json.dumps(doc, ensure_ascii=False, sort_keys=True))
    write_csv(os.path.join(out_dir, "receipts.csv"),
              ["id", "vendor_name", "extracted_total", "extracted_date", "image_url", "status", "version", "created_at",
               "updated_at"], receipts)
    write_csv(os.path.join(out_dir, "transactions.csv"),
              ["id", "amount", "note", "transaction_date", "is_expense", "category_name", "location", "payment_method",
               "voucher_code", "user_id", "category_id", "receipt_id", "client_id", "created_at", "updated_at"], tx_rows)
    with open(os.path.join(out_dir, "es_bulk.ndjson"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(es_lines) + "\n")

    # ---- OCR documents (their own scale: transactionId 1..N_OCR, not tied to the PostgreSQL receipts)
    ocr_rng = random.Random(SEED + 1)
    logs = []
    feedbacks = []
    ocr_span = int((END - START).total_seconds())
    stamps = sorted(ocr_rng.randrange(ocr_span + 1) for _ in range(N_OCR))
    for i in range(N_OCR):
        tid = i + 1
        when = START + timedelta(seconds=stamps[i])
        v5 = i >= N_OCR // 2
        seller = VENDORS[ocr_rng.randrange(len(VENDORS))]
        total = 20000 + 1000 * ocr_rng.randrange(0, 1500)
        score = round(((0.86 if v5 else 0.68) + ocr_rng.random() * 0.12) if ocr_rng.random() < 0.9 else ocr_rng.random() * 0.7, 2)
        date_text = when.strftime("%Y-%m-%d")
        logs.append({
            "transactionId": tid,
            "rawJsonData": {"seller": {"seller_name": seller, "address": LOCATIONS[ocr_rng.randrange(len(LOCATIONS))],
                                       "timestamp": date_text, "total_cost": f"{total:,}", "total_cost_number": total},
                            "confidence_score": score},
            "modelVersion": MODELS[1 if v5 else 0],
            "aiReading": {"sellerName": seller, "totalCost": str(total), "receiptDate": date_text},
            "averageConfidenceScore": score,
            "createdAt": iso_ms(when),
        })
        if ocr_rng.random() < 0.30:
            picked = []
            while not picked:
                picked = [f for f in FIELDS if ocr_rng.random() < 0.40]
            for field in picked:
                expected, ai = {"seller_name": (seller, unaccent(seller).replace("o", "0")),
                                "total_cost": (str(total * 10), str(total)),
                                "receipt_date": (date_text, "2026-01-01")}[field]
                reported = when + timedelta(minutes=5 + ocr_rng.randrange(0, 60 * 24 * 3))
                feedbacks.append({
                    "receiptId": tid, "transactionId": tid, "userId": ocr_rng.randrange(1, N_USERS + 1),
                    "fieldError": field, "expectedValue": expected, "aiValue": ai, "modelVersion": MODELS[1 if v5 else 0],
                    "isResolved": ocr_rng.random() < 0.40, "reportedAt": iso_ms(reported), "updatedAt": iso_ms(reported),
                })
    for name, docs in (("ocr_logs.ndjson", logs), ("ocr_feedbacks.ndjson", feedbacks)):
        with open(os.path.join(out_dir, name), "w", encoding="utf-8", newline="\n") as f:
            for d in docs:
                f.write(json.dumps(d, ensure_ascii=False, sort_keys=True) + "\n")

    # ---- manifest
    names = ["users.csv", "categories.csv", "receipts.csv", "transactions.csv", "es_bulk.ndjson", "ocr_logs.ndjson",
             "ocr_feedbacks.ndjson"]
    lines = [f"{sha256_of(os.path.join(out_dir, n))}  {n}" for n in names]
    total = hashlib.sha256("\n".join(lines).encode()).hexdigest()
    with open(os.path.join(out_dir, "MANIFEST.sha256"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
        f.write(f"{total}  ALL (sha256 of the lines above)\n")
    print(f"transactions={len(tx_rows)} receipts={len(receipts)} users={len(users)} ocr_logs={len(logs)} "
          f"ocr_feedbacks={len(feedbacks)}")
    print(f"ALL {total}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
