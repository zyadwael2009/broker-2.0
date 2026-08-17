"""Request/response validation for auth endpoints.

RegisterSchema deliberately rejects role='admin' — admins are seeded
via the `flask seed-admin` CLI command only."""
from __future__ import annotations

from marshmallow import Schema, fields, validate, validates, ValidationError

from ..config import Config


PUBLIC_ROLES = ("buyer", "broker")


class RegisterSchema(Schema):
    phone = fields.String(required=True)
    password = fields.String(
        required=True,
        validate=validate.Length(min=Config.MIN_PASSWORD_LEN),
        load_only=True,
    )
    full_name = fields.String(
        required=True, validate=validate.Length(min=2, max=120)
    )
    role = fields.String(required=True, validate=validate.OneOf(PUBLIC_ROLES))
    email = fields.Email(required=False, load_default=None, allow_none=True)
    # Phase G1 — optional referral code captured via marketing web.
    # Silently ignored if the code doesn't match a known user.
    ref_code = fields.String(
        load_default=None, allow_none=True,
        validate=validate.Length(max=16),
    )

    @validates("role")
    def _no_admin(self, value: str, **_):
        if value == "admin":
            raise ValidationError("Admin accounts cannot be self-registered.")


class LoginSchema(Schema):
    phone = fields.String(required=True)
    password = fields.String(required=True, load_only=True)
