#!/usr/bin/env python3
"""Compare every map present in two dump folders (compare_geo.py per map) and print one table.

  compare_all.py IN_GAME_DIR HEADLESS_DIR [--lib RC_LIB] [--jobs 4] [--maps M1,M2] [--json OUT]

Columns: scene triangles A/B, triangles only in A/B, differing cells, .cells lines only in A/B, draw-time
triangles in A (sprite meshes, not compared), dump time of A, result. Exit 0 when every map is identical.
"""
import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))


def one(a, b, lib):
    fd, path = tempfile.mkstemp(suffix='.json')
    os.close(fd)
    try:
        p = subprocess.run([sys.executable, os.path.join(HERE, 'compare_geo.py'), a, b, '--lib', lib, '--json', path],
                           capture_output=True, text=True)
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            return {'error': (p.stderr or p.stdout)[-300:]}
    finally:
        os.unlink(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('a')
    ap.add_argument('b')
    ap.add_argument('--lib', default=os.path.expanduser('~/Documents/Emerald/.autoloop/rc/lib'))
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--maps')
    ap.add_argument('--json')
    o = ap.parse_args()
    names = sorted(n[:-7] for n in os.listdir(o.a) if n.endswith('.geo.gz') and os.path.exists(os.path.join(o.b, n)))
    if o.maps:
        want = set(o.maps.split(','))
        names = [n for n in names if n in want]
    res = {}
    with cf.ThreadPoolExecutor(o.jobs) as ex:
        futs = {ex.submit(one, os.path.join(o.a, n + '.geo.gz'), os.path.join(o.b, n + '.geo.gz'), o.lib): n for n in names}
        for f in cf.as_completed(futs):
            res[futs[f]] = f.result()
    bad = 0
    print('%-34s %9s %9s %7s %7s %5s %6s %6s %7s %8s  %s' % ('map', 'sceneA', 'sceneB', 'onlyA', 'onlyB', 'cells', 'c.A', 'c.B', 'drawA', 'A time', 'result'))
    for n in names:
        r = res[n]
        t = time.strftime('%H:%M:%S', time.localtime(os.path.getmtime(os.path.join(o.a, n + '.geo.gz'))))
        if 'error' in r:
            bad += 1
            print('%-34s ERROR %s' % (n, r['error'].replace('\n', ' ')))
            continue
        draw = sum(v[0] for k, v in r['kinds'].items() if k.startswith('draw:'))
        c = r.get('cells') or {}
        ok = r.get('identical')
        bad += 0 if ok else 1
        print('%-34s %9d %9d %7d %7d %5d %6s %6s %7d %8s  %s' % (n, r['scene_a'], r['scene_b'], r['only_a'], r['only_b'],
              len(r['diff_cells']), c.get('only_a', '-'), c.get('only_b', '-'), draw, t, 'IDENTICAL' if ok else 'DIFFERENT'))
    print('%d maps, %d identical, %d different' % (len(names), len(names) - bad, bad))
    if o.json:
        with open(o.json, 'w') as f:
            json.dump(res, f, indent=1)
    sys.exit(0 if bad == 0 else 1)


if __name__ == '__main__':
    main()
