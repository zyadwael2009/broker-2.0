"""Device-token registration for push notifications.

- POST /devices — mobile client sends its FCM token after login. Upsert
  keyed on (user_id, token) so a re-register is a no-op and refreshes
  last_seen_at.
- DELETE /devices — client tells us to forget the token (logout).

We deliberately don't require the client to send an existing token id —
tokens are opaque strings that already uniquely identify the device.
"""
from __future__ import annotations

from datetime import datetime, timezone

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from marshmallow import Schema, ValidationError, fields, validate
from sqlalchemy.exc import IntegrityError

from ..extensions import db
from ..models.device_token import DevicePlatform, DeviceToken

devices_bp = Blueprint("devices", __name__)


class RegisterDeviceSchema(Schema):
    token = fields.String(required=True, validate=validate.Length(min=8, max=4096))
    platform = fields.String(
        required=True,
        validate=validate.OneOf([p.value for p in DevicePlatform]),
    )


class DeleteDeviceSchema(Schema):
    token = fields.String(required=True, validate=validate.Length(min=8, max=4096))


_register_schema = RegisterDeviceSchema()
_delete_schema = DeleteDeviceSchema()


def _current_user_id() -> int | None:
    ident = get_jwt_identity()
    return int(ident) if ident is not None else None


@devices_bp.post("")
@jwt_required()
def register_device():
    try:
        data = _register_schema.load(request.get_json(silent=True) or {})
    except ValidationError as exc:
        return jsonify(error="Validation failed.", fields=exc.messages), 400

    user_id = _current_user_id()
    if user_id is None:
        return jsonify(error="Account not available."), 401

    now = datetime.now(timezone.utc)
    existing = (
        db.session.query(DeviceToken)
        .filter_by(user_id=user_id, token=data["token"])
        .first()
    )
    if existing is not None:
        existing.last_seen_at = now
        existing.platform = DevicePlatform(data["platform"])
        db.session.commit()
        return jsonify(id=existing.id, status="refreshed"), 200

    row = DeviceToken(
        user_id=user_id,
        token=data["token"],
        platform=DevicePlatform(data["platform"]),
        last_seen_at=now,
    )
    db.session.add(row)
    try:
        db.session.commit()
    except IntegrityError:
        # Race: another request just inserted the same (user_id, token).
        db.session.rollback()
        existing = (
            db.session.query(DeviceToken)
            .filter_by(user_id=user_id, token=data["token"])
            .first()
        )
        if existing is None:
            raise
        return jsonify(id=existing.id, status="refreshed"), 200
    return jsonify(id=row.id, status="registered"), 201


@devices_bp.delete("")
@jwt_required()
def deregister_device():
    try:
        data = _delete_schema.load(request.get_json(silent=True) or {})
    except ValidationError as exc:
        return jsonify(error="Validation failed.", fields=exc.messages), 400

    user_id = _current_user_id()
    if user_id is None:
        return jsonify(error="Account not available."), 401

    (
        db.session.query(DeviceToken)
        .filter_by(user_id=user_id, token=data["token"])
        .delete(synchronize_session=False)
    )
    db.session.commit()
    return "", 204
