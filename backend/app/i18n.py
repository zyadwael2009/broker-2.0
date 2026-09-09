"""EN ↔ AR translation for the public Jinja marketing/SEO surface.

Design choices:
- Flat dict, not Flask-Babel. ~250 strings across 13 templates —
  the dict is easier to review, translate, and audit than a `.po`
  workflow. Adding Flask-Babel later means renaming `t(key)` calls
  to `gettext(key)` — trivial.
- Cookie-based (`wasit_lang`) + `?lang=` URL trigger. No path
  prefix — every route works with either language via the same
  URL. Trade-off: search engines index the default (EN) view.
  Path-prefixed URLs + hreflang tags are a follow-up if we want
  first-class Arabic SEO indexation.
- `t(key)` returns the key itself on a miss so typos are loud.
- Arabic strings are Egyptian-informal, not MSA formal — matches
  how brokers and buyers actually talk.
"""
from __future__ import annotations

from urllib.parse import urlparse

from flask import Blueprint, Response, g, redirect, request

LANGUAGES = ("en", "ar")
DEFAULT_LANG = "en"
LANG_COOKIE = "wasit_lang"
LANG_COOKIE_MAX_AGE = 60 * 60 * 24 * 365  # 1 year


# ── Translation dict ────────────────────────────────────────────────
# Keys are flat, named `<page>_<section>_<field>`. Missing keys
# fall back to the key string itself (loud errors on typos, not
# silent fallbacks to English — that would mask bugs).

