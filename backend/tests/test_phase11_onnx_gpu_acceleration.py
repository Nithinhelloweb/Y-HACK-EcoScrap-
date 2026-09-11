import os
import io
import time
import wave
import struct
import math
from PIL import Image
import numpy as np
import pytest
from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.services.local_vision import (
    get_yolo_model,
    detect_components_in_image,
    get_vision_accelerator_info,
)
from backend.app.services.local_whisper import (
    get_whisper_model,
    transcribe_audio_local,
    get_whisper_accelerator_info,
)

client = TestClient(app)


def test_yolo_onnx_gpu_model_loading():
    """Verifies that the E-Waste YOLO model loads from best.onnx with GPU acceleration."""
    model = get_yolo_model()
    assert model is not None
    assert hasattr(model, "names")
    assert len(model.names) == 12
    # Verify classes match the 12 fine-tuned e-waste categories
    assert "mobile" in [v.lower() for v in model.names.values()]
    assert "battery_waste" in [v.lower() for v in model.names.values()]
    assert "pcb" in [v.lower() for v in model.names.values()]


def test_vision_accelerator_info():
    """Verifies that vision accelerator telemetry detects GPU acceleration."""
    info = get_vision_accelerator_info()
    assert "accelerator" in info
    assert "model_path" in info
    assert "is_gpu_accelerated" in info
    assert info["is_gpu_accelerated"] is True
    assert "best.onnx" in info["model_path"]
    assert "DirectML" in info["accelerator"] or "GPU" in info["accelerator"] or "CUDA" in info["accelerator"]


def test_yolo_onnx_inference_components_and_latency():
    """Verifies sub-250ms inference latency on RTX 3050 GPU with bounding boxes and CPCB mapping."""
    img = Image.new("RGB", (640, 640), color=(30, 120, 40))  # Green PCB-like image
    
    # Initial warmup to ensure DirectML graphics pipe and buffers are ready
    detect_components_in_image(img)

    t0 = time.time()
    res = detect_components_in_image(img)
    latency_ms = (time.time() - t0) * 1000

    assert res is not None
    assert "material_type" in res
    assert "category" in res
    assert "confidence" in res
    assert "detected_components" in res
    assert "accelerator" in res
    assert len(res["detected_components"]) >= 1
    # Check that GPU DirectML accelerated execution completes rapidly (< 250ms, typically ~17-30ms)
    assert latency_ms < 250.0, f"Latency {latency_ms:.1f}ms exceeds benchmark threshold"


def test_ai_classify_image_endpoint_includes_accelerator():
    """Verifies that /api/ai/classify-image returns accelerator telemetry."""
    img = Image.new("RGB", (320, 320), color=(50, 50, 50))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    res = client.post(
        "/api/ai/classify-image",
        files={"file": ("test_frame.jpg", buf, "image/jpeg")},
        data={"hint_text": "camera test"}
    )
    assert res.status_code == 200
    data = res.json()
    assert "category" in data
    assert "subcategory" in data
    assert "accelerator" in data
    assert data["accelerator"] is not None
    assert "GPU" in data["accelerator"] or "DirectML" in data["accelerator"] or "CUDA" in data["accelerator"]


def test_local_whisper_gpu_loading_and_telemetry():
    """Verifies that local Whisper model loads with CUDA GPU acceleration."""
    model = get_whisper_model()
    assert model is not None
    
    info = get_whisper_accelerator_info()
    assert "accelerator" in info
    assert "is_gpu_accelerated" in info
    assert info["is_gpu_accelerated"] is True
    assert "CUDA" in info["accelerator"]


def test_local_whisper_transcription_gpu_fast():
    """Verifies high-speed audio transcription with CUDA compute on RTX 3050."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(16000)
        for i in range(8000):
            val = int(32767.0 * 0.2 * math.sin(2.0 * math.pi * 440.0 * i / 16000.0))
            wf.writeframes(struct.pack("<h", val))
    raw_wav = buf.getvalue()

    # Initial warmup to ensure CUDA graph/buffers are initialized
    transcribe_audio_local(raw_wav, language_hint="en")

    t0 = time.time()
    res = transcribe_audio_local(raw_wav, language_hint="en")
    latency_ms = (time.time() - t0) * 1000

    assert res is not None
    assert "text" in res
    assert "detected_language" in res
    assert "confidence" in res
    assert "accelerator" in res
    assert "CUDA" in res["accelerator"]
    assert latency_ms < 1500.0


def test_voice_transcribe_endpoint_includes_accelerator():
    """Verifies that /api/voice/transcribe returns accelerator telemetry."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(16000)
        for i in range(8000):
            val = int(32767.0 * 0.2 * math.sin(2.0 * math.pi * 440.0 * i / 16000.0))
            wf.writeframes(struct.pack("<h", val))
    buf.seek(0)

    res = client.post(
        "/api/voice/transcribe",
        files={"file": ("mic_input.wav", buf, "audio/wav")},
        data={"language_hint": "en"}
    )
    assert res.status_code == 200
    data = res.json()
    assert "text" in data
    assert "detected_language" in data
    assert "accelerator" in data
    assert data["accelerator"] is not None
    assert "CUDA" in data["accelerator"]
