import math
from typing import Dict, Any, List

def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0 # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 1)

def compute_recycler_match_score(
    offer_price: float,
    fair_value_median: float,
    distance_km: float,
    reliability_score: float,
    material_matched: bool
) -> Dict[str, Any]:
    """
    Multi-objective scoring for Smart Recycler Matching.
    Weights:
      - Price fit: 40%
      - Logistics/Distance fit: 25%
      - Recycler Reliability: 20%
      - Material Specialization: 15%
    """
    # 1. Price Score (0 - 40 pts)
    price_ratio = offer_price / max(1.0, fair_value_median)
    price_score = min(40.0, max(0.0, price_ratio * 40.0))

    # 2. Distance Score (0 - 25 pts)
    # Closer is better; full points within 10km, decays up to 60km
    distance_score = max(5.0, 25.0 - (distance_km * 0.35))
    distance_score = min(25.0, distance_score)

    # 3. Reliability Score (0 - 20 pts)
    # reliability_score is on 0-100 scale
    reliability_pts = (reliability_score / 100.0) * 20.0

    # 4. Material Match (0 - 15 pts)
    mat_score = 15.0 if material_matched else 5.0

    total_score = round(price_score + distance_score + reliability_pts + mat_score, 1)
    total_score = min(100.0, max(10.0, total_score))

    reasons: List[str] = []
    if price_score >= 38.0:
        reasons.append("Top price offer above regional median")
    if distance_km <= 15.0:
        reasons.append(f"Nearby facility ({distance_km:.1f} km) minimizes transit emissions")
    if reliability_score >= 90.0:
        reasons.append(f"High recycler trust rating ({reliability_score:.0f}%) with fast settlement")
    if material_matched:
        reasons.append("Direct CPCB certified processing capability for this material")

    return {
        "match_score": total_score,
        "is_recommended": total_score >= 80.0,
        "reasons": reasons
    }
