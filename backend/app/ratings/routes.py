"""Buyer→broker ratings. Upsert on `(rater, broker)`. Public list.

Rating gate: to POST, the caller must have at least one MessageThread
where `buyer_id=me AND broker_id=<broker>`. No drive-by ratings.

Rate-limited: 3/hour/user (env `RATELIMIT_RATINGS`).
"""
from __future__ import annotations

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..extensions import db, limiter
from ..models.broker_rating import BrokerRating
from ..models.message_thread import MessageThread
from ..models.user import User, UserRole
from .aggregate import aggregate_for
from .schemas import SubmitRatingSchema

ratings_bp = Blueprint("ratings", __name__)

_submit_schema = SubmitRatingSchema()


def _current_user() -> User | None:
    ident = get_jwt_identity()
    if ident is None:
        return None
    return db.session.get(User, int(ident))


def _load_broker_or_404(broker_id: int):
    """Broker must be a broker and active. Anyone (buyer, admin, another
    broker) can *read* the ratings list."""
    broker = db.session.get(User, broker_id)
    if broker is None or broker.role != UserRole.BROKER or not broker.is_active:
        return None, (jsonify(error="Broker not found."), 404)
    return broker, None


@ratings_bp.get("/<int:broker_id>/ratings")
@jwt_required()
def list_ratings(broker_id: int):
    broker, err = _load_broker_or_404(broker_id)
    if err is not None:
        return err

    ratings = (
        BrokerRating.query
        .filter(BrokerRating.broker_user_id == broker.id)
        .order_by(BrokerRating.id.desc())
        .limit(20)
        .all()
    )
    return jsonify(
        {
            "aggregate": aggregate_for(broker.id),
            "reviews": [r.to_public_dict() for r in ratings],
        }
    ), 200


@ratings_bp.post("/<int:broker_id>/ratings")
@limiter.limit(lambda: current_app.config.get("RATELIMIT_RATINGS", "3 per hour"))
@jwt_required()
def submit_rating(broker_id: int):
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401

    broker, err = _load_broker_or_404(broker_id)
    if err is not None:
        return err

    if user.id == broker.id:
        return jsonify(error="You cannot rate yourself."), 400
    if user.role != UserRole.BUYER:
        return jsonify(error="Only buyers can rate brokers."), 403

    # Gate: must have a thread with this broker.
    thread = (
        MessageThread.query
        .filter_by(buyer_id=user.id, broker_id=broker.id)
        .first()
    )
    if thread is None:
        return jsonify(
            error="You can only rate a broker you've messaged."
        ), 403

    data = _submit_schema.load(request.get_json(silent=True) or {})

    existing = (
        BrokerRating.query
        .filter_by(rater_user_id=user.id, broker_user_id=broker.id)
        .first()
    )
    if existing is not None:
        existing.stars = data["stars"]
        existing.note = (data.get("note") or None)
        existing.thread_id = thread.id
        db.session.commit()
        return jsonify(existing.to_public_dict()), 200

    rating = BrokerRating(
        rater_user_id=user.id,
        broker_user_id=broker.id,
        thread_id=thread.id,
        stars=data["stars"],
        note=(data.get("note") or None),
    )
    db.session.add(rating)
    db.session.commit()
    return jsonify(rating.to_public_dict()), 201


@ratings_bp.delete("/<int:broker_id>/ratings/mine")
@jwt_required()
def delete_my_rating(broker_id: int):
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401

    rating = (
        BrokerRating.query
        .filter_by(rater_user_id=user.id, broker_user_id=broker_id)
        .first()
    )
    if rating is None:
        return "", 204   # idempotent
    db.session.delete(rating)
    db.session.commit()
    return "", 204


@ratings_bp.get("/<int:broker_id>/ratings/mine")
@jwt_required()
def get_my_rating(broker_id: int):
    """Returns the caller's own rating for this broker, if any. The
    mobile client uses this to decide whether to show the 'Rate broker'
    prompt in the thread screen."""
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401
    rating = (
        BrokerRating.query
        .filter_by(rater_user_id=user.id, broker_user_id=broker_id)
        .first()
    )
    if rating is None:
        return jsonify(None), 200
    return jsonify(rating.to_public_dict()), 200
