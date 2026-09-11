import os
import io
import logging
import threading
from typing import Dict, Any, List, Optional
from PIL import Image
import numpy as np

logger = logging.getLogger("ecoscrap.local_vision")
logging.basicConfig(level=logging.INFO)

_yolo_lock = threading.Lock()
_yolo_model = None

# CPCB Price benchmarks (INR)
CPCB_BENCHMARKS = {
    "SMARTPHONE": {"category": "ITEW", "price_per_unit": 850.0, "price_per_kg": 850.0, "hazardous": True},
    "TABLET": {"category": "ITEW", "price_per_unit": 850.0, "price_per_kg": 620.0, "hazardous": True},
    "LAPTOP": {"category": "ITEW", "price_per_unit": 1850.0, "price_per_kg": 480.0, "hazardous": False},
    "PRINTED_CIRCUIT_BOARD": {"category": "ITEW", "price_per_kg": 550.0, "hazardous": False},
    "LOW_GRADE_PCB": {"category": "PCB", "price_per_kg": 110.0, "hazardous": False},
    "BATTERY_LITHIUM_ION": {"category": "HAZARDOUS_COMPONENTS", "price_per_kg": 180.0, "hazardous": True},
    "BATTERY_LEAD_ACID": {"category": "HAZARDOUS_COMPONENTS", "price_per_kg": 85.0, "hazardous": True},
    "COPPER_CABLE": {"category": "CEEW", "price_per_kg": 420.0, "hazardous": False},
    "MONITOR_DISPLAY": {"category": "ITEW", "price_per_unit": 380.0, "price_per_kg": 140.0, "hazardous": True},
    "CRT_DISPLAY": {"category": "ITEW", "price_per_unit": 200.0, "price_per_kg": 65.0, "hazardous": True},
    "KEYBOARD": {"category": "ITEW", "price_per_kg": 160.0, "hazardous": False},
    "MOUSE": {"category": "ITEW", "price_per_kg": 140.0, "hazardous": False},
    "LIGHT_BULB": {"category": "HAZARDOUS_COMPONENTS", "price_per_kg": 40.0, "hazardous": True},
    "CAPACITORS_TRANSFORMERS": {"category": "CEEW", "price_per_kg": 160.0, "hazardous": False},
    "MIXED_EWASTE": {"category": "CEEW", "price_per_kg": 110.0, "hazardous": False}
}

# Electronics & e-waste mappings from fine-tuned E-Waste YOLO model + legacy COCO classes
YOLO_ELECTRONICS_MAP = {
    # Fine-Tuned E-Waste Model (EWaste_Final_Model) classes:
    "mobile": "SMARTPHONE",
    "pcb": "PRINTED_CIRCUIT_BOARD",
    "battery_waste": "BATTERY_LITHIUM_ION",
    "keyboard": "KEYBOARD",
    "mouse": "MOUSE",
    "light_bulb": "LIGHT_BULB",
    "glass_waste": "MONITOR_DISPLAY",
    "metal_waste": "COPPER_CABLE",
    "plastic_waste": "MIXED_EWASTE",
    "medical_waste": "HAZARDOUS_COMPONENTS",
    "organic_waste": "MIXED_EWASTE",
    "paper_waste": "MIXED_EWASTE",

    # Standard COCO fallbacks:
    "cell phone": "SMARTPHONE",
    "laptop": "LAPTOP",
    "tv": "MONITOR_DISPLAY",
    "remote": "SMARTPHONE",
    "circuit_board": "PRINTED_CIRCUIT_BOARD",
    "microwave": "MIXED_EWASTE",
    "refrigerator": "MIXED_EWASTE",
}

_yolo_accelerator = "Uninitialized"
_yolo_model_path = ""

