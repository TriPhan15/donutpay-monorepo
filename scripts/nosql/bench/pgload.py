"""Creates the Hibernate schema (schema_hibernate_pg.ddl) in the throwaway PostgreSQL and loads the synthetic CSV files."""
import os
import time

import psycopg

from benchlib import BENCH_DIR, DATA_DIR, wait_tcp

TABLES = ["users", "categories", "receipts", "transactions"]


def connect(host=None, autocommit=True):
    host = host or os.environ.get("PG_HOST", "bench-pg")
    wait_tcp(host, 5432)
    last = None
    for _ in range(60):
        try:
            return psycopg.connect(host=host, port=5432, user="bench", password="bench", dbname="bench",
                                   autocommit=autocommit)
        except psycopg.OperationalError as e:  # the server accepts TCP a moment before it accepts logins
            last = e
            time.sleep(1)
    raise last


def load(conn):
    started = time.time()
    with conn.cursor() as cur:
        cur.execute(open(os.path.join(BENCH_DIR, "schema_hibernate_pg.ddl"), encoding="utf-8").read())
        for table in TABLES:
            path = os.path.join(DATA_DIR, f"{table}.csv")
            with open(path, encoding="utf-8") as f:
                header = f.readline().strip()
            with cur.copy(f"COPY {table} ({header}) FROM STDIN WITH (FORMAT csv, HEADER true)") as copy:
                with open(path, "rb") as f:
                    while chunk := f.read(1 << 20):
                        copy.write(chunk)
        cur.execute("ANALYZE")
        counts = {}
        for table in TABLES:
            cur.execute(f"SELECT count(*) FROM {table}")
            counts[table] = cur.fetchone()[0]
    print(f"PostgreSQL loaded in {time.time() - started:.1f}s: {counts}", flush=True)
    return counts
