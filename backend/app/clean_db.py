import logging
from sqlalchemy import text
from sqlalchemy.orm import Session
from backend.app.database import SessionLocal, Base, engine
from backend.app.models import (
    User,
    CollectorProfile,
    RecyclerProfile,
    AdminProfile,
    Lot,
    Bid,
    HandoverEvent,
    ChainEvent,
    RiskEvent,
    UserRole,
    Payment,
    Collection,
    CollectionItem,
    Dispute,
    AuditLog,
    VoiceSession,
    VoiceToolLog,
)
from backend.app.services.security import hash_password

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ecoscrap.clean_db")

def clean_database():
    """
    Purges all test and mock lots, bids, events, collections, payments, disputes,
    and resets the database to only the canonical demo accounts with 0 lots.
    """
    logger.info("Connecting to database and purging mock/test data...")
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        # 1. Truncate all transactional tables in dependency order
        transactional_tables = [
            "audit_logs",
            "voice_tool_logs",
            "voice_sessions",
            "risk_events",
            "chain_events",
            "handover_events",
            "disputes",
            "payments",
            "bids",
            "collection_items",
            "collections",
            "lots",
            "admin_profiles",
            "collectors",
            "recyclers",
            "users",
        ]

        logger.info("Truncating transactional and user tables...")
        for table in transactional_tables:
            try:
                db.execute(text(f"TRUNCATE TABLE {table} CASCADE;"))
            except Exception as e:
                logger.warning(f"Could not TRUNCATE {table} (trying DELETE): {e}")
                db.execute(text(f"DELETE FROM {table};"))
        db.commit()

        logger.info("Seeding canonical foundational demo accounts (0 lots)...")

        # 2. Canonical Collector: Murugan K.
        col_user = User(
            name="Murugan K.",
            phone="9842100001",
            email="murugan@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.COLLECTOR,
            language="ta",
            is_verified=True,
        )
        db.add(col_user)
        db.commit()

        col_profile = CollectorProfile(
            user_id=col_user.id,
            collector_code="COL-TN-019284",
            trust_score=94.5,
            training_completed=True,
            service_area="Gandhipuram & RS Puram, Coimbatore",
            total_collections_count=0.0,
        )
        db.add(col_profile)

        # 3. Canonical Recycler: GreenTech Circular Solutions
        rec_user = User(
            name="GreenTech E-Recovery",
            phone="9842100010",
            email="greentech@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.RECYCLER,
            language="en",
            is_verified=True,
        )
        db.add(rec_user)
        db.commit()

        rec_profile = RecyclerProfile(
            user_id=rec_user.id,
            org_name="GreenTech Circular Solutions Pvt Ltd",
            registration_no="CPCB-TN-REC-2024-8812",
            reliability_score=96.0,
            service_radius_km=45.0,
            latitude=11.0250,
            longitude=76.9400,
            accepted_materials=["PCB", "BATTERY", "IT_EQUIPMENT", "CABLE", "DISPLAY"],
            daily_capacity_kg=2500.0,
        )
        db.add(rec_profile)

        # 4. Canonical Regulatory Admin: CPCB Inspector Arumugam S.
        admin_user = User(
            name="CPCB Inspector Arumugam S.",
            phone="9842100099",
            email="admin@ecoscrap.in",
            password_hash=hash_password("admin123"),
            role=UserRole.ADMIN,
            language="en",
            is_verified=True,
        )
        db.add(admin_user)
        db.commit()

        admin_profile = AdminProfile(
            user_id=admin_user.id,
            officer_id="CPCB-TN-OFFICER-001",
            department="CPCB Hazardous Waste Management Division",
            designation="Senior E-Waste Regulatory Inspector",
            jurisdiction="Tamil Nadu - Western Zone (Coimbatore & Tirupur)",
        )
        db.add(admin_profile)
        db.commit()

        # Print summary
        lot_count = db.query(Lot).count()
        bid_count = db.query(Bid).count()
        user_count = db.query(User).count()
        payment_count = db.query(Payment).count()
        dispute_count = db.query(Dispute).count()

        logger.info(
            f"Database successfully reset! Current stats:\n"
            f"  - Users: {user_count} (Collector, Recycler, Admin)\n"
            f"  - Lots: {lot_count}\n"
            f"  - Bids: {bid_count}\n"
            f"  - Payments: {payment_count}\n"
            f"  - Disputes: {dispute_count}"
        )

    except Exception as e:
        logger.error(f"Error resetting database: {e}")
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == "__main__":
    clean_database()
