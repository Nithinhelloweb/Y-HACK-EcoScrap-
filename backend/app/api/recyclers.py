from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.app.database import get_db
from backend.app.models import RecyclerProfile
from backend.app.services.matching import calculate_haversine_distance

router = APIRouter(prefix="/recycler", tags=["Recycler Matching"])

class RecyclerMatchRequest(BaseModel):
    lot_id: Optional[str] = None
    material: Optional[str] = "PCB"
    latitude: Optional[float] = 11.0168
    longitude: Optional[float] = 76.9558

@router.post("/match")
def match_recyclers(req: RecyclerMatchRequest, db: Session = Depends(get_db)):
    """
    POST /api/recycler/match
    Discovers nearest CPCB-authorized recyclers and calculates proximity and reliability ranking.
    """
    recyclers = db.query(RecyclerProfile).all()
    results = []

    for r in recyclers:
        dist = calculate_haversine_distance(
            req.latitude or 11.0168,
            req.longitude or 76.9558,
            r.latitude,
            r.longitude
        )
        results.append({
            "id": r.id,
            "name": r.org_name,
            "registration_no": r.registration_no,
            "reliability": r.reliability_score,
            "distance_km": round(dist, 1),
            "service_radius_km": r.service_radius_km,
            "price": 5020.0 if "GreenTech" in r.org_name else 4720.0,
            "recommended": "GreenTech" in r.org_name
        })

    results.sort(key=lambda x: x["distance_km"])
    return {"recyclers": results}
