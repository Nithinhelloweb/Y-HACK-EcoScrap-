"""
disputes.py — Dispute Management & Triage Endpoints
Implements:
  - POST  /api/disputes               — Raise a dispute on a lot/transaction
  - GET   /api/disputes               — List disputes (supports status/lot filters)
  - GET   /api/disputes/{dispute_id}  — Dispute details with context
  - PATCH /api/disputes/{dispute_id}/resolve — Admin dispute resolution
"""
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from backend.app.database import get_db
from backend.app.models import (
    Dispute, DisputeStatus, DisputeType, Lot, LotStatus,
    RiskEvent, AuditLog, User, CollectorProfile, RecyclerProfile
)
from backend.app.schemas import (
    DisputeCreateRequest,
    DisputeResolveRequest,
    DisputeResponse,
)

router = APIRouter(prefix="/disputes", tags=["Disputes & Escalation"])


def _record_audit_log(db: Session, action: str, actor_id: Optional[str], actor_role: str, entity_type: str, entity_id: str, details: dict):
    log = AuditLog(
        action=action,
        actor_id=actor_id,
        actor_role=actor_role,
        entity_type=entity_type,
        entity_id=entity_id,
        details=details,
        timestamp=datetime.now(timezone.utc),
    )
    db.add(log)
    try:
        db.commit()
    except Exception:
        db.rollback()


@router.post("", response_model=DisputeResponse)
def raise_dispute(req: DisputeCreateRequest, db: Session = Depends(get_db)):
    """
    POST /api/disputes
    Collector or Recycler raises a dispute on an active lot.
    """
    lot = db.query(Lot).filter(Lot.id == req.lot_id).first()
    if not lot:
        # Check by lot_code if UUID didn't match
        lot = db.query(Lot).filter(Lot.lot_code == req.lot_id).first()
        if not lot:
            raise HTTPException(status_code=404, detail="Lot not found for dispute")

    # Resolve raised_by_name if not provided
    name = req.raised_by_name
    if not name or name == "Collector":
        user = db.query(User).filter(User.id == req.raised_by_id).first()
        if user:
            name = user.name
        else:
            col = db.query(CollectorProfile).filter(CollectorProfile.id == req.raised_by_id).first()
            if col and col.user:
                name = col.user.name

    dispute = Dispute(
        lot_id=lot.id,
        raised_by_id=req.raised_by_id,
        raised_by_name=name or "Participant",
        raised_by_role=req.raised_by_role or "COLLECTOR",
        dispute_type=req.dispute_type,
        description=req.description,
        evidence_notes=req.evidence_notes,
        status=DisputeStatus.NEW,
        created_at=datetime.now(timezone.utc),
    )
    db.add(dispute)
    
    # Auto-flag lot or create risk event if weight or pricing related
    if req.dispute_type in [DisputeType.WEIGHT_MISMATCH, DisputeType.SUSPICIOUS_PRICING]:
        risk = RiskEvent(
            lot_id=lot.id,
            risk_type=f"DISPUTE_{req.dispute_type}",
            severity="HIGH",
            deviation_percentage=15.0,
            explanation=f"Active dispute raised by {req.raised_by_role}: {req.description}",
        )
        db.add(risk)

    db.commit()
    db.refresh(dispute)

    _record_audit_log(
        db=db,
        action="DISPUTE_RAISED",
        actor_id=req.raised_by_id,
        actor_role=req.raised_by_role or "COLLECTOR",
        entity_type="DISPUTE",
        entity_id=dispute.id,
        details={
            "lot_code": lot.lot_code,
            "dispute_type": req.dispute_type,
            "raised_by": name,
        }
    )

    return DisputeResponse(
        id=dispute.id,
        lot_id=dispute.lot_id,
        lot_code=lot.lot_code,
        raised_by_id=dispute.raised_by_id,
        raised_by_name=dispute.raised_by_name,
        raised_by_role=dispute.raised_by_role,
        dispute_type=dispute.dispute_type,
        description=dispute.description,
        evidence_notes=dispute.evidence_notes,
        status=dispute.status,
        resolution_decision=dispute.resolution_decision,
        resolution_notes=dispute.resolution_notes,
        created_at=dispute.created_at.isoformat(),
        resolved_at=dispute.resolved_at.isoformat() if dispute.resolved_at else None,
    )


