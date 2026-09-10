import io
import base64
import os
import pytest
from PIL import Image, ImageDraw
from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.services.self_training import (
    record_detection_feedback,
    get_self_training_status,
    run_self_training,
    TRAINING_DIR,
    IMAGES_DIR,
    LABELS_DIR,
    CLASS_NAMES,
)

client = TestClient(app)

def test_record_detection_feedback_saves_yolo_sample():
    """Verify editing a detected object saves training image and normalized YOLO label."""
    img = Image.new("RGB", (640, 480), color=(180, 180, 185))
    draw = ImageDraw.Draw(img)
    draw.ellipse([200, 150, 440, 330], fill=(40, 40, 45))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    b64_str = base64.b64encode(buf.getvalue()).decode("utf-8")

    res = client.post(
        "/api/ai/edit-feedback",
        json={
            "image_base64": b64_str,
            "original_item_name": "Generic Electronics",
            "original_category": "ITEW",
            "original_subcategory": "KEYBOARD",
            "corrected_item_name": "Optical USB Mouse",
            "corrected_category": "ITEW",
            "corrected_subcategory": "MOUSE",
            "corrected_weight_kg": 0.35,
            "corrected_quantity": 1.0,
            "corrected_condition": "scrap",
            "bounding_box": [0.31, 0.31, 0.69, 0.69],
            "collector_id": "TEST-COL-001"
        }
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "RECORDED"
    assert data["sample_id"].startswith("sample_")
    assert data["total_training_samples"] >= 1

    sample_id = data["sample_id"]
    lbl_file = os.path.join(LABELS_DIR, f"{sample_id}.txt")
    img_file = os.path.join(IMAGES_DIR, f"{sample_id}.jpg")

    assert os.path.exists(lbl_file)
    assert os.path.exists(img_file)

    with open(lbl_file, "r", encoding="utf-8") as f:
        lbl_content = f.read().strip()
    parts = lbl_content.split()
    assert len(parts) == 5
    assert parts[0] == "7"  # Mouse class index in EWaste_Final_Model
    bx, by, bw, bh = [float(p) for p in parts[1:]]
    assert 0.0 <= bx <= 1.0
    assert 0.0 <= by <= 1.0
    assert 0.0 < bw <= 1.0
    assert 0.0 < bh <= 1.0

def test_self_training_status():
    """Verify GET /api/ai/self-train/status reports active learning readiness."""
    res = client.get("/api/ai/self-train/status")
    assert res.status_code == 200
    data = res.json()
    assert "current_model_version" in data
    assert "base_model_classes" in data
    assert len(data["base_model_classes"]) == 12
    assert "Mouse" in data["base_model_classes"]
    assert "Mobile" in data["base_model_classes"]
    assert "PCB" in data["base_model_classes"]
    assert data["total_samples"] >= 1

def test_trigger_self_training():
    """Verify POST /api/ai/self-train launches background fine-tuning pipeline."""
    res = client.post("/api/ai/self-train", json={"epochs": 2, "batch_size": 2})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] in ["STARTED", "COMPLETED", "ALREADY_RUNNING"]
    assert "model_version" in data

def test_classify_image_returns_normalized_boxes_and_edit_fields():
    """Verify /api/ai/classify-image returns normalized_box for bounding overlays."""
    img = Image.new("RGB", (500, 500), color=(10, 140, 20))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    res = client.post(
        "/api/ai/classify-image",
        files={"file": ("pcb_test.jpg", img_bytes, "image/jpeg")}
    )
    assert res.status_code == 200
    data = res.json()
    assert "estimated_weight_kg" in data
    assert "quantity" in data
    assert "detected_components" in data
    comps = data["detected_components"]
    assert len(comps) > 0
    first = comps[0]
    assert "normalized_box" in first
    nbox = first["normalized_box"]
    assert len(nbox) == 4
    for coord in nbox:
        assert 0.0 <= coord <= 1.0
