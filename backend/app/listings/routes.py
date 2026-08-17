"""Listing CRUD + photos + confirm.

Access rules:
- Create/update/delete: only verified brokers (owner for update/delete).
- Read: any authenticated user; expired listings are auto-hidden from
  the public list (they stay visible on the owning broker's "my listings"
  screen so they can reconfirm).
- Duplicate detection runs on every photo upload; the flag is stored on
  the listing so admins see it in the flagged queue.
"""
from __future__ import annotations

import mimetypes
import secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path

from flask import Blueprint, jsonify, request
from flask_jwt_extended import (
    get_jwt,
    get_jwt_identity,
    jwt_required,
    verify_jwt_in_request,
)

from ..auth.security import roles_required
from ..extensions import db
from ..models.broker_profile import VerificationStatus
from ..models.listing import DeliveryStatus, Listing, ListingKind, ListingStatus, PropertyType
from ..models.listing_photo import ListingPhoto
from ..models.user import User, UserRole
from ..ratings.aggregate import aggregate_for, aggregate_for_many
from ..security.content_validation import (
    ContentTypeError,
    image_kinds,
    read_and_validate,
)
from ..storage import get_storage
from .phash import compute_phash, find_near_duplicate, PhashError
from .schemas import ListingCreateSchema, ListingUpdateSchema

listings_bp = Blueprint("listings", __name__)

_create_schema = ListingCreateSchema()
_update_schema = ListingUpdateSchema()

_ALLOWED_PHOTO_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
_ALLOWED_PHOTO_MIMES = {"image/jpeg", "image/png", "image/webp"}

# Auto-expire window per Phase 3 spec.
LISTING_TTL = timedelta(days=30)


# ── helpers ────────────────────────────────────────────────────────────

def _current_user() -> User | None:
    ident = get_jwt_identity()
    if ident is None:
        return None
    return db.session.get(User, int(ident))


def _is_expired(listing: Listing, now: datetime | None = None) -> bool:
    if listing.status != ListingStatus.ACTIVE:
        return listing.status == ListingStatus.EXPIRED
    now = now or datetime.now(timezone.utc)
    lca = listing.last_confirmed_at
    if lca is None:
        # Fresh listings use created_at as the baseline.
        lca = listing.created_at
    if lca is None:
        return False
    # Ensure both sides are timezone-aware for the compare.
    if lca.tzinfo is None:
        lca = lca.replace(tzinfo=timezone.utc)
    return (now - lca) > LISTING_TTL


def _listing_public_dict(listing: Listing, include_broker: bool = True) -> dict:
    storage = get_storage()
    # Only ACTIVE listings have a meaningful expiry — a SOLD or HIDDEN
    # listing shouldn't render as "Expired" on the broker's UI weeks
    # after the fact.
    is_active = listing.status == ListingStatus.ACTIVE
    payload = {
        "id": listing.id,
        "title": listing.title,
        "description": listing.description,
        "price_egp": str(listing.price_egp) if listing.price_egp is not None else None,
        "area_m2": str(listing.area_m2) if listing.area_m2 is not None else None,
        "governorate": listing.governorate,
        "city": listing.city,
        "district": listing.district,
        "lat": listing.lat,
        "lng": listing.lng,
        "property_type": listing.property_type.value,
        "status": listing.status.value,
        "listing_kind": listing.listing_kind.value if listing.listing_kind else "sale",
        "bedrooms": listing.bedrooms,
        "bathrooms": listing.bathrooms,
        "floor_number": listing.floor_number,
        "is_furnished": listing.is_furnished,
        "compound_name": listing.compound_name,
        "delivery_status": (
            listing.delivery_status.value if listing.delivery_status else None
        ),
        "created_at": listing.created_at.isoformat() if listing.created_at else None,
        "last_confirmed_at": (
            listing.last_confirmed_at.isoformat()
            if listing.last_confirmed_at
            else None
        ),
        "expires_at": _expiry_iso(listing) if is_active else None,
        "is_expired": _is_expired(listing) if is_active else False,
        "photos": [
            p.to_public_dict(storage.url(p.storage_key)) for p in listing.photos
        ],
    }
    if include_broker and listing.broker is not None:
        b = listing.broker
        payload["broker"] = {
            "id": b.id,
            "full_name": b.full_name,
            "phone": b.phone,
            "verification_status": (
                b.broker_profile.verification_status.value
                if b.broker_profile is not None
                else "pending"
            ),
            "rating": aggregate_for(b.id),
        }
    return payload


