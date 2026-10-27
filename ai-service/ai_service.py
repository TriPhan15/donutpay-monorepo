from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional
import uvicorn
import torch
from PIL import Image, ImageOps
from transformers import DonutProcessor, VisionEncoderDecoderModel
import re
import io
import os
import threading
import logging

from starlette.concurrency import run_in_threadpool

from spending_analysis import DEFAULT_TOP_N, SpadeAnalyzeResponse, analyze_spending
from spending_data import MAX_AMOUNT, MAX_TRANSACTIONS, TransactionIn, expenses_from
from wcm_spade import DEFAULT_MIN_SUP
import budget_advisor
import rfm_segmentation
from rfm_segmentation import RfmInput
from receipt_postprocess import fields_from_sequence, normalize_receipt

logger = logging.getLogger(__name__)

MAX_UPLOAD_BYTES = 15 * 1024 * 1024
MAX_IMAGE_PIXELS = 40_000_000
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS
ALLOWED_IMAGE_FORMATS = frozenset({"JPEG", "PNG", "WEBP"})

EMPTY_IMAGE_MESSAGE = "File ảnh nhận được bị rỗng (0 bytes)"
IMAGE_TOO_LARGE_MESSAGE = "Ảnh quá lớn, vui lòng chụp lại với độ phân giải thấp hơn."
UNSUPPORTED_IMAGE_MESSAGE = "Chỉ nhận ảnh JPEG, PNG hoặc WEBP."
UNREADABLE_IMAGE_MESSAGE = "Không đọc được file ảnh."

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
app = FastAPI()

MODEL_PATH = os.path.join(BASE_DIR, "Version5", "donut_result")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Kích thước ảnh lúc train V5 (Version5/model_config.py DEFAULT_IMAGE_SIZE)
IMAGE_HEIGHT = 1920
IMAGE_WIDTH = 1440

logger.info("Đang khởi động AI DONUT Engine trên thiết bị: [%s]...", DEVICE.upper())
if not os.path.exists(MODEL_PATH):
    raise RuntimeError(f"Không tìm thấy weights tại {MODEL_PATH}")

# Processor + tokenizer (đã mở rộng ký tự tiếng Việt) được lưu cùng weights V5
processor = DonutProcessor.from_pretrained(MODEL_PATH)

model = VisionEncoderDecoderModel.from_pretrained(MODEL_PATH).to(DEVICE)
model.eval()
logger.info("AI DONUT Engine đã tải xong!")


def _raw_fields(sequence: str, prediction: Dict[str, Any]) -> Dict[str, str]:
    """Giá trị thô từng trường: đọc thẻ trong chuỗi (như lúc chấm V5), thiếu thì lấy từ token2json."""
    fields = fields_from_sequence(sequence)
    seller = prediction.get("seller")
    if isinstance(seller, dict):
        for key, value in fields.items():
            if not value and seller.get(key) is not None:
                fields[key] = str(seller[key])
    return fields


# Mỗi lúc chỉ một lượt DONUT: model.generate tốn nhiều RAM/CPU, chạy song song dễ làm sập máy
_donut_lock = threading.Lock()


def _run_donut(pil_img: Image.Image) -> str:
    """Suy luận DONUT (đồng bộ, nặng CPU): trả về chuỗi sequence đã bỏ eos/pad."""
    pixel_values = processor(
        pil_img,
        return_tensors="pt",
        do_resize=True,
        size={"height": IMAGE_HEIGHT, "width": IMAGE_WIDTH},
        do_align_long_axis=True
    ).pixel_values.to(DEVICE)

    start_token_id = processor.tokenizer.convert_tokens_to_ids("<s_seller>")
    outputs = model.generate(
        pixel_values,
        max_length=768,
        decoder_input_ids=torch.tensor([[start_token_id]]).to(DEVICE),
        pad_token_id=processor.tokenizer.pad_token_id,
        eos_token_id=processor.tokenizer.eos_token_id,
        use_cache=True,
    )

    sequence = processor.batch_decode(outputs)[0]
    sequence = sequence.replace(processor.tokenizer.eos_token, "").replace(processor.tokenizer.pad_token, "")
    return re.sub(r"<pad>", "", sequence)


def _run_donut_locked(pil_img: Image.Image) -> str:
    """Giữ _donut_lock quanh _run_donut để các lượt scan đọc lần lượt từng ảnh."""
    with _donut_lock:
        return _run_donut(pil_img)


@app.get("/health")
async def health_check() -> Dict[str, str]:
    return {"status": "ok"}


def _decode_image(contents: bytes) -> Image.Image:
    """Giải mã ảnh (nặng CPU, chạy trong threadpool). Loại theo định dạng Pillow đọc được,
    không tin Content-Type (app gửi application/octet-stream); kiểm số pixel trước khi giải mã."""
    try:
        pil_img = Image.open(io.BytesIO(contents))
    except Exception:
        logger.warning("Không mở được ảnh", exc_info=True)
        raise HTTPException(status_code=400, detail=UNREADABLE_IMAGE_MESSAGE)
    if pil_img.format not in ALLOWED_IMAGE_FORMATS:
        raise HTTPException(status_code=415, detail=UNSUPPORTED_IMAGE_MESSAGE)
    if pil_img.width * pil_img.height > MAX_IMAGE_PIXELS:
        raise HTTPException(status_code=413, detail=IMAGE_TOO_LARGE_MESSAGE)
    try:
        # Khắc phục lỗi xoay ảnh EXIF từ Camera Android & convert sang RGB chuẩn
        return ImageOps.exif_transpose(pil_img).convert("RGB")
    except Exception:  # gồm DecompressionBombError, file cắt cụt
        logger.warning("Không giải mã được ảnh", exc_info=True)
        raise HTTPException(status_code=400, detail=UNREADABLE_IMAGE_MESSAGE)


