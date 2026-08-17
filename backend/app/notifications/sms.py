"""SMS delivery abstraction — provider-agnostic OTP sending.

Design principle: same as fcm.py — the module is safe to call whether
or not a real provider is configured. In dev / tests we log the code
and pretend the send succeeded; in prod you set SMS_PROVIDER=twilio
(or another adapter) and real SMS goes out.

Called from auth routes for two flows:
  1. verify_phone — after registration and via `/auth/verify-phone/send`
  2. reset_password — from `/auth/forgot-password`

Every send is deliberately non-fatal: an SMS failure never blocks the
auth flow. The user can request a fresh code.
"""
from __future__ import annotations

import logging

from flask import current_app

logger = logging.getLogger(__name__)


# Providers registered here. Selected via config.SMS_PROVIDER.
_PROVIDER = None  # set by init_from_config


def init_from_config(config) -> None:
    """Called once from create_app. Idempotent."""
    global _PROVIDER
    provider = (config.get("SMS_PROVIDER") or "").strip().lower() or None
    if provider is None:
        _PROVIDER = _NoopProvider()
        return
    if provider in ("log", "noop"):
        _PROVIDER = _NoopProvider()
        return
    if provider == "twilio":
        _PROVIDER = _make_twilio(config) or _NoopProvider()
        return
    logger.warning("Unknown SMS_PROVIDER=%r; falling back to noop.", provider)
    _PROVIDER = _NoopProvider()


def is_configured() -> bool:
    """True when a real (non-noop) provider is active."""
    return _PROVIDER is not None and not isinstance(_PROVIDER, _NoopProvider)


def send_otp(phone: str, code: str, purpose: str) -> bool:
    """Send an OTP to a phone number. Never raises. Returns True on
    apparent success (or when noop-mode swallows it silently)."""
    provider = _PROVIDER or _NoopProvider()
    try:
        return provider.send(phone=phone, code=code, purpose=purpose)
    except Exception as exc:  # noqa: BLE001
        logger.warning("SMS send failed for %s (%s): %s", phone, purpose, exc)
        return False


# ── providers ──────────────────────────────────────────────────────────

class _NoopProvider:
    """The default. Logs the OTP + purpose at INFO so devs testing
    locally can grab it from stdout. Returns True so callers proceed."""

    def send(self, *, phone: str, code: str, purpose: str) -> bool:
        logger.info("[SMS-NOOP] to=%s code=%s purpose=%s", phone, code, purpose)
        return True


class _TwilioProvider:
    """Real Twilio delivery. Only used when SMS_PROVIDER=twilio AND the
    twilio SDK is installed AND TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN /
    SMS_FROM_NUMBER are all set."""

    def __init__(self, sid: str, token: str, from_number: str):
        # Import lazily so the dep is optional.
        from twilio.rest import Client
        self._client = Client(sid, token)
        self._from = from_number

    def send(self, *, phone: str, code: str, purpose: str) -> bool:
        body = _message_body(code, purpose)
        message = self._client.messages.create(to=phone, from_=self._from, body=body)
        logger.info("Twilio SMS sent sid=%s to=%s purpose=%s",
                    getattr(message, "sid", "?"), phone, purpose)
        return True


def _make_twilio(config):
    sid = config.get("TWILIO_ACCOUNT_SID")
    token = config.get("TWILIO_AUTH_TOKEN")
    from_number = config.get("SMS_FROM_NUMBER")
    if not (sid and token and from_number):
        logger.warning(
            "SMS_PROVIDER=twilio but TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN "
            "/ SMS_FROM_NUMBER not all set; falling back to noop."
        )
        return None
    try:
        return _TwilioProvider(sid, token, from_number)
    except ImportError:
        logger.warning("twilio SDK not installed; falling back to noop.")
        return None
    except Exception as exc:  # noqa: BLE001
        logger.warning("Twilio init failed; falling back to noop: %s", exc)
        return None


def _message_body(code: str, purpose: str) -> str:
    if purpose == "verify_phone":
        return f"Wasit — your verification code is {code}. Expires in 10 minutes."
    if purpose == "reset_password":
        return f"Wasit — your password reset code is {code}. Expires in 10 minutes."
    return f"Wasit — your code is {code}."


def _debug_return_code_enabled() -> bool:
    """Whether the API should echo the plaintext code back in dev.
    Reads live at request time (env may change between requests in dev)."""
    try:
        return bool(current_app.config.get("SMS_DEBUG_RETURN_CODE"))
    except RuntimeError:
        return False
