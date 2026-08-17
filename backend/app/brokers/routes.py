"""Broker-facing routes: submit verification, check own status, public
profile, and (Phase G2) my-analytics."""
from __future__ import annotations

import mimetypes
import secrets
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func

from ..auth.security import roles_required
from ..extensions import db
from ..models.broker_profile import VerificationStatus
from ..models.listing import Listing, ListingStatus
from ..models.listing_view import ListingViewDay
from ..models.message import Message
from ..models.message_thread import MessageThread
from ..models.user import User, UserRole
from ..ratings.aggregate import aggregate_for
from ..security.content_validation import (
    ContentTypeError,
    document_kinds,
    read_and_validate,
)
from ..storage import get_storage
from .schemas import VerificationSubmitSchema

brokers_bp = Blueprint("brokers", __name__)

_submit_schema = VerificationSubmitSchema()

# Only these types are accepted as proof documents.
_ALLOWED_DOC_MIMETYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
}
_ALLOWED_DOC_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png", ".webp"}


def _current_user() -> User | None:
    ident = get_jwt_identity()
    if ident is None:
        return None
    return db.session.get(User, int(ident))


@brokers_bp.post("/me/verification")
@roles_required(UserRole.BROKER)
def submit_verification():
    """Broker uploads a registration doc and GOEIC number. Overwrites any
    prior submission and resets status to pending for re-review."""
    user = _current_user()
    if user is None or user.broker_profile is None:
        return jsonify(error="Broker profile not found."), 404

    # Marshmallow validates the form field (multipart form-data).
    data = _submit_schema.load(request.form.to_dict())

    file = request.files.get("document")
    if file is None or not file.filename:
        return jsonify(error="A registration document file is required."), 400

    ext = Path(file.filename).suffix.lower()
    if ext not in _ALLOWED_DOC_EXTENSIONS:
        return jsonify(
            error=f"Unsupported file type. Allowed: {sorted(_ALLOWED_DOC_EXTENSIONS)}"
        ), 400

    # Prefer the declared mimetype but fall back to extension-based guess.
    mimetype = file.mimetype or mimetypes.guess_type(file.filename)[0] or ""
    if mimetype and mimetype not in _ALLOWED_DOC_MIMETYPES:
        return jsonify(error=f"Unsupported content type: {mimetype}"), 400

    # Magic-byte check — extension + declared MIME are trivially forgeable.
    try:
        doc_bytes = read_and_validate(file.stream, allowed=document_kinds)
    except ContentTypeError as exc:
        return jsonify(error=str(exc)), 400

    storage = get_storage()

    # Write NEW file first, then commit, then delete OLD. If put or
    # commit fails, the broker still has their previous proof intact.
    from io import BytesIO
    old_key = user.broker_profile.registration_document_path
    new_key = f"broker-docs/{user.id}/{secrets.token_hex(16)}{ext}"
    storage.put(new_key, BytesIO(doc_bytes), content_type=mimetype or None)

    profile = user.broker_profile
    profile.goeic_registration_number = data["goeic_registration_number"].strip()
    profile.registration_document_path = new_key
    profile.verification_status = VerificationStatus.PENDING
    profile.rejection_reason = None
    profile.verified_at = None
    profile.verified_by = None
    # PDPL audit trail — capture which version of the consent text
    # the broker just implicitly agreed to by submitting the doc.
    from flask import current_app
    profile.consent_version = current_app.config.get(
        "PDPL_CONSENT_VERSION", "1.0"
    )

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        storage.delete(new_key)
        raise

    if old_key:
        storage.delete(old_key)

    return jsonify(profile.to_public_dict()), 200


@brokers_bp.get("/me/verification")
@roles_required(UserRole.BROKER)
def my_verification():
    user = _current_user()
    if user is None or user.broker_profile is None:
        return jsonify(error="Broker profile not found."), 404
    return jsonify(user.broker_profile.to_public_dict()), 200


@brokers_bp.get("/<int:broker_id>")
@jwt_required()
def public_broker_profile(broker_id: int):
    """Buyers hit this before contacting a broker. We deliberately expose
    only what a buyer needs to make a trust decision — no document paths,
    no rejection reasons."""
    user = db.session.get(User, broker_id)
    if user is None or user.role != UserRole.BROKER or not user.is_active:
        return jsonify(error="Broker not found."), 404

    profile = user.broker_profile
    return jsonify(
        {
            "id": user.id,
            "full_name": user.full_name,
            "phone": user.phone,
            "verification_status": (
                profile.verification_status.value
                if profile is not None
                else VerificationStatus.PENDING.value
            ),
            "verified_at": (
                profile.verified_at.isoformat()
                if profile is not None and profile.verified_at is not None
                else None
            ),
            "rating": aggregate_for(user.id),
        }
    ), 200


# ── Phase G2: broker analytics ─────────────────────────────────────────