@app.post("/donut/scan")
async def extract_receipt_info(image: UploadFile = File(...)):
    contents = await image.read(MAX_UPLOAD_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail=EMPTY_IMAGE_MESSAGE)
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail=IMAGE_TOO_LARGE_MESSAGE)

    pil_img = await run_in_threadpool(_decode_image, contents)
    logger.info("Đã mở ảnh, kích thước %s", pil_img.size)

    # Suy luận trong threadpool để event loop vẫn trả lời /health và các request khác
    sequence = await run_in_threadpool(_run_donut_locked, pil_img)

    try:
        prediction = processor.token2json(sequence)
    except Exception:
        logger.warning("Lỗi parse JSON từ Donut", exc_info=True)
        prediction = {"raw_text": sequence}
    if not isinstance(prediction, dict):
        prediction = {"raw_text": sequence}

    # Hậu xử lý Regex (receipt_postprocess): giữ nguyên các field cũ, thêm "normalized" kèm cờ valid từng trường
    normalized = normalize_receipt(_raw_fields(sequence, prediction))
    seller = prediction.get("seller")
    if isinstance(seller, dict):
        if normalized.total_cost.valid:
            seller["total_cost_number"] = normalized.total_cost.value
        else:
            seller.pop("total_cost_number", None)
    prediction["normalized"] = normalized.model_dump()
    if normalized.invalid_fields:
        logger.info("Trường cần người dùng kiểm tra: %s", normalized.invalid_fields)
    return prediction


class SpadeRequest(BaseModel):
    # Trường thừa (alpha, beta, max_gap_days của APK cũ) bị Pydantic bỏ qua.
    transactions: List[TransactionIn] = Field(max_length=MAX_TRANSACTIONS)
    top_n: int = Field(DEFAULT_TOP_N, ge=1, le=50)
    min_sup_factor: float = Field(DEFAULT_MIN_SUP, gt=0, le=1)

class RecommendRequest(BaseModel):
    # Old APK fields (alpha, min_sup_factor, max_cut_ratio) are ignored by Pydantic.
    transactions: List[TransactionIn] = Field(max_length=MAX_TRANSACTIONS)
    target: float = Field(0, ge=0, le=MAX_AMOUNT)
    current: float = Field(0, ge=0, le=MAX_AMOUNT)
    months_left: Optional[int] = Field(None, ge=1, le=600)
    monthly_income: Optional[float] = Field(None, ge=0, le=MAX_AMOUNT)
    needed_monthly: Optional[float] = Field(None, ge=0, le=MAX_AMOUNT)


@app.post("/spade/analyze", response_model=SpadeAnalyzeResponse)
def analyze_patterns(req: SpadeRequest) -> SpadeAnalyzeResponse:
    """Phân tích chi tiêu 26 tuần (CPU-bound nên dùng def, chạy trong threadpool)."""
    return analyze_spending(
        expenses_from(req.transactions), top_n=req.top_n, min_sup=req.min_sup_factor
    )


@app.post("/spade/recommend")
def recommend_budget(req: RecommendRequest):
    logger.info("BudgetAdvisor nhận %d giao dịch", len(req.transactions))
    try:
        result = budget_advisor.advise(
            req.transactions,
            target=req.target,
            current=req.current,
            months_left=req.months_left,
            monthly_income=req.monthly_income,
            needed_monthly=req.needed_monthly,
        )
    except budget_advisor.AdviceError as e:
        raise HTTPException(status_code=422, detail=str(e))

    logger.info("BudgetAdvisor: %d đề xuất", len(result.get("recommendations", [])))
    return result


MAX_RFM_USERS = 100_000


class UserRFM(BaseModel):
    user_id: str = Field(min_length=1, max_length=20, pattern=r"^\d+$")
    recency: int = Field(ge=0, le=36500)
    frequency: int = Field(ge=0, le=10_000_000)
    monetary: float = Field(ge=0, le=1e15)


class AdminSegmentRequest(BaseModel):
    users: List[UserRFM] = Field(max_length=MAX_RFM_USERS)


@app.post("/admin/segment")
def segment_users(req: AdminSegmentRequest):
    logger.info("Đang phân lớp %d khách hàng RFM...", len(req.users))
    results = rfm_segmentation.segment_users(
        [RfmInput(u.user_id, u.recency, u.frequency, u.monetary) for u in req.users]
    )
    return {
        "segments": [
            {"user_id": r.user_id, "label": r.label.value, "rfm": r.rfm}
            for r in results
        ]
    }

if __name__ == "__main__":
    uvicorn.run("ai_service", host="0.0.0.0", port=8000, reload=True)