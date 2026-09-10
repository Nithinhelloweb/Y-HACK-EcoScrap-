import base64
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form
from backend.app.schemas import (
    MaterialClassifyResponse,
    PriceEstimateRequest,
    PriceEstimateResponse,
    OCRResponse,
    DetectionEditFeedback,
    DetectionEditResponse,
    SelfTrainingTriggerRequest,
    SelfTrainingStatusResponse
)
from backend.app.services.ai_lens import classify_material_input
from backend.app.services.ai_vision import analyze_scrap_image
from backend.app.services.fair_value import calculate_fair_value
from backend.app.services.local_ocr import extract_text_and_entities
from backend.app.services.self_training import (
    record_detection_feedback,
    get_self_training_status,
    run_self_training
)

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
 

@router.post("/edit-feedback", response_model=DetectionEditResponse)
def submit_detection_feedback(feedback: DetectionEditFeedback):
    """
    Active Learning Feedback Endpoint:
    Records user corrections (e.g. corrected category, subcategory, weight, and bounding box)
    and saves the sample into the local training dataset for continuous self-training.
    """
    res = record_detection_feedback(
        image_base64=feedback.image_base64,
        original_item_name=feedback.original_item_name,
        original_category=feedback.original_category,
        original_subcategory=feedback.original_subcategory,
        corrected_item_name=feedback.corrected_item_name,
        corrected_category=feedback.corrected_category,
        corrected_subcategory=feedback.corrected_subcategory,
        corrected_weight_kg=feedback.corrected_weight_kg,
        corrected_quantity=feedback.corrected_quantity,
        corrected_condition=feedback.corrected_condition,
        bounding_box=feedback.bounding_box,
        collector_id=feedback.collector_id,
    )
    return res


@router.post("/self-train")
def trigger_self_training(req: SelfTrainingTriggerRequest):
    """
    Triggers local background self-training / incremental fine-tuning
    of the e-waste YOLO model using the latest feedback dataset.
    """
    return run_self_training(
        epochs=req.epochs or 5,
        batch_size=req.batch_size or 4,
        imgsz=req.imgsz or 416
    )


@router.get("/self-train/status", response_model=SelfTrainingStatusResponse)
def get_training_status():
    """
    Returns the live status, dataset sample count, and validation metrics
    of the local self-training engine.
    """
    return get_self_training_status()


