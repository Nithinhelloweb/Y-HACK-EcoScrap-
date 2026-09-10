import random
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Lot, HandoverEvent, RiskEvent, LotStatus
from backend.app.schemas import HandoverVerifyRequest, HandoverVerifyResponse
from backend.app.services.ledger import record_chain_event

router = APIRouter(prefix="/handover", tags=["Digital Handover & Scale Verification"])

@router.post("/{lot_id}/start")
def start_handover(lot_id: str, db: Session = Depends(get_db)):
    """
    Initiates physical handover by generating a secure 6-digit verification OTP.
    """
    lot = db.query(Lot).filter(Lot.id == lot_id).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")

    otp = f"{random.randint(100000, 999999)}"
    
    # Check if handover already exists
    handover = db.query(HandoverEvent).filter(HandoverEvent.lot_id == lot.id).first()
    if not handover:
        handover = HandoverEvent(
            lot_id=lot.id,
            otp_code=otp,
            otp_verified=False
        )
        db.add(handover)
    else:
        handover.otp_code = otp
        handover.otp_verified = False

    lot.status = LotStatus.HANDOVER_SCHEDULED
    db.commit()

    return {
        "lot_id": lot.id,
        "lot_code": lot.lot_code,
        "otp_code": otp,
        "status": lot.status,
        "message": "Handover scheduled. Present this OTP to authorized recycler upon physical delivery."
    }

@router.post("/verify", response_model=HandoverVerifyResponse)
def verify_handover(req: HandoverVerifyRequest, db: Session = Depends(get_db)):
    """
    Recycler enters the OTP and calibrated scale weight.
    Verifies dual-weight tolerance and appends verified blocks to SHA-256 ledger.
    """
    lot = db.query(Lot).filter(Lot.id == req.lot_id).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")

    handover = db.query(HandoverEvent).filter(HandoverEvent.lot_id == lot.id).first()
    if not handover or handover.otp_code != req.otp_code:
        raise HTTPException(status_code=400, detail="Invalid OTP code")

    # Weight discrepancy check
    declared = lot.estimated_weight_kg
    scale_wt = req.scale_weight_kg
    diff_pct = round(abs(declared - scale_wt) / max(0.1, declared) * 100, 1)

    flagged_anomaly = False
    if diff_pct > 15.0:
        flagged_anomaly = True
        db.add(RiskEvent(
            lot_id=lot.id,
            risk_type="WEIGHT_MISMATCH",
            deviation_percentage=diff_pct,
            severity="MEDIUM",
            explanation=f"Weight discrepancy detected: declared {declared} kg vs scale verified {scale_wt} kg ({diff_pct}% diff)."
        ))

    handover.otp_verified = True
    handover.scale_weight_kg = scale_wt
    handover.collector_confirmed = True
    handover.recycler_confirmed = True

    lot.verified_weight_kg = scale_wt
    lot.status = LotStatus.RECEIVED

    db.commit()

    # Append Dual-Weight Event to Cryptographic Ledger
    record_chain_event(
        db=db,
        lot_id=lot.id,
        event_type="SCALE_VERIFIED_AND_HANDOVER",
        payload={
            "declared_weight_kg": declared,
            "scale_verified_weight_kg": scale_wt,
            "weight_deviation_pct": diff_pct,
            "otp_verified": True,
            "handover_timestamp": datetime.utcnow().isoformat()
        }
    )

    return HandoverVerifyResponse(
        lot_id=lot.id,
        success=True,
        message=f"Handover verified successfully! Weight recorded: {scale_wt} kg.",
        weight_deviation_pct=diff_pct,
        flagged_anomaly=flagged_anomaly
    )

@router.post("/{lot_id}/process")
def complete_recycling_process(lot_id: str, db: Session = Depends(get_db)):
    """
    Records material recovery completion and payment settlement in the cryptographic chain.
    """
    lot = db.query(Lot).filter(Lot.id == lot_id).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")

    from backend.app.services.passport import estimate_recovered_fractions, calculate_environmental_impact
    wt = lot.verified_weight_kg or lot.estimated_weight_kg
    fractions = estimate_recovered_fractions(lot.category, lot.subcategory, wt)
    impact = calculate_environmental_impact(wt)

    lot.status = LotStatus.CLOSED
    db.commit()

    txn_ref = f"TXN-TN-2026-{random.randint(100000, 999999)}"

    # Record Block 4: MATERIAL_RECOVERED & SETTLED
    chain_ev = record_chain_event(
        db=db,
        lot_id=lot.id,
        event_type="MATERIAL_RECOVERED_AND_CLOSED",
        payload={
            "status": "CLOSED",
            "verified_weight_kg": wt,
            "recovered_fractions": fractions,
            "environmental_impact": impact,
            "settlement_status": "PAID",
            "payment_reference": txn_ref
        }
    )

    return {
        "lot_id": lot.id,
        "lot_code": lot.lot_code,
        "status": lot.status,
        "settlement_status": "PAID",
        "payment_reference": txn_ref,
        "recovered_fractions": fractions,
        "block_hash": chain_ev.current_hash,
        "message": "Lot processing complete. Material recovered and settlement issued to collector."
    }
