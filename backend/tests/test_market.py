"""Phase 5 — price-per-m² aggregation, trend, filters."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.extensions import db
from app.models.listing import Listing, ListingStatus
from tests.conftest import bearer


def _valid_body(**overrides) -> dict:
    base = {
        "title": "Market test listing",
        "description": "For phase-5 tests.",
        "price_egp": "2000000.00",
        "area_m2": "100",
        "governorate": "Cairo",
        "city": "New Cairo",
        "district": "Fifth Settlement",
        "lat": 30.02,
        "lng": 31.47,
        "property_type": "apartment",
    }
    base.update(overrides)
    return base


def _create(client, tokens, **overrides):
    return client.post("/listings", json=_valid_body(**overrides),
                       headers=bearer(tokens))


# ── happy paths ────────────────────────────────────────────────────────

def test_price_per_m2_empty_returns_null(client, buyer):
    res = client.get("/market/price-per-m2", headers=bearer(buyer["tokens"]))
    assert res.status_code == 200
    body = res.get_json()
    assert body["count"] == 0
    assert body["median"] is None
    assert body["unit"] == "EGP/m2"


def test_price_per_m2_single_listing(client, buyer, verified_broker):
    # 2,000,000 / 100 = 20,000/m²
    _create(client, verified_broker["tokens"])
    res = client.get("/market/price-per-m2", headers=bearer(buyer["tokens"]))
    body = res.get_json()
    assert body["count"] == 1
    assert body["median"] == 20000.0
    assert body["min"] == 20000.0
    assert body["max"] == 20000.0


def test_price_per_m2_median_and_quartiles(client, buyer, verified_broker):
    tokens = verified_broker["tokens"]
    # 5 listings at 10k, 12k, 15k, 20k, 30k per m²
    for price_per_m2 in (10000, 12000, 15000, 20000, 30000):
        _create(client, tokens,
                price_egp=f"{price_per_m2 * 100}.00",
                area_m2="100",
                title=f"listing @ {price_per_m2}")
    res = client.get("/market/price-per-m2", headers=bearer(buyer["tokens"]))
    body = res.get_json()
    assert body["count"] == 5
    assert body["median"] == 15000.0
    assert body["min"] == 10000.0
    assert body["max"] == 30000.0
    # 25th percentile between 10k and 12k, 75th between 20k and 30k
    assert 11000 <= body["p25"] <= 12500
    assert 20000 <= body["p75"] <= 27500


def test_filter_by_governorate(client, buyer, verified_broker):
    tokens = verified_broker["tokens"]
    _create(client, tokens, governorate="Cairo", price_egp="1000000", area_m2="100")
    _create(client, tokens, governorate="Alexandria", price_egp="500000", area_m2="100")

    r1 = client.get("/market/price-per-m2?governorate=Cairo",
                    headers=bearer(buyer["tokens"])).get_json()
    r2 = client.get("/market/price-per-m2?governorate=Alexandria",
                    headers=bearer(buyer["tokens"])).get_json()
    assert r1["count"] == 1 and r1["median"] == 10000.0
    assert r2["count"] == 1 and r2["median"] == 5000.0


def test_filter_by_property_type(client, buyer, verified_broker):
    tokens = verified_broker["tokens"]
    _create(client, tokens, property_type="apartment",
            price_egp="1000000", area_m2="100")
    _create(client, tokens, property_type="villa",
            price_egp="5000000", area_m2="200")
    res = client.get("/market/price-per-m2?property_type=villa",
                     headers=bearer(buyer["tokens"])).get_json()
    assert res["count"] == 1
    assert res["median"] == 25000.0


def test_invalid_property_type_400(client, buyer):
    res = client.get("/market/price-per-m2?property_type=spaceship",
                     headers=bearer(buyer["tokens"]))
    assert res.status_code == 400


# ── verification + status rules ───────────────────────────────────────

def test_unverified_broker_listings_excluded(app, client, buyer, verified_broker, broker):
    """Non-verified-broker listings must not skew market data."""
    _create(client, verified_broker["tokens"])
    # `broker` fixture is unverified — cannot even create a listing, so
    # simulate the case where a broker WAS verified then got rejected.
    from app.models.broker_profile import BrokerProfile, VerificationStatus

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.REJECTED
        db.session.commit()

    # Now no verified brokers → aggregation empty.
    res = client.get("/market/price-per-m2",
                     headers=bearer(buyer["tokens"])).get_json()
    assert res["count"] == 0


def test_sold_listings_included_expired_excluded(app, client, buyer, verified_broker):
    """SOLD is a stronger price signal; EXPIRED/HIDDEN are excluded."""
    tokens = verified_broker["tokens"]
    a = _create(client, tokens, price_egp="1000000", area_m2="100").get_json()
    b = _create(client, tokens, price_egp="2000000", area_m2="100").get_json()
    c = _create(client, tokens, price_egp="3000000", area_m2="100").get_json()

    with app.app_context():
        db.session.get(Listing, a["id"]).status = ListingStatus.SOLD
        db.session.get(Listing, b["id"]).status = ListingStatus.EXPIRED
        db.session.get(Listing, c["id"]).status = ListingStatus.HIDDEN
        db.session.commit()

    res = client.get("/market/price-per-m2",
                     headers=bearer(buyer["tokens"])).get_json()
    # Only the SOLD one counts.
    assert res["count"] == 1
    assert res["median"] == 10000.0


# ── trend ─────────────────────────────────────────────────────────────

def test_trend_hides_months_with_too_few_listings(client, buyer, verified_broker):
    """Single-listing months should NOT appear on the trend line."""
    _create(client, verified_broker["tokens"])
    res = client.get("/market/price-per-m2/trend",
                     headers=bearer(buyer["tokens"]))
    assert res.status_code == 200
    assert res.get_json() == []


def test_trend_returns_month_bucket_when_enough_data(
    app, client, buyer, verified_broker
):
    tokens = verified_broker["tokens"]
    a = _create(client, tokens, price_egp="1000000", area_m2="100").get_json()
    b = _create(client, tokens, price_egp="2000000", area_m2="100").get_json()

    # Force both into a known month bucket.
    with app.app_context():
        anchor = datetime(2026, 6, 15, tzinfo=timezone.utc)
        for lid in (a["id"], b["id"]):
            db.session.get(Listing, lid).created_at = anchor
        db.session.commit()

    res = client.get("/market/price-per-m2/trend?months=36",
                     headers=bearer(buyer["tokens"])).get_json()
    assert len(res) == 1
    assert res[0]["month"] == "2026-06"
    assert res[0]["count"] == 2
    assert res[0]["median"] == 15000.0


# ── filters ───────────────────────────────────────────────────────────

def test_filters_endpoint_lists_distinct_governorates(
    client, buyer, verified_broker
):
    tokens = verified_broker["tokens"]
    _create(client, tokens, governorate="Cairo", city="New Cairo")
    _create(client, tokens, governorate="Cairo", city="Nasr City")
    _create(client, tokens, governorate="Alexandria", city="Smouha")

    res = client.get("/market/filters",
                     headers=bearer(buyer["tokens"])).get_json()
    assert res["governorates"] == ["Alexandria", "Cairo"]
    assert set(res["cities_by_governorate"]["Cairo"]) == {"Nasr City", "New Cairo"}
    assert res["cities_by_governorate"]["Alexandria"] == ["Smouha"]


def test_market_endpoints_require_auth(client):
    assert client.get("/market/price-per-m2").status_code == 401
    assert client.get("/market/price-per-m2/trend").status_code == 401
    assert client.get("/market/filters").status_code == 401


def test_expired_active_listing_excluded_from_market(app, client, buyer, verified_broker):
    """Regression: market aggregated stale ACTIVE listings that would be
    hidden from the buyer feed."""
    tokens = verified_broker["tokens"]
    _create(client, tokens, price_egp="1000000", area_m2="100")

    # Backdate the listing past the 30-day auto-expire window while
    # keeping status=ACTIVE (broker just walked away without hiding it).
    with app.app_context():
        listing = Listing.query.first()
        listing.last_confirmed_at = datetime.now(timezone.utc) - timedelta(days=45)
        db.session.commit()

    res = client.get("/market/price-per-m2",
                     headers=bearer(buyer["tokens"])).get_json()
    assert res["count"] == 0


def test_sold_listing_included_even_when_old(app, client, buyer, verified_broker):
    """SOLD prices remain valid market signal regardless of age."""
    tokens = verified_broker["tokens"]
    a = _create(client, tokens, price_egp="1000000", area_m2="100").get_json()
    with app.app_context():
        listing = db.session.get(Listing, a["id"])
        listing.status = ListingStatus.SOLD
        listing.last_confirmed_at = datetime.now(timezone.utc) - timedelta(days=120)
        db.session.commit()
    res = client.get("/market/price-per-m2",
                     headers=bearer(buyer["tokens"])).get_json()
    assert res["count"] == 1


def test_trend_months_one_returns_at_most_one_bucket(app, client, buyer, verified_broker):
    """Regression: 32*months approximation overshot and returned extra
    buckets when months=1."""
    tokens = verified_broker["tokens"]
    a = _create(client, tokens, price_egp="1000000", area_m2="100").get_json()
    b = _create(client, tokens, price_egp="2000000", area_m2="100").get_json()

    # Put both in the CURRENT month so we should get exactly one bucket.
    with app.app_context():
        now = datetime.now(timezone.utc)
        for lid in (a["id"], b["id"]):
            db.session.get(Listing, lid).created_at = now
        db.session.commit()

    # Also add a listing 2 months back — must NOT appear when months=1.
    c = _create(client, tokens, price_egp="3000000", area_m2="100").get_json()
    d = _create(client, tokens, price_egp="4000000", area_m2="100").get_json()
    with app.app_context():
        two_months_ago = datetime.now(timezone.utc).replace(day=15) - timedelta(days=65)
        for lid in (c["id"], d["id"]):
            db.session.get(Listing, lid).created_at = two_months_ago
        db.session.commit()

    res = client.get("/market/price-per-m2/trend?months=1",
                     headers=bearer(buyer["tokens"])).get_json()
    assert len(res) <= 1
    if res:
        current_key = datetime.now(timezone.utc).strftime("%Y-%m")
        assert res[0]["month"] == current_key
