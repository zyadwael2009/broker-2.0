"""Curated real-estate photos for `flask seed-demo`.

Downloads a hand-picked set of royalty-free photos from Unsplash on
first seed, caches them in `backend/app/cli_photos_cache/`, and hands
back JPEG bytes ready to store as listing photos.

Why Unsplash: photos are licensed for free commercial use with no
attribution required (see https://unsplash.com/license). Explicitly
NOT scraping Google Images — those are copyrighted and would create
legal risk for a client-facing demo.

Fallback: if the download fails (offline, ID went dead, whatever),
returns None so the caller can fall back to a colored-square
placeholder without failing the whole seed run.
"""
from __future__ import annotations

import io
import logging
from pathlib import Path
from typing import Iterable

log = logging.getLogger(__name__)

CACHE_DIR = Path(__file__).parent / "cli_photos_cache"

# Handpicked Unsplash photo IDs, grouped by what suits an Egyptian
# real-estate listing. Each entry is the `photo-<id>` slug that goes
# into the images.unsplash.com URL. Picked to feel like Cairo /
# Alexandria / North Coast property, not beach houses or ski chalets.
PHOTOS: dict[str, list[str]] = {
    # Apartment interiors — bright living rooms, bedrooms, hallways.
    "apartment": [
        "photo-1502672260266-1c1ef2d93688",  # bedroom w/ window
        "photo-1560448204-e02f11c3d0e2",     # living room
        "photo-1493809842364-78817add7ffb",  # sofa + coffee table
        "photo-1554995207-c18c203602cb",     # modern loft
        "photo-1522708323590-d24dbb6b0267",  # bedroom detail
        "photo-1600607687939-ce8a6c25118c",  # kitchen
    ],
    # Villa exteriors — upscale white/tan facades that could pass for
    # Sheikh Zayed / North Coast.
    "villa": [
        "photo-1613490493576-7fde63acd811",  # modern white villa
        "photo-1600596542815-ffad4c1539a9",  # villa w/ pool
        "photo-1568605114967-8130f3a36994",  # angular modern home
        "photo-1600585154340-be6161a56a0c",  # luxury exterior
        "photo-1613977257363-707ba9348227",  # night-lit villa
    ],
    # Townhouse / mid-sized house shots.
    "house": [
        "photo-1512917774080-9991f1c4c750",  # modern corner exterior
        "photo-1600566753190-17f0baa2a6c3",  # townhouse interior
        "photo-1600566752355-35792bedcfea",  # upscale living
        "photo-1502005229762-cf1b2da7c5d6",  # townhouse row
    ],
    # Empty land / plots — flat + view shots.
    "land": [
        "photo-1500382017468-9049fed747ef",  # open field
        "photo-1470770903676-69b98201ea1c",  # green plot
        "photo-1441974231531-c6227db76b6e",  # cleared land
    ],
    # Commercial — office / retail.
    "commercial": [
        "photo-1497366216548-37526070297c",  # office interior
        "photo-1497366811353-6870744d04b2",  # meeting room
        "photo-1497215842964-222b430dc094",  # retail shopfront
    ],
}


def _cdn_url(photo_id: str) -> str:
    # w=1200 is plenty for the card grid + detail gallery; q=80 keeps
    # file size around 100–200 KB per photo.
    return f"https://images.unsplash.com/{photo_id}?w=1200&q=80&fm=jpg"


def _cache_path(photo_id: str) -> Path:
    return CACHE_DIR / f"{photo_id}.jpg"


def _download_photo(photo_id: str, timeout: float = 15.0) -> bytes | None:
    """Return JPEG bytes for `photo_id`. Caches to disk on first
    fetch. Returns None on any error so the caller can fall back."""
    cache_path = _cache_path(photo_id)
    if cache_path.exists() and cache_path.stat().st_size > 0:
        return cache_path.read_bytes()

    try:
        # Local import — requests may not be present in a stripped
        # test env. seed-demo isn't part of the test path anyway.
        import requests

        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        r = requests.get(_cdn_url(photo_id), timeout=timeout)
        if r.status_code != 200:
            log.warning("Photo %s: HTTP %s", photo_id, r.status_code)
            return None
        # Sanity-check the response is actually a JPEG (Unsplash always
        # returns image/jpeg with fm=jpg, but be defensive).
        data = r.content
        if not data or not data.startswith(b"\xff\xd8"):
            log.warning("Photo %s: not a JPEG (%d bytes)", photo_id, len(data))
            return None
        cache_path.write_bytes(data)
        return data
    except Exception as exc:  # noqa: BLE001 — best-effort downloader
        log.warning("Photo %s: %s", photo_id, exc)
        return None


def photos_for(category: str, count: int, seed: int) -> list[bytes]:
    """Return up to `count` JPEG-byte blobs of the given category.

    `seed` picks a stable rotation into the category list so the same
    listing gets the same photos across reseeds (screenshot stability).
    Missing/failed downloads are silently dropped — the caller decides
    what to do if the returned list is short.
    """
    ids: list[str] = PHOTOS.get(category, [])
    if not ids:
        return []
    # Rotate the list by `seed` so different listings of the same
    # category get different photos.
    start = seed % len(ids)
    ordered = ids[start:] + ids[:start]

    out: list[bytes] = []
    for photo_id in ordered:
        if len(out) >= count:
            break
        data = _download_photo(photo_id)
        if data is not None:
            out.append(data)
    return out
