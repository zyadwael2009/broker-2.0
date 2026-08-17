"""One conversation between a buyer and a broker about a specific listing.

Model design decisions:
- Unique per `(buyer_id, broker_id, listing_id)` — a buyer contacting the
  same broker about the same listing always lands in the same thread.
- `last_message_at` is denormalized so the inbox list stays cheap; kept
  in sync on every message insert.
"""
from __future__ import annotations

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    DateTime,
    ForeignKey,
    UniqueConstraint,
    Index,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class MessageThread(TimestampMixin, db.Model):
    __tablename__ = "message_threads"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    buyer_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    broker_id = Column(
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

    # Denormalized so the inbox `ORDER BY last_message_at DESC` is O(index).
    last_message_at = Column(DateTime(timezone=True), nullable=True)

    buyer = relationship("User", foreign_keys=[buyer_id])
    broker = relationship("User", foreign_keys=[broker_id])
    listing = relationship("Listing", foreign_keys=[listing_id])
    messages = relationship(
        "Message",
        back_populates="thread",
        cascade="all, delete-orphan",
        order_by="Message.id",
    )

    __table_args__ = (
        UniqueConstraint(
            "buyer_id", "broker_id", "listing_id",
            name="uq_thread_buyer_broker_listing",
        ),
        Index("ix_threads_last_msg_desc", "last_message_at"),
    )

    def counterparty_for(self, user_id: int):
        """Return the User on the other side of this thread from `user_id`."""
        if user_id == self.buyer_id:
            return self.broker
        if user_id == self.broker_id:
            return self.buyer
        return None
