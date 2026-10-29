"""E2: Elasticsearch search (AP-29) vs PostgreSQL LOWER(..) LIKE .. ESCAPE (AP-31), on 100 000 synthetic transactions.

PostgreSQL side: the SQL Hibernate emits for TransactionRepository.searchIdsByText (captured_queries.txt, section
searchIdsByText: page query + count query), on the tables created from Hibernate's own DDL. Like Spring Data's Page, the count
query only runs when the first page is full.
Elasticsearch side: the request body of ElasticsearchTransactionSearchEngine.hits (fields, boosts, operators, fuzziness, sort,
track_total_hits, page 0 / size 20 = TransactionSearchRequestDto.DEFAULT_SIZE) against an index created from the app's own
transactions-settings.json / transactions-mapping.json.
Only the engine step is timed (what PostgresTransactionSearchEngine / ElasticsearchTransactionSearchEngine do); the reload of the
rows by id from PostgreSQL that TransactionSearchService does afterwards is the same for both and is left out.
"""
import json
import os
import random
import re
import time
import unicodedata

import requests

import pgload
from benchlib import ITERATIONS, WARMUP, load_captured_sql, measure, line, save, wait_tcp, DATA_DIR

ES = os.environ.get("ES_URL", "http://bench-es:9200")
CONF = os.environ.get("ES_CONF", "/es_conf")
PAGE = 20
# 10 terms, each as typed with accents and as typed without (people skip them on a phone keyboard).
TERMS = [("phở", "pho"), ("cà phê", "ca phe"), ("bún", "bun"), ("cơm tấm", "com tam"), ("bánh mì", "banh mi"),
         ("phúc long", "phuc long"), ("trà sữa", "tra sua"), ("tiền điện", "tien dien"), ("đổ xăng", "do xang"),
         ("siêu thị", "sieu thi")]
QUERIES = [q for pair in TERMS for q in pair]  # 20 strings
EXACT_FIELDS = ["vendorName^3", "vendorName.autocomplete^2", "note^2", "note.autocomplete", "categoryName", "location",
                "paymentMethod"]
FUZZINESS = "AUTO:4,7"  # ElasticsearchTransactionSearchEngine.FUZZINESS (commit 7f07caa): no typos under 4 characters
FUZZY_PREFIX_LENGTH = 1  # ElasticsearchTransactionSearchEngine.FUZZY_PREFIX_LENGTH (commit b35cd6e): the first letter must be right
FUZZY_FIELDS = ["vendorName^3", "note^2", "categoryName", "location", "paymentMethod"]


def like_pattern(q):  # TransactionRepository.likePattern
    return "%" + q.lower().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"


def es_body(user_id, q):  # ElasticsearchTransactionSearchEngine.hits
    return {
        "query": {"bool": {
            "filter": [{"term": {"userId": {"value": user_id}}}],
            "should": [
                {"multi_match": {"query": q, "fields": EXACT_FIELDS, "operator": "and", "boost": 2.0}},
                {"multi_match": {"query": q, "fields": FUZZY_FIELDS, "fuzziness": FUZZINESS, "prefix_length": FUZZY_PREFIX_LENGTH, "operator": "and"}}],
            "minimum_should_match": "1"}},
        "sort": [{"_score": {"order": "desc"}}, {"transactionDate": {"order": "desc"}}],
        "from": 0, "size": PAGE, "track_total_hits": True}


def fold(text):
    """lowercase + accent-stripped, like the vi_folded analyzer (lowercase, asciifolding); đ is folded to d."""
    text = text.replace("đ", "d").replace("Đ", "D")
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn").lower()


TOKEN = re.compile(r"\w+")
FIELD_NAMES = ["note", "category_name", "location", "payment_method", "vendor_name"]


def truth(rows, q):
    """Ground truth: ids of the user's rows in which one text field contains every folded token of q as a whole word."""
    need = TOKEN.findall(fold(q))
    ids = set()
    for row in rows:
        for value in row[1:]:
            if value and all(t in set(TOKEN.findall(fold(value))) for t in need):
                ids.add(row[0])
                break
    return ids


