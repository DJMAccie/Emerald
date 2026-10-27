#!/usr/bin/env python3
"""propose.py [MAP ...]: PROPOSED pins for every outdoor map without a pin file (default: draw_pack's ALL list minus the pinned maps):
docs/elevation/pins/<MAP>_proposed.txt (x y h [?]) and docs/elevation/draw/<MAP>_proposed.png (the 2D sheet with the numbers in blue, unsure ones orange).
Never touches docs/elevation/draw/<MAP>.png (the user draws on those). The edge table is fitted on ALL pinned maps."""
import sys, os, re, subprocess, collections
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..'))
import proposer as P
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(HERE, '..', '..', '..'); DRAW = os.path.join(ROOT, 'docs', 'elevation', 'draw'); PINS = os.path.join(ROOT, 'docs', 'elevation', 'pins')
CROP = os.path.join(ROOT, 'skills', 'emerald-terrain', 'scripts', 'crop2d.py')
ALL = re.search(r"ALL = \((.*?)\)\.split\(\)", open(os.path.join(HERE, '..', 'draw_pack.py')).read(), re.S).group(1)
ALL = ''.join(re.findall(r"'([^']*)'", ALL)).split()
def propose(g, tab):
    adj = collections.defaultdict(list)
    for e in g.edges:
        v = P.dh(e, tab); shaky = e['t'] == 'gap' or (e['t'] == 'cliff' and (e['d'] >= 6 or e['d'] == 2))
        adj[e['hi']].append((e['lo'], -v, e['w'], shaky)); adj[e['lo']].append((e['hi'], v, e['w'], shaky))
    todo = set(range(len(g.nodes))); res = {}
    order = sorted(todo, key=lambda k: (g.nodes[k]['kind'] != 'water', -len(g.nodes[k]['cells'])))
    first = True
    for r in order:
        if r not in todo: continue
        import heapq
        H = {r: 0.0}; cost = {r: 0}; shk = {r: False}; pq = [(0, r)]
        while pq:
            c, a = heapq.heappop(pq)
            if c > cost[a]: continue
            for b, d, w, s in adj[a]:
                if b not in cost or c + w < cost[b]: cost[b] = c + w; H[b] = H[a] + d; shk[b] = shk[a] or s; heapq.heappush(pq, (c + w, b))
        bad = set()
        for e in g.edges:
            if e['hi'] in H and e['lo'] in H and abs((H[e['hi']] - H[e['lo']]) - P.dh(e, tab)) > .5: bad.add(e['hi']); bad.add(e['lo'])
        lo = 0.0 if g.nodes[r]['kind'] == 'water' else min(H.values())
        for k, h in H.items(): res[k] = (max(0, round(h - lo)), shk[k] or k in bad or not first or round(h - lo) < 0)   # a component apart from the biggest one is unsure
        todo -= set(H); first = False
    return res
def render(m, out, pins):
    L = P.emdata.Layout(m); tmp = out + '.tmp.png'
    subprocess.run(['python3', CROP, L.slot, L.pair, '0', '0', str(L.w - 1), str(L.h - 1), tmp, '3'], check=True)
    im = Image.open(tmp).convert('RGB'); os.remove(tmp); d = ImageDraw.Draw(im)
    try: font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 30)
    except Exception: font = ImageFont.load_default()
    for x, y, h, un in pins:
        col = (255, 120, 0) if un else (0, 90, 255)
        d.rectangle([x * 48, y * 48, x * 48 + 48, y * 48 + 48], outline=col, width=3); d.text((x * 48 + 6, y * 48 + 6), '%g' % h, fill=col, font=font)
    strip = Image.new('RGB', (im.width, 40), (255, 255, 255)); sd = ImageDraw.Draw(strip)
    sd.text((6, 4), '%s PROPOSED heights (courses): blue = confident, orange = unsure. Correct them in place; 0 = sea / ground.' % m, fill=(0, 0, 0))
    full = Image.new('RGB', (im.width, im.height + 40), (0, 0, 0)); full.paste(strip, (0, 0)); full.paste(im, (0, 40)); full.save(out)
if __name__ == '__main__':
    pinned = set(P.pinned_maps()); maps = sys.argv[1:] or [m for m in ALL if m not in pinned]
    graphs = [P.G(m) for m in pinned if 'FRONTIER' not in m]; tab = P.fit(graphs)
    print('table: sig %d entries, g %s' % (len(tab['sig']), tab['g']))
    for m in maps:
        try: g = P.G(m)
        except Exception as ex: print('skip', m, ex); continue
        res = propose(g, tab); pins = []
        for k, (h, un) in sorted(res.items()):
            n = g.nodes[k]
            if len(n['cells']) < 2 or (n['kind'] == 'water' and h == 0): continue
            cx = sum(c[0] for c in n['cells']) / len(n['cells']); cy = sum(c[1] for c in n['cells']) / len(n['cells'])
            x, y = min(n['cells'], key=lambda c: (c[0] - cx) ** 2 + (c[1] - cy) ** 2); pins.append((x, y, h, un))
        with open(os.path.join(PINS, m + '_proposed.txt'), 'w') as f:
            f.write('# %s  PROPOSED heights from the stair/cliff/ledge/shore graph (tools/elevation/learn/propose.py); not the user\'s drawing\n# x y height [? = unsure]\n' % m)
            for x, y, h, un in pins: f.write('%d %d %g%s\n' % (x, y, h, ' ?' if un else ''))
        render(m, os.path.join(DRAW, m + '_proposed.png'), pins)
        print('%-32s %3d nodes  %3d proposed  %3d unsure  max h %g' % (m, len(g.nodes), len(pins), sum(p[3] for p in pins), max([p[2] for p in pins] or [0])))
