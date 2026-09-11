"""
test_phase12_disputes_duplicate_and_recovery.py
Unit & integration tests verifying:
  1. Dispute raising by collector
  2. Dispute listing and filtering
  3. Admin dispute resolution with audit logging
  4. Duplicate lot detection calculation and reasons
  5. Geographic intelligence regional hubs
  6. Formal ecosystem integrations readiness
  7. Audit logging capture
  8. Recycler material recovery fractions recording
"""
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)

def test_raise_and_list_dispute():
    # 1. Get an existing lot
    lots_res = client.get("/api/lots")
    assert lots_res.status_code == 200
    lots = lots_res.json()
    assert len(lots) > 0
    test_lot = lots[0]

    # 2. Raise dispute
    disp_payload = {
        "lot_id": test_lot["id"],
        "raised_by_id": test_lot["collector_id"],
        "raised_by_name": "Murugan K.",
        "raised_by_role": "COLLECTOR",
        "dispute_type": "WEIGHT_MISMATCH",
        "description": "Recycler scale declared 8.1kg vs collector calibrated scale 8.4kg.",
        "evidence_notes": "Weighbridge printout receipt attached."
    }
    create_res = client.post("/api/disputes", json=disp_payload)
    assert create_res.status_code == 200, create_res.text
    dispute_data = create_res.json()
    assert dispute_data["lot_id"] == test_lot["id"]
    assert dispute_data["status"] == "NEW"
    assert dispute_data["dispute_type"] == "WEIGHT_MISMATCH"
    dispute_id = dispute_data["id"]

    # 3. List disputes
    list_res = client.get("/api/disputes")
    assert list_res.status_code == 200
    all_disputes = list_res.json()
    assert any(d["id"] == dispute_id for d in all_disputes)

    # 4. Resolve dispute as Admin
    resolve_payload = {
        "resolution_decision": "PARTIAL_SETTLEMENT",
        "resolution_notes": "Split weight discrepancy at 8.25kg, credited difference of INR 150.",
        "settlement_adjustment_inr": 150.0
    }
    resolve_res = client.patch(f"/api/disputes/{dispute_id}/resolve", json=resolve_payload)
    assert resolve_res.status_code == 200
    res_data = resolve_res.json()
    assert res_data["status"] == "RESOLVED"
    assert res_data["resolution_decision"] == "PARTIAL_SETTLEMENT"


def test_duplicate_lot_detection():
    # Query duplicate check with identical specs to Lot 1
    dup_payload = {
        "category": "PCB",
        "subcategory": "IT_HIGH_GRADE_PCB",
        "estimated_weight_kg": 8.4,
        "tolerance_weight_pct": 10.0
    }
    res = client.post("/api/admin/check-duplicate-lot", json=dup_payload)
    assert res.status_code == 200
    data = res.json()
    assert "is_suspected_duplicate" in data
    assert "highest_similarity_score" in data
    assert len(data["matches"]) > 0
    # Should flag high similarity since category, subcategory, and weight match lot 1
    assert data["highest_similarity_score"] >= 80.0
    assert data["is_suspected_duplicate"] is True


def test_geographic_intelligence():
    res = client.get("/api/admin/geographic-intelligence")
    assert res.status_code == 200
    data = res.json()
    assert data["total_hubs"] >= 4
    hub_names = [h["hub_name"] for h in data["hubs"]]
    assert any("Coimbatore" in h for h in hub_names)
    assert any("Pollachi" in h for h in hub_names)
    assert any("Tiruppur" in h for h in hub_names)


def test_ecosystem_integrations():
    res = client.get("/api/admin/integrations")
    assert res.status_code == 200
    data = res.json()
    assert data["total_connectors"] >= 5
    codes = [c["system_code"] for c in data["connectors"]]
    assert "CPCB-PORTAL" in codes
    assert "TNPCB-REG" in codes
    assert "BANK-ESCROW" in codes
    # Verify non-negotiable rule: Payment is clearly marked simulated
    escrow = next(c for c in data["connectors"] if c["system_code"] == "BANK-ESCROW")
    assert escrow["integration_status"] == "SIMULATED"


def test_audit_logs_endpoint():
    res = client.get("/api/admin/audit-logs")
    assert res.status_code == 200
    data = res.json()
    assert "logs" in data
    assert data["total_logs"] > 0
    actions = [l["action"] for l in data["logs"]]
    assert any("DISPUTE" in a or "USER" in a or "LOT" in a for a in actions)


def test_recycler_recovery_recording():
    # Fetch or create a lot in processing
    lots_res = client.get("/api/lots")
    lots = lots_res.json()
    target_lot = next((l for l in lots if l["status"] in ["HANDOVER_SCHEDULED", "PROCESSING", "RECEIVED"]), lots[0])
    if target_lot["status"] not in ["HANDOVER_SCHEDULED", "PROCESSING", "RECEIVED"]:
        from backend.app.database import SessionLocal
        from backend.app.models import Lot, LotStatus
        with SessionLocal() as db:
            l = db.query(Lot).filter(Lot.id == target_lot["id"]).first()
            if l:
                l.status = LotStatus.PROCESSING
                db.commit()

    # Record actual recovered material fractions
    rec_payload = {
        "lot_id": target_lot["id"],
        "recovered_fractions": {
            "Copper_kg": 1.85,
            "Plastics_kg": 2.94,
            "Gold_g": 0.42,
            "Steel_kg": 2.10
        },
        "notes": "Completed hydrometallurgical dismantling at SIDCO yard."
    }
    rec_res = client.post(f"/api/lots/{target_lot['id']}/recovery", json=rec_payload)
    assert rec_res.status_code == 200
    rec_data = rec_res.json()
    assert rec_data["status"] == "OK"
    assert rec_data["lot_status"] == "MATERIAL_RECOVERED"
    assert "Copper_kg" in rec_data["recovered_materials"]
    assert rec_data["total_recovered_weight_kg"] > 0
