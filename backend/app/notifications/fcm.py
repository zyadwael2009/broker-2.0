"""Firebase Cloud Messaging integration.

Design principle: everything here is safe to call even when Firebase
isn't configured. Absent credentials → the send helpers become no-ops
and log a debug line. This matches the Sentry pattern and means tests
never need to mock FCM.

Wire it up in production by setting FIREBASE_CREDENTIALS_JSON to either
a filesystem path to a service-account JSON file, or the JSON string
itself (for platforms that only take env vars, like PythonAnywhere).
"""
from __future__ import annotations

import json
import logging
import os
from typing import Iterable

from flask import current_app

logger = logging.getLogger(__name__)

# Module-level flag rather than app-config lookup on every call — the
# check runs inside every message-send hot path.
_INITIALIZED = False


def init_from_config(config) -> None:
    """Called once during app factory. Idempotent — pytest creates a
    fresh app per test but Firebase Admin only allows one default init."""
    global _INITIALIZED
    if _INITIALIZED:
        return
    creds_val = (config.get("FIREBASE_CREDENTIALS_JSON") or "").strip()
    if not creds_val:
        return  # remain uninitialized; helpers no-op
    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        logger.warning("firebase-admin not installed; push notifications disabled.")
        return

    try:
        if os.path.isfile(creds_val):
            cred = credentials.Certificate(creds_val)
        else:
            cred = credentials.Certificate(json.loads(creds_val))
        firebase_admin.initialize_app(cred)
    except ValueError:
        # Already initialized (e.g. reloader in dev, second test app).
        pass
    except Exception as exc:  # noqa: BLE001
        logger.warning("Firebase init failed; push disabled: %s", exc)
        return

    _INITIALIZED = True


def is_configured() -> bool:
    return _INITIALIZED


def send_push_to_user(
    user_id: int,
    *,
    title: str,
    body: str,
    data: dict | None = None,
) -> int:
    """Send to every device registered for one user. Returns the number
    of tokens successfully delivered to. Zero when Firebase isn't
    configured or the user has no devices."""
    return send_push_to_users([user_id], title=title, body=body, data=data)


def send_push_to_users(
    user_ids: Iterable[int],
    *,
    title: str,
    body: str,
    data: dict | None = None,
) -> int:
    """Fan-out push. Deletes tokens the FCM server calls out as
    unregistered so a stale row doesn't keep failing forever."""
    ids = [int(u) for u in user_ids if u is not None]
    if not ids:
        return 0
    if not _INITIALIZED:
        logger.debug("push skipped (Firebase not configured): %s -> %d recipients",
                     title, len(ids))
        return 0

    from ..extensions import db
    from ..models.device_token import DeviceToken

    tokens = (
        db.session.query(DeviceToken)
        .filter(DeviceToken.user_id.in_(ids))
        .all()
    )
    if not tokens:
        return 0

    try:
        from firebase_admin import messaging
    except ImportError:
        return 0

    # Truncate to keep the FCM payload small — long messages just get
    # cut off in the notification tray anyway.
    title = (title or "")[:100]
    body = (body or "")[:240]

    payload_data = {k: str(v) for k, v in (data or {}).items()}
    message = messaging.MulticastMessage(
        tokens=[t.token for t in tokens],
        notification=messaging.Notification(title=title, body=body),
        data=payload_data or None,
    )

    try:
        resp = messaging.send_each_for_multicast(message)
    except Exception as exc:  # noqa: BLE001
        logger.warning("FCM send failed: %s", exc)
        return 0

    # Clean up tokens the FCM server rejected as unregistered / invalid.
    if resp.failure_count:
        stale = []
        for token_row, sub in zip(tokens, resp.responses):
            if sub.success:
                continue
            code = getattr(sub.exception, "code", "") or ""
            if code in ("registration-token-not-registered", "invalid-argument"):
                stale.append(token_row)
        if stale:
            for row in stale:
                db.session.delete(row)
            db.session.commit()

    return resp.success_count
