from typing import List, Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field

# ----------------- User & Profile -----------------
class UserBase(BaseModel):
    name: str
    phone: str
    email: Optional[str] = None
    role: str = "COLLECTOR"
    language: str = "ta"

class UserCreate(UserBase):
    password: Optional[str] = "password123"

class CollectorProfileSchema(BaseModel):
    id: Optional[str] = None
    collector_code: str
    trust_score: float
    training_completed: bool
    service_area: str
    total_collections_count: float

    model_config = {"from_attributes": True}

class RecyclerProfileSchema(BaseModel):
    id: str
    org_name: str
    registration_no: str
    reliability_score: float
    service_radius_km: float
    accepted_materials: List[str]
    daily_capacity_kg: float

    model_config = {"from_attributes": True}

class AdminProfileSchema(BaseModel):
    id: str
    officer_id: str
    department: str
    designation: str
    jurisdiction: str

    model_config = {"from_attributes": True}

class UserResponse(UserBase):
    id: str
    is_verified: bool
    collector_profile: Optional[CollectorProfileSchema] = None
    recycler_profile: Optional[RecyclerProfileSchema] = None
    admin_profile: Optional[AdminProfileSchema] = None

    model_config = {"from_attributes": True}

class LoginRequest(BaseModel):
    identifier: str # phone or email
    password: str
    role: Optional[str] = None

class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    role: str
    profile: Dict[str, Any] = {}

class DemoUserItem(BaseModel):
    role: str
    name: str
    identifier: str
    password: str
    description: str
    badge: str

# ----------------- AI Lens -----------------
class MaterialClassifyResponse(BaseModel):
    category: str
    subcategory: str
    item_name: str
    grade: str
    confidence: float
    safety_flags: List[str]
    safety_guidance: str
    estimated_base_rate_per_kg: float
    recommended_action: str

# ----------------- Fair Value & Pricing -----------------
class PriceFactor(BaseModel):
    name: str
    adjustment_inr: float
    description: str

class PriceEstimateRequest(BaseModel):
    category: str
    subcategory: str
    weight_kg: float
    condition: str = "mixed"
    distance_km: float = 15.0

class PriceEstimateResponse(BaseModel):
    category: str
    subcategory: str
    weight_kg: float
    fair_value_min: float
    fair_value_max: float
    fair_value_median: float
    confidence_score: float
    breakdown: List[PriceFactor]
    currency: str = "INR"

# ----------------- Lot Management -----------------
class LotCreate(BaseModel):
    collector_id: str
    category: str
    subcategory: str
    estimated_weight_kg: float
    condition: str = "mixed"
    photo_url: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class BidResponse(BaseModel):
    id: str
    recycler_id: str
    recycler_name: Optional[str] = None
    offer_price: float
    logistics_deduction: float
    net_collector_payable: float
    match_score: float
    status: str
    is_anomaly: bool
    anomaly_reason: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}

class LotResponse(BaseModel):
    id: str
    lot_code: str
    collector_id: str
    collector_code: Optional[str] = None
    category: str
    subcategory: str
    estimated_weight_kg: float
    verified_weight_kg: Optional[float] = None
    condition: str
    fair_value_min: float
    fair_value_max: float
    status: str
    photo_url: Optional[str] = None
    qr_code_url: Optional[str] = None
    created_at: datetime
    bids: List[BidResponse] = []

    model_config = {"from_attributes": True}

class LotSyncItem(BaseModel):
    client_temp_id: str
    collector_id: str
    category: str
    subcategory: str
    estimated_weight_kg: float
    condition: str = "mixed"
    created_timestamp: Optional[str] = None

class LotSyncRequest(BaseModel):
    items: List[LotSyncItem]

class LotSyncResultItem(BaseModel):
    client_temp_id: str
    canonical_lot_id: str
    lot_code: str
    status: str

class LotSyncResponse(BaseModel):
    synced_count: int
    results: List[LotSyncResultItem]

# ----------------- Bidding -----------------
class BidCreate(BaseModel):
    lot_id: str
    recycler_id: str
    offer_price: float
    logistics_deduction: float = 0.0

# ----------------- Handover -----------------
class HandoverVerifyRequest(BaseModel):
    lot_id: str
    otp_code: str
    scale_weight_kg: float

class HandoverVerifyResponse(BaseModel):
    lot_id: str
    success: bool
    message: str
    weight_deviation_pct: float
    flagged_anomaly: bool

# ----------------- Passport & Ledger -----------------
class ChainEventResponse(BaseModel):
    id: str
    event_type: str
    previous_hash: str
    current_hash: str
    payload_json: Dict[str, Any]
    timestamp: datetime

    model_config = {"from_attributes": True}

class PassportResponse(BaseModel):
    lot_code: str
    category: str
    subcategory: str
    collector_code: str
    verified_recycler_name: Optional[str] = None
    estimated_weight_kg: float
    verified_weight_kg: Optional[float] = None
    current_status: str
    created_at: datetime
    qr_code_url: Optional[str] = None
    ledger_integrity_valid: bool
    events_timeline: List[ChainEventResponse]
    recovered_fractions_estimate: Dict[str, float]
    environmental_savings: Dict[str, Any]
