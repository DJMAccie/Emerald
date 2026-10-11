#!/usr/bin/env python3
"""Levels of a cave's floors read from its drawing (user: "make the cave
floors have real height differences"). The cartridge rates most caves one
level; the art draws ledges, mesas and pits.

Evidence, per map column, walking north from a floor cell S across blocked
cells to the next floor cell N:
  only FACE tiles between them (the dark drawn front of a ledge, k rows):
      N stands k levels above S (a terrace front);
  face tiles then lighter LID tiles: a free-standing ridge, N level with S;
  only lid tiles (a ledge's back rim): N is somewhere below S -- no number.
Stairs (stair_platforms) join floors too: the north floor is one level up per
stair row. Votes are counted per pair of floors; levels spread from the
biggest floor. A level is one row of face art (16 px).

python3 cave_levels.py MAP PAIR [--png out.png]"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'buildings')); sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
import stair_platforms as sp
import collections

MAXFACE = 2          # more face rows than this in one column is rock fill, not a ledge front
_faces = {}

def face_tiles(pair, floor_mid):
    """A face tile is mostly darker than the cave's floor (dark = under .72 of
    the floor tile's mean brightness: Mirage Tower's sand walls are light)."""
    if (pair, floor_mid) in _faces: return _faces[(pair, floor_mid)]
    import bldmodel as M, layers
    L = layers.load(pair); cache = {}
    def lum(mid):
        t = M.voxproto.art(L, mid)[..., :3].astype(float) / 255
        return .299 * t[..., 0] + .587 * t[..., 1] + .114 * t[..., 2]
    try: cut = min(.5, .72 * float(lum(floor_mid).mean()))
    except Exception: cut = .42
    def is_face(mid):
        if mid not in cache:
            try:
                l = lum(mid)
                cache[mid] = bool((l < cut).mean() >= .5) and bool((l > .04).any())
            except Exception:
                cache[mid] = False
        return cache[mid]
    _faces[(pair, floor_mid)] = is_face
    return is_face

def levels(mp, pair, stair_mids):
    W, H, cells, comps, comp, edges, _, _, _ = sp.analyse(mp, stair_mids, True)
    walkmids = collections.Counter(cells[y * W + x] & 0x3ff for (x, y) in comp)
    is_face = face_tiles(pair, walkmids.most_common(1)[0][0] if walkmids else 0)
    blocked = lambda x, y: (cells[y * W + x] >> 10) & 3 != 0
    up = collections.defaultdict(collections.Counter); eq = collections.Counter()
    for (x, y), a in comp.items():
        k = y - 1; kinds = []
        while k >= 0 and blocked(x, k):
            kinds.append(is_face(cells[k * W + x] & 0x3ff)); k -= 1
        if not kinds or k < 0 or (x, k) not in comp: continue
        b = comp[(x, k)]
        if b == a: continue
        # (a pocket of one or two cells in the rock is no terrace: it takes
        # the level of the floor nearest it; stairs still count)
        if len(comps[a]) <= 2 or len(comps[b]) <= 2: continue
        f = 0
        while f < len(kinds) and kinds[f]: f += 1
        lids = len(kinds) - f
        if f >= 1 and lids == 0 and f <= MAXFACE: up[(a, b)][f] += 1
        elif f >= 1 and lids >= 1 and not any(kinds[f:]): eq[(min(a, b), max(a, b))] += 1
    links = []                                   # (votes, low, high, rise)
    for (a, b), c in up.items():
        n, votes = c.most_common(1)[0]
        if votes >= eq[(min(a, b), max(a, b))]: links.append((sum(c.values()), a, b, n))
    for (a, b), votes in eq.items():
        if votes > sum(up[(a, b)].values()) + sum(up[(b, a)].values()): links.append((votes, a, b, 0))
    for upc, down, n, _ in edges: links.append((1000, down, upc, n))
    links.sort(key=lambda l: -l[0])
    # join floors link by link, strongest evidence first (stairs, then the
    # most-voted drawn fronts); a link between floors already joined is
    # dropped, so a staircase is never overruled by a look across the rock
    lv = {}
    if comps:
        group = {k: k for k in range(len(comps))}; off = {k: 0 for k in range(len(comps))}   # level = off + level of group root
        members = {k: [k] for k in range(len(comps))}
        for _, a, b, n in links:
            ra, rb = group[a], group[b]
            if ra == rb: continue
            d = off[a] + n - off[b]                # shift for b's group so that b = a + n
            for k in members[rb]: off[k] += d; group[k] = ra
            members[ra] += members.pop(rb)
        base = max(range(len(comps)), key=lambda k: len(comps[k])); root = group[base]
        for k in members[root]: lv[k] = off[k]
        # floors nothing links to the main one: their own group, set level
        # with the nearest floor already placed
        rest = [r for r in members if r != root]
        rest.sort(key=lambda r: -sum(len(comps[k]) for k in members[r]))
        for r in rest:
            best = None
            for k in members[r]:
                for x, y in comps[k]:
                    for (px, py), j in comp.items():
                        if j in lv:
                            # (a floor in the same row first: boulders and rock part a row's cells, rows are levels)
                            d = abs(px - x) + 2.5 * abs(py - y)
                            if best is None or d < best[0]: best = (d, lv[j] - off[k])
            sh = best[1] if best else 0
            for k in members[r]: lv[k] = off[k] + sh
        lo = min(lv.values())
        for k in lv: lv[k] -= lo
    stairs = sorted({p for e in edges for p in e[3]})
    return W, H, cells, comps, comp, lv, stairs

if __name__ == '__main__':
    mp, pair = sys.argv[1], sys.argv[2]
    import gen_stair_terraces as g
    W, H, cells, comps, comp, lv, stairs = levels(mp, pair, g.CAVE_STAIRS.get(pair, set()))
    print(mp, 'floors', len(comps), 'levels', sorted(set(lv.values())), 'stairs', len(stairs))
    if '--png' in sys.argv:
        import bldmodel as M
        from PIL import Image, ImageDraw
        a = M.compose(pair, mp, 0, 0, W - 1, H - 1)
        im = Image.fromarray(a).convert('RGB').resize((W * 32, H * 32), Image.NEAREST)
        ov = Image.new('RGBA', im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
        col = [(0, 0, 255), (0, 200, 0), (255, 220, 0), (255, 120, 0), (255, 0, 0), (255, 0, 255), (255, 255, 255), (0, 255, 255)]
        for (x, y), k in comp.items():
            c = col[min(lv[k], len(col) - 1)]
            d.rectangle((x * 32 + 10, y * 32 + 10, x * 32 + 22, y * 32 + 22), fill=c + (200,))
            d.text((x * 32 + 12, y * 32 + 10), str(lv[k]), fill=(0, 0, 0, 255))
        for x, y in stairs: d.rectangle((x * 32 + 4, y * 32 + 4, x * 32 + 28, y * 32 + 28), outline=(255, 255, 255, 255))
        Image.alpha_composite(im.convert('RGBA'), ov).convert('RGB').save(sys.argv[sys.argv.index('--png') + 1])
