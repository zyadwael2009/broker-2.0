"""Flask CLI commands.

`flask seed-admin` is the only way to create an admin account — the
public register endpoint rejects role=admin.

`flask seed-demo` populates a full realistic dataset (users, listings,
photos, documents, message threads) so the app can be walked end-to-end
without manual registrations. All demo accounts use phones in the
reserved `+2015550…` range so they can never collide with real signups.
"""
from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Iterable

import click
from flask import Flask
from flask.cli import with_appcontext

from .auth.security import hash_password, normalize_phone
from .extensions import db
from .models.broker_profile import BrokerProfile, VerificationStatus
from .models.listing import Listing, ListingStatus, PropertyType
from .models.listing_document import DocumentKind, DocumentState, ListingDocument
from .models.listing_photo import ListingPhoto
from .models.broker_rating import BrokerRating
from .models.message import Message
from .models.message_thread import MessageThread
from .models.report import Report, ReportReason, ReportStatus, ReportTargetType
from .models.user import User, UserRole
from .storage import get_storage


# ─── shared admin helper ───────────────────────────────────────────────

def create_or_promote_admin(
    phone: str, password: str, name: str, email: str | None
) -> User:
    """Idempotent — promotes an existing user or creates a fresh admin.
    Reused by `seed-admin` and `seed-demo`."""
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters.")
    phone_e164 = normalize_phone(phone)
    existing = User.query.filter_by(phone=phone_e164).first()
    if existing:
        existing.role = UserRole.ADMIN
        existing.is_active = True
        db.session.commit()
        return existing
    user = User(
        phone=phone_e164,
        email=email,
        password_hash=hash_password(password),
        full_name=name,
        role=UserRole.ADMIN,
    )
    db.session.add(user)
    db.session.commit()
    return user


@click.command("seed-admin")
@click.option("--phone", required=True, help="Admin phone (any format; will be normalized to E.164).")
@click.option("--password", required=True, help="Initial password (min 8 chars).")
@click.option("--name", required=True, help="Full name.")
@click.option("--email", default=None, help="Optional email.")
@with_appcontext
def seed_admin(phone: str, password: str, name: str, email: str | None):
    """Create or promote an admin account."""
    try:
        user = create_or_promote_admin(phone, password, name, email)
    except ValueError as exc:
        raise click.ClickException(str(exc)) from exc
    click.echo(f"Admin ready: {user.id} ({user.phone}).")


# ─── seed-demo ─────────────────────────────────────────────────────────

DEMO_PHONE_PREFIX = "+2015550"       # reserved for demo — never collides with real users
DEMO_PASSWORD = "demopass"
DEMO_ADMIN_PHONE = "+201000000000"
DEMO_ADMIN_PASSWORD = "demoadmin"


def _make_jpeg(color: tuple[int, int, int], size: int = 800) -> bytes:
    """Generate a valid JPEG whose magic bytes pass read_and_validate."""
    from PIL import Image
    img = Image.new("RGB", (size, int(size * 0.75)), color)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85)
    return buf.getvalue()


def _make_pdf_placeholder() -> bytes:
    """Minimal PDF header + trailer. Passes the `%PDF-` magic-byte sniff."""
    return (
        b"%PDF-1.4\n"
        b"1 0 obj<</Type/Catalog>>endobj\n"
        b"trailer<</Root 1 0 R>>\n"
        b"%%EOF"
    )


def _upsert_user(phone: str, name: str, role: UserRole,
                 verified: VerificationStatus | None = None,
                 has_doc: bool = False,
                 rejection_reason: str | None = None,
                 is_active: bool = True) -> User:
    """Insert-or-update a user by phone. Sets/keeps broker profile state."""
    e164 = normalize_phone(phone)
    user = User.query.filter_by(phone=e164).first()
    if user is None:
        user = User(
            phone=e164,
            password_hash=hash_password(DEMO_PASSWORD),
            full_name=name,
            role=role,
        )
        db.session.add(user)
        db.session.flush()
    else:
        user.full_name = name
        user.role = role
    user.is_active = is_active

    if role == UserRole.BROKER:
        profile = user.broker_profile
        if profile is None:
            profile = BrokerProfile(user_id=user.id, verification_status=VerificationStatus.PENDING)
            db.session.add(profile)
            db.session.flush()
        if verified is not None:
            profile.verification_status = verified
            profile.verified_at = (
                datetime.now(timezone.utc)
                if verified == VerificationStatus.VERIFIED else None
            )
        if has_doc:
            profile.goeic_registration_number = "EG-DEMO-" + str(user.id)
            profile.registration_document_path = (
                f"broker-docs/{user.id}/demo.pdf"
            )
        profile.rejection_reason = rejection_reason

    db.session.commit()
    return user


