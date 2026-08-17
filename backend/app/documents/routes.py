"""Per-listing document checklist endpoints.

The full listing feed already lives in `app/listings/routes.py`; this
blueprint carries only the document sub-resources so listings/routes.py
stays focused on the listing itself.

Access rules:
- READ (list documents for a listing): any authenticated user, so buyers
  can see the checklist before contacting the broker.
- WRITE (self-report / upload / delete): only the listing's owner AND
  currently a verified broker — same re-check the audit uncovered we
  needed on every other mutation route.
"""
from __future__ import annotations

import mimetypes
import secrets
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy.exc import IntegrityError

from ..extensions import db
from ..listings.routes import _require_verified_broker
from ..models.listing import Listing
from ..models.listing_document import DocumentKind, DocumentState, ListingDocument
from ..models.user import User
from ..security.content_validation import (
    ContentTypeError,
    document_kinds,
    read_and_validate,
)
from ..storage import get_storage

documents_bp = Blueprint("documents", __name__)

# Same content-type allowlist as broker verification docs.
_ALLOWED_EXTS = {".pdf", ".jpg", ".jpeg", ".png", ".webp"}
_ALLOWED_MIMES = {"application/pdf", "image/jpeg", "image/png", "image/webp"}


def _current_user() -> User | None:
    ident = get_jwt_identity()
    if ident is None:
        return None
    return db.session.get(User, int(ident))


def _load_listing_or_404(listing_id: int):
    listing = db.session.get(Listing, listing_id)
    if listing is None:
        return None, (jsonify(error="Listing not found."), 404)
    return listing, None


def _require_owner_and_verified(listing: Listing, user: User | None):
    """Combined owner + verified-broker gate used on every write."""
    if user is None or listing.broker_id != user.id:
        return jsonify(error="Forbidden."), 403
    err = _require_verified_broker(user)
    if err is not None:
        return err
    return None


def _parse_kind(kind: str):
    try:
        return DocumentKind(kind), None
    except ValueError:
        return None, (
            jsonify(
                error=f"Unknown document kind. Allowed: "
                      f"{[k.value for k in DocumentKind]}"
            ),
            400,
        )


def _serialize_document(doc: ListingDocument, for_owner: bool = False) -> dict:
    """Owner-visible payload. Buyers see the same shape minus the
    document URL and the reviewer's rejection note."""
    url = None
    if for_owner and doc.storage_key is not None:
        url = get_storage().url(doc.storage_key)
    payload = doc.to_public_dict(include_document_url=for_owner, url=url)
    if not for_owner:
        # Broker-facing signals — don't leak to buyers.
        payload["rejection_reason"] = None
        payload["document_url"] = None
    return payload


def _all_kinds_for_listing(listing: Listing, caller_id: int | None) -> list[dict]:
    """Return the full 3-row checklist, filling in unset kinds so the
    client always sees a stable shape. `rejection_reason` and
    `document_url` are only sent back when the caller is the owner."""
    is_owner = caller_id is not None and caller_id == listing.broker_id
    by_kind = {doc.kind: doc for doc in listing.documents}
    rows: list[dict] = []
    for kind in DocumentKind:
        doc = by_kind.get(kind)
        if doc is None:
            # Stable shape — every field a real doc row would have,
            # `id: null` so clients can iterate without KeyError.
            rows.append({
                "id": None,
                "listing_id": listing.id,
                "kind": kind.value,
                "state": "unset",
                "has_document": False,
                "verified_at": None,
                "rejection_reason": None,
                "document_url": None,
                "created_at": None,
                "updated_at": None,
            })
        else:
            rows.append(_serialize_document(doc, for_owner=is_owner))
    return rows


# ── endpoints ──────────────────────────────────────────────────────────

@documents_bp.get("/<int:listing_id>/documents")
@jwt_required()
def list_documents(listing_id: int):
    listing, err = _load_listing_or_404(listing_id)
    if err is not None:
        return err
    caller_id = int(get_jwt_identity()) if get_jwt_identity() else None
    return jsonify(_all_kinds_for_listing(listing, caller_id)), 200


