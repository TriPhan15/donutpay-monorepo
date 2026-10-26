"""Cấu hình model Donut V5: tokenizer, chuỗi đích (có che loss trường chưa kiểm tra), dataset và collate."""

import json
import os
from collections.abc import Iterable
from functools import partial
from pathlib import Path

import torch
from torch.utils.data import Dataset

from labels import FIELDS, Record, is_long, read_image

BASE_MODEL = "naver-clova-ix/donut-base-finetuned-cord-v2"
TASK_TOKEN = "<s_seller>"
TASK_END_TOKEN = "</s_seller>"
FIELD_TAGS: dict[str, str] = {
    "SELLER": "seller_name",
    "ADDRESS": "address",
    "TIMESTAMP": "timestamp",
    "TOTAL_COST": "total_cost",
}
MAX_LENGTH = 768
MIN_ROUNDTRIP = 0.99
DEFAULT_IMAGE_SIZE = (1920, 1440)  # (height, width)
LONG_REPEAT = 2
IGNORE_INDEX = -100
MAX_LISTED = 20


class TokenizerCheckError(RuntimeError):
    """Tokenizer không tái tạo được đủ nhãn train sau encode/decode."""


class LabelTooLongError(ValueError):
    """Nhãn dài hơn MAX_LENGTH token: dừng thay vì cắt mất thẻ đóng."""


class MissingImagesError(FileNotFoundError):
    """Có ảnh trong nhãn nhưng không có file."""


def image_size_from_env() -> tuple[int, int]:
    height = int(os.environ.get("DONUT_IMAGE_HEIGHT", DEFAULT_IMAGE_SIZE[0]))
    width = int(os.environ.get("DONUT_IMAGE_WIDTH", DEFAULT_IMAGE_SIZE[1]))
    return height, width


def field_tokens() -> list[str]:
    tokens = [TASK_TOKEN, TASK_END_TOKEN]
    for tag in FIELD_TAGS.values():
        tokens += [f"<s_{tag}>", f"</s_{tag}>"]
    return tokens


def find_unk_chars(tokenizer, texts: Iterable[str]) -> list[str]:
    """Ký tự không có piece riêng trong từ vựng (ví dụ chỉ có "▁1" mà không có "1", nên "QL1A" ra <unk>)."""
    chars = {ch for t in texts for ch in t if not ch.isspace()}
    vocab = tokenizer.get_vocab() if hasattr(tokenizer, "get_vocab") else None
    return sorted(ch for ch in chars
                  if (vocab is not None and ch not in vocab)
                  or tokenizer.unk_token_id in tokenizer(ch, add_special_tokens=False).input_ids)


def roundtrip_failures(tokenizer, texts: Iterable[str]) -> list[str]:
    return [t for t in texts if tokenizer.decode(tokenizer(t, add_special_tokens=False).input_ids) != t]


def _shift_ids(mapping: dict, start: int, by: int) -> dict:
    return {(str(int(k) + by) if int(k) >= start else k): v for k, v in mapping.items()}


