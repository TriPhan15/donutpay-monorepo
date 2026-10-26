"""Train Donut V5 trên Kaggle: chọn checkpoint theo độ chính xác đọc thật, có chạy thử và chạy tiếp."""

import os
import random
import re
import shutil
import time
from pathlib import Path

import torch
from transformers import EarlyStoppingCallback, Seq2SeqTrainer, Seq2SeqTrainingArguments, TrainerCallback

from evaluate import ALL_KEY, generate_fields, score
from labels import FIELDS, Record, load_metadata, read_image
from model_config import LONG_REPEAT, DonutDataset, image_size_from_env, setup_model_and_processor
from paths import IS_KAGGLE, KAGGLE_INPUT, LABEL_ROOT, WORK_DIR, find_image_root

VAL_SUBSET_SIZE = 150
SEED = 42
CHECKPOINT_DIR = WORK_DIR / "donut_checkpoints"
OUTPUT_DIR = WORK_DIR / "donut_result"
GRAD_ACCUM = 8
EARLY_STOPPING_PATIENCE = 4
DRY_RUN_ENV = "DONUT_DRY_RUN_STEPS"
_CHECKPOINT = re.compile(r"^checkpoint-(\d+)$")


def val_subset(records: list[Record], n: int, seed: int) -> list[Record]:
    ordered = sorted(records, key=lambda r: r.file_name)
    return random.Random(seed).sample(ordered, min(n, len(ordered)))


def find_resume_checkpoint(roots: list[Path]) -> Path | None:
    best: tuple[int, Path] | None = None
    for root in roots:
        if not root.exists():
            continue
        for folder in root.rglob("donut_checkpoints"):
            for ckpt in folder.iterdir():
                match = _CHECKPOINT.match(ckpt.name)
                if match and ckpt.is_dir() and (best is None or int(match.group(1)) > best[0]):
                    best = (int(match.group(1)), ckpt)
    return best[1] if best else None


def sec_per_step(step_times: list[float]) -> float | None:
    """Thời gian trung bình mỗi bước, bỏ bước đầu (khởi động CUDA, cache)."""
    if len(step_times) < 3:
        return None
    return (step_times[-1] - step_times[1]) / (len(step_times) - 2)


def build_args(dry_run_steps: int | None, output_dir: Path = CHECKPOINT_DIR) -> Seq2SeqTrainingArguments:
    common = dict(
        output_dir=str(output_dir),
        per_device_train_batch_size=1,
        gradient_accumulation_steps=GRAD_ACCUM,
        learning_rate=3e-5,
        lr_scheduler_type="cosine",
        warmup_steps=300,
        num_train_epochs=8,
        logging_steps=20,
        fp16=torch.cuda.is_available(),
        gradient_checkpointing=True,
        dataloader_num_workers=2,
        remove_unused_columns=False,
        report_to="none",
        seed=SEED,
    )
    if dry_run_steps:
        return Seq2SeqTrainingArguments(**common, max_steps=dry_run_steps, eval_strategy="no",
                                        save_strategy="no", load_best_model_at_end=False)
    return Seq2SeqTrainingArguments(
        **common,
        eval_strategy="steps",
        eval_steps=400,
        save_steps=400,
        save_total_limit=3,
        load_best_model_at_end=True,
        metric_for_best_model="eval_field_exact",
        greater_is_better=True,
    )


