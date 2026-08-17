#!/usr/bin/env python3
"""Build Play Console listing graphics: feature graphic + 9:16 phone screenshots."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "store-listing"
CHOSEN = ROOT / "design-mockups" / "chosen"
FONTS = ROOT / "assets" / "fonts"
CORMORANT = FONTS / "CormorantGaramond-Variable.ttf"
GROTESK = FONTS / "SpaceGrotesk-Variable.ttf"

GOLD = (229, 193, 111, 255)
WHITE = (255, 255, 255, 255)
IVORY = (244, 239, 230, 255)
DARK = (14, 11, 26, 255)

PHONE_W, PHONE_H = 1080, 1920
FEATURE_W, FEATURE_H = 1024, 500


def _font(path: Path, size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(path), size)
    try:
        font.set_variation_by_name("Bold" if bold else "Regular")
    except Exception:
        pass
    return font


def _draw_centered_v(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    size = x1 - x0
    font = _font(CORMORANT, int(size * 0.55), bold=True)
    bbox = draw.textbbox((0, 0), "V", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = x0 + (size - tw) / 2 - bbox[0]
    y = y0 + (size - th) / 2 - bbox[1] + size * 0.012
    draw.text((x, y), "V", font=font, fill=WHITE)


def feature_graphic() -> Image.Image:
    hero = Image.open(ROOT / "assets" / "images" / "auth_hero.jpg").convert("RGB")
    # Cover-crop to 1024x500
    scale = max(FEATURE_W / hero.width, FEATURE_H / hero.height)
    hero = hero.resize((int(hero.width * scale), int(hero.height * scale)), Image.Resampling.LANCZOS)
    left = (hero.width - FEATURE_W) // 2
    top = max(0, (hero.height - FEATURE_H) // 3)
    hero = hero.crop((left, top, left + FEATURE_W, top + FEATURE_H))
    hero = hero.filter(ImageFilter.GaussianBlur(radius=1.2))

    overlay = Image.new("RGBA", (FEATURE_W, FEATURE_H), (14, 11, 26, 132))
    img = Image.alpha_composite(hero.convert("RGBA"), overlay)
    draw = ImageDraw.Draw(img)

    # Gold mark
    mark = 196
    mx, my = 72, (FEATURE_H - mark) // 2
    draw.ellipse((mx, my, mx + mark, my + mark), fill=GOLD)
    _draw_centered_v(draw, (mx, my, mx + mark, my + mark))

    title = _font(CORMORANT, 72, bold=True)
    tag = _font(GROTESK, 22, bold=True)
    sub = _font(GROTESK, 20, bold=False)
    tx = mx + mark + 40
    draw.text((tx, 148), "FIRSTVUE", font=title, fill=GOLD)
    draw.text((tx, 238), "SEE FIRST. BOOK FIRST.", font=tag, fill=WHITE)
    draw.text(
        (tx, 286),
        "Discover local beauty & service pros.",
        font=sub,
        fill=(244, 239, 230, 230),
    )
    return img.convert("RGB")


def phone_screenshot(src: Path) -> Image.Image:
    shot = Image.open(src).convert("RGB")
    canvas = Image.new("RGB", (PHONE_W, PHONE_H), IVORY[:3])
    # Scale to full width, keep aspect, center vertically.
    scale = PHONE_W / shot.width
    nw, nh = PHONE_W, int(shot.height * scale)
    if nh > PHONE_H:
        scale = PHONE_H / shot.height
        nw, nh = int(shot.width * scale), PHONE_H
    shot = shot.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (PHONE_W - nw) // 2
    y = (PHONE_H - nh) // 2
    canvas.paste(shot, (x, y))
    return canvas


def main() -> None:
    LISTING.mkdir(exist_ok=True)
    phones_dir = LISTING / "phone-screenshots"
    phones_dir.mkdir(exist_ok=True)

    feature = feature_graphic()
    feature.save(LISTING / "feature-graphic-1024x500.png", "PNG", optimize=True)

    shots = [
        ("01-vue.png", CHOSEN / "03-vue-grid.png"),
        ("02-explore.png", CHOSEN / "01-explore-social-grid.png"),
        ("03-business.png", CHOSEN / "06-entity-business-profile.png"),
        ("04-profile.png", CHOSEN / "04-profile.png"),
    ]
    for name, src in shots:
        phone_screenshot(src).save(phones_dir / name, "PNG", optimize=True)
        print("wrote", name)

    print("Wrote feature graphic and 4 phone screenshots")


if __name__ == "__main__":
    main()
