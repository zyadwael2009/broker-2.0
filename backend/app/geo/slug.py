"""URL slug helpers for the geo taxonomy.

Kept separate from `egypt.py` because slugs are a URL-layer concern —
the data model itself stores human strings ("Nasr City"). Slugs only
exist so we can construct pretty landing-page URLs like
`/browse/cairo/nasr-city`.
"""
from __future__ import annotations

import re

from .egypt import GOVERNORATES, governorate_by_en

_SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(text: str) -> str:
    """'Nasr City' → 'nasr-city'; '6th of October' → '6th-of-october'.

    ASCII-only. Non-ASCII characters (e.g. Arabic city names) collapse
    to hyphens — fine because we currently only construct slugs from
    the English side of the taxonomy.
    """
    return _SLUG_RE.sub("-", (text or "").lower()).strip("-")


def slug_for_city(city_name: str) -> str:
    """Public alias so callers don't reach for the raw regex helper."""
    return slugify(city_name)


def city_by_slug(gov_key: str, city_slug: str) -> str | None:
    """Return the DB-string city name for (gov_key, city_slug), or None.

    Case-sensitive on `gov_key` (matches the canonical values in
    `GOVERNORATES`), case-insensitive on `city_slug` (URL lower).
    """
    slug = (city_slug or "").lower()
    for gov in GOVERNORATES:
        if gov["key"] != gov_key:
            continue
        for city in gov["cities"]:
            if slugify(city) == slug:
                return city
    return None


def gov_by_slug(gov_slug: str) -> dict | None:
    """Return the governorate dict for a URL slug (e.g., 'cairo')."""
    if not gov_slug:
        return None
    key = gov_slug.lower()
    for gov in GOVERNORATES:
        if gov["key"] == key:
            return gov
    return None


# Re-export for convenience.
__all__ = [
    "slugify",
    "slug_for_city",
    "city_by_slug",
    "gov_by_slug",
    "governorate_by_en",
]
