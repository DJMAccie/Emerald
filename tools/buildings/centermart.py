#!/usr/bin/env python3
"""Pokemon Center / Poke Mart model (data/buildings/pokemon_center.lua, poke_mart.lua).

Hand-designed shape, painted from the building's own drawing (64x64, four tile rows):
  * a box 64 wide and D deep with 45-degree chamfered corners, walls HW high;
  * a steep mansard band (the red / dark-blue band with the emblem) on ALL four sides;
  * a flat striped top, and where the drawing has a pediment (the Center) a raised
    barrel running front to back behind it, closed by the pediment at both ends.
The front is painted by the oblique rule (screen row = height + depth), one drawing
row per riser or tread, so the play camera sees the drawing; the sides and the back
take the band's and the wall's own rows at the same heights; the top repeats the
drawing's stripe rows to the back.
  python3 tools/buildings/centermart.py [--depth 48] [--preview out.png]
Needs tools from the scratch art reader: the QA cache's native tileset atlases.
"""
import argparse, os, re, sys, zlib, glob, struct
from collections import Counter
from PIL import Image

NATIVE = os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/')
DATA = os.path.expanduser('~/Documents/battle-art-notquiteog/data/buildings/')
W, HW, CH = 64, 25, 7            # width, wall height, corner chamfer
STEPS = [28, 31, 34, 36]         # mansard height after each px in from the edge
TOP = 36


def atlas(pair):
    d = NATIVE + pair
    raw = open(d + '/mids.idx', 'rb').read()
    raw = raw if raw[:4] == b'SVMI' else zlib.decompress(raw)
    count, cols, rows = struct.unpack_from('<HHH', raw, 6)
    ids = struct.unpack_from('<%dH' % count, raw, 12)
    w, h = cols * 16, rows * 16

    def rd(p):
        b = open(p, 'rb').read()
        return b if len(b) == w * h * 4 else zlib.decompress(b)
    u = Image.frombytes('RGBA', (w, h), rd(glob.glob(d + '/atlas_u_*.rgba')[0]))
    ov = glob.glob(d + '/atlas_o_*.rgba')
    o = Image.frombytes('RGBA', (w, h), rd(ov[0])) if ov else None
    return u, o, {m: i for i, m in enumerate(ids)}, cols


