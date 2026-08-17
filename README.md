# Wasit — verified brokers for Egyptian real estate

Mobile app + REST backend + public marketing web for the Egyptian real-estate market. The one thing that sets Wasit apart from Aqarmap / Aqar Pro / Property Finder: it's built around **trust and verification** — the biggest pain point for buyers dealing with unlicensed brokers, forged listings, and unclear title.

The original product spec lives in [`claude_code_prompt.md`](./claude_code_prompt.md). What's shipped goes well beyond it: rich property model with sale/rent + bedrooms + compound filters, phone-verification OTP flow, password reset with session invalidation, Flutter Web deployment at `/app/`, and legal + analytics for launch.

## What's in the box

| Folder | What it is |
|---|---|
| [`backend/`](./backend/) | Flask REST API. Auth, broker verification, listings + photos + auto-expire + duplicate detection, per-listing document checklist, market price transparency. |
| [`mobile/`](./mobile/) | Flutter app (Android + iOS + web preview). Bilingual English/Arabic with RTL. Buyer, broker, and admin roles. |
| [`docker-compose.yml`](./docker-compose.yml) | One-command dev stack: Postgres 16 + Redis 7 + backend. Mirrors prod topology. |

## Quick start

```bash
# One command brings up backend + Postgres + Redis.
docker compose up --build

# In another shell — seed an admin so you can approve brokers.
docker compose exec backend flask seed-admin \
  --phone +201000000000 --password "supersecret" --name "Site Admin"

# Run the mobile app against the compose backend.
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5000
```

Web preview:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000 --web-port 3000
```

## Without Docker

- [`backend/README.md`](./backend/README.md) covers the `venv` + `flask run` path (SQLite for dev or point at a Postgres you already have).
- [`mobile/README.md`](./mobile/README.md) covers Android emulator + physical device + web setup.

## Sanity check

```bash
./scripts/preflight.sh     # runs backend pytest + flutter analyze + flutter build web
```

## Architecture at a glance

```
┌───────────────────────────────┐
│   Flutter (mobile + web)      │
│  ─ features/                  │
│    auth / broker / admin /    │
│    listings / documents /     │
│    market / shared            │
│  ─ Riverpod + go_router + dio │
│  ─ EN + AR, LTR + RTL         │
└──────────────┬────────────────┘
               │ HTTPS + Bearer JWT
               ▼
┌───────────────────────────────┐
│      Flask API (Gunicorn)     │
│  ─ /auth /brokers /listings   │
│    /admin /market /files      │
│  ─ Flask-JWT-Extended          │
│  ─ Flask-Limiter (Redis in    │
│    prod, memory in dev)       │
│  ─ pHash duplicate detection  │
│  ─ Magic-byte upload check    │
└──────┬────────────────────┬───┘
       │                    │
       ▼                    ▼
┌───────────────┐   ┌───────────────┐
│  Postgres 16  │   │   Redis 7     │
│  Alembic mig. │   │  rate limits  │
│               │   │  JWT revoked  │
└───────────────┘   └───────────────┘
```

## Trust vocabulary

The app is careful about what "verified" means and never overstates it. Three levels users see, in three places:

- **Verified broker** — admin reviewed the broker's GOEIC (Egyptian broker registry) proof document.
- **Admin-verified property document** — for each of `title deed` / `no liens` / `tax clearance`, admin reviewed the proof.
- **Self-reported** — broker ticked a checkbox but uploaded no proof. Buyers see this distinctly.

Everywhere any of these show up, the app also shows a small honest note: this assists with verification, it does not replace a lawyer or the notary office.

## Flutter Web deployment (Path 2)

The mobile Flutter app also compiles to a browser and is served at `/app/`
on the same domain as the Jinja marketing web. One codebase, two shipping
targets: native mobile app + full-featured web app.

### Build & deploy

```powershell
# From repo root — build the web bundle for production
.\scripts\build-web-app.ps1 `
  -ApiBaseUrl https://api.wasit.app `
  -PublicBaseUrl https://wasit.app
