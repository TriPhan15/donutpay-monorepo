"""E5: $lookup (reference, Q-13) vs an embedded copy of the log in each feedback, on the synthetic OCR documents.

Q-13 of scripts/nosql/mongodb_demo.js, unchanged: $match fieldError -> $lookup ocr_logs on transactionId (unique index) ->
$unwind -> $project -> $sort receiptId -> $limit 4.
  A  the pipeline as written: $match fieldError == "seller_name" (no index serves it, ~1/3 of the feedbacks match)
  B  the drill-down an admin would make: the same plus userId == <user> (index userId), ~15 feedbacks
The embedded side runs the same $match / $project / $sort / $limit on ocr_feedbacks_embedded, where every feedback already
carries rawJsonData, modelVersion and averageConfidenceScore of its log, with the same indexes as ocr_feedbacks (so the only
difference is the join). The two answers are compared before timing. Because Q-13 sorts only after the join, two reordered variants are added
(`$match, $sort, $limit` first, then `$lookup`/`$unwind`/`$project`, and the same order on the embedded copy); all four give the
same answer (asserted). Variant A therefore measures the cost of a LATE $lookup (one lookup per matching feedback), variant B
(per user) the fair embed-versus-reference figure.
The price of embedding is reported too: collection size and the duplicated bytes.
"""
import random

import pymongo

import mongoload
from benchlib import line, measure, save

LOOKUP = {"$lookup": {"from": "ocr_logs", "localField": "transactionId", "foreignField": "transactionId", "as": "log"}}
PROJECT_REF = {"$project": {"_id": 0, "receiptId": 1, "aiValue": 1, "expectedValue": 1,
                            "rawSeller": "$log.rawJsonData.seller.seller_name", "confidence": "$log.averageConfidenceScore",
                            "model": "$log.modelVersion"}}


def reference(match):
    return [{"$match": match}, LOOKUP, {"$unwind": "$log"}, PROJECT_REF, {"$sort": {"receiptId": 1}}, {"$limit": 4}]


def reference_reordered(match):
    """Q-13 with the $lookup moved after $sort/$limit: the same answer (transactionId is unique in ocr_logs and every feedback
    has a log, asserted below), but only 4 lookups instead of one per matching feedback."""
    return [{"$match": match}, {"$sort": {"receiptId": 1}}, {"$limit": 4}, LOOKUP, {"$unwind": "$log"}, PROJECT_REF]


def embedded(match):
    return [{"$match": match}, PROJECT_REF, {"$sort": {"receiptId": 1}}, {"$limit": 4}]


def embedded_reordered(match):
    """The embedded side in the same order ($match, $sort, $limit, then $project): the fair partner of reference_reordered."""
    return [{"$match": match}, {"$sort": {"receiptId": 1}}, {"$limit": 4}, PROJECT_REF]


def find_stat(node, key, acc):
    """Collect every value of `key` found anywhere in the explain document."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k == key:
                acc.append(v)
            find_stat(v, key, acc)
    elif isinstance(node, list):
        for v in node:
            find_stat(v, key, acc)
    return acc


def explain_agg(db, coll, pipeline):
    res = db.command({"explain": {"aggregate": coll, "pipeline": pipeline, "cursor": {}}, "verbosity": "executionStats"})
    return {"totalDocsExamined": find_stat(res, "totalDocsExamined", []), "totalKeysExamined": find_stat(res, "totalKeysExamined", []),
            "nReturned": find_stat(res, "nReturned", [])[:6], "executionTimeMillis": find_stat(res, "executionTimeMillis", []),
            "indexesUsed": find_stat(res, "indexesUsed", []), "stages": [list(s)[0] for s in res.get("stages", [])]}


def main():
    client, db, counts = mongoload.load(embedded=True)
    info = client.server_info()
    out = {"versions": {"mongodb": info["version"], "pymongo": pymongo.version}, "counts": counts, "scenarios": {},
           "explain": {}, "sizes": {}}
    for name in ("ocr_feedbacks", "ocr_feedbacks_embedded", "ocr_logs"):
        st = db.command("collStats", name)
        out["sizes"][name] = {"count": st["count"], "size": st["size"], "avgObjSize": st["avgObjSize"],
                              "storageSize": st["storageSize"], "totalIndexSize": st["totalIndexSize"]}

    rng = random.Random(9)
    pool = [d["_id"] for d in db.ocr_feedbacks.aggregate([{"$match": {"fieldError": "seller_name"}}, {"$group": {"_id": "$userId"}}])]
    pool.sort()
    users = [rng.choice(pool) for _ in range(2000)]
    out["seller_name_feedbacks"] = db.ocr_feedbacks.count_documents({"fieldError": "seller_name"})
    out["users_with_seller_name_feedback"] = len(pool)

    def match_a(i):
        return {"fieldError": "seller_name"}

    def match_b(i):
        return {"fieldError": "seller_name", "userId": users[i % len(users)]}

    for variant, match in (("A", match_a), ("B", match_b)):
        for i in range(0, 50):  # same answer from both shapes, order included
            ref = list(db.ocr_feedbacks.aggregate(reference(match(i))))
            emb = list(db.ocr_feedbacks_embedded.aggregate(embedded(match(i))))
            assert ref == emb, f"answers differ for variant {variant}, i={i}"
            assert ref == list(db.ocr_feedbacks.aggregate(reference_reordered(match(i)))), "reordered pipeline differs"
            assert ref == list(db.ocr_feedbacks_embedded.aggregate(embedded_reordered(match(i)))), "embedded reordered differs"
        out["explain"][f"{variant}/reference"] = explain_agg(db, "ocr_feedbacks", reference(match(0)))
        out["explain"][f"{variant}/reference_reordered"] = explain_agg(db, "ocr_feedbacks", reference_reordered(match(0)))
        out["explain"][f"{variant}/embedded_reordered"] = explain_agg(db, "ocr_feedbacks_embedded", embedded_reordered(match(0)))
        out["explain"][f"{variant}/embedded"] = explain_agg(db, "ocr_feedbacks_embedded", embedded(match(0)))
        print("explain", variant, out["explain"][f"{variant}/reference"], out["explain"][f"{variant}/embedded"], flush=True)
        out["scenarios"][f"{variant}/reference"], _, _ = measure(lambda i, m=match: list(db.ocr_feedbacks.aggregate(reference(m(i)))))
        line(f"E5 {variant} $lookup (Q-13)", out["scenarios"][f"{variant}/reference"])
        out["scenarios"][f"{variant}/reference_reordered"], _, _ = measure(lambda i, m=match: list(db.ocr_feedbacks.aggregate(reference_reordered(m(i)))))
        line(f"E5 {variant} $lookup after $sort/$limit (Q-13 reordered)", out["scenarios"][f"{variant}/reference_reordered"])
        out["scenarios"][f"{variant}/embedded_reordered"], _, _ = measure(lambda i, m=match: list(db.ocr_feedbacks_embedded.aggregate(embedded_reordered(m(i)))))
        line(f"E5 {variant} embedded, $sort/$limit before $project", out["scenarios"][f"{variant}/embedded_reordered"])
        out["scenarios"][f"{variant}/embedded"], _, _ = measure(lambda i, m=match: list(db.ocr_feedbacks_embedded.aggregate(embedded(m(i)))))
        line(f"E5 {variant} embedded copy", out["scenarios"][f"{variant}/embedded"])
    save("E5", out)


if __name__ == "__main__":
    main()