def _reset_demo() -> tuple[int, int]:
    """Delete every user whose phone begins with the demo prefix, plus
    the fixed demo admin. Returns (users_deleted, threads_deleted)."""
    users = (
        User.query.filter(
            (User.phone.like(DEMO_PHONE_PREFIX + "%"))
            | (User.phone == normalize_phone(DEMO_ADMIN_PHONE))
        )
        .all()
    )
    thread_count = 0
    for u in users:
        thread_count += MessageThread.query.filter(
            (MessageThread.buyer_id == u.id) | (MessageThread.broker_id == u.id)
        ).count()
    for u in users:
        db.session.delete(u)  # cascades listings, photos, docs, threads, messages
    db.session.commit()
    return len(users), thread_count


def _wipe_demo_storage() -> None:
    from .storage.local import LocalDiskStorage
    storage = get_storage()
    if not isinstance(storage, LocalDiskStorage):
        return
    import shutil
    for sub in ("listing-photos", "listing-docs", "broker-docs"):
        target = storage.root / sub
        if not target.exists():
            continue
        # Only wipe demo files — recognizable by `demo` prefix or filename.
        for child in target.rglob("demo*"):
            if child.is_file():
                child.unlink()
            elif child.is_dir():
                shutil.rmtree(child, ignore_errors=True)


def _put_photo(listing_id: int, index: int, data: bytes) -> str:
    """Store already-built JPEG bytes at a fixed key. Returns the key."""
    from io import BytesIO
    key = f"listing-photos/{listing_id}/demo-{index}.jpg"
    get_storage().put(key, BytesIO(data), content_type="image/jpeg")
    return key


def _attach_photos(listing: Listing, category: str, seed: int,
                   count: int = 3,
                   fallback_colors: Iterable[tuple[int, int, int]] | None = None,
                   force_bytes: list[bytes] | None = None) -> list[bytes]:
    """Idempotent: replaces demo-* rows for this listing every run.

    - `category`: one of `cli_photos.PHOTOS` keys ("apartment", "villa"…).
    - `seed`: stable per-listing so screenshots don't churn on reseed.
    - `count`: number of photos to attach.
    - `fallback_colors`: RGB tuples used if photo download fails, one
      per missing slot. Falls back to a fixed palette if not provided.
    - `force_bytes`: bypass the download step entirely (used for the
      L9/L3 duplicate-hash case — both listings need IDENTICAL bytes).

    Returns the raw JPEG bytes actually attached (useful when the
    caller needs to hand them to a duplicate listing).
    """
    from .listings.phash import compute_phash
    from .cli_photos import photos_for

    ListingPhoto.query.filter(
        ListingPhoto.listing_id == listing.id,
        ListingPhoto.storage_key.like("listing-photos/%/demo-%"),
    ).delete(synchronize_session=False)
    db.session.flush()

    # Prefer forced bytes (dup case) → real photos → colored fallback.
    if force_bytes is not None:
        blobs = list(force_bytes[:count])
    else:
        blobs = photos_for(category, count, seed)

    if len(blobs) < count:
        # Fill missing slots with colored placeholders so every listing
        # renders even if some Unsplash IDs went dead.
        palette = list(fallback_colors or [
            (200, 30, 30), (30, 30, 200), (30, 200, 30),
            (200, 200, 30), (30, 200, 200), (200, 30, 200),
        ])
        for i in range(len(blobs), count):
            blobs.append(_make_jpeg(palette[i % len(palette)]))

    for i, data in enumerate(blobs):
        key = _put_photo(listing.id, i, data)
        db.session.add(ListingPhoto(
            listing_id=listing.id,
            storage_key=key,
            phash=compute_phash(data),
            sort_order=i,
        ))
    db.session.flush()
    return blobs


def _upsert_listing(*, broker: User, title: str, gov: str, city: str,
                    property_type: PropertyType, price: str, area: str,
                    status: ListingStatus, last_confirmed_days_ago: int = 0,
                    created_days_ago: int | None = None,
                    lat: float = 30.05, lng: float = 31.24,
                    district: str | None = None) -> Listing:
    """Upsert by (broker_id, title). Backdates timestamps so market
    trend + auto-expire logic exercise correctly."""
    now = datetime.now(timezone.utc)
    listing = Listing.query.filter_by(broker_id=broker.id, title=title).first()
    if listing is None:
        listing = Listing(
            broker_id=broker.id,
            title=title,
            price_egp=Decimal(price),
            area_m2=Decimal(area),
            governorate=gov,
            city=city,
            district=district,
            lat=lat,
            lng=lng,
            property_type=property_type,
            status=status,
        )
        db.session.add(listing)
        db.session.flush()
    listing.price_egp = Decimal(price)
    listing.area_m2 = Decimal(area)
    listing.governorate = gov
    listing.city = city
    listing.district = district
    listing.property_type = property_type
    listing.status = status
    listing.last_confirmed_at = now - timedelta(days=last_confirmed_days_ago)
    if created_days_ago is not None:
        listing.created_at = now - timedelta(days=created_days_ago)
    db.session.flush()
    return listing


