"""File-serving endpoint. For the local-disk storage backend only —
S3 will return presigned URLs and skip this route entirely.

Access rules:
- `listing-photos/**` is PUBLIC (no JWT). Content is meant to be shown
  in the app; random hex keys keep specific files unguessable.
- `broker-docs/**` is admin-only or the owning broker themselves.
- `listing-docs/<listing_id>/<kind>/**` is admin-only or the owning
  broker of that listing.
- Anything else is authenticated but open to any logged-in user.
"""
from __future__ import annotations

import mimetypes
from pathlib import PurePosixPath

from flask import Blueprint, abort, jsonify, send_file
from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request

from ..extensions import db
from ..models.listing import Listing
from ..models.user import UserRole
from ..storage import get_storage
from ..storage.local import LocalDiskStorage

files_bp = Blueprint("files", __name__)


def _broker_doc_owner_id(key: str) -> int | None:
    """`broker-docs/<user_id>/<random>.ext` → user_id, or None if malformed."""
    parts = PurePosixPath(key).parts
    if len(parts) >= 2 and parts[0] == "broker-docs":
        try:
            return int(parts[1])
        except ValueError:
            return None
    return None


def _listing_doc_listing_id(key: str) -> int | None:
    """`listing-docs/<listing_id>/<kind>/<random>.ext` → listing_id."""
    parts = PurePosixPath(key).parts
    if len(parts) >= 2 and parts[0] == "listing-docs":
        try:
            return int(parts[1])
        except ValueError:
            return None
    return None


@files_bp.get("/<path:key>")
def serve_file(key: str):
    storage = get_storage()
    if not isinstance(storage, LocalDiskStorage):
        # In S3 mode the client should hit the presigned URL directly.
        return jsonify(error="This backend does not serve files directly."), 501

    is_public_listing_photo = key.startswith("listing-photos/")

    # Auth: enforced for everything except public listing photos.
    if not is_public_listing_photo:
        verify_jwt_in_request()
        claims = get_jwt()
        role = claims.get("role")
        caller_id = int(get_jwt_identity())

        if key.startswith("broker-docs/"):
            owner_id = _broker_doc_owner_id(key)
            if role != UserRole.ADMIN.value and caller_id != owner_id:
                return jsonify(error="Forbidden."), 403

        elif key.startswith("listing-docs/"):
            listing_id = _listing_doc_listing_id(key)
            if listing_id is None:
                return jsonify(error="Illegal file key."), 400
            if role != UserRole.ADMIN.value:
                listing = db.session.get(Listing, listing_id)
                if listing is None or listing.broker_id != caller_id:
                    return jsonify(error="Forbidden."), 403

    try:
        path = storage._abs(key)  # noqa: SLF001 — trusted local backend
    except ValueError:
        abort(400, description="Illegal file key.")
    if not path.exists() or not path.is_file():
        abort(404)

    mimetype = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    return send_file(path, mimetype=mimetype)
