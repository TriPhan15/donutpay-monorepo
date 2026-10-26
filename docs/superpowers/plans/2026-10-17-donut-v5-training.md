# Donut V5 Training Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `ai-service/Version5/` (code + corrected labels) and two Kaggle notebooks so the user can relabel `data1` with Gemini + Qwen, train Donut V5, and score V3 against V5 on the same test set.

**Architecture:** `Version5/` is a small, self-contained Python bundle that the user uploads to Kaggle as a dataset. Images are **not** copied: the bundle finds the existing `data1` image folders, either already on Kaggle under `/kaggle/input` or at `ai-service/data1` locally. Corrected labels live only in `Version5/data1/<split>/metadata.jsonl`. A shared `labels.py` holds the field list, jsonl I/O and the comparison rules used by relabeling, merging, training and scoring, so every stage compares values the same way.

**Tech Stack:** Python 3.11, PyTorch, `transformers` (Donut `VisionEncoderDecoderModel`, `Qwen2_5_VLForConditionalGeneration`), `google-genai`, Pydantic v2, `albumentations==2.0.8`, Pillow, pytest.

**Spec:** `docs/superpowers/specs/2026-10-17-donut-v5-training-design.md`

## Global Constraints

- Never modify anything under `ai-service/data1/` (the original labels and images), or `ai-service/requirements.txt`, `ai-service/ai_service.py`, `core-backend/`, `mobile-app/`.
- Never run git (`add`, `commit`, ...) — the user commits. The "commit" step of every task is replaced by "stop; the user commits".
- No heavy local execution: never load Donut/Qwen weights, train, or run inference on the user's machine. The only allowed local commands are targeted runs of one test file (`ai-service/venv/bin/python -m pytest ai-service/Version5/tests/<file> -q`) and the light CLI runs named in the tasks.
- Heavy imports (`albumentations`, `cv2`, `google.genai`, `qwen_vl_utils`, Qwen classes) are lazy, inside the function that needs them, so the tests run in the local venv, which does not have those packages.
- The four fields, in this order: `FIELDS = ("SELLER", "ADDRESS", "TIMESTAMP", "TOTAL_COST")`. The Donut tags stay as in V3: `SELLER→seller_name`, `ADDRESS→address`, `TIMESTAMP→timestamp`, `TOTAL_COST→total_cost`. The task token stays `<s_seller>`.
- Every image is opened as `ImageOps.exif_transpose(Image.open(p)).convert("RGB")`, the same as `ai_service.py:85`.
- Start model: `naver-clova-ix/donut-base-finetuned-cord-v2`. Do not fine-tune from V3.
- The Gemini API key is read from Kaggle Secrets `GEMINI_API_KEY`, falling back to the env var `GEMINI_API_KEY`. It is never written to a file, a log or a notebook output.
- Type hints everywhere. Model replies are parsed with Pydantic (`model_validate_json`), never with regex or manual `json.loads` field picking.
- Log/print messages and code comments in Vietnamese; identifiers in English (repo convention).
- Checkpoints are chosen on `validation/` only; `test/` is used for the final scoring only.

## Review Focus

1. **Overwriting labels the user already corrected:** running `init_labels.py` again after a merge or a review must not replace `Version5/data1/<split>/metadata.jsonl` (test in Task 1).
2. **A model reply that is not clean JSON** (markdown fences, a number instead of a string, `null`, extra keys, truncated text): it must be cached as an *error* and retried on the next run, never recorded as "field empty" (test in Task 3).
3. **Gemini daily quota running out halfway through a split:** the run stops cleanly, keeps every answer already cached, and the next run skips the files that are done (test in Task 3).
4. **The same amount written differently** (`"33,000VND"`, `"33.000 đ"`, `"70,000.00"`, `"Tổng tiền: 387,000"`): it must compare as equal in merging and scoring, and `"70,000.00"` must not become 7,000,000 (test in Task 1).
5. **A label too long for `MAX_LENGTH` once tokenized:** training must stop with the file name instead of silently truncating the closing tags (test in Task 6).

---

## File Structure

All new files go in `ai-service/Version5/`:

| File | Responsibility |
|------|----------------|
| `labels.py` | `FIELDS`, `SPLITS`, `Record`, jsonl load/dump, `normalize_text`, `money_value`, `fields_match`, `read_image` |
| `paths.py` | where the bundle, labels and images live (Kaggle vs local) |
| `init_labels.py` | first copy of the original `metadata.jsonl` into `Version5/data1/` (never overwrites) |
| `check_data.py` | checks one split: json parses, every image opens, empty-field counts |
| `relabel_common.py` | `ReceiptFields`, prompt, reply parsing, answer cache, resumable reading loop |
| `relabel_gemini.py` | Gemini reader + CLI |
| `relabel_qwen.py` | Qwen2.5-VL reader + CLI |
| `merge_labels.py` | per-field merge rules, writes new metadata + `review.csv` + report |
| `review_labels.py` | local terminal tool to settle `review.csv` rows |
| `find_v3_seen.py` | writes `v3_seen_test.txt` (test images V3 probably trained on) |
| `model_config.py` | constants, tokenizer setup/check, target building with masking, `DonutDataset`, `collate_fn` |
| `postprocess.py` | verbatim copy of `clean_vietnamese_text` (for scoring V3 only) |
| `evaluate.py` | `Predictor`, scoring, subsets, comparison CLI |
| `train_model.py` | trainer with generation-based checkpoint choice, dry run, resume |
| `tests/` | one pytest file per module above |

Notebooks: `ai-service/relabel-v5.ipynb` and `ai-service/donut-v5.ipynb`. The old `ai-service/donut-tranformer.ipynb`, `model_config.py` and `train_model.py` are left untouched.

**A change from the spec, decided by Claude:** the spec says to hard-link the 13 GB of images into `Version5/data1`. This plan uses the images that already exist (on Kaggle, the dataset holding `data1` the user uploaded before; locally, `ai-service/data1`), so a new label version is a small upload instead of 13 GB. Point this out to the user at handoff.

---

### Task 1: Shared labels module, paths, first label copy

**Files:**
- Create: `ai-service/Version5/labels.py`, `ai-service/Version5/paths.py`, `ai-service/Version5/init_labels.py`
- Test: `ai-service/Version5/tests/test_labels.py`, `ai-service/Version5/tests/conftest.py` (puts `Version5/` on `sys.path`)

