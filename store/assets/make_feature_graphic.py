#!/usr/bin/env python3
"""Generate the Google Play feature graphic (1024x500) for KoruBeni.

DRAFT asset. Brand identity is taken from the app, not invented:
  - Palette: lib/core/app_colors.dart (deep navy + cyan/teal "Noonlight" theme)
  - Icon:    store/assets/play_icon_512.png (metallic shield wordmark)
  - Tagline: "Kişisel Güvenlik" - the official app subtitle from the Play
             listing title (store/play_store_listing_tr.md). No promo words
             (no price / "ucretsiz" / "yeni" / "#1") per Play policy.

Output: store/assets/feature_graphic_1024x500.png
  - exactly 1024x500, 24-bit RGB, NO alpha channel (Play forbids transparency)

Re-run:  python3 store/assets/make_feature_graphic.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1024, 500
HERE = Path(__file__).resolve().parent
ICON_PATH = HERE / "play_icon_512.png"
OUT_PATH = HERE / "feature_graphic_1024x500.png"

# --- Brand palette (from lib/core/app_colors.dart) --------------------------
GRAD_TL = (13, 33, 55)          # #0D2137 gradientStart
GRAD_BR = (7, 17, 28)           # slightly darker than #0A1B2A for depth
SURFACE = (16, 38, 58)          # #10263A surface (glass card fill)
CYAN = (46, 197, 255)           # #2EC5FF primary
TEXT_PRIMARY = (243, 247, 255)  # #F3F7FF
TEXT_TAGLINE = (175, 198, 222)  # light steel, readable on navy

ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"


def diagonal_gradient(size, c0, c1):
    w, h = size
    base = Image.new("RGB", size)
    px = base.load()
    maxd = (w - 1) + (h - 1)
    for y in range(h):
        for x in range(w):
            t = (x + y) / maxd
            px[x, y] = (
                int(c0[0] + (c1[0] - c0[0]) * t),
                int(c0[1] + (c1[1] - c0[1]) * t),
                int(c0[2] + (c1[2] - c0[2]) * t),
            )
    return base


def main():
    img = diagonal_gradient((W, H), GRAD_TL, GRAD_BR).convert("RGBA")

    cx, cy = 241, 250  # center of the icon card

    # --- Faint radar/signal rings behind the icon (echoes the icon motif) ---
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for r, a in [(170, 26), (230, 18), (300, 12), (380, 8)]:
        od.ellipse([cx - r, cy - r, cx + r, cy + r], outline=CYAN + (a,), width=3)
    img = Image.alpha_composite(img, overlay)

    # --- Soft drop shadow for the icon card ---------------------------------
    card = 290
    cx0, cy0 = 96, (H - card) // 2
    cx1, cy1 = cx0 + card, cy0 + card
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [cx0 + 6, cy0 + 12, cx1 + 6, cy1 + 12], radius=40, fill=(0, 0, 0, 110)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    img = Image.alpha_composite(img, shadow)

    # --- Glass card framing the app icon ------------------------------------
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([cx0, cy0, cx1, cy1], radius=40,
                           fill=SURFACE + (235,), outline=CYAN + (140,), width=3)

    pad = 30
    side = card - 2 * pad
    icon = Image.open(ICON_PATH).convert("RGBA").resize((side, side), Image.LANCZOS)
    img.paste(icon, (cx0 + pad, cy0 + pad), icon)

    # --- Wordmark + tagline (right of the icon, vertically centered) --------
    draw = ImageDraw.Draw(img)
    tx = 432
    wordmark_font = ImageFont.truetype(ARIAL_BOLD, 100)
    tagline_font = ImageFont.truetype(ARIAL, 42)

    wm, tg = "KoruBeni", "Kişisel Güvenlik"
    wb = draw.textbbox((0, 0), wm, font=wordmark_font)
    tb = draw.textbbox((0, 0), tg, font=tagline_font)
    wm_h = wb[3] - wb[1]
    tg_h = tb[3] - tb[1]
    gap, accent_h = 28, 7
    block_h = wm_h + gap + accent_h + gap + tg_h
    top = (H - block_h) // 2

    draw.text((tx, top - wb[1]), wm, font=wordmark_font, fill=TEXT_PRIMARY)
    accent_y = top + wm_h + gap
    draw.rounded_rectangle([tx + 2, accent_y, tx + 132, accent_y + accent_h],
                           radius=accent_h // 2, fill=CYAN)
    tg_y = accent_y + accent_h + gap - tb[1]
    draw.text((tx, tg_y), tg, font=tagline_font, fill=TEXT_TAGLINE)

    # --- Flatten to 24-bit RGB (NO alpha) and save --------------------------
    final = Image.new("RGB", (W, H))
    final.paste(img.convert("RGB"), (0, 0))
    final.save(OUT_PATH, "PNG", optimize=True)
    print("wrote", OUT_PATH, final.size, final.mode)


if __name__ == "__main__":
    main()
