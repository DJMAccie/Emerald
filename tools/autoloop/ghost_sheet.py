#!/usr/bin/env python3
"""Ghost v0 output: heatmap.png, sheet.html (cards the user answers), from the walk in <run dir>.

  python3 tools/autoloop/ghost_sheet.py <run dir> [--map EM_ROUTE112]

<run dir> = .autoloop/runs/ghost (frames/, senses.csv, spots.json). Writes <run dir>/ghost/{heatmap.png,sheet.html}.
The cards are hand-judged (full-resolution frames looked at, pixel boxes set by eye): edit CARDS below, rerun.
Frames are 1280x720; boxes are (x0, y0, x1, y1) in frame pixels.
"""
import base64, csv, io, json, os, subprocess, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'relief'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emdata
from PIL import Image, ImageDraw
import numpy as np

CARDS = [
    dict(id='G1', cls='floating foliage (F035 / F032 class)', cell=(27, 32), verdict='REAL',
         wrong='Flat green crowns hang in the sky with no trunk and nothing under them. A geometry check finds 55 such crown slabs on Route 112 (a Gen3Canopy slab seated 26 px up over a tile with no tree under it: 21 are the ash-bush tile 0x210 on walkable ground, the rest are the stacked crown tiles 0x218 / 0x21A / 0x3B8 of the plateau-edge trees). By projection at least one shows against the sky in 81 of 204 low and orbit frames; seen from the west, the plate over the terrace at (9..10,40..41) is the F035 plate.',
         action='Remove the floating slab: F032 attempt 2 (a solid bush that repeats the art 1:1) for the 0x210 bushes, and for the stacked crowns give the plateau-edge trees an upright tree like the Dewford / Chimney stamps (task 11 "general trees"; this is the mangled-tree spot you were asked for). Then re-walk Route 112.',
         frames=[('frames/y39_b1/b005.png', 'plates', '(27,32) low camera'),
                 ('frames/y08_b3/b011.png', 'plates', '(15,38) low camera'),
                 ('frames/y39_b3/b032.png', 'plates', '(23,19) low camera: a plate over the cable-car pylon'),
                 ('frames/y08_b2/b036.png', 'plates', '(4,51) orbit camera: the F035 plate over the terrace, far away')]),
    dict(id='G2', cls='bush plates on rock (F032 / F040 class)', cell=(11, 26), verdict='REAL',
         wrong='The bushes drawn on the red rock stand as full-height columns of the same green tile stacked up the wall (and mirrored in corners): a striped green plate, not a few tufts on rock. The rock walls here carry 72 runs of 3 or more cells of one foliage tile.',
         action='Show rock on rock faces and keep bushes only where the 2D draws a bush on flat ground; the rc-main F040 fix (193662a / 9199b05) does this for relief walls but is not in the game yet: install it or confirm these cells are covered.',
         frames=[('frames/y08_b3/b002.png', [(404, 60, 536, 322), (944, 30, 1018, 176)], '(11,26) low camera'),
                 ('frames/y08_b3/b003.png', [(76, 288, 210, 448), (488, 290, 576, 440), (852, 225, 920, 310)], '(11,26) orbit camera'),
                 ('frames/y08_b4/b008.png', [(205, 0, 632, 480)], '(26,23) low camera')]),
    dict(id='G3', cls='hollow (sky under rock)', cell=(30, 22), verdict='REAL',
         wrong='Pale-blue sky shows under the pink rock plate: the plateau edge has no wall or underside down to the floor, so a low camera sees through it to the void. Same at the foot of the cable-car station, where the ground has a hole beside its door.',
         action='Inspect (30,22), (26,23) and (25,27): extend the rock wall to the floor below the plateau edge and close the floor under the station; confirm from the low camera that it is only visible low.',
         frames=[('frames/y39_b4/b014.png', [(0, 170, 660, 720)], '(30,22) low camera'),
                 ('frames/y08_b4/b008.png', [(630, 410, 1010, 545)], '(26,23) low camera'),
                 ('frames/y08_b4/b005.png', [(740, 380, 960, 500)], '(25,27) low camera')]),
    dict(id='G4', cls='camera inside geometry', cell=(34, 23), verdict='REAL',
         wrong='The orbit camera sits inside the Fiery Path cable-car station (glass panes fill the top of the frame) at (34,23) and (25,27); in 16 of 102 orbit frames the line from the player to the camera crosses terrain or a building, e.g. a rock pillar fills the view at (15,34).',
         action='Camera collision, not terrain: keep the orbit camera out of building volumes and pull it in before a wall. LATER unless you want it in this pass.',
         frames=[('frames/y08_b4/b024.png', [(0, 0, 1280, 312)], '(34,23) orbit camera'),
                 ('frames/y39_b4/b006.png', [(0, 0, 1280, 312)], '(25,27) orbit camera'),
                 ('frames/y08_b1/b012.png', [(415, 0, 890, 320)], '(15,34) orbit camera: a rock face in front of the lens')]),
    dict(id='G5', cls='untextured stairs', cell=(20, 43), verdict='UNCLEAR',
         wrong='The stairs are flat grey slabs with a white lip and no stone texture; I cannot tell from the frame whether the 2D steps look like this.',
         action='Compare with the 2D crop: if the 2D steps have texture, give the slabs the tile art; KEEP if the plain steps are what you want.',
         frames=[('frames/y08_b3/b023.png', [(0, 0, 830, 560)], '(20,43) low camera')]),
    dict(id='G6', cls='leaning single-colour slab', cell=(19, 35), verdict='UNCLEAR',
         wrong='A tall dark-red slab leans against the pink plateau with one flat colour on its face.',
         action='Check against the 2D rock cell; probably a rock course stand-in. LATER unless it bothers you.',
         frames=[('frames/y39_b1/b017.png', [(1005, 150, 1205, 405)], '(19,35) low camera')]),
]

