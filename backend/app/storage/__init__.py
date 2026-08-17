"""Storage abstraction. Call sites use `get_storage()`; the concrete
backend (local disk today, S3 later) is picked from config."""
from __future__ import annotations

from flask import current_app

from .base import Storage
from .local import LocalDiskStorage


def get_storage() -> Storage:
    backend = current_app.config.get("STORAGE_BACKEND", "local").lower()
    if backend == "local":
        return LocalDiskStorage(current_app.config["UPLOAD_DIR"])
    # S3Storage will land here in a later phase without touching callers.
    raise ValueError(f"Unsupported STORAGE_BACKEND: {backend!r}")


__all__ = ["Storage", "LocalDiskStorage", "get_storage"]
