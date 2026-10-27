# NoSQL Word report + BaoCaoMinhChung — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the final NoSQL course report and the filled evidence/self-assessment form, both drawn from what the code on `feature/nosql` really does:
- 9 chapters per the course template, plus the demo script as an appendix;
- every known grading criterion mapped to evidence;
- references in IEEE style.

**Architecture:** This is the thesis pipeline, adapted.
- **Skeleton:** a `.docx` derived from thesis v9, which already has every style, the TOC fields and the abbreviation table. The SRS cover is transplanted into it, and a yellow `[T7.cN_x]` placeholder sits under every section.
- **Builder:** a NoSQL copy of `builder.py` (`docs/nosql/build/builder_nosql.py`) with one addition, a monospace `code` block. Content modules fill the chapters.
- **Facts:** every fact comes from `facts.md`, which cites the code. `facts.md` is authoritative over the spec wherever the two differ.
- **Sources of content:** diagrams are PlantUML; measurements come from scripts in throwaway containers.
- **Screenshots:** the agent captures what it can automate. The user captures the rest from a numbered list. Every screenshot slot holds a placeholder PNG until the real one replaces it via `IMAGE_REPLACE`.

**Tech Stack:**
- Python 3 (raw XML editing, as `builder.py` does);
- PlantUML 1.2024.7 jar (in the scratchpad; `!pragma layout smetana`);
- throwaway docker images: `mongo:6.0`, `redis:8.10-alpine`, `elasticsearch:8.11.4`, `kibana:8.11.4`, `postgres:15-alpine`, `redis/redisinsight`, `cars10/elasticvue`, `scratch-lo-render:1` (LibreOffice → PDF);
- matplotlib;
- Playwright (Python, scratch venv).

**Spec:** `docs/superpowers/specs/2026-10-26-nosql-report-and-elasticsearch-design.md` §1, §2, §4, §6, §10. Code reference: branch `feature/nosql` at `63328b7`.

## Global Constraints

- **Requirements** (under `/home/triphan/Workspace/Deploy_Project/`, the main checkout; `Nosql/` is not in git): `Nosql/YC_NoSql/nosql_doan.txt`, `Nosql/YC_NoSql/REFS_NoSQL_SRS&SDS_Template.docx`, `Nosql/YC_NoSql/BaoCaoMinhChung_DoAn_DuLieuNoSQL.docx`.
- **Inputs:**
  - thesis base `/home/triphan/Workspace/Deploy_Project/KhoaLuan_KLCN175_v9.docx` (not in git);
  - SRS cover `Nosql/Nosql_38/38_SRS_…docx`.
- **Group:** 38.
  - Members: Phan Thanh Trí (2001230977, nhóm trưởng) and Phan Minh Tiến (2001230806).
  - GVHD: Ths. Ngô Minh Anh Thư.
  - Title (registered with the GVHD, same as the week-6 SRS cover): "ỨNG DỤNG CƠ SỞ DỮ LIỆU MONGODB VÀ BỘ NHỚ ĐỆM REDIS TRONG VIỆC XÂY DỰNG HỆ THỐNG QUẢN LÝ TÀI CHÍNH CÁ NHÂN". Elasticsearch is presented inside the report as the self-researched DB.
  - Cover date: "Thành phố Hồ Chí Minh tháng 11 năm 2026".
  - Cover lines as in the SRS: Bộ Công Thương / Trường ĐH Công Thương TP.HCM / Khoa CNTT / "BÁO CÁO MÔN HỌC – DỮ LIỆU NOSQL".
- **Styles:** use only the thesis style set and never manual formatting: `noidung`, `GachDau1/2`, `Heading1–4` ("CHƯƠNG n:"), `TieuDeKhongSo`, `Caption`/`ChuThichBang` with `SEQ Hình`/`SEQ Bảng \s 1`, `NoiDungBang`, `Hinh`, `TableGrid` 8504 dxa, plus the new monospace `MaNguon`.
- **Honesty** (spec §2 anti-goals):
  - **Scope of claims:** only claim what the code does at `63328b7`. Every number is measured in this plan or marked "mục tiêu". Every dataset count names its source: "dữ liệu demo" (scripts/nosql) or "dữ liệu tổng hợp 100k (sinh bằng gen_data.py)".
  - **Words never to use:** "Circuit Breaker" for `FallbackCacheErrorHandler`; Jitter/@Async presented as the "CSDL tự tìm hiểu" (that is Elasticsearch); "CQRS read model" as a fact (MongoDB is an after-commit "bản sao phân tích"; CQRS is only an analogy); production runs ES (`SEARCH_ENGINE` defaults to postgres; the deployed mode is stated only once known).
  - **Do not reuse the old argument** "tách JSON để Postgres khỏi phình".
  - **Wording that must match the code:** PG search is `LOWER(col) LIKE … ESCAPE`, not ILIKE. The leaderboard writes absolute totals with a Lua `ZADD`/`ZREM` (never `ZINCRBY`) to `ledgermind:leaderboard:spend:yyyy-MM`. `ReceiptStatus.PROCESSING` is reserved and unreachable. Auth sessions are JWT. The token blacklist is in PostgreSQL. The only Redis piece of user management is the reset OTP (`RedisPasswordResetOtpStore`).
  - **Outages:** degradation claims say "vẫn trả lời" with the observed latency, never "không ảnh hưởng".
