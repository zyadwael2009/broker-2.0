"""Password hashing, phone normalization, and a role-based access decorator.

Kept in its own module so route files stay focused on request/response
shape."""
from __future__ import annotations

import secrets
from functools import wraps

import phonenumbers
from flask import jsonify
from flask_jwt_extended import get_jwt, verify_jwt_in_request
from marshmallow import ValidationError

from ..extensions import bcrypt
from ..models.user import UserRole


# --- passwords ---------------------------------------------------------------

def hash_password(plain: str) -> str:
    return bcrypt.generate_password_hash(plain).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.check_password_hash(hashed, plain)
    except (ValueError, TypeError):
        return False


# Computed lazily on first use — at module import there's no Flask app
# context yet, and Flask-Bcrypt reads rounds from app config so a bare
# call there silently falls back to something (or worse, no-ops).
_DUMMY_HASH: str | None = None


def constant_time_dummy_verify(plain: str) -> bool:
    """Run bcrypt against a throwaway hash so login's `no such user`
    branch takes the same wall-time as `wrong password`. Always False."""
    global _DUMMY_HASH
    if _DUMMY_HASH is None:
        _DUMMY_HASH = bcrypt.generate_password_hash("dummy-timing-hash").decode("utf-8")
    verify_password(plain, _DUMMY_HASH)
    return False


# --- OTP codes (phone verify + password reset) -------------------------------

def generate_otp() -> str:
    """Cryptographically random 6-digit code, zero-padded."""
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_otp(code: str) -> str:
    """Same bcrypt primitive as passwords — one hash function to reason
    about + rotate. A DB dump doesn't reveal codes."""
    return hash_password(code)


def verify_otp(code: str, hashed: str) -> bool:
    return verify_password(code, hashed)


# --- referral codes ----------------------------------------------------------

# Ambiguous-character-free alphabet — safe to dictate over the phone
# (`o` vs `0`, `l/1/i`, upper vs lower — all excluded).
_REFERRAL_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789"


def generate_referral_code(length: int = 8) -> str:
    """Cryptographically-random short code. ~40 bits of entropy at 8
    chars is plenty for our scale (collision after ~1B users).

    The caller retries on collision — Postgres UNIQUE will 500 an
    insert but we check-then-insert on hot path.
    """
    return "".join(secrets.choice(_REFERRAL_ALPHABET) for _ in range(length))


# --- phone normalization -----------------------------------------------------

def normalize_phone(raw: str, default_region: str = "EG") -> str:
    """Parse a user-entered phone into E.164, defaulting to Egypt.

    Raises marshmallow.ValidationError so callers can surface a clean
    400 with a per-field message.
    """
    if not raw or not raw.strip():
        raise ValidationError("Phone number is required.")
    try:
        parsed = phonenumbers.parse(raw.strip(), default_region)
    except phonenumbers.NumberParseException as exc:
        raise ValidationError(f"Invalid phone number: {exc}") from exc
    if not phonenumbers.is_valid_number(parsed):
        raise ValidationError("Phone number is not valid.")
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


# --- role-based access -------------------------------------------------------

def roles_required(*allowed: str | UserRole):
    """Guard a view so only the listed roles can hit it.

    Usage:
        @roles_required('admin')
        def approve_broker(...): ...
    """
    allowed_values = {
        (r.value if isinstance(r, UserRole) else r) for r in allowed
    }

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            claims = get_jwt()
            role = claims.get("role")
            if role not in allowed_values:
                return jsonify(error="Forbidden: insufficient role"), 403
            return fn(*args, **kwargs)

        return wrapper

    return decorator
