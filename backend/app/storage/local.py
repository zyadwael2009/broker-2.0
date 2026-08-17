"""Local-disk storage backend. Fine for dev and Phase 1; swap to S3 later
without touching callers by adjusting `STORAGE_BACKEND=s3` and adding
`S3Storage` in this package."""
from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import BinaryIO


class LocalDiskStorage:
    def __init__(self, root: str | os.PathLike):
        self.root = Path(root).resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def _abs(self, key: str) -> Path:
        # Guard against path traversal — reject anything that escapes root.
        # Use is_relative_to (not startswith) so that a sibling directory
        # sharing a prefix — e.g. /var/uploads vs /var/uploadsX — is caught.
        target = (self.root / key).resolve()
        try:
            target.relative_to(self.root)
        except ValueError as exc:
            raise ValueError(f"Illegal storage key: {key!r}") from exc
        return target

    def put(self, key: str, stream: BinaryIO, content_type: str | None = None) -> str:
        target = self._abs(key)
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(target, "wb") as fh:
            shutil.copyfileobj(stream, fh)
        return str(target.relative_to(self.root)).replace(os.sep, "/")

    def get(self, key: str) -> BinaryIO:
        return open(self._abs(key), "rb")

    def delete(self, key: str) -> None:
        try:
            self._abs(key).unlink()
        except FileNotFoundError:
            pass

    def url(self, key: str) -> str:
        # Local backend has no HTTP server for uploads yet. Return the
        # storage-relative path; a future /files/<key> route (or S3
        # presigned URL) can replace this.
        return f"/files/{key}"