@documents_bp.post("/<int:listing_id>/documents/<kind>/self-report")
@jwt_required()
def self_report(listing_id: int, kind: str):
    listing, err = _load_listing_or_404(listing_id)
    if err is not None:
        return err
    err = _require_owner_and_verified(listing, _current_user())
    if err is not None:
        return err

    kind_enum, kerr = _parse_kind(kind)
    if kerr is not None:
        return kerr

    # Refuse to demote an admin-approved doc or clobber a pending review
    # — either would silently destroy real work. Broker has to explicitly
    # DELETE first if they truly want to start over.
    existing = ListingDocument.query.filter_by(
        listing_id=listing.id, kind=kind_enum
    ).first()
    if existing is not None:
        if existing.state == DocumentState.VERIFIED:
            return jsonify(
                error="This document is already admin-verified. "
                      "Remove it first if you want to replace it with a self-report."
            ), 409
        if existing.state == DocumentState.PENDING:
            return jsonify(
                error="Your uploaded document is awaiting admin review. "
                      "Remove it first if you want to switch to a self-report."
            ), 409

    doc = _upsert_doc(listing, kind_enum)
    # Order: mutate DB & commit FIRST, only touch storage after. If commit
    # fails, the file (if any) stays intact — worst case a small waste.
    old_key = doc.storage_key
    doc.storage_key = None
    doc.state = DocumentState.SELF_REPORTED
    doc.verified_at = None
    doc.verified_by = None
    doc.rejection_reason = None
    db.session.commit()
    if old_key is not None:
        get_storage().delete(old_key)

    return jsonify(_serialize_document(doc, for_owner=True)), 200


@documents_bp.post("/<int:listing_id>/documents/<kind>")
@jwt_required()
def upload_document(listing_id: int, kind: str):
    listing, err = _load_listing_or_404(listing_id)
    if err is not None:
        return err
    err = _require_owner_and_verified(listing, _current_user())
    if err is not None:
        return err

    kind_enum, kerr = _parse_kind(kind)
    if kerr is not None:
        return kerr

    file = request.files.get("document")
    if file is None or not file.filename:
        return jsonify(error="A document file is required."), 400

    ext = Path(file.filename).suffix.lower()
    if ext not in _ALLOWED_EXTS:
        return jsonify(
            error=f"Unsupported file type. Allowed: {sorted(_ALLOWED_EXTS)}"
        ), 400

    mime = file.mimetype or mimetypes.guess_type(file.filename)[0] or ""
    if mime and mime not in _ALLOWED_MIMES:
        return jsonify(error=f"Unsupported content type: {mime}"), 400

    # Magic-byte check — reject payloads whose actual bytes don't match.
    try:
        doc_bytes = read_and_validate(file.stream, allowed=document_kinds)
    except ContentTypeError as exc:
        return jsonify(error=str(exc)), 400

    storage = get_storage()
    doc = _upsert_doc(listing, kind_enum)
    old_key = doc.storage_key

    # Write the NEW file first so if put() fails, the old proof is intact.
    from io import BytesIO
    new_key = f"listing-docs/{listing.id}/{kind_enum.value}/{secrets.token_hex(16)}{ext}"
    storage.put(new_key, BytesIO(doc_bytes), content_type=mime or None)

    doc.storage_key = new_key
    doc.state = DocumentState.PENDING
    doc.verified_at = None
    doc.verified_by = None
    doc.rejection_reason = None
    try:
        db.session.commit()
    except Exception:
        # Commit failed → back out the file we just wrote, leave the old
        # one in place, and let the request bubble up.
        db.session.rollback()
        storage.delete(new_key)
        raise

    # Commit succeeded — safe to drop the previous file.
    if old_key is not None:
        storage.delete(old_key)

    return jsonify(_serialize_document(doc, for_owner=True)), 200


@documents_bp.delete("/<int:listing_id>/documents/<kind>")
@jwt_required()
def delete_document(listing_id: int, kind: str):
    listing, err = _load_listing_or_404(listing_id)
    if err is not None:
        return err
    err = _require_owner_and_verified(listing, _current_user())
    if err is not None:
        return err

    kind_enum, kerr = _parse_kind(kind)
    if kerr is not None:
        return kerr

    doc = ListingDocument.query.filter_by(
        listing_id=listing.id, kind=kind_enum
    ).first()
    if doc is None:
        return "", 204  # idempotent

    # Delete the DB row FIRST; only remove the file after a successful
    # commit. Reversing the order (file first) would irrecoverably drop
    # the proof on any DB error.
    key = doc.storage_key
    db.session.delete(doc)
    db.session.commit()
    if key is not None:
        get_storage().delete(key)
    return "", 204


def _upsert_doc(listing: Listing, kind: DocumentKind) -> ListingDocument:
    existing = ListingDocument.query.filter_by(
        listing_id=listing.id, kind=kind
    ).first()
    if existing is not None:
        return existing
    doc = ListingDocument(
        listing_id=listing.id,
        kind=kind,
        state=DocumentState.SELF_REPORTED,  # overwritten by caller
    )
    db.session.add(doc)
    try:
        db.session.flush()
    except IntegrityError:
        # Race: another request inserted the same (listing, kind) between
        # our SELECT and INSERT. Recover by returning the winner so the
        # caller can proceed with an update instead of a duplicate insert.
        db.session.rollback()
        winner = ListingDocument.query.filter_by(
            listing_id=listing.id, kind=kind
        ).first()
        if winner is None:
            raise
        return winner
    return doc
