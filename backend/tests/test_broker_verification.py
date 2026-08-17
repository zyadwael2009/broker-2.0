"""Phase 2: broker submission + admin approve/reject + access control."""
from __future__ import annotations

import io

from tests.conftest import bearer


def _submit_doc(client, broker_tokens, goeic="EG-12345"):
    return client.post(
        "/brokers/me/verification",
        headers=bearer(broker_tokens),
        data={
            "goeic_registration_number": goeic,
            "document": (io.BytesIO(b"%PDF-fake-content"), "reg.pdf"),
        },
        content_type="multipart/form-data",
    )


def test_broker_submits_verification(client, broker):
    res = _submit_doc(client, broker["tokens"])
    assert res.status_code == 200, res.get_json()
    body = res.get_json()
    assert body["verification_status"] == "pending"
    assert body["goeic_registration_number"] == "EG-12345"


def test_broker_verification_submit_stamps_consent_version(app, client, broker):
    """PDPL audit trail — submitting the doc counts as consent for
    processing the sensitive data. Stamp the current
    PDPL_CONSENT_VERSION so we can prove which text version was in
    effect at submit time."""
    from app.models.broker_profile import BrokerProfile

    res = _submit_doc(client, broker["tokens"])
    assert res.status_code == 200

    with app.app_context():
        profile = BrokerProfile.query.filter_by(user_id=broker["user"]["id"]).first()
        assert profile is not None
        assert profile.consent_version == app.config["PDPL_CONSENT_VERSION"]


def test_buyer_cannot_submit_verification(client, buyer):
    res = _submit_doc(client, buyer["tokens"])
    assert res.status_code == 403


def test_broker_submission_rejects_bad_extension(client, broker):
    res = client.post(
        "/brokers/me/verification",
        headers=bearer(broker["tokens"]),
        data={
            "goeic_registration_number": "EG-1",
            "document": (io.BytesIO(b"nope"), "reg.exe"),
        },
        content_type="multipart/form-data",
    )
    assert res.status_code == 400


def test_admin_lists_pending(client, admin, broker):
    _submit_doc(client, broker["tokens"])
    res = client.get("/admin/brokers?status=pending", headers=bearer(admin["tokens"]))
    assert res.status_code == 200
    items = res.get_json()
    assert len(items) == 1
    assert items[0]["user"]["phone"] == broker["user"]["phone"]
    assert items[0]["document_url"] is not None


def test_admin_cannot_double_approve_broker(client, admin, broker):
    """Regression: re-approving VERIFIED silently rewrote audit trail."""
    _submit_doc(client, broker["tokens"])
    broker_id = broker["user"]["id"]
    r1 = client.post(f"/admin/brokers/{broker_id}/approve",
                     headers=bearer(admin["tokens"]))
    assert r1.status_code == 200
    r2 = client.post(f"/admin/brokers/{broker_id}/approve",
                     headers=bearer(admin["tokens"]))
    assert r2.status_code == 409


def test_admin_cannot_reject_verified_broker(client, admin, broker):
    _submit_doc(client, broker["tokens"])
    broker_id = broker["user"]["id"]
    client.post(f"/admin/brokers/{broker_id}/approve",
                headers=bearer(admin["tokens"]))
    r = client.post(f"/admin/brokers/{broker_id}/reject",
                    json={"reason": "changed my mind"},
                    headers=bearer(admin["tokens"]))
    assert r.status_code == 409


def test_admin_approves_broker(client, admin, broker):
    _submit_doc(client, broker["tokens"])
    broker_id = broker["user"]["id"]

    res = client.post(
        f"/admin/brokers/{broker_id}/approve",
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 200
    assert res.get_json()["verification_status"] == "verified"

    # Broker sees updated status.
    me = client.get("/brokers/me/verification", headers=bearer(broker["tokens"]))
    assert me.get_json()["verification_status"] == "verified"


def test_admin_cannot_approve_broker_without_document(client, admin, broker):
    broker_id = broker["user"]["id"]
    res = client.post(
        f"/admin/brokers/{broker_id}/approve",
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 409


def test_admin_rejects_broker_with_reason(client, admin, broker):
    _submit_doc(client, broker["tokens"])
    broker_id = broker["user"]["id"]

    res = client.post(
        f"/admin/brokers/{broker_id}/reject",
        json={"reason": "Document unreadable — please rescan."},
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["verification_status"] == "rejected"
    assert "unreadable" in body["rejection_reason"]


def test_broker_can_resubmit_after_rejection(client, admin, broker):
    _submit_doc(client, broker["tokens"], goeic="EG-1")
    broker_id = broker["user"]["id"]
    client.post(
        f"/admin/brokers/{broker_id}/reject",
        json={"reason": "Blurry"},
        headers=bearer(admin["tokens"]),
    )

    # Resubmit — must flip back to pending and clear rejection_reason.
    res = _submit_doc(client, broker["tokens"], goeic="EG-2")
    assert res.status_code == 200
    body = res.get_json()
    assert body["verification_status"] == "pending"
    assert body["goeic_registration_number"] == "EG-2"
    assert body["rejection_reason"] is None


def test_buyer_cannot_access_admin_list(client, buyer):
    res = client.get("/admin/brokers", headers=bearer(buyer["tokens"]))
    assert res.status_code == 403


def test_public_broker_profile_visible_to_buyer(client, buyer, admin, broker):
    _submit_doc(client, broker["tokens"])
    broker_id = broker["user"]["id"]
    client.post(
        f"/admin/brokers/{broker_id}/approve",
        headers=bearer(admin["tokens"]),
    )

    res = client.get(f"/brokers/{broker_id}", headers=bearer(buyer["tokens"]))
    assert res.status_code == 200
    body = res.get_json()
    assert body["verification_status"] == "verified"
    assert body["full_name"] == "Broker One"
    # Public profile must NOT leak the document URL or rejection reason.
    assert "document_url" not in body
    assert "rejection_reason" not in body


def test_file_endpoint_forbids_other_broker(client, admin, broker):
    _submit_doc(client, broker["tokens"])

    # Read the admin view to find the document key.
    res = client.get("/admin/brokers?status=pending", headers=bearer(admin["tokens"]))
    doc_url = res.get_json()[0]["document_url"]
    assert doc_url.startswith("/files/")
    key = doc_url[len("/files/"):]

    # A second, unrelated broker must not be able to fetch it.
    other = client.post(
        "/auth/register",
        json={
            "phone": "01000000050",
            "password": "supersecret",
            "full_name": "Other Broker",
            "role": "broker",
        },
    ).get_json()

    res = client.get(f"/files/{key}", headers=bearer(other["tokens"]))
    assert res.status_code == 403

    # Admin can read it.
    res = client.get(f"/files/{key}", headers=bearer(admin["tokens"]))
    assert res.status_code == 200

    # The owning broker can read their own doc.
    res = client.get(f"/files/{key}", headers=bearer(broker["tokens"]))
    assert res.status_code == 200


def test_public_profile_404_for_nonexistent(client, buyer):
    res = client.get("/brokers/9999999", headers=bearer(buyer["tokens"]))
    assert res.status_code == 404
