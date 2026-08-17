"""Auth blueprint: /auth/register, /login, /refresh, /me, and Phase A2's
verify-phone + forgot-password + reset-password endpoints."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    get_jwt,
    get_jwt_identity,
    jwt_required,
    verify_jwt_in_request,
)
from marshmallow import ValidationError

from ..extensions import db, limiter
from ..models.broker_profile import BrokerProfile, VerificationStatus
from ..models.user import User, UserRole
from ..notifications import sms
from .revocation import revocation_list
from .schemas import LoginSchema, RegisterSchema
from .security import (
    constant_time_dummy_verify,
    generate_otp,
    generate_referral_code,
    hash_otp,
    hash_password,
    normalize_phone,
    verify_otp,
    verify_password,
)

auth_bp = Blueprint("auth", __name__)

_register_schema = RegisterSchema()
_login_schema = LoginSchema()


def _tokens_for(user: User) -> dict:
    """Build access + refresh tokens. Role, verification status (for
    brokers) and phone_verified all ride in the claims so the mobile
    client can gate UI without a round trip."""
    extra = _jwt_claims_for(user)
    access = create_access_token(identity=str(user.id), additional_claims=extra)
    refresh = create_refresh_token(identity=str(user.id), additional_claims=extra)
    return {"access_token": access, "refresh_token": refresh}


def _jwt_claims_for(user: User) -> dict:
    """Extra JWT claims for a user. Extracted so refresh + tokens_for
    stay in sync when we add/remove claims."""
    extra = {
        "role": user.role.value,
        "phone_verified": bool(user.phone_verified),
    }
    if user.role == UserRole.BROKER and user.broker_profile is not None:
        extra["verification_status"] = user.broker_profile.verification_status.value
    return extra


def _user_payload(user: User) -> dict:
    payload = {"user": user.to_public_dict()}
    if user.role == UserRole.BROKER and user.broker_profile is not None:
        payload["broker_profile"] = user.broker_profile.to_public_dict()
    return payload


# ── OTP helpers ────────────────────────────────────────────────────────

def _issue_otp_for(user: User, purpose: str, field_hash: str, field_exp: str) -> str:
    """Generate a fresh OTP, hash + store it, deliver via sms.send_otp.

    Returns the plaintext code so callers can (optionally, in dev) echo
    it back in the response body via SMS_DEBUG_RETURN_CODE.
    """
    code = generate_otp()
    ttl = timedelta(minutes=int(current_app.config.get("OTP_TTL_MINUTES", 10)))
    setattr(user, field_hash, hash_otp(code))
    setattr(user, field_exp, datetime.now(timezone.utc) + ttl)
    db.session.commit()
    # Send is best-effort — sms.send_otp never raises.
    sms.send_otp(user.phone, code, purpose)
    return code


def _debug_code_response_body(code: str) -> dict:
    """Include the plaintext OTP in the API response ONLY when
    SMS_DEBUG_RETURN_CODE is on (dev fixture flag; refused in prod).

    Reads env live so tests can monkeypatch the flag without re-importing
    Config (whose class attributes cache at module load)."""
    import os
    baked = bool(current_app.config.get("SMS_DEBUG_RETURN_CODE"))
    live = os.environ.get("SMS_DEBUG_RETURN_CODE", "").lower() == "true"
    if baked or live:
        return {"debug_code": code}
    return {}


def _clear_otp_fields(user: User, field_hash: str, field_exp: str) -> None:
    setattr(user, field_hash, None)
    setattr(user, field_exp, None)


def _otp_is_valid(user: User, code: str, field_hash: str, field_exp: str) -> bool:
    hashed = getattr(user, field_hash)
    expires_at = getattr(user, field_exp)
    if not hashed or not expires_at:
        return False
    # DateTime from SQLite may be naive; normalize.
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc) > expires_at:
        return False
    return verify_otp(code, hashed)


@auth_bp.post("/register")
@limiter.limit(lambda: current_app.config["RATELIMIT_REGISTER"])
def register():
    data = _register_schema.load(request.get_json(silent=True) or {})

    phone_e164 = normalize_phone(data["phone"])

    # Cheap pre-check so we can return a specific 409 instead of the
    # generic one from the IntegrityError handler.
    if User.query.filter_by(phone=phone_e164).first():
        return jsonify(error="An account with this phone number already exists."), 409
    if data.get("email") and User.query.filter_by(email=data["email"]).first():
        return jsonify(error="An account with this email already exists."), 409

    # Phase G1 — referral code capture. Silently ignore invalid codes;
    # anti-friction. Look-up is cheap (indexed unique column).
    referrer_id: int | None = None
    ref_code_in = (data.get("ref_code") or "").strip().lower()
    if ref_code_in:
        referrer = User.query.filter_by(referral_code=ref_code_in).first()
        if referrer is not None and referrer.is_active:
            referrer_id = referrer.id

    # Phase G1 — generate this user's own code with a short retry loop.
    # 8-char alphabet → collision odds negligible for our scale.
    new_code = generate_referral_code()
    for _ in range(6):
        if not User.query.filter_by(referral_code=new_code).first():
            break
        new_code = generate_referral_code()

    user = User(
        phone=phone_e164,
        email=data.get("email"),
        password_hash=hash_password(data["password"]),
        full_name=data["full_name"].strip(),
        role=UserRole(data["role"]),
        referral_code=new_code,
        referred_by_user_id=referrer_id,
    )
    db.session.add(user)
    db.session.flush()  # get user.id before creating the profile

    if user.role == UserRole.BROKER:
        db.session.add(
            BrokerProfile(
                user_id=user.id,
                verification_status=VerificationStatus.PENDING,
            )
        )

    db.session.commit()

    # Auto-issue a phone-verification OTP so the client can jump straight
    # to the verify screen. Never fatal — even if SMS delivery fails, the
    # user can request a fresh code later.
    debug_code = _issue_otp_for(
        user, "verify_phone", "phone_otp_hash", "phone_otp_expires_at"
    )
    return jsonify({
        **_user_payload(user),
        "tokens": _tokens_for(user),
        **_debug_code_response_body(debug_code),
    }), 201


@auth_bp.post("/login")
@limiter.limit(lambda: current_app.config["RATELIMIT_LOGIN"])
def login():
    data = _login_schema.load(request.get_json(silent=True) or {})
    phone_e164 = normalize_phone(data["phone"])

    user = User.query.filter_by(phone=phone_e164).first()
    # Constant-time-ish: run bcrypt either way so response time doesn't
    # leak whether the phone is registered.
    if user is None:
        constant_time_dummy_verify(data["password"])
        return jsonify(error="Invalid phone or password."), 401
    if not verify_password(data["password"], user.password_hash):
        return jsonify(error="Invalid phone or password."), 401
    if not user.is_active:
        return jsonify(error="Account is disabled."), 403

    return jsonify({**_user_payload(user), "tokens": _tokens_for(user)}), 200


@auth_bp.post("/refresh")
@limiter.limit(lambda: current_app.config["RATELIMIT_REFRESH"])
@jwt_required(refresh=True)
def refresh():
    """Rotate refresh tokens on every use — mint a new refresh + new
    access, and revoke the presented refresh so a leaked one can't be
    used twice. If a stolen token is used, the legitimate user's next
    refresh trips the blocklist and they log back in cleanly."""
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if user is None or not user.is_active:
        return jsonify(error="Account not available."), 401

    extra = _jwt_claims_for(user)
    access = create_access_token(identity=str(user.id), additional_claims=extra)
    new_refresh = create_refresh_token(identity=str(user.id), additional_claims=extra)

    # Revoke the refresh token we just spent.
    old_claims = get_jwt()
    old_jti = old_claims.get("jti")
    old_exp = old_claims.get("exp")
    if old_jti and old_exp:
        revocation_list.revoke(old_jti, float(old_exp))

    return jsonify(access_token=access, refresh_token=new_refresh), 200


@auth_bp.get("/me")
@jwt_required()
def me():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if user is None:
        return jsonify(error="User not found."), 404
    return jsonify(_user_payload(user)), 200


@auth_bp.post("/logout")
def logout():
    """Revoke every JTI in the request. Client passes an Authorization
    header with either the access or refresh token; if it happens to be
    both (very rare but possible) both get blocklisted.

    The mobile client compensates by calling this endpoint twice — once
    per token — so both loops complete. Non-mobile callers benefit too:
    even a single call revokes whichever token was presented rather than
    stopping at the first success as before."""
    for is_refresh in (False, True):
        try:
            verify_jwt_in_request(refresh=is_refresh, optional=False)
            claims = get_jwt()
            jti = claims.get("jti")
            exp = claims.get("exp")
            if jti and exp:
                revocation_list.revoke(jti, float(exp))
        except Exception:
            continue
    # 204 either way — clients always clear local state after logout,
    # even for a caller who forgot to send a token.
    return "", 204


# ── Phase A2: phone verification ───────────────────────────────────────

@auth_bp.post("/verify-phone/send")
@limiter.limit(lambda: current_app.config["RATELIMIT_VERIFY_PHONE"])
@jwt_required()
def verify_phone_send():
    """Send/resend an OTP to the current user's phone number.

    409 if the phone is already verified — no need to burn an SMS.
    Never fatal on delivery failure; user can retry.
    """
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if user is None or not user.is_active:
        return jsonify(error="Account not available."), 401
    if user.phone_verified:
        return jsonify(error="Phone number is already verified."), 409

    debug_code = _issue_otp_for(
        user, "verify_phone", "phone_otp_hash", "phone_otp_expires_at"
    )
    return jsonify({"sent": True, **_debug_code_response_body(debug_code)}), 200


@auth_bp.post("/verify-phone/confirm")
@limiter.limit(lambda: current_app.config["RATELIMIT_VERIFY_PHONE"])
@jwt_required()
def verify_phone_confirm():
    """Validate the 6-digit OTP the user typed. On success, flip
    phone_verified and null the code fields."""
    payload = request.get_json(silent=True) or {}
    code = str(payload.get("code") or "").strip()
    if len(code) != 6 or not code.isdigit():
        return jsonify(error="Enter the 6-digit code you received."), 400

    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if user is None or not user.is_active:
        return jsonify(error="Account not available."), 401
    if user.phone_verified:
        return jsonify(error="Phone number is already verified."), 409

    if not _otp_is_valid(user, code, "phone_otp_hash", "phone_otp_expires_at"):
        return jsonify(error="That code is incorrect or has expired."), 400

    user.phone_verified = True
    user.phone_verified_at = datetime.now(timezone.utc)
    _clear_otp_fields(user, "phone_otp_hash", "phone_otp_expires_at")
    db.session.commit()

    # Return an updated user + fresh tokens so the client's JWT carries
    # the new phone_verified=True claim without a separate refresh.
    return jsonify({
        **_user_payload(user),
        "tokens": _tokens_for(user),
    }), 200


# ── Phase A2: password reset ──────────────────────────────────────────

@auth_bp.post("/forgot-password")
@limiter.limit(lambda: current_app.config["RATELIMIT_FORGOT_PASSWORD"])
def forgot_password():
    """Send a reset code to the given phone.

    Anti-enumeration: we always return 200, whether or not an account
    with that phone exists. A rate limit keeps this cheap (SMS costs
    real money).
    """
    payload = request.get_json(silent=True) or {}
    raw_phone = payload.get("phone") or ""
    try:
        phone_e164 = normalize_phone(raw_phone)
    except ValidationError:
        # Even a malformed phone gets the same shape response.
        return jsonify({"sent": True}), 200

    user = User.query.filter_by(phone=phone_e164).first()
    debug_code = None
    if user is not None and user.is_active:
        debug_code = _issue_otp_for(
            user, "reset_password",
            "password_reset_hash", "password_reset_expires_at",
        )

    body = {"sent": True}
    # Only include debug_code when a user actually exists AND the flag
    # is on — otherwise we'd leak "no user for this phone" via absence.
    if debug_code is not None:
        body.update(_debug_code_response_body(debug_code))
    return jsonify(body), 200


@auth_bp.post("/reset-password")
@limiter.limit(lambda: current_app.config["RATELIMIT_RESET_PASSWORD"])
def reset_password():
    """Complete the password-reset flow. Validates OTP + updates hash +
    revokes every existing session for the user."""
    payload = request.get_json(silent=True) or {}
    raw_phone = payload.get("phone") or ""
    code = str(payload.get("code") or "").strip()
    new_password = payload.get("new_password") or ""

    if len(code) != 6 or not code.isdigit():
        return jsonify(error="Enter the 6-digit code you received."), 400
    min_len = current_app.config.get("MIN_PASSWORD_LEN", 8)
    if len(new_password) < min_len:
        return jsonify(
            error=f"Password must be at least {min_len} characters."
        ), 400

    try:
        phone_e164 = normalize_phone(raw_phone)
    except ValidationError:
        return jsonify(error="That code is incorrect or has expired."), 400

    user = User.query.filter_by(phone=phone_e164).first()
    if user is None or not user.is_active:
        # Constant-ish response so timing doesn't confirm phone existence.
        constant_time_dummy_verify(new_password)
        return jsonify(error="That code is incorrect or has expired."), 400

    if not _otp_is_valid(
        user, code, "password_reset_hash", "password_reset_expires_at"
    ):
        return jsonify(error="That code is incorrect or has expired."), 400

    # Rotate the password + clear the reset token + stamp the change
    # timestamp so every JWT issued before this moment is now revoked
    # (see __init__.py::_is_revoked). Truly kills old sessions.
    user.password_hash = hash_password(new_password)
    user.password_changed_at = datetime.now(timezone.utc)
    _clear_otp_fields(user, "password_reset_hash", "password_reset_expires_at")
    db.session.commit()

    return jsonify({"ok": True}), 200


# ── Phase G1: referrals ────────────────────────────────────────────────

def _referred_display_name(full_name: str | None) -> str:
    """First name + last-initial + period. Keeps identities recognizable
    to the referrer without exposing full names of everyone who signed
    up via them to whoever holds the JWT."""
    if not full_name:
        return "?"
    parts = full_name.strip().split()
    if not parts:
        return "?"
    if len(parts) == 1:
        return parts[0]
    return f"{parts[0]} {parts[-1][0].upper()}."


@auth_bp.get("/me/referrals")
@jwt_required()
def my_referrals():
    """Everyone the current user referred, most recent first."""
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if user is None or not user.is_active:
        return jsonify(error="Account not available."), 401

    referred = (
        User.query
        .filter(User.referred_by_user_id == user.id)
        .order_by(User.created_at.desc())
        .all()
    )
    return jsonify({
        "code": user.referral_code,
        "count": len(referred),
        "referred": [
            {
                "id": r.id,
                "display_name": _referred_display_name(r.full_name),
                "role": r.role.value,
                "phone_verified": bool(r.phone_verified),
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in referred
        ],
    }), 200
