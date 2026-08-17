"""Phase 4: per-listing document checklist — self-report + upload +
admin approve/reject + access control."""
from __future__ import annotations

import io

from PIL import Image

from tests.conftest import bearer


def _img_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), (10, 200, 10)).save(buf, "JPEG")
    return buf.getvalue()


def _valid_body() -> dict:
    return {
        "title": "Doc test listing",
        "description": "For phase-4 doc tests.",
        "price_egp": "1000000.00",
        "area_m2": "80",
        "governorate": "Cairo",
        "city": "Nasr City",
        "district": "Zone 6",
        "lat": 30.06,
        "lng": 31.34,
        "property_type": "apartment",
    }


def _create_listing(client, tokens, **overrides):
    body = _valid_body() | overrides
    return client.post("/listings", json=body, headers=bearer(tokens))


def _upload_doc(client, tokens, lid: int, kind: str, filename: str = "deed.pdf"):
    return client.post(
        f"/listings/{lid}/documents/{kind}",
        headers=bearer(tokens),
        data={"document": (io.BytesIO(b"%PDF-fake-pdf-bytes"), filename)},
        content_type="multipart/form-data",
    )


# ── list + shape ───────────────────────────────────────────────────────

def test_documents_endpoint_returns_three_unset_rows_by_default(
    client, buyer, verified_broker
):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.get(f"/listings/{lid}/documents", headers=bearer(buyer["tokens"]))
    assert res.status_code == 200
    items = res.get_json()
    assert {i["kind"] for i in items} == {"title_deed", "no_liens", "tax_clearance"}
    assert all(i["state"] == "unset" for i in items)
    assert all(i["has_document"] is False for i in items)


# ── owner self-report ──────────────────────────────────────────────────

