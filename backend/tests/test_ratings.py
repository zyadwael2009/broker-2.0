"""Phase 11 — broker ratings."""
from __future__ import annotations

from tests.conftest import bearer


def _valid_listing() -> dict:
    return {
        "title": "Ratings test listing",
        "price_egp": "1000000", "area_m2": "80",
        "governorate": "Cairo", "city": "Cairo",
        "lat": 30.05, "lng": 31.24,
        "property_type": "apartment",
    }


def _create_listing(client, tokens):
    return client.post("/listings", json=_valid_listing(), headers=bearer(tokens))


def _start_thread(client, buyer, listing_id):
    return client.post("/threads", json={"listing_id": listing_id},
                       headers=bearer(buyer["tokens"]))


def _submit_rating(client, tokens, broker_id, stars, note=None):
    body = {"stars": stars}
    if note is not None:
        body["note"] = note
    return client.post(f"/brokers/{broker_id}/ratings",
                       json=body, headers=bearer(tokens))


# ── happy path ────────────────────────────────────────────────────────

def test_buyer_can_rate_broker_after_messaging(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)

    broker_id = verified_broker["user"]["id"]
    r = _submit_rating(client, buyer["tokens"], broker_id, 5, "Great broker")
    assert r.status_code == 201
    body = r.get_json()
    assert body["stars"] == 5
    assert body["note"] == "Great broker"
    # Rater's surname is masked to a single initial + period.
    # Fixture registers the buyer as "Buyer One" → display "Buyer O.".
    display = body["rater_display"]
    assert display.endswith(".")
    assert "One" not in display    # full surname not exposed


def test_rating_is_upsert(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]

    r1 = _submit_rating(client, buyer["tokens"], broker_id, 3)
    r2 = _submit_rating(client, buyer["tokens"], broker_id, 5, "changed my mind")
    assert r1.status_code == 201
    assert r2.status_code == 200          # update, not create
    assert r2.get_json()["stars"] == 5

    # Only one row for this pair.
    lst = client.get(f"/brokers/{broker_id}/ratings",
                     headers=bearer(buyer["tokens"])).get_json()
    assert lst["aggregate"]["count"] == 1
    assert lst["aggregate"]["avg"] == 5.0


def test_delete_own_rating(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]
    _submit_rating(client, buyer["tokens"], broker_id, 4)

    r = client.delete(f"/brokers/{broker_id}/ratings/mine",
                      headers=bearer(buyer["tokens"]))
    assert r.status_code == 204
    lst = client.get(f"/brokers/{broker_id}/ratings",
                     headers=bearer(buyer["tokens"])).get_json()
    assert lst["aggregate"]["count"] == 0


def test_aggregate_math(client, buyer, verified_broker):
    """Two ratings → avg + distribution correct in the payload."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]
    _submit_rating(client, buyer["tokens"], broker_id, 4)

    # Second buyer with their own thread + rating.
    other = client.post("/auth/register", json={
        "phone": "01044440000", "password": "supersecret",
        "full_name": "Second Buyer", "role": "buyer",
    }).get_json()
    _start_thread(client, other, lid)
    _submit_rating(client, other["tokens"], broker_id, 5)

    body = client.get(f"/brokers/{broker_id}/ratings",
                      headers=bearer(buyer["tokens"])).get_json()
    assert body["aggregate"]["count"] == 2
    assert body["aggregate"]["avg"] == 4.5
    assert body["aggregate"]["distribution"]["5"] == 1
    assert body["aggregate"]["distribution"]["4"] == 1


# ── gate + validation ────────────────────────────────────────────────

def test_cannot_rate_without_thread(client, buyer, verified_broker):
    broker_id = verified_broker["user"]["id"]
    r = _submit_rating(client, buyer["tokens"], broker_id, 5)
    assert r.status_code == 403


def test_cannot_rate_yourself(client, verified_broker):
    """Broker tries to rate themselves — 400."""
    broker_id = verified_broker["user"]["id"]
    r = _submit_rating(client, verified_broker["tokens"], broker_id, 5)
    assert r.status_code == 400


def test_stars_out_of_range(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]

    assert _submit_rating(client, buyer["tokens"], broker_id, 6).status_code == 400
    assert _submit_rating(client, buyer["tokens"], broker_id, 0).status_code == 400


def test_note_too_long(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]
    r = _submit_rating(client, buyer["tokens"], broker_id, 3, "a" * 501)
    assert r.status_code == 400


# ── aggregate embedded in broker payloads ───────────────────────────

def test_broker_public_profile_includes_rating(
    client, buyer, verified_broker
):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]
    _submit_rating(client, buyer["tokens"], broker_id, 4)

    prof = client.get(f"/brokers/{broker_id}",
                      headers=bearer(buyer["tokens"])).get_json()
    assert prof["rating"]["count"] == 1
    assert prof["rating"]["avg"] == 4.0


def test_listings_feed_broker_includes_rating(
    client, buyer, verified_broker
):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]
    _submit_rating(client, buyer["tokens"], broker_id, 5)

    feed = client.get("/listings", headers=bearer(buyer["tokens"])).get_json()
    assert feed[0]["broker"]["rating"]["count"] == 1
    assert feed[0]["broker"]["rating"]["avg"] == 5.0


# ── my-rating helper ────────────────────────────────────────────────

def test_get_my_rating_none_and_present(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _start_thread(client, buyer, lid)
    broker_id = verified_broker["user"]["id"]

    r = client.get(f"/brokers/{broker_id}/ratings/mine",
                   headers=bearer(buyer["tokens"]))
    assert r.status_code == 200
    assert r.get_json() is None

    _submit_rating(client, buyer["tokens"], broker_id, 3)
    r = client.get(f"/brokers/{broker_id}/ratings/mine",
                   headers=bearer(buyer["tokens"]))
    assert r.status_code == 200
    assert r.get_json()["stars"] == 3
