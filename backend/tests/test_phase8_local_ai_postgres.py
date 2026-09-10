import io
import pytest
from PIL import Image
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.services.local_whisper import get_whisper_model, transcribe_audio_local
from backend.app.services.local_vision import get_yolo_model, detect_components_in_image
from backend.app.database import check_db_health

client = TestClient(app)

def test_local_whisper_model_singleton():
    """Verify local Whisper model loads successfully and maintains singleton."""
    model = get_whisper_model()
    assert model is not None
    model2 = get_whisper_model()
    assert model is model2

def test_local_vision_yolo_model_singleton():
    """Verify Ultralytics YOLOv8 model loads successfully as a singleton."""
    model = get_yolo_model()
    assert model is not None
    model2 = get_yolo_model()
    assert model is model2

def test_local_vision_component_detection_pcb():
    """Verify local e-waste vision identifies PCB components by color/texture."""
    # Create synthetic PCB green image
    img = Image.new("RGB", (200, 200), color=(15, 140, 35))
    res = detect_components_in_image(img)
    assert res["material_type"] == "PRINTED_CIRCUIT_BOARD"
    assert res["category"] == "ITEW"
    assert res["confidence"] >= 0.70
    assert len(res["detected_components"]) >= 1
    assert any("Circuit Board" in c["label"] for c in res["detected_components"])

def test_local_vision_component_detection_battery():
    """Verify local e-waste vision identifies battery hazard packaging."""
    # Create synthetic battery warning yellow/black image
    img = Image.new("RGB", (200, 200), color=(220, 190, 20))
    res = detect_components_in_image(img)
    assert res["material_type"] == "BATTERY_LITHIUM_ION"
    assert res["is_hazardous"] is True
    assert res["hazard_alert"] is not None
    assert any("Battery" in c["label"] for c in res["detected_components"])

def test_ai_classify_image_endpoint_with_components():
    """Verify /api/ai/classify-image returns detected_components in response."""
    img = Image.new("RGB", (128, 128), color=(10, 150, 40))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    response = client.post(
        "/api/ai/classify-image",
        files={"file": ("pcb_sample.jpg", img_bytes, "image/jpeg")},
        data={"hint_text": "scrap motherboard"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["category"] == "PCB"
    assert data["image_analyzed"] is True
    assert "detected_components" in data
    assert data["detected_components"] is not None

def test_database_health_endpoint():
    """Verify /api/health/db reports live database engine status."""
    response = client.get("/api/health/db")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "connected"
    assert data["engine"] in ["postgresql", "sqlite"]
    assert "database" in data

def test_overall_health_endpoint_with_models():
    """Verify /api/health reports healthy with local models loaded."""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "database" in data
    assert data["local_models"]["whisper"] == "loaded"
    assert data["local_models"]["yolo_component_detector"] == "loaded"
