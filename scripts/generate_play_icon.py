#!/usr/bin/env python3
"""Generate FirstVue Play listing + Android launcher icons from the VUE-tab V."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_PATH = ROOT / "assets" / "fonts" / "CormorantGaramond-Variable.ttf"
GOLD = (229, 193, 111, 255)  # FirstVueColors.gold #E5C16F
WHITE = (255, 255, 255, 255)

# Vue tab: 32px V on a 58px gold circle (~0.55 of the mark).
V_SIZE_RATIO = 0.55


def _cormorant_bold(size: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(FONT_PATH), size)
    font.set_variation_by_name("Bold")
    return font


def _draw_v(draw: ImageDraw.ImageDraw, canvas: int, font_px: int) -> None:
    font = _cormorant_bold(font_px)
    bbox = draw.textbbox((0, 0), "V", font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    # Optical nudge: serif V sits slightly high if purely bbox-centered.
    x = (canvas - w) / 2 - bbox[0]
    y = (canvas - h) / 2 - bbox[1] + canvas * 0.012
    draw.text((x, y), "V", font=font, fill=WHITE)


def gold_square(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), GOLD)
    draw = ImageDraw.Draw(img)
    _draw_v(draw, size, int(size * V_SIZE_RATIO))
    return img


def gold_circle_on_transparent(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse((0, 0, size - 1, size - 1), fill=GOLD)
    _draw_v(draw, size, int(size * V_SIZE_RATIO))
    return img


def adaptive_foreground(size: int) -> Image.Image:
    """White V on transparent; Android safe zone is the inner 66%."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    _draw_v(draw, size, int(size * 0.42))
    return img


def main() -> None:
    listing = ROOT / "store-listing"
    listing.mkdir(exist_ok=True)
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"

    play = gold_square(512)
    play.save(listing / "play-icon-512.png", "PNG", optimize=True)

    circle = gold_circle_on_transparent(1024)
    circle.save(listing / "vue-v-circle-1024.png", "PNG", optimize=True)

    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        dest = android_res / folder
        dest.mkdir(parents=True, exist_ok=True)
        gold_square(size).save(dest / "ic_launcher.png", "PNG", optimize=True)
        adaptive_foreground(size).save(
            dest / "ic_launcher_foreground.png", "PNG", optimize=True
        )

    print("Wrote Play icon 512 and Android launcher mipmaps")


if __name__ == "__main__":
    main()
