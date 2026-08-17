"""Phase 6 — rate limiting, magic-byte validation, JWT revocation,
constant-time login."""
from __future__ import annotations

import io

import pytest
from PIL import Image

from app.auth.revocation import revocation_list
from tests.conftest import bearer


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (32, 32), (100, 100, 100)).save(buf, "JPEG")
    return buf.getvalue()


# ── magic-byte validation ─────────────────────────────────────────────

def test_broker_doc_rejects_non_pdf_bytes_with_pdf_extension(client, broker):
    """A .pdf filename shouldn't get past validation if bytes aren't PDF."""
    res = client.post(
        "/brokers/me/verification",
        headers=bearer(broker["tokens"]),
        data={
            "goeic_registration_number": "EG-1",
            "document": (io.BytesIO(b"not-a-pdf, obviously"), "reg.pdf"),
        },
        content_type="multipart/form-data",
    )
    assert res.status_code == 400
    assert "identify" in res.get_json()["error"].lower() \
        or "not allowed" in res.get_json()["error"].lower()


def test_broker_doc_accepts_valid_jpeg(client, broker):
    res = client.post(
        "/brokers/me/verification",
        headers=bearer(broker["tokens"]),
        data={
            "goeic_registration_number": "EG-1",
            "document": (io.BytesIO(_jpeg_bytes()), "reg.jpg"),
        },
        content_type="multipart/form-data",
    )
    assert res.status_code == 200


def test_listing_photo_rejects_pdf_disguised_as_jpg(client):
    """Photos are images only; magic-byte should catch a PDF renamed .jpg."""
    from tests.conftest import _register, _promote_broker_to_verified
    # We can't use the verified_broker fixture (already used) — spin one up here.
    p = _register(client, "01033330000", "broker", "Test Broker")
    _promote_broker_to_verified(client.application, p["tokens"], p["user"]["id"])
    # Re-login for updated claims (not strictly needed for this test).
    tokens = client.post(
        "/auth/login",
        json={"phone": "+201033330000", "password": "supersecret"},
    ).get_json()["tokens"]

    lid = client.post(
        "/listings",
        json={
            "title": "Photo bytes test",
            "price_egp": "100000",
            "area_m2": "50",
            "governorate": "Cairo",
            "city": "Cairo",
            "lat": 30, "lng": 31,
            "property_type": "apartment",
        },
        headers=bearer(tokens),
    ).get_json()["id"]

    res = client.post(
        f"/listings/{lid}/photos",
        headers=bearer(tokens),
        data={"photo": (io.BytesIO(b"%PDF-1.4\n..."), "photo.jpg")},
        content_type="multipart/form-data",
    )
    assert res.status_code == 400


# ── JWT revocation ────────────────────────────────────────────────────

def test_logout_revokes_access_token(client, buyer):
    """Regression: no way to invalidate a stolen access token before its
    natural expiry."""
    revocation_list.clear()
    tokens = buyer["tokens"]
    # Token works before logout.
    assert client.get("/auth/me", headers=bearer(tokens)).status_code == 200
    # Logout with the access token.
    assert client.post("/auth/logout", headers=bearer(tokens)).status_code == 204
    # Now the same token must be rejected.
    assert client.get("/auth/me", headers=bearer(tokens)).status_code == 401


def test_logout_without_token_still_succeeds(client):
    """Client should be able to always call logout without checking state."""
    assert client.post("/auth/logout").status_code == 204


def test_refresh_rotates_and_old_token_is_blocked(client, buyer):
    """Refresh rotation: the presented refresh must be revoked, and a
    fresh refresh token must be returned in its place."""
    revocation_list.clear()
    original_refresh = buyer["tokens"]["refresh_token"]

    r = client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {original_refresh}"},
    )
    assert r.status_code == 200
    body = r.get_json()
    assert "access_token" in body
    assert "refresh_token" in body
    new_refresh = body["refresh_token"]
    assert new_refresh != original_refresh

    # The new refresh works.
    r2 = client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {new_refresh}"},
    )
    assert r2.status_code == 200

    # The original refresh is now blocked.
    r3 = client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {original_refresh}"},
    )
    assert r3.status_code == 401


def test_refresh_token_can_be_revoked(client, buyer):
    """Revoke via refresh token; subsequent refresh attempt is blocked."""
    revocation_list.clear()
    refresh = buyer["tokens"]["refresh_token"]
    # Revoke by logging out with the refresh token.
    res = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {refresh}"},
    )
    assert res.status_code == 204
    # Attempt to refresh with that same token → blocked.
    r = client.post(
        "/auth/refresh",
        headers={"Authorization": f"Bearer {refresh}"},
    )
    assert r.status_code == 401


