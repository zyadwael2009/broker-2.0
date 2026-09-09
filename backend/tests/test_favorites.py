"""Phase 3 redesign: buyer favorites (heart on cards + Saved tab)."""
from __future__ import annotations

from app.extensions import db
from app.models.broker_profile import BrokerProfile, VerificationStatus
from tests.conftest import bearer


def _valid_body() -> dict:
    return {
        "title": "Nile-view apartment",
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
    res = client.post(
        "/listings", json=_valid_body() | overrides, headers=bearer(tokens)
    )
    assert res.status_code == 201, res.get_json()
    return res.get_json()["id"]


def test_save_then_list_then_unsave(client, verified_broker, buyer):
    listing_id = _create_listing(client, verified_broker["tokens"])
    h = bearer(buyer["tokens"])

    assert client.get("/favorites", headers=h).get_json() == []

    res = client.post(f"/favorites/{listing_id}", headers=h)
    assert res.status_code == 201
    assert res.get_json()["favorited"] is True

    saved = client.get("/favorites", headers=h).get_json()
    assert [l["id"] for l in saved] == [listing_id]
    assert saved[0]["title"] == "Nile-view apartment"

    ids = client.get("/favorites/ids", headers=h).get_json()
    assert ids["listing_ids"] == [listing_id]

    assert client.delete(f"/favorites/{listing_id}", headers=h).status_code == 204
    assert client.get("/favorites", headers=h).get_json() == []


def test_saving_twice_is_idempotent(client, verified_broker, buyer):
    listing_id = _create_listing(client, verified_broker["tokens"])
    h = bearer(buyer["tokens"])

    assert client.post(f"/favorites/{listing_id}", headers=h).status_code == 201
    # Second tap: still success, still exactly one row.
    assert client.post(f"/favorites/{listing_id}", headers=h).status_code == 200
    assert len(client.get("/favorites", headers=h).get_json()) == 1


def test_unsaving_something_never_saved_is_not_an_error(client, verified_broker, buyer):
    listing_id = _create_listing(client, verified_broker["tokens"])
    res = client.delete(f"/favorites/{listing_id}", headers=bearer(buyer["tokens"]))
    assert res.status_code == 204


def test_saving_a_missing_listing_404s(client, buyer):
    res = client.post("/favorites/999999", headers=bearer(buyer["tokens"]))
    assert res.status_code == 404


def test_favorites_require_auth(client):
    assert client.get("/favorites").status_code == 401


def test_favorites_are_per_user(client, verified_broker, buyer):
    """One buyer's saves never leak into another account's Saved tab."""
    listing_id = _create_listing(client, verified_broker["tokens"])
    client.post(f"/favorites/{listing_id}", headers=bearer(buyer["tokens"]))

    other = client.post(
        "/auth/register",
        json={
            "phone": "01000000077",
            "password": "supersecret",
            "full_name": "Other Buyer",
            "role": "buyer",
        },
    ).get_json()
    assert client.get("/favorites", headers=bearer(other["tokens"])).get_json() == []


def test_saved_listing_hidden_when_broker_loses_verification(
    app, client, verified_broker, buyer
):
    """Saved runs through the same trust gate as browse — but the row
    survives, so re-verifying brings the save back."""
    listing_id = _create_listing(client, verified_broker["tokens"])
    h = bearer(buyer["tokens"])
    client.post(f"/favorites/{listing_id}", headers=h)

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.PENDING
        db.session.commit()

    assert client.get("/favorites", headers=h).get_json() == []
    # The save itself is untouched.
    assert client.get("/favorites/ids", headers=h).get_json()["listing_ids"] == [
        listing_id
    ]

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.VERIFIED
        db.session.commit()

    assert len(client.get("/favorites", headers=h).get_json()) == 1
