#!/usr/bin/env python3
# cave_maps.py  -> tools/caves/maps_caves.txt (MAP x y, map centre) + maps_caves.csv (map type, tilesets, size)
# cave scope (task 28): header mapType 4 (underground), 9 (secret base), 5 underwater, plus the rock interiors typed 8 (Mt Pyre, Aqua Hideout, Faraway/Navel)
# left out: Abandoned Ship + New Mauville (Gen3Rock.cave skips them), and the outdoor-typed rock maps (Jagged Pass, Mt Pyre exterior/summit, Southern Island, Sky Pillar outside/top) that task 27 owns
import sys, json, re, os
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
base = emdata.GBA + '/map_tree/maps/'
man = emdata.manifest()
norm = {k[3:].replace('_', ''): k for k in man}
out, csvl = [], []
EXTRA = re.compile(r'^EM_(MT_PYRE_\dF|AQUA_HIDEOUT_(1F|B1F|B2F)|FARAWAY_ISLAND_|NAVEL_ROCK_(EXTERIOR|HARBOR)|ROUTE114_FOSSIL)')
SKIP = re.compile(r'ABANDONED_SHIP|NEW_MAUVILLE')
for e in emdata.census()['maps']:
    h = json.load(open(base + e['slot'] + '/header.json'))
    n = norm.get(e['id'].replace('_', '').upper()) or emdata.em_name(e['id']); mt = h['mapType']
    if SKIP.search(n): continue
    if mt in (4, 9) or (mt == 5 and 'UNDERWATER' in n) or EXTRA.search(n):
        out.append('%s %d %d' % (n, e['width'] // 2, e['height'] // 2))
        csvl.append('%s,%d,%s,%s,%d,%d,%s' % (n, mt, e['primaryTileset'][-4:], e['secondaryTileset'][-4:], e['width'], e['height'], man.get(n, '?')))
d = os.path.dirname(os.path.abspath(__file__))
open(d + '/maps_caves.txt', 'w').write('\n'.join(out) + '\n')
open(d + '/maps_caves.csv', 'w').write('map,mapType,prim,sec,w,h,pair\n' + '\n'.join(csvl) + '\n')
print(len(out), 'maps')
