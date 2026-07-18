#!/usr/bin/env python3
"""Create premium Play Store screenshots from real KoruBeni app captures."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "final"
OUT = ROOT / "premium_app_store"

CANVAS = (1080, 1920)
FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

INK = (244, 250, 255)
MUTED = (180, 205, 224)
CYAN = (46, 197, 255)
TEAL = (22, 224, 196)
RED = (255, 77, 77)
NAVY = (7, 20, 33)
CARD = (12, 32, 50)


@dataclass(frozen=True)
class Shot:
    source: str
    output: str
    eyebrow: str
    title: str
    subtitle: str
    accent: tuple[int, int, int]


SHOTS = [
    Shot(
        "01_home_locked_panic.png",
        "01_panik_sos.png",
        "KORUBENI PRO",
        "Panik/SOS akışını hazır tut",
        "Uzun bas, geri sayımda PIN ile iptal et.",
        RED,
    ),
    Shot(
        "02_contacts.png",
        "02_acil_kisiler.png",
        "GUVEN AGI",
        "Acil kişilerini tek yerde yönet",
        "Güvendiğin kişileri cihazında yerel olarak sakla.",
        CYAN,
    ),
    Shot(
        "03_settings_legal.png",
        "03_gizlilik_ayarlar.png",
        "KONTROL SENDE",
        "PIN, gizlilik ve yasal ayarlar",
        "Uygulama erişimi ve güvenlik tercihleri net.",
        TEAL,
    ),
    Shot(
        "04_map.png",
        "04_konum_oturumu.png",
        "KONUM OTURUMU",
        "Konumunu ekranda net gör",
        "Harita oturumunu başlat, durumunu takip et.",
        CYAN,
    ),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REGULAR, size)


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0], box[3] - box[1]


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if text_size(draw, candidate, fnt)[0] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_centered(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    size: int,
    color: tuple[int, int, int],
    bold: bool = False,
    max_width: int = 880,
    line_gap: int = 12,
) -> int:
    fnt = font(size, bold)
    lines = wrap(draw, text, fnt, max_width)
    heights = [text_size(draw, line, fnt)[1] for line in lines]
    total = sum(heights) + line_gap * max(0, len(lines) - 1)
    cy = y
    for line, h in zip(lines, heights):
        w, _ = text_size(draw, line, fnt)
        draw.text(((CANVAS[0] - w) / 2, cy), line, font=fnt, fill=color)
        cy += h + line_gap
    return y + total


def gradient_background(base_shot: Image.Image, accent: tuple[int, int, int]) -> Image.Image:
    bg = Image.new("RGB", CANVAS, NAVY)
    shot = base_shot.convert("RGB")
    shot = cover(shot, CANVAS)
    shot = shot.filter(ImageFilter.GaussianBlur(30))
    tint = Image.new("RGB", CANVAS, NAVY)
    bg = Image.blend(shot, tint, 0.76)

    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    px = overlay.load()
    for y in range(CANVAS[1]):
        t = y / (CANVAS[1] - 1)
        for x in range(CANVAS[0]):
            radial = max(0, 1 - (((x - 540) / 650) ** 2 + ((y - 1280) / 880) ** 2))
            a = int(46 * radial + 35 * (1 - t))
            px[x, y] = (*accent, a)
    bg = bg.convert("RGBA")
    bg.alpha_composite(overlay)

    dark = Image.new("RGBA", CANVAS, (3, 11, 21, 90))
    bg.alpha_composite(dark)
    return bg


def cover(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    iw, ih = img.size
    tw, th = size
    scale = max(tw / iw, th / ih)
    nw, nh = int(iw * scale), int(ih * scale)
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def contain(img: Image.Image, size: tuple[int, int], fill: tuple[int, int, int]) -> Image.Image:
    canvas = Image.new("RGB", size, fill)
    iw, ih = img.size
    tw, th = size
    scale = min(tw / iw, th / ih)
    nw, nh = int(iw * scale), int(ih * scale)
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_phone(canvas: Image.Image, screenshot: Image.Image, y: int, accent: tuple[int, int, int]) -> None:
    screen_size = (600, 1116)
    frame_pad = 24
    frame_size = (screen_size[0] + frame_pad * 2, screen_size[1] + frame_pad * 2)
    x = (CANVAS[0] - frame_size[0]) // 2

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (x - 10, y + 14, x + frame_size[0] + 10, y + frame_size[1] + 34),
        radius=72,
        fill=(0, 0, 0, 135),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.alpha_composite(shadow)

    glow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle(
        (x - 18, y - 18, x + frame_size[0] + 18, y + frame_size[1] + 18),
        radius=82,
        outline=(*accent, 95),
        width=5,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(8))
    canvas.alpha_composite(glow)

    frame = Image.new("RGBA", frame_size, (5, 13, 23, 255))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle((0, 0, frame_size[0] - 1, frame_size[1] - 1), radius=68, fill=(5, 13, 23, 255))
    fd.rounded_rectangle((6, 6, frame_size[0] - 7, frame_size[1] - 7), radius=62, outline=(255, 255, 255, 22), width=2)
    fd.rounded_rectangle((frame_size[0] // 2 - 86, 14, frame_size[0] // 2 + 86, 38), radius=13, fill=(3, 8, 15, 255))

    screen = contain(screenshot.convert("RGB"), screen_size, CARD).convert("RGBA")
    mask = rounded_mask(screen_size, 42)
    frame.paste(screen, (frame_pad, frame_pad), mask)
    canvas.alpha_composite(frame, (x, y))


def draw_header(draw: ImageDraw.ImageDraw, shot: Shot) -> None:
    eyef = font(22, bold=True)
    tw, th = text_size(draw, shot.eyebrow, eyef)
    pill_w = tw + 46
    pill_h = 46
    px = (CANVAS[0] - pill_w) // 2
    py = 104
    draw.rounded_rectangle(
        (px, py, px + pill_w, py + pill_h),
        radius=23,
        fill=(3, 11, 21, 118),
        outline=(*shot.accent, 180),
        width=1,
    )
    draw.text((px + 23, py + 10), shot.eyebrow, font=eyef, fill=shot.accent)

    bottom = draw_centered(draw, shot.title, 186, 66, INK, bold=True, max_width=900, line_gap=10)
    draw_centered(draw, shot.subtitle, bottom + 26, 34, MUTED, max_width=820, line_gap=8)


def draw_footer_mark(draw: ImageDraw.ImageDraw) -> None:
    mark = "KoruBeni"
    f = font(28, bold=True)
    w, h = text_size(draw, mark, f)
    draw.rounded_rectangle(
        (CANVAS[0] // 2 - 18 - w // 2, 1814, CANVAS[0] // 2 + 18 + w // 2, 1872),
        radius=29,
        fill=(3, 11, 21, 150),
        outline=(255, 255, 255, 32),
        width=1,
    )
    draw.text(((CANVAS[0] - w) / 2, 1830), mark, font=f, fill=(220, 238, 248))


def render(shot: Shot) -> None:
    source = Image.open(SOURCE / shot.source)
    canvas = gradient_background(source, shot.accent)
    draw = ImageDraw.Draw(canvas)
    draw_header(draw, shot)
    paste_phone(canvas, source, 588, shot.accent)
    draw_footer_mark(draw)
    canvas.convert("RGB").save(OUT / shot.output, optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for shot in SHOTS:
        render(shot)
    (OUT / "README.md").write_text(
        "# Premium KoruBeni app screenshots\n\n"
        "Generated from the real app captures in `store/screenshots/android/final/`.\n"
        "Run `python3 store/screenshots/android/generate_premium_app_screenshots.py` to regenerate.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
