from marshmallow import Schema, fields, validate


class SubmitRatingSchema(Schema):
    stars = fields.Integer(required=True, validate=validate.Range(min=1, max=5))
    note = fields.String(
        required=False, load_default=None, allow_none=True,
        validate=validate.Length(max=500),
    )
