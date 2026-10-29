#!/usr/bin/env python3
"""Automated screenshots of the NoSQL report (Task 4): Kibana, Elasticvue, RedisInsight and terminal captures.

Runs against the demo stack of scripts/nosql/demo-stack.sh (start it first, with the same NOSQL_DEMO_* variables):

    python3 docs/nosql/build/capture_tools.py terminal-setup       S-01 (sets the kibana_system password via the API)
    python3 docs/nosql/build/capture_tools.py kibana               S-02..S-04, S-07..S-09, S-49..S-59
    python3 docs/nosql/build/capture_tools.py kibana-extra         S-19, S-05 (S-05 needs no giao_dich_csv data view yet)
    python3 docs/nosql/build/capture_tools.py kibana-csv           S-06
    python3 docs/nosql/build/capture_tools.py elasticvue           S-10..S-13
    python3 docs/nosql/build/capture_tools.py redisinsight         S-18, S-36..S-48
    python3 docs/nosql/build/capture_tools.py redisinsight-pubsub  S-60
    python3 docs/nosql/build/capture_tools.py terminal-backup      S-61..S-64, S-86, S-87 (and NFR-13 timings)
    python3 docs/nosql/build/capture_tools.py measure-tools        S-14 (docker stats + first page load of Kibana/Elasticvue)
    python3 docs/nosql/build/capture_tools.py terminal-e6          S-88 (from docs/nosql/bench_raw/E6.txt)
    NOSQL_DEMO_ES_MEMORY=1G ... docker-stats                       S-89 (NFR-14, limits of docker-compose.yml)

Needs Python Playwright (pip install playwright pillow && python -m playwright install chromium) and Docker.
Every screenshot is a real page or a real command output: terminal images are rendered from the exact command line and
the output it printed (passwords that a command prints are masked, nothing else is changed). The PNGs go to
docs/nosql/screenshots/S-xx.png (1600 px wide) and replace the grey placeholders of make_placeholder_png.py.
"""
import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
SHOTS = HERE.parent / "screenshots"
RAW = HERE.parent / "bench_raw"

E = os.environ.get
MONGO_PW = E("NOSQL_DEMO_MONGO_PASSWORD", "demo-mongo-pass")
ELASTIC_PW = E("NOSQL_DEMO_ELASTIC_PASSWORD", "demo-elastic-pass")
KIBANA = f"http://localhost:{E('NOSQL_DEMO_KIBANA_PORT', '5602')}"
ELASTICVUE = f"http://localhost:{E('NOSQL_DEMO_ELASTICVUE_PORT', '8081')}"
REDISINSIGHT = f"http://localhost:{E('NOSQL_DEMO_REDISINSIGHT_PORT', '5541')}"
WIDTH = 1600

# --------------------------------------------------------------------------------------------- terminal images
MONO = "/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf"  # full Vietnamese coverage
MONO_BOLD = "/usr/share/fonts/truetype/noto/NotoSansMono-Bold.ttf"
BG, FG, PROMPT, NOTE, TITLE_BG = (30, 30, 30), (220, 220, 220), (110, 210, 120), (120, 170, 230), (60, 60, 60)


def render_terminal(blocks, out, title, font_size=17):
    """blocks: list of (kind, text) with kind in {"cmd", "out", "note"}; long lines are wrapped, nothing is dropped."""
    font = ImageFont.truetype(MONO, font_size)
    bold = ImageFont.truetype(MONO_BOLD, font_size)
    cw = font.getlength("M")
    lh = int(font_size * 1.35)
    cols = int((WIDTH - 40) // cw)
    lines = []
    for kind, text in blocks:
        for raw in text.rstrip("\n").split("\n"):
            raw = raw.replace("\t", "    ")
            s = "$ " + raw if kind == "cmd" else raw
            while True:
                lines.append((kind, s[:cols]))
                s = s[cols:]
                if not s:
                    break
    height = 44 + 20 + lh * len(lines) + 20
    im = Image.new("RGB", (WIDTH, max(height, 300)), BG)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, WIDTH, 40], fill=TITLE_BG)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse([14 + i * 24, 13, 28 + i * 24, 27], fill=c)
    d.text((100, 10), title, font=bold, fill=(235, 235, 235))
    y = 60
    for kind, s in lines:
        color = PROMPT if kind == "cmd" else NOTE if kind == "note" else FG
        d.text((20, y), s, font=bold if kind == "cmd" else font, fill=color)
        y += lh
    im.save(out)
    return out


def sh(cmd, timeout=600):
    """Runs cmd with bash; returns stdout+stderr as text."""
    p = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=timeout)
    return (p.stdout + p.stderr).rstrip("\n")


class Term:
    def __init__(self, title):
        self.title = title
        self.blocks = []

    def run(self, cmd, shown=None, mask=None, keep=None):
        out = sh(cmd)
        if mask:
            for pattern, repl in mask:
                out = re.sub(pattern, repl, out)
        if keep:
            out = keep(out)
        self.blocks.append(("cmd", shown or cmd))
        if out:
            self.blocks.append(("out", out))
        return out

    def run_argv(self, argv, shown):
        """Runs argv without a shell (for arguments full of quotes); shown is the equivalent command line."""
        p = subprocess.run(argv, capture_output=True, text=True)
        out = (p.stdout + p.stderr).rstrip("\n")
        self.blocks.append(("cmd", shown))
        if out:
            self.blocks.append(("out", out))
        return out

    def note(self, text):
        self.blocks.append(("note", text))

    def save(self, sid, font_size=17):
        path = SHOTS / f"{sid}.png"
        render_terminal(self.blocks, path, self.title, font_size)
        print("wrote", path)
        return path


def es(path, method="GET", body=None, extra=""):
    data = f" -H 'Content-Type: application/json' -d '{body}'" if body else ""
    return (f"docker exec nosql-demo-es sh -c \"curl -s -u elastic:\\$ELASTIC_PASSWORD -X {method} "
            f"'localhost:9200/{path}'{data.replace(chr(34), chr(92) + chr(34))}{extra}\"")


