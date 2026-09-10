import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import SessionLocal
from backend.app.models import Lot, RecyclerProfile, Bid, RiskEvent, ChainEvent, LotStatus, BidStatus
from backend.app.services.matching import compute_recycler_match_score

client = TestClient(app)

def test_reverse_bidding_submission_and_net_payable():
    """Verify reverse bid submission, net collector payable, and smart match calculation."""
    db = SessionLocal()
    lot = db.query(Lot).filter(Lot.status == LotStatus.OPEN_FOR_BIDS).first()
    recycler = db.query(RecyclerProfile).first()
    assert lot is not None and recycler is not None

    payload = {
        "lot_id": lot.id,
        "recycler_id": recycler.id,
        "offer_price": 4950.0,
        "logistics_deduction": 150.0
    }

    res = client.post("/api/bids", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["offer_price"] == 4950.0
    assert data["logistics_deduction"] == 150.0
    assert data["net_collector_payable"] == 4800.0
    assert data["match_score"] >= 80.0
    assert data["is_anomaly"] is False
    db.close()

def test_predatory_bid_anomaly_shield():
    """Verify statistical anomaly detector flags predatory lowball offers (<25% of min)."""
    db = SessionLocal()
    lot = db.query(Lot).filter(Lot.status == LotStatus.OPEN_FOR_BIDS).first()
    recycler = db.query(RecyclerProfile).first()
    assert lot is not None and recycler is not None

    fair_min = lot.fair_value_min
    predatory_offer = round(fair_min * 0.60, 2) # 40% below fair floor!

    payload = {
        "lot_id": lot.id,
        "recycler_id": recycler.id,
        "offer_price": predatory_offer,
        "logistics_deduction": 100.0
    }

    res = client.post("/api/bids", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["is_anomaly"] is True
    assert "PREDATORY OFFER" in data["anomaly_reason"]

    # Verify a RiskEvent was created in database
    risk_events = db.query(RiskEvent).filter(RiskEvent.lot_id == lot.id).all()
    assert len(risk_events) >= 1
    recent_risk = [r for r in risk_events if r.risk_type == "PRICE_ANOMALY_LOW"]
    assert len(recent_risk) >= 1
    assert recent_risk[0].severity == "HIGH"
    db.close()

def test_smart_matching_scoring_weights():
    """Verify smart matching weighs price, proximity, reliability, and material specialization."""
    # Scenario 1: High price, close distance (5km), high reliability (96%), material matched
    match1 = compute_recycler_match_score(
        offer_price=5100.0,
        fair_value_median=5000.0,
        distance_km=5.0,
        reliability_score=96.0,
        material_matched=True
    )
    # Scenario 2: Low price, far distance (50km), lower reliability (75%), material unmatched
    match2 = compute_recycler_match_score(
        offer_price=3500.0,
        fair_value_median=5000.0,
        distance_km=50.0,
        reliability_score=75.0,
        material_matched=False
    )

    assert match1["match_score"] > match2["match_score"]
    assert match1["is_recommended"] is True
    assert match2["is_recommended"] is False
    assert len(match1["reasons"]) >= 3

def test_bid_acceptance_and_chain_block_generation():
    """Verify bid acceptance updates lot status, rejects competing bids, and writes SHA-256 block."""
    db = SessionLocal()
    lot = db.query(Lot).filter(Lot.status == LotStatus.OPEN_FOR_BIDS).first()
    assert lot is not None

    bids = db.query(Bid).filter(Bid.lot_id == lot.id, Bid.status == BidStatus.SUBMITTED).all()
    assert len(bids) >= 2, "Expected at least 2 submitted bids"
    winning_bid = bids[0]
    competing_bid = bids[1]

    res = client.post(f"/api/bids/{winning_bid.id}/accept")
    assert res.status_code == 200

    db.refresh(lot)
    db.refresh(winning_bid)
    db.refresh(competing_bid)

    assert lot.status == LotStatus.BID_SELECTED
    assert winning_bid.status == BidStatus.ACCEPTED
    assert competing_bid.status == BidStatus.REJECTED

    # Verify BID_ACCEPTED event block appended to cryptographic chain
    latest_event = (
        db.query(ChainEvent)
        .filter(ChainEvent.lot_id == lot.id)
        .order_by(ChainEvent.timestamp.desc())
        .first()
    )
    assert latest_event is not None
    assert latest_event.event_type == "BID_ACCEPTED"
    assert latest_event.payload_json["accepted_price_inr"] == winning_bid.offer_price
    db.close()

def test_get_bids_ranked_for_lot():
    """Verify GET /api/bids/lot/{lot_id} returns bids ranked by match score."""
    db = SessionLocal()
    lot = db.query(Lot).join(Bid).first()
    assert lot is not None
    db.close()

    res = client.get(f"/api/bids/lot/{lot.id}")
    assert res.status_code == 200
    bids = res.json()
    assert len(bids) >= 1
    # Check descending order of match_score
    scores = [b["match_score"] for b in bids]
    assert scores == sorted(scores, reverse=True)
