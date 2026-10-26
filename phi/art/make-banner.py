#!/usr/bin/env python3
# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: make-banner.py
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
"""renders the pwnbox-phi hero banner (readme, socials).

every size is a power of φ times one length, a (the φ ring's half-width):
- emblem: a φ cut out of a sunflower, tearing apart on the right. seeds sit
  at the golden angle (137.508°), the ones inside the φ shape glow. ring a × a/φ, stroke
  reaching a·φ, sunflower radius a·φ, centred on the golden section w/φ
- wordmark: hand-made 6x7 pixel letters, 2a/φ³ tall, gaps of px·φ, no fonts
- right edge: the sunflower breaks up into falling dot columns
- bottom: particle waves; corners: brackets, dot grids, + + + marks

    python3 phi/art/make-banner.py        # writes banner.png (1618x1000) next to it
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
BG = (10, 9, 7)
DEEP = (150, 108, 18)
GOLD = (212, 175, 55)
AMBER = (255, 214, 102)
BRONZE = (104, 86, 46)
GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

GLYPHS = {
    "P": ["######", "#....#", "#....#", "######", "#.....", "#.....", "#....."],
    "W": ["#....#", "#....#", "#....#", "#.##.#", "#.##.#", "##..##", "#....#"],
    "N": ["#....#", "##...#", "#.#..#", "#..#.#", "#...##", "#....#", "#....#"],
    "B": ["#####.", "#....#", "#....#", "#####.", "#....#", "#....#", "#####."],
    "O": ["######", "#....#", "#....#", "#....#", "#....#", "#....#", "######"],
    "X": ["#....#", ".#..#.", "..##..", "..##..", "..##..", ".#..#.", "#....#"],
}
DIGITS = {  # 3x5, for the tiny φ readout
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", "###", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", "..#", "..#", "..#"],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
    ".": ["...", "...", "...", "...", ".#."], " ": ["...", "...", "...", "...", "..."],
}


def mix(a: tuple[int, ...], b: tuple[int, ...], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def dot(d: ImageDraw.ImageDraw, x: float, y: float, r: float, col: tuple[int, int, int]) -> None:
    d.ellipse([x - r, y - r, x + r, y + r], fill=col)


PHI = (1 + math.sqrt(5)) / 2


def wordmark(img: Image.Image, x0: int, y0: int, px: int, gap: int, rng: random.Random) -> int:
    """draws PWNBOX, returns the right edge"""
    layer = Image.new("RGB", img.size, (0, 0, 0))
    d = ImageDraw.Draw(layer)
    x = x0
    width = len("PWNBOX") * 6 * px + 5 * gap
    for ch in "PWNBOX":
        for r, row in enumerate(GLYPHS[ch]):
            for c, on in enumerate(row):
                if on != "#":
                    continue
                t = (x + c * px - x0) / width
                col = mix(DEEP, AMBER, 0.25 + 0.75 * t)
                d.rectangle([x + c * px, y0 + r * px, x + (c + 1) * px - 2, y0 + (r + 1) * px - 2], fill=col)
        x += 6 * px + gap
    x -= gap
    # thin scanlines through the letters, like a crt
    h = 7 * px
    for yy in range(y0 + 2, y0 + h, 4):
        d.line([(x0, yy), (x, yy)], fill=(0, 0, 0), width=1)
    # glitch: a few horizontal slices shoved sideways
    for _ in range(4):
        sy = rng.randint(y0, y0 + h - 6)
        sh = rng.randint(2, px // 3 + 2)
        dx = rng.choice([-1, 1]) * rng.randint(4, px)
        band = layer.crop((x0 - px * 3, sy, x + px * 3, sy + sh))
        layer.paste((0, 0, 0), (x0 - px * 3, sy, x + px * 3, sy + sh))
        layer.paste(band, (x0 - px * 3 + dx, sy))
    glow = layer.filter(ImageFilter.GaussianBlur(px * 0.9)).point(lambda v: int(v * 0.5))
    img.paste(ImageChops.lighter(ImageChops.add(img, glow), layer))
    return x


def tiny_text(d: ImageDraw.ImageDraw, text: str, x: int, y: int, px: int, col: tuple[int, int, int]) -> None:
    for ch in text:
        for r, row in enumerate(DIGITS.get(ch, DIGITS[" "])):
            for c, on in enumerate(row):
                if on == "#":
                    d.rectangle([x + c * px, y + r * px, x + (c + 1) * px - 1, y + (r + 1) * px - 1], fill=col)
        x += 4 * px


def tiny_width(text: str, px: int) -> int:
    return len(text) * 4 * px - px


# the φ glyph, all in units of a = the ring's half-width:
#   ring:   ellipse with semi-axes a and a/φ, a golden ellipse. the band's
#           inner edge is the same ellipse scaled by 1/√φ
#   stroke: half-width a/φ⁵, reaching a·φ above and below the centre
#   disc:   the sunflower around it has radius a·φ, so the stroke tips
#           touch its rim
def in_phi(x: float, y: float, a: float) -> bool:
    ring = (x / a) ** 2 + (y / (a / PHI)) ** 2
    if 1 / PHI < ring <= 1.0:
        return True
    return abs(x) < a / PHI**5 and abs(y) <= a * PHI


def emblem(d: ImageDraw.ImageDraw, cx: float, cy: float, a: float, rng: random.Random) -> None:
    """the φ sunflower, tearing apart on its right side.

    left of the break the seeds sit where the golden angle puts them. past
    it, each seed has a chance to come loose: it gets flung right, shrinks,
    and leaves a trail of smaller dots behind it, so the glyph looks like it
    is being pulled apart dot by dot"""
    R = a * PHI  # sunflower radius
    n = 2600
    pitch = R * math.sqrt(math.pi / n)  # average distance between seeds
    brk = cx + a / PHI**2  # where it starts coming apart
    reach = R + a          # how far the furthest seed gets thrown

    for i in range(n):
        rr = math.sqrt(i / n)
        th = i * GOLDEN_ANGLE
        x, y = cx + rr * R * math.cos(th), cy + rr * R * math.sin(th)
        lit = in_phi(x - cx, y - cy, a)
        base_r = pitch * (0.36 if lit else 0.13)
        if lit:
            col = mix(GOLD, AMBER, 1 - ((y - cy) / R + 1) / 2)
        else:
            col = mix(BG, BRONZE, 0.55 * (1 - rr) + 0.2)

        # 0 = intact, 1 = fully torn off. a bit of noise so the edge is ragged
        tear = max(0.0, min(1.0, (x - brk) / a + rng.uniform(-0.2, 0.2)))
        if tear <= 0 or rng.random() > tear ** 0.6:
            dot(d, x, y, base_r * (1 - 0.35 * tear), col)
            continue

        fling = tear * reach * rng.random() ** 1.3
        nx = x + fling
        ny = y + rng.gauss(0, 1) * tear * a * 0.12
        if tear > 1 / PHI:
            # the further gone, the more it falls into the column grid the
            # streams use, so the torn bits flow into them
            nx = cx + round((nx - cx) / (pitch * PHI)) * pitch * PHI
            # and once it's in a column it slides up or down it
            ny += rng.gauss(0, 1) * (tear - 1 / PHI) * a * PHI
        shrink = 1 - 0.75 * tear
        # trail between where it was and where it went, smallest at the tail
        steps = 2 + int(tear * 6)
        for s in range(1, steps + 1):
            t = s / (steps + 1)
            dot(d, x + (nx - x) * t, y + (ny - y) * t,
                base_r * shrink * (0.25 + 0.5 * t), mix(BG, col, 0.35 + 0.5 * t))
        dot(d, nx, ny, base_r * shrink, col)


def streams(d: ImageDraw.ImageDraw, cx: float, cy: float, a: float, w: int, h: int, rng: random.Random) -> None:
    """thin vertical dot lines behind the tear, densest right next to it,
    thinning out toward the edge. plus a few + sparks"""
    R = a * PHI
    pitch = R * math.sqrt(math.pi / 2600)
    x = cx + a / PHI
    while x < w - h / PHI**6:
        near = 1 - (x - cx) / (w - cx)  # 1 next to the emblem, 0 at the edge
        if rng.random() < 0.35 + 0.55 * near:
            top = rng.uniform(0, cy - R * near * 0.5)
            bottom = rng.uniform(cy + R * near * 0.3, h * (1 - 1 / PHI**4))
            gap = pitch * rng.choice([0.6, 0.8, 1.0, 1.3])
            y = top
            while y < bottom:
                if rng.random() < 0.55 + 0.35 * near:
                    r = 0.7 + 1.6 * near * rng.random()
                    dot(d, x, y, r, mix(BG, GOLD if rng.random() < 0.3 else BRONZE, 0.2 + 0.65 * near))
                y += gap
        x += pitch * rng.choice([0.6, 0.9, 1.2, 1.6])
    for _ in range(21):
        sx = rng.uniform(cx + a, w - h / PHI**6)
        sy = rng.uniform(h / PHI**5, h * (1 - 1 / PHI**3))
        s = rng.uniform(2, 4)
        col = mix(BG, AMBER, rng.uniform(0.4, 0.8))
        d.line([(sx - s, sy), (sx + s, sy)], fill=col, width=1)
        d.line([(sx, sy - s), (sx, sy + s)], fill=col, width=1)


def waves(d: ImageDraw.ImageDraw, w: int, h: int, horizon: float, rng: random.Random) -> None:
    """two twisting ribbons of particle strands rising to the right. each
    strand is the same curve nudged by a small phase step, so together they
    fold over like a ribbon instead of crossing at random"""
    for strands, lift, amp, seed_ph in ((21, 0.10, 0.055, 0.0), (13, 0.05, 0.035, 2.4)):
        for k in range(strands):
            u = k / (strands - 1)
            ph = seed_ph + u * 1.1
            for x in range(0, w, 4):
                t = x / w
                y = (horizon - h * lift * t ** 1.4
                     + h * amp * math.sin(t * 6.3 + ph) * (0.6 + 0.6 * t)
                     + h * amp * 0.45 * math.sin(t * 13.1 - ph * 1.7)
                     + (u - 0.5) * h * 0.012 * math.cos(t * 4.0 + ph))
                if rng.random() > 0.35 + 0.35 * t:
                    continue
                edge = 1 - abs(u - 0.5) * 2  # strands in the middle of the ribbon glow more
                bright = (0.08 + 0.6 * t ** 1.3) * (0.45 + 0.55 * edge)
                dot(d, x, y, 0.55 + 0.5 * t, mix(BG, GOLD if rng.random() < 0.2 else BRONZE, bright * 0.95))


def guides(d: ImageDraw.ImageDraw, w: int, h: int) -> None:
    """faint dotted lines on the golden sections, the grid everything sits on"""
    col = mix(BG, BRONZE, 0.35)
    for x in (w / PHI**2, w / PHI):
        for y in range(0, h, 7):
            d.point((int(x), y), fill=col)
    for y in (h / PHI**2, h / PHI):
        for x in range(0, w, 7):
            d.point((x, int(y)), fill=col)


def frame(d: ImageDraw.ImageDraw, w: int, h: int) -> None:
    m = h / PHI**6  # margin
    L = m / PHI      # bracket arm
    col = mix(BG, GOLD, 0.7)
    for (x, y, sx, sy) in ((m, m, 1, 1), (w - m, m, -1, 1), (m, h - m, 1, -1), (w - m, h - m, -1, -1)):
        d.line([(x, y), (x + sx * L, y)], fill=col, width=2)
        d.line([(x, y), (x, y + sy * L)], fill=col, width=2)
    s = m / PHI**3  # dot grid pitch
    for gy in (h / PHI**4, h - h / PHI**4 - 5 * s):
        for r in range(6):
            for c in range(3):
                dot(d, m + c * s, gy + r * s, 1.6, mix(BG, GOLD, 0.6))
    for (x, y) in ((m + L * PHI**2, h / PHI**4), (m + L * PHI**2, h - h / PHI**4)):
        for i in range(3):
            cx = x + i * L / PHI
            d.line([(cx - 5, y), (cx + 5, y)], fill=col, width=2)
            d.line([(cx, y - 5), (cx, y + 5)], fill=col, width=2)
        if y < h / 2:
            for i in range(40):
                dot(d, x + 3 * L / PHI + i * 6, y, 0.9, mix(BG, GOLD, 0.45))


def render(w: int, h: int, seed: int = 1618) -> Image.Image:
    rng = random.Random(seed)  # fixed seed, so re-rendering gives the same png
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)

    # the emblem is h/φ tall in total (stroke tip to tip = 2·a·φ), centred on
    # the golden section of the width and the middle of the height
    a = h / (2 * PHI**2)
    cx, cy = w / PHI, h / 2

    guides(d, w, h)
    waves(d, w, h, h * (1 - 1 / PHI**4), rng)
    streams(d, cx, cy, a, w, h, rng)
    emblem(d, cx, cy, a, rng)
    frame(d, w, h)

    # wordmark: letters 2a/φ³ tall, gaps of px·φ between them, centred in the
    # space left of the sunflower, on the same axis as the emblem
    px = max(4, round(2 * a / PHI**3 / 7))
    gap = round(px * PHI)
    word_w = 6 * 6 * px + 5 * gap
    room = cx - a * PHI - a / PHI  # left of the disc, minus one ring-height of air
    x0 = int(max(h / PHI**6 * PHI, (room - word_w) / 2))
    y0 = int(cy - 7 * px / 2)
    wordmark(img, x0, y0, px, gap, rng)

    d = ImageDraw.Draw(img)
    tpx = max(2, round(px / PHI**2))
    digits = "1.6180339887"
    tiny_text(d, digits, x0, int(y0 + 7 * px + 7 * px / PHI**2), tpx, mix(BG, AMBER, 0.75))
    return img


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")  # windows consoles choke on ✓
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    fails = []
    # one banner, and it's a golden rectangle itself: 1618 × 1000
    for name, (w, h) in {"banner.png": (1618, 1000)}.items():
        path = os.path.join(out, name)
        render(w, h).save(path, optimize=True)
        if Image.open(path).size != (w, h):
            fails.append(name)
        print(f"wrote {path} {w}x{h} {os.path.getsize(path) // 1024} KiB")
    # the maths the layout relies on, checked rather than trusted
    a = 100.0
    checks = {
        "ring is a golden ellipse": in_phi(a, 0, a) and in_phi(0, a / PHI, a) and not in_phi(a * 1.01, 0, a),
        "stroke tips at a·φ": in_phi(0, a * PHI, a) and not in_phi(0, a * PHI * 1.01, a),
        "inner edge at 1/√φ": not in_phi(a / math.sqrt(PHI) * 0.99, 0, a) and in_phi(a / math.sqrt(PHI) * 1.01, 0, a),
        "golden angle": abs(math.degrees(GOLDEN_ANGLE) - 137.5077640500378) < 1e-9,
        "banner is a golden rectangle": abs(1618 / 1000 - PHI) < 1e-3,
    }
    for name, ok in checks.items():
        if not ok:
            fails.append(name)
    for f in fails:
        print("✗", f)
    if not fails:
        print(f"✓ {len(checks)} geometry checks")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
