# Mobile — Flutter

Phases 1–5 implemented: auth, broker verification, listings (browse/create/photo upload/auto-expire), per-listing document checklist, price transparency, admin queues (brokers + flagged listings + pending docs).

## Setup

```bash
cd mobile
flutter pub get
```

Requires Flutter 3.22+ and (for Android) an Android SDK.

## Run

```bash
# Android emulator, backend on host localhost — 10.0.2.2 is the emulator's alias.
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000

# Physical device on your LAN
flutter run --dart-define=API_BASE_URL=http://192.168.x.y:5000

# iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:5000

# Web (Edge/Chrome)
flutter run -d edge --dart-define=API_BASE_URL=http://localhost:5000 --web-port 3000
```

Release builds must supply `API_BASE_URL` explicitly — the app crashes at startup otherwise (see `lib/core/env.dart::Env.assertConfigured`), so a broken build can't ship silently:

```bash
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

## Structure

```
lib/
├── main.dart               # ProviderScope + BrokerApp; hydrates auth + theme before first frame
├── app.dart                # MaterialApp.router with light + dark theme
├── router.dart             # go_router; role-based landing + gates
├── theme.dart              # AppColors tokens (light + dark), Material 3 ThemeData
├── core/
│   ├── env.dart            # API_BASE_URL from --dart-define
│   ├── token_storage.dart  # flutter_secure_storage wrapper
│   ├── api_client.dart     # Dio + JWT interceptor + single-flight refresh
│   └── theme_controller.dart  # light/dark/system, persisted
└── features/
    ├── auth/                # login, register, hydrate/refresh/logout
    ├── broker/              # verification screen (Phase 2)
    ├── admin/               # queue: brokers + flagged listings + pending documents tabs
    ├── listings/            # browse, my listings, create, detail (Phase 3)
    ├── documents/           # per-listing checklist section + owner dialog (Phase 4)
    ├── market/              # price transparency screen with trend chart (Phase 5)
    └── shared/widgets/      # VerifiedBadge, StatusCard, ThemeToggleButton
```

## Role landings

- **Buyer** → `/` — Browse Listings
- **Broker** → `/broker/listings` — My Listings (verification gate if not verified)
- **Admin** → `/admin/queue` — Brokers + Flagged Listings tabs

## Screens

- **Auth**: login (phone + password), register (buyer/broker toggle, honest disclaimer for brokers)
- **Broker verification**: status card (pending/verified/rejected with reviewer note), GOEIC input, file picker for pdf/image, resubmit
- **Broker listings**: list of own listings with expiry chip, "New listing" FAB, verification-status shield icon in AppBar, market button
- **Create listing**: form + geolocation ("Use my location") + multi-photo picker
- **Listing detail**: photo carousel, price/area/type, **property documents checklist** (verified/self-reported/pending/rejected badges; owner dialog for upload/self-report/remove), verified broker card, "Still available" (owner) or "Call broker" (buyer)
- **Browse listings**: type filter chips, pull-to-refresh, empty states, market button
- **Price transparency** (`/market/prices`): governorate → city → type dropdowns, big median EGP/m² headline, range + middle-50% + listings-count mini-stats, 12-month trend line chart (fl_chart), honest "signal not a valuation" disclaimer
- **Admin queue**: three tabs — Brokers (pending/verified/rejected filter), Flagged Listings (unflag inline), Pending Documents (view + approve + reject-with-reason)

## Theme

Toggle button (☀/☾/auto icon) in every logged-in AppBar cycles system → light → dark. Choice persists across launches.

Palette: deeper Nile teal primary, warm Egyptian-gold accent for future decorative moments, muted emerald/amber/red for verified/pending/rejected status.
