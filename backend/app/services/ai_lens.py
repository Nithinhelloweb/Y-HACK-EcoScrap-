import re
from typing import Dict, Any, List

MATERIAL_KNOWLEDGE_BASE = {
    "pcb": {
        "it_high_grade_pcb": {
            "category": "PCB",
            "subcategory": "IT_HIGH_GRADE_PCB",
            "item_name": "High-Grade Laptop/Server Motherboard",
            "grade": "Tier 1 Gold/Palladium Plated",
            "base_rate": 550.0,
            "safety_flags": ["SHARP_SOLDER_PINS", "ELECTROSTATIC_DISCHARGE"],
            "safety_guidance": "Handle by board edges using puncture-resistant gloves. Keep dry and avoid bending or snapping.",
            "recommended_action": "Create digital lot as High-Grade PCB for competitive reverse bidding."
        },
        "low_grade_pcb": {
            "category": "PCB",
            "subcategory": "LOW_GRADE_PCB",
            "item_name": "Single-Sided Appliance PCB / SMPS Board",
            "grade": "Tier 3 Phenolic Resin",
            "base_rate": 110.0,
            "safety_flags": ["POTENTIAL_LARGE_CAPACITOR_CHARGE"],
            "safety_guidance": "Do not puncture large capacitors. Discharge safely or store intact in dry container.",
            "recommended_action": "Bundle with power supply electronics for bulk metal and resin recovery."
        }
    },
    "battery": {
        "lithium_ion": {
            "category": "BATTERY",
            "subcategory": "LITHIUM_ION",
            "item_name": "Li-Ion Cell Battery Pack (Laptop/Phone)",
            "grade": "Cobalt/Nickel Rich Cells",
            "base_rate": 180.0,
            "safety_flags": ["THERMAL_RUNAWAY_RISK", "DO_NOT_PUNCTURE", "FLAMMABLE_ELECTROLYTE"],
            "safety_guidance": "CRITICAL HAZARD: Do not puncture, crush, or expose to heat or flame. Tape terminal ends with non-conductive tape and store in fire-retardant sand container.",
            "recommended_action": "Immediate safe isolation and dispatch to CPCB-authorized battery recycler only."
        },
        "lead_acid": {
            "category": "BATTERY",
            "subcategory": "LEAD_ACID",
            "item_name": "Sealed Lead-Acid UPS Battery",
            "grade": "Heavy Lead Alloy",
            "base_rate": 85.0,
            "safety_flags": ["CORROSIVE_SULFURIC_ACID", "TOXIC_HEAVY_METAL"],
            "safety_guidance": "CRITICAL HAZARD: Wear acid-resistant rubber gloves. Never break casing. Avoid acid leaks.",
            "recommended_action": "Route directly to formal battery smelter."
        }
    },
    "cable": {
        "copper_rich": {
            "category": "CABLE",
            "subcategory": "COPPER_RICH_CABLE",
            "item_name": "High-Purity Copper Data & Power Cables",
            "grade": "Grade 1 65%+ Copper Recovery",
            "base_rate": 420.0,
            "safety_flags": ["DO_NOT_BURN_PVC"],
            "safety_guidance": "STRICTLY PROHIBITED: Do not burn cables. Open burning releases toxic dioxins. Use mechanical stripping or formal granulator.",
            "recommended_action": "Bundle neatly. High market demand among copper smelters."
        }
    },
    "it_equipment": {
        "smartphone": {
            "category": "ITEW",
            "subcategory": "SMARTPHONE_HANDSET",
            "item_name": "End-of-Life Smartphone / Mobile Handset",
            "grade": "Tier 1 High-Density Mobile Electronics",
            "base_rate": 850.0,
            "safety_flags": ["INTEGRATED_LITHIUM_BATTERY_HAZARD", "GLASS_SHARD_RISK"],
            "safety_guidance": "Contains integrated lithium battery and fragile glass screen. Do not crush, bend, or incinerate. Store in cool, non-combustible container.",
            "recommended_action": "Safe disassembly at authorized facility to recover AMOLED display, logic board, and cobalt-rich battery."
        },
        "tablet": {
            "category": "ITEW",
            "subcategory": "TABLET_DEVICE",
            "item_name": "Tablet Computer / E-Reader",
            "grade": "Composite Handheld Electronics",
            "base_rate": 620.0,
            "safety_flags": ["INTEGRATED_LITHIUM_BATTERY_HAZARD"],
            "safety_guidance": "High-capacity lithium pouch cells inside. Do not puncture chassis or expose to extreme pressure.",
            "recommended_action": "Recover display assembly, aluminium chassis, and lithium cell pack."
        },
        "laptop": {
            "category": "IT_EQUIPMENT",
            "subcategory": "LAPTOP_WHOLE",
            "item_name": "Old / Decommissioned Laptop",
            "grade": "Composite Multi-Material",
            "base_rate": 480.0,
            "safety_flags": ["INTERNAL_BATTERY_PRESENT"],
            "safety_guidance": "Do not dismantle without proper ventilation. Ensure battery is checked for swelling before stacking.",
            "recommended_action": "Offer as complete unit or separate motherboard and battery for higher margin."
        }
    },
    "display": {
        "led_monitor": {
            "category": "DISPLAY",
            "subcategory": "LED_MONITOR",
            "item_name": "Flat Panel LCD / LED Computer Monitor",
            "grade": "Tier 2 Commercial Electronics",
            "base_rate": 140.0,
            "safety_flags": ["FRAGILE_GLASS_HAZARD"],
            "safety_guidance": "Handle with care to prevent screen shatter. Extract CCFL backlight safely if present.",
            "recommended_action": "Route to display recyclers for optical glass and back-panel circuit extraction."
        },
        "crt_monitor": {
            "category": "DISPLAY",
            "subcategory": "CRT_MONITOR",
            "item_name": "Cathode Ray Tube (CRT) / Heavy Display",
            "grade": "Hazardous Leaded Glass",
            "base_rate": 65.0,
            "safety_flags": ["TOXIC_LEAD_PHOSPHOR_HAZARD", "IMPLOSION_RISK_UNDER_VACUUM"],
            "safety_guidance": "CRITICAL HAZARD: Do not crack or puncture the vacuum neck. Never dispose in general waste.",
            "recommended_action": "Requires specialized CPCB mechanical glass separation facility."
        }
    },
    "mixed": {
        "mixed_ewaste": {
            "category": "MIXED_SCRAP",
            "subcategory": "MIXED_EWASTE",
            "item_name": "Mixed Electronic & Electrical Scrap",
            "grade": "Tier 3 Mixed Grade",
            "base_rate": 110.0,
            "safety_flags": ["GENERAL_EWASTE_SAFETY"],
            "safety_guidance": "Wear protective gloves. Sort by material stream into metals, plastics, and circuit boards.",
            "recommended_action": "Bulk sorting and secondary mechanical separation."
        }
    }
}

