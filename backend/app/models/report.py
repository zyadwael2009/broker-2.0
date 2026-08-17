"""User-reported problem (a suspicious listing or a bad broker).

`target_type` + `target_id` are polymorphic — same pattern as storage
keys. Kept polymorphic (not two nullable FKs) so adding a third target
type later doesn't require a schema migration and null-check gymnastics.
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
    Index,
)
from sqlalchemy.orm import relationship

from ..extensions import db
from ._mixins import TimestampMixin


class ReportTargetType(str, enum.Enum):
    LISTING = "listing"
    BROKER = "broker"


class ReportReason(str, enum.Enum):
    FRAUD = "fraud"
    SPAM = "spam"
    INAPPROPRIATE = "inappropriate"
    WRONG_INFO = "wrong_info"
    OTHER = "other"


class ReportStatus(str, enum.Enum):
    OPEN = "open"
    RESOLVED_ACTION = "resolved_action"       # admin took corrective action
    RESOLVED_NO_ACTION = "resolved_no_action" # legit, but nothing needed
    DISMISSED = "dismissed"                   # invalid / bad-faith report


class Report(TimestampMixin, db.Model):
    __tablename__ = "reports"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True)
    reporter_user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    target_type = Column(
        SAEnum(ReportTargetType, name="report_target_type",
               values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    target_id = Column(BigInteger, nullable=False)
    reason = Column(
        SAEnum(ReportReason, name="report_reason",
               values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    note = Column(Text, nullable=True)

    status = Column(
        SAEnum(ReportStatus, name="report_status",
               values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=ReportStatus.OPEN,
        server_default=ReportStatus.OPEN.value,
    )
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    resolved_by = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    resolution_note = Column(Text, nullable=True)

    reporter = relationship("User", foreign_keys=[reporter_user_id])
    resolver = relationship("User", foreign_keys=[resolved_by])

    __table_args__ = (
        # Admin queue reads WHERE status=? ORDER BY created_at DESC.
        Index("ix_reports_status_created", "status", "created_at"),
        Index("ix_reports_target", "target_type", "target_id"),
    )

    def to_admin_dict(self) -> dict:
        return {
            "id": self.id,
            "reporter": (
                {"id": self.reporter.id, "full_name": self.reporter.full_name}
                if self.reporter is not None else None
            ),
            "target_type": self.target_type.value,
            "target_id": self.target_id,
            "reason": self.reason.value,
            "note": self.note,
            "status": self.status.value,
            "resolution_note": self.resolution_note,
            "resolved_at": self.resolved_at.isoformat() if self.resolved_at else None,
            "resolved_by": self.resolved_by,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
