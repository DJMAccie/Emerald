#!/usr/bin/env python3
"""Four-camera foliage audit.
  python3 foliage_audit.py plan  OUTDIR [N]       # pick the N biggest foliage groups, write OUTDIR/cases.lua + manifest.json
  tools/props/fourcam.sh OUTDIR                   # capture level 4, level 7 turned, level 6 low, top-down
  python3 foliage_audit.py sheet OUTDIR [START]   # OUTDIR/fs_NN.png: source | player | turned | low | top-down
Source = the map's own art around the example cell (3 up, 1 down, 2 either side), the cell outlined."""
import os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'buildings'))
from PIL import Image, ImageDraw
W = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/world.json')))
MAPS = {m['id']: m for m in W['maps']}
CAT = os.environ.get('FOLIAGE_JSON', '/tmp/foliage.json')

def cell(m, x, y):
    if 0 <= x < m['w'] and 0 <= y < m['h']:
        v = m['cells'][y * m['w'] + x]; return v & 0x3FF, (v >> 10) & 3

def stand(m, x, y):
    for dy in (2, 3, 4):
        a, b = cell(m, x, y + dy), cell(m, x, y + dy - 1)
        if a and b and a[1] == 0 and b[1] == 0: return x, y + dy

def plan(out, n):
    os.makedirs(out, exist_ok=True)
    groups = json.load(open(CAT))[:n]
    man = []
    for g in groups:
        best = None
        for u in g['uses']:
            mp, x, y, coll = u['ex']
            m = MAPS[mp]
            # prefer an example whose own map shows several cells of this tile and has a stand cell
            s = stand(m, x, y) if y >= 3 else None
            if s: best = (u, mp, x, y, s); break
        if not best:
            # search the pair's maps for any cell of this tile
            u = g['uses'][0]; pair = 'general__' + u['pair']; mid = int(u['mid'], 16)
            for m in W['maps']:
                if m['pair'] != pair: continue
                for yy in range(3, m['h']):
                    for xx in range(m['w']):
                        c = cell(m, xx, yy)
                        if c and c[0] == mid and stand(m, xx, yy): best = (u, m['id'], xx, yy, stand(m, xx, yy)); break
                    if best: break
                if best: break
        if not best: continue
        u, mp, x, y, s = best
        man.append(dict(hash=g['hash'], kind=g['kind'], pair=u['pair'], mid=u['mid'], map=mp, x=x, y=y, sx=s[0], sy=s[1], total=g['total']))
    json.dump(man, open(os.path.join(out, 'manifest.json'), 'w'), indent=1)
    open(os.path.join(out, 'cases.lua'), 'w').write('return {' + ','.join("{'%s',%d,%d}" % (e['map'], e['sx'], e['sy']) for e in man) + '}\n')
    print(len(man), 'cases')

def sheet(out, start=0, per=4):
    import bldmodel as M
    man = json.load(open(os.path.join(out, 'manifest.json')))
    names = ['p4', 'p7', 'p6', 'pt']
    for si in range(start, len(man), per):
        chunk = man[si:si + per]
        img = Image.new('RGB', (1920, 240 * len(chunk)), (22, 22, 26)); d = ImageDraw.Draw(img)
        for r, e in enumerate(chunk):
            m = MAPS[e['map']]
            x0, x1 = max(0, e['x'] - 2), min(m['w'] - 1, e['x'] + 2)
            y0, y1 = max(0, e['y'] - 3), min(m['h'] - 1, e['y'] + 1)
            try:
                src = Image.fromarray(M.compose('general__' + e['pair'], e['map'], x0, y0, x1, y1)).convert('RGB')
                src = src.resize((src.width * 3, src.height * 3), Image.NEAREST)
                cx, cy = (e['x'] - x0) * 48, (e['y'] - y0) * 48
                ImageDraw.Draw(src).rectangle([cx, cy, cx + 47, cy + 47], outline=(255, 0, 0))
                img.paste(src.crop((0, 0, 240, 240)), (0, r * 240))
            except Exception as ex:
                d.text((4, r * 240 + 20), 'src failed %s' % ex, fill=(255, 90, 90))
            for c, nm in enumerate(names):
                p = os.path.join(out, nm, 'b%03d.png' % (si + r + 1))
                if os.path.exists(p):
                    g = Image.open(p).convert('RGB').crop((380, 40, 900, 400)).resize((400, 277))
                    img.paste(g, (240 + c * 420, r * 240))
            d.text((2, r * 240 + 2), '%d %s %s %s %s' % (si + r + 1, e['kind'], e['pair'], e['mid'], e['map'][3:]), fill=(255, 255, 0))
        img.save(os.path.join(out, 'fs_%02d.png' % (si // per + 1)))
    print('sheets', (len(man) - start + per - 1) // per)

if __name__ == '__main__':
    if sys.argv[1] == 'plan': plan(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 40)
    else: sheet(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 0)
