# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: phi-golden.awk
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# fibonacci tiling + golden spiral, drawn in braille (2x4 dots per cell).
# phi-mark runs this; you don't call it directly.
#
#   -v n=8 -v k=2         number of squares, dots per fibonacci unit
#   -v tc=1|0|-1          truecolor, 256 colour, no colour
#   -v mode=static        print the finished picture, txt pasted on the right
#   -v mode=anim          print cursor moves, "@" between frames, so the
#                         caller can sleep and it builds up square by square
#   -v orow=1 -v ocol=1   top-left corner on screen (anim only)
#
# needs LC_ALL=C so %c writes raw utf-8 bytes on gawk and mawk alike.

function paint(r, layer,   t) {
    if (tc < 0) return ""
    # squares stay bronze, the spiral fades amber -> deep gold top to bottom
    if (layer == 1) return tc ? "\033[38;2;104;86;46m" : "\033[38;5;58m"
    t = rows > 1 ? r / (rows - 1) : 0
    if (!tc) return t < 0.5 ? "\033[38;5;220m" : "\033[38;5;178m"
    return sprintf("\033[38;2;%d;%d;%dm", 255 - t * 71, 214 - t * 80, 102 - t * 91)
}

# U+2800 + mask, spelled out as utf-8
function glyph(m) { return sprintf("%c%c%c", 226, 160 + int(m / 64), 128 + m % 64) }

function dot(x, y, layer,   px, py, cx, cy, key, bit) {
    px = int((x - x0) * k + 0.5)
    py = int((y1 - y) * k + 0.5)
    cx = int(px / 2); cy = int(py / 4)
    bit = BIT[px % 2, py % 4]
    key = cy SUBSEP cx
    if (int(M[key] / bit) % 2 == 0) M[key] += bit
    else if (L[key] >= layer) return
    if (layer > L[key]) L[key] = layer
    if (mode != "anim") return
    printf "\033[%d;%dH%s%s\n", orow + cy, ocol + cx, paint(cy, L[key]), glyph(M[key])
    if (++drawn % batch == 0) print "@"
}

function square(i,   s, t, steps, f) {
    s = F[i]
    if (s * k < 6) return # the tiny middle squares are just noise in braille
    steps = s * k
    for (t = 0; t <= steps; t++) {
        f = t / steps * s
        dot(SX[i] + f, SY[i], 1); dot(SX[i] + f, SY[i] + s, 1)
        dot(SX[i], SY[i] + f, 1); dot(SX[i] + s, SY[i] + f, 1)
    }
}

function arc(i,   s, d, cx, cy, a, t, steps, th) {
    s = F[i]; d = i % 4
    # centre corner + start angle depend on which side the square was added
    if (d == 0)      { cx = SX[i] + s; cy = SY[i] + s; a = 180 }
    else if (d == 1) { cx = SX[i];     cy = SY[i] + s; a = 270 }
    else if (d == 2) { cx = SX[i];     cy = SY[i];     a = 0 }
    else             { cx = SX[i] + s; cy = SY[i];     a = 90 }
    steps = int(s * k * 2) + 4
    for (t = 0; t <= steps; t++) {
        th = (a + 90 * t / steps) * PI / 180
        dot(cx + s * cos(th), cy + s * sin(th), 2)
    }
}

BEGIN {
    PI = atan2(0, -1)
    if (!n) n = 8
    if (!k) k = 2
    if (!batch) batch = 6
    if (!orow) orow = 1
    if (!ocol) ocol = 1
    BIT[0, 0] = 1; BIT[0, 1] = 2; BIT[0, 2] = 4; BIT[0, 3] = 64
    BIT[1, 0] = 8; BIT[1, 1] = 16; BIT[1, 2] = 32; BIT[1, 3] = 128

    F[0] = 1; F[1] = 1
    for (i = 2; i < n; i++) F[i] = F[i - 1] + F[i - 2]

    # grow the box: each new square goes right, up, left, down in turn
    SX[0] = 0; SY[0] = 0; x0 = 0; y0 = 0; x1 = 1; y1 = 1
    for (i = 1; i < n; i++) {
        s = F[i]; d = i % 4
        if (d == 1)      { SX[i] = x1;     SY[i] = y0;     x1 += s }
        else if (d == 2) { SX[i] = x0;     SY[i] = y1;     y1 += s }
        else if (d == 3) { SX[i] = x0 - s; SY[i] = y1 - s; x0 -= s }
        else             { SX[i] = x0;     SY[i] = y0 - s; y0 -= s }
    }
    cols = int((x1 - x0) * k / 2) + 1
    rows = int((y1 - y0) * k / 4) + 1

    if (mode == "size") { print cols, rows; exit }

    for (i = 0; i < n; i++) { square(i); arc(i) }
    if (mode == "anim") { print "@"; exit }

    nt = split(txt, T, "\n")
    reset = tc < 0 ? "" : "\033[0m"
    for (r = 0; r < rows; r++) {
        line = ""
        for (c = 0; c < cols; c++) {
            key = r SUBSEP c
            # empty cells get the blank braille char, not a space. fonts
            # without braille fall back to one where it's narrower than a
            # space, and mixing the two skews every row differently
            line = line (M[key] ? paint(r, L[key]) glyph(M[key]) : glyph(0))
        }
        tr = r - trow + 1
        print line reset ((tr >= 1 && tr <= nt) ? "    " T[tr] reset : "")
    }
}
