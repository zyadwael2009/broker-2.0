"""Broker profile — one row per user with role=broker.

Created automatically at registration in `pending` status. The GOEIC
registration number and the uploaded proof document arrive later
(Phase 2 admin-review flow).
"""
from __future__ import annotations

import enum

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    String,
    Text,
    DateTime,
    ForeignKey,
    Enum as SAEnum,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class VerificationStatus(str, enum.Enum):
    PENDING = "pending"
    VERIFIED = "verified"
    REJECTED = "rejected"


class BrokerProfile(TimestampMixin, db.Model):
    __tablename__ = "broker_profiles"

    # SQLite only auto-increments INTEGER PRIMARY KEY; Postgres keeps BIGINT.
    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True,
    )

    goeic_registration_number = Column(String(64), nullable=True)
    registration_document_path = Column(Text, nullable=True)

    verification_status = Column(
        SAEnum(
            VerificationStatus,
            name="verification_status",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=VerificationStatus.PENDING,
        server_default=VerificationStatus.PENDING.value,
    )
    verified_at = Column(DateTime(timezone=True), nullable=True)
    verified_by = Column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    rejection_reason = Column(Text, nullable=True)

    # PDPL consent audit trail — stamped with `PDPL_CONSENT_VERSION`
    # (see app/config.py) on every successful verification submit or
    # bulk import. Nullable because pre-consent-versioning rows exist.
    consent_version = Column(String(16), nullable=True)

    user = relationship("User", back_populates="broker_profile", foreign_keys=[user_id])
    # Admin who approved (never displayed publicly, but useful for audit).
    verifier = relationship("User", foreign_keys=[verified_by])

    def to_public_dict(self) -> dict:
        return {
            "goeic_registration_number": self.goeic_registration_number,
            "verification_status": self.verification_status.value,
            "verified_at": self.verified_at.isoformat() if self.verified_at else None,
            "rejection_reason": self.rejection_reason,
        }
