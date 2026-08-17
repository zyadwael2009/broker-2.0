# Backend — Egyptian Real Estate Trust App

Flask REST API. Phases 1–5 implemented (auth, broker verification, listings + auto-expire + duplicate detection, per-listing document checklist, price transparency) plus auth hardening (rate limiting, JWT revocation, magic-byte content validation, refresh-token rotation) and Alembic migrations.

## Setup

Two paths:

**A. Docker (recommended for prod-parity)** — everything comes up together:

```bash
docker compose up --build      # from repo root
```

Postgres 16, Redis 7, and the Flask app all start. Migrations run automatically. See the root `README.md`.

**B. Bare Python** — for hacking on a laptop:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # then edit DATABASE_URL, secrets
```

### Database

**For local dev with SQLite (fastest):**

```bash
export DATABASE_URL=sqlite:///dev.db      # PowerShell: $env:DATABASE_URL="sqlite:///dev.db"
python -c "from app import create_app; from app.extensions import db; app = create_app(); app.app_context().push(); db.create_all()"
```

**For Postgres:**

```bash
psql -U postgres -c "CREATE DATABASE broker_dev;"
export DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/broker_dev
export FLASK_APP=wsgi:app
flask db upgrade    # applies the baseline in migrations/versions/
```

The baseline migration is committed — no `db init` needed for a fresh checkout.

Create the first admin (public register rejects role=admin):

```bash
flask seed-admin --phone +201000000000 --password "supersecret" --name "Site Admin"
```

Run:

```bash
export FLASK_APP=wsgi:app
flask run --host=0.0.0.0 --port=5000     # dev
gunicorn wsgi:app                         # prod
```

The `--host=0.0.0.0` is required if a device on your LAN (or an Android emulator) needs to reach the API — `flask run` defaults to loopback only.

## Endpoints

### Auth (Phase 1)
| method | path | notes |
|---|---|---|
| GET  | `/health` | liveness probe |
| POST | `/auth/register` | `{phone, password, full_name, role: 'buyer'\|'broker', email?}` |
| POST | `/auth/login` | `{phone, password}` |
| POST | `/auth/refresh` | refresh token in `Authorization: Bearer …` |
| GET  | `/auth/me` | access token required |

Phone accepts any format — server normalizes to E.164 assuming Egypt (`+20…`).

### Broker verification (Phase 2)
| method | path | who | notes |
|---|---|---|---|
| POST | `/brokers/me/verification` | broker | multipart: `goeic_registration_number` + `document` file. Overwrites prior submission, resets status to pending. Allowed types: pdf, jpg, png, webp. |
| GET | `/brokers/me/verification` | broker | current verification status |
| GET | `/brokers/<id>` | any authed | public broker profile: name, phone, verification status |
| GET | `/admin/brokers?status=…` | admin | list, defaults to `pending`; `verified` / `rejected` also accepted |
| GET | `/admin/brokers/<user_id>` | admin | full detail incl. `document_url` |
| POST | `/admin/brokers/<user_id>/approve` | admin | requires document uploaded (409 otherwise) |
| POST | `/admin/brokers/<user_id>/reject` | admin | body: `{reason: "..."}` |

### Listings (Phase 3)
| method | path | who | notes |
|---|---|---|---|
| POST | `/listings` | verified broker | requires lat/lng |
| GET | `/listings` | any authed | hides expired + only shows verified-broker listings; filters: governorate, city, property_type, min/max price |
| GET | `/listings/mine` | broker | includes expired |
| GET | `/listings/<id>` | any authed | with `is_expired` flag |
| PATCH | `/listings/<id>` | owner (verified) | `status` may only be `sold` or `hidden`; re-activate via `/confirm` |
| DELETE | `/listings/<id>` | owner or admin | |
| POST | `/listings/<id>/confirm` | owner (verified) | "still available" — resets 30-day clock |
| POST | `/listings/<id>/photos` | owner (verified) | multipart `photo`; runs pHash duplicate check silently |
| DELETE | `/listings/<id>/photos/<photo_id>` | owner (verified) | |
| GET | `/admin/listings/flagged` | admin | duplicate-suspected listings |
| POST | `/admin/listings/<id>/unflag` | admin | clear the flag |

### Property documents (Phase 4)
| method | path | who | notes |
|---|---|---|---|
| GET | `/listings/<id>/documents` | any authed | 3-row checklist (title_deed, no_liens, tax_clearance); `rejection_reason` + `document_url` returned only for the owner |
| POST | `/listings/<id>/documents/<kind>/self-report` | owner (verified) | broker asserts "I have this" without uploading proof |
| POST | `/listings/<id>/documents/<kind>` | owner (verified) | multipart `document` file → state=pending |
| DELETE | `/listings/<id>/documents/<kind>` | owner (verified) | clear entry and remove file |
| GET | `/admin/documents/pending` | admin | queue — only uploaded docs (self-reported never surfaces) |
| POST | `/admin/documents/<id>/approve` | admin | only allowed on `pending`; 409 otherwise |
| POST | `/admin/documents/<id>/reject` | admin | body `{reason}`; only allowed on `pending`; 409 otherwise |

### Market / price transparency (Phase 5)
| method | path | notes |
|---|---|---|
| GET | `/market/price-per-m2` | `{count, median, min, max, p25, p75, unit}`; filters: `governorate`, `city`, `district`, `property_type` |
| GET | `/market/price-per-m2/trend?months=1..36` | monthly buckets `[{month, count, median}]`; drops months with fewer than 2 listings |
| GET | `/market/filters` | distinct governorates + cities-per-governorate for building UI dropdowns |

Market data mirrors the buyer feed exactly: verified brokers only, active+sold statuses only, active listings older than 30 days excluded (sold prices are timeless).

### Files
| method | path | who | notes |
|---|---|---|---|
| GET | `/files/listing-photos/**` | any (public) | listing photos are public content |
| GET | `/files/broker-docs/**` | admin or owning broker | broker verification documents |
| GET | `/files/listing-docs/**` | admin or owning broker | per-listing property documents |

## Tests

```bash
python -m pytest tests -p no:langsmith
```

Tests use an in-memory SQLite; no Postgres needed.

## Deploy notes

The app reads everything from env vars. Any host works:

- `DATABASE_URL` — full SQLAlchemy URL (e.g. `postgresql+psycopg2://…`)
- `SECRET_KEY`, `JWT_SECRET_KEY` — long random strings
- `STORAGE_BACKEND=local`, `UPLOAD_DIR=/persistent/uploads`
- `CORS_ORIGINS=https://your-app.example` — comma-separated
- `MAX_UPLOAD_MB=20`
- `JWT_ACCESS_TTL=3600`, `JWT_REFRESH_TTL=2592000`

**Production safety net:** when `FLASK_ENV=production`, the app refuses to boot if `SECRET_KEY`, `JWT_SECRET_KEY`, or `DATABASE_URL` are unset (dev fallbacks) or if `CORS_ORIGINS=*`. See `app/config.py::assert_production_safe`.

**For horizontal scaling:** point rate limits and JWT revocation at Redis so multiple Gunicorn workers stay in sync:

```
RATELIMIT_STORAGE_URI=redis://cache:6379/0
JWT_REVOCATION_URI=redis://cache:6379/1
```

**Error tracking:** set `SENTRY_DSN` and errors are shipped to Sentry (no-op when unset — dev and tests need no account).

**Refresh-token rotation:** every `POST /auth/refresh` issues a fresh refresh token and revokes the presented one. If a leaked token is ever used, the legitimate user's next refresh trips the blocklist and forces a clean re-login.

PythonAnywhere, Railway, Fly, and bare-metal Gunicorn all use `wsgi:app` as the entry point.
