"""Phase 9 — buyer↔broker messaging."""
from __future__ import annotations

from tests.conftest import bearer


def _valid_listing() -> dict:
    return {
        "title": "Msg test listing",
        "price_egp": "1000000",
        "area_m2": "80",
        "governorate": "Cairo",
        "city": "Nasr City",
        "lat": 30.06,
        "lng": 31.34,
        "property_type": "apartment",
    }


def _make_listing(client, verified_broker) -> int:
    res = client.post("/listings", json=_valid_listing(),
                      headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 201, res.get_json()
    return res.get_json()["id"]


def _start_thread(client, buyer, listing_id: int):
    return client.post("/threads", json={"listing_id": listing_id},
                       headers=bearer(buyer["tokens"]))


def _send(client, tokens, thread_id: int, body: str):
    return client.post(f"/threads/{thread_id}/messages",
                       json={"body": body}, headers=bearer(tokens))


# ── thread creation ────────────────────────────────────────────────────

def test_buyer_creates_thread_on_listing(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    res = _start_thread(client, buyer, lid)
    assert res.status_code == 201
    body = res.get_json()
    assert body["listing_id"] == lid
    assert body["counterparty"]["role"] == "broker"
    assert body["counterparty"]["verification_status"] == "verified"
    assert body["unread_count"] == 0


def test_thread_creation_is_idempotent(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    r1 = _start_thread(client, buyer, lid)
    r2 = _start_thread(client, buyer, lid)
    assert r1.status_code == 201
    assert r2.status_code == 200      # already exists
    assert r1.get_json()["id"] == r2.get_json()["id"]


def test_only_buyer_can_start_thread(client, verified_broker):
    lid = _make_listing(client, verified_broker)
    res = client.post("/threads", json={"listing_id": lid},
                      headers=bearer(verified_broker["tokens"]))
    assert res.status_code == 403


def test_thread_creation_blocked_when_broker_unverified(app, client, buyer, verified_broker):
    from app.extensions import db as _db
    from app.models.broker_profile import BrokerProfile, VerificationStatus
    lid = _make_listing(client, verified_broker)

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.REJECTED
        _db.session.commit()

    res = _start_thread(client, buyer, lid)
    assert res.status_code == 403


# ── send + read ────────────────────────────────────────────────────────

def test_buyer_sends_message_and_broker_sees_unread(
    client, buyer, verified_broker
):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]

    r = _send(client, buyer["tokens"], tid, "Is this still available?")
    assert r.status_code == 201

    # Broker's inbox shows unread=1
    inbox = client.get("/threads", headers=bearer(verified_broker["tokens"])).get_json()
    assert len(inbox) == 1
    assert inbox[0]["unread_count"] == 1
    assert inbox[0]["last_message"] == "Is this still available?"

    # Buyer's inbox shows unread=0 (they wrote it)
    buyer_inbox = client.get("/threads", headers=bearer(buyer["tokens"])).get_json()
    assert buyer_inbox[0]["unread_count"] == 0


def test_broker_polling_marks_messages_read(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    _send(client, buyer["tokens"], tid, "hello")

    # Broker polls → messages are marked read.
    msgs = client.get(f"/threads/{tid}/messages",
                      headers=bearer(verified_broker["tokens"])).get_json()
    assert len(msgs) == 1
    assert msgs[0]["read_at"] is not None

    # Broker's inbox now shows 0 unread.
    inbox = client.get("/threads", headers=bearer(verified_broker["tokens"])).get_json()
    assert inbox[0]["unread_count"] == 0


def test_delta_since_returns_only_new(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    m1 = _send(client, buyer["tokens"], tid, "first").get_json()
    _send(client, buyer["tokens"], tid, "second")

    tail = client.get(f"/threads/{tid}/messages?since={m1['id']}",
                      headers=bearer(verified_broker["tokens"])).get_json()
    assert len(tail) == 1
    assert tail[0]["body"] == "second"


def test_explicit_read_endpoint(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    _send(client, buyer["tokens"], tid, "hello")

    r = client.post(f"/threads/{tid}/read", headers=bearer(verified_broker["tokens"]))
    assert r.status_code == 204

    inbox = client.get("/threads", headers=bearer(verified_broker["tokens"])).get_json()
    assert inbox[0]["unread_count"] == 0


# ── access control ────────────────────────────────────────────────────

def test_non_participant_cannot_read_thread(app, client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    _send(client, buyer["tokens"], tid, "private")

    # A third buyer signs up.
    other = client.post("/auth/register", json={
        "phone": "01088880000", "password": "supersecret",
        "full_name": "Nosy Buyer", "role": "buyer",
    }).get_json()

    r = client.get(f"/threads/{tid}/messages", headers=bearer(other["tokens"]))
    assert r.status_code == 403
    r2 = _send(client, other["tokens"], tid, "leaking")
    assert r2.status_code == 403


def test_broker_cannot_send_when_demoted(app, client, buyer, verified_broker):
    from app.extensions import db as _db
    from app.models.broker_profile import BrokerProfile, VerificationStatus
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.REJECTED
        _db.session.commit()

    r = _send(client, verified_broker["tokens"], tid, "sneaking through")
    assert r.status_code == 403


def test_buyer_can_send_freely(client, buyer, verified_broker):
    """Buyer isn't gated by verification (they don't have any)."""
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    for i in range(3):
        r = _send(client, buyer["tokens"], tid, f"msg {i}")
        assert r.status_code == 201


def test_get_single_thread_by_id(client, buyer, verified_broker):
    """Regression: deep-linked thread screens had no way to fetch
    counterparty info; showed "—" forever."""
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    res = client.get(f"/threads/{tid}", headers=bearer(buyer["tokens"]))
    assert res.status_code == 200
    body = res.get_json()
    assert body["id"] == tid
    assert body["counterparty"]["role"] == "broker"


def test_get_single_thread_forbidden_to_non_participant(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]
    other = client.post("/auth/register", json={
        "phone": "01099998888", "password": "supersecret",
        "full_name": "Other", "role": "buyer",
    }).get_json()
    res = client.get(f"/threads/{tid}", headers=bearer(other["tokens"]))
    assert res.status_code == 403


def test_body_length_validation(client, buyer, verified_broker):
    lid = _make_listing(client, verified_broker)
    tid = _start_thread(client, buyer, lid).get_json()["id"]

    # Empty body → 400
    r = _send(client, buyer["tokens"], tid, "")
    assert r.status_code == 400
    # Too long → 400
    r = _send(client, buyer["tokens"], tid, "a" * 2001)
    assert r.status_code == 400
