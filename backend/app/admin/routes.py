"""Admin-only routes for the broker verification queue."""
from __future__ import annotations

from datetime import datetime, timezone

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity

from ..auth.security import roles_required
from ..brokers.schemas import RejectSchema
from ..extensions import db
from ..models.broker_profile import BrokerProfile, VerificationStatus
from ..models.listing import Listing
from ..models.listing_document import DocumentState, ListingDocument
from ..models.user import User, UserRole
from ..notifications import fcm
from ..storage import get_storage

admin_bp = Blueprint("admin", __name__)

_reject_schema = RejectSchema()


def _profile_admin_view(profile: BrokerProfile) -> dict:
    """Full view for admin eyes — includes doc URL and rejection reason."""
    storage = get_storage()
    doc_url = (
        storage.url(profile.registration_document_path)
        if profile.registration_document_path
        else None
    )
    return {
        "id": profile.id,
        "user": profile.user.to_public_dict(),
        "goeic_registration_number": profile.goeic_registration_number,
        "document_url": doc_url,
        "verification_status": profile.verification_status.value,
        "verified_at": (
            profile.verified_at.isoformat() if profile.verified_at else None
        ),
        "verified_by": profile.verified_by,
        "rejection_reason": profile.rejection_reason,
        "created_at": profile.created_at.isoformat() if profile.created_at else None,
        "updated_at": profile.updated_at.isoformat() if profile.updated_at else None,
    }


@admin_bp.get("/brokers")
@roles_required(UserRole.ADMIN)
def list_brokers():
    """List broker profiles, optionally filtered by status. Default is
    `pending` since that's the admin's main queue."""
    status_str = request.args.get("status", "pending").lower()
    try:
        status = VerificationStatus(status_str)
    except ValueError:
        return jsonify(
            error=f"Invalid status. Allowed: {[s.value for s in VerificationStatus]}"
        ), 400

    q = (
        BrokerProfile.query
        .filter(BrokerProfile.verification_status == status)
        .order_by(BrokerProfile.updated_at.desc())
    )
    return jsonify([_profile_admin_view(p) for p in q.all()]), 200


@admin_bp.get("/brokers/<int:broker_user_id>")
@roles_required(UserRole.ADMIN)
def broker_detail(broker_user_id: int):
    """`broker_user_id` is the users.id of the broker, matching how the
    Flutter admin UI navigates from the pending list."""
    profile = BrokerProfile.query.filter_by(user_id=broker_user_id).first()
    if profile is None:
        return jsonify(error="Broker profile not found."), 404
    return jsonify(_profile_admin_view(profile)), 200


@admin_bp.post("/brokers/<int:broker_user_id>/approve")
@roles_required(UserRole.ADMIN)
def approve_broker(broker_user_id: int):
    profile = BrokerProfile.query.filter_by(user_id=broker_user_id).first()
    if profile is None:
        return jsonify(error="Broker profile not found."), 404
    if profile.registration_document_path is None:
        return jsonify(
            error="Broker has not submitted a registration document yet."
        ), 409
    # Only PENDING profiles may be approved. Re-approving verified/
    # rejected silently rewrites the audit trail — same guard the
    # document endpoints already have.
    if profile.verification_status != VerificationStatus.PENDING:
        return jsonify(
            error=f"Cannot approve a broker in state "
                  f"{profile.verification_status.value!r}. "
                  f"Only 'pending' brokers can be approved."
        ), 409

    profile.verification_status = VerificationStatus.VERIFIED
    profile.verified_at = datetime.now(timezone.utc)
    profile.verified_by = int(get_jwt_identity())
    profile.rejection_reason = None
    db.session.commit()

    fcm.send_push_to_user(
        broker_user_id,
        title="Verification approved",
        body="Your broker registration has been verified. You can post listings now.",
        data={"route": "/broker/verify", "type": "broker_verified"},
    )
    return jsonify(_profile_admin_view(profile)), 200


@admin_bp.post("/brokers/<int:broker_user_id>/reject")
@roles_required(UserRole.ADMIN)
def reject_broker(broker_user_id: int):
    data = _reject_schema.load(request.get_json(silent=True) or {})

    profile = BrokerProfile.query.filter_by(user_id=broker_user_id).first()
    if profile is None:
        return jsonify(error="Broker profile not found."), 404
    if profile.verification_status != VerificationStatus.PENDING:
        return jsonify(
            error=f"Cannot reject a broker in state "
                  f"{profile.verification_status.value!r}. "
                  f"Only 'pending' brokers can be rejected."
        ), 409

    profile.verification_status = VerificationStatus.REJECTED
    profile.rejection_reason = data["reason"].strip()
    profile.verified_at = None
    profile.verified_by = int(get_jwt_identity())  # who took the decision
    db.session.commit()

    fcm.send_push_to_user(
        broker_user_id,
        title="Verification rejected",
        body=(profile.rejection_reason or "See admin notes in the app.")[:120],
        data={"route": "/broker/verify", "type": "broker_rejected"},
    )
    return jsonify(_profile_admin_view(profile)), 200


# ── Phase 3: flagged listings queue ────────────────────────────────────

