import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base, engine
from backend.app.seed import seed_database
from backend.app.services.voice_engine import (
    classify_voice_intent,
    extract_items_and_quantities,
    extract_numbers,
    extract_weight_kg,
)

client = TestClient(app)

def setup_module():
    Base.metadata.create_all(bind=engine)
    seed_database()

class TestVoiceAgentNLUAccuracy:
    def test_vernacular_tamil_numbers_and_intent(self):
        tamil_text = "இரண்டு பழைய லேப்டாப் விலை என்ன?"
        intent = classify_voice_intent(tamil_text)
        assert intent == "CHECK_PRICE"

        items = extract_items_and_quantities(tamil_text)
        assert len(items) == 1
        assert items[0]["normalized_type"] == "LAPTOP"
        assert items[0]["quantity"] == 2.0

    def test_vernacular_hindi_numbers_and_intent(self):
        hindi_text = "तीन कंप्यूटर का दाम क्या है?"
        intent = classify_voice_intent(hindi_text)
        assert intent == "CHECK_PRICE"

        items = extract_items_and_quantities(hindi_text)
        assert len(items) == 1
        assert items[0]["normalized_type"] == "LAPTOP"
        assert items[0]["quantity"] == 3.0

    def test_english_multi_item_extraction(self):
        en_text = "I have three old laptops and two bags of copper wire"
        intent = classify_voice_intent(en_text)
        assert intent == "CREATE_COLLECTION"

        items = extract_items_and_quantities(en_text)
        assert len(items) == 2
        laptop_item = next(i for i in items if i["normalized_type"] == "LAPTOP")
        copper_item = next(i for i in items if i["normalized_type"] == "COPPER_CABLE")
        assert laptop_item["quantity"] == 3.0
        assert copper_item["quantity"] == 2.0
        assert copper_item["unit"] == "bags"

    def test_safety_guidance_intent_override(self):
        hazard_text = "How should I safely handle swollen lithium-ion laptop batteries?"
        intent = classify_voice_intent(hazard_text)
        assert intent == "GET_SAFETY_GUIDANCE"

    def test_recycler_matching_intent(self):
        recycler_text = "Find verified recyclers near me with best price"
        intent = classify_voice_intent(recycler_text)
        assert intent in ["FIND_RECYCLER", "COMPARE_RECYCLERS"]

class TestVoiceApiFullLevelInformation:
    def test_price_intelligence_full_payload(self):
        res = client.post("/api/voice/command", json={
            "text": "What is the CPCB benchmark price for laptops?",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["intent"] == "CHECK_PRICE"
        assert "spoken_response" in data and len(data["spoken_response"]) > 0

        action = data.get("action_result", {})
        assert "rate_per_kg" in action
        assert "unit_rate" in action
        assert "current_top_offer" in action
        assert "fair_value_range" in action
        assert "difference_percentage" in action

    def test_safety_guidance_full_payload(self):
        res = client.post("/api/voice/command", json={
            "text": "Can I open swollen lithium batteries?",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["intent"] == "GET_SAFETY_GUIDANCE"
        action = data.get("action_result", {})
        assert action.get("hazard_level") == "CRITICAL"
        assert "instructions" in action and len(action["instructions"]) > 0
        assert "prohibited_actions" in action

    def test_recycler_comparison_full_payload(self):
        res = client.post("/api/voice/command", json={
            "text": "Who offers the highest price for my PCB lot?",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["intent"] in ["COMPARE_RECYCLERS", "FIND_RECYCLER"]
        action = data.get("action_result", {})
        assert "recyclers" in action
        assert len(action["recyclers"]) > 0
        top = action["recyclers"][0]
        assert "name" in top
        assert "price" in top
        assert "distance_km" in top
        assert "reliability_score" in top
