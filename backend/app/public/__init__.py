"""Public web view — server-rendered HTML pages + unauthenticated JSON.

Purpose: SEO. Google/Bing crawlers don't index Flutter's CanvasKit SPA
reliably, so we serve dedicated HTML pages with per-URL <title>, meta
description, OpenGraph and JSON-LD schema for every active listing.
The mobile app keeps its own JWT-gated /listings API untouched.
"""
