"""Seed commands must leave the credentials they print actually working.

Regression: the Play reviewer got "Invalid phone or password" on the demo
admin because the phone already existed with an older password and
seed-demo only promoted the role.
"""
from __future__ import annotations

from app.auth.security import hash_password
from app.cli import DEMO_ADMIN_PASSWORD, DEMO_ADMIN_PHONE, create_or_promote_admin
from app.extensions import db
from app.models.user import User, UserRole


def _login(client, phone: str, password: str):
    return client.post("/auth/login", json={"phone": phone, "password": password})


def _existing_user(phone: str, password: str) -> None:
    db.session.add(User(
        phone=phone, password_hash=hash_password(password),
        full_name="Pre-existing", role=UserRole.BUYER,
    ))
    db.session.commit()


def test_demo_admin_password_reset_for_existing_phone(app, client):
    _existing_user(DEMO_ADMIN_PHONE, "some-older-password")

    create_or_promote_admin(DEMO_ADMIN_PHONE, DEMO_ADMIN_PASSWORD, "Demo Admin",
                            None, reset_password=True)

    res = _login(client, DEMO_ADMIN_PHONE, DEMO_ADMIN_PASSWORD)
    assert res.status_code == 200, res.get_json()
    assert res.get_json()["user"]["role"] == "admin"


def test_seed_admin_keeps_existing_password_by_default(app, client):
    _existing_user("+201000000009", "keep-this-one")

    create_or_promote_admin("+201000000009", "different-pass", "Admin", None)

    assert _login(client, "+201000000009", "keep-this-one").status_code == 200
    assert _login(client, "+201000000009", "different-pass").status_code == 401
