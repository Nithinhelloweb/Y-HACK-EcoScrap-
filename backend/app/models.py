import uuid
from datetime import datetime
from sqlalchemy import (
    Column,
    String,
    Float,
    Boolean,
    DateTime,
    ForeignKey,
    Text,
    Enum,
    JSON
)
from sqlalchemy.orm import relationship
from backend.app.database import Base

def generate_uuid():
    return str(uuid.uuid4())

class UserRole:
    COLLECTOR = "COLLECTOR"
    RECYCLER = "RECYCLER"
    HOUSEHOLD = "HOUSEHOLD"
    ADMIN = "ADMIN"

class LotStatus:
    DRAFT = "DRAFT"
    CREATED = "CREATED"
    OPEN_FOR_BIDS = "OPEN_FOR_BIDS"
    BID_SELECTED = "BID_SELECTED"
    HANDOVER_SCHEDULED = "HANDOVER_SCHEDULED"
    IN_TRANSIT = "IN_TRANSIT"
    RECEIVED = "RECEIVED"
    PROCESSING = "PROCESSING"
    MATERIAL_RECOVERED = "MATERIAL_RECOVERED"
    CLOSED = "CLOSED"

class BidStatus:
    SUBMITTED = "SUBMITTED"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=False, default="")
    role = Column(String(20), nullable=False, default=UserRole.COLLECTOR)
    language = Column(String(5), nullable=False, default="ta")  # ta, hi, en
    is_verified = Column(Boolean, default=True)
    last_login = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    collector_profile = relationship("CollectorProfile", back_populates="user", uselist=False)
    recycler_profile = relationship("RecyclerProfile", back_populates="user", uselist=False)
    admin_profile = relationship("AdminProfile", back_populates="user", uselist=False)

class AdminProfile(Base):
    __tablename__ = "admin_profiles"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    officer_id = Column(String(50), unique=True, nullable=False, index=True)
    department = Column(String(100), default="CPCB Hazardous Waste Division")
    designation = Column(String(100), default="Senior E-Waste Regulatory Inspector")
    jurisdiction = Column(String(100), default="Tamil Nadu - Coimbatore Zone")

    user = relationship("User", back_populates="admin_profile")

class CollectorProfile(Base):
    __tablename__ = "collectors"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    collector_code = Column(String(30), unique=True, nullable=False, index=True)
    trust_score = Column(Float, default=90.0)
    training_completed = Column(Boolean, default=True)
    service_area = Column(String(100), default="Coimbatore Central")
    total_collections_count = Column(Float, default=0)

    user = relationship("User", back_populates="collector_profile")
    lots = relationship("Lot", back_populates="collector")
    collections = relationship("Collection", back_populates="collector", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="collector", cascade="all, delete-orphan")

class RecyclerProfile(Base):
    __tablename__ = "recyclers"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    org_name = Column(String(150), nullable=False)
    registration_no = Column(String(50), nullable=False)
    reliability_score = Column(Float, default=92.0)
    service_radius_km = Column(Float, default=50.0)
    latitude = Column(Float, default=11.0168)
    longitude = Column(Float, default=76.9558)
    accepted_materials = Column(JSON, default=list)  # ["PCB", "BATTERY", "CABLE", "DISPLAY", "SMPS"]
    daily_capacity_kg = Column(Float, default=1000.0)

    user = relationship("User", back_populates="recycler_profile")
    bids = relationship("Bid", back_populates="recycler")

