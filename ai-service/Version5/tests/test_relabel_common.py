import pytest

from labels import Record
from relabel_common import (
    QuotaExhausted,
    ReplyParseError,
    build_prompt,
    load_cache,
    parse_reply,
    run_reader,
    select_examples,
    select_targets,
)

GOOD = '{"SELLER": "S", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "1"}'


def _rec(name, **kw):
    fields = {"SELLER": "S", "ADDRESS": "A", "TIMESTAMP": "T", "TOTAL_COST": "1"}
    fields.update(kw)
    return Record(name, fields)


def test_parse_reply_fenced_and_coerced():
    r = parse_reply('```json\n{"SELLER": "CIRCLE K", "TOTAL_COST": 33000, "ADDRESS": null, "TIMESTAMP": "", "extra": 1}\n```')
    assert r.as_dict() == {"SELLER": "CIRCLE K", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "33000"}


@pytest.mark.parametrize("bad", ["", "không đọc được", '{"SELLER": "x"', "[1,2]"])
def test_parse_reply_rejects(bad):
    with pytest.raises(ReplyParseError):
        parse_reply(bad)


def _reader(calls, fail_on=(), quota_on=()):
    def read(path):
        calls.append(path.name)
        if path.name in quota_on:
            raise QuotaExhausted("hết quota")
        if path.name in fail_on:
            return "xin lỗi, tôi không đọc được"
        return GOOD
    return read


def test_run_reader_records_errors_not_empty(tmp_path):
    cache = tmp_path / "c.jsonl"
    s = run_reader(_reader([], fail_on={"b.jpg"}), [_rec("a.jpg"), _rec("b.jpg")], tmp_path, "test", cache, "all")
    assert s.errors == 1 and s.done == 1
    assert list(load_cache(cache)) == ["a.jpg"]


def test_run_reader_resumes_and_retries_errors(tmp_path):
    cache = tmp_path / "c.jsonl"
    recs = [_rec("a.jpg"), _rec("b.jpg")]
    run_reader(_reader([], fail_on={"b.jpg"}), recs, tmp_path, "test", cache, "all")
    calls: list[str] = []
    s = run_reader(_reader(calls), recs, tmp_path, "test", cache, "all")
    assert calls == ["b.jpg"] and s.skipped == 1
    assert sorted(load_cache(cache)) == ["a.jpg", "b.jpg"]


def test_quota_stops_and_keeps_cache(tmp_path):
    cache = tmp_path / "c.jsonl"
    calls: list[str] = []
    recs = [_rec("a.jpg"), _rec("b.jpg"), _rec("c.jpg")]
    s = run_reader(_reader(calls, quota_on={"b.jpg"}), recs, tmp_path, "test", cache, "all")
    assert s.stopped == "quota" and calls == ["a.jpg", "b.jpg"]
    assert list(load_cache(cache)) == ["a.jpg"]


def test_run_reader_limit(tmp_path):
    calls: list[str] = []
    run_reader(_reader(calls), [_rec("a.jpg"), _rec("b.jpg")], tmp_path, "test", tmp_path / "c.jsonl", "all", limit=1)
    assert calls == ["a.jpg"]


def test_select_targets_with_empty():
    recs = [_rec("full.jpg"), _rec("has_empty.jpg", ADDRESS="")]
    assert [r.file_name for r in select_targets(recs, "with_empty")] == ["has_empty.jpg"]
    assert len(select_targets(recs, "all")) == 2


def test_select_examples_deterministic_and_full():
    recs = [_rec("c.jpg"), _rec("a.jpg", SELLER=""), _rec("b.jpg"), _rec("d.jpg")]
    ex = select_examples(recs, k=2)
    assert [r.file_name for r in ex] == ["b.jpg", "c.jpg"]
    assert ex == select_examples(list(reversed(recs)), k=2)


def test_build_prompt_contains_examples_and_rules():
    p = build_prompt([_rec("a.jpg", TOTAL_COST="50,000")])
    assert '"TOTAL_COST": "50,000"' in p and "JSON" in p


@pytest.mark.parametrize("wrong_keys", ['{}', '{"seller": "A"}', '{"gt_parse": {"SELLER": "A"}}'])
def test_parse_reply_rejects_missing_fields(wrong_keys):
    with pytest.raises(ReplyParseError):
        parse_reply(wrong_keys)
