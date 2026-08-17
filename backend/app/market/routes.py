"""Phase 5 — price-per-m² transparency.

Buyers rely on broker guesswork today; these endpoints publish aggregate
price signals from the app's own listings so a buyer can see what
comparable properties in the same area actually cost per square metre.

Rules (match the buyer-facing listing feed):
- Only listings whose broker is currently VERIFIED and active.
- `active` OR `sold` statuses: asking prices for active, achieved
  prices for sold. Hidden/expired excluded.
- Median/quartiles computed in Python — SQLite has no PERCENTILE_CONT
  and the dataset stays tiny for the MVP.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import func

from ..extensions import db
from ..listings.routes import LISTING_TTL
from ..models.broker_profile import BrokerProfile, VerificationStatus
from ..models.listing import Listing, ListingStatus, PropertyType
from ..models.user import User

market_bp = Blueprint("market", __name__)


def _base_query():
    """Common WHERE clause: verified-broker + not-expired active OR sold.

    Mirrors the buyer feed exactly — a broker who posts, walks away, and
    lets the listing auto-expire must not skew market medians forever."""
    now = datetime.now(timezone.utc)
    cutoff = now - LISTING_TTL
    baseline = func.coalesce(Listing.last_confirmed_at, Listing.created_at)

    return (
        Listing.query
        .join(User, Listing.broker_id == User.id)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .filter(Listing.status.in_([ListingStatus.ACTIVE, ListingStatus.SOLD]))
        .filter(Listing.area_m2 > 0)
        # Active listings must not be stale. SOLD listings keep counting —
        # a sold price is still a valid market signal, no matter when.
        .filter(
            (Listing.status == ListingStatus.SOLD) | (baseline > cutoff)
        )
    )


def _apply_filters(q, args):
    gov = args.get("governorate")
    if gov:
        q = q.filter(Listing.governorate == gov)
    city = args.get("city")
    if city:
        q = q.filter(Listing.city == city)
    district = args.get("district")
    if district:
        q = q.filter(Listing.district == district)
    ptype = args.get("property_type")
    if ptype:
        try:
            q = q.filter(Listing.property_type == PropertyType(ptype))
        except ValueError:
            return None, (jsonify(error=f"Invalid property_type: {ptype}"), 400)
    return q, None


def _price_per_m2(listing: Listing) -> float:
    """Fresh division per listing — Decimal → float for percentile math."""
    return float(Decimal(listing.price_egp) / Decimal(listing.area_m2))


def _percentile(sorted_values: list[float], p: float) -> float:
    """Linear-interpolation percentile. Matches numpy's default (p in [0,1])."""
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return sorted_values[0]
    k = (len(sorted_values) - 1) * p
    lo, hi = int(k), min(int(k) + 1, len(sorted_values) - 1)
    if lo == hi:
        return sorted_values[lo]
    frac = k - lo
    return sorted_values[lo] * (1 - frac) + sorted_values[hi] * frac


@market_bp.get("/price-per-m2")
@jwt_required()
def price_per_m2():
    q, err = _apply_filters(_base_query(), request.args)
    if err is not None:
        return err

    listings = q.all()
    if not listings:
        return jsonify(
            {
                "count": 0,
                "median": None,
                "min": None,
                "max": None,
                "p25": None,
                "p75": None,
                "unit": "EGP/m2",
            }
        ), 200

    values = sorted(_price_per_m2(l) for l in listings)

    return jsonify(
        {
            "count": len(values),
            "median": round(_percentile(values, 0.5), 2),
            "min": round(values[0], 2),
            "max": round(values[-1], 2),
            "p25": round(_percentile(values, 0.25), 2),
            "p75": round(_percentile(values, 0.75), 2),
            "unit": "EGP/m2",
        }
    ), 200


@market_bp.get("/price-per-m2/trend")
@jwt_required()
def price_per_m2_trend():
    """Monthly buckets over the last `months` (default 12). Only months
    with at least MIN_MONTHLY_LISTINGS entries are returned — otherwise a
    single outlier would swing the trend line."""
    MIN_MONTHLY_LISTINGS = 2

    try:
        months = int(request.args.get("months", "12"))
    except ValueError:
        return jsonify(error="months must be an integer"), 400
    months = max(1, min(months, 36))

    q, err = _apply_filters(_base_query(), request.args)
    if err is not None:
        return err

    # Anchor to the first of the calendar month N months back so we get
    # exactly N buckets (the 32*months approximation overshot by ~2 days
    # per month — enough for months=36 to grab ~2 extra buckets).
    now = datetime.now(timezone.utc).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    year = now.year
    month = now.month - months
    while month <= 0:
        month += 12
        year -= 1
    cutoff = now.replace(year=year, month=month)
    q = q.filter(Listing.created_at >= cutoff)

    # Bucket in Python — SQLite/Postgres cross-portable and dataset is tiny.
    buckets: dict[str, list[float]] = defaultdict(list)
    for l in q.all():
        created = l.created_at
        if created is None:
            continue
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        key = f"{created.year:04d}-{created.month:02d}"
        buckets[key].append(_price_per_m2(l))

    out = []
    for key in sorted(buckets):
        values = sorted(buckets[key])
        if len(values) < MIN_MONTHLY_LISTINGS:
            continue
        out.append(
            {
                "month": key,
                "count": len(values),
                "median": round(_percentile(values, 0.5), 2),
            }
        )
    return jsonify(out), 200


@market_bp.get("/filters")
@jwt_required()
def filter_options():
    """Distinct governorates and (per-governorate) cities from the same
    dataset the buyer feed uses. Powers filter dropdowns without any
    hard-coded location list."""
    rows = (
        _base_query()
        .with_entities(Listing.governorate, Listing.city)
        .distinct()
        .all()
    )

    by_gov: dict[str, set[str]] = defaultdict(set)
    for gov, city in rows:
        by_gov[gov].add(city)

    return jsonify(
        {
            "governorates": sorted(by_gov.keys()),
            "cities_by_governorate": {
                gov: sorted(cities) for gov, cities in by_gov.items()
            },
        }
    ), 200
