import base64
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form
from backend.app.schemas import (
    MaterialClassifyResponse,
    PriceEstimateRequest,
    PriceEstimateResponse,
    OCRResponse
)
from backend.app.services.ai_lens import classify_material_input
from backend.app.services.ai_vision import analyze_scrap_image
from backend.app.services.fair_value import calculate_fair_value
from backend.app.services.local_ocr import extract_text_and_entities

router = APIRouter(prefix="/ai", tags=["AI Lens & Fair Value Engine"])

@router.post("/classify", response_model=MaterialClassifyResponse)
@router.post("/classify-material", response_model=MaterialClassifyResponse)
async def classify_material(
    query_text: Optional[str] = Form(""),
    file: Optional[UploadFile] = File(None)
):
    """
    AI Lens: Classifies e-waste from photo or voice transcript into 3-tier hierarchy
    with explainability, safety warnings, and benchmark rates.
    """
    if file:
        file_bytes = await file.read()
        if len(file_bytes) > 0:
            return analyze_scrap_image(image_bytes=file_bytes, filename=file.filename or "", hint_text=query_text or "")

    filename = file.filename if file else ""
    result = classify_material_input(query_text=query_text or "", image_filename=filename)
    return result

@router.post("/classify-image", response_model=MaterialClassifyResponse)
async def classify_image(
    file: Optional[UploadFile] = File(None),
    image_base64: Optional[str] = Form(""),
    hint_text: Optional[str] = Form("")
):
    """
    Live Camera & Image AI Lens: Analyzes live camera snapshot or image upload
    using offline computer vision heuristics, color histograms, and safety hazard detection.
    """
    image_bytes = b""
    filename = ""

    if file:
        image_bytes = await file.read()
        filename = file.filename or "camera_snapshot.jpg"
    elif image_base64:
        b64_clean = image_base64.split(",")[-1]
        try:
            image_bytes = base64.b64decode(b64_clean)
            filename = "camera_snapshot.jpg"
        except Exception:
            image_bytes = b""

    result = analyze_scrap_image(
        image_bytes=image_bytes,
        filename=filename,
        hint_text=hint_text or ""
    )
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

@router.post("/ocr", response_model=OCRResponse)
async def extract_image_text(
    file: Optional[UploadFile] = File(None),
    image_base64: Optional[str] = Form("")
):
    """
    Local OCR Text Extraction: Scans image for brand names, model numbers,
    serial identifiers, and safety/battery hazard warnings without cloud dependencies.
    """
    image_bytes = b""
    if file:
        image_bytes = await file.read()
    elif image_base64:
        b64_clean = image_base64.split(",")[-1]
        try:
            image_bytes = base64.b64decode(b64_clean)
        except Exception:
            image_bytes = b""

    return extract_text_and_entities(image_bytes)