def test_owner_can_self_report(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(verified_broker["tokens"]),
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["state"] == "self_reported"
    assert body["has_document"] is False


def test_non_owner_cannot_self_report(client, buyer, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(buyer["tokens"]),
    )
    assert res.status_code == 403


def test_unverified_broker_cannot_self_report(app, client, broker, verified_broker):
    """Guard: only verified brokers can act on their listings."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(broker["tokens"]),
    )
    # broker doesn't own the listing anyway — 403 for that reason.
    assert res.status_code == 403


# ── owner upload proof ─────────────────────────────────────────────────

def test_owner_can_upload_document(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = _upload_doc(client, verified_broker["tokens"], lid, "no_liens")
    assert res.status_code == 200, res.get_json()
    body = res.get_json()
    assert body["state"] == "pending"
    assert body["has_document"] is True


def test_upload_rejects_bad_extension(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.post(
        f"/listings/{lid}/documents/tax_clearance",
        headers=bearer(verified_broker["tokens"]),
        data={"document": (io.BytesIO(b"nope"), "bad.exe")},
        content_type="multipart/form-data",
    )
    assert res.status_code == 400


def test_upload_unknown_kind_rejected(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    res = client.post(
        f"/listings/{lid}/documents/nonexistent",
        headers=bearer(verified_broker["tokens"]),
        data={"document": (io.BytesIO(b"x"), "x.pdf")},
        content_type="multipart/form-data",
    )
    assert res.status_code == 400


def test_uploading_after_self_report_switches_to_pending(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(verified_broker["tokens"]),
    )
    up = _upload_doc(client, verified_broker["tokens"], lid, "title_deed")
    assert up.status_code == 200
    assert up.get_json()["state"] == "pending"


def test_owner_can_delete(client, verified_broker):
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    _upload_doc(client, verified_broker["tokens"], lid, "title_deed")
    res = client.delete(
        f"/listings/{lid}/documents/title_deed",
        headers=bearer(verified_broker["tokens"]),
    )
    assert res.status_code == 204
    # Now back to unset.
    got = client.get(
        f"/listings/{lid}/documents", headers=bearer(verified_broker["tokens"])
    ).get_json()
    assert next(i for i in got if i["kind"] == "title_deed")["state"] == "unset"


# ── admin review ──────────────────────────────────────────────────────

def test_admin_lists_only_pending_documents(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]

    # One self-reported, one uploaded.
    client.post(f"/listings/{lid}/documents/title_deed/self-report", headers=bearer(tokens))
    _upload_doc(client, tokens, lid, "no_liens")

    q = client.get("/admin/documents/pending", headers=bearer(admin["tokens"])).get_json()
    kinds = {r["kind"] for r in q}
    # Only the uploaded doc is in the admin queue; self-reported never is.
    assert kinds == {"no_liens"}


def test_admin_approves_document(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    up = _upload_doc(client, tokens, lid, "tax_clearance")
    doc_id = up.get_json()["id"]

    res = client.post(
        f"/admin/documents/{doc_id}/approve", headers=bearer(admin["tokens"])
    )
    assert res.status_code == 200
    assert res.get_json()["state"] == "verified"

    # Broker sees the flip too.
    got = client.get(f"/listings/{lid}/documents", headers=bearer(tokens)).get_json()
    assert next(i for i in got if i["kind"] == "tax_clearance")["state"] == "verified"


def test_admin_cannot_approve_self_reported(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    # Self-report has no ID exposed in the doc endpoint's response — get it
    # from the list response.
    client.post(f"/listings/{lid}/documents/title_deed/self-report", headers=bearer(tokens))
    got = client.get(f"/listings/{lid}/documents", headers=bearer(tokens)).get_json()
    doc = next(i for i in got if i["kind"] == "title_deed")
    doc_id = doc["id"]

    res = client.post(
        f"/admin/documents/{doc_id}/approve", headers=bearer(admin["tokens"])
    )
    assert res.status_code == 409


def test_admin_rejects_document(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    doc_id = _upload_doc(client, tokens, lid, "title_deed").get_json()["id"]

    res = client.post(
        f"/admin/documents/{doc_id}/reject",
        json={"reason": "Illegible — please rescan."},
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["state"] == "rejected"
    assert "Illegible" in body["rejection_reason"]

    # Broker sees the rejection and its reason.
    got = client.get(f"/listings/{lid}/documents", headers=bearer(tokens)).get_json()
    row = next(i for i in got if i["kind"] == "title_deed")
    assert row["state"] == "rejected"
    assert row["rejection_reason"].startswith("Illegible")


def test_broker_can_resubmit_after_rejection(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    doc_id = _upload_doc(client, tokens, lid, "title_deed").get_json()["id"]
    client.post(
        f"/admin/documents/{doc_id}/reject",
        json={"reason": "Blurry"},
        headers=bearer(admin["tokens"]),
    )

    # Resubmit flips back to pending and clears rejection_reason.
    res = _upload_doc(client, tokens, lid, "title_deed")
    assert res.status_code == 200
    body = res.get_json()
    assert body["state"] == "pending"
    assert body["rejection_reason"] is None


def test_buyer_cannot_hit_admin_docs_queue(client, buyer):
    res = client.get("/admin/documents/pending", headers=bearer(buyer["tokens"]))
    assert res.status_code == 403


# ── listing-docs file access ───────────────────────────────────────────

def test_listing_doc_file_is_admin_or_owner_only(client, verified_broker, admin, buyer):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    _upload_doc(client, tokens, lid, "title_deed")

    # Admin retrieves the doc URL from their queue.
    q = client.get("/admin/documents/pending", headers=bearer(admin["tokens"])).get_json()
    url = q[0]["document_url"]
    assert url.startswith("/files/listing-docs/")
    key = url[len("/files/"):]

    # Admin can fetch.
    assert client.get(f"/files/{key}", headers=bearer(admin["tokens"])).status_code == 200
    # Owning broker can fetch.
    assert client.get(f"/files/{key}", headers=bearer(tokens)).status_code == 200
    # A random buyer cannot.
    assert client.get(f"/files/{key}", headers=bearer(buyer["tokens"])).status_code == 403


# ── verified re-check (audit regression) ───────────────────────────────

def test_self_report_refused_on_verified_document(client, verified_broker, admin):
    """Regression: self-report on a VERIFIED doc silently demoted it
    and deleted the storage file. Now must 409."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    doc_id = _upload_doc(client, tokens, lid, "title_deed").get_json()["id"]
    client.post(f"/admin/documents/{doc_id}/approve", headers=bearer(admin["tokens"]))

    res = client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(tokens),
    )
    assert res.status_code == 409
    assert "verified" in res.get_json()["error"].lower()


def test_self_report_refused_on_pending_document(client, verified_broker):
    """Regression: mid-review self-report would drop the pending file."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    _upload_doc(client, tokens, lid, "title_deed")

    res = client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(tokens),
    )
    assert res.status_code == 409
    assert "review" in res.get_json()["error"].lower() \
        or "awaiting" in res.get_json()["error"].lower()


def test_admin_cannot_double_approve_document(client, verified_broker, admin):
    """Regression: approve_document silently overwrote audit trail on
    already-verified docs."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    doc_id = _upload_doc(client, tokens, lid, "title_deed").get_json()["id"]
    # First approve: 200
    client.post(f"/admin/documents/{doc_id}/approve", headers=bearer(admin["tokens"]))
    # Second approve: 409
    res = client.post(f"/admin/documents/{doc_id}/approve", headers=bearer(admin["tokens"]))
    assert res.status_code == 409


