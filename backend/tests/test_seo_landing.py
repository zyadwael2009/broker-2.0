"""Phase G3 — SEO location landing pages.

Covers:
 - /browse/<gov> renders when the gov has listings
 - /browse/<gov>/<city> renders for known cities
 - /browse/<gov>/<facet> for property-type and kind facets
 - unknown slugs 404
 - empty landings 404 (never index thin pages)
 - JSON-LD emits both BreadcrumbList and ItemList
 - sitemap includes only populated landings
 - slug helpers round-trip
"""
from __future__ import annotations

import io
import json
import re

from PIL import Image

from tests.conftest import bearer


def _img_bytes(color=(80, 40, 200), size=48) -> bytes:
    img = Image.new("RGB", (size, size), color)
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    return buf.getvalue()


def _valid_body() -> dict:
    return {
        "title": "Landing page test unit",
        "price_egp": "1500000.00",
        "area_m2": "90.0",
        "governorate": "Cairo",
        "city": "Nasr City",
        "lat": 30.05,
        "lng": 31.24,
        "property_type": "apartment",
    }


def _create_listing(client, tokens, **overrides):
    return client.post("/listings", json=_valid_body() | overrides,
                       headers=bearer(tokens))


# ── slug helpers unit test ────────────────────────────────────────────

def test_slugify_and_reverse_lookup():
    from app.geo import city_by_slug, gov_by_slug, slugify

    assert slugify("Nasr City") == "nasr-city"
    assert slugify("6th of October") == "6th-of-october"
    assert slugify("  Padded  ") == "padded"
    assert slugify("") == ""

    # gov_by_slug hits the canonical taxonomy.
    assert gov_by_slug("cairo")["en"] == "Cairo"
    assert gov_by_slug("CAIRO")["en"] == "Cairo"  # case-insensitive
    assert gov_by_slug("atlantis") is None

    # city_by_slug round-trip.
    assert city_by_slug("cairo", "nasr-city") == "Nasr City"
    assert city_by_slug("cairo", "not-a-city") is None
    assert city_by_slug("nonsense", "nasr-city") is None


# ── governorate landing ──────────────────────────────────────────────

def test_gov_landing_renders_with_listings(client, verified_broker):
    _create_listing(client, verified_broker["tokens"])

    r = client.get("/browse/cairo")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "Property in Cairo" in html
    # Breadcrumbs include the governorate.
    assert 'aria-label="Breadcrumb"' in html
    # Card for the listing shows up.
    assert "Landing page test unit" in html


def test_unknown_gov_slug_404(client):
    r = client.get("/browse/atlantis")
    assert r.status_code == 404


def test_empty_landing_404(client, verified_broker):
    """A valid governorate with no listings must 404 — thin pages
    are worse than no page for SEO."""
    # Broker exists but hasn't posted a single listing.
    r = client.get("/browse/aswan")
    assert r.status_code == 404


# ── city landing ─────────────────────────────────────────────────────

def test_city_landing_renders(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], city="Nasr City")

    r = client.get("/browse/cairo/nasr-city")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "Nasr City" in html
    assert "Property in Nasr City, Cairo" in html


def test_city_landing_only_matches_that_city(client, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    title="In Nasr City", city="Nasr City")
    _create_listing(client, verified_broker["tokens"],
                    title="In Maadi", city="Maadi")

    r = client.get("/browse/cairo/nasr-city")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "In Nasr City" in html
    assert "In Maadi" not in html


# ── facet landing ────────────────────────────────────────────────────

def test_facet_landing_property_type(client, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    title="An apartment", property_type="apartment")
    _create_listing(client, verified_broker["tokens"],
                    title="A villa", property_type="villa",
                    price_egp="8000000.00", area_m2="400.0")

    r = client.get("/browse/cairo/apartments")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "Apartments in Cairo" in html
    assert "An apartment" in html
    assert "A villa" not in html


def test_facet_landing_kind_for_rent(client, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    title="For rent one", listing_kind="rent")
    _create_listing(client, verified_broker["tokens"],
                    title="For sale one", listing_kind="sale")

    r = client.get("/browse/cairo/for-rent")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "For rent one" in html
    assert "For sale one" not in html


# ── JSON-LD ───────────────────────────────────────────────────────────

def test_landing_emits_breadcrumb_and_itemlist_jsonld(client, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    title="LD test unit", city="Nasr City")

    r = client.get("/browse/cairo/nasr-city")
    assert r.status_code == 200
    html = r.get_data(as_text=True)

    # Pull the JSON-LD script block. We emit ONE script whose body is a
    # JSON array of two objects (Breadcrumb + ItemList).
    m = re.search(
        r'<script[^>]*application/ld\+json[^>]*>\s*(\[.+?\])\s*</script>',
        html, re.DOTALL,
    )
    assert m is not None, "No JSON-LD script found"
    payload = json.loads(m.group(1))
    assert isinstance(payload, list) and len(payload) == 2
    types = {p.get("@type") for p in payload}
    assert types == {"BreadcrumbList", "ItemList"}
    # ItemList item count matches rendered listings (1).
    item_list = next(p for p in payload if p["@type"] == "ItemList")
    assert item_list["numberOfItems"] == 1
    # Breadcrumb runs Home → Browse → Cairo → Nasr City.
    breadcrumbs = next(p for p in payload if p["@type"] == "BreadcrumbList")
    names = [item["name"] for item in breadcrumbs["itemListElement"]]
    assert names == ["Home", "Browse", "Cairo", "Nasr City"]


# ── canonical + meta ─────────────────────────────────────────────────

def test_landing_sets_canonical_url(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], city="Nasr City")

    r = client.get("/browse/cairo/nasr-city")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    # rel="canonical" points at the pretty URL, not the query variant.
    assert 'rel="canonical"' in html
    assert "/browse/cairo/nasr-city" in html


# ── sitemap ───────────────────────────────────────────────────────────

def test_sitemap_includes_populated_landings_only(client, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    city="Nasr City")

    r = client.get("/sitemap.xml")
    assert r.status_code == 200
    xml = r.get_data(as_text=True)
    # Populated governorate landing is present.
    assert "/browse/cairo</loc>" in xml
    # Populated city landing is present.
    assert "/browse/cairo/nasr-city</loc>" in xml
    # Governorates with no listings are absent.
    assert "/browse/aswan</loc>" not in xml
    assert "/browse/aswan/" not in xml


def test_sitemap_omits_facet_when_no_matching_listings(client, verified_broker):
    """Facet URLs only appear when the facet actually has listings for
    that governorate — no soft-404s in the sitemap."""
    _create_listing(client, verified_broker["tokens"],
                    property_type="apartment", listing_kind="sale")

    r = client.get("/sitemap.xml")
    xml = r.get_data(as_text=True)
    # 'apartments' + 'for-sale' should appear for Cairo.
    assert "/browse/cairo/apartments</loc>" in xml
    assert "/browse/cairo/for-sale</loc>" in xml
    # But not 'villas' or 'for-rent' (no such listings exist).
    assert "/browse/cairo/villas</loc>" not in xml
    assert "/browse/cairo/for-rent</loc>" not in xml


# ── browse regression (partial extraction) ───────────────────────────

def test_browse_still_renders_after_card_partial_extraction(client, verified_broker):
    _create_listing(client, verified_broker["tokens"], title="Post-refactor card")

    r = client.get("/browse")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "Post-refactor card" in html
    # The include-based card still emits the same broker-check pill.
    assert "broker-check" in html
