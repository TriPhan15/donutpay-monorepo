# Benchmarks E1–E5 (NoSQL report, Task 3)

Reproducible, data-layer measurements for the report (Ch.4.4, 4.13/6.4, 7.2). **All data is synthetic** (`gen_data.py`, seed 42).
Results: `docs/nosql/bench_results.md` (written by `docs/nosql/build/report_bench.py` from the JSON in `docs/nosql/bench_raw/`; `runs.log` lists which command produced which run),
charts `docs/nosql/diagrams/bench_E*.png` (`docs/nosql/build/plot_bench.py`).

## Run

```bash
scripts/nosql/bench/run_all.sh            # E1 E2 E3 E4 E5, about 45 minutes (E5 variant A is slow by nature)
scripts/nosql/bench/run_all.sh E3 E4      # a subset
BENCH_WARMUP=20 BENCH_ITERATIONS=60 OUT=/tmp/smoke scripts/nosql/bench/run_all.sh E3   # quick smoke test
python3 docs/nosql/build/report_bench.py
python3 -m venv /tmp/venv && /tmp/venv/bin/pip install matplotlib==3.10.7 && /tmp/venv/bin/python docs/nosql/build/plot_bench.py
```

Needs Docker and images `mongo:6.0`, `redis:8.10-alpine`, `elasticsearch:8.11.4`, `postgres:15-alpine` (same as
`docker-compose.yml`); the client image (`Dockerfile`, `python:3.12-slim` + pymongo, redis-py, psycopg, requests) is built on the
first run. Each run creates **one private docker network** and containers labelled with the run id; nothing is published on the
host and the `finance-*` compose stack is never touched. A `trap` removes the containers and the network on exit.

## Method (same for every experiment)

- One long-lived Python client per experiment, inside the network (never `docker exec` per call).
- Warm-up 200 iterations (not timed), then 1 200 timed iterations (`BENCH_ITERATIONS`), one thread, strictly sequential.
- Each call is timed with `time.perf_counter_ns`; p50/p95/p99 are nearest-rank on the sorted samples; ops/s = n / total time.
- Server-side timing next to the client-side one: MongoDB `explain("executionStats")`, PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`,
  Elasticsearch `took`, Redis `INFO commandstats` `usec_per_call`. A "floor" (Redis `PING`, PostgreSQL `SELECT 1`,
  Elasticsearch `GET /`) is measured to show the cost of a call that does nothing.
- Container limits as in `docker-compose.yml`: Redis 192 MB / `maxmemory 128mb`, MongoDB 512 MB / WiredTiger cache 0.25 GB,
  Elasticsearch 1 GB / heap 512 MB (security off in the private network). PostgreSQL: image defaults.

## Files

| File | What |
|---|---|
| `gen_data.py` | deterministic data: 100 000 transactions (1 000 users, user 1 holds 20 %), 34 943 receipts, 100 000 `ocr_logs`, ~45 000 `ocr_feedbacks`, ES bulk file; writes `MANIFEST.sha256` |
| `schema_hibernate_pg.ddl` | Hibernate 6.4 DDL (PostgreSQL 15) of `users`, `categories`, `receipts`, `transactions`, copied from a show-sql log |
| `captured_queries.txt` | the SQL (and bind values) Hibernate emitted for `searchIdsByText`, `sumExpensesByUserBetween`, `findAllById` (users), `dashboardOf`, `popularVendorsOf`, `getDashboardSummary` |
| `BenchSqlCaptureTest.java.txt` | the throwaway `@DataJpaTest` (PostgreSQL 15 Testcontainer, `ddl-auto=create`, show-sql + bind tracing) that produced the two files above; copy it into `core-backend/src/test/java/.../Repository/`, run `mvn -o -Dtest=BenchSqlCaptureTest test`, delete it again |
| `benchlib.py`, `pgload.py`, `mongoload.py` | timing loop and statistics, PostgreSQL schema + COPY loader, MongoDB loader (app indexes + no-index twins) |
| `bench_e1_mongo.py` … `bench_e5_embed.py` | the experiments (see their docstrings) |
| `run_all.sh`, `Dockerfile` | orchestration and client image |

## Experiments

- **E1** Q-01/Q-02/Q-03 with the app's indexes vs twin collections with only `_id`; `explain` keys/docs examined.
- **E2** the real `searchIdsByText` SQL (page + count) vs the real `ElasticsearchTransactionSearchEngine` query body (fuzziness
  `AUTO:4,7`, commit 7f07caa) on an index made from the app's settings/mapping files; 10 terms × (with, without accents) for a
  typical user and a heavy user; full result sets compared with a ground truth (whole word after lowercase + accent folding):
  false positives, misses, precision of the top 20.
- **E3** `ZREVRANGE 0 9 WITHSCORES` and `ZREVRANGE` + the `findAllById` users lookup (the app's whole Redis path) vs
  `sumExpensesByUserBetween`; the Lua refresh script; the rebuild.
- **E4** Redis `GET` of the cached JSON vs the captured SQL of the dashboard, popular vendors and admin summary.
- **E5** Q-13 `$lookup` vs an embedded copy of the log in each feedback (answers compared first), plus the same two with
  `$sort`/`$limit` moved before the join (variant A measures a late `$lookup`; variant B is the fair figure).

## Determinism check

`python3 gen_data.py A && python3 gen_data.py B && diff A/MANIFEST.sha256 B/MANIFEST.sha256` prints nothing (checked 2026-10-28;
the combined sha256 is in `docs/nosql/bench_raw/MANIFEST.sha256`). Only Python's seeded `random` is used; the one float function
(`math.exp`) comes from the platform libm, so another libm could in principle move an amount by one unit of 1 000.