# --------------------------------------------------------------------------------------------- S-01
def terminal_setup(_):
    t = Term("S-01 · Elasticsearch healthy + mật khẩu kibana_system (stack demo nosql-demo, bảo mật bật)")
    t.run("docker ps --filter name=nosql-demo-es --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}'")
    t.run(es("_cluster/health?pretty&filter_path=cluster_name,status,number_of_nodes,active_shards"))
    port = E("NOSQL_DEMO_ES_PORT", "9201")
    t.run(f"curl -s -w '  (HTTP %{{http_code}}, không đăng nhập)\\n' http://127.0.0.1:{port}/")
    kib_pw = E("NOSQL_DEMO_KIBANA_PASSWORD", "demo-kibana-pass")
    api = ("docker exec nosql-demo-es sh -c \"curl -s -u elastic:\\$ELASTIC_PASSWORD -X POST "
           "localhost:9200/_security/user/kibana_system/_password -H 'Content-Type: application/json' "
           "-d '{\\\"password\\\":\\\"%s\\\"}'\"")
    t.run(api % kib_pw + "; echo", shown=api % "***")
    auth = ("docker exec nosql-demo-es curl -s -u kibana_system:%s "
            "'localhost:9200/_security/_authenticate?filter_path=username,authentication_realm.name'")
    t.run(auth % kib_pw + "; echo", shown=auth % "***")
    t.run("docker ps --filter name=nosql-demo-kibana --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}'")
    st = ("docker exec nosql-demo-kibana curl -s -u elastic:%s localhost:5601/api/status "
          "| grep -o '\"overall\":{\"level\":\"[a-z]*\"' | head -1")
    t.run(st % ELASTIC_PW, shown=st % "***")
    t.save("S-01")


# --------------------------------------------------------------------------------------------- browser helpers
def browser(p, height=900):
    b = p.chromium.launch()
    ctx = b.new_context(viewport={"width": WIDTH, "height": height}, locale="en-US")
    return b, ctx


def shot(page, sid, full=False, clip=None):
    path = SHOTS / f"{sid}.png"
    page.screenshot(path=str(path), full_page=full, clip=clip)
    print("wrote", path)


def settle(page, seconds=2.0):
    try:
        page.wait_for_load_state("networkidle", timeout=20000)
    except Exception:
        pass
    time.sleep(seconds)


