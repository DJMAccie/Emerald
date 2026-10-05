#!/usr/bin/env python3
"""Prop audit: source art next to the in-game render, one row per (pair, metatile).

  python3 audit.py plan  KIND[,KIND..] OUTDIR [TOP_N_BY_COUNT]     # writes OUTDIR/cases.lua + manifest.json
  tools/props/audit_capture.sh OUTDIR             # captures bNNN.png (QA identity, player camera)
  python3 audit.py sheet OUTDIR                   # OUTDIR/sheet_NN.png contact sheets

props.tsv comes from catalogue_props.lua (luajit, run from ~/Documents/gen1recomp).
Each row: source art of the example cell with its neighbours (3 up, 1 down, 3 either side),
and the game at the player's camera, the player standing 2+ cells below the cell."""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'buildings'))
from PIL import Image, ImageDraw
W = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/world.json')))
MAPS = {m['id']: m for m in W['maps']}


def cell(m, x, y):
    if 0 <= x < m['w'] and 0 <= y < m['h']:
        v = m['cells'][y * m['w'] + x]
        return v & 0x3FF, (v >> 10) & 3
    return None


def standing(m, x, y):
    for dy in (2, 3, 4):
        a, b = cell(m, x, y + dy), cell(m, x, y + dy - 1)
        if a and b and a[1] == 0 and b[1] == 0:
            return x, y + dy
    return None


def plan(kinds, out, tsv, top=0):
    os.makedirs(out, exist_ok=True)
    want = set(kinds)
    rows = [l.rstrip('\n').split('\t') for l in open(tsv)]
    rows = [r for r in rows if len(r) == 8 and r[2] in want and r[0] != 'pair']
    rows.sort(key=lambda r: -int(r[4]))
    if top:
        rows = rows[:top]
    bypair = {}
    for m in W['maps']:
        bypair.setdefault(m['pair'], []).append(m)
    pick = {}
    for pair, mid, kind, coll, n, mp, x, y in rows:
        key = (pair, int(mid, 16), kind, coll)
        for m in bypair.get(pair, []):
            for yy in range(3, m['h']):
                for xx in range(m['w']):
                    c = cell(m, xx, yy)
                    if c and c[0] == key[1] and (c[1] != 0) == (coll == 'blocked'):
                        s = standing(m, xx, yy)
                        if s:
                            pick[key] = (m['id'], xx, yy, s, int(n))
                            break
                if key in pick:
                    break
            if key in pick:
                break
    man = []
    for key, (mp, x, y, s, n) in sorted(pick.items()):
        man.append(dict(pair=key[0], mid=key[1], kind=key[2], coll=key[3], map=mp, x=x, y=y, sx=s[0], sy=s[1], n=n))
    json.dump(man, open(os.path.join(out, 'manifest.json'), 'w'), indent=1)
    with open(os.path.join(out, 'cases.lua'), 'w') as f:
        f.write('return {' + ','.join("{'%s',%d,%d}" % (e['map'], e['sx'], e['sy']) for e in man) + '}\n')
    print(len(man), 'cases of', len(rows), 'kinds')


def sheet(out):
    import bldmodel as M
    man = json.load(open(os.path.join(out, 'manifest.json')))
    per = 5
    for si in range(0, len(man), per):
        chunk = man[si:si + per]
        img = Image.new('RGB', (1000, 250 * len(chunk)), (20, 20, 24)); d = ImageDraw.Draw(img)
        for r, e in enumerate(chunk):
            m = MAPS[e['map']]
            x0, x1 = max(0, e['x'] - 3), min(m['w'] - 1, e['x'] + 3)
            y0, y1 = max(0, e['y'] - 3), min(m['h'] - 1, e['y'] + 1)
            try:
                src = Image.fromarray(M.compose(e['pair'], e['map'], x0, y0, x1, y1)).convert('RGB')
                src = src.resize((src.width * 3, src.height * 3), Image.NEAREST)
                cx, cy = (e['x'] - x0) * 48, (e['y'] - y0) * 48
                ImageDraw.Draw(src).rectangle([cx, cy, cx + 47, cy + 47], outline=(255, 0, 0))
                img.paste(src, (0, r * 250 + 24))
            except Exception as ex:
                d.text((4, r * 250 + 30), 'source failed: %s' % ex, fill=(255, 80, 80))
            shot = os.path.join(out, 'b%03d.png' % (si + r + 1))
            if os.path.exists(shot):
                g = Image.open(shot).convert('RGB').crop((440, 190, 840, 390))
                img.paste(g.resize((600, 300)).crop((0, 0, 600, 226)), (400, r * 250 + 20))
            d.text((4, r * 250 + 4), '%s  %03X  %s %s  x%d  %s %d,%d' % (e['pair'], e['mid'], e['kind'], e['coll'], e['n'], e['map'], e['x'], e['y']), fill=(255, 255, 0))
        img.save(os.path.join(out, 'sheet_%02d.png' % (si // per + 1)))
    print('sheets', (len(man) + per - 1) // per)


if __name__ == '__main__':
    if sys.argv[1] == 'plan':
        plan(sys.argv[2].split(','), sys.argv[3], os.path.join(HERE, 'props.tsv'), int(sys.argv[4]) if len(sys.argv) > 4 else 0)
    else:
        sheet(sys.argv[2])
