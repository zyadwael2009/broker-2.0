# Wasit — Google Play Store Listing Copy

Paste-ready copy for Play Console. Character limits noted per field.
The English variant is for users who set Play Store to English; the Arabic
variant is what Egyptian users will actually see.

> **How to attach a translation in Play Console**: Store presence →
> Main store listing → Manage translations → Add your own translations →
> select `ar` (Arabic) → paste the Arabic block.

---

## 🇸🇦 Arabic (primary — default for Egypt)

### App name (max 30 chars)
```
وسيط — توثيق السماسرة
```
*(28 chars — inside limit. Falls back to "وسيط" alone if too long.)*

### Short description (max 80 chars)
```
شهادة السمسار العقاري اللي كل مصري يستاهلها. صفحة موثّقة بـ GOEIC وتقييمات حقيقية.
```
*(79 chars — right at the limit.)*

### Full description (max 4000 chars)
```
وسيط هو منصة توثيق السماسرة العقاريين في مصر. كل سمسار بيديك صفحة عامة واحدة تشاركها،
بتثبت تسجيله بـ GOEIC، بتوثّق إعلاناته، وبتحمل كل تقييم كسبه.

ابعتها قبل أول لقاء — واختصر على نفسك أسئلة الشك.

━━━ للسمسار العقاري ━━━

• صفحة عامة موثّقة على wasit.app/b/<id> — بنراجع مستندك، وبنطلعّلك لينك عملاؤك يقدروا يثقوا فيه.
• كل إعلان بيحمل أوراقه — سند الملكية، شهادة عدم الرهن، المخالصة الضريبية. المشتري بيشوف بالظبط اللي موثّق قبل ما يكلّمك.
• تقييمات ليها معنى فعلًا — مفيش تقييمات عشوائية، مفيش نجوم مزيفة. المشترين اللي كلّموك بس هم اللي يقدروا يقيّموك — الرقم اللي على صفحتك حقيقتك.
• شفافية أسعار — رسم بياني للأسعار في منطقتك عشان تسعّر صح.

━━━ للمشتري / المستأجر ━━━

• تصفّح إعلانات موثّقة — كل كارت تحت من وسيط راجعنا تسجيل السمسار وأوراق العقار.
• شوف الوسيط قبل ما تكلّمه — صفحته العامة بتقولك أوراقه، تقييماته، وسنين خبرته.
• رسايل مباشرة — تواصل مع السمسار من داخل التطبيق، وتاريخ محادثاتك محفوظ.
• لو حصل مشكلة — بلّغ عن أي إعلان أو سلوك مش تمام، وفريقنا بيراجع.

━━━ ليه وسيط ━━━

وسيط مش بديل عن المحامي أو الشهر العقاري — إحنا بنساعد في التوثيق، لكن تأكد دايمًا من الملكية في السجل العقاري قبل التوقيع.

━━━━━━━━━━━━━━━━

• الموقع: https://wasit.pythonanywhere.com
• الخصوصية: https://wasit.pythonanywhere.com/privacy
• الشروط: https://wasit.pythonanywhere.com/terms
• الدعم: support@wasit.app
```

---

## 🇬🇧 English (fallback)

### App name (max 30 chars)
```
Wasit — Verified Brokers
```
*(24 chars.)*

### Short description (max 80 chars)
```
Verified real-estate brokers in Egypt. Real listings, GOEIC-checked profiles.
```
*(77 chars.)*

### Full description (max 4000 chars)
```
Wasit is the verification platform for Egyptian real-estate brokers. Every broker
gets a single public page they can share — one that proves their GOEIC registration,
carries their listings' actual paperwork, and holds every review they've earned.

Send it before the first meeting. Skip the guesswork.

━━━ FOR BROKERS ━━━

• A verified public page at wasit.app/b/<id> — we review your registration, then
  hand you a link your clients can trust.
• Every listing carries its papers — title deed, mortgage release, tax clearance.
  Buyers see exactly what's verified before they contact you.
• Reviews that actually mean something — no random star ratings, no fake five-stars.
  Only buyers who contacted you can review you. The number on your page is real.
• Price transparency — a chart of what's actually selling in your area so you
  can price with confidence.

━━━ FOR BUYERS & RENTERS ━━━

• Browse verified listings — every card here has a broker whose GOEIC registration
  we reviewed and a property whose paperwork we've seen.
• Check the broker before you call — their public page shows their documents,
  their reviews, and their years of experience.
• Direct messaging — talk to the broker inside the app; your history is saved.
• Something wrong? Report any listing or bad conduct and our team reviews it.

━━━ WHY WASIT ━━━

Wasit is not a substitute for a lawyer or the Real-Estate Registry. We help with
documentation, but always verify ownership at the Registry before signing.

━━━━━━━━━━━━━━━━

• Site: https://wasit.pythonanywhere.com
• Privacy: https://wasit.pythonanywhere.com/privacy
• Terms: https://wasit.pythonanywhere.com/terms
• Support: support@wasit.app
```

