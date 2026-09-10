from typing import Optional, Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.app.database import get_db
from backend.app.schemas import PriceEstimateRequest, PriceEstimateResponse
from backend.app.services.fair_value import calculate_fair_value

router = APIRouter(prefix="/pricing", tags=["Pricing & Fair Value"])

@router.post("/fair-value", response_model=PriceEstimateResponse)
def get_pricing_fair_value(req: PriceEstimateRequest):
    """
    POST /api/pricing/fair-value
    Computes fair valuation range with explainability breakdown.
    """
    fv = calculate_fair_value(
        category=req.category,
        subcategory=req.subcategory,
        weight_kg=req.weight_kg,
        condition=req.condition,
        distance_km=req.distance_km
    )
    return PriceEstimateResponse(**fv)

@router.get("/history")
def get_pricing_history():
    """
    GET /api/pricing/history
    Returns local historical price trends for scrap materials.
    """
    return [
        {"material": "IT_HIGH_GRADE_PCB", "avg_rate_inr_per_kg": 550.0, "30d_trend": "+3.4%", "region": "Coimbatore"},
        {"material": "LITHIUM_ION", "avg_rate_inr_per_kg": 180.0, "30d_trend": "+1.8%", "region": "Coimbatore"},
        {"material": "COPPER_RICH_CABLE", "avg_rate_inr_per_kg": 420.0, "30d_trend": "+5.1%", "region": "Coimbatore"},
        {"material": "LOW_GRADE_PCB", "avg_rate_inr_per_kg": 110.0, "30d_trend": "-0.5%", "region": "Coimbatore"},
        {"material": "CRT_MONITOR", "avg_rate_inr_per_kg": 65.0, "30d_trend": "0.0%", "region": "Coimbatore"}
    ]
