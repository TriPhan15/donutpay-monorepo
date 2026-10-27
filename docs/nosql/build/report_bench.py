#!/usr/bin/env python3
"""Renders docs/nosql/bench_results.md from the JSON files that scripts/nosql/bench/run_all.sh wrote to docs/nosql/bench_raw/.

    python3 docs/nosql/build/report_bench.py [RAW_DIR] [OUT_MD]

Every number in the output is read from the JSON; the NFR targets are the ones frozen in facts.md section 2.3 and are only
compared here, never changed. Decimal comma (Vietnamese); times in milliseconds.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
RAW = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "nosql", "bench_raw")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "nosql", "bench_results.md")

LOAD = "1 luồng"


def load(name):
    with open(os.path.join(RAW, name), encoding="utf-8") as f:
        return json.load(f)


def f(x, nd=2):
    return f"{x:.{nd}f}".replace(".", ",")


def ms(x):
    if x < 0.1:
        return f(x, 3)
    if x < 10:
        return f(x, 2)
    return f(x, 1)


def exec_ms(text):
    return re.search(r"Execution Time: ([0-9.]+) ms", text).group(1).replace(".", ",")


def th(n):
    return f"{n:,}".replace(",", ".")


def dec(x, nd=1):
    return f"{x:.{nd}f}".replace(".", ",")


def ops(x):
    return th(round(x))


def row(label, nfr, records, s, verdict):
    return (f"| {label} | {nfr} | {records} | {LOAD} | {ms(s['p50_ms'])} | {ms(s['p95_ms'])} | {ms(s['p99_ms'])} | "
            f"{ops(s['ops_s'])} | {verdict} |")


HEAD = ("| Kịch bản | NFR | Số bản ghi | Tải | p50 (ms) | p95 (ms) | p99 (ms) | ops/s | Đạt NFR |\n"
        "|---|---|---|---|---|---|---|---|---|")
HEAD_MAX = "| Kịch bản | max (ms) | trung bình (ms) | n (đo) | khởi động (không tính) |\n|---|---|---|---|---|"


def maxrow(label, s):
    return f"| {label} | {ms(s['max_ms'])} | {ms(s['mean_ms'])} | {s['n']} | {s['warmup']} |"


def ok(flag):
    return "Đạt" if flag else "KHÔNG đạt"


def host_block():
    text = open(os.path.join(RAW, "host.txt"), encoding="utf-8").read()
    manifest = open(os.path.join(RAW, "MANIFEST.sha256"), encoding="utf-8").read().strip().split("\n")
    return text.strip(), manifest


def main():
    e1, e2, e3, e4, e5 = (load(f"E{i}.json") for i in range(1, 6))
    host, manifest = host_block()
    hostd = dict(l.split(": ", 1) for l in host.split("\n") if ": " in l and not l.startswith("image"))
    images = [l for l in host.split("\n") if l.startswith("image")]
    out = []
    w = out.append
    nfr = {}  # id -> (target, measured, verdict) for the summary table

    w("# Kết quả đo hiệu năng E1–E5 (Task 3)")
    w("")
    w("> **Dữ liệu tổng hợp**: toàn bộ dữ liệu trong bảng này do `scripts/nosql/bench/gen_data.py` sinh ra (seed 42), không có "
      "dữ liệu thật của người dùng. Số đo là **độ trễ tầng dữ liệu** (client Python trong cùng mạng docker, không qua "
      "Spring/JPA/mạng ngoài), 1 luồng, tuần tự. Dấu phẩy là dấu thập phân. Mục tiêu NFR lấy nguyên từ `facts.md` §2.3 "
      "(đóng băng trước khi đo); cột \"Đạt NFR\" chỉ so sánh, không sửa mục tiêu.")
    w("")
    w("## 0. Môi trường, phiên bản, lệnh")
    w("")
    w("| Mục | Giá trị |\n|---|---|")
    runs = open(os.path.join(RAW, "runs.log"), encoding="utf-8").read().strip().split("\n")
    w(f"| Ngày đo (UTC), lệnh | " + "; ".join(f"`{r.split(' ', 1)[1]}` lúc {r.split(' ', 1)[0]}" for r in runs) + " |")
    w(f"| CPU | {hostd.get('cpu')} ({hostd.get('cpus')} luồng) |")
    w(f"| RAM | {hostd.get('mem')} |")
    w(f"| Nhân Linux | {hostd.get('kernel')} |")
    w(f"| Docker Engine | {hostd.get('docker')} |")
    w(f"| MongoDB (server / pymongo) | {e1['versions']['mongodb']} / {e1['versions']['pymongo']} |")
    w(f"| Redis (server / redis-py) | {e3['versions']['redis']} / {e3['versions']['redis-py']} |")
    w(f"| Elasticsearch | {e2['versions']['elasticsearch']} (bảo mật tắt trong mạng riêng, 1 node, heap 512 MB, 1 shard, 0 replica) |")
    w(f"| PostgreSQL | {e2['versions']['postgres']} |")
    w(f"| Driver PostgreSQL / HTTP | psycopg {e2['versions']['psycopg']} (chuẩn bị câu lệnh sau 5 lần, như pgjdbc) / requests {e2['versions']['requests']} (keep-alive) |")
    w(f"| Python client | {e1['client_host']['python']} (image `python:3.12-slim`) |")
    w(f"| Giới hạn tài nguyên container | như `docker-compose.yml`: Redis 192 MB (`maxmemory 128mb`), MongoDB 512 MB (WiredTiger cache 0,25 GB), Elasticsearch 1 GB (heap 512 MB); PostgreSQL không giới hạn (compose cũng không) |")
    w(f"| Cách đo | khởi động {e1['warmup']} lần (không tính), rồi {e1['iterations']} lần đo; mỗi lần gọi đo riêng bằng `perf_counter_ns`; phân vị nearest-rank; ops/s = n / tổng thời gian (1 luồng); GC của Python tạm dừng khi đo |")
    w("| Ghi chú lệnh | cần Docker; mỗi lần chạy tạo một mạng riêng và xóa sạch khi xong; sau đó `python3 docs/nosql/build/report_bench.py` và `python3 docs/nosql/build/plot_bench.py`. "
      "Lần chạy thứ hai (E2, E3, E5) làm lại ba thí nghiệm sau khi ứng dụng đổi `FUZZINESS` thành `AUTO:4,7` (commit 7f07caa) và sau khi thêm các hàng bổ sung; lần thứ ba (chỉ E2) làm lại E2 sau khi thêm `prefix_length: 1` (commit b35cd6e). E1 và E4 giữ số đo của lần đầu, E3 và E5 của lần hai, cùng máy, cùng dữ liệu. |")
    w("| Image (ID) | " + "; ".join(f"`{l.split(': ')[0][6:]}` {l.split(': ')[1][7:19]}" for l in images) + " |")
    w("")
    w("Dữ liệu (sha256 từng tệp, sinh hai lần cho ra cùng kết quả):")
    w("")
    w("```\n" + "\n".join(manifest) + "\n```")
    w("")
    w(f"Quy mô: 100.000 giao dịch ({th(e2['rows']['receipts'])} hóa đơn, {e2['rows']['users']} người dùng; người dùng 1 là tài khoản "
      f"\"nặng\" giữ {th(e2['heavy_user_rows'])} giao dịch, mỗi người dùng còn lại khoảng 80), "
      f"{th(e1['counts']['ocr_logs'])} `ocr_logs` và {th(e1['counts']['ocr_feedbacks'])} `ocr_feedbacks`; 10 % văn bản viết không dấu.")
    w("")
    w("Sơ đồ PostgreSQL là DDL do Hibernate 6.4 sinh ra (bốn bảng `users`, `categories`, `receipts`, `transactions`; không có "
      "index nào ngoài khóa chính và khóa duy nhất `uk_transactions_user_client_id (user_id, client_id)`), lấy từ log show-sql của một "
      "bài test tạm chạy trên container PostgreSQL 15 (`scripts/nosql/bench/BenchSqlCaptureTest.java.txt`, "
      "`schema_hibernate_pg.ddl`). Các câu SQL của E2/E3/E4 cũng lấy từ log đó (`captured_queries.txt`), không viết tay.")
    w("")

    # ---------------------------------------------------------------- E1
    w("## E1. MongoDB: có index và không có index (AP-19, AP-38; NFR-05)")
    w("")
    recs1 = f"{th(e1['counts']['ocr_logs'])} / {th(e1['counts']['ocr_feedbacks'])}"
    w(HEAD)
    e1_ok = {}
    for q, nfr_note in (("Q-01", "NFR-05"), ("Q-02", "NFR-05"), ("Q-03", "NFR-05")):
        ex = e1["explain"][f"{q}/indexed"]
        s = e1["scenarios"][f"{q}/indexed"]
        flag = ("IXSCAN" in ex["stages"]) and ex["totalDocsExamined"] == ex["nReturned"] and s["p95_ms"] < 20
        e1_ok[q] = (flag, ex, s)
        tick = lambda b: "✓" if b else "✗"  # noqa: E731
        verdict = (f"IXSCAN {tick('IXSCAN' in ex['stages'])}, p95 {tick(s['p95_ms'] < 20)}, docs = nReturned "
                   f"{tick(ex['totalDocsExamined'] == ex['nReturned'])} ({ex['totalDocsExamined']}/{ex['nReturned']}) → {ok(flag)}")
        recs_q = th(e1["counts"]["ocr_feedbacks"] if q == "Q-03" else e1["counts"]["ocr_logs"])
        w(row(f"{q} có index (`{ex['index']}`)", nfr_note, recs_q, s, verdict))
        s0 = e1["scenarios"][f"{q}/noindex"]
        w(row(f"{q} không index (COLLSCAN)", "–", recs_q, s0, f"– (chậm hơn {f(s0['p50_ms'] / s['p50_ms'], 0)}× ở p50)"))
    w("")
    w("Máy chủ (`explain(\"executionStats\")` của đúng lệnh đó):")
    w("")
    w("| Truy vấn | Kế hoạch thắng | Index | keys examined | docs examined | nReturned | executionTimeMillis |\n|---|---|---|---|---|---|---|")
    for q in ("Q-01", "Q-02", "Q-03"):
        for label, name in (("có index", "indexed"), ("không index", "noindex")):
            ex = e1["explain"][f"{q}/{name}"]
            w(f"| {q} {label} | {ex['stages']} | {ex['index'] or '–'} | {ex['totalKeysExamined']} | {ex['totalDocsExamined']} | "
              f"{ex['nReturned']} | {ex['executionTimeMillis']} |")
    w("")
    w(HEAD_MAX)
    for q in ("Q-01", "Q-02", "Q-03"):
        w(maxrow(f"{q} có index", e1["scenarios"][f"{q}/indexed"]))
        w(maxrow(f"{q} không index", e1["scenarios"][f"{q}/noindex"]))
    w("")
    w("Kích thước: " + "; ".join(
        f"`{n}` {th(v['count'])} document, dữ liệu {dec(v['size'] / 1e6, 1)} MB, index {dec(v['totalIndexSize'] / 1e6, 1)} MB"
        for n, v in e1["index_sizes"].items()) + ".")
    w("")
    q2 = e1_ok["Q-02"][1]
    w(f"Ghi chú trung thực: với Q-02 bộ lập kế hoạch chọn index `{q2['index']}` (quét `createdAt` giảm dần cho tới khi đủ 5 dòng "
      f"có `averageConfidenceScore < 0,75`) nên phải kiểm tra {q2['totalDocsExamined']} document để trả {q2['nReturned']}: "
      "điều kiện \"totalDocsExamined = nReturned\" của NFR-05 chỉ đúng khi truy vấn khớp trọn một index theo cả bộ lọc lẫn thứ tự "
      "sắp xếp (Q-03 với `status_date_idx`, Q-01 với `transactionId`). Với Q-02 không index nào làm được điều đó: bộ lọc là một "
      "**khoảng** trên `averageConfidenceScore` (`$lt 0,75`) còn thứ tự sắp xếp là `createdAt`. Theo quy tắc ESR (Equality, Sort, Range) "
      "của MongoDB, index `{averageConfidenceScore, createdAt}` có trường khoảng đứng trước trường sắp xếp nên các khóa trả về theo thứ tự "
      "điểm chứ không theo thời gian, buộc phải có bước SORT trong bộ nhớ (`score_date_idx` nằm trong bộ index nhưng bị bỏ qua); "
      "index `{createdAt}` cho đúng thứ tự nhưng không lọc được theo điểm nên phải đọc các document để loại những dòng điểm ≥ 0,75. "
      "Chỉ khi điều kiện trên điểm là bằng nhau (không phải khoảng) thì `{điểm, createdAt}` mới thỏa cả hai.")
    w("")
    nfr["NFR-05"] = ("IXSCAN, totalDocsExamined = nReturned, p95 < 20 ms (Q-01..03, có index)",
                     "; ".join(f"{q}: p95 {ms(e1_ok[q][2]['p95_ms'])} ms, docs/nReturned {e1_ok[q][1]['totalDocsExamined']}/{e1_ok[q][1]['nReturned']}"
                               for q in e1_ok),
                     "Đạt" if all(v[0] for v in e1_ok.values()) else
                     "Một phần: " + ", ".join(q for q, v in e1_ok.items() if v[0]) + " đạt; " + ", ".join(q for q, v in e1_ok.items() if not v[0]) + " không đạt vế docs = nReturned" if all(v[2]['p95_ms'] < 20 and 'IXSCAN' in v[1]['stages'] for v in e1_ok.values()) else "Không đạt")

    # ---------------------------------------------------------------- E2
    w("## E2. Elasticsearch và PostgreSQL `LOWER(..) LIKE .. ESCAPE` (AP-29, AP-31; NFR-03, NFR-04)")
    w("")
    w("PostgreSQL: câu `searchIdsByText` (trang 20 dòng, thêm câu `count` khi trang đầy, như `Page` của Spring Data). "
      "Elasticsearch: thân yêu cầu của `ElasticsearchTransactionSearchEngine.hits` (hai `multi_match`, nhánh mờ `fuzziness: AUTO:4,7` với `prefix_length: 1` như `FUZZINESS` và `FUZZY_PREFIX_LENGTH` hiện tại của mã nguồn (commits 7f07caa, b35cd6e), lọc `userId`, sắp xếp "
      "điểm rồi ngày, `track_total_hits`, trang 0 cỡ 20), trên index tạo từ `transactions-settings.json` và `transactions-mapping.json` của ứng dụng. "
      "Chỉ đo bước truy vấn của engine (việc nạp lại các dòng theo id từ PostgreSQL là chung cho cả hai). "
      f"20 chuỗi tìm kiếm = 10 từ × (có dấu, không dấu), quay vòng đều; 'điển hình' = 20 người dùng ~80 giao dịch (quay vòng), 'nặng' = người dùng 1 ({th(e2['heavy_user_rows'])} giao dịch).")
    w("")
    w(HEAD)
    recs2 = "100.000"
    sc = e2["scenarios"]
    es_pass = {}
    for scen, label in (("typical", "người dùng điển hình (~80 dòng)"), ("heavy", f"người dùng nặng ({th(e2['heavy_user_rows'])} dòng)")):
        s = sc[f"{scen}/elasticsearch"]
        es_pass[scen] = s["p95_ms"] < 100
        w(row(f"ES, {label}", "NFR-03", recs2, s, f"p95 < 100 ms → {ok(s['p95_ms'] < 100)}"))
        sp = sc[f"{scen}/postgres"]
        w(row(f"PostgreSQL LIKE, {label}", "–", recs2, sp, f"– (PostgreSQL = {f(sp['p50_ms'] / s['p50_ms'], 2)}× thời gian của ES ở p50)"))
    w("")
    w(HEAD_MAX)
    for scen in ("typical", "heavy"):
        w(maxrow(f"ES {scen}", sc[f"{scen}/elasticsearch"]))
        w(maxrow(f"PostgreSQL {scen}", sc[f"{scen}/postgres"]))
    w("")
    w("Máy chủ Elasticsearch (`took` trong mỗi phản hồi, ms): " + "; ".join(
        f"{scen}: p50 {sc[f'{scen}/elasticsearch']['took_ms']['p50']}, p95 {sc[f'{scen}/elasticsearch']['took_ms']['p95']}, "
        f"p99 {sc[f'{scen}/elasticsearch']['took_ms']['p99']}, max {sc[f'{scen}/elasticsearch']['took_ms']['max']}" for scen in ("typical", "heavy")) + ".")
    w("")
    fl_pg, fl_es = e2["floor"]["postgres_select_1"], e2["floor"]["elasticsearch_GET_root"]
    w(f"Sàn của lời gọi (làm gì cũng phải trả): PostgreSQL `SELECT 1` p50 {ms(fl_pg['p50_ms'])} ms; Elasticsearch `GET /` qua HTTP p50 {ms(fl_es['p50_ms'])} ms "
      "(Python `requests`, một phần của phần chênh giữa `took` và độ trễ client).")
    w("")
    heavy_pg = e2["explain"]["pg/heavy/phở"]
    m = re.search(r"Execution Time: ([\d.]+) ms", heavy_pg)
    mt = re.search(r"Execution Time: ([\d.]+) ms", e2["explain"]["pg/typical/phở"])
    w(f"Máy chủ PostgreSQL (`EXPLAIN (ANALYZE, BUFFERS)` của câu trang, từ \"phở\"): người dùng nặng {m.group(1).replace('.', ',')} ms, "
      f"người dùng điển hình {mt.group(1).replace('.', ',')} ms. Kế hoạch là Bitmap Index Scan trên `uk_transactions_user_client_id` "
      "(chỉ khóa duy nhất này có `user_id` đứng đầu) rồi lọc `LIKE` từng dòng của người dùng đó: không có index nào giúp `LIKE '%…%'`, "
      f"nên thời gian tăng theo số giao dịch của một người dùng, không theo cả bảng. Cơ sở dữ liệu dùng collation `{e2['pg_collation']['datcollate']}` "
      "(mặc định của image compose), nên `LOWER()` hạ được chữ hoa có dấu.")
    w("")
    w(f"Elasticsearch: {th(e2['es_docs'])} document, {dec(e2['es_store_bytes'] / 1e6, 1)} MB, {e2['es_segments']} segment (không force-merge).")
    w("")
    w("Chất lượng kết quả. **Sự thật nền** = các giao dịch của người dùng có một trường văn bản chứa **mọi** từ của chuỗi như một từ nguyên vẹn "
      "sau khi hạ chữ thường và bỏ dấu (cùng cách `vi_folded` làm: lowercase + asciifolding, `đ` thành `d`). "
      "Hai engine được lấy **toàn bộ** tập kết quả (không chỉ trang đầu) rồi so với sự thật nền theo id: *dương tính giả* = có trong kết quả nhưng không "
      "thuộc sự thật nền; *bỏ sót* = thuộc sự thật nền nhưng không có trong kết quả. Người dùng nặng (người dùng 1):")
    w("")
    w("| Chuỗi | Sự thật nền | PG: số hit | PG: dương tính giả | PG: bỏ sót | ES: số hit | ES: dương tính giả | ES: bỏ sót |\n|---|---|---|---|---|---|---|---|")
    qh = e2["quality"]["heavy"]
    from_ = [("phở", "pho"), ("cà phê", "ca phe"), ("bún", "bun"), ("cơm tấm", "com tam"), ("bánh mì", "banh mi"),
             ("phúc long", "phuc long"), ("trà sữa", "tra sua"), ("tiền điện", "tien dien"), ("đổ xăng", "do xang"),
             ("siêu thị", "sieu thi")]
    for a_, b_ in from_:
        for q_ in (a_, b_):
            v = qh[q_]
            w(f"| {q_} | {th(v['truth'])} | {th(v['pg_total'])} | {th(v['pg_fp'])} | {th(v['pg_fn'])} | {th(v['es_total'])} | {th(v['es_fp'])} | {th(v['es_fn'])} |")
    w("")
    qt = e2["quality"]["typical"]
    w("Tổng gộp trên 20 người dùng điển hình (cộng các số đếm): " + "; ".join(
        f"\"{q_}\": sự thật nền {th(qt[q_]['truth'])}, PG {th(qt[q_]['pg_total'])} (giả {th(qt[q_]['pg_fp'])}, sót {th(qt[q_]['pg_fn'])}), "
        f"ES {th(qt[q_]['es_total'])} (giả {th(qt[q_]['es_fp'])}, sót {th(qt[q_]['es_fn'])})" for q_ in ("phở", "pho")) + ".")
    w("")
    w("Độ chính xác của 20 kết quả đầu (P@20 = tỉ lệ trong 20 dòng đầu có chứa từ khóa như một từ nguyên vẹn sau khi bỏ dấu), người dùng nặng, "
      "và tổng gộp của 20 người dùng điển hình (số dòng đúng / số dòng trả về):")
    w("")
    w("| Chuỗi | PG, nặng | ES, nặng | PG, điển hình | ES, điển hình |\n|---|---|---|---|---|")

    def p20(v, name):
        n = v[f"{name}_top20_n"]
        return f"{v[f'{name}_top20_hit']}/{n}" + (f" ({f(100 * v[f'{name}_top20_hit'] / n, 0)} %)" if n else "")

    for q_ in ("phở", "pho"):
        w(f"| {q_} | {p20(qh[q_], 'pg')} | {p20(qh[q_], 'es')} | {p20(qt[q_], 'pg')} | {p20(qt[q_], 'es')} |")
    w("")
    eq = e2["pair_sets_equal_heavy"]
    same_es = all(v["elasticsearch"] for v in eq.values())
    same_pg = [k for k, v in eq.items() if v["postgres"]]
    w(f"Cách gõ có dấu và không dấu: **tập kết quả** của Elasticsearch giống hệt nhau (so theo id) ở {sum(1 for v in eq.values() if v['elasticsearch'])}/{len(eq)} cặp "
      f"(\"pho\" và \"phở\" cùng {th(qh['pho']['es_total'])} giao dịch), vì `asciifolding` đưa cả hai về token `pho`. PostgreSQL chỉ giống nhau ở "
      f"{len(same_pg)}/{len(eq)} cặp: \"phở\" ra {th(qh['phở']['pg_total'])} nhưng \"pho\" chỉ {th(qh['pho']['pg_total'])}, vì `LIKE` so từng ký tự "
      "(\"pho\" chỉ khớp những giao dịch được gõ không dấu), nên PostgreSQL **bỏ sót** phần lớn sự thật nền ở mọi chuỗi có dấu/không dấu không khớp với cách ghi "
      "trong dữ liệu (cột \"PG: bỏ sót\"); đó là giới hạn đã ghi nhận của chế độ PostgreSQL.")
    w("")
    n_fp = [q_ for q_, v in qh.items() if v["es_fp"]]
    w("Dương tính giả của Elasticsearch: chỉ còn **tiền tố**. Nhánh chính xác dùng thêm trường `.autocomplete` (edge-ngram) nên \"pho\" khớp mọi từ bắt đầu bằng "
      "`pho`, ví dụ \"phòng\" trong \"Ăn trưa văn phòng\" (PostgreSQL cũng có dương tính giả cùng loại vì `LIKE '%pho%'` khớp \"phong\" khi viết không dấu). "
      f"Chuỗi có dương tính giả: {', '.join(n_fp) if n_fp else 'không có'} ({th(qh['pho']['es_fp'])} giao dịch ở \"pho\"). "
      "Nhánh mờ hiện chạy với `AUTO:4,7` và `prefix_length: 1` (commit 7f07caa, b35cd6e): từ dưới 4 ký tự không được sai, từ 4-6 ký tự sai tối đa 1 ký tự, từ 7 ký tự sai tối đa 2 **nhưng chữ cái đầu phải đúng**. "
      f"Vì vậy \"tiền điện\"/\"tien dien\" (trước khi có `prefix_length` là 6.224 hit so với sự thật nền 391, 5.833 dương tính giả vì \"tien\" và \"dien\" cách nhau đúng một ký tự) "
      f"nay trả {th(qh['tiền điện']['es_total'])} hit, đúng bằng sự thật nền {th(qh['tiền điện']['truth'])}. \"phố\" (\"Xúc Xích Phố Cổ\") **không** phải dương tính giả: nó khớp \"pho\" "
      "vì `asciifolding` (token chính xác), không phải do mờ, nên nó nằm trong sự thật nền. "
      f"Elasticsearch không bỏ sót dòng nào của sự thật nền ở cả {len(qh)} chuỗi." if all(v['es_fn'] == 0 for v in qh.values()) else "Elasticsearch có bỏ sót ở một số chuỗi (xem cột).")
    w("")
    w("Kiểm tra đúng/sai còn lại của NFR-04 (sai một ký tự vẫn ra, tiền tố \"phu\" ra \"Phúc Long\", không ra giao dịch người khác) nằm ở TC-32..TC-35 (test tích hợp), không lặp lại ở đây.")
    w("")
    nfr["NFR-03"] = ("ES p95 < 100 ms trên 100.000 giao dịch",
                     "; ".join(f"{s}: p95 {ms(sc[f'{s}/elasticsearch']['p95_ms'])} ms (took p95 {sc[f'{s}/elasticsearch']['took_ms']['p95']} ms)" for s in ("typical", "heavy")),
                     ok(all(es_pass.values())))
    nfr["NFR-04"] = ("\"pho\" tìm ra \"Phở\"; PG không bỏ dấu (giới hạn)",
                     f"ES: tập kết quả của \"pho\" = \"phở\" ({th(qh['pho']['es_total'])} giao dịch, bỏ sót {qh['pho']['es_fn']}, P@20 {p20(qh['pho'], 'es')}); "
                     f"PG: \"phở\" {th(qh['phở']['pg_total'])}, \"pho\" {th(qh['pho']['pg_total'])} (bỏ sót {th(qh['pho']['pg_fn'])})",
                     "Đạt phần đo ở đây (các phần còn lại ở TC-32..35)" if same_es and qh["pho"]["es_fn"] == 0 else "Không đạt")

    # ---------------------------------------------------------------- E3
    w("## E3. Bảng xếp hạng top 10: Redis ZSET và SQL `sumExpensesByUserBetween` (AP-11, AP-12; NFR-06)")
    w("")
    w(f"Tháng 2026-10: {th(e3['month_expense_rows'])} dòng chi tiêu của {th(e3['zset_members'])} người dùng; ZSET dựng bằng `ZADD` từ kết quả SQL như `writeRows`. "
      f"Kết quả top 10 của hai đường {'khớp nhau (cùng id, cùng điểm)' if e3['top10_agree'] else 'KHÔNG khớp'}. "
      "Đường ghi: script Lua `REFRESH_MEMBER_SCRIPT` của dịch vụ (EXISTS rồi ZADD điểm tuyệt đối) gọi bằng EVALSHA. "
      "Đường Redis của ứng dụng không chỉ là đọc ZSET: `topSpenders` còn gọi `userRepo.findAllById(ids)` để lấy tên 10 người dùng "
      "(đường SQL đã có tên nhờ phép nối), nên hàng so sánh công bằng với SQL là **ZREVRANGE + tra tên** (câu `select … from users where id in (10 id)` "
      "do Hibernate phát ra cho `findAllById`, lấy từ log show-sql).")
    w("")
    w(HEAD)
    s3 = e3["scenarios"]
    zr, sq = s3["redis_zrevrange_top10"], s3["pg_sum_expenses_by_user"]
    recs3 = f"{th(e3['month_expense_rows'])} dòng → {th(e3['zset_members'])} member"
    zn = s3["redis_zrevrange_plus_users_lookup"]
    w(row("Redis `ZREVRANGE 0 9 WITHSCORES` (chỉ đọc ZSET)", "NFR-06", recs3, zr, f"p95 < 5 ms → {ok(zr['p95_ms'] < 5)}"))
    w(row("Redis `ZREVRANGE` + tra tên (`findAllById`, 10 id): đường Redis đầy đủ của ứng dụng", "NFR-06", recs3, zn,
          f"p95 < 5 ms → {ok(zn['p95_ms'] < 5)}; nhanh hơn SQL {f(sq['p50_ms'] / zn['p50_ms'], 0)}× ở p50"))
    w(row("PostgreSQL `sumExpensesByUserBetween` (toàn bộ nhóm, đã gồm tên)", "–", f"{th(e3['month_expense_rows'])} dòng", sq,
          f"– (gấp {f(sq['p50_ms'] / zr['p50_ms'], 0)}× ZREVRANGE trần, gấp {f(sq['p50_ms'] / zn['p50_ms'], 0)}× đường Redis đầy đủ ở p50)"))
    lua = s3["redis_lua_refresh_member"]
    w(row("Redis Lua refresh một member (EVALSHA, ZADD tuyệt đối)", "–", recs3, lua, "– (đường ghi)"))
    rb = s3["redis_rebuild_zadd_all_members"]
    w(row("Redis dựng lại (DEL + ZADD mọi member)", "–", recs3, rb, "– (chỉ phần Redis của một lần miss)"))
    w("")
    w(HEAD_MAX)
    for label, s in (("Redis ZREVRANGE", zr), ("Redis ZREVRANGE + tra tên", zn), ("PostgreSQL SQL", sq), ("Redis Lua refresh", lua), ("Redis rebuild", rb)):
        w(maxrow(label, s))
    w("")
    fr, fp = e3["floor"]["redis_ping"], e3["floor"]["postgres_select_1"]
    mm = re.search(r"Execution Time: ([\d.]+) ms", e3["explain"]["pg"])
    w(f"Máy chủ: Redis `usec_per_call` của ZREVRANGE = {f(zr['server_usec_per_call'], 2)} µs, của EVALSHA = {f(lua['server_usec_per_call_evalsha'], 2)} µs "
      f"(`INFO commandstats`); PostgreSQL `EXPLAIN (ANALYZE)` = {mm.group(1).replace('.', ',')} ms (Seq Scan `transactions` + HashAggregate). "
      f"Sàn: Redis `PING` p50 {ms(fr['p50_ms'])} ms, PostgreSQL `SELECT 1` p50 {ms(fp['p50_ms'])} ms.")
    w("")
    nfr["NFR-06"] = ("Top 10 p95 < 5 ms, so với SQL",
                     f"Redis ZREVRANGE p95 {ms(zr['p95_ms'])} ms; Redis + tra tên p95 {ms(zn['p95_ms'])} ms (p50 {ms(zn['p50_ms'])}); SQL p50 {ms(sq['p50_ms'])} ms "
                     f"({f(sq['p50_ms'] / zn['p50_ms'], 0)}× chậm hơn đường Redis đầy đủ)",
                     ok(zr["p95_ms"] < 5 and zn["p95_ms"] < 5 and e3["top10_agree"]))

    # ---------------------------------------------------------------- E4
    w("## E4. Cache và không cache ở tầng dữ liệu (AP-07, AP-08; NFR-01, NFR-02)")
    w("")
    w("\"Trúng cache\" = Redis `GET` của JSON đã cache (và một dòng `GET` + `json.loads`). \"Trượt cache\" = các câu SQL mà Hibernate phát ra "
      "khi `UserStatisticsService.dashboardOf` / `popularVendorsOf` và `AdminStatisticsService.getDashboardSummary` chạy "
      "(3, 1 và 5 câu, lấy từ log show-sql) cộng việc dựng kết quả; \"trượt đầy đủ\" thêm `json.dumps` và `SET`. "
      f"Dashboard/popular vendors quay vòng qua {e4['cache_users']} người dùng; PostgreSQL ấm (toàn bộ dữ liệu nằm trong bộ nhớ đệm của PG). "
      "Đường trượt của ứng dụng thật còn thêm một câu tra khóa chính (`select … from receipts where id = ?`) cho hóa đơn của giao dịch lớn nhất "
      "(quan hệ `receipt` là lazy và `TransactionResponseDto.from` đọc nó) mỗi khi giao dịch đó có hóa đơn mà không nằm trong 5 giao dịch gần nhất hoặc "
      "danh sách có mã giảm giá; câu đó không có trong log vì giao dịch lớn nhất của dữ liệu bắt log cũng là giao dịch mới nhất, nên hóa đơn của nó đã được "
      "nạp bởi câu liền trước. Với dữ liệu thật câu này xuất hiện ở đa số người dùng, nên thời gian "
      "trượt ở đây là cận dưới và hệ số tăng tốc là thận trọng.")
    w("")
    w(HEAD)
    s4 = e4["scenarios"]
    nm = {"dashboard": "Dashboard người dùng", "popular_vendors": "Quán phổ biến", "admin_summary": "Tổng quan quản trị"}
    stmts = e4["pg_statements"]
    nfr1_ok, nfr2_ok = [], []
    for k in ("dashboard", "popular_vendors", "admin_summary"):
        g, gl, sql_, mc = s4[f"{k}/redis_get"], s4[f"{k}/redis_get_json_loads"], s4[f"{k}/sql"], s4[f"{k}/miss_complete"]
        size = e4["payload_bytes"][k]["mean"]
        recs = f"JSON ~{f(size / 1024, 1)} KB"
        sp1 = sql_["p50_ms"] / g["p50_ms"]
        nfr1_ok.append(g["p95_ms"] < 5)
        nfr2_ok.append(sp1 >= 5)
        w(row(f"{nm[k]}: Redis GET", "NFR-01", recs, g, f"p95 < 5 ms → {ok(g['p95_ms'] < 5)}"))
        w(row(f"{nm[k]}: Redis GET + json.loads", "NFR-01", recs, gl, f"p95 < 5 ms → {ok(gl['p95_ms'] < 5)}"))
        w(row(f"{nm[k]}: SQL ({stmts[k]} câu)", "NFR-02", "100.000 giao dịch", sql_, f"GET nhanh hơn {f(sp1, 0)}× ở p50 (≥ 5×) → {ok(sp1 >= 5)}"))
        w(row(f"{nm[k]}: trượt đầy đủ (SQL + dumps + SET)", "–", "100.000 giao dịch", mc,
              f"– (GET + loads nhanh hơn {f(mc['p50_ms'] / gl['p50_ms'], 0)}× ở p50)"))
    w("")
    w(HEAD_MAX)
    for k in ("dashboard", "popular_vendors", "admin_summary"):
        for lab, key in (("Redis GET", "redis_get"), ("GET + loads", "redis_get_json_loads"), ("SQL", "sql"), ("trượt đầy đủ", "miss_complete")):
            w(maxrow(f"{nm[k]}: {lab}", s4[f"{k}/{key}"]))
    w("")
    w("Máy chủ: `EXPLAIN (ANALYZE)` của từng câu SQL (người dùng đầu của danh sách, ms): " + "; ".join(
        f"{k} {exec_ms(v)}" for k, v in e4["explain"].items()) +
      f". Redis `usec_per_call` của GET = {f(s4['dashboard/redis_get']['server_usec_per_call'], 2)} µs.")
    w("")
    fr, fp = e4["floor"]["redis_ping"], e4["floor"]["postgres_select_1"]
    w(f"Sàn: Redis `PING` p50 {ms(fr['p50_ms'])} ms; PostgreSQL `SELECT 1` p50 {ms(fp['p50_ms'])} ms. "
      "Câu SQL của dashboard người dùng chạy trong khoảng nửa mili-giây ở máy chủ vì mỗi người dùng chỉ ~80 dòng và đi qua "
      "`uk_transactions_user_client_id`; các câu tổng quan quản trị quét toàn bảng (Seq Scan) nên đắt hơn nhiều và là nơi cache có lợi nhất.")
    w("")
    nfr["NFR-01"] = ("Redis GET (AP-07/08) p95 < 5 ms", "; ".join(f"{nm[k]} p95 {ms(s4[f'{k}/redis_get']['p95_ms'])} ms" for k in nm), ok(all(nfr1_ok)))
    nfr["NFR-02"] = ("GET nhanh hơn trượt ≥ 5× ở p50", "; ".join(f"{nm[k]} {f(s4[f'{k}/sql']['p50_ms'] / s4[f'{k}/redis_get']['p50_ms'], 0)}×" for k in nm), ok(all(nfr2_ok)))

    # ---------------------------------------------------------------- E5
    w("## E5. `$lookup` (tham chiếu) và bản sao nhúng (AP-37; Q-13)")
    w("")
    w("Q-13 giữ nguyên (`$match` → `$lookup` `ocr_logs` theo `transactionId` (index unique) → `$unwind` → `$project` → `$sort` → `$limit 4`). "
      "Bản nhúng: mỗi feedback mang sẵn `rawJsonData`, `modelVersion`, `averageConfidenceScore` của log, cùng các index của `ocr_feedbacks`, nên chỗ "
      "khác duy nhất là phép nối; mọi biến thể trả cùng kết quả (kiểm trước khi đo, 50 lần mỗi biến thể). "
      f"A = đúng như Q-13 (`fieldError = seller_name`, {th(e5['seller_name_feedbacks'])} feedback khớp, không index nào phục vụ điều kiện này); "
      "B = thêm `userId` (index `userId`), cách quản trị viên xem chi tiết một người dùng. "
      "Vì Q-13 chỉ sắp xếp và cắt 4 dòng **sau** phép nối, hai hàng \"sắp lại\" được thêm: `$match → $sort → $limit → $lookup → $unwind → $project` "
      "(cùng kết quả, vì `transactionId` là duy nhất trong `ocr_logs` và mọi feedback đều có log: đã kiểm bằng so sánh kết quả) và cùng thứ tự đó trên bản nhúng "
      "(`$project` sau `$limit`).")
    w("")
    w(HEAD)
    s5 = e5["scenarios"]
    recs5 = f"{th(e5['counts']['ocr_feedbacks'])} feedback / {th(e5['counts']['ocr_logs'])} log"
    for v, lab in (("A", "A: toàn bộ `seller_name`"), ("B", "B: theo người dùng")):
        r_, rr_, e_, er_ = s5[f"{v}/reference"], s5[f"{v}/reference_reordered"], s5[f"{v}/embedded"], s5[f"{v}/embedded_reordered"]
        w(row(f"{lab}: `$lookup` (Q-13 nguyên bản)", "–", recs5, r_, "–"))
        w(row(f"{lab}: Q-13 sắp lại (`$sort`/`$limit` trước `$lookup`)", "–", recs5, rr_, f"– (nhanh hơn Q-13 nguyên bản {f(r_['p50_ms'] / rr_['p50_ms'], 1)}× ở p50)"))
        w(row(f"{lab}: bản sao nhúng (cùng thứ tự với Q-13)", "–", recs5, e_, f"– (nhanh hơn Q-13 nguyên bản {f(r_['p50_ms'] / e_['p50_ms'], 1)}× ở p50)"))
        w(row(f"{lab}: bản sao nhúng, `$sort`/`$limit` trước `$project`", "–", recs5, er_, f"– ({f(rr_['p50_ms'] / er_['p50_ms'], 2)}× so với Q-13 sắp lại, p50)"))
    w("")
    w("Cách đọc: **biến thể A đo cái giá của một `$lookup` đặt muộn** (một phép tra cho mỗi feedback khớp, "
      f"{th(e5['seller_name_feedbacks'])} lần, rồi mới sắp xếp và lấy 4 dòng), không phải cái giá của việc tham chiếu so với nhúng: "
      "khi `$sort`/`$limit` chạy trước thì `$lookup` chỉ còn 4 lần và cả hai đường cùng xuống dưới 1 ms (bản nhúng sắp lại chỉ còn nhanh hơn "
      f"{f(s5['A/reference_reordered']['p50_ms'] / s5['A/embedded_reordered']['p50_ms'], 2)}× ở p50). **Biến thể B (theo người dùng, khoảng 15 feedback) là số so sánh "
      f"công bằng giữa tham chiếu và nhúng**: nhúng nhanh hơn {f(s5['B/reference']['p50_ms'] / s5['B/embedded']['p50_ms'], 1)}× ở p50.")
    w("")
    w(HEAD_MAX)
    for v in ("A", "B"):
        w(maxrow(f"{v}: `$lookup` nguyên bản", s5[f"{v}/reference"]))
        w(maxrow(f"{v}: Q-13 sắp lại", s5[f"{v}/reference_reordered"]))
        w(maxrow(f"{v}: nhúng (cùng thứ tự Q-13)", s5[f"{v}/embedded"]))
        w(maxrow(f"{v}: nhúng sắp lại", s5[f"{v}/embedded_reordered"]))
    w("")
    w("Máy chủ (`explain(\"executionStats\")` của pipeline):")
    w("")
    w("| Biến thể | docs examined (từng giai đoạn) | keys examined | index dùng | executionTimeMillis |\n|---|---|---|---|---|")
    for v in ("A", "B"):
        for lab, key in (("`$lookup` nguyên bản", "reference"), ("Q-13 sắp lại", "reference_reordered"), ("nhúng", "embedded"), ("nhúng sắp lại", "embedded_reordered")):
            ex = e5["explain"][f"{v}/{key}"]
            w(f"| {v} {lab} | {ex['totalDocsExamined']} | {ex['totalKeysExamined']} | {ex['indexesUsed'] or '–'} | {ex['executionTimeMillis']} |")
    w("")
    sz = e5["sizes"]
    dup = sz["ocr_feedbacks_embedded"]["size"] - sz["ocr_feedbacks"]["size"]
    w(f"Giá của bản nhúng: `ocr_feedbacks` {dec(sz['ocr_feedbacks']['size'] / 1e6, 1)} MB ({sz['ocr_feedbacks']['avgObjSize']} B/document) → "
      f"`ocr_feedbacks_embedded` {dec(sz['ocr_feedbacks_embedded']['size'] / 1e6, 1)} MB ({sz['ocr_feedbacks_embedded']['avgObjSize']} B/document), "
      f"tức thêm {dec(dup / 1e6, 1)} MB dữ liệu trùng lặp (mỗi log chép vào mọi feedback của nó, và phải cập nhật ở nhiều nơi nếu log đổi; "
      "ứng dụng không sửa log sau khi ghi nên rủi ro này thấp).")
    w("")

    # ---------------------------------------------------------------- summary
    w("## Tổng hợp NFR (mục tiêu giữ nguyên như đã đóng băng)")
    w("")
    w("| NFR | Mục tiêu | Số đo | Kết luận |\n|---|---|---|---|")
    for k in ("NFR-01", "NFR-02", "NFR-03", "NFR-04", "NFR-05", "NFR-06"):
        t, m_, v = nfr[k]
        w(f"| {k} | {t} | {m_} | {v} |")
    w("")
    task4 = os.path.join(RAW, "task4.md")
    if os.path.exists(task4):
        w("E6 độ trễ realtime (NFR-15), sao lưu/khôi phục (NFR-13) và `docker stats` (NFR-14) do Task 4 đo, xem các mục ngay "
          "sau (chép nguyên từ `bench_raw/task4.md`). JMeter ở mức ứng dụng không được chạy (tùy chọn, do người dùng chạy).")
        w("")
        with open(task4, encoding="utf-8") as fh:
            w(fh.read().rstrip("\n"))
    else:
        w("Chưa đo ở đây (thuộc Task 4): E6 độ trễ realtime (NFR-15), sao lưu/khôi phục (NFR-13), `docker stats` (NFR-14). "
          "JMeter ở mức ứng dụng không được chạy trong task này (tùy chọn, do người dùng chạy).")
    w("")
    w("## Giới hạn của phép đo (đọc trước khi trích số)")
    w("")
    for line in (
        "Đây là độ trễ **tầng dữ liệu** từ một client Python trong cùng mạng docker: không gồm Spring, JPA, Jackson, JWT hay mạng thật; "
        "phần Python (driver, `requests`, `json`) cộng vài chục đến vài trăm micro-giây vào mọi dòng, giống nhau cho các bên so sánh.",
        "Một máy, 12 luồng, mọi container cùng chia CPU; các thí nghiệm chạy tuần tự, mỗi thí nghiệm chỉ bật các container nó cần. Không có tải song song: "
        "cột Tải luôn là \"1 luồng\", nên ops/s là tốc độ một luồng đạt được chứ không phải sức chứa của hệ thống.",
        "Dữ liệu tổng hợp, phân bố do `gen_data.py` đặt ra (người dùng nặng 20 %, văn bản mẫu ngắn, 10 % không dấu): số tuyệt đối sẽ khác với dữ liệu thật; "
        "tỉ lệ giữa các bên và hình dạng kế hoạch truy vấn mới là điều đáng tin.",
        "Bộ nhớ đệm đã ấm (200 lần khởi động, dữ liệu nằm gọn trong RAM của PostgreSQL, WiredTiger cache 0,25 GB và Elasticsearch heap 512 MB). "
        "Số đo \"nguội\" (đĩa) không được đo.",
        "Elasticsearch chạy với bảo mật tắt (mạng riêng) và index không force-merge; PostgreSQL dùng cấu hình mặc định của image (compose cũng vậy).",
        "Thân yêu cầu Elasticsearch dựng lại từng trường của `ElasticsearchTransactionSearchEngine.hits`; không bắt được byte-by-byte yêu cầu mà Spring Data gửi.",
        "psycopg gửi số nguyên nhỏ dưới dạng smallint (JDBC gửi BIGINT); kế hoạch (`EXPLAIN`) vẫn dùng đúng index như nhau.",
    ):
        w(f"- {line}")
    w("")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