_GEO = {}


def auto_boxes(G, mp, frame, what):
    """boxes of a sense on one frame, from the geometry dump (what = 'plates': tools/autoloop/ghost_geo.py)"""
    import ghost_geo
    if mp not in _GEO:
        a, kk, cells = ghost_geo.load_geo(G, mp)
        orph = {tuple(o['cell']) for o in json.load(open(os.path.join(G, 'geo_senses.json')))['orphan_canopy']}
        _GEO[mp] = (a, kk, cells, orph)
    a, kk, cells, orph = _GEO[mp]
    row = next(r for r in csv.DictReader(open(os.path.join(G, 'senses.csv'))) if r['frame'] == frame)
    x, y, lv = int(row['x']), int(row['y']), int(row['level'])
    yaw = 0.8 if row['yaw'] == 'y08' else 3.9
    ground = float(cells.get((x, y), {}).get('base') or 0)
    return ghost_geo.green_boxes(os.path.join(G, frame), ghost_geo.plate_boxes(a, kk, x, y, yaw, lv, ground, only=orph))


def crop2d(L, cell, out, half=5, scale=3):
    x, y = cell
    x0, y0 = max(0, x - half), max(0, y - half)
    x1, y1 = min(L.w - 1, x + half), min(L.h - 1, y + half)
    here = os.path.dirname(os.path.abspath(__file__))
    tool = os.path.join(here, '..', '..', 'skills', 'emerald-terrain', 'scripts', 'crop2d.py')
    subprocess.run(['python3', tool, L.slot, L.pair, str(x0), str(y0), str(x1), str(y1), out, str(scale)], check=True)
    im = Image.open(out).convert('RGB')
    d = ImageDraw.Draw(im)
    cx, cy = (x - x0) * 16 * scale, (y - y0) * 16 * scale
    d.rectangle((cx, cy, cx + 16 * scale, cy + 16 * scale), outline=(255, 0, 0), width=3)
    im.save(out)
    return im


