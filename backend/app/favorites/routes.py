"""Favorites: save a listing, unsave it, list what you saved.

Visibility rule: the Saved tab runs through the same gate as the browse
feed (`visible_listings_query`). A listing whose broker lost verification
— or that fell off the 30-day confirm cliff — disappears from Saved just
like it disappears from browse. The row survives, so if the broker
re-confirms, the save comes back rather than being silently destroyed.
"""
from __future__ import annotations

from flask import Blueprint, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..extensions import db
from ..models.favorite import Favorite
from ..models.listing import Listing
from ..listings.routes import _listing_public_dict, visible_listings_query

favorites_bp = Blueprint("favorites", __name__)


def _user_id() -> int:
    return int(get_jwt_identity())


@favorites_bp.get("")
@jwt_required()
def list_favorites():
    """The buyer's saved listings, newest save first."""
    uid = _user_id()
    rows = (
        visible_listings_query()
        .join(Favorite, Favorite.listing_id == Listing.id)
        .filter(Favorite.user_id == uid)
        .order_by(Favorite.created_at.desc())
        .all()
    )
    return jsonify([_listing_public_dict(l) for l in rows]), 200


@favorites_bp.get("/ids")
@jwt_required()
def favorite_ids():
    """Just the ids — the browse feed calls this once to know which
    hearts to fill, instead of hydrating every saved listing."""
    uid = _user_id()
    ids = [
        row.listing_id
        for row in Favorite.query.filter(Favorite.user_id == uid).all()
    ]
    return jsonify({"listing_ids": ids}), 200


@favorites_bp.post("/<int:listing_id>")
@jwt_required()
def add_favorite(listing_id: int):
    """Idempotent — 201 on a fresh save, 200 if it was already saved.
    A double-tapping client should never see an error."""
    uid = _user_id()
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404

    existing = Favorite.query.filter_by(user_id=uid, listing_id=listing_id).first()
    if existing is not None:
        return jsonify(favorited=True, listing_id=listing_id), 200

    db.session.add(Favorite(user_id=uid, listing_id=listing_id))
    try:
        db.session.commit()
    except Exception:
        # Lost the race against a concurrent save of the same listing;
        # the unique constraint held, and the user's intent is satisfied.
        db.session.rollback()
        if Favorite.query.filter_by(user_id=uid, listing_id=listing_id).first() is None:
            raise
        return jsonify(favorited=True, listing_id=listing_id), 200

    return jsonify(favorited=True, listing_id=listing_id), 201


@favorites_bp.delete("/<int:listing_id>")
@jwt_required()
def remove_favorite(listing_id: int):
    """Idempotent — 204 whether or not the row was there."""
    uid = _user_id()
    Favorite.query.filter_by(user_id=uid, listing_id=listing_id).delete()
    db.session.commit()
    return "", 204
