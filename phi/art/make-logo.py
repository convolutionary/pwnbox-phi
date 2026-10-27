#!/usr/bin/env python3
# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: make-logo.py
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
"""renders the phi logo for fastfetch: a golden rectangle cut into its
fibonacci squares, the spiral running through them, gold on transparent.
same geometry as phi-golden.awk, so it matches the braille art.

    python3 phi/art/make-logo.py    # writes dotfiles/config/fastfetch/pwnbox.png
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "dotfiles", "config", "fastfetch", "pwnbox.png")

GOLD = (212, 175, 55)
AMBER = (255, 196, 64)
BRONZE = (104, 86, 46)

SS = 4  # draw big, shrink, free anti-aliasing
FIB = [1, 1, 2, 3, 5, 8, 13, 21]  # ends on a left turn: landscape, like the wallpaper
UNIT = 24 * SS
PAD = 12 * SS


def squares():
    # lay the squares out the usual way: each new one goes right, down,
    # left, up of everything so far. returns (x, y, size, side) in units
    x0, y0, x1, y1 = 0, 0, 1, 1
    out = [(0, 0, 1, "start")]
    sides = ["right", "down", "left", "up"]
    for i, f in enumerate(FIB[1:]):
        side = sides[i % 4]
        if side == "right":
            out.append((x1, y0, f, side)); x1 += f
        elif side == "down":
            out.append((x0, y1, f, side)); y1 += f
        elif side == "left":
            out.append((x0 - f, y0, f, side)); x0 -= f
        else:
            out.append((x0, y0 - f, f, side)); y0 -= f
    return out, (x0, y0, x1, y1)


def main():
    sq, (x0, y0, x1, y1) = squares()
    w = (x1 - x0) * UNIT + 2 * PAD
    h = (y1 - y0) * UNIT + 2 * PAD
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def box(x, y, s):
        return ((x - x0) * UNIT + PAD, (y - y0) * UNIT + PAD,
                (x - x0 + s) * UNIT + PAD, (y - y0 + s) * UNIT + PAD)

    for x, y, s, _ in sq:
        d.rectangle(box(x, y, s), outline=BRONZE + (255,), width=2 * SS)

    # the quarter arc in each square, oriented by which side it was added on
    arc_of = {"start": (180, 270), "right": (270, 360), "down": (0, 90),
              "left": (90, 180), "up": (180, 270)}
    corner_of = {"start": (1, 1), "right": (0, 1), "down": (0, 0),
                 "left": (1, 0), "up": (1, 1)}
    n = len(sq)
    for i, (x, y, s, side) in enumerate(sq):
        cx, cy = corner_of[side]
        bx, by = x + cx * s, y + cy * s
        a0, a1 = arc_of[side]
        t = i / (n - 1)
        col = tuple(int(GOLD[k] + (AMBER[k] - GOLD[k]) * t) for k in range(3)) + (255,)
        d.arc(box(bx - s, by - s, 2 * s), a0, a1, fill=col, width=int((3 + 5 * t) * SS))

    img = img.resize((w // SS, h // SS), Image.LANCZOS)
    img.save(OUT)
    print(f"wrote {os.path.normpath(OUT)} {img.size}")


if __name__ == "__main__":
    main()
