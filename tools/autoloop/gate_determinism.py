#!/usr/bin/env python3
"""Determinism check for a gate: two identical captures of the same case from the same tree must look the same.

  gate_determinism.py RUN1_DIR RUN2_DIR [--max 1.5] [--json OUT]

Compares every frame present in both runs by the share of pixels that differ (max channel delta > 8), and prints one line
per frame. Why: F001's fix passed its gate and looked strictly better, yet one capture in four opened fresh sky holes - the
new closure read the scene's streaming cell table, so a partially built window decided differently (docs/AUTOLOOP.md
2026-10-22). A fix whose own render is not reproducible is not a fix. Measured run-to-run spread: 0.08-0.85 % of a frame on the candidate tree
(sprites and animated water), 5.3 % on a tree whose closure read the streaming cell table; --max 1.5 % separates them.
Exit 1 when any frame is over the limit. Run with python3 -I? No: it needs PIL, so plain python3.
"""
import sys, os, glob, json
import numpy as np
from PIL import Image


def frames(d):
    return {os.path.basename(p): p for p in glob.glob(os.path.join(d, 'b*.png'))}


def main(argv):
    a, b = argv[0], argv[1]
    limit = 1.5
    out = None
    if '--max' in argv:
        limit = float(argv[argv.index('--max') + 1])
    if '--json' in argv:
        out = argv[argv.index('--json') + 1]
    fa, fb = frames(a), frames(b)
    common = sorted(set(fa) & set(fb))
    rows, worst = [], 0.0
    for k in common:
        ia = np.asarray(Image.open(fa[k]).convert('RGB'), dtype=np.int16)
        ib = np.asarray(Image.open(fb[k]).convert('RGB'), dtype=np.int16)
        if ia.shape != ib.shape:
            rows.append({'frame': k, 'diff_pct': None, 'note': 'size differs'})
            continue
        d = np.abs(ia - ib).max(axis=2)
        pct = float((d > 8).mean() * 100.0)
        worst = max(worst, pct)
        rows.append({'frame': k, 'diff_pct': round(pct, 3)})
    for r in rows:
        print('  %-10s %s' % (r['frame'], ('%6.3f %%' % r['diff_pct']) if r['diff_pct'] is not None else r.get('note', '')))
    ok = bool(common) and all((r['diff_pct'] is not None and r['diff_pct'] <= limit) for r in rows)
    print('[determinism] %d frame(s) compared, worst %.3f %% (limit %.2f %%): %s'
          % (len(common), worst, limit, 'STABLE' if ok else 'UNSTABLE'))
    if out:
        json.dump({'frames': rows, 'worst_pct': round(worst, 3), 'limit': limit, 'stable': ok}, open(out, 'w'), indent=1)
    if not common:
        print('[determinism] no frames to compare - was the second capture run made?')
        return 2
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