**Interfaces:**
- Produces (`labels.py`):
  - `FIELDS: tuple[str, ...]`, `SPLITS = ("train", "validation", "test")`
  - `@dataclass Record: file_name: str; fields: dict[str, str]; unverified: list[str] = field(default_factory=list)`
  - `load_metadata(path: Path) -> list[Record]`: accepts upper- and lower-case keys and stores them upper-case; missing fields become `""`; a bad line raises `LabelError(f"{path}:{line_no}: ...")`
  - `dump_metadata(records: list[Record], path: Path) -> None`: one line per record, `{"file_name", "ground_truth": json.dumps({"gt_parse": fields}, ensure_ascii=False)}`, plus `"unverified_fields"` only when it is non-empty. Writes to `path.with_suffix(".tmp")` then `os.replace`.
  - `normalize_text(s: str) -> str`: NFC, lowercase, collapse whitespace, strip
  - `money_value(s: str) -> int | None`
  - `fields_match(field: str, a: str, b: str) -> bool`: `TOTAL_COST` compares `money_value` (falling back to `normalize_text` when both are `None`); the other fields compare `normalize_text`
  - `read_image(path: Path) -> PIL.Image.Image`
  - `LONG_RATIO = 2.2`; `image_hw(path: Path) -> tuple[int, int]`: (height, width) after EXIF orientation, read from the header without decoding pixels (orientation 5–8 swaps them); `is_long(path: Path) -> bool` = height/width > `LONG_RATIO`
- Produces (`paths.py`):
  - `BUNDLE_DIR: Path` (the folder of `paths.py`), `LABEL_ROOT = BUNDLE_DIR / "data1"`
  - `find_image_root(probe: tuple[str, str]) -> Path`: `probe = (split, file_name)`. Searches `/kaggle/input` when it exists, otherwise `BUNDLE_DIR.parent / "data1"`, and returns the folder that contains `<split>/<file_name>`. Raises `FileNotFoundError` naming the probe.
  - `IS_KAGGLE: bool`, `WORK_DIR: Path` (`/kaggle/working` on Kaggle, `BUNDLE_DIR` locally)
- Produces (`init_labels.py`): `init_labels(src_root: Path, dst_root: Path) -> list[str]` copies `<split>/metadata.jsonl` with `shutil.copyfile`, **only when the destination is missing**, and returns the splits it copied. The CLI runs it with `ai-service/data1` → `LABEL_ROOT`.

`money_value` algorithm (the tests pin it): take every `\d[\d.,]*` match. In each match, a trailing `[.,]\d{2}` that is not followed by another digit is a cents part and is dropped; the remaining `.` and `,` are removed. Return the largest integer, or `None` when there are no digits.

- [ ] **Step 1: Write the failing tests**

```python
def test_money_value_variants():
    assert money_value("33,000VND") == 33000
    assert money_value("33.000 đ") == 33000
    assert money_value("70,000.00") == 70000
    assert money_value("99,999.99") == 99999
    assert money_value("Tổng tiền : 387,000") == 387000
    assert money_value("1,234,567") == 1234567
    assert money_value("Tổng tiền :") is None

def test_fields_match_rules():
    assert fields_match("TOTAL_COST", "50,000", "50.000đ")
    assert not fields_match("TOTAL_COST", "50,000", "5,000")
    assert fields_match("SELLER", "  Circle  K ", "circle k")
    assert not fields_match("SELLER", "Circle K", "")
    assert fields_match("ADDRESS", "", "")

def test_load_metadata_lowercase_keys_and_missing(tmp_path):
    p = tmp_path / "m.jsonl"
    p.write_text('{"file_name":"a.jpg","ground_truth":"{\\"gt_parse\\":{\\"seller\\":\\"X\\"}}"}\n', encoding="utf-8")
    [r] = load_metadata(p)
    assert r.fields == {"SELLER": "X", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": ""}

def test_load_metadata_bad_line_names_line(tmp_path):
    p = tmp_path / "m.jsonl"; p.write_text("{oops\n", encoding="utf-8")
    with pytest.raises(LabelError, match=r"m.jsonl:1"):
        load_metadata(p)

def test_dump_roundtrip_keeps_unverified(tmp_path):
    rec = Record("a.jpg", {"SELLER": "Ố", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "1"}, ["ADDRESS"])
    dump_metadata([rec], tmp_path / "m.jsonl")
    assert load_metadata(tmp_path / "m.jsonl") == [rec]
    assert "Ố" in (tmp_path / "m.jsonl").read_text(encoding="utf-8")   # ensure_ascii=False

def test_init_labels_never_overwrites(tmp_path):
    src, dst = tmp_path / "src", tmp_path / "dst"
    for s in SPLITS:
        (src / s).mkdir(parents=True); (src / s / "metadata.jsonl").write_text("orig\n")
    assert init_labels(src, dst) == list(SPLITS)
    (dst / "test" / "metadata.jsonl").write_text("corrected\n")
    assert init_labels(src, dst) == []
    assert (dst / "test" / "metadata.jsonl").read_text() == "corrected\n"
    assert (dst / "test" / "metadata.jsonl").stat().st_nlink == 1

def test_read_image_applies_exif(tmp_path):
    # Save a 20x10 JPEG with EXIF Orientation=6; read_image must return 10x20 RGB.
    ...

def test_image_hw_and_is_long(tmp_path):
    # 100x300 (w x h) plain -> (300, 100), long; 300x100 with Orientation=6 -> (300, 100), long; 300x100 plain -> not long
    ...
```

- [ ] **Step 2: Run them and see them fail**

Run: `ai-service/venv/bin/python -m pytest ai-service/Version5/tests/test_labels.py -q`
Expected: FAIL (ImportError, `labels` not defined)

- [ ] **Step 3: Implement `labels.py`, `paths.py` and `init_labels.py` with the interfaces above**

- [ ] **Step 4: Run the tests and see them pass**

Run: same command. Expected: all PASS.

- [ ] **Step 5: Run the first copy for real (light)**

Run: `ai-service/venv/bin/python ai-service/Version5/init_labels.py`
Expected: it prints the 3 copied splits; `ai-service/Version5/data1/{train,validation,test}/metadata.jsonl` exist; `git status` shows nothing changed under `ai-service/data1/`.

- [ ] **Step 6: Stop; the user commits.**

---

### Task 2: Data check