def _upsert_document(listing: Listing, kind: DocumentKind, state: DocumentState,
                     rejection_reason: str | None = None,
                     admin: User | None = None) -> ListingDocument:
    """Upsert (listing, kind); write a placeholder PDF for non-unset states."""
    from io import BytesIO
    doc = ListingDocument.query.filter_by(
        listing_id=listing.id, kind=kind
    ).first()
    if doc is None:
        doc = ListingDocument(listing_id=listing.id, kind=kind, state=state)
        db.session.add(doc)
        db.session.flush()

    doc.state = state
    if state == DocumentState.SELF_REPORTED:
        doc.storage_key = None
    elif state in (DocumentState.PENDING, DocumentState.VERIFIED, DocumentState.REJECTED):
        key = f"listing-docs/{listing.id}/{kind.value}/demo.pdf"
        get_storage().put(key, BytesIO(_make_pdf_placeholder()), content_type="application/pdf")
        doc.storage_key = key
    doc.rejection_reason = rejection_reason if state == DocumentState.REJECTED else None
    if state == DocumentState.VERIFIED:
        doc.verified_at = datetime.now(timezone.utc)
        doc.verified_by = admin.id if admin else None
    else:
        doc.verified_at = None
    db.session.flush()
    return doc


def _upsert_thread(buyer: User, broker: User, listing: Listing) -> MessageThread:
    thread = MessageThread.query.filter_by(
        buyer_id=buyer.id, broker_id=broker.id, listing_id=listing.id
    ).first()
    if thread is None:
        thread = MessageThread(
            buyer_id=buyer.id, broker_id=broker.id, listing_id=listing.id,
        )
        db.session.add(thread)
        db.session.flush()
    return thread


def _add_message(thread: MessageThread, sender: User, body: str,
                 minutes_ago: int, read_by_recipient: bool) -> None:
    """Idempotent by (thread_id, sender_id, body)."""
    existing = Message.query.filter_by(
        thread_id=thread.id, sender_id=sender.id, body=body
    ).first()
    when = datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)
    if existing is not None:
        existing.created_at = when
        existing.read_at = when if read_by_recipient else None
        return
    msg = Message(
        thread_id=thread.id,
        sender_id=sender.id,
        body=body,
    )
    db.session.add(msg)
    db.session.flush()
    msg.created_at = when
    msg.read_at = when if read_by_recipient else None
    thread.last_message_at = when
    db.session.flush()


@click.command("seed-demo")
@click.option("--reset", is_flag=True, default=False,
              help="Wipe every demo user (phones under +2015550…) before reseeding.")
@click.option("--wipe-storage", is_flag=True, default=False,
              help="Also delete demo* files under UPLOAD_DIR. Only affects LocalDiskStorage.")