TRANSLATIONS: dict[str, dict[str, str]] = {
    "en": {
        # ── Chrome (used in base.html) ──────────────────────────
        "meta_default_title": "Wasit — Verified brokers for Egyptian real estate",
        "meta_default_description": "Egyptian real estate you can trust. Every broker is verified with GOEIC registration.",
        "brand_aria_home": "Wasit — home",
        "nav_browse": "Browse",
        "nav_for_brokers": "For brokers",
        "nav_get_verified": "Get verified",
        "lang_toggle_to_ar": "العربية",
        "lang_toggle_to_en": "English",
        "footer_title": "Wasit",
        "footer_note": "Wasit assists with verification — it does not replace a lawyer or the notary office. Always confirm ownership at the Real Estate Registry before signing.",
        "footer_browse": "Browse listings",
        "footer_for_brokers": "For brokers",
        "footer_privacy": "Privacy",
        "footer_terms": "Terms",
        "footer_contact": "Contact",
        "footer_sitemap": "Sitemap",

        # ── home.html ────────────────────────────────────────────
        "home_meta_title": "Wasit — the credential every Egyptian real-estate broker deserves",
        "home_meta_description": "Wasit gives verified Egyptian real-estate brokers a public credential page: GOEIC verification, star ratings, and every listing they hold — one shareable link for WhatsApp, Instagram, and business cards.",
        "home_hero_tag": "For Egyptian real-estate brokers",
        "home_hero_title": "Prove you're real. Win the client.",
        "home_hero_lede": "Wasit gives you one shareable page that proves your GOEIC registration, shows your active listings, and carries every review you've earned. Send it before the first meeting — skip the sceptical questions.",
        "home_hero_cta_primary": "Get verified — free",
        "home_hero_cta_secondary": "Or browse listings →",
        "home_hero_disclaimer": "Wasit assists with verification — it does not replace a lawyer or the notary office. Always confirm ownership at the Real Estate Registry before signing.",
        "home_trust_1_title": "A GOEIC-verified public page",
        "home_trust_1_body_prefix": "We review your registration document, then issue a shareable",
        "home_trust_1_body_suffix": "URL your clients can trust.",
        "home_trust_2_title": "Ratings that actually mean something",
        "home_trust_2_body": "Only buyers who've messaged you can rate you. No drive-by reviews, no fake stars — the number on your page is real.",
        "home_trust_3_title": "Every listing carries its papers",
        "home_trust_3_body": "Title deed, no-liens certificate, tax clearance — tracked per listing. Buyers see exactly what's verified before they call.",
        "home_secondary_title": "Not a broker?",
        "home_secondary_lede": "Wasit is built around brokers, but if you're here to buy — browse every verified listing in Egypt right now.",
        "home_secondary_cta": "Browse verified listings →",

        # ── for_brokers.html ─────────────────────────────────────
        "fb_meta_title": "For brokers · Wasit — get verified, win the client",
        "fb_meta_description": "Wasit is a credential platform for Egyptian real-estate brokers. Get your GOEIC verification reviewed, receive a public /b/ URL, and share it on WhatsApp before every meeting.",
        "fb_hero_tag": "For Egyptian real-estate brokers",
        "fb_hero_title_l1": "Verified beats unverified.",
        "fb_hero_title_l2": "Every time.",
        "fb_hero_lede": "Send your client one link before the meeting. They see your GOEIC registration, your active listings, and every review you've earned. No more “who is this guy” energy.",
        "fb_hero_cta_primary": "Get verified — free",
        "fb_hero_cta_secondary": "See how it works →",
        "fb_hero_social_singular": "Trusted by <b>{count}</b> verified broker across Egypt.",
        "fb_hero_social_plural": "Trusted by <b>{count}</b> verified brokers across Egypt.",
        "fb_how_kicker": "How it works",
        "fb_how_title": "Three steps. About forty-eight hours.",
        "fb_how_1_title": "Submit your GOEIC registration",
        "fb_how_1_body": "Sign up in the app, enter your GOEIC number, and upload a photo or scan of your registration document. That's the whole form.",
        "fb_how_2_title": "Our reviewer checks it",
        "fb_how_2_body": "A human at Wasit opens your document and confirms it against the GOEIC record. Typically under 48 hours. If anything looks off we message you back with a specific reason — not a template.",
        "fb_how_3_title": "You get your public credential",
        "fb_how_3_body_prefix": "Your",
        "fb_how_3_body_suffix": "URL goes live. Paste it into your WhatsApp Business bio, Instagram profile, your business card. Every client who clicks sees proof, not promises.",
        "fb_features_kicker": "What verification unlocks",
        "fb_features_title": "Everything you need to look serious.",
        "fb_features_1_title": "A public credential page",
        "fb_features_1_body": "Verified seal, GOEIC number, jurisdiction, active listings, review history. Design that reads as official, not startup.",
        "fb_features_2_title": "Ratings buyers actually trust",
        "fb_features_2_body": "Only buyers who've messaged you can rate. No drive-by stars. When your page says 4.8, it means 4.8.",
        "fb_features_3_title": "Per-listing document checklist",
        "fb_features_3_body": "Title deed, no-liens certificate, tax clearance. Upload each, or mark as self-reported. Buyers see the difference.",
        "fb_features_4_title": "In-app messaging & call routing",
        "fb_features_4_body": "Buyers reach you through the app. Every conversation lives alongside the listing and the docs — nothing gets lost in WhatsApp.",
        "fb_features_5_title": "Duplicate-listing detection",
        "fb_features_5_body": "Someone reposts your photo? Our system flags it and admins review. Your work stays yours.",
        "fb_features_6_title": "Neighbourhood price transparency",
        "fb_features_6_body": "Median EGP/m² for every governorate, refreshed as listings post. Anchor your prices to real data during negotiation.",
        "fb_compare_kicker": "The difference",
        "fb_compare_title": "What changes on day one.",
        "fb_compare_before_title": "Before Wasit",
        "fb_compare_before_1": "Every client asks “are you licensed?” before they trust anything else.",
        "fb_compare_before_2": "Your ratings live on WhatsApp screenshots. Or nowhere.",
        "fb_compare_before_3": "Buyers ghost you after the first call — you have no way to build reputation across deals.",
        "fb_compare_before_4": "Your best listings get reposted by someone else with no consequences.",
        "fb_compare_before_5": "You compete on price because you can't compete on credibility.",
        "fb_compare_after_title": "With Wasit",
        "fb_compare_after_1": "You paste one URL. The verification, GOEIC number, and rating are already there.",
        "fb_compare_after_2": "Every review comes from a real buyer conversation. It's public, permanent, and searchable.",
        "fb_compare_after_3": "Your credibility compounds across deals — a strong page opens the next one.",
        "fb_compare_after_4": "Duplicate detection flags your photos on other listings. Admins act.",
        "fb_compare_after_5": "You compete on trust. The buyers who care will pay for it.",
        "fb_faq_kicker": "Common questions",
        "fb_faq_title": "Straight answers.",
        "fb_faq_1_q": "How much does verification cost?",
        "fb_faq_1_a": "Free during our launch. We'll be transparent well in advance if that changes.",
        "fb_faq_2_q": "What documents do I need?",
        "fb_faq_2_a": "Your GOEIC registration certificate. A clear photo or scan is fine. That's it. We never ask for national-ID card or bank details.",
        "fb_faq_3_q": "What if my GOEIC is expired or being renewed?",
        "fb_faq_3_a": "We'll tell you exactly what's missing. If it's a renewal in progress you can resubmit as soon as it's reissued.",
        "fb_faq_4_q": "Can I use Wasit while I'm still pending review?",
        "fb_faq_4_a": "You can sign in, but posting listings and sending messages are gated on verification. This is the whole point — buyers only ever see verified brokers.",
        "fb_faq_5_q": "What happens if I get rejected?",
        "fb_faq_5_a": "You get a specific reason and can resubmit with corrected documents. No cooldown, no penalty.",
        "fb_faq_6_q": "Do buyers see my phone number?",
        "fb_faq_6_a_prefix": "Only inside the app after they open a thread with you. Your public",
        "fb_faq_6_a_suffix": "URL never shows your phone or email — everything goes through in-app messaging.",
        "fb_final_title": "Ready to get verified?",
        "fb_final_lede": "Register, upload your GOEIC document, and paste your public URL into every conversation from tomorrow onward.",
        "fb_final_cta_primary": "Register — free",
        "fb_final_cta_secondary": "Browse the marketplace",
        "fb_final_disclaimer": "Wasit assists with verification — it does not replace a lawyer or the notary office. Always confirm ownership at the Real Estate Registry before signing any contract.",
        "fb_final_legal_prefix": "By registering you agree to our",
        "fb_final_legal_terms": "Terms",
        "fb_final_legal_and": ",",
        "fb_final_legal_privacy": "Privacy Policy",
        "fb_final_legal_pdpl": ", and consent to processing of your registration details for identity verification under Egypt's Personal Data Protection Law (151/2020).",
        "fb_final_legal_questions": "Questions?",
        "fb_final_legal_contact": "Contact us",

        # ── browse.html ──────────────────────────────────────────
        "browse_meta_title": "Browse listings · Wasit",
        "browse_meta_description": "Verified real estate listings across Egypt. Apartments, houses, villas, land, and commercial property from GOEIC-registered brokers.",
        "browse_header_title": "Verified listings",
        "browse_header_lede": "Every card below is from a broker whose GOEIC registration we've reviewed.",
        "browse_filter_kind": "Kind",
        "browse_filter_governorate": "Governorate",
        "browse_filter_city": "City",
        "browse_filter_type": "Type",
        "browse_filter_bedrooms": "Bedrooms",
        "browse_filter_price": "Price (EGP)",
        "browse_filter_all": "All",
        "browse_filter_any": "Any",
        "browse_filter_anywhere": "Anywhere",
        "browse_filter_apply": "Apply",
        "browse_filter_reset": "Reset",
        "browse_filter_price_min": "Min",
        "browse_filter_price_max": "Max",
        "browse_bedrooms_5plus": "5+",
        "browse_bedrooms_n_plus": "{n}+",
        "browse_empty": "No listings match your filters.",
        "browse_empty_reset": "Reset",
        "browse_empty_suffix": "to see everything.",

        # kind + property_type labels used in cards, landings, filters
        "kind_sale": "For sale",
        "kind_rent": "For rent",
        "kind_sale_short": "sale",
        "kind_rent_short": "rent",
        "ptype_apartment": "Apartment",
        "ptype_villa": "Villa",
        "ptype_house": "House",
        "ptype_land": "Land",
        "ptype_commercial": "Commercial",
        "ptype_apartment_plural": "Apartments",
        "ptype_villa_plural": "Villas",
        "ptype_house_plural": "Houses",
        "ptype_land_plural": "Land",
        "ptype_commercial_plural": "Commercial property",

        # ── _partials/listing_card.html ─────────────────────────
        "card_bed": "bed",
        "card_bath": "bath",
        "card_currency_egp": "EGP",
        "card_per_month": " / mo",

        # ── landing.html (G3 SEO) ────────────────────────────────
        "landing_facet_all": "All",
        "landing_facet_any": "Any",
        "landing_more_filters": "More filters →",
        "landing_related_title": "Also popular in {gov}",
        "landing_related_listing_singular": "{n} listing",
        "landing_related_listing_plural": "{n} listings",
        "landing_breadcrumb_home": "Home",
        "landing_breadcrumb_browse": "Browse",
        "landing_intro_template": "Browse {count} verified {facet} listing{plural} in {subject}. Every broker on Wasit is registered with the Egyptian General Organization for Import & Export Control (GOEIC) — you can contact them directly without middlemen.",
        "landing_intro_default_facet": "property",
        "landing_h1_property_in": "Property in {subject}",
        "landing_h1_facet_in": "{facet} in {subject}",
        "landing_title_property_in": "Property in {subject} | Wasit",
        "landing_title_facet_in": "{facet} in {subject} | Wasit",
        "landing_title_kind_in": "Property {kind} in {subject} | Wasit",

        # ── listing.html ─────────────────────────────────────────
        "listing_copy_link": "Copy link",
        "listing_copy_link_done": "Copied ✓",
        "listing_share_whatsapp_aria": "Share on WhatsApp",
        "listing_share_whatsapp": "WhatsApp",
        "listing_shareable_url_aria": "Shareable listing URL",
        "listing_fact_bed": "bed",
        "listing_fact_bath": "bath",
        "listing_fact_floor": "Floor",
        "listing_fact_furnished": "Furnished",
        "listing_fact_unfurnished": "Unfurnished",
        "listing_delivery_ready": "Ready to move",
        "listing_delivery_under_construction": "Under construction",
        "listing_about_heading": "About this property",
        "listing_location_heading": "Location",
        "listing_map_of": "Map of {city}",
        "listing_open_larger_map": "Open larger map →",
        "listing_disclaimer_strong": "Honest note.",
        "listing_disclaimer_body": "This platform helps verify — it does not replace a lawyer or the notary office. Always confirm ownership at the Real Estate Registry before signing.",
        "listing_verified_broker_fallback": "Verified broker",
        "listing_verified_badge": "✓ Verified",
        "listing_reviews_singular": "({n} review)",
        "listing_reviews_plural": "({n} reviews)",
        "listing_broker_note": "Contact the broker via the app to keep messages, ratings, and the document trail in one place.",
        "listing_open_in_app": "Open in the app",
        "listing_see_credentials": "See {name}'s public credentials →",
        "listing_broker_generic_name": "broker",
        "listing_sticky_open_in_app": "Open in app",

        # ── broker.html ──────────────────────────────────────────
        "broker_og_suffix": "verified broker",
        "broker_share_url_aria": "Shareable profile URL",
        "broker_copy_link": "Copy link",
        "broker_share_whatsapp": "WhatsApp",
        "broker_share_whatsapp_aria": "Share on WhatsApp",
        "broker_seal_title_en": "VERIFIED BROKER",
        "broker_seal_since_prefix": "since",
        "broker_seal_aria_verified_broker": "Verified broker",
        "broker_seal_aria_goeic": "GOEIC",
        "broker_seal_aria_verified_on": "verified",
        "broker_metaline_country": "Egypt",
        "broker_metaline_since": "Broker since {year}",
        "broker_rating_line_from_singular": "from {count} review",
        "broker_rating_line_from_plural": "from {count} reviews",
        "broker_rating_aria": "Rated {avg} out of 5 from {count} reviews",
        "broker_meta_goeic": "GOEIC No.",
        "broker_meta_jurisdiction": "Jurisdiction",
        "broker_meta_verified": "Verified",
        "broker_meta_valid_through": "Valid through",
        "broker_action_message": "Message in the app",
        "broker_action_copy_profile": "Copy profile link",
        "broker_at_a_glance_aria": "Broker at a glance",
        "broker_stat_active_listings": "Active listings",
        "broker_stat_reviews": "Reviews",
        "broker_stat_avg_rating": "Avg rating",
        "broker_stat_verified": "Verified",
        "broker_stat_year_unit": "y",
        "broker_stat_less_than_1y": "<1",
        "broker_section_active_listings": "Active listings",
        "broker_section_browse_all": "Browse all →",
        "broker_section_recent_reviews": "Recent reviews",
        "broker_review_stars_aria": "{n} out of 5",
        "broker_mrz_head": "Machine-Readable Zone · Registry Data",

        # ── legal_base.html ──────────────────────────────────────
        "legal_draft_banner": "Draft — not legal advice. Awaiting review by an Egyptian lawyer before launch.",
        "legal_last_updated": "Last updated:",
        "legal_updated_date": "17 August 2026",

        # ── 404.html ─────────────────────────────────────────────
        "404_title": "Not found · Wasit",
        "404_meta_description": "The page you're looking for isn't here.",
        "404_heading": "This page is no longer available",
        "404_body": "The listing or broker profile you're looking for may have been removed, sold, or is no longer verified.",
        "404_cta_browse": "Browse verified listings",
        "404_cta_home": "Back to home",

        # ── Stitch round: header, home bands, results bar, legal hub ──
        "header_live_count": "{n} verified listings live",
        "footer_about_body": "Wasit is an Egyptian platform where every broker is checked against their GOEIC registration before a single listing goes live.",
        "footer_pill": "Every broker reviewed by our team",
        "footer_col_quick": "Quick links",
        "footer_col_legal": "Legal & compliance",
        "footer_delete_account": "Delete your account",
        "footer_copyright": "© {year} Wasit. Verified Egyptian real estate.",
        "home_stat_listings_label": "Verified listings live right now",
        "home_stat_verified_value": "100%",
        "home_stat_verified_label": "Of listings come from a GOEIC-checked broker",
        "home_stat_zero_value": "0",
        "home_stat_zero_label": "Listings from unverified brokers — they cannot post",
        "home_compliance_title": "Where the verification actually comes from",
        "home_compliance_body": "Three concrete checks, and the honest limits of each one.",
        "home_compliance_c1_title": "GOEIC registration",
        "home_compliance_c1_body": "A broker uploads their commercial-registry document. Our team reads it before the account can list anything.",
        "home_compliance_c2_title": "Egypt's data protection law",
        "home_compliance_c2_body": "Personal data is handled under Law 151/2020 (PDPL), and every broker records their consent when they submit documents.",
        "home_compliance_c3_title": "What we do not claim",
        "home_compliance_c3_body": "We are not the notary office. Verification means a human checked the paperwork — always confirm the title deed yourself before paying.",
        "browse_results_count": "{n} verified listings match",
        "browse_results_shown": "Showing {shown}",
        "browse_sort_label": "Sort",
        "browse_sort_newest": "Newest first",
        "browse_sort_oldest": "Oldest first",
        "browse_sort_price_asc": "Price: low to high",
        "browse_sort_price_desc": "Price: high to low",
        "browse_sort_area_desc": "Largest area",
        "card_verified_broker": "Verified broker",
        "card_view_details": "View the listing",
        "legal_hub_title": "Legal & compliance",
        "legal_hub_body": "Our privacy policy, terms of use, and how to delete your account — written to Egypt's Personal Data Protection Law 151/2020 and Google Play's data rules.",
        "legal_hub_pill": "Published document",
        "legal_tab_privacy": "Privacy & data",
        "legal_tab_terms": "Terms of use",
        "legal_tab_delete": "Delete your account",
        "legal_index_title": "On this page",
        "legal_dpo_title": "Data protection contact",
        "legal_dpo_body": "For any question about your data, or to file a request under the PDPL, write to us and we will answer in writing.",
        "legal_dpo_email_label": "Email",
        "legal_help_title": "Need this in a hurry?",
        "legal_help_body": "Account deletion from inside the app is immediate. Email requests are handled within 7 working days.",
        "legal_help_cta": "Contact us",
    },
    "ar": {
        # ── Chrome (used in base.html) ──────────────────────────
        "meta_default_title": "وسيط — وسطاء عقاريون موثّقون في مصر",
        "meta_default_description": "عقارات مصرية تقدر تثق فيها. كل وسيط عندنا موثّق بتسجيل GOEIC.",
        "brand_aria_home": "وسيط — الرئيسية",
        "nav_browse": "تصفح",
        "nav_for_brokers": "للوسطاء",
        "nav_get_verified": "توثيق حسابك",
        "lang_toggle_to_ar": "العربية",
        "lang_toggle_to_en": "English",
        "footer_title": "وسيط",
        "footer_note": "وسيط بيساعد في التوثيق — لكنه مش بديل عن المحامي أو الشهر العقاري. تأكد دايمًا من الملكية في السجل العقاري قبل التوقيع.",
        "footer_browse": "تصفح الإعلانات",
        "footer_for_brokers": "للوسطاء",
        "footer_privacy": "الخصوصية",
        "footer_terms": "الشروط",
        "footer_contact": "تواصل معنا",
        "footer_sitemap": "خريطة الموقع",

        # ── home.html ────────────────────────────────────────────
        "home_meta_title": "وسيط — الشهادة اللي كل سمسار عقاري مصري يستاهلها",
        "home_meta_description": "وسيط بيدي الوسطاء العقاريين المصريين الموثّقين صفحة توثيق عامة: توثيق GOEIC، تقييمات بالنجوم، وكل إعلاناتهم — كل ده في لينك واحد للواتساب وإنستغرام وكارت الشغل.",
        "home_hero_tag": "للوسطاء العقاريين في مصر",
        "home_hero_title": "أثبت إنك حقيقي. اقفل الصفقة.",
        "home_hero_lede": "وسيط بيديك صفحة واحدة تشاركها، بتثبت تسجيل GOEIC بتاعك، بتوّرِي إعلاناتك الشغالة، وبتحمل كل تقييم كسبته. ابعتها قبل أول لقاء — واختصر على نفسك أسئلة الشك.",
        "home_hero_cta_primary": "وثّق حسابك — مجانًا",
        "home_hero_cta_secondary": "أو تصفح الإعلانات ←",
        "home_hero_disclaimer": "وسيط بيساعد في التوثيق — مش بديل عن المحامي أو الشهر العقاري. تأكد دايمًا من الملكية في السجل العقاري قبل التوقيع.",
        "home_trust_1_title": "صفحة عامة موثّقة بـ GOEIC",
        "home_trust_1_body_prefix": "بنراجع مستند تسجيلك، وبنطلعّلك لينك",
        "home_trust_1_body_suffix": "عملاؤك يقدروا يثقوا فيه.",
        "home_trust_2_title": "تقييمات ليها معنى فعلًا",
        "home_trust_2_body": "المشترين اللي كلّموك بس هم اللي يقدروا يقيّموك. مفيش تقييمات عشوائية، مفيش نجوم مزيفة — الرقم اللي على صفحتك حقيقي.",
        "home_trust_3_title": "كل إعلان بيحمل أوراقه",
        "home_trust_3_body": "سند الملكية، شهادة عدم الرهن، المخالصة الضريبية — بتتابع لكل إعلان. المشتري بيشوف بالظبط إيه اللي موثّق قبل ما يكلّمك.",
        "home_secondary_title": "مش وسيط؟",
        "home_secondary_lede": "وسيط مبني حوالين الوسطاء، لكن لو هنا عشان تشتري — تصفح كل إعلان موثّق في مصر دلوقتي.",
        "home_secondary_cta": "تصفح الإعلانات الموثّقة ←",

        # ── for_brokers.html ─────────────────────────────────────
        "fb_meta_title": "للوسطاء · وسيط — وثّق واكسب العميل",
        "fb_meta_description": "وسيط منصة توثيق للوسطاء العقاريين المصريين. راجعنا توثيق GOEIC بتاعك، خد لينك /b/ عام، وشاركه على واتساب قبل كل مقابلة.",
        "fb_hero_tag": "للوسطاء العقاريين في مصر",
        "fb_hero_title_l1": "الموثّق بيكسب.",
        "fb_hero_title_l2": "كل مرة.",
        "fb_hero_lede": "ابعت لعميلك لينك واحد قبل الاجتماع. يشوف تسجيل GOEIC، إعلاناتك الشغالة، وكل تقييم كسبته. بلاش طاقة «مين ده اللي بيتكلم».",
        "fb_hero_cta_primary": "وثّق حسابك — مجانًا",
        "fb_hero_cta_secondary": "شوف إزاي بيشتغل ←",
        "fb_hero_social_singular": "موثوق فيه من <b>{count}</b> وسيط موثّق في كل مصر.",
        "fb_hero_social_plural": "موثوق فيه من <b>{count}</b> وسيط موثّق في كل مصر.",
        "fb_how_kicker": "إزاي بيشتغل",
        "fb_how_title": "ثلاث خطوات. حوالي ٤٨ ساعة.",
        "fb_how_1_title": "قدّم تسجيل GOEIC بتاعك",
        "fb_how_1_body": "سجّل في التطبيق، ادخل رقم GOEIC، وارفع صورة أو مسح ضوئي لمستند التسجيل. ده الفورم كله.",
        "fb_how_2_title": "المراجع بتاعنا بيتأكد",
        "fb_how_2_body": "موظف بشري في وسيط بيفتح مستندك ويأكده مع سجل GOEIC. عادة أقل من ٤٨ ساعة. لو حاجة مش مظبوطة، بنبعت لك سبب محدد — مش رد جاهز.",
        "fb_how_3_title": "بتاخد شهادة التوثيق العامة",
        "fb_how_3_body_prefix": "لينكك",
        "fb_how_3_body_suffix": "بيبقى شغّال. حطّه في بايو الواتساب بيزنس، ملف الإنستغرام، كارت الشغل. كل عميل يفتح اللينك يشوف إثبات، مش وعود.",
        "fb_features_kicker": "التوثيق بيفتح لك إيه",
        "fb_features_title": "كل حاجة محتاجها عشان تبان جاد.",
        "fb_features_1_title": "صفحة توثيق عامة",
        "fb_features_1_body": "ختم توثيق، رقم GOEIC، جهة الاختصاص، إعلانات شغالة، تاريخ التقييمات. تصميم بيقرأ رسمي، مش ستارتاب.",
        "fb_features_2_title": "تقييمات المشتري بيثق فيها فعلًا",
        "fb_features_2_body": "بس المشترين اللي كلّموك يقدروا يقيّموا. مفيش تقييمات عشوائية. لما صفحتك تقول 4.8، معناها 4.8.",
        "fb_features_3_title": "قائمة مستندات لكل إعلان",
        "fb_features_3_body": "سند الملكية، شهادة عدم الرهن، المخالصة الضريبية. ارفع كل واحدة، أو سجّلها كذاتية. المشتري بيشوف الفرق.",
        "fb_features_4_title": "مراسلة داخل التطبيق وإدارة المكالمات",
        "fb_features_4_body": "المشترين بيوصلوك عن طريق التطبيق. كل محادثة بتكون جنب الإعلان والمستندات — مفيش حاجة بتضيع في الواتساب.",
        "fb_features_5_title": "كشف الإعلانات المكررة",
        "fb_features_5_body": "حد نشر صورتك تاني؟ نظامنا بيعلّم عليه والأدمن بيراجع. شغلك يفضل بتاعك.",
        "fb_features_6_title": "شفافية أسعار المنطقة",
        "fb_features_6_body": "متوسط الجنيه/متر² لكل محافظة، بيتحدّث مع كل إعلان جديد. اربط أسعارك ببيانات حقيقية أثناء التفاوض.",
        "fb_compare_kicker": "الفرق",
        "fb_compare_title": "بيتغير إيه من أول يوم.",
        "fb_compare_before_title": "قبل وسيط",
        "fb_compare_before_1": "كل عميل بيسأل «هو حضرتك مرخّص؟» قبل أي حاجة تانية.",
        "fb_compare_before_2": "تقييماتك على سكرين شوت واتساب. أو مفيش.",
        "fb_compare_before_3": "المشترين بيختفوا بعد أول مكالمة — مفيش طريقة تبني سمعتك عبر الصفقات.",
        "fb_compare_before_4": "أفضل إعلاناتك بيعيد نشرها حد تاني بدون عواقب.",
        "fb_compare_before_5": "بتتنافس على السعر لأنك مش قادر تتنافس على المصداقية.",
        "fb_compare_after_title": "مع وسيط",
        "fb_compare_after_1": "بتلصق لينك واحد. التوثيق، رقم GOEIC، والتقييم كلهم موجودين.",
        "fb_compare_after_2": "كل تقييم من محادثة حقيقية مع مشتري. علني، دايم، قابل للبحث.",
        "fb_compare_after_3": "مصداقيتك بتتراكم عبر الصفقات — صفحة قوية بتفتح الصفقة اللي بعدها.",
        "fb_compare_after_4": "كشف التكرار بيعلّم على صورك في إعلانات تانية. الأدمن بيتحرك.",
        "fb_compare_after_5": "بتتنافس على الثقة. المشترين اللي بيهمهم هيدفعوا فيها.",
        "fb_faq_kicker": "أسئلة شائعة",
        "fb_faq_title": "إجابات مباشرة.",
        "fb_faq_1_q": "التوثيق بيكلّف كام؟",
        "fb_faq_1_a": "مجاني أثناء الإطلاق. لو الأمور اتغيّرت، هنقولكم بشفافية قبل ما ده يحصل.",
        "fb_faq_2_q": "محتاج إيه مستندات؟",
        "fb_faq_2_a": "شهادة تسجيل GOEIC. صورة أو مسح واضح. بس. عمرنا ما بنطلب بطاقة الرقم القومي أو بيانات البنك.",
        "fb_faq_3_q": "لو تسجيل GOEIC منتهي أو بيتجدد؟",
        "fb_faq_3_a": "هنقولك بالظبط الناقص إيه. لو تجديد شغال، تقدر تعيد الرفع أول ما يتصدر تاني.",
        "fb_faq_4_q": "أقدر أستخدم وسيط وأنا لسه بستنى المراجعة؟",
        "fb_faq_4_a": "تقدر تسجّل دخول، بس نشر الإعلانات وإرسال الرسائل مقفولين لحد التوثيق. ده أهم حاجة — المشترين مش بيشوفوا غير وسطاء موثّقين.",
        "fb_faq_5_q": "لو رفضتوا حسابي بيحصل إيه؟",
        "fb_faq_5_a": "بتاخد سبب محدد وتقدر تعيد الرفع بمستندات مصححة. مفيش انتظار، مفيش عقوبة.",
        "fb_faq_6_q": "المشتري بيشوف رقم موبايلي؟",
        "fb_faq_6_a_prefix": "بس داخل التطبيق بعد ما يفتح محادثة معاك. لينكك العام",
        "fb_faq_6_a_suffix": "عمره ما بيوّرِي رقمك أو إيميلك — كل حاجة بتعدّي جوة رسائل التطبيق.",
        "fb_final_title": "جاهز تتوثّق؟",
        "fb_final_lede": "سجّل، ارفع مستند GOEIC، والصق لينكك العام في كل محادثة من بكرا وطالع.",
        "fb_final_cta_primary": "سجّل — مجانًا",
        "fb_final_cta_secondary": "تصفح السوق",
        "fb_final_disclaimer": "وسيط بيساعد في التوثيق — مش بديل عن المحامي أو الشهر العقاري. أكد دايمًا من الملكية في السجل العقاري قبل التوقيع على أي عقد.",
        "fb_final_legal_prefix": "بتسجيلك أنت موافق على",
        "fb_final_legal_terms": "الشروط",
        "fb_final_legal_and": " و",
        "fb_final_legal_privacy": "سياسة الخصوصية",
        "fb_final_legal_pdpl": "، وموافق على معالجة بيانات تسجيلك لأغراض التحقق من الهوية بموجب قانون حماية البيانات الشخصية المصري (151/2020).",
        "fb_final_legal_questions": "عندك أسئلة؟",
        "fb_final_legal_contact": "تواصل معنا",

        # ── browse.html ──────────────────────────────────────────
        "browse_meta_title": "تصفح الإعلانات · وسيط",
        "browse_meta_description": "إعلانات عقارية موثّقة في كل مصر. شقق، بيوت، فيلات، أراضي، وعقارات تجارية من وسطاء مسجّلين في GOEIC.",
        "browse_header_title": "إعلانات موثّقة",
        "browse_header_lede": "كل كارت تحت من وسيط راجعنا تسجيل GOEIC بتاعه.",
        "browse_filter_kind": "النوع",
        "browse_filter_governorate": "المحافظة",
        "browse_filter_city": "المدينة",
        "browse_filter_type": "التصنيف",
        "browse_filter_bedrooms": "الغرف",
        "browse_filter_price": "السعر (جنيه)",
        "browse_filter_all": "الكل",
        "browse_filter_any": "أي",
        "browse_filter_anywhere": "أي مكان",
        "browse_filter_apply": "تطبيق",
        "browse_filter_reset": "مسح",
        "browse_filter_price_min": "الحد الأدنى",
        "browse_filter_price_max": "الحد الأعلى",
        "browse_bedrooms_5plus": "+5",
        "browse_bedrooms_n_plus": "+{n}",
        "browse_empty": "مفيش إعلانات مطابقة للفلاتر.",
        "browse_empty_reset": "امسح",
        "browse_empty_suffix": "عشان تشوف كل حاجة.",

        # kind + property_type
        "kind_sale": "للبيع",
        "kind_rent": "للإيجار",
        "kind_sale_short": "بيع",
        "kind_rent_short": "إيجار",
        "ptype_apartment": "شقة",
        "ptype_villa": "فيلا",
        "ptype_house": "بيت",
        "ptype_land": "أرض",
        "ptype_commercial": "تجاري",
        "ptype_apartment_plural": "شقق",
        "ptype_villa_plural": "فيلات",
        "ptype_house_plural": "بيوت",
        "ptype_land_plural": "أراضي",
        "ptype_commercial_plural": "عقارات تجارية",

        # ── _partials/listing_card.html ─────────────────────────
        "card_bed": "غرفة",
        "card_bath": "حمام",
        "card_currency_egp": "جنيه",
        "card_per_month": " / شهر",

        # ── landing.html ────────────────────────────────────────
        "landing_facet_all": "الكل",
        "landing_facet_any": "أي",
        "landing_more_filters": "فلاتر إضافية ←",
        "landing_related_title": "شائع أيضًا في {gov}",
        "landing_related_listing_singular": "إعلان {n}",
        "landing_related_listing_plural": "{n} إعلان",
        "landing_breadcrumb_home": "الرئيسية",
        "landing_breadcrumb_browse": "تصفح",
        "landing_intro_template": "تصفح {count} إعلان {facet} موثّق في {subject}. كل وسيط على وسيط مسجّل في الهيئة العامة للرقابة على الصادرات والواردات (GOEIC) — تقدر تتواصل معاه مباشرة بدون وسطاء.",
        "landing_intro_default_facet": "عقاري",
        "landing_h1_property_in": "عقارات في {subject}",
        "landing_h1_facet_in": "{facet} في {subject}",
        "landing_title_property_in": "عقارات في {subject} | وسيط",
        "landing_title_facet_in": "{facet} في {subject} | وسيط",
        "landing_title_kind_in": "عقارات {kind} في {subject} | وسيط",

        # ── listing.html ─────────────────────────────────────────
        "listing_copy_link": "نسخ اللينك",
        "listing_copy_link_done": "تم النسخ ✓",
        "listing_share_whatsapp_aria": "شارك على واتساب",
        "listing_share_whatsapp": "واتساب",
        "listing_shareable_url_aria": "لينك الإعلان القابل للمشاركة",
        "listing_fact_bed": "غرفة",
        "listing_fact_bath": "حمام",
        "listing_fact_floor": "الدور",
        "listing_fact_furnished": "مفروش",
        "listing_fact_unfurnished": "غير مفروش",
        "listing_delivery_ready": "جاهز للسكن",
        "listing_delivery_under_construction": "تحت الإنشاء",
        "listing_about_heading": "عن العقار",
        "listing_location_heading": "الموقع",
        "listing_map_of": "خريطة {city}",
        "listing_open_larger_map": "افتح خريطة أكبر ←",
        "listing_disclaimer_strong": "ملحوظة صريحة.",
        "listing_disclaimer_body": "المنصة بتساعد في التوثيق — مش بديل عن المحامي أو الشهر العقاري. تأكد دايمًا من الملكية في السجل العقاري قبل التوقيع.",
        "listing_verified_broker_fallback": "وسيط موثّق",
        "listing_verified_badge": "✓ موثّق",
        "listing_reviews_singular": "({n} تقييم)",
        "listing_reviews_plural": "({n} تقييم)",
        "listing_broker_note": "اتواصل مع الوسيط عن طريق التطبيق عشان تحتفظ بالرسائل والتقييمات والمستندات في مكان واحد.",
        "listing_open_in_app": "افتح في التطبيق",
        "listing_see_credentials": "شوف الشهادات العامة لـ {name} ←",
        "listing_broker_generic_name": "الوسيط",
        "listing_sticky_open_in_app": "افتح في التطبيق",

        # ── broker.html ──────────────────────────────────────────
        "broker_og_suffix": "وسيط موثّق",
        "broker_share_url_aria": "لينك الملف الشخصي القابل للمشاركة",
        "broker_copy_link": "نسخ اللينك",
        "broker_share_whatsapp": "واتساب",
        "broker_share_whatsapp_aria": "شارك على واتساب",
        "broker_seal_title_en": "VERIFIED BROKER",
        "broker_seal_since_prefix": "منذ",
        "broker_seal_aria_verified_broker": "وسيط موثّق",
        "broker_seal_aria_goeic": "GOEIC",
        "broker_seal_aria_verified_on": "تم التوثيق",
        "broker_metaline_country": "مصر",
        "broker_metaline_since": "وسيط منذ {year}",
        "broker_rating_line_from_singular": "من {count} تقييم",
        "broker_rating_line_from_plural": "من {count} تقييم",
        "broker_rating_aria": "التقييم {avg} من 5 من {count} تقييم",
        "broker_meta_goeic": "رقم GOEIC",
        "broker_meta_jurisdiction": "الاختصاص",
        "broker_meta_verified": "التوثيق",
        "broker_meta_valid_through": "ساري حتى",
        "broker_action_message": "راسل في التطبيق",
        "broker_action_copy_profile": "انسخ لينك الملف",
        "broker_at_a_glance_aria": "الوسيط في لمحة",
        "broker_stat_active_listings": "إعلانات شغالة",
        "broker_stat_reviews": "تقييمات",
        "broker_stat_avg_rating": "متوسط التقييم",
        "broker_stat_verified": "موثّق",
        "broker_stat_year_unit": "سنة",
        "broker_stat_less_than_1y": "أقل من سنة",
        "broker_section_active_listings": "إعلانات شغالة",
        "broker_section_browse_all": "تصفح الكل ←",
        "broker_section_recent_reviews": "أحدث التقييمات",
        "broker_review_stars_aria": "{n} من 5",
        "broker_mrz_head": "منطقة قابلة للقراءة آليًا · بيانات السجل",

        # ── legal_base.html ──────────────────────────────────────
        "legal_draft_banner": "مسودة — ليست استشارة قانونية. في انتظار مراجعة محامٍ مصري قبل الإطلاق.",
        "legal_last_updated": "آخر تحديث:",
        "legal_updated_date": "17 أغسطس 2026",

        # ── 404.html ─────────────────────────────────────────────
        "404_title": "غير موجود · وسيط",
        "404_meta_description": "الصفحة اللي بتدور عليها مش هنا.",
        "404_heading": "الصفحة دي مش متاحة",
        "404_body": "الإعلان أو ملف الوسيط اللي بتدور عليه ممكن يكون اتشال، اتباع، أو مش موثّق دلوقتي.",
        "404_cta_browse": "تصفح الإعلانات الموثّقة",
        "404_cta_home": "الرجوع للرئيسية",

        # ── جولة Stitch: الترويسة، أشرطة الرئيسية، شريط النتائج، البوابة القانونية ──
        "header_live_count": "{n} عقار موثّق معروض الآن",
        "footer_about_body": "وسيط منصة مصرية بنراجع فيها تسجيل كل وسيط في الهيئة العامة للرقابة على الصادرات والواردات قبل ما ينشر أي إعلان.",
        "footer_pill": "كل وسيط راجعه فريقنا",
        "footer_col_quick": "روابط سريعة",
        "footer_col_legal": "القانوني والامتثال",
        "footer_delete_account": "حذف حسابك",
        "footer_copyright": "© {year} وسيط. عقارات مصرية موثّقة.",
        "home_stat_listings_label": "عقار موثّق معروض الآن",
        "home_stat_verified_value": "١٠٠٪",
        "home_stat_verified_label": "من الإعلانات من وسيط راجعنا تسجيله في GOEIC",
        "home_stat_zero_value": "٠",
        "home_stat_zero_label": "إعلان من وسيط غير موثّق — النشر مقفول عليهم",
        "home_compliance_title": "التوثيق ده جاي منين بالظبط",
        "home_compliance_body": "ثلاث خطوات ملموسة، وحدودها بصراحة.",
        "home_compliance_c1_title": "تسجيل GOEIC",
        "home_compliance_c1_body": "الوسيط بيرفع مستند السجل التجاري، وفريقنا بيقراه بنفسه قبل ما الحساب يقدر ينشر أي إعلان.",
        "home_compliance_c2_title": "قانون حماية البيانات",
        "home_compliance_c2_body": "البيانات الشخصية بتتعامل تحت القانون 151 لسنة 2020، وكل وسيط بيسجّل موافقته وقت رفع المستندات.",
        "home_compliance_c3_title": "اللي مش بندّعيه",
        "home_compliance_c3_body": "إحنا مش الشهر العقاري. التوثيق معناه إن إنسان راجع الورق — راجع سند الملكية بنفسك قبل أي دفع.",
        "browse_results_count": "{n} عقار موثّق مطابق",
        "browse_results_shown": "معروض {shown}",
        "browse_sort_label": "الترتيب",
        "browse_sort_newest": "الأحدث أولاً",
        "browse_sort_oldest": "الأقدم أولاً",
        "browse_sort_price_asc": "السعر: من الأقل",
        "browse_sort_price_desc": "السعر: من الأعلى",
        "browse_sort_area_desc": "الأكبر مساحة",
        "card_verified_broker": "وسيط موثّق",
        "card_view_details": "عرض الإعلان",
        "legal_hub_title": "القانوني والامتثال",
        "legal_hub_body": "سياسة الخصوصية وشروط الاستخدام وطريقة حذف حسابك — مكتوبة وفق قانون حماية البيانات الشخصية المصري 151 لسنة 2020 وقواعد بيانات Google Play.",
        "legal_hub_pill": "مستند منشور",
        "legal_tab_privacy": "الخصوصية والبيانات",
        "legal_tab_terms": "شروط الاستخدام",
        "legal_tab_delete": "حذف الحساب",
        "legal_index_title": "في هذه الصفحة",
        "legal_dpo_title": "التواصل بشأن البيانات",
        "legal_dpo_body": "لأي استفسار عن بياناتك، أو لتقديم طلب بموجب قانون حماية البيانات، اكتب لنا وسنرد كتابةً.",
        "legal_dpo_email_label": "البريد",
        "legal_help_title": "محتاجها بسرعة؟",
        "legal_help_body": "حذف الحساب من داخل التطبيق فوري. طلبات البريد بتتنفذ خلال 7 أيام عمل.",
        "legal_help_cta": "تواصل معنا",
    },
}