def extend_unigram_vocab(tokenizer, chars: list[str], work_dir: Path):
    """Thêm ký tự vào chính bộ từ vựng Unigram (không dùng added token).

    Added token tách câu thành nhiều đoạn, mỗi đoạn lại được SentencePiece thêm "▁" ở đầu,
    nên "Dương" bị giải mã thành "Dươ ng" (lỗi dấu cách của V3). Ký tự nằm trong từ vựng
    thì được cắt chung với phần còn lại của từ nên giữ đúng khoảng trắng.
    """
    from transformers import AutoTokenizer

    work_dir = Path(work_dir)
    tokenizer.save_pretrained(work_dir)
    tj_path = work_dir / "tokenizer.json"
    tj = json.loads(tj_path.read_text(encoding="utf-8"))
    vocab = tj["model"]["vocab"]
    base_size = len(vocab)
    known = {piece for piece, _ in vocab}
    new_chars = [ch for ch in chars if ch not in known]
    if not new_chars:
        return tokenizer
    min_score = min(score for _, score in vocab)
    vocab.extend([ch, min_score] for ch in new_chars)
    shift = len(new_chars)
    # Các added token (thẻ CORD, thẻ trường...) đang nằm sau từ vựng gốc: dời id ra sau để không trùng
    for tok in tj["added_tokens"]:
        if tok["id"] >= base_size:
            tok["id"] += shift
    tj_path.write_text(json.dumps(tj, ensure_ascii=False), encoding="utf-8")

    cfg_path = work_dir / "tokenizer_config.json"
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    if "added_tokens_decoder" in cfg:
        cfg["added_tokens_decoder"] = _shift_ids(cfg["added_tokens_decoder"], base_size, shift)
    cfg_path.write_text(json.dumps(cfg, ensure_ascii=False), encoding="utf-8")
    added_path = work_dir / "added_tokens.json"
    if added_path.exists():
        added = json.loads(added_path.read_text(encoding="utf-8"))
        added = {k: (v + shift if v >= base_size else v) for k, v in added.items()}
        added_path.write_text(json.dumps(added, ensure_ascii=False), encoding="utf-8")
    return AutoTokenizer.from_pretrained(work_dir)


def setup_model_and_processor(train_texts: list[str], image_size: tuple[int, int], work_dir: Path):
    from transformers import DonutProcessor, VisionEncoderDecoderModel

    processor = DonutProcessor.from_pretrained(BASE_MODEL)
    model = VisionEncoderDecoderModel.from_pretrained(BASE_MODEL)
    tokenizer = processor.tokenizer

    texts = sorted({t for t in train_texts if t})
    base_size = len(json.loads(tokenizer.backend_tokenizer.to_str())["model"]["vocab"])
    unk_chars = find_unk_chars(tokenizer, texts)
    tokenizer = extend_unigram_vocab(tokenizer, unk_chars, Path(work_dir) / "tokenizer_v5")
    processor.tokenizer = tokenizer
    tokenizer.add_tokens(field_tokens(), special_tokens=True)
    print(f"Đã thêm {len(unk_chars)} ký tự vào từ vựng: {unk_chars} và {len(field_tokens())} thẻ trường")
    embeddings = model.decoder.resize_token_embeddings(len(tokenizer))
    with torch.no_grad():
        # Ký tự mới bắt đầu từ vector trung bình của từ vựng gốc
        embeddings.weight[base_size:base_size + len(unk_chars)] = embeddings.weight[:base_size].mean(dim=0)

    failures = roundtrip_failures(tokenizer, texts)
    rate = 1 - len(failures) / max(len(texts), 1)
    print(f"Tỉ lệ nhãn encode/decode giữ nguyên: {rate:.2%}")
    if rate < MIN_ROUNDTRIP:
        raise TokenizerCheckError(f"Chỉ {rate:.2%} nhãn tái tạo đúng (cần {MIN_ROUNDTRIP:.0%}). "
                                  f"Ví dụ lỗi: {failures[:MAX_LISTED]}")

    height, width = image_size
    model.config.encoder.image_size = [height, width]
    processor.image_processor.size = {"height": height, "width": width}
    processor.image_processor.do_align_long_axis = True

    task_id = tokenizer.convert_tokens_to_ids(TASK_TOKEN)
    for cfg in (model.config, model.generation_config):
        cfg.decoder_start_token_id = task_id
        cfg.pad_token_id = tokenizer.pad_token_id
        cfg.eos_token_id = tokenizer.eos_token_id
    model.generation_config.max_length = MAX_LENGTH
    return model, processor


