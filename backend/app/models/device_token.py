"""Push-notification registration token — one row per (user, device).

Populated by the mobile client after a successful login (Flutter posts
to /devices with the FCM registration token) and cleaned out on logout
or when the FCM server tells us the token is dead."""
from __future__ import annotations

import enum

from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)

from ..extensions import db


_PkType = BigInteger().with_variant(Integer, "sqlite")


class DevicePlatform(str, enum.Enum):
    ANDROID = "android"
    IOS = "ios"
    WEB = "web"


class DeviceToken(db.Model):
    __tablename__ = "device_tokens"

    id = Column(_PkType, primary_key=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # FCM registration tokens are ~163 chars; give plenty of headroom.
    token = Column(String(4096), nullable=False)
    platform = Column(
        SAEnum(
            DevicePlatform,
            name="device_platform",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )

    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_seen_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        # Same token twice for the same user is a no-op re-registration.
        UniqueConstraint("user_id", "token", name="uq_device_tokens_user_token"),
    )
