"""E4: cache vs no cache at the data layer (AP-07, AP-08): Redis GET of the cached JSON vs the SQL a cache miss runs.

The SQL is what Hibernate emitted when UserStatisticsService.dashboardOf / popularVendorsOf and
AdminStatisticsService.getDashboardSummary ran against PostgreSQL 15 (captured_queries.txt, written from the show-sql + bind log
of BenchSqlCaptureTest): 3 statements for the user dashboard, 1 for the popular vendors, 5 for the admin summary. Nothing is
hand-written. The cached JSON is built from those same result rows with the field set of AppDashboardResponseDto /
TransactionResponseDto (Jackson's @class type tags are not added), so its size is realistic to within a few percent.
"hit"  = Redis GET of the key (and, in a second row, GET + json.loads, the work of a client that uses the value).
"miss" = the statements run one after the other on one connection + building the same JSON-shaped result (row "SQL"), and
         that + json.dumps + SET (row "miss, complete": what the @Cacheable method really does on a miss).
The miss path of the real app may add a lazy PK lookup of the receipt of the biggest transaction; it is not in the capture, so
the miss cost here is a lower bound and the speed-up a conservative one.
"""
import json
import os
import random
import re
from datetime import datetime

import psycopg
import redis

import pgload
from benchlib import load_captured_sql, line, measure, save, wait_tcp

REDIS_HOST = os.environ.get("REDIS_HOST", "bench-redis")
LEGACY_STATUS = {"COMPLETED_RAW": "SUCCESS", "EDITED": "SUCCESS", "APPROVED": "SUCCESS"}
PERIOD = (datetime(2026, 10, 1), datetime(2026, 10, 31, 23, 59, 59))
THRESHOLD = 50000


def select_index(sql):
    """'alias.column' -> position in the select list of a Hibernate statement."""
    head = sql.split("from", 1)[0]
    exprs = [e.strip() for e in head.replace("select", "", 1).split(",")]
    return {e: i for i, e in enumerate(exprs)}


def tx_dto(row, ix):
    note = row[ix["t1_0.note"]]
    receipt_id = row[ix["r1_0.id"]] if "r1_0.id" in ix else None
    status = row[ix["r1_0.status"]] if "r1_0.status" in ix else None
    return {
        "id": row[ix["t1_0.id"]],
        "title": note if note and note.strip() else row[ix["t1_0.category_name"]],
        "amount": str(row[ix["t1_0.amount"]]),
        "date": row[ix["t1_0.transaction_date"]].isoformat(),
        "category": row[ix["t1_0.category_name"]],
        "isExpense": row[ix["t1_0.is_expense"]],
        "imageUrl": row[ix["r1_0.image_url"]] if receipt_id is not None else None,
        "receiptStatus": LEGACY_STATUS.get(status, status) if receipt_id is not None else None,
        "clientId": row[ix["t1_0.client_id"]],
    }


