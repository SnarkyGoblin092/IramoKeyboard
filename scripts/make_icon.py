#!/usr/bin/env python3
"""Draws the 1024x1024 app icon (a few keyboard keys). Needs Pillow:  pip install pillow"""
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
out = Path(__file__).resolve().parent.parent / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "icon.png"

img = Image.new("RGB", (SIZE, SIZE), (24, 32, 56))
draw = ImageDraw.Draw(img)

# subtle vertical gradient background
for y in range(SIZE):
    t = y / (SIZE - 1)
    colour = (int(28 + 30 * t), int(40 + 50 * t), int(86 + 90 * t))
    draw.line([(0, y), (SIZE, y)], fill=colour)

key = (245, 247, 252)
accent = (255, 190, 60)
gap, radius = 28, 54
rows = [(4, 0.0), (3, 0.5), (4, 0.0)]
key_w, key_h = 150, 150
total_h = len(rows) * key_h + (len(rows) - 1) * gap
top = (SIZE - total_h) // 2 - 70
for r, (count, offset) in enumerate(rows):
    row_w = count * key_w + (count - 1) * gap
    left = (SIZE - row_w) // 2
    y = top + r * (key_h + gap)
    for i in range(count):
        x = left + i * (key_w + gap)
        draw.rounded_rectangle([x, y + 10, x + key_w, y + key_h + 10], radius=radius, fill=(10, 16, 36))
        fill = accent if (r == 1 and i == 1) else key
        draw.rounded_rectangle([x, y, x + key_w, y + key_h], radius=radius, fill=fill)

# space bar
sw = 4 * key_w + 3 * gap
sx = (SIZE - sw) // 2
sy = top + 3 * (key_h + gap)
draw.rounded_rectangle([sx, sy + 10, sx + sw, sy + 110], radius=radius, fill=(10, 16, 36))
draw.rounded_rectangle([sx, sy, sx + sw, sy + 100], radius=radius, fill=key)

out.parent.mkdir(parents=True, exist_ok=True)
img.save(out)
print("wrote", out)
