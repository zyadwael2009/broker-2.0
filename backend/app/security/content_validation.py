"""Magic-byte content-type validation for uploaded files.

The declared extension + MIME type from `werkzeug`'s form parsing are
trivially forgeable — an attacker can rename `evil.sh` to `evil.pdf` or
send `Content-Type: image/jpeg` with arbitrary bytes. Every upload route
must sniff the actual file header before persisting it.

Kept dependency-free: reading the first ~12 bytes is enough to
distinguish the four types we accept.
"""
from __future__ import annotations

from typing import Iterable


class ContentTypeError(ValueError):
    """Raised when the file's actual bytes don't match its declared kind."""


# The kinds we serve. `all_kinds` is the union used for broker verification
# docs; listing photos use `image_kinds` only; listing documents use
# `all_kinds` again.
image_kinds = frozenset({"jpeg", "png", "webp"})
document_kinds = frozenset({"pdf"}) | image_kinds


def sniff_kind(head: bytes) -> str | None:
    """Return `'pdf' | 'jpeg' | 'png' | 'webp' | None`.

    Requires at least the first 12 bytes; anything shorter is treated as
    an unknown kind."""
    if len(head) < 12:
        return None

    # PDF: %PDF-
    if head.startswith(b"%PDF-"):
        return "pdf"

    # JPEG: FF D8 FF (JFIF/EXIF variants share this three-byte SOI+marker).
    if head[0] == 0xFF and head[1] == 0xD8 and head[2] == 0xFF:
        return "jpeg"

    # PNG: 89 50 4E 47 0D 0A 1A 0A
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"

    # WebP: 'RIFF' <4-byte size> 'WEBP'
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"

    return None


def read_and_validate(
    stream, allowed: Iterable[str], max_bytes: int | None = None
) -> bytes:
    """Read the whole stream, sniff the header, raise on mismatch.

    Returns the bytes so callers can hand them to storage without a
    second read. `stream` is typically `request.files[...].stream` — a
    SpooledTemporaryFile-backed werkzeug FileStorage.
    """
    data = stream.read(max_bytes) if max_bytes else stream.read()
    if not data:
        raise ContentTypeError("Empty file.")
    kind = sniff_kind(data[:12])
    if kind is None:
        raise ContentTypeError(
            "Could not identify file type from its contents."
        )
    if kind not in allowed:
        raise ContentTypeError(
            f"File type {kind!r} not allowed here (accepted: {sorted(allowed)})."
        )
    return data
