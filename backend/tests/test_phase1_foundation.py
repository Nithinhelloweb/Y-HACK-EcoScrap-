import pytest
from sqlalchemy import inspect
from backend.app.database import engine, SessionLocal, Base
from backend.app.models import (
    User,
    CollectorProfile,
    RecyclerProfile,
    Lot,
    Bid,
    HandoverEvent,
    ChainEvent,
    RiskEvent,
    UserRole
)
from backend.app.seed import seed_database
from backend.app.schemas import UserResponse, LotResponse

def test_phase1_database_tables_exist():
    """Verify all Phase 1 relational tables exist in the database."""
    Base.metadata.create_all(bind=engine)
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    
    required_tables = [
        "users",
        "collectors",
        "recyclers",
        "lots",
        "bids",
        "handover_events",
        "chain_events",
        "risk_events"
    ]
    for table in required_tables:
        assert table in tables, f"Missing table: {table}"

def test_phase1_seeding_and_relationships():
    """Verify seed data creates valid collector, recycler, and lot relationships."""
    seed_database()
    db = SessionLocal()

    try:
        # 1. Collectors seeded
        collectors = db.query(CollectorProfile).all()
        assert len(collectors) >= 2, "Expected at least 2 demo collectors"
        c1 = collectors[0]
        assert c1.user is not None
        assert c1.trust_score >= 90.0
        assert "Coimbatore" in c1.service_area

        # 2. Recyclers seeded
        recyclers = db.query(RecyclerProfile).all()
        assert len(recyclers) >= 3, "Expected at least 3 demo recyclers"
        r1 = recyclers[0]
        assert r1.user is not None
        assert r1.registration_no.startswith("CPCB")
        assert "PCB" in r1.accepted_materials

        # 3. Lots seeded with reverse bids
        lots = db.query(Lot).all()
        assert len(lots) >= 2, "Expected at least 2 demo lots"
        lot1 = next(l for l in lots if l.lot_code == "EW-TN-2026-000184")
        assert lot1.collector_id == c1.id
        assert len(lot1.bids) >= 3, "Expected at least 3 reverse bids for Lot 1"

        # Check that one bid is flagged as an anomaly
        anomalous_bids = [b for b in lot1.bids if b.is_anomaly]
        assert len(anomalous_bids) >= 1, "Expected at least 1 predatory lowball bid flagged"

        # Check genesis chain event exists
        chain_events = db.query(ChainEvent).filter(ChainEvent.lot_id == lot1.id).all()
        assert len(chain_events) >= 1
        assert chain_events[0].event_type == "LOT_CREATED"
        assert chain_events[0].previous_hash == "0" * 64

    finally:
        db.close()

def test_phase1_pydantic_schema_serialization():
    """Verify Pydantic models validate and serialize ORM entities cleanly."""
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.role == UserRole.COLLECTOR).first()
        user_schema = UserResponse.model_validate(user)
        assert user_schema.phone == user.phone
        assert user_schema.collector_profile is not None
        assert user_schema.collector_profile.trust_score == user.collector_profile.trust_score

        lot = db.query(Lot).first()
        lot_schema = LotResponse.model_validate(lot)
        assert lot_schema.lot_code == lot.lot_code
        assert lot_schema.fair_value_min == lot.fair_value_min
    finally:
        db.close()
