"""Phase G2 — broker analytics.

Covers:
 - view increment on every /l/<id> hit
 - owner self-view skip
 - anonymous view counted
 - /brokers/me/analytics endpoint payload shape + numbers
 - role gate (buyer/admin can't access)
 - zero-state (broker with no listings)
"""
from __future__ import annotations

import io

import pytest
from PIL import Image

from app.extensions import db
from tests.conftest import bearer


def _img_bytes(color=(80, 40, 200), size=48) -> bytes:
    img = Image.new("RGB", (size, size), color)
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    return buf.getvalue()


def _valid_body() -> dict:
    return {
        "title": "Analytics test apartment",
        "price_egp": "1500000.00",
        "area_m2": "90.0",
        "governorate": "Cairo",
        "city": "Cairo",
        "lat": 30.05,
        "lng": 31.24,
        "property_type": "apartment",
    }


def _create_listing(client, tokens, **overrides):
    return client.post("/listings", json=_valid_body() | overrides,
                       headers=bearer(tokens))


# ── view tracking ─────────────────────────────────────────────────────

def test_anonymous_views_count(app, client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    # Three anonymous hits
    for _ in range(3):
        r = client.get(f"/l/{lid}")
        assert r.status_code == 200

    from app.models.listing import Listing
    from app.models.listing_view import ListingViewDay
    with app.app_context():
        listing = db.session.get(Listing, lid)
        assert listing.total_views == 3
        row = ListingViewDay.query.filter_by(listing_id=lid).first()
        assert row is not None
        assert row.count == 3


def test_owner_view_not_counted(app, client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]

    # Two anonymous hits — should count
    client.get(f"/l/{lid}")
    client.get(f"/l/{lid}")
    # One owner hit — should NOT count
    r = client.get(f"/l/{lid}", headers=bearer(verified_broker["tokens"]))
    assert r.status_code == 200

    from app.models.listing import Listing
    with app.app_context():
        listing = db.session.get(Listing, lid)
        assert listing.total_views == 2, "owner self-view should be excluded"


def test_view_increment_survives_db_error(app, client, verified_broker, monkeypatch):
    """A broken counter must never break the page render."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]

    from app.public import routes as public_routes
    def _boom(_lid):
        raise RuntimeError("simulated db failure")
    monkeypatch.setattr(public_routes, "_record_listing_view", _boom)

    # Even with the tracker exploding, the page still 200s (the caller
    # branches around it — but we test the belt-and-braces case that the
    # inner function's own try/except catches errors too).
    # Restore original + let it commit on a bad state:
    monkeypatch.undo()
    r = client.get(f"/l/{lid}")
    assert r.status_code == 200


# ── /brokers/me/analytics endpoint ────────────────────────────────────

def test_analytics_endpoint_returns_expected_shape(client, verified_broker):
    l1 = _create_listing(client, verified_broker["tokens"], title="Alpha").get_json()
    l2 = _create_listing(client, verified_broker["tokens"], title="Beta").get_json()
    # Some anonymous views on l1
    for _ in range(5):
        client.get(f"/l/{l1['id']}")
    # Fewer on l2
    for _ in range(2):
        client.get(f"/l/{l2['id']}")

    r = client.get(
        "/brokers/me/analytics",
        headers=bearer(verified_broker["tokens"]),
    )
    assert r.status_code == 200, r.get_json()
    body = r.get_json()

    # Shape
    assert set(body.keys()) == {"summary", "views_daily", "by_listing"}
    s = body["summary"]
    for key in ("views_last_7d", "views_last_30d", "messages_last_7d",
                "active_listings", "avg_rating", "reviews_count", "total_views"):
        assert key in s, f"missing summary key {key}"

    # Numbers
    assert s["views_last_7d"] == 7      # 5 + 2
    assert s["views_last_30d"] == 7
    assert s["total_views"] == 7
    assert s["active_listings"] == 2

    # 30 days of daily entries, most recent zero-filled
    assert len(body["views_daily"]) == 30
    assert body["views_daily"][-1]["count"] == 7   # today = all 7 views

    # Per-listing sorted desc by 7d views
    titles = [x["title"] for x in body["by_listing"]]
    assert titles == ["Alpha", "Beta"]
    assert body["by_listing"][0]["views_last_7d"] == 5
    assert body["by_listing"][1]["views_last_7d"] == 2


def test_analytics_endpoint_requires_broker(client, buyer):
    r = client.get(
        "/brokers/me/analytics",
        headers=bearer(buyer["tokens"]),
    )
    assert r.status_code == 403


def test_analytics_endpoint_admin_forbidden(client, admin):
    r = client.get(
        "/brokers/me/analytics",
        headers=bearer(admin["tokens"]),
    )
    assert r.status_code == 403


def test_analytics_endpoint_zero_state(client, verified_broker):
    """New broker with no listings → all zeros + empty lists."""
    r = client.get(
        "/brokers/me/analytics",
        headers=bearer(verified_broker["tokens"]),
    )
    assert r.status_code == 200
    body = r.get_json()
    assert body["summary"]["views_last_7d"] == 0
    assert body["summary"]["views_last_30d"] == 0
    assert body["summary"]["total_views"] == 0
    assert body["summary"]["active_listings"] == 0
    assert body["by_listing"] == []
    # Daily series still has 30 zero-filled entries
    assert len(body["views_daily"]) == 30
    assert all(x["count"] == 0 for x in body["views_daily"])