def _expiry_iso(listing: Listing) -> str | None:
    lca = listing.last_confirmed_at or listing.created_at
    if lca is None:
        return None
    if lca.tzinfo is None:
        lca = lca.replace(tzinfo=timezone.utc)
    return (lca + LISTING_TTL).isoformat()


def _require_verified_broker(user: User | None):
    """Common gate for create/update/photo endpoints.

    Called on every write, not just create — a broker who was verified when
    they posted but later rejected/deactivated must not be able to keep
    editing, reconfirming, or adding photos.
    """
    if user is None or not user.is_active:
        return jsonify(error="Account not available."), 401
    if user.role != UserRole.BROKER:
        return jsonify(error="Only brokers can perform this action."), 403
    profile = user.broker_profile
    if profile is None or profile.verification_status != VerificationStatus.VERIFIED:
        return jsonify(
            error="Only verified brokers can perform this action. "
                  "Submit your registration document for verification first."
        ), 403
    return None


# ── endpoints ──────────────────────────────────────────────────────────

@listings_bp.get("")
@jwt_required()
def list_listings():
    """Public listing feed. Auto-hides expired listings AND listings whose
    broker is no longer verified/active — the whole verification flow
    exists to gate what buyers see, so this must enforce it."""
    from sqlalchemy import func
    from ..models.broker_profile import BrokerProfile

    now = datetime.now(timezone.utc)
    cutoff = now - LISTING_TTL

    q = (
        Listing.query
        .join(User, Listing.broker_id == User.id)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(Listing.status == ListingStatus.ACTIVE)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
    )

    # last_confirmed_at is nullable; use created_at as the baseline via COALESCE.
    baseline = func.coalesce(Listing.last_confirmed_at, Listing.created_at)
    q = q.filter(baseline > cutoff)

    q, err = apply_listing_filters(q, request.args)
    if err is not None:
        return err

    q = q.order_by(Listing.created_at.desc())
    return jsonify([_listing_public_dict(l) for l in q.all()]), 200


def apply_listing_filters(q, args):
    """Apply the standard listing-search filters based on request args.

    Shared by /listings (authenticated) and /api/public/listings + /browse
    (public). Returns (query, error_response) — error_response is None on
    success or a (jsonify, 400) tuple on invalid input.
    """
    gov = args.get("governorate")
    if gov:
        q = q.filter(Listing.governorate == gov)
    city = args.get("city")
    if city:
        q = q.filter(Listing.city == city)
    ptype = args.get("property_type")
    if ptype:
        try:
            q = q.filter(Listing.property_type == PropertyType(ptype))
        except ValueError:
            return q, (jsonify(error=f"Invalid property_type: {ptype}"), 400)

    # Sale vs rent — the single biggest filter Egyptian buyers apply.
    kind = args.get("kind") or args.get("listing_kind")
    if kind:
        try:
            q = q.filter(Listing.listing_kind == ListingKind(kind))
        except ValueError:
            return q, (jsonify(error=f"Invalid kind: {kind}"), 400)

    # Delivery status (ready vs under construction).
    delivery = args.get("delivery_status")
    if delivery:
        try:
            q = q.filter(Listing.delivery_status == DeliveryStatus(delivery))
        except ValueError:
            return q, (jsonify(error=f"Invalid delivery_status: {delivery}"), 400)

    # Bedrooms — min-threshold ("3+ bed").
    bmin_raw = args.get("bedrooms_min")
    if bmin_raw is not None and bmin_raw != "":
        try:
            bmin = int(bmin_raw)
        except ValueError:
            return q, (jsonify(error=f"Invalid bedrooms_min: {bmin_raw!r}"), 400)
        q = q.filter(Listing.bedrooms >= bmin)

    # Furnished — tri-state: absent = ignore, "true"/"false" = filter.
    furn_raw = args.get("furnished")
    if furn_raw is not None and furn_raw != "":
        low = furn_raw.strip().lower()
        if low in ("true", "1", "yes"):
            q = q.filter(Listing.is_furnished.is_(True))
        elif low in ("false", "0", "no"):
            q = q.filter(Listing.is_furnished.is_(False))
        else:
            return q, (jsonify(error=f"Invalid furnished: {furn_raw!r}"), 400)

    # Compound — exact match on the name a broker entered.
    compound = args.get("compound")
    if compound:
        q = q.filter(Listing.compound_name == compound)

    for arg_name, op in (("min_price", ">="), ("max_price", "<=")):
        raw = args.get(arg_name)
        if raw is None or raw == "":
            continue
        try:
            value = float(raw)
        except ValueError:
            return q, (jsonify(error=f"Invalid {arg_name}: {raw!r}"), 400)
        q = q.filter(
            Listing.price_egp >= value if op == ">=" else Listing.price_egp <= value
        )

    return q, None