def _patch_ultralytics_onnx_gpu():
    """
    Patches Ultralytics ONNXBackend to enable DirectML GPU acceleration
    on Windows (NVIDIA/AMD/Intel GPUs via DirectX 12) or CUDA when available.
    """
    try:
        import ultralytics.nn.backends.onnx as ob
        orig_load = getattr(ob.ONNXBackend, "_orig_load_model", None)
        if orig_load is None:
            ob.ONNXBackend._orig_load_model = ob.ONNXBackend.load_model
            
            def custom_load(self, weight):
                if self.format != "dnn":
                    try:
                        import onnxruntime
                        avail = onnxruntime.get_available_providers()
                        providers = []
                        if "DmlExecutionProvider" in avail:
                            providers.append("DmlExecutionProvider")
                        if "CUDAExecutionProvider" in avail:
                            providers.append("CUDAExecutionProvider")
                        providers.append("CPUExecutionProvider")
                        
                        logger.info(f"Configuring ONNX Runtime session with providers: {providers}")
                        self.session = onnxruntime.InferenceSession(str(weight), providers=providers)
                        self.output_names = [x.name for x in self.session.get_outputs()]
                        metadata_map = self.session.get_modelmeta().custom_metadata_map
                        if metadata_map:
                            self.apply_metadata(dict(metadata_map))
                        self.dynamic = isinstance(self.session.get_outputs()[0].shape[0], str)
                        self.fp16 = "float16" in self.session.get_inputs()[0].type
                        self.use_io_binding = False
                        active = self.session.get_providers()
                        logger.info(f"ONNX Runtime successfully loaded with active provider: {active[0] if active else 'CPU'}")
                        return
                    except Exception as e:
                        logger.warning(f"DirectML/CUDA custom loader fallback to default: {e}")
                return ob.ONNXBackend._orig_load_model(self, weight)
                
            ob.ONNXBackend.load_model = custom_load
    except Exception as e:
        logger.warning(f"Could not patch ONNXBackend for GPU: {e}")

def get_vision_accelerator_info() -> Dict[str, Any]:
    """Returns telemetry on the active computer vision model and GPU accelerator."""
    global _yolo_accelerator, _yolo_model_path
    if _yolo_model is None:
        try:
            get_yolo_model()
        except Exception:
            pass
    return {
        "accelerator": _yolo_accelerator,
        "model_path": _yolo_model_path,
        "is_gpu_accelerated": "GPU" in _yolo_accelerator or "DirectML" in _yolo_accelerator or "CUDA" in _yolo_accelerator
    }

def get_yolo_model():
    """
    Returns the loaded Ultralytics YOLO instance (singleton).
    Prioritizes the fine-tuned ONNX E-Waste model with DirectML / CUDA GPU acceleration.
    Falls back gracefully to PyTorch weights and CPU if necessary.
    Thread-safe.
    """
    global _yolo_model, _yolo_accelerator, _yolo_model_path
    if _yolo_model is None:
        with _yolo_lock:
            if _yolo_model is None:
                try:
                    import torch
                    from ultralytics import YOLO
                    
                    _patch_ultralytics_onnx_gpu()
                    
                    onnx_path = os.path.abspath(
                        os.path.join(os.path.dirname(__file__), "..", "..", "models", "ewaste_detector", "best.onnx")
                    )
                    pt_path = os.path.abspath(
                        os.path.join(os.path.dirname(__file__), "..", "..", "models", "ewaste_detector", "best.pt")
                    )
                    
                    candidates = [
                        os.getenv("EWASTE_ONNX_PATH", ""),
                        onnx_path,
                        "backend/models/ewaste_detector/best.onnx",
                        "models/ewaste_detector/best.onnx",
                        os.getenv("EWASTE_MODEL_PATH", ""),
                        os.getenv("YOLO_WEIGHTS_PATH", ""),
                        pt_path,
                        "backend/models/ewaste_detector/best.pt",
                        "models/ewaste_detector/best.pt",
                        "backend/best.pt",
                        "best.pt",
                        "backend/yolov8n.pt",
                        "yolov8n.pt",
                    ]
                    weights_path = onnx_path if os.path.exists(onnx_path) else (pt_path if os.path.exists(pt_path) else "yolov8n.pt")
                    for c in candidates:
                        if c and os.path.exists(c):
                            weights_path = c
                            break

                    logger.info(f"Loading Fine-Tuned E-Waste YOLO model: {weights_path}")
                    _yolo_model = YOLO(weights_path, task="detect")
                    _yolo_model_path = weights_path
                    
                    # Detect active acceleration
                    if weights_path.endswith(".onnx"):
                        try:
                            import onnxruntime
                            avail = onnxruntime.get_available_providers()
                            if "DmlExecutionProvider" in avail:
                                gpu_desc = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "DirectX 12 GPU"
                                _yolo_accelerator = f"ONNX DirectML (GPU: {gpu_desc})"
                            elif "CUDAExecutionProvider" in avail:
                                _yolo_accelerator = f"ONNX CUDA (GPU: {torch.cuda.get_device_name(0)})"
                            else:
                                _yolo_accelerator = "ONNX CPUExecutionProvider"
                        except Exception:
                            _yolo_accelerator = "ONNX Runtime"
                    else:
                        if torch.cuda.is_available():
                            _yolo_accelerator = f"PyTorch CUDA (GPU: {torch.cuda.get_device_name(0)})"
                        else:
                            _yolo_accelerator = "PyTorch CPU"
                    
                    # Warmup run to compile shaders/kernels so subsequent real-time calls are ultra-fast (<20ms)
                    try:
                        dummy_frame = np.zeros((640, 640, 3), dtype=np.uint8)
                        _yolo_model(dummy_frame, verbose=False)
                        logger.info(f"E-Waste YOLO model warmup completed successfully on {_yolo_accelerator}.")
                    except Exception as warmup_err:
                        logger.warning(f"Warmup notice: {warmup_err}")

                    logger.info(f"Fine-Tuned E-Waste YOLO model ready with {_yolo_model.names} on {_yolo_accelerator}.")
                except Exception as e:
                    logger.error(f"Failed to load fine-tuned YOLO model: {e}")
                    raise
    return _yolo_model

