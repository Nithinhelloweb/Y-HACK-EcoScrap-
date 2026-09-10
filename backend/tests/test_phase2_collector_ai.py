import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.services.ai_lens import classify_material_input
from backend.app.services.fair_value import calculate_fair_value
from backend.app.database import SessionLocal
from backend.app.models import CollectorProfile, Lot, ChainEvent

client = TestClient(app)

def test_ai_lens_3tier_hierarchy_pcb():
    """Verify 3-tier classification hierarchy for high-grade PCB."""
    res = classify_material_input(query_text="high grade laptop motherboard with intel cpu")
    assert res["category"] == "PCB"
    assert res["subcategory"] == "IT_HIGH_GRADE_PCB"
    assert "Motherboard" in res["item_name"]
    assert "Gold/Palladium" in res["grade"]
    assert res["confidence"] >= 0.90
    assert res["estimated_base_rate_per_kg"] >= 500.0

def test_ai_lens_3tier_hierarchy_battery_hazard():
    """Verify safety protocol & hazard detection on lithium batteries."""
    res = classify_material_input(query_text="old 18650 li-ion battery cells pack")
    assert res["category"] == "BATTERY"
    assert res["subcategory"] == "LITHIUM_ION"
    assert "THERMAL_RUNAWAY_RISK" in res["safety_flags"]
    assert "DO_NOT_PUNCTURE" in res["safety_flags"]
    assert "CRITICAL HAZARD" in res["safety_guidance"]

def test_ai_lens_3tier_hierarchy_copper_cables():
    """Verify copper cable classification and anti-burning safety flag."""
    res = classify_material_input(query_text="heavy copper cables and telecom wires")
    assert res["category"] == "CABLE"
    assert res["subcategory"] == "COPPER_RICH_CABLE"
    assert "DO_NOT_BURN_PVC" in res["safety_flags"]

def test_fair_value_engine_bulk_and_condition():
    """Verify fair value calculations include bulk bonus and condition adjustments."""
    # Test 1: Standard intact lot (8 kg)
    fv_standard = calculate_fair_value(
        category="PCB",
        subcategory="IT_HIGH_GRADE_PCB",
        weight_kg=8.0,
        condition="intact",
        distance_km=10.0
    )
    assert fv_standard["fair_value_min"] > 0
    assert fv_standard["fair_value_max"] > fv_standard["fair_value_min"]
    factors_standard = [f["name"] for f in fv_standard["breakdown"]]
    assert "Base Regional Market Rate" in factors_standard
    assert "Grade & Precious Fraction Premium" in factors_standard

    # Test 2: Bulk lot (>15 kg) gets bulk volume incentive
    fv_bulk = calculate_fair_value(
        category="PCB",
        subcategory="IT_HIGH_GRADE_PCB",
        weight_kg=20.0,
        condition="intact",
        distance_km=10.0
    )
    factors_bulk = [f["name"] for f in fv_bulk["breakdown"]]
    assert "Bulk Weight Bonus" in factors_bulk

    # Test 3: Dismantled condition applies handling deduction
    fv_dismantled = calculate_fair_value(
        category="PCB",
        subcategory="IT_HIGH_GRADE_PCB",
        weight_kg=8.0,
        condition="dismantled",
        distance_km=10.0
    )
    factors_dismantled = [f["name"] for f in fv_dismantled["breakdown"]]
    assert "Dismantled Handling Deduction" in factors_dismantled
    assert fv_dismantled["fair_value_median"] < fv_standard["fair_value_median"]

def test_offline_lots_batch_sync_api():
    """Verify offline lots batch upload, canonical ID issuance, and ledger chaining."""
    db = SessionLocal()
    collector = db.query(CollectorProfile).first()
    db.close()
    assert collector is not None

    sync_payload = {
        "items": [
            {
                "client_temp_id": "OFFLINE-TEST-001",
                "collector_id": collector.id,
                "category": "CABLE",
                "subcategory": "COPPER_RICH_CABLE",
                "estimated_weight_kg": 12.5,
                "condition": "intact"
            },
            {
                "client_temp_id": "OFFLINE-TEST-002",
                "collector_id": collector.id,
                "category": "PCB",
                "subcategory": "LOW_GRADE_PCB",
                "estimated_weight_kg": 6.0,
                "condition": "mixed"
            }
        ]
    }

    res = client.post("/api/lots/sync", json=sync_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["synced_count"] == 2
    assert len(data["results"]) == 2

    # Verify canonical lot codes assigned
    res1 = data["results"][0]
    assert res1["client_temp_id"] == "OFFLINE-TEST-001"
    assert res1["lot_code"].startswith("EW-TN-2026-")
    assert res1["status"] == "SYNCED"

    # Verify ledger block was recorded
    db = SessionLocal()
    synced_lot = db.query(Lot).filter(Lot.id == res1["canonical_lot_id"]).first()
    assert synced_lot is not None
    chain_events = db.query(ChainEvent).filter(ChainEvent.lot_id == synced_lot.id).all()
    assert len(chain_events) >= 1
    assert chain_events[0].event_type == "OFFLINE_LOT_SYNCED"
    db.close()

def test_collector_profile_trust_score():
    """Verify collector profile exposes credibility and collection metrics."""
    db = SessionLocal()
    collector = db.query(CollectorProfile).first()
    assert collector.trust_score >= 90.0
    assert collector.total_collections_count > 0
    assert collector.collector_code.startswith("COL-TN-")
    db.close()
