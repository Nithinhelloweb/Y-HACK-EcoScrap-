import logging
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
    RiskEvent,
    UserRole,
    LotStatus,
    BidStatus,
    Payment,
    PaymentStatus,
    Collection,
    CollectionItem,
    CollectionStatus,
    Dispute,
    DisputeStatus,
    DisputeType,
    AuditLog
)
from backend.app.services.passport import generate_qr_for_lot
from backend.app.services.ledger import record_chain_event
from backend.app.services.security import hash_password

logger = logging.getLogger("ecoscrap.seed")

def seed_database():
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        # Check if already seeded
        if db.query(User).count() > 0:
            logger.info("Database already seeded with demo records.")
            return

        logger.info("Seeding realistic EcoScrap demo data for Tamil Nadu...")

        # 1. Collectors
        col1_user = User(
            name="Murugan K.",
            phone="9842100001",
            email="murugan@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.COLLECTOR,
            language="ta",
            is_verified=True
        )
        db.add(col1_user)
        db.commit()

        col1_profile = CollectorProfile(
            user_id=col1_user.id,
            collector_code="COL-TN-019284",
            trust_score=94.5,
            training_completed=True,
            service_area="Gandhipuram & RS Puram, Coimbatore",
            total_collections_count=182
        )
        db.add(col1_profile)

        col2_user = User(
            name="Selvam R.",
            phone="9842100002",
            email="selvam@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.COLLECTOR,
            language="ta",
            is_verified=True
        )
        db.add(col2_user)
        db.commit()

        col2_profile = CollectorProfile(
            user_id=col2_user.id,
            collector_code="COL-TN-019285",
            trust_score=91.0,
            training_completed=True,
            service_area="Peelamedu & Hopes College, Coimbatore",
            total_collections_count=94
        )
        db.add(col2_profile)
        db.commit()

        # 2. Recyclers
        rec1_user = User(
            name="GreenTech E-Recovery",
            phone="9842100010",
            email="greentech@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.RECYCLER,
            language="en",
            is_verified=True
        )
        db.add(rec1_user)
        db.commit()

        rec1_profile = RecyclerProfile(
            user_id=rec1_user.id,
            org_name="GreenTech Circular Solutions Pvt Ltd",
            registration_no="CPCB-TN-REC-2024-8812",
            reliability_score=96.0,
            service_radius_km=45.0,
            latitude=11.0250,
            longitude=76.9400,
            accepted_materials=["PCB", "BATTERY", "IT_EQUIPMENT"],
            daily_capacity_kg=2500.0
        )
        db.add(rec1_profile)

        rec2_user = User(
            name="EcoMetals Circular Hub",
            phone="9842100020",
            email="ecometals@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.RECYCLER,
            language="en",
            is_verified=True
        )
        db.add(rec2_user)
        db.commit()

        rec2_profile = RecyclerProfile(
            user_id=rec2_user.id,
            org_name="EcoMetals Smelting & Refining Corp",
            registration_no="CPCB-TN-REC-2023-4129",
            reliability_score=93.5,
            service_radius_km=60.0,
            latitude=10.9800,
            longitude=77.0100,
            accepted_materials=["CABLE", "PCB", "DISPLAY"],
            daily_capacity_kg=3200.0
        )
        db.add(rec2_profile)

        rec3_user = User(
            name="Kongu E-Waste Processors",
            phone="9842100030",
            email="kongu@ecoscrap.in",
            password_hash=hash_password("password123"),
            role=UserRole.RECYCLER,
            language="en",
            is_verified=True
        )
        db.add(rec3_user)
        db.commit()

        rec3_profile = RecyclerProfile(
            user_id=rec3_user.id,
            org_name="Kongu E-Waste Recovery Unit",
            registration_no="CPCB-TN-REC-2025-1044",
            reliability_score=90.0,
            service_radius_km=30.0,
            latitude=10.9500,
            longitude=76.9700,
            accepted_materials=["IT_EQUIPMENT", "PCB", "SMPS"],
            daily_capacity_kg=1200.0
        )
        db.add(rec3_profile)
        db.commit()

        # 3. Regulatory Administrators
        admin_user = User(
            name="CPCB Inspector Arumugam S.",
            phone="9842100099",
            email="admin@ecoscrap.in",
            password_hash=hash_password("admin123"),
            role=UserRole.ADMIN,
            language="en",
            is_verified=True
        )
        db.add(admin_user)
        db.commit()

        admin_profile = AdminProfile(
            user_id=admin_user.id,
            officer_id="CPCB-TN-OFFICER-001",
            department="CPCB Hazardous Waste Management Division",
            designation="Senior E-Waste Regulatory Inspector",
            jurisdiction="Tamil Nadu - Western Zone (Coimbatore & Tirupur)"
        )
        db.add(admin_profile)
        db.commit()

        # 3. Seed Realistic Demo Lots
        # Lot 1: High-Grade Laptop Motherboards (Active Bidding)
        lot1_code = "EW-TN-2026-000184"
        qr1_url = generate_qr_for_lot(lot1_code)

        lot1 = Lot(
            lot_code=lot1_code,
            collector_id=col1_profile.id,
            category="PCB",
            subcategory="IT_HIGH_GRADE_PCB",
            estimated_weight_kg=8.4,
            condition="mixed",
            fair_value_min=4700.0,
            fair_value_max=5200.0,
            status=LotStatus.OPEN_FOR_BIDS,
            qr_code_url=qr1_url,
            latitude=11.0168,
            longitude=76.9558
        )
        db.add(lot1)
        db.commit()
        db.refresh(lot1)

        # Genesis block for Lot 1
        record_chain_event(
            db=db,
            lot_id=lot1.id,
            event_type="LOT_CREATED",
            payload={
                "lot_code": lot1.lot_code,
                "category": lot1.category,
                "subcategory": lot1.subcategory,
                "estimated_weight_kg": lot1.estimated_weight_kg,
                "fair_value_min": lot1.fair_value_min,
                "fair_value_max": lot1.fair_value_max,
                "collector_code": col1_profile.collector_code
            }
        )

        # 3 Bids for Lot 1:
        # Bid 1: High quality offer by GreenTech (Top Match)
        bid1 = Bid(
            lot_id=lot1.id,
            recycler_id=rec1_profile.id,
            offer_price=5020.0,
            logistics_deduction=120.0,
            net_collector_payable=4900.0,
            status=BidStatus.SUBMITTED,
            match_score=94.2,
            is_anomaly=False
        )
        db.add(bid1)

        # Bid 2: Competitive offer by Kongu
        bid2 = Bid(
            lot_id=lot1.id,
            recycler_id=rec3_profile.id,
            offer_price=4720.0,
            logistics_deduction=80.0,
            net_collector_payable=4640.0,
            status=BidStatus.SUBMITTED,
            match_score=86.5,
            is_anomaly=False
        )
        db.add(bid2)

        # Bid 3: Predatory lowball offer by rogue intermediary (Triggers Anomaly Shield!)
        bid3 = Bid(
            lot_id=lot1.id,
            recycler_id=rec2_profile.id,
            offer_price=2950.0,
            logistics_deduction=150.0,
            net_collector_payable=2800.0,
            status=BidStatus.SUBMITTED,
            match_score=48.0,
            is_anomaly=True,
            anomaly_reason="🚨 PREDATORY OFFER: Offer ₹2,950 is 37.2% BELOW the fair minimum (₹4,700). Middleman exploitation detected."
        )
        db.add(bid3)

        # Log Risk Event
        db.add(RiskEvent(
            lot_id=lot1.id,
            risk_type="PRICE_ANOMALY_LOW",
            deviation_percentage=37.2,
            severity="HIGH",
            explanation="Predatory lowball offer detected from Recycler 2 (-37.2% below fair floor)."
        ))

        # Lot 2: Copper Rich Cables (Ready for Handover)
        lot2_code = "EW-TN-2026-000185"
        qr2_url = generate_qr_for_lot(lot2_code)
        lot2 = Lot(
            lot_code=lot2_code,
            collector_id=col1_profile.id,
            category="CABLE",
            subcategory="COPPER_RICH_CABLE",
            estimated_weight_kg=14.2,
            condition="intact",
            fair_value_min=5600.0,
            fair_value_max=6200.0,
            status=LotStatus.HANDOVER_SCHEDULED,
            qr_code_url=qr2_url
        )
        db.add(lot2)
        db.commit()
        db.refresh(lot2)

        record_chain_event(
            db=db,
            lot_id=lot2.id,
            event_type="LOT_CREATED",
            payload={"lot_code": lot2.lot_code, "weight_kg": 14.2}
        )
        record_chain_event(
            db=db,
            lot_id=lot2.id,
            event_type="BID_ACCEPTED",
            payload={"accepted_price_inr": 6050.0, "recycler": rec2_profile.org_name}
        )

        # Handover event for Lot 2
        handover2 = HandoverEvent(
            lot_id=lot2.id,
            otp_code="482910",
            otp_verified=False
        )
        db.add(handover2)

        # Demo Payment record for Murugan
        payment1 = Payment(
            transaction_reference="TXN-ESCROW-2026-99214",
            lot_id=lot2.id,
            collector_id=col1_profile.id,
            recycler_id=rec2_profile.id,
            amount=6050.0,
            currency="INR",
            status=PaymentStatus.SETTLED,
            payment_method="UPI Direct Escrow",
            settlement_date=datetime.utcnow()
        )
        db.add(payment1)

        # Demo Collection Draft for Murugan
        col_draft = Collection(
            collection_code="COL-TN-2026-10492",
            collector_id=col1_profile.id,
            source_type="household",
            status=CollectionStatus.DRAFT,
            total_items_count=5.0,
            notes="Household doorstep collection"
        )
        db.add(col_draft)
        db.flush()

        item1 = CollectionItem(
            collection_id=col_draft.id,
            name="old laptop",
            normalized_type="LAPTOP",
            quantity=3.0,
            unit="units"
        )
        item2 = CollectionItem(
            collection_id=col_draft.id,
            name="copper wire",
            normalized_type="COPPER_CABLE",
            quantity=2.0,
            unit="bags"
        )
        db.add_all([item1, item2])

        # Demo Dispute on Lot 2 (Weight Mismatch)
        demo_dispute = Dispute(
            lot_id=lot2.id,
            raised_by_id=col1_profile.id,
            raised_by_name="Murugan K.",
            raised_by_role="COLLECTOR",
            dispute_type=DisputeType.WEIGHT_MISMATCH,
            description="Recycler scale declared 13.6 kg vs collector calibrated scale 14.2 kg (0.6 kg difference).",
            evidence_notes="Photo of physical weighbridge slip uploaded at time of transfer.",
            status=DisputeStatus.NEW,
            created_at=datetime.utcnow()
        )
        db.add(demo_dispute)

        # Demo Audit Logs
        db.add_all([
            AuditLog(
                action="USER_VERIFIED",
                actor_id="CPCB-TN-OFFICER-001",
                actor_role="ADMIN",
                entity_type="USER",
                entity_id=col1_user.id,
                details={"user_name": "Murugan K.", "role": "COLLECTOR", "cpcb_status": "VERIFIED"},
                timestamp=datetime.utcnow()
            ),
            AuditLog(
                action="LOT_CREATED",
                actor_id=col1_profile.id,
                actor_role="COLLECTOR",
                entity_type="LOT",
                entity_id=lot1.id,
                details={"lot_code": lot1.lot_code, "category": "PCB", "weight_kg": 8.4},
                timestamp=datetime.utcnow()
            ),
            AuditLog(
                action="BID_ACCEPTED",
                actor_id=col1_profile.id,
                actor_role="COLLECTOR",
                entity_type="BID",
                entity_id=bid1.id,
                details={"lot_code": lot1.lot_code, "offer_price": 5020.0, "recycler": "GreenTech Circular Solutions"},
                timestamp=datetime.utcnow()
            ),
            AuditLog(
                action="DISPUTE_RAISED",
                actor_id=col1_profile.id,
                actor_role="COLLECTOR",
                entity_type="DISPUTE",
                entity_id=demo_dispute.id,
                details={"lot_code": lot2.lot_code, "dispute_type": "WEIGHT_MISMATCH"},
                timestamp=datetime.utcnow()
            )
        ])

        db.commit()
        logger.info("Successfully seeded demo data for EcoScrap!")

    except Exception as e:
        logger.error(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