def load_es(session):
    wait_tcp(ES.split("//")[1].split(":")[0], 9200)
    for _ in range(120):
        try:
            if session.get(ES + "/_cluster/health").json()["status"] in ("green", "yellow"):
                break
        except Exception:
            pass
        time.sleep(1)
    settings = json.load(open(os.path.join(CONF, "transactions-settings.json"), encoding="utf-8"))
    mapping = json.load(open(os.path.join(CONF, "transactions-mapping.json"), encoding="utf-8"))
    r = session.put(ES + "/transactions", json={"settings": settings, "mappings": mapping})
    r.raise_for_status()
    started = time.time()
    lines = open(os.path.join(DATA_DIR, "es_bulk.ndjson"), encoding="utf-8").read().split("\n")
    lines = [x for x in lines if x]
    for i in range(0, len(lines), 10000):
        body = "\n".join(lines[i:i + 10000]) + "\n"
        r = session.post(ES + "/transactions/_bulk", data=body.encode("utf-8"), headers={"Content-Type": "application/x-ndjson"})
        r.raise_for_status()
        assert not r.json()["errors"], "bulk reported errors"
    session.post(ES + "/transactions/_refresh").raise_for_status()
    count = session.get(ES + "/transactions/_count").json()["count"]
    stats = session.get(ES + "/transactions/_stats/store,docs").json()["indices"]["transactions"]["primaries"]
    print(f"Elasticsearch loaded in {time.time() - started:.1f}s: {count} docs, store {stats['store']['size_in_bytes']} B",
          flush=True)
    return count, stats["store"]["size_in_bytes"]


