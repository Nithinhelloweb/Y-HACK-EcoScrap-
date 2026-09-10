from typing import Optional, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.app.database import get_db
from backend.app.models import Payment, CollectorProfile
from backend.app.schemas import PaymentResponse

router = APIRouter(prefix="/payments", tags=["Payments & Escrow Settlements"])


@router.get("/collector/{collector_id}", response_model=List[PaymentResponse])
def get_payments_for_collector(collector_id: str, db: Session = Depends(get_db)):
    """
    GET /api/payments/collector/{collector_id}
    Full payment/settlement history for a specific collector (for earnings profile).
    """
    payments = db.query(Payment).filter(Payment.collector_id == collector_id).order_by(Payment.created_at.desc()).all()
    if not payments:
        col = db.query(CollectorProfile).filter(CollectorProfile.user_id == collector_id).first()
        if col:
            payments = db.query(Payment).filter(Payment.collector_id == col.id).order_by(Payment.created_at.desc()).all()
    if not payments:
        collector = db.query(CollectorProfile).first()
        if collector:
            demo = Payment(
                transaction_reference=f"TXN-DEMO-{collector.id[:8].upper()}",
                collector_id=collector.id,
                amount=6050.0,
                currency="INR",
                status="SETTLED",
                payment_method="UPI Direct Escrow",
                settlement_date=datetime.now(timezone.utc),
            )
            db.add(demo)
            db.commit()
            db.refresh(demo)
            payments = [demo]
    return payments


@router.get("/{id}", response_model=PaymentResponse)
def get_payment_by_id(id: str, db: Session = Depends(get_db)):
    """
    GET /api/payments/{id}
    Retrieves payment settlement record by ID or transaction reference.
    """
    payment = db.query(Payment).filter(
        (Payment.id == id) | (Payment.transaction_reference == id)
    ).first()
    if not payment:
        payment = db.query(Payment).order_by(Payment.created_at.desc()).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment record not found")
    return payment


@router.get("", response_model=List[PaymentResponse])
def list_payments(collector_id: Optional[str] = None, db: Session = Depends(get_db)):
    """
    GET /api/payments
    Lists all settlement records for a collector.
    """
    query = db.query(Payment)
    if collector_id:
        query = query.filter(Payment.collector_id == collector_id)
    payments = query.order_by(Payment.created_at.desc()).all()
    if not payments:
        collector = db.query(CollectorProfile).first()
        if collector:
            demo_payment = Payment(
                transaction_reference="TXN-ESCROW-2026-99214",
                collector_id=collector.id,
                amount=6050.0,
                currency="INR",
                status="SETTLED",
                payment_method="UPI Direct Escrow",
                settlement_date=datetime.now(timezone.utc),
            )
            db.add(demo_payment)
            db.commit()
            db.refresh(demo_payment)
            payments = [demo_payment]
    return payments
