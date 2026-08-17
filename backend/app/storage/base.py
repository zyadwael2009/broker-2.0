"""Storage protocol. Any concrete backend must implement these four ops."""
from __future__ import annotations

from typing import BinaryIO, Protocol


class Storage(Protocol):
    def put(self, key: str, stream: BinaryIO, content_type: str | None = None) -> str:
        """Persist stream under `key`. Returns the canonical storage path/URL."""
        ...

    def get(self, key: str) -> BinaryIO:
        """Return a readable binary stream for `key`."""
        ...

    def delete(self, key: str) -> None:
        """Remove `key`. No error if absent."""
        ...

    def url(self, key: str) -> str:
        """Return a URL/path the client can reference. For local disk this
        is a relative path; for S3 it would be a presigned URL."""
        ...
