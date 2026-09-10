import re
from typing import Dict, Any, Optional

# Multilingual number dictionary
NUMBER_WORDS = {
    # Tamil
    "ஒன்று": 1.0, "ஒரு": 1.0,
    "இரண்டு": 2.0, "ரெண்டு": 2.0,
    "மூன்று": 3.0, "மூணு": 3.0,
    "நான்கு": 4.0, "நாலு": 4.0,
    "ஐந்து": 5.0, "அஞ்சு": 5.0,
    "ஆறு": 6.0,
    "ஏழு": 7.0,
    "எட்டு": 8.0,
    "ஒன்பது": 9.0,
    "பத்து": 10.0,
    "இருபது": 20.0,
    "ஐம்பது": 50.0,
    "நூறு": 100.0,
    # Hindi
    "एक": 1.0,
    "दो": 2.0,
    "तीन": 3.0,
    "चार": 4.0,
    "पांच": 5.0, "पाँच": 5.0,
    "छह": 6.0,
    "सात": 7.0,
    "आठ": 8.0,
    "नौ": 9.0,
    "दस": 10.0,
    "बीस": 20.0,
    "पचास": 50.0,
    "सौ": 100.0,
    # English
    "one": 1.0, "two": 2.0, "three": 3.0, "four": 4.0, "five": 5.0,
    "six": 6.0, "seven": 7.0, "eight": 8.0, "nine": 9.0, "ten": 10.0,
    "twenty": 20.0, "fifty": 50.0
}

def detect_language(text: str) -> str:
    """Detects whether text contains Tamil, Hindi, or English scripts."""
    # Tamil Unicode block: U+0B80 - U+0BFF
    if re.search(r"[\u0B80-\u0BFF]", text):
        return "ta"
    # Devanagari (Hindi) Unicode block: U+0900 - U+097F
    elif re.search(r"[\u0900-\u097F]", text):
        return "hi"
    return "en"

def extract_weight(text: str) -> float:
    """Extracts weight from voice prompt in kg, supporting digits and vernacular words."""
    # Check for digit patterns like '10.5 kg', '10kg', '10 கிலோ', '10 किलो'
    digit_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:kg|kgs|kilo|kilos|கிலோ|किलो|கிகி|किग्रा)?", text, re.IGNORECASE)
    if digit_match:
        try:
            val = float(digit_match.group(1))
            if val > 0:
                return round(val, 2)
        except ValueError:
            pass

    # Check for vernacular word matches
    words = text.lower().split()
    for word in words:
        clean_word = re.sub(r"[^\w\s]", "", word)
        if clean_word in NUMBER_WORDS:
            return NUMBER_WORDS[clean_word]

    # Default fallback weight
    return 5.0