def compose(name):
    s = open(DATA + name + '.lua').read()
    pair = re.search(r"pair='([^']+)'", s).group(1)
    t = re.search(r"tiles=\{(.*?)\}\},", s, re.S).group(1)
    tiles = [tuple(int(x) for x in m) for m in re.findall(r'\{(\d+),(\d+),(\d+)', t)]
    u, o, slot, cols = atlas(pair)
    im = Image.new('RGBA', (64, 64))
    for dx, dy, mid in tiles:
        k = slot[mid]
        box = (k % cols * 16, k // cols * 16, k % cols * 16 + 16, k // cols * 16 + 16)
        im.paste(u.crop(box), (dx * 16, dy * 16))
        if o:
            c = o.crop(box); im.paste(c, (dx * 16, dy * 16), c)
    g = slot[1]
    ground = set(u.crop((g % cols * 16, g // cols * 16, g % cols * 16 + 16, g // cols * 16 + 16)).convert('RGB').getdata())
    return im.convert('RGB'), ground, s


def build(name, D):
    im, ground, src = compose(name)
    px = im.load()
    # background: ground colours connected to the picture's edge
    bg = [[False] * 64 for _ in range(64)]
    stack = [(x, y) for x in range(64) for y in (0, 63)] + [(x, y) for y in range(64) for x in (0, 63)]
    while stack:
        x, y = stack.pop()
        if 0 <= x < 64 and 0 <= y < 64 and not bg[y][x] and px[x, y] in ground:
            bg[y][x] = True
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    top = [next((y for y in range(64) if not bg[y][x]), 63) for x in range(64)]
    low = [next((y for y in range(63, -1, -1) if not bg[y][x]), 0) for x in range(64)]
    lum = lambda c: .3 * c[0] + .59 * c[1] + .11 * c[2]
    band = px[10, 26]                       # the band's own colour

    def ref(y, xs):                         # pixel of row y with the row's commonest colour over xs
        cnt = Counter(px[x, y] for x in xs if not bg[y][x])
        if not cnt: return (xs[0], y)
        c = cnt.most_common(1)[0][0]
        return (next(x for x in xs if px[x, y] == c and not bg[y][x]), y)
    bandRef = {y: ref(y, range(8, 15)) for y in range(64)}
    wallRef = {y: ref(y, range(1, 6)) for y in range(64)}
    # the pediment: rows above the band (y 23 upward) that are still band-coloured or outline
    ped = [0] * 64
    for x in range(16, 48):
        n = 0
        while 23 - n > top[x] and (px[x, 23 - n] == band or lum(px[x, 23 - n]) < 110):
            n += 1
        ped[x] = n if n < 12 else 0
    # a pediment is one closed shape: keep it only where it is a run with a real apex
    if max(ped) < 4: ped = [0] * 64
    else:
        xs = [x for x in range(64) if ped[x] > 0]
        for x in range(64):
            if x < min(xs) or x > max(xs): ped[x] = 0
            elif ped[x] == 0: ped[x] = 1

    def inset(x, z):                        # distance in from the plan's edge, and which edge limits it
        c = [(z + .5, 'front'), (D - z - .5, 'back'), (x + .5, 'side'), (W - x - .5, 'side')]
        for dx, dz in ((x, z), (W - 1 - x, z), (x, D - 1 - z), (W - 1 - x, D - 1 - z)):
            c.append(((dx + dz + 1 - CH) * .75, 'corner'))
        return min(c)

    H = [[0] * D for _ in range(64)]; EDGE = [[None] * D for _ in range(64)]
    for x in range(64):
        for z in range(D):
            e, edge = inset(x, z)
            if e <= 0: continue
            k = int(e)
            h = STEPS[k] if k < len(STEPS) else TOP
            if k >= len(STEPS) and ped[x] and 4 <= z < D - 4: h = TOP + ped[x]
            H[x][z] = h; EDGE[x][z] = edge if k < len(STEPS) else 'top'
    Hat = lambda x, z: H[x][z] if 0 <= x < 64 and 0 <= z < D else 0

    def wallPaint(x, h, own):
        y = 63 - h
        if own:
            return (x, y) if not bg[y][x] else (x, low[x])
        return wallRef[y]

    def bandPaint(h, tread):               # the band at height h, by the front's own step order
        if h < HW: return None
        prev, k = HW, 0
        for k, s in enumerate(STEPS):
            if h < s or (tread and h == s): break
            prev = s
        if tread: return bandRef[38 - (h - HW) - k]
        return bandRef[38 - (h - HW) - k]

    quads = []
    # (last value: a shade in percent that replaces the face's own, 0 = none. A chamfered corner is a
    # stair of south and west faces: with their own shades it stood as a fan of light and dark slats)
    add = lambda f, x0, x1, h0, h1, z0, z1, p, sh=0: quads.append((f, x0, x1, h0, h1, -z0, -z1, p[0], p[1], sh))
    corner = lambda x, z: 80 if min(x + z, W - 1 - x + z) < CH + 1 else 72 if min(x + D - 1 - z, W - 1 - x + D - 1 - z) < CH + 1 else 0
    rx = lambda x: max(CH, min(W - 1 - CH, x))   # the corner facets' own roof pixels carry outline strokes
    stripe0 = lambda x, n: (x, top[x] + 1 + n % max(1, min(6, (23 - ped[x]) - top[x] - 1)))
    stripe = lambda x, n: stripe0(rx(x), n)
    for x in range(64):
        r, n, started = 38, 0, False
        for z in range(D):
            h = H[x][z]
            if h == 0: continue
            hp = Hat(x, z - 1)
            edge = EDGE[x][z]
            path = edge in ('front', 'top') and rx(x) == x
            cs = corner(x, z)
            # south risers
            for hh in range(hp, h):
                if hh < HW: p = wallPaint(x, hh, z < D // 2)
                elif path:
                    if r > top[x]: p = (x, r); r -= 1
                    else: p = stripe(x, n); n += 1
                else: p = bandPaint(hh, False)
                add(1, x, x + 1, hh, hh + 1, z, z, p, cs if hh < HW else 0)
            # top
            if path and h >= HW and hp <= h:
                if r > top[x]: p = (x, r); r -= 1
                else: p = stripe(x, n); n += 1
            elif h >= TOP: p = stripe(x, n); n += 1
            else: p = bandPaint(h, True)
            add(3, x, x + 1, h, h, z + 1, z, p)
            # north risers
            hn = Hat(x, z + 1)
            for hh in range(hn, h):
                if hh < HW: p = wallPaint(x, hh, False)
                elif hh >= TOP: p = (x, 23 - (hh - TOP)) if ped[x] else stripe(x, hh)
                else: p = bandPaint(hh, False)
                add(2, x, x + 1, hh, hh + 1, z + 1, z + 1, p, cs if hh < HW else 0)
            # west and east
            for f, nx, xe in ((5, x - 1, x), (4, x + 1, x + 1)):
                hs = Hat(nx, z)
                for hh in range(hs, h):
                    if hh < HW: p = wallPaint(x, hh, z < CH and cs > 0)
                    elif hh >= TOP: p = stripe(x, hh + z)
                    else: p = bandPaint(hh, False)
                    add(f, xe, xe, hh, hh + 1, z + 1, z, p, cs if hh < HW else 0)
    return quads, src, im, H


def write(name, quads, src):
    head = src[:src.index('quads={') + 7]
    head = re.sub(r'-- generated by[^\n]*', '-- generated by tools/buildings/centermart.py (hand-designed shape, painted from the drawing)', head, 1)
    out, line = [], ' '
    for q in quads:
        t = ','.join(str(v) for v in q) + ','
        if len(line) + len(t) > 150: out.append(line); line = '  '
        line += t
    out.append(line)
    open(DATA + name + '.lua', 'w').write(head + '\n' + '\n'.join(out) + '\n }}\n')


def preview(models, path):
    """four orthographic looks: play camera (oblique from the south), from the west, the north, above"""
    S = 4
    tiles = []
    for quads, src, im, H in models:
        px = im.load()
        D = len(H[0])
        def col(p, s): c = px[p[0], p[1]]; return tuple(int(v * s) for v in c)
        views = []
        for mode in ('south', 'north', 'west', 'east', 'top'):
            cv = Image.new('RGB', (130, 130), (150, 200, 240)); zb = {}
            def put(u, v, d, c):
                if 0 <= u < 130 and 0 <= v < 130 and zb.get((u, v), -1e9) < d: zb[(u, v)] = d; cv.putpixel((u, v), c)
            for f, x0, x1, h0, h1, z0, z1, a, b, _ in quads:
                z0, z1 = -z0, -z1
                sh = {1: .9, 2: .68, 3: 1, 4: .84, 5: .72}[f]
                c = col((a, b), sh)
                if f == 3: x, y, z = x0 + .5, h0, min(z0, z1) + .5
                elif f in (1, 2): x, y, z = x0 + .5, h0 + .5, z0
                else: x, y, z = x0, h0 + .5, min(z0, z1) + .5
                if mode == 'south' and f in (1, 3): put(int(x) + 30, int(110 - y - z + (0 if f == 3 else .5)), -z + y * .01, c)
                if mode == 'north' and f in (2, 3): put(int(64 - x) + 30, int(60 - y + z + (0 if f == 3 else .5)), z + y * .01, c)
                if mode == 'west' and f in (5, 3): put(int(D - z) + 30 + int(x * .0), int(110 - y - x + (0 if f == 3 else .5)), -x + y * .01, c)
                if mode == 'east' and f in (4, 3): put(int(z) + 30, int(46 - y + x + (0 if f == 3 else .5)), x + y * .01, c)
                if mode == 'top' and f == 3: put(int(x) + 30, int(90 - z), y, c)
            views.append(cv.resize((130 * S, 130 * S), Image.NEAREST))
        tiles.append(views)
    sheet = Image.new('RGB', (130 * S * 5, 130 * S * len(tiles)))
    for j, row in enumerate(tiles):
        for i, v in enumerate(row): sheet.paste(v, (i * 130 * S, j * 130 * S))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--depth', type=int, default=48); ap.add_argument('--preview'); ap.add_argument('--dry', action='store_true')
    a = ap.parse_args()
    ms = []
    for name in ('pokemon_center', 'poke_mart'):
        q, src, im, H = build(name, a.depth)
        ms.append((q, src, im, H))
        if not a.dry: write(name, q, src)
        print(name, len(q), 'quads', 'max height', max(max(r) for r in H))
    if a.preview: preview(ms, a.preview)
