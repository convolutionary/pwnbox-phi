#!/usr/bin/env python3
# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: make-art.py
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
"""renders the pwnbox-phi boot splashes and wallpaper.

same geometry as phi-golden.awk (fibonacci squares, quarter-arc spiral),
drawn as vectors with pillow instead of braille. no fonts, so nothing
licensed ends up baked into the pngs.

    python3 phi/art/make-art.py          # writes next to this file
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
BG = (12, 11, 9)
BRONZE = (104, 86, 46)
DEEP = (184, 134, 11)
AMBER = (255, 214, 102)


def fib_layout(n: int) -> tuple[list[tuple[int, int, int]], tuple[int, int, int, int]]:
    """squares as (x, y, side), y pointing up, plus the bounding box"""
    f = [1, 1]
    while len(f) < n:
        f.append(f[-1] + f[-2])
    sq = [(0, 0, 1)]
    x0, y0, x1, y1 = 0, 0, 1, 1
    for i in range(1, n):
        s, d = f[i], i % 4
        if d == 1:
            sq.append((x1, y0, s)); x1 += s
        elif d == 2:
            sq.append((x0, y1, s)); y1 += s
        elif d == 3:
            sq.append((x0 - s, y1 - s, s)); x0 -= s
        else:
            sq.append((x0, y0 - s, s)); y0 -= s
    return sq, (x0, y0, x1, y1)


def arc_points(i: int, sq: tuple[int, int, int], steps: int) -> list[tuple[float, float]]:
    """same corner rule as the awk version"""
    x, y, s = sq
    d = i % 4
    cx, cy, a = {0: (x + s, y + s, 180), 1: (x, y + s, 270), 2: (x, y, 0), 3: (x + s, y, 90)}[d]
    return [(cx + s * math.cos(math.radians(a + 90 * t / steps)),
             cy + s * math.sin(math.radians(a + 90 * t / steps))) for t in range(steps + 1)]


def mix(c1: tuple[int, ...], c2: tuple[int, ...], t: float) -> tuple[int, ...]:
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def render(w: int, h: int, n: int, fill: float, dim: float, phi_mark: bool) -> Image.Image:
    """fill = share of the image height the rectangle takes,
    dim = brightness of the art (menus get drawn on top of the splashes)"""
    ss = 3  # supersample, then shrink for smooth lines
    W, H = w * ss, h * ss
    img = Image.new("RGB", (W, H), BG)
    sq, (x0, y0, x1, y1) = fib_layout(n)
    unit = H * fill / (y1 - y0)
    ox = (W - (x1 - x0) * unit) / 2
    oy = (H - (y1 - y0) * unit) / 2

    def px(x: float, y: float) -> tuple[float, float]:
        return ox + (x - x0) * unit, oy + (y1 - y) * unit

    lines = Image.new("RGB", (W, H), BG)
    ld = ImageDraw.Draw(lines)
    lw = max(1, int(1.2 * ss))
    for (x, y, s) in sq:
        if s * unit < 6 * ss:
            continue  # tiny middle squares turn to mush
        ld.rectangle([px(x, y + s), px(x + s, y)], outline=mix(BG, BRONZE, dim), width=lw)

    spiral = Image.new("RGB", (W, H), (0, 0, 0))
    sd = ImageDraw.Draw(spiral)
    total = sum(s for (_, _, s) in sq)
    walked = 0.0
    for i, s3 in enumerate(sq):
        pts = [px(*p) for p in arc_points(i, s3, max(24, int(s3[2] * 6)))]
        for j in range(len(pts) - 1):
            t = (walked + s3[2] * j / (len(pts) - 1)) / total
            col = mix(DEEP, AMBER, t ** 0.6)
            sd.line([pts[j], pts[j + 1]], fill=mix((0, 0, 0), col, dim), width=int((1.5 + 3.5 * t) * ss))
        walked += s3[2]

    glow = spiral.filter(ImageFilter.GaussianBlur(10 * ss)).point(lambda v: int(v * 0.55))
    img = Image.composite(lines, img, Image.new("L", (W, H), 255))
    img = Image.blend(img, Image.new("RGB", (W, H), BG), 0)
    from PIL import ImageChops
    img = ImageChops.add(img, glow)
    img = ImageChops.lighter(img, spiral)

    if phi_mark:
        # φ out of an ellipse and a stroke, bottom centre
        d = ImageDraw.Draw(img)
        cx, cy, r = W / 2, H * 0.92, H * 0.02
        col = mix(BG, AMBER, dim)
        d.ellipse([cx - r * 1.25, cy - r, cx + r * 1.25, cy + r], outline=col, width=int(1.6 * ss))
        d.line([(cx, cy - r * 1.9), (cx, cy + r * 1.9)], fill=col, width=int(1.6 * ss))

    return img.resize((w, h), Image.LANCZOS)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")  # windows consoles choke on ✓
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    jobs = {
        # grub on uefi draws its menu over this, so it stays dim
        "splash-efi.png": (1920, 1080, 10, 0.62, 0.45, True),
        # syslinux wants exactly 640x480
        "splash-bios.png": (640, 480, 10, 0.62, 0.40, True),
        "wallpaper-phi.png": (3840, 2160, 12, 0.66, 1.0, True),
    }
    fails = []
    for name, (w, h, n, fill, dim, mark) in jobs.items():
        img = render(w, h, n, fill, dim, mark)
        path = os.path.join(out, name)
        img.save(path, optimize=True)
        check = Image.open(path)
        if check.size != (w, h):
            fails.append(f"{name} came out {check.size}, wanted {(w, h)}")
        print(f"wrote {path} {w}x{h} {os.path.getsize(path) // 1024} KiB")
    for f in fails:
        print("✗", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
