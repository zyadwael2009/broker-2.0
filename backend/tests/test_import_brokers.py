"""Pre-launch — `flask import-brokers` bulk onboarding CLI.

Covers the row-level create / update / skip logic, `--verified`
behaviour, `--dry-run`, and post-import login by the created broker.
"""
from __future__ import annotations

from pathlib import Path

import pytest

from app.cli import _run_import_brokers
from app.extensions import db
from app.models.broker_profile import BrokerProfile, VerificationStatus
from app.models.user import User, UserRole


def _write_csv(tmp_path: Path, rows: list[dict], name: str = "brokers.csv") -> str:
    """Helper — write a CSV with header derived from the union of keys."""
    import csv as _csv
    header: list[str] = []
    for r in rows:
        for k in r.keys():
            if k not in header:
                header.append(k)
    path = tmp_path / name
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = _csv.DictWriter(fh, fieldnames=header)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    return str(path)


# ── happy path ────────────────────────────────────────────────────────

def test_creates_new_brokers(app, tmp_path):
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000010", "full_name": "Ahmed Nabil",
         "email": "ahmed@example.com", "goeic_number": "EG-1001"},
        {"phone": "01000000011", "full_name": "Sara Fouad",
         "goeic_number": "EG-1002"},
        {"phone": "01000000012", "full_name": "Mahmoud Salah",
         "goeic_number": "EG-1003"},
    ])
    with app.app_context():
        summary = _run_import_brokers(csv_path, verified=False,
                                      dry_run=False, password_length=12)

    assert len(summary["created"]) == 3
    assert len(summary["updated"]) == 0
    assert len(summary["errors"]) == 0

    with app.app_context():
        # All three exist as PENDING brokers with referral codes.
        brokers = User.query.filter_by(role=UserRole.BROKER).all()
        assert len(brokers) == 3
        assert all(u.referral_code and len(u.referral_code) >= 4 for u in brokers)
        assert all(u.phone_verified for u in brokers), \
            "bulk-imported brokers are hand-vetted; skip OTP"
        codes = {u.referral_code for u in brokers}
        assert len(codes) == 3, "referral codes should be unique"

        profiles = BrokerProfile.query.all()
        assert all(p.verification_status == VerificationStatus.PENDING
                   for p in profiles)
        assert all(p.consent_version == app.config["PDPL_CONSENT_VERSION"]
                   for p in profiles)


def test_rerun_same_csv_is_idempotent(app, tmp_path):
    """Running the import twice should not create duplicates."""
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000020", "full_name": "Idempotent One",
         "goeic_number": "EG-2001"},
        {"phone": "01000000021", "full_name": "Idempotent Two",
         "goeic_number": "EG-2002"},
    ])
    with app.app_context():
        s1 = _run_import_brokers(csv_path, verified=False,
                                 dry_run=False, password_length=12)
    with app.app_context():
        s2 = _run_import_brokers(csv_path, verified=False,
                                 dry_run=False, password_length=12)

    assert len(s1["created"]) == 2
    assert len(s2["created"]) == 0
    assert len(s2["updated"]) == 2
    assert len(s2["errors"]) == 0

    with app.app_context():
        assert User.query.filter_by(role=UserRole.BROKER).count() == 2


# ── verified flag ─────────────────────────────────────────────────────

def test_verified_flag_stamps_status_and_uploads_stub(app, admin, tmp_path):
    """--verified marks brokers VERIFIED and puts a stub PDF at the
    same storage path the standard submit flow uses."""
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000030", "full_name": "Bulk Verified",
         "goeic_number": "EG-3001"},
    ])
    with app.app_context():
        summary = _run_import_brokers(csv_path, verified=True,
                                      dry_run=False, password_length=12)

    assert len(summary["created"]) == 1
    assert len(summary["errors"]) == 0

    with app.app_context():
        profile = BrokerProfile.query.filter(
            BrokerProfile.goeic_registration_number == "EG-3001"
        ).first()
        assert profile is not None
        assert profile.verification_status == VerificationStatus.VERIFIED
        assert profile.verified_at is not None
        assert profile.verified_by is not None      # stamped with the admin
        assert profile.registration_document_path.startswith(
            f"broker-docs/{profile.user_id}/bulk-"
        )
        assert profile.consent_version == app.config["PDPL_CONSENT_VERSION"]


