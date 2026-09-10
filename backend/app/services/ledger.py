import hashlib
import json
from datetime import datetime
from typing import Dict, Any, List
from sqlalchemy.orm import Session
from backend.app.models import ChainEvent

GENESIS_HASH = "0" * 64

def calculate_event_hash(previous_hash: str, event_type: str, payload: Dict[str, Any], timestamp_str: str) -> str:
    """
    Computes SHA-256 hash for an event chained to the previous event hash.
    """
    serialized_payload = json.dumps(payload, sort_keys=True, default=str)
    raw_content = f"{previous_hash}|{event_type}|{serialized_payload}|{timestamp_str}"
    return hashlib.sha256(raw_content.encode("utf-8")).hexdigest()

def record_chain_event(db: Session, lot_id: str, event_type: str, payload: Dict[str, Any]) -> ChainEvent:
    """
    Appends a new verified event block to the tamper-evident ledger for a lot.
    """
    # Fetch last event for this lot
    last_event = (
        db.query(ChainEvent)
        .filter(ChainEvent.lot_id == lot_id)
        .order_by(ChainEvent.timestamp.desc())
        .first()
    )

    previous_hash = last_event.current_hash if last_event else GENESIS_HASH
    now = datetime.utcnow()
    timestamp_str = now.isoformat()

    current_hash = calculate_event_hash(previous_hash, event_type, payload, timestamp_str)

    chain_event = ChainEvent(
        lot_id=lot_id,
        event_type=event_type,
        previous_hash=previous_hash,
        current_hash=current_hash,
        payload_json=payload,
        timestamp=now
    )
    db.add(chain_event)
    db.commit()
    db.refresh(chain_event)
    return chain_event

def verify_lot_chain_integrity(events: List[ChainEvent]) -> bool:
    """
    Verifies that no record in the ledger for a lot has been altered or tampered with.
    """
    if not events:
        return True

    expected_prev_hash = GENESIS_HASH
    # Ensure events are checked in chronological order
    sorted_events = sorted(events, key=lambda e: e.timestamp)

    for event in sorted_events:
        if event.previous_hash != expected_prev_hash:
            return False

        computed_hash = calculate_event_hash(
            event.previous_hash,
            event.event_type,
            event.payload_json,
            event.timestamp.isoformat()
        )
        if event.current_hash != computed_hash:
            return False

        expected_prev_hash = event.current_hash

    return True
