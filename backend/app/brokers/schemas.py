"""Request/response schemas for broker + admin endpoints."""
from __future__ import annotations

from marshmallow import Schema, fields, validate


class VerificationSubmitSchema(Schema):
    """Multipart POST /brokers/me/verification — the `document` file is
    handled separately via request.files, not marshmallow."""

    goeic_registration_number = fields.String(
        required=True, validate=validate.Length(min=1, max=64)
    )


class RejectSchema(Schema):
    reason = fields.String(required=True, validate=validate.Length(min=1, max=1000))
