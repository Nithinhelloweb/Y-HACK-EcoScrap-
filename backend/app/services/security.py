import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple

# PBKDF2-HMAC-SHA256 password hashing (Zero AWS, pure Python standard library)
ITERATIONS = 100_000

def hash_password(password: str) -> str:
    """Hashes a plain text password with a cryptographically secure 16-byte random salt."""
    salt = secrets.token_hex(16)
    key = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        bytes.fromhex(salt),
        ITERATIONS
    )
    return f"{salt}"

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plain text password against a stored salt+hash."""
    try:
        if not hashed_password or '$' not in hashed_password:
            return False
        salt_hex, key_hex = hashed_password.split('$', 1)
        salt = bytes.fromhex(salt_hex)
        expected_key = hashlib.pbkdf2_hmac(
            'sha256',
            plain_password.encode('utf-8'),
            salt,
            ITERATIONS
        )
        return secrets.compare_digest(expected_key.hex(), key_hex)
    except Exception:
        return False

def generate_session_token(user_id: str, role: str) -> str:
    """Generates an opaque, cryptographically secure session token."""
    entropy = secrets.token_urlsafe(32)
    return f"ecoscrap_{role.lower()}_{entropy}"
