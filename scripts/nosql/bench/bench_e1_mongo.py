"""E1: MongoDB index vs no index, on 100 000 ocr_logs and ~45 000 ocr_feedbacks (synthetic).

Shapes (scripts/nosql/mongodb_demo.js, Q-01..Q-03):
  Q-01  ocr_logs.find({transactionId}, projection).limit(1)                         index: transactionId (unique)
  Q-02  ocr_logs.find({averageConfidenceScore: {$lt: 0.75}}, projection).sort({createdAt: -1}).limit(5)
  Q-03  ocr_feedbacks.find({isResolved: false}, projection).sort({reportedAt: -1}).limit(5)   index: status_date_idx
"indexed" runs on the app's collections (indexes of mongodb_init.js); "no index" on twins that hold the same documents and only
the _id index. Server-side numbers come from explain("executionStats") of the very same command.
"""
import random

import pymongo
from bson import Int64

import mongoload
from benchlib import line, measure, save

Q01_PROJ = {"_id": 0, "transactionId": 1, "modelVersion": 1, "averageConfidenceScore": 1, "rawJsonData.seller": 1}
Q02_PROJ = {"_id": 0, "transactionId": 1, "modelVersion": 1, "averageConfidenceScore": 1, "createdAt": 1}
Q03_PROJ = {"_id": 0, "receiptId": 1, "fieldError": 1, "reportedAt": 1}


def stages(plan):
    names = []
    while plan:
        names.append(plan["stage"])
        plan = plan.get("inputStage")
        if plan is None:
            break
    return names


def index_name(plan):
    while plan:
        if "indexName" in plan:
            return plan["indexName"]
        plan = plan.get("inputStage")
    return None


def explain(db, coll, find_cmd):
    cmd = {"explain": {"find": coll, **find_cmd}, "verbosity": "executionStats"}
    res = db.command(cmd)
    es = res["executionStats"]
    win = res["queryPlanner"]["winningPlan"]
    return {"stages": " -> ".join(stages(win)), "index": index_name(win), "totalKeysExamined": es["totalKeysExamined"],
            "totalDocsExamined": es["totalDocsExamined"], "nReturned": es["nReturned"],
            "executionTimeMillis": es["executionTimeMillis"]}


def main():
    client, db, counts = mongoload.load()
    info = client.server_info()
    out = {"versions": {"mongodb": info["version"], "pymongo": pymongo.version}, "counts": counts, "scenarios": {},
           "explain": {}, "index_sizes": {}}
    for name in ("ocr_logs", "ocr_feedbacks"):
        st = db.command("collStats", name)
        out["index_sizes"][name] = {"count": st["count"], "storageSize": st["storageSize"], "size": st["size"],
                                    "totalIndexSize": st["totalIndexSize"], "indexSizes": st["indexSizes"]}

    rng = random.Random(5)
    tx_ids = [Int64(rng.randrange(1, 100_001)) for _ in range(5000)]

    def q01(coll):
        return lambda i: db[coll].find_one({"transactionId": tx_ids[i % len(tx_ids)]}, Q01_PROJ)

    def q02(coll):
        return lambda i: list(db[coll].find({"averageConfidenceScore": {"$lt": 0.75}}, Q02_PROJ).sort("createdAt", -1).limit(5))

    def q03(coll):
        return lambda i: list(db[coll].find({"isResolved": False}, Q03_PROJ).sort("reportedAt", -1).limit(5))

    cases = [
        ("Q-01", "ocr_logs", "ocr_logs_noidx", q01,
         {"filter": {"transactionId": tx_ids[0]}, "projection": Q01_PROJ, "limit": 1, "singleBatch": True}),
        ("Q-02", "ocr_logs", "ocr_logs_noidx", q02,
         {"filter": {"averageConfidenceScore": {"$lt": 0.75}}, "projection": Q02_PROJ, "sort": {"createdAt": -1}, "limit": 5}),
        ("Q-03", "ocr_feedbacks", "ocr_feedbacks_noidx", q03,
         {"filter": {"isResolved": False}, "projection": Q03_PROJ, "sort": {"reportedAt": -1}, "limit": 5}),
    ]
    for q, with_idx, no_idx, make, cmd in cases:
        for label, coll in (("indexed", with_idx), ("noindex", no_idx)):
            out["explain"][f"{q}/{label}"] = explain(db, coll, cmd)
            e = out["explain"][f"{q}/{label}"]
            print(f"explain {q}/{label}: {e}", flush=True)
            s, results, _ = measure(make(coll))
            s["collection"] = coll
            out["scenarios"][f"{q}/{label}"] = s
            line(f"E1 {q} {label}", s)
    save("E1", out)


if __name__ == "__main__":
    main()