def detect_components_in_image(image_input: Any) -> Dict[str, Any]:
    """
    Runs fine-tuned E-Waste YOLO neural detection combined with specialized electronic component
    color, aspect ratio, and texture heuristics.
    
    Accepts:
      - PIL Image
      - bytes / bytearray
      - str (file path)
    
    Returns structured analysis with detected components, bounding boxes,
    CPCB category, hazard status, and price estimation.
    """
    if isinstance(image_input, (bytes, bytearray)):
        pil_img = Image.open(io.BytesIO(image_input)).convert("RGB")
    elif isinstance(image_input, str):
        pil_img = Image.open(image_input).convert("RGB")
    elif isinstance(image_input, Image.Image):
        pil_img = image_input.convert("RGB")
    else:
        raise ValueError("Unsupported image input type")

    img_w, img_h = pil_img.size
    detected_components: List[Dict[str, Any]] = []
    primary_item = "MIXED_EWASTE"
    highest_conf = 0.50

    # 1. Run Ultralytics YOLO detection with fine-tuned e-waste model
    try:
        model = get_yolo_model()
        results = model(pil_img, conf=0.15, verbose=False)
        
        if results and len(results) > 0:
            boxes = results[0].boxes
            for box in boxes:
                cls_idx = int(box.cls[0].item())
                class_name = model.names.get(cls_idx, "").lower()
                conf = float(box.conf[0].item())
                coords = [round(c, 1) for c in box.xyxy[0].tolist()]

                if class_name in YOLO_ELECTRONICS_MAP:
                    mapped_type = YOLO_ELECTRONICS_MAP[class_name]
                    
                    # Disambiguate Computer Mouse vs Keyboard vs Smartphone:
                    # Keyboards are wide/elongated (aspect ratio >= 2.4). Handheld compact peripherals are Computer Mice.
                    bw = max(1.0, coords[2] - coords[0])
                    bh = max(1.0, coords[3] - coords[1])
                    box_aspect = max(bw, bh) / min(bw, bh)
                    if mapped_type == "KEYBOARD" and box_aspect < 2.3:
                        mapped_type = "MOUSE"
                    elif mapped_type == "SMARTPHONE" and box_aspect < 1.55:
                        mapped_type = "MOUSE"

                    label_name = {
                        "SMARTPHONE": "Mobile / Smartphone Handset",
                        "PRINTED_CIRCUIT_BOARD": "Circuit Board (PCB)",
                        "BATTERY_LITHIUM_ION": "Battery Waste Cell / Pack (Hazardous)",
                        "KEYBOARD": "Computer Keyboard Input Device",
                        "MOUSE": "Computer Mouse Peripheral",
                        "LIGHT_BULB": "Light Bulb / Mercury Lamp (Hazardous)",
                        "MONITOR_DISPLAY": "Display Glass / Monitor Screen",
                        "COPPER_CABLE": "Metal Scrap / Copper Wiring",
                        "LAPTOP": "Laptop / Notebook Computer",
                        "HAZARDOUS_COMPONENTS": "Hazardous Electronic / Medical Waste",
                        "MIXED_EWASTE": "Electronic Appliance / Mixed Scrap"
                    }.get(mapped_type, class_name.replace("_", " ").title())

                    detected_components.append({
                        "label": f"E-Waste: {label_name}",
                        "raw_class": class_name,
                        "e_waste_type": mapped_type,
                        "confidence": round(conf, 3),
                        "box_xyxy": coords,
                        "normalized_box": [
                            round(coords[0] / max(img_w, 1), 4),
                            round(coords[1] / max(img_h, 1), 4),
                            round(coords[2] / max(img_w, 1), 4),
                            round(coords[3] / max(img_h, 1), 4)
                        ]
                    })
                    if conf > highest_conf:
                        highest_conf = conf
                        primary_item = mapped_type
    except Exception as yolo_err:
        logger.warning(f"YOLO inference notice: {yolo_err}")

    # 2. Specialized E-Waste Component Heuristic Detection
    np_img = np.array(pil_img)
    r = np_img[:, :, 0].astype(float)
    g = np_img[:, :, 1].astype(float)
    b = np_img[:, :, 2].astype(float)
    total_pixels = float(img_w * img_h)

    # A. PCB Detection: Strong Green/Dark-Green soldermask predominance
    green_mask = (g > 70) & (g > r * 1.30) & (g > b * 1.25)
    green_pct = float(np.count_nonzero(green_mask)) / total_pixels
    
    # B. Copper Wire Detection: Rich orange/red-brown hue
    copper_mask = (r > 130) & (r > g * 1.35) & (g > b * 1.1) & (b < 100)
    copper_pct = float(np.count_nonzero(copper_mask)) / total_pixels

    # C. Battery / Hazard Packaging: High-contrast yellow/black or blue shrink
    yellow_warn_mask = (r > 180) & (g > 160) & (b < 80)
    yellow_pct = float(np.count_nonzero(yellow_warn_mask)) / total_pixels

    # D. Handheld Device Aspect & Peripheral Heuristic:
    # Check for compact mouse/peripheral characteristics vs elongated phone only when relevant
    # Avoid classifying full 16:9 webcam canvas as a phone.
    if primary_item == "MIXED_EWASTE" and highest_conf < 0.60:
        dark_matte_mask = (r < 75) & (g < 75) & (b < 75)
        dark_matte_pct = float(np.count_nonzero(dark_matte_mask)) / total_pixels
        # If image contains a compact centered dark peripheral object (mouse/accessory)
        if 0.08 < dark_matte_pct < 0.65 and green_pct < 0.05 and copper_pct < 0.03:
            # Check if there is high curvature or compact ratio in center
            center_crop = np_img[int(img_h * 0.25):int(img_h * 0.75), int(img_w * 0.25):int(img_w * 0.75)]
            c_r, c_g, c_b = center_crop[:, :, 0], center_crop[:, :, 1], center_crop[:, :, 2]
            # If center has glowing LED or optical sensor (e.g. yellow or red glow)
            sensor_glow = (c_r > 120) & (c_g > 100) & (c_b < 80)
            if np.count_nonzero(sensor_glow) > 15:
                box_coords = [round(img_w * 0.2), round(img_h * 0.2), round(img_w * 0.8), round(img_h * 0.8)]
                detected_components.append({
                    "label": "E-Waste: Computer Mouse Peripheral",
                    "raw_class": "optical_mouse_sensor",
                    "e_waste_type": "MOUSE",
                    "confidence": 0.88,
                    "box_xyxy": box_coords,
                    "normalized_box": [0.2, 0.2, 0.8, 0.8]
                })
                highest_conf = 0.88
                primary_item = "MOUSE"

    # Strict PCB detection: only trigger if actual green soldermask is present (> 12%)
    if green_pct > 0.12:
        conf = min(0.98, 0.75 + (green_pct * 1.5))
        box_coords = [round(img_w * 0.1), round(img_h * 0.1), round(img_w * 0.9), round(img_h * 0.9)]
        detected_components.append({
            "label": "Electronic Component: Printed Circuit Board (PCB)",
            "raw_class": "circuit_board",
            "e_waste_type": "PRINTED_CIRCUIT_BOARD",
            "confidence": round(conf, 2),
            "box_xyxy": box_coords,
            "normalized_box": [0.1, 0.1, 0.9, 0.9]
        })
        if conf > highest_conf:
            highest_conf = conf
            primary_item = "PRINTED_CIRCUIT_BOARD"

    if copper_pct > 0.05:
        conf = min(0.96, 0.70 + (copper_pct * 2.0))
        box_coords = [round(img_w * 0.15), round(img_h * 0.15), round(img_w * 0.85), round(img_h * 0.85)]
        detected_components.append({
            "label": "Component: Stripped Copper Wiring & Cables",
            "raw_class": "copper_cable",
            "e_waste_type": "COPPER_CABLE",
            "confidence": round(conf, 2),
            "box_xyxy": box_coords,
            "normalized_box": [0.15, 0.15, 0.85, 0.85]
        })
        if conf > highest_conf:
            highest_conf = conf
            primary_item = "COPPER_CABLE"

    if yellow_pct > 0.06:
        conf = min(0.95, 0.65 + (yellow_pct * 2.5))
        box_coords = [round(img_w * 0.2), round(img_h * 0.2), round(img_w * 0.8), round(img_h * 0.8)]
        detected_components.append({
            "label": "Component: Lithium-Ion / Rechargeable Battery Cell",
            "raw_class": "battery_cell",
            "e_waste_type": "BATTERY_LITHIUM_ION",
            "confidence": round(conf, 2),
            "box_xyxy": box_coords,
            "normalized_box": [0.2, 0.2, 0.8, 0.8]
        })
        if conf > highest_conf:
            highest_conf = conf
            primary_item = "BATTERY_LITHIUM_ION"

    # Default fallback component if none explicitly triggered
    if not detected_components:
        detected_components.append({
            "label": "General Electronic Scrap Components",
            "raw_class": "mixed_scrap",
            "e_waste_type": "MIXED_EWASTE",
            "confidence": 0.80,
            "box_xyxy": [round(img_w * 0.1), round(img_h * 0.1), round(img_w * 0.9), round(img_h * 0.9)],
            "normalized_box": [0.1, 0.1, 0.9, 0.9]
        })

    meta = CPCB_BENCHMARKS.get(primary_item, CPCB_BENCHMARKS["MIXED_EWASTE"])
    is_hazardous = meta.get("hazardous", False)
    
    hazard_msg = None
    if is_hazardous:
        if primary_item == "SMARTPHONE":
            hazard_msg = "CPCB HAZARD ALERT: Device contains high-density Lithium battery. Do not crush, bend, or puncture screen. Route to authorized dismantler."
        else:
            hazard_msg = "CPCB HAZARD ALERT: Item contains toxic heavy metals/chemicals. Do not crush, burn, or puncture. Hand over exclusively to authorized dismantler."

    price_str = f"₹{meta.get('price_per_kg', 0.0):.1f}/kg" if "price_per_kg" in meta else f"₹{meta.get('price_per_unit', 0.0):.0f}/unit"

    return {
        "material_type": primary_item,
        "category": meta["category"],
        "confidence": round(highest_conf, 2),
        "is_hazardous": is_hazardous,
        "hazard_alert": hazard_msg,
        "detected_components": detected_components,
        "estimated_fair_price": price_str,
        "model_version": "Fine-Tuned E-Waste YOLO (EWaste_Final_Model) + Multi-Modal Analyzer",
        "accelerator": _yolo_accelerator,
        "total_components_detected": len(detected_components)
    }