def main():
    q = load_captured_sql()
    biggest_sql, recent_sql, sale_sql = (x[0] for x in q["dashboardOf"])
    popular_sql = q["popularVendorsOf"][0][0]
    s_volume, s_users, s_count, s_low, s_status = (x[0] for x in q["getDashboardSummary"])
    ix_big, ix_recent, ix_sale = select_index(biggest_sql), select_index(recent_sql), select_index(sale_sql)

    conn = pgload.connect()
    counts = pgload.load(conn)
    cur = conn.cursor()
    pg_version = cur.execute("SELECT version()").fetchone()[0]
    rng = random.Random(11)
    pool = [r[0] for r in conn.execute(
        "SELECT user_id FROM transactions WHERE user_id <> 1 GROUP BY user_id HAVING count(*) BETWEEN 70 AND 90 ORDER BY user_id")]
    users = sorted(rng.sample(pool, 500))

    def dashboard_miss(uid):
        big = cur.execute(biggest_sql, (uid, 1)).fetchall()
        recent = cur.execute(recent_sql, (uid, 0, 5)).fetchall()
        sale = cur.execute(sale_sql, (uid,)).fetchall()
        return {"recentTransactions": [tx_dto(r, ix_recent) for r in recent],
                "biggestTransaction": tx_dto(big[0], ix_big) if big else None,
                "saleTransactions": [tx_dto(r, ix_sale) for r in sale]}

    def popular_miss(uid):
        return [{"vendorName": v, "transactionCount": c} for v, c in cur.execute(popular_sql, (uid,)).fetchall()]

    def summary_miss(_uid):
        volume = cur.execute(s_volume).fetchone()[0]
        n_users = cur.execute(s_users).fetchone()[0]
        n_tx = cur.execute(s_count, PERIOD).fetchone()[0]
        low = cur.execute(s_low, (THRESHOLD,)).fetchall()
        statuses = {}
        for st, n in cur.execute(s_status).fetchall():
            statuses[LEGACY_STATUS.get(st, st)] = statuses.get(LEGACY_STATUS.get(st, st), 0) + n
        return {"totalVolume": str(volume), "totalUsers": n_users, "transactionsInPeriod": n_tx,
                "lowBalanceUsers": [{"id": r[0], "username": r[12], "walletBalance": str(r[13])} for r in low],
                "receiptStatuses": [{"status": k, "count": v} for k, v in statuses.items()]}

    wait_tcp(REDIS_HOST, 6379)
    r = redis.Redis(host=REDIS_HOST, port=6379)
    redis_version = r.info("server")["redis_version"]
    r.flushall()

    cases = {
        "dashboard": ("ledgermind:bench:1:user-dashboard:", dashboard_miss, users),
        "popular_vendors": ("ledgermind:bench:1:user-popular-vendors:", popular_miss, users),
        "admin_summary": ("ledgermind:bench:1:admin-dashboard-summary:", summary_miss, [0]),
    }
    out = {"versions": {"postgres": pg_version, "redis": redis_version, "redis-py": redis.__version__,
                        "psycopg": psycopg.__version__},
           "rows": counts, "cache_users": len(users), "scenarios": {}, "payload_bytes": {}, "floor": {}, "explain": {},
           "redis_server_usec_per_call_get": None, "pg_statements": {
               "dashboard": 3, "popular_vendors": 1, "admin_summary": 5}}

    s, _, _ = measure(lambda i: r.ping())
    out["floor"]["redis_ping"] = s
    line("floor: Redis PING", s)
    s, _, _ = measure(lambda i: cur.execute("SELECT 1").fetchone())
    out["floor"]["postgres_select_1"] = s
    line("floor: PostgreSQL SELECT 1", s)

    for name, (prefix, miss, keys) in cases.items():
        sizes = []
        for k in keys:
            payload = json.dumps(miss(k), ensure_ascii=False, separators=(",", ":"))
            sizes.append(len(payload.encode("utf-8")))
            r.set(prefix + str(k), payload, ex=3600)
        out["payload_bytes"][name] = {"mean": sum(sizes) / len(sizes), "max": max(sizes), "min": min(sizes)}

        def get_raw(i, prefix=prefix, keys=keys):
            return r.get(prefix + str(keys[i % len(keys)]))

        def get_decoded(i, prefix=prefix, keys=keys):
            return json.loads(r.get(prefix + str(keys[i % len(keys)])))

        def sql_only(i, miss=miss, keys=keys):
            return miss(keys[i % len(keys)])

        def miss_complete(i, prefix=prefix, miss=miss, keys=keys):
            k = keys[i % len(keys)]
            r.set(prefix + str(k), json.dumps(miss(k), ensure_ascii=False, separators=(",", ":")), ex=3600)

        r.config_resetstat()
        s, _, _ = measure(get_raw)
        s["server_usec_per_call"] = float(r.info("commandstats")["cmdstat_get"]["usec_per_call"])
        out["scenarios"][f"{name}/redis_get"] = s
        line(f"E4 {name} Redis GET", s)
        for label, fn in (("redis_get_json_loads", get_decoded), ("sql", sql_only), ("miss_complete", miss_complete)):
            s, _, _ = measure(fn)
            out["scenarios"][f"{name}/{label}"] = s
            line(f"E4 {name} {label}", s)
        hit, miss_s = out["scenarios"][f"{name}/redis_get"], out["scenarios"][f"{name}/sql"]
        out["scenarios"][f"{name}/redis_get"]["speedup_p50_vs_sql"] = miss_s["p50_ms"] / hit["p50_ms"]
        out["scenarios"][f"{name}/redis_get_json_loads"]["speedup_p50_vs_miss_complete"] = (
            out["scenarios"][f"{name}/miss_complete"]["p50_ms"] / out["scenarios"][f"{name}/redis_get_json_loads"]["p50_ms"])

    # server-side timing of every captured statement for one user
    uid = users[0]
    stmts = {
        "dashboard/biggest": (biggest_sql, (uid, 1)), "dashboard/recent": (recent_sql, (uid, 0, 5)),
        "dashboard/sale": (sale_sql, (uid,)), "popular_vendors": (popular_sql, (uid,)),
        "admin/sum_volume": (s_volume, ()), "admin/count_users": (s_users, ()), "admin/count_period": (s_count, PERIOD),
        "admin/low_balance": (s_low, (THRESHOLD,)), "admin/receipt_status": (s_status, ()),
    }
    for name, (sql, params) in stmts.items():
        plan = cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) " + sql, params).fetchall()
        text = "\n".join(x[0] for x in plan)
        out["explain"][name] = text
        m = re.search(r"Execution Time: ([\d.]+) ms", text)
        print(f"  EXPLAIN ANALYZE {name}: {m.group(1)} ms", flush=True)
    save("E4", out)


if __name__ == "__main__":
    main()