# ── Access helpers ────────────────────────────────────────────────

def t(key: str, lang: str, **fmt) -> str:
    """Look up a translation key. Missing keys return the key itself
    (loud fallback — never silently show English when a key is missing
    from AR, since that would mask a translation bug). Any keyword
    arguments format the string via .format()."""
    table = TRANSLATIONS.get(lang, TRANSLATIONS[DEFAULT_LANG])
    text = table.get(key, key)
    if fmt:
        try:
            return text.format(**fmt)
        except (KeyError, IndexError):
            return text
    return text


def gov_display(gov_en: str, lang: str) -> str:
    """Return the localized governorate name. Falls back to the DB
    string if we don't have an AR translation for it."""
    if lang != "ar":
        return gov_en
    # Lazy import — avoids a cycle with `app/__init__.py` where the
    # context processor lives.
    from .geo.egypt import GOVERNORATES
    for g in GOVERNORATES:
        if g["en"] == gov_en:
            return g["ar"]
    return gov_en


def lang_from_request() -> str:
    """Read cookie/default. Called via before_request; the ?lang=
    URL param is handled by the /set-lang route so query strings
    don't leak into every cached URL."""
    cookie = request.cookies.get(LANG_COOKIE, "")
    if cookie in LANGUAGES:
        return cookie
    return DEFAULT_LANG


