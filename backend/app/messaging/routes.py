"""In-app messaging between a buyer and a broker about a listing.

- One thread per (buyer, broker, listing). Re-creating returns the
  existing thread — no accidental duplicates from double-taps.
- Broker must be currently verified to *send*. Buyers can send anytime.
- Delta polling: `GET .../messages?since=<id>` returns messages with
  `id > since`, and marks those addressed to the caller as read.
- Rate-limited: 30 messages per minute per authed user.
"""
from __future__ import annotations

from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from marshmallow import Schema, fields, validate
from sqlalchemy.exc import IntegrityError

from ..auth.security import roles_required  # noqa: F401 — kept for consistency
from ..extensions import db, limiter
from ..models.broker_profile import BrokerProfile, VerificationStatus
from ..models.listing import Listing
from ..models.message import Message
from ..models.message_thread import MessageThread
from ..models.user import User, UserRole
from ..notifications import fcm

messaging_bp = Blueprint("messaging", __name__)


# ── schemas ────────────────────────────────────────────────────────────

class CreateThreadSchema(Schema):
    listing_id = fields.Integer(required=True, validate=validate.Range(min=1))


class SendMessageSchema(Schema):
    body = fields.String(required=True, validate=validate.Length(min=1, max=2000))


_create_schema = CreateThreadSchema()
_send_schema = SendMessageSchema()


# ── helpers ────────────────────────────────────────────────────────────

def _current_user() -> User | None:
    ident = get_jwt_identity()
    if ident is None:
        return None
    return db.session.get(User, int(ident))


def _load_thread_for(user: User, thread_id: int):
    """Return (thread, error_response). Only participants can access."""
    thread = db.session.get(MessageThread, thread_id)
    if thread is None:
        return None, (jsonify(error="Thread not found."), 404)
    if user.id not in (thread.buyer_id, thread.broker_id):
        return None, (jsonify(error="Forbidden."), 403)
    return thread, None


def _thread_summary(thread: MessageThread, viewer_id: int) -> dict:
    """Inbox row. Includes counterparty info, last-message preview, and
    the viewer's unread count for the thread."""
    other = thread.counterparty_for(viewer_id)
    unread = (
        db.session.query(Message)
        .filter(Message.thread_id == thread.id)
        .filter(Message.sender_id != viewer_id)
        .filter(Message.read_at.is_(None))
        .count()
    )
    last = (
        db.session.query(Message)
        .filter(Message.thread_id == thread.id)
        .order_by(Message.id.desc())
        .first()
    )
    return {
        "id": thread.id,
        "listing_id": thread.listing_id,
        "listing_title": thread.listing.title if thread.listing is not None else None,
        "counterparty": None if other is None else {
            "id": other.id,
            "full_name": other.full_name,
            "role": other.role.value,
            "verification_status": (
                other.broker_profile.verification_status.value
                if other.role == UserRole.BROKER and other.broker_profile is not None
                else None
            ),
        },
        "unread_count": unread,
        "last_message": last.body if last is not None else None,
        "last_message_at": (
            thread.last_message_at.isoformat() if thread.last_message_at else None
        ),
        "created_at": thread.created_at.isoformat() if thread.created_at else None,
    }


# ── endpoints ──────────────────────────────────────────────────────────

@messaging_bp.post("")
@jwt_required()
def create_thread():
    """Idempotent — same (buyer, broker, listing) always returns the
    same thread. Only buyers can initiate."""
    data = _create_schema.load(request.get_json(silent=True) or {})
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401
    if user.role != UserRole.BUYER:
        return jsonify(error="Only buyers can start conversations."), 403

    listing = db.session.get(Listing, data["listing_id"])
    if listing is None:
        return jsonify(error="Listing not found."), 404

    # Broker must currently be verified & active to receive messages —
    # otherwise a buyer could start threads with revoked accounts.
    broker = db.session.get(User, listing.broker_id)
    if broker is None or not broker.is_active:
        return jsonify(error="Broker not available."), 404
    if (
        broker.broker_profile is None
        or broker.broker_profile.verification_status != VerificationStatus.VERIFIED
    ):
        return jsonify(error="Broker not currently verified."), 403

    existing = (
        db.session.query(MessageThread)
        .filter_by(buyer_id=user.id, broker_id=broker.id, listing_id=listing.id)
        .first()
    )
    if existing is not None:
        return jsonify(_thread_summary(existing, user.id)), 200

    thread = MessageThread(
        buyer_id=user.id,
        broker_id=broker.id,
        listing_id=listing.id,
    )
    db.session.add(thread)
    try:
        db.session.commit()
    except IntegrityError:
        # Double-tap race: another request just inserted the same
        # (buyer, broker, listing). Fetch and return that one — no
        # scary "Conflict" for the user, thread is thread.
        db.session.rollback()
        winner = (
            db.session.query(MessageThread)
            .filter_by(buyer_id=user.id, broker_id=broker.id, listing_id=listing.id)
            .first()
        )
        if winner is None:
            raise
        return jsonify(_thread_summary(winner, user.id)), 200
    return jsonify(_thread_summary(thread, user.id)), 201