# --------------------------------------------------------------------------------------------- Kibana
def wait_kibana(limit=300):
    for _ in range(limit // 3):
        if sh(f"curl -s -o /dev/null -w '%{{http_code}}' {KIBANA}/login") == "200":
            return
        time.sleep(3)
    sys.exit("Kibana does not answer")


def kibana_login(page):
    wait_kibana()
    page.goto(KIBANA + "/login")
    page.wait_for_selector("input[name=username]", timeout=120000)
    page.fill("input[name=username]", "elastic")
    page.fill("input[name=password]", ELASTIC_PW)
    page.click("button[type=submit]")
    page.wait_for_url("**/app/**", timeout=90000)
    settle(page, 3)


def kbn_api(method, path, body=None):
    """Kibana HTTP API through curl inside the Kibana container (port not needed on the host)."""
    data = f" -H 'Content-Type: application/json' -d '{json.dumps(body)}'" if body is not None else ""
    return sh(f"docker exec nosql-demo-kibana curl -s -u elastic:{ELASTIC_PW} -H 'kbn-xsrf: true' -X {method} "
              f"'localhost:5601{path}'{data}")


def es_api(method, path, body=None):
    data = f" -H 'Content-Type: application/json' -d '{json.dumps(body)}'" if body is not None else ""
    return sh(f"docker exec nosql-demo-es curl -s -u elastic:{ELASTIC_PW} -X {method} 'localhost:9200/{path}'{data}")


def console_run(page, text, wait=4.0):
    """Puts text in the Dev Tools Console request editor, selects all and sends it."""
    page.evaluate("""(text) => {
        const el = document.querySelector('[data-test-subj=request-editor] .ace_editor') ||
                   document.querySelector('#ConAppEditor');
        const ed = el.env.editor;
        ed.setValue(text, -1);
        ed.selectAll();
    }""", text)
    page.click("[data-test-subj=sendRequestButton]")
    time.sleep(wait)
    page.evaluate("""() => {
        const el = document.querySelector('[data-test-subj=request-editor] .ace_editor') ||
                   document.querySelector('#ConAppEditor');
        const ed = el.env.editor;
        ed.clearSelection(); ed.gotoLine(1); ed.scrollToLine(0);
        const r = document.querySelector('[data-test-subj=response-editor] .ace_editor');
        if (r && r.env) { r.env.editor.gotoLine(1); r.env.editor.scrollToLine(0); }
        document.activeElement && document.activeElement.blur();
    }""")
    # The "Click to send request" hover tip of the action button would cover the editor.
    page.add_style_tag(content=".euiToolTipPopover { display: none !important; }")
    page.mouse.move(5, 890)
    time.sleep(0.5)


def open_console(page):
    page.goto(KIBANA + "/app/dev_tools#/console")
    settle(page, 3)
    for sel in ("[data-test-subj=help-close-button]", "button:has-text('Dismiss')"):
        try:
            if page.locator(sel).first.is_visible():
                page.locator(sel).first.click()
                time.sleep(1)
        except Exception:
            pass


def devtools_blocks():
    """{Q-30: text, ...} from scripts/nosql/elasticsearch/kibana-devtools.txt (comments kept, they explain the query)."""
    text = (REPO / "scripts/nosql/elasticsearch/kibana-devtools.txt").read_text(encoding="utf8")
    parts = re.split(r"\n# -{20,}\n(?=# Q-\d\d)", text)
    blocks = {}
    for part in parts[1:]:
        qid = re.match(r"# (Q-\d\d)", part).group(1)
        body = re.sub(r"\n# -{20,}\n", "\n", part).strip()
        blocks[qid] = body
    return blocks


def kibana(_):
    from playwright.sync_api import sync_playwright

    # Real objects shown on the pages (created through the APIs, then looked at in the UI).
    es_api("PUT", "_snapshot/demo_repo", {"type": "fs", "settings": {"location": "/usr/share/elasticsearch/snapshots"}})
    es_api("DELETE", "_snapshot/demo_repo/snap-2026-10-28")
    es_api("PUT", "_snapshot/demo_repo/snap-2026-10-28?wait_for_completion=true",
           {"indices": "transactions", "include_global_state": False})
    es_api("PUT", "_security/role/transactions_read",
           {"indices": [{"names": ["transactions"], "privileges": ["read", "view_index_metadata"]}]})
    es_api("PUT", "_security/user/tien_viewer",
           {"password": "demo-viewer-pass", "roles": ["transactions_read", "kibana_admin"],
            "full_name": "Người xem (chỉ đọc transactions)"})
    with sync_playwright() as p:
        b, ctx = browser(p)
        page = ctx.new_page()
        kibana_login(page)
        # S-02: Home after the first login
        for label in ("Explore on my own",):
            if page.locator(f"text={label}").count():
                page.locator(f"text={label}").first.click()
                settle(page, 4)
        page.goto(KIBANA + "/app/home#/")
        settle(page, 4)
        shot(page, "S-02")
        # S-03: Index Management -> transactions -> mappings/settings
        page.goto(KIBANA + "/app/management/data/index_management/indices")
        settle(page, 3)
        page.locator("text=transactions").first.click()
        settle(page, 3)
        page.get_by_role("tab", name="Mappings").click()
        settle(page, 3)
        shot(page, "S-03")
        # S-09: the Statistics tab of the same index (no Stack Monitoring: Metricbeat is not installed)
        page.get_by_role("tab", name="Statistics").click()
        settle(page, 3)
        shot(page, "S-09")
        # S-07: Snapshot and Restore
        page.goto(KIBANA + "/app/management/data/snapshot_restore/snapshots")
        settle(page, 4)
        shot(page, "S-07")
        # S-08: role
        page.goto(KIBANA + "/app/management/security/roles/edit/transactions_read")
        settle(page, 4)
        shot(page, "S-08")
        # Dev Tools: S-04, S-19, S-49..S-59
        open_console(page)
        blocks = devtools_blocks()
        for n in range(30, 41):
            console_run(page, blocks[f"Q-{n}"])
            shot(page, f"S-{n + 19}")
        console_run(page, "# Dev Tools: chạy truy vấn (tìm \"pho\" trong ghi chú/tên quán của user 1)\n"
                          "GET transactions/_search\n{\n  \"size\": 3,\n  \"query\": { \"bool\": {\n"
                          "    \"filter\": [ { \"term\": { \"userId\": 1 } } ],\n"
                          "    \"must\": [ { \"match\": { \"vendorName\": \"pho\" } } ]\n  } },\n"
                          "  \"_source\": [ \"vendorName\", \"note\", \"amount\" ]\n}")
        shot(page, "S-04")
        b.close()


def demo_csv(path):
    """The 47 demo transactions of transactions-bulk.ndjson as CSV (input of the Kibana Upload file demo)."""
    import csv
    rows = []
    for line in (REPO / "scripts/nosql/elasticsearch/transactions-bulk.ndjson").read_text(encoding="utf8").splitlines():
        doc = json.loads(line)
        if "index" not in doc:
            rows.append(doc)
    cols = ["transactionDate", "userId", "vendorName", "note", "categoryName", "amount", "expense", "paymentMethod",
            "location", "receiptStatus"]
    with open(path, "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    return path


def kibana_extra(_):
    """S-19 (create index + bulk in Dev Tools), S-05 (Upload file), S-06 (Discover -> CSV report)."""
    from playwright.sync_api import sync_playwright
    settings = (REPO / "core-backend/src/main/resources/elasticsearch/transactions-settings.json").read_text(encoding="utf8")
    mapping = (REPO / "core-backend/src/main/resources/elasticsearch/transactions-mapping.json").read_text(encoding="utf8")
    bulk = (REPO / "scripts/nosql/elasticsearch/transactions-bulk.ndjson").read_text(encoding="utf8").strip()
    import tempfile
    csv_path = demo_csv(Path(tempfile.mkdtemp()) / "giao_dich_mau.csv")
    with sync_playwright() as p:
        b, ctx = browser(p)
        page = ctx.new_page()
        kibana_login(page)
        # S-19
        open_console(page)
        console_run(page, "# Tạo index transactions từ settings + mapping thật của app, nạp 47 document mẫu, đếm lại\n"
                          "DELETE transactions\n\nPUT transactions\n{\n\"settings\": " + settings.strip() +
                          ",\n\"mappings\": " + mapping.strip() + "\n}\n\n"
                          "POST _bulk?refresh=true&filter_path=took,errors\n" + bulk + "\n\n"
                          "GET transactions/_count", wait=6)
        page.mouse.move(5, 890)
        shot(page, "S-19")
        # S-05: Upload file (Data Visualizer) -> new index giao_dich_csv
        es_api("DELETE", "giao_dich_csv?ignore_unavailable=true")
        page.goto(KIBANA + "/app/home#/tutorial_directory/fileDataViz")
        settle(page, 4)
        page.set_input_files("input[type=file]", str(csv_path))
        settle(page, 6)
        page.get_by_role("button", name="Import").first.click()
        settle(page, 3)
        page.get_by_placeholder("Index name").first.fill("giao_dich_csv")
        time.sleep(1)
        page.get_by_role("button", name="Import").last.click()
        page.wait_for_selector("text=Import complete", timeout=120000)
        settle(page, 3)
        shot(page, "S-05")
        b.close()


def kibana_csv(_):
    """S-06: data view on transactions, Discover, Share -> CSV Reports -> Generate csv, then the Reporting list."""
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b, ctx = browser(p)
        page = ctx.new_page()
        kibana_login(page)
        kbn_api("POST", "/api/data_views/data_view", {"data_view": {
            "title": "transactions", "name": "transactions", "timeFieldName": "transactionDate", "id": "transactions-dv"}})
        page.goto(KIBANA + "/app/discover#/?_g=(time:(from:'2026-08-01T00:00:00.000Z',to:'2026-11-01T00:00:00.000Z'))"
                           "&_a=(index:'transactions-dv')")
        settle(page, 6)
        page.click("[data-test-subj=shareTopNavButton]")
        time.sleep(1.5)
        page.get_by_text("CSV Reports").first.click()
        time.sleep(1.5)
        shot(page, "S-06-share")
        page.get_by_role("button", name=re.compile("Generate csv", re.I)).first.click()
        time.sleep(3)
        page.goto(KIBANA + "/app/management/insightsAndAlerting/reporting")
        for _ in range(20):
            settle(page, 3)
            if page.locator("text=Done").count() or page.locator("text=Completed").count():
                break
            page.reload()
        shot(page, "S-06")
        b.close()
    # One figure: the Share -> CSV Reports panel (top) and the finished report in Stack Management -> Reporting.
    share = SHOTS / "S-06-share.png"
    stack_images([share, SHOTS / "S-06.png"], SHOTS / "S-06.png")
    share.unlink()


def console_requests(block):
    """[(method, path, body or None)] of a Dev Tools block (comment lines dropped)."""
    reqs, cur = [], None
    for line in block.split("\n"):
        if line.startswith("#"):
            continue
        m = re.match(r"^(GET|POST|PUT|DELETE) (\S+)$", line)
        if m:
            cur = [m.group(1), m.group(2), []]
            reqs.append(cur)
        elif cur is not None and line.strip():
            cur[2].append(line)
    return [(m_, p_, "\n".join(b_) or None) for m_, p_, b_ in reqs]


def run_es_queries():
    """Q-30..Q-40 against the demo Elasticsearch (curl inside its container); returns {Q-xx: [HTTP codes]}."""
    done = {}
    for qid, block in devtools_blocks().items():
        codes = []
        for method, path, body in console_requests(block):
            data = ""
            if body:
                data = " -H 'Content-Type: application/json' --data-binary @-"
            p = subprocess.run(["bash", "-c", f"docker exec -i nosql-demo-es curl -s -o /dev/null -w '%{{http_code}}' "
                                              f"-u elastic:{ELASTIC_PW} -X {method} 'localhost:9200/{path}'{data}"],
                               input=body or "", capture_output=True, text=True)
            codes.append(p.stdout)
        done[qid] = codes
    return done


STATS = ("docker stats --no-stream --format 'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.MemPerc}}' "
         "nosql-demo-redis nosql-demo-mongo nosql-demo-es nosql-demo-kibana nosql-demo-elasticvue nosql-demo-redisinsight")
RESTARTS = ("docker inspect -f '{{.Name}} limit={{.HostConfig.Memory}} restarts={{.RestartCount}} "
            "oomKilled={{.State.OOMKilled}} status={{.State.Status}}' "
            "nosql-demo-redis nosql-demo-mongo nosql-demo-es nosql-demo-kibana")


def docker_stats(_):
    """S-89 (NFR-14): docker stats of the demo stack with the limits of docker-compose.yml, Kibana off then on."""
    from playwright.sync_api import sync_playwright
    t = Term("S-89 · docker stats --no-stream của stack demo (giới hạn bộ nhớ = docker-compose.yml) – NFR-14")
    started = time.strftime("%Y-%m-%d %H:%M:%S")
    t.note(f"# 1) {started}: nạp lại dữ liệu demo, chạy Q-01..Q-41 (mongosh, redis-cli, curl Q-30..Q-40); Kibana TẮT")
    codes = run_es_queries()
    sh("docker exec -w /s nosql-demo-mongo bash -c 'mongosh -u root -p \"$MONGO_INITDB_ROOT_PASSWORD\" "
       "--authenticationDatabase admin --quiet mongodb_demo.js' >/dev/null")
    sh("docker exec nosql-demo-redis sh -c 'REDISCLI_AUTH=\"$REDIS_PASSWORD\" redis-cli -n 2 < /s/redis_demo.txt' >/dev/null")
    time.sleep(20)
    t.run(STATS)
    t.run(RESTARTS)
    t.note(f"# 2) {time.strftime('%H:%M:%S')}: bật Kibana (cùng giới hạn 1G), đăng nhập, mở Home / Index Management / Dev Tools, đợi 60 giây")
    sh("docker start nosql-demo-kibana")
    with sync_playwright() as p:
        b, ctx = browser(p)
        page = ctx.new_page()
        try:
            kibana_login(page)
            for path in ("/app/home#/", "/app/management/data/index_management/indices", "/app/dev_tools#/console"):
                page.goto(KIBANA + path)
                settle(page, 5)
            t.note("#    (đăng nhập Kibana và mở 3 trang: thành công)")
        except Exception as e:  # noqa: BLE001 - what happened is part of the measurement
            t.note(f"#    (đăng nhập/mở trang Kibana THẤT BẠI: {type(e).__name__}: {str(e).splitlines()[0][:90]})")
            page.screenshot(path=str(Path(__import__("tempfile").mkdtemp()) / "S-89-kibana-failure.png"))
        b.close()
    time.sleep(60)
    t.run(STATS)
    t.run(RESTARTS)
    t.note(f"# Các tiến trình bị kernel giết vì vượt giới hạn bộ nhớ cgroup từ lúc bắt đầu đo ({started}):")
    t.run(f"journalctl -k --since '{started}' | grep 'Memory cgroup out of memory: Killed process' "
          "| sed -E 's/^(\\S+ \\S+ \\S+).*(Killed process [0-9]+ \\(\\S+\\)).*(anon-rss:[0-9]+kB).*/\\1 \\2 \\3/'; "
          "docker inspect -f 'ES container: {{.Id}}' nosql-demo-es | cut -c1-27; "
          f"journalctl -k --since '{started}' | grep -o 'oom_memcg=/system.slice/docker-[0-9a-f]\\{{12\\}}' | sort | uniq -c")
    print(json.dumps(codes))
    t.save("S-89", font_size=16)


# --------------------------------------------------------------------------------------------- backup / restore terminals
MONGO_AUTH = '-u root -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin'
MONGO_COUNT = ("const d=db.getSiblingDB(\"finance_nosql_demo\"); printjson({ocr_logs: d.ocr_logs.countDocuments(), "
               "ocr_feedbacks: d.ocr_feedbacks.countDocuments(), index: d.ocr_logs.getIndexes().length + "
               "d.ocr_feedbacks.getIndexes().length, validator: d.getCollectionInfos({\"options.validator\": "
               "{$exists: true}}).length})")


def in_container(t, container, inner, shell="bash"):
    """Runs inner with bash/sh inside container; shows exactly that command line."""
    return t.run_argv(["docker", "exec", container, shell, "-c", inner],
                      shown=f"docker exec {container} {shell} -c '{inner}'")


def mongo_count(t):
    return in_container(t, "nosql-demo-mongo", f"mongosh {MONGO_AUTH} --quiet --eval '{MONGO_COUNT}'")


def terminal_backup(_):
    """S-61 (+ NFR-13 timings), S-62, S-63, S-64, S-86, S-87 on the demo stack (S-63 in a throw-away Redis)."""
    results = {"date": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
    # Fresh demo data first (36 + 36 documents, 12 indexes, 2 validators).
    sh(f"docker exec -w /s nosql-demo-mongo bash -c 'mongosh {MONGO_AUTH} --quiet mongodb_demo.js' >/dev/null")

    # S-61: count -> mongodump -> drop -> count -> time mongorestore -> count
    t = Term("S-61 · MongoDB: đếm → mongodump → xóa → time mongorestore → đếm lại (NFR-13, dữ liệu demo)")
    mongo_count(t)
    in_container(t, "nosql-demo-mongo", f"mongodump {MONGO_AUTH} --quiet --db finance_nosql_demo "
                                        "--archive=/tmp/demo.archive.gz --gzip && ls -l /tmp/demo.archive.gz")
    in_container(t, "nosql-demo-mongo", f"mongosh {MONGO_AUTH} --quiet --eval "
                                        "'db.getSiblingDB(\"finance_nosql_demo\").dropDatabase()'")
    mongo_count(t)
    out = in_container(t, "nosql-demo-mongo", f"time mongorestore {MONGO_AUTH} --quiet "
                                              "--archive=/tmp/demo.archive.gz --gzip")
    mongo_count(t)
    m = re.search(r"real\s+(\d+)m([\d.]+)s", out)
    results["S-61_real_s"] = int(m.group(1)) * 60 + float(m.group(2)) if m else None
    # NFR-13: 5 more drop + restore rounds, `time` real of mongorestore only
    reals = []
    for _ in range(5):
        sh(f"docker exec nosql-demo-mongo bash -c 'mongosh {MONGO_AUTH} --quiet --eval "
           "\"db.getSiblingDB(\\\"finance_nosql_demo\\\").dropDatabase()\"'")
        o = sh(f"docker exec nosql-demo-mongo bash -c 'time mongorestore {MONGO_AUTH} --quiet "
               "--archive=/tmp/demo.archive.gz --gzip'")
        mm = re.search(r"real\s+(\d+)m([\d.]+)s", o)
        reals.append(int(mm.group(1)) * 60 + float(mm.group(2)))
    results["restore_runs_real_s"] = reals
    results["counts_after"] = subprocess.run(
        ["docker", "exec", "nosql-demo-mongo", "bash", "-c", f"mongosh {MONGO_AUTH} --quiet --eval '{MONGO_COUNT}'"],
        capture_output=True, text=True).stdout.strip()
    t.note(f"# NFR-13: thêm 5 lần xóa + khôi phục: real = {', '.join(f'{r:.3f}' for r in reals)} s "
           f"(trung vị {statistics.median(reals):.3f} s; mục tiêu < 300 s)")
    t.save("S-61")

    # S-62: mongoexport / mongoimport (canonical JSON), schema from mongodb_init.js
    t = Term("S-62 · MongoDB: mongoexport → xóa → mongodb_init.js → mongoimport → đếm lại")
    mongo_count(t)
    in_container(t, "nosql-demo-mongo", "for c in ocr_logs ocr_feedbacks; do mongoexport " + MONGO_AUTH +
                 " --quiet --db finance_nosql_demo --collection $c --jsonFormat=canonical --out=/tmp/$c.jsonl; done; "
                 "wc -l /tmp/ocr_logs.jsonl /tmp/ocr_feedbacks.jsonl")
    in_container(t, "nosql-demo-mongo", f"mongosh {MONGO_AUTH} --quiet --eval "
                                        "'db.getSiblingDB(\"finance_nosql_demo\").dropDatabase()'")
    in_container(t, "nosql-demo-mongo", f"cd /s && mongosh {MONGO_AUTH} --quiet --eval "
                                        "'var TARGET_DB=\"finance_nosql_demo\"; load(\"mongodb_init.js\")' | tail -3")
    in_container(t, "nosql-demo-mongo", "for c in ocr_logs ocr_feedbacks; do mongoimport " + MONGO_AUTH +
                 " --db finance_nosql_demo --collection $c --file /tmp/$c.jsonl 2>&1 | tail -1; done")
    mongo_count(t)
    in_container(t, "nosql-demo-mongo", f"mongosh {MONGO_AUTH} --quiet --eval 'printjson(db.getSiblingDB("
                                        "\"finance_nosql_demo\").ocr_logs.findOne({{}}, {{transactionId: 1, "
                                        "createdAt: 1, _id: 0}}))'".replace("{{", "{").replace("}}", "}"))
    t.save("S-62")

    # S-63: RDB in a throw-away Redis with RDB on (the demo/real Redis runs --save '' and has FLUSHALL renamed)
    t = Term("S-63 · Redis: RDB SAVE → FLUSHALL → khởi động lại với dump.rdb → đếm (container dùng một lần)")
    script = ("mkdir -p /tmp/bk; redis-server --daemonize yes --dir /tmp/bk --dbfilename dump.rdb >/dev/null; sleep 1; "
              "redis-cli < /s/redis_demo.txt >/dev/null; sleep 2; "
              "redis-cli ZADD ledgermind:leaderboard:spend:2026-10 4200000 1 6850000 2 9100000 4 >/dev/null; "
              "echo \"1. truoc: DBSIZE=$(redis-cli DBSIZE) ZCARD=$(redis-cli ZCARD ledgermind:leaderboard:spend:2026-10) "
              "top=$(redis-cli ZREVRANGE ledgermind:leaderboard:spend:2026-10 0 0 WITHSCORES | tr \"\\n\" \" \")\"; "
              "echo \"SAVE: $(redis-cli SAVE)\"; cp /tmp/bk/dump.rdb /tmp/bk/backup.rdb; ls -l /tmp/bk/backup.rdb; "
              "echo \"FLUSHALL: $(redis-cli FLUSHALL)\"; echo \"2. sau FLUSHALL: DBSIZE=$(redis-cli DBSIZE)\"; "
              "redis-cli SHUTDOWN NOSAVE; sleep 1; cp /tmp/bk/backup.rdb /tmp/bk/dump.rdb; "
              "redis-server --daemonize yes --dir /tmp/bk --dbfilename dump.rdb >/dev/null; sleep 1; "
              "echo \"3. sau khoi dong lai: DBSIZE=$(redis-cli DBSIZE) ZCARD=$(redis-cli ZCARD "
              "ledgermind:leaderboard:spend:2026-10) top=$(redis-cli ZREVRANGE ledgermind:leaderboard:spend:2026-10 0 0 "
              "WITHSCORES | tr \"\\n\" \" \") TTL(user-dashboard:1)=$(redis-cli TTL ledgermind:default:v1:user-dashboard:1)\"")
    t.run_argv(["docker", "run", "--rm", "--network", "none", "-v", f"{REPO}/scripts/nosql:/s:ro", "redis:8.10-alpine",
                "sh", "-c", script],
               shown=f"docker run --rm --network none -v \"$PWD/scripts/nosql:/s:ro\" redis:8.10-alpine sh -c '{script}'")
    t.save("S-63", font_size=15)

    # S-86: import with redis-cli < redis_demo.txt (empty logical DB 3) and export with redis-cli --rdb
    t = Term("S-86 · Redis: nhập bằng redis-cli < redis_demo.txt, xuất bằng redis-cli --rdb (stack demo)")
    rc = 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli'
    in_container(t, "nosql-demo-redis", f"{rc} -n 3 DBSIZE", shell="sh")
    in_container(t, "nosql-demo-redis", f"{rc} -n 3 < /s/redis_demo.txt | tail -2", shell="sh")
    in_container(t, "nosql-demo-redis", f"{rc} -n 3 DBSIZE; {rc} -n 3 --scan --pattern \"ledgermind:*\"", shell="sh")
    in_container(t, "nosql-demo-redis", f"{rc} --rdb /tmp/remote.rdb && ls -l /tmp/remote.rdb", shell="sh")
    t.save("S-86")

    # S-64: Elasticsearch snapshot -> delete -> restore -> _count
    t = Term("S-64 · Elasticsearch: snapshot → xóa index → restore → _count (stack demo, bảo mật bật)")
    cu = 'curl -s -u "elastic:$ELASTIC_PASSWORD"'
    jh = "-H \"Content-Type: application/json\""
    body = "{\"indices\":\"transactions\",\"include_global_state\":false}"
    sh(f"docker exec nosql-demo-es curl -s -u elastic:{ELASTIC_PW} -X DELETE localhost:9200/_snapshot/demo_repo/snap-s64")
    for inner in (
        f"{cu} localhost:9200/transactions/_count; echo",
        f"{cu} -X PUT localhost:9200/_snapshot/demo_repo {jh} -d '{{\"type\":\"fs\",\"settings\":{{\"location\":"
        f"\"/usr/share/elasticsearch/snapshots\"}}}}'; echo",
        f"{cu} -X PUT \"localhost:9200/_snapshot/demo_repo/snap-s64?wait_for_completion=true&filter_path="
        f"snapshot.snapshot,snapshot.state,snapshot.indices\" {jh} -d '{body}'; echo",
        f"{cu} -X DELETE localhost:9200/transactions; echo",
        f"{cu} localhost:9200/transactions/_count; echo",
        f"{cu} -X POST \"localhost:9200/_snapshot/demo_repo/snap-s64/_restore?wait_for_completion=true&filter_path="
        f"snapshot.shards\" {jh} -d '{body}'; echo",
        f"{cu} localhost:9200/transactions/_count; echo",
        f"{cu} \"localhost:9200/transactions/_analyze?filter_path=tokens.token\" {jh} -d "
        f"'{{\"analyzer\":\"vi_folded\",\"text\":\"Phở Bò\"}}'; echo",
    ):
        in_container(t, "nosql-demo-es", inner, shell="sh")
    t.save("S-64", font_size=15)

    # S-87: export with _search, delete, recreate from the app's files, _bulk, _count
    t = Term("S-87 · Elasticsearch: xuất _search → xóa → tạo lại từ mapping/settings của app → _bulk → _count")
    for inner in (
        f"{cu} \"localhost:9200/transactions/_search?size=1000\" > /tmp/export.json; "
        "grep -o '\"_id\":\"[0-9]*\"' /tmp/export.json | wc -l",
        f"{cu} -X DELETE localhost:9200/transactions; echo",
        "printf '{\"settings\":%s,\"mappings\":%s}' \"$(cat /app-es/transactions-settings.json)\" "
        f"\"$(cat /app-es/transactions-mapping.json)\" | {cu} -X PUT localhost:9200/transactions {jh} "
        "--data-binary @-; echo",
        f"{cu} \"localhost:9200/_bulk?refresh=true&filter_path=errors,items.index.status\" "
        "-H \"Content-Type: application/x-ndjson\" --data-binary @/s-es/transactions-bulk.ndjson "
        "| grep -o '\"errors\":[a-z]*\\|\"status\":201' | sort | uniq -c",
        f"{cu} localhost:9200/transactions/_count; echo",
    ):
        in_container(t, "nosql-demo-es", inner, shell="sh")
    t.save("S-87", font_size=15)

    (RAW / "task4_backup.json").write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n", encoding="utf8")
    print(json.dumps(results, ensure_ascii=False))


def terminal_e6(_):
    """S-88: the output table of the E6 benchmark run (docs/nosql/bench_raw/E6.txt, copied from target/bench)."""
    t = Term("S-88 · E6 độ trễ sự kiện realtime: AdminEventPublisher → Redis Pub/Sub → AdminEventRelay → SseEmitter")
    t.blocks.append(("cmd", "cd core-backend && TESTCONTAINERS_RYUK_DISABLED=true mvn -B -o -q -Dmaven.repo.local=<kho m2 cục bộ> test "
                            "-Dtest=AdminEventLatencyBench -Dbench=true"))
    t.blocks.append(("out", (RAW / "E6.txt").read_text(encoding="utf8")))
    t.blocks.append(("note", "# Chỉ đo đường đi phía server (publish → emitter.send); chặng mạng tới trình duyệt KHÔNG đo."))
    t.save("S-88")


def measure_tools(_):
    """S-14: docker stats of Kibana vs Elasticvue (+ Elasticsearch) and the first-page load, 5 cold loads each."""
    from playwright.sync_api import sync_playwright
    runs = {"kibana_login": [], "kibana_home_after_login": [], "elasticvue_home": []}
    with sync_playwright() as p:
        for _ in range(5):
            b = p.chromium.launch()
            ctx = b.new_context(viewport={"width": WIDTH, "height": 900})  # new profile = empty cache
            page = ctx.new_page()
            t0 = time.perf_counter()
            page.goto(KIBANA + "/login")
            page.wait_for_selector("input[name=username]", timeout=120000)
            runs["kibana_login"].append(time.perf_counter() - t0)
            page.fill("input[name=username]", "elastic")
            page.fill("input[name=password]", ELASTIC_PW)
            t1 = time.perf_counter()
            page.click("button[type=submit]")
            page.wait_for_selector("text=Welcome home", timeout=120000)
            runs["kibana_home_after_login"].append(time.perf_counter() - t1)
            b.close()
            b = p.chromium.launch()
            ctx = b.new_context(viewport={"width": WIDTH, "height": 900})
            page = ctx.new_page()
            t0 = time.perf_counter()
            page.goto(ELASTICVUE + "/")
            page.wait_for_selector("text=Cluster Health", timeout=60000)
            runs["elasticvue_home"].append(time.perf_counter() - t0)
            b.close()
    t = Term("S-14 · Kibana và Elasticvue: RAM/CPU (docker stats) và thời gian tải trang đầu (đo, 5 lần, cache trống)")
    t.run("docker stats --no-stream --format 'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.MemPerc}}' "
          "nosql-demo-kibana nosql-demo-elasticvue nosql-demo-es")
    t.run("docker image ls --format 'table {{.Repository}}:{{.Tag}}\\t{{.Size}}' | grep -E 'REPOSITORY|kibana|elasticvue'")
    t.blocks.append(("cmd", "python3 docs/nosql/build/capture_tools.py measure-tools   "
                            "# Playwright Chromium headless, hồ sơ mới mỗi lần"))
    lines = ["trang (đến khi dùng được)                     lần 1..5 (giây)                       trung vị"]
    labels = {"kibana_login": "Kibana /login (form đăng nhập hiện)",
              "kibana_home_after_login": "Kibana sau khi bấm Log in (Home hiện)",
              "elasticvue_home": "Elasticvue / (thẻ Cluster Health hiện)"}
    for k, v in runs.items():
        lines.append(f"{labels[k]:<46}{'  '.join(f'{x:5.2f}' for x in v):<38}{statistics.median(v):6.2f}")
    t.blocks.append(("out", "\n".join(lines)))
    t.save("S-14")
    (RAW / "task4_tools.json").write_text(json.dumps({"date": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "runs_s": runs},
                                                     indent=2) + "\n", encoding="utf8")
    print(json.dumps(runs))


# --------------------------------------------------------------------------------------------- Elasticvue
def elasticvue(_):
    """S-10..S-13. The cluster is pre-configured by ELASTICVUE_CLUSTERS (demo-stack.compose.yml), browser -> ES direct."""
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b, ctx = browser(p)
        page = ctx.new_page()
        page.goto(ELASTICVUE + "/")
        settle(page, 4)
        shot(page, "S-10")

        def nav(path):  # in-app navigation: a direct page load leaves Elasticvue's IndexedDB unopened (REST tab breaks)
            page.click(f"a[href='/cluster/0/{path}']")
            settle(page, 3)

        # S-11: index list (top) + full-text search "phở" in index transactions (bottom)
        nav("indices")
        page.get_by_label("Filter").first.fill("transactions") if page.get_by_label("Filter").count() else None
        settle(page, 2)
        shot(page, "_ev-indices", clip={"x": 0, "y": 0, "width": WIDTH, "height": 420})
        nav("search")
        page.get_by_label("Index pattern").fill("transactions")
        page.get_by_label("Search", exact=True).fill("phở")
        page.get_by_role("button", name="Search", exact=True).click()
        settle(page, 3)
        page.locator("text=HITS").first.scroll_into_view_if_needed()
        shot(page, "_ev-search", full=True)
        stack_images([SHOTS / "_ev-indices.png", SHOTS / "_ev-search.png"], SHOTS / "S-11.png")
        # S-12: REST tab: POST transactions/_search with an aggregation body (POST is the default method)
        nav("rest")
        page.get_by_label("Path").fill("transactions/_search?filter_path=hits.total,aggregations")
        page.locator(".cm-content:visible").first.click()
        page.keyboard.press("Control+A")
        page.keyboard.press("Delete")
        page.keyboard.insert_text('{\n"size": 0,\n"query": { "term": { "userId": 1 } },\n"aggs": {\n'
                                  '"theo_danh_muc": { "terms": { "field": "categoryName.keyword", "size": 5 } }\n}\n}')
        page.get_by_role("button", name="Send request").click()
        settle(page, 3)
        shot(page, "S-12")
        # S-13: snapshot repositories -> demo_repo -> its snapshots
        nav("snapshot_repositories")
        shot(page, "_ev-repos", clip={"x": 0, "y": 0, "width": WIDTH, "height": 380})
        page.get_by_role("button", name="Snapshots").last.click()
        settle(page, 3)
        shot(page, "_ev-snaps")
        stack_images([SHOTS / "_ev-repos.png", SHOTS / "_ev-snaps.png"], SHOTS / "S-13.png")
        b.close()
    for name in ("_ev-indices", "_ev-search", "_ev-repos", "_ev-snaps"):
        (SHOTS / f"{name}.png").unlink(missing_ok=True)


# --------------------------------------------------------------------------------------------- RedisInsight
def redis_blocks():
    """{Q-17: [commands], ...} from scripts/nosql/redis_demo.txt (the ECHO explanation lines are left out)."""
    lines = (REPO / "scripts/nosql/redis_demo.txt").read_text(encoding="utf8").split("\n")
    blocks, cur = {}, None
    for line in lines:
        m = re.match(r"^ECHO '-- (Q-\d\d) ", line)
        if m:
            cur = blocks.setdefault(m.group(1), [])
            continue
        if cur is None or not line.strip() or line.startswith("ECHO"):
            continue
        cur.append(line)
    return blocks


REDIS_SEED = [
    'ZADD "ledgermind:leaderboard:spend:2026-10" 4200000 1 6850000 2 1250000 3 9100000 4 3300000 5',
    'EXPIRE "ledgermind:leaderboard:spend:2026-10" 5356800',
    'HSET "ledgermind:password-reset-otp:sv01@huit.edu.vn" code 482931 expiresAt 4102444800000',
    'PEXPIRE "ledgermind:password-reset-otp:sv01@huit.edu.vn" 300000',
    'SET "ledgermind:default:v1:user-dashboard:1" \'{"totalBalance":12500000,"monthlyExpense":3150000,"monthlyIncome":15000000}\' EX 285',
    'SET "ledgermind:default:v1:user-dashboard:2" \'{"totalBalance":4200000}\' EX 270',
    'SET "ledgermind:default:v1:user-popular-vendors:1" \'[{"vendorName":"Highlands Coffee","visits":12}]\' EX 600',
]


def redis_cli(commands):
    return subprocess.run(["bash", "-c", "docker exec -i nosql-demo-redis sh -c 'REDISCLI_AUTH=\"$REDIS_PASSWORD\" redis-cli'"],
                          input="\n".join(commands) + "\n", capture_output=True, text=True).stdout


def ri_db_id():
    import urllib.request
    dbs = json.load(urllib.request.urlopen(REDISINSIGHT + "/api/databases"))
    return next(d["id"] for d in dbs if d["name"] == "nosql-demo-redis")


def wb_run(page, commands, wait=3.0):
    """Clears the Workbench editor, types the commands (one per line) and runs them, results grouped in one card."""
    editor = page.locator(".monaco-editor").first
    editor.click()
    page.keyboard.press("Control+A")
    page.keyboard.press("Delete")
    page.keyboard.insert_text("\n".join(commands))
    page.keyboard.press("Escape")
    page.click("[data-testid=btn-submit]")
    time.sleep(wait)


def wb_shot(page, sid):
    """Opens the newest result card full screen (the card list scrolls otherwise), screenshots it, closes it."""
    card = page.locator("[data-testid^=query-card-container]").first
    card.hover()
    card.locator("[data-testid=toggle-full-screen]").click()
    time.sleep(1.5)
    shot(page, sid)
    crop_blank_bottom(SHOTS / f"{sid}.png")
    page.locator("[data-testid=toggle-full-screen]").first.click()
    time.sleep(0.5)


def crop_blank_bottom(path, margin=28, min_height=360):
    """Cuts the empty white area under the last line of a full-screen result card (nothing else is touched)."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    last = 0
    for y in range(h - 1, -1, -1):
        if any(px[x, y] != (255, 255, 255) for x in range(0, w, 2)):
            last = y
            break
    im.crop((0, 0, w, min(h, max(min_height, last + margin)))).save(path)


def stack_images(paths, out, gap=12):
    """One PNG made of several real captures placed one under the other (used for the two-window Pub/Sub demo)."""
    ims = [Image.open(p).convert("RGB") for p in paths]
    w = max(i.width for i in ims)
    canvas = Image.new("RGB", (w, sum(i.height for i in ims) + gap * (len(ims) - 1)), (90, 90, 90))
    y = 0
    for i in ims:
        canvas.paste(i, (0, y))
        y += i.height + gap
    canvas.save(out)


def redisinsight_pubsub(_):
    """S-60 (Q-41): window 1 = RedisInsight Pub/Sub subscribed to ledgermind:admin-events; window 2 = redis-cli PUBLISH."""
    from playwright.sync_api import sync_playwright
    dbid = ri_db_id()
    msg = '{"type":"RECEIPT_WAITING_REVIEW","id":1025,"message":"Hóa đơn #1025 đang chờ duyệt","at":"2026-10-27T10:00:00Z"}'
    tmp = RAW.parent / "screenshots" / "_S-60-window1.png"
    with sync_playwright() as p:
        b, ctx = browser(p, height=760)
        page = ctx.new_page()
        page.goto(f"{REDISINSIGHT}/{dbid}/pub-sub")
        settle(page, 3)
        page.fill("[data-testid=channels-input]", "ledgermind:admin-events")
        page.click("[data-testid=subscribe-btn]")
        time.sleep(2)
        t = Term("Cửa sổ 2 – redis-cli (người gửi): PUBLISH trả về số người nghe đã nhận tin")
        cli = "docker exec nosql-demo-redis sh -c 'REDISCLI_AUTH=\"$REDIS_PASSWORD\" redis-cli %s'"
        t.note("# RedisInsight đăng ký theo mẫu (PSUBSCRIBE, 'Patterns: 1'), nên NUMSUB của kênh = 0 và NUMPAT = 1:")
        t.run(cli % "PUBSUB NUMSUB ledgermind:admin-events")
        t.run(cli % "PUBSUB NUMPAT")
        pub = 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli PUBLISH ledgermind:admin-events "$0"'
        t.run_argv(["docker", "exec", "nosql-demo-redis", "sh", "-c", pub, msg],
                   shown=f"docker exec nosql-demo-redis sh -c '{pub}' '{msg}'")
        time.sleep(2)
        page.fill("[data-testid=field-channel-name]", "ledgermind:admin-events")
        page.fill("[data-testid=field-message]", msg.replace("1025", "1026"))
        page.click("[data-testid=publish-message-submit]")
        time.sleep(2)
        page.screenshot(path=str(tmp))
        b.close()
    term = render_terminal(t.blocks, RAW.parent / "screenshots" / "_S-60-window2.png", t.title, 16)
    stack_images([tmp, term], SHOTS / "S-60.png")
    tmp.unlink()
    Path(term).unlink()
    print("wrote", SHOTS / "S-60.png")


def redisinsight(_):
    from playwright.sync_api import sync_playwright
    redis_cli(REDIS_SEED)
    dbid = ri_db_id()
    blocks = redis_blocks()
    with sync_playwright() as p:
        b, ctx = browser(p, height=1000)
        page = ctx.new_page()
        # S-18: key list with type and TTL (list view)
        page.goto(f"{REDISINSIGHT}/{dbid}/browser")
        settle(page, 4)
        page.click("[data-testid=view-type-browser-btn]")  # "List view button" (testid names are swapped in RI)
        page.fill("[data-testid=search-key]", "ledgermind:*")
        page.keyboard.press("Enter")
        settle(page, 3)
        page.locator("text=ledgermind:password-reset-otp:sv01@huit.edu.vn").first.click()
        settle(page, 2)
        shot(page, "S-18")
        # Workbench: Q-17..Q-29 = S-36..S-48, one grouped result card per query
        page.goto(f"{REDISINSIGHT}/{dbid}/workbench")
        settle(page, 4)
        if page.locator("[data-testid=clear-history-btn]").count():
            page.click("[data-testid=clear-history-btn]")
        page.click("[data-testid=btn-change-group-mode]")  # off in a fresh browser profile: on = one card per run
        for n in range(17, 30):
            wb_run(page, blocks[f"Q-{n}"])
            wb_shot(page, f"S-{n + 19}")
        b.close()
    redis_cli(REDIS_SEED)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("what")
    args = ap.parse_args()
    SHOTS.mkdir(parents=True, exist_ok=True)
    globals()[args.what.replace("-", "_")](args)


if __name__ == "__main__":
    main()
