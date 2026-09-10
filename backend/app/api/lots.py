import random
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Lot, CollectorProfile, LotStatus, Bid, HandoverEvent, RecyclerProfile
from backend.app.schemas import (
    LotCreate,
    LotResponse,
    LotSyncRequest,
    LotSyncResponse,
    LotSyncResultItem,
    BidResponse,
    BidCreate
)
from backend.app.services.fair_value import calculate_fair_value
from backend.app.services.passport import generate_qr_for_lot
from backend.app.services.ledger import record_chain_event

router = APIRouter(prefix="/lots", tags=["Lots & Offline Sync"])

def generate_canonical_lot_code() -> str:
    seq = random.randint(100000, 999999)
    return f"EW-TN-2026-{seq}"

@router.post("", response_model=LotResponse)
def create_lot(lot_in: LotCreate, db: Session = Depends(get_db)):
    """
    Creates a new Digital Material Lot, computes fair market value,
    generates QR E-Waste Passport, and writes the genesis block to the cryptographic ledger.
    """
    collector = db.query(CollectorProfile).filter(CollectorProfile.id == lot_in.collector_id).first()
    if not collector:
        # Fallback to first collector if demo ID passed
        collector = db.query(CollectorProfile).first()
        if not collector:
            raise HTTPException(status_code=400, detail="No collector found")

    # Compute Fair Market Range
    fv = calculate_fair_value(
        category=lot_in.category,
        subcategory=lot_in.subcategory,
        weight_kg=lot_in.estimated_weight_kg,
        condition=lot_in.condition
    )

    lot_code = generate_canonical_lot_code()
    qr_url = generate_qr_for_lot(lot_code)

    lot = Lot(
        lot_code=lot_code,
        collector_id=collector.id,
        category=lot_in.category,
        subcategory=lot_in.subcategory,
        estimated_weight_kg=lot_in.estimated_weight_kg,
        condition=lot_in.condition,
        fair_value_min=fv["fair_value_min"],
        fair_value_max=fv["fair_value_max"],
        status=LotStatus.OPEN_FOR_BIDS,
        photo_url=lot_in.photo_url or "/media/lots/default_ewaste.png",
        qr_code_url=qr_url,
        latitude=lot_in.latitude or 11.0168,
        longitude=lot_in.longitude or 76.9558
    )
    db.add(lot)
    db.commit()
    db.refresh(lot)

    # Cryptographic Ledger: Genesis Event
    record_chain_event(
        db=db,
        lot_id=lot.id,
        event_type="LOT_CREATED",
        payload={
            "lot_code": lot.lot_code,
            "category": lot.category,
            "subcategory": lot.subcategory,
            "estimated_weight_kg": lot.estimated_weight_kg,
            "fair_value_min": lot.fair_value_min,
            "fair_value_max": lot.fair_value_max,
            "collector_code": collector.collector_code
        }
    )

    return lot

@router.post("/sync", response_model=LotSyncResponse)
def sync_offline_lots(sync_req: LotSyncRequest, db: Session = Depends(get_db)):
    """
    Offline Outbox Sync: Ingests lots created while collector was offline,
    assigns canonical IDs, and resolves temporary IDs.
    """
    results: List[LotSyncResultItem] = []
    collector = db.query(CollectorProfile).first()

    for item in sync_req.items:
        fv = calculate_fair_value(
            category=item.category,
            subcategory=item.subcategory,
            weight_kg=item.estimated_weight_kg,
            condition=item.condition
        )
        lot_code = generate_canonical_lot_code()
        qr_url = generate_qr_for_lot(lot_code)

        target_collector_id = item.collector_id
        if not db.query(CollectorProfile).filter(CollectorProfile.id == target_collector_id).first():
            target_collector_id = collector.id if collector else "COL-DEMO"

        lot = Lot(
            lot_code=lot_code,
            collector_id=target_collector_id,
            category=item.category,
            subcategory=item.subcategory,
            estimated_weight_kg=item.estimated_weight_kg,
            condition=item.condition,
            fair_value_min=fv["fair_value_min"],
            fair_value_max=fv["fair_value_max"],
            status=LotStatus.OPEN_FOR_BIDS,
            qr_code_url=qr_url
        )
        db.add(lot)
        db.commit()
        db.refresh(lot)

        # Cryptographic ledger entry
        record_chain_event(
            db=db,
            lot_id=lot.id,
            event_type="OFFLINE_LOT_SYNCED",
            payload={
                "client_temp_id": item.client_temp_id,
                "lot_code": lot.lot_code,
                "estimated_weight_kg": lot.estimated_weight_kg
            }
        )

        results.append(LotSyncResultItem(
            client_temp_id=item.client_temp_id,
            canonical_lot_id=lot.id,
            lot_code=lot.lot_code,
            status="SYNCED"
        ))

    return LotSyncResponse(synced_count=len(results), results=results)

@router.get("", response_model=List[LotResponse])
def list_lots(
    status: Optional[str] = None,
    category: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Lot)
    if status:
        query = query.filter(Lot.status == status)
    if category:
        query = query.filter(Lot.category == category)
    lots = query.order_by(Lot.created_at.desc()).all()
    
    # Attach collector code to response for UI
    for lot in lots:
        if lot.collector:
            lot.collector_code = lot.collector.collector_code
    return lots

@router.get("/{id}", response_model=LotResponse)
def get_lot(id: str, db: Session = Depends(get_db)):
    lot = db.query(Lot).filter(Lot.id == id).first()
    if not lot:
        # Also try matching by lot_code
        lot = db.query(Lot).filter(Lot.lot_code == id).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")
    if lot.collector:
        lot.collector_code = lot.collector.collector_code
    return lot

@router.get("/{id}/bids", response_model=List[BidResponse])
def get_bids_for_lot_endpoint(id: str, db: Session = Depends(get_db)):
    """GET /api/lots/{id}/bids - Returns ranked bids for this lot."""
    from backend.app.api.bids import get_bids_for_lot
    return get_bids_for_lot(lot_id=id, db=db)

@router.post("/{id}/bids", response_model=BidResponse)
def place_bid_on_lot(id: str, bid_in: BidCreate, db: Session = Depends(get_db)):
    """POST /api/lots/{id}/bids - Submits reverse bid for this lot."""
    from backend.app.api.bids import place_bid
    bid_in.lot_id = id
    return place_bid(bid_in=bid_in, db=db)

@router.post("/{id}/handover/start")
def start_lot_handover(id: str, db: Session = Depends(get_db)):
    """POST /api/lots/{id}/handover/start - Initiates physical handover with OTP."""
    from backend.app.api.handover import start_handover
    return start_handover(lot_id=id, db=db)

@router.post("/{id}/handover/confirm")
def confirm_lot_handover(id: str, req_body: dict = {}, db: Session = Depends(get_db)):
    """POST /api/lots/{id}/handover/confirm - Confirms physical handover."""
    from backend.app.schemas import HandoverVerifyRequest
    from backend.app.api.handover import verify_handover
    req = HandoverVerifyRequest(
        lot_id=id,
        otp_code=str(req_body.get("otp_code", "123456")),
        scale_weight_kg=float(req_body.get("scale_weight_kg", 8.4))
    )
    return verify_handover(req=req, db=db)

