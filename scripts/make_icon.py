#!/usr/bin/env python3
"""Draws the app icon, one keycap with a rainbow side and a swipe swoop across its face: the home screen icon as
Icon Composer layers (App/AppIcon.icon), and the app's own logo in a light and a dark version that match how iOS
shows that icon. Drawn at 4x and scaled down for smooth edges. Needs Pillow and NumPy:  pip install pillow numpy"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

F = 4             # supersampling factor
S = 1024 * F
ASSETS = Path(__file__).resolve().parent.parent / "App" / "Assets.xcassets"
LOGOS = ASSETS / "AppLogo.imageset"
ICON_FILE = ASSETS.parent / "AppIcon.icon"


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


KEY_BOX = (S / 2 - 330 * F, S / 2 - 340 * F, S / 2 + 330 * F, S / 2 + 300 * F)
KEY_RADIUS, KEY_DEPTH = 140 * F, 34 * F
FACE = ["#FFFFFF", "#ECEEFA"]


def key_masks():
    """The keycap's face, and its side showing below the face."""
    face = rrect_mask(KEY_BOX, KEY_RADIUS)
    side = Image.new("L", (S, S), 0)
    side.paste(face, (0, KEY_DEPTH))
    return face, side


def coloured(mask, stops, angle):
    layer = gradient([(i / (len(stops) - 1), c) for i, c in enumerate(stops)], angle)
    layer.putalpha(mask)
    return layer


def swoop():
    """The swoop, as a finger swipes a word: a quick dip, then a long sweep up to the top right. It thickens towards
    the end and runs cyan, blue, violet, pink; it sits centred on the key face. Returns its mask and its colours."""
    C = S / 2
    curve = [(x * 0.76 * F, y * 0.76 * F) for x, y in ((-270, 230), (-90, 450), (70, -310), (270, -80))]
    points = bezier(*curve, 1600)
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    dx, dy = C - (min(xs) + max(xs)) / 2, C - 22 * F - (min(ys) + max(ys)) / 2
    w_start, w_end = 34 * F, 92 * F
    mask = Image.new("L", (S, S), 0)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_mask, draw_layer = ImageDraw.Draw(mask), ImageDraw.Draw(layer)
    for i, (x, y) in enumerate(points):
        x, y = x + dx, y + dy
        u = i / (len(points) - 1)
        r = (w_start + (w_end - w_start) * u ** 0.8) / 2
        draw_mask.ellipse((x - r, y - r, x + r, y + r), fill=255)
        draw_layer.ellipse((x - r, y - r, x + r, y + r), fill=colour_at(u, RAINBOW) + (255,))
    return mask, layer


def top_rim(mask, depth):
    """The upper edge of a shape, where glass catches the light."""
    lower = Image.new("L", (S, S), 0)
    lower.paste(mask, (0, depth))
    return ImageChops.subtract(mask, lower).filter(ImageFilter.GaussianBlur(depth / 2))


def draw(dark):
    """The flat icon for the app's own logo, drawn to look like iOS renders AppIcon.icon as glass on the home
    screen: the light keycap with its rainbow side and the swoop, on lavender (light mode) or near black (dark)."""
    C = S / 2
    if dark:
        img = gradient([(0, "#202022"), (1, "#141416")], 90)
    else:
        img = gradient([(0, "#E9E5FD"), (1, "#D8D3F5")], 90)
    face, side = key_masks()
    shadow(img, side, (0, 18 * F), 30 * F, (0, 0, 0) if dark else (60, 50, 120), 0.5 if dark else 0.18)
    img.alpha_composite(coloured(side, RAINBOW, 0))
    img.alpha_composite(coloured(face, ["#F4F4F7", "#D9DAE0"] if dark else ["#FFFFFF", "#EFEFF5"], 90))
    paste_colour(img, top_rim(face, 6 * F), (255, 255, 255), 0.9)
    mask, layer = swoop()
    shadow(img, mask, (0, 8 * F), 12 * F, (40, 30, 90), 0.2)
    layer.putalpha(mask.point(lambda v: int(v * 0.9)))   # glass lets a little of the key through
    img.alpha_composite(layer)
    paste_colour(img, top_rim(mask, 8 * F), (255, 255, 255), 0.45)
    return img.convert("RGB").resize((1024, 1024), Image.LANCZOS)


def small(img):
    return img.resize((1024, 1024), Image.LANCZOS)


def write_glass_icon():
    """The home screen icon as an Icon Composer file (AppIcon.icon): the background as a fill and the key and the
    swoop as separate layers, so iOS 26 and later render them as Liquid Glass and can make the icon clear or tinted.
    No shadows or glows are drawn into the layers: the system adds its own. The groups are listed front first."""
    assets = ICON_FILE / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    face, side = key_masks()
    rim = ImageChops.subtract(side, face)   # only the part of the side below the face, so none shows through it
    small(coloured(rim, RAINBOW, 0)).save(assets / "key-side.png")
    small(coloured(face, FACE, 90)).save(assets / "key-face.png")
    small(swoop()[1]).save(assets / "swoop.png")
    glass = {"shadow": {"kind": "neutral", "opacity": 0.5}, "translucency": {"enabled": True, "value": 0.4}}
    # In dark mode iOS puts the same light key on its own dark background.
    icon = {
        "fill": {"automatic-gradient": "display-p3:0.89804,0.88627,1.00000,1.00000"},
        "groups": [
            {"name": "Swoop", **glass, "layers": [{"name": "swoop", "image-name": "swoop.png", "glass": True}]},
            {"name": "Key", **glass, "layers": [
                {"name": "face", "image-name": "key-face.png", "glass": True},
                {"name": "side", "image-name": "key-side.png", "glass": True},
            ]},
        ],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    (ICON_FILE / "icon.json").write_text(json.dumps(icon, indent=2) + "\n", encoding="utf-8")
    print("wrote", ICON_FILE)


LOGOS.mkdir(parents=True, exist_ok=True)
for dark, suffix in [(False, ""), (True, "-dark")]:
    # The app's own logo (56 pt, at 3x), in the More tab and on the welcome screen.
    draw(dark).resize((168, 168), Image.LANCZOS).save(LOGOS / f"logo{suffix}.png")
    print("wrote", LOGOS / f"logo{suffix}.png")
write_glass_icon()
