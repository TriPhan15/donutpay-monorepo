"""Đọc lại nhãn hóa đơn bằng Qwen2.5-VL chạy offline trên GPU Kaggle (ý kiến thứ hai)."""

import sys
from argparse import Namespace
from pathlib import Path
from typing import Callable

from labels import read_image
from relabel_common import run_cli

QWEN_MODEL = "Qwen/Qwen2.5-VL-7B-Instruct"
QWEN_MAX_PIXELS = 1600 * 28 * 28
MAX_NEW_TOKENS = 256


def make_qwen_reader(prompt: str) -> Callable[[Path], str]:
    import torch
    from qwen_vl_utils import process_vision_info
    from transformers import AutoProcessor, Qwen2_5_VLForConditionalGeneration

    model = Qwen2_5_VLForConditionalGeneration.from_pretrained(QWEN_MODEL, dtype=torch.float16, device_map="auto")
    model.eval()
    processor = AutoProcessor.from_pretrained(QWEN_MODEL, max_pixels=QWEN_MAX_PIXELS)

    def read(path: Path) -> str:
        messages = [{"role": "user", "content": [{"type": "image", "image": read_image(path)},
                                                  {"type": "text", "text": prompt}]}]
        text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        images, videos = process_vision_info(messages)
        inputs = processor(text=[text], images=images, videos=videos, padding=True, return_tensors="pt").to(model.device)
        with torch.no_grad():
            out = model.generate(**inputs, max_new_tokens=MAX_NEW_TOKENS, do_sample=False)
        new_tokens = out[:, inputs.input_ids.shape[1]:]
        return processor.batch_decode(new_tokens, skip_special_tokens=True)[0]

    return read


def _make(prompt: str, _args: Namespace) -> Callable[[Path], str]:
    return make_qwen_reader(prompt)


if __name__ == "__main__":
    sys.exit(run_cli("qwen", _make))
