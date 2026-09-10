import io
import pytest
from PIL import Image, ImageDraw
from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.services.ai_lens import classify_material_input
from backend.app.services.ai_vision import analyze_scrap_image
from backend.app.services.local_ocr import extract_text_and_entities

client = TestClient(app)

def test_ocr_extraction_smartphone_brand():
    """Verify local OCR correctly identifies smartphone brand and model code."""
    img = Image.new("RGB", (320, 180), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((20, 40), "SAMSUNG GALAXY SM-A50", fill=(0, 0, 0))
    d.text((20, 80), "MADE IN INDIA", fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    img_bytes = buf.getvalue()

    ocr_res = extract_text_and_entities(img_bytes)
    assert "Samsung" in ocr_res["extracted_brands"]
    assert "SAMSUNG" in ocr_res["detected_text"]
    assert ocr_res["inferred_material_hint"] == "SMARTPHONE"

def test_ocr_extraction_battery_hazard():
    """Verify local OCR recognizes hazardous battery specifications."""
    img = Image.new("RGB", (320, 180), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((20, 40), "RECHARGEABLE LI-ION 18650 CELL", fill=(0, 0, 0))
    d.text((20, 80), "3.7V 2600MAH DANGER FLAMMABLE", fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    img_bytes = buf.getvalue()

    ocr_res = extract_text_and_entities(img_bytes)
    assert any(h in ocr_res["hazard_keywords"] for h in ["LI-ION", "18650", "DANGER", "FLAMMABLE"])
    assert ocr_res["inferred_material_hint"] == "BATTERY"

def test_smartphone_never_misclassified_as_motherboard():
    """Verify phone held in front of camera is classified as SMARTPHONE, not motherboard."""
    # Dark handheld rectangular device with phone aspect ratio (~2.0)
    phone_img = Image.new("RGB", (360, 720), color=(20, 20, 22))
    buf = io.BytesIO()
    phone_img.save(buf, format="JPEG")
    phone_bytes = buf.getvalue()

    res = analyze_scrap_image(phone_bytes, filename="", hint_text="")
    assert res["category"] == "ITEW"
    assert res["subcategory"] == "SMARTPHONE_HANDSET"
    assert "Smartphone" in res["item_name"]
    assert res["subcategory"] != "IT_HIGH_GRADE_PCB"
    assert "INTEGRATED_LITHIUM_BATTERY_HAZARD" in res["safety_flags"]

def test_circuit_board_classified_as_pcb():
    """Verify exposed green printed circuit board is classified as PCB."""
    pcb_img = Image.new("RGB", (400, 400), color=(15, 130, 25))
    d = ImageDraw.Draw(pcb_img)
    for y in range(0, 400, 25):
        d.line([(0, y), (400, y)], fill=(210, 190, 60), width=2)
    buf = io.BytesIO()
    pcb_img.save(buf, format="JPEG")
    pcb_bytes = buf.getvalue()

    res = analyze_scrap_image(pcb_bytes, filename="motherboard.jpg", hint_text="")
    assert res["category"] == "PCB"
    assert res["subcategory"] == "IT_HIGH_GRADE_PCB"
    assert "Motherboard" in res["item_name"]

def test_ocr_api_endpoint():
    """Verify dedicated POST /api/ai/ocr returns structured text analysis."""
    img = Image.new("RGB", (250, 100), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((10, 30), "DELL INSPIRON 15", fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    res = client.post(
        "/api/ai/ocr",
        files={"file": ("laptop_label.jpg", img_bytes, "image/jpeg")}
    )
    assert res.status_code == 200
    data = res.json()
    assert "Dell" in data["extracted_brands"]
    assert data["inferred_material_hint"] == "LAPTOP"

def test_classify_image_returns_ocr_fields():
    """Verify /api/ai/classify-image includes detected_text and extracted_brands."""
    img = Image.new("RGB", (300, 600), color=(30, 30, 35))
    d = ImageDraw.Draw(img)
    d.text((50, 250), "REDMI NOTE 10", fill=(220, 220, 220))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    img_bytes = buf.getvalue()

    res = client.post(
        "/api/ai/classify-image",
        files={"file": ("redmi.jpg", img_bytes, "image/jpeg")}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["subcategory"] == "SMARTPHONE_HANDSET"
    assert "Redmi" in data["extracted_brands"] or "Redmi" in data["detected_text"]
    assert "detected_text" in data
    assert "extracted_brands" in data
