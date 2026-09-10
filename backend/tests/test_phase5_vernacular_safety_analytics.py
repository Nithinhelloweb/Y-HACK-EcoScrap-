import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)

def test_voice_parse_tamil_scrap_intent():
    """Verify Tamil speech intent parsing extracts weight and classifies cable."""
    res = client.post("/api/voice/parse", json={"text": "10 கிலோ தாமிர கம்பி"})
    assert res.status_code == 200
    data = res.json()

    assert data["detected_language"] == "ta"
    assert data["category"] == "CABLE"
    assert data["subcategory"] == "COPPER_RICH_CABLE"
    assert data["weight_kg"] == 10.0
    assert data["is_hazard"] is False
    assert "10.0" in data["confirmation_message"] or "10" in data["confirmation_message"]

def test_voice_parse_tamil_swollen_battery_hazard():
    """Verify Tamil voice parser identifies swollen battery hazard alert."""
    res = client.post("/api/voice/parse", json={"text": "வீங்கிய லித்தியம் பேட்டரி"})
    assert res.status_code == 200
    data = res.json()

    assert data["detected_language"] == "ta"
    assert data["category"] == "BATTERY"
    assert data["is_hazard"] is True
    assert "CRITICAL" in data["hazard_reason"] or "Swollen" in data["hazard_reason"]

def test_voice_parse_hindi_scrap_intent():
    """Verify Hindi speech intent parsing extracts weight and classifies high-grade PCB."""
    res = client.post("/api/voice/parse", json={"text": "5 किलो पुराना लैपटॉप मदरबोर्ड"})
    assert res.status_code == 200
    data = res.json()

    assert data["detected_language"] == "hi"
    assert data["category"] == "PCB"
    assert data["subcategory"] == "IT_HIGH_GRADE_PCB"
    assert data["weight_kg"] == 5.0
    assert data["is_hazard"] is False

def test_voice_parse_english_and_code_mixed():
    """Verify English scrap prompt parses weight and category."""
    res = client.post("/api/voice/parse", json={"text": "15kg heavy copper cables and wires"})
    assert res.status_code == 200
    data = res.json()

    assert data["detected_language"] == "en"
    assert data["category"] == "CABLE"
    assert data["weight_kg"] == 15.0

def test_safety_assess_swollen_lithium_battery():
    """Verify Safety AI flags swollen lithium battery as CRITICAL hazard with sand bucket containment."""
    payload = {
        "category": "BATTERY",
        "subcategory": "LITHIUM_ION",
        "condition": "swollen and bulging"
    }
    res = client.post("/api/safety/assess", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["hazard_level"] == "CRITICAL"
    assert data["hazard_type"] == "THERMAL_RUNAWAY_PUNCTURE"
    assert data["urgency"] == "SAND_BUCKET_CONTAINMENT"
    assert "handling_sop_ta" in data
    assert "handling_sop_hi" in data
    assert len(data["mandatory_ppe"]) >= 1

def test_safety_assess_lead_acid_corrosive():
    """Verify Safety AI flags Lead Acid battery with acid burn and lead toxicity warnings."""
    payload = {
        "category": "BATTERY",
        "subcategory": "LEAD_ACID",
        "condition": "cracked"
    }
    res = client.post("/api/safety/assess", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert data["hazard_level"] == "CRITICAL"
    assert data["hazard_type"] == "CORROSIVE_ACID_LEAD"
    assert data["urgency"] == "IMMEDIATE_UPRIGHT_ISOLATION"

def test_safety_protocols_endpoint():
    """Verify standard safety SOPs are returned in multilingual format."""
    res = client.get("/api/safety/protocols")
    assert res.status_code == 200
    data = res.json()

    assert "SWOLLEN_LITHIUM_BATTERY" in data
    assert "CRT_MONITOR_LEAD_GLASS" in data
    assert "LEAD_ACID_INVERTER" in data
    assert "CABLE_OPEN_BURNING" in data

def test_admin_metrics_circularity_and_anomalies():
    """Verify enriched Admin KPI dashboard metrics including toxic containment and material breakdown."""
    res = client.get("/api/admin/metrics")
    assert res.status_code == 200
    data = res.json()

    assert data["total_lots_created"] >= 1
    assert data["total_ewaste_diverted_kg"] >= 0
    assert data["co2e_avoided_kg"] >= 0
    assert data["toxic_heavy_metals_contained_g"] >= 0
    assert data["landfill_space_saved_liters"] >= 0
    assert data["trees_offset_equivalent"] >= 0
    assert "category_distribution" in data
    assert "recent_anomalies" in data
    assert data["chain_integrity_status"] == "ALL_LEDGERS_SECURE"