@messaging_bp.get("")
@jwt_required()
def list_threads():
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401

    threads = (
        db.session.query(MessageThread)
        .filter(
            (MessageThread.buyer_id == user.id)
            | (MessageThread.broker_id == user.id)
        )
        .order_by(MessageThread.last_message_at.desc().nullslast(), MessageThread.id.desc())
        .all()
    )
    return jsonify([_thread_summary(t, user.id) for t in threads]), 200


@messaging_bp.get("/<int:thread_id>")
@jwt_required()
def get_thread(thread_id: int):
    """Single thread summary — needed by the mobile client when a user
    deep-links directly to a thread (share link, notification) without
    having loaded the inbox first."""
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401
    thread, err = _load_thread_for(user, thread_id)
    if err is not None:
        return err
    return jsonify(_thread_summary(thread, user.id)), 200


@messaging_bp.get("/<int:thread_id>/messages")
@jwt_required()
def get_messages(thread_id: int):
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401
    thread, err = _load_thread_for(user, thread_id)
    if err is not None:
        return err

    since_raw = request.args.get("since")
    q = db.session.query(Message).filter(Message.thread_id == thread.id)
    if since_raw:
        try:
            since = int(since_raw)
        except ValueError:
            return jsonify(error="`since` must be an integer message id."), 400
        q = q.filter(Message.id > since)
    else:
        # No cursor → return the tail so a fresh open doesn't scroll to
        # ancient history. Client can paginate backwards later if needed.
        q = q.order_by(Message.id.desc()).limit(50)
        rows = list(reversed(q.all()))
        _mark_as_read_for_recipient(rows, user)
        return jsonify([m.to_public_dict() for m in rows]), 200

    rows = q.order_by(Message.id.asc()).all()
    _mark_as_read_for_recipient(rows, user)
    return jsonify([m.to_public_dict() for m in rows]), 200


def _mark_as_read_for_recipient(msgs: list[Message], viewer: User) -> None:
    """Set read_at on messages the viewer just fetched — but only ones
    they didn't send themselves. Called from GET so any successful poll
    doubles as an implicit read receipt."""
    now = datetime.now(timezone.utc)
    changed = False
    for m in msgs:
        if m.sender_id != viewer.id and m.read_at is None:
            m.read_at = now
            changed = True
    if changed:
        db.session.commit()


@messaging_bp.post("/<int:thread_id>/messages")
@limiter.limit(lambda: current_app.config.get("RATELIMIT_MESSAGES", "30 per minute"))
@jwt_required()
def send_message(thread_id: int):
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401
    thread, err = _load_thread_for(user, thread_id)
    if err is not None:
        return err

    data = _send_schema.load(request.get_json(silent=True) or {})

    # Sender-side gate: brokers must currently be verified. Buyers always OK.
    if user.role == UserRole.BROKER:
        profile = user.broker_profile
        if profile is None or profile.verification_status != VerificationStatus.VERIFIED:
            return jsonify(
                error="Only verified brokers can send messages."
            ), 403

    msg = Message(
        thread_id=thread.id,
        sender_id=user.id,
        body=data["body"].strip(),
    )
    db.session.add(msg)
    thread.last_message_at = datetime.now(timezone.utc)
    db.session.commit()

    # Notify the counterparty. Silent no-op when FCM isn't configured.
    counterparty_id = (
        thread.broker_id if user.id == thread.buyer_id else thread.buyer_id
    )
    preview = (msg.body or "")[:80]
    fcm.send_push_to_user(
        counterparty_id,
        title=user.full_name or "New message",
        body=preview,
        data={"route": f"/messages/{thread.id}", "type": "message"},
    )
    return jsonify(msg.to_public_dict()), 201


@messaging_bp.post("/<int:thread_id>/read")
@jwt_required()
def mark_read(thread_id: int):
    """Explicit read — flips read_at on every message in the thread not
    sent by the caller. GET already does this implicitly; this endpoint
    is for the case where the client wants to zero out the inbox badge
    without loading the full message list."""
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401
    thread, err = _load_thread_for(user, thread_id)
    if err is not None:
        return err

    now = datetime.now(timezone.utc)
    (
        db.session.query(Message)
        .filter(Message.thread_id == thread.id)
        .filter(Message.sender_id != user.id)
        .filter(Message.read_at.is_(None))
        .update({Message.read_at: now}, synchronize_session=False)
    )
    db.session.commit()
    return "", 204
