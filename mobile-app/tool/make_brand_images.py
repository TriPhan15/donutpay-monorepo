"""Builds the T9 brand images from the original logo (spec 2.4 and 3.11, logo C and the splash screen).

Usage (Pillow is in the ai-service venv):
    git show pre-redesign:mobile-app/assets/images/logo.png > logo_original.png
    ai-service/.venv/bin/python -I mobile-app/tool/make_brand_images.py \
        logo_original.png BeVietnamPro-Bold.ttf \
        mobile-app/assets/images/logo.png \
        mobile-app/android/app/src/main/res/drawable-xxhdpi/splash_logo.png

logo.png: 1024 px RGB (no alpha, the iOS icon needs none), the L of the original turned white on the #38BDF8 ->
#0369A1 gradient, full bleed. splash_logo.png: the logo at 96 dp with 28 dp corners and "LedgerMind" under it, white on a
transparent background, drawn at xxhdpi (x3).
"""

import math
import sys
from PIL import Image, ImageDraw, ImageFont

GRADIENT_START = (0x38, 0xBD, 0xF8)
GRADIENT_END = (0x03, 0x69, 0xA1)
GRADIENT_DEGREES = 160  # CSS direction of the design: top to bottom, leaning right
ICON_SIZE = 1024

# The original is a cyan rounded square (green channel 239) with a navy L (green channel 10) on white corners (green
# channel 255): the green channel alone tells the L apart, anti-aliased edges included, and leaves the corners out.
CYAN_GREEN = 239
NAVY_GREEN = 10
# Compression noise along the original's rounded edge reads as a few percent of L; below this it is background.
NOISE_FLOOR = 0.15

SCALE = 3  # xxhdpi
LOGO_DP = 96
CORNER_DP = 28
GAP_DP = 16
TEXT_DP = 24
APP_NAME = "LedgerMind"

COLOUR_TOLERANCE = 12
WHITE_COUNT_TOLERANCE = 0.01


def letter_mask(original: Image.Image) -> list[list[float]]:
    """How much of each pixel is the L: 0 for the background and the corners, 1 inside the letter."""
    width, height = original.size
    pixels = original.load()
    span = CYAN_GREEN - NAVY_GREEN

    def amount(green: int) -> float:
        raw = (CYAN_GREEN - green) / span
        return min(1.0, max(0.0, (raw - NOISE_FLOOR) / (1 - NOISE_FLOOR)))

    return [[amount(pixels[x, y][1]) for x in range(width)] for y in range(height)]


def gradient(size: int) -> Image.Image:
    angle = math.radians(GRADIENT_DEGREES)
    dx, dy = math.sin(angle), -math.cos(angle)
    half = (abs(dx) + abs(dy)) * size / 2
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = ((x - size / 2) * dx + (y - size / 2) * dy + half) / (2 * half)
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(GRADIENT_START, GRADIENT_END))
    return image


def build_logo(original: Image.Image, background: Image.Image) -> tuple[Image.Image, int]:
    """The original's L blended in white over [background]; also returns how many pixels are mostly white."""
    original = original.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
    mask = letter_mask(original)
    logo = background.copy()
    pixels = logo.load()
    letter_pixels = 0
    for y in range(ICON_SIZE):
        for x in range(ICON_SIZE):
            t = mask[y][x]
            if t > 0.5:
                letter_pixels += 1
            if t > 0:
                pixels[x, y] = tuple(round(c + (255 - c) * t) for c in pixels[x, y])
    return logo, letter_pixels


def build_splash(logo: Image.Image, font_path: str) -> Image.Image:
    logo_px, corner_px = LOGO_DP * SCALE, CORNER_DP * SCALE
    small = logo.resize((logo_px, logo_px), Image.LANCZOS).convert("RGBA")
    corners = Image.new("L", (logo_px * 4, logo_px * 4), 0)
    ImageDraw.Draw(corners).rounded_rectangle((0, 0, logo_px * 4 - 1, logo_px * 4 - 1), corner_px * 4, fill=255)
    small.putalpha(corners.resize((logo_px, logo_px), Image.LANCZOS))

    font = ImageFont.truetype(font_path, TEXT_DP * SCALE)
    left, top, right, bottom = font.getbbox(APP_NAME)
    text_w, text_h = right - left, bottom - top
    width = max(logo_px, text_w)
    gap = GAP_DP * SCALE
    splash = Image.new("RGBA", (width, logo_px + gap + text_h), (0, 0, 0, 0))
    splash.alpha_composite(small, ((width - logo_px) // 2, 0))
    ImageDraw.Draw(splash).text(((width - text_w) // 2 - left, logo_px + gap - top), APP_NAME, font=font, fill="white")
    return splash


def check(logo: Image.Image, letter_pixels: int, background: Image.Image, expected_letter_pixels: int) -> None:
    """The icon is 1024 px RGB, its four corners are the gradient (no white left from the original's rounded corners)
    and the L kept its size."""
    assert logo.size == (ICON_SIZE, ICON_SIZE) and logo.mode == "RGB", (logo.size, logo.mode)
    last = ICON_SIZE - 1
    for corner in [(0, 0), (last, 0), (0, last), (last, last)]:
        got, want = logo.getpixel(corner), background.getpixel(corner)
        assert all(abs(p - q) <= COLOUR_TOLERANCE for p, q in zip(got, want)), (corner, got, want)
    assert abs(letter_pixels - expected_letter_pixels) <= expected_letter_pixels * WHITE_COUNT_TOLERANCE, (
        letter_pixels,
        expected_letter_pixels,
    )


def main() -> None:
    original_path, font_path, logo_path, splash_path = sys.argv[1:5]
    original = Image.open(original_path).convert("RGB")
    background = gradient(ICON_SIZE)
    logo, letter_pixels = build_logo(original, background)
    # The L as the original draws it, measured inside its cyan square, before any blending.
    expected = sum(1 for row in letter_mask(original.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)) for t in row if t > 0.5)
    check(logo, letter_pixels, background, expected)
    logo.save(logo_path, optimize=True)
    print(f"OK logo {logo.size[0]}x{logo.size[1]} {logo.mode}, letter pixels {letter_pixels}")
    splash = build_splash(logo, font_path)
    splash.save(splash_path, optimize=True)
    print(f"OK splash {splash.size[0]}x{splash.size[1]}")


if __name__ == "__main__":
    main()
