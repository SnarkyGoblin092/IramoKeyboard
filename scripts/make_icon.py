#!/usr/bin/env python3
"""Draws the 1024x1024 app icon in a light and a dark version (iOS shows the dark one when the phone is in dark
mode): keycaps on a blue-violet gradient with a swipe trail swooping across them. Drawn at 4x and scaled down for
smooth edges. Needs Pillow and NumPy:  pip install pillow numpy"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

F = 4             # supersampling factor
S = 1024 * F
ASSETS = Path(__file__).resolve().parent.parent / "App" / "Assets.xcassets"
ICONS = ASSETS / "AppIcon.appiconset"
LOGOS = ASSETS / "AppLogo.imageset"


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def gradient(stops, angle_deg):
    """Linear gradient over the square; stops = [(position 0...1, "#rrggbb"), ...]."""
    a = math.radians(angle_deg)
    y, x = np.mgrid[0:S, 0:S] / (S - 1) - 0.5
    t = np.clip((x * math.cos(a) + y * math.sin(a)) / (abs(math.cos(a)) + abs(math.sin(a))) + 0.5, 0, 1)
    rgb = np.zeros((S, S, 3))
    positions = [p for p, _ in stops]
    colours = [hexrgb(c) for _, c in stops]
    for ch in range(3):
        rgb[..., ch] = np.interp(t, positions, [c[ch] for c in colours])
    return Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")


def radial(center, radius, colour, alpha):
    """A soft round glow."""
    y, x = np.mgrid[0:S, 0:S]
    d = np.sqrt((x - center[0]) ** 2 + (y - center[1]) ** 2) / radius
    layer = Image.new("RGBA", (S, S), colour + (0,))
    layer.putalpha(Image.fromarray((np.clip(1 - d, 0, 1) ** 2 * alpha * 255).astype(np.uint8), "L"))
    return layer


def rrect_mask(box, r):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255)
    return m


def paste_colour(img, mask, colour, alpha=1.0):
    layer = Image.new("RGBA", img.size, colour + (0,))
    layer.putalpha(mask.point(lambda v: int(v * alpha)))
    img.alpha_composite(layer)


def shadow(img, mask, offset, blur, colour, alpha):
    m = Image.new("L", img.size, 0)
    m.paste(mask, offset)
    paste_colour(img, m.filter(ImageFilter.GaussianBlur(blur)), colour, alpha)


def draw(dark):
    """The icon: light (white keys on blue-violet) or dark (graphite keys on a deep night violet)."""
    # Background, lit from the top left.
    if dark:
        img = gradient([(0, "#1B1F3B"), (0.55, "#241B45"), (1, "#371A57")], 55)
        img.alpha_composite(radial((S * 0.25, S * 0.1), S * 0.8, (120, 110, 255), 0.22))
    else:
        img = gradient([(0, "#6C7BFF"), (1, "#A35CFF")], 55)
        img.alpha_composite(radial((S * 0.25, S * 0.1), S * 0.8, (255, 255, 255), 0.25))

    # Keycaps in keyboard rows (4, 3 shifted by half a key, 4), each with an edge below it.
    key, gap, radius, depth = 168 * F, 26 * F, 46 * F, 12 * F
    rows = [(4, 0.0), (3, 0.5), (4, 0.0)]
    width, height = 4 * key + 3 * gap, 3 * key + 2 * gap
    left, top = (S - width) // 2, (S - height) // 2
    keys = [(left + int((i + offset) * (key + gap)), top + row * (key + gap))
            for row, (count, offset) in enumerate(rows) for i in range(count)]
    shade = (5, 4, 20) if dark else (40, 30, 120)
    for x0, y0 in keys:   # all shadows first, so none falls on a neighbouring key
        shadow(img, rrect_mask((x0, y0 + depth, x0 + key, y0 + key + depth), radius), (0, 14 * F), 22 * F,
               shade, 0.45 if dark else 0.22)
    face_fill = gradient([(0, "#4A4F6E"), (1, "#383C57")] if dark else [(0, "#FFFFFF"), (1, "#EEF0FA")], 90)
    edge = (34, 36, 56) if dark else (206, 210, 238)
    for x0, y0 in keys:
        paste_colour(img, rrect_mask((x0, y0 + depth, x0 + key, y0 + key + depth), radius), edge)
        face = face_fill.copy()
        face.putalpha(rrect_mask((x0, y0, x0 + key, y0 + key), radius))
        img.alpha_composite(face)

    # The swipe trail: one swoop, as a finger swipes a word: a quick dip from the left, then a long sweep rising to
    # the top right; it thickens towards the end, with a shadow under it.
    p0 = (left + width * 0.05, top + height * 0.46)
    p1 = (left + width * 0.16, top + height * 1.22)
    p2 = (left + width * 0.58, top + height * 0.66)
    p3 = (left + width * 0.95, top + height * 0.13)
    points = []
    for i in range(1201):
        u = i / 1200
        a, b, c, d = (1 - u) ** 3, 3 * (1 - u) ** 2 * u, 3 * (1 - u) * u ** 2, u ** 3
        points.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    w_start, w_end = 26 * F, 74 * F
    stops = ["#2FA8FF", "#5B63FF", "#A23CF2", "#FF3D8E"] if dark else ["#0A8DFF", "#3F48F2", "#8E2BE8", "#E8287A"]
    colours = [np.array(hexrgb(c), float) for c in stops]
    trail_mask = Image.new("L", img.size, 0)
    trail = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_mask, draw_trail = ImageDraw.Draw(trail_mask), ImageDraw.Draw(trail)
    for i, (x, y) in enumerate(points):
        u = i / (len(points) - 1)
        t = u * (len(colours) - 1)
        k = min(int(t), len(colours) - 2)
        colour = colours[k] + (colours[k + 1] - colours[k]) * (t - k)
        r = (w_start + (w_end - w_start) * u ** 0.7) / 2
        draw_mask.ellipse((x - r, y - r, x + r, y + r), fill=255)
        draw_trail.ellipse((x - r, y - r, x + r, y + r), fill=tuple(int(v) for v in colour) + (255,))
    if dark:
        # A coloured glow under the line instead of a shadow, which would not show on the dark.
        shadow(img, trail_mask, (0, 6 * F), 34 * F, hexrgb("#7A4DFF"), 0.75)
        shadow(img, trail_mask, (0, 14 * F), 14 * F, (0, 0, 0), 0.55)
    else:
        shadow(img, trail_mask, (0, 24 * F), 28 * F, (30, 14, 100), 0.9)   # wide and soft...
        shadow(img, trail_mask, (0, 24 * F), 28 * F, (30, 14, 100), 0.6)
        shadow(img, trail_mask, (0, 9 * F), 9 * F, (30, 14, 100), 0.6)     # ...and tight under the line
    img.alpha_composite(trail)

    # Where the finger lifts: a white dot with a pink glow.
    x, y = points[-1]
    r = 44 * F
    dot = Image.new("L", img.size, 0)
    ImageDraw.Draw(dot).ellipse((x - r, y - r, x + r, y + r), fill=255)
    shadow(img, dot, (0, 0), 28 * F, hexrgb("#FF3D8E" if dark else "#E8287A"), 1.0 if dark else 0.9)
    paste_colour(img, dot, (255, 255, 255))
    return img.convert("RGB").resize((1024, 1024), Image.LANCZOS)   # no alpha: iOS rejects icons with it


ICONS.mkdir(parents=True, exist_ok=True)
LOGOS.mkdir(parents=True, exist_ok=True)
for dark, suffix in [(False, ""), (True, "-dark")]:
    icon = draw(dark)
    icon.save(ICONS / f"icon{suffix}.png")
    # A small copy for the app's own header (56 pt, at 3x).
    icon.resize((168, 168), Image.LANCZOS).save(LOGOS / f"logo{suffix}.png")
    print("wrote", ICONS / f"icon{suffix}.png", "and", LOGOS / f"logo{suffix}.png")