@router.get("", response_model=List[DisputeResponse])
def list_disputes(
    status: Optional[str] = Query(None, description="Filter: NEW, UNDER_REVIEW, RESOLVED, REJECTED"),
    lot_id: Optional[str] = Query(None, description="Filter by Lot ID or Lot Code"),
    db: Session = Depends(get_db),
):
    """
    GET /api/disputes
    List all recorded disputes, with optional status/lot filters.
    """
    query = db.query(Dispute)
    if status:
        query = query.filter(Dispute.status == status.upper())
    if lot_id:
        lot = db.query(Lot).filter((Lot.id == lot_id) | (Lot.lot_code == lot_id)).first()
        if lot:
            query = query.filter(Dispute.lot_id == lot.id)
        else:
            query = query.filter(Dispute.lot_id == lot_id)

    disputes = query.order_by(Dispute.created_at.desc()).all()
    results = []
    for d in disputes:
        lot = db.query(Lot).filter(Lot.id == d.lot_id).first()
        results.append(DisputeResponse(
            id=d.id,
            lot_id=d.lot_id,
            lot_code=lot.lot_code if lot else d.lot_id,
            raised_by_id=d.raised_by_id,
            raised_by_name=d.raised_by_name,
            raised_by_role=d.raised_by_role,
            dispute_type=d.dispute_type,
            description=d.description,
            evidence_notes=d.evidence_notes,
            status=d.status,
            resolution_decision=d.resolution_decision,
            resolution_notes=d.resolution_notes,
            created_at=d.created_at.isoformat() if d.created_at else datetime.now(timezone.utc).isoformat(),
            resolved_at=d.resolved_at.isoformat() if d.resolved_at else None,
        ))
    return results


@router.get("/{dispute_id}", response_model=DisputeResponse)
def get_dispute(dispute_id: str, db: Session = Depends(get_db)):
    """
    GET /api/disputes/{dispute_id}
    Fetch a single dispute record.
    """
    d = db.query(Dispute).filter(Dispute.id == dispute_id).first()
    if not d:
        raise HTTPException(status_code=404, detail="Dispute not found")
    lot = db.query(Lot).filter(Lot.id == d.lot_id).first()
    return DisputeResponse(
        id=d.id,
        lot_id=d.lot_id,
        lot_code=lot.lot_code if lot else d.lot_id,
        raised_by_id=d.raised_by_id,
        raised_by_name=d.raised_by_name,
        raised_by_role=d.raised_by_role,
        dispute_type=d.dispute_type,
        description=d.description,
        evidence_notes=d.evidence_notes,
        status=d.status,
        resolution_decision=d.resolution_decision,
        resolution_notes=d.resolution_notes,
        created_at=d.created_at.isoformat() if d.created_at else datetime.now(timezone.utc).isoformat(),
        resolved_at=d.resolved_at.isoformat() if d.resolved_at else None,
    )


@router.patch("/{dispute_id}/resolve", response_model=DisputeResponse)
def resolve_dispute(dispute_id: str, req: DisputeResolveRequest, db: Session = Depends(get_db)):
    """
    PATCH /api/disputes/{dispute_id}/resolve
    Admin reviews evidence and records a final decision.
    """
    d = db.query(Dispute).filter(Dispute.id == dispute_id).first()
    if not d:
        raise HTTPException(status_code=404, detail="Dispute not found")

    d.status = DisputeStatus.RESOLVED if req.resolution_decision != "REJECT" else DisputeStatus.REJECTED
    d.resolution_decision = req.resolution_decision
    d.resolution_notes = req.resolution_notes
    d.resolved_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(d)

    lot = db.query(Lot).filter(Lot.id == d.lot_id).first()

    _record_audit_log(
        db=db,
        action="DISPUTE_RESOLVED",
        actor_id="ADMIN-GOVERNANCE",
        actor_role="ADMIN",
        entity_type="DISPUTE",
        entity_id=d.id,
        details={
            "lot_code": lot.lot_code if lot else d.lot_id,
            "decision": req.resolution_decision,
            "notes": req.resolution_notes,
            "adjustment_inr": req.settlement_adjustment_inr,
        }
    )

    return DisputeResponse(
        id=d.id,
        lot_id=d.lot_id,
        lot_code=lot.lot_code if lot else d.lot_id,
        raised_by_id=d.raised_by_id,
        raised_by_name=d.raised_by_name,
        raised_by_role=d.raised_by_role,
        dispute_type=d.dispute_type,
        description=d.description,
        evidence_notes=d.evidence_notes,
        status=d.status,
        resolution_decision=d.resolution_decision,
        resolution_notes=d.resolution_notes,
        created_at=d.created_at.isoformat() if d.created_at else datetime.now(timezone.utc).isoformat(),
        resolved_at=d.resolved_at.isoformat() if d.resolved_at else None,
    )