**Files:**
- Create: `ai-service/Version5/check_data.py`
- Test: `ai-service/Version5/tests/test_check_data.py`

**Interfaces:**
- Consumes: `load_metadata`, `read_image`, `FIELDS`, `LABEL_ROOT`, `find_image_root`
- Produces:
  - `@dataclass SplitReport: split: str; rows: int; missing: list[str]; unreadable: list[str]; unlabeled: list[str]; empty_counts: dict[str, int]; unverified_counts: dict[str, int]` and `ok` (property: `not missing and not unreadable`)
  - `check_split(split: str, label_root: Path, image_root: Path, open_images: bool = True) -> SplitReport`. The "unlabeled" list counts image files (`.jpg/.jpeg/.png`, case-insensitive) that have no row.
  - `main(argv: list[str] | None = None) -> int`: checks every split, prints one Vietnamese summary per split and the first 20 bad file names, returns `1` if any split is not `ok`. `--no-open` only checks that files exist.

- [ ] **Step 1: Write the failing tests**

```python
def test_reports_missing_and_unreadable(tmp_path):
    # labels: a.jpg (valid image), b.jpg (absent), c.jpg (text bytes); extra image d.png without a row
    rep = check_split("train", label_root, image_root)
    assert rep.missing == ["b.jpg"] and rep.unreadable == ["c.jpg"]
    assert rep.unlabeled == ["d.png"] and not rep.ok

def test_empty_counts(tmp_path):
    # two rows: one with ADDRESS "" and one fully filled
    assert check_split(...).empty_counts == {"SELLER": 0, "ADDRESS": 1, "TIMESTAMP": 0, "TOTAL_COST": 0}

def test_main_exit_code(tmp_path, monkeypatch):
    assert main(["--label-root", str(bad_root), "--image-root", str(img_root)]) == 1
```

- [ ] **Step 2: Run them and see them fail.** `... -m pytest ai-service/Version5/tests/test_check_data.py -q`
- [ ] **Step 3: Implement `check_data.py`**
- [ ] **Step 4: Run them and see them pass**
- [ ] **Step 5: Light real check:** `ai-service/venv/bin/python ai-service/Version5/check_data.py --no-open`. Expected: exit code 0, about 5081/635/636 rows, 0 missing.
- [ ] **Step 6: Stop; the user commits.**

---

### Task 3: Shared relabel core (prompt, parsing, cache, resumable loop)

**Files:**
- Create: `ai-service/Version5/relabel_common.py`
- Test: `ai-service/Version5/tests/test_relabel_common.py`

**Interfaces:**
- Consumes: `Record`, `FIELDS`, `load_metadata`
- Produces:
  - `class ReceiptFields(BaseModel)`: `SELLER: str = ""`, `ADDRESS: str = ""`, `TIMESTAMP: str = ""`, `TOTAL_COST: str = ""`; `model_config = ConfigDict(extra="ignore")`; a `field_validator("*", mode="before")` turns `None` into `""` and numbers into `str`; `def as_dict(self) -> dict[str, str]`
  - `class ReplyParseError(ValueError)` and `class QuotaExhausted(RuntimeError)`
  - `select_examples(records: list[Record], k: int = 4) -> list[Record]`: rows with all 4 fields filled, sorted by `file_name`, the first `k`; a deterministic pick
  - `build_prompt(examples: list[Record]) -> str`: Vietnamese instructions. Copy every field exactly as printed. `TOTAL_COST` is only the final amount to pay, digits and separators as printed with no label text (e.g. `"50,000"`). `TIMESTAMP` is copied as printed. A field missing from the receipt is `""`. Answer only with a JSON object with the 4 keys. Then the `k` examples as JSON (values only, no images).
  - `parse_reply(text: str) -> ReceiptFields`: strip a surrounding ```` ```json ... ``` ```` fence, then `ReceiptFields.model_validate_json`. Any failure raises `ReplyParseError`.
  - `load_cache(path: Path) -> dict[str, ReceiptFields]`: successful answers only; with duplicate lines, the last one wins
  - `select_targets(records: list[Record], scope: Literal["all", "with_empty"]) -> list[Record]`
  - `run_reader(read: Callable[[Path], str], records: list[Record], image_root: Path, split: str, cache_path: Path, scope: Literal["all", "with_empty"], limit: int | None = None) -> RunSummary`. `RunSummary` is a dataclass: `done: int`, `skipped: int`, `errors: int`, `stopped: str | None`. Each answer is appended at once and flushed to `cache_path` as `{"file_name", "fields": {...}}` or `{"file_name", "error": "<msg>"}`. Files already successful in the cache are skipped. `ReplyParseError` and any other per-image exception are recorded as errors and the loop goes on. `QuotaExhausted` stops the loop (`stopped="quota"`) after flushing. Every 50 images, print progress.

- [ ] **Step 1: Write the failing tests**

```python
def test_parse_reply_fenced_and_coerced():
    r = parse_reply('```json\n{"SELLER": "CIRCLE K", "TOTAL_COST": 33000, "ADDRESS": null, "extra": 1}\n```')
    assert r.as_dict() == {"SELLER": "CIRCLE K", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "33000"}

@pytest.mark.parametrize("bad", ["", "không đọc được", '{"SELLER": "x"', "[1,2]"])
def test_parse_reply_rejects(bad):
    with pytest.raises(ReplyParseError):
        parse_reply(bad)

def test_run_reader_records_errors_not_empty(tmp_path):
    # reader returns garbage for b.jpg
    s = run_reader(fake_read, recs, img_root, "test", cache, "all")
    assert s.errors == 1 and "b.jpg" not in load_cache(cache)

def test_run_reader_resumes_and_retries_errors(tmp_path):
    run_reader(read_fails_on_b, ...); calls.clear()
    run_reader(read_ok, ...)
    assert calls == ["b.jpg"]          # a.jpg skipped, b.jpg retried

def test_quota_stops_and_keeps_cache(tmp_path):
    # reader raises QuotaExhausted on the 2nd image of 3
    s = run_reader(...)
    assert s.stopped == "quota" and list(load_cache(cache)) == ["a.jpg"]

def test_select_targets_with_empty():
    assert [r.file_name for r in select_targets(recs, "with_empty")] == ["has_empty.jpg"]

def test_select_examples_deterministic_and_full():
    ex = select_examples(recs, k=2)
    assert all(all(v for v in r.fields.values()) for r in ex) and ex == select_examples(list(reversed(recs)), k=2)
```