@with_appcontext
def seed_demo(reset: bool, wipe_storage: bool):
    """Seed a realistic demo dataset: admin + 3 buyers + 9 brokers +
    16 listings + a mix of documents and 3 message threads."""
    if reset:
        deleted_users, deleted_threads = _reset_demo()
        click.echo(f"Cleared {deleted_users} demo users ({deleted_threads} threads).")
    if wipe_storage:
        _wipe_demo_storage()
        click.echo("Wiped demo files under UPLOAD_DIR.")

    # --- admin -----------------------------------------------------------
    admin = create_or_promote_admin(
        DEMO_ADMIN_PHONE, DEMO_ADMIN_PASSWORD, "Demo Admin", None
    )

    # --- buyers ----------------------------------------------------------
    buyer_aya = _upsert_user("+201555000101", "Aya Buyer", UserRole.BUYER)
    buyer_hana = _upsert_user("+201555000102", "Hana Buyer", UserRole.BUYER)
    _ = _upsert_user("+201555000103", "Omar Buyer", UserRole.BUYER)

    # --- brokers ---------------------------------------------------------
    youssef = _upsert_user(
        "+201555000201", "Youssef Broker", UserRole.BROKER,
        verified=VerificationStatus.VERIFIED, has_doc=True,
    )
    mariam = _upsert_user(
        "+201555000202", "Mariam Broker", UserRole.BROKER,
        verified=VerificationStatus.VERIFIED, has_doc=True,
    )
    karim = _upsert_user(
        "+201555000203", "Karim Broker (fully documented)", UserRole.BROKER,
        verified=VerificationStatus.VERIFIED, has_doc=True,
    )
    nour = _upsert_user(
        "+201555000204", "Nour Broker (docs in flight)", UserRole.BROKER,
        verified=VerificationStatus.VERIFIED, has_doc=True,
    )
    salma_pending = _upsert_user(
        "+201555000205", "Salma Broker (pending review)", UserRole.BROKER,
        verified=VerificationStatus.PENDING, has_doc=True,
    )
    _ = _upsert_user(
        "+201555000206", "Tarek Broker (rejected)", UserRole.BROKER,
        verified=VerificationStatus.REJECTED, has_doc=True,
        rejection_reason="GOEIC certificate is blurry — please rescan at higher resolution.",
    )
    _ = _upsert_user(
        "+201555000207", "Laila Broker (never submitted)", UserRole.BROKER,
        verified=VerificationStatus.PENDING, has_doc=False,
    )
    hidden_broker = _upsert_user(
        "+201555000208", "Hidden Broker", UserRole.BROKER,
        verified=VerificationStatus.VERIFIED, has_doc=True,
        is_active=False,
    )
    dup_broker = _upsert_user(
        "+201555000209", "Duplicate Broker", UserRole.BROKER,
        verified=VerificationStatus.VERIFIED, has_doc=True,
    )

    # --- listings (10 core) ---------------------------------------------
    l1 = _upsert_listing(broker=youssef, title="Sunny 3-BR in Zamalek",
                         gov="Cairo", city="Cairo", district="Zamalek",
                         property_type=PropertyType.APARTMENT,
                         price="6500000", area="140",
                         status=ListingStatus.ACTIVE, lat=30.061, lng=31.222)
    l2 = _upsert_listing(broker=youssef, title="Modern villa",
                         gov="Giza", city="Sheikh Zayed",
                         property_type=PropertyType.VILLA,
                         price="18000000", area="420",
                         status=ListingStatus.ACTIVE,
                         last_confirmed_days_ago=10, lat=30.045, lng=30.972)
    l3 = _upsert_listing(broker=youssef, title="Studio near AUC",
                         gov="Cairo", city="New Cairo", district="Fifth Settlement",
                         property_type=PropertyType.APARTMENT,
                         price="2100000", area="55",
                         status=ListingStatus.ACTIVE, lat=30.02, lng=31.47)
    _l4 = _upsert_listing(broker=youssef, title="Old expired listing",
                          gov="Alexandria", city="Alexandria",
                          property_type=PropertyType.APARTMENT,
                          price="3000000", area="110",
                          status=ListingStatus.ACTIVE,
                          last_confirmed_days_ago=40, lat=31.20, lng=29.92)
    l5 = _upsert_listing(broker=mariam, title="Roof apartment",
                         gov="Cairo", city="Maadi",
                         property_type=PropertyType.APARTMENT,
                         price="4800000", area="180",
                         status=ListingStatus.ACTIVE, lat=29.96, lng=31.26)
    _l6 = _upsert_listing(broker=mariam, title="Sold last week",
                          gov="Cairo", city="Nasr City",
                          property_type=PropertyType.APARTMENT,
                          price="3200000", area="120",
                          status=ListingStatus.SOLD,
                          last_confirmed_days_ago=5, lat=30.05, lng=31.32)
    l7 = _upsert_listing(broker=karim, title="Fully documented townhouse",
                         gov="Giza", city="6th of October",
                         property_type=PropertyType.HOUSE,
                         price="7900000", area="260",
                         status=ListingStatus.ACTIVE, lat=29.96, lng=30.93)
    l8 = _upsert_listing(broker=nour, title="Villa with docs in review",
                         gov="Giza", city="Sheikh Zayed",
                         property_type=PropertyType.VILLA,
                         price="16500000", area="380",
                         status=ListingStatus.ACTIVE, lat=30.05, lng=30.97)
    l9 = _upsert_listing(broker=dup_broker, title="Cheap flat",
                         gov="Alexandria", city="Smouha",
                         property_type=PropertyType.APARTMENT,
                         price="2900000", area="90",
                         status=ListingStatus.ACTIVE, lat=31.20, lng=29.94)
    _l10 = _upsert_listing(broker=hidden_broker, title="Should never appear publicly",
                           gov="Cairo", city="Heliopolis",
                           property_type=PropertyType.APARTMENT,
                           price="4000000", area="130",
                           status=ListingStatus.ACTIVE, lat=30.09, lng=31.32)

    # --- historical listings (populate market trend buckets) ------------
    for months, price_delta in [(2, 300000), (4, 250000), (6, 200000),
                                (9, 150000), (12, 100000), (15, 50000)]:
        # Two per month bucket so MIN_MONTHLY_LISTINGS=2 in /market/trend passes.
        for a_or_b in ("A", "B"):
            _upsert_listing(
                broker=youssef,
                title=f"Historical demo listing {months}mo-{a_or_b}",
                gov="Cairo", city="Cairo",
                property_type=PropertyType.APARTMENT,
                price=str(3000000 + price_delta),
                area="100",
                status=ListingStatus.SOLD,
                last_confirmed_days_ago=months * 30,
                created_days_ago=months * 30,
                lat=30.05, lng=31.24,
            )

    # --- photos ---------------------------------------------------------
    # Real royalty-free photos (Unsplash) — see app/cli_photos.py. The
    # `seed` arg gives each listing a stable rotation into the category
    # list so reseeds show the same photos (screenshot stability).
    _attach_photos(l1, "apartment", seed=1, count=3)
    _attach_photos(l2, "villa",     seed=2, count=3)
    # L9's photos MUST equal L3's byte-for-byte → same pHash → auto-flag.
    # Capture L3's bytes and force them into L9.
    l3_bytes = _attach_photos(l3, "apartment", seed=3, count=3)
    _attach_photos(l5, "apartment", seed=5, count=2)
    _attach_photos(l7, "house",     seed=7, count=3)
    _attach_photos(l8, "villa",     seed=8, count=2)
    _attach_photos(l9, "apartment", seed=3, count=3, force_bytes=l3_bytes)
    # Hidden broker's L10 gets one photo so it renders in listings/mine.
    _attach_photos(_l10, "apartment", seed=10, count=1)

    # --- documents ------------------------------------------------------
    _upsert_document(l1, DocumentKind.TITLE_DEED, DocumentState.VERIFIED, admin=admin)
    _upsert_document(l1, DocumentKind.NO_LIENS, DocumentState.SELF_REPORTED)
    _upsert_document(l5, DocumentKind.TITLE_DEED, DocumentState.VERIFIED, admin=admin)
    _upsert_document(l5, DocumentKind.NO_LIENS, DocumentState.VERIFIED, admin=admin)
    _upsert_document(l7, DocumentKind.TITLE_DEED, DocumentState.VERIFIED, admin=admin)
    _upsert_document(l7, DocumentKind.NO_LIENS, DocumentState.VERIFIED, admin=admin)
    _upsert_document(l7, DocumentKind.TAX_CLEARANCE, DocumentState.VERIFIED, admin=admin)
    _upsert_document(l8, DocumentKind.TITLE_DEED, DocumentState.PENDING)
    _upsert_document(l8, DocumentKind.NO_LIENS, DocumentState.REJECTED,
                     rejection_reason="Illegible scan — please resubmit.")
    _upsert_document(l8, DocumentKind.TAX_CLEARANCE, DocumentState.VERIFIED, admin=admin)

    # --- flagged listing (L9 already has duplicate-photo pHash flagged;
    # populate the duplicate_suspected/of columns directly since we
    # bypassed the upload path). ------------------------------------------
    l9.duplicate_suspected = True
    l9.duplicate_of_listing_id = l3.id

    # --- message threads ------------------------------------------------
    t1 = _upsert_thread(buyer=buyer_aya, broker=youssef, listing=l1)
    _add_message(t1, buyer_aya, "Is this still available?", minutes_ago=180, read_by_recipient=True)
    _add_message(t1, youssef, "Yes, when would you like to visit?", minutes_ago=170, read_by_recipient=True)
    _add_message(t1, buyer_aya, "Sunday around 4pm?", minutes_ago=160, read_by_recipient=True)

    t2 = _upsert_thread(buyer=buyer_hana, broker=mariam, listing=l5)
    _add_message(t2, buyer_hana, "Can you send more photos?", minutes_ago=90, read_by_recipient=True)
    _add_message(t2, mariam, "Just added two more — take a look.", minutes_ago=30, read_by_recipient=False)

    t3 = _upsert_thread(buyer=buyer_hana, broker=karim, listing=l7)
    _add_message(t3, buyer_hana, "Are the documents really all verified?", minutes_ago=45, read_by_recipient=False)

    # --- broker ratings (upsert by (rater, broker)) ---------------------
    def _upsert_rating(rater: User, broker: User, thread: MessageThread,
                       stars: int, note: str | None) -> None:
        existing = BrokerRating.query.filter_by(
            rater_user_id=rater.id, broker_user_id=broker.id
        ).first()
        if existing is not None:
            existing.stars = stars
            existing.note = note
            existing.thread_id = thread.id
            return
        db.session.add(BrokerRating(
            rater_user_id=rater.id, broker_user_id=broker.id,
            thread_id=thread.id, stars=stars, note=note,
        ))

    _upsert_rating(buyer_aya, youssef, t1, 5,
                   "Responded quickly and showed the flat the same weekend.")
    _upsert_rating(buyer_hana, mariam, t2, 4,
                   "Helpful, though photos could be better.")
    _upsert_rating(buyer_hana, karim, t3, 5,
                   "All documents were in order. Very professional.")

    # --- one open report so the admin queue isn't empty ------------------
    existing_report = (
        Report.query.filter_by(
            reporter_user_id=buyer_aya.id,
            target_type=ReportTargetType.LISTING,
            target_id=l9.id,
        ).first()
    )
    if existing_report is None:
        db.session.add(Report(
            reporter_user_id=buyer_aya.id,
            target_type=ReportTargetType.LISTING,
            target_id=l9.id,
            reason=ReportReason.FRAUD,
            note="Photos look copied from another listing.",
            status=ReportStatus.OPEN,
        ))

    db.session.commit()

    # --- report ---------------------------------------------------------
    click.echo("")
    click.echo("Demo seed complete. Log in with:")
    click.echo("")
    click.echo(f"  {'PHONE':<18}  {'PASSWORD':<12}  ROLE     STATE")
    click.echo(f"  {'-' * 18}  {'-' * 12}  {'-' * 8} {'-' * 40}")
    click.echo(f"  {DEMO_ADMIN_PHONE:<18}  {DEMO_ADMIN_PASSWORD:<12}  admin    Admin dashboard")
    click.echo(f"  +201555000101       {DEMO_PASSWORD:<12}  buyer    Aya — active thread w/ Youssef")
    click.echo(f"  +201555000102       {DEMO_PASSWORD:<12}  buyer    Hana — 2 threads, 1 with unread")
    click.echo(f"  +201555000201       {DEMO_PASSWORD:<12}  broker   Youssef — 4 listings")
    click.echo(f"  +201555000203       {DEMO_PASSWORD:<12}  broker   Karim — fully documented listing")
    click.echo(f"  +201555000205       {DEMO_PASSWORD:<12}  broker   Salma — pending admin review")
    click.echo(f"  +201555000206       {DEMO_PASSWORD:<12}  broker   Tarek — rejected, can resubmit")
    click.echo("")
    click.echo("Admin key routes:")
    click.echo(f"  Pending brokers:   /admin/brokers?status=pending  (Salma above)")
    click.echo(f"  Flagged listings:  /admin/listings/flagged        (L9 = duplicate of L3)")
    click.echo(f"  Pending docs:      /admin/documents/pending       (L8's title deed)")
    click.echo(f"  Open reports:      /admin/reports?status=open     (Aya reported L9)")