def jpeg_b64(im, q=82):
    b = io.BytesIO()
    im.convert('RGB').save(b, 'JPEG', quality=q)
    return base64.b64encode(b.getvalue()).decode()


def frame_with_boxes(path, boxes):
    im = Image.open(path).convert('RGB')
    d = ImageDraw.Draw(im)
    for b in boxes:
        d.rectangle(b, outline=(255, 40, 40), width=4)
    return im


def heatmap(G, L, mp, out):
    rows = list(csv.DictReader(open(os.path.join(G, 'senses.csv'))))
    met = ('stretch', 'void', 'skyfloor')
    arr = {m: np.array([float(r[m]) for r in rows]) for m in met}
    # skyfloor reads a hole under the camera only in the first-person frames: an orbit overview ends at the build window and
    # shows sky below the world (Route 112 (31,42) L4 gave .88 and was a false alarm), so the other levels do not count
    arr['skyfloor'] = np.where(np.array([r['level'] == '6' for r in rows]), arr['skyfloor'], 0)
    z = {m: (arr[m] - arr[m].mean()) / (arr[m].std() or 1) for m in met}
    # geometry senses (ghost_geo.py columns, when present): plates with no trunk ahead, camera inside a building / behind terrain
    has_geo = 'plates' in rows[0]
    orph = np.array([float(r['plates'] or 0) for r in rows]) if has_geo else np.zeros(len(rows))
    per = {}
    for i, r in enumerate(rows):
        s = max(z['skyfloor'][i], z['void'][i], .5 * z['stretch'][i])
        if has_geo:
            s = max(s, orph[i] / (orph.max() or 1) * 3,         # plates against the sky
                    3.5 if int(r['camin'] or 0) % 2 else 0,
                    1.5 if int(r['camblock'] or 0) >= 4 else 0)
        k = (int(r['x']), int(r['y']))
        per[k] = max(per.get(k, -9), s)
    tmp = os.path.join(G, 'ghost', '_map.png')
    subprocess.run(['python3', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'skills', 'emerald-terrain', 'scripts', 'crop2d.py'),
                    L.slot, L.pair, '0', '0', str(L.w - 1), str(L.h - 1), tmp, '1'], check=True)
    bg = Image.open(tmp).convert('RGB')
    bg = Image.blend(bg, Image.new('RGB', bg.size, (255, 255, 255)), .45)
    d = ImageDraw.Draw(bg)
    hi = max(per.values()); lo = min(per.values())
    for (x, y), s in per.items():
        t = (s - lo) / ((hi - lo) or 1)
        col = (int(60 + 195 * t), int(200 - 150 * t), 60)
        cx, cy = x * 16 + 8, y * 16 + 8
        d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), fill=col, outline=(0, 0, 0))
    for c in CARDS:
        cx, cy = c['cell'][0] * 16 + 8, c['cell'][1] * 16 + 8
        d.rectangle((cx - 13, cy - 13, cx + 13, cy + 13), outline=(0, 0, 160), width=3)
        d.text((cx + 14, cy - 20), c['id'], fill=(0, 0, 160))
    d.rectangle((0, 0, 330, 14), fill=(255, 255, 255))
    d.text((3, 2), 'ghost walk %s: max sense score per spot (green low, red high); boxes = cards' % mp, fill=(0, 0, 0))
    bg.save(out)
    os.remove(tmp)


