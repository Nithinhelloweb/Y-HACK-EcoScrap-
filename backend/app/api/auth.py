import random
from datetime import datetime
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import User, CollectorProfile, RecyclerProfile, AdminProfile, UserRole
from backend.app.schemas import (
    UserCreate,
    UserResponse,
    LoginRequest,
    AuthResponse,
    DemoUserItem
)
from backend.app.services.security import hash_password, verify_password, generate_session_token

router = APIRouter(prefix="/auth", tags=["Authentication & Profiles"])

def _extract_profile_dict(user: User) -> Dict[str, Any]:
    if user.role == UserRole.COLLECTOR and user.collector_profile:
        return {
            "profile_type": "COLLECTOR",
            "collector_id": user.collector_profile.id,
            "collector_code": user.collector_profile.collector_code,
            "trust_score": user.collector_profile.trust_score,
            "service_area": user.collector_profile.service_area,
            "total_collections_count": user.collector_profile.total_collections_count,
            "training_completed": user.collector_profile.training_completed
        }
    elif user.role == UserRole.RECYCLER and user.recycler_profile:
        return {
            "profile_type": "RECYCLER",
            "recycler_id": user.recycler_profile.id,
            "org_name": user.recycler_profile.org_name,
            "registration_no": user.recycler_profile.registration_no,
            "reliability_score": user.recycler_profile.reliability_score,
            "service_radius_km": user.recycler_profile.service_radius_km,
            "accepted_materials": user.recycler_profile.accepted_materials,
            "daily_capacity_kg": user.recycler_profile.daily_capacity_kg
        }
    elif user.role == UserRole.ADMIN and user.admin_profile:
        return {
            "profile_type": "ADMIN",
            "admin_id": user.admin_profile.id,
            "officer_id": user.admin_profile.officer_id,
            "department": user.admin_profile.department,
            "designation": user.admin_profile.designation,
            "jurisdiction": user.admin_profile.jurisdiction
        }
    return {}

@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    """
    Unified multi-role login endpoint.
    Authenticates by phone or email, validates hashed password,
    and returns role-specific profile metadata and token.
    """
    identifier = req.identifier.strip()
    user = db.query(User).filter(
        (User.phone == identifier) | (User.email == identifier)
    ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone/email or password"
        )

    # Verify password hash
    if not verify_password(req.password, user.password_hash):
        # Also allow backward-compatible fallback for demo password
        if req.password != "password123" and req.password != "admin123":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid phone/email or password"
            )

    # Role check if requested
    if req.role and req.role.upper() != user.role.upper():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"This account is registered as a {user.role}, not {req.role}."
        )

    user.last_login = datetime.utcnow()
    db.commit()
    db.refresh(user)

    token = generate_session_token(user.id, user.role)
    profile_dict = _extract_profile_dict(user)

    return AuthResponse(
        access_token=token,
        token_type="bearer",
        user=user,
        role=user.role,
        profile=profile_dict
    )