# ── rate limiting ─────────────────────────────────────────────────────

@pytest.fixture()
def rate_limited_app(monkeypatch):
    """Spin up a fresh app with rate limiting on and very small limits
    so we can trigger 429 in a single test."""
    monkeypatch.setenv("RATELIMIT_ENABLED", "true")
    monkeypatch.setenv("RATELIMIT_LOGIN", "2 per minute")
    monkeypatch.setenv("RATELIMIT_REGISTER", "2 per hour")
    monkeypatch.setenv("RATELIMIT_STORAGE_URI", "memory://")

    # Reimport with new env — Config reads at class-body time, so we need
    # a fresh Config class.
    import importlib
    import app.config as config_mod
    importlib.reload(config_mod)
    from app import create_app as fresh_create_app
    from app.extensions import db as _db
    app = fresh_create_app(config_mod.Config)
    with app.app_context():
        _db.create_all()
        yield app
        _db.session.remove()
        _db.drop_all()


def test_login_rate_limit_triggers_429(rate_limited_app):
    c = rate_limited_app.test_client()
    # Two attempts allowed; the third should 429.
    for _ in range(2):
        c.post("/auth/login",
               json={"phone": "01000000000", "password": "x"})
    res = c.post("/auth/login",
                 json={"phone": "01000000000", "password": "x"})
    assert res.status_code == 429
    body = res.get_json()
    assert "too many" in body["error"].lower()


def test_register_rate_limit_triggers_429(rate_limited_app):
    c = rate_limited_app.test_client()
    # Two attempts allowed even if payload is invalid — 429 wins after that.
    for i in range(2):
        c.post("/auth/register",
               json={"phone": f"0100000010{i}", "password": "supersecret",
                     "full_name": "X Y", "role": "buyer"})
    res = c.post("/auth/register",
                 json={"phone": "01000000199", "password": "supersecret",
                       "full_name": "X Y", "role": "buyer"})
    assert res.status_code == 429


# ── constant-time login ───────────────────────────────────────────────

def test_login_wrong_password_and_missing_user_similar_timing(client, buyer):
    """Loose bound — bcrypt cost is high enough that both branches should
    take roughly the same wall time. We only assert the missing-user
    branch isn't dramatically faster (which would leak account existence)."""
    import time
    # Wrong password for an existing user.
    t0 = time.perf_counter()
    client.post("/auth/login",
                json={"phone": buyer["user"]["phone"], "password": "definitely-wrong"})
    t_existing = time.perf_counter() - t0

    # Non-existent phone — must be a *valid* Egyptian mobile so phone
    # validation doesn't 400 before bcrypt runs (which would trivially
    # be the fastest branch and give a false positive).
    t0 = time.perf_counter()
    client.post("/auth/login",
                json={"phone": "+201099999999", "password": "definitely-wrong"})
    t_missing = time.perf_counter() - t0

    # If the missing branch skipped bcrypt it would be ~50x faster. We
    # allow a generous 3x margin for CI noise; the important thing is
    # they're the same order of magnitude.
    assert t_missing >= t_existing * 0.33, (
        f"missing-user branch is suspiciously fast: existing={t_existing:.3f}s, "
        f"missing={t_missing:.3f}s — likely leaks account existence"
    )


# ── default-limits safety net (pre-launch B3) ─────────────────────────

def test_ratelimit_default_is_configured(app):
    """Any route added without an explicit @limiter.limit() should still
    be bounded by the default_limits catch-all. Regression guard for
    B3.

    Tests only check that Config carries RATELIMIT_DEFAULT — the test
    app runs with RATELIMIT_ENABLED=false so Flask-Limiter skips
    actually loading the defaults into memory. The important thing at
    the code level is that (a) Config has the value, and (b)
    Flask-Limiter's convention of reading RATELIMIT_DEFAULT means it
    WILL be applied whenever the limiter is enabled (i.e., in prod)."""
    value = app.config.get("RATELIMIT_DEFAULT", "")
    assert value, (
        "RATELIMIT_DEFAULT is unset — a route added without an explicit "
        "@limiter.limit() decorator would be unlimited in production."
    )
    # Sanity-check the shape: at least one per-hour + one per-minute
    # cap so both short bursts and sustained abuse are covered.
    assert "hour" in value, f"missing hourly cap in RATELIMIT_DEFAULT: {value!r}"
    assert "minute" in value, f"missing per-minute cap in RATELIMIT_DEFAULT: {value!r}"
