#!/usr/bin/env python3
"""Dark-theme 16:9 tablet screenshots for Play Console (unique vs phone shots)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "store-listing"
IMG = ROOT / "assets" / "images"
CORMORANT = ROOT / "assets" / "fonts" / "CormorantGaramond-Variable.ttf"
GROTESK = ROOT / "assets" / "fonts" / "SpaceGrotesk-Variable.ttf"

# Play Console: 16:9. 7-inch sides 320–3840; 10-inch both sides ≥1080.
SIZE_7 = (1280, 720)
SIZE_10 = (1920, 1080)

BG = (14, 11, 26, 255)
SURFACE = (22, 18, 34, 255)
ELEVATED = (28, 24, 41, 255)
GOLD = (229, 193, 111, 255)
TEAL = (61, 217, 201, 255)
IVORY = (244, 239, 230, 255)
MUTED = (138, 144, 153, 255)
WHITE = (255, 255, 255, 255)


def font(path: Path, size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_name("Bold" if bold else "Regular")
    except Exception:
        pass
    return f


def cover(path: Path, w: int, h: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    scale = max(w / im.width, h / im.height)
    im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.Resampling.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def rounded(im: Image.Image, radius: int) -> Image.Image:
    im = im.convert("RGBA")
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=radius, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, mask=mask)
    return out


def draw_v(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    size = x1 - x0
    fnt = font(CORMORANT, int(size * 0.55), True)
    bbox = draw.textbbox((0, 0), "V", font=fnt)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        (x0 + (size - tw) / 2 - bbox[0], y0 + (size - th) / 2 - bbox[1] + size * 0.012),
        "V",
        font=fnt,
        fill=WHITE,
    )


def nav(canvas: Image.Image, w: int, h: int, selected: str) -> None:
    draw = ImageDraw.Draw(canvas)
    bar_h = int(h * 0.12)
    y = h - bar_h
    draw.rectangle((0, y, w, h), fill=BG)
    draw.line((0, y, w, y), fill=(244, 239, 230, 34), width=1)
    labels = ["HOME", "FEEDS", "VUE", "EXPLORE", "PROFILE"]
    slot = w / 5
    fnt = font(GROTESK, max(11, int(h * 0.022)), True)
    for i, label in enumerate(labels):
        cx = int(slot * (i + 0.5))
        active = label == selected
        color = GOLD if active else MUTED
        if label == "VUE":
            d = int(bar_h * 0.62)
            x0, y0 = cx - d // 2, y + 8
            draw.ellipse((x0, y0, x0 + d, y0 + d), fill=GOLD)
            draw_v(draw, (x0, y0, x0 + d, y0 + d))
            draw.text((cx, y0 + d + 2), "VUE", font=fnt, fill=GOLD if selected == "VUE" else MUTED, anchor="mt")
        else:
            draw.text((cx, y + int(bar_h * 0.38)), label, font=fnt, fill=color, anchor="mm")


def chip(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, *, filled: bool, scale: float) -> int:
    fnt = font(GROTESK, max(12, int(14 * scale)), True)
    pad_x, pad_y = int(14 * scale), int(8 * scale)
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = xy
    w, h = tw + pad_x * 2, th + pad_y * 2
    if filled:
        draw.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=GOLD)
        draw.text((x + pad_x - bbox[0], y + pad_y - bbox[1]), text, font=fnt, fill=BG)
    else:
        draw.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, outline=(244, 239, 230, 50), width=2)
        draw.text((x + pad_x - bbox[0], y + pad_y - bbox[1]), text, font=fnt, fill=IVORY)
    return w + int(10 * scale)


def home_7() -> Image.Image:
    w, h = SIZE_7
    s = w / 1280
    canvas = Image.new("RGBA", (w, h), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((int(28 * s), int(22 * s)), "FIRSTVUE", font=font(CORMORANT, int(36 * s), True), fill=GOLD)
    draw.text((int(28 * s), int(62 * s)), "SEE FIRST. BOOK FIRST.", font=font(GROTESK, int(14 * s), True), fill=IVORY)
    draw.text((w - int(28 * s), int(40 * s)), "Atlanta  ·  2.1 mi", font=font(GROTESK, int(14 * s), True), fill=TEAL, anchor="rm")

    draw.rounded_rectangle((int(28 * s), int(92 * s), w - int(28 * s), int(136 * s)), radius=18, fill=ELEVATED)
    draw.text((int(52 * s), int(114 * s)), "Search people, places, or services", font=font(GROTESK, int(16 * s)), fill=MUTED, anchor="lm")

    x = int(28 * s)
    y = int(152 * s)
    for label, filled in (("Trending", True), ("Events", False), ("Nearby", False)):
        x += chip(draw, (x, y), label, filled=filled, scale=s)

    # Two content cards
    card_y, card_h = int(210 * s), int(h * 0.52)
    gap = int(18 * s)
    left_w = int(w * 0.58)
    salon = rounded(cover(IMG / "explore_salons.jpg", left_w - int(28 * s) * 2 + int(28 * s), card_h - int(70 * s)), 16)
    canvas.alpha_composite(salon, (int(28 * s), card_y))
    draw.rounded_rectangle((int(28 * s), card_y + card_h - int(64 * s), int(28 * s) + salon.width, card_y + card_h), radius=12, fill=SURFACE)
    draw.text((int(44 * s), card_y + card_h - int(44 * s)), "Velvet Room Salon  ·  Saturday silk press", font=font(GROTESK, int(15 * s), True), fill=IVORY, anchor="lm")

    rx = int(28 * s) + salon.width + gap
    rw = w - rx - int(28 * s)
    event = rounded(cover(IMG / "explore_things_to_do.jpg", rw, int(card_h * 0.62)), 16)
    canvas.alpha_composite(event, (rx, card_y))
    draw.rounded_rectangle((rx, card_y + event.height - int(8 * s), rx + rw, card_y + card_h), radius=12, fill=ELEVATED)
    draw.text((rx + int(16 * s), card_y + event.height + int(18 * s)), "Summer Nights  ·  Piedmont Park", font=font(GROTESK, int(14 * s), True), fill=TEAL)
    draw.text((rx + int(16 * s), card_y + event.height + int(42 * s)), "Tonight 7:00 PM", font=font(GROTESK, int(13 * s)), fill=MUTED)

    nav(canvas, w, h, "HOME")
    return canvas.convert("RGB")


def feeds_7() -> Image.Image:
    w, h = SIZE_7
    s = w / 1280
    canvas = Image.new("RGBA", (w, h), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((int(28 * s), int(24 * s)), "FEEDS", font=font(CORMORANT, int(36 * s), True), fill=GOLD)
    draw.text((int(28 * s), int(64 * s)), "Communities, groups, and local posts", font=font(GROTESK, int(14 * s)), fill=MUTED)

    x = int(28 * s)
    for name, photo in (
        ("CurlFest", "explore_beauty.jpg"),
        ("Table 45", "explore_restaurants.jpg"),
        ("StayVue", "explore_rentals.jpg"),
        ("ATL Park", "explore_things_to_do.jpg"),
    ):
        av = rounded(cover(IMG / photo, int(72 * s), int(72 * s)), int(36 * s))
        canvas.alpha_composite(av, (x, int(96 * s)))
        draw.text((x + int(36 * s), int(176 * s)), name, font=font(GROTESK, int(12 * s), True), fill=IVORY, anchor="mt")
        x += int(96 * s)

    card_y = int(200 * s)
    card_h = int(h * 0.48)
    gap = int(16 * s)
    cw = (w - int(28 * s) * 2 - gap) // 2
    for i, (photo, title, sub) in enumerate(
        (
            ("explore_beauty.jpg", "Wash day done right", "#NaturalHairCare  ·  56 likes"),
            ("explore_restaurants.jpg", "Chef’s tasting tonight", "Table 45  ·  Midtown  ·  0.8 mi"),
        )
    ):
        px = int(28 * s) + i * (cw + gap)
        shot = rounded(cover(IMG / photo, cw, card_h - int(56 * s)), 16)
        canvas.alpha_composite(shot, (px, card_y))
        draw.rounded_rectangle((px, card_y + shot.height - 4, px + cw, card_y + card_h), radius=12, fill=SURFACE)
        draw.text((px + int(14 * s), card_y + card_h - int(36 * s)), title, font=font(GROTESK, int(14 * s), True), fill=IVORY, anchor="lm")
        draw.text((px + int(14 * s), card_y + card_h - int(16 * s)), sub, font=font(GROTESK, int(12 * s)), fill=MUTED, anchor="lm")

    nav(canvas, w, h, "FEEDS")
    return canvas.convert("RGB")


def community_10() -> Image.Image:
    w, h = SIZE_10
    s = w / 1920
    canvas = Image.new("RGBA", (w, h), BG)
    draw = ImageDraw.Draw(canvas)

    cover_h = int(h * 0.42)
    hero = cover(IMG / "explore_beauty.jpg", w, cover_h)
    canvas.paste(hero, (0, 0))
    overlay = Image.new("RGBA", (w, cover_h), (14, 11, 26, 90))
    canvas.alpha_composite(overlay, (0, 0))

    av = rounded(cover(IMG / "explore_stylists.jpg", int(120 * s), int(120 * s)), int(60 * s))
    canvas.alpha_composite(av, (int(40 * s), cover_h - int(70 * s)))
    draw.text((int(180 * s), cover_h - int(48 * s)), "Natural Hair ATL", font=font(CORMORANT, int(40 * s), True), fill=IVORY)
    draw.text((int(180 * s), cover_h - int(10 * s)), "Community hub  ·  Atlanta  ·  1.8k members", font=font(GROTESK, int(16 * s)), fill=TEAL)

    y = cover_h + int(28 * s)
    draw.rounded_rectangle((int(40 * s), y, int(200 * s), y + int(44 * s)), radius=12, fill=GOLD)
    draw.text((int(120 * s), y + int(22 * s)), "Join", font=font(GROTESK, int(16 * s), True), fill=BG, anchor="mm")
    draw.rounded_rectangle((int(216 * s), y, int(376 * s), y + int(44 * s)), radius=12, outline=GOLD, width=2)
    draw.text((int(296 * s), y + int(22 * s)), "Share", font=font(GROTESK, int(16 * s), True), fill=GOLD, anchor="mm")
    draw.text((int(420 * s), y + int(22 * s)), "FEED   GROUPS   MEMBERS   MEDIA", font=font(GROTESK, int(15 * s), True), fill=MUTED, anchor="lm")

    post_y = y + int(70 * s)
    # Two posts side by side
    gap = int(20 * s)
    pw = (w - int(40 * s) * 2 - gap) // 2
    ph = int(h * 0.28)
    for i, (photo, title, meta) in enumerate(
        (
            ("explore_beauty.jpg", "CurlFest pop-up this Saturday", "56 likes  ·  8 comments"),
            ("explore_stylists.jpg", "Locs Circle meetup  ·  East Point", "12 going  ·  2.4 mi"),
        )
    ):
        px = int(40 * s) + i * (pw + gap)
        draw.rounded_rectangle((px, post_y, px + pw, post_y + ph), radius=16, fill=SURFACE)
        thumb = rounded(cover(IMG / photo, int(ph - 24 * s), int(ph - 24 * s)), 12)
        canvas.alpha_composite(thumb, (px + int(12 * s), post_y + int(12 * s)))
        tx = px + thumb.width + int(28 * s)
        draw.text((tx, post_y + int(36 * s)), title, font=font(GROTESK, int(20 * s), True), fill=IVORY)
        draw.text((tx, post_y + int(72 * s)), meta, font=font(GROTESK, int(15 * s)), fill=MUTED)

    nav(canvas, w, h, "EXPLORE")
    return canvas.convert("RGB")


def professional_10() -> Image.Image:
    w, h = SIZE_10
    s = w / 1920
    canvas = Image.new("RGBA", (w, h), BG)
    draw = ImageDraw.Draw(canvas)

    left_w = int(w * 0.46)
    hero = cover(IMG / "explore_barbers.jpg", left_w, h - int(h * 0.12))
    canvas.paste(hero, (0, 0))
    shade = Image.new("RGBA", (left_w, h), (14, 11, 26, 70))
    canvas.alpha_composite(shade, (0, 0))

    av = rounded(cover(IMG / "explore_barbers.jpg", int(108 * s), int(108 * s)), int(54 * s))
    canvas.alpha_composite(av, (left_w + int(36 * s), int(36 * s)))
    draw.text((left_w + int(160 * s), int(52 * s)), "Marcus Reed", font=font(CORMORANT, int(42 * s), True), fill=IVORY)
    draw.text((left_w + int(160 * s), int(102 * s)), "Verified barber  ·  @marcusfade  ·  1.6 mi", font=font(GROTESK, int(16 * s)), fill=TEAL)
    draw.text((left_w + int(36 * s), int(168 * s)), "128 posts     2.1k followers     4.9 ★", font=font(GROTESK, int(16 * s), True), fill=MUTED)

    y = int(214 * s)
    draw.rounded_rectangle((left_w + int(36 * s), y, left_w + int(196 * s), y + int(44 * s)), radius=12, fill=GOLD)
    draw.text((left_w + int(116 * s), y + int(22 * s)), "Follow", font=font(GROTESK, int(16 * s), True), fill=BG, anchor="mm")
    draw.rounded_rectangle((left_w + int(212 * s), y, left_w + int(372 * s), y + int(44 * s)), radius=12, outline=GOLD, width=2)
    draw.text((left_w + int(292 * s), y + int(22 * s)), "Message", font=font(GROTESK, int(16 * s), True), fill=GOLD, anchor="mm")
    draw.rounded_rectangle((left_w + int(388 * s), y, left_w + int(548 * s), y + int(44 * s)), radius=12, fill=GOLD)
    draw.text((left_w + int(468 * s), y + int(22 * s)), "Book", font=font(GROTESK, int(16 * s), True), fill=BG, anchor="mm")

    draw.text((left_w + int(36 * s), int(286 * s)), "SERVICES", font=font(GROTESK, int(14 * s), True), fill=GOLD)
    services = [("Skin fade", "$45"), ("Beard work", "$25"), ("Designs", "$60")]
    sx = left_w + int(36 * s)
    for name, price in services:
        draw.rounded_rectangle((sx, int(318 * s), sx + int(170 * s), int(400 * s)), radius=14, fill=ELEVATED)
        draw.text((sx + int(16 * s), int(338 * s)), name, font=font(GROTESK, int(15 * s), True), fill=IVORY)
        draw.text((sx + int(16 * s), int(368 * s)), price, font=font(GROTESK, int(18 * s), True), fill=GOLD)
        sx += int(186 * s)

    draw.text((left_w + int(36 * s), int(428 * s)), "PORTFOLIO", font=font(GROTESK, int(14 * s), True), fill=GOLD)
    thumbs = ["explore_barbers.jpg", "explore_stylists.jpg", "explore_beauty.jpg", "explore_salons.jpg"]
    tw = int(150 * s)
    tx = left_w + int(36 * s)
    for photo in thumbs:
        t = rounded(cover(IMG / photo, tw, tw), 12)
        canvas.alpha_composite(t, (tx, int(458 * s)))
        tx += tw + int(12 * s)

    nav(canvas, w, h, "PROFILE")
    return canvas.convert("RGB")


def main() -> None:
    d7 = LISTING / "tablet-7inch"
    d10 = LISTING / "tablet-10inch"
    d7.mkdir(parents=True, exist_ok=True)
    d10.mkdir(parents=True, exist_ok=True)
    for old in list(d7.glob("*.png")) + list(d10.glob("*.png")):
        old.unlink()

    home_7().save(d7 / "01-home-dark.png", "PNG", optimize=True)
    feeds_7().save(d7 / "02-feeds-dark.png", "PNG", optimize=True)
    community_10().save(d10 / "01-community-dark.png", "PNG", optimize=True)
    professional_10().save(d10 / "02-professional-dark.png", "PNG", optimize=True)

    for p in sorted(d7.glob("*.png")) + sorted(d10.glob("*.png")):
        im = Image.open(p)
        print(p.parent.name, p.name, im.size, f"{p.stat().st_size / 1024:.0f}KB")


if __name__ == "__main__":
    main()