---

## Play Console — other required fields

### Category
- **App category**: House & Home *(or Business — House & Home is closer)*
- **Tags**: Real Estate, Property, House & Home, Egypt

### Contact details
- **Email**: `support@wasit.app` *(create this mailbox or use a Gmail alias; must
  respond — Play verifies)*
- **Website**: `https://wasit.pythonanywhere.com`
- **Phone**: optional, only include if you have a real support line

### External marketing
- Do NOT tick "Marketing opt-out" — leave Google's default (allows Google to
  feature you).

---

## Data Safety declarations

Fill this in Play Console → App content → Data safety. Every "collected" toggle
below is REQUIRED — omitting one is grounds for takedown.

| Data type | Collected? | Shared with 3rd parties? | Optional? | Purpose |
|---|---|---|---|---|
| Name | Yes | No | Required | Account management |
| Email address | Yes | No | Optional | Account management |
| Phone number | Yes | No | Required | Account management, authentication (OTP) |
| User photos | Yes | No | Optional | App functionality (listing photos, broker ID) |
| Files & docs (PDFs) | Yes | No | Optional | App functionality (GOEIC certificate, title deeds) |
| Approximate location | Yes | No | Optional | App functionality ("use my location" on create-listing) |
| Precise location | Yes | No | Optional | App functionality (same as above, when user grants precise) |
| In-app messages | Yes | No | Required | App functionality (broker ↔ buyer threads) |
| Device or other IDs | Yes | No | Required | Push notifications (Firebase Messaging registration token) |
| Crash logs | No (unless you add Firebase Crashlytics later) | — | — | — |
| Diagnostics | No | — | — | — |

### Security practices to tick "Yes"
- ✅ Data is encrypted in transit (HTTPS)
- ✅ You can request that data be deleted (implement `/auth/delete-account` if
  not already — Play requires an in-app account-deletion path from Aug 2022)

---

## Content rating (IARC questionnaire)

Answers that apply to Wasit — a factual marketplace with user messaging:

- Violence / gore: No
- Sexual content / nudity: No
- Profanity / crude humor: No
- Controlled substances: No
- Gambling / simulated gambling: No
- Realistic gambling with money: No
- User-generated content: **YES** (listings, reviews, messages) — this will
  add ~1 rating tier and require you to declare the moderation/report flow
- User-to-user communication: **YES** (in-app messaging)
- Shares user location: **YES** (optional, for create-listing)
- Digital purchases: No

**Expected rating**: PEGI 3 / ESRB Everyone / IARC 3+.

---

## Target audience

- **Age group**: 18+ *(financial-transaction-adjacent — do NOT check "designed
  for children", ever)*
- **Appeals to children under 18**: No

## Ads

- **Contains ads**: No

---

## Review notes (given to Google's reviewer — private)

Paste this in Play Console → App content → Government apps → App access:

```
Wasit requires an account to use most features. Please use the following
demo credentials to log in:

  Phone (Egypt): +20 15550 000 001
  Password: demopass

This account has broker role with sample listings and messages seeded.
Public browse without login is not currently offered.

The app connects to https://wasit.pythonanywhere.com over HTTPS.

If SMS OTP is required at any step, use debug code 000000 (dev fixture is
disabled in production — the demo account is pre-verified so this should
not appear).
```

*Only paste this if the demo account is actually seeded on production. If
it isn't, register a real test account instead and paste those credentials.*

---

## Screenshots checklist

- ✅ 512×512 icon — `docs/store/play_store_icon_512.png`
- ✅ 1024×500 feature graphic — `docs/store/play_feature_graphic_1024x500.png`
- ⏳ Phone screenshots (min 2, up to 8) — captured via `adb screencap` from
  the release build, then framed via `scratchpad/frame_screenshot.py`
- ❌ 7" tablet screenshots (optional but recommended)
- ❌ 10" tablet screenshots (optional but recommended)