@listings_bp.get("/mine")
@roles_required(UserRole.BROKER)
def my_listings():
    """A broker's own listings — includes expired so they can reconfirm."""
    user = _current_user()
    if user is None:
        return jsonify(error="User not found."), 404
    listings = (
        Listing.query.filter(Listing.broker_id == user.id)
        .order_by(Listing.created_at.desc())
        .all()
    )
    return jsonify([_listing_public_dict(l, include_broker=False) for l in listings]), 200


@listings_bp.get("/<int:listing_id>")
@jwt_required()
def get_listing(listing_id: int):
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    return jsonify(_listing_public_dict(listing)), 200


@listings_bp.post("")
def create_listing():
    # We do the JWT + role check manually so we can return a specific
    # 403 message when the broker isn't verified yet.
    verify_jwt_in_request()
    user = _current_user()
    err = _require_verified_broker(user)
    if err is not None:
        return err

    data = _create_schema.load(request.get_json(silent=True) or {})

    listing = Listing(
        broker_id=user.id,
        title=data["title"].strip(),
        description=(data.get("description") or None),
        price_egp=data["price_egp"],
        area_m2=data["area_m2"],
        governorate=data["governorate"].strip(),
        city=data["city"].strip(),
        district=(data.get("district") or None),
        lat=data["lat"],
        lng=data["lng"],
        property_type=PropertyType(data["property_type"]),
        status=ListingStatus.ACTIVE,
        last_confirmed_at=datetime.now(timezone.utc),
        # Phase A1 richer fields — all optional; schema defaults kind→sale
        listing_kind=ListingKind(data.get("listing_kind", "sale")),
        bedrooms=data.get("bedrooms"),
        bathrooms=data.get("bathrooms"),
        floor_number=data.get("floor_number"),
        is_furnished=data.get("is_furnished"),
        compound_name=(data.get("compound_name") or None),
        delivery_status=(
            DeliveryStatus(data["delivery_status"])
            if data.get("delivery_status") else None
        ),
    )
    db.session.add(listing)
    db.session.commit()

    return jsonify(_listing_public_dict(listing)), 201


@listings_bp.patch("/<int:listing_id>")
@jwt_required()
def update_listing(listing_id: int):
    user = _current_user()
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    if user is None or listing.broker_id != user.id:
        return jsonify(error="Forbidden."), 403
    err = _require_verified_broker(user)
    if err is not None:
        return err

    data = _update_schema.load(request.get_json(silent=True) or {})
    for key, value in data.items():
        if key == "property_type":
            setattr(listing, key, PropertyType(value))
        elif key == "status":
            setattr(listing, key, ListingStatus(value))
        elif key == "listing_kind" and value is not None:
            setattr(listing, key, ListingKind(value))
        elif key == "delivery_status":
            setattr(listing, key, DeliveryStatus(value) if value else None)
        else:
            setattr(listing, key, value)

    db.session.commit()
    return jsonify(_listing_public_dict(listing)), 200


@listings_bp.delete("/<int:listing_id>")
@jwt_required()
def delete_listing(listing_id: int):
    user = _current_user()
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    claims = get_jwt()
    is_admin = claims.get("role") == UserRole.ADMIN.value
    if user is None or (listing.broker_id != user.id and not is_admin):
        return jsonify(error="Forbidden."), 403

    # Clean up photos AND per-listing documents from storage — the DB
    # rows cascade but the files on disk wouldn't, and orphaned
    # listing-docs would still exist while files/routes.py has no listing
    # row to check ownership against (would 403 forever for admins too).
    storage = get_storage()
    for photo in listing.photos:
        storage.delete(photo.storage_key)
    for doc in listing.documents:
        if doc.storage_key is not None:
            storage.delete(doc.storage_key)

    db.session.delete(listing)
    db.session.commit()
    return "", 204