def parse_vernacular_voice_prompt(text: str, language_hint: Optional[str] = None) -> Dict[str, Any]:
    """
    Parses natural language scrap descriptions from collectors in English, Tamil, or Hindi.
    Extracts category, subcategory, weight, condition, and safety alert signals.
    """
    detected_lang = language_hint or detect_language(text)
    lower_text = text.lower()
    weight_kg = extract_weight(text)

    # 1. Material Keyword Matching
    category = "PCB"
    subcategory = "IT_HIGH_GRADE_PCB"
    item_name = "Motherboard Scrap"
    is_hazard = False
    hazard_reason = ""

    # Battery check
    battery_keywords = [
        "battery", "cell", "lithium", "li-ion", "பேட்டரி", "மின்கலம்",
        "बैटरी", "सेल", "lead acid", "இன்வெர்ட்டர்", "இன்வர்ட்டர்", "यूपीएस"
    ]
    swollen_keywords = [
        "swollen", "bulging", "puff", "வீங்கிய", "வீக்கம்", "சூடான", "फुला", "फूला", "गर्म"
    ]

    pcb_keywords = [
        "motherboard", "mobo", "ram", "cpu", "processor", "circuit board",
        "pcb", "போர்டு", "மதர்போர்டு", "சர்க்யூட் போர்டு", "मदरबोर्ड", "सर्किट बोर्ड", "पीसीबी"
    ]

    cable_keywords = [
        "cable", "wire", "copper", "charger", "cord", "செம்பு", "தாமிர", "கம்பி",
        "ஒயர்", "கேபிள்", "तांबा", "तार", "केबल", "वायर"
    ]

    laptop_keywords = [
        "laptop", "notebook", "computer", "pc", "desktop", "மடிக்கணினி",
        "கம்ப்யூட்டர்", "கணினி", "லேப்டாப்", "लैपटॉप", "कंप्यूटर"
    ]

    low_grade_pcb_keywords = [
        "smps", "power supply", "tv board", "transformer", "டிவி போர்டு", "டிவி", "टीवी"
    ]

    if any(k in lower_text for k in battery_keywords):
        category = "BATTERY"
        if any(k in lower_text for k in ["lead acid", "ups", "inverter", "இன்வெர்ட்டர்", "यूपीएस"]):
            subcategory = "LEAD_ACID"
            item_name = "Lead-Acid Battery"
            is_hazard = True
            hazard_reason = "Acid leak and heavy lead toxicity risk."
        else:
            subcategory = "LITHIUM_ION"
            item_name = "Lithium-Ion Battery Pack"
            is_hazard = True
            hazard_reason = "Fire and thermal runaway hazard."

        # Check for swelling (critical safety alert)
        if any(k in lower_text for k in swollen_keywords):
            is_hazard = True
            hazard_reason = "CRITICAL: Swollen battery detected! Extreme explosion/puncture risk. Do NOT charge or compress!"

    elif any(k in lower_text for k in pcb_keywords):
        category = "PCB"
        subcategory = "IT_HIGH_GRADE_PCB"
        item_name = "Motherboard PCB"

    elif any(k in lower_text for k in cable_keywords):
        category = "CABLE"
        subcategory = "COPPER_RICH_CABLE"
        item_name = "Copper Cables"
        if any(k in lower_text for k in ["burn", "fire", "எரி", "जला"]):
            is_hazard = True
            hazard_reason = "Do NOT burn cables! Burning releases carcinogenic dioxins. Strip mechanically."

    elif any(k in lower_text for k in laptop_keywords):
        category = "IT_EQUIPMENT"
        subcategory = "LAPTOP_WHOLE"
        item_name = "Decommissioned Laptop"

    elif any(k in lower_text for k in low_grade_pcb_keywords):
        category = "PCB"
        subcategory = "LOW_GRADE_PCB"
        item_name = "Low-Grade Appliance Board"

    else:
        # Default PCB
        category = "PCB"
        subcategory = "IT_HIGH_GRADE_PCB"
        item_name = "Motherboard PCB"

    # Multilingual confirmation messages
    if detected_lang == "ta":
        confirmation = f"புரிந்துகொண்டது: {weight_kg} கிகி {item_name} அடையாளம் காணப்பட்டது."
        if is_hazard:
            confirmation += f" ⚠️ பாதுகாப்பு எச்சரிக்கை: {hazard_reason}"
    elif detected_lang == "hi":
        confirmation = f"पहचान की गई: {weight_kg} किग्रा {item_name} मिला।"
        if is_hazard:
            confirmation += f" ⚠️ सुरक्षा चेतावनी: {hazard_reason}"
    else:
        confirmation = f"Identified: {weight_kg} kg {item_name}."
        if is_hazard:
            confirmation += f" ⚠️ Safety Alert: {hazard_reason}"

    return {
        "raw_text": text,
        "detected_language": detected_lang,
        "category": category,
        "subcategory": subcategory,
        "item_name": item_name,
        "weight_kg": weight_kg,
        "is_hazard": is_hazard,
        "hazard_reason": hazard_reason,
        "confirmation_message": confirmation
    }
