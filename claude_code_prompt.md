# Project: Egyptian Real Estate Trust App (Flutter)

## Context
I'm building a Flutter mobile app targeting the Egyptian real estate market. Unlike existing apps (Aqarmap, Aqar Pro, Property Finder Egypt) which are just listing marketplaces, this app's core differentiator is **trust and verification** — solving the biggest pain points buyers/renters face in Egypt:

1. Unlicensed/scam brokers (سماسرة) who intimidate buyers and demand undocumented commissions — this is serious enough that Egypt passed Law No. 21/2022 to regulate real estate brokerage.
2. No easy way to verify a broker is legally registered (GOEIC broker registry) — currently a manual, offline process.
3. No easy way to verify property ownership/legal status before paying anything (title deed, liens, disputes).
4. Fake, duplicate, or stale listings (photos reused, sold units still showing as available).
5. No transparent price data — buyers rely on broker guesswork.

Note: there is NO public government API to auto-check broker registration or property records. Verification must be a manual admin-review workflow (user/broker uploads proof documents, an admin approves and issues a verified badge) — do not build or assume an automated gov API integration.

## Stack
- Frontend: Flutter (mobile-first, Android priority, iOS later)
- Backend: Flask (Python), REST API — this matches my existing stack (I already run Flask + Flutter apps on PythonAnywhere/Railway)
- Database: MySQL or PostgreSQL (whichever you recommend for this schema)
- Auth: JWT-based, with separate roles: buyer/renter, broker/agent, admin
- File storage: plan for property photos + verification documents (assume S3-compatible or local disk for now, I'll wire up cloud storage later)

## MVP Scope — build in this order

### Phase 1: Core data model + auth
- Users table with role (buyer, broker, admin)
- Broker profile: name, phone, GOEIC registration number (text field), uploaded registration proof document, verification_status (pending/verified/rejected)
- Property listings: title, description, price, area (m²), location (governorate/city/district), property type, photos, owner/broker reference, listing status (active/sold/expired), created_at, last_confirmed_at
- JWT auth endpoints (register, login, role-based access)

### Phase 2: Verified broker system
- Broker submits registration documents for review
- Admin panel/endpoint to approve/reject broker verification
- "Verified" badge shown on broker profile and their listings in the app
- Public users can see broker verification status before contacting them

### Phase 3: Listing integrity features
- Auto-expire listings after 30 days unless the broker/owner reconfirms them ("still available" button)
- Simple duplicate-photo detection (perceptual image hashing) to flag likely reposted/stolen listings for admin review
- Require at least one photo + location pin per listing

### Phase 4: Document verification checklist (buyer-facing)
- Per-listing checklist the seller/broker can fill in and upload proof for: title deed registered at notary (الشهر العقاري), no liens/disputes, tax clearance
- Buyers see which checkboxes have admin-verified proof vs self-reported (be honest about this distinction in the UI — don't imply legal certainty we can't guarantee)

### Phase 5: Price transparency
- Price-per-m² view aggregated from the app's own listings, filterable by area/district
- Simple trend chart if enough historical data exists

## What I need from you right now
Start with Phase 1. Please:
1. Propose the Flask project structure (matching how I'd deploy this to PythonAnywhere) and the Flutter project structure.
2. Design the database schema for users, broker_profiles, and listings.
3. Build the Flask auth endpoints (register/login/JWT) with the three roles.
4. Build the Flutter auth screens (login/register) wired to the Flask API.

Ask me clarifying questions before writing code if anything about hosting, database choice, or role permissions is ambiguous. Keep the legal/verification language in the UI honest — this app assists with verification, it does not replace a lawyer or the notary office.

## Audit requirement — do this after every edit and every phase
After every single edit (file created/modified) and before moving on to the next task or phase:
1. Re-read the file(s) you just changed and confirm the code actually does what was intended — don't just assume the edit worked.
2. Check for obvious bugs, broken imports, mismatched types, unhandled errors, or leftover placeholder/TODO code that should have been filled in.
3. Run whatever quick check is possible (lint, syntax check, `flutter analyze`, a basic Flask route test, etc.) — actually run it, don't just say you would.
4. Give me a short audit summary: what was built, what was verified, and any issues found or assumptions made.
5. Only move on to the next edit/phase after this audit is done and any issues are fixed or flagged to me. Do not silently continue to the next phase if the current one isn't verified working.
