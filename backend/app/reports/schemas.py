from marshmallow import Schema, fields, validate

from ..models.report import ReportReason, ReportTargetType


class SubmitReportSchema(Schema):
    target_type = fields.String(
        required=True,
        validate=validate.OneOf([t.value for t in ReportTargetType]),
    )
    target_id = fields.Integer(required=True, validate=validate.Range(min=1))
    reason = fields.String(
        required=True,
        validate=validate.OneOf([r.value for r in ReportReason]),
    )
    note = fields.String(
        required=False, load_default=None, allow_none=True,
        validate=validate.Length(max=1000),
    )


class ResolveReportSchema(Schema):
    action = fields.String(
        required=True,
        validate=validate.OneOf(["dismiss", "resolved_no_action", "resolved_action"]),
    )
    note = fields.String(
        required=False, load_default=None, allow_none=True,
        validate=validate.Length(max=1000),
    )
