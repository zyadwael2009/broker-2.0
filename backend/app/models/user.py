"""User model. Login identifier is phone (E.164); email is optional.

Admin accounts are never created via the public API — see
`app/cli.py::seed_admin` and `app/auth/schemas.py::RegisterSchema`
which rejects role='admin'.
"""
from __future__ import annotations

import enum

from sqlalchemy import (
    BigInteger, Boolean, Column, DateTime, Enum as SAEnum, ForeignKey, Integer, String,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


# SQLite only auto-increments INTEGER PRIMARY KEY; on Postgres this stays BIGINT.
_PkType = BigInteger().with_variant(Integer, "sqlite")


class UserRole(str, enum.Enum):
    BUYER = "buyer"
    BROKER = "broker"
    ADMIN = "admin"


class User(TimestampMixin, db.Model):
    __tablename__ = "users"

    id = Column(_PkType, primary_key=True)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(120), nullable=False)
    role = Column(
        SAEnum(UserRole, name="user_role", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    is_active = Column(Boolean, nullable=False, default=True, server_default="true")

    # ── Phase A2: phone verification (soft flag) ─────────────────────
    phone_verified = Column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    phone_verified_at = Column(DateTime(timezone=True), nullable=True)
    phone_otp_hash = Column(String(128), nullable=True)
    phone_otp_expires_at = Column(DateTime(timezone=True), nullable=True)

    # ── Phase A2: password reset ─────────────────────────────────────
    # Same bcrypt hashing family as phone_otp / password_hash — one primitive.
    password_reset_hash = Column(String(128), nullable=True)
    password_reset_expires_at = Column(DateTime(timezone=True), nullable=True)

    # ── Phase A3: session invalidation on password change ────────────
    # Every JWT carries an `iat` claim. When this timestamp is set to
    # `now()` on password change, the blocklist loader treats any JWT
    # with `iat < password_changed_at` as revoked — invalidating every
    # session created before the change.
    password_changed_at = Column(DateTime(timezone=True), nullable=True)

    # ── Phase G1: referral tracking ──────────────────────────────────
    # Short unique code brokers can share; `wasit.app/?ref=<code>`
    # captures the referrer on the referred user's register call.
    referral_code = Column(String(16), unique=True, nullable=True, index=True)
    # Who referred THIS user, if anyone. SET NULL cascade so deleting
    # a referrer doesn't nuke the referrals themselves.
    referred_by_user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Only present when role == BROKER. uselist=False makes it 1:1.
    broker_profile = relationship(
        "BrokerProfile",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
        foreign_keys="BrokerProfile.user_id",
    )

    def to_public_dict(self) -> dict:
        return {
            "id": self.id,
            "phone": self.phone,
            "email": self.email,
            "full_name": self.full_name,
            "role": self.role.value,
            "is_active": self.is_active,
            "phone_verified": self.phone_verified,
            "referral_code": self.referral_code,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