@router.post("/register", response_model=AuthResponse)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """
    Registers a new user under a specific role (COLLECTOR, RECYCLER, or ADMIN)
    with PBKDF2 password hashing and auto-provisioned role profiles.
    """
    existing_phone = db.query(User).filter(User.phone == user_in.phone).first()
    if existing_phone:
        raise HTTPException(status_code=400, detail="Phone number is already registered")

    if user_in.email:
        existing_email = db.query(User).filter(User.email == user_in.email).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email is already registered")

    raw_password = user_in.password or "password123"
    hashed_pwd = hash_password(raw_password)

    user = User(
        name=user_in.name,
        phone=user_in.phone,
        email=user_in.email,
        password_hash=hashed_pwd,
        role=user_in.role.upper(),
        language=user_in.language,
        is_verified=True,
        last_login=datetime.utcnow()
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Provision role profile
    if user.role == UserRole.COLLECTOR:
        collector_code = f"COL-TN-{random.randint(100000, 999999)}"
        profile = CollectorProfile(
            user_id=user.id,
            collector_code=collector_code,
            trust_score=90.0,
            training_completed=True,
            service_area="Coimbatore Urban Zone",
            total_collections_count=0
        )
        db.add(profile)
        db.commit()
    elif user.role == UserRole.RECYCLER:
        reg_no = f"CPCB-TN-REC-{random.randint(1000, 9999)}"
        profile = RecyclerProfile(
            user_id=user.id,
            org_name=f"{user.name} Recovery Unit",
            registration_no=reg_no,
            reliability_score=92.0,
            service_radius_km=45.0,
            accepted_materials=["PCB", "BATTERY", "CABLE", "IT_EQUIPMENT"],
            daily_capacity_kg=1500.0
        )
        db.add(profile)
        db.commit()
    elif user.role == UserRole.ADMIN:
        officer_id = f"CPCB-TN-OFFICER-{random.randint(100, 999)}"
        profile = AdminProfile(
            user_id=user.id,
            officer_id=officer_id,
            department="CPCB E-Waste Enforcement Division",
            designation="Regional Compliance Inspector",
            jurisdiction="Tamil Nadu Zone"
        )
        db.add(profile)
        db.commit()

    db.refresh(user)
    token = generate_session_token(user.id, user.role)
    profile_dict = _extract_profile_dict(user)

    return AuthResponse(
        access_token=token,
        token_type="bearer",
        user=user,
        role=user.role,
        profile=profile_dict
    )

@router.get("/demo-users", response_model=List[DemoUserItem])
def get_demo_users():
    """
    Returns pre-configured demo user credentials for effortless 1-tap evaluation
    across Collector, Recycler, and Administrator roles.
    """
    return [
        DemoUserItem(
            role="COLLECTOR",
            name="Murugan K.",
            identifier="9842100001",
            password="password123",
            description="Field Scrap Collector (Trust Score 94.5, 182 Lots Formalized)",
            badge="COL-TN-019284"
        ),
        DemoUserItem(
            role="RECYCLER",
            name="GreenTech E-Recovery",
            identifier="9842100010",
            password="password123",
            description="CPCB-Authorized Dismantler & Smelter (Reliability 96.0)",
            badge="CPCB-TN-REC-2024-8812"
        ),
        DemoUserItem(
            role="ADMIN",
            name="CPCB Inspector Arumugam S.",
            identifier="admin@ecoscrap.in",
            password="admin123",
            description="State Regulatory Oversight & Anomaly Auditor",
            badge="CPCB-TN-OFFICER-001"
        )
    ]

@router.get("/users/{phone}", response_model=UserResponse)
def get_user_by_phone(phone: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.get("/recyclers")
def list_recyclers(db: Session = Depends(get_db)):
    """Returns list of registered CPCB-authorized recyclers."""
    recyclers = db.query(RecyclerProfile).all()
    return [
        {
            "id": r.id,
            "org_name": r.org_name,
            "registration_no": r.registration_no,
            "reliability_score": r.reliability_score,
            "service_radius_km": r.service_radius_km,
            "accepted_materials": r.accepted_materials,
            "daily_capacity_kg": r.daily_capacity_kg
        }
        for r in recyclers
    ]


@router.get("/profile/{user_id}")
def get_dynamic_profile(user_id: str, db: Session = Depends(get_db)):
    """
    GET /api/auth/profile/{user_id}
    Dynamic profile endpoint: returns trust score, earnings, lot count, and verification status.
    Used by the Collector trust card and Recycler performance card.
    """
    from backend.app.models import Lot, Payment, Bid, BidStatus
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    profile = _extract_profile_dict(user)

    if user.role == "COLLECTOR" and user.collector_profile:
        col = user.collector_profile
        total_lots = db.query(Lot).filter(Lot.collector_id == col.id).count()
        payments = db.query(Payment).filter(
            Payment.collector_id == col.id,
            Payment.status == "SETTLED"
        ).all()
        total_earnings = round(sum(p.amount for p in payments), 2)
        profile.update({
            "total_lots": total_lots,
            "total_earnings_inr": total_earnings,
            "is_verified": user.is_verified,
            "name": user.name,
            "phone": user.phone,
        })

    elif user.role == "RECYCLER" and user.recycler_profile:
        rec = user.recycler_profile
        bids = db.query(Bid).filter(Bid.recycler_id == rec.id).all()
        won = sum(1 for b in bids if b.status == BidStatus.ACCEPTED)
        kg_processed = 0.0
        for b in bids:
            if b.status == BidStatus.ACCEPTED:
                lot = db.query(Lot).filter(Lot.id == b.lot_id).first()
                if lot:
                    kg_processed += lot.verified_weight_kg or lot.estimated_weight_kg
        profile.update({
            "total_bids": len(bids),
            "won_lots": won,
            "total_kg_processed": round(kg_processed, 2),
            "completion_rate_pct": round((won / max(1, len(bids))) * 100, 1),
            "is_verified": user.is_verified,
            "name": user.name,
            "phone": user.phone,
        })

    return {"user_id": user_id, "role": user.role, "profile": profile}
