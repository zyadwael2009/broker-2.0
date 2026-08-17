"""Perceptual-hash helpers for duplicate photo detection.

Uses `imagehash.phash` — a robust 64-bit DCT-based hash that survives
scaling, mild compression, and light color adjustments. Photos that share
a hash within Hamming distance ~8 are almost always visually identical
(reposts, same photo cropped, same photo re-encoded).

We store the hash as its 16-char hex string; comparison is done in Python
because SQLite has no native XOR-popcount. For MVP scale (thousands of
photos), a full scan on upload is trivially fast (<1ms).
"""
from __future__ import annotations

from io import BytesIO
from typing import Iterable

import imagehash
from PIL import Image, UnidentifiedImageError

# Two photos are considered near-duplicates when their pHashes differ in
# at most this many bits. 8 is the widely-used default for phash.
DUPLICATE_THRESHOLD_BITS = 8


class PhashError(ValueError):
    """Raised when the image bytes can't be decoded as an image."""


def compute_phash(image_bytes: bytes) -> str:
    """Return the 16-char hex representation of the image's pHash."""
    try:
        img = Image.open(BytesIO(image_bytes))
        img.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise PhashError(f"Not a valid image: {exc}") from exc
    return str(imagehash.phash(img))


def hamming_distance_hex(a: str, b: str) -> int:
    """Hamming distance between two hex-encoded 64-bit hashes."""
    if len(a) != len(b):
        raise ValueError("Hash length mismatch")
    return bin(int(a, 16) ^ int(b, 16)).count("1")


def find_near_duplicate(
    phash: str, candidates: Iterable[tuple[int, str]]
) -> int | None:
    """Return the listing_id of the first candidate within threshold, or None.

    `candidates` is an iterable of `(listing_id, phash_hex)` tuples — the
    caller filters out photos on the same listing before calling.
    """
    for listing_id, other in candidates:
        try:
            if hamming_distance_hex(phash, other) <= DUPLICATE_THRESHOLD_BITS:
                return listing_id
        except ValueError:
            continue
    return None