- **Limitations** (Ch.7.4 + Ch.8):
  - PG search mode is not accent-insensitive;
  - NoSQL writes are after-commit, async and eventually consistent; if the JVM dies between commit and the async write, the change is healed only by the next change, a rebuild or a reindex;
  - DONUT V5 returns no confidence (null);
  - single node per DB, no replication or sharding (designs only);
  - no realtime feature (unless [Q2] adds one);
  - MongoDB CRUD and ES reindex have REST endpoints but no admin web page; the backup page covers PostgreSQL only (unless [Q4] changes this).
- **References:** IEEE style.
  - Article: `[n] A. Tác giả, "Tên bài," *Nơi XB*, vol., no., pp., năm.`
  - Web: `[n] Tên, Nhà phát hành. [Online]. Available: URL (truy cập dd/mm/yyyy).`
  - Numbered by first citation, so "Vietnamese first" does not apply.
  - Kept in `docs/nosql/references.md` with "Kiểm chứng" URL + "Dùng cho".
  - Thesis-verified sources are reused but rewritten to IEEE.
  - Licence, community and performance claims about Kibana/Elasticvue cite a source or a measurement.
- **Builder rules:** every content module declares `SESSION_TAG = None`, `SECTIONS = {}` and `RENUMBER = True`. Content goes in through `HEADING_PLACEHOLDERS`, keyed by heading text; skeleton headings are unique. Figure and table references use `[[key]]` only; there are no literal "Hình c.n". No forward `[[key]]` to a chapter not built yet. Cross-chapter IDs (FR, AP, Q, TC, S) are frozen in `facts.md` in Task 1, so text can cite them before they exist.
- **Screenshot slots:** every S-id is a `fig` block with its own placeholder PNG `docs/nosql/screenshots/S-xx.png` (grey, "S-xx – chưa chụp"). The real capture is swapped in with `IMAGE_REPLACE [("S-xx.png", path, "fit")]`, so caption and number stay.
- **Outputs** (not in git; `*.docx` is ignored): `Nosql/Nosql_38/NoSQL_38_BaoCao_vN.docx` (one per task, never overwritten). Final files: `Nosql/Nosql_38/38_BaoCao_NoSQL.docx` and `Nosql/Nosql_38/38_BaoCaoMinhChung.docx`.
- **Tracked sources:**
  - `docs/nosql/{outline.md, facts.md, references.md, screenshots.md, bench_results.md, kich_ban_demo.md}`;
  - `docs/nosql/build/*.py`, which `**/build/` ignores, so add them with `git add -f`;
  - `docs/nosql/diagrams/*`, `docs/nosql/screenshots/*.png`;
  - `scripts/nosql/bench/*`, `scripts/nosql/sample_data/*.json`.
- **Verification of every docx:**
  1. Unpack, run `builder_nosql.py`, repack.
  2. Render to PDF with `scratch-lo-render:1`: `docker run --rm --network none -u $(id -u):$(id -g) -e HOME=/w/home -v DIR:/w -w /w scratch-lo-render:1 soffice -env:UserInstallation=file:///w/home/lo --headless --convert-to pdf X.docx`.
  3. Run `check_report.py`, check the PDF page count and grep the PDF text.
  4. Run the docx skill's `validate.py` in a scratch venv.
  5. LibreOffice does not refresh TOC/SEQ fields. Every checkpoint tells the user that in Word they must press Ctrl+A, then F9, then save, before judging the TOC and lists.
- **Process:**
  - The agent commits only after the user's "ok".
  - Never touch the running local compose stack; throwaway containers only.
  - Running core-backend tests follows the backend runbook: system `mvn -o`, a scratchpad `~/.m2` copy, Testcontainers. Never start the app.
