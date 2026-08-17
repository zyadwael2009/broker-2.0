"""JSON error handlers. Keeps API responses consistent so the Flutter client
never has to parse HTML error pages."""
from __future__ import annotations

from flask import Flask, jsonify
from marshmallow import ValidationError
from sqlalchemy.exc import IntegrityError
from werkzeug.exceptions import HTTPException


def _json_error(message: str, status: int, **extra):
    payload = {"error": message}
    payload.update(extra)
    return jsonify(payload), status


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(ValidationError)
    def handle_validation(err: ValidationError):
        return _json_error("Validation failed", 400, fields=err.messages)

    @app.errorhandler(IntegrityError)
    def handle_integrity(err: IntegrityError):
        # Most likely duplicate phone/email. Keep the message generic so we
        # don't leak which field collided when that matters.
        return _json_error("Conflict with existing record", 409)

    @app.errorhandler(HTTPException)
    def handle_http(err: HTTPException):
        # Preserve headers on 429 (Retry-After) so clients can back off cleanly.
        payload = {"error": err.description or err.name}
        if err.code == 429:
            payload["error"] = "Too many requests. Please slow down and try again shortly."
        response = jsonify(payload)
        response.status_code = err.code or 500
        for key, value in (err.get_response().headers.items() if err.code == 429 else []):
            if key.lower() == "retry-after":
                response.headers[key] = value
        return response

    @app.errorhandler(Exception)
    def handle_unexpected(err: Exception):
        app.logger.exception("Unhandled exception")
        return _json_error("Internal server error", 500)
