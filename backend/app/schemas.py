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
    visual_features: Optional[Dict[str, Any]] = None
    composition_breakdown: Optional[Dict[str, Any]] = None
    fair_value_estimate: Optional[Dict[str, Any]] = None
    image_analyzed: Optional[bool] = False
    detected_components: Optional[List[Dict[str, Any]]] = None
    component_analysis: Optional[Dict[str, Any]] = None
    detected_text: Optional[str] = None
    extracted_brands: Optional[List[str]] = None
    extracted_models: Optional[List[str]] = None
    hazard_keywords: Optional[List[str]] = None
    ocr_confidence: Optional[float] = None
    estimated_weight_kg: Optional[float] = 1.0
    quantity: Optional[float] = 1.0
    accelerator: Optional[str] = None

class OCRResponse(BaseModel):
    detected_text: str
    extracted_brands: List[str]
    extracted_models: List[str]
    hazard_keywords: List[str]
    inferred_material_hint: Optional[str] = None
    ocr_confidence: float
    total_words_detected: int
    text_snippets: Optional[List[Dict[str, Any]]] = None

# ----------------- Active Learning & Self-Training -----------------
class DetectionEditFeedback(BaseModel):
    image_base64: Optional[str] = None
    original_item_name: Optional[str] = None
    original_category: Optional[str] = None
    original_subcategory: Optional[str] = None
    corrected_item_name: str
    corrected_category: str
    corrected_subcategory: str
    corrected_weight_kg: Optional[float] = None
    corrected_quantity: Optional[float] = 1.0
    corrected_condition: Optional[str] = "mixed"
    bounding_box: Optional[List[float]] = None  # [x1, y1, x2, y2]
    collector_id: Optional[str] = None

class DetectionEditResponse(BaseModel):
    status: str
    message: str
    sample_id: str
    total_training_samples: int

class SelfTrainingTriggerRequest(BaseModel):
    epochs: Optional[int] = 5
    batch_size: Optional[int] = 4
    imgsz: Optional[int] = 416

class SelfTrainingStatusResponse(BaseModel):
    status: str  # IDLE, TRAINING, COMPLETED, ERROR
    current_model_version: str
    base_model_classes: List[str]
    total_samples: int
    last_trained_at: Optional[str] = None
    metrics: Dict[str, Any] = {}

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

# ----------------- Collections -----------------
class CollectionItemCreate(BaseModel):
    name: str
    quantity: float = 1.0
    unit: str = "units"
    estimated_weight_kg: Optional[float] = None

class CollectionItemResponse(BaseModel):
    id: str
    collection_id: str
    name: str
    normalized_type: str
    quantity: float
    unit: str
    estimated_weight_kg: Optional[float] = None

    model_config = {"from_attributes": True}

class CollectionCreate(BaseModel):
    collector_id: Optional[str] = None
    items: List[CollectionItemCreate] = []
    source_type: str = "household"
    notes: Optional[str] = None

class CollectionResponse(BaseModel):
    id: str
    collection_code: str
    collector_id: str
    source_type: str
    status: str
    total_items_count: float
    notes: Optional[str] = None
    items: List[CollectionItemResponse] = []
    created_at: datetime

    model_config = {"from_attributes": True}

# ----------------- Payments -----------------
class PaymentResponse(BaseModel):
    id: str
    transaction_reference: str
    lot_id: Optional[str] = None
    collector_id: str
    recycler_id: Optional[str] = None
    amount: float
    currency: str = "INR"
    status: str
    payment_method: str
    settlement_date: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}

# ----------------- Voice Assistant -----------------
class VoiceSessionRequest(BaseModel):
    language: Optional[str] = "en"
    input_mode: Optional[str] = "push_to_talk"

class VoiceSessionResponse(BaseModel):
    session_id: str
    session_token: str
    user_id: str
    collector_id: Optional[str] = None
    language: str
    input_mode: str
    status: str
    expires_at: datetime
    tool_manifest: List[Dict[str, Any]] = []
    openai_realtime_config: Optional[Dict[str, Any]] = None

