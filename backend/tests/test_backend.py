import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base, engine, SessionLocal
from backend.app.seed import seed_database
from backend.app.services.ledger import verify_lot_chain_integrity, record_chain_event
from backend.app.services.fair_value import detect_price_anomaly, calculate_fair_value
from backend.app.services.ai_lens import classify_material_input
from backend.app.models import Lot, ChainEvent

client = TestClient(app)

def setup_module():
    Base.metadata.create_all(bind=engine)
    seed_database()

def test_health():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"

def test_ai_lens_pcb():
    res = client.post("/api/ai/classify", data={"query_text": "I have old laptop motherboard"})
    assert res.status_code == 200
    data = res.json()
    assert data["category"] == "PCB"
    assert "Motherboard" in data["item_name"]
    assert data["confidence"] > 0.8

def test_ai_lens_battery_hazard():
    res = client.post("/api/ai/classify", data={"query_text": "swollen lithium ion battery"})
    assert res.status_code == 200
    data = res.json()
    assert data["category"] == "BATTERY"
    assert "DO_NOT_PUNCTURE" in data["safety_flags"]
    assert "CRITICAL HAZARD" in data["safety_guidance"]

def test_fair_value_calculation():
    res = client.post("/api/ai/fair-value", json={
        "category": "PCB",
        "subcategory": "IT_HIGH_GRADE_PCB",
        "weight_kg": 8.4,
        "condition": "mixed",
        "distance_km": 15.0
    })
    assert res.status_code == 200
    data = res.json()
    assert data["fair_value_min"] > 0
    assert data["fair_value_max"] > data["fair_value_min"]
    assert len(data["breakdown"]) >= 3

def test_price_anomaly_detector():
    # Min is 4700. Offer is 2950 (37.2% below min)
    is_anomaly, dev_pct, severity, reason = detect_price_anomaly(2950.0, 4700.0, 5200.0)
    assert is_anomaly is True
    assert dev_pct > 25.0
    assert severity == "HIGH"
    assert "PREDATORY OFFER" in reason

def test_cryptographic_hash_chain_integrity():
    db = SessionLocal()
    lot = db.query(Lot).first()
    assert lot is not None

    events = db.query(ChainEvent).filter(ChainEvent.lot_id == lot.id).all()
    assert len(events) >= 1
    assert verify_lot_chain_integrity(events) is True
    db.close()

def test_passport_endpoint():
    db = SessionLocal()
    lot = db.query(Lot).filter(Lot.category == "PCB").first() or db.query(Lot).first()
    db.close()

    res = client.get(f"/api/passport/{lot.lot_code}")
    assert res.status_code == 200
    data = res.json()
    assert data["lot_code"] == lot.lot_code
    assert data["ledger_integrity_valid"] is True
    assert ("copper_kg" in data["recovered_fractions_estimate"] or 
            "precious_metal_bearing_resin_kg" in data["recovered_fractions_estimate"] or
            "pure_copper_rod_kg" in data["recovered_fractions_estimate"])
    assert data["environmental_savings"]["co2e_avoided_kg"] > 0
