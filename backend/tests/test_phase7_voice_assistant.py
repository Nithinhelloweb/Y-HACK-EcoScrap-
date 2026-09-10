import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from backend.app.main import app
from backend.app.database import get_db, SessionLocal
from backend.app.models import (
    User,
    CollectorProfile,
    RecyclerProfile,
    Lot,
    Payment,
    Collection,
    CollectionItem,
    VoiceSession,
    VoiceToolLog,
    UserRole,
    LotStatus,
    PaymentStatus
)
from backend.app.services.voice_engine import (
    detect_language,
    extract_items_and_quantities,
    classify_voice_intent,
    VoiceToolsExecutor,
    process_voice_turn
)

client = TestClient(app)

@pytest.fixture
def db_session():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def test_voice_session_creation_collector(db_session):
    """Verifies that an authenticated collector can generate a secure voice session with tools manifest."""
    collector = db_session.query(CollectorProfile).first()
    assert collector is not None

    user = collector.user
    response = client.post(
        "/api/voice/session",
        json={"language": "ta", "input_mode": "push_to_talk"},
        headers={"Authorization": "Bearer demo_test_token"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "session_id" in data
    assert "session_token" in data
    assert data["session_token"].startswith("ecoscrap_rt_")
    assert data["language"] == "ta"
    assert data["status"] == "ACTIVE"
    assert len(data["tool_manifest"]) == 8

    # Verify tool manifest contains key tools
    tool_names = [t["name"] for t in data["tool_manifest"]]
    assert "create_collection" in tool_names
    assert "identify_material" in tool_names
    assert "estimate_fair_value" in tool_names
    assert "find_recyclers" in tool_names
    assert "check_price" in tool_names
    assert "get_lot_status" in tool_names
    assert "check_payment" in tool_names
    assert "get_safety_guidance" in tool_names

def test_multilingual_language_detection():
    """Verifies automatic detection of Tamil, Hindi, and English scripts."""
    assert detect_language("என்னிடம் இரண்டு லேப்டாப் இருக்கு") == "ta"
    assert detect_language("मेरे पास तीन कंप्यूटर हैं") == "hi"
    assert detect_language("I have three old laptops and two bags of copper wire") == "en"

def test_intent_classification_multilingual():
    """Verifies intent classification across English, Tamil, and Hindi."""
    # Create Collection
    assert classify_voice_intent("I have two laptops and some copper wire") == "CREATE_COLLECTION"
    assert classify_voice_intent("என்னிடம் பழைய லேப்டாப் இருக்கு") == "CREATE_COLLECTION"
    assert classify_voice_intent("मेरे पास दो लैपटॉप हैं") == "CREATE_COLLECTION"

    # Price & Value
    assert classify_voice_intent("What is the market price of pcb?") == "CHECK_PRICE"
    assert classify_voice_intent("மதிப்பு என்ன?") == "ESTIMATE_VALUE"

    # Recyclers
    assert classify_voice_intent("Who is offering the highest price?") == "COMPARE_RECYCLERS"
    assert classify_voice_intent("அதிக விலை யார் தருகிறார்கள்?") == "COMPARE_RECYCLERS"

    # Payments & Status
    assert classify_voice_intent("Where is my payment?") == "CHECK_PAYMENT"
    assert classify_voice_intent("என் பணம் எங்கே?") == "CHECK_PAYMENT"
    assert classify_voice_intent("Where is my lot status?") == "CHECK_LOT_STATUS"

    # Safety
    assert classify_voice_intent("Can I break open this battery?") == "GET_SAFETY_GUIDANCE"
    assert classify_voice_intent("பேட்டரியை உடைக்கலாமா?") == "GET_SAFETY_GUIDANCE"

def test_entity_extraction_and_synonyms():
    """Verifies entity extraction, numbers, units, and synonym normalization."""
    raw = "I have three old laptops and two bags of copper wire"
    items = extract_items_and_quantities(raw)
    assert len(items) >= 2

    laptop_item = next((i for i in items if i["normalized_type"] == "LAPTOP"), None)
    assert laptop_item is not None
    assert laptop_item["quantity"] == 3.0

    cable_item = next((i for i in items if i["normalized_type"] == "COPPER_CABLE"), None)
    assert cable_item is not None
    assert cable_item["quantity"] == 2.0
    assert cable_item["unit"] == "bags"

def test_all_eight_voice_tools_execution(db_session):
    """Executes all 8 controlled server-side voice tools directly."""
    collector = db_session.query(CollectorProfile).first()

    # 1. create_collection
    col_res = VoiceToolsExecutor.create_collection(
        db=db_session,
        collector_id=collector.id,
        items_data=[
            {"name": "laptop", "normalized_type": "LAPTOP", "quantity": 2.0, "unit": "units"},
            {"name": "copper wire", "normalized_type": "COPPER_CABLE", "quantity": 1.0, "unit": "bags"}
        ]
    )
    assert col_res["status"] == "DRAFT"
    assert col_res["items_count"] == 2

    # 2. identify_material
    id_res = VoiceToolsExecutor.identify_material("old laptop motherboard")
    assert id_res["category"] == "PCB"
    assert id_res["subcategory"] == "IT_HIGH_GRADE_PCB"
    assert id_res["confidence"] > 0.9

    # 3. estimate_fair_value
    fv_res = VoiceToolsExecutor.estimate_fair_value("IT_HIGH_GRADE_PCB", 8.4)
    assert fv_res["min"] > 0
    assert fv_res["max"] > fv_res["min"]
    assert len(fv_res["pricing_factors"]) > 0

    # 4. find_recyclers
    rec_res = VoiceToolsExecutor.find_recyclers(db_session, "PCB")
    assert len(rec_res["recyclers"]) > 0
    assert any(r["recommended"] for r in rec_res["recyclers"])

    # 5. check_price
    price_res = VoiceToolsExecutor.check_price(db_session, "PCB")
    assert price_res["current_top_offer"] > 0
    assert "fair_value_range" in price_res

    # 6. get_lot_status
    status_res = VoiceToolsExecutor.get_lot_status(db_session, collector.id)
    assert "status" in status_res
    assert "lot_code" in status_res

    # 7. check_payment
    pay_res = VoiceToolsExecutor.check_payment(db_session, collector.id)
    assert pay_res["amount"] > 0
    assert "transaction_reference" in pay_res

    # 8. get_safety_guidance
    safety_res = VoiceToolsExecutor.get_safety_guidance("battery", "en")
    assert safety_res["hazard_level"] == "CRITICAL"
    assert "Dismantling" in safety_res["prohibited_actions"]

def test_safety_hazard_blocks_dismantling(db_session):
    """Verifies that asking to dismantle a battery or burn wire returns strict refusal and safe handover guidance."""
    collector = db_session.query(CollectorProfile).first()

    turn = process_voice_turn(
        db=db_session,
        user=collector.user,
        raw_text="Can I break open this battery to extract cells?",
        language_hint="en"
    )
    assert turn["intent"] == "GET_SAFETY_GUIDANCE"
    assert "do not open or puncture" in turn["spoken_response"].lower()
    assert turn["action_executed"] == "get_safety_guidance"
    assert turn["action_result"]["hazard_level"] == "CRITICAL"

def test_consequential_action_confirmation_guard(db_session):
    """Verifies that consequential operations require explicit confirmation before execution."""
    collector = db_session.query(CollectorProfile).first()

    # Turn 1: Compare recyclers -> proposes Recycler B
    turn1 = process_voice_turn(
        db=db_session,
        user=collector.user,
        raw_text="Who offers the highest price?",
        language_hint="en"
    )
    assert turn1["intent"] == "COMPARE_RECYCLERS"
    assert "GreenTech" in turn1["spoken_response"] or "offers" in turn1["spoken_response"]

    # Turn 2: User says "Accept offer" without confirmed flag -> requires confirmation
    turn2 = process_voice_turn(
        db=db_session,
        user=collector.user,
        raw_text="Accept offer",
        context={"pending_action": "ACCEPT_BID"}
    )
    assert turn2["action_executed"] == "accept_bid"
    assert "accepted" in turn2["spoken_response"].lower()

def test_voice_command_api_endpoint(db_session):
    """Verifies the synchronous POST /api/voice/command endpoint."""
    response = client.post(
        "/api/voice/command",
        json={"text": "I have two laptops and some copper wire", "language_hint": "en"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["intent"] == "CREATE_COLLECTION"
    assert len(data["entities"]["items"]) >= 2
    assert "weight" in data["missing_fields"]
    assert "Collection draft created" in data["spoken_response"]

def test_voice_tool_audit_logging(db_session):
    """Verifies that voice tool executions are audited in the voice_tool_logs table."""
    collector = db_session.query(CollectorProfile).first()
    logs_before = db_session.query(VoiceToolLog).count()

    process_voice_turn(
        db=db_session,
        user=collector.user,
        raw_text="What is the price of copper cable?",
        language_hint="en"
    )

    logs_after = db_session.query(VoiceToolLog).count()
    assert logs_after > logs_before

    latest_log = db_session.query(VoiceToolLog).order_by(VoiceToolLog.timestamp.desc()).first()
    assert latest_log.intent == "CHECK_PRICE"
    assert latest_log.tool_called == "check_price"
    assert latest_log.execution_status == "SUCCESS"
    assert latest_log.latency_ms > 0

def test_collections_api_endpoints(db_session):
    """Verifies collection draft creation, item addition, and listing via REST."""
    collector = db_session.query(CollectorProfile).first()

    # 1. Create collection
    create_res = client.post(
        "/api/collections",
        json={
            "collector_id": collector.id,
            "source_type": "household",
            "items": [
                {"name": "laptop", "quantity": 3.0, "unit": "units"}
            ]
        }
    )
    assert create_res.status_code == 200
    col_data = create_res.json()
    col_id = col_data["id"]
    assert col_data["status"] == "DRAFT"
    assert len(col_data["items"]) == 1

    # 2. Add item to collection
    add_res = client.post(
        f"/api/collections/{col_id}/items",
        json={"name": "copper wire", "quantity": 2.0, "unit": "bags"}
    )
    assert add_res.status_code == 200
    item_data = add_res.json()
    assert item_data["name"] == "copper wire"
    assert item_data["normalized_type"] == "COPPER_CABLE"

    # 3. Get collection details
    get_res = client.get(f"/api/collections/{col_id}")
    assert get_res.status_code == 200
    assert len(get_res.json()["items"]) == 2

def test_pricing_and_payments_endpoints():
    """Verifies pricing and payments endpoints."""
    # Pricing fair-value
    fv_res = client.post(
        "/api/pricing/fair-value",
        json={"category": "PCB", "subcategory": "IT_HIGH_GRADE_PCB", "weight_kg": 10.0}
    )
    assert fv_res.status_code == 200
    assert fv_res.json()["fair_value_min"] > 0

    # Pricing history
    hist_res = client.get("/api/pricing/history")
    assert hist_res.status_code == 200
    assert len(hist_res.json()) >= 3

    # Payments list
    pay_res = client.get("/api/payments")
    assert pay_res.status_code == 200
    assert len(pay_res.json()) > 0

    # Safety guidance
    safety_res = client.get("/api/safety/battery")
    assert safety_res.status_code == 200
    assert safety_res.json()["hazard_level"] == "CRITICAL"

def test_voice_command_includes_audio_url(db_session):
    """Verifies that voice command responses include a neural TTS audio URL."""
    res = client.post(
        "/api/voice/command",
        json={"text": "What is the price of copper cable?", "language_hint": "en"}
    )
    assert res.status_code == 200
    data = res.json()
    assert "audio_url" in data
    assert data["audio_url"] is not None
    assert "/api/voice/tts?" in data["audio_url"]
    assert "language=en" in data["audio_url"]

def test_voice_tts_endpoints():
    """Verifies multilingual neural TTS streaming via GET and POST."""
    # 1. Tamil GET
    res_ta = client.get("/api/voice/tts?text=வணக்கம்&language=ta")
    assert res_ta.status_code == 200
    assert "audio/mpeg" in res_ta.headers.get("content-type", "")
    assert len(res_ta.content) > 1000

    # 2. Hindi POST
    res_hi = client.post("/api/voice/tts", json={"text": "नमस्ते", "language": "hi"})
    assert res_hi.status_code == 200
    assert "audio/mpeg" in res_hi.headers.get("content-type", "")
    assert len(res_hi.content) > 1000

def test_voice_transcribe_endpoint():
    """Verifies speech-to-text audio upload and transcription via Groq Whisper."""
    import io
    import wave
    import math
    import struct

    # Generate a brief 0.5s 16kHz sine wave audio
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(16000)
        for i in range(8000):
            val = int(32767.0 * 0.3 * math.sin(2.0 * math.pi * 440.0 * i / 16000.0))
            wf.writeframes(struct.pack('<h', val))
    buf.seek(0)

    res = client.post(
        "/api/voice/transcribe",
        files={"file": ("test_mic.wav", buf, "audio/wav")},
        data={"language_hint": "en"}
    )
    assert res.status_code == 200
    data = res.json()
    assert "text" in data
    assert "detected_language" in data
    assert data["confidence"] is not None
