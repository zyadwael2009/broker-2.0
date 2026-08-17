"""Per-listing document checklist model.

One row per (listing, kind). Distinguishes self-reported (broker just
checked a box) from admin-verified (broker uploaded proof and an admin
approved it) so the buyer-facing UI can be honest about which is which.
"""
from __future__ import annotations

import enum

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    Text,
    DateTime,
    ForeignKey,
    Enum as SAEnum,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class DocumentKind(str, enum.Enum):
    """The three documents the spec calls out. Extending later is a
    schema-only change; no code branches on individual values."""
    TITLE_DEED = "title_deed"       # الشهر العقاري
    NO_LIENS = "no_liens"           # no liens / disputes
    TAX_CLEARANCE = "tax_clearance"


class DocumentState(str, enum.Enum):
    """Notably: `unset` is never stored — absence of a row means unset.

    We distinguish these five so the buyer badge can be honest about
    what's actually been verified vs merely asserted by the broker.
    """
    SELF_REPORTED = "self_reported"   # broker ticked a box, no proof
    PENDING = "pending"               # broker uploaded proof; admin queue
    VERIFIED = "verified"             # admin approved the proof
    REJECTED = "rejected"             # admin rejected; broker may resubmit


class ListingDocument(TimestampMixin, db.Model):
    __tablename__ = "listing_documents"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    listing_id = Column(
        BigInteger,
        ForeignKey("listings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    kind = Column(
        SAEnum(
            DocumentKind,
            name="document_kind",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )
    state = Column(
        SAEnum(
            DocumentState,
            name="document_state",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )

    # Set when the broker uploads proof; cleared on delete/self-report.
    storage_key = Column(Text, nullable=True)

    verified_at = Column(DateTime(timezone=True), nullable=True)
    verified_by = Column(
        BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    rejection_reason = Column(Text, nullable=True)

    listing = relationship("Listing", back_populates="documents")
    verifier = relationship("User", foreign_keys=[verified_by])

    __table_args__ = (
        # One row per (listing, kind) — POST replaces rather than duplicates.
        UniqueConstraint("listing_id", "kind", name="uq_listing_docs_listing_kind"),
    )

    def to_public_dict(self, include_document_url: bool = False, url: str | None = None) -> dict:
        payload: dict = {
            "id": self.id,
            "listing_id": self.listing_id,
            "kind": self.kind.value,
            "state": self.state.value,
            "has_document": self.storage_key is not None,
            "verified_at": self.verified_at.isoformat() if self.verified_at else None,
            "rejection_reason": self.rejection_reason,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
        if include_document_url:
            payload["document_url"] = url
        return payload
