# Wasit — Operations

Short reference for the operator (Zyad) once Wasit is live. Deploy
setup lives in `DEPLOY.md`; this file covers the day-to-day ops that
happen after the site is running.

---

## Bulk-onboard the first cohort of brokers

The single biggest launch-week task: turn a spreadsheet of 20–100
verified brokers into real accounts on Wasit, so buyers arriving on
Day 1 don't see empty search results.

**Command**:
```bash
python -m flask --app wsgi import-brokers brokers.csv --verified
```

**CSV shape** (header row required):

| Column | Required | Notes |
|---|---|---|
| `phone` | yes | Any format — normalized to E.164. E.g. `01000000042`. |
| `full_name` | yes | 3–120 chars. |
| `email` | no | Falls back to NULL. |
| `goeic_number` | yes when `--verified` | Their real GOEIC registration ID. |
| `notes` | no | Free-text; not stored in DB (ignored). |

Extra columns are ignored with a warning.

**Options**:
- `--verified` — mark imported brokers as VERIFIED immediately. Zyad
  should have already confirmed their GOEIC number by hand before
  running with this flag. Without it, brokers land as PENDING and go
  through the normal admin queue.
- `--dry-run` — parse + report, write nothing. Use before every real
  import.
- `--password-length 12` — length of the generated temp passwords.
  Default 12; minimum 8.

**Output**:
```
CSV rows: 20
  Created:  18
  Updated:  1
  Skipped:  1
  Errors:   0

Skipped:
  row 7: +201555000123  → existing-buyer (refusing role change)

Temp passwords written to: import_logs/import-brokers-20260817T104500Z.csv
(share credentials over WhatsApp, then delete that file)
```

**Sharing credentials**: open the `import_logs/*.csv` file, message
each broker their phone + temp password over WhatsApp with a link to
`https://wasit.eg`. Ask them to change the password on first login.
**Delete the log file after distribution** — it holds plaintext
passwords.

**Idempotent**: running the same CSV twice updates existing rows
instead of creating duplicates. Password is NOT changed on reruns —
so if a broker has already logged in and set their own password, a
rerun won't reset it.

**Refuse conditions** (row appears in `Skipped` or `Errors`):
- Phone matches an existing buyer → skipped (refuse role change).
- Phone matches an existing admin → skipped.
- `--verified` set without `goeic_number` → error.
- Phone doesn't normalize to a valid number → error.
- `full_name` shorter than 3 chars or longer than 120 → error.

---

## Approving verifications the standard way

For brokers who self-signed up (not bulk-imported):

1. Admin logs into `/admin/brokers?status=pending`.
2. Reviews the uploaded GOEIC doc + registration number.
3. Clicks approve or reject.
4. Broker gets a push notification (if they registered a device) and
   their public `/b/<id>` credential page goes live.

**Public SLA**: verify every broker within 24 business hours. Publish
this on `/for-brokers`. If Zyad can't meet it, adjust the number
publicly before quiet-breaking the SLA.

---

## Responding to reports

Buyers can flag a listing or broker via the `/reports` endpoint.
Reports land in the admin queue at `/admin/reports?status=open`.

**Response SLA**: acknowledge every report within 4 business hours.
That's an internal target — no need to publish it, but track it.

---

## Rotating a compromised secret

If a `SECRET_KEY` or `JWT_SECRET_KEY` is ever leaked:

1. `flask generate-secrets` → grab fresh values.
2. Update the secret in your production secret store.
3. Restart every gunicorn worker (rolling restart is fine, but the
   consequence of changing `JWT_SECRET_KEY` is that **every existing
   session is invalidated** — users will need to log in again). This
   is the intended behaviour for a compromise scenario.
4. `SECRET_KEY` change also invalidates password-reset tokens still
   in flight; users on those flows re-request.

---

## Postgres backup restore

Tested during launch prep (see `DEPLOY.md § 3`). Recap:

- Backups happen automatically via the hosting provider — verify the
  latest backup timestamp weekly.
- Restore procedure: spin up a scratch DB from the latest backup,
  point a spare app instance at it, run `flask db upgrade`, hit
  `/health`. If it comes back 200, real restore would work.
- Never restore over the production DB without first exporting the
  current state — some data since the last backup is otherwise lost.

---

## Extending

New CLI commands live in `backend/app/cli.py` and register in
`register_cli()` at the bottom. Follow the pattern of
`generate_secrets` (side-effect-free helper) or `import_brokers`
(the core logic in a `_run_…` function so tests don't need Click).
