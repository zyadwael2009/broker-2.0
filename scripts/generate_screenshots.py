#!/usr/bin/env python
"""Generate Play Store + App Store screenshots via Playwright.

Reads a running Wasit backend + Flutter Web build. Captures each key
page in each store's device size. Output lands in
`docs/screenshots/<device>/<page>.png` ready to upload directly to
Play Console / App Store Connect.

Prerequisites (one time, ~400MB Chromium download):
    pip install -r scripts/screenshots-requirements.txt
    playwright install chromium

Usage:
    # Boot the backend first (see README 'Flutter Web deployment'), then:
    python scripts/generate_screenshots.py
    python scripts/generate_screenshots.py --device phone-play
    python scripts/generate_screenshots.py --page listing
    python scripts/generate_screenshots.py --headed  # show browser

Environment:
    SCREENSHOT_BASE_URL         default http://localhost:5250
    SCREENSHOT_BROKER_PHONE     default +201555000201 (Youssef Broker)
    SCREENSHOT_BROKER_PASSWORD  default demopass
    SCREENSHOT_BUYER_PHONE      default +201555000101 (Aya Buyer)
    SCREENSHOT_BUYER_PASSWORD   default demopass
    SCREENSHOT_ADMIN_PHONE      default +201000000000 (Demo Admin)
    SCREENSHOT_ADMIN_PASSWORD   default demoadmin
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path


# ── device presets ────────────────────────────────────────────────────
# Sizes are per each store's guidelines:
# - Play Store phone: 320-3840px shorter side. 1080x1920 is safe.
# - Play Store 7" tablet: 1280x800 (landscape) or 800x1280 (portrait).
# - App Store iPhone 6.7": 1290x2796 required for new submissions.
# - App Store iPad Pro 13": 2064x2752 required for new submissions.
DEVICES = {
    "phone-play":  {"width": 1080, "height": 1920, "deviceScaleFactor": 2},
    "phone-ios":   {"width": 1290, "height": 2796, "deviceScaleFactor": 3},
    "tablet-play": {"width": 1280, "height": 800,  "deviceScaleFactor": 2},
    "tablet-ipad": {"width": 2064, "height": 2752, "deviceScaleFactor": 2},
}


# ── shot list ────────────────────────────────────────────────────────
# name → (url_path, credentials_role_or_None)
# credentials_role can be None (public), 'broker', 'buyer', 'admin'.
SHOTS = [
    ("home",         "/",                                        None),
    ("for-brokers",  "/for-brokers",                             None),
    ("browse-cairo", "/browse?kind=rent&governorate=Cairo",      None),
    ("listing",      "/l/2",                                     None),
    ("broker",       "/b/5",                                     None),
    # Flutter Web app pages — require login.
    ("app-broker",   "/app/#/broker/listings",                   "broker"),
    ("app-messages", "/app/#/messages",                          "buyer"),
    ("app-admin",    "/app/#/admin/queue",                       "admin"),
]


def _creds(role: str) -> tuple[str, str]:
    """Read (phone, password) for a role from env or fall back to
    seed-demo defaults."""
    defaults = {
        "broker": ("+201555000201", "demopass"),
        "buyer":  ("+201555000101", "demopass"),
        "admin":  ("+201000000000", "demoadmin"),
    }
    phone_default, pass_default = defaults[role]
    return (
        os.environ.get(f"SCREENSHOT_{role.upper()}_PHONE", phone_default),
        os.environ.get(f"SCREENSHOT_{role.upper()}_PASSWORD", pass_default),
    )


def _output_dir() -> Path:
    """`docs/screenshots/` at the repo root."""
    return (Path(__file__).parent.parent / "docs" / "screenshots").resolve()


async def _login(page, base_url: str, role: str) -> None:
    """Fill the /app/#/login form and wait for the post-login redirect.

    Uses intl_phone_field's stripped format — enter the local part
    (10 digits after +20) not the E.164 prefix.
    """
    phone, password = _creds(role)
    # Strip the +20 country code — the phone field prefixes it.
    local_part = phone.replace("+20", "").lstrip("0")

    await page.goto(f"{base_url}/app/#/login", wait_until="networkidle")
    # Wait for Flutter to boot — the boot splash is removed when
    # <flutter-view> appears; login form is inside.
    await page.wait_for_selector("input[type=tel], input[inputmode=numeric]",
                                 timeout=20_000)

    # Phone (intl_phone_field renders as tel/numeric input)
    phone_input = page.locator("input[type=tel], input[inputmode=numeric]").first
    await phone_input.click()
    await phone_input.fill(local_part)

    # Password (obscured text field)
    pw_input = page.locator("input[type=password]").first
    await pw_input.click()
    await pw_input.fill(password)

    # Submit — Flutter renders FilledButton as a semantic button.
    submit = page.get_by_role("button", name="Sign in", exact=False).first
    await submit.click()

    # Wait for the URL fragment to change away from /login.
    await page.wait_for_function(
        "() => !location.hash.includes('/login')",
        timeout=15_000,
    )
    # Give the destination screen a moment to paint.
    await page.wait_for_load_state("networkidle")


async def _capture_one(context, base_url: str, device_name: str,
                        page_name: str, url_path: str, role: str | None,
                        out_dir: Path) -> None:
    page = await context.new_page()
    try:
        if role is not None:
            await _login(page, base_url, role)
            # Navigate to the specific in-app URL after logging in.
            await page.goto(f"{base_url}{url_path}", wait_until="networkidle")
        else:
            await page.goto(f"{base_url}{url_path}", wait_until="networkidle")

        # Small extra delay for any late-loading images (OpenStreetMap
        # tiles, listing photos).
        await page.wait_for_timeout(1500)

        target = out_dir / device_name / f"{page_name}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        await page.screenshot(path=str(target), full_page=False)
        print(f"  ✓ {device_name}/{page_name}.png")
    except Exception as exc:
        print(f"  ✗ {device_name}/{page_name}.png — {exc}", file=sys.stderr)
    finally:
        await page.close()


async def _run(args) -> None:
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print(
            "Playwright is not installed. Run:\n"
            "    pip install -r scripts/screenshots-requirements.txt\n"
            "    playwright install chromium",
            file=sys.stderr,
        )
        sys.exit(1)

    base_url = os.environ.get("SCREENSHOT_BASE_URL", "http://localhost:5250").rstrip("/")
    out_dir = _output_dir()

    devices = ({args.device: DEVICES[args.device]} if args.device
               else DEVICES)
    shots = ([s for s in SHOTS if s[0] == args.page] if args.page
             else SHOTS)
    if args.page and not shots:
        print(f"Unknown page: {args.page!r}. Known: {[s[0] for s in SHOTS]}",
              file=sys.stderr)
        sys.exit(2)
    if args.device and args.device not in DEVICES:
        print(f"Unknown device: {args.device!r}. Known: {list(DEVICES)}",
              file=sys.stderr)
        sys.exit(2)

    print(f"base_url={base_url}")
    print(f"output={out_dir}")
    print(f"devices={list(devices)}")
    print(f"pages={[s[0] for s in shots]}\n")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=not args.headed)
        try:
            for device_name, viewport in devices.items():
                print(f"[{device_name}]")
                context = await browser.new_context(
                    viewport={"width": viewport["width"],
                              "height": viewport["height"]},
                    device_scale_factor=viewport["deviceScaleFactor"],
                )
                for page_name, url_path, role in shots:
                    await _capture_one(context, base_url, device_name,
                                       page_name, url_path, role, out_dir)
                await context.close()
        finally:
            await browser.close()

    print(f"\nDone. Screenshots in {out_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate app-store screenshots")
    parser.add_argument("--device", help=f"one of {list(DEVICES)}; default: all")
    parser.add_argument("--page", help=f"one of {[s[0] for s in SHOTS]}; default: all")
    parser.add_argument("--headed", action="store_true",
                        help="show the browser (useful for debugging)")
    args = parser.parse_args()
    asyncio.run(_run(args))


if __name__ == "__main__":
    main()
