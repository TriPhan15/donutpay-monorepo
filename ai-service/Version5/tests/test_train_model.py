from labels import Record
from train_model import build_args, find_resume_checkpoint, sec_per_step, val_subset


def _recs(n):
    return [Record(f"{i:03}.jpg", {"SELLER": "", "ADDRESS": "", "TIMESTAMP": "", "TOTAL_COST": ""}) for i in range(n)]


def test_val_subset_deterministic():
    recs = _recs(10)
    a, b = val_subset(recs, 3, 42), val_subset(list(reversed(recs)), 3, 42)
    assert a == b and len(a) == 3
    assert len(val_subset(_recs(2), 150, 42)) == 2


def test_find_resume_checkpoint_picks_highest(tmp_path):
    for n in (400, 1200, 800):
        (tmp_path / "x" / "donut_checkpoints" / f"checkpoint-{n}").mkdir(parents=True)
    (tmp_path / "x" / "donut_checkpoints" / "checkpoint-9999.tmp").mkdir()
    assert find_resume_checkpoint([tmp_path]).name == "checkpoint-1200"
    assert find_resume_checkpoint([tmp_path / "empty"]) is None


def test_build_args_dry_run(tmp_path):
    import pytest

    pytest.importorskip("accelerate", reason="TrainingArguments cần accelerate (chỉ có trên Kaggle)")
    a = build_args(20, tmp_path)
    assert a.max_steps == 20 and a.save_strategy == "no" and not a.load_best_model_at_end
    b = build_args(None, tmp_path)
    assert b.metric_for_best_model == "eval_field_exact" and b.greater_is_better
    assert b.per_device_train_batch_size == 1 and b.gradient_accumulation_steps == 8
    assert b.eval_steps == 400 and b.save_steps == 400 and not b.remove_unused_columns


def test_sec_per_step_ignores_first_step():
    assert sec_per_step([0.0, 100.0, 110.0, 120.0]) == 10.0
    assert sec_per_step([5.0]) is None


def test_scoring_trainer_keeps_grad_accum_scaling(tmp_path):
    import pytest
    import torch

    pytest.importorskip("accelerate", reason="Trainer cần accelerate (chỉ có trên Kaggle)")
    from train_model import ScoringTrainer

    trainer = ScoringTrainer(model=torch.nn.Linear(1, 1), args=build_args(None, tmp_path))
    assert trainer.model_accepts_loss_kwargs is False
