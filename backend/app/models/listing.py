"""Listing model. Table exists in Phase 1 so migrations are stable;
no listing endpoints are exposed until Phase 2/3."""
from __future__ import annotations

import enum

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    String,
    Text,
    Numeric,
    Float,
    Boolean,
    DateTime,
    ForeignKey,
    Enum as SAEnum,
    Index,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class PropertyType(str, enum.Enum):
    APARTMENT = "apartment"
    HOUSE = "house"
    VILLA = "villa"
    LAND = "land"
    COMMERCIAL = "commercial"


class ListingStatus(str, enum.Enum):
    ACTIVE = "active"
    SOLD = "sold"
    EXPIRED = "expired"
    HIDDEN = "hidden"


class ListingKind(str, enum.Enum):
    """Whether the listing is a sale or a rental — the single biggest
    filter Egyptian buyers apply. Every listing has exactly one kind."""
    SALE = "sale"
    RENT = "rent"


class DeliveryStatus(str, enum.Enum):
    """For sale/apartment/villa/commercial: is the unit ready to move
    into, or still under construction? Not applicable for LAND."""
    READY = "ready"
    UNDER_CONSTRUCTION = "under_construction"


class Listing(TimestampMixin, db.Model):
    __tablename__ = "listings"

    # SQLite only auto-increments INTEGER PRIMARY KEY; Postgres keeps BIGINT.
    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    broker_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)

    price_egp = Column(Numeric(14, 2), nullable=False)
    area_m2 = Column(Numeric(8, 2), nullable=False)

    governorate = Column(String(80), nullable=False)
    city = Column(String(120), nullable=False)
    district = Column(String(120), nullable=True)

    # Nullable in Phase 1; enforced from Phase 3.
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)

    property_type = Column(
        SAEnum(PropertyType, name="property_type", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    status = Column(
        SAEnum(
            ListingStatus,
            name="listing_status",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=ListingStatus.ACTIVE,
        server_default=ListingStatus.ACTIVE.value,
    )

    # ── Phase A1: richer property fields ──────────────────────────
    listing_kind = Column(
        SAEnum(ListingKind, name="listing_kind",
               values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=ListingKind.SALE,
        server_default=ListingKind.SALE.value,
    )
    # None where the field doesn't apply — land has no bedrooms, a villa
    # has no floor number. Buyers filter with min-thresholds so unspecified
    # rows still get excluded from a "3+ bed" search naturally.
    bedrooms = Column(Integer, nullable=True)
    bathrooms = Column(Integer, nullable=True)
    floor_number = Column(Integer, nullable=True)
    # Tri-state: True/False/None(=unspecified).
    is_furnished = Column(Boolean, nullable=True)
    compound_name = Column(String(120), nullable=True, index=True)
    delivery_status = Column(
        SAEnum(DeliveryStatus, name="delivery_status",
               values_callable=lambda x: [e.value for e in x]),
        nullable=True,
    )

    # Drives the Phase 3 auto-expire flow.
    last_confirmed_at = Column(DateTime(timezone=True), nullable=True)

    # Phase 3 duplicate-detection: set when this listing's photo pHash
    # matches an existing photo on another listing.
    duplicate_suspected = Column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    duplicate_of_listing_id = Column(
        BigInteger,
        ForeignKey("listings.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Phase G2 — lifetime view counter. Incremented atomically by the
    # public /l/<id> route (owner self-views excluded). Broker
    # analytics screen shows it plus the ListingViewDay time-series.
    total_views = Column(
        Integer, nullable=False, default=0, server_default="0"
    )

    broker = relationship("User", foreign_keys=[broker_id])
    photos = relationship(
        "ListingPhoto",
        back_populates="listing",
        cascade="all, delete-orphan",
        order_by="ListingPhoto.sort_order",
    )
    documents = relationship(
        "ListingDocument",
        back_populates="listing",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("ix_listings_status_location", "status", "governorate", "city"),
        Index("ix_listings_last_confirmed", "last_confirmed_at"),
    )