def build_target(rec: Record, tokenizer) -> tuple[list[int], list[int]]:
    segments: list[tuple[str | None, str]] = [
        (f, f"<s_{FIELD_TAGS[f]}>{rec.fields[f]}</s_{FIELD_TAGS[f]}>") for f in FIELDS
    ]
    segments.append((None, TASK_END_TOKEN))
    full: list[int] = []
    labels: list[int] = []
    for f, seg in segments:
        ids = tokenizer(seg, add_special_tokens=False).input_ids
        full += ids
        # Trường rỗng chưa được kiểm tra có thể là nhãn bị bỏ sót: không phạt model ở đó
        masked = f is not None and f in rec.unverified and rec.fields[f] == ""
        labels += [IGNORE_INDEX] * len(ids) if masked else ids
    full.append(tokenizer.eos_token_id)
    labels.append(tokenizer.eos_token_id)
    if len(full) > MAX_LENGTH:
        raise LabelTooLongError(f"{rec.file_name}: {len(full)} token > {MAX_LENGTH}")
    decoder_input_ids = [tokenizer.convert_tokens_to_ids(TASK_TOKEN)] + full[:-1]
    return decoder_input_ids, labels


def build_augment():
    import albumentations as A
    import cv2

    return A.Compose([
        A.Rotate(limit=10, border_mode=cv2.BORDER_CONSTANT, fill=255, p=0.5),
        A.RandomBrightnessContrast(p=0.5),
        A.GaussianBlur(blur_limit=(3, 5), p=0.3),
        A.MotionBlur(blur_limit=5, p=0.3),  # mô phỏng rung tay khi chụp
        A.ImageCompression(quality_range=(40, 90), p=0.4),  # mô phỏng ảnh bị nén qua app
        A.GaussNoise(std_range=(0.04, 0.2), p=0.3),
    ])


class DonutDataset(Dataset):
    def __init__(self, records: list[Record], image_dir: Path, processor, image_size: tuple[int, int],
                 train: bool, long_repeat: int = 1):
        super().__init__()
        missing = [r.file_name for r in records if not (Path(image_dir) / r.file_name).is_file()]
        if missing:
            raise MissingImagesError(f"Thiếu {len(missing)} ảnh trong {image_dir}: {', '.join(missing)}")
        self.records = records
        self.image_dir = Path(image_dir)
        self.processor = processor
        self.image_size = image_size
        self.train = train
        self.augment = None  # tạo lười ở lần lấy mẫu đầu tiên (albumentations chỉ có trên Kaggle)
        self.index: list[int] = []
        for i, rec in enumerate(records):
            repeat = long_repeat if is_long(self.image_dir / rec.file_name) else 1
            self.index += [i] * repeat
        self.collate_fn = partial(collate_fn, pad_id=processor.tokenizer.pad_token_id)

    def __len__(self) -> int:
        return len(self.index)

    def __getitem__(self, idx: int) -> dict[str, torch.Tensor]:
        rec = self.records[self.index[idx]]
        image = read_image(self.image_dir / rec.file_name)
        if self.train:
            if self.augment is None:
                self.augment = build_augment()
            import numpy as np
            from PIL import Image

            image = Image.fromarray(self.augment(image=np.array(image))["image"])
        height, width = self.image_size
        pixel_values = self.processor(
            image, return_tensors="pt", do_resize=True,
            size={"height": height, "width": width}, do_align_long_axis=True,
        ).pixel_values.squeeze(0)
        decoder_input_ids, labels = build_target(rec, self.processor.tokenizer)
        return {
            "pixel_values": pixel_values,
            "decoder_input_ids": torch.tensor(decoder_input_ids, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }


def collate_fn(batch: list[dict[str, torch.Tensor]], pad_id: int) -> dict[str, torch.Tensor]:
    width = max(len(x["labels"]) for x in batch)

    def pad(t: torch.Tensor, value: int) -> torch.Tensor:
        return torch.cat([t, torch.full((width - len(t),), value, dtype=torch.long)])

    return {
        "pixel_values": torch.stack([x["pixel_values"] for x in batch]),
        "decoder_input_ids": torch.stack([pad(x["decoder_input_ids"], pad_id) for x in batch]),
        "labels": torch.stack([pad(x["labels"], IGNORE_INDEX) for x in batch]),
    }
