"""Canonical Egyptian geo — hardcoded because this data changes maybe
once a decade and is small enough to live in code.

Exposes helpers used by the browse route + templates + create-listing
form:

    from app.geo import GOVERNORATES, cities_for, all_governorates
    from app.geo import slugify, city_by_slug, gov_by_slug
"""
from .egypt import (
    GOVERNORATES,
    all_governorates,
    cities_for,
    governorate_by_en,
    is_valid_governorate,
)
from .slug import (
    city_by_slug,
    gov_by_slug,
    slug_for_city,
    slugify,
)

__all__ = [
    "GOVERNORATES",
    "all_governorates",
    "cities_for",
    "governorate_by_en",
    "is_valid_governorate",
    "slugify",
    "slug_for_city",
    "city_by_slug",
    "gov_by_slug",
]