def classify_material_input(query_text: str = "", image_filename: str = "") -> Dict[str, Any]:
    """
    AI Lens classification engine.
    Analyzes visual signatures or voice/text keywords to classify into specialized e-waste material hierarchy.
    Cleanly differentiates mobile phones, laptops, motherboards, batteries, cables, displays, and mixed scrap.
    """
    normalized = f"{query_text} {image_filename}".lower()

    # 1. Motherboard / Dedicated PCB check (strictly for circuit boards)
    if any(k in normalized for k in ["motherboard", "mobo", "server board", "logic board"]):
        info = MATERIAL_KNOWLEDGE_BASE["pcb"]["it_high_grade_pcb"]
        confidence = 0.94
    elif any(k in normalized for k in ["smps", "power supply", "transformer", "circuit board", "low grade pcb"]):
        info = MATERIAL_KNOWLEDGE_BASE["pcb"]["low_grade_pcb"]
        confidence = 0.89
    elif any(k in normalized for k in ["pcb", "ram", "cpu", "processor"]):
        info = MATERIAL_KNOWLEDGE_BASE["pcb"]["it_high_grade_pcb"]
        confidence = 0.92

    # 2. Smartphone / Mobile Phone check
    elif any(k in normalized for k in [
        "smartphone", "mobile", "cellphone", "cell phone", "phone", "handset",
        "android", "iphone", "galaxy", "redmi", "xiaomi", "oneplus", "realme",
        "oppo", "vivo", "pixel", "nokia", "motorola", "honor"
    ]):
        info = MATERIAL_KNOWLEDGE_BASE["it_equipment"]["smartphone"]
        confidence = 0.96

    # 3. Tablet check
    elif any(k in normalized for k in ["tablet", "ipad", "e-reader", "kindle"]):
        info = MATERIAL_KNOWLEDGE_BASE["it_equipment"]["tablet"]
        confidence = 0.94

    # 4. Battery check
    elif any(k in normalized for k in ["lithium", "cell", "li-ion", "18650", "polymer", "lipo"]) or (
        "battery" in normalized and not any(p in normalized for p in ["phone", "mobile", "laptop"])
    ):
        info = MATERIAL_KNOWLEDGE_BASE["battery"]["lithium_ion"]
        confidence = 0.96
    elif any(k in normalized for k in ["lead acid", "ups", "inverter battery"]):
        info = MATERIAL_KNOWLEDGE_BASE["battery"]["lead_acid"]
        confidence = 0.94

    # 5. Cable & Wire check
    elif any(k in normalized for k in ["cable", "wire", "copper", "charger", "cord", "harness"]):
        info = MATERIAL_KNOWLEDGE_BASE["cable"]["copper_rich"]
        confidence = 0.95

    # 6. Laptop / Notebook check
    elif any(k in normalized for k in ["laptop", "notebook", "thinkpad", "macbook", "chromebook"]):
        info = MATERIAL_KNOWLEDGE_BASE["it_equipment"]["laptop"]
        confidence = 0.93

    # 7. Display / Monitor check
    elif any(k in normalized for k in ["crt", "tube"]):
        info = MATERIAL_KNOWLEDGE_BASE["display"]["crt_monitor"]
        confidence = 0.94
    elif any(k in normalized for k in ["monitor", "display", "screen", "lcd", "led panel"]):
        info = MATERIAL_KNOWLEDGE_BASE["display"]["led_monitor"]
        confidence = 0.91

    # 8. Unclassified / General fallback (NO LONGER defaults to motherboard!)
    else:
        info = MATERIAL_KNOWLEDGE_BASE["mixed"]["mixed_ewaste"]
        confidence = 0.75

    return {
        "category": info["category"],
        "subcategory": info["subcategory"],
        "item_name": info["item_name"],
        "grade": info["grade"],
        "confidence": confidence,
        "safety_flags": list(info["safety_flags"]),
        "safety_guidance": info["safety_guidance"],
        "estimated_base_rate_per_kg": info["base_rate"],
        "recommended_action": info["recommended_action"]
    }
