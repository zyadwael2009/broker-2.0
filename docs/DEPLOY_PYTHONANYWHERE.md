# Deploy Wasit to PythonAnywhere (Free tier)

Step-by-step runbook. Follow top to bottom. Where you see `USER`,
substitute your PythonAnywhere username. Estimated first-time run:
**60–90 minutes**, most of which is waiting on installs and uploads.

**Targets:**
- Flask API + Jinja marketing web at `https://USER.pythonanywhere.com`
- Flutter Web app at `https://USER.pythonanywhere.com/app/`

**Constraints (free tier):**
- MySQL only (no Postgres). Handled — see step 4.
- No custom domain (upgrade to Hacker $5/mo when ready).
- Outbound HTTP allowed only to whitelisted hosts (Twilio, FCM,
  Sentry are on it — see step 13).
- 512 MB persistent disk. Plenty for a few thousand listing photos.

---

## 1. Prerequisites

- A PythonAnywhere account: https://www.pythonanywhere.com/registration/register/beginner/
- The Wasit code pushed to a GitHub repo (public or private — both
  work with PA's SSH).
- Your local Windows machine with **Flutter** installed (needed for
  the Web bundle in step 10).

---

## 2. Upload the code to PythonAnywhere

Open a **Bash console** from the PA dashboard (Consoles → Bash), then:

```bash
cd ~
git clone https://github.com/YOUR_GITHUB/broker.git wasit
```

If the repo is private, PA's [SSH key setup docs](https://help.pythonanywhere.com/pages/UsingGitHub/)
walk you through adding a deploy key.

*Alternative (no git):* zip the `backend/` and `docs/` folders on
your machine, upload the zip via the PA Files tab, then:
```bash
cd ~ && mkdir wasit && cd wasit && unzip ../wasit-code.zip
```

---

## 3. Virtualenv + dependencies

Same Bash console:

```bash
mkvirtualenv wasit --python=/usr/bin/python3.12
pip install -r ~/wasit/backend/requirements.txt
```

`mkvirtualenv` is preinstalled on PA. Python 3.12 is available.
This step downloads ~200 MB and takes 3–5 minutes.

If any package fails to build, note the error and check
https://www.pythonanywhere.com/forums/topic/26881/ — most C-toolchain
issues on free tier are already solved there.

---

## 4. Create the MySQL database

**PA dashboard → Databases tab**:

1. Set a **MySQL password** (top of the page). Save it somewhere
   safe — you can't retrieve it later.
2. Under **Create a database**, type `wasit` and click Create.
3. Note the connection host shown at the top:
   `USER.mysql.pythonanywhere-services.com`.

Actual DB name becomes `USER$wasit` (PA prefixes with username + `$`).

---

## 5. Configure `.env`

Copy the production template:

```bash
cd ~/wasit/backend
cp .env.production.example .env
nano .env
```

Generate fresh secrets in another console:
```bash
workon wasit
cd ~/wasit/backend
python -m flask --app wsgi generate-secrets
```

Paste the two lines into `.env`. Then fill in the rest:

```env
FLASK_ENV=production
FLASK_APP=wsgi:app
FLASK_DEBUG=0

# Paste from `flask generate-secrets` — two DIFFERENT values
SECRET_KEY=<from generate-secrets>
JWT_SECRET_KEY=<from generate-secrets>

# MySQL — the '$' is literal, part of PA's DB naming
DATABASE_URL=mysql+pymysql://USER:MYSQL_PASSWORD@USER.mysql.pythonanywhere-services.com/USER$wasit

# CORS + canonical URLs
CORS_ORIGINS=https://USER.pythonanywhere.com
PUBLIC_BASE_URL=https://USER.pythonanywhere.com

# Storage — PA persistent disk
STORAGE_BACKEND=local
UPLOAD_DIR=/home/USER/wasit/uploads
MAX_UPLOAD_MB=20

# Flutter Web bundle location (set in step 10)
WEBAPP_BUILD_DIR=/home/USER/wasit-webapp

# JWT lifetimes
JWT_ACCESS_TTL=3600
JWT_REFRESH_TTL=2592000

# Rate limits — memory:// is fine on PA free tier (one worker)
RATELIMIT_ENABLED=true
RATELIMIT_STORAGE_URI=memory://
RATELIMIT_REGISTER=5 per hour
RATELIMIT_LOGIN=10 per minute
RATELIMIT_REFRESH=30 per minute
RATELIMIT_MESSAGES=30 per minute
RATELIMIT_RATINGS=3 per hour
RATELIMIT_REPORTS=5 per hour
RATELIMIT_VERIFY_PHONE=5 per minute
RATELIMIT_FORGOT_PASSWORD=3 per hour
RATELIMIT_RESET_PASSWORD=5 per minute
RATELIMIT_DEFAULT=1000 per hour;100 per minute

# Legal / contact — shown on /privacy, /terms, /contact
SUPPORT_EMAIL=hello@wasit.eg
SUPPORT_WHATSAPP_URL=https://wa.me/201XXXXXXXXX
COMPANY_LEGAL_NAME=Wasit
COMPANY_ADDRESS=Cairo, Egypt
PDPL_CONSENT_VERSION=1.0

# Leave commented until you sign up (see step 13):
# SENTRY_DSN=
# SMS_PROVIDER=twilio
# TWILIO_ACCOUNT_SID=
# TWILIO_AUTH_TOKEN=
# SMS_FROM_NUMBER=
# FIREBASE_CREDENTIALS_JSON=
# PLAUSIBLE_DOMAIN=
```

`SMS_DEBUG_RETURN_CODE` MUST stay unset (defaults to false) —
`assert_production_safe` refuses to boot with it enabled.

---

## 6. Create the uploads directory + run migrations

```bash
mkdir -p ~/wasit/uploads
workon wasit
cd ~/wasit/backend
python -m flask --app wsgi db upgrade
```

Migration output should end with the G3+PDPL revision:
`Running upgrade c8b47f2e0a9d -> d4a72e1f8b60, Pre-launch — PDPL
consent audit trail`.

If it errors on `Access denied` — the `.env` DATABASE_URL is wrong.
Test with `python -c "from app import create_app; create_app().app_context().push()"`.

---

## 7. Create your admin account

```bash
python -m flask --app wsgi seed-admin \
    --phone +2010XXXXXXXX \
    --password 'PICK_A_STRONG_PASSWORD' \
    --name "Zyad Wael"
```

Skip `seed-demo` for a real launch — bulk-import your real broker
cohort in step 12 instead.

---

## 8. Configure the PythonAnywhere Web tab

**PA dashboard → Web tab → Add a new web app**:

1. Domain: use the default `USER.pythonanywhere.com`.
2. Framework: **Manual configuration** (not "Flask" — the wizard
   creates a fresh scaffold we don't want).
3. Python version: **3.12**.

After creation, scroll down and fill in:

| Field | Value |
|---|---|
| Source code | `/home/USER/wasit/backend` |
| Working directory | `/home/USER/wasit/backend` |
| Virtualenv | `/home/USER/.virtualenvs/wasit` |

---

## 9. Edit the WSGI file

Same Web tab → click the WSGI configuration file link
(`/var/www/USER_pythonanywhere_com_wsgi.py`).

Replace **all** existing content with:

```python
"""Wasit — PythonAnywhere WSGI entry point."""
import sys
from pathlib import Path

PROJECT = Path.home() / "wasit" / "backend"
sys.path.insert(0, str(PROJECT))

# Load .env explicitly — PA doesn't cd into the project dir before
# importing this file, so dotenv's default search would miss it.
from dotenv import load_dotenv
load_dotenv(PROJECT / ".env")

from wsgi import app as application  # noqa
```

Save.

---

## 10. Static file mappings

Still on the Web tab → **Static files** section → add one row:

| URL | Directory |
|---|---|
| `/static/` | `/home/USER/wasit/backend/app/static/` |

That's it. Do NOT map `/files/` (dynamic auth check needed) or
`/app/` (Flask serves it via the webapp blueprint, and PA static
mapping would break the SPA deep-link fallback).

---

## 11. Build + upload the Flutter Web bundle

**On your Windows machine** (not on PA):

```powershell
cd "D:\Programming\broker 2.0"
.\scripts\build-web-app.ps1 `
    -ApiBaseUrl https://USER.pythonanywhere.com `
    -PublicBaseUrl https://USER.pythonanywhere.com
```

Output goes to `mobile\build\web\`. Zip it:
```powershell
Compress-Archive -Path "mobile\build\web\*" -DestinationPath "wasit-webapp.zip" -Force
```

**Upload** — PA Files tab → home dir → Upload → pick `wasit-webapp.zip`.

Then in a Bash console on PA:
```bash
cd ~
mkdir -p wasit-webapp
cd wasit-webapp
unzip -o ~/wasit-webapp.zip
```

`WEBAPP_BUILD_DIR` from your `.env` (step 5) already points here.

---

## 12. First reload + smoke test

**PA dashboard → Web tab → the green "Reload" button** (top right).

Wait ~10 seconds, then verify from a local terminal:

```bash
curl -s https://USER.pythonanywhere.com/health
# → {"status":"ok"}

curl -s https://USER.pythonanywhere.com/browse | head -20
# → HTML (no listings yet, but the page renders)

curl -s https://USER.pythonanywhere.com/privacy | grep -o "hello@wasit"
# → hello@wasit

curl -s https://USER.pythonanywhere.com/sitemap.xml | head -5
# → <?xml version="1.0" encoding="UTF-8"?><urlset ...

curl -sI https://USER.pythonanywhere.com/app/
# → HTTP/1.1 200 OK
```

If any of these 500, check the PA Web tab's **Error log** and
**Server log** links.

Open `https://USER.pythonanywhere.com` in a browser — you should
see the home page. Click through to `/browse` (empty until brokers
are imported), `/for-brokers`, `/privacy`, `/app/` (Flutter loads
in a spinner then boots).

---

## 13. Import the launch cohort

```bash
workon wasit
cd ~/wasit/backend
# Upload brokers.csv via PA Files tab first, or paste it into a
# console with cat > brokers.csv <<EOF ... EOF
python -m flask --app wsgi import-brokers ~/brokers.csv --verified
```

The command writes temp passwords to
`import_logs/import-brokers-<timestamp>.csv`. Download it via PA
Files tab, share credentials over WhatsApp per
`docs/OPERATIONS.md`, then **delete the log file**:

```bash
rm ~/wasit/backend/import_logs/import-brokers-*.csv
```

---

## 14. Optional integrations (turn on as ready)

Free-tier PA blocks outbound HTTP except to a
[whitelist](https://www.pythonanywhere.com/whitelist/). All of these
are on it as of 2026-08:

- **Sentry** — sign up at sentry.io (free tier), grab the DSN, add
  `SENTRY_DSN=...` to `.env`, reload.
- **Twilio SMS** — grab SID/token/phone from twilio.com/console,
  add `SMS_PROVIDER=twilio` + `TWILIO_ACCOUNT_SID` +
  `TWILIO_AUTH_TOKEN` + `SMS_FROM_NUMBER`, reload.
- **Firebase Cloud Messaging** — create a project, download the
  service-account JSON, upload it to
  `~/wasit/backend/firebase-service-account.json`, add
  `FIREBASE_CREDENTIALS_JSON=/home/USER/wasit/backend/firebase-service-account.json`,
  reload.
- **Plausible** — set `PLAUSIBLE_DOMAIN=USER.pythonanywhere.com` (or
  your real domain when you upgrade).

Each is a no-op when unset; flip on when ready.

---

## 15. Deploying updates later

After every code push:

```bash
workon wasit
cd ~/wasit
git pull
pip install -r backend/requirements.txt   # only if requirements.txt changed
cd backend
python -m flask --app wsgi db upgrade     # only if a new migration exists
# then: PA Web tab → Reload
```

If you added new Flutter code that changes the Web bundle:
1. Rebuild locally (step 11).
2. Reupload the zip.
3. Overwrite `~/wasit-webapp/` and reload.

---

## Common failures

| Symptom | Fix |
|---|---|
| 500 on every route, "Access denied" in error log | `.env` `DATABASE_URL` is wrong. Double-check user + password + `$` in DB name. |
| "Refusing to start in FLASK_ENV=production" | You still have a dev-shaped secret. Rerun `flask generate-secrets`, paste fresh values. |
| `/app/` shows "App not built yet" | `WEBAPP_BUILD_DIR` doesn't exist or is empty. Check the path in `.env` matches step 11's unzip destination. |
| Static CSS not loading (unstyled pages) | Static file mapping in step 10 is missing or the directory is wrong. |
| OTP never arrives after Twilio setup | Free-tier PA whitelist may not include `api.twilio.com` anymore. Check the [current whitelist](https://www.pythonanywhere.com/whitelist/). |
| Migrations error on `Enum` type | Rare, but if a migration hand-writes Postgres-specific syntax it'll fail on MySQL. All current migrations use dialect-neutral SQLAlchemy DDL. |

---

## What's next (post-launch)

- **Custom domain**: upgrade to $5/mo Hacker tier, add
  `wasit.eg` (or whatever) in PA Web tab, update `CORS_ORIGINS` +
  `PUBLIC_BASE_URL` in `.env`, reload.
- **Real photos storage**: PA's 512 MB persistent disk holds
  ~5000 photos at 100 KB each. Extend `app/storage/` with an S3/R2
  backend when you outgrow it — the storage abstraction was
  designed for exactly this swap.
- **PostgreSQL upgrade**: on paid tier + custom domain, if you want
  Postgres for its performance edge, re-add `psycopg2-binary` to
  requirements, change `DATABASE_URL`, `mysqldump | psql` your data.