def main():
    sql = load_captured_sql()["searchIdsByText"]
    page_sql, count_sql = sql[0][0], sql[1][0]
    conn = pgload.connect()
    counts = pgload.load(conn)
    cur = conn.cursor()
    cur.execute("SELECT version()")
    pg_version = cur.fetchone()[0]
    cur.execute("SELECT datcollate, datctype, pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database()")
    collate = cur.fetchone()
    cur.execute("SELECT count(*) FROM pg_indexes WHERE tablename = 'transactions'")
    indexes = [r[0] for r in conn.execute("SELECT indexdef FROM pg_indexes WHERE tablename = 'transactions' ORDER BY 1")]

    session = requests.Session()
    es_count, es_bytes = load_es(session)
    es_info = session.get(ES + "/").json()["version"]["number"]
    es_segments = len(session.get(ES + "/_cat/segments/transactions?format=json").json())
    print(f"Elasticsearch segments: {es_segments} (no force-merge: the index is searched as the background merges left it)", flush=True)

    rng = random.Random(7)
    typical = [r[0] for r in conn.execute(
        "SELECT user_id FROM transactions WHERE user_id <> 1 GROUP BY user_id HAVING count(*) BETWEEN 70 AND 90 ORDER BY user_id")]
    typical = sorted(rng.sample(typical, 20))
    typical_rows = {u: conn.execute("SELECT count(*) FROM transactions WHERE user_id = %s", (u,)).fetchone()[0] for u in typical}
    heavy_rows = conn.execute("SELECT count(*) FROM transactions WHERE user_id = 1").fetchone()[0]
    print(f"typical users {typical}, heavy user 1 rows={heavy_rows}", flush=True)

    def pg_search(user_id, q):
        pattern = like_pattern(q)
        rows = cur.execute(page_sql, (user_id, pattern, pattern, pattern, pattern, pattern, 0, PAGE)).fetchall()
        if len(rows) < PAGE:  # PageableExecutionUtils: the first page that is not full already knows the total
            return len(rows)
        return cur.execute(count_sql, (user_id, pattern, pattern, pattern, pattern, pattern)).fetchone()[0]

    took = []

    def es_search(user_id, q):
        r = session.post(ES + "/transactions/_search", data=json.dumps(es_body(user_id, q)),
                         headers={"Content-Type": "application/json"})
        j = r.json()
        took.append(j["took"])
        return j["hits"]["total"]["value"]

    out = {"versions": {"postgres": pg_version, "elasticsearch": es_info, "psycopg": __import__("psycopg").__version__,
                        "requests": requests.__version__},
           "pg_collation": {"datcollate": collate[0], "datctype": collate[1], "encoding": collate[2]},
           "pg_indexes_on_transactions": indexes, "rows": counts, "es_docs": es_count, "es_segments": es_segments, "es_store_bytes": es_bytes,
           "typical_users": typical, "typical_user_rows": typical_rows, "heavy_user_rows": heavy_rows,
           "queries": QUERIES, "page_size": PAGE, "scenarios": {}, "floor": {}, "explain": {}}

    # the floor: one trivial round trip per engine (what a call costs before it does any work)
    s, _, _ = measure(lambda i: cur.execute("SELECT 1").fetchone())
    out["floor"]["postgres_select_1"] = s
    line("floor: PostgreSQL SELECT 1", s)
    s, _, _ = measure(lambda i: session.get(ES + "/").status_code)
    out["floor"]["elasticsearch_GET_root"] = s
    line("floor: Elasticsearch GET /", s)

    scenarios = {
        "typical": lambda i: (typical[(i // len(QUERIES)) % len(typical)], QUERIES[i % len(QUERIES)]),
        "heavy": lambda i: (1, QUERIES[i % len(QUERIES)]),
    }
    for scen, pick in scenarios.items():
        for engine, fn in (("postgres", pg_search), ("elasticsearch", es_search)):
            took.clear()
            s, results, samples = measure(lambda i: fn(*pick(i)))
            per_query = {}
            n_warm = WARMUP
            for k, (ns, total) in enumerate(zip(samples, results)):
                qi = (n_warm + k) % len(QUERIES)
                per_query.setdefault(qi, []).append(ns / 1e6)
            s["per_query_p50_ms"] = {QUERIES[qi]: sorted(v)[len(v) // 2] for qi, v in sorted(per_query.items())}
            s["mean_hits"] = sum(results) / len(results)
            if engine == "elasticsearch":
                t = sorted(took[WARMUP:])
                s["took_ms"] = {"p50": t[len(t) // 2], "p95": t[int(len(t) * 0.95) - 1], "p99": t[int(len(t) * 0.99) - 1],
                                "max": t[-1], "mean": sum(t) / len(t)}
            out["scenarios"][f"{scen}/{engine}"] = s
            line(f"E2 {scen:<8} {engine}", s)

    # quality: full result sets of both engines against the ground truth (whole-word match after folding), outside the timing
    def pg_ids(user_id, q):
        pattern = like_pattern(q)
        return [r[0] for r in cur.execute(page_sql, (user_id, pattern, pattern, pattern, pattern, pattern, 0, 10000)).fetchall()]

    def es_ids(user_id, q):
        body = dict(es_body(user_id, q), size=10000, _source=False)
        j = session.post(ES + "/transactions/_search", data=json.dumps(body), headers={"Content-Type": "application/json"}).json()
        return [int(h["_id"]) for h in j["hits"]["hits"]]

    def user_rows(user_id):
        return cur.execute("SELECT t.id, t.note, t.category_name, t.location, t.payment_method, r.vendor_name FROM transactions t "
                           "LEFT JOIN receipts r ON r.id = t.receipt_id WHERE t.user_id = %s", (user_id,)).fetchall()

    def examples(rows, ids, limit=3):
        by_id = {r[0]: r for r in rows}
        return [[v for v in by_id[i][1:] if v] for i in sorted(ids)[:limit]]

    out["quality"] = {}
    for scen, users in (("heavy", [1]), ("typical", typical)):
        table = {}
        for q in QUERIES:
            agg = {"truth": 0, "pg_total": 0, "pg_tp": 0, "pg_fp": 0, "pg_fn": 0, "es_total": 0, "es_tp": 0, "es_fp": 0, "es_fn": 0,
                   "pg_top20_hit": 0, "pg_top20_n": 0, "es_top20_hit": 0, "es_top20_n": 0}
            for u in users:
                rows = user_rows(u)
                gt = truth(rows, q)
                pg, es = pg_ids(u, q), es_ids(u, q)
                for name, got in (("pg", pg), ("es", es)):
                    sg = set(got)
                    agg[f"{name}_total"] += len(got)
                    agg[f"{name}_tp"] += len(sg & gt)
                    agg[f"{name}_fp"] += len(sg - gt)
                    agg[f"{name}_fn"] += len(gt - sg)
                    agg[f"{name}_top20_n"] += len(got[:PAGE])
                    agg[f"{name}_top20_hit"] += sum(1 for i in got[:PAGE] if i in gt)
                    if scen == "heavy":
                        agg[f"{name}_fp_examples"] = examples(rows, sg - gt)
                        agg[f"{name}_fn_examples"] = examples(rows, gt - sg)
                agg["truth"] += len(gt)
            table[q] = agg
        out["quality"][scen] = table
    out["pair_sets_equal_heavy"] = {
        a: {"elasticsearch": set(es_ids(1, a)) == set(es_ids(1, b)), "postgres": set(pg_ids(1, a)) == set(pg_ids(1, b))}
        for a, b in TERMS}
    for q in ("pho", "phở"):
        print("quality heavy", q, {k: v for k, v in out["quality"]["heavy"][q].items() if not k.endswith("examples")}, flush=True)


    # server-side timing: EXPLAIN (ANALYZE) of the page query, heavy and one typical user
    for label, user in (("heavy", 1), ("typical", typical[0])):
        for q in ("phở", "pho"):
            pattern = like_pattern(q)
            plan = cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) " + page_sql,
                               (user, pattern, pattern, pattern, pattern, pattern, 0, PAGE)).fetchall()
            text = "\n".join(r[0] for r in plan)
            out["explain"][f"pg/{label}/{q}"] = text
    # ES server-side: `took` per request is already in the scenario summaries; keep one profile for the record
    body = es_body(1, "phở")
    prof = session.post(ES + "/transactions/_search", json=dict(body, profile=True)).json()
    out["explain"]["es/heavy/phở/took_ms"] = prof["took"]
    out["explain"]["es/heavy/phở/profile_time_in_nanos"] = sum(
        q["time_in_nanos"] for sh in prof["profile"]["shards"] for s_ in sh["searches"] for q in s_["query"])
    save("E2", out)


if __name__ == "__main__":
    main()