- **User answers** (all answered on 2026-10-27, see spec §11; Task 1 copies them into `facts.md` §0). Q1: rubric criterion 10 = 4 × 0.5. Q2/Q4: plan 1b is done (admin pages, Mongo backup UI, realtime). Q3: honest split (Trí: all code; Tiến: real remaining work per `docs/nosql/HUONG_DAN_TIEN.md`). Q5: the `main` branch link, repo private (note collaborator or zip). Q6: tháng 11/2026. Q7: the registered title. Q8: separate demo stack. The questions were:
  - [Q1] official thang điểm / criterion 10;
  - [Q2] realtime;
  - [Q3] real task split, dates, "Phụ trách CSDL", %;
  - [Q4] evidence for MongoDB CRUD and NoSQL backup from the UI;
  - [Q5] links for the form;
  - [Q6] cover month and year;
  - [Q7] final title;
  - [Q8] which stack the user captures Compass, RedisInsight and app screens on.
  - Until an answer arrives, its slot is a yellow note, never an invented value.

## Review Focus

1. **A claim the code does not back.** `check_report.py` checks every identifier in `MaNguon` runs and code-like tokens against `facts.md` and `git grep @63328b7`.
2. **Criteria coverage.** `barem.py` fails when a row has no section and no evidence. Criterion 10 is labelled "suy luận từ template" until [Q1] is answered.
3. **Broken numbering or references.** Use `[[key]]` refs only, `RENUMBER = True`, and grep the output for "[[" and "[T7." leftovers.
4. **Screenshots still placeholders at the end.** Task 10 lists them. Only the ones the user agrees to leave may stay.
5. **Citations in both directions** (`check_report.py` without `--chapter`).

---

### Task 1: Inputs, facts, builder copy, checkers, skeleton v0

**Files:**
- Create: `docs/nosql/build/builder_nosql.py`, a copy of `docs/thesis/build/builder.py` plus:
  - a `("code", text)` block that renders each line as a `MaNguon` paragraph (Consolas 10 pt, light grey shading, keeps spaces). The style is added to `styles.xml` by `make_skeleton.py`.
  - `("sid", "S-xx", caption, chapter, width_cm, key)`: a `fig` with the placeholder PNG.
- Create: `docs/nosql/build/make_skeleton.py`, `docs/nosql/build/check_report.py`, `docs/nosql/build/make_placeholder_png.py`
- Create: `docs/nosql/outline.md`, `docs/nosql/facts.md`, `docs/nosql/references.md`
- Output: `Nosql/Nosql_38/NoSQL_38_BaoCao_v0.docx`

