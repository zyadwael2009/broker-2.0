"""Env-driven config. Never hard-code hosts, secrets, or paths."""
from __future__ import annotations

import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()  # loads .env if present; no-op in prod where env vars are set directly


def _split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


# Sentinel used to detect env vars that were never set.
_DEV_SECRET_SENTINEL = "dev-only-change-me"
_DEV_DB_SENTINEL = "postgresql+psycopg2://postgres:postgres@localhost:5432/broker_dev"


def _looks_like_dev_secret(value: str) -> bool:
    """Reject any secret that obviously wasn't set for prod: empty, or
    containing the substrings `dev`, `change-me`, `test`, `secret`
    (case-insensitive). Catches the docker-compose defaults like
    `dev-secret-change-me` that the literal sentinel missed."""
    if not value:
        return True
    low = value.lower()
    return any(marker in low for marker in ("dev-", "change-me", "changeme", "test-secret"))


class Config:
    # Core
    SECRET_KEY = os.getenv("SECRET_KEY", _DEV_SECRET_SENTINEL)

    # DB
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL", _DEV_DB_SENTINEL)
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}

    # JWT
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", SECRET_KEY)
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(
        seconds=int(os.getenv("JWT_ACCESS_TTL", "3600"))
    )
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(
        seconds=int(os.getenv("JWT_REFRESH_TTL", "2592000"))
    )
    JWT_TOKEN_LOCATION = ["headers"]

    # CORS
    CORS_ORIGINS = _split_csv(os.getenv("CORS_ORIGINS", "*")) or ["*"]

    # Storage
    STORAGE_BACKEND = os.getenv("STORAGE_BACKEND", "local")
    UPLOAD_DIR = os.getenv("UPLOAD_DIR", "./uploads")
    MAX_CONTENT_LENGTH = int(os.getenv("MAX_UPLOAD_MB", "20")) * 1024 * 1024

    # Password rules (kept loose; tighten later if you want)
    MIN_PASSWORD_LEN = 8

    # Rate limits. Values are Flask-Limiter strings, comma-separated for
    # multiple thresholds. Tests set RATELIMIT_ENABLED=false to skip.
    RATELIMIT_ENABLED = os.getenv("RATELIMIT_ENABLED", "true").lower() == "true"
    RATELIMIT_STORAGE_URI = os.getenv("RATELIMIT_STORAGE_URI", "memory://")
    RATELIMIT_REGISTER = os.getenv("RATELIMIT_REGISTER", "5 per hour")
    RATELIMIT_LOGIN = os.getenv("RATELIMIT_LOGIN", "10 per minute")
    RATELIMIT_REFRESH = os.getenv("RATELIMIT_REFRESH", "30 per minute")
    RATELIMIT_MESSAGES = os.getenv("RATELIMIT_MESSAGES", "30 per minute")
    RATELIMIT_RATINGS = os.getenv("RATELIMIT_RATINGS", "3 per hour")
    RATELIMIT_REPORTS = os.getenv("RATELIMIT_REPORTS", "5 per hour")

    # Public web view (SEO) — used to build absolute URLs in the sitemap,
    # canonical <link> tags, and the JSON-LD `offers.url`. In dev, unset
    # falls back to `request.host_url` so it just works.
    PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "").rstrip("/")

    # Firebase Cloud Messaging (push notifications). Optional — when unset
    # the notifications module silently no-ops so tests + local dev never
    # need a service-account file. Value is either a filesystem path or
    # the literal JSON string.
    FIREBASE_CREDENTIALS_JSON = os.getenv("FIREBASE_CREDENTIALS_JSON", "").strip()

    # Flutter Web bundle location. When unset, the webapp blueprint
    # serves from `mobile/build/web/` relative to the repo root. In
    # production, set this to an absolute path so Flask doesn't have to
    # assume the repo layout.
    WEBAPP_BUILD_DIR = os.getenv("WEBAPP_BUILD_DIR", "").strip() or None

    # ── Phase A2: SMS provider (for OTP delivery) ───────────────────
    # SMS_PROVIDER unset → NoopProvider (logs the code). Same optional
    # pattern as FIREBASE_CREDENTIALS_JSON — production wires this up
    # with a real gateway; tests + dev work without.
    SMS_PROVIDER = os.getenv("SMS_PROVIDER", "").strip().lower() or None
    SMS_FROM_NUMBER = os.getenv("SMS_FROM_NUMBER", "").strip() or None
    # Dev-only convenience: return the plaintext OTP in the API response
    # so client-side tests can complete the flow without reading logs.
    # assert_production_safe refuses to boot with this true in prod.
    SMS_DEBUG_RETURN_CODE = os.getenv("SMS_DEBUG_RETURN_CODE", "false").lower() == "true"
    # Twilio-specific (used only when SMS_PROVIDER=twilio).
    TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "").strip() or None
    TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "").strip() or None
    # OTP TTL — 10 min is standard for verification + password-reset codes.
    OTP_TTL_MINUTES = int(os.getenv("OTP_TTL_MINUTES", "10"))
    # Rate limits for the new auth endpoints.
    RATELIMIT_VERIFY_PHONE = os.getenv("RATELIMIT_VERIFY_PHONE", "5 per minute")
    RATELIMIT_FORGOT_PASSWORD = os.getenv("RATELIMIT_FORGOT_PASSWORD", "3 per hour")
    RATELIMIT_RESET_PASSWORD = os.getenv("RATELIMIT_RESET_PASSWORD", "5 per minute")

    # Default-limits safety net for every route without an explicit
    # decorator. Semicolon-separated Flask-Limiter strings. Generous
    # enough that real users never hit it; tight enough to block basic
    # abuse. Any route with its own @limiter.limit() overrides this.
    RATELIMIT_DEFAULT = os.getenv(
        "RATELIMIT_DEFAULT", "1000 per hour;100 per minute"
    )

    # ── Phase A3: launch-hygiene envs ────────────────────────────────
    # Privacy-friendly analytics — one <script> tag on public pages
    # when set (e.g. PLAUSIBLE_DOMAIN=wasit.app). Rendered nothing if
    # unset. Cookie-free, no consent banner needed.
    PLAUSIBLE_DOMAIN = os.getenv("PLAUSIBLE_DOMAIN", "").strip() or None
    # Contact info surfaced on the /contact + /privacy + /terms pages.
    # Templates render placeholder text if unset.
    SUPPORT_EMAIL = os.getenv("SUPPORT_EMAIL", "").strip() or None
    SUPPORT_WHATSAPP_URL = os.getenv("SUPPORT_WHATSAPP_URL", "").strip() or None
    COMPANY_LEGAL_NAME = os.getenv("COMPANY_LEGAL_NAME", "").strip() or None
    COMPANY_ADDRESS = os.getenv("COMPANY_ADDRESS", "").strip() or None

    # PDPL consent tracking. Bumped when the consent text materially
    # changes; stamped on BrokerProfile.consent_version at verification
    # submit + on bulk-imported brokers. Keeps an audit trail if we
    # later need to prove which text version a broker agreed to.
    PDPL_CONSENT_VERSION = os.getenv("PDPL_CONSENT_VERSION", "1.0").strip() or "1.0"