class Lot(Base):
    __tablename__ = "lots"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    lot_code = Column(String(50), unique=True, nullable=False, index=True)
    collector_id = Column(String(36), ForeignKey("collectors.id"), nullable=False)
    category = Column(String(50), nullable=False)        # PCB, BATTERY, CABLE, IT_EQUIPMENT
    subcategory = Column(String(80), nullable=False)     # IT_HIGH_GRADE_PCB, LITHIUM_ION, etc.
    estimated_weight_kg = Column(Float, nullable=False)
    verified_weight_kg = Column(Float, nullable=True)
    condition = Column(String(30), default="mixed")      # intact, mixed, dismantled
    fair_value_min = Column(Float, default=0.0)
    fair_value_max = Column(Float, default=0.0)
    status = Column(String(30), default=LotStatus.CREATED)
    photo_url = Column(String(255), nullable=True)
    qr_code_url = Column(String(255), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    collector = relationship("CollectorProfile", back_populates="lots")
    bids = relationship("Bid", back_populates="lot", cascade="all, delete-orphan")
    handover_events = relationship("HandoverEvent", back_populates="lot", cascade="all, delete-orphan")
    chain_events = relationship("ChainEvent", back_populates="lot", cascade="all, delete-orphan")
    risk_events = relationship("RiskEvent", back_populates="lot", cascade="all, delete-orphan")

class Bid(Base):
    __tablename__ = "bids"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    lot_id = Column(String(36), ForeignKey("lots.id"), nullable=False)
    recycler_id = Column(String(36), ForeignKey("recyclers.id"), nullable=False)
    offer_price = Column(Float, nullable=False)
    logistics_deduction = Column(Float, default=0.0)
    net_collector_payable = Column(Float, nullable=False)
    status = Column(String(20), default=BidStatus.SUBMITTED)
    match_score = Column(Float, default=85.0)
    is_anomaly = Column(Boolean, default=False)
    anomaly_reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    lot = relationship("Lot", back_populates="bids")
    recycler = relationship("RecyclerProfile", back_populates="bids")

class HandoverEvent(Base):
    __tablename__ = "handover_events"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    lot_id = Column(String(36), ForeignKey("lots.id"), nullable=False)
    otp_code = Column(String(6), nullable=False)
    otp_verified = Column(Boolean, default=False)
    scale_weight_kg = Column(Float, nullable=True)
    collector_confirmed = Column(Boolean, default=False)
    recycler_confirmed = Column(Boolean, default=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    lot = relationship("Lot", back_populates="handover_events")

class ChainEvent(Base):
    __tablename__ = "chain_events"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    lot_id = Column(String(36), ForeignKey("lots.id"), nullable=False)
    event_type = Column(String(50), nullable=False) # LOT_CREATED, BID_ACCEPTED, SCALE_VERIFIED, HANDOVER_DONE, RECYCLED
    previous_hash = Column(String(64), nullable=False)
    current_hash = Column(String(64), nullable=False)
    payload_json = Column(JSON, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    lot = relationship("Lot", back_populates="chain_events")

class RiskEvent(Base):
    __tablename__ = "risk_events"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    lot_id = Column(String(36), ForeignKey("lots.id"), nullable=False)
    risk_type = Column(String(50), nullable=False) # PRICE_ANOMALY_LOW, WEIGHT_MISMATCH, DUPLICATE_LOT
    deviation_percentage = Column(Float, default=0.0)
    severity = Column(String(20), default="MEDIUM") # LOW, MEDIUM, HIGH
    explanation = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    lot = relationship("Lot", back_populates="risk_events")

class CollectionStatus:
    DRAFT = "DRAFT"
    SUBMITTED = "SUBMITTED"
    CONVERTED_TO_LOT = "CONVERTED_TO_LOT"
    CANCELLED = "CANCELLED"

class PaymentStatus:
    PENDING = "PENDING"
    ESCROW_LOCKED = "ESCROW_LOCKED"
    SETTLED = "SETTLED"
    FAILED = "FAILED"

class Collection(Base):
    __tablename__ = "collections"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    collection_code = Column(String(50), unique=True, nullable=False, index=True)
    collector_id = Column(String(36), ForeignKey("collectors.id"), nullable=False)
    source_type = Column(String(50), default="household")  # household, commercial, institutional
    status = Column(String(30), default=CollectionStatus.DRAFT)
    total_items_count = Column(Float, default=0.0)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    collector = relationship("CollectorProfile", back_populates="collections")
    items = relationship("CollectionItem", back_populates="collection", cascade="all, delete-orphan")

class CollectionItem(Base):
    __tablename__ = "collection_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    collection_id = Column(String(36), ForeignKey("collections.id"), nullable=False)
    name = Column(String(100), nullable=False)
    normalized_type = Column(String(50), default="UNKNOWN")  # LAPTOP, COPPER_CABLE, BATTERY, PCB
    quantity = Column(Float, default=1.0)
    unit = Column(String(20), default="units")  # units, bags, kg, pieces
    estimated_weight_kg = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    collection = relationship("Collection", back_populates="items")

class Payment(Base):
    __tablename__ = "payments"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    transaction_reference = Column(String(100), unique=True, nullable=False, index=True)
    lot_id = Column(String(36), ForeignKey("lots.id"), nullable=True)
    collector_id = Column(String(36), ForeignKey("collectors.id"), nullable=False)
    recycler_id = Column(String(36), ForeignKey("recyclers.id"), nullable=True)
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default="INR")
    status = Column(String(30), default=PaymentStatus.SETTLED)
    payment_method = Column(String(50), default="UPI / Escrow Direct Bank")
    settlement_date = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    collector = relationship("CollectorProfile", back_populates="payments")
    lot = relationship("Lot")

class VoiceSession(Base):
    __tablename__ = "voice_sessions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    session_token = Column(String(100), unique=True, nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    language = Column(String(10), default="en")
    input_mode = Column(String(30), default="push_to_talk")  # push_to_talk, hands_free
    status = Column(String(30), default="ACTIVE")
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

class VoiceToolLog(Base):
    __tablename__ = "voice_tool_logs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    session_id = Column(String(100), nullable=True, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    intent = Column(String(50), nullable=False)
    tool_called = Column(String(50), nullable=False)
    parameters_hash = Column(String(64), nullable=False)
    execution_status = Column(String(30), default="SUCCESS")  # SUCCESS, FAILED, CONFIRMATION_REQUIRED
    latency_ms = Column(Float, default=0.0)
    error_code = Column(String(50), nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