def test_verified_without_goeic_is_an_error(app, admin, tmp_path):
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000031", "full_name": "Missing Goeic"},
    ])
    with app.app_context():
        summary = _run_import_brokers(csv_path, verified=True,
                                      dry_run=False, password_length=12)

    assert len(summary["created"]) == 0
    assert len(summary["errors"]) == 1
    assert "goeic" in summary["errors"][0]["reason"].lower()


def test_verified_without_admin_raises(app, tmp_path):
    """No admin in DB + --verified must fail loudly, not silently."""
    import click
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000032", "full_name": "No Admin",
         "goeic_number": "EG-3002"},
    ])
    with app.app_context():
        with pytest.raises(click.ClickException):
            _run_import_brokers(csv_path, verified=True,
                                dry_run=False, password_length=12)


# ── skip / error rows ────────────────────────────────────────────────

def test_existing_buyer_is_skipped_not_promoted(app, buyer, tmp_path):
    """Refuse to change a buyer's role via bulk import."""
    csv_path = _write_csv(tmp_path, [
        # buyer fixture uses this phone (see conftest)
        {"phone": buyer["user"]["phone"], "full_name": "Would-be Broker",
         "goeic_number": "EG-4001"},
        # ...alongside a valid new broker.
        {"phone": "01000000041", "full_name": "Fresh Broker",
         "goeic_number": "EG-4002"},
    ])
    with app.app_context():
        summary = _run_import_brokers(csv_path, verified=False,
                                      dry_run=False, password_length=12)

    assert len(summary["created"]) == 1
    assert len(summary["skipped"]) == 1
    assert summary["skipped"][0]["phone"] == buyer["user"]["phone"]
    assert "buyer" in summary["skipped"][0]["reason"].lower()

    with app.app_context():
        # Buyer role unchanged.
        buyer_row = User.query.filter_by(id=buyer["user"]["id"]).first()
        assert buyer_row.role == UserRole.BUYER


def test_bad_phone_is_an_error_row_not_a_crash(app, tmp_path):
    csv_path = _write_csv(tmp_path, [
        {"phone": "not-a-phone", "full_name": "Bad Phone",
         "goeic_number": "EG-5001"},
        {"phone": "01000000050", "full_name": "Good Row",
         "goeic_number": "EG-5002"},
    ])
    with app.app_context():
        summary = _run_import_brokers(csv_path, verified=False,
                                      dry_run=False, password_length=12)

    assert len(summary["created"]) == 1
    assert len(summary["errors"]) == 1
    assert "phone" in summary["errors"][0]["reason"].lower()


# ── dry run ──────────────────────────────────────────────────────────

def test_dry_run_writes_nothing(app, tmp_path):
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000060", "full_name": "Dry Run One"},
        {"phone": "01000000061", "full_name": "Dry Run Two"},
    ])
    with app.app_context():
        before = User.query.count()
        summary = _run_import_brokers(csv_path, verified=False,
                                      dry_run=True, password_length=12)
        after = User.query.count()

    assert before == after
    assert len(summary["created"]) == 2   # reports what WOULD happen
    assert summary["dry_run"] is True


# ── post-import login ────────────────────────────────────────────────

def test_created_broker_can_log_in_with_temp_password(app, client, tmp_path):
    csv_path = _write_csv(tmp_path, [
        {"phone": "01000000070", "full_name": "Login Test",
         "goeic_number": "EG-7001"},
    ])
    with app.app_context():
        summary = _run_import_brokers(csv_path, verified=False,
                                      dry_run=False, password_length=12)

    row = summary["created"][0]
    temp_pw = row["temp_password"]

    # E.164 normalization means the returned phone starts with +.
    res = client.post("/auth/login", json={
        "phone": row["phone"], "password": temp_pw,
    })
    assert res.status_code == 200, res.get_json()
    body = res.get_json()
    assert body["user"]["role"] == "broker"
    # phone_verified was stamped by the importer, so login shouldn't
    # push them through the OTP flow.
    assert body["user"]["phone_verified"] is True
