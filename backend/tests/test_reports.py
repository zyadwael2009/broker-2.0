"""Phase 11 — user reports + admin queue."""
from __future__ import annotations

from tests.conftest import bearer


def _listing(client, verified_broker) -> int:
    body = {
        "title": "Reports test", "price_egp": "1000000", "area_m2": "80",
        "governorate": "Cairo", "city": "Cairo",
        "lat": 30.05, "lng": 31.24, "property_type": "apartment",
    }
    return client.post("/listings", json=body,
                       headers=bearer(verified_broker["tokens"])).get_json()["id"]


def _submit(client, tokens, **overrides):
    body = {"target_type": "listing", "target_id": 1, "reason": "fraud"}
    body.update(overrides)
    return client.post("/reports", json=body, headers=bearer(tokens))


# ── submit ────────────────────────────────────────────────────────────

def test_buyer_reports_a_listing(client, buyer, verified_broker):
    lid = _listing(client, verified_broker)
    r = _submit(client, buyer["tokens"], target_id=lid,
                reason="fraud", note="Looks fake")
    assert r.status_code == 201
    body = r.get_json()
    assert body["status"] == "open"
    assert body["target_type"] == "listing"
    assert body["reason"] == "fraud"


def test_buyer_reports_a_broker(client, buyer, verified_broker):
    r = _submit(client, buyer["tokens"],
                target_type="broker",
                target_id=verified_broker["user"]["id"],
                reason="inappropriate")
    assert r.status_code == 201


def test_cannot_report_yourself_broker(client, verified_broker):
    """Broker tries to report their own account."""
    r = _submit(client, verified_broker["tokens"],
                target_type="broker",
                target_id=verified_broker["user"]["id"],
                reason="spam")
    assert r.status_code == 400


def test_cannot_report_own_listing(client, verified_broker):
    lid = _listing(client, verified_broker)
    r = _submit(client, verified_broker["tokens"],
                target_type="listing", target_id=lid, reason="fraud")
    assert r.status_code == 400


def test_report_unknown_listing(client, buyer):
    r = _submit(client, buyer["tokens"], target_id=999999)
    assert r.status_code == 400


def test_invalid_reason_rejected(client, buyer, verified_broker):
    lid = _listing(client, verified_broker)
    r = _submit(client, buyer["tokens"], target_id=lid, reason="not-a-reason")
    assert r.status_code == 400


# ── admin queue + resolve ────────────────────────────────────────────

def test_admin_lists_open_reports(client, buyer, verified_broker, admin):
    lid = _listing(client, verified_broker)
    _submit(client, buyer["tokens"], target_id=lid, reason="fraud")

    r = client.get("/admin/reports?status=open", headers=bearer(admin["tokens"]))
    assert r.status_code == 200
    assert len(r.get_json()) == 1


def test_buyer_cannot_hit_admin_queue(client, buyer):
    r = client.get("/admin/reports", headers=bearer(buyer["tokens"]))
    assert r.status_code == 403


def test_admin_resolves_report(client, buyer, verified_broker, admin):
    lid = _listing(client, verified_broker)
    rid = _submit(client, buyer["tokens"], target_id=lid).get_json()["id"]

    r = client.post(f"/admin/reports/{rid}/resolve",
                    json={"action": "resolved_action", "note": "Deleted listing."},
                    headers=bearer(admin["tokens"]))
    assert r.status_code == 200
    body = r.get_json()
    assert body["status"] == "resolved_action"
    assert body["resolution_note"] == "Deleted listing."


def test_admin_cannot_double_resolve(client, buyer, verified_broker, admin):
    lid = _listing(client, verified_broker)
    rid = _submit(client, buyer["tokens"], target_id=lid).get_json()["id"]

    client.post(f"/admin/reports/{rid}/resolve", json={"action": "dismiss"},
                headers=bearer(admin["tokens"]))
    r = client.post(f"/admin/reports/{rid}/resolve", json={"action": "dismiss"},
                    headers=bearer(admin["tokens"]))
    assert r.status_code == 409


def test_admin_dismiss(client, buyer, verified_broker, admin):
    lid = _listing(client, verified_broker)
    rid = _submit(client, buyer["tokens"], target_id=lid).get_json()["id"]

    r = client.post(f"/admin/reports/{rid}/resolve", json={"action": "dismiss"},
                    headers=bearer(admin["tokens"]))
    assert r.status_code == 200
    assert r.get_json()["status"] == "dismissed"
