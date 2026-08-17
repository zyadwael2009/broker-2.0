"""Shared pytest fixtures. Uses an in-memory SQLite so nothing external
is required."""
from __future__ import annotations

import os
import tempfile

import pytest

# Set env BEFORE importing the app so config.py picks it up.
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret")
os.environ.setdefault("SECRET_KEY", "test-secret")
os.environ.setdefault("STORAGE_BACKEND", "local")
# Rate limiting off by default so the existing 84 tests aren't affected;
# the new hardening test file re-enables it locally.
os.environ.setdefault("RATELIMIT_ENABLED", "false")

_tmp_upload_dir = tempfile.mkdtemp(prefix="broker_test_uploads_")
os.environ.setdefault("UPLOAD_DIR", _tmp_upload_dir)

from app import create_app  # noqa: E402
from app.extensions import db  # noqa: E402
from app.models.user import User, UserRole  # noqa: E402
from app.models.broker_profile import BrokerProfile, VerificationStatus  # noqa: E402
from app.auth.security import hash_password  # noqa: E402


def _promote_broker_to_verified(app, tokens: dict, broker_user_id: int) -> None:
    """Utility for Phase 3 tests: flip a broker to verified without going
    through the admin approve endpoint (which requires an uploaded doc)."""
    from app.models.broker_profile import BrokerProfile as BP, VerificationStatus as VS
    from datetime import datetime, timezone
    with app.app_context():
        profile = BP.query.filter_by(user_id=broker_user_id).first()
        assert profile is not None
        profile.verification_status = VS.VERIFIED
        profile.verified_at = datetime.now(timezone.utc)
        db.session.commit()


@pytest.fixture()
def app():
    app = create_app()
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def client(app):
    return app.test_client()


def _register(client, phone: str, role: str, name: str = "Test User"):
    res = client.post(
        "/auth/register",
        json={
            "phone": phone,
            "password": "supersecret",
            "full_name": name,
            "role": role,
        },
    )
    assert res.status_code == 201, res.get_json()
    return res.get_json()


@pytest.fixture()
def buyer(client):
    return _register(client, "01000000001", "buyer", "Buyer One")


@pytest.fixture()
def broker(client):
    return _register(client, "01000000002", "broker", "Broker One")


@pytest.fixture()
def verified_broker(app, client):
    payload = _register(client, "01000000003", "broker", "Verified Broker")
    _promote_broker_to_verified(app, payload["tokens"], payload["user"]["id"])
    # Re-login so the JWT carries verification_status=verified in claims
    # (not that our current guards read it, but the client's UI will).
    res = client.post(
        "/auth/login",
        json={"phone": "+201000000003", "password": "supersecret"},
    )
    assert res.status_code == 200
    return res.get_json()


@pytest.fixture()
def admin(app):
    """Admins can't be created via /auth/register — we insert one directly,
    the same way `flask seed-admin` does."""
    with app.app_context():
        user = User(
            phone="+201000000099",
            password_hash=hash_password("supersecret"),
            full_name="Site Admin",
            role=UserRole.ADMIN,
        )
        db.session.add(user)
        db.session.commit()
        # Log in via the normal endpoint so we get a real JWT.
    res = app.test_client().post(
        "/auth/login",
        json={"phone": "+201000000099", "password": "supersecret"},
    )
    assert res.status_code == 200
    return res.get_json()


def bearer(tokens: dict) -> dict:
    return {"Authorization": f"Bearer {tokens['access_token']}"}
