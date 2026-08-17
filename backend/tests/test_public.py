"""Phase 12: public web view (SEO). Tests /l/<id>, /browse, sitemap,
/api/public/*, and the anonymous-broker sanitization."""
from __future__ import annotations

import io

import pytest
from PIL import Image

from tests.conftest import bearer


def _img_bytes(color: tuple[int, int, int] = (30, 100, 200), size: int = 64) -> bytes:
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


def _upload_photo(client, tokens, listing_id: int) -> None:
    res = client.post(
        f"/listings/{listing_id}/photos",
        headers=bearer(tokens),
        data={"photo": (io.BytesIO(_img_bytes()), "photo.jpg")},
        content_type="multipart/form-data",
    )
    assert res.status_code == 201, res.get_json()


# ── JSON endpoints ─────────────────────────────────────────────────────

def test_public_listings_json_no_auth_required(client, verified_broker):
    res = _create_listing(client, verified_broker["tokens"])
    assert res.status_code == 201

    # Plain GET, no bearer token.
    res = client.get("/api/public/listings")
    assert res.status_code == 200
    rows = res.get_json()
    assert isinstance(rows, list)
    assert len(rows) == 1
    assert rows[0]["title"] == "Nile-view apartment"


def test_public_listings_strips_broker_phone_and_email(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    res = client.get("/api/public/listings")
    body = res.get_json()[0]
    assert "broker" in body
    b = body["broker"]
    # Full name and verification status are OK to expose; contact isn't.
    assert "full_name" in b
    assert "verification_status" in b
    assert "phone" not in b
    assert "email" not in b


def test_public_listings_hides_unverified_broker(client, broker, verified_broker):
    # Unverified broker's listing is blocked upstream — we can't POST one
    # via /listings. Instead we insert directly and confirm the public
    # feed also filters it out.
    from app.extensions import db
    from app.models.listing import Listing, ListingStatus, PropertyType
    from datetime import datetime, timezone

    # Verified broker creates one — should show.
    _create_listing(client, verified_broker["tokens"], title="Should show")

    # Unverified broker gets a listing inserted directly.
    listing = Listing(
        broker_id=broker["user"]["id"],
        title="Should be hidden",
        price_egp=1_000_000,
        area_m2=100,
        governorate="Cairo",
        city="Nasr City",
        lat=30.05,
        lng=31.35,
        property_type=PropertyType.APARTMENT,
        status=ListingStatus.ACTIVE,
        last_confirmed_at=datetime.now(timezone.utc),
    )
    db.session.add(listing)
    db.session.commit()

    res = client.get("/api/public/listings")
    titles = [r["title"] for r in res.get_json()]
    assert "Should show" in titles
    assert "Should be hidden" not in titles


def test_public_listing_detail_json(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"])
    lid = r.get_json()["id"]
    res = client.get(f"/api/public/listings/{lid}")
    assert res.status_code == 200
    body = res.get_json()
    assert body["id"] == lid
    assert "phone" not in body["broker"]


def test_public_listing_detail_404(client):
    res = client.get("/api/public/listings/999999")
    assert res.status_code == 404


# ── HTML pages ─────────────────────────────────────────────────────────

def test_home_page_renders(client):
    res = client.get("/")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    # Home page is broker-first — pitches brokers, not buyers.
    assert "Wasit" in html
    assert "og:site_name" in html
    # The broker-facing hero + secondary buyer CTA are both present.
    assert "Prove you" in html   # "Prove you're real"
    assert "/browse" in html      # secondary link for buyers


def test_for_brokers_page_renders(client, verified_broker):
    """Tier 2 sales page — the deep pitch for brokers."""
    res = client.get("/for-brokers")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    # Hero + all three main sections present
    assert "Verified beats unverified" in html
    assert "How it works" in html
    assert "What verification unlocks" in html
    assert "Common questions" in html
    # Social proof reflects the seeded verified broker
    assert "verified broker" in html.lower()
    # Canonical link + og tags
    assert "/for-brokers" in html
    assert "og:title" in html


def test_for_brokers_page_renders_with_zero_brokers(client):
    """Fresh install has no brokers yet — the social-proof line should
    just be omitted, not throw."""
    res = client.get("/for-brokers")
    assert res.status_code == 200


def test_sitemap_includes_for_brokers(client):
    res = client.get("/sitemap.xml")
    assert res.status_code == 200
    assert "/for-brokers" in res.get_data(as_text=True)


def test_browse_page_renders_and_lists(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], title="For sale in Nasr City")
    res = client.get("/browse")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "For sale in Nasr City" in html


def test_listing_page_has_seo_tags(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"])
    lid = r.get_json()["id"]
    res = client.get(f"/l/{lid}")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    # Title tag reflects the listing.
    assert "Nile-view apartment" in html
    # OpenGraph + JSON-LD present.
    assert "og:title" in html
    assert "application/ld+json" in html
    assert "schema.org" in html
    # Broker name shown, phone is NOT.
    assert "Verified Broker" in html
    assert "+201000000003" not in html


def test_listing_page_missing_returns_404(client):
    res = client.get("/l/999999")
    assert res.status_code == 404
    assert "no longer available" in res.get_data(as_text=True).lower()


# ── Phase A1: browse filters + listing page facts + map ────────────────

def test_browse_filters_by_kind(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], listing_kind="sale", title="Buy me")
    _create_listing(client, verified_broker["tokens"], listing_kind="rent", title="Rent me")

    res = client.get("/browse?kind=rent")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "Rent me" in html
    assert "Buy me" not in html


def test_browse_filters_by_bedrooms_min(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], bedrooms=1, title="Studio")
    _create_listing(client, verified_broker["tokens"], bedrooms=4, title="Big place")

    res = client.get("/browse?bedrooms_min=3")
    html = res.get_data(as_text=True)
    assert "Big place" in html
    assert "Studio" not in html