**Interfaces:**
- Produces:
  - `make_skeleton.py <thesis_v9_docx> <srs_docx> <outline_md> <out_docx>`:
    - Start from thesis v9. Keep `styles.xml` (add `MaNguon`), `numbering.xml`, the 3 TOC fields ("Mục lục", "Danh mục hình", "Danh mục bảng"), and the heading "DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT" with its table reduced to its header plus one data row (`add_abbreviation` needs `rows[1]`).
    - Remove the rest of the thesis body and the thesis header/footer text.
    - Transplant the SRS cover paragraphs with their direct formatting, media and rels, then put in the new title.
    - Add the chapters and sections from `outline.md`, each section with its `[T7.cN_x]` placeholder.
    - Assert that all heading texts are unique.
  - `check_report.py <docx> [--chapter N]`. Exit code ≠ 0 on any of:
    - a leftover `[T7.cN_` of that chapter (all chapters without `--chapter`);
    - a leftover `[[`;
    - a `[n]` with no entry, or (without `--chapter`) an entry never cited;
    - a "Hình/Bảng c.n" to a missing number;
    - a `MaNguon` identifier or Q/AP/FR/TC/S id unknown to `facts.md` or `git grep @63328b7`.
    - It prints the remaining `S-xx – chưa chụp` placeholders as information.
  - `outline.md`: the template tree heading for heading, with these adaptations:
    - Section 1.6 = "Kế hoạch dự án", because template Ch.8 cites "bảng phân công 1.6". Its subsections a)–f) are bold runs, not headings.
    - Ch.2: §2.1–2.4 overview/distribution/families/systems, §2.5 Kibana vs Elasticvue.
    - Ch.4: §4.5 "Thiết kế CSDL Search/Document [Elasticsearch] – CSDL tự tìm hiểu" and §4.6 "Cassandra và Neo4j: không sử dụng".
    - Ch.6: no 6.5.
    - Ch.9: 9.1 Tài liệu tham khảo; 9.2 Phụ lục A cấu trúc thư mục; 9.3 Phụ lục B trích docker-compose; 9.4 Phụ lục C hướng dẫn chạy demo; 9.5 Phụ lục D kịch bản demo 5–7 phút (the template's 4-row table).
    - Page budgets: Ch.1 4–5 pages, Ch.2 10–12 pages.
  - `facts.md`:
    - §0: the user answers [Q1]–[Q8].
    - §1: verified code facts with `(file:line @63328b7)`, per DB: stored data, keys/collections/indexes, TTLs, endpoints (method, path, params, role), events/listeners, defaults, compose (services, profiles, ports, heap, memory).
    - §2: the frozen ID lists:
      - FR-xx and AP-xx, each with the target latency and consistency **fixed now, before any measurement**;
      - NFR-xx with targets and verification method;
      - Q-01..Q-40 (from `scripts/nosql`);
      - TC-xx (one per test method/script check that Ch.7 will use);
      - S-xx (all screenshot slots).
    - §3: the limitations list.
    - §4: the test classes to cite.
  - `references.md`, each entry verified on the web:
    - MongoDB Manual, Redis docs, Elasticsearch Reference 8.11, Kibana Guide 8.11 (+ licence page), Elasticvue (GitHub, licence);
    - Spring Data MongoDB/Redis/Elasticsearch reference;
    - Sadalage & Fowler, Brewer 2000, Gilbert & Lynch 2002, Abadi 2012, Kleppmann *DDIA*;
    - IEEE 830-1998, ISO/IEC/IEEE 29148:2018, IEEE 1016-2009;
    - Kim et al. 2022 (Donut);
    - Fowler PolyglotPersistence and CQRS;
    - Lucene/ES inverted index (to place ES outside the 4 families).

- [ ] **Step 1:** Write `check_report.py` and test it on a hand-made tiny docx that holds one placeholder, one unknown citation and one bad "Bảng 9.9". Expected: exit 1, all three reported.
- [ ] **Step 2:** Make `builder_nosql.py`. Check: build a 2-paragraph test docx with a `code` block of 3 indented lines and a `sid` block. The render shows monospace lines with their indentation kept, and the placeholder image with its caption.
- [ ] **Step 3:** Write `outline.md`, `facts.md` §1–§4 and `references.md`. For §4, run the cited test classes now the runbook way and record the surefire counts and the date, never `@Test` counts.
- [ ] **Step 4:** Write `make_skeleton.py` and produce v0. Render it. Expected:
  - the cover looks like the SRS cover with the new title;
  - the abbreviation table is there;
  - every placeholder is visible;
  - `check_report.py v0` fails only on placeholders.
- [ ] **Step 5: Checkpoint.** Give the user the PDF and the outline, with the F9 reminder. Commit on their "ok".

### Task 2: Diagrams

**Files:** `docs/nosql/diagrams/_style.iuml` (copy of the thesis style), `*.puml` + `*.png`.

**Interfaces — PNG names:**
- `arch_tong_the`, `trien_khai`, `ngu_canh`, `phan_cap_chuc_nang`;
- `uc_tong_quat`, `uc_nguoi_dung`, `uc_quan_tri`;
- `bpmn_quet_hoa_don` (swimlanes User / App / core-api / ai-service, data written per step);
- `act_dashboard_cache`, `act_tim_kiem`, `act_sua_hoa_don` (cache vs primary-DB branches);
- `seq_tim_kiem`, `seq_sua_ocr`, `seq_bang_xep_hang`, `seq_dong_bo_index` (one lifeline per DB);
- `state_hoa_don` (from the `ReceiptStatus` enum; PROCESSING drawn as reserved/unreachable);
- `dfd_muc0`, `dfd_muc1`;
- `erd_khai_niem`, `erd_postgres`, `erd_da_csdl`;
- `mongo_document`, `redis_keys`, `es_mapping`;
- `lop_nosql` (stereotypes `<<Document>>`, `<<Table>>`, `<<RedisKey>>`, `<<EsDocument>>`);
- `bench_*` charts come from Task 3.

Every functional diagram labels the DB taking part, and every element name is a real class, key, collection or endpoint.

- [ ] **Step 1:** Put the PlantUML jar in the scratchpad (no plantuml or graphviz on the host; use smetana for non-activity diagrams).
- [ ] **Step 2:** Write the diagrams from `facts.md`.
- [ ] **Step 3:** Render them. Expected: each is at most 2000 px wide.
- [ ] **Step 4: Checkpoint.**

### Task 3: Measurements

**Files:** `scripts/nosql/bench/{README.md, gen_data.py, run_all.sh, bench_*.py}`, `docs/nosql/build/plot_bench.py` → `docs/nosql/bench_results.md`, `docs/nosql/diagrams/bench_*.png`.

**Method** (one rule set for every experiment):
- one private throwaway docker network;
- one long-lived client process per experiment inside that network (pymongo/redis-py/psycopg/ES HTTP), never `docker exec` per call;
- warm-up of 200 iterations, then ≥ 1 000 timed iterations;
- single thread, sequential (the "Tải" column reads "1 luồng");
- report p50/p95/p99/max + ops/s;
- also report the server-side timing: `explain` executionStats, `EXPLAIN ANALYZE`, ES `took`.
- Data: `gen_data.py`, seed 42, 100 000 synthetic Vietnamese transactions plus the OCR documents, labelled synthetic everywhere.
- Each table lists versions, machine and command.

**Experiments:**
- **E1 MongoDB index vs no index:** Q-02/Q-03 shapes, with keys/docs examined.
- **E2 ES vs PG `LOWER(..) LIKE … ESCAPE`:** the real `searchIdsByText` SQL and the real `ElasticsearchTransactionSearchEngine` body. The PG schema is from the Hibernate DDL of a test run (show-sql). 10 terms, with and without accents. Includes the hit counts "pho" vs "phở" on both engines.
- **E3 leaderboard:** Lua-maintained ZSET `ZREVRANGE 0 9 WITHSCORES` vs the real `sumExpensesByUserBetween` SQL.
- **E4 cache vs no cache, data layer:** Redis `GET` of the cached JSON vs the SQL the JPA layer emits for the dashboard on a miss. That SQL is captured with show-sql from `UserStatisticsService`/`AdminStatisticsService` tests, not hand-written.
- **E5 embed vs reference:** `$lookup` (Q-13) vs the embedded copy.
- App-level JMeter is optional and run by the user. If not run, the report says so.
- Ch.7.2 is "khuyến khích, không có trong thang điểm". These numbers earn points as the 4.13/6.4 before-and-after evidence, so keep the experiments at this size.

- [ ] **Step 1:** Write `gen_data.py`. Check: two runs give the same sha256.
- [ ] **Step 2:** Write the runners and run them. Expected: every table is filled, with no NaN, and the network is torn down.
- [ ] **Step 3:** Write `plot_bench.py`.
- [ ] **Step 4: Checkpoint.**

### Task 4: Screenshot list, placeholders and automated captures

**Files:** `docs/nosql/screenshots.md`, `docs/nosql/build/capture_tools.py`, `docs/nosql/screenshots/S-xx.png`.

- [ ] **Step 1:** Write `screenshots.md`. Each row holds the S-id, the section, the tool, the exact steps or command, and who captures it: agent, or user per [Q8]. It covers:
  - **§2.5, criteria 1–4:**
    - Kibana and Elasticvue install steps;
    - Dev Tools queries, index management, import (Data Visualizer / Upload file), export, snapshot/restore;
    - users/roles (security on);
    - monitoring through Index Management/`_cat` stats. Stack Monitoring needs Metricbeat, so do not show it as working unless it is set up.
    - performance: the `docker stats` RAM/CPU of both tools and the first-page load time, measured.
  - **Ch.5:** every Q-xx result on its GUI (Compass for Mongo = user; RedisInsight; Kibana Dev Tools).
  - **Ch.6.3:** the 4 function groups.
    - Login/roles, OTP in RedisInsight.
    - CRUD + backup. Per [Q4]: the Postman/Swagger call + the GUI tool showing the data change + the PG backup page.
    - Business features: search, scan, leaderboard.
    - Support features: analytics, statistics.
  - **3.7:** the UI screens.
  - **Ch.7:** JMeter, if run.
- [ ] **Step 2:** Generate the placeholder PNG for every S-id.
- [ ] **Step 3:** Start a throwaway setup on a private network, ports bound to 127.0.0.1 only:
  - ES (`xpack.security.enabled=true`, `http.cors.enabled=true`, `http.cors.allow-origin` = the Elasticvue origin, `http.cors.allow-headers=Authorization,Content-Type`, `path.repo` set);
  - set the `kibana_system` password with `elasticsearch-reset-password`, then start Kibana with it;
  - Elasticvue, Redis + RedisInsight;
  - the demo data from `scripts/nosql`.
- [ ] **Step 4:** Capture the automated ids with Playwright, then tear everything down. Expected: each PNG is ≥ 1280 px wide and shows the stated result.
- [ ] **Step 5: Checkpoint.** Give the user their capture list. They capture while Tasks 5–9 run.

### Task 5: Chapters 1–2 → v1

**Files:** `docs/nosql/build/content_c1_c2.py`.

**Ch.1:**
- context and reasons: "ứng dụng có sẵn" = LedgerMind, a mobile app + a Thymeleaf admin web app, extended under direction 1;
- measurable goals, taken from the frozen NFRs in `facts.md`;
- scope in/out;
- method, technologies with versions;
- **1.6 Kế hoạch dự án:**
  - a) organisation table: Họ tên · MSSV · Vai trò · Phụ trách CSDL;
  - b) task table: Mã · Công việc · Người thực hiện · Bắt đầu · Kết thúc · Sản phẩm bàn giao · Trạng thái, **only from [Q3]**. Do not take people or dates from git: every commit is by one account and on one day. Unknown cells stay yellow.
  - c) SDLC and the reason for it;
  - d) phases with weeks 6/7/11;
  - e) tools;
  - f) test plan, where passing means meeting the NFRs of 3.4.

