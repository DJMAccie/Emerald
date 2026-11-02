# Static scan of the imported Emerald maps (no game run): does a metatile pattern occur anywhere?
# grid.bin = u16 little-endian per cell, mid = v & 0x3FF. Maps are keyed by pret name (PetalburgCity).
# Primary tilesets: ts_083df704 = general, ts_083df884 = building, ts_083dfc5c = secret_base.
# Use: python3 tools/gridscan.py 0x141,0x142 0x149,0x14A   (rows of a pattern, general primary)
import glob, json, os, struct, sys
ROOT = os.path.expanduser('~/Library/Application Support/pokemon-love2d/emerald/data/generated/gba/map_tree/maps')
GENERAL, BUILDING, SECRET = 'ts_083df704', 'ts_083df884', 'ts_083dfc5c'
maps = {}
for d in sorted(glob.glob(ROOT + '/*')):
    h = json.load(open(d + '/header.json'))
    w, hh = h['width'], h['height']
    v = struct.unpack('<%dH' % (w * hh), open(d + '/grid.bin', 'rb').read()[:w * hh * 2])
    maps[h['pretName']] = dict(w=w, h=hh, mid=[x & 0x3FF for x in v], prim=h['primaryTileset'],
                               sec=h['secondaryTileset'], type=h['mapType'])
def find(rows, primary=None):
    """rows: list of rows of mids (None = wildcard). Returns [(map, x, y)]."""
    out = []
    ph, pw = len(rows), max(len(r) for r in rows)
    for k, m in maps.items():
        if primary and m['prim'] != primary: continue
        w, mids = m['w'], m['mid']
        for y in range(m['h'] - ph + 1):
            for x in range(w - pw + 1):
                if all(mid is None or mids[(y + dy) * w + x + dx] == mid
                       for dy, row in enumerate(rows) for dx, mid in enumerate(row)):
                    out.append((k, x, y))
    return out
if __name__ == '__main__':
    rows = [[int(t, 0) for t in a.split(',')] for a in sys.argv[1:]]
    hits = find(rows, GENERAL) if rows else []
    print(len(hits), 'hits', hits[:10])