- [ ] **Step 2: Run them and see them fail.** `... -m pytest ai-service/Version5/tests/test_relabel_common.py -q`
- [ ] **Step 3: Implement `relabel_common.py`**
- [ ] **Step 4: Run them and see them pass**
- [ ] **Step 5: Stop; the user commits.**

---

### Task 4: Gemini and Qwen readers

**Files:**
- Create: `ai-service/Version5/relabel_gemini.py`, `ai-service/Version5/relabel_qwen.py`
- Test: `ai-service/Version5/tests/test_relabel_readers.py` (covers only the pure parts: key lookup and quota detection; no network, no weights)

**Interfaces:**
- Consumes: `build_prompt`, `select_examples`, `run_reader`, `QuotaExhausted`, `ReceiptFields`, `read_image`, `LABEL_ROOT`, `find_image_root`, `WORK_DIR`
- Produces (`relabel_gemini.py`):
  - `GEMINI_MODEL: str`: before writing it, open https://ai.google.dev/gemini-api/docs/models and https://ai.google.dev/gemini-api/docs/rate-limits, pick the newest **Flash** model offered on the free tier, and write its id and free-tier requests-per-day in a comment next to the constant. `--model` overrides it.
  - `get_api_key() -> str`: `kaggle_secrets.UserSecretsClient().get_secret("GEMINI_API_KEY")` when importable, otherwise `os.environ["GEMINI_API_KEY"]`, otherwise `RuntimeError` with a Vietnamese message pointing to Add-ons → Secrets. Never print the key.
  - `is_daily_quota_error(exc: Exception) -> bool`: true for HTTP 429 / `RESOURCE_EXHAUSTED` whose message mentions a per-day quota
  - `make_gemini_reader(api_key: str, model: str, prompt: str) -> Callable[[Path], str]`: `google.genai.Client`, image bytes plus the prompt, `config={"response_mime_type": "application/json", "response_schema": ReceiptFields, "temperature": 0}`. A per-minute 429 waits (`retryDelay` from the error, or 30 s) and retries up to 5 times. A daily-quota error raises `QuotaExhausted`.
  - CLI: `--split {test,validation,train}`, `--scope {all,with_empty}` (default `all` for test/validation and `with_empty` for train), `--limit N`, `--model`. Cache file: `WORK_DIR / "relabel_cache" / f"{split}.gemini.jsonl"`.
- Produces (`relabel_qwen.py`):
  - `QWEN_MODEL = "Qwen/Qwen2.5-VL-7B-Instruct"`, `QWEN_MAX_PIXELS = 1600 * 28 * 28`
  - `make_qwen_reader(prompt: str) -> Callable[[Path], str]`: `Qwen2_5_VLForConditionalGeneration.from_pretrained(QWEN_MODEL, torch_dtype=torch.float16, device_map="auto")` (spread over the 2 T4s), `AutoProcessor` with `max_pixels=QWEN_MAX_PIXELS`, chat template with the image plus the prompt, greedy decoding, `max_new_tokens=256`, returns the decoded text of the new tokens only
  - CLI: same flags as Gemini. Cache file `... f"{split}.qwen.jsonl"`.

- [ ] **Step 1: Write the failing tests**

```python
def test_get_api_key_from_env(monkeypatch):
    monkeypatch.setenv("GEMINI_API_KEY", "k"); assert get_api_key() == "k"

def test_get_api_key_missing(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    with pytest.raises(RuntimeError, match="Secrets"):
        get_api_key()

def test_daily_quota_detection():
    assert is_daily_quota_error(FakeApiError(429, "Quota exceeded for metric ... per_day"))
    assert not is_daily_quota_error(FakeApiError(429, "... per minute"))
    assert not is_daily_quota_error(ValueError("x"))
```

- [ ] **Step 2: Run them and see them fail.** `... -m pytest ai-service/Version5/tests/test_relabel_readers.py -q`
- [ ] **Step 3: Implement both modules (lazy imports for `google.genai`, `kaggle_secrets`, `transformers` Qwen classes, `qwen_vl_utils`)**
- [ ] **Step 4: Run them and see them pass.** Do **not** call either reader locally.
- [ ] **Step 5: Stop; the user commits.**

---

### Task 5: Merge and review

**Files:**
- Create: `ai-service/Version5/merge_labels.py`, `ai-service/Version5/review_labels.py`
- Test: `ai-service/Version5/tests/test_merge_labels.py`, `ai-service/Version5/tests/test_review_labels.py`

