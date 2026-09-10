import io
import re
import logging
import threading
from typing import Dict, Any, List, Optional, Union
from PIL import Image
import numpy as np

logger = logging.getLogger("ecoscrap.local_ocr")

_ocr_lock = threading.Lock()
_ocr_reader = None

KNOWN_PHONE_BRANDS = [
    "samsung", "apple", "iphone", "xiaomi", "redmi", "poco", "oneplus", "realme",
    "vivo", "oppo", "motorola", "moto", "nokia", "pixel", "google", "huawei",
    "honor", "sony", "xperia", "asus", "tecno", "infinix", "nothing", "micromax", "lava"
]

KNOWN_PC_BRANDS = [
    "dell", "hp", "hewlett-packard", "lenovo", "thinkpad", "ideapad", "acer",
    "asus", "toshiba", "msi", "alienware", "intel", "amd", "nvidia", "gigabyte",
    "asrock", "corsair", "kingston", "seagate", "western digital"
]

KNOWN_BATTERY_BRANDS = [
    "exide", "amaron", "luminous", "duracell", "energizer", "panasonic", "lg chem", "samsung sdi"
]

BATTERY_HAZARD_KEYWORDS = [
    "li-ion", "lithium", "li-po", "polymer", "18650", "21700", "mah", "wh",
    "rechargeable", "lead-acid", "acid", "pb", "vrla", "agm", "danger", "hazard", "flammable"
]

def get_ocr_reader():
    """
    Returns the loaded EasyOCR Reader instance (singleton).
    Thread-safe.
    """
    global _ocr_reader
    if _ocr_reader is None:
        with _ocr_lock:
            if _ocr_reader is None:
                try:
                    import easyocr
                    logger.info("Initializing local EasyOCR reader (en)...")
                    _ocr_reader = easyocr.Reader(['en'], gpu=False)
                    logger.info("Local EasyOCR reader initialized successfully.")
                except Exception as e:
                    logger.warning(f"EasyOCR reader initialization warning: {e}")
                    return None
    return _ocr_reader

def extract_text_and_entities(image_input: Union[bytes, bytearray, str, Image.Image]) -> Dict[str, Any]:
    """
    Performs local optical character recognition on scrap device image.
    Extracts text tokens, brand identifiers, model numbers, and hazard specifications.
    
    Returns structured analysis with inferred scrap category.
    """
    if isinstance(image_input, (bytes, bytearray)):
        pil_img = Image.open(io.BytesIO(image_input)).convert("RGB")
    elif isinstance(image_input, str):
        pil_img = Image.open(image_input).convert("RGB")
    elif isinstance(image_input, Image.Image):
        pil_img = image_input.convert("RGB")
    else:
        raise ValueError("Unsupported image input type for OCR")

    # Resize image if excessively large to keep CPU inference under ~1.5s
    max_dim = 1024
    w, h = pil_img.size
    if max(w, h) > max_dim:
        scale = max_dim / float(max(w, h))
        new_w, new_h = int(w * scale), int(h * scale)
        pil_img = pil_img.resize((new_w, new_h), Image.Resampling.BILINEAR)

    np_img = np.array(pil_img)
    reader = get_ocr_reader()

    detected_snippets: List[Dict[str, Any]] = []
    full_text_list: List[str] = []

    if reader is not None:
        try:
            raw_results = reader.readtext(np_img)
            for bbox, text, conf in raw_results:
                clean_text = str(text).strip()
                if clean_text and float(conf) >= 0.20:
                    box_list = [[int(pt[0]), int(pt[1])] for pt in bbox] if hasattr(bbox, '__iter__') else []
                    detected_snippets.append({
                        "text": clean_text,
                        "confidence": round(float(conf), 3),
                        "box": box_list
                    })
                    full_text_list.append(clean_text)
        except Exception as ocr_err:
            logger.warning(f"OCR inference warning: {ocr_err}")

    joined_text = " ".join(full_text_list)
    text_lower = joined_text.lower()

    # Entity Extraction
    matched_brands: List[str] = []
    matched_hazard_tags: List[str] = []
    matched_models: List[str] = []
    inferred_hint: Optional[str] = None

    # Check phone brands
    for pb in KNOWN_PHONE_BRANDS:
        if re.search(rf"\b{re.escape(pb)}\b", text_lower):
            matched_brands.append(pb.title())
            if not inferred_hint:
                inferred_hint = "SMARTPHONE"

    # Check PC brands
    for pcb in KNOWN_PC_BRANDS:
        if re.search(rf"\b{re.escape(pcb)}\b", text_lower):
            matched_brands.append(pcb.title())
            if not inferred_hint:
                inferred_hint = "LAPTOP"

    # Check battery brands
    for bb in KNOWN_BATTERY_BRANDS:
        if re.search(rf"\b{re.escape(bb)}\b", text_lower):
            matched_brands.append(bb.title())
            if not inferred_hint:
                inferred_hint = "BATTERY"

    # Check hazard & battery keywords
    for hk in BATTERY_HAZARD_KEYWORDS:
        if re.search(rf"\b{re.escape(hk)}\b", text_lower):
            matched_hazard_tags.append(hk.upper())
            if not inferred_hint:
                inferred_hint = "BATTERY"

    # Model pattern extraction (e.g. SM-A50, iPhone 11, Model: X123, FCC ID, IMEI)
    model_patterns = [
        r"\b(sm-[a-z0-9]+)\b",
        r"\b(iphone\s*\d+[a-z]*)\b",
        r"\b(redmi\s*[a-z0-9]+)\b",
        r"\b(model[:\s]+[a-z0-9\-_]+)\b",
        r"\b(imei[:\s]*\d+)\b",
        r"\b(fcc\s*id[:\s]*[a-z0-9]+)\b",
        r"\b(a\d{4})\b"
    ]
    for pattern in model_patterns:
        matches = re.findall(pattern, text_lower)
        for m in matches:
            clean_m = m.upper().strip()
            if clean_m not in matched_models:
                matched_models.append(clean_m)
                if not inferred_hint:
                    inferred_hint = "SMARTPHONE"

    # Specific PCB markings (e.g. DDR, REV 1.0, LGA, BGA, SOCKET, HDMI, PCI)
    pcb_patterns = [r"\brev\s*\d+\.\d+", r"\bddr[345]\b", r"\blga\s*\d+", r"\bpcie\b"]
    for pattern in pcb_patterns:
        if re.search(pattern, text_lower):
            if not inferred_hint or inferred_hint == "LAPTOP":
                inferred_hint = "PRINTED_CIRCUIT_BOARD"

    avg_conf = 0.0
    if detected_snippets:
        avg_conf = sum(s["confidence"] for s in detected_snippets) / len(detected_snippets)

    return {
        "detected_text": joined_text,
        "text_snippets": detected_snippets,
        "extracted_brands": list(dict.fromkeys(matched_brands)),
        "extracted_models": list(dict.fromkeys(matched_models)),
        "hazard_keywords": list(dict.fromkeys(matched_hazard_tags)),
        "inferred_material_hint": inferred_hint,
        "ocr_confidence": round(avg_conf, 2),
        "total_words_detected": len(full_text_list)
    }
