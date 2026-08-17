"""Tests for the /app/* blueprint that serves the Flutter Web bundle.

Uses a fixture directory instead of requiring an actual Flutter build.
The tests set WEBAPP_BUILD_DIR before app-creation so the blueprint
serves from the fixture path.
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

import pytest


@pytest.fixture()
def fake_web_build(monkeypatch):
    """Create a minimal fake Flutter Web build directory:
        index.html
        main.dart.js
        assets/wasit-mark.svg  (nested asset)
    Yield the directory; monkeypatch WEBAPP_BUILD_DIR to point at it.
    """
    tmp = Path(tempfile.mkdtemp(prefix="wasit_web_build_"))
    (tmp / "index.html").write_text(
        "<!doctype html><html><head>"
        "<title>Wasit</title>"
        "<meta name='robots' content='noindex, nofollow'>"
        "<base href='/app/'>"
        "</head><body>fake-flutter-boot</body></html>",
        encoding="utf-8",
    )
    (tmp / "main.dart.js").write_text("// fake main.dart.js body\n", encoding="utf-8")
    (tmp / "assets").mkdir()
    (tmp / "assets" / "wasit-mark.svg").write_text("<svg/>", encoding="utf-8")

    monkeypatch.setenv("WEBAPP_BUILD_DIR", str(tmp))
    yield tmp
    # tempdir cleanup is fine to skip — OS reaps eventually


@pytest.fixture()
def webapp_client(fake_web_build, monkeypatch):
    """Fresh app instance with the fixture build wired in via config."""
    # Reuse the standard test env so create_app doesn't blow up on the
    # production-safety checks.
    monkeypatch.setenv("DATABASE_URL", "sqlite:///:memory:")
    monkeypatch.setenv("SECRET_KEY", "test-secret")
    monkeypatch.setenv("JWT_SECRET_KEY", "test-secret")

    from app import create_app
    from app.extensions import db

    app = create_app()
    with app.app_context():
        db.create_all()
        yield app.test_client()
        db.session.remove()
        db.drop_all()


def test_app_root_serves_index(webapp_client):
    res = webapp_client.get("/app/")
    assert res.status_code == 200
    body = res.get_data(as_text=True)
    assert "<title>Wasit</title>" in body
    assert "fake-flutter-boot" in body
    assert "noindex" in body


def test_app_serves_javascript_asset(webapp_client):
    res = webapp_client.get("/app/main.dart.js")
    assert res.status_code == 200
    assert "fake main.dart.js body" in res.get_data(as_text=True)


def test_app_serves_nested_asset(webapp_client):
    res = webapp_client.get("/app/assets/wasit-mark.svg")
    assert res.status_code == 200
    assert res.get_data(as_text=True) == "<svg/>"


def test_app_missing_asset_falls_back_to_index(webapp_client):
    """A URL like /app/register (which Flutter routes client-side) should
    still return index.html so the SPA can boot and handle the route."""
    res = webapp_client.get("/app/register")
    assert res.status_code == 200
    # Same index content as the root
    assert "fake-flutter-boot" in res.get_data(as_text=True)


def test_app_path_traversal_blocked(webapp_client):
    """A `..` in the URL must not escape the build directory."""
    res = webapp_client.get("/app/../wsgi.py")
    # Werkzeug normalizes `..` server-side before dispatch, so this
    # usually 404s at the router level. If it reaches our blueprint,
    # the resolve() guard falls back to index.html. Either way the
    # source file is NOT served.
    assert res.status_code in (200, 404)
    if res.status_code == 200:
        body = res.get_data(as_text=True)
        assert "def create_app" not in body
        assert "fake-flutter-boot" in body


def test_app_returns_helpful_message_when_build_missing(monkeypatch):
    """If no build has been produced yet, /app/ returns a 503 with a
    'run the build script' pointer — not a stack trace."""
    empty = Path(tempfile.mkdtemp(prefix="wasit_web_empty_"))
    monkeypatch.setenv("DATABASE_URL", "sqlite:///:memory:")
    monkeypatch.setenv("SECRET_KEY", "test-secret")
    monkeypatch.setenv("JWT_SECRET_KEY", "test-secret")
    monkeypatch.setenv("WEBAPP_BUILD_DIR", str(empty))

    from app import create_app
    app = create_app()
    with app.app_context():
        res = app.test_client().get("/app/")
    assert res.status_code == 503
    body = res.get_data(as_text=True)
    assert "build-web-app" in body.lower()
