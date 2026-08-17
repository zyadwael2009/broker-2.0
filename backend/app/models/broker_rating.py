"""Per-buyer, per-broker rating.

One row per (rater, broker) — POST is an upsert. Provenance thread_id is
kept nullable/SET-NULL so the rating survives thread deletion (a buyer
who rated their broker doesn't lose the rating if we later add a
"delete thread" feature).
"""
from __future__ import annotations

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    SmallInteger,
    Text,
    ForeignKey,
    CheckConstraint,
    UniqueConstraint,
    Index,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class BrokerRating(TimestampMixin, db.Model):
    __tablename__ = "broker_ratings"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    rater_user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    broker_user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    thread_id = Column(
        BigInteger,
        ForeignKey("message_threads.id", ondelete="SET NULL"),
        nullable=True,
    )

    stars = Column(SmallInteger, nullable=False)
    note = Column(Text, nullable=True)

    rater = relationship("User", foreign_keys=[rater_user_id])
    broker = relationship("User", foreign_keys=[broker_user_id])

    __table_args__ = (
        UniqueConstraint(
            "rater_user_id", "broker_user_id",
            name="uq_ratings_rater_broker",
        ),
        CheckConstraint(
            "stars BETWEEN 1 AND 5",
            name="ck_ratings_stars_range",
        ),
        # Broker's public profile reads WHERE broker_user_id=? ORDER BY id DESC.
        Index("ix_ratings_broker_recent", "broker_user_id", "id"),
    )

    def to_public_dict(self) -> dict:
        rater = self.rater
        display_name = _initial_form(rater.full_name if rater else "")
        return {
            "id": self.id,
            "broker_user_id": self.broker_user_id,
            "stars": self.stars,
            "note": self.note,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "rater_display": display_name,
        }


def _initial_form(full_name: str) -> str:
    """`Aya Buyer` → `Aya B.`  ·  `Mohamed` → `Mohamed`  ·  `` → `Anonymous`.
    Keeps the reviewer's surname private in the public list."""
    name = full_name.strip()
    if not name:
        return "Anonymous"
    parts = name.split()
    if len(parts) == 1:
        return parts[0]
    return f"{parts[0]} {parts[-1][0]}."
