#!/usr/bin/env python3
"""Calibrate Colosseum pack sizes against Stadium 2 and lay them out for the
importer fork.

  calibrate.py <dsm-dir> <install-dir> [--scale S]

The Stadium 2 importer's world scale treats a median species as 52.25 raw
units tall (Battle Art's StadiumModels reference), so the global factor S maps
the median Colosseum rest height (GameCube units) onto 52.25. Every pack was
written with rootScale = 1/100 (int16 units = GC*100); here the header's
rootScale, height, floor and radius floats are rewritten in place (offsets
16 and 21/25/29 of the DSM5 header), then the packs are copied to
<install-dir>/colosseum/normal/<dex>.dsm (base form: the mapped name without
a form suffix wins) and .../shiny/<dex>.dsm from the rare_<name> models.
"""
import os, sys, json, struct, shutil, statistics

REFERENCE_HEIGHT = 52.25
UNITS = 100.0

def main():
    src, dst = sys.argv[1], sys.argv[2]
    scale = None
    if '--scale' in sys.argv: scale = float(sys.argv[sys.argv.index('--scale') + 1])
    report = json.load(open(os.path.join(src, 'report.json')))
    ok = {n: r for n, r in report.items() if 'error' not in r}
    heights = [r['height_gc'] for n, r in ok.items() if not n.startswith('rare_') and r['height_gc'] > 0]
    median = statistics.median(heights)
    if scale is None: scale = REFERENCE_HEIGHT / median
    print(f'{len(ok)} packs; median rest height {median:.2f} GC units -> S = {scale:.3f}; rootScale = {scale/UNITS:.5f}')
    root_scale = scale / UNITS

    def patched(path):
        b = bytearray(open(path, 'rb').read())
        assert b[:4] == b'DSM5'
        old_root = struct.unpack_from('<f', b, 16)[0]
        factor = root_scale / old_root
        struct.pack_into('<f', b, 16, root_scale)
        for off in (21, 25, 29):
            struct.pack_into('<f', b, off, struct.unpack_from('<f', b, off)[0] * factor)
        return bytes(b)

    # base form per dex: prefer the plain name (no _x suffix), then shortest
    by_dex, shiny_by_dex = {}, {}
    for name, r in ok.items():
        dex = r['dex']
        if name.startswith('rare_'):
            shiny_by_dex.setdefault(dex, []).append(name)
        else:
            by_dex.setdefault(dex, []).append(name)
    def pick(names):
        return sorted(names, key=lambda n: ('_' in n, len(n), n))[0]
    os.makedirs(os.path.join(dst, 'colosseum', 'normal'), exist_ok=True)
    os.makedirs(os.path.join(dst, 'colosseum', 'shiny'), exist_ok=True)
    installed, shiny = 0, 0
    for dex, names in sorted(by_dex.items()):
        if dex < 252: continue   # Stadium 2 owns #1-251
        name = pick(names)
        open(os.path.join(dst, 'colosseum', 'normal', f'{dex:03d}.dsm'), 'wb').write(patched(os.path.join(src, name + '.dsm')))
        installed += 1
        if dex in shiny_by_dex:
            open(os.path.join(dst, 'colosseum', 'shiny', f'{dex:03d}.dsm'), 'wb').write(patched(os.path.join(src, pick(shiny_by_dex[dex]) + '.dsm')))
            shiny += 1
    missing = sorted(d for d in range(252, 387) if d not in by_dex)
    print(f'installed {installed} normal + {shiny} shiny packs into {dst}/colosseum; missing dex: {missing}')
    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(os.path.join(dst, 'colosseum')) for f in fs)
    print(f'total size {total/2**20:.1f} MB')

if __name__ == '__main__':
    main()
