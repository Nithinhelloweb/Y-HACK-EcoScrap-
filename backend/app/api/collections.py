import random
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.app.database import get_db
from backend.app.models import Collection, CollectionItem, CollectorProfile, CollectionStatus
from backend.app.schemas import (
    CollectionCreate,
    CollectionResponse,
    CollectionItemCreate,
    CollectionItemResponse
)

router = APIRouter(prefix="/collections", tags=["Collections & E-Waste Aggregation"])

@router.post("", response_model=CollectionResponse)
def create_collection(col_in: CollectionCreate, db: Session = Depends(get_db)):
    """
    POST /api/collections
    Creates a new draft collection for an informal collector.
    """
    collector = None
    if col_in.collector_id:
        collector = db.query(CollectorProfile).filter(CollectorProfile.id == col_in.collector_id).first()
    if not collector:
        collector = db.query(CollectorProfile).first()
        if not collector:
            raise HTTPException(status_code=400, detail="No collector found")

    code = f"COL-TN-2026-{random.randint(10000, 99999)}"
    total_qty = sum(i.quantity for i in col_in.items)

    collection = Collection(
        collection_code=code,
        collector_id=collector.id,
        source_type=col_in.source_type or "household",
        status=CollectionStatus.DRAFT,
        total_items_count=total_qty,
        notes=col_in.notes or ""
    )
    db.add(collection)
    db.flush()

    for item_data in col_in.items:
        # map synonym to normalized type
        norm = "UNKNOWN"
        name_lower = item_data.name.lower()
        if "laptop" in name_lower:
            norm = "LAPTOP"
        elif "cable" in name_lower or "copper" in name_lower or "wire" in name_lower:
            norm = "COPPER_CABLE"
        elif "battery" in name_lower:
            norm = "BATTERY"
        elif "pcb" in name_lower or "motherboard" in name_lower:
            norm = "PCB"

        c_item = CollectionItem(
            collection_id=collection.id,
            name=item_data.name,
            normalized_type=norm,
            quantity=item_data.quantity,
            unit=item_data.unit,
            estimated_weight_kg=item_data.estimated_weight_kg
        )
        db.add(c_item)

    db.commit()
    db.refresh(collection)
    return collection

@router.post("/{collection_id}/items", response_model=CollectionItemResponse)
def add_item_to_collection(
    collection_id: str,
    item_in: CollectionItemCreate,
    db: Session = Depends(get_db)
):
    """
    POST /api/collections/{id}/items
    Adds a scrap item to an existing collection draft.
    """
    collection = db.query(Collection).filter(Collection.id == collection_id).first()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")

    name_lower = item_in.name.lower()
    norm = "UNKNOWN"
    if "laptop" in name_lower:
        norm = "LAPTOP"
    elif "cable" in name_lower or "copper" in name_lower or "wire" in name_lower:
        norm = "COPPER_CABLE"
    elif "battery" in name_lower:
        norm = "BATTERY"
    elif "pcb" in name_lower or "motherboard" in name_lower:
        norm = "PCB"

    item = CollectionItem(
        collection_id=collection.id,
        name=item_in.name,
        normalized_type=norm,
        quantity=item_in.quantity,
        unit=item_in.unit,
        estimated_weight_kg=item_in.estimated_weight_kg
    )
    db.add(item)
    collection.total_items_count += item_in.quantity
    db.commit()
    db.refresh(item)
    return item

@router.get("", response_model=List[CollectionResponse])
def list_collections(collector_id: Optional[str] = None, db: Session = Depends(get_db)):
    """
    GET /api/collections
    Lists collections filtered by collector or all drafts.
    """
    query = db.query(Collection)
    if collector_id:
        query = query.filter(Collection.collector_id == collector_id)
    return query.order_by(Collection.created_at.desc()).all()

@router.get("/{collection_id}", response_model=CollectionResponse)
def get_collection(collection_id: str, db: Session = Depends(get_db)):
    """
    GET /api/collections/{id}
    Retrieves collection details with all extracted items.
    """
    col = db.query(Collection).filter(Collection.id == collection_id).first()
    if not col:
        raise HTTPException(status_code=404, detail="Collection not found")
    return col
