"""
admin_analytics.py — Admin Panel Analytics & User Management Endpoints
Implements:
  - GET  /api/admin/collectors       — List all collectors with stats
  - GET  /api/admin/recyclers        — List all recyclers with performance data
  - POST /api/admin/verify-user      — Toggle user verification status
  - GET  /api/admin/market-trends    — Pricing trends by category
  - GET  /api/admin/environmental-impact — Recovered material summary
  - GET  /api/admin/fraud-alerts     — Risk events with severity filtering
  - GET  /api/admin/metrics          — Existing KPI dashboard (moved here)
"""
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from backend.app.database import get_db
from backend.app.models import (
    User, CollectorProfile, RecyclerProfile, Lot, Bid, Payment,
    RiskEvent, LotStatus, BidStatus
)
from backend.app.schemas import (
    AdminCollectorListItem,
    AdminRecyclerListItem,
    MarketTrendsResponse,
    MarketTrendItem,
    EnvironmentalSummaryResponse,
    FraudAlertsResponse,
    FraudAlertItem,
    VerifyUserRequest,
)

router = APIRouter(prefix="/admin", tags=["Admin Analytics & Governance"])

# ---------- Material recovery fraction lookup (kg per kg of category) ----------
RECOVERY_FRACTIONS = {
    "PCB":          {"Gold_g_per_kg": 0.28,  "Silver_g_per_kg": 1.2,  "Copper_kg_pct": 0.20, "Plastics_kg_pct": 0.35},
    "BATTERY":      {"Lithium_kg_pct": 0.06, "Cobalt_kg_pct": 0.12,   "Nickel_kg_pct": 0.08, "Plastics_kg_pct": 0.22},
    "CABLE":        {"Copper_kg_pct": 0.65,  "PVC_kg_pct": 0.28,      "Steel_kg_pct": 0.07},
    "IT_EQUIPMENT": {"Steel_kg_pct": 0.45,   "Aluminum_kg_pct": 0.18, "PCB_kg_pct": 0.08,    "Plastics_kg_pct": 0.25},
    "DISPLAY":      {"Glass_kg_pct": 0.55,   "Copper_kg_pct": 0.07,   "Indium_g_per_kg": 0.05, "Plastics_kg_pct": 0.25},
    "MIXED_SCRAP":  {"Ferrous_kg_pct": 0.35, "Non_Ferrous_kg_pct": 0.18, "Plastics_kg_pct": 0.30},
    "ITEW":         {"Steel_kg_pct": 0.40,   "Copper_kg_pct": 0.10,   "PCB_kg_pct": 0.06,    "Plastics_kg_pct": 0.30},
}

CO2E_PER_KG = {
    "PCB": 2.4, "BATTERY": 1.8, "CABLE": 1.6, "IT_EQUIPMENT": 1.9,
    "DISPLAY": 1.4, "MIXED_SCRAP": 1.2, "ITEW": 2.0,
}
HEAVY_METAL_G_PER_KG = {
    "PCB": 2.1, "BATTERY": 1.6, "DISPLAY": 0.9, "IT_EQUIPMENT": 0.8, "ITEW": 0.7,
}


def _collector_total_earnings(collector: CollectorProfile, db: Session) -> float:
    payments = db.query(Payment).filter(
        Payment.collector_id == collector.id,
        Payment.status == "SETTLED"
    ).all()
    return round(sum(p.amount for p in payments), 2)


def _collector_total_lots(collector: CollectorProfile, db: Session) -> int:
    return db.query(Lot).filter(Lot.collector_id == collector.id).count()


