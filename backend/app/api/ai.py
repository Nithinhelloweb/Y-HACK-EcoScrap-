from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form
from backend.app.schemas import MaterialClassifyResponse, PriceEstimateRequest, PriceEstimateResponse
from backend.app.services.ai_lens import classify_material_input
from backend.app.services.fair_value import calculate_fair_value

router = APIRouter(prefix="/ai", tags=["AI Lens & Fair Value Engine"])

@router.post("/classify", response_model=MaterialClassifyResponse)
async def classify_material(
    query_text: Optional[str] = Form(""),
    file: Optional[UploadFile] = File(None)
):
    """
    AI Lens: Classifies e-waste from photo or voice transcript into 3-tier hierarchy
    with explainability, safety warnings, and benchmark rates.
    """
    filename = file.filename if file else ""
    result = classify_material_input(query_text=query_text or "", image_filename=filename)
    return result

@router.post("/fair-value", response_model=PriceEstimateResponse)
def get_fair_value(request: PriceEstimateRequest):
    """
    AI Fair Value Engine: Estimates transparent market price range in INR
    with itemized explainability factors.
    """
    return calculate_fair_value(
        category=request.category,
        subcategory=request.subcategory,
        weight_kg=request.weight_kg,
        condition=request.condition,
        distance_km=request.distance_km
    )
