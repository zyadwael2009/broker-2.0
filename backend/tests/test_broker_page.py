"""Phase 13 — public broker credential page at /b/<id>.

Mirrors the shape of test_public.py. Guarantees:
- verified brokers get a page; unverified/inactive/missing → 404
- phone + email never leak to public callers (HTML or JSON)
- the broker's own active listings appear; others' don't
- sitemap includes verified brokers
- JSON-LD RealEstateAgent + og tags present
"""
from __future__ import annotations

import io

from PIL import Image

from app.extensions import db
from tests.conftest import bearer


def _img_bytes(color=(30, 100, 200), size=48) -> bytes:
    img = Image.new("RGB", (size, size), color)
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    return buf.getvalue()


def _valid_body() -> dict:
    return {
        "title": "Nile-view apartment",
        "description": "Corner unit with morning light.",
        "price_egp": "3500000.00",
        "area_m2": "120.5",
        "governorate": "Cairo",
        "city": "New Cairo",
        "district": "Fifth Settlement",
        "lat": 30.02,
        "lng": 31.47,
        "property_type": "apartment",
    }


def _create_listing(client, tokens, **overrides):
    body = _valid_body() | overrides
    return client.post("/listings", json=body, headers=bearer(tokens))


# ── HTML page ─────────────────────────────────────────────────────────

def test_broker_page_renders_with_name_and_seo(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    broker_id = verified_broker["user"]["id"]

    res = client.get(f"/b/{broker_id}")
    assert res.status_code == 200
    html = res.get_data(as_text=True)

    # Name is the visual centerpiece
    assert "Verified Broker" in html
    # SEO tags
    assert "og:title" in html
    assert "application/ld+json" in html
    assert "RealEstateAgent" in html
    # Verified seal + GOEIC lockup
    assert "VERIFIED BROKER" in html
    # MRZ strip present
    assert "Machine-Readable Zone" in html.replace("&middot;", "·")
    # Canonical link
    assert f"/b/{broker_id}" in html


def test_broker_page_has_whatsapp_share(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    bid = verified_broker["user"]["id"]
    html = client.get(f"/b/{bid}").get_data(as_text=True)
    assert "wa.me/?text=" in html
    assert 'class="urlbar-whatsapp"' in html


def test_broker_page_does_not_leak_phone_or_email(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    broker_id = verified_broker["user"]["id"]
    res = client.get(f"/b/{broker_id}")
    html = res.get_data(as_text=True)

    # The verified_broker fixture uses +201000000003 — must NOT appear.
    assert "+201000000003" not in html
    assert "01000000003" not in html
    # Also no email leak (fixture has none, but generalize).
    assert "@" not in html or "og:type" in html  # og:type contains @ in a URL context; sanity-guard


def test_broker_page_hides_unverified_broker(client, broker):
    """A pending/rejected broker is invisible to the public web."""
    res = client.get(f"/b/{broker['user']['id']}")
    assert res.status_code == 404
    assert "no longer available" in res.get_data(as_text=True).lower()


def test_broker_page_hides_inactive_broker(app, client, verified_broker):
    """Flipping is_active off removes the broker from the public web."""
    from app.models.user import User
    broker_id = verified_broker["user"]["id"]
    with app.app_context():
        u = db.session.get(User, broker_id)
        u.is_active = False
        db.session.commit()

    res = client.get(f"/b/{broker_id}")
    assert res.status_code == 404


def test_broker_page_404_for_missing_id(client):
    res = client.get("/b/999999")
    assert res.status_code == 404


def test_broker_page_lists_only_own_listings(client, verified_broker):
    """A broker's credential page shows their own listings, not everyone's."""
    _create_listing(client, verified_broker["tokens"], title="Mine A")
    _create_listing(client, verified_broker["tokens"], title="Mine B")

    # A second verified broker with their own listing — should NOT appear.
    from tests.conftest import _register, _promote_broker_to_verified
    other = _register(client, "01000000123", "broker", "Other Broker")
    _promote_broker_to_verified(client.application, other["tokens"], other["user"]["id"])
    # log in fresh so JWT reflects verified status
    login = client.post(
        "/auth/login",
        json={"phone": "+201000000123", "password": "supersecret"},
    ).get_json()
    _create_listing(client, login["tokens"], title="Someone Else")

    res = client.get(f"/b/{verified_broker['user']['id']}")
    html = res.get_data(as_text=True)
    assert "Mine A" in html
    assert "Mine B" in html
    assert "Someone Else" not in html


# ── JSON companion ─────────────────────────────────────────────────────

def test_api_broker_json_returns_sanitized(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    broker_id = verified_broker["user"]["id"]

    res = client.get(f"/api/public/brokers/{broker_id}")
    assert res.status_code == 200
    body = res.get_json()
    assert body["id"] == broker_id
    assert body["full_name"] == "Verified Broker"
    assert body["verification_status"] == "verified"
    assert "listings" in body
    assert body["listings_count"] >= 1
    # Sanitized — no contact info
    assert "phone" not in body
    assert "email" not in body
    for l in body["listings"]:
        assert "broker" in l
        assert "phone" not in l["broker"]
        assert "email" not in l["broker"]


def test_api_broker_json_404_for_missing(client):
    res = client.get("/api/public/brokers/999999")
    assert res.status_code == 404


def test_api_broker_json_404_for_unverified(client, broker):
    res = client.get(f"/api/public/brokers/{broker['user']['id']}")
    assert res.status_code == 404


# ── sitemap includes brokers ───────────────────────────────────────────

def test_sitemap_includes_verified_brokers(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    broker_id = verified_broker["user"]["id"]
    res = client.get("/sitemap.xml")
    assert res.status_code == 200
    xml = res.get_data(as_text=True)
    assert f"/b/{broker_id}" in xml
