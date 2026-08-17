"""Phase G2 — per-day rolled-up view counter for the broker analytics
screen.

One row per (listing_id, day). Incremented by the public listing_page
route on every anonymous GET; owner self-views are excluded upstream.
Aggregated by the /brokers/me/analytics endpoint into 7d/30d totals and
a 30-day series for the chart."""
from __future__ import annotations

from sqlalchemy import (
    BigInteger,
    Column,
    Date,
    ForeignKey,
    Index,
    Integer,
    UniqueConstraint,
)

from ..extensions import db


_PkType = BigInteger().with_variant(Integer, "sqlite")


class ListingViewDay(db.Model):
    __tablename__ = "listing_view_days"

    id = Column(_PkType, primary_key=True)
    listing_id = Column(
        BigInteger,
        ForeignKey("listings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # UTC calendar day. Simpler than a full timestamp: 1 row per
    # listing per day. 100 listings × 365 days = 36 500 rows/year
    # per active broker — negligible.
    day = Column(Date, nullable=False, index=True)
    count = Column(Integer, nullable=False, default=0)

    __table_args__ = (
        UniqueConstraint("listing_id", "day", name="uq_view_day"),
        Index("ix_view_day_listing_day", "listing_id", "day"),
    )
