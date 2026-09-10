from typing import Optional, Dict, Any
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException, Depends
from backend.app.services.voice import parse_vernacular_voice_prompt
from backend.app.services.safety import assess_safety_risk, SAFETY_PROTOCOLS

router = APIRouter(prefix="", tags=["Vernacular Voice & Safety AI Engine"])

class VoiceParseRequest(BaseModel):
    text: str
    language_hint: Optional[str] = None

class SafetyAssessRequest(BaseModel):
    category: str
    subcategory: str
    condition: Optional[str] = "normal"

@router.post("/voice/parse")
def parse_voice_command(req: VoiceParseRequest):
    """
    Parses vernacular scrap collection prompts in Tamil, Hindi, or English.
    Extracts category, subcategory, estimated weight, and safety hazard signals.
    """
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Voice text transcript cannot be empty.")
    
    return parse_vernacular_voice_prompt(req.text, req.language_hint)

@router.post("/safety/assess")
def assess_safety(req: SafetyAssessRequest):
    """
    Context-aware Safety AI: assesses hazard severity (LOW, MEDIUM, CRITICAL),
    mandatory PPE, and localized step-by-step handling SOPs.
    """
    return assess_safety_risk(
        category=req.category,
        subcategory=req.subcategory,
        condition=req.condition or "normal"
    )

@router.get("/safety/protocols")
def get_all_safety_protocols():
    """
    Returns all CPCB-aligned standard operating safety protocols in EN, TA, HI.
    """
    return SAFETY_PROTOCOLS
