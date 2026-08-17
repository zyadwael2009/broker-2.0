# Wasit — Deploy Checklist

The short version of what to do before pointing `wasit.eg` at a
production server. Each item is either a **[BLOCK]** launch-blocker or
a **[SOON]** first-week fix.

---

## 1. Generate real secrets — [BLOCK]

```bash
cd backend
python -m flask --app wsgi generate-secrets
```

Copy the two lines into your secrets store — **never** commit them to
git. Recommended stores in order of preference:

- Provider-native secret manager (Fly.io `flyctl secrets set …`,
  Railway env vars, cloud KMS)
- Doppler
- 1Password Ops / CLI
- Absolute last resort: `.env` file on the server, `chmod 600`, owned
  by the app user

`SECRET_KEY` and `JWT_SECRET_KEY` **must be different** — reusing one
value shrinks the compromise surface for no benefit.

---

## 2. Fill in `.env.production.example` — [BLOCK]

Copy `backend/.env.production.example` → your secrets store, then
replace every `REPLACE_ME` placeholder. Bare-minimum keys the app
will refuse to boot without:

- `SECRET_KEY` (from `generate-secrets`)
- `JWT_SECRET_KEY` (from `generate-secrets`, different value)
- `DATABASE_URL` (a real Postgres, not localhost)
- `CORS_ORIGINS` (comma-separated real domains, no `*`)
- `FLASK_ENV=production`

Boot-time enforcement lives in
`backend/app/config.py::assert_production_safe` — if any placeholder
sneaks through, the app raises before serving requests.

---

## 3. Database — [BLOCK]

- Managed Postgres from your hosting provider (Fly.io PG, Railway,
  Supabase, RDS). Free tiers are fine to start.
- Enable **daily automatic backups**, **30-day retention**.
- **Test restore ONCE** before launch: spin up a scratch DB, restore
  yesterday's backup, verify the schema comes back. Every provider
  documents this — do it before you need it.

Migrations run on deploy:

```bash
python -m flask --app wsgi db upgrade
```

---

## 4. Redis — [SOON]

Rate limiter + JWT revocation store need Redis in a multi-worker
prod setup, otherwise limits and revocations are per-process.

- `RATELIMIT_STORAGE_URI=redis://…/0`
- `JWT_REVOCATION_URI=redis://…/1`

If launching with 1 gunicorn worker on one box, `memory://` works
for the first week — but tighten before scaling out.

---

## 5. HTTPS + HSTS — [BLOCK]

- Hosting provider terminates TLS (all of Fly, Railway, Render do
  automatically).
- Add `Strict-Transport-Security: max-age=31536000; includeSubDomains`
  via a reverse-proxy header rule or Flask-Talisman middleware.

---

## 6. Sentry — [BLOCK]

Sign up (free tier fine), set `SENTRY_DSN` in secrets. The Flask
integration is already wired in `app/__init__.py` — set the env var
and 500s start reporting. Watch it for the first week.

---

## 7. Uptime monitor — [SOON]

Better Stack / UptimeRobot, 60-second interval, pinging:

- `https://wasit.eg/health` (returns 200 `{status: "ok"}`)
- `https://wasit.eg/api/public/listings` (checks DB path too)

Alert on 3-strike down → Slack + phone.

---

## 8. Storage — [SOON]

`STORAGE_BACKEND=local` + `UPLOAD_DIR=/data/uploads` on persistent
disk is fine for the first month or two of low volume. When photo
volume grows, extend `app/storage/` with an S3/R2 backend and switch
the env var — the storage abstraction was designed for exactly this.

For CDN offload day-one, put Cloudflare in front of the whole domain
— it'll cache `/files/…` responses automatically with a small
Cache-Control tweak on the storage response.

---

## 9. SMS + FCM — [SOON]

The SMS/FCM abstractions no-op when credentials are unset — the app
works without them, users just can't verify phone numbers or receive
pushes.

- **SMS**: recommend **Twilio** for launch (fastest onboarding),
  switch to **Vodafone Egypt bulk SMS** in month 2 for local pricing.
  Set `SMS_PROVIDER=twilio` + `TWILIO_*` + `SMS_FROM_NUMBER`.
- **FCM**: create a Firebase project, download the service-account
  JSON, set `FIREBASE_CREDENTIALS_JSON=/path/to/file.json` (or the
  literal JSON string).

Test one end-to-end (register a phone, receive OTP; send a message,
receive push) before flipping the DNS.

---

## 10. Launch-day SEO — [BLOCK]

- Verify the domain in Google Search Console.
- Submit `https://wasit.eg/sitemap.xml`. G3's landing pages start
  getting crawled the moment you do.
- If using Plausible: set `PLAUSIBLE_DOMAIN=wasit.eg`. One `<script>`
  tag auto-injects; no cookie banner needed.

---

## Post-deploy smoke test

Run through this in a browser as the DNS goes live:

1. `https://wasit.eg/` renders
2. `https://wasit.eg/browse` shows real listings
3. `https://wasit.eg/browse/cairo` (or another populated gov) renders
   with the G3 landing layout
4. `https://wasit.eg/sitemap.xml` lists landing URLs
5. `https://wasit.eg/health` returns `{"status":"ok"}`
6. Register a new account via the Flutter app → OTP arrives → login
   works
7. As a broker, submit verification with a real doc → admin sees it
   in the queue
8. Sentry has no unhandled exceptions

If any of these fail, investigate before announcing the launch.