def assert_production_safe(config: Config) -> list[str]:
    """Return a list of production-hostile settings, [] if safe.

    Called from `create_app` when `FLASK_ENV=production` — the app refuses
    to boot rather than silently ship with dev secrets or wildcard CORS.
    """
    problems: list[str] = []
    if _looks_like_dev_secret(config.SECRET_KEY):
        problems.append("SECRET_KEY looks like a dev/test placeholder.")
    if _looks_like_dev_secret(config.JWT_SECRET_KEY):
        problems.append("JWT_SECRET_KEY looks like a dev/test placeholder.")
    if config.SQLALCHEMY_DATABASE_URI == _DEV_DB_SENTINEL:
        problems.append("DATABASE_URL is unset (using local dev fallback).")
    if "localhost" in config.SQLALCHEMY_DATABASE_URI.lower() \
            or "127.0.0.1" in config.SQLALCHEMY_DATABASE_URI:
        problems.append("DATABASE_URL points at localhost.")
    if config.CORS_ORIGINS == ["*"]:
        problems.append("CORS_ORIGINS is '*' — pin explicit origins in prod.")
    if config.SMS_DEBUG_RETURN_CODE:
        problems.append("SMS_DEBUG_RETURN_CODE=true leaks OTP codes in API responses.")
    return problems
