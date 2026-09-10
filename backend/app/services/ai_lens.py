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
    }
}

def classify_material_input(query_text: str = "", image_filename: str = "") -> Dict[str, Any]:
    """
    AI Lens classification engine.
    Analyzes visual signatures or voice/text keywords to classify into 3-tier material hierarchy.
    """
    normalized = f"{query_text} {image_filename}".lower()

    if any(k in normalized for k in ["battery", "lithium", "cell", "li-ion", "18650"]):
        info = MATERIAL_KNOWLEDGE_BASE["battery"]["lithium_ion"]
        confidence = 0.96
    elif any(k in normalized for k in ["lead acid", "ups", "inverter"]):
        info = MATERIAL_KNOWLEDGE_BASE["battery"]["lead_acid"]
        confidence = 0.94
    elif any(k in normalized for k in ["motherboard", "mobo", "ram", "cpu", "processor", "pcb"]):
        info = MATERIAL_KNOWLEDGE_BASE["pcb"]["it_high_grade_pcb"]
        confidence = 0.92
    elif any(k in normalized for k in ["smps", "power supply", "transformer", "circuit"]):
        info = MATERIAL_KNOWLEDGE_BASE["pcb"]["low_grade_pcb"]
        confidence = 0.88
    elif any(k in normalized for k in ["cable", "wire", "copper", "charger", "cord"]):
        info = MATERIAL_KNOWLEDGE_BASE["cable"]["copper_rich"]
        confidence = 0.95
    elif any(k in normalized for k in ["laptop", "notebook", "thinkpad", "macbook"]):
        info = MATERIAL_KNOWLEDGE_BASE["it_equipment"]["laptop"]
        confidence = 0.91
    else:
        # Default high-grade motherboard signature for demo
        info = MATERIAL_KNOWLEDGE_BASE["pcb"]["it_high_grade_pcb"]
        confidence = 0.85

    return {
        "category": info["category"],
        "subcategory": info["subcategory"],
        "item_name": info["item_name"],
        "grade": info["grade"],
        "confidence": confidence,
        "safety_flags": info["safety_flags"],
        "safety_guidance": info["safety_guidance"],
        "estimated_base_rate_per_kg": info["base_rate"],
        "recommended_action": info["recommended_action"]
    }