@brokers_bp.get("/me/analytics")
@roles_required(UserRole.BROKER)
def my_analytics():
    """Views + messages + rating summary for the current broker.

    Every field is over the calendar window the field name implies
    (7-day = today back through 6 days ago, inclusive; 30-day
    similarly). Zero-filled series for missing days so the chart draws
    a smooth line without gaps.
    """
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401

    today = date.today()
    day_7d_start = today - timedelta(days=6)   # 7 days inclusive
    day_30d_start = today - timedelta(days=29)  # 30 days inclusive
    now = datetime.now(timezone.utc)
    ts_7d_start = now - timedelta(days=7)

    # All of my listings — used for both filters below.
    my_listing_ids = [
        lid for (lid,) in db.session.query(Listing.id)
        .filter(Listing.broker_id == user.id)
        .all()
    ]

    # 7d / 30d view sums via SUM aggregate on ListingViewDay.
    def _sum_views_since(day_start: date) -> int:
        if not my_listing_ids:
            return 0
        total = (
            db.session.query(func.coalesce(func.sum(ListingViewDay.count), 0))
            .filter(ListingViewDay.listing_id.in_(my_listing_ids))
            .filter(ListingViewDay.day >= day_start)
            .scalar()
        )
        return int(total or 0)

    views_7d = _sum_views_since(day_7d_start)
    views_30d = _sum_views_since(day_30d_start)

    # Lifetime total from the counter column.
    total_views = int(
        db.session.query(func.coalesce(func.sum(Listing.total_views), 0))
        .filter(Listing.broker_id == user.id)
        .scalar() or 0
    )

    # Messages received (inbound to broker) in the last 7d.
    messages_7d = (
        db.session.query(func.count(Message.id))
        .join(MessageThread, Message.thread_id == MessageThread.id)
        .filter(MessageThread.broker_id == user.id)
        .filter(Message.sender_id != user.id)
        .filter(Message.created_at >= ts_7d_start)
        .scalar()
    ) or 0

    # Active listing count.
    active = (
        db.session.query(func.count(Listing.id))
        .filter(Listing.broker_id == user.id)
        .filter(Listing.status == ListingStatus.ACTIVE)
        .scalar()
    ) or 0

    # Rating aggregate.
    rating = aggregate_for(user.id)

    # 30-day daily series, zero-filled for missing days.
    daily_rows = {}
    if my_listing_ids:
        for view_day, count in (
            db.session.query(ListingViewDay.day, func.sum(ListingViewDay.count))
            .filter(ListingViewDay.listing_id.in_(my_listing_ids))
            .filter(ListingViewDay.day >= day_30d_start)
            .group_by(ListingViewDay.day)
            .all()
        ):
            daily_rows[view_day] = int(count or 0)
    views_daily = []
    for offset in range(30):
        d = day_30d_start + timedelta(days=offset)
        views_daily.append({"day": d.isoformat(), "count": daily_rows.get(d, 0)})

    # Per-listing breakdown — sorted by views_last_7d desc.
    by_listing = []
    for l in (
        db.session.query(Listing)
        .filter(Listing.broker_id == user.id)
        .filter(Listing.status == ListingStatus.ACTIVE)
        .all()
    ):
        listing_7d = int(
            db.session.query(func.coalesce(func.sum(ListingViewDay.count), 0))
            .filter(ListingViewDay.listing_id == l.id)
            .filter(ListingViewDay.day >= day_7d_start)
            .scalar() or 0
        )
        listing_30d = int(
            db.session.query(func.coalesce(func.sum(ListingViewDay.count), 0))
            .filter(ListingViewDay.listing_id == l.id)
            .filter(ListingViewDay.day >= day_30d_start)
            .scalar() or 0
        )
        listing_msg_7d = (
            db.session.query(func.count(Message.id))
            .join(MessageThread, Message.thread_id == MessageThread.id)
            .filter(MessageThread.listing_id == l.id)
            .filter(Message.sender_id != user.id)
            .filter(Message.created_at >= ts_7d_start)
            .scalar()
        ) or 0
        by_listing.append({
            "id": l.id,
            "title": l.title,
            "views_last_7d": listing_7d,
            "views_last_30d": listing_30d,
            "messages_last_7d": int(listing_msg_7d),
            "total_views": int(l.total_views or 0),
        })
    by_listing.sort(key=lambda x: x["views_last_7d"], reverse=True)

    return jsonify({
        "summary": {
            "views_last_7d": views_7d,
            "views_last_30d": views_30d,
            "messages_last_7d": int(messages_7d),
            "active_listings": int(active),
            "avg_rating": rating.get("avg", 0.0),
            "reviews_count": rating.get("count", 0),
            "total_views": total_views,
        },
        "views_daily": views_daily,
        "by_listing": by_listing,
    }), 200