**Ch.2:**
- overview, history, terms, vs RDBMS, ACID vs BASE, CAP, PACELC;
- distribution: sharding, replication, consistency levels;
- the 4-families table, plus **where Elasticsearch sits**: a search engine with a document-oriented store over a Lucene inverted index. It is outside the 4 families of the course, which is why it counts as "CSDL tự tìm hiểu";
- the systems used, each with its features, install, data structures and main syntax, using the template's own terms:
  - MongoDB: Database/Collection/Document/Field, References, Embedded, Tree Structures, Atomic Operations;
  - Redis: String/Hash/List/Set/Sorted Set;
- §2.5, criteria 1–4, with exactly the template's comparison criteria and cited or measured claims.

- [ ] **Step 1:** Write the module.
- [ ] **Step 2:** Build v1. Run `check_report --chapter 1/2` (exit 0) and render. Expected: Ch.2 is 10–12 pages.
- [ ] **Step 3: Checkpoint.**

### Task 6: Chapter 3 (SRS) → v2

**Files:** `docs/nosql/build/content_c3.py`.
- **3.1:** purpose, readers, scope, definitions, references.
- **3.2:** context diagram; actors; constraints (free tier / single VM, 1 node per DB, Java/Dart); assumptions and dependencies.
- **3.3:**
  - FR table → AP;
  - detailed specs for the main use cases (preconditions, main and alternative flows, postconditions, data read/written per DB);
  - 3.3.1 BPMN with the data noted per step;
  - 3.3.2 use case, activity ×3, sequence ×4, state machine, DFD 0/1.