# ─── import-brokers ───────────────────────────────────────────────────

_IMPORT_LOGS_DIR = "import_logs"


def _run_import_brokers(csv_path: str, verified: bool, dry_run: bool,
                        password_length: int) -> dict:
    """Core of the `import-brokers` command. Returns a summary dict.

    Separated from the Click command so tests can drive it without
    invoking Click's CliRunner.
    """
    import csv as _csv
    import secrets as _secrets
    from datetime import datetime as _dt, timezone as _tz
    from io import BytesIO
    from pathlib import Path

    from flask import current_app
    from marshmallow import ValidationError as _MMValidationError

    from .auth.security import generate_referral_code, hash_password, normalize_phone

    REQUIRED_COLS = {"phone", "full_name"}
    OPTIONAL_COLS = {"email", "goeic_number", "notes"}
    KNOWN_COLS = REQUIRED_COLS | OPTIONAL_COLS

    path = Path(csv_path)
    if not path.is_file():
        raise click.ClickException(f"CSV not found: {csv_path}")

    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = _csv.DictReader(fh)
        header = set(reader.fieldnames or [])
        missing = REQUIRED_COLS - header
        if missing:
            raise click.ClickException(
                f"CSV is missing required columns: {sorted(missing)}"
            )
        unknown = header - KNOWN_COLS
        if unknown:
            click.echo(
                f"Warning: ignoring unknown columns: {sorted(unknown)}", err=True
            )
        rows = list(reader)

    if verified:
        # Need a stamping admin — verified_by is a FK to users.id.
        admin = (
            User.query.filter_by(role=UserRole.ADMIN)
            .order_by(User.id.asc())
            .first()
        )
        if admin is None:
            raise click.ClickException(
                "No admin user found — `flask seed-admin` first, or omit --verified."
            )
    else:
        admin = None

    consent_version = current_app.config.get("PDPL_CONSENT_VERSION", "1.0")
    storage = get_storage()
    now = _dt.now(_tz.utc)

    created: list[dict] = []
    updated: list[dict] = []
    skipped: list[dict] = []
    errors: list[dict] = []

    for i, raw_row in enumerate(rows, start=2):  # start=2 = 1-indexed + header
        phone_raw = (raw_row.get("phone") or "").strip()
        full_name = (raw_row.get("full_name") or "").strip()
        email = (raw_row.get("email") or "").strip() or None
        goeic = (raw_row.get("goeic_number") or "").strip() or None

        if not phone_raw or not full_name:
            errors.append({"row": i, "reason": "phone + full_name required"})
            continue

        try:
            phone = normalize_phone(phone_raw)
        except _MMValidationError as exc:
            errors.append({"row": i, "phone": phone_raw,
                          "reason": f"phone: {exc.messages}"})
            continue

        if verified and not goeic:
            errors.append({"row": i, "phone": phone,
                          "reason": "goeic_number required when --verified"})
            continue

        if len(full_name) < 3 or len(full_name) > 120:
            errors.append({"row": i, "phone": phone,
                          "reason": "full_name must be 3–120 chars"})
            continue

        existing = User.query.filter_by(phone=phone).first()

        # --- existing user path -----------------------------------
        if existing is not None:
            if existing.role == UserRole.BUYER:
                skipped.append({"row": i, "phone": phone,
                               "reason": "existing-buyer (refusing role change)"})
                continue
            if existing.role == UserRole.ADMIN:
                skipped.append({"row": i, "phone": phone,
                               "reason": "existing-admin (refusing role change)"})
                continue

            # Existing broker → idempotent update.
            if dry_run:
                updated.append({"row": i, "phone": phone, "user_id": existing.id,
                              "action": "would-update"})
                continue

            existing.full_name = full_name
            if email is not None:
                existing.email = email
            profile = existing.broker_profile
            if profile is None:
                profile = BrokerProfile(user_id=existing.id,
                                        verification_status=VerificationStatus.PENDING)
                db.session.add(profile)
                db.session.flush()
            if goeic:
                profile.goeic_registration_number = goeic
            if verified:
                profile.verification_status = VerificationStatus.VERIFIED
                profile.verified_at = now
                profile.verified_by = admin.id
                profile.rejection_reason = None
                if not profile.registration_document_path:
                    key = _upload_bulk_stub_doc(storage, existing.id, goeic)
                    profile.registration_document_path = key
            profile.consent_version = consent_version
            updated.append({"row": i, "phone": phone, "user_id": existing.id,
                          "action": "updated"})
            continue

        # --- new user path ----------------------------------------
        temp_pw = _secrets.token_urlsafe(password_length)[:password_length]

        if dry_run:
            created.append({"row": i, "phone": phone, "name": full_name,
                          "temp_password": "(dry-run)", "user_id": None})
            continue

        # Referral code with the same 6-retry collision loop as the
        # register flow (auth/routes.py:145-149).
        new_code = generate_referral_code()
        for _ in range(6):
            if not User.query.filter_by(referral_code=new_code).first():
                break
            new_code = generate_referral_code()

        user = User(
            phone=phone,
            email=email,
            password_hash=hash_password(temp_pw),
            full_name=full_name,
            role=UserRole.BROKER,
            phone_verified=True,        # hand-vetted, skip OTP
            phone_verified_at=now,
            referral_code=new_code,
        )
        db.session.add(user)
        db.session.flush()

        profile = BrokerProfile(
            user_id=user.id,
            verification_status=(
                VerificationStatus.VERIFIED if verified
                else VerificationStatus.PENDING
            ),
            goeic_registration_number=goeic,
            consent_version=consent_version,
        )
        if verified:
            profile.verified_at = now
            profile.verified_by = admin.id
            profile.registration_document_path = _upload_bulk_stub_doc(
                storage, user.id, goeic
            )
        db.session.add(profile)
        db.session.flush()

        created.append({"row": i, "phone": phone, "name": full_name,
                       "temp_password": temp_pw, "user_id": user.id})

    if dry_run:
        db.session.rollback()
    else:
        db.session.commit()

    return {
        "created": created,
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
        "dry_run": dry_run,
    }