def sheet(G, L, mp, out):
    css = ('body{font:15px -apple-system,Helvetica,sans-serif;margin:0 auto;max-width:1100px;padding:16px;background:#f6f3ee;color:#222}'
           '.card{background:#fff;border:1px solid #d8d2c8;border-radius:10px;margin:18px 0;padding:14px}'
           '.card h2{margin:0 0 6px;font-size:18px}.tag{font-size:12px;background:#eee;border-radius:6px;padding:2px 7px;margin-left:8px}'
           '.imgs{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0}.imgs figure{margin:0}.imgs img{display:block;max-width:100%}'
           '.crop img{width:330px}.fr img{width:520px}figcaption{font-size:12px;color:#666}'
           'button{font-size:14px;padding:6px 14px;margin-right:6px;border:1px solid #888;border-radius:6px;background:#fafafa;cursor:pointer}'
           'button.on{background:#222;color:#fff}#copy{background:#0a6;color:#fff;border-color:#0a6}pre{background:#fff;border:1px solid #ddd;padding:8px;white-space:pre-wrap}')
    h = ['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ghost walk: Route 112</title><style>%s</style>' % css,
         '<h1>Ghost walk: %s</h1><p>%d cards, worst first. Left: the 2D original around the cell (red square). Right: our 3D frame, the red box is what I mean. Answer each: KEEP (it is fine as it is), REJECT (it is wrong, fix it), LATER. Then "copy answers".</p>' % (mp, len(CARDS))]
    for c in CARDS:
        L2 = os.path.join(G, 'ghost', '_crop_%s.png' % c['id'])
        crop = crop2d(L, c['cell'], L2)
        os.remove(L2)
        h.append('<div class="card" id="%s"><h2>%s &mdash; %s <span class="tag">%s</span><span class="tag">%s</span></h2>' % (c['id'], c['id'], c['wrong'].split(':')[0].split('.')[0][:90], c['cls'], c['verdict']))
        h.append('<div><b>What feels wrong:</b> %s</div><div><b>Proposed action:</b> %s</div><div class="imgs">' % (c['wrong'], c['action']))
        h.append('<figure class="crop"><img src="data:image/jpeg;base64,%s"><figcaption>2D original, cell %d,%d</figcaption></figure>' % (jpeg_b64(crop), *c['cell']))
        for f, boxes, cap in c['frames']:
            if isinstance(boxes, str):
                boxes = auto_boxes(G, mp, f, boxes)
            h.append('<figure class="fr"><img src="data:image/jpeg;base64,%s"><figcaption>%s &middot; %s</figcaption></figure>' % (jpeg_b64(frame_with_boxes(os.path.join(G, f), boxes)), cap, f))
        h.append('</div><div class="btns">')
        for a in ('KEEP', 'REJECT', 'LATER'):
            h.append('<button onclick="ans(\'%s\',\'%s\',this)">%s</button>' % (c['id'], a, a))
        h.append('</div></div>')
    meta = json.dumps({c['id']: dict(map=mp, cell=list(c['cell']), cls=c['cls']) for c in CARDS})
    h.append('<p><button id="copy" onclick="cp()">copy answers</button></p><pre id="out"></pre>')
    h.append('<script>var M=%s,A={};function ans(i,a,b){A[i]=a;var p=b.parentNode.children;for(var k=0;k<p.length;k++)p[k].className=p[k]===b?"on":"";show()}'
             'function js(){return JSON.stringify(Object.keys(A).map(function(i){return{card:i,map:M[i].map,cell:M[i].cell,class:M[i].cls,answer:A[i]}}),null,1)}'
             'function show(){document.getElementById("out").textContent=js()}'
             'function cp(){show();if(navigator.clipboard)navigator.clipboard.writeText(js())}</script>' % meta)
    open(out, 'w').write('\n'.join(h))


def main():
    G = sys.argv[1]
    mp = sys.argv[sys.argv.index('--map') + 1] if '--map' in sys.argv else 'EM_ROUTE112'
    L = emdata.Layout(mp)
    os.makedirs(os.path.join(G, 'ghost'), exist_ok=True)
    heatmap(G, L, mp, os.path.join(G, 'ghost', 'heatmap.png'))
    sheet(G, L, mp, os.path.join(G, 'ghost', 'sheet.html'))
    print('wrote', os.path.join(G, 'ghost'))


if __name__ == '__main__':
    main()