- **3.4:** the NFR table, frozen in Task 1. Its verification methods are Task 3 measurements, cited test classes or the backup walk-through. App-level latency counts only if JMeter is run; otherwise it stays "mục tiêu".
- **3.5:**
  - a) the 3V table with the source of each count. It includes the **4 data types** paragraph: relational (PG); semi-structured AI documents (Mongo); key-value cache / OTP / sorted-set ranking (Redis); full-text search documents (ES).
  - b) conceptual ERD + data dictionary.
- **3.6:** the AP table (frozen).
- **3.7:** the real screens (S-ids), the API list, hardware/software.
- **3.8:** the traceability matrix FR → AP → structure → TC, using the frozen IDs.
- [ ] Same steps as Task 5 (`--chapter 3`).

### Task 7: Chapter 4 (SDS) → v3

**Files:** `docs/nosql/build/content_c4.py`.

**Frame and architecture:**
- IEEE 1016 frame.
- 4.1 architecture and deployment.
- 4.2 DB choice matrix: data group → DB → reason → options rejected. MongoDB is the analytics copy; the raw JSON stays in PG because of the receipt lifecycle.

**4.3 Redis:**
- key naming `ledgermind:<feature>:...`;
- the key table: pattern, type, example, TTL, AP, commands;
- cache-aside with AFTER_COMMIT eviction, jitter, `allkeys-lru`;
- no persistence and why;
- RDB/AOF and Sentinel/Cluster as designs;
- the Lua scripts, as `code` excerpts.

**4.4 MongoDB:**
- embed vs reference decisions;
- the patterns used (Computed, Extended Reference), with sample documents as `code`;
- the index table (ESR), `$jsonSchema`, the pipelines;
- `explain()` from E1;
- replica set and shard key as design only.

**4.5 Elasticsearch:**
- settings, analyzers, mapping, the real query as `code`;
- consistency: after commit, auto-create off, retry, reindex;
- cluster as design.

**4.6** Cassandra and Neo4j are not used, with the reasons from the 4.2 matrix.

**4.7 Sync:**
- the source of truth per data group;
- after-commit events instead of Outbox, Change Streams or a message queue, and why;
- the loss window when the JVM dies after commit, and how it heals;
- failure handling.

**4.8–4.9:**
- 4.8 the CAP/PACELC table;
- 4.9 security (roles, TLS, `$`-operator injection vs typed Spring Data queries and ES `multi_match`), backup, monitoring (actuator; Prometheus/Grafana as future work).

**4.10–4.12:**
- 4.10 modules and API;
- 4.11 AP → design;
- 4.12 class diagram, `erd_postgres`, entity-mapping table (the annotations actually used).

**4.13 Advanced techniques that are actually in the code**, each with its problem, the code excerpt, the before/after evidence and the test that proves it:
- @Async + @TransactionalEventListener;
- `@Scheduled` index retry;
- **conflict handling:**
  - Lua atomic leaderboard update;
  - Mongo upsert with `$setOnInsert` + unique `receipt_field_uq`;
  - wallet `PESSIMISTIC_WRITE` lock;
  - receipt optimistic lock → 409;
  - idempotent checkout by `clientId`;
