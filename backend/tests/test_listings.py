"""Phase 3: listings CRUD, photo upload, auto-expire, duplicate detection."""
from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone

import pytest
from PIL import Image

from app.extensions import db
from app.models.listing import Listing
from tests.conftest import bearer


# ── helpers ────────────────────────────────────────────────────────────

def _img_bytes(color: tuple[int, int, int] = (200, 30, 30), size: int = 64) -> bytes:
    """Produce a valid JPEG so PIL/imagehash accept it."""
    img = Image.new("RGB", (size, size), color)
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    return buf.getvalue()


def _valid_body() -> dict:
    return {
        "title": "Nile-view apartment",
        "description": "Corner unit, morning light.",
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


def _upload_photo(client, tokens, listing_id: int, img: bytes | None = None):
    return client.post(
        f"/listings/{listing_id}/photos",
        headers=bearer(tokens),
        data={"photo": (io.BytesIO(img or _img_bytes()), "photo.jpg")},
        content_type="multipart/form-data",
    )


# ── create + read ──────────────────────────────────────────────────────

def test_verified_broker_can_create_listing(client, verified_broker):
    res = _create_listing(client, verified_broker["tokens"])
    assert res.status_code == 201, res.get_json()
    body = res.get_json()
    assert body["title"] == "Nile-view apartment"
    assert body["photos"] == []
    assert body["is_expired"] is False


def test_unverified_broker_blocked_from_create(client, broker):
    res = _create_listing(client, broker["tokens"])
    assert res.status_code == 403
    assert "verified" in res.get_json()["error"].lower()


def test_buyer_blocked_from_create(client, buyer):
    res = _create_listing(client, buyer["tokens"])
    assert res.status_code == 403


def test_create_requires_lat_lng(client, verified_broker):
    body = _valid_body()
    del body["lat"]
    res = client.post("/listings", json=body, headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 400


def test_public_list_visible_to_buyer(client, buyer, verified_broker):
    _create_listing(client, verified_broker["tokens"])
    res = client.get("/listings", headers=bearer(buyer["tokens"]))
    assert res.status_code == 200
    items = res.get_json()
    assert len(items) == 1
    assert items[0]["broker"]["verification_status"] == "verified"


def test_filters_by_governorate(client, buyer, verified_broker):
    _create_listing(client, verified_broker["tokens"], governorate="Cairo")
    _create_listing(client, verified_broker["tokens"], governorate="Alexandria")

    r_cairo = client.get(
        "/listings?governorate=Cairo", headers=bearer(buyer["tokens"])
    )
    assert len(r_cairo.get_json()) == 1
    assert r_cairo.get_json()[0]["governorate"] == "Cairo"


# ── Phase A1: richer fields + filters ──────────────────────────────────

def test_create_with_richer_fields(client, verified_broker):
    body = _valid_body() | {
        "listing_kind": "rent",
        "bedrooms": 3,
        "bathrooms": 2,
        "floor_number": 5,
        "is_furnished": True,
        "compound_name": "El Rehab",
        "delivery_status": "ready",
    }
    res = client.post("/listings", json=body, headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 201, res.get_json()
    payload = res.get_json()
    assert payload["listing_kind"] == "rent"
    assert payload["bedrooms"] == 3
    assert payload["bathrooms"] == 2
    assert payload["floor_number"] == 5
    assert payload["is_furnished"] is True
    assert payload["compound_name"] == "El Rehab"
    assert payload["delivery_status"] == "ready"


def test_create_defaults_to_sale_when_kind_omitted(client, verified_broker):
    res = client.post(
        "/listings", json=_valid_body(), headers=bearer(verified_broker["tokens"])
    )
    assert res.status_code == 201
    assert res.get_json()["listing_kind"] == "sale"


def test_filters_by_listing_kind(client, buyer, verified_broker):
    _create_listing(client, verified_broker["tokens"], listing_kind="sale", title="Buy me")
    _create_listing(client, verified_broker["tokens"], listing_kind="rent", title="Rent me")

    r_rent = client.get("/listings?kind=rent", headers=bearer(buyer["tokens"]))
    assert r_rent.status_code == 200
    rows = r_rent.get_json()
    assert len(rows) == 1
    assert rows[0]["title"] == "Rent me"
    assert rows[0]["listing_kind"] == "rent"


def test_filters_by_bedrooms_min(client, buyer, verified_broker):
    _create_listing(client, verified_broker["tokens"], bedrooms=1, title="Small studio")
    _create_listing(client, verified_broker["tokens"], bedrooms=3, title="Medium apartment")
    _create_listing(client, verified_broker["tokens"], bedrooms=5, title="Large villa")

    r3 = client.get("/listings?bedrooms_min=3", headers=bearer(buyer["tokens"]))
    titles = [x["title"] for x in r3.get_json()]
    assert "Small studio" not in titles
    assert "Medium apartment" in titles
    assert "Large villa" in titles


def test_filters_by_compound(client, buyer, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    compound_name="Palm Hills", title="Alpha listing")
    _create_listing(client, verified_broker["tokens"],
                    compound_name="Marassi", title="Beta listing")

    r = client.get(
        "/listings", query_string={"compound": "Palm Hills"},
        headers=bearer(buyer["tokens"]),
    )
    rows = r.get_json()
    assert len(rows) == 1
    assert rows[0]["title"] == "Alpha listing"


def test_filters_furnished_tri_state(client, buyer, verified_broker):
    _create_listing(client, verified_broker["tokens"],
                    is_furnished=True, title="Furnished unit")
    _create_listing(client, verified_broker["tokens"],
                    is_furnished=False, title="Unfurnished unit")
    _create_listing(client, verified_broker["tokens"],
                    title="Unspecified unit")  # is_furnished not set

    r_f = client.get("/listings?furnished=true", headers=bearer(buyer["tokens"]))
    assert [x["title"] for x in r_f.get_json()] == ["Furnished unit"]

    r_u = client.get("/listings?furnished=false", headers=bearer(buyer["tokens"]))
    assert [x["title"] for x in r_u.get_json()] == ["Unfurnished unit"]


def test_update_can_set_new_fields(client, verified_broker):
    r = client.post(
        "/listings", json=_valid_body(), headers=bearer(verified_broker["tokens"])
    )
    lid = r.get_json()["id"]
    res = client.patch(
        f"/listings/{lid}",
        json={"bedrooms": 4, "compound_name": "Uptown Cairo", "listing_kind": "rent"},
        headers=bearer(verified_broker["tokens"]),
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["bedrooms"] == 4
    assert body["compound_name"] == "Uptown Cairo"
    assert body["listing_kind"] == "rent"


# ── auto-expire ────────────────────────────────────────────────────────

def test_expired_listing_hidden_from_public_list(app, client, buyer, verified_broker):
    create = _create_listing(client, verified_broker["tokens"])
    listing_id = create.get_json()["id"]

    # Backdate last_confirmed_at past the TTL.
    with app.app_context():
        listing = db.session.get(Listing, listing_id)
        listing.last_confirmed_at = datetime.now(timezone.utc) - timedelta(days=31)
        db.session.commit()

    res = client.get("/listings", headers=bearer(buyer["tokens"]))
    assert res.get_json() == []


def test_confirm_resets_expiry(app, client, verified_broker, buyer):
    create = _create_listing(client, verified_broker["tokens"])
    listing_id = create.get_json()["id"]
    with app.app_context():
        listing = db.session.get(Listing, listing_id)
        listing.last_confirmed_at = datetime.now(timezone.utc) - timedelta(days=31)
        db.session.commit()

    # Hidden from public
    assert client.get("/listings", headers=bearer(buyer["tokens"])).get_json() == []

    # Broker taps "still available"
    res = client.post(
        f"/listings/{listing_id}/confirm",
        headers=bearer(verified_broker["tokens"]),
    )
    assert res.status_code == 200

    # Now visible again
    assert len(client.get("/listings", headers=bearer(buyer["tokens"])).get_json()) == 1


def test_expired_listing_still_in_my_listings(app, client, verified_broker):
    create = _create_listing(client, verified_broker["tokens"])
    listing_id = create.get_json()["id"]
    with app.app_context():
        listing = db.session.get(Listing, listing_id)
        listing.last_confirmed_at = datetime.now(timezone.utc) - timedelta(days=31)
        db.session.commit()

    res = client.get("/listings/mine", headers=bearer(verified_broker["tokens"]))
    items = res.get_json()
    assert len(items) == 1
    assert items[0]["is_expired"] is True


# ── photos + duplicate detection ───────────────────────────────────────

def test_upload_photo(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = _upload_photo(client, verified_broker["tokens"], lid)
    assert res.status_code == 201, res.get_json()
    assert res.get_json()["url"].startswith("/files/listing-photos/")


def test_upload_rejects_non_image(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.post(
        f"/listings/{lid}/photos",
        headers=bearer(verified_broker["tokens"]),
        data={"photo": (io.BytesIO(b"not an image"), "photo.jpg")},
        content_type="multipart/form-data",
    )
    # Extension passes; pHash decode fails.
    assert res.status_code == 400


def test_duplicate_photo_flags_listing(client, verified_broker, admin):
    """Uploading the same photo to a second listing should silently flag it."""
    tokens = verified_broker["tokens"]
    lid_a = _create_listing(client, tokens).get_json()["id"]
    lid_b = _create_listing(client, tokens, title="Second listing").get_json()["id"]

    dup_bytes = _img_bytes(color=(50, 200, 50))
    r1 = _upload_photo(client, tokens, lid_a, img=dup_bytes)
    r2 = _upload_photo(client, tokens, lid_b, img=dup_bytes)
    assert r1.status_code == 201
    assert r2.status_code == 201  # silent — no error surfaced to broker

    # Listing B should now show as flagged.
    detail = client.get(f"/listings/{lid_b}", headers=bearer(tokens)).get_json()
    # Public listing dict doesn't expose the flag; admin queue does.
    admin_q = client.get(
        "/admin/listings/flagged", headers=bearer(admin["tokens"])
    )
    flagged = admin_q.get_json()
    assert any(l["id"] == lid_b for l in flagged)
    match = next(l for l in flagged if l["id"] == lid_b)
    assert match["duplicate_of_listing_id"] == lid_a


def test_admin_can_unflag(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid_a = _create_listing(client, tokens).get_json()["id"]
    lid_b = _create_listing(client, tokens, title="Listing B").get_json()["id"]
    dup = _img_bytes(color=(20, 20, 200))
    _upload_photo(client, tokens, lid_a, img=dup)
    _upload_photo(client, tokens, lid_b, img=dup)

    res = client.post(
        f"/admin/listings/{lid_b}/unflag", headers=bearer(admin["tokens"])
    )
    assert res.status_code == 200
    assert res.get_json()["duplicate_suspected"] is False

    # Flagged queue is now empty
    empty = client.get(
        "/admin/listings/flagged", headers=bearer(admin["tokens"])
    ).get_json()
    assert all(l["id"] != lid_b for l in empty)


def test_delete_photo(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    up = _upload_photo(client, verified_broker["tokens"], lid)
    photo_id = up.get_json()["id"]
    res = client.delete(
        f"/listings/{lid}/photos/{photo_id}",
        headers=bearer(verified_broker["tokens"]),
    )
    assert res.status_code == 204


# ── update + delete ────────────────────────────────────────────────────

def test_owner_can_update(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.patch(
        f"/listings/{lid}",
        json={"price_egp": "3200000.00"},
        headers=bearer(verified_broker["tokens"]),
    )
    assert res.status_code == 200
    assert res.get_json()["price_egp"] == "3200000.00"


def test_non_owner_cannot_update(client, verified_broker, buyer):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.patch(
        f"/listings/{lid}",
        json={"price_egp": "1"},
        headers=bearer(buyer["tokens"]),
    )
    assert res.status_code == 403


def test_owner_can_delete(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.delete(
        f"/listings/{lid}", headers=bearer(verified_broker["tokens"])
    )
    assert res.status_code == 204


def test_admin_can_delete_any_listing(client, verified_broker, admin):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.delete(f"/listings/{lid}", headers=bearer(admin["tokens"]))
    assert res.status_code == 204


# ── audit fix regression tests ─────────────────────────────────────────

def test_broker_demoted_to_rejected_cannot_mutate(app, client, verified_broker):
    """Fix from audit: update/confirm/upload/delete_photo must re-check
    verification, not just ownership."""
    from app.models.broker_profile import BrokerProfile, VerificationStatus
    from app.extensions import db as _db

    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    up = _upload_photo(client, verified_broker["tokens"], lid)
    photo_id = up.get_json()["id"]

    # Admin flips them to rejected.
    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.REJECTED
        _db.session.commit()

    tokens = verified_broker["tokens"]
    assert client.patch(f"/listings/{lid}", json={"title": "sneaky edit"},
                        headers=bearer(tokens)).status_code == 403
    assert client.post(f"/listings/{lid}/confirm",
                       headers=bearer(tokens)).status_code == 403
    assert _upload_photo(client, tokens, lid).status_code == 403
    assert client.delete(f"/listings/{lid}/photos/{photo_id}",
                         headers=bearer(tokens)).status_code == 403


def test_list_listings_hides_rejected_broker_listings(app, client, buyer, verified_broker):
    """Fix from audit: /listings must exclude listings owned by
    non-verified brokers."""
    from app.models.broker_profile import BrokerProfile, VerificationStatus
    from app.extensions import db as _db

    _create_listing(client, verified_broker["tokens"])
    # Still visible while broker is verified.
    assert len(client.get("/listings", headers=bearer(buyer["tokens"])).get_json()) == 1

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.REJECTED
        _db.session.commit()

    assert client.get("/listings", headers=bearer(buyer["tokens"])).get_json() == []


def test_update_status_active_is_rejected(client, verified_broker):
    """Fix from audit: PATCH can only set sold/hidden, not re-activate."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]

    # active is not allowed — must use /confirm
    res = client.patch(f"/listings/{lid}", json={"status": "active"},
                       headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 400

    # sold is allowed
    res = client.patch(f"/listings/{lid}", json={"status": "sold"},
                       headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 200
    assert res.get_json()["status"] == "sold"


def test_min_price_invalid_returns_400_not_500(client, buyer):
    res = client.get("/listings?min_price=not-a-number",
                     headers=bearer(buyer["tokens"]))
    assert res.status_code == 400


def test_confirm_reactivates_sold_listing(app, client, verified_broker):
    """Regression: SOLD/HIDDEN listings had no reactivate path."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    client.patch(f"/listings/{lid}", json={"status": "sold"},
                 headers=bearer(verified_broker["tokens"]))
    res = client.post(f"/listings/{lid}/confirm",
                      headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 200
    assert res.get_json()["status"] == "active"


def test_sold_listing_has_no_expiry(client, verified_broker):
    """Regression: SOLD listings rendered as 'Expired' after 30 days."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    client.patch(f"/listings/{lid}", json={"status": "sold"},
                 headers=bearer(verified_broker["tokens"]))
    body = client.get(f"/listings/{lid}",
                      headers=bearer(verified_broker["tokens"])).get_json()
    assert body["is_expired"] is False
    assert body["expires_at"] is None