# ── Blueprint: /set-lang ─────────────────────────────────────────

lang_bp = Blueprint("lang", __name__)


def _safe_next(candidate: str) -> str:
    """Guard against open-redirect. Only relative URLs (start with '/'
    and don't schema-inject) are allowed."""
    if not candidate:
        return "/"
    # Reject anything that looks like a scheme or host.
    parsed = urlparse(candidate)
    if parsed.scheme or parsed.netloc:
        return "/"
    if not candidate.startswith("/"):
        return "/"
    # Reject protocol-relative // URLs.
    if candidate.startswith("//"):
        return "/"
    return candidate


@lang_bp.get("/set-lang")
def set_lang():
    lang = (request.args.get("lang") or "").lower()
    if lang not in LANGUAGES:
        return Response("invalid lang", status=400)
    next_url = _safe_next(request.args.get("next", "/"))
    resp = redirect(next_url, code=302)
    resp.set_cookie(
        LANG_COOKIE,
        lang,
        max_age=LANG_COOKIE_MAX_AGE,
        httponly=False,  # allow JS to read if we ever want a client-side toggle
        samesite="Lax",
    )
    return resp


def init_app(app) -> None:
    """Wire the before_request + context processor + register /set-lang."""

    @app.before_request
    def _set_lang():
        g.lang = lang_from_request()

    @app.context_processor
    def _inject_lang():
        lang = getattr(g, "lang", DEFAULT_LANG)
        # Bake `lang` into a partial so templates can write `t('key')`
        # without repeating the language on every call.
        def _t(key, **fmt):
            return t(key, lang, **fmt)
        return {
            "lang": lang,
            "dir": "rtl" if lang == "ar" else "ltr",
            "t": _t,
            "gov_display": lambda name: gov_display(name, lang),
        }

    app.register_blueprint(lang_bp)