- index/ESR, cache-aside;
- realtime per [Q2].

- [ ] Same steps as Task 5 (`--chapter 4`).

### Task 8: Chapters 5–6 → v4

**Files:** `docs/nosql/build/content_c5_c6.py`, `scripts/nosql/sample_data/{ocr_logs,ocr_feedbacks}.json` (`mongoexport --jsonArray` from the demo data in a throwaway container: the Mongo minimum "dữ liệu mẫu dạng JSON").

**Ch.5:**
- 5.1 environment: machine, versions, single-node setup;
- 5.2 create the DBs: `mongodb_init.js`, the ES index, the Redis conventions/TTL;
- 5.3 data: a table with source and counts (demo data vs synthetic);
- 5.4 and 5.5: a Q-xx table (plain-language requirement, DB, command as `code`, the S-id figure, AP). ≥ 10 basic and ≥ 10 advanced, each DB with both kinds;
- 5.6 import/export and backup/restore, as count → delete → restore → count.

**Ch.6:**
- 6.1 architecture;
- 6.2 the connection per DB: the real config/repository excerpts as `code` with file paths, plus connection-error handling;
- 6.3 the 4 groups, with the evidence per [Q4] and the honest note on which actions are REST-only;
- 6.4 the results of the 4.13 techniques.

- [ ] Same steps as Task 5 (`--chapter 5`, `--chapter 6`).

### Task 9: Chapters 7–9, barem and self-assessment → v5

**Files:** `docs/nosql/build/content_c7_c9.py`, `docs/nosql/build/barem.py`, `docs/nosql/kich_ban_demo.md`.

**Ch.7:**
- 7.1 TC table from the frozen TC list, with results from the `facts.md` §4 run (date and surefire counts);
- 7.2 performance tables and charts in the template's columns;
- 7.3 degradation: Redis down → PG, ES down → PG search, Mongo down → logged. Each with its proving test and the latency observed. No failover claim;
- 7.4 discussion and limitations.

**Ch.8:**
- results (function · % · note);
- NFR vs measured;
- team activity per [Q3] (completion vs table 1.6, %, how the team worked);
- lessons, future work;
- **the barem table:**
  - one row per criterion 1–10, per Mongo/Redis minimum, "≥1 CSDL tự tìm hiểu", "≥4 loại dữ liệu", SRS/SDS and the files to submit;
  - columns: section(s), evidence, status;
  - criterion 10 is labelled "suy luận từ template (2 điểm), chưa có thang điểm chính thức" unless [Q1] answers it;
  - point values are never presented as official.

**Ch.9:** references in citation order, appendices A–C, and D = the demo script table. That table is also written to `kich_ban_demo.md`, with the 4 parts and timings of the template. Every line names the screen, command or Q-id. The outage demo is `docker compose stop redis`/`elasticsearch` on the user's stack, stating "vẫn trả lời" with the latency observed.

- [ ] Steps as Task 5, then `check_report.py v5` without `--chapter`. Expected: only S-id placeholders and the user's yellow notes remain. `barem.py` exits 0.

### Task 10: Evidence form, captures, final review → final files

**Files:** `docs/nosql/build/fill_minhchung.py` (cell-level XML editing of the form table; images through its own drawing + rels code adapted from `Doc.add_image`/`drawing`), `docs/nosql/build/content_screens.py`.

- [ ] **Step 1:** Fill `38_BaoCaoMinhChung.docx`. Keep the header "HỌC PHẦN DỮ LIỆU NoSQL".
  - Information: title, group code 38, members.
  - Links: source link and "Các liên kết trong báo cáo" per [Q5]; the video link stays yellow.
  - The 7 deliverable rows, with file/path, Đã nộp and Ghi chú:
    - "báo cáo hoạt động nhóm" points to Ch.8 + table 1.6;
    - "tài liệu kiểm thử" points to Ch.7 + the test classes.
  - Team table per [Q3].
  - Section II: problem, actors, main functions + `phan_cap_chuc_nang`, architecture/technology, RDBMS PostgreSQL, NoSQL used with their features, the DB diagrams (`arch_tong_the` + per-DB).
  - **Self-assessment block** (the form title is "… VÀ TỰ ĐÁNH GIÁ"): criterion → evidence → status, from `barem.py`. Self-scores stay yellow for the user.
