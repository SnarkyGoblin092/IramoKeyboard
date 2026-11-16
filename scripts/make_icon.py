#!/usr/bin/env python3
"""Draws the 1024x1024 app icon in a light and a dark version (iOS shows the dark one when the phone is in dark
mode): one keycap with a rainbow side and a swipe swoop across its face. Drawn at 4x and scaled down for smooth
edges. Needs Pillow and NumPy:  pip install pillow numpy"""
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


RAINBOW = ["#14C8D8", "#2F7BFF", "#7B4DFF", "#E8287A"]


def bezier(p0, p1, p2, p3, n):
    pts = []
    for i in range(n + 1):
        u = i / n
        a, b, c, d = (1 - u) ** 3, 3 * (1 - u) ** 2 * u, 3 * (1 - u) * u ** 2, u ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def colour_at(u, stops):
    cols = [np.array(hexrgb(c), float) for c in stops]
    t = u * (len(cols) - 1)
    k = min(int(t), len(cols) - 2)
    return tuple(int(v) for v in cols[k] + (cols[k + 1] - cols[k]) * (t - k))


def draw(dark):
    """The icon: one keycap whose side glows with the rainbow, a swipe swoop across its face. Light: a white key on
    a pastel wash. Dark: a navy key on a deep navy, the swoop glowing."""
    C = S / 2
    if dark:
        img = gradient([(0, "#121733"), (0.5, "#1A1640"), (1, "#26143A")], 120)
        img.alpha_composite(radial((C, C + 120 * F), S * 0.6, (110, 70, 255), 0.35))
    else:
        img = gradient([(0, "#DCEBFF"), (0.5, "#EADFFF"), (1, "#FFDDEB")], 120)

    # The keycap: a soft coloured shadow, the rainbow side below, the face on top.
    box = (C - 330 * F, C - 340 * F, C + 330 * F, C + 300 * F)
    radius, depth = 140 * F, 34 * F
    face_mask = rrect_mask(box, radius)
    side = Image.new("L", (S, S), 0)
    side.paste(face_mask, (0, depth))
    shadow(img, side, (0, 22 * F), 36 * F, (120, 60, 255) if dark else (120, 60, 200), 0.55 if dark else 0.4)
    edge = gradient([(i / (len(RAINBOW) - 1), c) for i, c in enumerate(RAINBOW)], 0)
    edge.putalpha(side)
    img.alpha_composite(edge)
    face = gradient([(0, "#2A3058"), (1, "#1E2346")] if dark else [(0, "#FFFFFF"), (1, "#ECEEFA")], 90)
    face.putalpha(face_mask)
    img.alpha_composite(face)

    # The swoop, as a finger swipes a word: a quick dip, then a long sweep up to the top right. It thickens
    # towards the end and runs cyan, blue, violet, pink; it sits centred on the key face.
    curve = [(x * 0.76 * F, y * 0.76 * F) for x, y in ((-270, 230), (-90, 450), (70, -310), (270, -80))]
    points = bezier(*curve, 1600)
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    dx, dy = C - (min(xs) + max(xs)) / 2, C - 22 * F - (min(ys) + max(ys)) / 2
    points = [(x + dx, y + dy) for x, y in points]
    w_start, w_end = 34 * F, 92 * F
    swoop_mask = Image.new("L", img.size, 0)
    swoop = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_mask, draw_swoop = ImageDraw.Draw(swoop_mask), ImageDraw.Draw(swoop)
    for i, (x, y) in enumerate(points):
        u = i / (len(points) - 1)
        r = (w_start + (w_end - w_start) * u ** 0.8) / 2
        draw_mask.ellipse((x - r, y - r, x + r, y + r), fill=255)
        draw_swoop.ellipse((x - r, y - r, x + r, y + r), fill=colour_at(u, RAINBOW) + (255,))
    if dark:
        shadow(img, swoop_mask, (0, 0), 34 * F, hexrgb("#7B4DFF"), 0.6)   # a glow; a shadow would not show
    else:
        shadow(img, swoop_mask, (0, 12 * F), 16 * F, (60, 30, 140), 0.15)
    img.alpha_composite(swoop)
    return img.convert("RGB").resize((1024, 1024), Image.LANCZOS)   # no alpha: iOS rejects icons with it


ICONS.mkdir(parents=True, exist_ok=True)
LOGOS.mkdir(parents=True, exist_ok=True)
for dark, suffix in [(False, ""), (True, "-dark")]:
    icon = draw(dark)
    icon.save(ICONS / f"icon{suffix}.png")
    # A small copy for the app's own header (56 pt, at 3x).
    icon.resize((168, 168), Image.LANCZOS).save(LOGOS / f"logo{suffix}.png")
    print("wrote", ICONS / f"icon{suffix}.png", "and", LOGOS / f"logo{suffix}.png")
