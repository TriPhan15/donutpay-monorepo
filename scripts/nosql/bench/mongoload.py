"""Loads the synthetic OCR documents into the throwaway MongoDB with the indexes of scripts/nosql/mongodb_init.js.

Collections (database "bench"):
    ocr_logs, ocr_feedbacks                 the app's collections, with the app's indexes (no $jsonSchema validator: it is not
                                            read-path work; ids are bson Int64 as the validator demands)
    ocr_logs_noidx, ocr_feedbacks_noidx     the same documents with only the _id index (E1 baseline)
    ocr_feedbacks_embedded                  (E5) each feedback with a copy of its log's raw answer, model and score, and the
                                            same indexes as ocr_feedbacks
"""
import json
import os
import time
from datetime import datetime

import pymongo
from bson import Int64

from benchlib import DATA_DIR, wait_tcp

HOST = os.environ.get("MONGO_HOST", "bench-mongo")
DATES = ("createdAt", "reportedAt", "updatedAt")
LONGS = ("transactionId", "receiptId", "userId")


def parse(line):
    d = json.loads(line)
    for k in DATES:
        if k in d:
            d[k] = datetime.strptime(d[k], "%Y-%m-%dT%H:%M:%S.000")
    for k in LONGS:
        if k in d:
            d[k] = Int64(d[k])
    return d


def read(name):
    with open(os.path.join(DATA_DIR, name), encoding="utf-8") as f:
        return [parse(line) for line in f]


def insert(coll, docs):
    for i in range(0, len(docs), 5000):
        coll.insert_many([dict(d) for d in docs[i:i + 5000]], ordered=False)


def logs_indexes(c):
    c.create_index([("transactionId", 1)], name="transactionId", unique=True)
    c.create_index([("averageConfidenceScore", 1)], name="averageConfidenceScore")
    c.create_index([("createdAt", 1)], name="createdAt")
    c.create_index([("averageConfidenceScore", 1), ("createdAt", -1)], name="score_date_idx")


def feedback_indexes(c):
    c.create_index([("receiptId", 1), ("fieldError", 1)], name="receipt_field_uq", unique=True)
    c.create_index([("receiptId", 1)], name="receiptId")
    c.create_index([("userId", 1)], name="userId")
    c.create_index([("transactionId", 1)], name="transactionId")
    c.create_index([("isResolved", 1)], name="isResolved")
    c.create_index([("reportedAt", 1)], name="reportedAt")
    c.create_index([("isResolved", 1), ("reportedAt", -1)], name="status_date_idx")


def load(embedded=False):
    wait_tcp(HOST, 27017)
    client = pymongo.MongoClient(HOST, 27017, serverSelectionTimeoutMS=60000)
    client.admin.command("ping")
    client.drop_database("bench")
    db = client["bench"]
    started = time.time()
    logs, feedbacks = read("ocr_logs.ndjson"), read("ocr_feedbacks.ndjson")
    insert(db.ocr_logs, logs)
    insert(db.ocr_feedbacks, feedbacks)
    insert(db.ocr_logs_noidx, logs)
    insert(db.ocr_feedbacks_noidx, feedbacks)
    logs_indexes(db.ocr_logs)
    feedback_indexes(db.ocr_feedbacks)
    if embedded:
        by_tx = {d["transactionId"]: d for d in logs}
        emb = []
        for f in feedbacks:
            log = by_tx[f["transactionId"]]
            g = dict(f)
            g["log"] = {"rawJsonData": log["rawJsonData"], "modelVersion": log["modelVersion"],
                        "averageConfidenceScore": log["averageConfidenceScore"]}
            emb.append(g)
        insert(db.ocr_feedbacks_embedded, emb)
        feedback_indexes(db.ocr_feedbacks_embedded)
    counts = {n: db[n].count_documents({}) for n in db.list_collection_names()}
    print(f"MongoDB loaded in {time.time() - started:.1f}s: {counts}", flush=True)
    return client, db, counts
