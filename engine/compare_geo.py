#!/usr/bin/env python3
"""Compare two geometry dumps (em_geo_driver.lua format, in-game or headless).

  compare_geo.py A.geo.gz B.geo.gz [--lib RC_LIB] [--all] [--top 20] [--json OUT]

Reports, for A and B:
  * triangles per mesh kind (kind = the upload('<kind>') of Gen3Scene's field meshes, read from the rc source
    like tools/autoloop/detect.py does, else file:line of the newMesh caller);
  * an order-independent checksum of the triangle multiset (coordinates as written, i.e. rounded to 0.1 px;
    each triangle rotated to start at its smallest corner, winding kept), with and without the mesh kind;
  * the cells (centroid cell = floor(x/16), floor(z/16), as the driver assigns them) where the sets differ,
    top N by number of differing triangles;
  * the .cells files next to the dumps: lines only in A / only in B, and the first differing cells.
Draw-time meshes (made while a frame is drawn: sprite cards fn=actor, field effect cards fn=effect, ride dust, landmark models
SpriteVoxel<LandmarkModels, rock/ball/boat models Gen3RockSprites) and tree prototypes (NativeTreeArt.addInstance:
one model per tree card, instanced at draw time, made in whichever build first needs it) are in model space at the
origin (field effects in world space), not built scene geometry: they are listed apart and left out of the scene
checksum unless --all.
Exit code 0 when the scene triangle sets and the .cells lines are identical, 1 otherwise.
"""
import argparse
import collections
import gzip
import hashlib
import json
import os
import re
import sys

DEFAULT_LIB = os.path.expanduser('~/Documents/Emerald/.autoloop/rc/lib')
MASK = (1 << 64) - 1
DRAW_FNS = {'actor', 'effect', 'rideDust', 'fieldEffects', 'actors'}


def source_lines(libdir):
    out = {}
    if libdir and os.path.isdir(libdir):
        for n in os.listdir(libdir):
            if n.endswith('.lua'):
                with open(os.path.join(libdir, n), encoding='utf-8', errors='replace') as f:
                    out[n] = f.read().split('\n')
    return out


def tag_kind(src, tag, fn):
    m = re.match(r'([^:]+):(\d+)<([^:]+):(\d+)', tag)
    if not m:
        return tag
    f1, l1, f2, l2 = m.group(1), int(m.group(2)), m.group(3), int(m.group(4))
    if fn in DRAW_FNS:
        # made while a frame is drawn (Gen3Scene actor(), fieldEffects' effect(), rideDust()), not by the build
        return 'draw:' + fn
    if 'LandmarkModels' in tag or f1 == 'SpriteVoxel.lua':
        return 'draw:landmark'
    if f1 == 'Gen3RockSprites.lua' or f2 == 'Gen3RockSprites.lua':
        return 'draw:rocksprite'
    s2 = src.get(f2)
    if s2 and 0 < l2 <= len(s2):
        k = re.search(r"upload\('(\w+)'", s2[l2 - 1])
        if k:
            return k.group(1)
    s1 = src.get(f1)
    if s1 and 0 < l1 <= len(s1):
        line = s1[l1 - 1]
        if 'cache.wood' in line or 'cache.leaves' in line:
            return 'tree'
        if 'part.waters' in line:
            return 'water'
    if f1 == 'NativeTreeArt.lua':
        # NativeTreeArt.addInstance: a tree prototype in model space at the origin, instanced at draw time;
        # made once per tree card and detail (a weak cache), so which build's group holds it varies
        return 'proto:treeModel'
    if f1 == 'Gen3Lamp.lua':
        return 'lamp'
    return '%s:%d' % (f1, l1)


