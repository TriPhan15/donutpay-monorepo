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
import traceback

from starlette.concurrency import run_in_threadpool

from spending_analysis import DEFAULT_TOP_N, SpadeAnalyzeResponse, analyze_spending
from spending_data import MAX_TRANSACTIONS, TransactionIn, expenses_from
from wcm_spade import DEFAULT_MIN_SUP
import budget_advisor
from receipt_postprocess import fields_from_sequence, normalize_receipt

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
app = FastAPI()

MODEL_PATH = os.path.join(BASE_DIR, "Version5", "donut_result")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Kích thước ảnh lúc train V5 (Version5/model_config.py DEFAULT_IMAGE_SIZE)
IMAGE_HEIGHT = 1920
IMAGE_WIDTH = 1440

print(f"Đang khởi động AI DONUT Engine trên thiết bị: [{DEVICE.upper()}]...")
if not os.path.exists(MODEL_PATH):
    raise RuntimeError(f"Không tìm thấy weights tại {MODEL_PATH}")

# Processor + tokenizer (đã mở rộng ký tự tiếng Việt) được lưu cùng weights V5
processor = DonutProcessor.from_pretrained(MODEL_PATH)

model = VisionEncoderDecoderModel.from_pretrained(MODEL_PATH).to(DEVICE)
model.eval()
print("AI DONUT Engine đã tải xong!")


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
def health_check():
    return {"status": "ok"}


@app.post("/donut/scan")
async def extract_receipt_info(image: UploadFile = File(...)):
    print(f"\nĐã nhận hóa đơn từ App: {image.filename}")
    try:
        contents = await image.read()
        if not contents or len(contents) == 0:
            print("LỖI: File ảnh rỗng (0 bytes)!")
            raise HTTPException(status_code=400, detail="File ảnh nhận được bị rỗng (0 bytes)")
            
        pil_img = Image.open(io.BytesIO(contents))
        # Khắc phục lỗi xoay ảnh EXIF từ Camera Android & convert sang RGB chuẩn
        pil_img = ImageOps.exif_transpose(pil_img).convert("RGB")
        print(f"Đã mở ảnh thành công! Kích thước: {pil_img.size}")
    except HTTPException:
        raise
    except Exception as e:
        print(f"Lỗi đọc/convert file ảnh chi tiết: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=400, detail=f"Lỗi đọc file ảnh: {str(e)}")

    # Suy luận trong threadpool để event loop vẫn trả lời /health và các request khác
    sequence = await run_in_threadpool(_run_donut_locked, pil_img)

    try:
        prediction = processor.token2json(sequence)
    except Exception as e:
        print(f"Lỗi parse JSON từ Donut: {e}")
        prediction = {"raw_text": sequence}
    if not isinstance(prediction, dict):
        prediction = {"raw_text": sequence}

    # Hậu xử lý Regex (receipt_postprocess): giữ nguyên các field cũ, thêm "normalized" kèm cờ valid từng trường
    normalized = normalize_receipt(_raw_fields(sequence, prediction))
    seller = prediction.get("seller")
    if isinstance(seller, dict) and "total_cost" in seller:
        seller["total_cost_number"] = normalized.total_cost.value or 0
    prediction["normalized"] = normalized.model_dump()
    if normalized.invalid_fields:
        print(f"Trường cần người dùng kiểm tra: {normalized.invalid_fields}")

    print(f"Bóc tách thành công: {prediction}")
    return prediction


class SpadeRequest(BaseModel):
    # Trường thừa (alpha, beta, max_gap_days của APK cũ) bị Pydantic bỏ qua.
    transactions: List[TransactionIn] = Field(max_length=MAX_TRANSACTIONS)
    top_n: int = Field(DEFAULT_TOP_N, ge=1, le=50)
    min_sup_factor: float = Field(DEFAULT_MIN_SUP, gt=0, le=1)

class RecommendRequest(BaseModel):
    transactions: List[TransactionIn]
    target: float = 0.0          
    current: float = 0.0         
    months_left: int = 0        
    monthly_income: Optional[float] = None  
    needed_monthly: Optional[float] = None  
    alpha: float = 0.5
    min_sup_factor: float = 0.4
    max_cut_ratio: float = 0.30


@app.post("/spade/analyze", response_model=SpadeAnalyzeResponse)
def analyze_patterns(req: SpadeRequest) -> SpadeAnalyzeResponse:
    """Phân tích chi tiêu 26 tuần (CPU-bound nên dùng def, chạy trong threadpool)."""
    return analyze_spending(
        expenses_from(req.transactions), top_n=req.top_n, min_sup=req.min_sup_factor
    )


@app.post("/spade/recommend")
def recommend_budget(req: RecommendRequest):
    print(f"\nBudgetAdvisor nhận {len(req.transactions)} giao dịch")
    txs = [
        {"category": t.category, "amount": t.amount, "date": t.date, "isExpense": t.isExpense}
        for t in req.transactions
    ]
    if not txs:
        return {
            "trends": [],
            "tagStats": [],
            "goal": {"neededMonthly": 0, "monthlyIncome": req.monthly_income or 0, "monthlyExpense": 0, "surplus": 0, "gap": 0},
            "recommendations": [],
            "summary": "Bạn chưa có giao dịch. Hãy nhập chi tiêu để AI tính toán nhé!"
        }

    result = budget_advisor.advise(
        txs,
        target=req.target,
        current=req.current,
        months_left=req.months_left,
        monthly_income=req.monthly_income,
        needed_monthly=req.needed_monthly,
        alpha=req.alpha,
        min_sup_factor=req.min_sup_factor,
        max_cut_ratio=req.max_cut_ratio,
    )
        
    print(f"BudgetAdvisor: {len(result.get('recommendations', []))} đề xuất")
    return result


class UserRFM(BaseModel):
    user_id: str
    recency: int    
    frequency: int   
    monetary: float  

class AdminSegmentRequest(BaseModel):
    users: List[UserRFM]

@app.post("/admin/segment")
def segment_users(req: AdminSegmentRequest):
    print(f"\n Đang phân lớp {len(req.users)} khách hàng RFM...")
    
    if not req.users:
        return {"segments": []}

    result_segments = []
    
    for u in req.users:
        if u.recency > 120:
            label = "CHURN"
        elif u.recency > 30:
            label = "AT-RISK"
        elif u.monetary > 10000000 and u.frequency >= 2:
            label = "VIP"
        else:
            label = "ACTIVE"
            
        result_segments.append({
            "user_id": u.user_id,
            "label": label
        })
        
    return {"segments": result_segments}

if __name__ == "__main__":
    uvicorn.run("ai_service", host="0.0.0.0", port=8000, reload=True)