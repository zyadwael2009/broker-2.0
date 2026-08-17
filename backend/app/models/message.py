"""A single message inside a thread.

`read_at` is set the moment the RECIPIENT (not sender) polls for
messages after this one was written — so unread math for the recipient
is simply `WHERE read_at IS NULL AND sender_id != me`.
"""
from __future__ import annotations

from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    Text,
    DateTime,
    ForeignKey,
    Index,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class Message(TimestampMixin, db.Model):
    __tablename__ = "messages"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    thread_id = Column(
        BigInteger,
        ForeignKey("message_threads.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sender_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    body = Column(Text, nullable=False)
    read_at = Column(DateTime(timezone=True), nullable=True)

    thread = relationship("MessageThread", back_populates="messages")
    sender = relationship("User", foreign_keys=[sender_id])

    __table_args__ = (
        # Composite index for delta polling (WHERE thread_id=? AND id>?).
        # Named distinctly to avoid collision with the standalone
        # `ix_messages_thread_id` that `index=True` on thread_id creates.
        Index("ix_messages_thread_asc", "thread_id", "id"),
    )

    def to_public_dict(self) -> dict:
        return {
            "id": self.id,
            "thread_id": self.thread_id,
            "sender_id": self.sender_id,
            "body": self.body,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "read_at": self.read_at.isoformat() if self.read_at else None,
        }
