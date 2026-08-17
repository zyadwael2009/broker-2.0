"""Flask application factory.

Everything is wired through env vars so the same code runs on any host
(PythonAnywhere, Railway, Fly, bare metal). No host-specific imports here.
"""
from __future__ import annotations

import os

from flask import Flask, jsonify

from .config import Config, assert_production_safe
from .extensions import db, migrate, jwt, bcrypt, cors
from .errors import register_error_handlers


def create_app(config_class: type[Config] = Config) -> Flask:
    # Sentry FIRST — must init before Flask so errors during boot are captured.
    _init_sentry_if_configured()

    app = Flask(__name__)
    app.config.from_object(config_class())

    # Refuse to boot in production with dev secrets / open CORS.
    if os.getenv("FLASK_ENV", "").lower() == "production":
        problems = assert_production_safe(config_class())
        if problems:
            raise RuntimeError(
                "Refusing to start in FLASK_ENV=production with insecure config:\n  - "
                + "\n  - ".join(problems)
            )

    # Extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    bcrypt.init_app(app)
    cors.init_app(
        app,
        resources={r"/*": {"origins": app.config["CORS_ORIGINS"]}},
        supports_credentials=False,
    )
    from .extensions import limiter
    limiter.enabled = app.config["RATELIMIT_ENABLED"]
    limiter.storage_uri = app.config["RATELIMIT_STORAGE_URI"]
    # Flask-Limiter reads RATELIMIT_DEFAULT from Flask config on
    # init_app — no explicit wiring needed. Route-level @limiter.limit()
    # decorators still override the default.
    limiter.init_app(app)

    # Import models so Alembic sees them via `db.metadata`.
    # Kept inside the factory to avoid circular imports.
    from . import models  # noqa: F401

    # JWT revocation — consulted on every @jwt_required.
    from .auth.revocation import revocation_list
    from .models.user import User

    @jwt.token_in_blocklist_loader
    def _is_revoked(_jwt_header, jwt_payload):
        # First: per-JTI blocklist (login rotation, explicit logout).
        if revocation_list.is_revoked(jwt_payload.get("jti", "")):
            return True
        # Session-invalidation-on-password-change: any JWT issued
        # BEFORE the user's password was last changed is revoked. Closes
        # the A2 known gap — reset-password now truly kills old sessions.
        iat = jwt_payload.get("iat")
        sub = jwt_payload.get("sub")
        if not (iat and sub):
            return False
        try:
            user = db.session.get(User, int(sub))
        except (TypeError, ValueError):
            return False
        if user is None or user.password_changed_at is None:
            return False
        # SQLite strips tzinfo on read — coerce to UTC before comparing.
        # JWT iat is int seconds; password_changed_at has microseconds.
        # Truncate the DB side to int too so a login issued in the SAME
        # second as the reset isn't wrongly revoked.
        from datetime import timezone as _tz
        changed = user.password_changed_at
        if changed.tzinfo is None:
            changed = changed.replace(tzinfo=_tz.utc)
        return int(iat) < int(changed.timestamp())

    # Blueprints
    from .auth.routes import auth_bp
    from .brokers.routes import brokers_bp
    from .admin.routes import admin_bp
    from .files.routes import files_bp
    from .listings.routes import listings_bp
    from .documents.routes import documents_bp
    from .market.routes import market_bp
    from .messaging.routes import messaging_bp
    from .ratings.routes import ratings_bp
    from .reports.routes import reports_bp
    from .public.routes import public_bp
    from .devices.routes import devices_bp
    from .webapp.routes import webapp_bp
    app.register_blueprint(auth_bp, url_prefix="/auth")
    app.register_blueprint(brokers_bp, url_prefix="/brokers")
    app.register_blueprint(admin_bp, url_prefix="/admin")
    app.register_blueprint(files_bp, url_prefix="/files")
    app.register_blueprint(listings_bp, url_prefix="/listings")
    # Document endpoints hang off /listings/<id>/documents; sharing the
    # /listings prefix keeps the URL flat for the mobile client.
    app.register_blueprint(documents_bp, url_prefix="/listings")
    app.register_blueprint(market_bp, url_prefix="/market")
    app.register_blueprint(messaging_bp, url_prefix="/threads")
    # Ratings hang off /brokers/<id>/ratings, same convention as documents.
    app.register_blueprint(ratings_bp, url_prefix="/brokers")
    app.register_blueprint(reports_bp)
    # Public web view — HTML at /, /browse, /l/<id> + sitemap/robots +
    # /api/public/*. No URL prefix on purpose: SEO shareable URLs live
    # at the root of the domain.
    app.register_blueprint(public_bp)
    # Push-notification device registration.
    app.register_blueprint(devices_bp, url_prefix="/devices")
    # Flutter Web bundle — the interactive app inside a browser.
    app.register_blueprint(webapp_bp, url_prefix="/app")

    # CLI commands
    from .cli import register_cli
    register_cli(app)

    # Error handlers
    register_error_handlers(app)

    @app.get("/health")
    def health():
        return jsonify(status="ok"), 200

    # Initialise Firebase Admin so the push helper can call into it. Kept
    # after blueprints so an FCM crash can never block route registration.
    _init_firebase_if_configured(app)

    return app


def _init_sentry_if_configured() -> None:
    """No-op when SENTRY_DSN isn't set — tests, local dev, and anyone
    who doesn't want it just work."""
    dsn = os.getenv("SENTRY_DSN", "").strip()
    if not dsn:
        return
    try:
        import sentry_sdk
        from sentry_sdk.integrations.flask import FlaskIntegration
    except ImportError:
        # sentry-sdk isn't installed in this environment — silently skip.
        return
    sentry_sdk.init(
        dsn=dsn,
        integrations=[FlaskIntegration()],
        traces_sample_rate=float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.0")),
        environment=os.getenv("SENTRY_ENVIRONMENT", "dev"),
        release=os.getenv("SENTRY_RELEASE"),
        # Don't ship PII like phone numbers by default.
        send_default_pii=False,
    )


def _init_firebase_if_configured(app: Flask) -> None:
    """No-op when FIREBASE_CREDENTIALS_JSON is unset. Same pattern as
    Sentry — tests and local dev never need a real Firebase project."""
    from .notifications import fcm, sms
    fcm.init_from_config(app.config)
    # SMS uses the same 'optional' pattern — unset provider = log-only noop.
    sms.init_from_config(app.config)
