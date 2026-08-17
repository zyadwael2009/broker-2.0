"""User reports of listings/brokers + admin resolution.

Rules:
- Any authed user can submit a report. Rate-limited: 5/hour.
- Can't report yourself (broker can't self-report; buyer can't
  report their own... but buyers have no target).
- Target must exist at submit time (400 otherwise).
- Admin resolves via `/admin/reports/<id>/resolve` — state guard
  refuses already-resolved reports (mirrors the pattern used by
  documents/brokers approve+reject).
"""
from __future__ import annotations

from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from ..auth.security import roles_required
from ..extensions import db, limiter
from ..models.listing import Listing
from ..models.report import Report, ReportReason, ReportStatus, ReportTargetType
from ..models.user import User, UserRole
from ..notifications import fcm
from .schemas import ResolveReportSchema, SubmitReportSchema

reports_bp = Blueprint("reports", __name__)

_submit_schema = SubmitReportSchema()
_resolve_schema = ResolveReportSchema()


def _current_user() -> User | None:
    ident = get_jwt_identity()
    if ident is None:
        return None
    return db.session.get(User, int(ident))


@reports_bp.post("/reports")
@limiter.limit(lambda: current_app.config.get("RATELIMIT_REPORTS", "5 per hour"))
@jwt_required()
def submit_report():
    user = _current_user()
    if user is None:
        return jsonify(error="Account not available."), 401

    data = _submit_schema.load(request.get_json(silent=True) or {})
    target_type = ReportTargetType(data["target_type"])
    target_id = data["target_id"]

    # Existence + self-report checks.
    if target_type == ReportTargetType.LISTING:
        listing = db.session.get(Listing, target_id)
        if listing is None:
            return jsonify(error="Listing not found."), 400
        if listing.broker_id == user.id:
            return jsonify(error="You cannot report your own listing."), 400
    else:
        target_user = db.session.get(User, target_id)
        if target_user is None or target_user.role != UserRole.BROKER:
            return jsonify(error="Broker not found."), 400
        if target_user.id == user.id:
            return jsonify(error="You cannot report yourself."), 400

    report = Report(
        reporter_user_id=user.id,
        target_type=target_type,
        target_id=target_id,
        reason=ReportReason(data["reason"]),
        note=(data.get("note") or None),
    )
    db.session.add(report)
    db.session.commit()
    return jsonify(report.to_admin_dict()), 201


# ── admin ───────────────────────────────────────────────────────────

@reports_bp.get("/admin/reports")
@roles_required(UserRole.ADMIN)
def list_reports():
    status_str = request.args.get("status", "open").lower()
    try:
        status = ReportStatus(status_str)
    except ValueError:
        return jsonify(
            error=f"Invalid status. Allowed: {[s.value for s in ReportStatus]}"
        ), 400
    q = (
        Report.query.filter(Report.status == status)
        .order_by(Report.created_at.desc())
    )
    return jsonify([r.to_admin_dict() for r in q.all()]), 200


@reports_bp.post("/admin/reports/<int:report_id>/resolve")
@roles_required(UserRole.ADMIN)
def resolve_report(report_id: int):
    data = _resolve_schema.load(request.get_json(silent=True) or {})

    report = db.session.get(Report, report_id)
    if report is None:
        return jsonify(error="Report not found."), 404
    if report.status != ReportStatus.OPEN:
        return jsonify(
            error=f"Cannot resolve a report already in state "
                  f"{report.status.value!r}."
        ), 409

    action = data["action"]
    if action == "dismiss":
        report.status = ReportStatus.DISMISSED
    elif action == "resolved_no_action":
        report.status = ReportStatus.RESOLVED_NO_ACTION
    else:
        report.status = ReportStatus.RESOLVED_ACTION
    report.resolution_note = (data.get("note") or None)
    report.resolved_at = datetime.now(timezone.utc)
    report.resolved_by = int(get_jwt_identity())

    db.session.commit()

    if report.reporter_user_id:
        fcm.send_push_to_user(
            report.reporter_user_id,
            title="Report reviewed",
            body="Thanks for the report — an admin has reviewed it.",
            data={"route": "/", "type": "report_resolved"},
        )
    return jsonify(report.to_admin_dict()), 200
