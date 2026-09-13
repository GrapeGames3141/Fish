#!/usr/bin/env python3
"""Derive Play Console listing art and Android launcher icons from tracked masters.

Regenerate with `python3 tools/make_store_assets.py` after the icon or the
Cedar River plate changes. Every output is deterministic, so a rerun with
unchanged inputs produces byte-identical files.

Outputs:
  builds/store/hooked/App icon.png              512x512   Play listing icon
  builds/store/hooked/Feature graphic.png      1024x500   Play feature graphic
  art/ui_v1/android/launcher-icon-192.png       192x192   legacy launcher icon
  art/ui_v1/android/adaptive-foreground-432.png 432x432   adaptive foreground
  art/ui_v1/android/adaptive-background-432.png 432x432   adaptive background
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui_v1" / "runtime_source"
ICON_MASTER = SOURCE / "app-icon-runtime-512.png"
PLATE_MASTER = SOURCE / "cedar-river-michigan-v01.png"
CINZEL = ROOT / "art" / "fonts" / "cinzel" / "Cinzel[wght].ttf"

STORE_DIR = ROOT / "builds" / "store" / "hooked"
ANDROID_DIR = ROOT / "art" / "ui_v1" / "android"

# Sampled from the icon master's field, which is also the boot splash colour.
DEEP_TEAL = (9, 38, 46)


def load_icon() -> Image.Image:
    return Image.open(ICON_MASTER).convert("RGBA")


def play_listing_icon() -> None:
    """Play requires a 512x512 32-bit PNG with no alpha channel."""
    icon = load_icon()
    flat = Image.new("RGB", icon.size, DEEP_TEAL)
    flat.paste(icon, (0, 0), icon)
    flat.save(STORE_DIR / "App icon.png")


def launcher_icons() -> None:
    icon = load_icon()
    icon.resize((192, 192), Image.LANCZOS).save(ANDROID_DIR / "launcher-icon-192.png")

    # The adaptive mask crops to the centre ~66%, so the badge is inset to
    # 288px inside the 432px canvas and the field is carried by the background.
    foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    badge = icon.resize((288, 288), Image.LANCZOS)
    foreground.paste(badge, (72, 72), badge)
    foreground.save(ANDROID_DIR / "adaptive-foreground-432.png")

    Image.new("RGBA", (432, 432), DEEP_TEAL + (255,)).save(
        ANDROID_DIR / "adaptive-background-432.png"
    )


def _cinzel(size: int, weight: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(CINZEL), size)
    # Cinzel ships as a variable font; pin the axis so runs stay deterministic.
    font.set_variation_by_axes([weight])
    return font


def feature_graphic() -> None:
    """1024x500 banner: river plate, icon badge, wordmark, one-line hook."""
    plate = Image.open(PLATE_MASTER).convert("RGB")

    # Crop a landscape band from the plate's midriver, then cover-fit to 1024x500.
    band_height = int(plate.width * 500 / 1024)
    top = int(plate.height * 0.34)
    band = plate.crop((0, top, plate.width, top + band_height))
    canvas = band.resize((1024, 500), Image.LANCZOS).convert("RGBA")

    # Play crops the outer edges on some surfaces, so the artwork is darkened
    # left-to-right and the lockup sits inside the centre-safe band.
    scrim = Image.new("RGBA", (1024, 500), (0, 0, 0, 0))
    scrim_draw = ImageDraw.Draw(scrim)
    for x in range(1024):
        ramp = min(1.0, max(0.0, (x - 40) / 620.0))
        scrim_draw.line([(x, 0), (x, 500)], fill=DEEP_TEAL + (int(70 + 175 * ramp),))
    canvas.alpha_composite(scrim)

    # Vignette the top and bottom so the banner reads as one plate, not a crop.
    edge = Image.new("RGBA", (1024, 500), (0, 0, 0, 0))
    edge_draw = ImageDraw.Draw(edge)
    for y in range(70):
        alpha = int(120 * (1 - y / 70.0))
        edge_draw.line([(0, y), (1024, y)], fill=(4, 18, 24, alpha))
        edge_draw.line([(0, 499 - y), (1024, 499 - y)], fill=(4, 18, 24, alpha))
    canvas.alpha_composite(edge)

    icon = load_icon().resize((272, 272), Image.LANCZOS)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 150), (96, 126, 96 + 272, 126 + 272), icon)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(16)))
    canvas.alpha_composite(icon, (88, 114))

    draw = ImageDraw.Draw(canvas)
    title_font = _cinzel(92, 700)
    tagline_font = _cinzel(30, 500)

    draw.text((400, 178), "HOOKED", font=title_font, fill=(247, 240, 222, 255))
    draw.text((404, 286), "Cast, hook and fight fish", font=tagline_font,
              fill=(186, 216, 216, 255))
    draw.text((404, 326), "by moving your phone", font=tagline_font,
              fill=(186, 216, 216, 255))

    canvas.convert("RGB").save(STORE_DIR / "Feature graphic.png")


def main() -> None:
    STORE_DIR.mkdir(parents=True, exist_ok=True)
    ANDROID_DIR.mkdir(parents=True, exist_ok=True)
    play_listing_icon()
    launcher_icons()
    feature_graphic()
    print(f"Wrote store art to {STORE_DIR} and launcher icons to {ANDROID_DIR}")


if __name__ == "__main__":
    main()
