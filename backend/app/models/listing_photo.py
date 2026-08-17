"""Listing photo model. One row per uploaded image; the perceptual hash
column feeds the Phase-3 duplicate-detection scan."""
from __future__ import annotations

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    String,
    Text,
    SmallInteger,
    ForeignKey,
    Index,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class ListingPhoto(TimestampMixin, db.Model):
    __tablename__ = "listing_photos"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    listing_id = Column(
        BigInteger,
        ForeignKey("listings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    storage_key = Column(Text, nullable=False)
    # 16-hex-char perceptual hash. Stored as string for portability across
    # SQLite (no bitwise popcount) and Postgres. Duplicate scan reads all
    # existing hashes in Python and compares Hamming distance — trivial
    # cost until listing volume grows.
    phash = Column(String(16), nullable=False, index=True)

    sort_order = Column(SmallInteger, nullable=False, default=0, server_default="0")

    listing = relationship("Listing", back_populates="photos")

    __table_args__ = (
        Index("ix_listing_photos_listing_sort", "listing_id", "sort_order"),
    )

    def to_public_dict(self, url: str) -> dict:
        return {
            "id": self.id,
            "url": url,
            "sort_order": self.sort_order,
        }
