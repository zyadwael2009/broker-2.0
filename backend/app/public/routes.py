"""Public (no-auth) HTML pages + JSON endpoints for SEO and social sharing.

Design notes:
- The HTML pages are hand-written Jinja templates with a small
  hand-rolled CSS file (no CDN — CSP-friendly and works offline).
- The JSON endpoints intentionally strip the broker's phone/email; only
  authenticated /listings gives contact details, so a broker's number
  can't be scraped by search-engine indexers or unauth callers.
- Sitemap and robots are generated on request — no build step, no cron.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal

from flask import (
    Blueprint,
    Response,
    abort,
    current_app,
    jsonify,
    render_template,
    request,
    url_for,
)

from ..extensions import db
from ..geo import GOVERNORATES, all_governorates, cities_for
from ..geo.slug import city_by_slug, gov_by_slug, slugify
from ..listings.routes import apply_listing_filters
from ..models.broker_profile import BrokerProfile, VerificationStatus
from ..models.broker_rating import BrokerRating
from ..models.listing import Listing, ListingKind, ListingStatus, PropertyType
from ..models.listing_view import ListingViewDay
from ..models.user import User, UserRole
from ..ratings.aggregate import aggregate_for, aggregate_for_many
from ..storage import get_storage

public_bp = Blueprint("public", __name__, template_folder="../templates")

# Must match listings.LISTING_TTL — imported lazily to avoid a hard
# dependency cycle if the listings module ever gets reorganized.
LISTING_TTL = timedelta(days=30)


# ── helpers ────────────────────────────────────────────────────────────

def _active_verified_query():
    """Base query: ACTIVE listings whose broker is active AND verified,
    and which haven't fallen off the 30-day auto-expire cliff.

    Anything shown to anonymous callers has to pass this bar — the whole
    point of the trust system is that random Google visitors don't stumble
    onto sketchy listings.
    """
    from sqlalchemy import func

    now = datetime.now(timezone.utc)
    cutoff = now - LISTING_TTL
    baseline = func.coalesce(Listing.last_confirmed_at, Listing.created_at)
    return (
        Listing.query
        .join(User, Listing.broker_id == User.id)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(Listing.status == ListingStatus.ACTIVE)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .filter(baseline > cutoff)
    )


def _sanitized_broker(listing: Listing, rating: dict | None = None) -> dict:
    """Broker payload for anonymous callers — no phone, no email."""
    b = listing.broker
    if b is None:
        return {}
    return {
        "id": b.id,
        "full_name": b.full_name,
        "verification_status": (
            b.broker_profile.verification_status.value
            if b.broker_profile is not None
            else "pending"
        ),
        "rating": rating if rating is not None else aggregate_for(b.id),
    }


def _sanitized_listing(listing: Listing, rating: dict | None = None) -> dict:
    """JSON payload of one listing for anonymous callers.

    Shape mirrors the authenticated /listings response so a future client
    can share DTO parsing, minus contact details on the broker.
    """
    storage = get_storage()
    return {
        "id": listing.id,
        "title": listing.title,
        "description": listing.description,
        "price_egp": str(listing.price_egp) if listing.price_egp is not None else None,
        "area_m2": str(listing.area_m2) if listing.area_m2 is not None else None,
        "governorate": listing.governorate,
        "city": listing.city,
        "district": listing.district,
        "lat": listing.lat,
        "lng": listing.lng,
        "property_type": listing.property_type.value,
        "status": listing.status.value,
        "listing_kind": listing.listing_kind.value if listing.listing_kind else "sale",
        "bedrooms": listing.bedrooms,
        "bathrooms": listing.bathrooms,
        "floor_number": listing.floor_number,
        "is_furnished": listing.is_furnished,
        "compound_name": listing.compound_name,
        "delivery_status": (
            listing.delivery_status.value if listing.delivery_status else None
        ),
        "created_at": listing.created_at.isoformat() if listing.created_at else None,
        "last_confirmed_at": (
            listing.last_confirmed_at.isoformat()
            if listing.last_confirmed_at else None
        ),
        "photos": [
            p.to_public_dict(storage.url(p.storage_key)) for p in listing.photos
        ],
        "broker": _sanitized_broker(listing, rating),
    }


def _public_base_url() -> str:
    """Absolute base for canonical URLs / sitemap entries.

    Falls back to `request.host_url` in dev so `/l/1` works out of the
    box without setting the env var. Trailing slash always stripped.
    """
    base = (current_app.config.get("PUBLIC_BASE_URL") or "").rstrip("/")
    if base:
        return base
    return request.host_url.rstrip("/")


def _absolute(path: str) -> str:
    """Join a leading-slash path onto the public base URL."""
    if path.startswith(("http://", "https://")):
        return path
    if not path.startswith("/"):
        path = "/" + path
    return _public_base_url() + path


def _whatsapp_share_url(text: str, url: str) -> str:
    """Compose a wa.me share URL. Text + URL on separate lines — this
    is the shape WhatsApp's own share button emits so the preview card
    resolves cleanly. Zero-JS, no auth, works on every WhatsApp client."""
    from urllib.parse import quote
    body = f"{text}\n{url}"
    return f"https://wa.me/?text={quote(body, safe='')}"


def _price_display(v: Decimal | None) -> str:
    if v is None:
        return ""
    # Egyptian real estate is priced in whole pounds; show grouped digits.
    try:
        return f"{int(v):,}"
    except Exception:
        return str(v)


# ── JSON endpoints (no auth) ───────────────────────────────────────────

@public_bp.get("/api/public/listings")
def api_listings():
    q = _active_verified_query()
    q, err = apply_listing_filters(q, request.args)
    if err is not None:
        return err

    # Bounded so anonymous scraping can't drain the DB.
    limit = min(int(request.args.get("limit", "60")), 200)
    q = q.order_by(Listing.created_at.desc()).limit(limit)
    rows = q.all()

    ratings = aggregate_for_many({l.broker_id for l in rows if l.broker_id})
    return jsonify([
        _sanitized_listing(l, ratings.get(l.broker_id)) for l in rows
    ]), 200


@public_bp.get("/api/public/listings/<int:listing_id>")
def api_listing(listing_id: int):
    listing = _active_verified_query().filter(Listing.id == listing_id).first()
    if listing is None:
        return jsonify(error="Listing not found."), 404
    return jsonify(_sanitized_listing(listing)), 200


# ── HTML pages ─────────────────────────────────────────────────────────

@public_bp.get("/")
def home():
    """SEO landing — small, fast, links into /browse."""
    return render_template(
        "home.html",
        canonical=_absolute("/"),
        site_name="Wasit — Verified brokers for Egyptian real estate",
    )


@public_bp.get("/privacy")
def privacy():
    """Placeholder privacy policy — clearly marked as draft."""
    return render_template("privacy.html", canonical=_absolute("/privacy"))


@public_bp.get("/terms")
def terms():
    """Placeholder terms of service — clearly marked as draft."""
    return render_template("terms.html", canonical=_absolute("/terms"))


@public_bp.get("/contact")
def contact():
    """Support + press + legal contact channels."""
    return render_template("contact.html", canonical=_absolute("/contact"))


@public_bp.get("/for-brokers")
def for_brokers():
    """Sales page aimed at brokers. Zero DB queries — pure marketing.

    Linked from the home page hero, the top-bar 'For brokers' link, and
    the 'Get verified' CTA in the top-bar. Any broker-only CTA on the
    site ultimately funnels here.
    """
    # Show a count of currently-verified brokers as social proof, but
    # keep it optional — a fresh install with 0 brokers renders cleanly.
    verified_broker_count = (
        db.session.query(User)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(User.role == UserRole.BROKER)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .count()
    )
    return render_template(
        "for_brokers.html",
        canonical=_absolute("/for-brokers"),
        verified_broker_count=verified_broker_count,
    )


# ── Shared card builder for /browse and the SEO landing pages ────────

def _build_card_dicts(listings: list[Listing]) -> list[dict]:
    """Turn a list of Listing rows into the dicts the card partial expects.

    Extracted so `/browse` and the G3 landing pages render identically.
    """
    ratings = aggregate_for_many({l.broker_id for l in listings if l.broker_id})
    storage = get_storage()
    cards: list[dict] = []
    for l in listings:
        cover = l.photos[0] if l.photos else None
        broker_name = l.broker.full_name if l.broker is not None else None
        cards.append({
            "id": l.id,
            "title": l.title,
            "price_display": _price_display(l.price_egp),
            "price_egp": l.price_egp,
            "area_m2": str(l.area_m2) if l.area_m2 is not None else "",
            "governorate": l.governorate,
            "city": l.city,
            "cover_url": _absolute(storage.url(cover.storage_key)) if cover else None,
            "rating": ratings.get(l.broker_id) or {"avg": 0.0, "count": 0},
            "url": _absolute(url_for("public.listing_page", listing_id=l.id)),
            "broker_id": l.broker_id,
            "broker_name": broker_name,
            "broker_url": (
                _absolute(url_for("public.broker_page", broker_id=l.broker_id))
                if l.broker_id else None
            ),
            # Phase A1 richer fields — surface on card for filter feedback.
            "listing_kind": l.listing_kind.value if l.listing_kind else "sale",
            "bedrooms": l.bedrooms,
            "bathrooms": l.bathrooms,
            "compound_name": l.compound_name,
        })
    return cards


# ── SEO landing pages (Phase G3) ──────────────────────────────────────

# Closed set of facet slugs that appear at the second URL segment.
# These take priority over city slugs during disambiguation — a future
# city named "Apartments" would collide, but we'll cross that bridge
# if we get there.
_FACET_MAP = {
    "apartments":  ("property_type", PropertyType.APARTMENT, "Apartments"),
    "villas":      ("property_type", PropertyType.VILLA, "Villas"),
    "houses":      ("property_type", PropertyType.HOUSE, "Houses"),
    "land":        ("property_type", PropertyType.LAND, "Land"),
    "commercial":  ("property_type", PropertyType.COMMERCIAL, "Commercial property"),
    "for-sale":    ("kind", ListingKind.SALE, "For sale"),
    "for-rent":    ("kind", ListingKind.RENT, "For rent"),
}

# Governorates that get facet landing pages in the sitemap. Every gov
# supports every URL, but we only *advertise* facet URLs for the big
# ones to keep the sitemap tight and focused on high-intent traffic.
_TOP_GOV_KEYS_FOR_FACETS = ("cairo", "giza", "alexandria", "6th-of-october")


def _landing_copy(gov: dict, city: str | None, facet_slug: str | None,
                  count: int) -> dict:
    """Auto-generate title/description/H1/intro for a landing page.

    Kept deterministic so refreshing the page doesn't churn the SEO copy.
    All strings mention the count + verification promise (our moat).
    """
    gov_en = gov["en"]
    if city is not None:
        subject = f"{city}, {gov_en}"
    else:
        subject = gov_en

    facet_label = None
    if facet_slug is not None:
        facet_label = _FACET_MAP[facet_slug][2]

    if facet_label is None:
        h1 = f"Property in {subject}"
        title = f"Property in {subject} | Wasit"
    elif facet_slug in ("for-sale", "for-rent"):
        # "For rent in Nasr City" reads better than "Property for rent…"
        h1 = f"{facet_label} in {subject}"
        title = f"Property {facet_label.lower()} in {subject} | Wasit"
    else:
        # "Apartments in Cairo"
        h1 = f"{facet_label} in {subject}"
        title = f"{facet_label} in {subject} | Wasit"

    intro = (
        f"Browse {count} verified {facet_label.lower() if facet_label else 'property'} "
        f"listing{'s' if count != 1 else ''} in {subject}. "
        f"Every broker on Wasit is registered with the Egyptian General "
        f"Organization for Import & Export Control (GOEIC) — you can "
        f"contact them directly without middlemen."
    )
    # Meta description is the intro trimmed to ~160 chars — Google truncates
    # around there anyway.
    description = intro if len(intro) <= 160 else intro[:157].rstrip() + "…"
    return {"title": title, "description": description, "h1": h1, "intro": intro}


def _breadcrumb_ld(gov: dict, city: str | None, facet_slug: str | None) -> dict:
    items = [
        {"@type": "ListItem", "position": 1, "name": "Home",
         "item": _absolute("/")},
        {"@type": "ListItem", "position": 2, "name": "Browse",
         "item": _absolute("/browse")},
        {"@type": "ListItem", "position": 3, "name": gov["en"],
         "item": _absolute(f"/browse/{gov['key']}")},
    ]
    if city is not None:
        items.append({
            "@type": "ListItem", "position": 4, "name": city,
            "item": _absolute(f"/browse/{gov['key']}/{slugify(city)}"),
        })
    elif facet_slug is not None:
        items.append({
            "@type": "ListItem", "position": 4,
            "name": _FACET_MAP[facet_slug][2],
            "item": _absolute(f"/browse/{gov['key']}/{facet_slug}"),
        })
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": items,
    }


def _item_list_ld(cards: list[dict]) -> dict:
    """ItemList of RealEstateListing items. Google indexes the
    aggregate; individual /l/<id> pages get their own Product LD."""
    return {
        "@context": "https://schema.org",
        "@type": "ItemList",
        "numberOfItems": len(cards),
        "itemListElement": [
            {
                "@type": "ListItem",
                "position": i + 1,
                "url": c["url"],
                "item": {
                    "@type": "RealEstateListing",
                    "name": c["title"],
                    "image": c["cover_url"],
                    "url": c["url"],
                    "offers": {
                        "@type": "Offer",
                        "price": str(c["price_egp"]) if c.get("price_egp") is not None else "0",
                        "priceCurrency": "EGP",
                    },
                },
            }
            for i, c in enumerate(cards)
        ],
    }


def _render_landing(gov: dict, city: str | None = None,
                    facet_slug: str | None = None):
    """Build and render a landing page. Returns a 404 if the resulting
    query has zero rows — thin pages are worse than no page for SEO."""
    q = _active_verified_query().filter(Listing.governorate == gov["en"])
    if city is not None:
        q = q.filter(Listing.city == city)
    if facet_slug is not None:
        col_key, enum_value, _ = _FACET_MAP[facet_slug]
        if col_key == "property_type":
            q = q.filter(Listing.property_type == enum_value)
        elif col_key == "kind":
            q = q.filter(Listing.listing_kind == enum_value)

    listings = q.order_by(Listing.created_at.desc()).limit(60).all()
    if not listings:
        abort(404)

    cards = _build_card_dicts(listings)
    copy = _landing_copy(gov, city, facet_slug, len(cards))

    # Canonical URL for THIS landing (not the query-string variant).
    if city is not None:
        canonical_path = f"/browse/{gov['key']}/{slugify(city)}"
    elif facet_slug is not None:
        canonical_path = f"/browse/{gov['key']}/{facet_slug}"
    else:
        canonical_path = f"/browse/{gov['key']}"

    # Related-locations block: sibling cities under the same
    # governorate, top 8 by listing count. Cheap query so we do it
    # inline rather than caching.
    from sqlalchemy import func as _sqlfunc
    now = datetime.now(timezone.utc)
    cutoff = now - LISTING_TTL
    baseline = _sqlfunc.coalesce(Listing.last_confirmed_at, Listing.created_at)
    sibling_rows = (
        db.session.query(Listing.city, _sqlfunc.count(Listing.id))
        .join(User, Listing.broker_id == User.id)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(Listing.status == ListingStatus.ACTIVE)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .filter(baseline > cutoff)
        .filter(Listing.governorate == gov["en"])
        .group_by(Listing.city)
        .order_by(_sqlfunc.count(Listing.id).desc())
        .limit(9)  # 8 shown + 1 in case current city is one of them
        .all()
    )
    related_locations = []
    for c_name, c_count in sibling_rows:
        if not c_name or c_name == city:
            continue
        related_locations.append({
            "name": c_name,
            "count": int(c_count or 0),
            "url": _absolute(f"/browse/{gov['key']}/{slugify(c_name)}"),
        })
        if len(related_locations) >= 8:
            break

    breadcrumb_ld = _breadcrumb_ld(gov, city, facet_slug)
    item_list_ld = _item_list_ld(cards)

    # Breadcrumb UI data (mirrors the JSON-LD).
    breadcrumbs = [
        {"name": "Home", "url": _absolute("/")},
        {"name": "Browse", "url": _absolute("/browse")},
        {"name": gov["en"], "url": _absolute(f"/browse/{gov['key']}")},
    ]
    if city is not None:
        breadcrumbs.append({"name": city, "url": _absolute(canonical_path)})
    elif facet_slug is not None:
        breadcrumbs.append({
            "name": _FACET_MAP[facet_slug][2],
            "url": _absolute(canonical_path),
        })

    return render_template(
        "landing.html",
        listings=cards,
        gov=gov,
        city=city,
        facet_slug=facet_slug,
        title_text=copy["title"],
        description=copy["description"],
        h1=copy["h1"],
        intro=copy["intro"],
        canonical=_absolute(canonical_path),
        breadcrumbs=breadcrumbs,
        related_locations=related_locations,
        json_ld=[breadcrumb_ld, item_list_ld],
        count=len(cards),
    )


@public_bp.get("/browse/<gov_slug>")
def landing_gov(gov_slug: str):
    gov = gov_by_slug(gov_slug)
    if gov is None:
        abort(404)
    return _render_landing(gov)


@public_bp.get("/browse/<gov_slug>/<slug>")
def landing_gov_facet_or_city(gov_slug: str, slug: str):
    gov = gov_by_slug(gov_slug)
    if gov is None:
        abort(404)
    slug_l = slug.lower()
    # Facet slugs take priority (closed set, all English type words).
    if slug_l in _FACET_MAP:
        return _render_landing(gov, facet_slug=slug_l)
    # Otherwise try city lookup.
    city = city_by_slug(gov["key"], slug_l)
    if city is None:
        abort(404)
    return _render_landing(gov, city=city)


@public_bp.get("/browse")
def browse():
    q = _active_verified_query()
    q, err = apply_listing_filters(q, request.args)
    if err is not None:
        # Bad filter arg — silently ignore rather than 400ing an HTML page.
        # Fall back to the unfiltered feed.
        q = _active_verified_query()

    q = q.order_by(Listing.created_at.desc()).limit(60)
    listings = q.all()
    cards = _build_card_dicts(listings)

    # Values currently selected — echoed back so the template highlights
    # the active chips.
    selected = {
        "kind": request.args.get("kind") or "",
        "governorate": request.args.get("governorate") or "",
        "city": request.args.get("city") or "",
        "property_type": request.args.get("property_type") or "",
        "bedrooms_min": request.args.get("bedrooms_min") or "",
        "min_price": request.args.get("min_price") or "",
        "max_price": request.args.get("max_price") or "",
    }

    # Governorate → city dropdown data. Pre-fill cities for the selected
    # governorate so the initial render is right (no JS needed for a
    # first-paint), then inline JS repopulates on change.
    initial_cities = cities_for(selected["governorate"]) if selected["governorate"] else []

    return render_template(
        "browse.html",
        listings=cards,
        selected=selected,
        governorates=all_governorates(),
        initial_cities=initial_cities,
        cities_by_gov={g["en"]: g["cities"] for g in GOVERNORATES},
        property_types=[t.value for t in PropertyType],
        listing_kinds=[k.value for k in ListingKind],
        canonical=_absolute("/browse"),
    )


def _record_listing_view(listing_id: int) -> None:
    """Fire-and-forget view increment for broker analytics.

    Called from `listing_page` for anonymous + non-owner viewers. Bumps
    the ListingViewDay row for today (create-if-missing) AND the
    Listing.total_views counter. Any DB error is swallowed — a broken
    counter must never break the page render.
    """
    from datetime import date
    try:
        today = date.today()
        row = ListingViewDay.query.filter_by(
            listing_id=listing_id, day=today
        ).first()
        if row is None:
            db.session.add(ListingViewDay(
                listing_id=listing_id, day=today, count=1,
            ))
        else:
            row.count = row.count + 1
        # Atomic bump on the counter column.
        db.session.query(Listing).filter_by(id=listing_id).update(
            {Listing.total_views: Listing.total_views + 1}
        )
        db.session.commit()
    except Exception:  # noqa: BLE001
        db.session.rollback()


def _viewer_is_owner(broker_id: int | None) -> bool:
    """Optional-JWT peek. Only skips the increment when we can PROVE
    the viewer is the listing's own broker. Anonymous / other-user /
    invalid-token all count."""
    if broker_id is None:
        return False
    try:
        from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request
        verify_jwt_in_request(optional=True)
        uid = get_jwt_identity()
        return uid is not None and int(uid) == broker_id
    except Exception:  # noqa: BLE001
        return False


@public_bp.get("/l/<int:listing_id>")
def listing_page(listing_id: int):
    listing = _active_verified_query().filter(Listing.id == listing_id).first()
    if listing is None:
        # Render our themed 404 rather than the default Flask error page —
        # crawlers still get a 404 status.
        return render_template("404.html"), 404

    # Broker analytics view tracking. Owner self-views excluded.
    if not _viewer_is_owner(listing.broker_id):
        _record_listing_view(listing.id)

    storage = get_storage()
    photos = [
        {
            "url": _absolute(storage.url(p.storage_key)),
            "sort_order": p.sort_order,
        }
        for p in listing.photos
    ]
    cover_url = photos[0]["url"] if photos else None
    rating = aggregate_for(listing.broker_id) if listing.broker_id else None
    broker = _sanitized_broker(listing, rating)

    # Meta text — kept short, no HTML, safe for tag values.
    desc_source = (listing.description or "").strip()
    if not desc_source:
        desc_source = (
            f"{listing.title} in {listing.city}, {listing.governorate}. "
            f"Verified broker on Wasit."
        )
    meta_description = (desc_source[:157] + "…") if len(desc_source) > 158 else desc_source

    title_line = (
        f"{listing.title} · {listing.city}, {listing.governorate} · "
        f"{_price_display(listing.price_egp)} EGP"
    )

    # JSON-LD payload — Google's rich-results parser understands
    # Product + Place + Offer for real estate listings.
    ld = {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": listing.title,
        "description": meta_description,
        "image": [p["url"] for p in photos] or None,
        "offers": {
            "@type": "Offer",
            "priceCurrency": "EGP",
            "price": str(listing.price_egp) if listing.price_egp is not None else None,
            "availability": "https://schema.org/InStock",
            "url": _absolute(url_for("public.listing_page", listing_id=listing.id)),
        },
        "brand": {
            "@type": "Organization",
            "name": broker.get("full_name") or "Verified broker",
        },
    }
    if rating and rating.get("count"):
        ld["aggregateRating"] = {
            "@type": "AggregateRating",
            "ratingValue": rating["avg"],
            "reviewCount": rating["count"],
        }
    place = {
        "@type": "Place",
        "address": {
            "@type": "PostalAddress",
            "addressLocality": listing.city,
            "addressRegion": listing.governorate,
            "addressCountry": "EG",
        },
    }
    if listing.lat is not None and listing.lng is not None:
        place["geo"] = {
            "@type": "GeoCoordinates",
            "latitude": listing.lat,
            "longitude": listing.lng,
        }

    wa_text = (
        f"{listing.title} — {_price_display(listing.price_egp)} EGP · "
        f"{listing.city}, {listing.governorate}"
    )
    return render_template(
        "listing.html",
        listing=listing,
        photos=photos,
        cover_url=cover_url,
        broker=broker,
        rating=rating,
        canonical=_absolute(url_for("public.listing_page", listing_id=listing.id)),
        meta_title=title_line,
        meta_description=meta_description,
        price_display=_price_display(listing.price_egp),
        json_ld=[ld, place],
        whatsapp_url=_whatsapp_share_url(
            wa_text,
            _absolute(url_for("public.listing_page", listing_id=listing.id)),
        ),
    )


# ── broker credential page ────────────────────────────────────────────

def _get_public_broker(broker_id: int):
    """Return the broker user or None. Public callers only see brokers
    who are active AND verified — same trust bar as _active_verified_query()."""
    return (
        db.session.query(User)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(User.id == broker_id)
        .filter(User.role == UserRole.BROKER)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .first()
    )


def _broker_listings_for(broker_id: int, limit: int = 12) -> list[Listing]:
    """The subset of the broker's listings a public visitor should see:
    active, non-expired, ordered by newest. Reuses _active_verified_query
    so the SAME 30-day cliff + status filters apply."""
    return (
        _active_verified_query()
        .filter(Listing.broker_id == broker_id)
        .order_by(Listing.created_at.desc())
        .limit(limit)
        .all()
    )


def _sanitized_broker_full(user: User, rating: dict, listings: list[Listing]) -> dict:
    """Broker payload for the public credential page. NEVER includes
    phone or email. Extends _sanitized_broker() with active listings and
    the richer profile fields the credential page renders."""
    profile = user.broker_profile
    return {
        "id": user.id,
        "full_name": user.full_name,
        "verification_status": (
            profile.verification_status.value if profile is not None else "pending"
        ),
        "verified_at": (
            profile.verified_at.isoformat()
            if profile is not None and profile.verified_at is not None
            else None
        ),
        "goeic_registration_number": (
            profile.goeic_registration_number if profile is not None else None
        ),
        "rating": rating,
        "listings_count": len(listings),
        "listings": [_sanitized_listing(l) for l in listings],
    }


def _split_name(full_name: str) -> tuple[str, str]:
    """Best-effort first/last split for MRZ formatting.
    Egyptian names are often 3-4 tokens; we treat the first token as
    given-name and the rest as surname. Non-Arabic-safe strings are
    upper-ASCII-only in the MRZ per ICAO convention."""
    parts = (full_name or "").strip().split()
    if not parts:
        return ("", "")
    if len(parts) == 1:
        return (parts[0], "")
    return (parts[0], " ".join(parts[1:]))


def _mrz_ascii(s: str) -> str:
    """Strip non-A-Z and uppercase for MRZ compatibility."""
    return "".join(c for c in s.upper() if "A" <= c <= "Z")


def _broker_mrz(user: User, verified_at, expires_at, jurisdiction_code: str = "EGY") -> list[str]:
    """Compose the two-line MRZ strip. Purely decorative — not a real
    ICAO document — but the shape reads as machine-authentic."""
    given, surname = _split_name(user.full_name or "")
    given_a = _mrz_ascii(given)[:20]
    surname_a = _mrz_ascii(surname)[:24]
    doc_id = _mrz_ascii(
        (user.broker_profile.goeic_registration_number or "")
        if user.broker_profile is not None else ""
    )[:12] or f"EGB{user.id:07d}"

    verified_yymmdd = verified_at.strftime("%y%m%d") if verified_at else "000000"
    expires_yymmdd = expires_at.strftime("%y%m%d") if expires_at else "000000"

    # Line 1: doc-code + issuing state + name field
    line1 = f"WSTP<{jurisdiction_code}<<{surname_a}<<{given_a}"
    line1 = (line1 + "<" * 44)[:44]

    # Line 2: document number + issue date + expiry
    line2 = f"{doc_id}<3{jurisdiction_code}<{verified_yymmdd}<B<{expires_yymmdd}"
    line2 = (line2 + "<" * 44)[:44]

    return [line1, line2]


@public_bp.get("/b/<int:broker_id>")
def broker_page(broker_id: int):
    user = _get_public_broker(broker_id)
    if user is None:
        return render_template("404.html"), 404

    listings = _broker_listings_for(user.id)
    rating = aggregate_for(user.id)
    reviews = (
        BrokerRating.query
        .filter(BrokerRating.broker_user_id == user.id)
        .order_by(BrokerRating.created_at.desc())
        .limit(6)
        .all()
    )
    # Attach the rater's display name — kept opaque ("Buyer M.") to
    # match the app's own ratings screen conventions.
    review_rows = []
    for r in reviews:
        rater_name = None
        if r.rater_user_id is not None:
            rater = db.session.get(User, r.rater_user_id)
            if rater is not None and rater.full_name:
                first = rater.full_name.strip().split()[0]
                review_rows.append({
                    "id": r.id,
                    "stars": r.stars,
                    "note": r.note,
                    "created_at": r.created_at,
                    "rater_display": f"{first} · verified buyer",
                })
                continue
        review_rows.append({
            "id": r.id,
            "stars": r.stars,
            "note": r.note,
            "created_at": r.created_at,
            "rater_display": "Verified buyer",
        })

    # Metaline: pull governorate from the most recent active listing;
    # falls back to "Egypt" so the row never renders blank.
    primary_gov = listings[0].governorate if listings else None
    primary_city = listings[0].city if listings else None

    # Metadata block dates
    verified_at = user.broker_profile.verified_at if user.broker_profile else None
    from datetime import timedelta as _td
    expires_at = (verified_at + _td(days=365 * 3)) if verified_at else None

    canonical = _absolute(url_for("public.broker_page", broker_id=user.id))
    meta_title = f"{user.full_name} · Verified broker · Wasit"
    meta_description = (
        f"Verified real-estate broker in Egypt. GOEIC #"
        f"{user.broker_profile.goeic_registration_number if user.broker_profile else '—'}. "
        f"{rating.get('count', 0)} reviews, {len(listings)} active listings."
    )[:158]

    # JSON-LD — RealEstateAgent is Google's canonical schema for this role.
    ld = {
        "@context": "https://schema.org",
        "@type": "RealEstateAgent",
        "name": user.full_name,
        "url": canonical,
        "areaServed": {"@type": "Country", "name": "Egypt"},
    }
    if primary_city and primary_gov:
        ld["address"] = {
            "@type": "PostalAddress",
            "addressLocality": primary_city,
            "addressRegion": primary_gov,
            "addressCountry": "EG",
        }
    if rating.get("count"):
        ld["aggregateRating"] = {
            "@type": "AggregateRating",
            "ratingValue": rating["avg"],
            "reviewCount": rating["count"],
        }

    storage = get_storage()
    listing_cards = []
    for l in listings:
        cover = l.photos[0] if l.photos else None
        listing_cards.append({
            "id": l.id,
            "title": l.title,
            "price_display": _price_display(l.price_egp),
            "area_m2": str(l.area_m2) if l.area_m2 is not None else "",
            "governorate": l.governorate,
            "city": l.city,
            "cover_url": _absolute(storage.url(cover.storage_key)) if cover else None,
            "url": _absolute(url_for("public.listing_page", listing_id=l.id)),
        })

    now = datetime.now(timezone.utc)
    review_count = rating.get("count", 0) if isinstance(rating, dict) else 0
    wa_text = (
        f"Verified broker on Wasit: {user.full_name} · "
        f"{review_count} review{'s' if review_count != 1 else ''}"
    )
    return render_template(
        "broker.html",
        user=user,
        broker=_sanitized_broker_full(user, rating, listings),
        listing_cards=listing_cards,
        reviews=review_rows,
        primary_gov=primary_gov,
        primary_city=primary_city,
        verified_at=verified_at,
        expires_at=expires_at,
        current_year=now.year,
        mrz_lines=_broker_mrz(user, verified_at, expires_at),
        share_url=canonical,
        canonical=canonical,
        meta_title=meta_title,
        meta_description=meta_description,
        json_ld=ld,
        whatsapp_url=_whatsapp_share_url(wa_text, canonical),
    )


@public_bp.get("/api/public/brokers/<int:broker_id>")
def api_broker(broker_id: int):
    user = _get_public_broker(broker_id)
    if user is None:
        return jsonify(error="Broker not found."), 404
    listings = _broker_listings_for(user.id)
    return jsonify(_sanitized_broker_full(user, aggregate_for(user.id), listings)), 200


# ── sitemap + robots ───────────────────────────────────────────────────

@public_bp.get("/sitemap.xml")
def sitemap():
    listings = (
        _active_verified_query()
        .order_by(Listing.updated_at.desc())
        .limit(50000)  # Google's soft cap per sitemap file
        .all()
    )
    urls = [
        {
            "loc": _absolute("/"),
            "lastmod": None,
            "priority": "1.0",
            "changefreq": "weekly",
        },
        {
            "loc": _absolute("/for-brokers"),
            "lastmod": None,
            "priority": "0.9",
            "changefreq": "monthly",
        },
        {
            "loc": _absolute("/browse"),
            "lastmod": None,
            "priority": "0.8",
            "changefreq": "daily",
        },
        {"loc": _absolute("/privacy"), "lastmod": None, "priority": "0.5", "changefreq": "monthly"},
        {"loc": _absolute("/terms"),   "lastmod": None, "priority": "0.5", "changefreq": "monthly"},
        {"loc": _absolute("/contact"), "lastmod": None, "priority": "0.5", "changefreq": "monthly"},
    ]
    for l in listings:
        lm = l.updated_at or l.created_at
        urls.append({
            "loc": _absolute(url_for("public.listing_page", listing_id=l.id)),
            "lastmod": lm.date().isoformat() if lm else None,
            "priority": "0.7",
            "changefreq": "weekly",
        })

    # Verified brokers — every one gets a shareable /b/<id> credential page.
    brokers = (
        db.session.query(User)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(User.role == UserRole.BROKER)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .order_by(User.updated_at.desc())
        .limit(50000)
        .all()
    )
    for u in brokers:
        lm = u.updated_at or u.created_at
        urls.append({
            "loc": _absolute(url_for("public.broker_page", broker_id=u.id)),
            "lastmod": lm.date().isoformat() if lm else None,
            "priority": "0.8",
            "changefreq": "weekly",
        })

    # ── SEO landing pages (Phase G3) ─────────────────────────────
    # Emitted only when the underlying filter returns ≥1 listing —
    # empty landings 404, so listing them here would fingerprint us
    # as a soft-404 factory.
    from sqlalchemy import func as _sqlfunc
    _now = datetime.now(timezone.utc)
    _cutoff = _now - LISTING_TTL
    _baseline = _sqlfunc.coalesce(Listing.last_confirmed_at, Listing.created_at)
    _active_filter = (
        db.session.query(Listing)
        .join(User, Listing.broker_id == User.id)
        .join(BrokerProfile, BrokerProfile.user_id == User.id)
        .filter(Listing.status == ListingStatus.ACTIVE)
        .filter(User.is_active.is_(True))
        .filter(BrokerProfile.verification_status == VerificationStatus.VERIFIED)
        .filter(_baseline > _cutoff)
    )

    # Governorate landings — one row per governorate with any listings.
    gov_counts = dict(
        _active_filter.with_entities(
            Listing.governorate, _sqlfunc.count(Listing.id)
        ).group_by(Listing.governorate).all()
    )
    for gov in GOVERNORATES:
        if gov_counts.get(gov["en"], 0) > 0:
            urls.append({
                "loc": _absolute(f"/browse/{gov['key']}"),
                "lastmod": None,
                "priority": "0.7",
                "changefreq": "daily",
            })

    # City landings — one row per (gov, city) with any listings.
    for gov_en, city_name, cnt in (
        _active_filter.with_entities(
            Listing.governorate, Listing.city, _sqlfunc.count(Listing.id)
        ).group_by(Listing.governorate, Listing.city).all()
    ):
        if not cnt or not city_name:
            continue
        gov = None
        for g in GOVERNORATES:
            if g["en"] == gov_en:
                gov = g
                break
        if gov is None:
            continue
        urls.append({
            "loc": _absolute(f"/browse/{gov['key']}/{slugify(city_name)}"),
            "lastmod": None,
            "priority": "0.6",
            "changefreq": "daily",
        })

    # Facet landings — only for the top-N governorates to cap sitemap
    # size. Verify each combo actually has listings before emitting.
    for gov_key in _TOP_GOV_KEYS_FOR_FACETS:
        gov = gov_by_slug(gov_key)
        if gov is None:
            continue
        for facet_slug, (col_key, enum_value, _) in _FACET_MAP.items():
            fq = _active_filter.filter(Listing.governorate == gov["en"])
            if col_key == "property_type":
                fq = fq.filter(Listing.property_type == enum_value)
            elif col_key == "kind":
                fq = fq.filter(Listing.listing_kind == enum_value)
            if fq.with_entities(_sqlfunc.count(Listing.id)).scalar():
                urls.append({
                    "loc": _absolute(f"/browse/{gov['key']}/{facet_slug}"),
                    "lastmod": None,
                    "priority": "0.6",
                    "changefreq": "daily",
                })

    xml = render_template("sitemap.xml", urls=urls)
    return Response(xml, mimetype="application/xml")


@public_bp.get("/robots.txt")
def robots():
    lines = [
        "User-agent: *",
        "Allow: /",
        "Disallow: /files/",  # storage isn't meant to be crawled directly
        "Disallow: /auth/",
        "Disallow: /admin/",
        f"Sitemap: {_absolute('/sitemap.xml')}",
        "",
    ]
    return Response("\n".join(lines), mimetype="text/plain")