def _upload_bulk_stub_doc(storage, user_id: int, goeic: str | None) -> str:
    """Upload a valid-but-clearly-stub PDF so registration_document_path
    isn't NULL. Real doc can replace this via the standard submit flow
    at any time. Stable key per (user_id, goeic) so reruns are
    idempotent."""
    from io import BytesIO
    safe_goeic = (goeic or "no-goeic").replace("/", "-").replace(" ", "-")
    key = f"broker-docs/{user_id}/bulk-{safe_goeic}.pdf"
    storage.put(key, BytesIO(_make_pdf_placeholder()),
                content_type="application/pdf")
    return key


def _write_import_log(summary: dict) -> str | None:
    """Write a CSV side-log with temp passwords so Zyad can share them
    over WhatsApp. Returns the path or None if there's nothing to log."""
    if not summary["created"]:
        return None
    import csv as _csv
    from datetime import datetime as _dt, timezone as _tz
    from pathlib import Path
    log_dir = Path(_IMPORT_LOGS_DIR)
    log_dir.mkdir(parents=True, exist_ok=True)
    stamp = _dt.now(_tz.utc).strftime("%Y%m%dT%H%M%SZ")
    path = log_dir / f"import-brokers-{stamp}.csv"
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = _csv.DictWriter(fh, fieldnames=["phone", "name", "temp_password", "user_id"])
        w.writeheader()
        for row in summary["created"]:
            w.writerow({
                "phone": row["phone"],
                "name": row["name"],
                "temp_password": row["temp_password"],
                "user_id": row["user_id"],
            })
    return str(path)