def _recycler_bid_stats(recycler: RecyclerProfile, db: Session) -> dict:
    bids = db.query(Bid).filter(Bid.recycler_id == recycler.id).all()
    total = len(bids)
    won = sum(1 for b in bids if b.status == BidStatus.ACCEPTED)
    completion_rate = round((won / max(1, total)) * 100, 1)
    # Approximate kg processed from won lots
    won_lot_ids = [b.lot_id for b in bids if b.status == BidStatus.ACCEPTED]
    kg_processed = 0.0
    for lid in won_lot_ids:
        lot = db.query(Lot).filter(Lot.id == lid).first()
        if lot:
            kg_processed += lot.verified_weight_kg or lot.estimated_weight_kg
    return {
        "total_bids": total,
        "won_lots": won,
        "completion_rate_pct": completion_rate,
        "total_kg_processed": round(kg_processed, 2),
        "avg_settlement_days": 2.3,  # TODO: derive from payment timestamps when available
    }


# ─────────────────────────────────────────────────────────────────────────────
#  EXISTING KPI metrics endpoint (migrated here from passport.py admin_router)
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/metrics")
def get_admin_metrics(db: Session = Depends(get_db)):
    """
    GET /api/admin/metrics
    Platform-wide KPI dashboard for governance oversight.
    """
    all_lots = db.query(Lot).all()
    closed = [l for l in all_lots if l.status in (LotStatus.CLOSED, LotStatus.MATERIAL_RECOVERED, LotStatus.RECEIVED)]
    total_kg = sum(l.verified_weight_kg or l.estimated_weight_kg for l in closed)
    co2e = round(sum(
        (l.verified_weight_kg or l.estimated_weight_kg) * CO2E_PER_KG.get(l.category.upper(), 1.5)
        for l in closed
    ), 2)
    heavy_metals = round(sum(
        (l.verified_weight_kg or l.estimated_weight_kg) * HEAVY_METAL_G_PER_KG.get(l.category.upper(), 0.5)
        for l in closed
    ), 2)
    trees = round(co2e / 21.7, 1)

    risk_events = db.query(RiskEvent).all()
    anomalies = [
        {"risk_type": r.risk_type, "explanation": r.explanation, "severity": r.severity}
        for r in risk_events if r.severity == "HIGH"
    ]

    category_dist: dict = {}
    for lot in closed:
        cat = lot.category.upper()
        wt = lot.verified_weight_kg or lot.estimated_weight_kg
        category_dist[cat] = category_dist.get(cat, 0.0) + wt

    verified_recyclers = db.query(RecyclerProfile).count()

    return {
        "total_ewaste_diverted_kg": round(total_kg, 2),
        "co2e_avoided_kg": co2e,
        "toxic_heavy_metals_contained_g": heavy_metals,
        "trees_offset_equivalent": trees,
        "price_anomalies_prevented": len(risk_events),
        "verified_recyclers": verified_recyclers,
        "category_distribution": {k: round(v, 1) for k, v in category_dist.items()},
        "recent_anomalies": anomalies[:5],
    }


# ─────────────────────────────────────────────────────────────────────────────
#  COLLECTORS LIST
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/collectors", response_model=List[AdminCollectorListItem])
def list_all_collectors(db: Session = Depends(get_db)):
    """
    GET /api/admin/collectors
    Full collector roster with trust score, lots, earnings, and verification.
    """
    collectors = db.query(CollectorProfile).all()
    result = []
    for c in collectors:
        user = db.query(User).filter(User.id == c.user_id).first()
        if not user:
            continue
        result.append(AdminCollectorListItem(
            user_id=user.id,
            collector_id=c.id,
            collector_code=c.collector_code,
            name=user.name,
            phone=user.phone,
            trust_score=c.trust_score,
            total_lots=_collector_total_lots(c, db),
            total_earnings_inr=_collector_total_earnings(c, db),
            is_verified=user.is_verified,
            training_completed=c.training_completed,
            service_area=c.service_area,
        ))
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  RECYCLERS LIST
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/recyclers", response_model=List[AdminRecyclerListItem])
def list_all_recyclers(db: Session = Depends(get_db)):
    """
    GET /api/admin/recyclers
    Full recycler roster with reliability score, bids won, kg processed.
    """
    recyclers = db.query(RecyclerProfile).all()
    result = []
    for r in recyclers:
        user = db.query(User).filter(User.id == r.user_id).first()
        if not user:
            continue
        stats = _recycler_bid_stats(r, db)
        result.append(AdminRecyclerListItem(
            user_id=user.id,
            recycler_id=r.id,
            org_name=r.org_name,
            registration_no=r.registration_no,
            reliability_score=r.reliability_score,
            won_lots=stats["won_lots"],
            total_kg_processed=stats["total_kg_processed"],
            is_verified=user.is_verified,
            accepted_materials=r.accepted_materials or [],
            daily_capacity_kg=r.daily_capacity_kg,
        ))
    return result