```

Or the Bash equivalent from Git Bash / WSL:

```bash
./scripts/build-web-app.sh https://api.wasit.app https://wasit.app
```

Output lands at `mobile/build/web/`. Flask's `webapp_bp` serves it under
`/app/*` (see `backend/app/webapp/routes.py`). Set `WEBAPP_BUILD_DIR` in
production to an absolute path if the repo layout differs on the server.

### Local dev

```powershell
# 1. Boot the backend on 5150 (any port works)
$env:DATABASE_URL="sqlite:///live.db"; $env:SECRET_KEY="dev"; $env:JWT_SECRET_KEY="dev"; `
$env:UPLOAD_DIR="./_up"; $env:STORAGE_BACKEND="local"; $env:RATELIMIT_ENABLED="false"; `
$env:FLASK_APP="wsgi:app"; $env:PUBLIC_BASE_URL="http://localhost:5150"
cd backend; flask run --host=127.0.0.1 --port=5150

# 2. Build the web bundle pointing at the same port
.\scripts\build-web-app.ps1  # defaults to http://localhost:5150

# 3. Open http://localhost:5150/app/ — Wasit boot splash → login screen
```

### How marketing pages deep-link into the app

Every "Open in app" / "Message" / "Register" CTA on the Jinja templates
points at a specific Flutter route via hash-URLs:

| Marketing page CTA | Destination |
|---|---|
| `/l/<id>` → *Open in the app* | `/app/#/listings/<id>` |
| `/b/<id>` → *Message in the app* | `/app/#/brokers/<id>` |
| `/for-brokers` → *Register — free* | `/app/#/register` |

## Phase 12 additions

- **Photo compression** on client (max 1920 px longer edge, ~82% JPEG). Cuts a broker's upload from ~30 MB to ~2–3 MB with no visible quality loss. Wired into all three upload paths (verification doc, listing photos, listing documents).
- **Public web view** — server-rendered Jinja pages at `/`, `/browse`, `/l/<id>`, plus `/sitemap.xml`, `/robots.txt`, and JSON at `/api/public/*`. Every URL is Google-indexable, carries OpenGraph + JSON-LD tags, and strips broker phone/email for anonymous callers. Configure the absolute base with `PUBLIC_BASE_URL=https://your-domain.com`.
- **Push notifications** via Firebase Cloud Messaging. Silent no-op unless you set `FIREBASE_CREDENTIALS_JSON` on the backend and drop platform config files on the client. Triggers push on message send, verification approve/reject, document approve/reject, and report resolution.

### Enabling FCM

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. **Backend**: download the service-account JSON from *Project settings → Service accounts → Generate new private key*. Set `FIREBASE_CREDENTIALS_JSON=/absolute/path/to/serviceAccount.json` (or paste the JSON string directly).
3. **Android**: in the Firebase console, add an Android app with the applicationId in `mobile/android/app/build.gradle`, download `google-services.json`, drop it at `mobile/android/app/google-services.json`.
4. **iOS**: add an iOS app in the console, download `GoogleService-Info.plist`, drop it at `mobile/ios/Runner/GoogleService-Info.plist`.
5. **Web**: paste the Firebase web config into `mobile/web/index.html` AND `mobile/web/firebase-messaging-sw.js` (both have commented stubs).

Without any of the above, the app still boots normally — notifications simply don't work.

## Enabling error tracking + analytics (optional)

**Sentry** — set `SENTRY_DSN` in your env; the boot picks it up and starts capturing errors automatically. Left unset in dev / tests. Optional extras: `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`, `SENTRY_TRACES_SAMPLE_RATE`.

**Plausible Analytics** — cookie-free, no consent banner needed. Sign up at plausible.io, set `PLAUSIBLE_DOMAIN=wasit.app`. A single `<script>` tag on every public page starts logging anonymous page views. Unset → no tracking.

**Contact info surfaced on /privacy, /terms, /contact:**
```
SUPPORT_EMAIL=hello@wasit.app
SUPPORT_WHATSAPP_URL=https://wa.me/201555000000
COMPANY_LEGAL_NAME=Wasit for Real Estate Technology Ltd.
COMPANY_ADDRESS=Cairo, Egypt
```
All optional — templates render placeholder text if any are unset.

## App-store submission

See [`docs/APP_STORE_COPY.md`](./docs/APP_STORE_COPY.md) for title / subtitle / description / keywords templates in EN + AR, screenshot content plan, and pre-submit checklist. Both stores hard-require /privacy and /terms URLs — those are shipped as draft placeholder pages you replace with lawyer-blessed copy before public launch.

### Generating store screenshots

1. Install Playwright (one-time, ~400MB download):

    ```bash
    pip install -r scripts/screenshots-requirements.txt
    playwright install chromium
    ```

2. Boot the backend + Flutter Web (see *Flutter Web deployment* above) with `flask seed-demo` data loaded on port 5250.

3. Run:

    ```bash
    python scripts/generate_screenshots.py
    # Or one specific device family / page:
    python scripts/generate_screenshots.py --device phone-play --page listing
    ```

4. Output lands in `docs/screenshots/{device}/{page}.png` at the exact sizes both stores require, ready for direct upload.

## Testing

```bash
# Backend
cd backend && python -m pytest tests -p no:langsmith
# Flutter
cd mobile && flutter analyze
```

Currently: **94 backend tests, 0 analyzer issues.**