@click.command("import-brokers")
@click.argument("csv_path", type=click.Path(exists=True, dir_okay=False))
@click.option("--verified", is_flag=True, default=False,
              help="Mark imported brokers as VERIFIED immediately (requires goeic_number).")
@click.option("--dry-run", is_flag=True, default=False,
              help="Parse + report but don't write anything.")
@click.option("--password-length", type=click.IntRange(8, 64), default=12,
              show_default=True, help="Temp password length for new brokers.")
@with_appcontext
def import_brokers(csv_path: str, verified: bool, dry_run: bool,
                   password_length: int):
    """Bulk-import brokers from a CSV. Idempotent — reruns update.

    CSV columns: phone (req), full_name (req), email, goeic_number,
    notes. Extra columns are ignored.

    Created brokers get a temp password logged to
    `import_logs/import-brokers-<timestamp>.csv` — share those over
    WhatsApp, then delete the log.
    """
    summary = _run_import_brokers(csv_path, verified, dry_run, password_length)

    total = (len(summary["created"]) + len(summary["updated"])
             + len(summary["skipped"]) + len(summary["errors"]))

    click.echo("")
    if dry_run:
        click.echo("-- DRY RUN -- nothing was written. -------------------")
    click.echo(f"CSV rows: {total}")
    click.echo(f"  Created:  {len(summary['created'])}")
    click.echo(f"  Updated:  {len(summary['updated'])}")
    click.echo(f"  Skipped:  {len(summary['skipped'])}")
    click.echo(f"  Errors:   {len(summary['errors'])}")

    if summary["errors"]:
        click.echo("")
        click.echo("Errors:")
        for e in summary["errors"]:
            click.echo(f"  row {e['row']}: {e['reason']}")

    if summary["skipped"]:
        click.echo("")
        click.echo("Skipped:")
        for s in summary["skipped"]:
            click.echo(f"  row {s['row']}: {s['phone']}  → {s['reason']}")

    if summary["created"] and not dry_run:
        log_path = _write_import_log(summary)
        click.echo("")
        click.echo(f"Temp passwords written to: {log_path}")
        click.echo("(share credentials over WhatsApp, then delete that file)")


# ─── generate-secrets ─────────────────────────────────────────────────

@click.command("generate-secrets")
def generate_secrets():
    """Print fresh SECRET_KEY + JWT_SECRET_KEY values.

    Zero side effects — output is meant to be pasted into your secrets
    store (Doppler / Fly.io secrets / 1Password / your provider). Two
    distinct 48-byte URL-safe strings.
    """
    import secrets as _secrets

    sk = _secrets.token_urlsafe(48)
    jsk = _secrets.token_urlsafe(48)
    click.echo("# Paste these into your production secret store.")
    click.echo("# NEVER commit them to git.")
    click.echo("")
    click.echo(f"SECRET_KEY={sk}")
    click.echo(f"JWT_SECRET_KEY={jsk}")
    click.echo("")
    click.echo("# assert_production_safe (app/config.py) refuses to boot")
    click.echo("# if these still look like dev placeholders.")


def register_cli(app: Flask) -> None:
    app.cli.add_command(seed_admin)
    app.cli.add_command(seed_demo)
    app.cli.add_command(generate_secrets)
    app.cli.add_command(import_brokers)
