"""Shared helpers of the benchmark clients: timing loop, percentiles, waiting for servers, captured-SQL loader, result file.

Method (one rule set for every experiment, from the plan):
  * one long-lived client process per experiment, inside the throwaway docker network;
  * warm-up 200 iterations (not timed), then >= 1000 timed iterations, single thread, strictly sequential;
  * every iteration is timed with time.perf_counter_ns around the call alone; percentiles are nearest-rank on the sorted
    samples; ops/s = n / sum(samples) (what one thread can sustain, "1 luồng"); the garbage collector is paused while timing.
"""
import gc
import json
import os
import platform
import re
import socket
import sys
import time

WARMUP = int(os.environ.get("BENCH_WARMUP", "200"))
ITERATIONS = int(os.environ.get("BENCH_ITERATIONS", "1200"))
RESULTS_DIR = os.environ.get("BENCH_RESULTS", "/results")
DATA_DIR = os.environ.get("BENCH_DATA", "/data")
BENCH_DIR = os.path.dirname(os.path.abspath(__file__))


def percentile(sorted_ms, p):
    """Nearest-rank percentile of an ascending list."""
    rank = max(1, -(-len(sorted_ms) * p // 100))  # ceil(n * p / 100)
    return sorted_ms[int(rank) - 1]


def summarize(samples_ns):
    ms = sorted(s / 1e6 for s in samples_ns)
    total_s = sum(samples_ns) / 1e9
    return {
        "n": len(ms),
        "p50_ms": percentile(ms, 50),
        "p95_ms": percentile(ms, 95),
        "p99_ms": percentile(ms, 99),
        "max_ms": ms[-1],
        "min_ms": ms[0],
        "mean_ms": sum(ms) / len(ms),
        "ops_s": len(ms) / total_s,
    }


def measure(fn, warmup=None, iterations=None):
    """fn(i) is called warmup times untimed, then iterations times timed. Returns (summary, fn results, samples in ns)."""
    warmup = WARMUP if warmup is None else warmup
    iterations = ITERATIONS if iterations is None else iterations
    for i in range(warmup):
        fn(i)
    samples = []
    results = []
    gc.collect()
    gc.disable()
    try:
        for i in range(iterations):
            t0 = time.perf_counter_ns()
            r = fn(warmup + i)
            t1 = time.perf_counter_ns()
            samples.append(t1 - t0)
            results.append(r)
    finally:
        gc.enable()
    out = summarize(samples)
    out["warmup"] = warmup
    return out, results, samples


def wait_tcp(host, port, timeout=180):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=2):
                return
        except OSError:
            time.sleep(1)
    raise RuntimeError(f"{host}:{port} did not come up in {timeout}s")


def load_captured_sql():
    """Sections of captured_queries.txt (written from the show-sql log of BenchSqlCaptureTest): name -> list of
    (sql with %s placeholders, bind type list). Hibernate's `?` become psycopg's `%s`; the SQL text is otherwise untouched."""
    path = os.path.join(BENCH_DIR, "captured_queries.txt")
    text = open(path, encoding="utf-8").read()
    sections = {}
    for block in re.split(r"(?m)^-- ### ", text)[1:]:
        name, rest = block.split("\n", 1)
        sql, binds = rest.split("\n-- binds:", 1)
        sql = sql.strip()
        assert sql.endswith(";")
        sql = sql[:-1]
        assert "%" not in sql, "a literal % would need escaping"
        types = re.findall(r"\$\d+ (\w+)=", binds)
        sections.setdefault(name.strip(), []).append((sql.replace("?", "%s"), types))
    return sections


def host_info():
    cpu = ""
    try:
        for line in open("/proc/cpuinfo", encoding="utf-8"):
            if line.startswith("model name"):
                cpu = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    mem = ""
    try:
        for line in open("/proc/meminfo", encoding="utf-8"):
            if line.startswith("MemTotal"):
                mem = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    return {"cpu": cpu, "mem_total": mem, "cpus": os.cpu_count(), "kernel": platform.release(),
            "python": sys.version.split()[0]}


def save(experiment, payload):
    os.makedirs(RESULTS_DIR, exist_ok=True)
    payload["experiment"] = experiment
    payload["client_host"] = host_info()
    payload["warmup"] = WARMUP
    payload["iterations"] = ITERATIONS
    path = os.path.join(RESULTS_DIR, f"{experiment}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"saved {path}", flush=True)


def line(label, s):
    print(f"{label:<58} p50={s['p50_ms']:.3f} p95={s['p95_ms']:.3f} p99={s['p99_ms']:.3f} max={s['max_ms']:.3f} ms  "
          f"{s['ops_s']:.0f} ops/s", flush=True)