# ─────────────────────────────────────────────────────────────────────────────
#  VERIFY / UNVERIFY USER
# ─────────────────────────────────────────────────────────────────────────────
@router.post("/verify-user")
def verify_user(req: VerifyUserRequest, db: Session = Depends(get_db)):
    """
    POST /api/admin/verify-user
    Toggle verification status of a collector or recycler.
    """
    user = db.query(User).filter(User.id == req.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_verified = req.verified
    db.commit()
    action = "VERIFIED" if req.verified else "UNVERIFIED"
    return {
        "status": "OK",
        "message": f"User {user.name} ({user.role}) has been {action}.",
        "user_id": user.id,
        "is_verified": user.is_verified,
    }


# ─────────────────────────────────────────────────────────────────────────────
#  MARKET INTELLIGENCE: PRICING TRENDS
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/market-trends", response_model=MarketTrendsResponse)
def get_market_trends(db: Session = Depends(get_db)):
    """
    GET /api/admin/market-trends
    Pricing trends by category: avg bid, lot counts, avg weight.
    """
    all_lots = db.query(Lot).all()
    category_map: dict = {}

    for lot in all_lots:
        cat = lot.category.upper()
        if cat not in category_map:
            category_map[cat] = {
                "total_lots": 0,
                "open_lots": 0,
                "closed_lots": 0,
                "total_value": 0.0,
                "total_weight": 0.0,
                "accepted_bids": [],
            }
        cm = category_map[cat]
        cm["total_lots"] += 1
        cm["total_weight"] += lot.estimated_weight_kg
        is_closed = lot.status in (LotStatus.CLOSED, LotStatus.MATERIAL_RECOVERED, LotStatus.RECEIVED)
        if is_closed:
            cm["closed_lots"] += 1
        else:
            cm["open_lots"] += 1
        for bid in lot.bids:
            if bid.status == BidStatus.ACCEPTED:
                cm["accepted_bids"].append(bid.offer_price)
                cm["total_value"] += bid.offer_price

    trends = []
    total_market_value = 0.0
    for cat, data in category_map.items():
        total_w = data["total_weight"]
        accepted = data["accepted_bids"]
        avg_price_per_kg = (sum(accepted) / max(1, total_w)) if accepted else (
            (data["total_value"] / max(1, data["total_lots"])) / max(1, total_w / max(1, data["total_lots"]))
        )
        total_market_value += data["total_value"]
        trends.append(MarketTrendItem(
            category=cat,
            avg_price_per_kg=round(avg_price_per_kg, 2),
            total_lots=data["total_lots"],
            open_lots=data["open_lots"],
            closed_lots=data["closed_lots"],
            avg_weight_kg=round(total_w / max(1, data["total_lots"]), 2),
        ))

    trends.sort(key=lambda x: x.total_lots, reverse=True)
    top_cats = [t.category for t in trends[:3]]

    return MarketTrendsResponse(
        trends=trends,
        top_categories=top_cats,
        total_market_value_inr=round(total_market_value, 2),
        generated_at=datetime.now(timezone.utc).isoformat(),
    )


# ─────────────────────────────────────────────────────────────────────────────
#  ENVIRONMENTAL IMPACT SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/environmental-impact", response_model=EnvironmentalSummaryResponse)
def get_environmental_impact(db: Session = Depends(get_db)):
    """
    GET /api/admin/environmental-impact
    Aggregated recovered material fractions, CO2e, heavy metals, trees offset.
    """
    all_lots = db.query(Lot).all()
    closed_lots = [l for l in all_lots if l.status in (LotStatus.CLOSED, LotStatus.MATERIAL_RECOVERED, LotStatus.RECEIVED, LotStatus.PROCESSING)]
    processing_lots = [l for l in all_lots if l.status == LotStatus.PROCESSING]

    total_kg = sum(l.verified_weight_kg or l.estimated_weight_kg for l in closed_lots)
    co2e = round(sum(
        (l.verified_weight_kg or l.estimated_weight_kg) * CO2E_PER_KG.get(l.category.upper(), 1.5)
        for l in closed_lots
    ), 2)
    heavy = round(sum(
        (l.verified_weight_kg or l.estimated_weight_kg) * HEAVY_METAL_G_PER_KG.get(l.category.upper(), 0.5)
        for l in closed_lots
    ), 2)
    trees = round(co2e / 21.7, 1)

    # Recovered fractions by category
    fractions_by_cat: dict = {}
    for lot in closed_lots:
        cat = lot.category.upper()
        wt = lot.verified_weight_kg or lot.estimated_weight_kg
        fractions = RECOVERY_FRACTIONS.get(cat, RECOVERY_FRACTIONS["MIXED_SCRAP"])
        if cat not in fractions_by_cat:
            fractions_by_cat[cat] = {}
        for frac_key, frac_val in fractions.items():
            recovered = wt * frac_val if isinstance(frac_val, float) else 0.0
            fractions_by_cat[cat][frac_key] = round(
                fractions_by_cat[cat].get(frac_key, 0.0) + recovered, 3
            )

    return EnvironmentalSummaryResponse(
        total_ewaste_diverted_kg=round(total_kg, 2),
        co2e_avoided_kg=co2e,
        toxic_heavy_metals_contained_g=heavy,
        trees_offset_equivalent=trees,
        recovered_fractions_by_category=fractions_by_cat,
        lots_closed_count=len(closed_lots),
        lots_in_processing_count=len(processing_lots),
    )


# ─────────────────────────────────────────────────────────────────────────────
#  FRAUD ALERTS — Risk events with severity filter
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/fraud-alerts", response_model=FraudAlertsResponse)
def get_fraud_alerts(
    severity: Optional[str] = Query(None, description="Filter: HIGH, MEDIUM, LOW"),
    db: Session = Depends(get_db),
):
    """
    GET /api/admin/fraud-alerts?severity=HIGH
    Returns all risk events ordered by severity and creation time.
    """
    query = db.query(RiskEvent)
    if severity:
        query = query.filter(RiskEvent.severity == severity.upper())
    events = query.order_by(RiskEvent.created_at.desc()).all()

    alerts = []
    for ev in events:
        lot = db.query(Lot).filter(Lot.id == ev.lot_id).first()
        lot_code = lot.lot_code if lot else ev.lot_id
        alerts.append(FraudAlertItem(
            lot_id=ev.lot_id,
            lot_code=lot_code,
            risk_type=ev.risk_type,
            severity=ev.severity,
            deviation_percentage=ev.deviation_percentage,
            explanation=ev.explanation,
            created_at=ev.created_at.isoformat(),
        ))

    high = sum(1 for a in alerts if a.severity == "HIGH")
    med  = sum(1 for a in alerts if a.severity == "MEDIUM")
    low  = sum(1 for a in alerts if a.severity == "LOW")

    return FraudAlertsResponse(
        total_alerts=len(alerts),
        high_severity=high,
        medium_severity=med,
        low_severity=low,
        alerts=alerts,
    )
