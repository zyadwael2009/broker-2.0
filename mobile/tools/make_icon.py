"""Generate the app icon + splash source PNG from primitives.

Kept as a script (not a manual asset) so anyone can tweak the palette
and regenerate. Requires Pillow — available in the backend venv.

Run:  python mobile/tools/make_icon.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

# Palette lifted from mobile/lib/theme.dart:AppColors.light.
PRIMARY = (11, 124, 168)       # #0B7CA8 Nile teal
VERIFIED = (14, 159, 110)      # #0E9F6E emerald
WHITE = (255, 255, 255)


def make_icon(size: int = 1024) -> Image.Image:
    """Solid primary background with a white house silhouette and a
    verified check on the roof."""
    img = Image.new("RGBA", (size, size), PRIMARY + (255,))
    d = ImageDraw.Draw(img)

    cx = size // 2
    # House body — a simple pentagon.
    body_w = int(size * 0.56)
    body_h = int(size * 0.34)
    body_top = int(size * 0.44)
    body_left = cx - body_w // 2
    body_right = cx + body_w // 2
    body_bottom = body_top + body_h

    roof_peak_y = int(size * 0.24)
    house = [
        (body_left, body_bottom),
        (body_left, body_top),
        (cx, roof_peak_y),
        (body_right, body_top),
        (body_right, body_bottom),
    ]
    d.polygon(house, fill=WHITE)

    # Verified check disc — bottom-right corner, sitting slightly outside
    # the house so it reads as a badge, not a decoration.
    disc_r = int(size * 0.14)
    disc_cx = int(size * 0.72)
    disc_cy = int(size * 0.70)
    d.ellipse(
        (disc_cx - disc_r, disc_cy - disc_r, disc_cx + disc_r, disc_cy + disc_r),
        fill=VERIFIED,
    )
    # Check mark inside the disc.
    check = [
        (disc_cx - disc_r * 0.45, disc_cy),
        (disc_cx - disc_r * 0.1,  disc_cy + disc_r * 0.35),
        (disc_cx + disc_r * 0.5,  disc_cy - disc_r * 0.35),
    ]
    d.line(check, fill=WHITE, width=max(6, size // 60))

    return img


def make_splash(size: int = 1024) -> Image.Image:
    """Splash uses the same silhouette but on a transparent background —
    flutter_native_splash paints the primary as the ground."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx = size // 2
    body_w = int(size * 0.42)
    body_h = int(size * 0.26)
    body_top = int(size * 0.48)
    body_left = cx - body_w // 2
    body_right = cx + body_w // 2
    body_bottom = body_top + body_h

    roof_peak_y = int(size * 0.32)
    d.polygon(
        [
            (body_left, body_bottom),
            (body_left, body_top),
            (cx, roof_peak_y),
            (body_right, body_top),
            (body_right, body_bottom),
        ],
        fill=WHITE,
    )
    return img


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    make_icon().save(out / "app_icon.png")
    make_splash().save(out / "splash_logo.png")
    print(f"wrote {out}/app_icon.png and splash_logo.png")


if __name__ == "__main__":
    main()
