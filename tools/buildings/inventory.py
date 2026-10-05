"""Complete outdoor building inventory from the cartridge's own doors.

Every warp on an outdoor map whose destination is a building interior (not a
cave, route, woods, gate or hideout) is a building entrance; two adjacent
doors to the same place are one building. Output: inventory.json with
{n, name, map, doors} and inventory_NN.png sheets showing each building's
original drawing around its door, labelled with its real name.
Reads the local QA cache only."""
import sys, os, json, subprocess
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto')); sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
import voxproto, layers
G = voxproto.G + '/map_tree'
NOT_BUILDING = ('Cave', 'Tunnel', 'Falls', 'Path', 'Underwater', 'Seafloor', 'MirageTower', 'MtPyre', 'Chamber',
                'Ruins', 'Hideout', 'SkyPillar', 'Woods', 'Shoal', 'VictoryRoad', 'Rusturf', 'NewMauville',
                'Meteor', 'Jagged', 'Scorched', 'AncientTomb', 'Southern', 'MtChimney', 'Island',
                'AbandonedShip', 'ArtisanCave', 'Tomb', 'Slab', 'Altering', 'Desert', 'Magma', 'Aqua', 'Terra')
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
ids = subprocess.run(['luajit', '-e', 'local W=dofile(os.getenv("HOME").."/Documents/gen1recomp-modwork/world.lua") '
                      'for _,m in ipairs(W.maps) do if m.type==1 or m.type==2 or m.type==3 or m.type==6 then print(m.id,m.pair) end end'],
                     capture_output=True, text=True).stdout.split('\n')
world = {l.split()[0][3:].replace('_', '').lower(): (l.split()[0], l.split()[1]) for l in ids if l.strip()}
census = json.load(open(G + '/census.json'))
items = []
for g in census['groups']:
    for m in g['maps']:
        k = m['id'].replace('_', '').lower()
        if k not in world: continue
        p = G + '/maps/%s/events.json' % m['slot']
        if not os.path.exists(p): continue
        for w in json.load(open(p))['warps']:
            dest = w['destMap']
            if any(s in dest for s in NOT_BUILDING) and not dest.endswith(('House', 'Station')): continue
            if dest.replace('_', '').lower() in world: continue          # outdoor-to-outdoor
            same = [it for it in items if it['map'] == world[k][0] and it['name'] == dest
                    and any(abs(d[0] - w['x']) + abs(d[1] - w['y']) <= 2 for d in it['doors'])]
            if same: same[0]['doors'].append([w['x'], w['y']])
            else: items.append({'name': dest, 'map': world[k][0], 'pair': world[k][1], 'doors': [[w['x'], w['y']]]})
for n, it in enumerate(items, 1): it['n'] = n
json.dump(items, open(os.path.join(out, 'inventory.json'), 'w'), indent=1)
Ls, maps, panes = {}, {}, []
for it in items:
    if it['pair'] not in Ls: Ls[it['pair']] = layers.load(it['pair'])
    L = Ls[it['pair']]
    if 'u' not in L: continue
    if it['map'] not in maps: maps[it['map']] = voxproto.map_cells(it['map'])
    W, H, cells = maps[it['map']]
    dx = sum(d[0] for d in it['doors']) // len(it['doors']); dy = it['doors'][0][1]
    x0, x1 = max(0, dx - 7), min(W - 1, dx + 7); y0, y1 = max(0, dy - 9), min(H - 1, dy + 1)
    img = np.zeros(((y1 - y0 + 1) * 16, (x1 - x0 + 1) * 16, 3), np.uint8)
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            mid = cells[yy * W + xx] & 0x3ff
            if mid in L['u'][2]: img[(yy-y0)*16:(yy-y0+1)*16, (xx-x0)*16:(xx-x0+1)*16] = voxproto.art(L, mid)
    im = Image.fromarray(img); s = min(310 / im.width, 210 / im.height)
    im = im.resize((int(im.width * s), int(im.height * s)), Image.NEAREST)
    pane = Image.new('RGB', (320, 240), (18, 18, 22)); pane.paste(im, (5, 26))
    ImageDraw.Draw(pane).text((5, 4), '%03d %s' % (it['n'], it['name'][:44]), fill=(255, 230, 0))
    panes.append(pane)
per = 30
for i in range(0, len(panes), per):
    chunk = panes[i:i + per]; cols = 6; rows = (len(chunk) + cols - 1) // cols
    s = Image.new('RGB', (320 * cols, 240 * rows))
    for j, p in enumerate(chunk): s.paste(p, ((j % cols) * 320, (j // cols) * 240))
    s.save(os.path.join(out, 'inventory_%02d.png' % (i // per + 1)))
print(len(items), 'buildings with doors')
