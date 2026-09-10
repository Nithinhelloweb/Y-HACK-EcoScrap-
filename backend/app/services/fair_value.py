from typing import Dict, Any, List, Tuple
from backend.app.services.ai_lens import MATERIAL_KNOWLEDGE_BASE

def get_base_rate(category: str, subcategory: str) -> float:
    cat_lower = category.lower()
    sub_lower = subcategory.lower()

    if cat_lower in MATERIAL_KNOWLEDGE_BASE:
        for sub_key, data in MATERIAL_KNOWLEDGE_BASE[cat_lower].items():
            if sub_key in sub_lower or data["subcategory"].lower() == sub_lower:
                return data["base_rate"]

    # General category defaults if not explicitly matched
    defaults = {
        "pcb": 450.0,
        "battery": 150.0,
        "cable": 380.0,
        "it_equipment": 350.0,
        "display": 60.0
    }
    return defaults.get(cat_lower, 200.0)

def calculate_fair_value(
    category: str,
    subcategory: str,
    weight_kg: float,
    condition: str = "mixed",
    distance_km: float = 15.0
) -> Dict[str, Any]:
    """
    Algorithmic fair market range estimation with explainable cost breakdowns.
    """
    base_rate = get_base_rate(category, subcategory)
    base_total = round(base_rate * weight_kg, 2)

    breakdown: List[Dict[str, Any]] = [
        {
            "name": "Base Regional Market Rate",
            "adjustment_inr": base_total,
            "description": f"₹{base_rate:.0f}/kg × {weight_kg:.1f} kg benchmark"
        }
    ]

    total = base_total

    # Grade & Purity Adjustment
    if "high_grade" in subcategory.lower() or "copper" in subcategory.lower():
        grade_bonus = round(base_total * 0.08, 2)
        total += grade_bonus
        breakdown.append({
            "name": "Grade & Precious Fraction Premium",
            "adjustment_inr": grade_bonus,
            "description": "+8% premium for high-grade / copper-rich material"
        })

    # Bulk Volume Incentive
    if weight_kg >= 15.0:
        bulk_bonus = round(base_total * 0.05, 2)
        total += bulk_bonus
        breakdown.append({
            "name": "Bulk Weight Bonus",
            "adjustment_inr": bulk_bonus,
            "description": "+5% bonus for lots >= 15 kg"
        })

    # Condition Adjustment
    if condition.lower() == "dismantled":
        condition_penalty = -round(base_total * 0.10, 2)
        total += condition_penalty
        breakdown.append({
            "name": "Dismantled Handling Deduction",
            "adjustment_inr": condition_penalty,
            "description": "-10% deduction for loose/fragmented components"
        })
    elif condition.lower() == "damaged":
        condition_penalty = -round(base_total * 0.15, 2)
        total += condition_penalty
        breakdown.append({
            "name": "Contamination / Damage Deduction",
            "adjustment_inr": condition_penalty,
            "description": "-15% deduction for burnt or wet parts"
        })

    # Distance Logistics Margin
    transport_cost = -round(max(50.0, distance_km * 4.5), 2)
    total += transport_cost
    breakdown.append({
        "name": "Estimated Logistics Adjustment",
        "adjustment_inr": transport_cost,
        "description": f"-₹{abs(transport_cost):.0f} estimated transport for ~{distance_km:.1f} km"
    })

    median_val = max(100.0, round(total, 2))
    val_min = round(median_val * 0.92, 2)
    val_max = round(median_val * 1.08, 2)

    return {
        "category": category,
        "subcategory": subcategory,
        "weight_kg": weight_kg,
        "fair_value_min": val_min,
        "fair_value_max": val_max,
        "fair_value_median": median_val,
        "confidence_score": 0.89,
        "breakdown": breakdown,
        "currency": "INR"
    }

def detect_price_anomaly(
    offer_price: float,
    fair_value_min: float,
    fair_value_max: float
) -> Tuple[bool, float, str, str]:
    """
    Statistical Price Anomaly Detector (Exploitation Shield).
    Identifies predatory low offers that fall significantly below fair market boundaries.
    """
    if fair_value_min <= 0:
        return False, 0.0, "LOW", "No baseline"

    if offer_price < fair_value_min:
        deficit_pct = round(((fair_value_min - offer_price) / fair_value_min) * 100, 1)

        if deficit_pct >= 25.0:
            return (
                True,
                deficit_pct,
                "HIGH",
                f"🚨 PREDATORY OFFER: Offer ₹{offer_price:.0f} is {deficit_pct}% BELOW the fair minimum (₹{fair_value_min:.0f}). Middleman exploitation detected."
            )
        elif deficit_pct >= 12.0:
            return (
                True,
                deficit_pct,
                "MEDIUM",
                f"⚠️ UNFAIR PRICING: Offer ₹{offer_price:.0f} is {deficit_pct}% below recommended minimum market rate."
            )

    return False, 0.0, "LOW", "Offer within expected market band."
