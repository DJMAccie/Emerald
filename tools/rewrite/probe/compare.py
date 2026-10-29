#!/usr/bin/env python3
"""compare.py <dirA> <dirB> [maps...]  compare two baseline dump folders map by map.

Works across tag styles: old h3_geo_driver dumps (TAG = source line, mapped with detect.tag_kind) and neutral
probe dumps (TAG = probe layer). Old kinds are mapped to probe layers: under->ground; roof canopy over plants model
tree water stay; everything else -> other. Per map it prints whether the .cells files are identical and, per layer,
the triangle counts and the triangles present in only one side (rounded to 0.001 px, as the dumps print 3 decimals).
Exit status 0 only when every map matches exactly."""
import sys, os, collections
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'autoloop'))
import detect

LIBDIR = os.path.expanduser('~/Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/lib')
LAYERS = {'under': 'ground', 'ground': 'ground', 'roof': 'roof', 'canopy': 'canopy', 'over': 'over',
          'plants': 'plants', 'model': 'model', 'tree': 'tree', 'water': 'water'}
_src = None


def layer_of(tag):
    global _src
    if tag in LAYERS:
        return LAYERS[tag]
    if _src is None:
        _src = detect.source_lines(LIBDIR)
    return LAYERS.get(detect.tag_kind(_src, tag), 'other')


def tris(path):
    head, tags, a = detect.load(path)
    lay = {t: layer_of(v['tag']) for t, v in tags.items()}
    out = collections.defaultdict(collections.Counter)
    for row in a:
        tri = np.round(row[1:10].reshape(3, 3), 3)
        k = tuple(sorted(map(tuple, tri.tolist())))
        out[lay.get(int(row[0]), 'other')][k] += 1
    return out


def main():
    A, B = sys.argv[1], sys.argv[2]
    maps = sys.argv[3:] or sorted(f[:-7] for f in os.listdir(A) if f.endswith('.geo.gz'))
    bad = 0
    for m in maps:
        ca, cb = os.path.join(A, m + '.cells'), os.path.join(B, m + '.cells')
        ga, gb = os.path.join(A, m + '.geo.gz'), os.path.join(B, m + '.geo.gz')
        if not (os.path.exists(gb) and os.path.exists(cb)):
            print(f'{m}: MISSING in B'); bad += 1; continue
        cells_same = sorted(open(ca).read().split('\n')) == sorted(open(cb).read().split('\n'))
        ta, tb = tris(ga), tris(gb)
        parts, diff = [], 0
        for L in sorted(set(ta) | set(tb)):
            x, y = ta.get(L, collections.Counter()), tb.get(L, collections.Counter())
            oa, ob = sum((x - y).values()), sum((y - x).values())
            diff += oa + ob
            parts.append(f'{L} {sum(x.values())}/{sum(y.values())}' + (f' onlyA={oa} onlyB={ob}' if oa or ob else ''))
        ok = cells_same and diff == 0
        bad += not ok
        print(f'{m}: {"SAME" if ok else "DIFF"} cells={"same" if cells_same else "DIFF"} | ' + '; '.join(parts))
    print('ALL SAME' if bad == 0 else f'{bad} map(s) differ')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
