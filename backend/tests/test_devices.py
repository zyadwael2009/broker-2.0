"""Phase 12: device-token registration + push-notification triggers.

The push helper (`app.notifications.fcm.send_push_to_user`) is a no-op
when Firebase isn't configured (which it never is in tests). We
monkey-patch it to record calls and assert the trigger sites fire.
"""
from __future__ import annotations

import io

import pytest
from PIL import Image

from app.extensions import db
from app.models.device_token import DevicePlatform, DeviceToken
from tests.conftest import bearer, _promote_broker_to_verified


TOK_A = "fcm-token-a-" + "x" * 40
TOK_B = "fcm-token-b-" + "y" * 40


def _bearer_for(res):
    return bearer(res["tokens"] if isinstance(res, dict) else res)


# ── /devices basic CRUD ────────────────────────────────────────────────

def test_register_device_creates_row(app, client, buyer):
    res = client.post(
        "/devices",
        json={"token": TOK_A, "platform": "android"},
        headers=bearer(buyer["tokens"]),
    )
    assert res.status_code == 201
    body = res.get_json()
    assert body["status"] == "registered"
    with app.app_context():
        assert DeviceToken.query.count() == 1


def test_register_same_token_twice_upserts(app, client, buyer):
    for _ in range(2):
        client.post(
            "/devices",
            json={"token": TOK_A, "platform": "android"},
            headers=bearer(buyer["tokens"]),
        )
    with app.app_context():
        assert DeviceToken.query.count() == 1


def test_register_second_token_creates_second_row(app, client, buyer):
    for tok in (TOK_A, TOK_B):
        client.post(
            "/devices",
            json={"token": tok, "platform": "android"},
            headers=bearer(buyer["tokens"]),
        )
    with app.app_context():
        assert DeviceToken.query.count() == 2


def test_deregister_removes_token(app, client, buyer):
    client.post(
        "/devices",
        json={"token": TOK_A, "platform": "android"},
        headers=bearer(buyer["tokens"]),
    )
    res = client.delete(
        "/devices",
        json={"token": TOK_A},
        headers=bearer(buyer["tokens"]),
    )
    assert res.status_code == 204
    with app.app_context():
        assert DeviceToken.query.count() == 0


def test_register_rejects_invalid_platform(client, buyer):
    res = client.post(
        "/devices",
        json={"token": TOK_A, "platform": "blackberry"},
        headers=bearer(buyer["tokens"]),
    )
    assert res.status_code == 400


def test_register_requires_auth(client):
    res = client.post("/devices", json={"token": TOK_A, "platform": "web"})
    assert res.status_code == 401


# ── push helper is a no-op when Firebase isn't configured ──────────────

def test_send_push_no_op_when_firebase_not_configured(app, client, buyer):
    """Sanity check — no crash, no side effects when Firebase absent."""
    from app.notifications import fcm as fcm_module

    # Register a device first so the code path exercises the token
    # lookup too.
    client.post(
        "/devices",
        json={"token": TOK_A, "platform": "web"},
        headers=bearer(buyer["tokens"]),
    )
    with app.app_context():
        assert fcm_module.is_configured() is False
        # Returns 0 because Firebase isn't init'd; no exception either.
        assert fcm_module.send_push_to_user(
            buyer["user"]["id"],
            title="Hi",
            body="There",
            data={"route": "/"},
        ) == 0


# ── trigger hooks call the push helper ─────────────────────────────────

class _PushRecorder:
    """Stand-in for send_push_to_user that records every call so tests
    can assert who got notified without a real Firebase project."""
    def __init__(self):
        self.calls = []

    def __call__(self, user_id, *, title, body, data=None):
        self.calls.append({"user_id": user_id, "title": title,
                            "body": body, "data": data or {}})
        return 1


@pytest.fixture()
def push_spy(monkeypatch):
    spy = _PushRecorder()
    from app.notifications import fcm as fcm_module
    monkeypatch.setattr(fcm_module, "send_push_to_user", spy)
    # The trigger call sites do `from ..notifications import fcm`; patching
    # the attribute on the module means callers see the spy immediately.
    return spy


def _img_bytes() -> bytes:
    img = Image.new("RGB", (40, 40), (10, 200, 50))
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    return buf.getvalue()


def _create_listing(client, tokens):
    return client.post(
        "/listings",
        json={
            "title": "Test",
            "price_egp": "100.00",
            "area_m2": "50.0",
            "governorate": "Cairo",
            "city": "Nasr City",
            "lat": 30.05,
            "lng": 31.35,
            "property_type": "apartment",
        },
        headers=bearer(tokens),
    )


def test_sending_message_notifies_counterparty(client, buyer, verified_broker, push_spy):
    # Buyer creates a thread on the broker's listing, then broker replies.
    lr = _create_listing(client, verified_broker["tokens"])
    listing_id = lr.get_json()["id"]

    thread_res = client.post(
        "/threads",
        json={"listing_id": listing_id},
        headers=bearer(buyer["tokens"]),
    )
    thread_id = thread_res.get_json()["id"]

    # Buyer -> Broker
    client.post(
        f"/threads/{thread_id}/messages",
        json={"body": "Is it still available?"},
        headers=bearer(buyer["tokens"]),
    )

    assert len(push_spy.calls) == 1
    call = push_spy.calls[0]
    assert call["user_id"] == verified_broker["user"]["id"]
    assert "route" in call["data"]
    assert str(thread_id) in call["data"]["route"]
    assert "Is it still available" in call["body"]


def test_broker_approval_notifies_broker(app, client, broker, admin, push_spy):
    # Broker uploads doc (required before approve).
    from app.models.broker_profile import BrokerProfile
    from app.storage import get_storage
    with app.app_context():
        profile = BrokerProfile.query.filter_by(user_id=broker["user"]["id"]).first()
        # Cheap shortcut: put a bogus registration doc marker on the profile.
        storage = get_storage()
        from io import BytesIO
        key = f"broker-docs/{broker['user']['id']}/test.pdf"
        storage.put(key, BytesIO(b"%PDF-1.4\n%stub"))
        profile.registration_document_path = key
        profile.goeic_registration_number = "TEST-12345"
        db.session.commit()

    res = client.post(
        f"/admin/brokers/{broker['user']['id']}/approve",
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 200

    assert len(push_spy.calls) == 1
    assert push_spy.calls[0]["user_id"] == broker["user"]["id"]
    assert "approved" in push_spy.calls[0]["title"].lower()


def test_report_resolution_notifies_reporter(app, client, buyer, verified_broker, admin, push_spy):
    # Buyer reports the broker.
    res = client.post(
        "/reports",
        json={
            "target_type": "broker",
            "target_id": verified_broker["user"]["id"],
            "reason": "fraud",
        },
        headers=bearer(buyer["tokens"]),
    )
    assert res.status_code == 201
    report_id = res.get_json()["id"]

    # Admin resolves it.
    res = client.post(
        f"/admin/reports/{report_id}/resolve",
        json={"action": "dismiss"},
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 200

    assert len(push_spy.calls) == 1
    assert push_spy.calls[0]["user_id"] == buyer["user"]["id"]
    assert "report" in push_spy.calls[0]["title"].lower()
