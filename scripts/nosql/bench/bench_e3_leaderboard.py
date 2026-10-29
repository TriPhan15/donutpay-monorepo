"""E3: top 10 of the monthly spending leaderboard (AP-11): Redis ZSET vs the SQL of TransactionRepository.sumExpensesByUserBetween.

Redis side: the month's sorted set (member = user id, score = what the user spent, built with ZADD from the SQL result exactly as
SpendingLeaderboardService.writeRows does) read with ZREVRANGE 0 9 WITHSCORES. The maintenance path (AP-12/13) is measured too:
the REFRESH_MEMBER_SCRIPT Lua script of the service (EXISTS, then ZADD with an absolute score), called through EVALSHA.
PostgreSQL side: the SQL Hibernate emits for sumExpensesByUserBetween (captured_queries.txt) for the same month (2026-10),
which is also what the service falls back to when Redis is down, and what a cache miss costs.
The Redis path of the app is not only the ZSET read: topSpenders then calls userRepo.findAllById(ids) for the 10 names (the SQL
path already carries the username through its join). That statement is the one Hibernate emitted for findAllById
(captured_queries.txt, section findAllById) and is timed as part of the Redis path ("ZREVRANGE + users lookup").
"""
import os
import random
from datetime import datetime
from decimal import Decimal

import psycopg
import redis

import pgload
from benchlib import load_captured_sql, line, measure, save, wait_tcp

REDIS_HOST = os.environ.get("REDIS_HOST", "bench-redis")
MONTH_KEY = "ledgermind:leaderboard:spend:2026-10"
START, END = datetime(2026, 10, 1), datetime(2026, 11, 1)
# SpendingLeaderboardService.REFRESH_MEMBER_SCRIPT, verbatim ('' = REMOVE_MEMBER)
LUA = """
if redis.call('EXISTS', KEYS[1]) == 0 then
  return 0
end
if ARGV[2] == '' then
  redis.call('ZREM', KEYS[1], ARGV[1])
else
  redis.call('ZADD', KEYS[1], ARGV[2], ARGV[1])
end
return 1
"""


def main():
    captured = load_captured_sql()
    sql = captured["sumExpensesByUserBetween"][0][0]
    users_sql = captured["findAllById"][0][0]
    conn = pgload.connect()
    counts = pgload.load(conn)
    cur = conn.cursor()
    pg_version = cur.execute("SELECT version()").fetchone()[0]
    month_rows = cur.execute("SELECT count(*) FROM transactions WHERE is_expense AND transaction_date >= %s AND transaction_date < %s",
                             (START, END)).fetchone()[0]

    wait_tcp(REDIS_HOST, 6379)
    r = redis.Redis(host=REDIS_HOST, port=6379)
    redis_version = r.info("server")["redis_version"]
    r.flushall()
    rows = cur.execute(sql, (START, END)).fetchall()
    members = {str(uid): float(total) for uid, _name, total in rows}
    r.zadd(MONTH_KEY, members)
    r.expire(MONTH_KEY, 62 * 86400)
    print(f"month 2026-10: {month_rows} expense rows -> {len(rows)} users in the sorted set", flush=True)

    # correctness: the two answers agree on the ids and scores of the top 10
    top_sql = [(str(uid), float(total)) for uid, _n, total in rows[:10]]
    top_redis = [(m.decode(), s) for m, s in r.zrevrange(MONTH_KEY, 0, 9, withscores=True)]
    agree = top_sql == top_redis
    print("top 10 agree between SQL and Redis:", agree, flush=True)

    out = {"versions": {"postgres": pg_version, "redis": redis_version, "redis-py": redis.__version__,
                        "psycopg": psycopg.__version__},
           "rows": counts, "month_expense_rows": month_rows, "zset_members": len(rows), "top10_agree": agree,
           "scenarios": {}, "floor": {}, "explain": {}}

    r.config_resetstat()
    s, _, _ = measure(lambda i: r.ping())
    out["floor"]["redis_ping"] = s
    line("floor: Redis PING", s)
    s, _, _ = measure(lambda i: cur.execute("SELECT 1").fetchone())
    out["floor"]["postgres_select_1"] = s
    line("floor: PostgreSQL SELECT 1", s)

    r.config_resetstat()
    s, res, _ = measure(lambda i: r.zrevrange(MONTH_KEY, 0, 9, withscores=True))
    s["server_usec_per_call"] = float(r.info("commandstats")["cmdstat_zrevrange"]["usec_per_call"])
    out["scenarios"]["redis_zrevrange_top10"] = s
    line("E3 Redis ZREVRANGE 0 9 WITHSCORES", s)

    def redis_top10_with_names(i):
        top = r.zrevrange(MONTH_KEY, 0, 9, withscores=True)
        names = cur.execute(users_sql, [int(m) for m, _ in top]).fetchall()
        return top, names

    s, res, _ = measure(redis_top10_with_names)
    assert len(res[0][1]) == 10
    out["scenarios"]["redis_zrevrange_plus_users_lookup"] = s
    line("E3 Redis ZREVRANGE + users lookup (findAllById SQL)", s)
    plan = cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) " + users_sql, [int(m) for m, _ in r.zrevrange(MONTH_KEY, 0, 9, withscores=True)]).fetchall()
    out["explain"]["pg_users_lookup"] = "\n".join(x[0] for x in plan)

    refresh = r.register_script(LUA)
    rng = random.Random(3)
    uids = [rng.choice(list(members)) for _ in range(5000)]
    r.config_resetstat()
    s, _, _ = measure(lambda i: refresh(keys=[MONTH_KEY], args=[uids[i % len(uids)], f"{1000 + i}.50"]))
    stats = r.info("commandstats")
    s["server_usec_per_call_evalsha"] = float(stats["cmdstat_evalsha"]["usec_per_call"])
    out["scenarios"]["redis_lua_refresh_member"] = s
    line("E3 Redis Lua refresh (EVALSHA, ZADD absolute)", s)
    # put the scores back as the SQL says: the Lua runs changed 1000+ of them
    r.zadd(MONTH_KEY, members)

    def pg_top():
        return cur.execute(sql, (START, END)).fetchmany(10)

    s, _, _ = measure(lambda i: cur.execute(sql, (START, END)).fetchall())
    out["scenarios"]["pg_sum_expenses_by_user"] = s
    line("E3 PostgreSQL sumExpensesByUserBetween (all rows)", s)

    plan = cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) " + sql, (START, END)).fetchall()
    out["explain"]["pg"] = "\n".join(x[0] for x in plan)
    # rebuild cost (what a miss does besides the SQL): ZADD of every member
    s, _, _ = measure(lambda i: (r.delete("bench:tmp"), r.zadd("bench:tmp", members)), warmup=20, iterations=200)
    out["scenarios"]["redis_rebuild_zadd_all_members"] = s
    line("E3 Redis rebuild (DEL + ZADD of every member)", s)
    r.delete("bench:tmp")
    save("E3", out)


if __name__ == "__main__":
    main()