def test_api_public_listings_filters_by_kind(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], listing_kind="rent")
    _create_listing(client, verified_broker["tokens"], listing_kind="sale")

    res = client.get("/api/public/listings?kind=rent")
    assert res.status_code == 200
    rows = res.get_json()
    assert len(rows) == 1
    assert rows[0]["listing_kind"] == "rent"


def test_listing_page_renders_facts_when_fields_set(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"],
                        bedrooms=3, bathrooms=2, is_furnished=True)
    lid = r.get_json()["id"]
    res = client.get(f"/l/{lid}")
    html = res.get_data(as_text=True)
    assert "3 bed" in html
    assert "2 bath" in html
    assert "Furnished" in html


def test_listing_page_omits_facts_when_all_null(client, verified_broker):
    """A listing with none of the new fields set → no facts strip."""
    r = _create_listing(client, verified_broker["tokens"])
    lid = r.get_json()["id"]
    res = client.get(f"/l/{lid}")
    html = res.get_data(as_text=True)
    assert "listing-facts" not in html


def test_listing_page_shows_rent_prefix(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"], listing_kind="rent")
    lid = r.get_json()["id"]
    res = client.get(f"/l/{lid}")
    html = res.get_data(as_text=True)
    assert "For rent" in html
    assert "/ mo" in html


def test_listing_page_has_whatsapp_share(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"])
    lid = r.get_json()["id"]
    html = client.get(f"/l/{lid}").get_data(as_text=True)
    # wa.me URL emitted next to the URL pill
    assert "wa.me/?text=" in html
    assert 'class="urlbar-whatsapp"' in html


def test_listing_page_renders_map_when_lat_lng_present(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"])
    lid = r.get_json()["id"]
    res = client.get(f"/l/{lid}")
    html = res.get_data(as_text=True)
    assert "listing-map" in html
    assert "openstreetmap.org" in html


# ── Phase A3: legal + analytics ─────────────────────────────────────

def test_privacy_page_renders(client):
    res = client.get("/privacy")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "Privacy Policy" in html
    # Placeholder-draft banner so nobody mistakes it for final legal text.
    assert "Draft" in html


def test_terms_page_renders(client):
    res = client.get("/terms")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "Terms of Service" in html
    assert "Draft" in html


def test_contact_page_renders(client):
    res = client.get("/contact")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "Contact" in html


def test_sitemap_includes_legal_pages(client):
    xml = client.get("/sitemap.xml").get_data(as_text=True)
    for path in ("/privacy", "/terms", "/contact"):
        assert path in xml, f"{path} missing from sitemap"


def test_footer_links_to_legal_pages(client):
    html = client.get("/").get_data(as_text=True)
    for path in ("/privacy", "/terms", "/contact"):
        assert f'href="{path}"' in html


def test_plausible_snippet_only_when_configured(client, app):
    # Not configured by default → no plausible tag.
    html = client.get("/").get_data(as_text=True)
    assert "plausible.io" not in html
    # Set the flag → snippet appears.
    with app.app_context():
        app.config["PLAUSIBLE_DOMAIN"] = "demo.wasit.app"
        html = app.test_client().get("/").get_data(as_text=True)
        assert "plausible.io" in html
        assert 'data-domain="demo.wasit.app"' in html


# ── sitemap + robots ───────────────────────────────────────────────────

def test_sitemap_includes_active_listings(client, verified_broker):
    r = _create_listing(client, verified_broker["tokens"])
    lid = r.get_json()["id"]
    res = client.get("/sitemap.xml")
    assert res.status_code == 200
    xml = res.get_data(as_text=True)
    assert "<urlset" in xml
    assert f"/l/{lid}" in xml
    # Home + browse are always included.
    assert "/browse" in xml


def test_robots_txt_allows_all_and_points_at_sitemap(client):
    res = client.get("/robots.txt")
    assert res.status_code == 200
    body = res.get_data(as_text=True)
    assert "User-agent: *" in body
    assert "Sitemap:" in body
    assert "sitemap.xml" in body
    assert "Disallow: /files/" in body
