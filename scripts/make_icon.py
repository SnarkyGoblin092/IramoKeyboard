#!/usr/bin/env python3
"""Draws the 1024x1024 app icon: white keycaps on a blue-violet gradient with a swipe trail waving across them.
Drawn at 4x and scaled down for smooth edges. Needs Pillow and NumPy:  pip install pillow numpy"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

F = 4             # supersampling factor
S = 1024 * F
out = Path(__file__).resolve().parent.parent / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "icon.png"


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


# Background: blue to violet, lit from the top left.
img = gradient([(0, "#6C7BFF"), (1, "#A35CFF")], 55)
img.alpha_composite(radial((S * 0.25, S * 0.1), S * 0.8, (255, 255, 255), 0.25))

# Keycaps in keyboard rows (4, 3 shifted by half a key, 4), each with an edge below it.
key, gap, radius, depth = 168 * F, 26 * F, 46 * F, 12 * F
rows = [(4, 0.0), (3, 0.5), (4, 0.0)]
width, height = 4 * key + 3 * gap, 3 * key + 2 * gap
left, top = (S - width) // 2, (S - height) // 2
keys = [(left + int((i + offset) * (key + gap)), top + row * (key + gap))
        for row, (count, offset) in enumerate(rows) for i in range(count)]
for x0, y0 in keys:   # all shadows first, so none falls on a neighbouring key
    shadow(img, rrect_mask((x0, y0 + depth, x0 + key, y0 + key + depth), radius), (0, 14 * F), 22 * F,
           (40, 30, 120), 0.22)
face_fill = gradient([(0, "#FFFFFF"), (1, "#EEF0FA")], 90)
for x0, y0 in keys:
    paste_colour(img, rrect_mask((x0, y0 + depth, x0 + key, y0 + key + depth), radius), (206, 210, 238))
    face = face_fill.copy()
    face.putalpha(rrect_mask((x0, y0, x0 + key, y0 + key), radius))
    img.alpha_composite(face)

# The swipe trail: one and a half waves across the keys, thickening towards the end, with a shadow under it.
points = []
x_start, x_end, mid, amplitude = left + key * 0.3, left + width - key * 0.3, top + height / 2, key * 0.82
for i in range(901):
    u = i / 900
    points.append((x_start + (x_end - x_start) * u, mid - amplitude * math.sin(2 * math.pi * 1.5 * u)))
w_start, w_end = 30 * F, 70 * F
colours = [np.array(hexrgb(c), float) for c in ["#0A8DFF", "#3F48F2", "#8E2BE8", "#E8287A"]]
trail_mask = Image.new("L", img.size, 0)
trail = Image.new("RGBA", img.size, (0, 0, 0, 0))
draw_mask, draw_trail = ImageDraw.Draw(trail_mask), ImageDraw.Draw(trail)
for i, (x, y) in enumerate(points):
    u = i / (len(points) - 1)
    t = u * (len(colours) - 1)
    k = min(int(t), len(colours) - 2)
    colour = colours[k] + (colours[k + 1] - colours[k]) * (t - k)
    r = (w_start + (w_end - w_start) * u ** 0.6) / 2
    draw_mask.ellipse((x - r, y - r, x + r, y + r), fill=255)
    draw_trail.ellipse((x - r, y - r, x + r, y + r), fill=tuple(int(v) for v in colour) + (255,))
shadow(img, trail_mask, (0, 24 * F), 28 * F, (30, 14, 100), 0.9)   # wide and soft...
shadow(img, trail_mask, (0, 24 * F), 28 * F, (30, 14, 100), 0.6)
shadow(img, trail_mask, (0, 9 * F), 9 * F, (30, 14, 100), 0.6)     # ...and tight under the line
img.alpha_composite(trail)

# Where the finger lifts: a white dot with a pink glow.
x, y = points[-1]
r = 44 * F
dot = Image.new("L", img.size, 0)
ImageDraw.Draw(dot).ellipse((x - r, y - r, x + r, y + r), fill=255)
shadow(img, dot, (0, 0), 28 * F, hexrgb("#E8287A"), 0.9)
paste_colour(img, dot, (255, 255, 255))

out.parent.mkdir(parents=True, exist_ok=True)
img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out)   # no alpha: iOS rejects icons with it
print("wrote", out)
