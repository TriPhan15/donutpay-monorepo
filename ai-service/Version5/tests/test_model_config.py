import re
from pathlib import Path
from types import SimpleNamespace

import pytest
import torch
from PIL import Image

from labels import Record
from model_config import (
    TASK_TOKEN,
    DonutDataset,
    LabelTooLongError,
    MissingImagesError,
    build_target,
    collate_fn,
    field_tokens,
    find_unk_chars,
    roundtrip_failures,
)

_TAG = re.compile(r"(</?s_[a-z_]+>)")


class FakeTokenizer:
    eos_token_id, pad_token_id, unk_token_id = 2, 1, 3

    def __init__(self):
        self.vocab = {t: 100 + i for i, t in enumerate(field_tokens())}

    def convert_tokens_to_ids(self, token):
        return self.vocab[token]

    def __call__(self, text, add_special_tokens=False):
        ids = []
        for part in _TAG.split(text):
            if part in self.vocab:
                ids.append(self.vocab[part])
            else:
                ids.extend(self.unk_token_id if ch == "☃" else 1000 + ord(ch) for ch in part)
        return SimpleNamespace(input_ids=ids)

    def decode(self, ids):
        return "".join("?" if i == self.unk_token_id else chr(i - 1000) for i in ids)


class FakeProcessor:
    def __init__(self):
        self.tokenizer = FakeTokenizer()

    def __call__(self, image, return_tensors="pt", **kw):
        return SimpleNamespace(pixel_values=torch.zeros(1, 3, 8, 6))


fake = FakeTokenizer()


def _fields(**kw):
    base = {"SELLER": "A", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": "1"}
    base.update(kw)
    return base


def test_build_target_shift_and_eos():
    dec, lab = build_target(Record("a.jpg", _fields()), fake)
    assert dec[0] == fake.convert_tokens_to_ids(TASK_TOKEN) and dec[1:] == lab[:-1] and lab[-1] == 2
    assert lab[0] == fake.convert_tokens_to_ids("<s_seller_name>")
    assert lab[-2] == fake.convert_tokens_to_ids("</s_seller>")


def test_build_target_masks_only_unverified_empty():
    rec = Record("a.jpg", _fields(), ["ADDRESS"])
    dec, lab = build_target(rec, fake)
    masked = [i for i, v in enumerate(lab) if v == -100]
    assert len(masked) == 2
    assert [dec[i + 1] for i in masked] == [fake.convert_tokens_to_ids("<s_address>"), fake.convert_tokens_to_ids("</s_address>")]
    assert -100 not in dec
    _, lab_filled = build_target(Record("a.jpg", _fields(ADDRESS="X"), ["ADDRESS"]), fake)
    assert -100 not in lab_filled


def test_build_target_too_long():
    with pytest.raises(LabelTooLongError, match="a.jpg"):
        build_target(Record("a.jpg", _fields(SELLER="x" * 900)), fake)


def test_find_unk_chars_and_roundtrip():
    assert find_unk_chars(fake, ["ab☃", "☃c"]) == ["☃"]
    only_word_initial = FakeTokenizer()
    only_word_initial.get_vocab = lambda: {"a": 1, "b": 2, "▁1": 3}
    assert find_unk_chars(only_word_initial, ["QL1A"]) == ["1", "A", "L", "Q"]
    assert roundtrip_failures(fake, ["ab", "x☃"]) == ["x☃"]


def _img_dir(tmp_path, sizes):
    for name, size in sizes.items():
        Image.new("RGB", size).save(tmp_path / name)
    return tmp_path


def test_dataset_lists_all_missing(tmp_path):
    d = _img_dir(tmp_path, {"a.jpg": (10, 10)})
    recs = [Record(n, _fields()) for n in ("a.jpg", "b.jpg", "c.jpg")]
    with pytest.raises(MissingImagesError, match="b.jpg.*c.jpg"):
        DonutDataset(recs, d, FakeProcessor(), (8, 6), train=False)


def test_long_receipts_repeated(tmp_path):
    d = _img_dir(tmp_path, {"short.jpg": (100, 100), "long.jpg": (100, 300)})
    recs = [Record("short.jpg", _fields()), Record("long.jpg", _fields())]
    ds = DonutDataset(recs, d, FakeProcessor(), (8, 6), train=True, long_repeat=2)
    assert len(ds) == 3 and sorted(ds.index) == [0, 1, 1]
    plain = DonutDataset(recs, d, FakeProcessor(), (8, 6), train=False)
    assert len(plain) == 2
    item = plain[0]
    assert set(item) == {"pixel_values", "decoder_input_ids", "labels"}
    assert item["labels"].dtype == torch.long


def test_collate_pads():
    t = torch.zeros(3, 8, 6)
    out = collate_fn([{"pixel_values": t, "decoder_input_ids": torch.tensor([5, 6, 7]), "labels": torch.tensor([6, 7, 2])},
                      {"pixel_values": t, "decoder_input_ids": torch.tensor([5]), "labels": torch.tensor([2])}], pad_id=1)
    assert out["decoder_input_ids"][1].tolist() == [5, 1, 1] and out["labels"][1].tolist() == [2, -100, -100]
    assert out["pixel_values"].shape == (2, 3, 8, 6)


def _cached_tokenizer():
    try:
        from transformers import AutoTokenizer
        return AutoTokenizer.from_pretrained("naver-clova-ix/donut-base", local_files_only=True)
    except Exception:  # noqa: BLE001
        return None


@pytest.mark.skipif(_cached_tokenizer() is None, reason="tokenizer donut-base chưa có trong cache local")
def test_real_tokenizer_segments_equal_whole_string():
    tok = _cached_tokenizer()
    tok.add_tokens(field_tokens(), special_tokens=True)
    rec = Record("a.jpg", {"SELLER": "SIÊU THỊ ĐIỆN MÁY 30-4", "ADDRESS": "40 đg 12 kp5 phường Hiệp Chánh",
                           "TIMESTAMP": "18/12/2020 19:09", "TOTAL_COST": "1,250,000"})
    dec, lab = build_target(rec, tok)
    whole = "".join(f"<s_{t}>{rec.fields[f]}</s_{t}>" for f, t in
                    [("SELLER", "seller_name"), ("ADDRESS", "address"), ("TIMESTAMP", "timestamp"), ("TOTAL_COST", "total_cost")])
    expected = tok(whole + "</s_seller>", add_special_tokens=False).input_ids + [tok.eos_token_id]
    assert lab == expected


@pytest.mark.skipif(_cached_tokenizer() is None, reason="tokenizer donut-base chưa có trong cache local")
def test_extend_unigram_vocab_keeps_vietnamese_spacing(tmp_path):
    from model_config import extend_unigram_vocab

    tok = _cached_tokenizer()
    tok.add_tokens(field_tokens(), special_tokens=True)
    tag_before = tok.convert_ids_to_tokens(tok.convert_tokens_to_ids("<s_address>"))
    texts = ["01 Dương Văn Cam, Q.Thủ Đức, TP.Hồ Chí Minh", "Quốc lộ 1, Tỉnh Phú Yên", "TỔNG CỘNG 1.250.000"]
    chars = find_unk_chars(tok, texts)
    assert chars
    new_tok = extend_unigram_vocab(tok, chars, tmp_path)
    assert find_unk_chars(new_tok, texts) == []
    assert roundtrip_failures(new_tok, texts) == []
    assert new_tok.convert_ids_to_tokens(new_tok.convert_tokens_to_ids("<s_address>")) == tag_before
    assert len(set(new_tok.get_vocab().values())) == len(new_tok)     # no id collisions
