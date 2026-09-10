"""Buyer favorites — one row per (user, listing) pair.

Backs the heart button on listing cards and the "Saved" bottom-nav tab.

Deliberately a join table and not a counter column on `listings`: the
product needs per-user state (did *I* save this?), and a global count is
derivable from here if we ever want it. Rows are cascade-deleted with
either side, so a deleted listing or a closed account leaves nothing
behind — which is also what PDPL erasure requires.
"""
from __future__ import annotations

from sqlalchemy import (
    BigInteger,
    Column,
    ForeignKey,
    Integer,
    UniqueConstraint,
)

from ..extensions import db
from ._mixins import TimestampMixin


class Favorite(TimestampMixin, db.Model):
    __tablename__ = "favorites"
    __table_args__ = (
        # Tapping the heart twice must not create a second row; the DB
        # enforces it so a double-tap race can't slip through.
        UniqueConstraint("user_id", "listing_id", name="uq_favorites_user_listing"),
    )

    # SQLite only auto-increments INTEGER PRIMARY KEY; Postgres keeps BIGINT.
    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    listing_id = Column(
        BigInteger,
        ForeignKey("listings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
