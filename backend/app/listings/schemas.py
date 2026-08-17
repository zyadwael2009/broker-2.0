"""Request/response schemas for listing endpoints."""
from __future__ import annotations

from marshmallow import Schema, fields, validate

from ..models.listing import DeliveryStatus, ListingKind, PropertyType


# Shared validators — reused between create and update.
_bedrooms = validate.Range(min=0, max=50)
_kind_values = [k.value for k in ListingKind]
_delivery_values = [d.value for d in DeliveryStatus]
_property_type_values = [t.value for t in PropertyType]


class ListingCreateSchema(Schema):
    title = fields.String(required=True, validate=validate.Length(min=3, max=200))
    description = fields.String(load_default=None, allow_none=True)
    price_egp = fields.Decimal(
        required=True, as_string=True, places=2,
        validate=validate.Range(min=1),
    )
    area_m2 = fields.Decimal(
        required=True, as_string=True, places=2,
        validate=validate.Range(min=1),
    )
    governorate = fields.String(required=True, validate=validate.Length(min=2, max=80))
    city = fields.String(required=True, validate=validate.Length(min=2, max=120))
    district = fields.String(load_default=None, allow_none=True)
    lat = fields.Float(required=True, validate=validate.Range(min=-90, max=90))
    lng = fields.Float(required=True, validate=validate.Range(min=-180, max=180))
    property_type = fields.String(
        required=True,
        validate=validate.OneOf(_property_type_values),
    )

    # Phase A1 richer fields — all optional on create so LAND / bare-lot
    # listings don't need to fill bedrooms / floors.
    listing_kind = fields.String(
        load_default=ListingKind.SALE.value,
        validate=validate.OneOf(_kind_values),
    )
    bedrooms = fields.Integer(load_default=None, allow_none=True, validate=_bedrooms)
    bathrooms = fields.Integer(load_default=None, allow_none=True, validate=_bedrooms)
    floor_number = fields.Integer(load_default=None, allow_none=True, validate=_bedrooms)
    is_furnished = fields.Boolean(load_default=None, allow_none=True)
    compound_name = fields.String(
        load_default=None, allow_none=True, validate=validate.Length(max=120),
    )
    delivery_status = fields.String(
        load_default=None, allow_none=True,
        validate=validate.OneOf(_delivery_values),
    )


class ListingUpdateSchema(Schema):
    """Same fields as create, all optional."""
    title = fields.String(validate=validate.Length(min=3, max=200))
    description = fields.String(allow_none=True)
    price_egp = fields.Decimal(as_string=True, places=2, validate=validate.Range(min=1))
    area_m2 = fields.Decimal(as_string=True, places=2, validate=validate.Range(min=1))
    governorate = fields.String(validate=validate.Length(min=2, max=80))
    city = fields.String(validate=validate.Length(min=2, max=120))
    district = fields.String(allow_none=True)
    lat = fields.Float(validate=validate.Range(min=-90, max=90))
    lng = fields.Float(validate=validate.Range(min=-180, max=180))
    property_type = fields.String(validate=validate.OneOf(_property_type_values))
    # PATCH may only set `sold` or `hidden` — flipping `active`/`expired`
    # directly would bypass the auto-expire + confirm flow that keeps the
    # feed fresh. Use POST /listings/<id>/confirm to re-activate.
    status = fields.String(validate=validate.OneOf(["sold", "hidden"]))

    # Phase A1 richer fields — all optional on update.
    listing_kind = fields.String(validate=validate.OneOf(_kind_values))
    bedrooms = fields.Integer(allow_none=True, validate=_bedrooms)
    bathrooms = fields.Integer(allow_none=True, validate=_bedrooms)
    floor_number = fields.Integer(allow_none=True, validate=_bedrooms)
    is_furnished = fields.Boolean(allow_none=True)
    compound_name = fields.String(allow_none=True, validate=validate.Length(max=120))
    delivery_status = fields.String(
        allow_none=True, validate=validate.OneOf(_delivery_values),
    )