- [ ] **Step 2:** Swap in every capture the user delivered with `IMAGE_REPLACE (S-xx.png, path, "fit")`.
- [ ] **Step 3:** Run `check_report.py` (no `--chapter`) and `barem.py`. Render both files and run `validate.py`.
- [ ] **Step 4:** Independent review on the most capable model, against the PDF, `facts.md`, the spec, the requirement files and the barem. Apply its fixes and produce the final `38_BaoCao_NoSQL.docx`.
- [ ] **Step 5: Checkpoint.** The user opens both files in Word, updates the fields (Ctrl+A, F9, save) and reviews. Commit the sources on their "ok".

---

## Additions after the user's answers (2026-10-27)

- **[Q1] is answered.** Criterion 10 is 4 × 0.5 points:
  - (a) a complete report with correct spelling and formatting, not copied;
  - (b) a confident presentation that answers the lecturer's questions;
  - (c) on time, with every file: **Word, PowerPoint, source code**;
  - (d) a clear work split and personal responsibility.

  `barem.py` uses these four items instead of the "suy luận" label.
- **[Q2]/[Q4]:** plan 1b (`docs/superpowers/plans/2026-10-27-nosql-admin-web-realtime.md`) runs **before** Task 5. Its effects on this plan:
  - 4.13/6.4 describe the realtime admin events (Redis Pub/Sub + SSE);
  - 6.3 group 2 shows the admin pages (OCR feedback CRUD, rebuild buttons, Mongo backup/restore);
  - Q-41 (Pub/Sub) joins the Q list;
  - mobile push is future work.
- **[Q8]:** the user captures on a separate demo stack. Task 4 also writes `scripts/nosql/demo-stack.sh` (up/down) and its README:
  - Mongo, Redis, ES, Kibana, Elasticvue and RedisInsight;
  - data loaded from `scripts/nosql`;
  - ports bound to 127.0.0.1 only;
  - project name `nosql-demo`, so it never collides with the `finance-*` stack.

### Task 9b: Spelling and originality pass (criterion 10a)

- [ ] **Step 1:** Extract the v5 text, then run a Vietnamese spell and style pass: typos, mixed diacritic encodings (NFC everywhere), double spaces, inconsistent terms (one glossary in `facts.md` §5: e.g. "chỉ mục" vs "index", always "CSDL"). Fix through the content modules, not by hand in the docx.
- [ ] **Step 2: Originality.** All prose is written for this report. Every quoted definition or figure from a source carries its citation, and no paragraph is copied from the thesis docx. Check with a sentence-level overlap script against `KhoaLuan_KLCN175_v9.docx`: report any sentence of 12 or more words that appears in both. Expected: none, or only cited definitions.
- [ ] **Step 3:** Rebuild, then run `check_report.py`. Checkpoint.

### Task 11: PowerPoint deck + defence Q&A (criteria 10b, 10c)

**Files:** `docs/nosql/slides_outline.md`, `docs/nosql/hoi_dap_bao_ve.md` → `Nosql/Nosql_38/38_SlideBaoCao_NoSQL.pptx` (made with the pptx skill; not in git).

- [ ] **Step 1:** Write `slides_outline.md`: 15–20 slides that follow the demo-script timing. Each slide gets its title, 3–5 bullets, the figure (from `docs/nosql/diagrams`, `screenshots`, `bench_*`) and speaker notes. The order:
  1. title + team;
  2. problem and why NoSQL;
  3. architecture;
  4. the DB choice matrix (why MongoDB/Redis/ES, why not Cassandra/Neo4j);
  5. one slide per DB design;
  6. the AP table highlights;
  7. GUI tool (Kibana vs Elasticvue);
  8. demo groups;
  9. advanced techniques + realtime;
  10. benchmarks;
  11. tests;
  12. limitations and future work;
  13. task split;
  14. Q&A.
- [ ] **Step 2:** Build the `.pptx` with the pptx skill: 16:9, a simple consistent theme, Vietnamese text, every figure readable. Render it to PDF with `scratch-lo-render:1` and check each slide visually (no overflow).
- [ ] **Step 3:** Write `hoi_dap_bao_ve.md`: 25–30 likely lecturer questions with short answers, each citing the report section and file. It must cover:
  - why these 3 DBs;
  - why the raw JSON stays in PG;
  - CAP/PACELC per DB;
  - what happens when Redis/ES/Mongo is down;
  - consistency and the after-commit loss window;
  - why Lua, why `$setOnInsert`;
  - ESR index order;
  - why not Cassandra/Neo4j;
  - the ES analyzer for Vietnamese;
  - SSE vs WebSocket;
  - how backup/restore was proven;
  - who did what (per [Q3]);
  - limitations.
- [ ] **Step 4: Checkpoint.** The user reviews the deck and the Q&A. Commit the `.md` sources on their "ok".

Order: **plan 1b first**, then 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 9b → 10 → 11. Every "@63328b7" in this plan means the HEAD of feature/nosql after plan 1b is committed (Task 1 writes that SHA into facts.md).