def load(path, src):
    head, tags, tris = {}, {}, []
    with gzip.open(path, 'rt') as f:
        for line in f:
            if line.startswith('T '):
                p = line.split()
                tris.append((int(p[1]), tuple(p[2:11])))
            elif line.startswith('TAG '):
                p = line.split()
                tags[int(p[1])] = {'tag': p[2], 'fn': p[3], 'meshes': int(p[4]), 'verts': int(p[5])}
            elif line.startswith('MAP '):
                p = line.split()
                head = {'map': p[1], 'W': int(p[2]), 'H': int(p[3])}
    kinds = {t: tag_kind(src, v['tag'], v['fn']) for t, v in tags.items()}
    out = []
    for t, c in tris:
        v = [c[0:3], c[3:6], c[6:9]]
        # canonical rotation: smallest corner first (numeric), winding kept
        key = [tuple(float(x) for x in q) for q in v]
        i = min(range(3), key=lambda j: key[j])
        v = v[i:] + v[:i]
        g = ' '.join(' '.join(q) for q in v)
        cx = int((float(c[0]) + float(c[3]) + float(c[6])) // 48)
        cz = int((float(c[2]) + float(c[5]) + float(c[8])) // 48)
        out.append((kinds.get(t, '?'), g, (cx, cz)))
    return head, tags, kinds, out


def h64(s):
    return int.from_bytes(hashlib.blake2b(s.encode(), digest_size=8).digest(), 'little')


def checksum(items):
    s = 0
    for it in items:
        s = (s + h64(it)) & MASK
    return '%016x' % s


def load_cells(path):
    try:
        with open(path) as f:
            return [l.rstrip('\n') for l in f if l.strip()]
    except FileNotFoundError:
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('a')
    ap.add_argument('b')
    ap.add_argument('--lib', default=DEFAULT_LIB, help='rc lib dir, for mesh kind names')
    ap.add_argument('--all', action='store_true', help='keep draw-time meshes in the scene comparison')
    ap.add_argument('--top', type=int, default=20)
    ap.add_argument('--json', help='write the numbers here')
    o = ap.parse_args()
    src = source_lines(o.lib)
    ha, ta, ka, A = load(o.a, src)
    hb, tb, kb, B = load(o.b, src)
    res = {'a': o.a, 'b': o.b, 'map': ha.get('map'), 'kinds': {}, 'cells': {}}
    print('A %s  %s %sx%s  %d tris' % (o.a, ha.get('map'), ha.get('W'), ha.get('H'), len(A)))
    print('B %s  %s %sx%s  %d tris' % (o.b, hb.get('map'), hb.get('W'), hb.get('H'), len(B)))
    if ha != hb:
        print('MAP header differs: %s vs %s' % (ha, hb))

    def scene(items):
        return [x for x in items if o.all or not (x[0].startswith('draw:') or x[0].startswith('proto:'))]

    ca, cb = collections.Counter(x[0] for x in A), collections.Counter(x[0] for x in B)
    print('\ntriangles per kind            A          B       diff')
    for k in sorted(set(ca) | set(cb)):
        d = cb[k] - ca[k]
        note = ''
        if not o.all and k.startswith('draw:'):
            note = '   (draw-time, not scene)'
        elif not o.all and k.startswith('proto:'):
            note = '   (instance prototype in model space, not scene)'
        print('  %-20s %10d %10d %+10d%s' % (k, ca[k], cb[k], d, note))
        res['kinds'][k] = [ca[k], cb[k]]
    SA, SB = scene(A), scene(B)
    ga = collections.Counter(x[1] for x in SA)
    gb = collections.Counter(x[1] for x in SB)
    kga = collections.Counter(x[0] + '|' + x[1] for x in SA)
    kgb = collections.Counter(x[0] + '|' + x[1] for x in SB)
    sa, sb = checksum(ga.elements()), checksum(gb.elements())
    ksa, ksb = checksum(kga.elements()), checksum(kgb.elements())
    print('\nscene triangles: A %d  B %d' % (len(SA), len(SB)))
    print('checksum geometry      A %s  B %s  %s' % (sa, sb, 'SAME' if sa == sb else 'DIFFERENT'))
    print('checksum kind+geometry A %s  B %s  %s' % (ksa, ksb, 'SAME' if ksa == ksb else 'DIFFERENT'))
    onlyA, onlyB = kga - kgb, kgb - kga
    print('triangles only in A %d, only in B %d' % (sum(onlyA.values()), sum(onlyB.values())))
    res.update(scene_a=len(SA), scene_b=len(SB), checksum_a=sa, checksum_b=sb, kchecksum_a=ksa, kchecksum_b=ksb,
               only_a=sum(onlyA.values()), only_b=sum(onlyB.values()))
    # per cell
    cellOf = {}
    for x in SA + SB:
        cellOf.setdefault(x[0] + '|' + x[1], x[2])
    perA, perB = collections.Counter(), collections.Counter()
    perKind = collections.defaultdict(collections.Counter)
    for g, n in onlyA.items():
        perA[cellOf[g]] += n
        perKind[cellOf[g]]['-' + g.split('|')[0]] += n
    for g, n in onlyB.items():
        perB[cellOf[g]] += n
        perKind[cellOf[g]]['+' + g.split('|')[0]] += n
    cells = sorted(set(perA) | set(perB), key=lambda c: -(perA[c] + perB[c]))
    print('cells with differences: %d' % len(cells))
    if cells:
        print('  cell        onlyA  onlyB  kinds')
        for c in cells[:o.top]:
            print('  %4d,%-4d %7d %6d  %s' % (c[0], c[1], perA[c], perB[c], ' '.join('%s:%d' % kv for kv in sorted(perKind[c].items()))))
    res['diff_cells'] = [[c[0], c[1], perA[c], perB[c]] for c in cells]
    # .cells
    pa, pb = re.sub(r'\.geo\.gz$', '.cells', o.a), re.sub(r'\.geo\.gz$', '.cells', o.b)
    la, lb = load_cells(pa), load_cells(pb)
    cells_same = True
    if la is not None and lb is not None:
        xa, xb = collections.Counter(la), collections.Counter(lb)
        da, db = xa - xb, xb - xa
        cells_same = not da and not db
        print('\n.cells: A %d lines  B %d lines  only in A %d  only in B %d  order %s' % (
            len(la), len(lb), sum(da.values()), sum(db.values()), 'same' if la == lb else 'differs'))
        byc = collections.defaultdict(lambda: [None, None])
        for l in da.elements():
            p = l.split(' ', 3)
            byc[(int(p[1]), int(p[2]))][0] = l
        for l in db.elements():
            p = l.split(' ', 3)
            byc[(int(p[1]), int(p[2]))][1] = l
        for c in sorted(byc)[:o.top]:
            a, b = byc[c]
            print('  A: %s\n  B: %s' % (a, b))
        res['cells'] = {'a': len(la), 'b': len(lb), 'only_a': sum(da.values()), 'only_b': sum(db.values())}
    else:
        print('\n.cells: missing (%s / %s)' % (pa if la is None else 'ok', pb if lb is None else 'ok'))
    same = ksa == ksb and cells_same
    print('\nRESULT %s %s' % (ha.get('map'), 'IDENTICAL' if same else 'DIFFERENT'))
    res['identical'] = same
    if o.json:
        with open(o.json, 'w') as f:
            json.dump(res, f, indent=1)
    sys.exit(0 if same else 1)


if __name__ == '__main__':
    main()
