import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import SessionLocal
from backend.app.models import Lot, HandoverEvent, RiskEvent, ChainEvent, LotStatus
from backend.app.services.ledger import verify_lot_chain_integrity

client = TestClient(app)

def test_handover_start_otp_generation():
    """Verify digital handover start produces a 6-digit OTP and schedules handover."""
    db = SessionLocal()
    lot = db.query(Lot).first()
    assert lot is not None

    res = client.post(f"/api/handover/{lot.id}/start")
    assert res.status_code == 200
    data = res.json()

    assert data["lot_id"] == lot.id
    assert "otp_code" in data
    assert len(data["otp_code"]) == 6
    assert data["otp_code"].isdigit()
    assert data["status"] == LotStatus.HANDOVER_SCHEDULED

    # Verify database state
    db.refresh(lot)
    assert lot.status == LotStatus.HANDOVER_SCHEDULED
    handover = db.query(HandoverEvent).filter(HandoverEvent.lot_id == lot.id).first()
    assert handover is not None
    assert handover.otp_code == data["otp_code"]
    assert handover.otp_verified is False
    db.close()

def test_handover_verify_scale_tolerance_success():
    """Verify dual-weight scale verification when weight is within 15% tolerance."""
    db = SessionLocal()
    lot = db.query(Lot).first()
    assert lot is not None

    # Start handover to get a fresh OTP
    start_res = client.post(f"/api/handover/{lot.id}/start").json()
    otp = start_res["otp_code"]

    # Handover with accurate scale weight (declared 8.4kg -> scale 8.5kg = ~1.2% diff)
    declared = lot.estimated_weight_kg
    scale_wt = round(declared * 1.02, 2)

    payload = {
        "lot_id": lot.id,
        "otp_code": otp,
        "scale_weight_kg": scale_wt
    }

    res = client.post("/api/handover/verify", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["success"] is True
    assert data["flagged_anomaly"] is False
    assert data["weight_deviation_pct"] < 15.0

    # Verify lot status transitioned to RECEIVED and verified weight updated
    db.refresh(lot)
    assert lot.status == LotStatus.RECEIVED
    assert lot.verified_weight_kg == scale_wt

    # Verify SHA-256 block appended
    last_block = db.query(ChainEvent).filter(
        ChainEvent.lot_id == lot.id,
        ChainEvent.event_type == "SCALE_VERIFIED_AND_HANDOVER"
    ).first()
    assert last_block is not None
    assert len(last_block.current_hash) == 64
    db.close()

def test_handover_verify_weight_mismatch_anomaly():
    """Verify dual-weight scale verification flags statistical discrepancy >15%."""
    db = SessionLocal()
    lot = db.query(Lot).first()
    assert lot is not None

    # Start handover
    start_res = client.post(f"/api/handover/{lot.id}/start").json()
    otp = start_res["otp_code"]

    # Handover with large weight mismatch (>30% difference)
    declared = lot.estimated_weight_kg
    tampered_scale_wt = round(declared * 0.50, 2) # 50% underweight

    payload = {
        "lot_id": lot.id,
        "otp_code": otp,
        "scale_weight_kg": tampered_scale_wt
    }

    res = client.post("/api/handover/verify", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["success"] is True
    assert data["flagged_anomaly"] is True
    assert data["weight_deviation_pct"] >= 15.0

    # Verify RiskEvent created in database
    risk = db.query(RiskEvent).filter(
        RiskEvent.lot_id == lot.id,
        RiskEvent.risk_type == "WEIGHT_MISMATCH"
    ).order_by(RiskEvent.created_at.desc()).first()
    assert risk is not None
    assert "Weight discrepancy detected" in risk.explanation
    db.close()

def test_lot_processing_and_settlement():
    """Verify lot closure, circular yield breakdown, and payment settlement block."""
    db = SessionLocal()
    lot = db.query(Lot).filter(Lot.category == "PCB").first() or db.query(Lot).first()
    assert lot is not None

    res = client.post(f"/api/handover/{lot.id}/process")
    assert res.status_code == 200
    data = res.json()

    assert data["status"] == LotStatus.CLOSED
    assert data["settlement_status"] == "PAID"
    assert data["payment_reference"].startswith("TXN-TN-2026-")
    assert "recovered_fractions" in data
    assert ("copper_kg" in data["recovered_fractions"] or "pure_copper_rod_kg" in data["recovered_fractions"])
    assert len(data["block_hash"]) == 64

    # Verify Block in ledger
    closed_block = db.query(ChainEvent).filter(
        ChainEvent.lot_id == lot.id,
        ChainEvent.event_type == "MATERIAL_RECOVERED_AND_CLOSED"
    ).first()
    assert closed_block is not None
    db.close()

def test_cryptographic_ledger_verification_and_tamper_detection():
    """Verify SHA-256 blockchain audit trail and immediate tamper detection."""
    db = SessionLocal()
    lot = db.query(Lot).first()
    assert lot is not None

    # 1. Check verified state initially
    verify_res = client.get(f"/api/passport/{lot.lot_code}/verify")
    assert verify_res.status_code == 200
    verify_data = verify_res.json()
    assert verify_data["cryptographic_integrity_valid"] is True
    assert verify_data["total_blocks"] >= 1

    # 2. Simulate malicious database tampering on an event block
    tampered_block = db.query(ChainEvent).filter(
        ChainEvent.lot_id == lot.id
    ).order_by(ChainEvent.timestamp.desc()).first()

    if tampered_block:
        original_hash = tampered_block.previous_hash
        tampered_block.previous_hash = "0000000000000000000000000000000000000000000000000000000000000000"
        db.commit()

        # 3. Ledger verification must detect fraud/tampering
        tampered_res = client.get(f"/api/passport/{lot.lot_code}/verify")
        assert tampered_res.status_code == 200
        tampered_data = tampered_res.json()
        assert tampered_data["cryptographic_integrity_valid"] is False
        assert tampered_data["status"] == "COMPROMISED_CHAIN"

        # 4. Restore original hash
        tampered_block.previous_hash = original_hash
        db.commit()

        restored_res = client.get(f"/api/passport/{lot.lot_code}/verify")
        assert restored_res.json()["cryptographic_integrity_valid"] is True

    db.close()

def test_circular_passport_details_and_qr():
    """Verify comprehensive Digital Product Passport payload with carbon metrics and QR."""
    db = SessionLocal()
    lot = db.query(Lot).first()
    assert lot is not None

    res = client.get(f"/api/passport/{lot.lot_code}")
    assert res.status_code == 200
    data = res.json()

    assert data["lot_code"] == lot.lot_code
    assert "qr_code_url" in data
    assert "events_timeline" in data
    assert len(data["events_timeline"]) >= 1
    assert "recovered_fractions_estimate" in data
    assert "environmental_savings" in data
    assert data["environmental_savings"]["co2e_avoided_kg"] > 0
    assert data["environmental_savings"]["toxic_heavy_metals_contained_g"] > 0
    db.close()