@listings_bp.post("/<int:listing_id>/confirm")
@jwt_required()
def confirm_listing(listing_id: int):
    """The 'still available' tap — resets the 30-day clock."""
    user = _current_user()
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    if user is None or listing.broker_id != user.id:
        return jsonify(error="Forbidden."), 403
    err = _require_verified_broker(user)
    if err is not None:
        return err

    listing.last_confirmed_at = datetime.now(timezone.utc)
    # Reactivate from ANY non-active status — broker who accidentally
    # marked a listing sold/hidden or let it auto-expire can bring it
    # back with one tap. Guarded by ownership above.
    if listing.status != ListingStatus.ACTIVE:
        listing.status = ListingStatus.ACTIVE
    db.session.commit()
    # Include broker so the mobile detail screen can keep rendering the
    # broker card after a confirm without needing to re-fetch.
    return jsonify(_listing_public_dict(listing)), 200


@listings_bp.post("/<int:listing_id>/photos")
@jwt_required()
def upload_photo(listing_id: int):
    user = _current_user()
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    if user is None or listing.broker_id != user.id:
        return jsonify(error="Forbidden."), 403
    err = _require_verified_broker(user)
    if err is not None:
        return err

    file = request.files.get("photo")
    if file is None or not file.filename:
        return jsonify(error="A photo file is required."), 400

    ext = Path(file.filename).suffix.lower()
    if ext not in _ALLOWED_PHOTO_EXTS:
        return jsonify(
            error=f"Unsupported file type. Allowed: {sorted(_ALLOWED_PHOTO_EXTS)}"
        ), 400
    mime = file.mimetype or mimetypes.guess_type(file.filename)[0] or ""
    if mime and mime not in _ALLOWED_PHOTO_MIMES:
        return jsonify(error=f"Unsupported content type: {mime}"), 400

    # Read + magic-byte validate + hash in one flow. `image_kinds` here
    # (photos are images only; no PDFs) matches the extension allowlist.
    try:
        photo_bytes = read_and_validate(file.stream, allowed=image_kinds)
    except ContentTypeError as exc:
        return jsonify(error=str(exc)), 400

    try:
        phash = compute_phash(photo_bytes)
    except PhashError as exc:
        return jsonify(error=str(exc)), 400

    # Duplicate scan: any existing photo on a DIFFERENT listing.
    existing = (
        db.session.query(ListingPhoto.listing_id, ListingPhoto.phash)
        .filter(ListingPhoto.listing_id != listing.id)
        .all()
    )
    dup_of = find_near_duplicate(phash, existing)

    storage = get_storage()
    key = f"listing-photos/{listing.id}/{secrets.token_hex(16)}{ext}"
    from io import BytesIO
    storage.put(key, BytesIO(photo_bytes), content_type=mime or None)

    sort_order = (
        db.session.query(db.func.coalesce(db.func.max(ListingPhoto.sort_order), -1))
        .filter(ListingPhoto.listing_id == listing.id)
        .scalar()
    )
    photo = ListingPhoto(
        listing_id=listing.id,
        storage_key=key,
        phash=phash,
        sort_order=(sort_order + 1),
    )
    db.session.add(photo)

    if dup_of is not None and not listing.duplicate_suspected:
        listing.duplicate_suspected = True
        listing.duplicate_of_listing_id = dup_of

    db.session.commit()

    return jsonify(photo.to_public_dict(storage.url(key))), 201


@listings_bp.delete("/<int:listing_id>/photos/<int:photo_id>")
@jwt_required()
def delete_photo(listing_id: int, photo_id: int):
    user = _current_user()
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    if user is None or listing.broker_id != user.id:
        return jsonify(error="Forbidden."), 403
    err = _require_verified_broker(user)
    if err is not None:
        return err

    photo = ListingPhoto.query.filter_by(
        id=photo_id, listing_id=listing.id
    ).first()
    if photo is None:
        return jsonify(error="Photo not found."), 404

    # Commit the DB delete first; only remove the file after. Reversing
    # would drop the file irrecoverably on any DB error.
    key = photo.storage_key
    db.session.delete(photo)
    db.session.commit()
    get_storage().delete(key)
    return "", 204
