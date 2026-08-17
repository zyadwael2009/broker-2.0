"""Phase-1 auth sanity checks. Fixtures come from conftest.py so env vars
and app/client setup are defined in one place."""
from __future__ import annotations

import pytest


def test_register_and_login_buyer(client):
    r = client.post(
        "/auth/register",
        json={
            "phone": "01012345678",  # local Egyptian format; server normalizes
            "password": "supersecret",
            "full_name": "Test Buyer",
            "role": "buyer",
        },
    )
    assert r.status_code == 201, r.get_json()
    body = r.get_json()
    assert body["user"]["phone"] == "+201012345678"
    assert body["user"]["role"] == "buyer"
    assert "access_token" in body["tokens"]

    r = client.post(
        "/auth/login",
        json={"phone": "+201012345678", "password": "supersecret"},
    )
    assert r.status_code == 200
    assert "access_token" in r.get_json()["tokens"]


def test_broker_registers_pending(client):
    r = client.post(
        "/auth/register",
        json={
            "phone": "01111111111",
            "password": "supersecret",
            "full_name": "Test Broker",
            "role": "broker",
        },
    )
    assert r.status_code == 201, r.get_json()
    body = r.get_json()
    assert body["user"]["role"] == "broker"
    assert body["broker_profile"]["verification_status"] == "pending"


def test_admin_role_rejected_on_register(client):
    r = client.post(
        "/auth/register",
        json={
            "phone": "01222222222",
            "password": "supersecret",
            "full_name": "Nope",
            "role": "admin",
        },
    )
    assert r.status_code == 400


def test_bad_login(client):
    client.post(
        "/auth/register",
        json={
            "phone": "01555555555",
            "password": "supersecret",
            "full_name": "Login Test",
            "role": "buyer",
        },
    )
    r = client.post(
        "/auth/login",
        json={"phone": "01555555555", "password": "wrong-password"},
    )
    assert r.status_code == 401


def test_me_requires_token(client):
    assert client.get("/auth/me").status_code == 401


def test_refresh_returns_new_access_token(client, buyer):
    """Regression: no test previously exercised /auth/refresh."""
    refresh_token = buyer["tokens"]["refresh_token"]
    r = client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )
    assert r.status_code == 200
    body = r.get_json()
    assert "access_token" in body


def test_refresh_rejects_missing_token(client):
    r = client.post("/auth/refresh")
    assert r.status_code == 401


def test_public_broker_profile_requires_auth(client):
    """Regression: previously only positive/404 paths were covered."""
    assert client.get("/brokers/1").status_code == 401


def test_files_public_listing_photo_needs_no_auth(client, tmp_path, app):
    """Regression: no test previously exercised the public /files branch."""
    # Write a fake photo to the upload dir under listing-photos/**
    from app.storage import get_storage
    from io import BytesIO
    with app.app_context():
        storage = get_storage()
        storage.put("listing-photos/1/probe.jpg", BytesIO(b"fake-jpg"))

    # No Authorization header — must still succeed for listing photos.
    r = client.get("/files/listing-photos/1/probe.jpg")
    assert r.status_code == 200
    assert r.data == b"fake-jpg"


def test_files_broker_docs_still_require_auth(client):
    r = client.get("/files/broker-docs/1/anything.pdf")
    assert r.status_code == 401


def test_local_storage_rejects_sibling_directory_traversal(app):
    """Regression: `startswith` guard was letting sibling dirs through
    (e.g. /var/uploads vs /var/uploadsX)."""
    from app.storage.local import LocalDiskStorage
    from pathlib import Path
    import tempfile

    tmp = Path(tempfile.mkdtemp(prefix="path_traversal_"))
    root = tmp / "uploads"
    root.mkdir()
    # A sibling with a shared prefix — the old startswith bug allowed this.
    sibling = tmp / "uploadsX"
    sibling.mkdir()

    storage = LocalDiskStorage(root)
    # Key that resolves outside the root must raise.
    import pytest
    with pytest.raises(ValueError):
        storage._abs("../uploadsX/whatever.txt")


# ══════════════════════════════════════════════════════════════════════
# Phase A2 — phone verification + password reset
# ══════════════════════════════════════════════════════════════════════