class VoiceCommandRequest(BaseModel):
    session_id: Optional[str] = None
    text: str
    language_hint: Optional[str] = None
    confirmed: Optional[bool] = None
    context: Optional[Dict[str, Any]] = None

class VoiceCommandResponse(BaseModel):
    intent: str
    detected_language: str
    entities: Dict[str, Any]
    missing_fields: List[str]
    spoken_response: str
    action_executed: Optional[str] = None
    action_result: Optional[Dict[str, Any]] = None
    requires_confirmation: bool = False
    confirmation_prompt: Optional[str] = None
    ui_payload: Optional[Dict[str, Any]] = None
    session_id: Optional[str] = None
    audio_url: Optional[str] = None

class VoiceTranscriptionResponse(BaseModel):
    text: str
    detected_language: Optional[str] = None
    confidence: Optional[float] = None
    accelerator: Optional[str] = None

class VoiceTTSRequest(BaseModel):
    text: str
    language: Optional[str] = "en"


# ----------------- Collector Profile & Earnings -----------------
class CollectorStatsResponse(BaseModel):
    collector_id: str
    collector_code: str
    name: str
    trust_score: float
    training_completed: bool
    service_area: str
    total_lots: int
    total_earnings_inr: float
    is_verified: bool
    last_active: Optional[str] = None


# ----------------- Recycler Performance Reputation -----------------
class RecyclerStatsResponse(BaseModel):
    recycler_id: str
    org_name: str
    registration_no: str
    reliability_score: float
    total_bids_submitted: int
    won_lots: int
    completion_rate_pct: float
    total_kg_processed: float
    avg_settlement_days: float
    accepted_materials: List[str]
    daily_capacity_kg: float


# ----------------- Admin User Management -----------------
class AdminCollectorListItem(BaseModel):
    user_id: str
    collector_id: str
    collector_code: str
    name: str
    phone: str
    trust_score: float
    total_lots: int
    total_earnings_inr: float
    is_verified: bool
    training_completed: bool
    service_area: str

    model_config = {"from_attributes": True}


class AdminRecyclerListItem(BaseModel):
    user_id: str
    recycler_id: str
    org_name: str
    registration_no: str
    reliability_score: float
    won_lots: int
    total_kg_processed: float
    is_verified: bool
    accepted_materials: List[str]
    daily_capacity_kg: float

    model_config = {"from_attributes": True}


# ----------------- Admin: Market Intelligence -----------------
class MarketTrendItem(BaseModel):
    category: str
    avg_price_per_kg: float
    total_lots: int
    open_lots: int
    closed_lots: int
    avg_weight_kg: float


class MarketTrendsResponse(BaseModel):
    trends: List[MarketTrendItem]
    top_categories: List[str]
    total_market_value_inr: float
    generated_at: str


# ----------------- Admin: Environmental Summary -----------------
class EnvironmentalSummaryResponse(BaseModel):
    total_ewaste_diverted_kg: float
    co2e_avoided_kg: float
    toxic_heavy_metals_contained_g: float
    trees_offset_equivalent: float
    recovered_fractions_by_category: Dict[str, Dict[str, float]]
    lots_closed_count: int
    lots_in_processing_count: int


# ----------------- Admin: Fraud Alerts -----------------
class FraudAlertItem(BaseModel):
    lot_id: str
    lot_code: str
    risk_type: str
    severity: str
    deviation_percentage: float
    explanation: str
    created_at: str


class FraudAlertsResponse(BaseModel):
    total_alerts: int
    high_severity: int
    medium_severity: int
    low_severity: int
    alerts: List[FraudAlertItem]


# ----------------- Admin: Verify User -----------------
class VerifyUserRequest(BaseModel):
    user_id: str
    verified: bool

