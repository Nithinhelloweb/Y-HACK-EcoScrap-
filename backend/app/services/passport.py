from pathlib import Path
from typing import Dict, Any
import qrcode
from backend.app.config import settings

def generate_qr_for_lot(lot_code: str) -> str:
    """
    Generates a QR code linking to the lot's digital passport.
    Saves to local media directory without any external cloud/AWS.
    """
    passport_payload = f"https://ecoscrap.in/passport/{lot_code}"
    
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=2,
    )
    qr.add_data(passport_payload)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    
    filename = f"qr_{lot_code}.png"
    filepath = settings.QR_DIR / filename
    img.save(str(filepath))

    # Return relative URL
    return f"/media/qr/{filename}"

def estimate_recovered_fractions(category: str, subcategory: str, weight_kg: float) -> Dict[str, float]:
    """
    Circularity Intelligence: estimates recovered pure metal, plastic, and fractions.
    """
    cat_lower = category.lower()
    
    if "pcb" in cat_lower or "pcb" in subcategory.lower():
        return {
            "copper_kg": round(weight_kg * 0.20, 2),
            "precious_metal_bearing_resin_kg": round(weight_kg * 0.35, 2),
            "ferrous_alloys_kg": round(weight_kg * 0.15, 2),
            "high_grade_polymers_kg": round(weight_kg * 0.22, 2),
            "safe_mineral_slag_kg": round(weight_kg * 0.08, 2)
        }
    elif "battery" in cat_lower:
        return {
            "cobalt_lithium_black_mass_kg": round(weight_kg * 0.38, 2),
            "copper_foil_kg": round(weight_kg * 0.12, 2),
            "aluminium_casing_kg": round(weight_kg * 0.20, 2),
            "graphite_kg": round(weight_kg * 0.18, 2),
            "electrolyte_neutralized_kg": round(weight_kg * 0.12, 2)
        }
    elif "cable" in cat_lower:
        return {
            "pure_copper_rod_kg": round(weight_kg * 0.62, 2),
            "pvc_polymer_pellets_kg": round(weight_kg * 0.35, 2),
            "filler_yarn_kg": round(weight_kg * 0.03, 2)
        }
    else:
        # Generic composite IT electronics
        return {
            "aluminium_and_steel_kg": round(weight_kg * 0.40, 2),
            "pcb_fractions_kg": round(weight_kg * 0.20, 2),
            "copper_windings_kg": round(weight_kg * 0.15, 2),
            "recycled_plastics_kg": round(weight_kg * 0.20, 2),
            "hazardous_diverted_kg": round(weight_kg * 0.05, 2)
        }

def calculate_environmental_impact(weight_kg: float) -> Dict[str, Any]:
    """
    Calculates carbon avoidance and toxic containment metrics from formalization.
    """
    # 1.44 kg CO2e saved per kg recycled vs virgin extraction
    co2_avoided = round(weight_kg * 1.44, 2)
    # Approx 25 grams of hazardous heavy metals (lead, cadmium, mercury) safely prevented from open dumping
    toxic_diverted_g = round(weight_kg * 25.0, 1)

    return {
        "co2e_avoided_kg": co2_avoided,
        "toxic_heavy_metals_contained_g": toxic_diverted_g,
        "landfill_space_saved_liters": round(weight_kg * 1.8, 1),
        "trees_offset_equivalent": round(co2_avoided / 21.0, 2)
    }
