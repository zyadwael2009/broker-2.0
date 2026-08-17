"""Serve the built Flutter Web bundle at /app/*.

Deploy flow: run `scripts/build-web-app.ps1` (or `.sh`), which invokes
`flutter build web --release --base-href /app/ …`. Output lives at
mobile/build/web/. This blueprint serves index.html on `/app/` and every
asset request under it.

Missing-asset requests fall back to index.html so bookmark-worthy deep
links like `/app/register` also boot the SPA (useful when we eventually
migrate from go_router's hash strategy to path strategy).
"""
from __future__ import annotations

import os
from pathlib import Path

from flask import Blueprint, current_app, send_from_directory

webapp_bp = Blueprint("webapp", __name__)


def _web_build_dir() -> Path:
    """Absolute path to the Flutter web build output.

    Precedence: WEBAPP_BUILD_DIR env var (read live so tests can flip it
    without re-importing Config), then app.config (baked at boot from
    the same env var, safety-checked in production), then a repo-layout
    default (mobile/build/web/ two levels above backend/app/).
    """
    live_env = (os.environ.get("WEBAPP_BUILD_DIR") or "").strip()
    if live_env:
        return Path(live_env).resolve()
    baked = current_app.config.get("WEBAPP_BUILD_DIR")
    if baked:
        return Path(baked).resolve()
    return (Path(current_app.root_path).parent.parent / "mobile" / "build" / "web").resolve()


@webapp_bp.get("/")
@webapp_bp.get("/<path:asset>")
def serve(asset: str = "index.html"):
    """Static serve with a path-traversal guard and SPA fallback."""
    root = _web_build_dir()

    # Resolve the requested asset relative to the build root. If the
    # resolved path escapes root (via .. traversal), or the file simply
    # doesn't exist, fall back to serving index.html so the SPA router
    # can handle the URL on the client side.
    target = (root / asset).resolve()
    try:
        target.relative_to(root)
        exists = target.is_file()
    except ValueError:
        exists = False

    if not exists:
        target = root / "index.html"
        # If even index.html isn't there (build wasn't run yet) return a
        # helpful 503 rather than a confusing 500 stack trace.
        if not target.is_file():
            return (
                "<!doctype html><meta charset=utf-8>"
                "<title>Wasit — app not built</title>"
                "<div style='font-family:system-ui;padding:40px;max-width:640px;margin:auto'>"
                "<h1>App not built yet</h1>"
                "<p>Run <code>scripts/build-web-app.ps1</code> "
                "(or <code>scripts/build-web-app.sh</code>) to produce the Flutter Web bundle, "
                "then reload this page.</p></div>",
                503,
                {"Content-Type": "text/html; charset=utf-8"},
            )

    return send_from_directory(target.parent, target.name)