@pytest.fixture(autouse=True)
def _reset_sms(monkeypatch):
    """Every A2 test gets a fresh, per-app SMS init with debug-return-code
    turned on so we can complete OTP flows without reading logs."""
    monkeypatch.setenv("SMS_DEBUG_RETURN_CODE", "true")


def _register_buyer(client, phone="01011111111"):
    return client.post("/auth/register", json={
        "phone": phone,
        "password": "supersecret",
        "full_name": "OTP Tester",
        "role": "buyer",
    })


def test_register_sends_otp_and_returns_unverified_user(client, app):
    r = _register_buyer(client)
    assert r.status_code == 201, r.get_json()
    body = r.get_json()
    # phone_verified is False on a fresh account
    assert body["user"]["phone_verified"] is False
    # dev-mode leaks the code back so tests can complete the flow
    assert "debug_code" in body
    assert len(body["debug_code"]) == 6 and body["debug_code"].isdigit()

    # OTP hash was actually stored on the row
    from app.models.user import User
    with app.app_context():
        u = User.query.filter_by(phone="+201011111111").first()
        assert u.phone_otp_hash is not None
        assert u.phone_otp_expires_at is not None
        assert u.phone_verified is False


def test_verify_phone_confirm_success(client):
    body = _register_buyer(client).get_json()
    tok = body["tokens"]["access_token"]
    code = body["debug_code"]

    r = client.post(
        "/auth/verify-phone/confirm",
        json={"code": code},
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 200, r.get_json()
    ret = r.get_json()
    assert ret["user"]["phone_verified"] is True
    assert "access_token" in ret["tokens"]  # fresh JWT with new claim


def test_verify_phone_confirm_wrong_code(client):
    body = _register_buyer(client).get_json()
    tok = body["tokens"]["access_token"]

    r = client.post(
        "/auth/verify-phone/confirm",
        json={"code": "000000"},
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 400
    assert "incorrect" in r.get_json()["error"].lower()


def test_verify_phone_confirm_rejects_non_six_digits(client):
    body = _register_buyer(client).get_json()
    tok = body["tokens"]["access_token"]

    for bad in ("12345", "abcdef", "1234567", ""):
        r = client.post(
            "/auth/verify-phone/confirm",
            json={"code": bad},
            headers={"Authorization": f"Bearer {tok}"},
        )
        assert r.status_code == 400, f"code={bad!r} should be rejected"


def test_verify_phone_expired_code(client, app):
    from datetime import datetime, timedelta, timezone
    from app.extensions import db
    from app.models.user import User

    body = _register_buyer(client).get_json()
    tok = body["tokens"]["access_token"]
    code = body["debug_code"]

    # Backdate the expiry to yesterday.
    with app.app_context():
        u = User.query.filter_by(phone="+201011111111").first()
        u.phone_otp_expires_at = datetime.now(timezone.utc) - timedelta(days=1)
        db.session.commit()

    r = client.post(
        "/auth/verify-phone/confirm",
        json={"code": code},
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert r.status_code == 400


def test_verify_phone_already_verified_returns_409(client):
    body = _register_buyer(client).get_json()
    tok = body["tokens"]["access_token"]
    code = body["debug_code"]
    client.post("/auth/verify-phone/confirm", json={"code": code},
                headers={"Authorization": f"Bearer {tok}"})
    # Try to send again → 409
    r = client.post("/auth/verify-phone/send",
                    headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 409
    # And confirm-again also 409
    r = client.post("/auth/verify-phone/confirm", json={"code": code},
                    headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 409


def test_verify_phone_send_resends_fresh_code(client, app):
    body = _register_buyer(client).get_json()
    tok = body["tokens"]["access_token"]
    original_code = body["debug_code"]

    r = client.post("/auth/verify-phone/send",
                    headers={"Authorization": f"Bearer {tok}"})
    assert r.status_code == 200
    new_code = r.get_json()["debug_code"]
    # Overwhelmingly likely to differ; guard against the ~1/million collision
    if original_code == new_code:
        r = client.post("/auth/verify-phone/send",
                        headers={"Authorization": f"Bearer {tok}"})
        new_code = r.get_json()["debug_code"]

    # Old code should now fail; new one should succeed.
    assert client.post(
        "/auth/verify-phone/confirm", json={"code": original_code},
        headers={"Authorization": f"Bearer {tok}"},
    ).status_code == 400
    assert client.post(
        "/auth/verify-phone/confirm", json={"code": new_code},
        headers={"Authorization": f"Bearer {tok}"},
    ).status_code == 200


# ── forgot / reset password ────────────────────────────────────────────

def test_forgot_password_sends_reset_code(client, app):
    # Existing account
    _register_buyer(client, phone="01022222222")

    r = client.post("/auth/forgot-password", json={"phone": "01022222222"})
    assert r.status_code == 200
    body = r.get_json()
    assert body["sent"] is True
    assert "debug_code" in body

    # Hash was saved
    from app.models.user import User
    with app.app_context():
        u = User.query.filter_by(phone="+201022222222").first()
        assert u.password_reset_hash is not None
        assert u.password_reset_expires_at is not None


def test_forgot_password_unknown_phone_returns_ok(client):
    """Anti-enumeration — same shape whether the phone exists or not."""
    r = client.post("/auth/forgot-password", json={"phone": "01099999999"})
    assert r.status_code == 200
    body = r.get_json()
    assert body["sent"] is True
    # No debug_code leaked when the user didn't exist
    assert "debug_code" not in body


def test_forgot_password_bad_phone_returns_ok(client):
    r = client.post("/auth/forgot-password", json={"phone": "not-a-number"})
    assert r.status_code == 200


def test_reset_password_completes_flow(client):
    _register_buyer(client, phone="01033333333")
    # Get a reset code
    forgot = client.post("/auth/forgot-password",
                         json={"phone": "01033333333"}).get_json()
    code = forgot["debug_code"]

    # Reset with new password
    r = client.post("/auth/reset-password", json={
        "phone": "01033333333",
        "code": code,
        "new_password": "newpassword-x1",
    })
    assert r.status_code == 200, r.get_json()

    # Old password no longer works
    r = client.post("/auth/login",
                    json={"phone": "+201033333333", "password": "supersecret"})
    assert r.status_code == 401
    # New password works
    r = client.post("/auth/login", json={
        "phone": "+201033333333", "password": "newpassword-x1",
    })
    assert r.status_code == 200


def test_reset_password_rejects_invalid_code(client):
    _register_buyer(client, phone="01044444444")
    client.post("/auth/forgot-password", json={"phone": "01044444444"})

    r = client.post("/auth/reset-password", json={
        "phone": "01044444444",
        "code": "000000",
        "new_password": "another-goodone",
    })
    assert r.status_code == 400
    # Old password still works
    r = client.post("/auth/login",
                    json={"phone": "+201044444444", "password": "supersecret"})
    assert r.status_code == 200


def test_reset_password_rejects_short_password(client):
    _register_buyer(client, phone="01055555555")
    forgot = client.post("/auth/forgot-password",
                         json={"phone": "01055555555"}).get_json()
    r = client.post("/auth/reset-password", json={
        "phone": "01055555555",
        "code": forgot["debug_code"],
        "new_password": "abc",  # too short
    })
    assert r.status_code == 400


def test_jwt_carries_phone_verified_claim(client):
    body = _register_buyer(client, phone="01066666666").get_json()
    tok = body["tokens"]["access_token"]
    # Decode the token payload (no signature check — we just inspect claims)
    import base64
    import json
    parts = tok.split(".")
    payload = json.loads(base64.urlsafe_b64decode(parts[1] + "==="))
    assert "phone_verified" in payload
    assert payload["phone_verified"] is False


def test_reset_password_revokes_existing_sessions(client, app):
    """Phase A3: after a password reset, any JWT issued before the
    change should be treated as revoked by the blocklist loader.
    Closes the A2-documented gap."""
    _register_buyer(client, phone="01088888888")
    login = client.post("/auth/login", json={
        "phone": "+201088888888", "password": "supersecret",
    }).get_json()
    old_access = login["tokens"]["access_token"]
    # The old JWT works before the reset.
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {old_access}"})
    assert r.status_code == 200

    # Sleep a moment so password_changed_at > iat (both are second-precision).
    import time as _time
    _time.sleep(1.1)

    forgot = client.post("/auth/forgot-password",
                         json={"phone": "01088888888"}).get_json()
    reset = client.post("/auth/reset-password", json={
        "phone": "01088888888",
        "code": forgot["debug_code"],
        "new_password": "brand-new-password",
    })
    assert reset.status_code == 200

    # Old JWT is now blacklisted by the password_changed_at check.
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {old_access}"})
    assert r.status_code == 401


def test_new_login_after_reset_still_works(client):
    """The session-invalidation logic must NOT bleed onto fresh tokens
    issued after the reset — the new login has iat > password_changed_at
    so it passes the blocklist check."""
    _register_buyer(client, phone="01077777777")
    forgot = client.post("/auth/forgot-password",
                         json={"phone": "01077777777"}).get_json()
    client.post("/auth/reset-password", json={
        "phone": "01077777777",
        "code": forgot["debug_code"],
        "new_password": "another-new-password",
    })
    # Fresh login with new password → JWT works.
    fresh = client.post("/auth/login", json={
        "phone": "+201077777777", "password": "another-new-password",
    }).get_json()
    r = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {fresh['tokens']['access_token']}"},
    )
    assert r.status_code == 200


def test_register_generates_referral_code(client):
    body = _register_buyer(client, phone="01099000001").get_json()
    code = body["user"]["referral_code"]
    assert code is not None
    assert len(code) == 8
    # Ambiguous-char-free alphabet — no 0/o/1/l/i uppercase mix.
    for ch in code:
        assert ch in "abcdefghjkmnpqrstuvwxyz23456789", f"bad char {ch!r} in {code!r}"


def test_register_with_valid_ref_code_records_referrer(client, app):
    referrer_body = _register_buyer(client, phone="01099000002").get_json()
    ref_code = referrer_body["user"]["referral_code"]

    r = client.post("/auth/register", json={
        "phone": "01099000003",
        "password": "supersecret",
        "full_name": "Referred User",
        "role": "buyer",
        "ref_code": ref_code,
    })
    assert r.status_code == 201, r.get_json()

    from app.models.user import User
    with app.app_context():
        referred = User.query.filter_by(phone="+201099000003").first()
        assert referred.referred_by_user_id == referrer_body["user"]["id"]


def test_register_with_invalid_ref_code_silently_ignored(client, app):
    r = client.post("/auth/register", json={
        "phone": "01099000004",
        "password": "supersecret",
        "full_name": "No Referrer",
        "role": "buyer",
        "ref_code": "nonexistent-code",
    })
    assert r.status_code == 201
    from app.models.user import User
    with app.app_context():
        u = User.query.filter_by(phone="+201099000004").first()
        assert u.referred_by_user_id is None


def test_me_referrals_returns_count_and_display_names(client):
    referrer = _register_buyer(client, phone="01099000005").get_json()
    referrer_tok = referrer["tokens"]["access_token"]
    ref_code = referrer["user"]["referral_code"]

    # Two referred users
    for phone, name in [("01099000006", "Ali Ahmed"), ("01099000007", "Mona Adel")]:
        client.post("/auth/register", json={
            "phone": phone, "password": "supersecret",
            "full_name": name, "role": "buyer",
            "ref_code": ref_code,
        })

    r = client.get(
        "/auth/me/referrals",
        headers={"Authorization": f"Bearer {referrer_tok}"},
    )
    assert r.status_code == 200
    body = r.get_json()
    assert body["code"] == ref_code
    assert body["count"] == 2
    display_names = [x["display_name"] for x in body["referred"]]
    # Ordered newest-first; both name shapes should be initial-abbreviated.
    assert "Mona A." in display_names
    assert "Ali A." in display_names
    # Full names must NOT leak
    assert not any("Ahmed" in x["display_name"] or "Adel" in x["display_name"]
                    for x in body["referred"])


def test_me_referrals_empty_for_new_user(client):
    body = _register_buyer(client, phone="01099000008").get_json()
    r = client.get(
        "/auth/me/referrals",
        headers={"Authorization": f"Bearer {body['tokens']['access_token']}"},
    )
    assert r.status_code == 200
    assert r.get_json() == {
        "code": body["user"]["referral_code"],
        "count": 0,
        "referred": [],
    }


def test_debug_return_code_flagged_unsafe_for_prod(monkeypatch):
    """assert_production_safe complains when the debug flag is on."""
    from app.config import Config, assert_production_safe
    # Config attributes are baked at class-body eval, so patch the class
    # attribute directly rather than the env var.
    monkeypatch.setattr(Config, "SMS_DEBUG_RETURN_CODE", True)
    problems = assert_production_safe(Config())
    assert any("SMS_DEBUG_RETURN_CODE" in p for p in problems)
