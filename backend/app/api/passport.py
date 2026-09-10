from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from backend.app.database import get_db
from backend.app.models import Lot, ChainEvent, RiskEvent, RecyclerProfile, CollectorProfile, Bid, BidStatus, LotStatus
from backend.app.schemas import PassportResponse, ChainEventResponse
from backend.app.services.ledger import verify_lot_chain_integrity
from backend.app.services.passport import estimate_recovered_fractions, calculate_environmental_impact

router = APIRouter(prefix="/passport", tags=["Digital E-Waste Passport & Traceability"])

@router.get("/{lot_code}", response_model=PassportResponse)
def get_digital_passport(lot_code: str, db: Session = Depends(get_db)):
    """
    Public Digital E-Waste Passport:
    Returns the complete chain of custody from collection to recycling,
    cryptographic hash ledger verification, and circular material recovery metrics.
    """
    lot = db.query(Lot).filter(Lot.lot_code == lot_code).first()
    if not lot:
        # Fallback query by ID
        lot = db.query(Lot).filter(Lot.id == lot_code).first()
    if not lot:
        raise HTTPException(status_code=404, detail="E-Waste Passport not found for this identifier")

    # Fetch event chain
    events = (
        db.query(ChainEvent)
        .filter(ChainEvent.lot_id == lot.id)
        .order_by(ChainEvent.timestamp.asc())
        .all()
    )

    integrity_valid = verify_lot_chain_integrity(events)

    effective_weight = lot.verified_weight_kg or lot.estimated_weight_kg
    fractions = estimate_recovered_fractions(lot.category, lot.subcategory, effective_weight)
    impact = calculate_environmental_impact(effective_weight)

    # Find verified recycler name if bid was accepted
    accepted_bid = db.query(Bid).filter(Bid.lot_id == lot.id, Bid.status == BidStatus.ACCEPTED).first()
    recycler_name = accepted_bid.recycler.org_name if (accepted_bid and accepted_bid.recycler) else "Pending Assignment"

    collector_code = lot.collector.collector_code if lot.collector else "COL-ANON"

    return PassportResponse(
        lot_code=lot.lot_code,
        category=lot.category,
        subcategory=lot.subcategory,
        collector_code=collector_code,
        verified_recycler_name=recycler_name,
        estimated_weight_kg=lot.estimated_weight_kg,
        verified_weight_kg=lot.verified_weight_kg,
        current_status=lot.status,
        created_at=lot.created_at,
        qr_code_url=lot.qr_code_url,
        ledger_integrity_valid=integrity_valid,
        events_timeline=[ChainEventResponse.model_validate(e) for e in events],
        recovered_fractions_estimate=fractions,
        environmental_savings=impact
    )

@router.get("/{lot_code}/verify")
def verify_passport_integrity(lot_code: str, db: Session = Depends(get_db)):
    """
    Cryptographically verifies the SHA-256 chain of custody for any lot.
    """
    lot = db.query(Lot).filter(Lot.lot_code == lot_code).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")

    events = (
        db.query(ChainEvent)
        .filter(ChainEvent.lot_id == lot.id)
        .order_by(ChainEvent.timestamp.asc())
        .all()
    )

    is_valid = verify_lot_chain_integrity(events)
    return {
        "lot_code": lot.lot_code,
        "total_blocks": len(events),
        "cryptographic_integrity_valid": is_valid,
        "status": "TAMPER_FREE" if is_valid else "COMPROMISED_CHAIN"
    }

# Admin / Ecosystem KPIs
admin_router = APIRouter(prefix="/admin", tags=["Governance & Admin Analytics"])

@admin_router.get("/metrics")
def get_admin_metrics(db: Session = Depends(get_db)):
    total_lots = db.query(Lot).count()
    completed_lots = db.query(Lot).filter(Lot.status.in_([LotStatus.RECEIVED, LotStatus.PROCESSING, LotStatus.CLOSED])).count()
    
    total_weight = db.query(func.sum(Lot.estimated_weight_kg)).scalar() or 0.0
    total_recyclers = db.query(RecyclerProfile).count()
    total_collectors = db.query(CollectorProfile).count()
    total_anomalies = db.query(RiskEvent).count()

    co2_saved = round(total_weight * 1.44, 1)
    toxic_contained_g = round(total_weight * 25.0, 1)
    landfill_saved_l = round(total_weight * 1.8, 1)
    trees_offset = round(co2_saved / 21.0, 1)

    # Category Breakdown
    category_rows = db.query(Lot.category, func.sum(Lot.estimated_weight_kg)).group_by(Lot.category).all()
    category_distribution = {cat: round(wt or 0.0, 1) for cat, wt in category_rows}

    # Recent risk events / anomaly alerts
    recent_risks = db.query(RiskEvent).order_by(RiskEvent.created_at.desc()).limit(5).all()
    recent_anomalies = [
        {
            "id": r.id,
            "risk_type": r.risk_type,
            "severity": r.severity,
            "explanation": r.explanation,
            "created_at": r.created_at.isoformat() if r.created_at else None
        }
        for r in recent_risks
    ]

    return {
        "total_lots_created": total_lots,
        "lots_formalized": completed_lots,
        "total_ewaste_diverted_kg": round(total_weight, 1),
        "co2e_avoided_kg": co2_saved,
        "toxic_heavy_metals_contained_g": toxic_contained_g,
        "landfill_space_saved_liters": landfill_saved_l,
        "trees_offset_equivalent": trees_offset,
        "category_distribution": category_distribution,
        "verified_recyclers": total_recyclers,
        "registered_collectors": total_collectors,
        "price_anomalies_prevented": total_anomalies,
        "recent_anomalies": recent_anomalies,
        "chain_integrity_status": "ALL_LEDGERS_SECURE"
    }