def test_admin_cannot_reject_verified_document(client, verified_broker, admin):
    """Regression: reject flipped VERIFIED back to REJECTED, rewriting audit trail."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    doc_id = _upload_doc(client, tokens, lid, "title_deed").get_json()["id"]
    client.post(f"/admin/documents/{doc_id}/approve", headers=bearer(admin["tokens"]))

    res = client.post(
        f"/admin/documents/{doc_id}/reject",
        json={"reason": "changed my mind"},
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 409


def test_admin_cannot_reject_self_reported_document(client, verified_broker, admin):
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(tokens),
    )
    row = next(
        r for r in client.get(
            f"/listings/{lid}/documents", headers=bearer(tokens)
        ).get_json() if r["kind"] == "title_deed"
    )
    res = client.post(
        f"/admin/documents/{row['id']}/reject",
        json={"reason": "no proof"},
        headers=bearer(admin["tokens"]),
    )
    assert res.status_code == 409


def test_owner_response_includes_document_url(client, verified_broker):
    """Regression: mutation responses were dropping document_url so the
    owner UI couldn't render the proof they just uploaded."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    up = _upload_doc(client, tokens, lid, "title_deed")
    body = up.get_json()
    assert body["document_url"] is not None
    assert body["document_url"].startswith("/files/listing-docs/")

    # And list_documents for the owner should include it too.
    rows = client.get(f"/listings/{lid}/documents", headers=bearer(tokens)).get_json()
    row = next(r for r in rows if r["kind"] == "title_deed")
    assert row["document_url"] is not None


def test_unset_document_row_includes_null_id(client, buyer, verified_broker):
    """Regression: synthetic 'unset' rows were missing the id field,
    causing KeyError in clients that iterate."""
    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]
    rows = client.get(f"/listings/{lid}/documents", headers=bearer(buyer["tokens"])).get_json()
    for r in rows:
        assert "id" in r  # even for unset


def test_delete_listing_cleans_document_files(app, client, verified_broker):
    """Regression: delete_listing wasn't touching listing-docs on disk."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    up = _upload_doc(client, tokens, lid, "title_deed")
    key = up.get_json()["document_url"][len("/files/"):]

    # Verify the file is really on disk under the upload dir.
    import os
    upload_dir = os.environ["UPLOAD_DIR"]
    disk_path = os.path.join(upload_dir, key.replace("/", os.sep))
    assert os.path.exists(disk_path), f"pre-delete file missing at {disk_path}"

    # Delete the listing.
    assert client.delete(f"/listings/{lid}", headers=bearer(tokens)).status_code == 204

    # The doc file should have been cleaned up alongside.
    assert not os.path.exists(disk_path), (
        f"document file leaked after listing delete: {disk_path}"
    )


def test_buyer_view_hides_rejection_reason_broker_sees_it(
    client, verified_broker, admin, buyer
):
    """Rejection reason is broker-facing feedback; must not leak to buyers."""
    tokens = verified_broker["tokens"]
    lid = _create_listing(client, tokens).get_json()["id"]
    doc_id = _upload_doc(client, tokens, lid, "title_deed").get_json()["id"]
    client.post(
        f"/admin/documents/{doc_id}/reject",
        json={"reason": "Blurry — please rescan."},
        headers=bearer(admin["tokens"]),
    )

    broker_view = client.get(
        f"/listings/{lid}/documents", headers=bearer(tokens)
    ).get_json()
    buyer_view = client.get(
        f"/listings/{lid}/documents", headers=bearer(buyer["tokens"])
    ).get_json()

    broker_row = next(i for i in broker_view if i["kind"] == "title_deed")
    buyer_row = next(i for i in buyer_view if i["kind"] == "title_deed")

    assert broker_row["state"] == "rejected"
    assert "Blurry" in broker_row["rejection_reason"]

    assert buyer_row["state"] == "rejected"
    assert buyer_row["rejection_reason"] is None


def test_broker_rejected_after_posting_cannot_touch_documents(
    app, client, verified_broker
):
    from app.extensions import db as _db
    from app.models.broker_profile import BrokerProfile, VerificationStatus

    lid = _create_listing(client, verified_broker["tokens"]).get_json()["id"]

    with app.app_context():
        profile = BrokerProfile.query.filter_by(
            user_id=verified_broker["user"]["id"]
        ).first()
        profile.verification_status = VerificationStatus.REJECTED
        _db.session.commit()

    tokens = verified_broker["tokens"]
    assert client.post(
        f"/listings/{lid}/documents/title_deed/self-report",
        headers=bearer(tokens),
    ).status_code == 403
    assert _upload_doc(client, tokens, lid, "no_liens").status_code == 403
    assert client.delete(
        f"/listings/{lid}/documents/tax_clearance", headers=bearer(tokens)
    ).status_code == 403