def _listing_admin_view(listing: Listing) -> dict:
    """Compact listing view for the flagged queue."""
    storage = get_storage()
    return {
        "id": listing.id,
        "title": listing.title,
        "price_egp": str(listing.price_egp) if listing.price_egp is not None else None,
        "governorate": listing.governorate,
        "city": listing.city,
        "duplicate_suspected": listing.duplicate_suspected,
        "duplicate_of_listing_id": listing.duplicate_of_listing_id,
        "photos": [
            p.to_public_dict(storage.url(p.storage_key)) for p in listing.photos
        ],
        "broker": {
            "id": listing.broker.id,
            "full_name": listing.broker.full_name,
            "phone": listing.broker.phone,
        } if listing.broker is not None else None,
        "created_at": listing.created_at.isoformat() if listing.created_at else None,
    }


@admin_bp.get("/listings/flagged")
@roles_required(UserRole.ADMIN)
def list_flagged_listings():
    q = (
        Listing.query.filter(Listing.duplicate_suspected.is_(True))
        .order_by(Listing.created_at.desc())
    )
    return jsonify([_listing_admin_view(l) for l in q.all()]), 200


@admin_bp.post("/listings/<int:listing_id>/unflag")
@roles_required(UserRole.ADMIN)
def unflag_listing(listing_id: int):
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return jsonify(error="Listing not found."), 404
    listing.duplicate_suspected = False
    listing.duplicate_of_listing_id = None
    db.session.commit()
    return jsonify(_listing_admin_view(listing)), 200


# ── Phase 4: per-listing document review queue ─────────────────────────

def _document_admin_view(doc: ListingDocument) -> dict:
    listing = doc.listing
    storage = get_storage()
    return {
        "id": doc.id,
        "listing_id": listing.id,
        "listing_title": listing.title,
        "kind": doc.kind.value,
        "state": doc.state.value,
        "document_url": (
            storage.url(doc.storage_key) if doc.storage_key is not None else None
        ),
        "rejection_reason": doc.rejection_reason,
        "verified_at": doc.verified_at.isoformat() if doc.verified_at else None,
        "created_at": doc.created_at.isoformat() if doc.created_at else None,
        "updated_at": doc.updated_at.isoformat() if doc.updated_at else None,
        "broker": {
            "id": listing.broker.id,
            "full_name": listing.broker.full_name,
            "phone": listing.broker.phone,
        } if listing.broker is not None else None,
    }


@admin_bp.get("/documents/pending")
@roles_required(UserRole.ADMIN)
def list_pending_documents():
    """Documents awaiting admin review. Self-reported checklist items are
    intentionally NOT in this queue — the admin only sees actual uploads."""
    q = (
        ListingDocument.query
        .filter(ListingDocument.state == DocumentState.PENDING)
        .order_by(ListingDocument.updated_at.desc())
    )
    return jsonify([_document_admin_view(d) for d in q.all()]), 200


@admin_bp.post("/documents/<int:document_id>/approve")
@roles_required(UserRole.ADMIN)
def approve_document(document_id: int):
    doc = db.session.get(ListingDocument, document_id)
    if doc is None:
        return jsonify(error="Document not found."), 404
    if doc.storage_key is None:
        return jsonify(error="Cannot verify a self-reported entry without a document."), 409
    # Only PENDING documents may be approved — prevents re-approving
    # already-verified docs (which would silently overwrite the audit
    # trail) and prevents reversing a REJECTED decision without a fresh
    # upload.
    if doc.state != DocumentState.PENDING:
        return jsonify(
            error=f"Cannot approve a document in state {doc.state.value!r}. "
                  f"Only 'pending' documents can be approved."
        ), 409

    doc.state = DocumentState.VERIFIED
    doc.verified_at = datetime.now(timezone.utc)
    doc.verified_by = int(get_jwt_identity())
    doc.rejection_reason = None
    db.session.commit()

    if doc.listing is not None and doc.listing.broker_id:
        fcm.send_push_to_user(
            doc.listing.broker_id,
            title="Document verified",
            body=f"{doc.kind.value.replace('_', ' ').title()} · {doc.listing.title}",
            data={
                "route": f"/listings/{doc.listing.id}",
                "type": "document_verified",
            },
        )
    return jsonify(_document_admin_view(doc)), 200


@admin_bp.post("/documents/<int:document_id>/reject")
@roles_required(UserRole.ADMIN)
def reject_document(document_id: int):
    data = _reject_schema.load(request.get_json(silent=True) or {})

    doc = db.session.get(ListingDocument, document_id)
    if doc is None:
        return jsonify(error="Document not found."), 404
    # Reject only PENDING — a self-reported entry has no upload to
    # judge, and re-rejecting an already-verified doc would silently
    # rewrite the audit trail.
    if doc.state != DocumentState.PENDING:
        return jsonify(
            error=f"Cannot reject a document in state {doc.state.value!r}. "
                  f"Only 'pending' documents can be rejected."
        ), 409

    doc.state = DocumentState.REJECTED
    doc.rejection_reason = data["reason"].strip()
    doc.verified_at = None
    doc.verified_by = int(get_jwt_identity())
    # Keep storage_key so the admin can see what they rejected; on the
    # broker's next upload it will be replaced. Clear it here would
    # orphan the file too.
    db.session.commit()

    if doc.listing is not None and doc.listing.broker_id:
        fcm.send_push_to_user(
            doc.listing.broker_id,
            title="Document rejected",
            body=(doc.rejection_reason or "See reviewer note in the app.")[:120],
            data={
                "route": f"/listings/{doc.listing.id}",
                "type": "document_rejected",
            },
        )
    return jsonify(_document_admin_view(doc)), 200