**Interfaces:**
- Consumes: `Record`, `FIELDS`, `fields_match`, `load_metadata`, `dump_metadata`, `load_cache`, `ReceiptFields`, `LABEL_ROOT`, `WORK_DIR`, `find_image_root`, `read_image`
- Produces (`merge_labels.py`):
  - `Status = Literal["kept", "agree", "review", "unchecked"]`
  - `@dataclass Decision: value: str; status: Status`
  - `decide_field(field: str, old: str, gemini: str | None, qwen: str | None) -> Decision`. `None` means that model has no answer for the image. Rules, in order:
    1. `gemini is None and qwen is None` → `Decision(old, "unchecked")`
    2. `old != ""` and `gemini is not None` and `fields_match(field, old, gemini)` → `Decision(old, "kept")` (keeps the user's spelling)
    3. `gemini is not None and qwen is not None and fields_match(field, gemini, qwen)` → `Decision(gemini, "agree")` (also covers both `""`: a confirmed-empty field)
    4. `gemini is None` and `old != ""` and `qwen is not None` and `fields_match(field, old, qwen)` → `Decision(old, "kept")`
    5. otherwise → `Decision(old, "review")`
  - `merge_split(records: list[Record], gemini: dict[str, ReceiptFields], qwen: dict[str, ReceiptFields]) -> tuple[list[Record], list[ReviewRow], dict[str, dict[Status, int]]]`. `ReviewRow` is a dataclass: `file_name`, `field`, `old`, `gemini`, `qwen`. Each new `Record.unverified` lists the fields whose decision is `review` or `unchecked` **and** whose value is `""`.
  - CLI `--split`: reads the 2 caches from `WORK_DIR / "relabel_cache"` and the labels from `LABEL_ROOT / split / "metadata.jsonl"`. Writes the labels back with `dump_metadata`, writes `WORK_DIR / "relabel" / f"{split}.review.csv"` (UTF-8 with BOM so Excel shows Vietnamese), and prints the per-field status table. Rows already settled in `review_done` (see below) are not re-added.
- Produces (`review_labels.py`):
  - `parse_answer(raw: str, row: ReviewRow) -> str | None`: `""` (Enter) → `row.gemini`; `"-"` → `""`; `"o"` → `row.old`; `"q"` → `None` (quit); anything else → `raw.strip()`
  - `apply_answer(record: Record, field: str, value: str) -> None`: sets the value and removes `field` from `record.unverified`
  - CLI `--split`: for each pending row in `review.csv`, shows the image (`read_image(...).show()`) and prints old / Gemini / Qwen. After each answer it appends `{"file_name", "field", "value"}` to `WORK_DIR / "relabel" / f"{split}.review_done.jsonl"` and saves the metadata with `dump_metadata`. Rows already in `review_done` are skipped. At the end it prints how many rows are left.

- [ ] **Step 1: Write the failing tests**

```python
@pytest.mark.parametrize("old,g,q,expected", [
    ("Circle K", "CIRCLE K", "x", Decision("Circle K", "kept")),
    ("", "33,000", "33.000", Decision("33,000", "agree")),
    ("", "", "", Decision("", "agree")),
    ("50,000", "60,000", "60,000", Decision("60,000", "agree")),
    ("", "A", "B", Decision("", "review")),
    ("X", None, "X", Decision("X", "kept")),
    ("", None, None, Decision("", "unchecked")),
])
def test_decide_field(old, g, q, expected):
    assert decide_field("TOTAL_COST" if "0" in (g or old or "0") else "SELLER", old, g, q) == expected

def test_merge_split_unverified_only_empty_unsettled():
    new, review, report = merge_split([rec_empty_address_disagree], gem, qwen)
    assert new[0].unverified == ["ADDRESS"] and [r.field for r in review] == ["ADDRESS"]

def test_merge_does_not_readd_settled_rows(tmp_path): ...

def test_parse_answer():
    row = ReviewRow("a.jpg", "SELLER", "old", "gem", "qw")
    assert [parse_answer(x, row) for x in ["", "-", "o", "q", " Mới "]] == ["gem", "", "old", None, "Mới"]

def test_apply_answer_clears_unverified():
    r = Record("a.jpg", {...ADDRESS: ""}, ["ADDRESS"]); apply_answer(r, "ADDRESS", "")
    assert r.unverified == [] and r.fields["ADDRESS"] == ""
```

(Write `test_decide_field` with an explicit `field` column instead of the shortcut above. The shortcut only shows the cases.)

- [ ] **Step 2: Run them and see them fail.** Run both test files.
- [ ] **Step 3: Implement both modules**
- [ ] **Step 4: Run them and see them pass**
- [ ] **Step 5: Stop; the user commits.**

---

### Task 6: Model config: tokenizer, targets with masking, dataset

**Files:**
- Create: `ai-service/Version5/model_config.py`
- Test: `ai-service/Version5/tests/test_model_config.py`

**Interfaces:**
- Consumes: `Record`, `FIELDS`, `load_metadata`, `read_image`, `is_long`
- Produces:
  - Constants: `BASE_MODEL = "naver-clova-ix/donut-base-finetuned-cord-v2"`, `TASK_TOKEN = "<s_seller>"`, `FIELD_TAGS = {"SELLER": "seller_name", "ADDRESS": "address", "TIMESTAMP": "timestamp", "TOTAL_COST": "total_cost"}`, `MAX_LENGTH = 768`, `MIN_ROUNDTRIP = 0.99`, `DEFAULT_IMAGE_SIZE = (1920, 1440)` (height, width), overridable by the env vars `DONUT_IMAGE_HEIGHT` / `DONUT_IMAGE_WIDTH`, through `image_size_from_env() -> tuple[int, int]`
  - `field_tokens() -> list[str]`: the 10 tags `<s_seller>`, `</s_seller>`, `<s_seller_name>`, `</s_seller_name>`, ...
  - `find_unk_chars(tokenizer, texts: Iterable[str]) -> list[str]`: the sorted distinct characters that encode to `tokenizer.unk_token_id`
  - `roundtrip_failures(tokenizer, texts: Iterable[str]) -> list[str]`: texts where `tokenizer.decode(tokenizer(t, add_special_tokens=False).input_ids) != t`
  - `class TokenizerCheckError(RuntimeError)`
  - `setup_model_and_processor(train_texts: list[str], image_size: tuple[int, int]) -> tuple[VisionEncoderDecoderModel, DonutProcessor]`:
    1. Load `BASE_MODEL`.
    2. Add `field_tokens()` as special tokens, plus the `find_unk_chars` result as normal added tokens (`AddedToken(c, normalized=False)`). Print both counts.
    3. Resize the decoder embeddings.
    4. Raise `TokenizerCheckError` (listing the first 20 failures) if `1 - len(failures)/len(texts) < MIN_ROUNDTRIP`.
    5. Set the encoder `image_size`, the processor `size` and `do_align_long_axis=True`, `decoder_start_token_id = id(TASK_TOKEN)` on both the config and the generation config, `pad_token_id`, `eos_token_id`, and `generation_config.max_length = MAX_LENGTH`.
  - `class LabelTooLongError(ValueError)`
  - `build_target(rec: Record, tokenizer) -> tuple[list[int], list[int]]` returns `(decoder_input_ids, labels)`. Algorithm (pinned):
    ```
    segments = [f"<s_{FIELD_TAGS[f]}>{rec.fields[f]}</s_{FIELD_TAGS[f]}>" for f in FIELDS] + ["</s_seller>"]
    full, labels = [], []
    for f, seg in zip(list(FIELDS) + [None], segments):
        ids = tokenizer(seg, add_special_tokens=False).input_ids
        full += ids
        labels += [-100] * len(ids) if (f in rec.unverified and rec.fields[f] == "") else ids
    full.append(eos); labels.append(eos)
    if len(full) > MAX_LENGTH: raise LabelTooLongError(rec.file_name)
    decoder_input_ids = [task_id] + full[:-1]
    return decoder_input_ids, labels
    ```
  - `build_augment()` (lazy `albumentations`, `cv2`), using the 2.x API:
    - `Rotate(limit=10, border_mode=cv2.BORDER_CONSTANT, fill=255, p=0.5)`
    - `RandomBrightnessContrast(p=0.5)`
    - `GaussianBlur(blur_limit=(3, 5), p=0.3)`
    - `MotionBlur(blur_limit=5, p=0.3)`
    - `ImageCompression(quality_range=(40, 90), p=0.4)`
    - `GaussNoise(std_range=(0.04, 0.2), p=0.3)`
  - `class MissingImagesError(FileNotFoundError)`
  - `LONG_REPEAT = 2`
  - `DonutDataset(records: list[Record], image_dir: Path, processor, image_size: tuple[int, int], train: bool, long_repeat: int = 1)`: in `__init__` it raises `MissingImagesError` listing **all** missing files, then builds `self.index: list[int]` in which every record whose image `is_long` appears `long_repeat` times (others once); `__len__ = len(self.index)`; `__getitem__` returns `{"pixel_values", "decoder_input_ids": LongTensor, "labels": LongTensor}`, augmenting only when `train`; there is no fallback image
  - `collate_fn(batch) -> dict`: pads `decoder_input_ids` with `pad_token_id` (stored on the dataset as `collate_fn = partial(collate_fn, pad_id=...)`) and `labels` with `-100`

- [ ] **Step 1: Write the failing tests** (a `FakeTokenizer` maps each tag to one id, each character to its own id and `eos_token_id=2`; one extra test uses the locally cached `naver-clova-ix/donut-base` tokenizer with `local_files_only=True` and is marked `pytest.mark.skipif` when it is not cached)

```python
def test_build_target_shift_and_eos():
    dec, lab = build_target(Record("a.jpg", {"SELLER": "A", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "1"}), fake)
    assert dec[0] == fake.convert_tokens_to_ids(TASK_TOKEN) and dec[1:] == lab[:-1] and lab[-1] == 2

def test_build_target_masks_only_unverified_empty():
    rec = Record("a.jpg", {"SELLER": "A", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "1"}, ["ADDRESS"])
    dec, lab = build_target(rec, fake)
    masked = [i for i, v in enumerate(lab) if v == -100]
    assert len(masked) == 2                     # <s_address></s_address>
    assert -100 not in dec                      # decoder still sees the real tokens

def test_build_target_too_long():
    with pytest.raises(LabelTooLongError, match="a.jpg"):
        build_target(Record("a.jpg", {"SELLER": "x" * 900, ...}), fake)

def test_dataset_lists_all_missing(tmp_path):
    with pytest.raises(MissingImagesError, match="b.jpg.*c.jpg"):
        DonutDataset([rec("a.jpg"), rec("b.jpg"), rec("c.jpg")], dir_with_only_a, proc, (64, 48), train=False)

def test_long_receipts_repeated(tmp_path):
    ds = DonutDataset([rec("short.jpg"), rec("long.jpg")], img_dir, proc, (64, 48), train=True, long_repeat=2)
    assert len(ds) == 3 and sorted(ds.index) == [0, 1, 1]
    assert len(DonutDataset([...same...], img_dir, proc, (64, 48), train=False)) == 2

def test_collate_pads():
    out = collate_fn([{"pixel_values": t, "decoder_input_ids": tensor([5, 6, 7]), "labels": tensor([6, 7, 2])},
                      {"pixel_values": t, "decoder_input_ids": tensor([5]), "labels": tensor([2])}], pad_id=1)
    assert out["decoder_input_ids"][1].tolist() == [5, 1, 1] and out["labels"][1].tolist() == [2, -100, -100]

@skip_unless_cached
def test_real_tokenizer_segments_equal_whole_string():
    # with field tokens added, concatenating per-segment ids == tokenizing the whole target string
```

- [ ] **Step 2: Run them and see them fail.** `... -m pytest ai-service/Version5/tests/test_model_config.py -q`
- [ ] **Step 3: Implement `model_config.py`**
- [ ] **Step 4: Run them and see them pass.** If the real-tokenizer test fails (segment boundaries tokenize differently), stop and report: do not change the masking design on your own.
- [ ] **Step 5: Stop; the user commits.**

---

### Task 7: Scoring and V3/V5 comparison

**Files:**
- Create: `ai-service/Version5/postprocess.py`, `ai-service/Version5/evaluate.py`, `ai-service/Version5/find_v3_seen.py`
- Test: `ai-service/Version5/tests/test_evaluate.py`, `ai-service/Version5/tests/test_find_v3_seen.py`

**Interfaces:**
- Consumes: `FIELDS`, `fields_match`, `normalize_text`, `money_value`, `load_metadata`, `read_image`, `FIELD_TAGS`, `TASK_TOKEN`, `LABEL_ROOT`, `find_image_root`, `BUNDLE_DIR`
- Produces (`postprocess.py`): `clean_vietnamese_text(sequence: str) -> str`, copied verbatim from `ai-service/ai_service.py:49-67`, with a comment saying it is a copy because the Kaggle bundle must be self-contained, and that it is used only for the V3 model.
- Produces (`evaluate.py`):
  - `RELAXED_THRESHOLD = 0.80` (`LONG_RATIO`/`is_long` come from `labels.py`), `CIRCLE_K_TEST = ("00005409.jpg", "00005385.jpg", "00006809.jpg")`
  - `sequence_to_fields(sequence: str, processor, legacy_v3: bool) -> dict[str, str]`: strip eos/pad, apply `clean_vietnamese_text` if `legacy_v3`, run `processor.token2json`, take the `"seller"` dict (when the top level is not nested, use it as is), map the tags back to `FIELDS`. A parse failure gives all fields `""`.
  - `class Predictor(model_dir: Path, legacy_v3: bool, device: str)`: loads `DonutProcessor` and the model from `model_dir`, reads `(height, width)` from `processor.image_processor.size`, `do_align_long_axis=True`; `predict(image) -> dict[str, str]` uses greedy `generate` starting from `TASK_TOKEN`, `max_length=768`
  - `@dataclass FieldScore: exact: int = 0; relaxed: int = 0; sim: float = 0.0; count: int = 0`
  - `score(pairs: list[tuple[dict[str, str], dict[str, str]]], include_empty_gt: bool) -> dict[str, FieldScore]` with the key `"ALL"` as the micro average over the four fields:
    - Exact uses `fields_match`.
    - Similarity uses `SequenceMatcher` on `normalize_text` (for `TOTAL_COST`, on `str(money_value)` when both are not `None`).
    - A field with empty ground truth is skipped when `include_empty_gt=False`; otherwise it counts as exact (sim 1.0) only when the prediction is `""`.
  - `subsets(records, image_root, seen: set[str]) -> dict[str, set[str]]` with the keys `"all"`, `"all_minus_v3_seen"`, `"long"` (`is_long`), `"circle_k"`
  - CLI: `--v3 DIR --v5 DIR [--split test] [--limit N]`. Ground truth: `LABEL_ROOT/<split>/metadata.jsonl` (the corrected labels). Predictions are cached in `WORK_DIR / f"pred_{name}_{split}.jsonl"` (resumable). It writes `WORK_DIR / "compare_{split}.csv"` with one row per image and field. It prints a table per subset: rows are `FIELDS + ALL`, columns are V3 and V5 exact / match@80 / sim (main metric), plus a second table with `include_empty_gt=True`. Last line: `V5 THẮNG` when V5's `ALL` exact beats V3's on both `all_minus_v3_seen` and `long`, else `V5 CHƯA THẮNG`.
- Produces (`find_v3_seen.py`):
  - `v3_seen(old_train_metadata: Path, metadata_files: list[Path]) -> list[str]`: file names whose `normalize_text(ADDRESS)` is longer than 15 characters and appears among the ADDRESS values of the old V3 train labels (both lower- and upper-case keys); sorted, without duplicates
  - CLI: unions the original `ai-service/data1/test/metadata.jsonl` and `LABEL_ROOT/test/metadata.jsonl` against `ai-service/data1/train_metadata.jsonl`, writes `BUNDLE_DIR / "v3_seen_test.txt"`, and prints the count

- [ ] **Step 1: Write the failing tests**

```python
def test_sequence_to_fields_v5_shape():
    seq = "<s_seller><s_seller_name>CIRCLE K</s_seller_name><s_address></s_address><s_timestamp>22/02/2023</s_timestamp><s_total_cost>32,000</s_total_cost></s_seller></s>"
    assert sequence_to_fields(seq, fake_processor, legacy_v3=False) == {"SELLER": "CIRCLE K", "ADDRESS": "", "TIMESTAMP": "22/02/2023", "TOTAL_COST": "32,000"}

def test_sequence_to_fields_garbage_is_empty():
    assert set(sequence_to_fields("<s_seller><s_seller_na", fake_processor, False).values()) == {""}

def test_score_main_vs_including_empty():
    pairs = [({"SELLER": "A", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "50,000"},
              {"SELLER": "a", "ADDRESS": "bịa", "TIMESTAMP": "", "TOTAL_COST": "50.000đ"})]
    main = score(pairs, include_empty_gt=False)
    assert main["SELLER"].exact == 1 and main["ADDRESS"].count == 0 and main["ALL"].count == 2
    full = score(pairs, include_empty_gt=True)
    assert full["ADDRESS"].exact == 0 and full["TIMESTAMP"].exact == 1 and full["ALL"].count == 4

def test_subsets_long_and_circle_k(tmp_path): ...   # 100x300 image counts as long, 300x100 does not

def test_v3_seen_matches_address_only_when_long(tmp_path):
    # old: ADDRESS "55 Pham Viet Chanh, Quan 1" and "Q1"; new rows: same long address (spacing/case differ), "Q1"
    assert v3_seen(old, [new]) == ["x.jpg"]
```

- [ ] **Step 2: Run them and see them fail.** Run both test files.
- [ ] **Step 3: Implement the three modules**
- [ ] **Step 4: Run them and see them pass**
- [ ] **Step 5: Light real run:** `ai-service/venv/bin/python ai-service/Version5/find_v3_seen.py`. Expected: it writes `ai-service/Version5/v3_seen_test.txt` with about 14 names. Run it again after the test split has been merged (Task 9 runbook).
- [ ] **Step 6: Stop; the user commits.**

---

### Task 8: Training script

**Files:**
- Create: `ai-service/Version5/train_model.py`
- Test: `ai-service/Version5/tests/test_train_model.py` (pure helpers only)

**Interfaces:**
- Consumes: `setup_model_and_processor`, `DonutDataset`, `collate_fn`, `image_size_from_env`, `build_target` (through the dataset), `load_metadata`, `LABEL_ROOT`, `find_image_root`, `WORK_DIR`, `Predictor`-style generation and `score` from `evaluate.py`
- Produces:
  - Constants: `VAL_SUBSET_SIZE = 150`, `SEED = 42`, `CHECKPOINT_DIR = WORK_DIR / "donut_checkpoints"`, `OUTPUT_DIR = WORK_DIR / "donut_result"`
  - `val_subset(records: list[Record], n: int, seed: int) -> list[Record]`: a deterministic `random.Random(seed).sample` over the records sorted by `file_name`
  - `find_resume_checkpoint(roots: list[Path]) -> Path | None`: the `checkpoint-<N>` folder with the highest N under any `donut_checkpoints` folder in `roots` (it searches `CHECKPOINT_DIR` and, on Kaggle, `/kaggle/input/**`)
  - `class ScoringTrainer(Seq2SeqTrainer)`: overrides `evaluate(self, eval_dataset=None, ignore_keys=None, metric_key_prefix="eval") -> dict[str, float]`. It generates greedily on the fixed validation subset (batch 1, `model.eval()`, `torch.no_grad()`, then back to train mode), scores with `score(..., include_empty_gt=False)`, and returns and logs `{"eval_field_exact": ALL exact ratio, "eval_seller_exact": ..., ...}` through `self.log` plus `self.control = self.callback_handler.on_evaluate(...)` so that early stopping and best-model tracking see it.
  - `build_args(dry_run_steps: int | None) -> Seq2SeqTrainingArguments`:
    - `per_device_train_batch_size=1`, `gradient_accumulation_steps=8`
    - `learning_rate=3e-5`, `lr_scheduler_type="cosine"`, `warmup_steps=300`, `num_train_epochs=8`
    - `eval_strategy="steps"`, `eval_steps=400`, `save_steps=400`, `save_total_limit=3`
    - `load_best_model_at_end=True`, `metric_for_best_model="eval_field_exact"`, `greater_is_better=True`
    - `fp16=True`, `gradient_checkpointing=True`, `dataloader_num_workers=2`, `remove_unused_columns=False`, `report_to="none"`, `seed=SEED`, `logging_steps=20`
    - With `dry_run_steps`: `max_steps=dry_run_steps`, `eval_strategy="no"`, `save_strategy="no"`, `load_best_model_at_end=False`
  - `EarlyStoppingCallback(early_stopping_patience=4)`
  - `train() -> None`:
    1. Load the train and validation labels from `LABEL_ROOT`, and the images through `find_image_root`.
    2. Run `setup_model_and_processor(train_texts=[all field values of train], image_size=image_size_from_env())`.
    3. Build the datasets: train with `long_repeat=LONG_REPEAT`, validation subset with the default `1`.
    4. Resume from `find_resume_checkpoint` when it finds one (copying an input checkpoint into `CHECKPOINT_DIR` first, because `/kaggle/input` is read-only).
    5. Train, then save the best model and the processor to `OUTPUT_DIR`.
  - Dry run: env `DONUT_DRY_RUN_STEPS=20` runs that many optimizer steps, then prints `torch.cuda.max_memory_allocated()` in GB, seconds per optimizer step, and the estimated hours per epoch (`len(train_dataset) / 8 * sec_per_step / 3600`, counting the repeated long receipts) and per 8 epochs, in Vietnamese, and exits without saving.

- [ ] **Step 1: Write the failing tests**

```python
def test_val_subset_deterministic():
    a = val_subset(recs, 3, 42); b = val_subset(list(reversed(recs)), 3, 42)
    assert a == b and len(a) == 3

def test_find_resume_checkpoint_picks_highest(tmp_path):
    for n in (400, 1200, 800): (tmp_path / "x" / "donut_checkpoints" / f"checkpoint-{n}").mkdir(parents=True)
    assert find_resume_checkpoint([tmp_path]).name == "checkpoint-1200"
    assert find_resume_checkpoint([tmp_path / "empty"]) is None

def test_build_args_dry_run():
    a = build_args(20)
    assert a.max_steps == 20 and a.save_strategy == "no" and not a.load_best_model_at_end
    b = build_args(None)
    assert b.metric_for_best_model == "eval_field_exact" and b.greater_is_better
```

- [ ] **Step 2: Run them and see them fail.** `... -m pytest ai-service/Version5/tests/test_train_model.py -q` (`transformers` is in the local venv; `build_args` only builds the arguments object)
- [ ] **Step 3: Implement `train_model.py`**
- [ ] **Step 4: Run them and see them pass.** Do **not** call `train()` locally.
- [ ] **Step 5: Stop; the user commits.**

---

### Task 9: Kaggle notebooks and runbook

**Files:**
- Create: `ai-service/relabel-v5.ipynb`, `ai-service/donut-v5.ipynb`, `ai-service/Version5/README.md`
- Test: a structural check, `ai-service/Version5/tests/test_notebooks.py` (loads both `.ipynb` as JSON and asserts the cell order below, the `pip` pins, and that the text `GEMINI_API_KEY=` never appears)

**Interfaces:**
- Consumes: every CLI above.
- Both notebooks start with a cell that finds the bundle (`/kaggle/input/**/Version5/paths.py`, or any folder that contains `paths.py` and `labels.py`), copies it to `/kaggle/working/Version5` (the input is read-only), and `chdir`s there. If a previous run's `relabel_cache`, `relabel` or `donut_checkpoints` folder is in `/kaggle/input`, it is copied into `/kaggle/working` too.
- `relabel-v5.ipynb` (Accelerator GPU T4×2, Internet on, Secret `GEMINI_API_KEY` attached), in this order:
  1. `pip install -q google-genai "transformers>=4.49" accelerate qwen-vl-utils`
  2. locate and copy the bundle
  3. `python check_data.py --no-open`
  4. Gemini on `test`, then `validation`, then `train` (each stops cleanly on quota; re-running the notebook later continues)
  5. Qwen on the same three splits
  6. zip `relabel_cache` to `/kaggle/working/relabel_cache.zip`
- `donut-v5.ipynb` (GPU T4, `CUDA_VISIBLE_DEVICES=0`), in this order:
  1. `pip install -q "albumentations==2.0.8" accelerate`
  2. locate and copy the bundle
  3. `python check_data.py` (exit ≠ 0 stops the notebook with `raise SystemExit`)
  4. dry run with `DONUT_DRY_RUN_STEPS=20`, `DONUT_IMAGE_HEIGHT/WIDTH` set in the cell (default 1920/1440, with a markdown note listing the alternatives 2560/1920 and 1280/960)
  5. full training with the same size env vars
  6. comparison: `python evaluate.py --v3 <dir found under /kaggle/input containing donut_result/config.json from Version3> --v5 /kaggle/working/donut_result`
  7. zip `donut_result` and `donut_checkpoints` separately
- `README.md` (Vietnamese) is the user runbook:
  1. Locally: `init_labels.py` (already run in Task 1).
  2. Upload `Version5/` as a new Kaggle dataset, add the existing `data1` image dataset and the V3 `donut_result` dataset, add the secret.
  3. Run `relabel-v5.ipynb`, download `relabel_cache.zip`, and unzip it into `ai-service/Version5/relabel_cache/`.
  4. Locally, per split (test first): `merge_labels.py --split test`, then `review_labels.py --split test`.
  5. Run `find_v3_seen.py` again after the test split is settled.
  6. Upload a new version of the `Version5` dataset.
  7. Run `donut-v5.ipynb`: dry run first, then pick the size, then train.
  8. If Kaggle stops the session: save the notebook version, add its output as input, and run it again (it resumes).
  9. Send the comparison table back.

  It also says that the training labels in `train/` that are still unsettled are masked, so training does not have to wait for the full review.

- [ ] **Step 1: Write `test_notebooks.py`** (asserts the cell order above by looking for the commands, `albumentations==2.0.8`, `DONUT_DRY_RUN_STEPS=20`, and no `GEMINI_API_KEY=`)
- [ ] **Step 2: Run it and see it fail**
- [ ] **Step 3: Write the two notebooks (no outputs saved) and `README.md`**
- [ ] **Step 4: Run the structural test and see it pass**
- [ ] **Step 5: Run every test file under `ai-service/Version5/tests/` one by one** (each a separate `pytest <file> -q` command) and report the counts.
- [ ] **Step 6: Stop; the user commits.**

---

## Out of this plan (follow-up, gated on results)

Switching `ai-service/ai_service.py` to V5 (reading the image size from the model's `processor_config.json`, and dropping `clean_vietnamese_text` for V5) happens only after the user reports `V5 THẮNG`. It is its own task with its own update of `test_main.py`.
