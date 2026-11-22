#!/usr/bin/env python3
"""Draws the 1024x1024 app icon. Needs Pillow:  pip install pillow

    python scripts/make_icon.py

Writes TacticsBoard/Assets.xcassets/AppIcon.appiconset/icon.png (opaque, no alpha).
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 2                      # supersample for smooth edges
SIZE = 1024
W = SIZE * S

PITCH = (0x2E, 0x7D, 0x32)
STRIPE = (0x38, 0x8E, 0x3C)
WHITE = (255, 255, 255)
BLUE = (0x15, 0x65, 0xC0)
RED = (0xC6, 0x28, 0x28)
YELLOW = (0xFF, 0xEB, 0x3B)
BLACK = (0x21, 0x21, 0x21)


def p(v):
    return int(round(v * S))


img = Image.new("RGB", (W, W), PITCH)
d = ImageDraw.Draw(img)

# Mown stripes, in eighths
for i in range(8):
    if i % 2 == 1:
        d.rectangle([p(i * 128), 0, p((i + 1) * 128), W], fill=STRIPE)

# Markings: outline 90 px in, halfway line, centre circle radius 150
line = p(10)
d.rectangle([p(90), p(90), p(SIZE - 90), p(SIZE - 90)], outline=WHITE, width=line)
d.line([p(SIZE / 2), p(90), p(SIZE / 2), p(SIZE - 90)], fill=WHITE, width=line)
c, r = SIZE / 2, 150
d.ellipse([p(c - r), p(c - r), p(c + r), p(c + r)], outline=WHITE, width=line)

# Positions (in 1024 space)
passer = (300, 700)
receiver = (720, 330)
defender = (330, 300)
ball_at = (835, 445)
TOKEN_R = 95


def token(centre, colour):
    global img, d
    x, y = centre
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = 14
    sd.ellipse([p(x - TOKEN_R), p(y - TOKEN_R + off), p(x + TOKEN_R), p(y + TOKEN_R + off)],
               fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(p(12)))
    img = Image.alpha_composite(img.convert("RGBA"), shadow).convert("RGB")
    d = ImageDraw.Draw(img)
    d.ellipse([p(x - TOKEN_R), p(y - TOKEN_R), p(x + TOKEN_R), p(y + TOKEN_R)], fill=colour)
    ring = p(12)
    d.ellipse([p(x - TOKEN_R), p(y - TOKEN_R), p(x + TOKEN_R), p(y + TOKEN_R)],
              outline=WHITE, width=ring)


# Dashed pass arrow between the two blue players (drawn under the tokens)
ax, ay = passer
bx, by = receiver
angle = math.atan2(by - ay, bx - ax)
start = (ax + math.cos(angle) * (TOKEN_R + 10), ay + math.sin(angle) * (TOKEN_R + 10))
end = (bx - math.cos(angle) * (TOKEN_R + 50), by - math.sin(angle) * (TOKEN_R + 50))
length = math.hypot(end[0] - start[0], end[1] - start[1])
dash, gap = 46, 30
pos = 0.0
while pos < length:
    seg_end = min(pos + dash, length)
    x1 = start[0] + math.cos(angle) * pos
    y1 = start[1] + math.sin(angle) * pos
    x2 = start[0] + math.cos(angle) * seg_end
    y2 = start[1] + math.sin(angle) * seg_end
    d.line([p(x1), p(y1), p(x2), p(y2)], fill=YELLOW, width=p(16))
    pos += dash + gap
head_len, head_w = 70, 46
tip = (bx - math.cos(angle) * (TOKEN_R + 8), by - math.sin(angle) * (TOKEN_R + 8))
base = (tip[0] - math.cos(angle) * head_len, tip[1] - math.sin(angle) * head_len)
nx, ny = -math.sin(angle), math.cos(angle)
d.polygon([(p(tip[0]), p(tip[1])),
           (p(base[0] + nx * head_w), p(base[1] + ny * head_w)),
           (p(base[0] - nx * head_w), p(base[1] - ny * head_w))], fill=YELLOW)

token(passer, BLUE)
token(receiver, BLUE)
token(defender, RED)

# White ball with black dots, next to the receiving player
bxr, byr = ball_at
BR = 44
d.ellipse([p(bxr - BR), p(byr - BR), p(bxr + BR), p(byr + BR)], fill=WHITE, outline=BLACK, width=p(6))
d.regular_polygon((p(bxr), p(byr), p(15)), 5, rotation=0, fill=BLACK)
for k in range(5):
    a = math.radians(-90 + k * 72)
    dx, dy = math.cos(a) * 31, math.sin(a) * 31
    d.ellipse([p(bxr + dx - 7), p(byr + dy - 7), p(bxr + dx + 7), p(byr + dy + 7)], fill=BLACK)

out = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
target = os.path.join(os.path.dirname(__file__), "..", "TacticsBoard", "Assets.xcassets",
                      "AppIcon.appiconset", "icon.png")
out.save(target, "PNG")
print("wrote", os.path.normpath(target))
