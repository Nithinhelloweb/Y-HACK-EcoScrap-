from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Bid, Lot, RecyclerProfile, RiskEvent, LotStatus, BidStatus
from backend.app.schemas import BidCreate, BidResponse
from backend.app.services.fair_value import detect_price_anomaly
from backend.app.services.matching import compute_recycler_match_score, calculate_haversine_distance
from backend.app.services.ledger import record_chain_event

router = APIRouter(prefix="/bids", tags=["Reverse Bidding & Anomaly Shield"])

@router.post("", response_model=BidResponse)
def place_bid(bid_in: BidCreate, db: Session = Depends(get_db)):
    """
    Submits a reverse bid from a verified recycler.
    Automatically evaluates for predatory price anomaly and computes smart match score.
    """
    lot = db.query(Lot).filter(Lot.id == bid_in.lot_id).first()
    if not lot:
        raise HTTPException(status_code=404, detail="Lot not found")

    recycler = db.query(RecyclerProfile).filter(RecyclerProfile.id == bid_in.recycler_id).first()
    if not recycler:
        recycler = db.query(RecyclerProfile).first()
        if not recycler:
            raise HTTPException(status_code=400, detail="Recycler profile missing")

    net_payable = round(bid_in.offer_price - bid_in.logistics_deduction, 2)

    # 1. Price Anomaly Detection
    is_anomaly, dev_pct, severity, reason = detect_price_anomaly(
        offer_price=bid_in.offer_price,
        fair_value_min=lot.fair_value_min,
        fair_value_max=lot.fair_value_max
    )

    if is_anomaly:
        risk_event = RiskEvent(
            lot_id=lot.id,
            risk_type="PRICE_ANOMALY_LOW",
            deviation_percentage=dev_pct,
            severity=severity,
            explanation=reason
        )
        db.add(risk_event)

    # 2. Smart Match Score
    lot_lat = lot.latitude or 11.0168
    lot_lon = lot.longitude or 76.9558
    dist = calculate_haversine_distance(lot_lat, lot_lon, recycler.latitude, recycler.longitude)
    
    mat_match = lot.category in (recycler.accepted_materials or [])

    median_fv = (lot.fair_value_min + lot.fair_value_max) / 2.0
    match_result = compute_recycler_match_score(
        offer_price=bid_in.offer_price,
        fair_value_median=median_fv,
        distance_km=dist,
        reliability_score=recycler.reliability_score,
        material_matched=mat_match
    )

    bid = Bid(
        lot_id=lot.id,
        recycler_id=recycler.id,
        offer_price=bid_in.offer_price,
        logistics_deduction=bid_in.logistics_deduction,
        net_collector_payable=net_payable,
        status=BidStatus.SUBMITTED,
        match_score=match_result["match_score"],
        is_anomaly=is_anomaly,
        anomaly_reason=reason if is_anomaly else None
    )
    db.add(bid)
    db.commit()
    db.refresh(bid)

    bid.recycler_name = recycler.org_name
    return bid

@router.post("/{id}/accept", response_model=BidResponse)
def accept_bid(id: str, db: Session = Depends(get_db)):
    """
    Collector selects and accepts a competitive bid.
    Transitions lot status and records block to tamper-evident SHA-256 ledger.
    """
    bid = db.query(Bid).filter(Bid.id == id).first()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")

    lot = bid.lot
    lot.status = LotStatus.BID_SELECTED
    bid.status = BidStatus.ACCEPTED

    # Reject other bids for this lot
    db.query(Bid).filter(Bid.lot_id == lot.id, Bid.id != bid.id).update(
        {"status": BidStatus.REJECTED}
    )

    db.commit()
    db.refresh(bid)

    # Append to Cryptographic Ledger
    record_chain_event(
        db=db,
        lot_id=lot.id,
        event_type="BID_ACCEPTED",
        payload={
            "bid_id": bid.id,
            "accepted_price_inr": bid.offer_price,
            "net_collector_payable": bid.net_collector_payable,
            "recycler_org": bid.recycler.org_name if bid.recycler else "Unknown Recycler",
            "match_score": bid.match_score
        }
    )

    if bid.recycler:
        bid.recycler_name = bid.recycler.org_name
    return bid

@router.get("/lot/{lot_id}", response_model=List[BidResponse])
def get_bids_for_lot(lot_id: str, db: Session = Depends(get_db)):
    """
    Returns all reverse bids for a specific lot, ranked by match score descending.
    """
    bids = (
        db.query(Bid)
        .filter(Bid.lot_id == lot_id)
        .order_by(Bid.match_score.desc())
        .all()
    )
    for b in bids:
        if b.recycler:
            b.recycler_name = b.recycler.org_name
    return bids