class ScoringTrainer(Seq2SeqTrainer):
    """Đánh giá bằng cách cho model đọc thật tập validation con, không dùng loss."""

    def __init__(self, *args, donut_processor=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.donut_processor = donut_processor
        # VisionEncoderDecoder nhận **kwargs nên Trainer tưởng model tự chia loss theo num_items_in_batch;
        # thực tế loss là trung bình thường, nên phải để Trainer tự chia cho gradient_accumulation_steps
        self.model_accepts_loss_kwargs = False

    def evaluate(self, eval_dataset=None, ignore_keys=None, metric_key_prefix: str = "eval", **kwargs) -> dict[str, float]:
        dataset = eval_dataset or self.eval_dataset
        model = self.model
        was_training = model.training
        model.eval()
        pairs = [(rec.fields, generate_fields(model, self.donut_processor,
                                              read_image(dataset.image_dir / rec.file_name), legacy_v3=False))
                 for rec in dataset.records]
        if was_training:
            model.train()
        scores = score(pairs, include_empty_gt=False)
        metrics = {f"{metric_key_prefix}_field_exact": scores[ALL_KEY].ratio("exact")}
        metrics.update({f"{metric_key_prefix}_{f.lower()}_exact": scores[f].ratio("exact") for f in FIELDS})
        self.log(metrics)
        self.control = self.callback_handler.on_evaluate(self.args, self.state, self.control, metrics)
        return metrics


class StepTimer(TrainerCallback):
    def __init__(self):
        self.times: list[float] = []

    def on_step_end(self, args, state, control, **kwargs):
        self.times.append(time.time())


def _resume_point() -> Path | None:
    ckpt = find_resume_checkpoint([CHECKPOINT_DIR] + ([KAGGLE_INPUT] if IS_KAGGLE else []))
    if ckpt is None or CHECKPOINT_DIR in ckpt.parents:
        return ckpt
    # /kaggle/input chỉ đọc: copy checkpoint của phiên trước sang thư mục làm việc
    target = CHECKPOINT_DIR / ckpt.name
    shutil.copytree(ckpt, target, dirs_exist_ok=True)
    return target


def _load(split: str) -> tuple[list[Record], Path]:
    records = load_metadata(LABEL_ROOT / split / "metadata.jsonl")
    return records, find_image_root((split, records[0].file_name)) / split


def train() -> None:
    dry_run_steps = int(os.environ.get(DRY_RUN_ENV, "0")) or None
    image_size = image_size_from_env()
    train_records, train_dir = _load("train")
    val_records, val_dir = _load("validation")

    train_texts = [r.fields[f] for r in train_records for f in FIELDS]
    model, processor = setup_model_and_processor(train_texts, image_size, WORK_DIR)
    train_ds = DonutDataset(train_records, train_dir, processor, image_size, train=True, long_repeat=LONG_REPEAT)
    val_ds = DonutDataset(val_subset(val_records, VAL_SUBSET_SIZE, SEED), val_dir, processor, image_size, train=False)
    print(f"Ảnh {image_size[0]}x{image_size[1]}, {len(train_records)} ảnh train ({len(train_ds)} mẫu/epoch "
          f"sau khi nhân {LONG_REPEAT} hóa đơn dài), {len(val_ds)} ảnh validation để chọn checkpoint")

    timer = StepTimer()
    trainer = ScoringTrainer(
        model=model,
        args=build_args(dry_run_steps),
        train_dataset=train_ds,
        eval_dataset=val_ds,
        data_collator=train_ds.collate_fn,
        callbacks=[timer] if dry_run_steps else [timer, EarlyStoppingCallback(early_stopping_patience=EARLY_STOPPING_PATIENCE)],
        donut_processor=processor,
    )

    if dry_run_steps:
        trainer.train()
        per_step = sec_per_step(timer.times) or 0.0
        hours_per_epoch = len(train_ds) / GRAD_ACCUM * per_step / 3600
        memory = torch.cuda.max_memory_allocated() / 1024**3 if torch.cuda.is_available() else 0.0
        print(f"CHẠY THỬ {dry_run_steps} bước: GPU tối đa {memory:.1f} GB, {per_step:.1f} giây/bước, "
              f"ước tính {hours_per_epoch:.1f} giờ/epoch, {hours_per_epoch * 8:.1f} giờ cho 8 epoch")
        return

    resume = _resume_point()
    print(f"Chạy tiếp từ {resume}" if resume else "Train từ đầu")
    trainer.train(resume_from_checkpoint=str(resume) if resume else None)
    trainer.save_model(str(OUTPUT_DIR))
    processor.save_pretrained(str(OUTPUT_DIR))
    print(f"Đã lưu model tốt nhất tại {OUTPUT_DIR} (best eval_field_exact = {trainer.state.best_metric})")


if __name__ == "__main__":
    train()
